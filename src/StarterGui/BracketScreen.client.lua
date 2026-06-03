-- BracketScreen.lua: displays bracket stage, points, countdown, and last result.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)

local gui = Instance.new("ScreenGui")
gui.Name         = "BracketScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 5
gui.Parent       = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundColor3 = Color3.fromRGB(8,8,16)
bg.BorderSizePixel  = 0
bg.Parent = gui

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,44,0,44)
closeBtn.Position = UDim2.new(1,-52,0,8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = bg
local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,8) cc.Parent = closeBtn
closeBtn.Activated:Connect(function() gui.Enabled = false end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,0,50)
title.Position = UDim2.new(0,12,0,8)
title.BackgroundTransparency = 1
title.Text = "🏆  THE BRAINROT CUP"
title.TextColor3 = Color3.fromRGB(255,215,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg

local function makeInfoBlock(name, yPos, defaultText)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(1,-24,0,40)
	label.Position = UDim2.new(0,12,0,yPos)
	label.BackgroundColor3 = Color3.fromRGB(18,18,30)
	label.BorderSizePixel  = 0
	label.Text = defaultText
	label.TextColor3 = Color3.fromRGB(220,220,220)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = bg
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,8) c.Parent = label
	local p = Instance.new("UIPadding") p.PaddingLeft = UDim.new(0,10) p.Parent = label
	return label
end

makeInfoBlock("StageLabel",      70,  "Stage: group")
makeInfoBlock("PointsLabel",    120,  "Points: 0  |  W:0 D:0 L:0")
makeInfoBlock("PowerLabel",     170,  "⚡ Squad Power: 0")
makeInfoBlock("CountdownLabel", 220,  "Next match: loading...")
makeInfoBlock("LastResultLabel",270,  "No matches played yet.")

-- Stage visual progress bar
local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1,-24,0,18)
progressBg.Position = UDim2.new(0,12,0,324)
progressBg.BackgroundColor3 = Color3.fromRGB(30,30,50)
progressBg.BorderSizePixel  = 0
progressBg.Parent = bg
local pbCorner = Instance.new("UICorner") pbCorner.CornerRadius = UDim.new(0,6) pbCorner.Parent = progressBg

local STAGES = {"group","r32","r16","qf","sf","final"}
for i, stage in ipairs(STAGES) do
	local marker = Instance.new("TextLabel")
	marker.Name = "Stage_" .. stage
	marker.Size = UDim2.new(1/#STAGES,0,1,0)
	marker.Position = UDim2.new((i-1)/#STAGES,0,0,0)
	marker.BackgroundColor3 = Color3.fromRGB(40,40,70)
	marker.BorderSizePixel  = 0
	marker.Text = stage:upper()
	marker.TextColor3 = Color3.fromRGB(150,150,180)
	marker.TextScaled = true
	marker.Font = Enum.Font.Gotham
	marker.Parent = progressBg
end

local function updateProgressBar(currentStage)
	for i, stage in ipairs(STAGES) do
		local marker = progressBg:FindFirstChild("Stage_" .. stage)
		if marker then
			if stage == currentStage then
				marker.BackgroundColor3 = Color3.fromRGB(50,180,80)
				marker.TextColor3 = Color3.new(1,1,1)
			elseif i < table.find(STAGES, currentStage) then
				marker.BackgroundColor3 = Color3.fromRGB(30,100,50)
				marker.TextColor3 = Color3.fromRGB(120,200,120)
			else
				marker.BackgroundColor3 = Color3.fromRGB(40,40,70)
				marker.TextColor3 = Color3.fromRGB(150,150,180)
			end
		end
	end
end

-- External update hook (called from UIController on ProfileUpdated)
local module = {}
function module.onProfileUpdated(data)
	if not gui.Enabled then return end
	if not data or not data.bracket then return end

	local b = data.bracket
	local stageLabel  = bg:FindFirstChild("StageLabel")
	local pointsLabel = bg:FindFirstChild("PointsLabel")
	local powerLabel  = bg:FindFirstChild("PowerLabel")

	if stageLabel  then stageLabel.Text  = "Stage: " .. (b.stage or "?") end
	if pointsLabel then
		pointsLabel.Text = string.format(
			"Points: %d  |  W:%d D:%d L:%d",
			b.points or 0, b.wins or 0, b.draws or 0, b.losses or 0
		)
	end

	-- Compute squad power straight from the profile (each card stores its power)
	if powerLabel and data.cards and data.squad then
		local total = 0
		for _, iid in ipairs(data.squad) do
			local card = data.cards[iid]
			if card then total += card.power end
		end
		powerLabel.Text = "⚡ Squad Power: " .. total
	end

	updateProgressBar(b.stage or "group")
end

-- Receive profile data directly from the server.
if Remotes then
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
		module.onProfileUpdated(profile)
	end)
end

return module
