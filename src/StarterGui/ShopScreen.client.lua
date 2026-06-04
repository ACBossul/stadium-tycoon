-- ShopScreen.lua: pack shop and gem store UI (LocalScript in StarterGui).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local PackConfig  = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PackConfig"))
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)
local EventConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EventConfig"))

local gui = Instance.new("ScreenGui")
gui.Name         = "ShopScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 5
gui.Parent       = PlayerGui

-- ─── Background ──────────────────────────────────────────────────────────────

local bg = Instance.new("Frame")
bg.Size                 = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3     = Color3.fromRGB(8, 8, 16)
bg.BackgroundTransparency = 0.05
bg.BorderSizePixel      = 0
bg.Parent               = gui

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 44, 0, 44)
closeBtn.Position         = UDim2.new(1, -52, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.new(1,1,1)
closeBtn.TextScaled       = true
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.Parent           = bg

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

closeBtn.Activated:Connect(function()
	gui.Enabled = false
end)

-- Title
local title = Instance.new("TextLabel")
title.Size             = UDim2.new(1, -60, 0, 50)
title.Position         = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text             = "🛍  SHOP"
title.TextColor3       = Color3.fromRGB(255,215,0)
title.TextScaled       = true
title.Font             = Enum.Font.GothamBold
title.TextXAlignment   = Enum.TextXAlignment.Left
title.Parent           = bg

-- ─── Pack list ────────────────────────────────────────────────────────────────

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size              = UDim2.new(1, -16, 1, -120)
scrollFrame.Position          = UDim2.new(0, 8, 0, 70)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent            = bg

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent  = scrollFrame

local function makePackCard(pack)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, -8, 0, 110)
	card.BackgroundColor3 = Color3.fromRGB(20,20,35)
	card.BorderSizePixel  = 0
	card.Parent           = scrollFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	-- Pack name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(0.6, 0, 0, 36)
	nameLabel.Position         = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = pack.name
	nameLabel.TextColor3       = Color3.fromRGB(255,255,255)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
	nameLabel.Parent           = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size             = UDim2.new(0.65, 0, 0, 28)
	descLabel.Position         = UDim2.new(0, 12, 0, 44)
	descLabel.BackgroundTransparency = 1
	descLabel.Text             = pack.description
	descLabel.TextColor3       = Color3.fromRGB(180,180,200)
	descLabel.TextScaled       = true
	descLabel.Font             = Enum.Font.Gotham
	descLabel.TextXAlignment   = Enum.TextXAlignment.Left
	descLabel.TextWrapped      = true
	descLabel.Parent           = card

	-- Buy button
	local costText
	if pack.costType == "coins" then
		costText = "💰 " .. tostring(pack.cost)
	else
		costText = "💎 " .. tostring(pack.gemCost)
	end

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size             = UDim2.new(0, 120, 0, 50)
	buyBtn.Position         = UDim2.new(1, -132, 0.5, -25)
	buyBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
	buyBtn.Text             = costText
	buyBtn.TextColor3       = Color3.new(1,1,1)
	buyBtn.TextScaled       = true
	buyBtn.Font             = Enum.Font.GothamBold
	buyBtn.Parent           = card

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buyBtn

	buyBtn.Activated:Connect(function()
		if Remotes then
			Remotes:FindFirstChild("OpenPack"):FireServer(pack.id)
		end
	end)
end

for _, pack in ipairs(PackConfig.Packs) do
	makePackCard(pack)
end

-- ─── Limited-time event packs (pinned to top, live countdown) ────────────────

local activeEventCards = {}   -- { card, countdownLabel, event }

