-- ClientMain.client.lua: bootstraps all client controllers.
--
-- Hardened boot: a failure (or missing module) in ANY one controller can no longer
-- halt the whole client. Previously a single erroring/yielding require here meant
-- NOTHING downstream ran — no nav buttons, no upgrade wiring, no ProfileUpdated
-- sync (income stuck at 0). Now every require/init/handler is isolated, and we
-- print progress so the Output window shows exactly how far boot got.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

print("[StadiumTycoon] Client booting…")

-- ─── On-screen debug readout (so state is visible WITHOUT the Output window) ─────
local dbgGui = Instance.new("ScreenGui")
dbgGui.Name           = "DebugOverlay"
dbgGui.ResetOnSpawn   = false
dbgGui.IgnoreGuiInset = true
dbgGui.DisplayOrder   = 999
dbgGui.Parent         = PlayerGui

local dbgLabel = Instance.new("TextLabel")
dbgLabel.Size                   = UDim2.new(0, 580, 0, 96)
dbgLabel.Position               = UDim2.new(0.5, -290, 0, 130)
dbgLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
dbgLabel.BackgroundTransparency = 0.25
dbgLabel.TextColor3             = Color3.fromRGB(0, 255, 120)
dbgLabel.Font                   = Enum.Font.Code
dbgLabel.TextSize               = 20
dbgLabel.TextXAlignment         = Enum.TextXAlignment.Left
dbgLabel.TextYAlignment         = Enum.TextYAlignment.Top
dbgLabel.Text                   = "DEBUG: waiting for server data…"
dbgLabel.Parent                 = dbgGui

local profileUpdates = 0
local lastMsg = "(none)"
local function refreshDebug(p)
	dbgLabel.Text = string.format(
		"DEBUG  profile-updates=%d\ncoins=%s   stands=%s\nlast server msg: %s",
		profileUpdates,
		tostring(p and p.coins),
		tostring(p and p.stadium and p.stadium.stands),
		lastMsg
	)
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not Remotes then
	warn("[Client] Remotes not found after 30s — did the server start?")
	dbgLabel.Text = "DEBUG: Remotes NOT FOUND — server didn't start."
	return
end

local ClientState = {
	profile = nil,
	remotes = Remotes,
}

-- ─── Isolated require / init ───────────────────────────────────────────────────

local function safeRequire(name)
	local module = script.Parent:FindFirstChild(name)
	if not module then
		warn("[Client] missing module: " .. name)
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[Client] require(" .. name .. ") FAILED: " .. tostring(result))
		return nil
	end
	return result
end

local StadiumController  = safeRequire("StadiumController")
local UIController       = safeRequire("UIController")
local PackOpenController = safeRequire("PackOpenController")
local BracketController  = safeRequire("BracketController")
local KartController     = safeRequire("KartController")

local function safeInit(controller, name)
	if not controller or type(controller.init) ~= "function" then return end
	local ok, err = pcall(controller.init, ClientState)
	if not ok then
		warn("[Client] " .. name .. ".init FAILED: " .. tostring(err))
	end
end

safeInit(StadiumController,  "StadiumController")
safeInit(UIController,       "UIController")
safeInit(PackOpenController, "PackOpenController")
safeInit(BracketController,  "BracketController")
safeInit(KartController,     "KartController")

print("[StadiumTycoon] Client controllers initialised.")

-- ─── Server → client events (each guarded) ─────────────────────────────────────

local function onEvent(name, handler)
	local ev = Remotes:FindFirstChild(name)
	if not ev then
		warn("[Client] remote missing: " .. name)
		return
	end
	ev.OnClientEvent:Connect(function(...)
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[Client] handler " .. name .. " errored: " .. tostring(err))
		end
	end)
end

onEvent("ProfileUpdated", function(profileData)
	ClientState.profile = profileData
	profileUpdates += 1
	refreshDebug(profileData)
	print(string.format("[ClProfile] coins=%s stands=%s",
		tostring(profileData and profileData.coins),
		tostring(profileData and profileData.stadium and profileData.stadium.stands)))
	-- Isolate each controller so one failing can't block the other.
	pcall(function() if UIController then UIController.onProfileUpdated(profileData) end end)
	pcall(function() if StadiumController then StadiumController.onProfileUpdated(profileData) end end)
end)

onEvent("ShowNotification", function(payload)
	lastMsg = tostring(payload and payload.message)
	refreshDebug(ClientState.profile)
	if UIController then UIController.showToast(payload.message, payload.color) end
end)

onEvent("ShowOfflineEarnings", function(payload)
	if UIController then UIController.showOfflineEarnings(payload.coins) end
end)

onEvent("PackOpenResult", function(payload)
	if PackOpenController then PackOpenController.playReveal(payload.cards) end
end)

onEvent("MatchdayResolved", function(result)
	if BracketController then BracketController.onMatchResolved(result) end
	if UIController then UIController.showMatchResult(result) end
end)

onEvent("MatchdayCountdown", function(payload)
	if BracketController then BracketController.setNextMatchday(payload.timestamp, payload.matchdayId) end
end)

onEvent("TradeStateChanged", function(payload)
	if UIController then UIController.onTradeStateChanged(payload) end
end)

onEvent("TradeComplete", function(payload)
	if UIController then UIController.onTradeComplete(payload) end
end)

print("[StadiumTycoon] Client ready.")
