-- KartCustomizeService: buy/equip kart skins previewed at the City garage.
-- Non-VIP skins cost coins (one-time unlock, then free to re-equip). VIP skins
-- are exclusive to VIP owners. The equipped skin recolours the kart on spawn.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local DataService    = require(ServerScriptService.DataService)
local EconomyService  = require(ServerScriptService.EconomyService)
local KartCosmetics  = require(ReplicatedStorage.Config.KartCosmetics)

local KartCustomizeService = {}

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

-- Buy (if needed) and equip a skin.
function KartCustomizeService.selectSkin(player, skinId)
	local skin = KartCosmetics.ById[skinId]
	if not skin then return end
	local data = DataService.getData(player)
	if not data then return end
	data.ownedSkins = data.ownedSkins or { stock = true }

	-- VIP skins are exclusive to VIP owners.
	if skin.vip and not (data.passes and data.passes.vip) then
		notify(player, "⭐ " .. skin.name .. " is a VIP-exclusive kart skin — grab VIP!", "red")
		return
	end

	-- Unlock if not owned yet.
	if not data.ownedSkins[skinId] then
		if (not skin.vip) and skin.cost > 0 then
			if not EconomyService.deductCoins(player, skin.cost) then
				notify(player, "Need " .. skin.cost .. " coins for the " .. skin.name .. " skin.", "red")
				return
			end
		end
		data.ownedSkins[skinId] = true
	end

	data.kartSkin = skinId
	pushProfile(player)
	notify(player, "🛺 Equipped the " .. skin.name .. " kart skin!", "gold")
end

local function wirePedestal(part)
	local cd = part:FindFirstChildOfClass("ClickDetector")
	if not cd then return end
	cd.MouseClick:Connect(function(plr)
		KartCustomizeService.selectSkin(plr, part:GetAttribute("Skin"))
	end)
end

function KartCustomizeService.init()
	for _, p in ipairs(CollectionService:GetTagged("KartSkinPedestal")) do
		task.spawn(wirePedestal, p)
	end
	CollectionService:GetInstanceAddedSignal("KartSkinPedestal"):Connect(function(p)
		task.spawn(wirePedestal, p)
	end)
end

return KartCustomizeService
