# ⚽ Stadium Tycoon: Road to the Final

> Build and upgrade your own football stadium that earns idle cash, spend it on packs of
> absurd meme-player cards, set an 11-card lineup, and watch your squad auto-progress through
> a 48-team bracket that advances on the **same days as the real 2026 tournament** — trade
> duplicate cards with other players to complete your dream team.

A cozy **idle-tycoon + card-collection** game for **Roblox** (Luau / Rojo). Mobile-first,
broad audience, low skill ceiling — built for the *Grow a Garden / Adopt Me* crowd.

---

## ⚠️ IP rule (read before adding anything)

**No real player names, national team badges, club logos, the word "FIFA", or official World
Cup branding/marks — anywhere** (assets, text, thumbnails, or UI). Roblox will take the game
down. Everything is **parody**: invented meme mascots (*Cristiano Ronaldon't*, *Lionel Messy*,
a screaming goat in gloves), generic national colors (*Los Azules*), and a made-up tournament
name (*The Brainrot Cup*). This is also better for the tone.

## Core loop

**Earn** (idle stadium income) → **Spend** (building upgrades + card packs) → **Collect**
(gacha cards by rarity) → **Build squad** (11 cards → Squad Power) → **Compete** (scheduled
bracket fixtures) → **Trade** (swap dupes) → repeat. A 38-day narrative arc tied to the real
tournament keeps players coming back daily.

## Features

- **Idle economy** — per-player plots built at runtime, passive + active income, offline
  earnings with a daily cap, exponential upgrade curves.
- **Cards** — ~30 parody cards across five rarities, weighted packs with guaranteed-rarity
  floors, an animated pack-opening reveal, and procedural emoji art until real decals exist.
- **Squad & bracket** — pick 11, sum Squad Power; the server resolves matchdays on a real
  clock mapped to 2026 fixtures, with a never-dead-end consolation track.
- **Trading** — atomic, server-authoritative card swaps with ownership re-validation, a
  cooldown, and a per-player trade history log for support/disputes.
- **Retention & money** — streak-based daily login rewards; monetization via game passes and
  dev products (`ProcessReceipt`), kept cosmetic/convenience-leaning to protect PvP fairness.

## Tech

- **Luau** in Roblox Studio, synced with **Rojo 7.x**.
- **Server-authoritative** everything — the client only sends requests; the server owns coins,
  cards, trades, and match results.
- All tunable values live in `src/ReplicatedStorage/Config/` ModuleScripts (no code edits to
  rebalance).
- **ProfileService** bundled for session-locked, dupe-safe saves.

## Quick start

1. Install [Rojo](https://rojo.space/) 7.x and the Studio plugin.
2. From this folder: `rojo serve`, then connect from the Rojo plugin in Studio.
3. Press **Play** — a plot with all six buildings is generated and tagged automatically. No
   manual setup.

See **[SETUP.md](SETUP.md)** for the full guide: project layout, balancing knobs, matchday-date
editing, and the pre-publish checklist.

## Status

MVP is **complete and playable in Studio**. The only remaining steps are account-specific:
set your real **monetization IDs** in `MonetizationConfig.lua` and (optionally) upload **card
art**. Everything else — economy, cards, squad, bracket, trading, daily rewards — is wired.

## License

Proprietary — © the author. All rights reserved. Not licensed for reuse or redistribution.
