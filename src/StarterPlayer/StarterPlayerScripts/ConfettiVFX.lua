-- ConfettiVFX: lightweight, upload-free GUI confetti burst for celebrations
-- (Mythic/Legendary pulls, match wins). Pure Frames + tweens; no assets.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

local ConfettiVFX = {}

local LocalPlayer = Players.LocalPlayer

local COLORS = {
	Color3.fromRGB(255, 87, 87),
	Color3.fromRGB(255, 200, 50),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(200, 100, 255),
	Color3.fromRGB(255, 255, 255),
}

local function vfxLayer()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("VFXGui")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name          = "VFXGui"
		gui.ResetOnSpawn  = false
		gui.DisplayOrder  = 50
		gui.IgnoreGuiInset = true
		gui.Parent        = pg
	end
	return gui
end

-- opts = { count = number, origin = Vector2(scale x, scale y), spread = number }
function ConfettiVFX.burst(opts)
	opts = opts or {}
	local count  = opts.count or 44
	local origin = opts.origin or Vector2.new(0.5, 0.35)
	local spread = opts.spread or 0.5
	local layer  = vfxLayer()

	for _ = 1, count do
		local piece = Instance.new("Frame")
		local w = math.random(8, 16)
		piece.Size = UDim2.fromOffset(w, w * (math.random() < 0.5 and 1 or 0.55))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(origin.X, origin.Y)
		piece.BackgroundColor3 = COLORS[math.random(#COLORS)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 50
		piece.Parent = layer
		if math.random() < 0.5 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = piece
		end

		local angle   = math.rad(math.random(0, 360))
		local dist     = math.random(15, 100) / 100 * spread
		local targetX = math.clamp(origin.X + math.cos(angle) * dist, -0.1, 1.1)
		local fallY   = origin.Y + math.random(40, 85) / 100
		local dur     = math.random(90, 160) / 100

		TweenService:Create(
			piece,
			TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromScale(targetX, fallY),
				Rotation = piece.Rotation + math.random(-260, 260),
				BackgroundTransparency = 1,
			}
		):Play()

		Debris:AddItem(piece, dur + 0.2)
	end
end

return ConfettiVFX
