-- UIController: manages all GUI screens (HUD, shop, squad builder, bracket, trade).
-- Expects ScreenGuis created in StarterGui. All screen references are found by name.
-- Mobile-first: assume portrait, big tap targets.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfettiVFX  = require(script.Parent:WaitForChild("ConfettiVFX"))
local BuildingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BuildingConfig"))

local UIController = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─── Screen references (found lazily) ────────────────────────────────────────

local function getGui(name)
	-- Panel LocalScripts share their name with the ScreenGui they create, so a plain
	-- FindFirstChild can return the SCRIPT. Prefer a real ScreenGui match.
	for _, c in ipairs(PlayerGui:GetChildren()) do
		if c:IsA("ScreenGui") and c.Name == name then return c end
	end
	return PlayerGui:FindFirstChild(name)
end

-- ─── Toast notifications ─────────────────────────────────────────────────────

local TOAST_COLORS = {
	white  = Color3.fromRGB(255,255,255),
	green  = Color3.fromRGB(80,200,100),
	red    = Color3.fromRGB(220,60,60),
	yellow = Color3.fromRGB(255,210,50),
	gold   = Color3.fromRGB(255,185,0),
}

function UIController.showToast(message, colorName)
	local toastGui = getGui("ToastGui")
	if not toastGui then
		-- Create a minimal toast if the ScreenGui doesn't exist yet
		toastGui = Instance.new("ScreenGui")
		toastGui.Name = "ToastGui"
		toastGui.ResetOnSpawn = false
		toastGui.Parent = PlayerGui
	end

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.6, 0, 0, 50)
	frame.Position = UDim2.new(0.2, 0, 0.85, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = toastGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = TOAST_COLORS[colorName or "white"] or TOAST_COLORS.white
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	-- Slide in then fade out
	frame.Position = UDim2.new(0.2, 0, 1.05, 0)
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.2, 0, 0.85, 0)
	}):Play()

	task.delay(2.5, function()
		TweenService:Create(frame, TweenInfo.new(0.4), {
			Position = UDim2.new(0.2, 0, 1.05, 0),
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.5, function() frame:Destroy() end)
	end)
end

-- ─── Welcome-back offline earnings popup ─────────────────────────────────────

function UIController.showOfflineEarnings(coins)
	UIController.showToast("Welcome back! You earned " .. tostring(coins) .. " Coins while away.", "gold")
end

-- ─── HUD update ───────────────────────────────────────────────────────────────

function UIController.onProfileUpdated(data)
	local hud = getGui("HUD")
	if not hud then return end

	local main = hud:FindFirstChild("Main")
	if not main then return end

	-- Labels live inside CoinsFrame/GemsFrame, so search descendants (recursive).
	local coinsLabel = main:FindFirstChild("CoinsLabel", true)
	if coinsLabel then
		coinsLabel.Text = "💰 " .. tostring(data.coins or 0)
	end

	local gemsLabel = main:FindFirstChild("GemsLabel", true)
	if gemsLabel then
		gemsLabel.Text = "💎 " .. tostring(data.gems or 0)
	end

	-- Live idle-income readout (was never updated before, so it sat at 0).
	local incomeLabel = hud:FindFirstChild("IncomeLabel", true)
	if incomeLabel and data.stadium then
		local rate = BuildingConfig.totalPassiveRate(data.stadium)
		if data.passes and data.passes.double_coins then rate = rate * 2 end
		incomeLabel.Text = "Income: " .. math.floor(rate) .. "/sec"
	end
end

-- ─── Match result popup ───────────────────────────────────────────────────────

function UIController.showMatchResult(result)
	local outcomeText = {
		win  = "WIN!",
		draw = "DRAW",
		loss = "LOSS",
	}
	local outcomeColor = {
		win  = "green",
		draw = "yellow",
		loss = "red",
	}
	local text = string.format(
		"Match result vs %s: %s | +%d Coins",
		result.opponentName or "???",
		outcomeText[result.outcome] or result.outcome,
		result.coinReward or 0
	)
	UIController.showToast(text, outcomeColor[result.outcome] or "white")

	if result.outcome == "win" then
		ConfettiVFX.burst({ count = 55, origin = Vector2.new(0.5, 0.25), spread = 0.85 })
	end
end

-- ─── Trade UI ─────────────────────────────────────────────────────────────────

-- The TradeScreen owns the trade window UI; UIController only surfaces a couple
-- of high-level toasts so feedback isn't noisy on every offer/lock change.
function UIController.onTradeStateChanged(payload)
	if payload and payload.type == "cancelled" then
		UIController.showToast("Trade cancelled.", "red")
	end
end

function UIController.onTradeComplete(payload)
	UIController.showToast("Trade complete! Cards received.", "green")
end

-- ─── Screen navigation ────────────────────────────────────────────────────────

-- Panels that are mutually exclusive. HUD is intentionally NOT here — it stays
-- visible at all times. "StadiumView" is the 3D world (no GUI), so selecting it
-- simply closes every panel.
local SCREEN_NAMES = {
	"ShopScreen", "PackOpenScreen",
	"CollectionScreen", "SquadBuilderScreen", "BracketScreen",
	"TradeScreen", "DailyRewardScreen", "BattlePassScreen",
}

function UIController.showScreen(name)
	for _, screenName in ipairs(SCREEN_NAMES) do
		local gui = getGui(screenName)
		if gui then
			gui.Enabled = (screenName == name)
		end
	end
end

-- ─── Init ────────────────────────────────────────────────────────────────────

function UIController.init(clientState)
	-- clientState is currently unused here (nav is wired by name); kept for parity
	-- with the other controllers' init signature.

	-- Wire up nav buttons once HUD loads
	task.spawn(function()
		local hud = PlayerGui:WaitForChild("HUD", 10)
		if not hud then return end

		local nav = hud:FindFirstChild("Nav")
		if not nav then return end

		local function wireButton(buttonName, screenName)
			local btn = nav:FindFirstChild(buttonName)
			if btn then
				btn.Activated:Connect(function()
					UIController.showScreen(screenName)
				end)
			end
		end

		wireButton("ShopBtn",       "ShopScreen")
		wireButton("CollectionBtn", "CollectionScreen")
		wireButton("SquadBtn",      "SquadBuilderScreen")
		wireButton("BracketBtn",    "BracketScreen")
		wireButton("TradeBtn",      "TradeScreen")
		wireButton("PassBtn",       "BattlePassScreen")
		wireButton("StadiumBtn",    "StadiumView")
	end)
end

return UIController
