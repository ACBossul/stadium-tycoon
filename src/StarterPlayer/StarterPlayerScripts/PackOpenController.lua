-- PackOpenController: drives the pack opening reveal animation.
-- Cards are revealed one by one; Mythic gets a slow dramatic reveal.
-- Expects a "PackOpenScreen" ScreenGui with a "CardContainer" Frame inside.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardVisuals = require(ReplicatedStorage:WaitForChild("CardVisuals"))
local ConfettiVFX = require(script.Parent:WaitForChild("ConfettiVFX"))

local PackOpenController = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local CardCatalog

local RARITY_GLOW = {
	Common    = Color3.fromRGB(180,180,180),
	Rare      = Color3.fromRGB(60,140,255),
	Epic      = Color3.fromRGB(160,50,255),
	Legendary = Color3.fromRGB(255,165,0),
	Mythic    = Color3.fromRGB(255,50,50),
}

-- ─── Card frame builder ────────────────────────────────────────────────────

local function buildCardFrame(cardResult)
	local cardDef = CardCatalog.ById[cardResult.cardId]
	local rarity  = (cardDef and cardDef.rarity) or cardResult.rarity or "Common"

	local outer = Instance.new("Frame")
	outer.Size = UDim2.new(0, 120, 0, 180)
	outer.BackgroundColor3 = Color3.fromRGB(15,15,20)
	outer.BorderSizePixel  = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = outer

	-- Glow stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color     = RARITY_GLOW[rarity] or RARITY_GLOW.Common
	stroke.Thickness = 3
	stroke.Parent    = outer

	-- Card art. When art is still the "rbxassetid://0" placeholder, show a
	-- rarity-tinted block with the card's initial so it reads as intentional.
	local artId  = (cardDef and cardDef.art) or "rbxassetid://0"
	local hasArt = artId ~= "rbxassetid://0" and artId ~= "" and artId ~= nil

	local art = Instance.new("ImageLabel")
	art.Size               = UDim2.new(1, -8, 0.55, 0)
	art.Position           = UDim2.new(0, 4, 0, 4)
	art.BackgroundTransparency = hasArt and 1 or 0
	art.Image              = hasArt and artId or ""
	art.ScaleType          = Enum.ScaleType.Fit
	art.Parent             = outer
	local artCorner = Instance.new("UICorner")
	artCorner.CornerRadius = UDim.new(0, 8)
	artCorner.Parent = art

	if not hasArt then
		-- Shared procedural face: rarity gradient + emoji + sheen.
		-- Animate the sheen for the exciting rarities only.
		local animate = (rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic")
		CardVisuals.buildFace(art, cardDef, { animate = animate })
	end

	-- Rarity badge
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size             = UDim2.new(1, 0, 0, 22)
	rarityLabel.Position         = UDim2.new(0, 0, 0.58, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text             = rarity:upper()
	rarityLabel.TextColor3       = RARITY_GLOW[rarity] or Color3.new(1,1,1)
	rarityLabel.TextScaled       = true
	rarityLabel.Font             = Enum.Font.GothamBold
	rarityLabel.Parent           = outer

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(1, -8, 0, 30)
	nameLabel.Position         = UDim2.new(0, 4, 0.76, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = (cardDef and cardDef.name) or cardResult.cardId
	nameLabel.TextColor3       = Color3.new(1,1,1)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.Gotham
	nameLabel.TextWrapped      = true
	nameLabel.Parent           = outer

	-- Power
	local powerLabel = Instance.new("TextLabel")
	powerLabel.Size             = UDim2.new(1, 0, 0, 24)
	powerLabel.Position         = UDim2.new(0, 0, 0.88, 0)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text             = "⚡ " .. tostring(cardResult.power)
	powerLabel.TextColor3       = Color3.fromRGB(255,220,50)
	powerLabel.TextScaled       = true
	powerLabel.Font             = Enum.Font.GothamBold
	powerLabel.Parent           = outer

	return outer
end

-- ─── Reveal sequence ───────────────────────────────────────────────────────

-- Lazily build the full-screen reveal ScreenGui + CardContainer if absent.
local function ensureScreen()
	local screen = PlayerGui:FindFirstChild("PackOpenScreen")
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name         = "PackOpenScreen"
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 20
		screen.Enabled      = false
		screen.IgnoreGuiInset = true
		screen.Parent       = PlayerGui

		local backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.Size = UDim2.new(1, 0, 1, 0)
		backdrop.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
		backdrop.BackgroundTransparency = 0.1
		backdrop.BorderSizePixel = 0
		backdrop.Parent = screen
	end

	local container = screen:FindFirstChild("CardContainer")
	if not container then
		container = Instance.new("Frame")
		container.Name = "CardContainer"
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.Position = UDim2.new(0.5, 0, 0.45, 0)
		container.Size = UDim2.new(0.95, 0, 0, 200)
		container.BackgroundTransparency = 1
		container.Parent = screen
	end

	return screen, container
end

-- ─── CS:GO-style roll reveal ─────────────────────────────────────────────────

local REEL_TILE_W  = 120
local REEL_TILE_H  = 160
local REEL_GAP     = 10
local REEL_STEP    = REEL_TILE_W + REEL_GAP
local REEL_COUNT   = 50
local REEL_LANDING = 43            -- 0-based tile the ticker stops on
local ROLL_TIME    = 4.6
local RARITY_RANK  = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

-- A compact card tile used to fill the spinning reel.
local function buildReelTile(cardId)
	local def    = CardCatalog.ById[cardId]
	local rarity = (def and def.rarity) or "Common"

	local tile = Instance.new("Frame")
	tile.Size = UDim2.fromOffset(REEL_TILE_W, REEL_TILE_H)
	tile.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = tile
	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_GLOW[rarity] or RARITY_GLOW.Common
	stroke.Thickness = 2
	stroke.Parent = tile

	local art = Instance.new("Frame")
	art.Size = UDim2.new(1, -8, 0.72, 0)
	art.Position = UDim2.new(0, 4, 0, 4)
	art.BackgroundTransparency = 1
	art.Parent = tile
	CardVisuals.buildFace(art, def)

	local nm = Instance.new("TextLabel")
	nm.Size = UDim2.new(1, -6, 0.24, 0)
	nm.Position = UDim2.new(0, 3, 0.74, 0)
	nm.BackgroundTransparency = 1
	nm.Text = (def and def.name) or cardId
	nm.TextColor3 = Color3.new(1, 1, 1)
	nm.TextScaled = true
	nm.Font = Enum.Font.GothamBold
	nm.TextWrapped = true
	nm.Parent = tile
	return tile
end

function PackOpenController.playReveal(cards)
	local screen = ensureScreen()
	if not cards or #cards == 0 then return end

	-- Wipe any previous reveal content (keep only the backdrop).
	for _, child in ipairs(screen:GetChildren()) do
		if not (child:IsA("Frame") and child.Name == "Backdrop") then
			child:Destroy()
		end
	end
	screen.Enabled = true

	-- Feature card = the rarest pull; that's where the reel lands.
	local function rarityOf(c)
		local d = CardCatalog.ById[c.cardId]
		return (d and d.rarity) or c.rarity or "Common"
	end
	local feature = cards[1]
	for _, c in ipairs(cards) do
		if (RARITY_RANK[rarityOf(c)] or 1) > (RARITY_RANK[rarityOf(feature)] or 1) then
			feature = c
		end
	end
	local featureRarity = rarityOf(feature)

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -20, 0, 52)
	header.Position = UDim2.new(0, 10, 0.12, 0)
	header.BackgroundTransparency = 1
	header.Text = "OPENING PACK…"
	header.TextColor3 = Color3.fromRGB(255, 215, 0)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Parent = screen

	-- Reel window (clips the moving strip)
	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.Size = UDim2.new(0.94, 0, 0, REEL_TILE_H + 16)
	reel.Position = UDim2.new(0.03, 0, 0.32, 0)
	reel.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	reel.BackgroundTransparency = 0.15
	reel.BorderSizePixel = 0
	reel.ClipsDescendants = true
	reel.Parent = screen
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 12) rc.Parent = reel
	local rsk = Instance.new("UIStroke") rsk.Color = Color3.fromRGB(60, 60, 90) rsk.Thickness = 2 rsk.Parent = reel

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.Size = UDim2.fromOffset(REEL_COUNT * REEL_STEP, REEL_TILE_H)
	strip.Position = UDim2.new(0, 0, 0.5, -(REEL_TILE_H / 2))
	strip.BackgroundTransparency = 1
	strip.Parent = reel

	for i = 0, REEL_COUNT - 1 do
		local cardId
		if i == REEL_LANDING then
			cardId = feature.cardId
		else
			cardId = CardCatalog.Cards[math.random(1, #CardCatalog.Cards)].id
		end
		local tile = buildReelTile(cardId)
		tile.Position = UDim2.fromOffset(i * REEL_STEP + REEL_GAP / 2, 0)
		tile.Parent = strip
	end

	-- Center ticker
	local ticker = Instance.new("Frame")
	ticker.Size = UDim2.new(0, 4, 1, 0)
	ticker.Position = UDim2.new(0.5, -2, 0, 0)
	ticker.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	ticker.BorderSizePixel = 0
	ticker.ZIndex = 5
	ticker.Parent = reel

	task.spawn(function()
		-- Wait for the reel to get a real pixel width, then roll to the landing tile.
		local guard = 0
		while reel.AbsoluteSize.X <= 0 and guard < 120 do
			task.wait()
			guard += 1
		end
		local reelW = reel.AbsoluteSize.X
		if reelW <= 0 then reelW = 800 end

		local function offsetForTile(index, jitter)
			return reelW / 2 - (index * REEL_STEP + REEL_GAP / 2 + REEL_TILE_W / 2) - (jitter or 0)
		end

		strip.Position = UDim2.new(0, offsetForTile(4, 0), 0.5, -(REEL_TILE_H / 2))
		local jitter = math.random(-32, 32)   -- so it doesn't always stop dead-centre
		local target = offsetForTile(REEL_LANDING, jitter)

		local tween = TweenService:Create(
			strip,
			TweenInfo.new(ROLL_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, target, 0.5, -(REEL_TILE_H / 2)) }
		)
		tween:Play()
		tween.Completed:Wait()

		header.Text = "YOU GOT"
		if featureRarity == "Mythic" or featureRarity == "Legendary" then
			ConfettiVFX.burst({
				count  = (featureRarity == "Mythic") and 90 or 55,
				origin = Vector2.new(0.5, 0.3),
				spread = (featureRarity == "Mythic") and 0.9 or 0.7,
			})
		end

		-- Reveal the full pull below the reel.
		local row = Instance.new("Frame")
		row.Name = "RevealRow"
		row.Size = UDim2.new(1, 0, 0, 200)
		row.Position = UDim2.new(0, 0, 0.62, 0)
		row.BackgroundTransparency = 1
		row.Parent = screen
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 10)
		rowLayout.Parent = row
		for _, c in ipairs(cards) do
			buildCardFrame(c).Parent = row
		end

		local hint = Instance.new("TextLabel")
		hint.Size = UDim2.new(1, 0, 0, 34)
		hint.Position = UDim2.new(0, 0, 0.92, 0)
		hint.BackgroundTransparency = 1
		hint.Text = "Tap anywhere to close"
		hint.TextColor3 = Color3.fromRGB(200, 200, 210)
		hint.TextScaled = true
		hint.Font = Enum.Font.Gotham
		hint.Parent = screen

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(1, 0, 1, 0)
		closeBtn.BackgroundTransparency = 1
		closeBtn.Text = ""
		closeBtn.ZIndex = 10
		closeBtn.Parent = screen
		closeBtn.Activated:Connect(function()
			screen.Enabled = false
		end)
	end)
end

function PackOpenController.init()
	CardCatalog = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CardCatalog"))
end

return PackOpenController
