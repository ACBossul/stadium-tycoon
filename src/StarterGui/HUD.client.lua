-- HUD.client.lua: top balance bar + bottom nav.
--
-- SELF-CONTAINED on purpose: it updates its OWN coin/gem/income labels straight
-- from the ProfileUpdated remote (no cross-script name lookups, which were silently
-- failing), and wires its OWN nav buttons to toggle the panel ScreenGuis. This is
-- the same pattern the working daily-reward screen uses.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- This LocalScript is ITSELF named "HUD" (rojo names the instance after the file),
-- so a plain FindFirstChild("HUD") matches the SCRIPT and bailed before building
-- anything — that's why the HUD never appeared. Guard only against a real HUD
-- ScreenGui (so respawns still don't stack duplicates).
local function hudScreenExists()
	for _, c in ipairs(PlayerGui:GetChildren()) do
		if c:IsA("ScreenGui") and c.Name == "HUD" then return true end
	end
	return false
end
if hudScreenExists() then return end

local gui = Instance.new("ScreenGui")
gui.Name           = "HUD"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = false  -- sit below Roblox's top menu strip so the balance shows
gui.DisplayOrder   = 1
gui.Parent         = PlayerGui

-- Pretty-print big numbers with thousands separators (1,000,000).
local function commas(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ─── Top balance bar ──────────────────────────────────────────────────────────

local topBar = Instance.new("Frame")
topBar.Name              = "Main"
topBar.Size              = UDim2.new(1, 0, 0, 60)
topBar.Position          = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3  = Color3.fromRGB(10, 10, 18)
topBar.BackgroundTransparency = 0.1
topBar.BorderSizePixel   = 0
topBar.Parent            = gui

local topLayout = Instance.new("UIListLayout")
topLayout.FillDirection = Enum.FillDirection.Horizontal
topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
topLayout.Padding = UDim.new(0, 8)
topLayout.Parent = topBar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.Parent = topBar

local function makeStatLabel(name, icon, color)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.new(0, 180, 0, 42)
	frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
	frame.BorderSizePixel  = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name              = name .. "Label"
	label.Size              = UDim2.new(1, -10, 1, 0)
	label.Position          = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Text              = icon .. " 0"
	label.TextColor3        = color
	label.TextScaled        = true
	label.Font              = Enum.Font.GothamBold
	label.TextXAlignment    = Enum.TextXAlignment.Left
	label.Parent            = frame
	return frame, label
end

local coinsFrame, coinsLabel = makeStatLabel("Coins", "💰", Color3.fromRGB(255,215,0))
local gemsFrame,  gemsLabel  = makeStatLabel("Gems",  "💎", Color3.fromRGB(100,200,255))
coinsFrame.Parent = topBar
gemsFrame.Parent  = topBar

local incomeLabel = Instance.new("TextLabel")
incomeLabel.Name              = "IncomeLabel"
incomeLabel.Size              = UDim2.new(0, 260, 0, 24)
incomeLabel.Position          = UDim2.new(0, 12, 0, 62)
incomeLabel.BackgroundTransparency = 1
incomeLabel.Text              = "Income: 0/sec"
incomeLabel.TextColor3        = Color3.fromRGB(160,255,130)
incomeLabel.TextScaled        = true
incomeLabel.Font              = Enum.Font.GothamBold
incomeLabel.TextXAlignment    = Enum.TextXAlignment.Left
incomeLabel.Parent            = gui

-- ─── Bottom nav bar ─────────────────────────────────────────────────────────

local navBar = Instance.new("Frame")
navBar.Name             = "Nav"
navBar.Size             = UDim2.new(1, 0, 0, 70)
navBar.Position         = UDim2.new(0, 0, 1, -70)
navBar.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
navBar.BorderSizePixel  = 0
navBar.Parent           = gui

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection  = Enum.FillDirection.Horizontal
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 0)
navLayout.Parent = navBar

-- Which panel each button opens (StadiumBtn just closes everything → 3D view).
local PANELS = {
	"ShopScreen", "CollectionScreen", "SquadBuilderScreen", "BracketScreen",
	"TradeScreen", "BattlePassScreen", "PackOpenScreen", "DailyRewardScreen",
}
local BTN_TO_PANEL = {
	ShopBtn       = "ShopScreen",
	CollectionBtn = "CollectionScreen",
	SquadBtn      = "SquadBuilderScreen",
	BracketBtn    = "BracketScreen",
	TradeBtn      = "TradeScreen",
	PassBtn       = "BattlePassScreen",
	StadiumBtn    = false,  -- close all
}

-- Each panel's LocalScript shares its name with the ScreenGui it creates, so match
-- the ScreenGui specifically — a plain FindFirstChild can return the script instead,
-- which is why opening menus did nothing.
local function findScreenGui(name)
	for _, c in ipairs(PlayerGui:GetChildren()) do
		if c:IsA("ScreenGui") and c.Name == name then return c end
	end
	return nil
end

local function showPanel(target)
	for _, name in ipairs(PANELS) do
		local s = findScreenGui(name)
		if s then s.Enabled = (name == target) end
	end
end

local NAV_BUTTONS = {
	{ name="StadiumBtn",    icon="🏟",  label="Stadium" },
	{ name="ShopBtn",       icon="🛍",  label="Shop"    },
	{ name="CollectionBtn", icon="📋",  label="Cards"   },
	{ name="SquadBtn",      icon="⚽",  label="Squad"   },
	{ name="BracketBtn",    icon="🏆",  label="Cup"     },
	{ name="TradeBtn",      icon="🔄",  label="Trade"   },
	{ name="PassBtn",       icon="🎖",  label="Pass"    },
}

for _, btnDef in ipairs(NAV_BUTTONS) do
	local btn = Instance.new("TextButton")
	btn.Name              = btnDef.name
	btn.Size              = UDim2.new(1/#NAV_BUTTONS, 0, 1, 0)
	btn.BackgroundColor3  = Color3.fromRGB(18, 18, 30)
	btn.BorderSizePixel   = 0
	btn.Text              = btnDef.icon .. "\n" .. btnDef.label
	btn.TextColor3        = Color3.fromRGB(220,220,220)
	btn.TextScaled        = true
	btn.Font              = Enum.Font.Gotham
	btn.AutoButtonColor   = false
	btn.Parent            = navBar

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(35,35,60) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(18,18,30) }):Play()
	end)

	-- Wire the nav directly here so it can't depend on another script finding us.
	btn.Activated:Connect(function()
		showPanel(BTN_TO_PANEL[btnDef.name])
	end)
