-- BracketController: countdown timer and bracket view updates.

local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")

local BracketController = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local nextMatchdayTimestamp = nil

-- ─── Countdown ticker ───────────────────────────────────────────────────────

local function formatCountdown(seconds)
	if seconds <= 0 then return "NOW" end
	local d = math.floor(seconds / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	else
		return string.format("%dm %ds", m, s)
	end
end

RunService.Heartbeat:Connect(function()
	if not nextMatchdayTimestamp then return end

	local screen = PlayerGui:FindFirstChild("BracketScreen")
	if not screen then return end

	local countdownLabel = screen:FindFirstChild("CountdownLabel", true)
	if not countdownLabel then return end

	local remaining = math.max(0, nextMatchdayTimestamp - os.time())
	countdownLabel.Text = "Next match: " .. formatCountdown(remaining)
end)

-- ─── Public ─────────────────────────────────────────────────────────────────

function BracketController.setNextMatchday(timestamp)
	nextMatchdayTimestamp = timestamp
end

function BracketController.onMatchResolved(result)
	-- Refresh bracket screen if open
	local screen = PlayerGui:FindFirstChild("BracketScreen")
	if not screen or not screen.Enabled then return end

	local stageLabel = screen:FindFirstChild("StageLabel", true)
	if stageLabel then
		stageLabel.Text = "Stage: " .. (result.newStage or "?")
	end

	local resultLabel = screen:FindFirstChild("LastResultLabel", true)
	if resultLabel then
		local text = string.format(
			"vs %s: %s (⚡%d vs ⚡%d)",
			result.opponentName or "???",
			result.outcome:upper(),
			result.playerPower or 0,
			result.opponentPower or 0
		)
		resultLabel.Text = text
	end
end

function BracketController.refreshFromProfile(data)
	local screen = PlayerGui:FindFirstChild("BracketScreen")
	if not screen then return end

	local stageLabel = screen:FindFirstChild("StageLabel", true)
	if stageLabel and data and data.bracket then
		stageLabel.Text = "Stage: " .. (data.bracket.stage or "?")
	end

	local pointsLabel = screen:FindFirstChild("PointsLabel", true)
	if pointsLabel and data and data.bracket then
		pointsLabel.Text = "Points: " .. (data.bracket.points or 0)
	end
end

function BracketController.init()
	-- No client state needed; bracket UI updates arrive via the public methods
	-- (setNextMatchday / onMatchResolved / refreshFromProfile).
end

return BracketController
