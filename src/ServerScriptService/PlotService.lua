-- PlotService: builds a per-player stadium plot at runtime.
-- Removes the need to hand-place and tag building models in Studio.
-- Each building model carries:
--   * a StringValue "BuildingId"  (matches BuildingConfig ids)
--   * an ObjectValue "Owner"      (the player who owns this plot)
--   * the CollectionService tag "StadiumBuilding"
--   * a BillboardGui "InfoBillboard" with NameLabel, LevelLabel, UpgradeButton
-- The client (StadiumController) wires the buttons/click detectors for the owner.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace         = game:GetService("Workspace")

local BuildingConfig = require(ReplicatedStorage.Config.BuildingConfig)

local PlotService = {}

-- ─── Plot layout constants ───────────────────────────────────────────────────

local PLOT_SIZE      = Vector3.new(150, 1, 150)
local PLOT_SPACING   = PLOT_SIZE.X    -- pads tile edge-to-edge into one connected ground

-- Hand-placed building spots (offset from plot origin, on the ground plane). The
-- central pitch occupies x[-40,40] z[-48,48]; buildings live in the margins around
-- it so nothing sits ON the field. Entrance/spawn is south (-Z); all face -Z.
local BUILDING_LAYOUT = {
	stands      = { x = -22, z =  60 },   -- north stand, behind the goal
	bigscreen   = { x =  40, z =  60 },   -- north-east, beside the stand
	floodlights = { x = -62, z =  62 },   -- north-west corner tower
	concessions = { x = -58, z =  12 },   -- west margin
	merch       = { x = -58, z = -20 },   -- west margin
	parking     = { x =  56, z = -56 },   -- south-east corner, clear of the pitch
}

-- Parody team palette (NO real club/national colors).
local TEAM_GREEN = Color3.fromRGB( 45, 165,  85)
local TEAM_GOLD  = Color3.fromRGB(245, 210,  60)
local CONCRETE   = Color3.fromRGB(120, 124, 134)
local METAL_DARK = Color3.fromRGB( 45,  48,  58)
local M = Enum.Material

-- Each building is composed of several anchored parts. Piece #1 is the
-- interactive base (carries the ClickDetector + info billboard + collision).
-- `offset` = part-center position relative to the building's ground point.
local BUILDING_PIECES = {
	stands = {
		{ size = Vector3.new(32, 11, 12),  offset = Vector3.new(0,  5.5, -1.0), color = CONCRETE,   material = M.Concrete },
		{ size = Vector3.new(32, 1.6, 3),  offset = Vector3.new(0,  7.2,  2.0), color = TEAM_GREEN, material = M.SmoothPlastic },
		{ size = Vector3.new(32, 1.6, 3),  offset = Vector3.new(0,  9.2,  3.6), color = TEAM_GOLD,  material = M.SmoothPlastic },
		{ size = Vector3.new(32, 1.6, 3),  offset = Vector3.new(0, 11.2,  5.2), color = TEAM_GREEN, material = M.SmoothPlastic },
	},
	concessions = {
		{ size = Vector3.new(11, 7, 9),      offset = Vector3.new(0, 3.5, 0),   color = Color3.fromRGB(230,150,60),  material = M.SmoothPlastic },
		{ size = Vector3.new(12.5, 1.4, 10.5),offset = Vector3.new(0, 7.4, 0),  color = Color3.fromRGB(200,70,70),   material = M.SmoothPlastic },
		{ size = Vector3.new(7, 2.2, 0.6),   offset = Vector3.new(0, 4.6, 4.7), color = Color3.fromRGB(250,245,235), material = M.SmoothPlastic },
	},
	merch = {
		{ size = Vector3.new(12, 8, 9),       offset = Vector3.new(0, 4, 0),    color = Color3.fromRGB(60,120,220), material = M.SmoothPlastic },
		{ size = Vector3.new(13.5, 1.4, 10.5),offset = Vector3.new(0, 8.4, 0),  color = Color3.fromRGB(35,80,170),  material = M.SmoothPlastic },
		{ size = Vector3.new(7, 2.2, 0.6),    offset = Vector3.new(0, 5.6, 4.7),color = TEAM_GOLD,                  material = M.SmoothPlastic },
	},
	parking = {
		{ size = Vector3.new(26, 0.6, 20), offset = Vector3.new(0,  0.3, 0), color = Color3.fromRGB(60,62,68),    material = M.Concrete },
		{ size = Vector3.new(0.4, 0.66, 16),offset = Vector3.new(-6, 0.34,0),color = Color3.fromRGB(235,235,235), material = M.SmoothPlastic },
		{ size = Vector3.new(0.4, 0.66, 16),offset = Vector3.new(0,  0.34,0),color = Color3.fromRGB(235,235,235), material = M.SmoothPlastic },
		{ size = Vector3.new(0.4, 0.66, 16),offset = Vector3.new(6,  0.34,0),color = Color3.fromRGB(235,235,235), material = M.SmoothPlastic },
	},
	bigscreen = {
		{ size = Vector3.new(22, 16, 2),   offset = Vector3.new(0, 9, 0),     color = METAL_DARK,                  material = M.Metal },
		{ size = Vector3.new(19, 13, 0.6), offset = Vector3.new(0, 9, -1.05), color = Color3.fromRGB(120,210,255), material = M.Neon },
		{ size = Vector3.new(1.4, 9, 1.4), offset = Vector3.new(-8, 4.5, 0.7),color = METAL_DARK,                  material = M.Metal },
		{ size = Vector3.new(1.4, 9, 1.4), offset = Vector3.new(8,  4.5, 0.7),color = METAL_DARK,                  material = M.Metal },
	},
	floodlights = {
		{ size = Vector3.new(1.4, 22, 1.4),offset = Vector3.new(0, 11, 0),    color = Color3.fromRGB(90,95,105),   material = M.Metal },
		{ size = Vector3.new(6, 1.6, 3),   offset = Vector3.new(0, 21.6, 0),  color = METAL_DARK,                  material = M.Metal },
		{ size = Vector3.new(5, 1.2, 2.4), offset = Vector3.new(0, 22.4, 0.3),color = Color3.fromRGB(255,250,210), material = M.Neon },
	},
}

