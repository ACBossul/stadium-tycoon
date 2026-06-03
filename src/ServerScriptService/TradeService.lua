-- TradeService: atomic, server-authoritative card trades between two players.
-- The swap is done as a single operation after both sides confirm.
-- SECURITY: never trusts client-sent card ownership — always re-validates at swap time.
--
-- All client notifications are CLIENT-RELATIVE: each player receives a snapshot
-- with `yourOffer` / `theirOffer` / `youLocked` / `theyLocked` / `partnerName`,
-- so the UI never has to figure out whether it is "player A" or "player B".

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.DataService)

local TradeService = {}

-- Active trade sessions keyed by a canonical session id (lower UserId first)
local activeTrades = {}

-- Per-player cooldown after a trade completes (seconds)
local TRADE_COOLDOWN = 60
local tradeCooldowns = {}  -- UserId → time trade unlocks

local MAX_CARDS_PER_SIDE = 5

-- How many past trades to retain per player (bounds profile size).
local MAX_TRADE_LOG = 25

-- Remotes (resolved lazily after InitRemotes runs)
local function getRemotes()
	return ReplicatedStorage:WaitForChild("Remotes", 10)
end

-- Build a compact [{instanceId, cardId}] list from a snapshot map (iid -> card).
local function buildCardList(cardsMap)
	local out = {}
	for iid, card in pairs(cardsMap) do
		table.insert(out, { instanceId = iid, cardId = card.cardId })
	end
	return out
end

-- Append a trade record to a player's capped history (newest last).
local function appendTradeLog(data, entry)
	data.tradeLog = data.tradeLog or {}
	table.insert(data.tradeLog, entry)
	while #data.tradeLog > MAX_TRADE_LOG do
		table.remove(data.tradeLog, 1)
	end
end

-- ─── Session helpers ─────────────────────────────────────────────────────────

local function sessionId(playerA, playerB)
	local a, b = playerA.UserId, playerB.UserId
	if a > b then a, b = b, a end
	return a .. "_" .. b
end

local function makeSession(playerA, playerB)
	return {
		playerA = playerA,
		playerB = playerB,
		offerA  = {},   -- array of instanceIds offered by A
		offerB  = {},
		lockedA = false,
		lockedB = false,
	}
end

local function getSession(player)
	for _, session in pairs(activeTrades) do
		if session.playerA == player or session.playerB == player then
			return session
		end
	end
	return nil
end

-- ─── Display resolution ──────────────────────────────────────────────────────

-- Turn an array of instanceIds owned by `player` into client-renderable card info.
local function offerToDisplay(player, instanceIds)
	local out = {}
	local data = DataService.getData(player)
	if not data then return out end
	for _, iid in ipairs(instanceIds) do
		local card = data.cards[iid]
		if card then
			table.insert(out, { instanceId = iid, cardId = card.cardId, power = card.power })
		end
	end
	return out
end

-- Send one player their own perspective of the session.
local function sendStateToPlayer(session, player)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("TradeStateChanged")
	if not event then return end

	local isA        = (session.playerA == player)
	local me         = isA and session.playerA or session.playerB
	local partner    = isA and session.playerB or session.playerA
	local myOffer    = isA and session.offerA  or session.offerB
	local theirOffer = isA and session.offerB  or session.offerA
	local myLocked   = isA and session.lockedA or session.lockedB
	local theirLocked = isA and session.lockedB or session.lockedA

	event:FireClient(player, {
		type        = "state",
		partnerName = partner.Name,
		yourOffer   = offerToDisplay(me, myOffer),
		theirOffer  = offerToDisplay(partner, theirOffer),
		youLocked   = myLocked,
		theyLocked  = theirLocked,
	})
end

local function broadcastState(session)
	sendStateToPlayer(session, session.playerA)
	sendStateToPlayer(session, session.playerB)
end

local function notifyBoth(session, payload)
	local remotes = getRemotes()
	local event = remotes and remotes:FindFirstChild("TradeStateChanged")
	if not event then return end
	event:FireClient(session.playerA, payload)
	event:FireClient(session.playerB, payload)
end

-- ─── Validation ──────────────────────────────────────────────────────────────

local function playerOwnsAll(player, instanceIds)
	local data = DataService.getData(player)
	if not data then return false end
	for _, iid in ipairs(instanceIds) do
		if not data.cards[iid] then return false end
	end
	return true
end

local function isCooldownActive(player)
	local until_ = tradeCooldowns[player.UserId] or 0
	return os.time() < until_
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- Initiate a trade with a target player. Opens the trade window for both.
function TradeService.requestTrade(requester, target)
	if requester == target then return false, "cant_trade_self" end
	if isCooldownActive(requester) then return false, "cooldown" end
	if isCooldownActive(target)    then return false, "target_cooldown" end
	if getSession(requester) then return false, "already_in_trade" end
	if getSession(target)    then return false, "target_in_trade" end
	if not target:IsDescendantOf(Players) then return false, "not_online" end

	local sid     = sessionId(requester, target)
	local session = makeSession(requester, target)
	activeTrades[sid] = session

	-- Open the window for both sides (recipient sees the requester as partner).
	broadcastState(session)
	return true, nil
