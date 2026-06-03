-- CollectionScreen.lua: card book — grid of owned cards with rarity filter.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CardCatalog"))
local CardVisuals = require(ReplicatedStorage:WaitForChild("CardVisuals"))
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)

local gui = Instance.new("ScreenGui")
gui.Name         = "CollectionScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 5
gui.Parent       = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundColor3 = Color3.fromRGB(8,8,16)
bg.BorderSizePixel  = 0
bg.Parent = gui

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,44,0,44)
closeBtn.Position = UDim2.new(1,-52,0,8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = bg
local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,8) cc.Parent = closeBtn
closeBtn.Activated:Connect(function() gui.Enabled = false end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,0,50)
title.Position = UDim2.new(0,12,0,8)
title.BackgroundTransparency = 1
title.Text = "📋  MY CARDS"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg

-- Completion %
local completionLabel = Instance.new("TextLabel")
completionLabel.Name = "CompletionLabel"
completionLabel.Size = UDim2.new(1,-16,0,28)
completionLabel.Position = UDim2.new(0,8,0,60)
completionLabel.BackgroundTransparency = 1
completionLabel.Text = "Collected: 0 / " .. #CardCatalog.Cards .. " unique cards"
completionLabel.TextColor3 = Color3.fromRGB(160,255,160)
completionLabel.TextScaled = true
completionLabel.Font = Enum.Font.Gotham
completionLabel.TextXAlignment = Enum.TextXAlignment.Left
completionLabel.Parent = bg

-- Rarity filter buttons
local filterFrame = Instance.new("Frame")
filterFrame.Size = UDim2.new(1,-16,0,38)
filterFrame.Position = UDim2.new(0,8,0,94)
filterFrame.BackgroundTransparency = 1
filterFrame.Parent = bg

local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.Padding = UDim.new(0,6)
filterLayout.Parent = filterFrame

local FILTERS = {"All","Common","Rare","Epic","Legendary","Mythic"}
local activeFilter = "All"
local filterButtons = {}

local RARITY_COLORS = {
	All       = Color3.fromRGB(200,200,200),
	Common    = Color3.fromRGB(180,180,180),
	Rare      = Color3.fromRGB(60,140,255),
	Epic      = Color3.fromRGB(160,50,255),
	Legendary = Color3.fromRGB(255,165,0),
	Mythic    = Color3.fromRGB(255,50,50),
}

for _, f in ipairs(FILTERS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 80, 1, 0)
	btn.BackgroundColor3 = f == "All" and Color3.fromRGB(50,50,80) or Color3.fromRGB(25,25,40)
	btn.BorderSizePixel = 0
	btn.Text = f
	btn.TextColor3 = RARITY_COLORS[f]
	btn.TextScaled = true
	btn.Font = Enum.Font.Gotham
	btn.Parent = filterFrame
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,8) c.Parent = btn
	filterButtons[f] = btn
end

-- Card grid
local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Size = UDim2.new(1,-16,1,-156)
gridScroll.Position = UDim2.new(0,8,0,142)
gridScroll.BackgroundTransparency = 1
gridScroll.ScrollBarThickness = 4
gridScroll.CanvasSize = UDim2.new(0,0,0,0)
gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
gridScroll.Parent = bg

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0,90,0,130)
gridLayout.CellPadding = UDim2.new(0,8,0,8)
gridLayout.Parent = gridScroll

local currentProfile = nil

local function buildCardTile(cardDef, instanceData)
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Color3.fromRGB(18,18,30)
	tile.BorderSizePixel  = 0

	local tileCorner = Instance.new("UICorner")
	tileCorner.CornerRadius = UDim.new(0,10)
	tileCorner.Parent = tile

	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_COLORS[cardDef.rarity] or Color3.new(1,1,1)
	stroke.Thickness = 2
	stroke.Parent = tile

	local artId = cardDef.art or "rbxassetid://0"
	local hasArt = artId ~= "rbxassetid://0" and artId ~= ""

	local art = Instance.new("ImageLabel")
	art.Size = UDim2.new(1,-4,0.55,0)
	art.Position = UDim2.new(0,2,0,2)
	art.BackgroundColor3 = (RARITY_COLORS[cardDef.rarity] or Color3.new(1,1,1)):Lerp(Color3.new(0,0,0), 0.55)
	art.BackgroundTransparency = hasArt and 1 or 0
	art.Image = hasArt and artId or ""
	art.ScaleType = Enum.ScaleType.Fit
	art.Parent = tile
	local artCorner = Instance.new("UICorner") artCorner.CornerRadius = UDim.new(0,6) artCorner.Parent = art

	if not hasArt then
		-- Shared procedural face (static glint — keep it cheap across many tiles).
		CardVisuals.buildFace(art, cardDef)
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1,0,0.28,0)
	nameLabel.Position = UDim2.new(0,0,0.57,0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = cardDef.name
	nameLabel.TextColor3 = Color3.new(1,1,1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextWrapped = true
	nameLabel.Parent = tile

	local powerLabel = Instance.new("TextLabel")
	powerLabel.Size = UDim2.new(1,0,0.18,0)
	powerLabel.Position = UDim2.new(0,0,0.82,0)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text = instanceData and ("⚡" .. instanceData.power) or "Not owned"
	powerLabel.TextColor3 = instanceData and Color3.fromRGB(255,220,50) or Color3.fromRGB(100,100,100)
	powerLabel.TextScaled = true
	powerLabel.Font = Enum.Font.GothamBold
	powerLabel.Parent = tile

	if not instanceData then
		local overlay = Instance.new("Frame")
		overlay.Size = UDim2.new(1,0,1,0)
		overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
		overlay.BackgroundTransparency = 0.55
		overlay.BorderSizePixel = 0
		overlay.Parent = tile
		local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(0,10) oc.Parent = overlay
	end

	return tile
end

local function refresh(filter)
	for _, child in ipairs(gridScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if not currentProfile then return end

	-- Build owned set by cardId
	local ownedByCardId = {}
	for _, cardInst in pairs(currentProfile.cards) do
		if not ownedByCardId[cardInst.cardId] or ownedByCardId[cardInst.cardId].power < cardInst.power then
			ownedByCardId[cardInst.cardId] = cardInst
		end
	end

	local uniqueOwned = 0
	for _, cardDef in ipairs(CardCatalog.Cards) do
		if filter ~= "All" and cardDef.rarity ~= filter then continue end
		local inst = ownedByCardId[cardDef.id]
		if inst then uniqueOwned += 1 end
		buildCardTile(cardDef, inst).Parent = gridScroll
	end

	completionLabel.Text = string.format(
		"Collected: %d / %d unique cards",
		uniqueOwned,
		#CardCatalog.Cards
	)
end

for _, f in ipairs(FILTERS) do
	filterButtons[f].Activated:Connect(function()
		activeFilter = f
		for _, btn in pairs(filterButtons) do
			btn.BackgroundColor3 = Color3.fromRGB(25,25,40)
		end
		filterButtons[f].BackgroundColor3 = Color3.fromRGB(50,50,80)
		refresh(f)
	end)
end

local module = {}
function module.onProfileUpdated(profile)
	currentProfile = profile
	if gui.Enabled then refresh(activeFilter) end
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled and currentProfile then refresh(activeFilter) end
end)

-- Receive profile data directly from the server.
if Remotes then
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
		module.onProfileUpdated(profile)
	end)
end
