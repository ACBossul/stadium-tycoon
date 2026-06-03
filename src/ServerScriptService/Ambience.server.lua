-- Ambience: one-time scene lighting + post-processing setup. Server-created so
-- it replicates to every client. All upload-free (built-in sky + post effects).
-- Turns the flat default lighting into a bright, slightly stylized stadium look.

local Lighting = game:GetService("Lighting")

-- ── Core lighting ────────────────────────────────────────────────────────────
Lighting.Brightness            = 2.2
Lighting.ClockTime             = 14.2          -- early-afternoon match light
Lighting.GeographicLatitude    = 20
Lighting.Ambient               = Color3.fromRGB(95, 100, 115)
Lighting.OutdoorAmbient        = Color3.fromRGB(150, 160, 180)
Lighting.ExposureCompensation  = 0.25
Lighting.EnvironmentDiffuseScale  = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows         = true
Lighting.FogEnd                = 5000

local function ensure(className, name, props)
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	for k, v in pairs(props) do
		inst[k] = v
	end
	return inst
end

-- ── Sky (Roblox built-in default skybox — no upload) ─────────────────────────
ensure("Sky", "StadiumSky", {
	SunAngularSize  = 16,
	MoonAngularSize = 11,
	StarCount       = 3000,
})

-- ── Atmosphere: soft depth/haze ──────────────────────────────────────────────
ensure("Atmosphere", "StadiumAtmosphere", {
	Density = 0.32,
	Offset  = 0.1,
	Color   = Color3.fromRGB(199, 210, 225),
	Decay   = Color3.fromRGB(106, 122, 150),
	Glare   = 0.25,
	Haze    = 1.6,
})

-- ── Bloom: glow on Neon screens/floodlights ──────────────────────────────────
ensure("BloomEffect", "StadiumBloom", {
	Intensity = 0.7,
	Size      = 24,
	Threshold = 1.1,
})

-- ── Color grade: a touch more pop ─────────────────────────────────────────────
ensure("ColorCorrectionEffect", "StadiumGrade", {
	Brightness  = 0.0,
	Contrast    = 0.08,
	Saturation  = 0.12,
	TintColor   = Color3.fromRGB(255, 252, 245),
})

-- ── Subtle sun rays through the structures ───────────────────────────────────
ensure("SunRaysEffect", "StadiumSunRays", {
	Intensity = 0.06,
	Spread    = 0.5,
})

print("[StadiumTycoon] Ambience applied.")
