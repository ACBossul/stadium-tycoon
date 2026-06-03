-- HUD.lua: creates the main HUD ScreenGui programmatically.
-- Place this as a LocalScript inside StarterGui, or use a Script with RunContext=Client.
-- Output: a ScreenGui named "HUD" in PlayerGui.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name         = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1
gui.Parent       = PlayerGui

-- ─── Top bar ────────────────────────────────────────────────────────────────

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
	frame.Size = UDim2.new(0, 140, 0, 40)
	frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
	frame.BorderSizePixel  = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name              = name .. "Label"
	label.Size              = UDim2.new(1, -8, 1, 0)
	label.Position          = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text              = icon .. " 0"
	label.TextColor3        = color
	label.TextScaled        = true
	label.Font              = Enum.Font.GothamBold
	label.TextXAlignment    = Enum.TextXAlignment.Left
	label.Parent            = frame

	return frame, label
end

-- Labels (named "CoinsLabel"/"GemsLabel") are created and parented inside their
-- frames by makeStatLabel; UIController updates them by name, so we only keep the frames.
local coinsFrame = makeStatLabel("Coins", "🪙", Color3.fromRGB(255,215,0))
local gemsFrame  = makeStatLabel("Gems",  "💎", Color3.fromRGB(100,200,255))
coinsFrame.Parent = topBar
gemsFrame.Parent  = topBar

-- ─── Bottom nav bar ───────────────────────────────────────────────────────────

local navBar = Instance.new("Frame")
navBar.Name             = "Nav"
navBar.Size             = UDim2.new(1, 0, 0, 70)
navBar.Position         = UDim2.new(0, 0, 1, -70)
navBar.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
navBar.BorderSizePixel  = 0
navBar.Parent           = gui

local navCorner = Instance.new("UICorner")
navCorner.CornerRadius = UDim.new(0, 0)
navCorner.Parent = navBar

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection  = Enum.FillDirection.Horizontal
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Padding = UDim.new(0, 0)
navLayout.Parent = navBar

local NAV_BUTTONS = {
	{ name="StadiumBtn",    icon="🏟",  label="Stadium"    },
	{ name="ShopBtn",       icon="🛍",  label="Shop"       },
	{ name="CollectionBtn", icon="📋",  label="Cards"      },
	{ name="SquadBtn",      icon="⚽",  label="Squad"      },
	{ name="BracketBtn",    icon="🏆",  label="Cup"        },
	{ name="TradeBtn",      icon="🔄",  label="Trade"      },
	{ name="PassBtn",       icon="🎖",  label="Pass"       },
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
end

-- ─── Income/sec ticker (cosmetic, reads from profile cache) ──────────────────

local incomeLabel = Instance.new("TextLabel")
incomeLabel.Name              = "IncomeLabel"
incomeLabel.Size              = UDim2.new(0, 200, 0, 24)
incomeLabel.Position          = UDim2.new(0, 12, 0, 62)
incomeLabel.BackgroundTransparency = 1
incomeLabel.Text              = "Income: 0/sec"
incomeLabel.TextColor3        = Color3.fromRGB(160,255,130)
incomeLabel.TextScaled        = true
incomeLabel.Font              = Enum.Font.Gotham
incomeLabel.TextXAlignment    = Enum.TextXAlignment.Left
incomeLabel.Parent            = gui
