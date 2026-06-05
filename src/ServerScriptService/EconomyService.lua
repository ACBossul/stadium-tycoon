-- EconomyService: idle income, offline earnings, building upgrades, coin/gem mutations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService      = require(ServerScriptService.DataService)
local BuildingConfig   = require(ReplicatedStorage.Config.BuildingConfig)

local EconomyService   = {}

-- Throttle: accumulate income every N seconds rather than every frame
local TICK_RATE = 1  -- seconds between income ticks

-- The pending pot caps at this many seconds of income — once full it stops
-- growing, so players come back to the Cash Stand and collect (the grind loop).
local PENDING_CAP_SECONDS = 300

-- Track per-player income accumulator
local lastTickTime = {}  -- UserId → last tick timestamp

-- ─── Helpers ────────────────────────────────────────────────────────────────

-- Returns the coin multiplier for a player (2x Coins game pass)
local function getCoinMultiplier(data)
	if data.passes and data.passes.double_coins then
		return 2
	end
	return 1
end

-- Returns the offline multiplier for a player
local function getOfflineMultiplier(data)
	if data.passes and data.passes.double_offline then
		return 2
	end
	return 1
end

-- Permanent income multiplier from rebirths (+50% per rebirth).
local function getRebirthMultiplier(data)
	return 1 + (data.rebirths or 0) * 0.5
end
EconomyService.getRebirthMultiplier = getRebirthMultiplier

-- VIP earns +25% income (a tangible VIP perk on top of speed/kart/teleport).
local function getVipMultiplier(data)
	return (data.passes and data.passes.vip) and 1.25 or 1
end
EconomyService.getVipMultiplier = getVipMultiplier

-- Computes and grants offline earnings on player join
function EconomyService.applyOfflineEarnings(player)
	local data = DataService.getData(player)
	if not data then return 0 end

	local lastLogout = data.stats.lastLogout or 0
	if lastLogout == 0 then return 0 end

	local now = os.time()
	local awaySeconds = math.min(now - lastLogout, BuildingConfig.OFFLINE_CAP)
	if awaySeconds <= 0 then return 0 end

	local passiveRate = BuildingConfig.totalPassiveRate(data.stadium)
	local offlineMult = BuildingConfig.OFFLINE_RATE_MULT * getOfflineMultiplier(data)
	local coinMult    = getCoinMultiplier(data)
	local earned      = math.floor(passiveRate * offlineMult * coinMult * getRebirthMultiplier(data) * getVipMultiplier(data) * awaySeconds)

	if earned > 0 then
		data.coins += earned
		data.stats.totalEarned = (data.stats.totalEarned or 0) + earned
	end

	return earned
end

-- ─── Income tick (called from main loop) ────────────────────────────────────

function EconomyService.tickIncome(player, now)
	local data = DataService.getData(player)
	if not data then return end

	local last = lastTickTime[player.UserId] or now
	local delta = now - last
	if delta < TICK_RATE then return end

	lastTickTime[player.UserId] = now

	local rate   = EconomyService.currentRate(data)
	local earned = math.floor(rate * delta)

	if earned > 0 then
		-- Pile income into the collectible pot (capped) instead of auto-banking it,
		-- so earning is active: you go to your Cash Stand and collect.
		local capacity = math.floor(rate * PENDING_CAP_SECONDS)
		data.pending = math.min((data.pending or 0) + earned, math.max(capacity, 0))
	end
end

-- Income multiplier from an active "money" snack (checked inline so EconomyService
-- doesn't need to require SnackService — avoids a circular dependency).
local function getSnackMoneyMultiplier(data)
	if data.buffs and (data.buffs.money or 0) > os.time() then return 1.10 end
	return 1
end

-- Current income generation rate (coins/sec) after all multipliers.
function EconomyService.currentRate(data)
	if not data then return 0 end
	return BuildingConfig.totalPassiveRate(data.stadium)
		* getCoinMultiplier(data) * getRebirthMultiplier(data)
		* getVipMultiplier(data) * getSnackMoneyMultiplier(data)
end

-- Collect the pending pot into spendable coins (wired to the Cash Stand pad).
function EconomyService.collectEarnings(player)
	local data = DataService.getData(player)
	if not data then return 0 end
	local amount = math.floor(data.pending or 0)
	if amount <= 0 then return 0 end
	data.coins = (data.coins or 0) + amount
	data.pending = 0
	data.stats.totalEarned = (data.stats.totalEarned or 0) + amount
	return amount
end

function EconomyService.onPlayerJoin(player)
	lastTickTime[player.UserId] = os.time()
end

function EconomyService.onPlayerLeave(player)
	local data = DataService.getData(player)
	if data then
		data.stats.lastLogout = os.time()
	end
	lastTickTime[player.UserId] = nil
end

-- ─── Building upgrade ───────────────────────────────────────────────────────

-- Returns success, errorMessage
function EconomyService.upgradeBuilding(player, buildingId)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local cfg = BuildingConfig.ById[buildingId]
	if not cfg then return false, "invalid_building" end

	local currentLevel = data.stadium[buildingId] or 0

	if cfg.maxLevel > 0 and currentLevel >= cfg.maxLevel then
		return false, "max_level"
	end

	local cost = BuildingConfig.upgradeCost(buildingId, currentLevel)
	if data.coins < cost then
		return false, "insufficient_coins"
	end

	data.coins -= cost
	data.stadium[buildingId] = currentLevel + 1

	return true, nil
end

-- ─── Active collect (concession stand etc.) ─────────────────────────────────

local lastCollect = {}  -- UserId_buildingId → timestamp

function EconomyService.collectBuilding(player, buildingId)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local cfg = BuildingConfig.ById[buildingId]
	if not cfg then return false, "invalid_building" end
	if not cfg.activeOnly then return false, "not_active" end

	local level = data.stadium[buildingId] or 0
	if level <= 0 then return false, "not_built" end

	local key = player.UserId .. "_" .. buildingId
	local last = lastCollect[key] or 0
	local now  = os.time()

	if now - last < cfg.collectCooldown then
		return false, "cooldown"
	end

	lastCollect[key] = now

	local coinMult = getCoinMultiplier(data)
	local earned   = math.floor(cfg.baseRate * level * coinMult * cfg.collectCooldown)
	data.coins += earned
	data.stats.totalEarned = (data.stats.totalEarned or 0) + earned

	return true, earned
end

-- ─── Currency mutations (used by other services) ────────────────────────────

function EconomyService.addCoins(player, amount)
	local data = DataService.getData(player)
	if not data then return end
	data.coins += amount
	data.stats.totalEarned = (data.stats.totalEarned or 0) + amount
end

function EconomyService.deductCoins(player, amount)
	local data = DataService.getData(player)
	if not data then return false end
	if data.coins < amount then return false end
	data.coins -= amount
	return true
end

function EconomyService.addGems(player, amount)
	local data = DataService.getData(player)
	if not data then return end
	data.gems += amount
end

function EconomyService.deductGems(player, amount)
	local data = DataService.getData(player)
	if not data then return false end
	if data.gems < amount then return false end
	data.gems -= amount
	return true
end

return EconomyService
