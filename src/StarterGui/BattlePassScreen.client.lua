-- BattlePassScreen.client.lua: seasonal battle pass — free + premium tracks.
-- Reads the player's progress from the normal ProfileUpdated sync (data.battlePass)
-- and renders against the shared BattlePassConfig. Claims go through a remote;
-- premium unlock is a Robux dev-product prompt.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local Config      = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BattlePassConfig"))

local currentProfile = nil
local tierRows = {}   -- [tier] = { freeBtn, premiumBtn }

-- ─── GUI shell ────────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name         = "BattlePassScreen"
gui.ResetOnSpawn = false
gui.Enabled      = false
gui.DisplayOrder = 7
gui.Parent       = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
bg.BorderSizePixel = 0
bg.Parent = gui

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 44)
closeBtn.Position = UDim2.new(1, -52, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = bg
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 8) cbc.Parent = closeBtn
closeBtn.Activated:Connect(function() gui.Enabled = false end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 34)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "🎖  BATTLE PASS"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bg

local seasonLabel = Instance.new("TextLabel")
seasonLabel.Size = UDim2.new(1, -16, 0, 22)
seasonLabel.Position = UDim2.new(0, 12, 0, 42)
seasonLabel.BackgroundTransparency = 1
seasonLabel.Text = Config.CurrentSeason.name
seasonLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
seasonLabel.TextScaled = true
seasonLabel.Font = Enum.Font.Gotham
seasonLabel.TextXAlignment = Enum.TextXAlignment.Left
seasonLabel.Parent = bg

-- Progress + tier
local progressBack = Instance.new("Frame")
progressBack.Size = UDim2.new(1, -16, 0, 24)
progressBack.Position = UDim2.new(0, 8, 0, 70)
progressBack.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
progressBack.BorderSizePixel = 0
progressBack.Parent = bg
local pbc = Instance.new("UICorner") pbc.CornerRadius = UDim.new(0, 8) pbc.Parent = progressBack

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack
local pfc = Instance.new("UICorner") pfc.CornerRadius = UDim.new(0, 8) pfc.Parent = progressFill

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, 0, 1, 0)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Tier 0"
progressLabel.TextColor3 = Color3.new(1, 1, 1)
progressLabel.TextScaled = true
progressLabel.Font = Enum.Font.GothamBold
progressLabel.ZIndex = 2
progressLabel.Parent = progressBack

-- Unlock premium button (hidden once owned)
local unlockBtn = Instance.new("TextButton")
unlockBtn.Size = UDim2.new(1, -16, 0, 34)
unlockBtn.Position = UDim2.new(0, 8, 0, 100)
unlockBtn.BackgroundColor3 = Color3.fromRGB(230, 150, 40)
unlockBtn.Text = "⭐ Unlock Premium Pass (Robux)"
unlockBtn.TextColor3 = Color3.new(1, 1, 1)
unlockBtn.TextScaled = true
unlockBtn.Font = Enum.Font.GothamBold
unlockBtn.Parent = bg
local ubc = Instance.new("UICorner") ubc.CornerRadius = UDim.new(0, 8) ubc.Parent = unlockBtn
unlockBtn.Activated:Connect(function()
	MarketplaceService:PromptProductPurchase(LocalPlayer, Config.PremiumProductId)
end)

-- Tier list
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -144)
scroll.Position = UDim2.new(0, 8, 0, 140)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 5
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = bg
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scroll

-- ─── Reward formatting ──────────────────────────────────────────────────────

local function rewardText(r)
	if not r then return "—" end
	local parts = {}
	if r.coins     then table.insert(parts, "💰" .. r.coins) end
	if r.gems      then table.insert(parts, "💎" .. r.gems) end
	if r.packId    then table.insert(parts, "📦Pack") end
	if r.cardFloor then table.insert(parts, "🃏" .. r.cardFloor) end
	return #parts > 0 and table.concat(parts, " ") or "—"
end

-- ─── Tier rows (built once; states refresh from profile) ────────────────────

