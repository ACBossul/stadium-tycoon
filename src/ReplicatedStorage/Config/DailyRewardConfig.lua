-- DailyRewardConfig: escalating 7-day login reward track + timing windows.
-- Shared read-only: the server grants from this, the client renders the track from it.

local DailyRewardConfig = {}

-- A player can claim once their cooldown has elapsed since the last claim.
DailyRewardConfig.COOLDOWN_SECONDS = 20 * 60 * 60   -- 20h: lets people claim ~daily

-- If this much time passes without claiming, the streak resets to day 1.
DailyRewardConfig.STREAK_BREAK_SECONDS = 48 * 60 * 60  -- 48h grace

-- 7-day cycle; after day 7 it loops back to day 1.
-- Tune freely — these are starting values.
DailyRewardConfig.Rewards = {
	{ day = 1, coins = 200,  gems = 0  },
	{ day = 2, coins = 400,  gems = 0  },
	{ day = 3, coins = 700,  gems = 0  },
	{ day = 4, coins = 1000, gems = 10 },
	{ day = 5, coins = 1500, gems = 0  },
	{ day = 6, coins = 2500, gems = 0  },
	{ day = 7, coins = 5000, gems = 50 },
}

DailyRewardConfig.CYCLE_LENGTH = #DailyRewardConfig.Rewards

-- Maps a 1-based streak count to the reward entry for that day (cycles).
function DailyRewardConfig.rewardForStreak(streak)
	local idx = ((streak - 1) % DailyRewardConfig.CYCLE_LENGTH) + 1
	return DailyRewardConfig.Rewards[idx]
end

return DailyRewardConfig
