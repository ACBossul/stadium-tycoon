-- KartService: spawnable, rideable arcade karts tied to the Parking Lot.
--
-- Design notes:
--   * The kart is a custom ARCADE vehicle, not Roblox's built-in wheel physics.
--     The chassis is a VehicleSeat with a LinearVelocity (planar drive + hover) and
--     an AlignOrientation (kept upright + faces the heading). The seated player's
--     client owns the assembly and runs the drive loop (KartController) for crisp,
--     lag-free handling. Because orientation is locked upright and the hover height
--     is held by the velocity controller, the kart can't flip or fall through.
--   * Idle karts are Anchored (frozen in place); the kart is unanchored + handed to
--     the driver's client the moment they sit, and re-anchored when they get out.
--   * Tiers: "basic" unlocks once the Parking Lot is built (the grind); "pro" is a
--     faster VIP kart (gated on the VIP game pass).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local DataService = require(ServerScriptService.DataService)

local KartService = {}

local KART_SPECS = {
	basic = {
		displayName = "Street Kart",
		body   = Color3.fromRGB(220, 82, 70),
		accent = Color3.fromRGB(38, 42, 52),
		maxSpeed = 48,
		turnRate = 2.3,
		neon = false,
	},
	pro = {
		displayName = "VIP Turbo Kart",
		body   = Color3.fromRGB(34, 38, 50),
		accent = Color3.fromRGB(120, 232, 255),
		maxSpeed = 76,
		turnRate = 2.7,
		neon = true,
	},
}

-- userId -> { model, chassis, conns = {} }
local activeKarts = {}

local function notify(player, message, color)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event   = remotes and remotes:FindFirstChild("ShowNotification")
	if event then
		event:FireClient(player, { message = message, color = color or "white" })
	end
end

local function clearKart(userId)
	local k = activeKarts[userId]
	if not k then return end
	for _, c in ipairs(k.conns) do
		pcall(function() c:Disconnect() end)
	end
	if k.model then k.model:Destroy() end
	activeKarts[userId] = nil
end

-- ─── Kart model builder ───────────────────────────────────────────────────────