end

-- ─── Live balance / income, straight from the server profile ────────────────

-- BuildingConfig is only needed for the income number; load it AFTER the HUD is
-- built (and safely) so a slow/failed require can never stop the HUD rendering.
local BuildingConfig
do
	local cfg = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 20)
	local mod = cfg and (cfg:FindFirstChild("BuildingConfig") or cfg:WaitForChild("BuildingConfig", 20))
	if mod then
		local ok, result = pcall(require, mod)
		if ok then BuildingConfig = result end
	end
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if Remotes then
	local profileEvent = Remotes:FindFirstChild("ProfileUpdated")
	if profileEvent then
		profileEvent.OnClientEvent:Connect(function(data)
			if type(data) ~= "table" then return end
			coinsLabel.Text = "💰 " .. commas(data.coins or 0)
			gemsLabel.Text  = "💎 " .. commas(data.gems or 0)
			if data.stadium and BuildingConfig then
				local rate = BuildingConfig.totalPassiveRate(data.stadium)
				if data.passes and data.passes.double_coins then rate = rate * 2 end
				rate = rate * (1 + (data.rebirths or 0) * 0.5)   -- permanent rebirth bonus
				if data.passes and data.passes.vip then rate = rate * 1.25 end  -- VIP +25%
				if data.buffs and (data.buffs.money or 0) > os.time() then rate = rate * 1.10 end  -- 🌭 money snack
				local pend = math.floor(data.pending or 0)
				if pend > 0 then
					incomeLabel.Text = "Income: " .. commas(math.floor(rate)) .. "/sec   💰" .. commas(pend) .. " to collect"
				else
					incomeLabel.Text = "Income: " .. commas(math.floor(rate)) .. "/sec"
				end
			end
		end)
	end
end