local DEFAULT_PIECES = {
	{ size = Vector3.new(10,10,10), offset = Vector3.new(0,5,0), color = Color3.fromRGB(150,150,150), material = M.SmoothPlastic },
}

-- Uploaded surface textures (decals on the AC6005 account, via Open Cloud).
local TEXTURES = {
	grass   = "rbxassetid://70872978008715",
	seats   = "rbxassetid://107539265030237",
	brick   = "rbxassetid://100402802088606",
	metal   = "rbxassetid://110788642331092",
	asphalt = "rbxassetid://129383393602486",
}

-- Tile a texture across the given faces of a part.
local function applyTexture(part, textureId, studs, faces)
	if not part or not textureId then return end
	for _, face in ipairs(faces) do
		local t = Instance.new("Texture")
		t.Texture      = textureId
		t.Face         = face
		t.StudsPerTileU = studs
		t.StudsPerTileV = studs
		t.Parent       = part
	end
end

local ALL_SIDES = {
	Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right,
}

-- Folder that holds all live plots
local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace
end

-- Each base brings its own solid, collidable ground pad (built in buildPlot).
-- Pads are placed edge-to-edge in a row, so together they read as one connected
-- ground — but every base always has guaranteed solid footing under it.

-- ─── Plot index allocation ───────────────────────────────────────────────────

local usedIndices = {}            -- index -> player.UserId
local playerPlotIndex = {}        -- player.UserId -> index
local playerPlotModel = {}        -- player.UserId -> plot Model
local playerSpawnCFrame = {}      -- player.UserId -> CFrame to (re)spawn at
local playerConns = {}            -- player.UserId -> CharacterAdded connection

-- Put the player on their plot's entrance, now and on every respawn.
local function teleportToPlot(player)
	local cf = playerSpawnCFrame[player.UserId]
	if not cf then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp  = char:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		hrp.CFrame = cf
	end
end

local function allocateIndex(player)
	local i = 0
	while usedIndices[i] do i += 1 end
	usedIndices[i] = player.UserId
	playerPlotIndex[player.UserId] = i
	return i
end

local function freeIndex(player)
	local i = playerPlotIndex[player.UserId]
	if i ~= nil then
		usedIndices[i] = nil
		playerPlotIndex[player.UserId] = nil
	end
end

-- ─── Building model builder ──────────────────────────────────────────────────