end

-- Update what a player is offering (resets BOTH locks — any change re-opens confirms).
function TradeService.updateOffer(player, instanceIds)
	if type(instanceIds) ~= "table" then return false, "invalid" end
	if #instanceIds > MAX_CARDS_PER_SIDE then return false, "too_many" end

	local session = getSession(player)
	if not session then return false, "no_session" end

	-- Validate the player actually owns everything they're offering.
	if not playerOwnsAll(player, instanceIds) then return false, "not_owned" end

	if session.playerA == player then
		session.offerA = instanceIds
	else
		session.offerB = instanceIds
	end
	-- Any offer change invalidates prior confirmations on both sides.
	session.lockedA = false
	session.lockedB = false

	broadcastState(session)
	return true, nil
end

-- Player locks/confirms their side. When both are locked the swap executes.
function TradeService.confirmTrade(player)
	local session = getSession(player)
	if not session then return false, "no_session" end

	if session.playerA == player then
		session.lockedA = true
	else
		session.lockedB = true
	end

	broadcastState(session)

	if session.lockedA and session.lockedB then
		return TradeService._executeSwap(session)
	end
	return true, nil
end

-- Cancel and remove the session, notifying both sides.
function TradeService.cancelTrade(player)
	local session = getSession(player)
	if not session then return end

	activeTrades[sessionId(session.playerA, session.playerB)] = nil
	notifyBoth(session, { type = "cancelled" })
end

-- Internal: atomic swap — re-validates ownership right before moving anything.
function TradeService._executeSwap(session)
	local pA, pB = session.playerA, session.playerB
	local dataA  = DataService.getData(pA)
	local dataB  = DataService.getData(pB)

	if not dataA or not dataB then
		TradeService.cancelTrade(pA)
		return false, "data_unavailable"
	end

	-- Re-validate ownership at swap time (critical anti-exploit check).
	if not playerOwnsAll(pA, session.offerA) then
		TradeService.cancelTrade(pA)
		return false, "ownership_invalid_a"
	end
	if not playerOwnsAll(pB, session.offerB) then
		TradeService.cancelTrade(pB)
		return false, "ownership_invalid_b"
	end

	-- Snapshot card data before mutating.
	local cardsFromA = {}
	for _, iid in ipairs(session.offerA) do cardsFromA[iid] = dataA.cards[iid] end
	local cardsFromB = {}
	for _, iid in ipairs(session.offerB) do cardsFromB[iid] = dataB.cards[iid] end

	-- Remove from both inventories, then grant to the opposite side.
	for iid in pairs(cardsFromA) do dataA.cards[iid] = nil end
	for iid in pairs(cardsFromB) do dataB.cards[iid] = nil end
	for iid, card in pairs(cardsFromA) do dataB.cards[iid] = card end
	for iid, card in pairs(cardsFromB) do dataA.cards[iid] = card end

	-- Record the trade in both players' histories (shared id cross-references the
	-- two sides). Written before the save so it persists with the swap.
	local now     = os.time()
	local tradeId = string.format("%d_%d_%d", now, pA.UserId, pB.UserId)
	local listA   = buildCardList(cardsFromA)   -- what A gave away
	local listB   = buildCardList(cardsFromB)   -- what B gave away
	appendTradeLog(dataA, {
		id = tradeId, time = now,
		partnerId = pB.UserId, partnerName = pB.Name,
		gave = listA, got = listB,
	})
	appendTradeLog(dataB, {
		id = tradeId, time = now,
		partnerId = pA.UserId, partnerName = pA.Name,
		gave = listB, got = listA,
	})

	-- Force save both immediately (trade is a critical mutation).
	DataService.forceSave(pA)
	DataService.forceSave(pB)

	-- Apply cooldowns.
	local unlockTime = os.time() + TRADE_COOLDOWN
	tradeCooldowns[pA.UserId] = unlockTime
	tradeCooldowns[pB.UserId] = unlockTime

	-- Tear down the session.
	activeTrades[sessionId(pA, pB)] = nil

	-- Notify completion with the cards each player just received
	-- (resolved AFTER the swap, so they read from the new owner's inventory).
	local remotes = getRemotes()
	local completeEvent = remotes and remotes:FindFirstChild("TradeComplete")
	if completeEvent then
		completeEvent:FireClient(pA, { received = offerToDisplay(pA, session.offerB) })
		completeEvent:FireClient(pB, { received = offerToDisplay(pB, session.offerA) })
	end

	return true, nil
end

-- Clean up when a player leaves mid-trade.
function TradeService.onPlayerLeave(player)
	TradeService.cancelTrade(player)
	tradeCooldowns[player.UserId] = nil
end

return TradeService
