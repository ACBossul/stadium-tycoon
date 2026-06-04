-- DailyRewardScreen.client.lua: daily login reward popup with a 7-day streak track.
-- Renders the track from the shared DailyRewardConfig, claims via ClaimDailyReward,
-- and auto-opens on join when a reward is claimable.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local DailyRewardConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DailyRewardConfig"))

-- ─── State ────────────────────────────────────────────────────────────────────

local claimable        = false
local nextStreak       = 1
local nextClaimAt      = 0      -- os.time() when the next claim unlocks (if not claimable)
local shownThisSession = false

-- ─── GUI ──────────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "DailyRewardScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 15
gui.Parent       = PlayerGui

-- Dim backdrop
local dim = Instance.new("TextButton")  -- button so tapping outside closes
dim.Size = UDim2.new(1,0,1,0)
dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
dim.BackgroundTransparency = 0.4
dim.Text = ""
dim.AutoButtonColor = false
dim.Parent = gui

-- Centered panel
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.92, 0, 0, 320)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 28)
panel.BorderSizePixel = 0
panel.Parent = gui
local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,16) pc.Parent = panel
local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(255,200,80) ps.Thickness = 2 ps.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-16,0,44)
title.Position = UDim2.new(0,8,0,8)
title.BackgroundTransparency = 1
title.Text = "🎁  DAILY REWARD"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

local streakLabel = Instance.new("TextLabel")
streakLabel.Size = UDim2.new(1,-16,0,26)
streakLabel.Position = UDim2.new(0,8,0,52)
streakLabel.BackgroundTransparency = 1
streakLabel.Text = "Come back daily to keep your streak!"
streakLabel.TextColor3 = Color3.fromRGB(200,200,220)
streakLabel.TextScaled = true
streakLabel.Font = Enum.Font.Gotham
streakLabel.Parent = panel

-- Day-tile track
local trackFrame = Instance.new("Frame")
trackFrame.Size = UDim2.new(1,-16,0,120)
trackFrame.Position = UDim2.new(0,8,0,86)
trackFrame.BackgroundTransparency = 1
trackFrame.Parent = panel

local trackGrid = Instance.new("UIGridLayout")
trackGrid.CellSize = UDim2.new(0, 80, 0, 110)
trackGrid.CellPadding = UDim2.new(0, 6, 0, 6)
trackGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
trackGrid.VerticalAlignment = Enum.VerticalAlignment.Center
trackGrid.Parent = trackFrame

local dayTiles = {}  -- day -> { frame, highlightStroke }

for _, entry in ipairs(DailyRewardConfig.Rewards) do
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Color3.fromRGB(26,26,44)
	tile.BorderSizePixel = 0
	tile.LayoutOrder = entry.day
	tile.Parent = trackFrame
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0,10) tc.Parent = tile
	local hs = Instance.new("UIStroke") hs.Color = Color3.fromRGB(255,210,70) hs.Thickness = 0 hs.Parent = tile

	local dayLabel = Instance.new("TextLabel")
	dayLabel.Size = UDim2.new(1,0,0,22)
	dayLabel.Position = UDim2.new(0,0,0,4)
	dayLabel.BackgroundTransparency = 1
	dayLabel.Text = "Day " .. entry.day
	dayLabel.TextColor3 = Color3.fromRGB(220,220,235)
	dayLabel.TextScaled = true
	dayLabel.Font = Enum.Font.GothamBold
	dayLabel.Parent = tile

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.new(1,-4,0,40)
	coinLabel.Position = UDim2.new(0,2,0,34)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "💰" .. entry.coins
	coinLabel.TextColor3 = Color3.fromRGB(255,215,0)
	coinLabel.TextScaled = true
	coinLabel.Font = Enum.Font.Gotham
	coinLabel.TextWrapped = true
	coinLabel.Parent = tile

	if entry.gems and entry.gems > 0 then
		local gemLabel = Instance.new("TextLabel")
		gemLabel.Size = UDim2.new(1,-4,0,24)
		gemLabel.Position = UDim2.new(0,2,0,74)
		gemLabel.BackgroundTransparency = 1
		gemLabel.Text = "💎" .. entry.gems
		gemLabel.TextColor3 = Color3.fromRGB(120,200,255)
		gemLabel.TextScaled = true
		gemLabel.Font = Enum.Font.Gotham
		gemLabel.Parent = tile
	end

	dayTiles[entry.day] = { frame = tile, stroke = hs }
