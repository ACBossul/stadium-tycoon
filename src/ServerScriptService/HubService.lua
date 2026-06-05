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
local KartCosmetics  = require(ReplicatedStorage.Config.KartCosmetics)

local HubService = {}

local HUB_ORIGIN = Vector3.new(0, 0, -700)   -- well clear of the plot row (along +X)
local PLAZA      = 280
local ARENA_R    = 40

local hubFolder
local hubSpawnCFrame
local kothPad

-- Live arena-event state (a cycle of football-themed events runs in the centre).
local currentEvent            -- id of the active event, or nil during intermission
local eventBannerL1, eventBannerL2   -- the jumbotron labels (set in build())

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
	-- flat roof + sign band
	block(hubFolder, Vector3.new(14, 1.2, 12),
		HUB_ORIGIN + Vector3.new(x, 9.4, z), signColor, Enum.Material.SmoothPlastic, true)
	-- storefront detailing on the FRONT (+Z) face the players approach from
	block(hubFolder, Vector3.new(13, 0.8, 4),                      -- awning
		HUB_ORIGIN + Vector3.new(x, 8.2, z + 6.2), signColor, Enum.Material.SmoothPlastic, false)
	block(hubFolder, Vector3.new(10.5, 4.4, 0.5),                  -- glass display front
		HUB_ORIGIN + Vector3.new(x, 4.8, z + 5.1), Color3.fromRGB(185, 218, 245), Enum.Material.Glass, true)
	block(hubFolder, Vector3.new(11.5, 1.4, 2.4),                  -- counter
		HUB_ORIGIN + Vector3.new(x, 2.3, z + 5.9), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks, true)
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

