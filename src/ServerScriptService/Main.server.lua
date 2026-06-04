-- Main.server.lua: server entry point.
-- Boots services in order, wires up all RemoteEvent handlers, starts income loop.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Boot remotes first so all services can reference them
require(ReplicatedStorage.InitRemotes)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DataService        = require(ServerScriptService.DataService)
local EconomyService     = require(ServerScriptService.EconomyService)
local CardService        = require(ServerScriptService.CardService)
local BracketService     = require(ServerScriptService.BracketService)
local TradeService       = require(ServerScriptService.TradeService)
local MonetizationService = require(ServerScriptService.MonetizationService)
local PlotService        = require(ServerScriptService.PlotService)
local KartService        = require(ServerScriptService.KartService)
local HubService         = require(ServerScriptService.HubService)
local DailyRewardService = require(ServerScriptService.DailyRewardService)
local BattlePassService  = require(ServerScriptService.BattlePassService)
local BuildingConfig     = require(ReplicatedStorage.Config.BuildingConfig)
local MatchdaySchedule   = require(ReplicatedStorage.Config.MatchdaySchedule)
local BattlePassConfig   = require(ReplicatedStorage.Config.BattlePassConfig)

-- Wire kart-station click pads → spawn rideable karts (tagged "KartSpawner").
KartService.init()

-- Build the shared Brainrot City hub + arena coin event, wire travel pads.
HubService.init()

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function notify(player, message, color)
	local event = Remotes:FindFirstChild("ShowNotification")
	if event then
		event:FireClient(player, { message = message, color = color or "white" })
	end
end

local function pushProfile(player)
	local data = DataService.getData(player)
	if not data then return end
	local event = Remotes:FindFirstChild("ProfileUpdated")
	if event then
		event:FireClient(player, data)
	end
end

local function pushDailyRewardState(player)
	local state = DailyRewardService.getState(player)
	if not state then return end
	local event = Remotes:FindFirstChild("DailyRewardState")
	if event then
		event:FireClient(player, state)
	end
end

-- Fire a MatchdayResolved event per result (drives the result popup, confetti,
-- and bracket-screen update on the client). Used on join (offline catch-up) and
-- live from the income loop when a matchday ticks over while the player is online.
local function sendMatchResults(player, results)
	if not results or #results == 0 then return end
	local event = Remotes:FindFirstChild("MatchdayResolved")
	if not event then return end
	for _, result in ipairs(results) do
		event:FireClient(player, result)
	end
end

-- Award battle-pass XP for a batch of match results (wins/draws).
local function awardMatchXp(player, results)
	if not results then return end
	for _, result in ipairs(results) do
		if result.outcome == "win" then
			BattlePassService.addXp(player, BattlePassConfig.XpAwards.matchWin)
		elseif result.outcome == "draw" then
			BattlePassService.addXp(player, BattlePassConfig.XpAwards.matchDraw)
		end
	end
end

-- ─── Player lifecycle ────────────────────────────────────────────────────────

-- Guard: in Play Solo this can fire from BOTH PlayerAdded and the startup loop,
-- which double-loads the profile and races the test-funds grant onto a copy that
-- isn't the live one. Run the join exactly once per user.
local joinedUsers = {}

