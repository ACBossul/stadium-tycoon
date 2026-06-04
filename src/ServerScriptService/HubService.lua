-- HubService: builds the shared "Brainrot City" hub and runs the central arena
-- coin-task event. Players travel here via the "ToCityPad" on their plot and head
-- home via "ToStadiumPad" pads here. Shop/Trade kiosks reuse the existing screens
-- (wired client-side by HubController); the Kart Garage reuses KartService.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local Workspace           = game:GetService("Workspace")

local EconomyService = require(ServerScriptService.EconomyService)
local DataService    = require(ServerScriptService.DataService)
local PlotService    = require(ServerScriptService.PlotService)

local HubService = {}

local HUB_ORIGIN = Vector3.new(0, 0, -700)   -- well clear of the plot row (along +X)
local PLAZA      = 280
local ARENA_R    = 40

local hubFolder
local hubSpawnCFrame

-- ─── helpers ──────────────────────────────────────────────────────────────────

local function notify(player, msg, color)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ShowNotification")
	if ev then ev:FireClient(player, { message = msg, color = color or "white" }) end
end

local function pushProfile(player)
	local data = DataService.getData(player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ProfileUpdated")
	if data and ev then ev:FireClient(player, data) end
end

local function block(parent, size, pos, color, material, collide)
	local p = Instance.new("Part")
	p.Anchored      = true
	p.CanCollide    = collide ~= false
	p.Size          = size
	p.Position      = pos
	p.Color         = color
	p.Material      = material or Enum.Material.SmoothPlastic
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent        = parent
	return p
end

-- A neon storefront sign on a part's +Z (Back) face… we just face the plaza centre.
local function neonSign(part, text, color, face)
	local sg = Instance.new("SurfaceGui")
	sg.Face          = face or Enum.NormalId.Front
	sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Parent        = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0.4, 0)
	bg.Position = UDim2.new(0, 0, 0.04, 0)
	bg.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
	bg.BackgroundTransparency = 0.15
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local stroke = Instance.new("UIStroke") stroke.Color = color stroke.Thickness = 3 stroke.Parent = bg
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -8, 1, -6)
	lbl.Position = UDim2.new(0, 4, 0, 3)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bg
end

-- A decorative city tower (parody brand) lining the plaza edges.
local function buildTower(x, z, w, h, d, color, name, signColor)
	local tower = block(hubFolder, Vector3.new(w, h, d),
		HUB_ORIGIN + Vector3.new(x, h / 2, z), color, Enum.Material.SmoothPlastic, true)
	neonSign(tower, name, signColor, Enum.NormalId.Front)
	neonSign(tower, name, signColor, Enum.NormalId.Back)
	-- a few lit "windows"
	for _ = 1, 6 do
		local wy = math.random(6, math.max(7, h - 6))
		block(hubFolder, Vector3.new(w * 0.7, 2, 0.4),
			HUB_ORIGIN + Vector3.new(x, wy, z - d / 2 - 0.1),
			Color3.fromRGB(120, 200, 255), Enum.Material.Neon, false)
	end
	return tower
end

