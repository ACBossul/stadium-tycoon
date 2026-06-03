-- PlotService: builds a per-player stadium plot at runtime.
-- Removes the need to hand-place and tag building models in Studio.
-- Each building model carries:
--   * a StringValue "BuildingId"  (matches BuildingConfig ids)
--   * an ObjectValue "Owner"      (the player who owns this plot)
--   * the CollectionService tag "StadiumBuilding"
--   * a BillboardGui "InfoBillboard" with NameLabel, LevelLabel, UpgradeButton
-- The client (StadiumController) wires the buttons/click detectors for the owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace         = game:GetService("Workspace")

local BuildingConfig = require(ReplicatedStorage.Config.BuildingConfig)

local PlotService = {}

-- ─── Plot layout constants ───────────────────────────────────────────────────

local PLOT_SPACING   = 200    -- studs between plot origins along X
local PLOT_SIZE      = Vector3.new(120, 1, 120)
local BUILDING_GAP   = 18     -- studs between buildings along Z

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
		{ size = Vector3.new(19, 13, 0.6), offset = Vector3.new(0, 9, 1.0),   color = Color3.fromRGB(120,210,255), material = M.Neon },
		{ size = Vector3.new(1.4, 9, 1.4), offset = Vector3.new(-8, 4.5,-0.6),color = METAL_DARK,                  material = M.Metal },
		{ size = Vector3.new(1.4, 9, 1.4), offset = Vector3.new(8,  4.5,-0.6),color = METAL_DARK,                  material = M.Metal },
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

-- ─── Plot index allocation ───────────────────────────────────────────────────

local usedIndices = {}            -- index -> player.UserId
local playerPlotIndex = {}        -- player.UserId -> index
local playerPlotModel = {}        -- player.UserId -> plot Model

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

local function buildBuildingModel(buildingCfg, position, player)
	local pieces = BUILDING_PIECES[buildingCfg.id] or DEFAULT_PIECES

	local model = Instance.new("Model")
	model.Name = buildingCfg.id

	local primary
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

	CollectionService:AddTag(model, "StadiumBuilding")

	return model
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

	-- Base ground
	local base = Instance.new("Part")
	base.Name        = "Ground"
	base.Size        = PLOT_SIZE
	base.Position    = origin
	base.Anchored    = true
	base.Color       = Color3.fromRGB(40, 90, 50)
	base.Material    = Enum.Material.Grass
	base.TopSurface  = Enum.SurfaceType.Smooth
	base.Parent      = plot
	plot.PrimaryPart = base

	-- Owner reference + spawn point
	local ownerValue = Instance.new("ObjectValue")
	ownerValue.Name   = "Owner"
	ownerValue.Value  = player
	ownerValue.Parent = plot

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name        = "PlotSpawn"
	spawnPad.Size        = Vector3.new(6, 1, 6)
	spawnPad.Position    = origin + Vector3.new(0, 1, -PLOT_SIZE.Z / 2 + 6)
	spawnPad.Anchored    = true
	spawnPad.Neutral     = true
	spawnPad.Duration    = 0          -- no forcefield
	spawnPad.Enabled     = false      -- not a global spawn; teleport handled manually
	spawnPad.Parent      = plot

	-- Lay out buildings in a row along Z, starting near the back
	local startZ = origin.Z - (#BuildingConfig.Buildings * BUILDING_GAP) / 2
	for i, buildingCfg in ipairs(BuildingConfig.Buildings) do
		local pos = Vector3.new(
			origin.X,
			origin.Y + PLOT_SIZE.Y / 2,
			startZ + (i - 1) * BUILDING_GAP
		)
		buildBuildingModel(buildingCfg, pos, player).Parent = plot
	end

	plot.Parent = plotsFolder
	playerPlotModel[player.UserId] = plot

	-- Teleport the player onto their plot once their character exists
	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local hrp  = char:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			hrp.CFrame = CFrame.new(spawnPad.Position + Vector3.new(0, 3, 0))
		end
	end)

	return plot
end

function PlotService.removePlot(player)
	local plot = playerPlotModel[player.UserId]
	if plot then
		plot:Destroy()
		playerPlotModel[player.UserId] = nil
	end
	freeIndex(player)
end

return PlotService
