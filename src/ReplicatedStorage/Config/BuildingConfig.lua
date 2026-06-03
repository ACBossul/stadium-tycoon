-- BuildingConfig: tunable numbers for every stadium building.
-- All balance knobs live here — no code edits needed for rebalancing.

local BuildingConfig = {}

-- OFFLINE_CAP: max seconds of idle earnings stored while player is away
BuildingConfig.OFFLINE_CAP = 8 * 60 * 60  -- 8 hours

-- Offline rate multiplier (fraction of online passive rate earned while away)
BuildingConfig.OFFLINE_RATE_MULT = 0.5

-- Auto-save interval in seconds
BuildingConfig.AUTOSAVE_INTERVAL = 60

-- Starting Coins given to new players
BuildingConfig.STARTING_COINS = 100

-- Buildings table. Fields:
--   id         unique key (matches profile.stadium field)
--   name       display name
--   baseRate   coins/sec at level 1
--   baseCost   upgrade cost at level 0→1
--   costMult   exponential multiplier per level (cost = baseCost * costMult^level)
--   maxLevel   hard cap (0 = unlimited for MVP, set to cap later)
--   activeOnly if true, player must interact to collect (not purely passive)
--   collectCooldown seconds between active collects (only used when activeOnly=true)

BuildingConfig.Buildings = {
	{
		id             = "stands",
		name           = "Stands",
		baseRate       = 1,      -- 1 coin/sec at level 1
		baseCost       = 50,
		costMult       = 1.15,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "concessions",
		name           = "Concession Stand",
		baseRate       = 3,      -- 3 coins/sec when actively collected
		baseCost       = 75,
		costMult       = 1.15,
		maxLevel       = 0,
		activeOnly     = true,
		collectCooldown = 30,    -- collect every 30s
	},
	{
		id             = "merch",
		name           = "Merch Shop",
		baseRate       = 2,
		baseCost       = 200,
		costMult       = 1.18,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "parking",
		name           = "Parking Lot",
		baseRate       = 1.5,
		baseCost       = 300,
		costMult       = 1.18,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "bigscreen",
		name           = "Big Screen",
		baseRate       = 4,
		baseCost       = 800,
		costMult       = 1.20,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "floodlights",
		name           = "Floodlights",
		baseRate       = 6,
		baseCost       = 2000,
		costMult       = 1.22,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
}

-- Build lookup by id
BuildingConfig.ById = {}
for _, b in ipairs(BuildingConfig.Buildings) do
	BuildingConfig.ById[b.id] = b
end

-- Returns the Coin cost to upgrade a building from its current level to level+1
function BuildingConfig.upgradeCost(buildingId, currentLevel)
	local b = BuildingConfig.ById[buildingId]
	if not b then return math.huge end
	return math.floor(b.baseCost * (b.costMult ^ currentLevel))
end

-- Returns coins/sec for a building at a given level (0 = not built yet)
function BuildingConfig.incomeRate(buildingId, level)
	if level <= 0 then return 0 end
	local b = BuildingConfig.ById[buildingId]
	if not b then return 0 end
	return b.baseRate * level
end

-- Returns total passive coins/sec across all buildings given the stadium table
function BuildingConfig.totalPassiveRate(stadium)
	local total = 0
	for _, b in ipairs(BuildingConfig.Buildings) do
		if not b.activeOnly then
			local level = stadium[b.id] or 0
			total += BuildingConfig.incomeRate(b.id, level)
		end
	end
	return total
end

return BuildingConfig
