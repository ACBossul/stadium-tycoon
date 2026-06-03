-- CardService: pack opening, inventory management, squad equipping.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService         = game:GetService("HttpService")

local DataService   = require(ServerScriptService.DataService)
local EconomyService = require(ServerScriptService.EconomyService)
local CardCatalog   = require(ReplicatedStorage.Config.CardCatalog)
local PackConfig    = require(ReplicatedStorage.Config.PackConfig)

local CardService = {}

-- ─── Rarity roll helpers ─────────────────────────────────────────────────────

-- Build a weighted rarity table from base rates + optional boost table
local function buildRarityPool(oddsBoost)
	local rates = {}
	for rarity, baseRate in pairs(CardCatalog.DropRates) do
		local boost = (oddsBoost and oddsBoost[rarity]) or 0
		rates[rarity] = math.max(0, baseRate + boost)
	end
	-- Normalise in case boosts shifted total away from 1.0
	local total = 0
	for _, v in pairs(rates) do total += v end
	for rarity, v in pairs(rates) do rates[rarity] = v / total end
	return rates
end

-- Roll a rarity from weighted pool
local function rollRarity(rarityPool)
	local r = math.random()
	local cumulative = 0
	-- Iterate in consistent order: Common → Rare → Epic → Legendary → Mythic
	local order = {"Common","Rare","Epic","Legendary","Mythic"}
	for _, rarity in ipairs(order) do
		cumulative += (rarityPool[rarity] or 0)
		if r <= cumulative then
			return rarity
		end
	end
	return "Common"
end

-- Rarity rank for floor comparisons
local RARITY_RANK = { Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5 }

local function rarityAtLeast(rolled, floor)
	return RARITY_RANK[rolled] >= (RARITY_RANK[floor] or 1)
end

-- Pick a random card of the given rarity
local function pickCardOfRarity(rarity)
	local pool = {}
	for _, card in ipairs(CardCatalog.Cards) do
		if card.rarity == rarity then
			table.insert(pool, card)
		end
	end
	if #pool == 0 then
		-- Fallback: pick any card (shouldn't happen with complete catalog)
		pool = CardCatalog.Cards
	end
	return pool[math.random(1, #pool)]
end

-- Roll power within rarity range
local function rollPower(rarity)
	local range = CardCatalog.PowerRanges[rarity]
	return math.random(range[1], range[2])
end

-- Generate a unique instance id
local function newInstanceId()
	return HttpService:GenerateGUID(false):sub(1, 12)
end

-- ─── Pack opening ─────────────────────────────────────────────────────────

-- Returns an array of card instance tables ready to add to inventory
-- Does NOT mutate player data — caller does the actual insertion
local function rollPackCards(packCfg)
	local rarityPool = buildRarityPool(packCfg.oddsBoost)
	local results = {}
	local guaranteedMet = not packCfg.guaranteeFloor

	for i = 1, packCfg.cardCount do
		local rarity = rollRarity(rarityPool)

		-- On last card, enforce guarantee floor if not yet met
		if i == packCfg.cardCount and not guaranteedMet then
			if not rarityAtLeast(rarity, packCfg.guaranteeFloor) then
				rarity = packCfg.guaranteeFloor
			end
		end

		if rarityAtLeast(rarity, packCfg.guaranteeFloor or "Common") then
			guaranteedMet = true
		end

		local cardDef = pickCardOfRarity(rarity)
		local power   = rollPower(rarity)
		table.insert(results, {
			instanceId = newInstanceId(),
			cardId     = cardDef.id,
			power      = power,
			rarity     = rarity,  -- cached for display; authoritative via CardCatalog
		})
	end

	return results
end

-- Roll + insert a pack's cards into inventory WITHOUT charging any currency.
-- Used by Robux dev-product grants (where the player already paid in Robux).
-- Returns success, resultCards or errorCode.
function CardService.grantPack(player, packId)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local packCfg = PackConfig.ById[packId]
	if not packCfg then return false, "invalid_pack" end

	local cards = rollPackCards(packCfg)
	for _, cardInstance in ipairs(cards) do
		data.cards[cardInstance.instanceId] = {
			cardId = cardInstance.cardId,
			power  = cardInstance.power,
		}
	end

	data.stats.packsOpened = (data.stats.packsOpened or 0) + 1
	return true, cards
end

-- Public: buy (charge soft/premium currency) and open a pack.
-- Returns success, resultCards or errorCode.
function CardService.openPack(player, packId)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local packCfg = PackConfig.ById[packId]
	if not packCfg then return false, "invalid_pack" end

	-- Deduct cost first; only grant cards if payment succeeds.
	if packCfg.costType == "coins" then
		if not EconomyService.deductCoins(player, packCfg.cost) then
			return false, "insufficient_coins"
		end
	elseif packCfg.costType == "gems" then
		if not EconomyService.deductGems(player, packCfg.gemCost) then
			return false, "insufficient_gems"
		end
	end

	return CardService.grantPack(player, packId)
end

-- Roll a single card of at least a given rarity floor (for match rewards)
function CardService.grantRewardCard(player, rarityFloor)
	local data = DataService.getData(player)
	if not data then return nil end

	local rarity  = rarityFloor or "Rare"
	local cardDef = pickCardOfRarity(rarity)
	local power   = rollPower(rarity)
	local id      = newInstanceId()

	data.cards[id] = { cardId = cardDef.id, power = power }
	return { instanceId = id, cardId = cardDef.id, power = power, rarity = rarity }
end

-- ─── Squad management ─────────────────────────────────────────────────────

-- Sets the squad. instanceIds is an ordered array of up to 11 instanceIds the player owns.
function CardService.equipSquad(player, instanceIds)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	if type(instanceIds) ~= "table" then return false, "invalid" end
	if #instanceIds > 11 then return false, "too_many" end

	-- Validate every id is owned
	for _, iid in ipairs(instanceIds) do
		if not data.cards[iid] then
			return false, "not_owned:" .. tostring(iid)
		end
	end

	data.squad = instanceIds
	return true, nil
end

-- Returns total squad power (sum of power of equipped cards)
function CardService.getSquadPower(player)
	local data = DataService.getData(player)
	if not data then return 0 end
	local total = 0
	for _, iid in ipairs(data.squad) do
		local card = data.cards[iid]
		if card then total += card.power end
	end
	return total
end

-- Same but accepts a data table directly (for bracket service, no player object needed)
function CardService.getSquadPowerFromData(data)
	if not data then return 0 end
	local total = 0
	for _, iid in ipairs(data.squad) do
		local card = data.cards[iid]
		if card then total += card.power end
	end
	return total
end

return CardService
