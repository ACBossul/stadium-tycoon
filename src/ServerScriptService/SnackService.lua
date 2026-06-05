-- SnackService: time-based consumable buffs sold at the concession stand for
-- gems. Each lasts 5 minutes. Speed gives extra walkspeed; Money gives a small
-- income multiplier. Gems come from VIP daily gems + daily login rewards.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local Players             = game:GetService("Players")

local DataService    = require(ServerScriptService.DataService)
local EconomyService  = require(ServerScriptService.EconomyService)

local SnackService = {}

local DURATION = 300  -- 5 minutes

SnackService.SNACKS = {
	speed = { name = "Energy Drink",  emoji = "⚡", gemCost = 8,  speedBonus = 8 },
	money = { name = "Lucky Hot Dog", emoji = "🌭", gemCost = 12, moneyMult  = 1.10 },
}

local function notify(player, msg, color)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ShowNotification")
	if ev then ev:FireClient(player, { message = msg, color = color or "white" }) end
end

local function pushProfile(player)
	local data = DataService.getData(player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ProfileUpdated")
	if data and ev then ev:FireClient(player, data) end
end

function SnackService.isActive(data, id)
	return data ~= nil and data.buffs ~= nil and (data.buffs[id] or 0) > os.time()
end

-- Walkspeed = base + VIP perk + active speed snack. One source of truth.
function SnackService.computeWalkSpeed(player)
	local data = DataService.getData(player)
	local s = 16
	if data and data.passes and data.passes.vip then s += 10 end
	if SnackService.isActive(data, "speed") then s += SnackService.SNACKS.speed.speedBonus end
	return s
end

function SnackService.refreshSpeed(player)
	local char = player.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.WalkSpeed = SnackService.computeWalkSpeed(player)
	end
end

function SnackService.buy(player, id)
	local snack = SnackService.SNACKS[id]
	if not snack then return end
	local data = DataService.getData(player)
	if not data then return end

	if not EconomyService.deductGems(player, snack.gemCost) then
		notify(player, "Need " .. snack.gemCost .. " 💎 for a " .. snack.name .. ".", "red")
		return
	end

	data.buffs = data.buffs or {}
	data.buffs[id] = os.time() + DURATION
	if id == "speed" then SnackService.refreshSpeed(player) end
	pushProfile(player)
	notify(player, snack.emoji .. " " .. snack.name .. " active for 5 minutes!", "gold")
end

-- ─── Wiring: concession-stand snack prompts (tagged "SnackStand") ───────────────

local function wireSnackStand(part)
	for _, prompt in ipairs(part:GetChildren()) do
		if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Snack") then
			prompt.Triggered:Connect(function(plr)
				SnackService.buy(plr, prompt:GetAttribute("Snack"))
			end)
		end
	end
end

function SnackService.init()
	for _, p in ipairs(CollectionService:GetTagged("SnackStand")) do
		task.spawn(wireSnackStand, p)
	end
	CollectionService:GetInstanceAddedSignal("SnackStand"):Connect(function(p)
		task.spawn(wireSnackStand, p)
	end)

	-- Expiry sweep: when a speed snack lapses, restore the player's walkspeed.
	-- (Money snacks need no action — EconomyService checks the expiry live.)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.getData(player)
				if data and data.buffs and data.buffs.speed and data.buffs.speed <= os.time() then
					data.buffs.speed = nil
					SnackService.refreshSpeed(player)
				end
			end
		end
	end)
end

return SnackService
