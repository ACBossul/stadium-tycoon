-- EventConfig: time-limited pack events, windows derived from MatchdaySchedule.
-- Server-enforced (CardService rejects event packs outside their window) AND
-- client-rendered (Shop shows active events with a live countdown).
--
-- Each event makes a PackConfig EventPack purchasable within [startsAt, endsAt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchdaySchedule  = require(ReplicatedStorage.Config.MatchdaySchedule)

local EventConfig = {}

local HOUR = 3600

-- matchdayId -> timestamp
local ts = {}
for _, e in ipairs(MatchdaySchedule.Entries) do
	ts[e.matchdayId] = e.timestamp
end

-- Group/knockout drops run from their matchday until the next one (rotating,
-- so there's always a live pack during the tournament). The Grand Final is a
-- tight 48h headline window with massively boosted Mythic odds.
EventConfig.Events = {
	{ id = "ev_g1",    name = "Kickoff Drop",       packId = "ev_matchday",   badge = "MATCHDAY",    startsAt = ts.group_1, endsAt = ts.group_2 },
	{ id = "ev_g2",    name = "Matchday 2 Drop",    packId = "ev_matchday",   badge = "MATCHDAY",    startsAt = ts.group_2, endsAt = ts.group_3 },
	{ id = "ev_g3",    name = "Matchday 3 Drop",    packId = "ev_matchday",   badge = "MATCHDAY",    startsAt = ts.group_3, endsAt = ts.r32 },
	{ id = "ev_r32",   name = "Round of 32 Drop",   packId = "ev_knockout",   badge = "KNOCKOUT",    startsAt = ts.r32,     endsAt = ts.r16 },
	{ id = "ev_r16",   name = "Round of 16 Drop",   packId = "ev_knockout",   badge = "KNOCKOUT",    startsAt = ts.r16,     endsAt = ts.qf },
	{ id = "ev_qf",    name = "Quarterfinal Drop",  packId = "ev_knockout",   badge = "KNOCKOUT",    startsAt = ts.qf,      endsAt = ts.sf },
	{ id = "ev_sf",    name = "Semifinal Drop",     packId = "ev_knockout",   badge = "KNOCKOUT",    startsAt = ts.sf,      endsAt = ts.final },
	{ id = "ev_final", name = "Grand Final Mega",   packId = "ev_grandfinal", badge = "GRAND FINAL", startsAt = ts.final,   endsAt = ts.final + 48 * HOUR },
}

function EventConfig.isActive(event, now)
	return now >= event.startsAt and now < event.endsAt
end

-- All events live at `now` (usually 0 or 1 of them).
function EventConfig.activeEvents(now)
	local out = {}
	for _, ev in ipairs(EventConfig.Events) do
		if EventConfig.isActive(ev, now) then
			table.insert(out, ev)
		end
	end
	return out
end

-- The active event currently enabling `packId`, or nil.
function EventConfig.activeEventForPack(packId, now)
	for _, ev in ipairs(EventConfig.Events) do
		if ev.packId == packId and EventConfig.isActive(ev, now) then
			return ev
		end
	end
	return nil
end

return EventConfig
