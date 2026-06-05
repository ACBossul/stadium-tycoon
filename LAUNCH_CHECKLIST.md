# Stadium Tycoon — Pre-Launch Checklist

Code-side systems are in place; these final items need YOUR Roblox account /
assets (I can't create them from here). Do these before going live.

## 1. Monetization IDs (currently placeholders)
Create the products in your Roblox experience, then paste the real IDs:
- **Game passes** (VIP, 2x Coins, 2x Offline, etc.) → `src/ReplicatedStorage/Config/MonetizationConfig.lua`
- **Developer products** (gem/coin packs, battle-pass premium) → `MonetizationConfig.lua`
- The **battle-pass premium** product id must match in BOTH `MonetizationConfig.lua`
  and `BattlePassConfig.PremiumProductId`.
- Verify each pass/product `id` matches what you set in the Creator Dashboard.

## 2. Card art
Cards currently render a procedural emoji face (no art). To use real art:
- Upload card decals, then set each card's `art = "rbxassetid://…"` in
  `src/ReplicatedStorage/Config/CardCatalog.lua` (replace the `rbxassetid://0`).

## 3. Audio
- SFX use built-in `rbxasset://sounds/…` (already working).
- Background **music**: set `MUSIC_ID` in
  `src/StarterPlayer/StarterPlayerScripts/SoundController.lua` to an audio asset
  you OWN (Roblox audio privacy blocks arbitrary tracks).

## 4. Surface textures (optional)
`PlotService.TEXTURES` / `HubService.TEXTURES` point at decals on the AC6005
account. They work, but confirm they're public / owned by the game's owner.

## 5. Leaderboard (optional upgrade)
The "Top Tycoons" board ranks players **in the current server**. For a true
cross-server global board, back it with an `OrderedDataStore` (needs Studio API
access enabled + a published place).

## 6. Final pass
- Remove the green DEBUG overlay in `ClientMain.client.lua` once you're happy.
- Studio test funds (`Main.server.lua`, gated by `RunService:IsStudio()`) never
  affect live servers — leave as-is.
- Keep all card/club/player names PARODY-ONLY (no real IPs).