end

-- Claim button
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0.7, 0, 0, 54)
claimBtn.AnchorPoint = Vector2.new(0.5, 0)
claimBtn.Position = UDim2.new(0.5, 0, 1, -64)
claimBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
claimBtn.Text = "Claim"
claimBtn.TextColor3 = Color3.new(1,1,1)
claimBtn.TextScaled = true
claimBtn.Font = Enum.Font.GothamBold
claimBtn.Parent = panel
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0,12) cbc.Parent = claimBtn

-- ─── Rendering ────────────────────────────────────────────────────────────────

local function dayInCycle(streak)
	return ((streak - 1) % DailyRewardConfig.CYCLE_LENGTH) + 1
end

local function formatCountdown(seconds)
	if seconds <= 0 then return "now" end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then return string.format("%dh %dm", h, m) end
	if m > 0 then return string.format("%dm %ds", m, s) end
	return string.format("%ds", s)
end

local function render()
	local cycleDay = dayInCycle(nextStreak)

	for day, tile in pairs(dayTiles) do
		if day == cycleDay then
			tile.stroke.Thickness = 3                       -- the next reward
			tile.frame.BackgroundColor3 = Color3.fromRGB(40,40,66)
		elseif day < cycleDay then
			tile.stroke.Thickness = 0                       -- already collected this cycle
			tile.frame.BackgroundColor3 = Color3.fromRGB(20,34,22)
		else
			tile.stroke.Thickness = 0
			tile.frame.BackgroundColor3 = Color3.fromRGB(26,26,44)
		end
	end

	streakLabel.Text = "Current streak: " .. (nextStreak - 1) .. " day(s)  •  Next: Day " .. cycleDay

	if claimable then
		claimBtn.Text = "Claim Day " .. cycleDay .. "!"
		claimBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
		claimBtn.Active = true
		claimBtn.AutoButtonColor = true
	else
		claimBtn.BackgroundColor3 = Color3.fromRGB(90,90,110)
		claimBtn.Active = false
		claimBtn.AutoButtonColor = false
	end
end

-- Live countdown on the claim button when locked.
RunService.Heartbeat:Connect(function()
	if not gui.Enabled or claimable then return end
	local remaining = math.max(0, nextClaimAt - os.time())
	claimBtn.Text = "Next in " .. formatCountdown(remaining)
	if remaining <= 0 then
		-- Becomes claimable; the server will confirm on next state push, but
		-- flip locally so the button is usable immediately.
		claimable = true
		render()
	end
end)

-- ─── Interactions ─────────────────────────────────────────────────────────────

claimBtn.Activated:Connect(function()
	if not claimable then return end
	Remotes.ClaimDailyReward:FireServer()
	-- Optimistically lock until the server replies with fresh state.
	claimable = false
	render()
end)

dim.Activated:Connect(function()
	gui.Enabled = false
end)

-- ─── Server state ─────────────────────────────────────────────────────────────

Remotes.DailyRewardState.OnClientEvent:Connect(function(state)
	if not state then return end
	claimable  = state.claimable or false
	nextStreak = state.nextStreak or 1
	nextClaimAt = os.time() + (state.secondsUntilNext or 0)
	render()

	-- Auto-open once per session if there's a reward waiting.
	if claimable and not shownThisSession then
		shownThisSession = true
		gui.Enabled = true
	end
end)