local function buildBillboard(buildingCfg)
	local billboard = Instance.new("BillboardGui")
	billboard.Name           = "InfoBillboard"
	billboard.Size           = UDim2.new(0, 180, 0, 90)
	billboard.StudsOffset    = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop    = true
	billboard.MaxDistance    = 80
	billboard.LightInfluence = 0

	local bg = Instance.new("Frame")
	bg.Size                 = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3     = Color3.fromRGB(15, 15, 22)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel      = 0
	bg.Parent               = billboard
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name             = "NameLabel"
	nameLabel.Size             = UDim2.new(1, -8, 0, 26)
	nameLabel.Position         = UDim2.new(0, 4, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = buildingCfg.name
	nameLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled       = true
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.Parent           = bg

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name             = "LevelLabel"
	levelLabel.Size             = UDim2.new(1, -8, 0, 22)
	levelLabel.Position         = UDim2.new(0, 4, 0, 28)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text             = "Locked"
	levelLabel.TextColor3       = Color3.fromRGB(180, 180, 200)
	levelLabel.TextScaled       = true
	levelLabel.Font             = Enum.Font.Gotham
	levelLabel.Parent           = bg

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name             = "UpgradeButton"
	upgradeButton.Size             = UDim2.new(1, -16, 0, 30)
	upgradeButton.Position         = UDim2.new(0, 8, 1, -34)
	upgradeButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
	upgradeButton.Text             = "Upgrade"
	upgradeButton.TextColor3       = Color3.fromRGB(255, 255, 255)
	upgradeButton.TextScaled       = true
	upgradeButton.Font             = Enum.Font.GothamBold
	upgradeButton.Parent           = bg
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = upgradeButton

	return billboard
end

-- ─── Signage ─────────────────────────────────────────────────────────────────

-- A lit storefront banner on a part's front (-Z) face.
local function addBoothSign(part, text, color)
	local sg = Instance.new("SurfaceGui")
	sg.Name          = "Sign"
	sg.Face          = Enum.NormalId.Front     -- -Z, toward the concourse
	sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0                       -- full-bright so it "lights up"
	sg.Parent        = part

	local board = Instance.new("Frame")
	board.Size = UDim2.new(1, 0, 0.34, 0)
	board.Position = UDim2.new(0, 0, 0.06, 0)
	board.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	board.BackgroundTransparency = 0.12
	board.BorderSizePixel = 0
	board.Parent = sg
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, -6)
	label.Position = UDim2.new(0, 4, 0, 3)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = board
end

-- A glowing live scoreboard on the big-screen's Neon face (parody teams only).
local function addScoreboard(part)
	local sg = Instance.new("SurfaceGui")
	sg.Name          = "Scoreboard"
	sg.Face          = Enum.NormalId.Front
	sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent        = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.24, 0)
	title.BackgroundTransparency = 1
	title.Text = "⚽ THE BRAINROT CUP"
	title.TextColor3 = Color3.fromRGB(255, 210, 70)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = bg

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0.5, 0)
	row.Position = UDim2.new(0, 0, 0.26, 0)
	row.BackgroundTransparency = 1
	row.Parent = bg

	local function teamChip(xScale, code, col)
		local chip = Instance.new("TextLabel")
		chip.Size = UDim2.new(0.3, 0, 0.7, 0)
		chip.Position = UDim2.new(xScale, 0, 0.15, 0)
		chip.BackgroundColor3 = col
		chip.Text = code
		chip.TextColor3 = Color3.new(1, 1, 1)
		chip.TextScaled = true
		chip.Font = Enum.Font.GothamBlack
		chip.Parent = row
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = chip
		local s = Instance.new("UIStroke") s.Color = Color3.new(0, 0, 0) s.Thickness = 2 s.Parent = chip
	end
	teamChip(0.04, "GRN", Color3.fromRGB(45, 165, 85))
	teamChip(0.66, "AZL", Color3.fromRGB(60, 120, 220))

	local score = Instance.new("TextLabel")
	score.Size = UDim2.new(0.32, 0, 1, 0)
	score.Position = UDim2.new(0.34, 0, 0, 0)
	score.BackgroundTransparency = 1
	score.Text = "2 - 1"
	score.TextColor3 = Color3.new(1, 1, 1)
	score.TextScaled = true
	score.Font = Enum.Font.GothamBlack
	score.Parent = row

	local live = Instance.new("TextLabel")
	live.Size = UDim2.new(1, 0, 0.2, 0)
	live.Position = UDim2.new(0, 0, 0.78, 0)
	live.BackgroundTransparency = 1
	live.Text = "🔴 LIVE"
	live.TextColor3 = Color3.fromRGB(255, 80, 80)
	live.TextScaled = true
	live.Font = Enum.Font.GothamBold
	live.Parent = bg
end

