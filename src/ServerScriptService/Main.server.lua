-- Main.server.lua: server entry point.
-- Boots services in order, wires up all RemoteEvent handlers, starts income loop.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Boot remotes first so all services can reference them
require(ReplicatedStorage.InitRemotes)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DataService        = require(ServerScriptService.DataService)
local EconomyService     = require(ServerScriptService.EconomyService)
local CardService        = require(ServerScriptService.CardService)
local BracketService     = require(ServerScriptService.BracketService)
local TradeService       = require(ServerScriptService.TradeService)
local MonetizationService = require(ServerScriptService.MonetizationService)
local PlotService        = require(ServerScriptService.PlotService)
local DailyRewardService = require(ServerScriptService.DailyRewardService)
local BuildingConfig     = require(ReplicatedStorage.Config.BuildingConfig)

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function notify(player, message, color)
	local event = Remotes:FindFirstChild("ShowNotification")
	if event then
		event:FireClient(player, { message = message, color = color or "white" })
	end
end

local function pushProfile(player)
	local data = DataService.getData(player)
	if not data then return end
	local event = Remotes:FindFirstChild("ProfileUpdated")
	if event then
		event:FireClient(player, data)
	end
end

local function pushDailyRewardState(player)
	local state = DailyRewardService.getState(player)
	if not state then return end
	local event = Remotes:FindFirstChild("DailyRewardState")
	if event then
		event:FireClient(player, state)
	end
end

-- ─── Player lifecycle ────────────────────────────────────────────────────────

local function onPlayerJoin(player)
	DataService.loadProfile(player)

	-- Wait for DataService to finish loading (ProfileService is async)
	local tries = 0
	while not DataService.getData(player) and tries < 30 do
		task.wait(0.5)
		tries += 1
	end

	local data = DataService.getData(player)
	if not data then
		player:Kick("Failed to load data. Please rejoin.")
		return
	end

	-- Sync game pass ownership into profile cache
	MonetizationService.syncGamePasses(player)

	-- Assign group if first join
	BracketService.assignGroupIfNeeded(player)

	-- Build the player's stadium plot (runtime-generated, tagged buildings)
	PlotService.buildPlot(player)

	-- Compute offline earnings
	local offlineEarned = EconomyService.applyOfflineEarnings(player)

	-- Resolve any missed matchdays
	local matchResults = BracketService.resolvePendingMatchdays(player)

	-- Start income tracking
	EconomyService.onPlayerJoin(player)

	-- Grant daily VIP gems
	MonetizationService.grantDailyVipGems(player)

	-- Push initial profile state to client
	pushProfile(player)

	-- Show offline earnings popup
	if offlineEarned > 0 then
		local event = Remotes:FindFirstChild("ShowOfflineEarnings")
		if event then
			event:FireClient(player, { coins = offlineEarned })
		end
	end

	-- Show match results that resolved while offline
	if #matchResults > 0 then
		for _, result in ipairs(matchResults) do
			local event = Remotes:FindFirstChild("MatchdayResolved")
			if event then
				event:FireClient(player, result)
			end
		end
	end

	-- Send next matchday countdown
	local nextEntry = require(ReplicatedStorage.Config.MatchdaySchedule).getNextEntry(data.bracket.lastResolvedMatchday)
	if nextEntry then
		local event = Remotes:FindFirstChild("MatchdayCountdown")
		if event then
			event:FireClient(player, { timestamp = nextEntry.timestamp, matchdayId = nextEntry.matchdayId })
		end
	end

	-- Send daily reward state (client auto-opens the popup if claimable)
	pushDailyRewardState(player)
end

local function onPlayerLeave(player)
	EconomyService.onPlayerLeave(player)
	TradeService.onPlayerLeave(player)
	PlotService.removePlot(player)
	DataService.releaseProfile(player)
end

Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)

-- Handle players already in game when script runs
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoin, player)
end

-- ─── Income tick loop ────────────────────────────────────────────────────────

