# Stadium Tycoon: Road to the Final — Setup Guide

## Prerequisites
- Roblox Studio
- Rojo 7.x (`rojo serve` to sync files)

ProfileService is **already bundled** at `src/ServerScriptService/Packages/ProfileService.lua`
(pinned to MadStudioRoblox v1.x). No manual download needed.

## Project structure
```
src/
  ReplicatedStorage/
    Config/
      CardCatalog.lua        -- all card definitions (~30 cards)
      BuildingConfig.lua     -- income rates, upgrade cost curves
      MatchdaySchedule.lua   -- tournament dates (Unix timestamps, computed for 2026)
      PackConfig.lua         -- pack types, costs, drop rate boosts
      MonetizationConfig.lua -- game pass and dev product IDs
      DailyRewardConfig.lua  -- 7-day login reward track + timing windows
    InitRemotes.lua          -- creates all RemoteEvents/Functions
  ServerScriptService/
    Main.server.lua          -- server entry point, boots all services
    DataService.lua          -- ProfileService wrapper
    EconomyService.lua       -- idle income, offline earnings, upgrades
    CardService.lua          -- pack rolls, inventory, squad power
    BracketService.lua       -- matchday resolution, bracket progression
    TradeService.lua         -- atomic player-to-player card swaps (client-relative state)
    MonetizationService.lua  -- ProcessReceipt, game pass sync
    PlotService.lua          -- runtime-builds each player's tagged stadium plot
    DailyRewardService.lua   -- streak-based daily login rewards
    Packages/
      ProfileService.lua     -- bundled (session-locking save/load)
  StarterPlayer/StarterPlayerScripts/
    ClientMain.client.lua    -- client bootstrap, wires all server events
    UIController.lua          (ModuleScript) toast, HUD updates, screen nav
    PackOpenController.lua    (ModuleScript) animated card reveal
    BracketController.lua     (ModuleScript) countdown timer
    StadiumController.lua     (ModuleScript) building interaction (owner-gated)
  StarterGui/                -- all .client.lua = LocalScripts that build their UI
    HUD.client.lua           -- top coin/gem bar + bottom nav (incl. Trade button)
    ShopScreen.client.lua    -- packs + game passes + gem bundles
    SquadBuilderScreen.client.lua -- lineup picker
    BracketScreen.client.lua -- stage + countdown
    CollectionScreen.client.lua   -- card book with rarity filter
    TradeScreen.client.lua   -- browse players + two-sided trade window
    DailyRewardScreen.client.lua  -- daily login popup with streak track
```

> File-type mapping matters in Rojo: `*.server.lua` → Script, `*.client.lua` → LocalScript,
> plain `*.lua` → ModuleScript. The StarterGui screens MUST stay `.client.lua` or they won't run.

## First-time Studio setup

1. Open Roblox Studio, create a blank baseplate (you can delete the default baseplate —
   `PlotService` builds ground for each player).
2. Run `rojo serve` in this directory and connect via the Rojo plugin.
3. Press Play. That's it — a plot with all six buildings is generated and tagged for you,
   and your character is teleported onto it. No manual model placement or tagging required.

### Before you publish (account-specific — needs your Creator Dashboard)
These two are the only things tied to your Roblox account and can't be pre-filled:

1. **Monetization IDs** — replace the placeholder `000000001` game-pass IDs and `100000001`
   product IDs in `MonetizationConfig.lua` with the real IDs you create on the Creator Dashboard.
   The code runs fine with placeholders in Studio (`UserOwnsGamePassAsync` is wrapped in pcall),
   so you can build and test everything else first.
2. **Card art (optional)** — `CardCatalog.lua` uses `rbxassetid://0` placeholders. Until you
   upload real art, each card renders a **procedural face**: its `emoji` on a rarity-colored
   gradient (in packs, the collection book, and trade chips), so the game looks designed, not
   broken. To use real images, set each card's `art` to an uploaded decal ID — any card with a
   real `art` automatically shows the image instead of the emoji.

Everything else — ProfileService, the stadium plot, and the fixture timestamps (computed for
18:00 UTC on each 2026 matchday) — is already wired.

## Balance tuning
All numbers are in `Config/` ModuleScripts. The main knobs:
- `BuildingConfig.Buildings[].baseRate` — income per second per building
- `BuildingConfig.Buildings[].baseCost / costMult` — upgrade price curve
- `CardCatalog.DropRates` — pack rarity percentages
- `MatchdaySchedule.WinRewards` — Coin payout per stage win
- `BuildingConfig.OFFLINE_CAP` — max hours of idle earnings (default 8h)
- `DailyRewardConfig.Rewards` — the 7-day login track; `COOLDOWN_SECONDS` (claim
  window, default 20h) and `STREAK_BREAK_SECONDS` (streak reset, default 48h)

## Trading (built)
Fully implemented and server-authoritative:
- Open the **Trade** tab → tap an online player → **Request**. Both players get the window.
- Add up to 5 of your cards (equipped squad cards are hidden to avoid dangling lineups),
  see the other side's offer live, then **Confirm**. Any offer change re-arms both confirms.
- The swap is a single atomic server op with an ownership re-check at swap time, a 60s
  post-trade cooldown, and an immediate forced save for both players. The client never
  decides ownership — `TradeService` re-validates everything.
- **Trade history:** every completed swap is recorded to both players' profiles
  (`data.tradeLog`, last 25 each) with a shared trade `id`, timestamp, partner, and the
  `gave`/`got` card lists — so you can review or unwind a disputed trade from either side.

## Adjusting matchday dates
`MatchdaySchedule.Entries` holds Unix timestamps (UTC). Current values fire at 18:00 UTC on
each real 2026 matchday. To shift a date, change the `timestamp`. Quick converter in any
Luau console: `os.time({year=2026, month=6, day=11, hour=18, min=0, sec=0})` (interpreted as
local time — compute in UTC or adjust for your offset).

## IP / legal reminder
NO real player names, real national badge logos, FIFA marks, or official World Cup branding
anywhere in assets, text, thumbnails, or UI. Everything must be parody. See spec §top.

## Post-launch stretch features
After stable MVP ships:
- Cosmetic stadium themes (sell via game passes / dev products)
- Card fusion (convert duplicates into higher rarity)
- Group leaderboards / friends comparison
- Post-final "Legacy" weekly recurring cup (soft-reset the bracket)
- Matchday-themed limited packs tied to `MatchdaySchedule` stages

Done and shipping in MVP: idle economy + offline earnings, packs + pack-opening,
collection book, squad builder, scheduled bracket, monetization (`ProcessReceipt` +
game-pass buttons), **trading**, and **daily login rewards**.