-- A gentle ambient sparkle on Neon surfaces (best-effort built-in texture).
local function addGlow(part, color)
	local att = Instance.new("Attachment")
	att.Parent = part
	local pe = Instance.new("ParticleEmitter")
	pe.Texture      = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color        = ColorSequence.new(color)
	pe.Lifetime     = NumberRange.new(0.8, 1.5)
	pe.Rate         = 5
	pe.Speed        = NumberRange.new(1, 2)
	pe.SpreadAngle  = Vector2.new(45, 45)
	pe.Size         = NumberSequence.new(0.7)
	pe.Transparency = NumberSequence.new(0.35)
	pe.Parent       = att
end

local function buildBuildingModel(buildingCfg, position, player)
	local pieces = BUILDING_PIECES[buildingCfg.id] or DEFAULT_PIECES

	local model = Instance.new("Model")
	model.Name = buildingCfg.id

	local primary
	local partsByIndex = {}
	for i, p in ipairs(pieces) do
		local part = Instance.new("Part")
		part.Name          = (i == 1) and "Base" or ("Piece" .. i)
		part.Size          = p.size
		part.Position      = position + p.offset
		part.Anchored      = true
		part.CanCollide    = (i == 1)       -- only the base blocks the player
		part.Color         = p.color
		part.Material       = p.material or Enum.Material.SmoothPlastic
		part.TopSurface    = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent        = model
		partsByIndex[i] = part
		if p.material == Enum.Material.Neon then
			addGlow(part, p.color)
		end
		if i == 1 then primary = part end
	end
	model.PrimaryPart = primary

	-- Surface textures per building
	local id = buildingCfg.id
	if id == "stands" then
		for i = 2, #partsByIndex do   -- the seating tiers
			applyTexture(partsByIndex[i], TEXTURES.seats, 5, { Enum.NormalId.Top, Enum.NormalId.Front })
		end
	elseif id == "concessions" or id == "merch" then
		applyTexture(partsByIndex[1], TEXTURES.brick, 6, ALL_SIDES)
	elseif id == "parking" then
		applyTexture(partsByIndex[1], TEXTURES.asphalt, 12, { Enum.NormalId.Top })
	elseif id == "bigscreen" then
		applyTexture(partsByIndex[1], TEXTURES.metal, 8, ALL_SIDES)
	elseif id == "floodlights" then
		applyTexture(partsByIndex[1], TEXTURES.metal, 5, ALL_SIDES)
	end

	local idValue = Instance.new("StringValue")
	idValue.Name   = "BuildingId"
	idValue.Value  = buildingCfg.id
	idValue.Parent = model

	local ownerValue = Instance.new("ObjectValue")
	ownerValue.Name   = "Owner"
	ownerValue.Value  = player
	ownerValue.Parent = model

	-- ClickDetector for active-collect buildings (client decides whether to use it)
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 32
	detector.Parent = primary

	buildBillboard(buildingCfg).Parent = primary

	-- Flavor signage
	if buildingCfg.id == "concessions" then
		addBoothSign(primary, "🍔 SNACKS", Color3.fromRGB(255, 175, 60))
	elseif buildingCfg.id == "merch" then
		addBoothSign(primary, "👕 MERCH", Color3.fromRGB(95, 160, 255))
	elseif buildingCfg.id == "bigscreen" then
		addScoreboard(partsByIndex[2] or primary)   -- the Neon screen face
	end

	CollectionService:AddTag(model, "StadiumBuilding")

	return model
end

-- Perimeter wall (with a south entrance gap) + two goal frames, for "place" feel.
local function buildSurrounds(plot, origin)
	local half = PLOT_SIZE.X / 2
	local wallH, wallT = 8, 2          -- tall enough that you can't jump over it
	local wallColor = Color3.fromRGB(70, 74, 86)

	local function wall(cx, cz, sx, sz)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(sx, wallH, sz)
		p.Position = origin + Vector3.new(cx, wallH / 2, cz)
		p.Color = wallColor
		p.Material = Enum.Material.Concrete
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = plot
		applyTexture(p, TEXTURES.brick, 12, ALL_SIDES)
	end

	wall(0,  half, PLOT_SIZE.X, wallT)   -- north
	wall( half, 0, wallT, PLOT_SIZE.Z)   -- east
	wall(-half, 0, wallT, PLOT_SIZE.Z)   -- west
	local sideW = (PLOT_SIZE.X - 24) / 2 -- south wall split for a centre entrance
	wall(-(12 + sideW / 2), -half, sideW, wallT)
	wall( (12 + sideW / 2), -half, sideW, wallT)

	-- Two simple white goal frames framing the central lane.
	local function goal(cz)
		local function bar(dx, dy, sx, sy, sz)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.Size = Vector3.new(sx, sy, sz)
			p.Position = origin + Vector3.new(dx, dy, cz)
			p.Color = Color3.fromRGB(240, 240, 245)
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = plot
		end
		bar(-7, 4, 1, 8, 1)    -- left post
		bar( 7, 4, 1, 8, 1)    -- right post
		bar( 0, 8, 15, 1, 1)   -- crossbar
	end
	goal(44)
	goal(-44)