local function onPlayerJoin(player)
	if joinedUsers[player.UserId] then return end
	joinedUsers[player.UserId] = true

	DataService.loadProfile(player)

	-- Wait for DataService to finish loading (ProfileService is async)
	local tries = 0
	while not DataService.getData(player) and tries < 30 do
		task.wait(0.5)
		tries += 1
	end

	local data = DataService.getData(player)
	if not data then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	-- Studio-only test funds so you can exercise upgrades and watch the stadium
	-- build up. RunService:IsStudio() is false on real servers, so this never
	-- affects live players.
	if game:GetService("RunService"):IsStudio() then
		data.coins = math.max(data.coins or 0, 1000000)
		data.passes = data.passes or {}
		data.passes.vip = true   -- so VIP-gated features (city teleport, Pro kart) are testable
	end

	print(string.format("[SvJoin] %s coins=%s gems=%s stands=%s isStudio=%s",
		player.Name, tostring(data.coins), tostring(data.gems),
		tostring(data.stadium and data.stadium.stands),
		tostring(game:GetService("RunService"):IsStudio())))

	-- Sync game pass ownership into profile cache
	MonetizationService.syncGamePasses(player)

	-- Assign group if first join
	BracketService.assignGroupIfNeeded(player)

	-- Reset battle-pass progress if the season rolled over while they were away
	BattlePassService.onPlayerJoin(player)

	-- Build the player's stadium plot (runtime-generated, tagged buildings)
	PlotService.buildPlot(player)

	-- Compute offline earnings
	local offlineEarned = EconomyService.applyOfflineEarnings(player)

	-- Resolve any missed matchdays
	local matchResults = BracketService.resolvePendingMatchdays(player)

	-- Start income tracking
	EconomyService.onPlayerJoin(player)

	-- Grant daily VIP gems
	MonetizationService.grantDailyVipGems(player)

	-- Push initial profile state to client
	pushProfile(player)

	-- Show offline earnings popup
	if offlineEarned > 0 then
		local event = Remotes:FindFirstChild("ShowOfflineEarnings")
		if event then
			event:FireClient(player, { coins = offlineEarned })
		end
	end

	-- Show match results that resolved while offline (+ battle-pass XP)
	sendMatchResults(player, matchResults)
	awardMatchXp(player, matchResults)

	-- Send next matchday countdown
	local nextEntry = MatchdaySchedule.getNextEntry(data.bracket.lastResolvedMatchday)
	if nextEntry then
		local event = Remotes:FindFirstChild("MatchdayCountdown")
		if event then
			event:FireClient(player, { timestamp = nextEntry.timestamp, matchdayId = nextEntry.matchdayId })
		end
	end

	-- Send daily reward state (client auto-opens the popup if claimable)
	pushDailyRewardState(player)
end

local function onPlayerLeave(player)
	joinedUsers[player.UserId] = nil
	EconomyService.onPlayerLeave(player)
	TradeService.onPlayerLeave(player)
	PlotService.removePlot(player)
	DataService.releaseProfile(player)
end

Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)

-- Handle players already in game when script runs
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoin, player)
end

-- ─── Income tick loop ────────────────────────────────────────────────────────

-- Push profile updates to clients every 5s to keep HUD in sync
local PROFILE_SYNC_INTERVAL = 5
local lastSync = {}

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()

		for _, player in ipairs(Players:GetPlayers()) do
			EconomyService.tickIncome(player, now)

			-- Studio-only: keep coins topped up so upgrades are always testable,
			-- even if the join-time grant raced the profile load.
			if game:GetService("RunService"):IsStudio() then
				local d = DataService.getData(player)
				if d and (d.coins or 0) < 100000 then d.coins = 1000000 end
			end

			-- Resolve any matchdays that ticked over while player is online,
			-- and notify them (popup + confetti + bracket update + countdown).
			local results = BracketService.resolvePendingMatchdays(player)
			if #results > 0 then
				sendMatchResults(player, results)
				awardMatchXp(player, results)
				pushProfile(player)

				local data = DataService.getData(player)
				local nextEntry = data and MatchdaySchedule.getNextEntry(data.bracket.lastResolvedMatchday)
				local cdEvent = Remotes:FindFirstChild("MatchdayCountdown")
				if nextEntry and cdEvent then
					cdEvent:FireClient(player, { timestamp = nextEntry.timestamp, matchdayId = nextEntry.matchdayId })
				end
			end

			-- Periodic profile sync to client
			local last = lastSync[player.UserId] or 0
			if now - last >= PROFILE_SYNC_INTERVAL then
				lastSync[player.UserId] = now
				pushProfile(player)
			end
		end
	end
end)

-- ─── RemoteEvent handlers ────────────────────────────────────────────────────

-- UpgradeBuilding: client sends buildingId
Remotes.UpgradeBuilding.OnServerEvent:Connect(function(player, buildingId)
	if type(buildingId) ~= "string" then return end
	local ok, err = EconomyService.upgradeBuilding(player, buildingId)
	if ok then
		BattlePassService.addXp(player, BattlePassConfig.XpAwards.upgrade)
		pushProfile(player)
		-- Grow the physical stadium to match the new level (live build-up).
		local data = DataService.getData(player)
		local lvl  = data and data.stadium and data.stadium[buildingId]
		if lvl then PlotService.onBuildingUpgraded(player, buildingId, lvl) end
		local cfg = BuildingConfig.ById[buildingId]
		notify(player, "Upgraded " .. (cfg and cfg.name or buildingId) .. "!", "green")
	else
		print("[SvUpgrade] " .. player.Name .. " " .. tostring(buildingId) .. " FAILED: " .. tostring(err))
		notify(player, "Cannot upgrade: " .. tostring(err), "red")
	end
end)

