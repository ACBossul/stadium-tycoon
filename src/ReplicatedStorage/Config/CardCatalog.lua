-- CardCatalog: all card definitions. Edit here to add/modify cards without touching service code.
-- Art fields are placeholder Roblox image asset IDs — swap for real decal uploads before launch.

local CardCatalog = {}

-- Rarity constants (also used by CardService for drop rate logic)
CardCatalog.Rarities = {
	COMMON    = "Common",
	RARE      = "Rare",
	EPIC      = "Epic",
	LEGENDARY = "Legendary",
	MYTHIC    = "Mythic",
}

-- Drop rates must sum to 1.0
CardCatalog.DropRates = {
	Common    = 0.60,
	Rare      = 0.25,
	Epic      = 0.11,
	Legendary = 0.035,
	Mythic    = 0.005,
}

-- Power ranges per rarity (min, max) — rolled uniformly on pack open
CardCatalog.PowerRanges = {
	Common    = { 10,  30  },
	Rare      = { 30,  60  },
	Epic      = { 60,  100 },
	Legendary = { 100, 160 },
	Mythic    = { 160, 250 },
}

-- Position constants
CardCatalog.Positions = {
	GK  = "GK",
	DEF = "DEF",
	MID = "MID",
	FWD = "FWD",
}

-- Card definitions. id must be unique snake_case string.
-- art:   placeholder "rbxassetid://0" — replace with uploaded decal IDs when ready.
-- emoji: procedural placeholder face, shown on a rarity gradient until real art exists.
CardCatalog.Cards = {
	-- GKs
	{ id = "the_wall",          name = "The Wall",               rarity = "Legendary", position = "GK",  emoji = "🧱", art = "rbxassetid://0" },
	{ id = "screaming_goat_gk", name = "Screaming Goat (GK)",    rarity = "Rare",      position = "GK",  emoji = "🐐", art = "rbxassetid://0" },
	{ id = "brick_hands",       name = "Brick Hands",            rarity = "Common",    position = "GK",  emoji = "🧤", art = "rbxassetid://0" },
	{ id = "jelly_keeper",      name = "Jelly Keeper",           rarity = "Epic",      position = "GK",  emoji = "🍮", art = "rbxassetid://0" },
	{ id = "npc_keeper",        name = "NPC Keeper",             rarity = "Common",    position = "GK",  emoji = "🤖", art = "rbxassetid://0" },

	-- DEFs
	{ id = "slab_jones",        name = "Slab Jones",             rarity = "Rare",      position = "DEF", emoji = "🪨", art = "rbxassetid://0" },
	{ id = "capybara_boots",    name = "Capybara in Boots",      rarity = "Epic",      position = "DEF", emoji = "🦫", art = "rbxassetid://0" },
	{ id = "wooden_wall",       name = "Wooden Wall FC",         rarity = "Common",    position = "DEF", emoji = "🪵", art = "rbxassetid://0" },
	{ id = "mr_offside",        name = "Mr. Offside",            rarity = "Common",    position = "DEF", emoji = "🚩", art = "rbxassetid://0" },
	{ id = "tank_bricksworth",  name = "Tank Bricksworth",       rarity = "Rare",      position = "DEF", emoji = "🛡️", art = "rbxassetid://0" },
	{ id = "soggy_boots_dan",   name = "Soggy Boots Dan",        rarity = "Common",    position = "DEF", emoji = "🥾", art = "rbxassetid://0" },
	{ id = "giant_crab_def",    name = "Giant Crab (DEF)",       rarity = "Legendary", position = "DEF", emoji = "🦀", art = "rbxassetid://0" },

	-- MIDs
	{ id = "ronaldont",         name = "Cristiano Ronaldon't",   rarity = "Legendary", position = "MID", emoji = "😎", art = "rbxassetid://0" },
	{ id = "messy",             name = "Lionel Messy",           rarity = "Mythic",    position = "MID", emoji = "🪄", art = "rbxassetid://0" },
	{ id = "dribble_king",      name = "Dribble King Jr.",       rarity = "Rare",      position = "MID", emoji = "👑", art = "rbxassetid://0" },
	{ id = "flopsy",            name = "Flopsy McFoulsworth",    rarity = "Common",    position = "MID", emoji = "🤡", art = "rbxassetid://0" },
	{ id = "spinning_raccoon",  name = "Spinning Raccoon",       rarity = "Epic",      position = "MID", emoji = "🦝", art = "rbxassetid://0" },
	{ id = "noodle_legs",       name = "Noodle Legs Nandez",     rarity = "Rare",      position = "MID", emoji = "🍜", art = "rbxassetid://0" },
	{ id = "the_tourist",       name = "The Tourist (MID)",      rarity = "Common",    position = "MID", emoji = "📸", art = "rbxassetid://0" },
	{ id = "wifi_warrior",      name = "Wifi Warrior",           rarity = "Epic",      position = "MID", emoji = "📶", art = "rbxassetid://0" },

	-- FWDs
	{ id = "mbappew",           name = "Kylian Mbap-pew",        rarity = "Mythic",    position = "FWD", emoji = "🚀", art = "rbxassetid://0" },
	{ id = "golden_hamster",    name = "Golden Hamster",         rarity = "Legendary", position = "FWD", emoji = "🐹", art = "rbxassetid://0" },
	{ id = "dr_dribbles",       name = "Dr. Dribbles",           rarity = "Rare",      position = "FWD", emoji = "🥼", art = "rbxassetid://0" },
	{ id = "tripping_hazard",   name = "Tripping Hazard",        rarity = "Common",    position = "FWD", emoji = "⚠️", art = "rbxassetid://0" },
	{ id = "hairy_striker",     name = "Hairy Striker",          rarity = "Common",    position = "FWD", emoji = "🦍", art = "rbxassetid://0" },
	{ id = "el_fantasma",       name = "El Fantasma",            rarity = "Epic",      position = "FWD", emoji = "👻", art = "rbxassetid://0" },
	{ id = "penguin_pete",      name = "Penguin Pete",           rarity = "Rare",      position = "FWD", emoji = "🐧", art = "rbxassetid://0" },
	{ id = "the_finisher",      name = "The Finisher 9000",      rarity = "Legendary", position = "FWD", emoji = "🎯", art = "rbxassetid://0" },
	{ id = "sneaky_ferret",     name = "Sneaky Ferret",          rarity = "Common",    position = "FWD", emoji = "🐀", art = "rbxassetid://0" },
	{ id = "sus_striker",       name = "Sus Striker",            rarity = "Rare",      position = "FWD", emoji = "🕵️", art = "rbxassetid://0" },
}

-- Build a lookup table by id for O(1) access
CardCatalog.ById = {}
for _, card in ipairs(CardCatalog.Cards) do
	CardCatalog.ById[card.id] = card
end

return CardCatalog