local function buildEventCard(event)
	local pack = PackConfig.ById[event.packId]
	if not pack then return end

	local card = Instance.new("Frame")
	card.Name             = "EventCard"
	card.Size             = UDim2.new(1, -8, 0, 122)
	card.BackgroundColor3 = Color3.fromRGB(40, 24, 48)
	card.BorderSizePixel  = 0
	card.LayoutOrder      = -100      -- sort above the always-available packs
	card.Parent           = scrollFrame
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 12) cc.Parent = card
	local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 90, 160) stroke.Thickness = 2 stroke.Parent = card

	local badge = Instance.new("TextLabel")
	badge.Size             = UDim2.new(0, 140, 0, 22)
	badge.Position         = UDim2.new(0, 12, 0, 8)
	badge.BackgroundColor3 = Color3.fromRGB(255, 70, 140)
	badge.Text             = "⏳ " .. event.badge
	badge.TextColor3       = Color3.new(1, 1, 1)
	badge.TextScaled       = true
	badge.Font             = Enum.Font.GothamBlack
	badge.Parent           = card
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = badge

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(0.6, 0, 0, 30)
	nameLabel.Position         = UDim2.new(0, 12, 0, 34)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = event.name
	nameLabel.TextColor3       = Color3.fromRGB(255, 235, 180)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
	nameLabel.Parent           = card

	local desc = Instance.new("TextLabel")
	desc.Size             = UDim2.new(0.6, 0, 0, 28)
	desc.Position         = UDim2.new(0, 12, 0, 64)
	desc.BackgroundTransparency = 1
	desc.Text             = pack.description
	desc.TextColor3       = Color3.fromRGB(200, 190, 205)
	desc.TextScaled       = true
	desc.Font             = Enum.Font.Gotham
	desc.TextWrapped      = true
	desc.TextXAlignment   = Enum.TextXAlignment.Left
	desc.Parent           = card

	local countdown = Instance.new("TextLabel")
	countdown.Name             = "Countdown"
	countdown.Size             = UDim2.new(0.6, 0, 0, 20)
	countdown.Position         = UDim2.new(0, 12, 0, 94)
	countdown.BackgroundTransparency = 1
	countdown.Text             = "ends in …"
	countdown.TextColor3       = Color3.fromRGB(255, 120, 160)
	countdown.TextScaled       = true
	countdown.Font             = Enum.Font.GothamBold
	countdown.TextXAlignment   = Enum.TextXAlignment.Left
	countdown.Parent           = card

	local price  = (pack.costType == "gems") and ("💎" .. pack.gemCost) or ("💰" .. pack.cost)
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size             = UDim2.new(0, 120, 0, 58)
	buyBtn.Position         = UDim2.new(1, -132, 0.5, -29)
	buyBtn.BackgroundColor3 = Color3.fromRGB(230, 70, 150)
	buyBtn.Text             = "Open\n" .. price
	buyBtn.TextColor3       = Color3.new(1, 1, 1)
	buyBtn.TextScaled       = true
	buyBtn.Font             = Enum.Font.GothamBold
	buyBtn.Parent           = card
	local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(0, 10) bbc.Parent = buyBtn

	local pid = pack.id
	buyBtn.Activated:Connect(function()
		if Remotes then Remotes:FindFirstChild("OpenPack"):FireServer(pid) end
	end)

	table.insert(activeEventCards, { card = card, countdownLabel = countdown, event = event })
end

local function refreshEvents()
	for _, c in ipairs(scrollFrame:GetChildren()) do
		if c:IsA("Frame") and c.Name == "EventCard" then c:Destroy() end
	end
	activeEventCards = {}
	for _, ev in ipairs(EventConfig.activeEvents(os.time())) do
		buildEventCard(ev)
	end
end

local function fmtCountdown(sec)
	if sec <= 0 then return "ending…" end
	local d = math.floor(sec / 86400)
	local h = math.floor((sec % 86400) / 3600)
	local m = math.floor((sec % 3600) / 60)
	if d > 0 then return string.format("ends in %dd %dh", d, h) end
	if h > 0 then return string.format("ends in %dh %dm", h, m) end
	return string.format("ends in %dm", math.max(m, 1))
end

refreshEvents()

-- Live countdown; rebuild when the active set changes (event starts/ends).
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		if not gui.Enabled then continue end
		local now = os.time()
		if #activeEventCards ~= #EventConfig.activeEvents(now) then
			refreshEvents()
		end
		for _, entry in ipairs(activeEventCards) do
			if entry.card.Parent then
				entry.countdownLabel.Text = fmtCountdown(entry.event.endsAt - now)
			end
		end
	end
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then refreshEvents() end
end)

-- ─── Game Passes (one-time Robux, in the same scroll list) ───────────────────