-- CollectBuilding: client sends buildingId
Remotes.CollectBuilding.OnServerEvent:Connect(function(player, buildingId)
	if type(buildingId) ~= "string" then return end
	local ok, earned = EconomyService.collectBuilding(player, buildingId)
	if ok then
		pushProfile(player)
		notify(player, "+" .. tostring(earned) .. " Coins!", "yellow")
	end
end)

-- OpenPack: client sends packId
Remotes.OpenPack.OnServerEvent:Connect(function(player, packId)
	if type(packId) ~= "string" then return end
	local ok, result = CardService.openPack(player, packId)
	if ok then
		BattlePassService.addXp(player, BattlePassConfig.XpAwards.packOpen)
		pushProfile(player)
		-- Send cards to client for pack opening animation
		local event = Remotes:FindFirstChild("PackOpenResult")
		if event then
			event:FireClient(player, { cards = result })
		end
	else
		notify(player, "Cannot open pack: " .. tostring(result), "red")
	end
end)

-- EquipSquad: client sends array of instanceIds
Remotes.EquipSquad.OnServerEvent:Connect(function(player, instanceIds)
	if type(instanceIds) ~= "table" then return end
	local ok, err = CardService.equipSquad(player, instanceIds)
	if ok then
		pushProfile(player)
	else
		notify(player, "Squad error: " .. tostring(err), "red")
	end
end)

-- GetBracketState: client requests bracket data
Remotes.GetBracketState.OnServerInvoke = function(player)
	return BracketService.getBracketState(player)
end

-- Trade remotes
Remotes.TradeRequest.OnServerEvent:Connect(function(player, targetName)
	if type(targetName) ~= "string" then return end
	local target = Players:FindFirstChild(targetName)
	if not target then
		notify(player, "Player not found.", "red")
		return
	end
	local ok, err = TradeService.requestTrade(player, target)
	if not ok then
		notify(player, "Trade failed: " .. tostring(err), "red")
	end
end)

Remotes.TradeOffer.OnServerEvent:Connect(function(player, instanceIds)
	if type(instanceIds) ~= "table" then return end
	TradeService.updateOffer(player, instanceIds)
end)

Remotes.TradeConfirm.OnServerEvent:Connect(function(player)
	TradeService.confirmTrade(player)
end)

Remotes.TradeCancel.OnServerEvent:Connect(function(player)
	TradeService.cancelTrade(player)
end)

-- Daily reward claim
Remotes.ClaimDailyReward.OnServerEvent:Connect(function(player)
	local ok, reward = DailyRewardService.claim(player)
	if ok then
		BattlePassService.addXp(player, BattlePassConfig.XpAwards.dailyClaim)
		pushProfile(player)
		pushDailyRewardState(player)
		local parts = { "Day " .. reward.streak .. " reward: +" .. reward.coins .. " Coins" }
		if reward.gems > 0 then table.insert(parts, "+" .. reward.gems .. " Gems") end
		notify(player, table.concat(parts, ", ") .. "!", "gold")
	else
		notify(player, "Daily reward not ready yet.", "red")
	end
end)

-- Battle pass: claim a tier reward
Remotes.ClaimBattlePassTier.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then return end
	local track = (payload.track == "premium") and "premium" or "free"
	local ok, err = BattlePassService.claimTier(player, payload.tier, track)
	if ok then
		pushProfile(player)
		notify(player, "Battle Pass reward claimed!", "gold")
	else
		notify(player, "Cannot claim: " .. tostring(err), "red")
	end
end)

-- Client → "I'm booted and listening, send my state." Covers the race where the
-- client connects its ProfileUpdated handler just after the join-time push.
Remotes.RequestState.OnServerEvent:Connect(function(player)
	local data = DataService.getData(player)
	if not data then return end
	pushProfile(player)
	pushDailyRewardState(player)
	local nextEntry = MatchdaySchedule.getNextEntry(data.bracket.lastResolvedMatchday)
	local cdEvent = Remotes:FindFirstChild("MatchdayCountdown")
	if nextEntry and cdEvent then
		cdEvent:FireClient(player, { timestamp = nextEntry.timestamp, matchdayId = nextEntry.matchdayId })
	end
end)

print("[StadiumTycoon] Server started.")
