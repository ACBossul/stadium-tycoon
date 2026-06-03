# Card Art Prompts — Stadium Tycoon

30 ready-to-paste prompts for an AI image tool (Midjourney, DALL·E, Leonardo, SDXL, etc.),
one per card in `CardCatalog.lua`. Generate → upload each as a **Decal** in Roblox Studio →
paste the asset IDs back and they get wired into each card's `art` field (replacing the emoji).

## ⚠️ IP rule (non-negotiable)
NO real player names, real faces/likenesses, real club or national jerseys/badges, "FIFA", or
official World Cup branding. These are **invented parody mascots**. Keep kits generic (plain
colors, no crests). If a tool starts drawing a recognizable real person, add "original
character, not a real person" and reroll.

## Style preamble (prepend to EVERY prompt for a consistent set)
> Vibrant 3D cartoon mascot character, mobile collectible-card game art, Roblox-friendly,
> bold clean outlines, exaggerated proportions, dynamic hero pose, centered, square 1:1
> composition, soft studio rim light, simple dark radial-gradient background, no text, no
> logos, no watermark —

## Rarity flair (append per card so art matches the in-game rarity frame)
- **Common** — plain dark background, no aura
- **Rare** — subtle blue energy glow
- **Epic** — glowing purple magical aura
- **Legendary** — radiant golden aura, floating sparks
- **Mythic** — intense red/holographic rainbow aura, dramatic god-rays, premium

---

## Goalkeepers
- **the_wall** (Legendary, GK) — a stout, confident goalkeeper whose body is a solid brick wall, big goalie gloves, immovable stance. *Golden aura.*
- **screaming_goat_gk** (Rare, GK) — a goat wearing goalkeeper gloves mid-leap, mouth open in a dramatic scream, comedic diving save. *Blue glow.*
- **brick_hands** (Common, GK) — a goofy goalkeeper with comically oversized, clumsy brick-textured gloves, sheepish grin. *Plain bg.*
- **jelly_keeper** (Epic, GK) — a wobbly translucent jelly/pudding blob creature acting as a goalkeeper, bouncy and gelatinous. *Purple aura.*
- **npc_keeper** (Common, GK) — a blocky low-poly "video-game NPC" goalkeeper with a blank vacant stare, default-character look. *Plain bg.*

## Defenders
- **slab_jones** (Rare, DEF) — a huge stoic defender carved from a granite stone slab, rocky muscles, arms crossed. *Blue glow.*
- **capybara_boots** (Epic, DEF) — a chill, relaxed capybara wearing tiny soccer boots, unbothered defensive stance. *Purple aura.*
- **wooden_wall** (Common, DEF) — a defender built from wooden fence planks, sturdy and rectangular, splinter texture. *Plain bg.*
- **mr_offside** (Common, DEF) — a sneaky, smug defender holding up a tiny linesman's offside flag, raised eyebrow. *Plain bg.*
- **tank_bricksworth** (Rare, DEF) — a heavy armored defender like a walking tank, riveted metal plating and a small shield. *Blue glow.*
- **soggy_boots_dan** (Common, DEF) — a miserable rain-soaked defender squelching in waterlogged boots, drips and a tiny puddle. *Plain bg.*
- **giant_crab_def** (Legendary, DEF) — a giant armored crab defender, big claws raised, sideways scuttling stance, barnacles. *Golden aura.*

## Midfielders
- **ronaldont** (Legendary, MID) — a cocky midfielder in sunglasses doing a flashy mid-air celebration jump, glossy hair, generic kit. Original character, not a real person. *Golden aura.*
- **messy** (Mythic, MID) — a tiny nimble midfielder dressed as a stage magician with a wand and top hat, dribbling a ball trailing sparkles. Original character, not a real person. *Holographic red aura, god-rays.*
- **dribble_king** (Rare, MID) — a confident midfielder wearing a golden crown, fancy footwork over the ball. *Blue glow.*
- **flopsy** (Common, MID) — a clownish midfielder dramatically flopping/diving as if fouled, exaggerated agony, clown nose. *Plain bg.*
- **spinning_raccoon** (Epic, MID) — a raccoon spinning rapidly with the ball, motion-blur swirl, mischievous. *Purple aura.*
- **noodle_legs** (Rare, MID) — a midfielder with floppy wobbly noodle/spaghetti legs, comedic loss of balance. *Blue glow.*
- **the_tourist** (Common, MID) — a confused tourist accidentally on the pitch, Hawaiian shirt, sun hat, camera around neck. *Plain bg.*
- **wifi_warrior** (Epic, MID) — a techy gamer midfielder surrounded by floating wifi-signal and emoji icons, headset, online-warrior vibe. *Purple aura.*

## Forwards
- **mbappew** (Mythic, FWD) — a hyper-fast forward blasting forward with rocket boosters and flame trails on the boots, speed lines. Original character, not a real person. *Holographic red aura, god-rays.*
- **golden_hamster** (Legendary, FWD) — a small but mighty glowing golden hamster striker, cheeks puffed, heroic. *Golden aura.*
- **dr_dribbles** (Rare, FWD) — a mad-scientist forward in a lab coat and goggles holding a bubbling beaker, inventive grin. *Blue glow.*
- **tripping_hazard** (Common, FWD) — a clumsy forward tripping over the ball mid-stride, yellow warning-sign motif, flailing. *Plain bg.*
- **hairy_striker** (Common, FWD) — a big brawny hairy ape-like striker, chest out, confident. *Plain bg.*
- **el_fantasma** (Epic, FWD) — a ghostly translucent forward phasing through the air to strike, spooky glow, trailing wisps. *Purple aura.*
- **penguin_pete** (Rare, FWD) — a penguin striker sliding on its belly to tap in a goal, joyful. *Blue glow.*
- **the_finisher** (Legendary, FWD) — a robotic terminator-style striker with a glowing red targeting eye, locked onto the ball, chrome. *Golden aura.*
- **sneaky_ferret** (Common, FWD) — a sneaky ferret forward darting low with the ball, sly grin, quick. *Plain bg.*
- **sus_striker** (Rare, FWD) — a shifty hooded striker with suspicious darting eyes, sneaking glance over shoulder, generic colored hood. *Blue glow.*

---

## Workflow
1. For each card: paste the **style preamble** + the card line + its **rarity flair**.
2. Generate at **1:1 (square)**, ideally 512×512 or 1024×1024.
3. In Studio: right-click in Asset Manager → **Add Images**, upload each PNG (it becomes a Decal/Image asset). Name them by card id (e.g. `the_wall`).
4. Send back the list of `cardId → assetId`. I'll set each card's `art = "rbxassetid://<id>"` in `CardCatalog.lua`. Any card with real `art` automatically shows the image instead of the emoji.
