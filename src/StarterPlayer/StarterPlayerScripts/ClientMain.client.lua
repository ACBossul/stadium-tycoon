-- ClientMain.client.lua: bootstraps all client controllers.
--
-- Hardened boot: a failure (or missing module) in ANY one controller can no longer
-- halt the whole client. Previously a single erroring/yielding require here meant
-- NOTHING downstream ran — no nav buttons, no upgrade wiring, no ProfileUpdated
-- sync (income stuck at 0). Now every require/init/handler is isolated, and we
-- print progress so the Output window shows exactly how far boot got.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[StadiumTycoon] Client booting…")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not Remotes then
	warn("[Client] Remotes not found after 30s — did the server start?")
	return
end

local ClientState = {
	profile = nil,
	remotes = Remotes,
}

-- Temporary diagnostic (small, top-right) so we can see the server's reply to each
-- upgrade/purchase while chasing the regression. Removed once confirmed behaving.
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local _dbgGui = Instance.new("ScreenGui")
_dbgGui.Name = "DebugOverlay"
_dbgGui.ResetOnSpawn = false
_dbgGui.IgnoreGuiInset = true
_dbgGui.DisplayOrder = 999
_dbgGui.Parent = PlayerGui
local _dbg = Instance.new("TextLabel")
_dbg.Size = UDim2.new(0, 360, 0, 58)
_dbg.Position = UDim2.new(1, -372, 0, 86)
_dbg.BackgroundColor3 = Color3.new(0, 0, 0)
_dbg.BackgroundTransparency = 0.35
_dbg.TextColor3 = Color3.fromRGB(0, 255, 120)
_dbg.Font = Enum.Font.Code
_dbg.TextSize = 15
_dbg.TextXAlignment = Enum.TextXAlignment.Left
_dbg.TextYAlignment = Enum.TextYAlignment.Top
_dbg.Text = "DEBUG: waiting for data…"
_dbg.Parent = _dbgGui
local _lastMsg = "(none)"
local function _dbgRefresh(p)
	_dbg.Text = string.format("coins=%s  gems=%s\nstands=%s\nlast: %s",
		tostring(p and p.coins), tostring(p and p.gems),
		tostring(p and p.stadium and p.stadium.stands), _lastMsg)
end

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
local HubController      = safeRequire("HubController")

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
safeInit(HubController,      "HubController")

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
	_dbgRefresh(profileData)
	-- Isolate each controller so one failing can't block the other.
	pcall(function() if UIController then UIController.onProfileUpdated(profileData) end end)
	pcall(function() if StadiumController then StadiumController.onProfileUpdated(profileData) end end)
end)

onEvent("ShowNotification", function(payload)
	_lastMsg = tostring(payload and payload.message)
	_dbgRefresh(ClientState.profile)
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

-- Now that every handler is connected, ask the server for our current state a few
-- times (covers the race where the join-time push landed before we were listening).
task.spawn(function()
	local req = Remotes:FindFirstChild("RequestState")
	if not req then return end
	for _ = 1, 3 do
		req:FireServer()
		task.wait(1.5)
	end
end)
