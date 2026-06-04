-- MonetizationService: game passes, developer products, ProcessReceipt.
-- ProcessReceipt MUST be idempotent — the same receipt can fire more than once.
-- Use a purchaseHistory table in the player profile to deduplicate.

local Players             = game:GetService("Players")
local MarketplaceService  = game:GetService("MarketplaceService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService        = require(ServerScriptService.DataService)
local EconomyService     = require(ServerScriptService.EconomyService)
local CardService        = require(ServerScriptService.CardService)
local BattlePassService  = require(ServerScriptService.BattlePassService)
local MonetizationConfig = require(ReplicatedStorage.Config.MonetizationConfig)

local MonetizationService = {}

-- ─── Game Pass checks ────────────────────────────────────────────────────────

-- Called on player join to sync pass ownership into the profile cache
function MonetizationService.syncGamePasses(player)
	local data = DataService.getData(player)
	if not data then return end

	for _, gp in ipairs(MonetizationConfig.GamePasses) do
		local owned = false
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.gamePassId)
		end)
		if ok then owned = result end
		data.passes[gp.id] = owned
	end
end

-- Grant daily VIP gems if applicable
function MonetizationService.grantDailyVipGems(player)
	local data = DataService.getData(player)
	if not data then return end
	if not (data.passes and data.passes.vip) then return end

	local gp = nil
	for _, g in ipairs(MonetizationConfig.GamePasses) do
		if g.id == "vip" then gp = g break end
	end
	if not gp or not gp.dailyGems then return end

	local now = os.time()
	local last = data.lastVipGemGrant or 0

	-- Grant once per 20 hours (allows timezone flexibility)
	if now - last >= 72000 then
		EconomyService.addGems(player, gp.dailyGems)
		data.lastVipGemGrant = now
	end
end

-- ─── ProcessReceipt ──────────────────────────────────────────────────────────

local function getPurchaseHistory(data)
	if not data.purchaseHistory then
		data.purchaseHistory = {}
	end
	return data.purchaseHistory
end

local function hasProcessed(data, receiptId)
	return getPurchaseHistory(data)[receiptId] == true
end

local function markProcessed(data, receiptId)
	getPurchaseHistory(data)[receiptId] = true
	-- Trim history to last 100 receipts to keep DataStore size bounded
	local history = getPurchaseHistory(data)
	local keys = {}
	for k in pairs(history) do table.insert(keys, k) end
	if #keys > 100 then
		table.sort(keys)
		for i = 1, #keys - 100 do
			history[keys[i]] = nil
		end
	end
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left — return NotProcessedYet so Roblox retries when they rejoin
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.getData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency check
	local receiptId = tostring(receiptInfo.PurchaseId)
	if hasProcessed(data, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	local productDef = MonetizationConfig.DevProductById[productId]

	if not productDef then
		-- Unknown product — grant anyway to avoid false "not processed"
		markProcessed(data, receiptId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Grant the product
	if productDef.gemsGranted then
		EconomyService.addGems(player, productDef.gemsGranted)
	end

	if productDef.packId then
		-- Robux-purchased pack: grant cards directly, no currency charged.
		local ok, cards = CardService.grantPack(player, productDef.packId)
		if ok then
			local event = ReplicatedStorage:FindFirstChild("Remotes")
			event = event and event:FindFirstChild("PackOpenResult")
			if event then
				event:FireClient(player, { cards = cards })
			end
		end
	end

	if productDef.battlePassPremium then
		BattlePassService.grantPremium(player)
	end

	markProcessed(data, receiptId)
	DataService.forceSave(player)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ─── Game pass purchase completion ───────────────────────────────────────────
-- Grant a game pass the moment its purchase completes, so buyers (incl. VIP) get
-- it live without rejoining. Studio test purchases fire this too.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local gp = MonetizationConfig.GamePassById[gamePassId]
	if not gp then return end
	local data = DataService.getData(player)
	if not data then return end
	data.passes = data.passes or {}
	data.passes[gp.id] = true

	-- VIP grants its first daily gems immediately on purchase.
	if gp.id == "vip" then
		MonetizationService.grantDailyVipGems(player)
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ProfileUpdated")
	if ev then ev:FireClient(player, data) end
end)

return MonetizationService
