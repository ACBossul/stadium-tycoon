-- MonetizationConfig: Robux product IDs and their effects.
-- Replace placeholder IDs with real ones from the Creator Dashboard before publishing.

local MonetizationConfig = {}

-- Game Passes (one-time purchase, checked via MarketplaceService:UserOwnsGamePassAsync)
MonetizationConfig.GamePasses = {
	{
		id         = "double_coins",
		name       = "2x Coins",
		gamePassId = 000000001,  -- REPLACE with real game pass ID
		effect     = "coinMultiplier",
		value      = 2,
	},
	{
		id         = "double_offline",
		name       = "2x Offline Earnings",
		gamePassId = 000000002,  -- REPLACE
		effect     = "offlineMultiplier",
		value      = 2,
	},
	{
		id         = "vip",
		name       = "VIP",
		gamePassId = 000000003,  -- REPLACE
		effect     = "vip",
		value      = 1,
		dailyGems  = 10,         -- gems granted per day login
	},
}

-- Developer Products (consumable, handled in ProcessReceipt)
MonetizationConfig.DevProducts = {
	{
		id          = "gems_100",
		name        = "100 Gems",
		productId   = 100000001,  -- REPLACE
		gemsGranted = 100,
	},
	{
		id          = "gems_550",
		name        = "550 Gems",
		productId   = 100000002,  -- REPLACE
		gemsGranted = 550,
	},
	{
		id          = "gems_1200",
		name        = "1200 Gems",
		productId   = 100000003,  -- REPLACE
		gemsGranted = 1200,
	},
	{
		id          = "premium_pack_single",
		name        = "Premium Pack (Instant)",
		productId   = 100000004,  -- REPLACE
		packId      = "premium",
	},
}

-- Lookup by productId (for ProcessReceipt)
MonetizationConfig.DevProductById = {}
for _, p in ipairs(MonetizationConfig.DevProducts) do
	MonetizationConfig.DevProductById[p.productId] = p
end

MonetizationConfig.GamePassById = {}
for _, gp in ipairs(MonetizationConfig.GamePasses) do
	MonetizationConfig.GamePassById[gp.gamePassId] = gp
end

return MonetizationConfig
