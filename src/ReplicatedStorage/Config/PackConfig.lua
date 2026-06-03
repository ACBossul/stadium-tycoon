-- PackConfig: pack types, costs, and card counts.
-- `Packs`      = always available in the shop.
-- `EventPacks` = limited; only purchasable while an EventConfig window is active
--                (server-enforced). Marked eventOnly = true.

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
}

-- Limited-time packs surfaced by EventConfig during their windows.
PackConfig.EventPacks = {
	{
		id          = "ev_matchday",
		name        = "Matchday Drop",
		description = "4 cards. Live only on matchdays. Boosted Rare/Epic.",
		cardCount   = 4,
		costType    = "coins",
		cost        = 600,
		gemCost     = 0,
		oddsBoost   = { Common = -0.12, Rare = 0.08, Epic = 0.04 },
		eventOnly   = true,
	},
	{
		id          = "ev_knockout",
		name        = "Knockout Drop",
		description = "5 cards. Knockout rounds only. Guaranteed Epic+.",
		cardCount   = 5,
		costType    = "gems",
		cost        = 0,
		gemCost     = 120,
		oddsBoost   = { Common = -0.20, Rare = -0.05, Epic = 0.13, Legendary = 0.10, Mythic = 0.02 },
		guaranteeFloor = "Epic",
		eventOnly   = true,
	},
	{
		id          = "ev_grandfinal",
		name        = "Grand Final Mega",
		description = "6 cards. 48h only. Massively boosted Mythic odds!",
		cardCount   = 6,
		costType    = "gems",
		cost        = 0,
		gemCost     = 250,
		oddsBoost   = { Common = -0.25, Rare = -0.10, Epic = 0.10, Legendary = 0.10, Mythic = 0.08 },
		guaranteeFloor = "Legendary",
		eventOnly   = true,
	},
}

-- Lookup by id covers BOTH always-available and event packs.
PackConfig.ById = {}
for _, p in ipairs(PackConfig.Packs) do
	PackConfig.ById[p.id] = p
end
for _, p in ipairs(PackConfig.EventPacks) do
	PackConfig.ById[p.id] = p
end

return PackConfig
