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
local kothPad

-- Uploaded surface textures (same decals the plots use).
local TEXTURES = {
	grass   = "rbxassetid://70872978008715",
	brick   = "rbxassetid://100402802088606",
	metal   = "rbxassetid://110788642331092",
	asphalt = "rbxassetid://129383393602486",
}
local ALL_SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local function applyTexture(part, textureId, studs, faces)
	if not part or not textureId then return end
	for _, face in ipairs(faces) do
		local t = Instance.new("Texture")
		t.Texture       = textureId
		t.Face          = face
		t.StudsPerTileU = studs
		t.StudsPerTileV = studs
		t.Parent        = part
	end
end

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
-- A grid of lit/dark window cells across one face (gives the glass-tower look).
local function addWindows(part, face, litColor)
	local sg = Instance.new("SurfaceGui")
	sg.Face          = face
	sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 10
	sg.LightInfluence = 0
	sg.Parent        = part
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.05, 0); pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.08, 0); pad.PaddingRight = UDim.new(0.08, 0)
	pad.Parent = sg
	local grid = Instance.new("UIGridLayout")
	grid.CellSize    = UDim2.new(0.17, 0, 0.07, 0)
	grid.CellPadding = UDim2.new(0.06, 0, 0.035, 0)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = sg
	for _ = 1, 24 do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = (math.random() < 0.5) and litColor or Color3.fromRGB(22, 26, 38)
		cell.BorderSizePixel = 0
		cell.Parent = sg
	end
end

-- A proper skyscraper: stepped setbacks, lit windows, a rooftop mast + beacon, and
-- a small street-level marquee (instead of a flat box with a giant name on it).
local function buildTower(x, z, w, h, d, color, name, accent)
	local function tier(tw, th, td, cy)
		local p = block(hubFolder, Vector3.new(tw, th, td), HUB_ORIGIN + Vector3.new(x, cy, z),
			color, Enum.Material.SmoothPlastic, true)
		applyTexture(p, TEXTURES.metal, 16, ALL_SIDES)
		return p
	end
	local h1, h2, h3 = h * 0.56, h * 0.30, h * 0.14
	local base = tier(w, h1, d, h1 / 2)
	tier(w * 0.78, h2, d * 0.78, h1 + h2 / 2)
	tier(w * 0.56, h3, d * 0.56, h1 + h2 + h3 / 2)

	addWindows(base, Enum.NormalId.Front, accent)
	addWindows(base, Enum.NormalId.Back,  accent)

	-- Rooftop mast + neon beacon.
	block(hubFolder, Vector3.new(0.7, h * 0.16, 0.7), HUB_ORIGIN + Vector3.new(x, h + h * 0.07, z),
		Color3.fromRGB(40, 44, 56), Enum.Material.Metal, false)
	block(hubFolder, Vector3.new(1.6, 1.6, 1.6), HUB_ORIGIN + Vector3.new(x, h + h * 0.16, z),
		accent, Enum.Material.Neon, false)

	-- Small street-level marquee.
	local marquee = block(hubFolder, Vector3.new(w * 0.66, 3.4, 0.5),
		HUB_ORIGIN + Vector3.new(x, 6.5, z - d / 2 - 0.35), Color3.fromRGB(12, 14, 22), Enum.Material.SmoothPlastic, false)
	local msg = Instance.new("SurfaceGui")
	msg.Face = Enum.NormalId.Front; msg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	msg.PixelsPerStud = 28; msg.LightInfluence = 0; msg.Parent = marquee
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
	lbl.Text = name; lbl.TextColor3 = accent; lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold
	lbl.Parent = msg
	return base
end

