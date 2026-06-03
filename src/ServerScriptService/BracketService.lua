-- BracketService: scheduled matchday resolution, bracket progression, rewards.
-- Designed to be called both on player join (resolve missed matchdays) and
-- from the server heartbeat loop (resolve for online players as matchdays tick over).

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService        = require(ServerScriptService.DataService)
local EconomyService     = require(ServerScriptService.EconomyService)
local CardService        = require(ServerScriptService.CardService)
local MatchdaySchedule   = require(ReplicatedStorage.Config.MatchdaySchedule)

local BracketService = {}

-- Opponent power pool — AI teams drawn from this range at each stage
-- Gets stronger as the bracket narrows (no real teams, just parody names)
local OPPONENT_POWER_BY_STAGE = {
	group = { min = 80,  max = 180 },
	r32   = { min = 150, max = 250 },
	r16   = { min = 200, max = 320 },
	qf    = { min = 280, max = 400 },
	sf    = { min = 350, max = 480 },
	final = { min = 420, max = 550 },
	plate = { min = 60,  max = 160 },
}

-- Parody opponent team names — picked at random per match
local OPPONENT_NAMES = {
	"Los Azules", "Team Green-Yellow", "Die Orangen", "Les Rouges",
	"Gli Azzurrini", "A Seleção Amarela", "The Three Triangles",
	"Stars & Circles FC", "The Flying Triangles", "Neon United",
	"Brainfog FC", "The Goblet Hunters", "Chaos United",
	"Thunder Penguins SC", "Funky FC", "The Ringtails",
	"Wet Socks Athletic", "The Couch FC", "Baguette Boys",
}

-- ─── Stage progression ──────────────────────────────────────────────────────

local STAGE_AFTER_GROUP = "r32"

-- Called when player wins their group (3 group matchdays won or most points)
local function advanceFromGroup(bracketData)
	bracketData.stage = STAGE_AFTER_GROUP
	bracketData.eliminated = false
end

-- Called after each knockout win
local NEXT_KNOCKOUT_STAGE = {
	r32   = "r16",
	r16   = "qf",
	qf    = "sf",
	sf    = "final",
	final = "champion",
}

-- Called when a player is eliminated from main bracket
local function sendToPlate(bracketData)
	bracketData.eliminated = true
	bracketData.consolation = true
	bracketData.stage = "plate"
end

-- ─── Match resolution ───────────────────────────────────────────────────────

local function rollOpponentPower(stage)
	local range = OPPONENT_POWER_BY_STAGE[stage] or OPPONENT_POWER_BY_STAGE.plate
	return math.random(range.min, range.max)
end

-- Returns "win", "draw", or "loss"
-- Uses win-probability formula with a random swing for drama
local function resolveMatch(playerPower, opponentPower)
	local total = playerPower + opponentPower
	if total == 0 then total = 1 end
	local winProb = playerPower / total

	-- Add ±10% random swing
	local swing = (math.random() - 0.5) * 0.20
	winProb = math.clamp(winProb + swing, 0.05, 0.95)

	local roll = math.random()
	if roll < winProb * 0.9 then
		return "win"
	elseif roll < winProb * 0.9 + 0.1 then
		return "draw"
	else
		return "loss"
	end
end

-- Resolve all pending matchdays for a player
-- Returns array of result tables (for notifying client)
function BracketService.resolvePendingMatchdays(player)
	local data = DataService.getData(player)
	if not data then return {} end

	local now     = os.time()
	local pending = MatchdaySchedule.getPendingEntries(data.bracket.lastResolvedMatchday, now)
	if #pending == 0 then return {} end

	local results = {}
	local playerPower = CardService.getSquadPowerFromData(data)

	for _, entry in ipairs(pending) do
		-- Skip if already fully progressed (champion or plate fully played)
		if data.bracket.stage == "champion" then break end

		-- Only resolve if this entry's stage matches where the player currently is
		-- (or if the player is in consolation and this is a plate matchday)
		local activeStage = data.bracket.stage
		if entry.stage ~= activeStage and not data.bracket.consolation then
			-- Player skipped a stage somehow — advance them passively
			data.bracket.stage = entry.stage
			activeStage = entry.stage
		end

		local opponentPower = rollOpponentPower(activeStage)
		local opponentName  = OPPONENT_NAMES[math.random(1, #OPPONENT_NAMES)]
		local outcome       = resolveMatch(playerPower, opponentPower)

		-- Update bracket state
		if activeStage == "group" then
			if outcome == "win" then
				data.bracket.points += 3
				data.bracket.wins   += 1
				data.stats.totalWins = (data.stats.totalWins or 0) + 1
			elseif outcome == "draw" then
				data.bracket.points += 1
				data.bracket.draws  += 1
			else
				data.bracket.losses += 1
			end

			-- After 3rd group matchday, decide progression
			if entry.matchdayId == "group_3" then
				if data.bracket.points >= 4 then
					advanceFromGroup(data.bracket)
				else
					sendToPlate(data.bracket)
				end
			end
		else
			-- Knockout or plate
			if outcome == "win" then
				data.stats.totalWins = (data.stats.totalWins or 0) + 1
				local next = NEXT_KNOCKOUT_STAGE[activeStage]
				if next then
					data.bracket.stage = next
				end
			elseif outcome == "loss" then
				if activeStage == "plate" then
					-- Dead end on plate is ok — keep them here, still earns
				else
					sendToPlate(data.bracket)
				end
			end
			-- draws in knockout: reroll (simple tie-break: player wins on draw for fun UX)
			if outcome == "draw" then
				data.stats.totalWins = (data.stats.totalWins or 0) + 1
				local next = NEXT_KNOCKOUT_STAGE[activeStage]
				if next then data.bracket.stage = next end
			end
		end

		-- Grant rewards
		local coinReward = MatchdaySchedule.WinRewards[activeStage] or 0
		local cardFloor  = MatchdaySchedule.WinCardFloor[activeStage] or "Rare"
		local grantedCard = nil

		if outcome == "win" or outcome == "draw" then
			EconomyService.addCoins(player, coinReward)
			grantedCard = CardService.grantRewardCard(player, cardFloor)
		else
			-- Consolation for loss: 25% of win reward, no card
			EconomyService.addCoins(player, math.floor(coinReward * 0.25))
		end

		data.bracket.lastResolvedMatchday = entry.matchdayId

		table.insert(results, {
			matchdayId    = entry.matchdayId,
			stage         = activeStage,
			outcome       = outcome,
			playerPower   = playerPower,
			opponentPower = opponentPower,
			opponentName  = opponentName,
			coinReward    = (outcome ~= "loss") and coinReward or math.floor(coinReward * 0.25),
			grantedCard   = grantedCard,
			newStage      = data.bracket.stage,
		})
	end

	if #results > 0 then
		DataService.forceSave(player)
	end

	return results
end

-- Assign a group letter on first join (random A–L for 12 groups)
function BracketService.assignGroupIfNeeded(player)
	local data = DataService.getData(player)
	if not data then return end
	if data.bracket.group ~= "A" then return end  -- already assigned to a non-default

	local letters = {"A","B","C","D","E","F","G","H","I","J","K","L"}
	data.bracket.group = letters[math.random(1, #letters)]
end

-- Returns current bracket state for client display
function BracketService.getBracketState(player)
	local data = DataService.getData(player)
	if not data then return nil end

	local nextEntry = MatchdaySchedule.getNextEntry(data.bracket.lastResolvedMatchday)
	return {
		bracket      = data.bracket,
		nextMatchday = nextEntry,
		squadPower   = CardService.getSquadPowerFromData(data),
	}
end

return BracketService
