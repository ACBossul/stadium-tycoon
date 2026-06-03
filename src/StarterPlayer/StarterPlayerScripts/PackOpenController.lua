-- PackOpenController: drives the pack opening reveal animation.
-- Cards are revealed one by one; Mythic gets a slow dramatic reveal.
-- Expects a "PackOpenScreen" ScreenGui with a "CardContainer" Frame inside.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PackOpenController = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local CardCatalog

-- Reveal timing by rarity
local REVEAL_PAUSE = {
	Common    = 0.3,
	Rare      = 0.5,
	Epic      = 0.8,
	Legendary = 1.2,
	Mythic    = 2.5,  -- slow, dramatic
}

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
	local rarity  = cardResult.rarity

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
	local artId = (cardDef and cardDef.art) or "rbxassetid://0"
	local hasArt = artId ~= "rbxassetid://0" and artId ~= "" and artId ~= nil

	local art = Instance.new("ImageLabel")
	art.Size               = UDim2.new(1, -8, 0.55, 0)
	art.Position           = UDim2.new(0, 4, 0, 4)
	art.BackgroundColor3   = (RARITY_GLOW[rarity] or RARITY_GLOW.Common):Lerp(Color3.new(0,0,0), 0.55)
	art.BackgroundTransparency = hasArt and 1 or 0
	art.Image              = hasArt and artId or ""
	art.ScaleType          = Enum.ScaleType.Fit
	art.Parent             = outer
	local artCorner = Instance.new("UICorner")
	artCorner.CornerRadius = UDim.new(0, 8)
	artCorner.Parent = art

	if not hasArt then
		-- Procedural "art": a rarity gradient with the card's emoji face.
		local glow = RARITY_GLOW[rarity] or RARITY_GLOW.Common
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(
			glow:Lerp(Color3.new(0,0,0), 0.15),
			glow:Lerp(Color3.new(0,0,0), 0.70)
		)
		grad.Rotation = 45
		grad.Parent = art

		local face = Instance.new("TextLabel")
		face.Size = UDim2.new(1, 0, 1, 0)
		face.BackgroundTransparency = 1
		face.Text = (cardDef and cardDef.emoji) or ((cardDef and cardDef.name or "?"):sub(1, 1))
		face.TextScaled = true
		face.TextColor3 = Color3.new(1, 1, 1)
		face.Font = Enum.Font.GothamBlack
		face.Parent = art
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

function PackOpenController.playReveal(cards)
	local screen, container = ensureScreen()

	-- Clear previous cards
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	screen.Enabled = true

	-- Reveal cards one at a time
	task.spawn(function()
		for i, cardResult in ipairs(cards) do
			local rarity = cardResult.rarity
			local frame  = buildCardFrame(cardResult)

			-- Start off-screen below, transparent
			frame.Position         = UDim2.new((i-1) * (1/#cards), 0, 1.2, 0)
			frame.BackgroundTransparency = 1
			frame.Parent           = container

			-- For Mythic: add a brief flash effect first
			if rarity == "Mythic" then
				local flash = Instance.new("Frame")
				flash.Size     = UDim2.new(1,0,1,0)
				flash.BackgroundColor3 = Color3.fromRGB(255,255,255)
				flash.BackgroundTransparency = 0
				flash.ZIndex   = 10
				flash.Parent   = screen
				TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				task.delay(0.6, function() flash:Destroy() end)
				task.wait(0.3)
			end

			-- Slide in
			TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new((i-1) * (1/#cards), 4, 0.1, 0),
				BackgroundTransparency = 0,
			}):Play()

			task.wait(REVEAL_PAUSE[rarity] or 0.4)
		end

		-- Tap-to-dismiss label
		local dismissLabel = Instance.new("TextLabel")
		dismissLabel.Size   = UDim2.new(0.6, 0, 0, 40)
		dismissLabel.AnchorPoint = Vector2.new(0.5, 0)
		dismissLabel.Position = UDim2.new(0.5, 0, 0.88, 0)
		dismissLabel.BackgroundTransparency = 1
		dismissLabel.Text   = "Tap to close"
		dismissLabel.TextColor3 = Color3.fromRGB(200,200,200)
		dismissLabel.TextScaled = true
		dismissLabel.Font   = Enum.Font.Gotham
		dismissLabel.Parent = screen

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size   = UDim2.new(1,0,1,0)
		closeBtn.BackgroundTransparency = 1
		closeBtn.Text   = ""
		closeBtn.Parent = screen

		closeBtn.Activated:Connect(function()
			for _, child in ipairs(screen:GetChildren()) do
				if child ~= container then child:Destroy() end
			end
			for _, child in ipairs(container:GetChildren()) do
				child:Destroy()
			end
			screen.Enabled = false
		end)
	end)
end

function PackOpenController.init()
	CardCatalog = require(ReplicatedStorage.Config.CardCatalog)
end

return PackOpenController