local passHeader = Instance.new("TextLabel")
passHeader.Size                 = UDim2.new(1, -8, 0, 32)
passHeader.BackgroundTransparency = 1
passHeader.Text                 = "⭐  Game Passes"
passHeader.TextColor3           = Color3.fromRGB(255,200,90)
passHeader.TextScaled           = true
passHeader.Font                 = Enum.Font.GothamBold
passHeader.TextXAlignment       = Enum.TextXAlignment.Left
passHeader.LayoutOrder          = 100
passHeader.Parent               = scrollFrame

local PASS_BLURBS = {
	double_coins   = "Permanently double all Coin income.",
	double_offline = "Double what you earn while away.",
	vip            = "Exclusive theme, daily Gems & chat tag.",
}

for i, gp in ipairs(MonetizationConfig.GamePasses) do
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, -8, 0, 90)
	card.BackgroundColor3 = Color3.fromRGB(30,26,16)
	card.BorderSizePixel  = 0
	card.LayoutOrder      = 100 + i
	card.Parent           = scrollFrame
	local cardCorner = Instance.new("UICorner") cardCorner.CornerRadius = UDim.new(0,12) cardCorner.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(0.6, 0, 0, 32)
	nameLabel.Position         = UDim2.new(0, 12, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = "⭐ " .. gp.name
	nameLabel.TextColor3       = Color3.fromRGB(255,235,180)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
	nameLabel.Parent           = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Size             = UDim2.new(0.62, 0, 0, 30)
	descLabel.Position         = UDim2.new(0, 12, 0, 42)
	descLabel.BackgroundTransparency = 1
	descLabel.Text             = PASS_BLURBS[gp.id] or ""
	descLabel.TextColor3       = Color3.fromRGB(190,180,160)
	descLabel.TextScaled       = true
	descLabel.Font             = Enum.Font.Gotham
	descLabel.TextXAlignment   = Enum.TextXAlignment.Left
	descLabel.TextWrapped      = true
	descLabel.Parent           = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size             = UDim2.new(0, 120, 0, 50)
	buyBtn.Position         = UDim2.new(1, -132, 0.5, -25)
	buyBtn.BackgroundColor3 = Color3.fromRGB(200,150,40)
	buyBtn.Text             = "Buy (Robux)"
	buyBtn.TextColor3       = Color3.new(1,1,1)
	buyBtn.TextScaled       = true
	buyBtn.Font             = Enum.Font.GothamBold
	buyBtn.Parent           = card
	local buyCorner = Instance.new("UICorner") buyCorner.CornerRadius = UDim.new(0,10) buyCorner.Parent = buyBtn

	local passId = gp.gamePassId
	buyBtn.Activated:Connect(function()
		MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
	end)
end

-- ─── Gem bundles (Robux) ─────────────────────────────────────────────────────

local gemTitle = Instance.new("TextLabel")
gemTitle.Size             = UDim2.new(1, -16, 0, 36)
gemTitle.Position         = UDim2.new(0, 8, 1, -116)
gemTitle.BackgroundTransparency = 1
gemTitle.Text             = "💎  Gem Bundles"
gemTitle.TextColor3       = Color3.fromRGB(100,200,255)
gemTitle.TextScaled       = true
gemTitle.Font             = Enum.Font.GothamBold
gemTitle.TextXAlignment   = Enum.TextXAlignment.Left
gemTitle.Parent           = bg

local gemLayout = Instance.new("Frame")
gemLayout.Size             = UDim2.new(1, -16, 0, 60)
gemLayout.Position         = UDim2.new(0, 8, 1, -76)
gemLayout.BackgroundTransparency = 1
gemLayout.Parent           = bg

local gemListLayout = Instance.new("UIListLayout")
gemListLayout.FillDirection = Enum.FillDirection.Horizontal
gemListLayout.Padding = UDim.new(0, 8)
gemListLayout.Parent  = gemLayout

for _, prod in ipairs(MonetizationConfig.DevProducts) do
	if prod.gemsGranted then
		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(0, 100, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(20,60,120)
		btn.Text             = "💎" .. tostring(prod.gemsGranted) .. "\n(Robux)"
		btn.TextColor3       = Color3.new(1,1,1)
		btn.TextScaled       = true
		btn.Font             = Enum.Font.Gotham
		btn.Parent           = gemLayout

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = btn

		btn.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(LocalPlayer, prod.productId)
		end)
	end
end
