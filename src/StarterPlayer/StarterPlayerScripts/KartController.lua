-- KartController: drives the local player's arcade kart while they're seated in it.
--
-- Reads WASD/arrows each RenderStepped and steers the kart by setting its
-- LinearVelocity (planar drive + hover-height hold) and AlignOrientation (heading).
-- The server hands this client network ownership of the kart on sit, so these
-- writes replicate. Orientation is locked level, so the kart never tips; the hover
-- term holds it just above the (flat) plot floor, so it never falls through.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local KartController = {}

local driveConn = nil
local heading   = 0

local function stopDriving()
	if driveConn then
		driveConn:Disconnect()
		driveConn = nil
	end
end

local function startDriving(seat)
	local chassis = seat
	local drive = chassis:FindFirstChild("Drive")
	local face  = chassis:FindFirstChild("Face")
	if not drive or not face then return end

	local maxSpeed = chassis:GetAttribute("MaxSpeed") or 48
	local turnRate = chassis:GetAttribute("TurnRate") or 2.3
	local hoverY   = chassis:GetAttribute("HoverY") or chassis.Position.Y

	-- Initialise heading from the current facing so it doesn't snap on entry.
	local _, hy = chassis.CFrame:ToOrientation()
	heading = hy

	stopDriving()
	driveConn = RunService.RenderStepped:Connect(function(dt)
		if not seat.Parent or seat.Occupant == nil then
			stopDriving()
			return
		end

		local throttle, steer = 0, 0
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then throttle += 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then throttle -= 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer    += 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then steer    -= 1 end

		-- Turn: full rate when moving, a slower pivot when nearly stopped.
		local moving = math.abs(throttle) > 0.05
		heading = heading - steer * turnRate * dt * (moving and 1 or 0.5)

		local look   = CFrame.fromOrientation(0, heading, 0).LookVector
		local planar = look * (throttle * maxSpeed)
		local yVel   = math.clamp((hoverY - chassis.Position.Y) * 10, -60, 60)
		drive.VectorVelocity = Vector3.new(planar.X, yVel, planar.Z)
		face.CFrame = CFrame.fromOrientation(0, heading, 0)
	end)
end

function KartController.init(_clientState)
	local function hookCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end
		humanoid.Seated:Connect(function(active, seat)
			stopDriving()                       -- always end the previous drive loop
			if not active then return end
			if not (seat and seat:IsA("VehicleSeat")) then return end
			local model = seat.Parent
			if not (model and model:GetAttribute("Kart")) then return end
			-- Wait for the Owner reference to resolve (it can land a beat after the
			-- kart replicates — checking too early was making driving silently fail).
			local owner = model:FindFirstChild("Owner") or model:WaitForChild("Owner", 5)
			local tries = 0
			while owner and owner.Value == nil and tries < 50 do
				task.wait(0.1)
				tries += 1
			end
			if owner and owner.Value == LocalPlayer and humanoid.SeatPart == seat then
				startDriving(seat)
			end
		end)
	end

	if LocalPlayer.Character then
		task.spawn(hookCharacter, LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(hookCharacter)
end

return KartController
