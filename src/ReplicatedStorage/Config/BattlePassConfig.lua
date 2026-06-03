-- BattlePassConfig: seasonal pass — free + premium reward tracks over 30 tiers.
-- "Recurring" revenue model: each SEASON players re-buy the premium track (Robux).
-- Roblox owns all billing, so there is no self-managed auto-charge; to rotate a
-- season, bump CurrentSeason.id (player progress auto-resets) and set a new endsAt.

local BattlePassConfig = {}

-- Bump `id` to start a new season (resets every player's XP/claims on next touch).
BattlePassConfig.CurrentSeason = {
	id     = "s1",
	name   = "Season 1: Road to the Final",
	endsAt = 1784484000 + 7 * 86400,   -- ~1 week after the Grand Final timestamp
}

BattlePassConfig.MAX_TIER    = 30
BattlePassConfig.XP_PER_TIER = 120

-- The Robux dev product that unlocks the premium track (see MonetizationConfig).
BattlePassConfig.PremiumProductId = 100000005

-- XP earned from core actions (keeps the pass tied to engagement, not just spend).
BattlePassConfig.XpAwards = {
	packOpen  = 25,
	matchWin  = 60,
	matchDraw = 30,
	dailyClaim = 50,
	upgrade   = 15,
}

-- Reward shape: { coins=, gems=, packId=, cardFloor= } (any subset).
-- 30 tiers generated: free track = coins (+ a pack at every 10th tier);
-- premium track = bigger coins + gems + cards, with milestone payouts.
BattlePassConfig.Tiers = {}
for t = 1, BattlePassConfig.MAX_TIER do
	local free = { coins = 200 + t * 40 }
	if t % 10 == 0 then
		free.packId = "basic"
	end

	local premium = { coins = 400 + t * 60, gems = 5 }
	if t % 5 == 0 then
		premium.cardFloor = "Epic"
	end
	if t % 10 == 0 then
		premium.packId = "premium"
		premium.gems = 20
	end
	if t == BattlePassConfig.MAX_TIER then
		premium.cardFloor = "Legendary"
		premium.gems = 50
	end

	BattlePassConfig.Tiers[t] = { tier = t, free = free, premium = premium }
end

-- Tier a player has reached for a given season XP total.
function BattlePassConfig.tierForXp(xp)
	return math.min(BattlePassConfig.MAX_TIER, math.floor((xp or 0) / BattlePassConfig.XP_PER_TIER))
end

return BattlePassConfig
