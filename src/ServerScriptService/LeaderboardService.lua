-- LeaderboardService: per-player leaderstats (Rebirths + Cash, shown in Roblox's
-- player list) and a "Top Tycoons" board in the city ranking online players by
-- net worth. (Cross-server global ranking via OrderedDataStore is a future add.)

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local DataService = require(ServerScriptService.DataService)

local LeaderboardService = {}

local INT_MAX = 2147483647

-- Net worth: lifetime coins earned + a big bonus per rebirth (so prestige ranks).
local function netWorth(data)
	if not data then return 0 end
	local earned = (data.stats and data.stats.totalEarned) or 0
	return earned + (data.rebirths or 0) * 2000000
end

local function abbreviate(n)
	n = math.floor(n)
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

function LeaderboardService.setupLeaderstats(player)
	if player:FindFirstChild("leaderstats") then return end
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
	local rb = Instance.new("IntValue"); rb.Name = "Rebirths"; rb.Parent = ls
	local cash = Instance.new("IntValue"); cash.Name = "Cash"; cash.Parent = ls
end

local function updateLeaderstats(player, data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls or not data then return end
	local rb = ls:FindFirstChild("Rebirths"); if rb then rb.Value = data.rebirths or 0 end
	local cash = ls:FindFirstChild("Cash"); if cash then cash.Value = math.clamp(math.floor(data.coins or 0), 0, INT_MAX) end
end

local function refreshBoard()
	local ranked = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.getData(player)
		if data then
			updateLeaderstats(player, data)
			table.insert(ranked, { name = player.DisplayName, worth = netWorth(data) })
		end
	end
	table.sort(ranked, function(a, b) return a.worth > b.worth end)

	local lines = {}
	for i = 1, math.min(10, #ranked) do
		local medal = (i == 1 and "🥇") or (i == 2 and "🥈") or (i == 3 and "🥉") or (i .. ".")
		lines[i] = string.format("%s  %s — 💰%s", medal, ranked[i].name, abbreviate(ranked[i].worth))
	end
	local text = (#lines > 0) and table.concat(lines, "\n") or "Be the first tycoon!"

	for _, sign in ipairs(CollectionService:GetTagged("LeaderboardSign")) do
		local sg = sign:FindFirstChildOfClass("SurfaceGui")
		local list = sg and sg:FindFirstChild("List")
		if list then list.Text = text end
	end
end

function LeaderboardService.init()
	for _, p in ipairs(Players:GetPlayers()) do LeaderboardService.setupLeaderstats(p) end
	task.spawn(function()
		while true do
			task.wait(10)
			pcall(refreshBoard)
		end
	end)
end

return LeaderboardService
