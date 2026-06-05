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

	-- ── More parody stars (transformative pun names only — no real players) ──
	-- GKs
	{ id = "allison_wonderland",name = "Allison Wonderland",     rarity = "Epic",      position = "GK",  emoji = "🐰", art = "rbxassetid://0" },
	{ id = "ter_stagnant",      name = "Ter Stagnant",           rarity = "Rare",      position = "GK",  emoji = "🧤", art = "rbxassetid://0" },
	{ id = "gigi_donnarumble",  name = "Gigi Donna-Rumble",      rarity = "Epic",      position = "GK",  emoji = "🥊", art = "rbxassetid://0" },
	{ id = "butter_fingers_ed", name = "Butter Fingers Ed",      rarity = "Common",    position = "GK",  emoji = "🧈", art = "rbxassetid://0" },
	-- DEFs
	{ id = "big_virg",          name = "Big Virg",               rarity = "Legendary", position = "DEF", emoji = "🗿", art = "rbxassetid://0" },
	{ id = "sergio_bricks",     name = "Sergio Bricks",          rarity = "Epic",      position = "DEF", emoji = "🟥", art = "rbxassetid://0" },
	{ id = "hakimi_mini",       name = "Hakimi Mini",            rarity = "Rare",      position = "DEF", emoji = "🏍️", art = "rbxassetid://0" },
	{ id = "cancel_o",          name = "Cancel-O",               rarity = "Rare",      position = "DEF", emoji = "❌", art = "rbxassetid://0" },
	{ id = "marqui_nilla",      name = "Marqui-Nilla",           rarity = "Epic",      position = "DEF", emoji = "🍦", art = "rbxassetid://0" },
	{ id = "couch_potato_def",  name = "Couch Potato (DEF)",     rarity = "Common",    position = "DEF", emoji = "🥔", art = "rbxassetid://0" },
	-- MIDs
	{ id = "de_bruyne_out",     name = "De Bruyne-Out",          rarity = "Legendary", position = "MID", emoji = "🅱️", art = "rbxassetid://0" },
	{ id = "pedri_oops",        name = "Pedri-Oops",             rarity = "Rare",      position = "MID", emoji = "🎮", art = "rbxassetid://0" },
	{ id = "gavi_goo",          name = "Gavi-Goo",               rarity = "Rare",      position = "MID", emoji = "🍬", art = "rbxassetid://0" },
	{ id = "modritch",          name = "Modritch",               rarity = "Epic",      position = "MID", emoji = "⏳", art = "rbxassetid://0" },
	{ id = "jude_bellingjam",   name = "Jude Belling-Jam",       rarity = "Legendary", position = "MID", emoji = "🍓", art = "rbxassetid://0" },
	{ id = "phil_fodenfresh",   name = "Phil Foden-Fresh",       rarity = "Epic",      position = "MID", emoji = "🧒", art = "rbxassetid://0" },
	{ id = "jack_greaselish",   name = "Jack Grease-Lish",       rarity = "Rare",      position = "MID", emoji = "💇", art = "rbxassetid://0" },
	{ id = "lag_switch_luka",   name = "Lag-Switch Luka",        rarity = "Common",    position = "MID", emoji = "📡", art = "rbxassetid://0" },
	-- FWDs
	{ id = "ney_mahh",          name = "Ney-Mahh Jr.",           rarity = "Mythic",    position = "FWD", emoji = "🤹", art = "rbxassetid://0" },
	{ id = "halaland",          name = "Hala-Land",              rarity = "Legendary", position = "FWD", emoji = "🤖", art = "rbxassetid://0" },
	{ id = "lewandontski",      name = "Lewandontski",           rarity = "Epic",      position = "FWD", emoji = "🎯", art = "rbxassetid://0" },
	{ id = "viniright_jr",      name = "Viniright Jr.",          rarity = "Epic",      position = "FWD", emoji = "✨", art = "rbxassetid://0" },
	{ id = "mo_salami",         name = "Mo Salah-mi",            rarity = "Rare",      position = "FWD", emoji = "🥪", art = "rbxassetid://0" },
	{ id = "harry_cane",        name = "Harry Cane",             rarity = "Rare",      position = "FWD", emoji = "🍬", art = "rbxassetid://0" },
	{ id = "marcus_flashford",  name = "Marcus Flashford",       rarity = "Rare",      position = "FWD", emoji = "⚡", art = "rbxassetid://0" },
	{ id = "benchwarmer_bob",   name = "Benchwarmer Bob",        rarity = "Common",    position = "FWD", emoji = "🪑", art = "rbxassetid://0" },

	-- ── More roster (parody puns only) ──
	{ id = "ederzone",          name = "Ederzone",               rarity = "Epic",      position = "GK",  emoji = "🧅", art = "rbxassetid://0" },
	{ id = "keylor_naptime",    name = "Keylor Naptime",         rarity = "Rare",      position = "GK",  emoji = "😴", art = "rbxassetid://0" },
	{ id = "ruben_diabolical",  name = "Ruben Diabolical",       rarity = "Epic",      position = "DEF", emoji = "😈", art = "rbxassetid://0" },
	{ id = "theo_hern_and_ez",  name = "Theo Hern-and-Ez",       rarity = "Rare",      position = "DEF", emoji = "🔧", art = "rbxassetid://0" },
	{ id = "koulibricky",       name = "Kalidou Koulibricky",    rarity = "Epic",      position = "DEF", emoji = "🧱", art = "rbxassetid://0" },
	{ id = "toni_crouton",      name = "Toni Crouton",           rarity = "Epic",      position = "MID", emoji = "🥖", art = "rbxassetid://0" },
	{ id = "kant_stop",         name = "Kant-Stop",              rarity = "Legendary", position = "MID", emoji = "🏃", art = "rbxassetid://0" },
	{ id = "bruno_fernandoh",   name = "Bruno Fernandoh",        rarity = "Epic",      position = "MID", emoji = "😤", art = "rbxassetid://0" },
	{ id = "ped_rye_bread",     name = "Ped-Rye Bread",          rarity = "Rare",      position = "MID", emoji = "🍞", art = "rbxassetid://0" },
	{ id = "vlahovroom",        name = "Vlahovroom",             rarity = "Epic",      position = "FWD", emoji = "🏎️", art = "rbxassetid://0" },
	{ id = "osi_when",          name = "Victor Osi-When?",       rarity = "Legendary", position = "FWD", emoji = "⏰", art = "rbxassetid://0" },
	{ id = "raheem_steam",      name = "Raheem Steam",           rarity = "Rare",      position = "FWD", emoji = "♨️", art = "rbxassetid://0" },

	-- ── Rebirth-exclusive cards (never drop in packs — only from rebirthing) ──
	{ id = "rb_the_prestige",   name = "The Prestige",           rarity = "Mythic",    position = "MID", emoji = "🌟", art = "rbxassetid://0", rebirthOnly = true },
	{ id = "rb_golden_reaper",  name = "Golden Reaper",          rarity = "Mythic",    position = "FWD", emoji = "💀", art = "rbxassetid://0", rebirthOnly = true },
	{ id = "rb_ascended_one",   name = "The Ascended One",       rarity = "Mythic",    position = "GK",  emoji = "🔆", art = "rbxassetid://0", rebirthOnly = true },
	{ id = "rb_phoenix",        name = "Phoenix Reborn",         rarity = "Mythic",    position = "DEF", emoji = "🔥", art = "rbxassetid://0", rebirthOnly = true },
	{ id = "rb_infinity",       name = "Infinity Striker",       rarity = "Mythic",    position = "FWD", emoji = "♾️", art = "rbxassetid://0", rebirthOnly = true },
}

-- Build a lookup table by id for O(1) access
CardCatalog.ById = {}
for _, card in ipairs(CardCatalog.Cards) do
	CardCatalog.ById[card.id] = card
end

return CardCatalog
