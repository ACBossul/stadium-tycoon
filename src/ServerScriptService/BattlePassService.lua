-- BattlePassService: seasonal pass progression (server-authoritative).
-- Player progress lives in data.battlePass; the client reads it from the normal
-- ProfileUpdated sync and renders against the shared BattlePassConfig.
-- Claimed sets use STRING tier keys (safer than sparse integer keys for storage).

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService    = require(ServerScriptService.DataService)
local EconomyService = require(ServerScriptService.EconomyService)
local CardService    = require(ServerScriptService.CardService)
local Config         = require(ReplicatedStorage.Config.BattlePassConfig)

local BattlePassService = {}

-- Reset season progress if the player's stored season is stale (or unset).
local function ensureSeason(data)
	local bp = data.battlePass
	if bp.seasonId ~= Config.CurrentSeason.id then
		bp.seasonId       = Config.CurrentSeason.id
		bp.xp             = 0
		bp.premium        = false
		bp.claimedFree    = {}
		bp.claimedPremium = {}
	end
end

function BattlePassService.onPlayerJoin(player)
	local data = DataService.getData(player)
	if data then ensureSeason(data) end
end

function BattlePassService.addXp(player, amount)
	local data = DataService.getData(player)
	if not data or type(amount) ~= "number" or amount <= 0 then return end
	ensureSeason(data)
	data.battlePass.xp += amount
end

function BattlePassService.grantPremium(player)
	local data = DataService.getData(player)
	if not data then return end
	ensureSeason(data)
	data.battlePass.premium = true
end

local function grantReward(player, reward)
	if not reward then return end
	if reward.coins     then EconomyService.addCoins(player, reward.coins) end
	if reward.gems      then EconomyService.addGems(player, reward.gems) end
	if reward.packId    then CardService.grantPack(player, reward.packId) end
	if reward.cardFloor then CardService.grantRewardCard(player, reward.cardFloor) end
end

-- Claim a tier's reward on the given track ("free" or "premium").
function BattlePassService.claimTier(player, tier, track)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end
	ensureSeason(data)

	if type(tier) ~= "number" then return false, "invalid" end
	tier = math.floor(tier)
	local tierDef = Config.Tiers[tier]
	if not tierDef then return false, "invalid_tier" end

	-- Must have reached this tier via XP.
	if tier > Config.tierForXp(data.battlePass.xp) then
		return false, "locked"
	end

	local key = tostring(tier)
	local bp  = data.battlePass

	if track == "premium" then
		if not bp.premium then return false, "no_premium" end
		if bp.claimedPremium[key] then return false, "already_claimed" end
		bp.claimedPremium[key] = true
		grantReward(player, tierDef.premium)
	else
		if bp.claimedFree[key] then return false, "already_claimed" end
		bp.claimedFree[key] = true
		grantReward(player, tierDef.free)
	end

	return true, nil
end

return BattlePassService
