-- MatchdaySchedule: maps in-game matchdays to real Unix timestamps.
-- Edit timestamps here to nudge dates without any code changes.
-- All times are UTC. Matchdays resolve server-side when os.time() >= timestamp.
--
-- Real World Cup 2026: June 11 kickoff, July 19 final.
-- Group stage: June 11–27 (3 matchdays per group over that window)
-- Round of 32: June 28 – July 1
-- Round of 16: July 4–5
-- Quarterfinals: July 8–9 (evening UTC)
-- Semifinals: July 14–15
-- Final: July 19
--
-- Adjust UTC offsets to match actual broadcast windows if needed.

local MatchdaySchedule = {}

-- Stage name constants
MatchdaySchedule.Stages = {
	GROUP = "group",
	R32   = "r32",
	R16   = "r16",
	QF    = "qf",
	SF    = "sf",
	FINAL = "final",
}

-- Match win Coin rewards per stage
MatchdaySchedule.WinRewards = {
	group = 500,
	r32   = 1500,
	r16   = 3000,
	qf    = 5000,
	sf    = 7500,
	final = 10000,
}

-- Guaranteed card rarity floor for winning at each stage
MatchdaySchedule.WinCardFloor = {
	group = "Rare",
	r32   = "Rare",
	r16   = "Epic",
	qf    = "Epic",
	sf    = "Legendary",
	final = "Mythic",
}

-- The schedule. matchdayId must be unique.
-- timestamp: Unix epoch seconds UTC when this matchday becomes resolvable.
-- Timestamps computed for 18:00 UTC on each date. Verify against the real
-- broadcast windows and adjust if you want matchdays to fire at a different hour.
MatchdaySchedule.Entries = {
	-- Group Stage matchday 1: 2026-06-11 18:00 UTC
	{ matchdayId = "group_1", stage = "group", timestamp = 1781200800 },
	-- Group Stage matchday 2: 2026-06-18 18:00 UTC
	{ matchdayId = "group_2", stage = "group", timestamp = 1781805600 },
	-- Group Stage matchday 3: 2026-06-25 18:00 UTC
	{ matchdayId = "group_3", stage = "group", timestamp = 1782410400 },
	-- Round of 32: 2026-06-29 18:00 UTC
	{ matchdayId = "r32",     stage = "r32",   timestamp = 1782756000 },
	-- Round of 16: 2026-07-04 18:00 UTC
	{ matchdayId = "r16",     stage = "r16",   timestamp = 1783188000 },
	-- Quarterfinals: 2026-07-09 18:00 UTC
	{ matchdayId = "qf",      stage = "qf",    timestamp = 1783620000 },
	-- Semifinals: 2026-07-14 18:00 UTC
	{ matchdayId = "sf",      stage = "sf",    timestamp = 1784052000 },
	-- Grand Final: 2026-07-19 18:00 UTC
	{ matchdayId = "final",   stage = "final", timestamp = 1784484000 },
}

-- Returns all schedule entries whose timestamp has passed and haven't been resolved yet
-- lastResolvedMatchday is the matchdayId string of the last one resolved (or "" if none)
function MatchdaySchedule.getPendingEntries(lastResolvedMatchday, now)
	local pending = {}
	local found = (lastResolvedMatchday == "" or lastResolvedMatchday == nil)
	for _, entry in ipairs(MatchdaySchedule.Entries) do
		if not found then
			if entry.matchdayId == lastResolvedMatchday then
				found = true
			end
		else
			if now >= entry.timestamp then
				table.insert(pending, entry)
			end
		end
	end
	return pending
end

-- Returns the next unresolved entry (for countdown timers)
function MatchdaySchedule.getNextEntry(lastResolvedMatchday)
	local found = (lastResolvedMatchday == "" or lastResolvedMatchday == nil)
	for _, entry in ipairs(MatchdaySchedule.Entries) do
		if not found then
			if entry.matchdayId == lastResolvedMatchday then
				found = true
			end
		else
			return entry
		end
	end
	return nil
end

return MatchdaySchedule
