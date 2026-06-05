-- TutorialController: a first-time objective banner that always shows the player's
-- next step, driven by their profile. Hides once the basics are done.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local TutorialController = {}

local gui, label

-- Returns the next uncompleted objective, or nil when the onboarding is done.
local function nextStep(p)
	if not p then return nil end
	local s = p.stadium or {}
	if (s.pitch or 0)       < 1 then return "💰 Tap the EARN button, then BUILD THE PITCH" end
	if (s.lowerstands or 0) < 1 then return "🪑 Build the LOWER STANDS" end
	if (s.stands or 0)      < 1 then return "🏟️ Build the GRANDSTAND" end
	if (s.parking or 0)     < 1 then return "🚗 Build the PARKING LOT (unlocks karts)" end
	if ((p.stats and p.stats.packsOpened) or 0) < 1 then return "🃏 Open a pack in the 🛍 Shop" end
	if not p.squad or #p.squad < 1 then return "⚽ Pick your SQUAD for the Cup" end
	return nil
end

function TutorialController.onProfileUpdated(p)
	if not gui then return end
	local step = nextStep(p)
	if step then
		label.Text = "🎯 NEXT: " .. step
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

function TutorialController.init(_clientState)
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGuide"; gui.ResetOnSpawn = false; gui.DisplayOrder = 8; gui.Enabled = false
	gui.IgnoreGuiInset = true; gui.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 440, 0, 44); frame.Position = UDim2.new(0.5, -220, 0, 92)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32); frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0; frame.Parent = gui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = frame
	local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 210, 80); stroke.Thickness = 2; stroke.Parent = frame

	label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -14, 1, 0); label.Position = UDim2.new(0, 7, 0, 0)
	label.BackgroundTransparency = 1; label.Text = "🎯 NEXT: …"
	label.TextColor3 = Color3.fromRGB(255, 235, 150); label.TextScaled = true
	label.Font = Enum.Font.GothamBold; label.Parent = frame
end

return TutorialController
