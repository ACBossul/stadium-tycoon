-- DataService: ProfileService wrapper.
-- Drop ProfileService (or ProfileStore) into ServerScriptService/Packages before using.
-- https://madstudioroblox.github.io/ProfileService/

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- Adjust path if you place ProfileService elsewhere
local ProfileService = require(ServerScriptService.Packages.ProfileService)

local DataService = {}

local STORE_NAME = "PlayerData_v1"

-- Default profile — all new players start from this
local PROFILE_TEMPLATE = {
	version = 1,
	coins   = 100,
	gems    = 0,

	-- One entry per building id; value is current level (0 = not purchased)
	stadium = {
		stands      = 1,
		concessions = 0,
		merch       = 0,
		parking     = 0,
		bigscreen   = 0,
		floodlights = 0,
	},

	-- Card inventory: key = unique instance id (generated server-side), value = table
	-- { cardId = "...", power = N }  (power rolled once at pack-open time)
	cards = {},

	-- Ordered array of instance ids currently equipped in the squad (up to 11)
	squad = {},

	bracket = {
		cupId               = "brainrot_cup_2026",
		group               = "A",       -- assigned on first join
		points              = 0,
		wins                = 0,
		draws               = 0,
		losses              = 0,
		stage               = "group",   -- group | r32 | r16 | qf | sf | final | plate
		eliminated          = false,
		consolation         = false,
		lastResolvedMatchday = "",
	},

	stats = {
		lastLogout    = 0,
		totalWins     = 0,
		packsOpened   = 0,
		totalEarned   = 0,
	},

	-- Game pass ownership cache (refreshed on join; authoritative check is MarketplaceService)
	passes = {
		double_coins   = false,
		double_offline = false,
		vip            = false,
	},

	-- Last time daily VIP gems were granted (Unix timestamp)
	lastVipGemGrant = 0,

	-- Daily login reward tracking
	lastDailyClaim = 0,   -- Unix timestamp of last claim
	dailyStreak    = 0,   -- consecutive-day streak count

	-- ProcessReceipt idempotency log: [tostring(PurchaseId)] = true
	purchaseHistory = {},

	-- Trade history (capped, newest last) for support / dispute review
	tradeLog = {},

	settings = {},
}

local ProfileStore = ProfileService.GetProfileStore(STORE_NAME, PROFILE_TEMPLATE)

-- Map UserId → profile
local Profiles = {}

-- Internal: called when a profile loads
local function onProfileLoaded(player, profile)
	-- Reconcile any new template keys added since last save
	profile:Reconcile()

	profile:ListenToRelease(function()
		Profiles[player.UserId] = nil
		player:Kick("Your data was loaded elsewhere. Please rejoin.")
	end)

	if not player:IsDescendantOf(Players) then
		profile:Release()
		return
	end

	Profiles[player.UserId] = profile
end

-- Load profile when player joins (called from main server init script)
function DataService.loadProfile(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile then
		onProfileLoaded(player, profile)
	else
		-- Could not load data — kick rather than let player play with blank state
		player:Kick("Could not load your data. Please rejoin.")
	end
end

-- Release profile when player leaves
function DataService.releaseProfile(player)
	local profile = Profiles[player.UserId]
	if profile then
		profile:Release()
	end
end

-- Returns the live profile data table (mutable)
function DataService.getProfile(player)
	return Profiles[player.UserId]
end

-- Returns just the data table (shorthand)
function DataService.getData(player)
	local profile = Profiles[player.UserId]
	return profile and profile.Data or nil
end

-- Safe setter helper — saves happen automatically via ProfileService auto-save
-- Optionally call profile:Save() after critical mutations (trade, purchase)
function DataService.forceSave(player)
	local profile = Profiles[player.UserId]
	if profile then
		profile:Save()
	end
end

return DataService
