-- HubController: wires the Brainrot City kiosks (tagged "HubKiosk") so clicking one
-- opens the matching panel ScreenGui locally. ClickDetector.MouseClick fires on the
-- client, so no remote is needed.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local HubController = {}

-- Panel LocalScripts share their name with the ScreenGui they create, so resolve
-- the real ScreenGui (a plain FindFirstChild can return the script).
local function findScreenGui(name)
	for _, c in ipairs(PlayerGui:GetChildren()) do
		if c:IsA("ScreenGui") and c.Name == name then return c end
	end
	return nil
end

local PANELS = {
	"ShopScreen", "CollectionScreen", "SquadBuilderScreen", "BracketScreen",
	"TradeScreen", "BattlePassScreen", "PackOpenScreen", "DailyRewardScreen",
}

local function openPanel(target)
	for _, name in ipairs(PANELS) do
		local s = findScreenGui(name)
		if s then s.Enabled = (name == target) end
	end
end

local wired = setmetatable({}, { __mode = "k" })

local function wireKiosk(part)
	if wired[part] then return end
	wired[part] = true

	local cd = part:FindFirstChildOfClass("ClickDetector")
	local tries = 0
	while not cd and tries < 50 do
		task.wait(0.1)
		cd = part:FindFirstChildOfClass("ClickDetector")
		tries += 1
	end
	if not cd then return end

	cd.MouseClick:Connect(function(clicker)
		if clicker ~= LocalPlayer then return end
		local panel = part:GetAttribute("Panel")
		if panel then openPanel(panel) end
	end)
end

function HubController.init(_clientState)
	for _, k in ipairs(CollectionService:GetTagged("HubKiosk")) do
		task.spawn(wireKiosk, k)
	end
	CollectionService:GetInstanceAddedSignal("HubKiosk"):Connect(function(k)
		task.spawn(wireKiosk, k)
	end)
end

return HubController
