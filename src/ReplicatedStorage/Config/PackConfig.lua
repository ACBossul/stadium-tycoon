-- PackConfig: pack types, costs, and card counts.

local PackConfig = {}

PackConfig.Packs = {
	{
		id          = "basic",
		name        = "Basic Pack",
		description = "3 cards. Anything can drop.",
		cardCount   = 3,
		costType    = "coins",   -- "coins" or "gems"
		cost        = 250,
		gemCost     = 0,
		oddsBoost   = {},        -- no rarity boost
	},
	{
		id          = "mega",
		name        = "Mega Pack",
		description = "5 cards. Guaranteed Rare or better.",
		cardCount   = 5,
		costType    = "coins",
		cost        = 800,
		gemCost     = 0,
		oddsBoost   = { Common = -0.15, Rare = 0.10, Epic = 0.04, Legendary = 0.01 },
		guaranteeFloor = "Rare",  -- at least one card is Rare+
	},
	{
		id          = "premium",
		name        = "Premium Pack",
		description = "5 cards. Doubled Epic+ odds. Gems only.",
		cardCount   = 5,
		costType    = "gems",
		cost        = 0,
		gemCost     = 100,
		oddsBoost   = { Common = -0.20, Rare = -0.05, Epic = 0.15, Legendary = 0.08, Mythic = 0.02 },
		guaranteeFloor = "Epic",
	},
	{
		id          = "matchday",
		name        = "Matchday Pack",
		description = "4 cards. Limited during live matchdays.",
		cardCount   = 4,
		costType    = "coins",
		cost        = 500,
		gemCost     = 0,
		oddsBoost   = { Common = -0.10, Rare = 0.07, Epic = 0.03 },
		limitedDuring = "matchday",
	},
}

PackConfig.ById = {}
for _, p in ipairs(PackConfig.Packs) do
	PackConfig.ById[p.id] = p
end

return PackConfig