local function makeClaimButton(parent, xScale, tier, track, rewardStr, tint)
	local cell = Instance.new("Frame")
	cell.Size = UDim2.new(0.44, 0, 1, -6)
	cell.Position = UDim2.new(xScale, 0, 0, 3)
	cell.BackgroundColor3 = tint
	cell.BorderSizePixel = 0
	cell.Parent = parent
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = cell

	local rwd = Instance.new("TextLabel")
	rwd.Size = UDim2.new(1, -6, 0.5, 0)
	rwd.Position = UDim2.new(0, 3, 0, 2)
	rwd.BackgroundTransparency = 1
	rwd.Text = rewardStr
	rwd.TextColor3 = Color3.new(1, 1, 1)
	rwd.TextScaled = true
	rwd.Font = Enum.Font.GothamBold
	rwd.Parent = cell

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0.42, 0)
	btn.Position = UDim2.new(0, 4, 0.54, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
	btn.Text = "Claim"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = cell
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 5) bc.Parent = btn

	btn.Activated:Connect(function()
		Remotes.ClaimBattlePassTier:FireServer({ tier = tier, track = track })
	end)
	return btn
end

for _, tierDef in ipairs(Config.Tiers) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, 60)
	row.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
	row.BorderSizePixel = 0
	row.LayoutOrder = tierDef.tier
	row.Parent = scroll
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 8) rc.Parent = row

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Size = UDim2.new(0.1, 0, 1, 0)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Text = tostring(tierDef.tier)
	tierLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
	tierLabel.TextScaled = true
	tierLabel.Font = Enum.Font.GothamBlack
	tierLabel.Parent = row

	local freeBtn    = makeClaimButton(row, 0.11, tierDef.tier, "free",    rewardText(tierDef.free),    Color3.fromRGB(28, 30, 44))
	local premiumBtn = makeClaimButton(row, 0.56, tierDef.tier, "premium", rewardText(tierDef.premium), Color3.fromRGB(48, 36, 20))

	tierRows[tierDef.tier] = { freeBtn = freeBtn, premiumBtn = premiumBtn }
end

-- ─── State refresh ──────────────────────────────────────────────────────────

local function setBtn(btn, text, color, active)
	btn.Text = text
	btn.BackgroundColor3 = color
	btn.Active = active
	btn.AutoButtonColor = active
end

local function updateClaimButton(btn, tier, reached, claimed, lockedReason)
	if lockedReason then
		setBtn(btn, lockedReason, Color3.fromRGB(70, 70, 85), false)
	elseif claimed then
		setBtn(btn, "✓", Color3.fromRGB(60, 110, 70), false)
	elseif reached then
		setBtn(btn, "Claim", Color3.fromRGB(50, 180, 80), true)
	else
		setBtn(btn, "🔒", Color3.fromRGB(70, 70, 85), false)
	end
end

local function refresh(profile)
	local bp = profile and profile.battlePass
	if not bp then return end

	local xp        = bp.xp or 0
	local tier      = Config.tierForXp(xp)
	local premium   = bp.premium == true
	local claimedF  = bp.claimedFree or {}
	local claimedP  = bp.claimedPremium or {}

	-- Progress bar (progress within the current tier; full at max).
	local intoTier  = xp % Config.XP_PER_TIER
	local frac      = (tier >= Config.MAX_TIER) and 1 or (intoTier / Config.XP_PER_TIER)
	progressFill.Size = UDim2.new(frac, 0, 1, 0)
	progressLabel.Text = (tier >= Config.MAX_TIER)
		and ("Tier MAX (" .. Config.MAX_TIER .. ")")
		or  string.format("Tier %d  •  %d/%d XP", tier, intoTier, Config.XP_PER_TIER)

	unlockBtn.Visible = not premium

	for t, refs in pairs(tierRows) do
		local reached = t <= tier
		updateClaimButton(refs.freeBtn, t, reached, claimedF[tostring(t)] == true, nil)
		updateClaimButton(
			refs.premiumBtn, t, reached, claimedP[tostring(t)] == true,
			(not premium) and "Premium" or nil
		)
	end
end

if Remotes then
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(profile)
		currentProfile = profile
		if gui.Enabled then refresh(profile) end
	end)
end

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled and currentProfile then refresh(currentProfile) end
end)
