-- ClientMain.client.lua: bootstraps all client controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if not Remotes then
	warn("[Client] Remotes not found. Server may not have started.")
	return
end

-- Shared state that all controllers read/write
local ClientState = {
	profile  = nil,    -- last ProfileUpdated payload
	remotes  = Remotes,
}

-- Load controllers
local StadiumController  = require(script.Parent.StadiumController)
local UIController       = require(script.Parent.UIController)
local PackOpenController = require(script.Parent.PackOpenController)
local BracketController  = require(script.Parent.BracketController)
local KartController      = require(script.Parent.KartController)

StadiumController.init(ClientState)
UIController.init(ClientState)
PackOpenController.init(ClientState)
BracketController.init(ClientState)
KartController.init(ClientState)

-- ─── Server → client events ───────────────────────────────────────────────

Remotes.ProfileUpdated.OnClientEvent:Connect(function(profileData)
	ClientState.profile = profileData
	UIController.onProfileUpdated(profileData)
	StadiumController.onProfileUpdated(profileData)
end)

Remotes.ShowNotification.OnClientEvent:Connect(function(payload)
	UIController.showToast(payload.message, payload.color)
end)

Remotes.ShowOfflineEarnings.OnClientEvent:Connect(function(payload)
	UIController.showOfflineEarnings(payload.coins)
end)

Remotes.PackOpenResult.OnClientEvent:Connect(function(payload)
	PackOpenController.playReveal(payload.cards)
end)

Remotes.MatchdayResolved.OnClientEvent:Connect(function(result)
	BracketController.onMatchResolved(result)
	UIController.showMatchResult(result)
end)

Remotes.MatchdayCountdown.OnClientEvent:Connect(function(payload)
	BracketController.setNextMatchday(payload.timestamp, payload.matchdayId)
end)

Remotes.TradeStateChanged.OnClientEvent:Connect(function(payload)
	UIController.onTradeStateChanged(payload)
end)

Remotes.TradeComplete.OnClientEvent:Connect(function(payload)
	UIController.onTradeComplete(payload)
end)

print("[StadiumTycoon] Client started.")