local function buildKart(tier, spawnCFrame, player)
	local spec = KART_SPECS[tier] or KART_SPECS.basic

	local model = Instance.new("Model")
	model.Name = "Kart_" .. player.UserId

	-- Chassis = the VehicleSeat itself (the floor pan you sit on/drive).
	local chassis = Instance.new("VehicleSeat")
	chassis.Name        = "Chassis"
	chassis.Size        = Vector3.new(5, 1.2, 8.5)
	chassis.Anchored    = true              -- frozen until a driver sits
	chassis.CanCollide  = true
	chassis.Color       = spec.body
	chassis.Material    = Enum.Material.SmoothPlastic
	chassis.MaxSpeed    = 0                 -- disable built-in wheel driving; we drive it
	chassis.Torque      = 0
	chassis.TurnSpeed   = 0
	chassis.HeadsUpDisplay = false
	chassis.CFrame      = spawnCFrame
	chassis.TopSurface  = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent      = model
	model.PrimaryPart   = chassis

	local function bolt(name, size, offset, color, material, shape)
		local p = Instance.new("Part")
		p.Name        = name
		p.Size        = size
		p.Color       = color
		p.Material    = material or Enum.Material.SmoothPlastic
		p.CanCollide  = false
		p.Massless    = true
		p.Anchored    = false
		p.TopSurface  = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.CFrame      = spawnCFrame * CFrame.new(offset)
		p.Parent      = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Forward is the seat's LookVector (= local -Z). Nose sits at -Z, seat-back at +Z.
	bolt("Nose",     Vector3.new(4.4, 1.0, 2.6), Vector3.new(0,  0.1, -4.6), spec.body,   Enum.Material.SmoothPlastic)
	bolt("SeatBack", Vector3.new(4.2, 2.6, 0.8), Vector3.new(0,  1.5,  3.4), spec.accent, Enum.Material.SmoothPlastic)
	bolt("RollBarL", Vector3.new(0.5, 3.0, 0.5), Vector3.new(-1.8, 2.0, 3.0), spec.accent, Enum.Material.Metal)
	bolt("RollBarR", Vector3.new(0.5, 3.0, 0.5), Vector3.new( 1.8, 2.0, 3.0), spec.accent, Enum.Material.Metal)
	bolt("RollBarTop", Vector3.new(4.1, 0.5, 0.5), Vector3.new(0, 3.4, 3.0), spec.accent, Enum.Material.Metal)
	local stripe = bolt("Stripe", Vector3.new(1.4, 0.3, 7.0), Vector3.new(0, 0.75, -0.4), spec.accent, Enum.Material.SmoothPlastic)
	stripe.Color = spec.neon and spec.accent or Color3.fromRGB(245, 245, 245)
	if spec.neon then stripe.Material = Enum.Material.Neon end

	-- Wheels (cylinders, axle along local X). Visual only — CanCollide false, Massless.
	local wheelColor = Color3.fromRGB(24, 24, 28)
	local function wheel(x, z)
		local w = bolt("Wheel", Vector3.new(1.0, 2.6, 2.6), Vector3.new(x, -0.5, z), wheelColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		-- a bright hub cap (neon for pro)
		local hub = bolt("Hub", Vector3.new(1.05, 1.0, 1.0), Vector3.new(x, -0.5, z), spec.accent, spec.neon and Enum.Material.Neon or Enum.Material.Metal, Enum.PartType.Cylinder)
		return w, hub
	end
	wheel(-2.7, -2.8)
	wheel( 2.7, -2.8)
	wheel(-2.7,  2.8)
	wheel( 2.7,  2.8)

	-- Control attachment + constraints (set live by the driver's client).
	local root = Instance.new("Attachment")
	root.Name = "Root"
	root.Parent = chassis

	local drive = Instance.new("LinearVelocity")
	drive.Name           = "Drive"
	drive.Attachment0    = root
	drive.RelativeTo     = Enum.ActuatorRelativeTo.World
	drive.MaxForce       = 1e6
	drive.VectorVelocity = Vector3.zero
	drive.Parent         = chassis

	local face = Instance.new("AlignOrientation")
	face.Name           = "Face"
	face.Mode           = Enum.OrientationAlignmentMode.OneAttachment
	face.Attachment0    = root
	face.Responsiveness = 28
	face.MaxTorque      = 1e6
	face.CFrame         = spawnCFrame.Rotation
	face.Parent         = chassis

	-- Tuning + identity surfaced to the client controller.
	chassis:SetAttribute("MaxSpeed", spec.maxSpeed)
	chassis:SetAttribute("TurnRate", spec.turnRate)
	chassis:SetAttribute("HoverY",   spawnCFrame.Position.Y)
	model:SetAttribute("Kart", true)
	model:SetAttribute("Tier", tier)

	local owner = Instance.new("ObjectValue")
	owner.Name  = "Owner"
	owner.Value = player
	owner.Parent = model

	-- Floating nameplate
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 28)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.Adornee = chassis
	bb.Parent = chassis
	local nm = Instance.new("TextLabel")
	nm.Size = UDim2.new(1, 0, 1, 0)
	nm.BackgroundTransparency = 1
	nm.Text = (spec.neon and "⭐ " or "🏎 ") .. spec.displayName
	nm.TextColor3 = spec.neon and Color3.fromRGB(150, 235, 255) or Color3.fromRGB(255, 235, 150)
	nm.TextScaled = true
	nm.Font = Enum.Font.GothamBold
	nm.TextStrokeTransparency = 0.4
	nm.Parent = bb

	CollectionService:AddTag(model, "Kart")
	return model, chassis
end

-- ─── Spawn / occupancy ─────────────────────────────────────────────────────────

function KartService.spawnKart(player)
	local data = DataService.getData(player)
	if not data then return end

	local parkingLevel = (data.stadium and data.stadium.parking) or 0
	if parkingLevel < 1 then
		notify(player, "Build the Parking Lot first to unlock your kart!", "red")
		return
	end

	local character = player.Character
	local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		notify(player, "Respawn before calling your kart.", "red")
		return
	end

	local tier = (data.passes and data.passes.vip) and "pro" or "basic"

	-- Replace any existing kart
	clearKart(player.UserId)

	-- Spawn just in front of the kart station (provided by the caller via attribute)
	local stationPos = player:GetAttribute("KartStationPos")
	local basePos = stationPos and Vector3.new(stationPos.X, stationPos.Y, stationPos.Z)
		or (character:GetPivot().Position + Vector3.new(0, 0, 6))
	-- Hover so the wheels sit just above the (flat, y=0) plot floor.
	local spawnPos = basePos + Vector3.new(0, 1.9, 0)
	local spawnCFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 1))  -- face +Z (into the plot)

	local model, chassis = buildKart(tier, spawnCFrame, player)

	local entry = { model = model, chassis = chassis, conns = {} }
	activeKarts[player.UserId] = entry

	-- Anchor/ownership toggling driven by who is sitting.
	local function onOccupantChanged()
		local occupant = chassis.Occupant
		local sittingPlayer = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if sittingPlayer then
			chassis.Anchored = false
			pcall(function() chassis:SetNetworkOwner(sittingPlayer) end)
		else
			-- Freeze in place when nobody is driving.
			chassis.Anchored = true
			local d = chassis:FindFirstChild("Drive")
			if d then d.VectorVelocity = Vector3.zero end
		end
	end
	table.insert(entry.conns, chassis:GetPropertyChangedSignal("Occupant"):Connect(onOccupantChanged))

	model.Parent = workspace

	-- Seat the owner immediately.
	chassis:Sit(humanoid)

	notify(player, "🏎 " .. (KART_SPECS[tier].displayName) .. " ready! WASD to drive.", "green")
end

function KartService.onPlayerLeave(player)
	clearKart(player.UserId)
end

-- ─── Wiring: kart station click pads (built by PlotService, tagged "KartSpawner") ─

local function wireStation(pad)
	local ownerVal = pad:FindFirstChild("Owner") or pad:WaitForChild("Owner", 15)
	if not ownerVal then return end
	local detector = pad:FindFirstChildOfClass("ClickDetector") or pad:WaitForChild("KartClick", 10)
	if not detector or not detector:IsA("ClickDetector") then
		detector = pad:FindFirstChildOfClass("ClickDetector")
	end
	if not detector then return end

	detector.MouseClick:Connect(function(clicker)
		if clicker ~= ownerVal.Value then return end   -- only the base owner
		-- Stash the station position so the kart spawns right here.
		if pad:IsA("BasePart") then
			clicker:SetAttribute("KartStationPos", pad.Position + Vector3.new(0, 0, 7))
		end
		KartService.spawnKart(clicker)
	end)
end

function KartService.init()
	for _, pad in ipairs(CollectionService:GetTagged("KartSpawner")) do
		task.spawn(wireStation, pad)
	end
	CollectionService:GetInstanceAddedSignal("KartSpawner"):Connect(function(pad)
		task.spawn(wireStation, pad)
	end)
	Players.PlayerRemoving:Connect(KartService.onPlayerLeave)
end

return KartService
