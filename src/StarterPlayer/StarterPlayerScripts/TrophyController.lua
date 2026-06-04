-- TrophyController: fills the Trophy Room display board on the player's upper deck
-- with their live cup stage, matches won, rebirths, and best card (from the profile).

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CardCatalog"))

local TrophyController = {}

local myBoards  = setmetatable({}, { __mode = "k" })  -- TrophyDisplay parts owned by us
local lastData  = nil

local function lineLabel(board)
	local sg = board:FindFirstChild("Info")
	return sg and sg:FindFirstChild("Lines")
end

local function render(board, data)
	local lbl = lineLabel(board)
	if not lbl then return end
	local b = data.bracket or {}
	local bestName, bestPower = nil, 0
	if data.cards then
		for _, c in pairs(data.cards) do
			if (c.power or 0) > bestPower then
				bestPower = c.power
				local def = CardCatalog.ById[c.cardId]
				bestName = (def and def.name) or c.cardId
			end
		end
	end
	lbl.Text = string.format(
		"Cup stage: %s\nMatches won: %d\nRebirths: %d\nBest card: %s",
		(b.stage or "group"):upper(), b.wins or 0, data.rebirths or 0,
		bestName and (bestName .. "  ⚡" .. bestPower) or "—"
	)
end

function TrophyController.onProfileUpdated(data)
	if not data then return end
	lastData = data
	for board in pairs(myBoards) do
		if board.Parent then render(board, data) end
	end
end

local function register(board)
	local owner = board:FindFirstChild("Owner") or board:WaitForChild("Owner", 10)
	local tries = 0
	while owner and owner.Value == nil and tries < 50 do
		task.wait(0.1); tries += 1
	end
	if owner and owner.Value == LocalPlayer then
		myBoards[board] = true
		if lastData then render(board, lastData) end
	end
end

function TrophyController.init(_clientState)
	for _, b in ipairs(CollectionService:GetTagged("TrophyDisplay")) do
		task.spawn(register, b)
	end
	CollectionService:GetInstanceAddedSignal("TrophyDisplay"):Connect(function(b)
		task.spawn(register, b)
	end)
end

return TrophyController
