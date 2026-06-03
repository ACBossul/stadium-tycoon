-- TradeScreen.client.lua: two-sided player trade window + player browser.
-- Backend is TradeService (server-authoritative). This script only renders state
-- and forwards intents (request / offer / confirm / cancel) via RemoteEvents.
--
-- Trade events are CLIENT-RELATIVE (see TradeService): a "state" payload carries
-- yourOffer / theirOffer / youLocked / theyLocked / partnerName.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CardCatalog"))

-- ─── State ────────────────────────────────────────────────────────────────────

local currentProfile = nil      -- for our own inventory
local inTrade        = false
local partnerName    = nil
local myOfferIds     = {}        -- instanceIds we've staged to offer
local theirOffer     = {}        -- [{instanceId, cardId, power}]
local youLocked      = false
local theyLocked     = false

local RARITY_COLORS = {
	Common    = Color3.fromRGB(180,180,180),
	Rare      = Color3.fromRGB(60,140,255),
	Epic      = Color3.fromRGB(160,50,255),
	Legendary = Color3.fromRGB(255,165,0),
	Mythic    = Color3.fromRGB(255,50,50),
}

-- ─── Root GUI ───────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "TradeScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 6
gui.Parent       = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundColor3 = Color3.fromRGB(8,8,16)
bg.BorderSizePixel  = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,0,50)
title.Position = UDim2.new(0,12,0,8)
title.BackgroundTransparency = 1
title.Text = "🔄  TRADE"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg

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

-- ─── Two sub-views: Browse and Window ─────────────────────────────────────────

local browseView = Instance.new("Frame")
browseView.Name = "BrowseView"
browseView.Size = UDim2.new(1,0,1,-66)
browseView.Position = UDim2.new(0,0,0,66)
browseView.BackgroundTransparency = 1
browseView.Parent = bg

local windowView = Instance.new("Frame")
windowView.Name = "WindowView"
windowView.Size = UDim2.new(1,0,1,-66)
windowView.Position = UDim2.new(0,0,0,66)
windowView.BackgroundTransparency = 1
windowView.Visible = false
windowView.Parent = bg

-- ── Browse view: list of online players ──

local browseHint = Instance.new("TextLabel")
browseHint.Size = UDim2.new(1,-16,0,28)
browseHint.Position = UDim2.new(0,8,0,0)
browseHint.BackgroundTransparency = 1
browseHint.Text = "Tap a player to request a trade:"
browseHint.TextColor3 = Color3.fromRGB(200,200,220)
browseHint.TextScaled = true
browseHint.Font = Enum.Font.Gotham
browseHint.TextXAlignment = Enum.TextXAlignment.Left
browseHint.Parent = browseView

local browseScroll = Instance.new("ScrollingFrame")
browseScroll.Size = UDim2.new(1,-16,1,-36)
browseScroll.Position = UDim2.new(0,8,0,32)
browseScroll.BackgroundTransparency = 1
browseScroll.ScrollBarThickness = 4
browseScroll.CanvasSize = UDim2.new(0,0,0,0)
browseScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
browseScroll.Parent = browseView

local browseList = Instance.new("UIListLayout")
browseList.Padding = UDim.new(0,6)
browseList.Parent = browseScroll