-- A clickable kiosk that opens a client panel (tagged "HubKiosk" + Panel attribute).
local function buildKiosk(x, z, color, title, signColor, panelName)
	local booth = block(hubFolder, Vector3.new(12, 9, 10),
		HUB_ORIGIN + Vector3.new(x, 4.5, z), color, Enum.Material.SmoothPlastic, true)
	booth.Name = "HubKiosk"
	block(hubFolder, Vector3.new(14, 1.2, 12),
		HUB_ORIGIN + Vector3.new(x, 9.4, z), signColor, Enum.Material.SmoothPlastic, true)
	neonSign(booth, title, signColor, Enum.NormalId.Front)

	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 26
	cd.Parent = booth
	booth:SetAttribute("Panel", panelName)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 170, 0, 34)
	bb.StudsOffset = Vector3.new(0, 6.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 70
	bb.Adornee = booth
	bb.Parent = booth
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = title
	lbl.TextColor3 = signColor
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.4
	lbl.Parent = bb

	CollectionService:AddTag(booth, "HubKiosk")
	return booth
end

local function buildStadiumPad(x, z)
	local pad = block(hubFolder, Vector3.new(10, 1.2, 10),
		HUB_ORIGIN + Vector3.new(x, 0.6, z), Color3.fromRGB(120, 230, 140), Enum.Material.Neon, true)
	pad.Name = "ToStadiumPad"
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 180, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.Adornee = pad
	bb.Parent = pad
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🏟 Back to my Stadium"
	lbl.TextColor3 = Color3.fromRGB(150, 255, 170)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0.4
	lbl.Parent = bb
	CollectionService:AddTag(pad, "ToStadiumPad")
end

-- A shared Kart Garage pad (KartService wires the "KartSpawner" tag; no Owner =
-- anyone may spawn THEIR kart here).
local function buildKartGarage(x, z)
	local pad = block(hubFolder, Vector3.new(10, 1.2, 10),
		HUB_ORIGIN + Vector3.new(x, 0.6, z), Color3.fromRGB(90, 200, 255), Enum.Material.Neon, true)
	pad.Name = "KartStation"
	local cd = Instance.new("ClickDetector")
	cd.Name = "KartClick"
	cd.MaxActivationDistance = 26
	cd.Parent = pad
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 170, 0, 34)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 70
	bb.Adornee = pad
	bb.Parent = pad
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🏎 Kart Garage"
	lbl.TextColor3 = Color3.fromRGB(150, 235, 255)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb
	CollectionService:AddTag(pad, "KartSpawner")
end

-- ─── build the hub ──────────────────────────────────────────────────────────

local function build()
	hubFolder = Instance.new("Model")
	hubFolder.Name = "BrainrotCity"

	-- Plaza floor
	block(hubFolder, Vector3.new(PLAZA, 4, PLAZA), HUB_ORIGIN + Vector3.new(0, -2, 0),
		Color3.fromRGB(58, 60, 70), Enum.Material.Concrete, true)
	-- Plaza centre tint (the arena floor)
	block(hubFolder, Vector3.new(ARENA_R * 2 + 8, 0.4, ARENA_R * 2 + 8), HUB_ORIGIN + Vector3.new(0, 0.2, 0),
		Color3.fromRGB(38, 40, 52), Enum.Material.SmoothPlastic, false)
	-- Arena ring marking
	for i = 0, 47 do
		local a = (i / 48) * math.pi * 2
		block(hubFolder, Vector3.new(2, 0.5, 2),
			HUB_ORIGIN + Vector3.new(math.cos(a) * ARENA_R, 0.3, math.sin(a) * ARENA_R),
			Color3.fromRGB(255, 210, 70), Enum.Material.Neon, false)
	end

	-- Arena title sign on a central pillar
	local pillar = block(hubFolder, Vector3.new(6, 22, 6), HUB_ORIGIN + Vector3.new(0, 11, 38),
		Color3.fromRGB(30, 32, 44), Enum.Material.Metal, true)
	neonSign(pillar, "⚡ BRAINROT ARENA", Color3.fromRGB(255, 210, 70), Enum.NormalId.Back)

	-- City skyline around the edges (parody brands only)
	local edge = PLAZA / 2 - 14
	buildTower(-edge,  edge, 30, 70, 26, Color3.fromRGB(54, 58, 80),  "BRAINROT TOWER", Color3.fromRGB(255, 90, 90))
	buildTower(  0,    edge, 34, 54, 26, Color3.fromRGB(60, 52, 70),  "OHIO PLAZA",     Color3.fromRGB(120, 220, 255))
	buildTower( edge,  edge, 30, 80, 26, Color3.fromRGB(48, 60, 64),  "SUS BANK HQ",    Color3.fromRGB(120, 230, 140))
	buildTower(-edge,  0,    26, 46, 30, Color3.fromRGB(64, 54, 48),  "RIZZ MALL",      Color3.fromRGB(255, 180, 70))
	buildTower( edge,  0,    26, 60, 30, Color3.fromRGB(50, 50, 66),  "GOBLINPAY",      Color3.fromRGB(180, 130, 255))

	-- Kiosks (reuse existing screens) + garage, along the south side near spawn
	buildKiosk(-44, -edge + 18, Color3.fromRGB(40, 90, 160), "💎 GEM SHOP", Color3.fromRGB(120, 200, 255), "ShopScreen")
	buildKiosk(-14, -edge + 18, Color3.fromRGB(150, 70, 70), "📦 PACKS",    Color3.fromRGB(255, 150, 80),  "ShopScreen")
	buildKiosk( 16, -edge + 18, Color3.fromRGB(60, 120, 90), "🔄 TRADE",    Color3.fromRGB(120, 230, 160), "TradeScreen")
	buildKartGarage(48, -edge + 18)

	-- Travel-home pads flanking the spawn
	buildStadiumPad(-20, -edge + 4)
	buildStadiumPad( 20, -edge + 4)

	-- Spawn point (arrive facing the arena/north)
	local spawnPos = HUB_ORIGIN + Vector3.new(0, 3, -edge + 4)
	hubSpawnCFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 1))

	hubFolder.Parent = Workspace
