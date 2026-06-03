-- SquadBuilderScreen.lua: drag-and-drop squad lineup UI.
-- Shows owned cards in a scrollable list; tap a slot to assign a card.
-- Sends EquipSquad to the server when the player taps "Save Lineup".

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CardCatalog"))

local gui = Instance.new("ScreenGui")
gui.Name         = "SquadBuilderScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 5
gui.Parent       = PlayerGui

-- ─── State ────────────────────────────────────────────────────────────────────

local selectedSlot = nil   -- index of lineup slot being filled
local lineup = {}          -- array of instanceId or nil (up to 11)
for i = 1, 11 do lineup[i] = nil end

local currentProfile = nil

-- ─── Layout ───────────────────────────────────────────────────────────────────

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
title.Text = "⚽  SQUAD BUILDER"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg

local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "PowerLabel"
powerLabel.Size = UDim2.new(1,-16,0,30)
powerLabel.Position = UDim2.new(0,8,0,58)
powerLabel.BackgroundTransparency = 1
powerLabel.Text = "⚡ Squad Power: 0"
powerLabel.TextColor3 = Color3.fromRGB(255,220,50)
powerLabel.TextScaled = true
powerLabel.Font = Enum.Font.GothamBold
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.Parent = bg

-- ─── 11 lineup slots ──────────────────────────────────────────────────────────

local slotsFrame = Instance.new("Frame")
slotsFrame.Size = UDim2.new(1,-16,0,200)
slotsFrame.Position = UDim2.new(0,8,0,95)
slotsFrame.BackgroundTransparency = 1
slotsFrame.Parent = bg

local slotButtons = {}
local SLOT_LABELS = {"GK","DEF","DEF","DEF","DEF","MID","MID","MID","MID","FWD","FWD"}

for i = 1, 11 do
	local col = (i-1) % 4
	local row = math.floor((i-1) / 4)

	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0.22, 0, 0, 44)
	slot.Position = UDim2.new(col * 0.245, 4, row * 0.36, 0)
	slot.BackgroundColor3 = Color3.fromRGB(30,30,50)
	slot.BorderSizePixel = 0
	slot.Text = SLOT_LABELS[i] .. "\n(empty)"
	slot.TextColor3 = Color3.fromRGB(150,150,180)
	slot.TextScaled = true
	slot.Font = Enum.Font.Gotham
	slot.Parent = slotsFrame

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0,8)
	slotCorner.Parent = slot

	slotButtons[i] = slot

	slot.Activated:Connect(function()
		selectedSlot = i
		-- Highlight selected slot
		for j, s in ipairs(slotButtons) do
			s.BackgroundColor3 = j == i
				and Color3.fromRGB(60,120,60)
				or Color3.fromRGB(30,30,50)
		end
	end)
end

-- ─── Card picker scroll list ──────────────────────────────────────────────────

local cardScroll = Instance.new("ScrollingFrame")
cardScroll.Size = UDim2.new(1,-16,1,-360)
cardScroll.Position = UDim2.new(0,8,0,310)
cardScroll.BackgroundTransparency = 1
cardScroll.ScrollBarThickness = 4
cardScroll.CanvasSize = UDim2.new(0,0,0,0)
cardScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardScroll.Parent = bg

local cardPickList = Instance.new("UIListLayout")
cardPickList.Padding = UDim.new(0,6)
cardPickList.Parent = cardScroll

local function updatePowerLabel()
	local total = 0
	if currentProfile then
		for _, iid in ipairs(lineup) do
			if iid and currentProfile.cards[iid] then
				total += currentProfile.cards[iid].power
			end
		end
	end
	powerLabel.Text = "⚡ Squad Power: " .. total
end

local function refreshSlotLabels()
	for i, iid in ipairs(lineup) do
		local slot = slotButtons[i]
		if iid and currentProfile and currentProfile.cards[iid] then
			local card = currentProfile.cards[iid]
			local def  = CardCatalog.ById[card.cardId]
			slot.Text = (def and def.name or card.cardId) .. "\n⚡" .. card.power
			slot.TextColor3 = Color3.fromRGB(255,255,255)
		else
			slot.Text = SLOT_LABELS[i] .. "\n(empty)"
			slot.TextColor3 = Color3.fromRGB(150,150,180)
		end
	end
	updatePowerLabel()
end

local function populateCardList(profile)
	for _, child in ipairs(cardScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	if not profile then return end

	for instanceId, card in pairs(profile.cards) do
		local def = CardCatalog.ById[card.cardId]
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1,-4,0,50)
		row.BackgroundColor3 = Color3.fromRGB(22,22,38)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.Gotham
		row.Text = string.format(
			"%s  [%s]  ⚡%d",
			def and def.name or card.cardId,
			card.rarity or "?",
			card.power
		)
		row.TextColor3 = Color3.fromRGB(220,220,220)
		row.TextScaled = true
		row.Parent = cardScroll

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0,8)
		rowCorner.Parent = row

		local iid = instanceId
		row.Activated:Connect(function()
			if not selectedSlot then return end
			lineup[selectedSlot] = iid
			refreshSlotLabels()
		end)
	end
end

-- ─── Save button ──────────────────────────────────────────────────────────────

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0.6,0,0,50)
saveBtn.Position = UDim2.new(0.2,0,1,-58)
saveBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
saveBtn.Text = "Save Lineup"
saveBtn.TextColor3 = Color3.new(1,1,1)
saveBtn.TextScaled = true
saveBtn.Font = Enum.Font.GothamBold
saveBtn.Parent = bg

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0,12)
saveCorner.Parent = saveBtn

saveBtn.Activated:Connect(function()
	local trimmed = {}
	for _, iid in ipairs(lineup) do
		if iid then table.insert(trimmed, iid) end
	end
	if Remotes then
		Remotes:FindFirstChild("EquipSquad"):FireServer(trimmed)
	end
end)

-- ─── External update hook ─────────────────────────────────────────────────────

gui.DescendantAdded:Connect(function() end)  -- noop; wired externally

-- Exported so UIController can call it on ProfileUpdated
local module = {}
function module.onProfileUpdated(profile)
	currentProfile = profile
	if gui.Enabled then
		populateCardList(profile)
		refreshSlotLabels()
	end
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled and currentProfile then
		populateCardList(currentProfile)
		refreshSlotLabels()
	end
end)

-- Receive profile data directly from the server.
if Remotes then
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
		module.onProfileUpdated(profile)
	end)
end
