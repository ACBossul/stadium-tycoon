-- CardVisuals: shared, upload-free procedural card art + rarity styling.
-- Single source of truth for rarity colors and the "card face" used in the
-- pack reveal, collection book, and trade chips. When a card later gets real
-- decal art, callers pass that instead and skip buildFace entirely.

local TweenService = game:GetService("TweenService")

local CardVisuals = {}

CardVisuals.RarityColor = {
	Common    = Color3.fromRGB(165, 175, 190),
	Rare      = Color3.fromRGB( 70, 150, 255),
	Epic      = Color3.fromRGB(180,  80, 255),
	Legendary = Color3.fromRGB(255, 175,  45),
	Mythic    = Color3.fromRGB(255,  65,  95),
}

local function darken(c, f)  return c:Lerp(Color3.new(0,0,0), f) end
local function lighten(c, f) return c:Lerp(Color3.new(1,1,1), f) end

function CardVisuals.color(rarity)
	return CardVisuals.RarityColor[rarity] or CardVisuals.RarityColor.Common
end

-- Rounded corners + a glowing rarity border on a card container.
function CardVisuals.styleCard(container, rarity, cornerPx)
	local glow = CardVisuals.color(rarity)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerPx or 10)
	corner.Parent = container
	local stroke = Instance.new("UIStroke")
	stroke.Color = glow
	stroke.Thickness = (rarity == "Mythic" or rarity == "Legendary") and 3 or 2
	stroke.Transparency = 0.05
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = container
	return stroke
end

-- Build the procedural art face into `parent` (any GuiObject, e.g. the art area).
-- Renders the card's emoji on a two-tone rarity gradient with a diagonal sheen.
-- opts = { animate = bool }  -- sweep the sheen (use only for the few pack cards)
function CardVisuals.buildFace(parent, cardDef, opts)
	opts = opts or {}
	local rarity = (cardDef and cardDef.rarity) or "Common"
	local glow   = CardVisuals.color(rarity)

	parent.ClipsDescendants     = true
	parent.BackgroundColor3      = darken(glow, 0.45)
	parent.BackgroundTransparency = 0

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(lighten(glow, 0.12), darken(glow, 0.72))
	grad.Rotation = 115
	grad.Parent = parent

	-- Emoji "character"
	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, 0)
	face.BackgroundTransparency = 1
	face.Text = (cardDef and cardDef.emoji) or ((cardDef and cardDef.name or "?"):sub(1, 1))
	face.TextScaled = true
	face.Font = Enum.Font.GothamBlack
	face.TextColor3 = Color3.new(1, 1, 1)
	face.ZIndex = (parent.ZIndex or 1) + 1
	face.Parent = parent
	local fpad = Instance.new("UIPadding")
	fpad.PaddingTop = UDim.new(0.14, 0); fpad.PaddingBottom = UDim.new(0.14, 0)
	fpad.PaddingLeft = UDim.new(0.14, 0); fpad.PaddingRight = UDim.new(0.14, 0)
	fpad.Parent = face
	local fstroke = Instance.new("UIStroke")
	fstroke.Color = darken(glow, 0.65)
	fstroke.Thickness = 2
	fstroke.Transparency = 0.25
	fstroke.Parent = face

	-- Diagonal sheen
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.Size = UDim2.new(1.7, 0, 1.7, 0)
	sheen.Position = UDim2.new(-0.35, 0, -0.35, 0)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BorderSizePixel = 0
	sheen.ZIndex = (parent.ZIndex or 1) + 2
	local sg = Instance.new("UIGradient")
	sg.Color = ColorSequence.new(Color3.new(1, 1, 1))
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 1),
		NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.50, 0.55),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1.00, 1),
	})
	sg.Rotation = 22
	sg.Parent = sheen
	sheen.Parent = parent

	if opts.animate then
		sg.Offset = Vector2.new(-1, 0)
		TweenService:Create(
			sg,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.huge, false, 0.5),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	else
		sg.Offset = Vector2.new(0.18, 0)  -- static glint
	end

	return face
end

return CardVisuals
