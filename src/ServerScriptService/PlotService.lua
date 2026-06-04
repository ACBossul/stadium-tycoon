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

local PLOT_SPACING   = 185    -- studs between plot origins (close enough to see neighbours)
local PLOT_SIZE      = Vector3.new(150, 1, 150)

-- Hand-placed building spots (offset from plot origin, on the ground plane). Gives
-- the grounds room to breathe: an entrance plaza at the south (-Z), buildings framing
-- it, a floodlight tower at the back corner. Every building faces -Z (the entrance).
local BUILDING_LAYOUT = {
	stands      = { x = -30, z =  50 },
	bigscreen   = { x =  34, z =  52 },
	floodlights = { x =  64, z =  60 },
	concessions = { x = -52, z =  -6 },
	merch       = { x = -52, z =  24 },
	parking     = { x =  46, z = -28 },
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

-- Folder that holds all live plots
local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace
end

-- ONE big shared ground for every base (instead of separate floating plots).
-- Top sits at y = 0; bases are placed along +X on it.
local arena = Workspace:FindFirstChild("Arena")
if not arena then
	arena = Instance.new("Part")
	arena.Name        = "Arena"
	arena.Anchored    = true
	arena.Size        = Vector3.new(3200, 4, 320)
	arena.Position    = Vector3.new(1400, -2, 0)   -- covers ~16 bases along +X
	arena.Color       = Color3.fromRGB(40, 90, 50)
	arena.Material    = Enum.Material.Grass
	arena.TopSurface  = Enum.SurfaceType.Smooth
	arena.Parent      = Workspace
end

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
	goal(38)
	goal(-44)
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

	-- (No per-plot ground — every base sits on the one shared "Arena" ground.)

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
	plot.PrimaryPart     = spawnPad

	-- Stored facing +Z so the player looks into their stadium on (re)spawn.
	playerSpawnCFrame[player.UserId] =
		CFrame.lookAt(spawnPos + Vector3.new(0, 3, 0), spawnPos + Vector3.new(0, 3, 10))

	-- Perimeter wall + goals + the defensible entrance gate
	buildSurrounds(plot, origin)
	buildDoor(plot, origin, player)

	-- Place each building at its hand-picked spot (spacious, framing the plaza).
	for _, buildingCfg in ipairs(BuildingConfig.Buildings) do
		local spot = BUILDING_LAYOUT[buildingCfg.id] or { x = 0, z = 0 }
		local pos = Vector3.new(
			origin.X + spot.x,
			origin.Y,                 -- shared arena top is y = 0
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
