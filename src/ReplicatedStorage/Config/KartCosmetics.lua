-- KartCosmetics: kart paint jobs you preview + buy at the City garage. Non-VIP
-- skins cost coins (one-time unlock). VIP skins are exclusive to VIP owners.
-- KartService recolours the kart to the player's equipped skin.

local KartCosmetics = {}

KartCosmetics.Skins = {
	{ id = "stock",   name = "Stock",         body = Color3.fromRGB(150, 152, 162), accent = Color3.fromRGB(95, 98, 110),  cost = 0,     vip = false },
	{ id = "crimson", name = "Crimson",       body = Color3.fromRGB(200, 60, 55),   accent = Color3.fromRGB(38, 40, 46),   cost = 3000,  vip = false },
	{ id = "forest",  name = "Forest",        body = Color3.fromRGB(48, 150, 82),   accent = Color3.fromRGB(28, 40, 32),   cost = 6000,  vip = false },
	{ id = "violet",  name = "Violet Haze",   body = Color3.fromRGB(140, 70, 200),  accent = Color3.fromRGB(40, 28, 60),   cost = 12000, vip = false },
	{ id = "gold",    name = "Champion Gold", body = Color3.fromRGB(240, 200, 70),  accent = Color3.fromRGB(70, 52, 18),   cost = 0,     vip = true },
	{ id = "chrome",  name = "Chrome",        body = Color3.fromRGB(222, 228, 238), accent = Color3.fromRGB(120, 130, 150), cost = 0,     vip = true },
}

KartCosmetics.ById = {}
for _, s in ipairs(KartCosmetics.Skins) do
	KartCosmetics.ById[s.id] = s
end

return KartCosmetics