end

-- A striped grass pitch with white markings in the centre, so the grounds read
-- as an actual stadium instead of an empty floor. Buildings frame it.
local function buildPitch(plot, origin)
	local PX, PZ = 80, 96

	local function flat(cx, cz, sx, sz, color, yy, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(sx, 0.2, sz)
		p.Position = origin + Vector3.new(cx, yy, cz)
		p.Color = color
		p.Material = material or Enum.Material.Grass
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = plot
	end

	-- Mowed stripes — PROCEDURAL, so the pitch always reads as a pitch even if the
	-- grass texture is still moderating or unavailable. When the texture does load
	-- it sits underneath these on the field and shows on the surrounding ground.
	local stripes = 8
	local sw = PX / stripes
	for i = 0, stripes - 1 do
		local shade = (i % 2 == 0) and Color3.fromRGB(52, 140, 70) or Color3.fromRGB(44, 120, 60)
		flat(-PX / 2 + sw / 2 + i * sw, 0, sw, PZ, shade, 0.12)
	end

	-- White field markings
	local white = Color3.fromRGB(235, 238, 240)
	local function line(cx, cz, sx, sz)
		flat(cx, cz, sx, sz, white, 0.22, Enum.Material.SmoothPlastic)
	end
	line(0,  PZ / 2, PX, 1)   -- north line
	line(0, -PZ / 2, PX, 1)   -- south line
	line( PX / 2, 0, 1, PZ)   -- east line
	line(-PX / 2, 0, 1, PZ)   -- west line
	line(0, 0, PX, 1)         -- halfway line
	line(0, 0, 4, 4)          -- centre spot
end

-- A force-field gate across the entrance + an owner-only toggle button.
-- Closed: touching it insta-kills NON-owners (the owner passes freely).
-- Open:   anyone may walk in. Owner clicks the button to open/close.
local function buildDoor(plot, origin, player)
	local entranceCF = origin + Vector3.new(0, 4, -PLOT_SIZE.Z / 2)

	local door = Instance.new("Part")
	door.Name       = "BaseDoor"
	door.Anchored   = true
	door.CanCollide  = false               -- kill-curtain, not a physical block
	door.Size       = Vector3.new(24, 8, 1)  -- full wall height so it can't be jumped
	door.Position   = entranceCF
	door.Material   = Enum.Material.ForceField
	door.Parent     = plot
	door:SetAttribute("Closed", true)

	local function paintDoor()
		local closed = door:GetAttribute("Closed")
		door.Color        = closed and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(70, 210, 110)
		door.Transparency = closed and 0.25 or 0.7
	end
	paintDoor()

	-- Insta-kill intruders crossing a closed door.
	door.Touched:Connect(function(hit)
		if not door:GetAttribute("Closed") then return end
		local character = hit and hit.Parent
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		local toucher = Players:GetPlayerFromCharacter(character)
		if not toucher or toucher == player then return end   -- owner is immune
		hum.Health = 0
	end)

	-- Owner-only toggle button just inside the entrance.
	local button = Instance.new("Part")
	button.Name      = "DoorButton"
	button.Anchored  = true
	button.Size      = Vector3.new(4, 2, 4)
	button.Position  = origin + Vector3.new(11, 1, -PLOT_SIZE.Z / 2 + 9)
	button.Material  = Enum.Material.Neon
	button.Parent    = plot

	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 20
	cd.Parent = button

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 32)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 60
	bb.Adornee = button
	bb.Parent = button
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Parent = bb

	local function paintButton()
		local closed = door:GetAttribute("Closed")
		button.Color = closed and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(70, 210, 110)
		lbl.Text     = closed and "🚪 Door: CLOSED" or "🚪 Door: OPEN"
	end
	paintButton()

	cd.MouseClick:Connect(function(clicker)
		if clicker ~= player then return end   -- only the base owner controls the gate
		door:SetAttribute("Closed", not door:GetAttribute("Closed"))
		paintDoor()
		paintButton()
	end)
end

