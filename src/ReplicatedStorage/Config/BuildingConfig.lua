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
	-- Progressive build: you start with NOTHING built. Lay the pitch first (cheap),
	-- then the lower-stands bowl, then the big grandstand, then the rest — each is a
	-- "Build" then "Upgrade". Costs roughly enforce that order.
	{
		id = "pitch", name = "The Pitch",
		baseRate = 2, baseCost = 40, costMult = 1.15, maxLevel = 0, activeOnly = false, collectCooldown = 0,
	},
	{
		id = "lowerstands", name = "Lower Stands",
		baseRate = 4, baseCost = 150, costMult = 1.15, maxLevel = 0, activeOnly = false, collectCooldown = 0,
	},
	{
		id             = "stands",
		name           = "Grandstand",
		baseRate       = 8,
		baseCost       = 350,
		costMult       = 1.15,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "concessions",
		name           = "Concession Stand",
		baseRate       = 3,
		baseCost       = 600,
		costMult       = 1.15,
		maxLevel       = 0,
		activeOnly     = false,   -- now feeds the Cash Stand like the others
		collectCooldown = 0,
	},
	{
		id             = "parking",
		name           = "Parking Lot",
		baseRate       = 6,
		baseCost       = 900,
		costMult       = 1.18,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "merch",
		name           = "Merch Shop",
		baseRate       = 18,
		baseCost       = 1400,
		costMult       = 1.18,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "bigscreen",
		name           = "Big Screen",
		baseRate       = 30,
		baseCost       = 2200,
		costMult       = 1.20,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		id             = "floodlights",
		name           = "Floodlights",
		baseRate       = 55,
		baseCost       = 4500,
		costMult       = 1.22,
		maxLevel       = 0,
		activeOnly     = false,
		collectCooldown = 0,
	},
	{
		-- The end-game structural upgrade: walls rise into a facade and a roof ring
		-- grows in + up each level, turning the ground into an enclosed stadium.
		id             = "structure",
		name           = "Stadium Roof",
		baseRate       = 25,
		baseCost       = 8000,
		costMult       = 1.26,
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
