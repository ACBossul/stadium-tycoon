-- RebirthService: prestige reset. Trade your coins + building levels for a
-- permanent income multiplier (+50% each) and an exclusive Mythic card. Cards,
-- cup progress, gems and game passes are KEPT.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local DataService    = require(ServerScriptService.DataService)
local CardService    = require(ServerScriptService.CardService)
local PlotService    = require(ServerScriptService.PlotService)
local BuildingConfig = require(ReplicatedStorage.Config.BuildingConfig)
local CardCatalog    = require(ReplicatedStorage.Config.CardCatalog)

local RebirthService = {}

-- Exclusive cards granted per rebirth (cycles if you rebirth more than this many times).
local REBIRTH_CARDS = { "rb_the_prestige", "rb_golden_reaper", "rb_ascended_one", "rb_phoenix", "rb_infinity" }

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

function RebirthService.totalLevels(data)
	local total = 0
	for _, b in ipairs(BuildingConfig.Buildings) do
		total += (data.stadium[b.id] or 0)
	end
	return total
end

-- Required total building levels for the player's NEXT rebirth (scales each time).
-- Gentle early bar so the first prestige comes quickly (addictive loop), then ramps.
function RebirthService.requirement(data)
	return 15 * ((data.rebirths or 0) + 1)
end

function RebirthService.canRebirth(data)
	return RebirthService.totalLevels(data) >= RebirthService.requirement(data)
end

function RebirthService.doRebirth(player)
	local data = DataService.getData(player)
	if not data then return false end

	if not RebirthService.canRebirth(data) then
		notify(player, "Not ready to rebirth — need " .. RebirthService.requirement(data)
			.. " total building levels (you have " .. RebirthService.totalLevels(data) .. ").", "red")
		return false
	end

	-- Reset coins + buildings (keep cards, cup, gems, passes).
	data.coins = BuildingConfig.STARTING_COINS
	data.pending = 0   -- uncollected earnings reset too
	for _, b in ipairs(BuildingConfig.Buildings) do
		data.stadium[b.id] = (b.id == "stands") and 1 or 0
	end
	data.rebirths = (data.rebirths or 0) + 1

	-- Exclusive reward: a rebirth-only Mythic card (cycles through the set), as a
	-- "better variant" — its power scales with your rebirth count, so each prestige
	-- hands you a stronger card than the last.
	local n        = data.rebirths
	local cardId   = REBIRTH_CARDS[((n - 1) % #REBIRTH_CARDS) + 1]
	local card     = CardService.grantSpecificCard(player, cardId, n * 30)
	local cardName = (CardCatalog.ById[cardId] and CardCatalog.ById[cardId].name) or "a Mythic card"
	local cardPow  = card and card.power or 0

	-- Reset the physical stadium to its new (low) levels.
	for _, b in ipairs(BuildingConfig.Buildings) do
		PlotService.onBuildingUpgraded(player, b.id, data.stadium[b.id])
	end

	pushProfile(player)
	local mult = 1 + 0.10 * n + 0.025 * n * (n - 1)
	local pct  = math.floor((mult - 1) * 100 + 0.5)
	notify(player, "🔁 REBIRTH " .. n .. "!  Income now +" .. pct .. "% forever + "
		.. cardName .. " ⚡" .. cardPow .. " (boosted)!", "gold")
	return true
end

-- ─── Pad wiring (PlotService tags a "RebirthPad" per plot) ──────────────────────

local function wireRebirthPad(pad)
	local ownerVal = pad:FindFirstChild("Owner")
	local cd = pad:FindFirstChildOfClass("ClickDetector") or pad:WaitForChild("RebirthClick", 10)
	if not cd or not cd:IsA("ClickDetector") then return end
	cd.MouseClick:Connect(function(clicker)
		if ownerVal and clicker ~= ownerVal.Value then return end
		RebirthService.doRebirth(clicker)
	end)
end

function RebirthService.init()
	for _, pad in ipairs(CollectionService:GetTagged("RebirthPad")) do
		task.spawn(wireRebirthPad, pad)
	end
	CollectionService:GetInstanceAddedSignal("RebirthPad"):Connect(function(pad)
		task.spawn(wireRebirthPad, pad)
	end)
end

return RebirthService