end

-- ─── teleports ───────────────────────────────────────────────────────────────

local teleportDebounce = {}

local function canTeleport(player)
	local now = os.clock()
	if (teleportDebounce[player.UserId] or 0) > now then return false end
	teleportDebounce[player.UserId] = now + 3
	return true
end

local function wireCityPad(pad)
	pad.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player or not hubSpawnCFrame then return end
		if not canTeleport(player) then return end
		char:PivotTo(hubSpawnCFrame)
		notify(player, "🏙 Welcome to Brainrot City!", "gold")
	end)
end

local function wireStadiumPad(pad)
	pad.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		if not canTeleport(player) then return end
		local cf = PlotService.getSpawnCFrame(player)
		if cf then char:PivotTo(cf + Vector3.new(0, 3, 0)) end
	end)
end

-- ─── arena coin-task event ─────────────────────────────────────────────────────

local function countOrbs()
	local n = 0
	for _, c in ipairs(hubFolder:GetChildren()) do
		if c.Name == "CoinOrb" then n += 1 end
	end
	return n
end

local function spawnCoinOrb()
	local angle = math.random() * math.pi * 2
	local dist  = math.random(6, ARENA_R - 4)
	local pos   = HUB_ORIGIN + Vector3.new(math.cos(angle) * dist, 3.5, math.sin(angle) * dist)

	local orb = Instance.new("Part")
	orb.Name        = "CoinOrb"
	orb.Shape       = Enum.PartType.Ball
	orb.Size        = Vector3.new(3.2, 3.2, 3.2)
	orb.Position    = pos
	orb.Anchored    = true
	orb.CanCollide  = false
	orb.Material    = Enum.Material.Neon
	orb.Color       = Color3.fromRGB(255, 205, 55)
	orb.Parent      = hubFolder

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 60, 0, 60)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.Adornee = orb
	bb.Parent = orb
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "💰"
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb

	local reward  = math.random(500, 2500)
	local claimed = false
	orb.Touched:Connect(function(hit)
		if claimed then return end
		local player = Players:GetPlayerFromCharacter(hit and hit.Parent)
		if not player then return end
		claimed = true
		EconomyService.addCoins(player, reward)
		pushProfile(player)
		notify(player, "💰 Arena coin! +" .. reward, "gold")
		orb:Destroy()
	end)

	task.delay(22, function()
		if orb and orb.Parent then orb:Destroy() end
	end)
end

local function eventLoop()
	while true do
		task.wait(7)
		if #Players:GetPlayers() == 0 then continue end
		if countOrbs() < 14 then
			for _ = 1, math.random(2, 4) do
				spawnCoinOrb()
			end
		end
	end
end

-- ─── init ──────────────────────────────────────────────────────────────────────

function HubService.init()
	build()

	for _, pad in ipairs(CollectionService:GetTagged("ToCityPad")) do task.spawn(wireCityPad, pad) end
	CollectionService:GetInstanceAddedSignal("ToCityPad"):Connect(function(pad) task.spawn(wireCityPad, pad) end)

	for _, pad in ipairs(CollectionService:GetTagged("ToStadiumPad")) do task.spawn(wireStadiumPad, pad) end
	CollectionService:GetInstanceAddedSignal("ToStadiumPad"):Connect(function(pad) task.spawn(wireStadiumPad, pad) end)

	task.spawn(eventLoop)
end

return HubService
