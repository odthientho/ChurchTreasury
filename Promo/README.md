# Church Treasury — Promo Videos

Two videos, both 1080×1920 portrait, 30 fps, H.264 + AAC, captions + soft ambient music:

### ⭐ `ChurchTreasury_Walkthrough.mp4` — the continuous screen-recorded walkthrough (~37 s, ~3.6 MB)
**One continuous full-screen screen recording** of the app being used — a single take that walks
through **all four tabs** (Offerings → Expenses → Reports → More) with a detailed click in each.
Every tap shows a **blue "click" ripple** so you can see exactly what's being pressed, real
navigation animations play, a clean lower-third **caption** narrates each step, and there is **no
music**. Recorded with `xcrun simctl io recordVideo` at device resolution (1080×2346).

Flow: browse Offerings by month → open a collection & expand the cash breakdown → Expenses list →
regular-bill checklist → Reports → generate the monthly treasurer PDF → More → a donor profile with
giving history.

The tap-ripples come from a DEBUG-only helper (`ChurchTreasury/Services/TouchIndicator.swift`) that
only runs under the `-showTouches` launch argument — it never appears in a normal launch. Record with:
`xcrun simctl launch booted com.odthientho.ChurchTreasury -seedMockData -showTouches`.
Captions/trim are applied afterward by `build/cont_caps.py`.

### `ChurchTreasury_Promo.mp4` — the sizzle/slideshow cut (~1 min 58 s, ~32 MB)
Polished still frames with a slow push-in (Ken Burns) and crossfades — a punchier "highlight reel"
alternative. Good for a hero banner or App Store preview.

## Storyboard (14 slides, ~9.5 s each)

| # | Screen | Caption |
|---|--------|---------|
| 0 | Title | **Church Treasury** — "The complete treasurer's assistant, right in your pocket." |
| 1 | Offerings (month) | **Record every Sunday offering** — checks, envelope cash & loose cash |
| 2 | Collection detail | **See each collection in full** — checks, cash, reimbursements & bank deposit |
| 3 | Cash breakdown | **Every dollar accounted for** — envelope cash + loose plate cash |
| 4 | Loose-cash counter | **Count loose cash by the bill** — totals add up automatically |
| 5 | Expenses list | **Track every expense** — by category, method & payee |
| 6 | Regular checklist | **Never miss a regular bill** — one-tap monthly checklist |
| 7 | Reimbursements | **Reimbursements made simple** — request → paid |
| 8 | Monthly report PDF | **A polished monthly report** — one tap to a treasurer's PDF |
| 9 | Donor detail | **Know every giver** — history, aliases & legal names |
| 10 | Giving statements | **Giving statements for taxes** — year-end receipts per donor |
| 11 | Reports home | **Every report you need** — weekly, monthly, year-end & audit |
| 12 | Built-in help | **Help built right in** — English & Vietnamese |
| 13 | Outro | **Church Treasury** — Private · On-device · Bilingual |

## Folders

- `ChurchTreasury_Promo.mp4` — the finished video.
- `slides/` — the 14 composed 1080×1920 frames (also usable as social graphics).
- `screenshots/` — the 15 clean device screenshots (great as **App Store screenshots**).
- `contact_sheet.png` — overview of all slides.

## How it was made / how to regenerate

1. **Mock data** — the app ships with a DEBUG-only seeder (`ChurchTreasury/Services/MockDataSeeder.swift`).
   Launch with the `-seedMockData` argument to wipe and load the curated demo dataset:
   ```
   xcrun simctl launch booted com.odthientho.ChurchTreasury -seedMockData
   ```
   (It only compiles/works in Debug builds and never runs in a normal launch.)
2. **Screenshots** — captured clean with `xcrun simctl io booted screenshot`.
3. **Slides** — composed with `build/compose.py` (Python + Pillow).
4. **Video** — assembled with `build/assemble.py` (ffmpeg: zoompan + xfade + a synthesized pad).

To re-render after changing captions/screens: rerun `compose.py` then `assemble.py`.

## Notes / easy swaps

- **Music**: currently a soft synthesized pad (royalty-free because it's generated). Drop in your own
  licensed track by muxing it over `video.mp4` if you prefer.
- **Length**: ~2 min. Trim by removing slides in `assemble.py` (the `durs` list) or shortening `9.5`.
- The demo shows a real configured church ("Vietnamese Alliance Church of North Atlanta") to look
  authentic; the app itself is generic and every church sets its own name/logo in **More → Church Info**.