-- A neon lamppost.
local function buildLamppost(x, z)
	block(hubFolder, Vector3.new(0.8, 14, 0.8), HUB_ORIGIN + Vector3.new(x, 7, z),
		Color3.fromRGB(40, 44, 54), Enum.Material.Metal, false)
	block(hubFolder, Vector3.new(2.6, 1.4, 2.6), HUB_ORIGIN + Vector3.new(x, 14.2, z),
		Color3.fromRGB(255, 240, 180), Enum.Material.Neon, false)
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
	local cd = Instance.new("ClickDetector")
	cd.Name = "StadiumClick"
	cd.MaxActivationDistance = 26
	cd.Parent = pad
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

	-- One big shared ground covering the whole plot GRID (the rectangle of claimable
	-- plots in front of the city) plus the city itself — no floating islands, drive
	-- anywhere. Top y = -0.2 so plot pads read as the play surface. Keep the bounds
	-- in sync with PlotService.PLOT_SLOTS.
	local ground = block(hubFolder, Vector3.new(1760, 4, 1500), Vector3.new(0, -2.2, -200),
		Color3.fromRGB(74, 110, 74), Enum.Material.Grass, true)
	applyTexture(ground, TEXTURES.grass, 48, { Enum.NormalId.Top })

	-- Road network: a central boulevard from the city's north gate up through the
	-- grid, plus an east-west cross street at each row of plots, so every plot —
	-- near or far — has a clear drive to the centre.
	local function road(cx, cz, sx, sz)
		local r = block(hubFolder, Vector3.new(sx, 0.3, sz), Vector3.new(cx, 0.05, cz),
			Color3.fromRGB(48, 50, 58), Enum.Material.Asphalt, false)
		applyTexture(r, TEXTURES.asphalt, 18, { Enum.NormalId.Top })
	end
	road(0, -67, 46, 1018)                       -- central avenue (gate → back of grid)
	for _, cz in ipairs({ -479, -229, 21, 271 }) do
		road(0, cz, 1640, 34)                    -- cross street at each plot row's entrance
	end
	for z = -560, 430, 26 do                     -- dashed centre line up the boulevard
		block(hubFolder, Vector3.new(2, 0.34, 10), Vector3.new(0, 0.08, z),
			Color3.fromRGB(240, 220, 90), Enum.Material.SmoothPlastic, false)
	end

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

	-- Pedestrian bollards just outside the ring: a player squeezes between them, but
	-- a (wider) kart can't pass or hop them — so arena coins are grabbed ON FOOT,
	-- not in a quick drive-through.
	local bollardN, bollardR = 44, ARENA_R + 4
	for i = 0, bollardN - 1 do
		local a = (i / bollardN) * math.pi * 2
		block(hubFolder, Vector3.new(1.6, 5, 1.6),
			HUB_ORIGIN + Vector3.new(math.cos(a) * bollardR, 2.5, math.sin(a) * bollardR),
			Color3.fromRGB(58, 62, 74), Enum.Material.Metal, true)
	end

	-- King-of-the-Hill capture pad at the arena centre: stand on it to earn coins.
	kothPad = block(hubFolder, Vector3.new(11, 1, 11), HUB_ORIGIN + Vector3.new(0, 0.6, 0),
		Color3.fromRGB(255, 120, 200), Enum.Material.Neon, true)
	kothPad.Name = "KothPad"
	local kbb = Instance.new("BillboardGui")
	kbb.Size = UDim2.new(0, 200, 0, 50)
	kbb.StudsOffset = Vector3.new(0, 5, 0)
	kbb.AlwaysOnTop = true
	kbb.MaxDistance = 120
	kbb.Adornee = kothPad
	kbb.Parent = kothPad
	local kl1 = Instance.new("TextLabel")
	kl1.Size = UDim2.new(1, 0, 0.6, 0); kl1.BackgroundTransparency = 1
	kl1.Text = "👑 KING OF THE HILL"; kl1.TextColor3 = Color3.fromRGB(255, 170, 220)
	kl1.TextScaled = true; kl1.Font = Enum.Font.GothamBlack; kl1.TextStrokeTransparency = 0.4; kl1.Parent = kbb
	local kl2 = Instance.new("TextLabel")
	kl2.Size = UDim2.new(1, 0, 0.4, 0); kl2.Position = UDim2.new(0, 0, 0.6, 0); kl2.BackgroundTransparency = 1
	kl2.Text = "stand to earn"; kl2.TextColor3 = Color3.fromRGB(220, 220, 235)
	kl2.TextScaled = true; kl2.Font = Enum.Font.Gotham; kl2.Parent = kbb

	local edge = PLAZA / 2 - 14   -- 126

	-- The NORTH edge faces the road, so it's kept OPEN. The skyline frames the
	-- EAST, WEST and SOUTH edges only (no tower blocking the entrance).
	-- West row
	buildTower(-edge,  edge - 34, 30, 70, 26, Color3.fromRGB(54,58,80), "BRAINROT TOWER", Color3.fromRGB(255,90,90))
	buildTower(-edge,  10,        26, 48, 30, Color3.fromRGB(64,54,48), "RIZZ MALL",      Color3.fromRGB(255,180,70))
	buildTower(-edge, -edge + 30, 28, 60, 26, Color3.fromRGB(58,52,64), "MEME MOBILE",    Color3.fromRGB(255,130,200))
	-- East row
	buildTower( edge,  edge - 34, 30, 80, 26, Color3.fromRGB(48,60,64), "SUS BANK HQ",    Color3.fromRGB(120,230,140))
	buildTower( edge,  10,        26, 58, 30, Color3.fromRGB(50,50,66), "GOBLINPAY",      Color3.fromRGB(180,130,255))
	buildTower( edge, -edge + 30, 28, 50, 26, Color3.fromRGB(52,58,64), "NEON COLA",      Color3.fromRGB(120,255,200))
	-- South backdrop (Ohio Plaza moved here, out of the road's path)
	buildTower(-46, -edge, 26, 46, 24, Color3.fromRGB(60,56,50), "THE GOBLET", Color3.fromRGB(255,215,90))
	buildTower(  0, -edge, 32, 66, 26, Color3.fromRGB(60,52,70), "OHIO PLAZA", Color3.fromRGB(120,220,255))
	buildTower( 46, -edge, 26, 56, 24, Color3.fromRGB(54,50,64), "RIZZ FUEL",  Color3.fromRGB(255,150,90))

	-- North entrance gate: two pillars with a sign arch, OPEN in the middle so the
	-- main street runs straight through.
	block(hubFolder, Vector3.new(6, 20, 6), HUB_ORIGIN + Vector3.new(-26, 10, edge), Color3.fromRGB(40,44,56), Enum.Material.Metal, true)
	block(hubFolder, Vector3.new(6, 20, 6), HUB_ORIGIN + Vector3.new( 26, 10, edge), Color3.fromRGB(40,44,56), Enum.Material.Metal, true)
	local arch = block(hubFolder, Vector3.new(58, 5, 6), HUB_ORIGIN + Vector3.new(0, 20, edge), Color3.fromRGB(36,40,52), Enum.Material.Metal, true)
	neonSign(arch, "🏙 BRAINROT CITY", Color3.fromRGB(255,200,90), Enum.NormalId.Front)

	-- Arena title pillar at the SOUTH end (facing the entrance), out of the way.
	local pillar = block(hubFolder, Vector3.new(6, 22, 6), HUB_ORIGIN + Vector3.new(0, 11, -54),
		Color3.fromRGB(30, 32, 44), Enum.Material.Metal, true)
	neonSign(pillar, "⚡ BRAINROT ARENA", Color3.fromRGB(255, 210, 70), Enum.NormalId.Front)

	-- Kiosks line the entrance avenue (just inside the gate), facing inward.
	buildKiosk(-42, edge - 36, Color3.fromRGB(40,90,160), "💎 GEM SHOP", Color3.fromRGB(120,200,255), "ShopScreen")
	buildKiosk( 42, edge - 36, Color3.fromRGB(150,70,70), "📦 PACKS",    Color3.fromRGB(255,150,80),  "ShopScreen")
	buildKiosk(-42, edge - 72, Color3.fromRGB(60,120,90), "🔄 TRADE",    Color3.fromRGB(120,230,160), "TradeScreen")
	buildKartGarage(42, edge - 72)

	-- Travel-home pads just inside the gate.
	buildStadiumPad(-22, edge - 14)
	buildStadiumPad( 22, edge - 14)

	-- Neon lampposts down the avenue + corners (none at the north-centre gate).
	for _, lp in ipairs({
		{ -52, edge - 20 }, { 52, edge - 20 },
		{ -edge + 6, 0 }, { edge - 6, 0 },
		{ -52, -edge + 16 }, { 52, -edge + 16 },
	}) do
		buildLamppost(lp[1], lp[2])
	end

	-- A lit path from the gate down to the arena centre.
	for z = edge - 18, 18, -16 do
		block(hubFolder, Vector3.new(12, 0.3, 9), HUB_ORIGIN + Vector3.new(0, 0.25, z),
			Color3.fromRGB(74, 78, 92), Enum.Material.SmoothPlastic, false)
	end

	-- Spawn just inside the north gate, facing south into the arena.
	local spawnPos = HUB_ORIGIN + Vector3.new(0, 3, edge - 12)
	hubSpawnCFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, -1))

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
	local cd = pad:FindFirstChildOfClass("ClickDetector") or pad:WaitForChild("CityClick", 10)
	if not cd or not cd:IsA("ClickDetector") then return end
	cd.MouseClick:Connect(function(player)
		if not player or not hubSpawnCFrame then return end
		local data = DataService.getData(player)
		if not (data and data.passes and data.passes.vip) then
			notify(player, "⭐ Instant City travel is VIP-only — or walk/drive there!", "red")
			return
		end
		if not canTeleport(player) then return end
		local char = player.Character
		if char then
			char:PivotTo(hubSpawnCFrame)
			notify(player, "🏙 Welcome to Brainrot City!", "gold")
		end
	end)