-- ─── Plot builder ────────────────────────────────────────────────────────────

function PlotService.buildPlot(player)
	-- Avoid duplicate plots if called twice
	if playerPlotModel[player.UserId] then
		return playerPlotModel[player.UserId]
	end

	local index  = allocateIndex(player)
	local origin = Vector3.new(index * PLOT_SPACING, 0, 0)

	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. player.UserId

	-- Solid, collidable ground pad — the single guaranteed walking surface for the
	-- whole base. Top sits exactly at y = 0; everything else is placed on top of it.
	local pad = Instance.new("Part")
	pad.Name         = "Ground"
	pad.Anchored     = true
	pad.CanCollide   = true
	pad.Size         = Vector3.new(PLOT_SIZE.X, 4, PLOT_SIZE.Z)
	pad.Position     = origin + Vector3.new(0, -2, 0)   -- top at y = 0
	pad.Color        = Color3.fromRGB(70, 112, 72)
	pad.Material     = Enum.Material.Grass
	pad.TopSurface   = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent       = plot
	plot.PrimaryPart = pad
	applyTexture(pad, TEXTURES.grass, 24, { Enum.NormalId.Top })   -- mowed-grass surface

	-- Owner reference + spawn point
	local ownerValue = Instance.new("ObjectValue")
	ownerValue.Name   = "Owner"
	ownerValue.Value  = player
	ownerValue.Parent = plot

	-- Entrance plaza spawn at the south edge, facing north into the grounds.
	local spawnPos = origin + Vector3.new(0, 1, -PLOT_SIZE.Z / 2 + 11)
	local spawnPad = Instance.new("Part")
	spawnPad.Name        = "PlotSpawn"
	spawnPad.Size        = Vector3.new(14, 1, 14)
	spawnPad.Position    = spawnPos
	spawnPad.Anchored    = true
	spawnPad.Color       = Color3.fromRGB(60, 64, 76)
	spawnPad.Material    = Enum.Material.Concrete
	spawnPad.TopSurface  = Enum.SurfaceType.Smooth
	spawnPad.Parent      = plot

	-- Floating base-name sign (visible over the walls, identifies whose base it is).
	local nameSign = Instance.new("BillboardGui")
	nameSign.Name        = "BaseName"
	nameSign.Size        = UDim2.new(0, 280, 0, 54)
	nameSign.StudsOffset = Vector3.new(0, 26, 0)
	nameSign.AlwaysOnTop = true
	nameSign.MaxDistance = 400
	nameSign.Adornee     = spawnPad
	nameSign.Parent      = spawnPad
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 1, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = player.DisplayName .. "'s Stadium"
	nameLbl.TextColor3 = Color3.fromRGB(255, 235, 150)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextStrokeTransparency = 0.4
	nameLbl.Parent = nameSign

	-- Stored facing +Z so the player looks into their stadium on (re)spawn.
	playerSpawnCFrame[player.UserId] =
		CFrame.lookAt(spawnPos + Vector3.new(0, 3, 0), spawnPos + Vector3.new(0, 3, 10))

	-- Pitch in the centre, perimeter wall + goals, and the defensible entrance gate
	buildPitch(plot, origin)
	buildSurrounds(plot, origin)
	buildDoor(plot, origin, player)

	-- Place each building at its hand-picked spot (spacious, framing the plaza).
	for _, buildingCfg in ipairs(BuildingConfig.Buildings) do
		local spot = BUILDING_LAYOUT[buildingCfg.id] or { x = 0, z = 0 }
		local pos = Vector3.new(
			origin.X + spot.x,
			origin.Y,                 -- ground pad top is y = 0
			origin.Z + spot.z
		)
		buildBuildingModel(buildingCfg, pos, player).Parent = plot
	end

	plot.Parent = plotsFolder
	playerPlotModel[player.UserId] = plot

	-- Teleport onto the plot now AND on every respawn (fixes spawning at world origin).
	playerConns[player.UserId] = player.CharacterAdded:Connect(function()
		teleportToPlot(player)
	end)
	task.spawn(teleportToPlot, player)

	return plot
end

function PlotService.removePlot(player)
	local conn = playerConns[player.UserId]
	if conn then
		conn:Disconnect()
		playerConns[player.UserId] = nil
	end
	playerSpawnCFrame[player.UserId] = nil

	local plot = playerPlotModel[player.UserId]
	if plot then
		plot:Destroy()
		playerPlotModel[player.UserId] = nil
	end
	freeIndex(player)
end

return PlotService