local function refreshBrowse()
	for _, child in ipairs(browseScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local any = false
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			any = true
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1,-4,0,50)
			row.BackgroundColor3 = Color3.fromRGB(22,22,38)
			row.BorderSizePixel = 0
			row.Parent = browseScroll
			local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0,8) rc.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.6,0,1,0)
			nameLabel.Position = UDim2.new(0,10,0,0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = plr.DisplayName .. "  (@" .. plr.Name .. ")"
			nameLabel.TextColor3 = Color3.new(1,1,1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = row

			local reqBtn = Instance.new("TextButton")
			reqBtn.Size = UDim2.new(0,110,0,38)
			reqBtn.Position = UDim2.new(1,-120,0.5,-19)
			reqBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
			reqBtn.Text = "Request"
			reqBtn.TextColor3 = Color3.new(1,1,1)
			reqBtn.TextScaled = true
			reqBtn.Font = Enum.Font.GothamBold
			reqBtn.Parent = row
			local bc2 = Instance.new("UICorner") bc2.CornerRadius = UDim.new(0,8) bc2.Parent = reqBtn

			local targetName = plr.Name
			reqBtn.Activated:Connect(function()
				Remotes.TradeRequest:FireServer(targetName)
			end)
		end
	end

	if not any then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1,-4,0,50)
		empty.BackgroundTransparency = 1
		empty.Parent = browseScroll
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1,0,1,0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "No other players online right now."
		lbl.TextColor3 = Color3.fromRGB(150,150,170)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = empty
	end
end

Players.PlayerAdded:Connect(function() if gui.Enabled and not inTrade then refreshBrowse() end end)
Players.PlayerRemoving:Connect(function() if gui.Enabled and not inTrade then refreshBrowse() end end)

-- ── Window view: the two-sided trade ──

local partnerLabel = Instance.new("TextLabel")
partnerLabel.Size = UDim2.new(1,-16,0,28)
partnerLabel.Position = UDim2.new(0,8,0,0)
partnerLabel.BackgroundTransparency = 1
partnerLabel.Text = "Trading with ..."
partnerLabel.TextColor3 = Color3.fromRGB(255,255,255)
partnerLabel.TextScaled = true
partnerLabel.Font = Enum.Font.GothamBold
partnerLabel.TextXAlignment = Enum.TextXAlignment.Left
partnerLabel.Parent = windowView

-- Helper: build a card chip
local function buildChip(cardId, power, onClick)
	local def = CardCatalog.ById[cardId]
	local chip = Instance.new("TextButton")
	chip.Size = UDim2.new(0,84,0,46)
	chip.BackgroundColor3 = Color3.fromRGB(28,28,46)
	chip.AutoButtonColor = onClick ~= nil
	chip.Text = ""
	chip.Parent = nil
	local chc = Instance.new("UICorner") chc.CornerRadius = UDim.new(0,8) chc.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_COLORS[def and def.rarity] or Color3.new(1,1,1)
	stroke.Thickness = 2
	stroke.Parent = chip

	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(1,-4,0.6,0)
	n.Position = UDim2.new(0,2,0,2)
	n.BackgroundTransparency = 1
	n.Text = ((def and def.emoji) and (def.emoji .. " ") or "") .. (def and def.name or cardId)
	n.TextColor3 = Color3.new(1,1,1)
	n.TextScaled = true
	n.Font = Enum.Font.Gotham
	n.TextWrapped = true
	n.Parent = chip

	local p = Instance.new("TextLabel")
	p.Size = UDim2.new(1,0,0.35,0)
	p.Position = UDim2.new(0,0,0.62,0)
	p.BackgroundTransparency = 1
	p.Text = "⚡" .. tostring(power)
	p.TextColor3 = Color3.fromRGB(255,220,50)
	p.TextScaled = true
	p.Font = Enum.Font.GothamBold
	p.Parent = chip

	if onClick then chip.Activated:Connect(onClick) end
	return chip
end

-- Their offer (read-only)
local theirLabel = Instance.new("TextLabel")
theirLabel.Size = UDim2.new(1,-16,0,22)
theirLabel.Position = UDim2.new(0,8,0,32)
theirLabel.BackgroundTransparency = 1
theirLabel.Text = "Their offer"
theirLabel.TextColor3 = Color3.fromRGB(200,200,220)
theirLabel.TextScaled = true
theirLabel.Font = Enum.Font.Gotham
theirLabel.TextXAlignment = Enum.TextXAlignment.Left
theirLabel.Parent = windowView

local theirRow = Instance.new("Frame")
theirRow.Size = UDim2.new(1,-16,0,52)
theirRow.Position = UDim2.new(0,8,0,56)
theirRow.BackgroundColor3 = Color3.fromRGB(16,16,28)
theirRow.BorderSizePixel = 0
theirRow.Parent = windowView
local trc = Instance.new("UICorner") trc.CornerRadius = UDim.new(0,8) trc.Parent = theirRow
local trl = Instance.new("UIListLayout")
trl.FillDirection = Enum.FillDirection.Horizontal
trl.Padding = UDim.new(0,6)
trl.VerticalAlignment = Enum.VerticalAlignment.Center
trl.Parent = theirRow
local trp = Instance.new("UIPadding") trp.PaddingLeft = UDim.new(0,4) trp.Parent = theirRow

-- Your offer (tap a chip to remove)
local yourLabel = Instance.new("TextLabel")
yourLabel.Size = UDim2.new(1,-16,0,22)
yourLabel.Position = UDim2.new(0,8,0,116)
yourLabel.BackgroundTransparency = 1
yourLabel.Text = "Your offer (tap to remove)"
yourLabel.TextColor3 = Color3.fromRGB(200,200,220)
yourLabel.TextScaled = true
yourLabel.Font = Enum.Font.Gotham
yourLabel.TextXAlignment = Enum.TextXAlignment.Left
yourLabel.Parent = windowView

local yourRow = Instance.new("Frame")
yourRow.Size = UDim2.new(1,-16,0,52)
yourRow.Position = UDim2.new(0,8,0,140)
yourRow.BackgroundColor3 = Color3.fromRGB(16,16,28)
yourRow.BorderSizePixel = 0
yourRow.Parent = windowView
local yrc = Instance.new("UICorner") yrc.CornerRadius = UDim.new(0,8) yrc.Parent = yourRow
local yrl = Instance.new("UIListLayout")
yrl.FillDirection = Enum.FillDirection.Horizontal
yrl.Padding = UDim.new(0,6)
yrl.VerticalAlignment = Enum.VerticalAlignment.Center
yrl.Parent = yourRow
local yrp = Instance.new("UIPadding") yrp.PaddingLeft = UDim.new(0,4) yrp.Parent = yourRow

-- Lock status line
local lockStatus = Instance.new("TextLabel")
lockStatus.Size = UDim2.new(1,-16,0,24)
lockStatus.Position = UDim2.new(0,8,0,198)
lockStatus.BackgroundTransparency = 1
lockStatus.Text = "You: not confirmed   |   Them: not confirmed"
lockStatus.TextColor3 = Color3.fromRGB(220,180,80)
lockStatus.TextScaled = true
lockStatus.Font = Enum.Font.Gotham
lockStatus.Parent = windowView

-- Your inventory picker (tap to add to offer)
local invLabel = Instance.new("TextLabel")
invLabel.Size = UDim2.new(1,-16,0,22)
invLabel.Position = UDim2.new(0,8,0,226)
invLabel.BackgroundTransparency = 1
invLabel.Text = "Your cards (tap to add — equipped squad cards hidden)"
invLabel.TextColor3 = Color3.fromRGB(200,200,220)
invLabel.TextScaled = true
invLabel.Font = Enum.Font.Gotham
invLabel.TextXAlignment = Enum.TextXAlignment.Left
invLabel.Parent = windowView

local invScroll = Instance.new("ScrollingFrame")
invScroll.Size = UDim2.new(1,-16,1,-318)
invScroll.Position = UDim2.new(0,8,0,250)
invScroll.BackgroundTransparency = 1
invScroll.ScrollBarThickness = 4
invScroll.CanvasSize = UDim2.new(0,0,0,0)
invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
invScroll.Parent = windowView

local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.new(0,84,0,46)
invGrid.CellPadding = UDim2.new(0,6,0,6)
invGrid.Parent = invScroll

-- Confirm + Cancel buttons
local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(0.5,-12,0,50)
confirmBtn.Position = UDim2.new(0,8,1,-58)
confirmBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
confirmBtn.Text = "Confirm"
confirmBtn.TextColor3 = Color3.new(1,1,1)
confirmBtn.TextScaled = true
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.Parent = windowView
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0,10) cbc.Parent = confirmBtn

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.new(0.5,-12,0,50)
cancelBtn.Position = UDim2.new(0.5,4,1,-58)
cancelBtn.BackgroundColor3 = Color3.fromRGB(150,70,70)
cancelBtn.Text = "Cancel"
cancelBtn.TextColor3 = Color3.new(1,1,1)
cancelBtn.TextScaled = true
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.Parent = windowView
local cnc = Instance.new("UICorner") cnc.CornerRadius = UDim.new(0,10) cnc.Parent = cancelBtn

