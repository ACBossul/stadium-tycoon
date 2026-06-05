-- SoundController: ambient music + SFX. SFX use Roblox's built-in `rbxasset://`
-- sounds (always available). Background music needs an audio asset you OWN (set
-- MUSIC_ID below) — Roblox audio privacy means we can't ship an arbitrary track.

local Players           = game:GetService("Players")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundController = {}

-- 🎵 Put a music asset id you own here (e.g. "rbxassetid://123456789"); leave ""
-- to run without background music.
local MUSIC_ID = ""

-- Built-in SFX (guaranteed to exist).
local SFX = {
	cash    = "rbxasset://sounds/electronicpingshort.wav",
	success = "rbxasset://sounds/bell.wav",
	error   = "rbxasset://sounds/switch3.wav",
	click   = "rbxasset://sounds/button.wav",
}

local pool = {}
local function makeSound(id, vol, looped)
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = vol or 0.5; s.Looped = looped or false
	s.Parent = SoundService
	return s
end

local function play(name)
	local s = pool[name]
	if s then s.TimePosition = 0; pcall(function() s:Play() end) end
end

function SoundController.playClick() play("click") end

function SoundController.init(_clientState)
	for name, id in pairs(SFX) do pool[name] = makeSound(id, 0.55, false) end

	if MUSIC_ID ~= "" then
		local music = makeSound(MUSIC_ID, 0.18, true)
		pcall(function() music:Play() end)
	end

	-- SFX on server notifications (covers collect / upgrade / purchase / events).
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("ShowNotification")
	if ev then
		ev.OnClientEvent:Connect(function(payload)
			local color = payload and payload.color
			if color == "gold" then play("cash")
			elseif color == "red" then play("error")
			else play("success") end
		end)
	end
end

return SoundController