-- A simple static display kart (decoration) coloured to a skin, posed on a CFrame.
local function buildDisplayKart(cf, body, accent, neon)
	local function bp(size, off, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true; p.CanCollide = false
		p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.CFrame = cf * CFrame.new(off)
		p.Parent = hubFolder
		return p
	end
	bp(Vector3.new(4.6, 1.2, 8),   Vector3.new(0, 0, 0),       body)                          -- floor pan
	bp(Vector3.new(4, 1, 2.4),     Vector3.new(0, 0.1, -4.2),  body)                          -- nose
	bp(Vector3.new(4, 2.4, 0.8),   Vector3.new(0, 1.3, 3.2),   accent)                        -- seat back
	bp(Vector3.new(4.1, 0.5, 0.5), Vector3.new(0, 2.6, 2.6),   accent, neon and Enum.Material.Neon or Enum.Material.Metal)  -- roll bar
	for _, wx in ipairs({ -2.6, 2.6 }) do
		for _, wz in ipairs({ -2.8, 2.8 }) do
			bp(Vector3.new(1, 2.4, 2.4), Vector3.new(wx, -0.5, wz), Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end
end

-- A drive-in garage in the city: preview every kart skin on a display kart, then
-- click its pedestal to buy/equip (KartCustomizeService handles the purchase).
local function buildCustomizeGarage()
	local GX, GZ = 0, -84              -- garage centre (local to HUB_ORIGIN), opens north (+Z)
	local W, D, H = 48, 28, 15         -- sized to sit clear of the south skyline towers
	local wallC = Color3.fromRGB(54, 58, 70)

	block(hubFolder, Vector3.new(W, 1, D),  HUB_ORIGIN + Vector3.new(GX, 0.5, GZ), Color3.fromRGB(46, 48, 58), Enum.Material.Concrete, true)         -- floor
	block(hubFolder, Vector3.new(W, H, 2),  HUB_ORIGIN + Vector3.new(GX, H/2, GZ - D/2), wallC, Enum.Material.Concrete, true)                         -- back wall
	block(hubFolder, Vector3.new(2, H, D),  HUB_ORIGIN + Vector3.new(GX - W/2, H/2, GZ), wallC, Enum.Material.Concrete, true)                         -- west wall
	block(hubFolder, Vector3.new(2, H, D),  HUB_ORIGIN + Vector3.new(GX + W/2, H/2, GZ), wallC, Enum.Material.Concrete, true)                         -- east wall
	block(hubFolder, Vector3.new(W+2, 2, D),HUB_ORIGIN + Vector3.new(GX, H, GZ), Color3.fromRGB(38, 40, 50), Enum.Material.Metal, true)               -- roof
	local header = block(hubFolder, Vector3.new(W, 5, 1.5), HUB_ORIGIN + Vector3.new(GX, H - 2, GZ + D/2), Color3.fromRGB(18, 20, 28), Enum.Material.SmoothPlastic, true)
	neonSign(header, "🛺 KART GARAGE — drive in & customise", Color3.fromRGB(120, 230, 255), Enum.NormalId.Back)   -- faces +Z (the entrance)

	local skins = KartCosmetics.Skins
	local n = #skins
	for i, skin in ipairs(skins) do
		local px = GX - (W/2 - 7) + ((W - 14) / (n - 1)) * (i - 1)
		local pz = GZ - 7

		block(hubFolder, Vector3.new(6, 1.6, 6), HUB_ORIGIN + Vector3.new(px, 1.3, pz), Color3.fromRGB(72, 76, 90), Enum.Material.Concrete, true)   -- pedestal
		local kartCF = CFrame.new(HUB_ORIGIN + Vector3.new(px, 3.5, pz)) * CFrame.Angles(0, math.rad(180), 0)   -- nose faces +Z (the viewer)
		buildDisplayKart(kartCF, skin.body, skin.accent, skin.vip)

		local hit = block(hubFolder, Vector3.new(6.4, 0.6, 6.4), HUB_ORIGIN + Vector3.new(px, 2.3, pz), Color3.fromRGB(96, 100, 116), Enum.Material.Neon, false)
		hit.Name = "KartSkinPedestal"
		hit:SetAttribute("Skin", skin.id)
		local cd = Instance.new("ClickDetector")
		cd.Name = "SkinClick"; cd.MaxActivationDistance = 18; cd.Parent = hit

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 160, 0, 52); bb.StudsOffset = Vector3.new(0, 6.5, 0)
		bb.AlwaysOnTop = true; bb.MaxDistance = 90; bb.Adornee = hit; bb.Parent = hit
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
		lbl.Text = (skin.vip and "⭐ " or "") .. skin.name .. "\n"
			.. (skin.vip and "VIP only" or (skin.cost > 0 and ("💰 " .. skin.cost) or "FREE"))
		lbl.TextColor3 = skin.vip and Color3.fromRGB(255, 215, 120) or Color3.fromRGB(235, 235, 245)
		lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold; lbl.TextStrokeTransparency = 0.4; lbl.Parent = bb

		CollectionService:AddTag(hit, "KartSkinPedestal")
	end
end

-- ─── build the hub ──────────────────────────────────────────────────────────

local function build()
	hubFolder = Instance.new("Model")
	hubFolder.Name = "BrainrotCity"

	-- One big shared ground CENTRED on the city, covering the whole 5x5 plot ring —
	-- no floating islands, drive anywhere. Top y = -0.2 so plot pads read as the
	-- play surface. Centre/extent must match PlotService.PLOT_SLOTS (city at
	-- z=-700, plots out to ±600 → ±690 with margin).
	local ground = block(hubFolder, Vector3.new(1560, 4, 1560), Vector3.new(0, -2.2, HUB_ORIGIN.Z),
		Color3.fromRGB(74, 110, 74), Enum.Material.Grass, true)
	applyTexture(ground, TEXTURES.grass, 48, { Enum.NormalId.Top })

	-- Road GRID: streets run between every row/column of plots and frame the central
	-- city, so every plot — on any side — has a clear, connected drive to the centre.
	local function road(cx, cz, sx, sz)
		local r = block(hubFolder, Vector3.new(sx, 0.3, sz), Vector3.new(cx, 0.05, cz),
			Color3.fromRGB(48, 50, 58), Enum.Material.Asphalt, false)
		applyTexture(r, TEXTURES.asphalt, 18, { Enum.NormalId.Top })
	end
	local GRID_LEN = 1500
	local STREETS = { -450, -150, 150, 450 }
	for _, cx in ipairs(STREETS) do
		road(cx, HUB_ORIGIN.Z, 50, GRID_LEN)              -- north-south streets
	end
	for _, off in ipairs(STREETS) do
		road(0, HUB_ORIGIN.Z + off, GRID_LEN, 50)         -- east-west streets
	end

	-- Road markings: dashed yellow centre lines, white edge lines + zebra
	-- crosswalks at the central intersections, so the streets read as real roads.
	local YEL, WHT = Color3.fromRGB(240, 215, 70), Color3.fromRGB(235, 238, 245)
	local zc = HUB_ORIGIN.Z
	local function paint(sx, sz, x, z, color)
		block(hubFolder, Vector3.new(sx, 0.34, sz), Vector3.new(x, 0.09, z), color, Enum.Material.SmoothPlastic, false)
	end
	for _, cx in ipairs(STREETS) do
		for z = zc - GRID_LEN/2 + 24, zc + GRID_LEN/2 - 24, 42 do paint(2, 11, cx, z, YEL) end
		paint(1.2, GRID_LEN, cx - 22, zc, WHT); paint(1.2, GRID_LEN, cx + 22, zc, WHT)
	end
	for _, off in ipairs(STREETS) do
		local cz = zc + off
		for x = -GRID_LEN/2 + 24, GRID_LEN/2 - 24, 42 do paint(11, 2, x, cz, YEL) end
		paint(GRID_LEN, 1.2, 0, cz - 22, WHT); paint(GRID_LEN, 1.2, 0, cz + 22, WHT)
	end
	for _, cx in ipairs({ -150, 150 }) do
		for _, off in ipairs({ -150, 150 }) do
			for i = -2, 2 do paint(3.5, 16, cx + i * 7, zc + off, WHT) end   -- zebra crossing
		end
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
	kl2.Text = "active during 👑 events"; kl2.TextColor3 = Color3.fromRGB(220, 220, 235)
	kl2.TextScaled = true; kl2.Font = Enum.Font.Gotham; kl2.Parent = kbb

	-- ── Event jumbotron: a tall screen above the arena announcing the live event. ──
	block(hubFolder, Vector3.new(2.5, 32, 2.5), HUB_ORIGIN + Vector3.new(0, 16, 0), Color3.fromRGB(40,44,56), Enum.Material.Metal, false)
	local jumbo = block(hubFolder, Vector3.new(2, 2, 2), HUB_ORIGIN + Vector3.new(0, 35, 0), Color3.fromRGB(10,12,18), Enum.Material.SmoothPlastic, false)
	jumbo.Transparency = 1
	local jbb = Instance.new("BillboardGui")
	jbb.Size = UDim2.new(0, 380, 0, 116); jbb.StudsOffset = Vector3.new(0, 4, 0); jbb.AlwaysOnTop = true; jbb.MaxDistance = 1200; jbb.Adornee = jumbo; jbb.Parent = jumbo
	local jframe = Instance.new("Frame")
	jframe.Size = UDim2.new(1,0,1,0); jframe.BackgroundColor3 = Color3.fromRGB(12,14,22); jframe.BackgroundTransparency = 0.18; jframe.BorderSizePixel = 0; jframe.Parent = jbb
	local jc = Instance.new("UICorner") jc.CornerRadius = UDim.new(0,12) jc.Parent = jframe
	eventBannerL1 = Instance.new("TextLabel")
	eventBannerL1.Size = UDim2.new(1,-12,0.6,0); eventBannerL1.Position = UDim2.new(0,6,0,4); eventBannerL1.BackgroundTransparency = 1
	eventBannerL1.Text = "⚡ ARENA EVENTS"; eventBannerL1.TextColor3 = Color3.fromRGB(255,210,80); eventBannerL1.TextScaled = true; eventBannerL1.Font = Enum.Font.GothamBlack; eventBannerL1.Parent = jframe
	eventBannerL2 = Instance.new("TextLabel")
	eventBannerL2.Size = UDim2.new(1,-12,0.36,0); eventBannerL2.Position = UDim2.new(0,6,0.62,0); eventBannerL2.BackgroundTransparency = 1
	eventBannerL2.Text = "next event soon…"; eventBannerL2.TextColor3 = Color3.fromRGB(220,220,235); eventBannerL2.TextScaled = true; eventBannerL2.Font = Enum.Font.GothamBold; eventBannerL2.Parent = jframe

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

	-- Drive-in kart customisation garage (south side of the plaza).
	buildCustomizeGarage()

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

	-- ── Environment: sky + a vast surrounding plain + a perimeter border wall, so
	-- the world reads as a real place instead of a floating island. ──
	local Lighting = game:GetService("Lighting")
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Density = 0.32; atmo.Offset = 0.1; atmo.Haze = 1.9; atmo.Glare = 0.2
		atmo.Color = Color3.fromRGB(199, 215, 235); atmo.Decay = Color3.fromRGB(106, 134, 168)
		atmo.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky"); sky.Name = "StadiumSky"; sky.Parent = Lighting
	end
	Lighting.ClockTime = 14; Lighting.Brightness = 2.4

	-- A huge low plain extending to the horizon (no more void under the edges).
	local plain = block(hubFolder, Vector3.new(6500, 10, 6500), HUB_ORIGIN + Vector3.new(0, -6, 0),
		Color3.fromRGB(58, 96, 60), Enum.Material.Grass, true)
	applyTexture(plain, TEXTURES.grass, 120, { Enum.NormalId.Top })

	-- Tall perimeter border wall enclosing the whole play area.
	local B, H = 745, 60
	local function borderWall(sx, sz, x, z)
		block(hubFolder, Vector3.new(sx, H, sz), HUB_ORIGIN + Vector3.new(x, H/2, z),
			Color3.fromRGB(46, 50, 64), Enum.Material.Concrete, true)
		block(hubFolder, Vector3.new(sx + 2, 2.5, sz + 2), HUB_ORIGIN + Vector3.new(x, H, z),
			Color3.fromRGB(120, 200, 255), Enum.Material.Neon, false)   -- glowing top trim
	end
	borderWall(2*B + 10, 10, 0,  B)
	borderWall(2*B + 10, 10, 0, -B)
	borderWall(10, 2*B, B, 0)
	borderWall(10, 2*B, -B, 0)

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

	local reward  = math.random(120, 420)
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

-- ─── event cycle: a rotation of announced, football-themed arena events ─────────

local function notifyAll(msg, color)
	for _, p in ipairs(Players:GetPlayers()) do notify(p, msg, color) end
end
local function setBanner(l1, l2)
	if eventBannerL1 then eventBannerL1.Text = l1 end
	if eventBannerL2 then eventBannerL2.Text = l2 end
end

local EVENTS = {
	{ id = "coinrush",   name = "Coin Rush",       emoji = "🪙", dur = 45, blurb = "Coins are raining in the arena — grab them all!" },
	{ id = "koth",       name = "King of the Hill", emoji = "👑", dur = 40, blurb = "Hold the centre spot to bank coins fast!" },
	{ id = "goldengoal", name = "Golden Goal",     emoji = "⚽", dur = 30, blurb = "First to touch the golden ball wins a JACKPOT!" },
	{ id = "fanfrenzy",  name = "Fan Frenzy",      emoji = "📣", dur = 40, blurb = "The crowd's going wild — everyone in the arena earns!" },
}

-- Golden Goal: a big golden ball; first touch wins a jackpot + ends the event.
local function spawnGoldenGoal()
	local ball = Instance.new("Part")
	ball.Name = "GoldenGoal"; ball.Shape = Enum.PartType.Ball; ball.Size = Vector3.new(5.5, 5.5, 5.5)
	ball.Position = HUB_ORIGIN + Vector3.new(0, 4, 0); ball.Anchored = true; ball.CanCollide = false
	ball.Material = Enum.Material.Neon; ball.Color = Color3.fromRGB(255, 215, 60); ball.Parent = hubFolder
	local bb = Instance.new("BillboardGui") bb.Size = UDim2.new(0,80,0,40); bb.StudsOffset = Vector3.new(0,4,0); bb.AlwaysOnTop = true; bb.MaxDistance = 200; bb.Adornee = ball; bb.Parent = ball
	local l = Instance.new("TextLabel") l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = "⚽ JACKPOT!"; l.TextColor3 = Color3.fromRGB(255,235,120); l.TextScaled = true; l.Font = Enum.Font.GothamBlack; l.Parent = bb
	local claimed = false
	ball.Touched:Connect(function(hit)
		if claimed then return end
		local plr = Players:GetPlayerFromCharacter(hit and hit.Parent)
		if not plr then return end
		claimed = true
		EconomyService.addCoins(plr, 50000); pushProfile(plr)
		notifyAll("⚽ " .. plr.DisplayName .. " scored the GOLDEN GOAL! +50,000", "gold")
		ball:Destroy()
		currentEvent = nil   -- ends the event early
	end)
	task.delay(35, function() if ball and ball.Parent then ball:Destroy() end end)
end

-- Coin-rush orb spawner (only while Coin Rush is live).
local function orbLoop()
	while true do
		task.wait(2.4)
		if currentEvent == "coinrush" and #Players:GetPlayers() > 0 and countOrbs() < 12 then
			for _ = 1, 2 do spawnCoinOrb() end
		end
	end
end

-- Earning loop for King-of-the-Hill (centre pad) + Fan Frenzy (anywhere in arena).
local function earnLoop()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx, dz = hrp.Position.X - HUB_ORIGIN.X, hrp.Position.Z - HUB_ORIGIN.Z
				local d2 = dx * dx + dz * dz
				if currentEvent == "koth" and d2 <= 49 and math.abs(hrp.Position.Y - HUB_ORIGIN.Y) < 12 then
					EconomyService.addCoins(player, 80); pushProfile(player)
				elseif currentEvent == "fanfrenzy" and d2 <= (ARENA_R + 12) ^ 2 then
					EconomyService.addCoins(player, 60); pushProfile(player)
				end
			end
		end
	end
end

-- The cycle manager: announce each event, run it, brief intermission, repeat.
local function eventManager()
	local idx = 0
	while true do
		currentEvent = nil
		setBanner("⚡ ARENA EVENTS", "next event soon…")
		task.wait(10)
		if #Players:GetPlayers() == 0 then continue end
		idx = idx % #EVENTS + 1
		local ev = EVENTS[idx]
		currentEvent = ev.id
		notifyAll("📣 EVENT: " .. ev.emoji .. " " .. ev.name .. " — " .. ev.blurb, "gold")
		if ev.id == "goldengoal" then spawnGoldenGoal() end
		local t = ev.dur
		while t > 0 and currentEvent == ev.id do
			setBanner(ev.emoji .. "  NOW: " .. ev.name, t .. "s left")
			task.wait(1); t -= 1
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

	task.spawn(orbLoop)
	task.spawn(earnLoop)
	task.spawn(eventManager)
end

return HubService
