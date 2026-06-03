-- DailyRewardService: server-authoritative daily login rewards with a streak.
-- Uses elapsed-time windows (not calendar midnights) to avoid timezone headaches.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService       = require(ServerScriptService.DataService)
local EconomyService    = require(ServerScriptService.EconomyService)
local DailyRewardConfig = require(ReplicatedStorage.Config.DailyRewardConfig)

local DailyRewardService = {}

-- Returns the current claim state for a player:
--   { claimable, streak, nextStreak, nextReward, secondsUntilNext }
function DailyRewardService.getState(player)
	local data = DataService.getData(player)
	if not data then return nil end

	local now   = os.time()
	local last  = data.lastDailyClaim or 0
	local streak = data.dailyStreak or 0

	local elapsed   = now - last
	local claimable = (last == 0) or (elapsed >= DailyRewardConfig.COOLDOWN_SECONDS)

	-- What streak day the NEXT claim will land on.
	local nextStreak
	if last == 0 or elapsed > DailyRewardConfig.STREAK_BREAK_SECONDS then
		nextStreak = 1
	else
		nextStreak = streak + 1
	end

	local secondsUntilNext = 0
	if not claimable then
		secondsUntilNext = math.max(0, DailyRewardConfig.COOLDOWN_SECONDS - elapsed)
	end

	return {
		claimable        = claimable,
		streak           = streak,
		nextStreak       = nextStreak,
		nextReward       = DailyRewardConfig.rewardForStreak(nextStreak),
		secondsUntilNext = secondsUntilNext,
	}
end

-- Attempts a claim. Returns success, rewardInfo or errorCode.
function DailyRewardService.claim(player)
	local data = DataService.getData(player)
	if not data then return false, "no_data" end

	local now  = os.time()
	local last = data.lastDailyClaim or 0
	local elapsed = now - last

	-- Server-authoritative gate: ignore the client's word entirely.
	if last ~= 0 and elapsed < DailyRewardConfig.COOLDOWN_SECONDS then
		return false, "not_ready"
	end

	-- Determine the streak day this claim lands on.
	local newStreak
	if last == 0 or elapsed > DailyRewardConfig.STREAK_BREAK_SECONDS then
		newStreak = 1
	else
		newStreak = (data.dailyStreak or 0) + 1
	end

	local reward = DailyRewardConfig.rewardForStreak(newStreak)

	if reward.coins and reward.coins > 0 then
		EconomyService.addCoins(player, reward.coins)
	end
	if reward.gems and reward.gems > 0 then
		EconomyService.addGems(player, reward.gems)
	end

	data.dailyStreak    = newStreak
	data.lastDailyClaim = now
	DataService.forceSave(player)

	return true, {
		streak = newStreak,
		coins  = reward.coins or 0,
		gems   = reward.gems or 0,
	}
end

return DailyRewardService
