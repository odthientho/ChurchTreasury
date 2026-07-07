#!/usr/bin/env python3
"""Compose branded 1080x1920 promo slides for the ChurchTreasury demo video."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE = "/private/tmp/claude-501/-Users-odthientho-Library-CloudStorage-OneDrive-GeorgiaInstituteofTechnology-ClaudeCode/58ab6775-b864-442e-b7bc-a7ef44688ebd/scratchpad"
SHOTS = os.path.join(BASE, "shots")
SLIDES = os.path.join(BASE, "slides")
os.makedirs(SLIDES, exist_ok=True)

W, H = 1080, 1920
GOLD = (232, 184, 92)
WHITE = (246, 248, 249)
SUB = (183, 202, 209)
TOP = (13, 33, 45)
BOT = (17, 66, 80)

AVENIR = "/System/Library/Fonts/Avenir Next.ttc"          # Bold by default
HELV = "/System/Library/Fonts/HelveticaNeue.ttc"          # Regular by default

def font(path, size):
    return ImageFont.truetype(path, size)

def title_font(size):  return font(AVENIR, size)
def body_font(size):   return font(HELV, size)

def gradient_bg():
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    for y in range(H):
        t = y / (H - 1)
        r = int(TOP[0] + (BOT[0] - TOP[0]) * t)
        g = int(TOP[1] + (BOT[1] - TOP[1]) * t)
        b = int(TOP[2] + (BOT[2] - TOP[2]) * t)
        for x in range(W):
            px[x, y] = (r, g, b)
    # Vignette
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-W*0.35, -H*0.15, W*1.35, H*1.15], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(220))
    dark = Image.new("RGB", (W, H), (4, 14, 20))
    bg = Image.composite(bg, dark, vig)
    return bg.convert("RGBA")

def glow(bg, cx, cy, rw, rh, color=GOLD, alpha=60):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx-rw, cy-rh, cx+rw, cy+rh], fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(120))
    bg.alpha_composite(layer)

def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]], radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out

def place_phone(bg, shot_path, target_h, top_y):
    shot = Image.open(shot_path).convert("RGBA")
    scale = target_h / shot.height
    tw = int(shot.width * scale)
    shot = shot.resize((tw, target_h), Image.LANCZOS)
    shot = rounded(shot, 44)
    x = (W - tw) // 2
    # Shadow
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([x, top_y+18, x+tw, top_y+target_h+18], 44, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    bg.alpha_composite(shadow)
    # Thin light border for a crisp edge
    border = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle([x-1, top_y-1, x+tw+1, top_y+target_h+1], 45,
                                             outline=(255, 255, 255, 40), width=2)
    bg.alpha_composite(border)
    bg.alpha_composite(shot, (x, top_y))

def text_w(draw, s, fnt, tracking=0):
    w = draw.textlength(s, font=fnt)
    if tracking:
        w += tracking * max(len(s) - 1, 0)
    return w

def draw_tracked(draw, xy, s, fnt, fill, tracking):
    x, y = xy
    for ch in s:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking

def wrap(draw, s, fnt, max_w):
    words = s.split()
    lines, cur = [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines

def centered(draw, y, s, fnt, fill, tracking=0):
    w = text_w(draw, s, fnt, tracking)
    x = (W - w) / 2
    if tracking:
        draw_tracked(draw, (x, y), s, fnt, fill, tracking)
    else:
        draw.text((x, y), s, font=fnt, fill=fill)

def feature_slide(idx, shot, eyebrow, title, subtitle):
    bg = gradient_bg()
    glow(bg, W/2, 1120, 520, 560, GOLD, 34)
    d = ImageDraw.Draw(bg)
    # Eyebrow
    ef = title_font(30)
    centered(d, 150, eyebrow.upper(), ef, GOLD, tracking=8)
    # Title (up to 2 lines)
    tf = title_font(70)
    tlines = wrap(d, title, tf, 980)
    ty = 205
    for ln in tlines:
        centered(d, ty, ln, tf, WHITE)
        ty += 82
    # Gold rule
    rule_w = 96
    d.rounded_rectangle([(W-rule_w)/2, ty+6, (W+rule_w)/2, ty+12], 3, fill=GOLD)
    # Subtitle
    sf = body_font(37)
    sy = ty + 40
    for ln in wrap(d, subtitle, sf, 940):
        centered(d, sy, ln, sf, SUB)
        sy += 48
    # Phone
    place_phone(bg, os.path.join(SHOTS, shot), target_h=1230, top_y=560)
    # Footer wordmark
    ff = title_font(34)
    centered(d, 1852, "CHURCH  TREASURY", ff, (222, 226, 228), tracking=6)
    bg.convert("RGB").save(os.path.join(SLIDES, f"slide_{idx:02d}.png"), quality=95)

def cross_emblem(bg, cx, cy, size):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([cx-size, cy-size, cx+size, cy+size], outline=GOLD, width=6)
    arm = size*0.16
    v = size*0.52
    h = size*0.40
    d.rounded_rectangle([cx-arm, cy-v, cx+arm, cy+v], int(arm), fill=GOLD)
    d.rounded_rectangle([cx-h, cy-arm*0.7, cx+h, cy+arm*0.7], int(arm*0.7), fill=GOLD)
    bg.alpha_composite(layer)

def title_slide(idx, title, tagline, footer):
    bg = gradient_bg()
    glow(bg, W/2, 900, 560, 620, GOLD, 40)
    d = ImageDraw.Draw(bg)
    cross_emblem(bg, W/2, 640, 92)
    tf = title_font(96)
    centered(d, 800, title, tf, WHITE, tracking=1)
    rw = 120
    d.rounded_rectangle([(W-rw)/2, 930, (W+rw)/2, 937], 3, fill=GOLD)
    sf = body_font(42)
    sy = 985
    for ln in wrap(d, tagline, sf, 900):
        centered(d, sy, ln, sf, SUB)
        sy += 56
    if footer:
        ftf = title_font(32)
        centered(d, 1740, footer.upper(), ftf, GOLD, tracking=6)
    bg.convert("RGB").save(os.path.join(SLIDES, f"slide_{idx:02d}.png"), quality=95)

def outro_slide(idx, title, keywords, cta):
    bg = gradient_bg()
    glow(bg, W/2, 960, 600, 640, GOLD, 42)
    d = ImageDraw.Draw(bg)
    cross_emblem(bg, W/2, 700, 88)
    tf = title_font(90)
    centered(d, 850, title, tf, WHITE, tracking=1)
    kf = title_font(40)
    centered(d, 985, keywords, kf, GOLD, tracking=3)
    sf = body_font(40)
    sy = 1085
    for ln in wrap(d, cta, sf, 900):
        centered(d, sy, ln, sf, SUB)
        sy += 54
    bg.convert("RGB").save(os.path.join(SLIDES, f"slide_{idx:02d}.png"), quality=95)

# ---- Slide deck ----
title_slide(0, "Church Treasury",
            "The complete treasurer's assistant — right in your pocket.",
            "For churches of every size")

features = [
    ("02_offerings_june.png",        "Offerings",   "Record every Sunday offering",
        "Checks, envelope cash and loose cash — logged in seconds, week by week."),
    ("03_batch_detail.png",          "Collections", "See each collection in full",
        "Checks, cash, on-the-spot reimbursements and the exact bank deposit."),
    ("04_batch_cash_expanded.png",   "Accuracy",    "Every dollar accounted for",
        "Expand any collection to see envelope cash and loose plate cash."),
    ("05_loose_cash.png",            "Cash",        "Count loose cash by the bill",
        "Enter how many of each bill — the totals add up automatically."),
    ("07_expenses_june.png",         "Expenses",    "Track every expense",
        "Organized by category, payment method and payee, month by month."),
    ("08_regular_checklist.png",     "Reminders",   "Never miss a regular bill",
        "A monthly checklist of recurring expenses — one tap to record each."),
    ("06_expenses_july_pending.png", "Reimburse",   "Reimbursements made simple",
        "Track money owed from request to paid, without missing a receipt."),
    ("10_monthly_report.png",        "Reports",     "A polished monthly report",
        "One tap turns the month into a professional treasurer's PDF."),
    ("13_donor_detail.png",          "Donors",      "Know every giver",
        "Giving history, alternate spellings and legal names — all in one place."),
    ("15_giving_statements.png",     "Year-End",    "Giving statements for taxes",
        "Year-end tax receipts for every donor, ready to print or send."),
    ("09_reports_home.png",          "Everything",  "Every report you need",
        "Weekly, monthly, year-in-review and a full audit packet."),
    ("14_about_help.png",            "Guidance",    "Help built right in",
        "Step-by-step guides — in English and Vietnamese."),
]
for i, (shot, eye, ttl, sub) in enumerate(features, start=1):
    feature_slide(i, shot, eye, ttl, sub)

outro_slide(len(features)+1, "Church Treasury",
            "Private  ·  On-device  ·  Bilingual",
            "Everything a church treasurer needs — in one simple app.")

print("slides written:", len(os.listdir(SLIDES)))
