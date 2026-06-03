-- InitRemotes: creates all RemoteEvents and RemoteFunctions once on server startup.
-- Run this from a Script in ServerScriptService before any service requires it.
-- Clients access remotes via ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local function makeEvent(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = folder
	return e
end

local function makeFunction(name)
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = folder
	return f
end

-- Economy
makeEvent("CollectBuilding")        -- client → server: collect active building
makeEvent("UpgradeBuilding")        -- client → server: upgrade building
makeEvent("ProfileUpdated")         -- server → client: push updated profile snapshot

-- Cards / Packs
makeEvent("OpenPack")               -- client → server: buy & open pack
makeEvent("PackOpenResult")         -- server → client: send card results for animation
makeEvent("EquipSquad")             -- client → server: set lineup (array of instanceIds)

-- Bracket
makeEvent("MatchdayResolved")       -- server → client: broadcast match result
makeFunction("GetBracketState")     -- client → server: pull current bracket data

-- Trade
makeEvent("TradeRequest")           -- client → server: request trade with player
makeEvent("TradeOffer")             -- client → server: update offered cards
makeEvent("TradeConfirm")           -- client → server: lock/confirm offer
makeEvent("TradeCancel")            -- client → server: cancel trade
makeEvent("TradeStateChanged")      -- server → client: push trade state to both parties
makeEvent("TradeComplete")          -- server → client: notify both that trade executed

-- Daily reward
makeEvent("ClaimDailyReward")       -- client → server: claim today's reward
makeEvent("DailyRewardState")       -- server → client: {claimable, streak, nextReward, ...}

-- Notifications / UI
makeEvent("ShowNotification")       -- server → client: toast popup
makeEvent("ShowOfflineEarnings")    -- server → client: welcome-back popup on join
makeEvent("MatchdayCountdown")      -- server → client: next matchday timestamp

return folder
