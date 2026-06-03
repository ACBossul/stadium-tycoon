# Art pipeline

Everything here is the **art handoff**: assets I can prepare without your account, plus the
prompts for the art only you (or an AI tool / artist) can generate. The wiring back into the
game is on me — you just upload and send asset IDs.

## 1. Card art — `CARD_PROMPTS.md`
30 ready-to-paste AI prompts (one per card), parody-safe and IP-compliant, with a shared style
preamble for a consistent set. **Workflow:** generate → upload each as a Decal in Studio →
send me `cardId → assetId`. I set each card's `art` in `CardCatalog.lua` (it auto-overrides the
emoji placeholder).

## 2. Surface textures — `textures/*.png` (already generated)
Real, tileable 512×512 PNGs produced procedurally (no artist needed):

| File | Use |
|------|-----|
| `pitch_grass.png` | stadium ground / pitch |
| `stand_seats.png` | the stands (parody team colors) |
| `brick.png` | concession / merch booth walls |
| `metal_panel.png` | big-screen frame, floodlight poles |
| `asphalt.png` | parking lot |

**Workflow:** upload each in Studio (Asset Manager → Add Images) → send me the asset IDs. I'll
apply them to the building parts via `Texture` / `SurfaceAppearance` in `PlotService`.

Regenerate anytime:
- Windows (no installs): `powershell -ExecutionPolicy Bypass -File art\generate_textures.ps1`
- Cross-platform (needs `pip install pillow`): `python art/generate_textures.py`

## The handoff, in one line
You upload → paste me the asset IDs → I plug them in. The code slots are already there.