end

local function wireStadiumPad(pad)
	local cd = pad:FindFirstChildOfClass("ClickDetector") or pad:WaitForChild("StadiumClick", 10)
	if not cd or not cd:IsA("ClickDetector") then return end
	cd.MouseClick:Connect(function(player)
		if not player then return end
		if not canTeleport(player) then return end
		local char = player.Character
		local cf = PlotService.getSpawnCFrame(player)
		if char and cf then char:PivotTo(cf + Vector3.new(0, 3, 0)) end
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

	local reward  = math.random(300, 1200)
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

	task.delay(16, function()
		if orb and orb.Parent then orb:Destroy() end
	end)
end

local function eventLoop()
	while true do
		task.wait(9)
		if #Players:GetPlayers() == 0 then continue end
		if countOrbs() < 8 then
			for _ = 1, math.random(1, 3) do
				spawnCoinOrb()
			end
		end
	end
end

-- King-of-the-Hill: anyone standing on the centre pad earns a trickle of coins.
local function kothLoop()
	while true do
		task.wait(1)
		if not kothPad then continue end
		local c = kothPad.Position
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx, dz = hrp.Position.X - c.X, hrp.Position.Z - c.Z
				if (dx * dx + dz * dz) <= 49 and math.abs(hrp.Position.Y - c.Y) < 8 then
					EconomyService.addCoins(player, 70)
					pushProfile(player)
				end
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
	task.spawn(kothLoop)
end

return HubService