-- ─── Rendering ────────────────────────────────────────────────────────────────

local function isOffered(iid)
	for _, x in ipairs(myOfferIds) do if x == iid then return true end end
	return false
end

local function isEquipped(iid)
	if not currentProfile or not currentProfile.squad then return false end
	for _, x in ipairs(currentProfile.squad) do if x == iid then return true end end
	return false
end

local function pushOffer()
	Remotes.TradeOffer:FireServer(myOfferIds)
end

local function renderTheirOffer()
	for _, c in ipairs(theirRow:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for _, card in ipairs(theirOffer) do
		buildChip(card.cardId, card.power, nil).Parent = theirRow
	end
end

local function renderYourOffer()
	for _, c in ipairs(yourRow:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	if not currentProfile then return end
	for _, iid in ipairs(myOfferIds) do
		local card = currentProfile.cards[iid]
		if card then
			buildChip(card.cardId, card.power, function()
				-- remove from offer
				local newOffer = {}
				for _, x in ipairs(myOfferIds) do
					if x ~= iid then table.insert(newOffer, x) end
				end
				myOfferIds = newOffer
				pushOffer()
			end).Parent = yourRow
		end
	end
end

local function renderInventory()
	for _, c in ipairs(invScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	if not currentProfile then return end
	for iid, card in pairs(currentProfile.cards) do
		if not isOffered(iid) and not isEquipped(iid) then
			local capturedIid = iid
			buildChip(card.cardId, card.power, function()
				if #myOfferIds >= 5 then return end
				table.insert(myOfferIds, capturedIid)
				pushOffer()
			end).Parent = invScroll
		end
	end
end

local function renderLocks()
	lockStatus.Text = string.format(
		"You: %s   |   Them: %s",
		youLocked and "✓ CONFIRMED" or "not confirmed",
		theyLocked and "✓ CONFIRMED" or "not confirmed"
	)
	if youLocked then
		confirmBtn.Text = "✓ Confirmed"
		confirmBtn.BackgroundColor3 = Color3.fromRGB(90,90,110)
	else
		confirmBtn.Text = "Confirm"
		confirmBtn.BackgroundColor3 = Color3.fromRGB(50,180,80)
	end
end

local function renderAll()
	partnerLabel.Text = "Trading with " .. (partnerName or "...")
	renderTheirOffer()
	renderYourOffer()
	renderInventory()
	renderLocks()
end

local function showBrowse()
	inTrade = false
	windowView.Visible = false
	browseView.Visible = true
	refreshBrowse()
end

local function showWindow()
	inTrade = true
	browseView.Visible = false
	windowView.Visible = true
	renderAll()
end

-- ─── Button handlers ──────────────────────────────────────────────────────────

confirmBtn.Activated:Connect(function()
	if not inTrade or youLocked then return end
	Remotes.TradeConfirm:FireServer()
end)

cancelBtn.Activated:Connect(function()
	Remotes.TradeCancel:FireServer()
	showBrowse()
end)

closeBtn.Activated:Connect(function()
	if inTrade then
		Remotes.TradeCancel:FireServer()
	end
	inTrade = false
	gui.Enabled = false
end)

-- ─── Remote subscriptions ──────────────────────────────────────────────────────

Remotes.TradeStateChanged.OnClientEvent:Connect(function(payload)
	if not payload then return end

	if payload.type == "cancelled" then
		myOfferIds = {}
		theirOffer = {}
		youLocked, theyLocked = false, false
		if gui.Enabled then showBrowse() end
		return
	end

	if payload.type == "state" then
		local justOpened = not inTrade   -- first state for this session?
		partnerName = payload.partnerName
		theirOffer  = payload.theirOffer or {}
		youLocked   = payload.youLocked or false
		theyLocked  = payload.theyLocked or false
		-- Sync our staged offer to the server's authoritative view.
		myOfferIds = {}
		for _, c in ipairs(payload.yourOffer or {}) do
			table.insert(myOfferIds, c.instanceId)
		end
		-- Only pop the screen open on the initial request. Later offer/lock
		-- updates just refresh content so we don't yank the player back here
		-- if they've navigated to another panel mid-trade.
		if justOpened then
			gui.Enabled = true
		end
		showWindow()
	end
end)

Remotes.TradeComplete.OnClientEvent:Connect(function(payload)
	myOfferIds = {}
	theirOffer = {}
	youLocked, theyLocked = false, false
	inTrade = false
	local n = payload and payload.received and #payload.received or 0
	-- Show a brief completion state, then return to browser.
	partnerLabel.Text = "✅ Trade complete! Received " .. n .. " card(s)."
	if gui.Enabled then
		task.delay(1.5, function()
			if gui.Enabled and not inTrade then showBrowse() end
		end)
	end
end)

-- ─── Profile sync (for our inventory) ─────────────────────────────────────────

Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
	currentProfile = profile
	if gui.Enabled and inTrade then
		renderYourOffer()
		renderInventory()
	end
end)

-- When opened from the nav (no active trade), show the browser.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled and not inTrade then
		showBrowse()
	end
end)