-- Push profile updates to clients every 5s to keep HUD in sync
local PROFILE_SYNC_INTERVAL = 5
local lastSync = {}

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()

		for _, player in ipairs(Players:GetPlayers()) do
			EconomyService.tickIncome(player, now)

			-- Resolve any matchdays that ticked over while player is online
			BracketService.resolvePendingMatchdays(player)

			-- Periodic profile sync to client
			local last = lastSync[player.UserId] or 0
			if now - last >= PROFILE_SYNC_INTERVAL then
				lastSync[player.UserId] = now
				pushProfile(player)
			end
		end
	end
end)

-- ─── RemoteEvent handlers ────────────────────────────────────────────────────

-- UpgradeBuilding: client sends buildingId
Remotes.UpgradeBuilding.OnServerEvent:Connect(function(player, buildingId)
	if type(buildingId) ~= "string" then return end
	local ok, err = EconomyService.upgradeBuilding(player, buildingId)
	if ok then
		pushProfile(player)
		local cfg = BuildingConfig.ById[buildingId]
		notify(player, "Upgraded " .. (cfg and cfg.name or buildingId) .. "!", "green")
	else
		notify(player, "Cannot upgrade: " .. tostring(err), "red")
	end
end)

-- CollectBuilding: client sends buildingId
Remotes.CollectBuilding.OnServerEvent:Connect(function(player, buildingId)
	if type(buildingId) ~= "string" then return end
	local ok, earned = EconomyService.collectBuilding(player, buildingId)
	if ok then
		pushProfile(player)
		notify(player, "+" .. tostring(earned) .. " Coins!", "yellow")
	end
end)

-- OpenPack: client sends packId
Remotes.OpenPack.OnServerEvent:Connect(function(player, packId)
	if type(packId) ~= "string" then return end
	local ok, result = CardService.openPack(player, packId)
	if ok then
		pushProfile(player)
		-- Send cards to client for pack opening animation
		local event = Remotes:FindFirstChild("PackOpenResult")
		if event then
			event:FireClient(player, { cards = result })
		end
	else
		notify(player, "Cannot open pack: " .. tostring(result), "red")
	end
end)

-- EquipSquad: client sends array of instanceIds
Remotes.EquipSquad.OnServerEvent:Connect(function(player, instanceIds)
	if type(instanceIds) ~= "table" then return end
	local ok, err = CardService.equipSquad(player, instanceIds)
	if ok then
		pushProfile(player)
	else
		notify(player, "Squad error: " .. tostring(err), "red")
	end
end)

-- GetBracketState: client requests bracket data
Remotes.GetBracketState.OnServerInvoke = function(player)
	return BracketService.getBracketState(player)
end

-- Trade remotes
Remotes.TradeRequest.OnServerEvent:Connect(function(player, targetName)
	if type(targetName) ~= "string" then return end
	local target = Players:FindFirstChild(targetName)
	if not target then
		notify(player, "Player not found.", "red")
		return
	end
	local ok, err = TradeService.requestTrade(player, target)
	if not ok then
		notify(player, "Trade failed: " .. tostring(err), "red")
	end
end)

Remotes.TradeOffer.OnServerEvent:Connect(function(player, instanceIds)
	if type(instanceIds) ~= "table" then return end
	TradeService.updateOffer(player, instanceIds)
end)

Remotes.TradeConfirm.OnServerEvent:Connect(function(player)
	TradeService.confirmTrade(player)
end)

Remotes.TradeCancel.OnServerEvent:Connect(function(player)
	TradeService.cancelTrade(player)
end)

-- Daily reward claim
Remotes.ClaimDailyReward.OnServerEvent:Connect(function(player)
	local ok, reward = DailyRewardService.claim(player)
	if ok then
		pushProfile(player)
		pushDailyRewardState(player)
		local parts = { "Day " .. reward.streak .. " reward: +" .. reward.coins .. " Coins" }
		if reward.gems > 0 then table.insert(parts, "+" .. reward.gems .. " Gems") end
		notify(player, table.concat(parts, ", ") .. "!", "gold")
	else
		notify(player, "Daily reward not ready yet.", "red")
	end
end)

print("[StadiumTycoon] Server started.")
