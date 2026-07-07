#!/usr/bin/env python3
"""Full-screen walkthrough: raw device recordings at full frame, caption overlay
only (top band that fades into the screen), no background, no music."""
import os, subprocess
from PIL import Image, ImageDraw, ImageFont

BASE = "/private/tmp/claude-501/-Users-odthientho-Library-CloudStorage-OneDrive-GeorgiaInstituteofTechnology-ClaudeCode/58ab6775-b864-442e-b7bc-a7ef44688ebd/scratchpad"
CLIPS = os.path.join(BASE, "clips")
WORK = os.path.join(BASE, "fullwork"); os.makedirs(WORK, exist_ok=True)
FF = "/opt/homebrew/bin/ffmpeg"
FPS = 30
T = 0.35                     # short crossfade
OW, OH = 1080, 2346          # full device aspect (1320x2868 -> width 1080)

GOLD = (232, 184, 92)
WHITE = (248, 250, 251)
SUB = (206, 216, 221)
AVENIR = "/System/Library/Fonts/Avenir Next.ttc"
HELV = "/System/Library/Fonts/HelveticaNeue.ttc"
def tf(s): return ImageFont.truetype(AVENIR, s)
def bf(s): return ImageFont.truetype(HELV, s)

def run(cmd, name):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"ERROR {name}:\n", r.stderr[-2500:]); raise SystemExit(1)

def probe_dur(path):
    r = subprocess.run(["/opt/homebrew/bin/ffprobe", "-v", "error",
                        "-show_entries", "format=duration", "-of",
                        "default=nw=1:nk=1", path], capture_output=True, text=True)
    return float(r.stdout.strip())

def wrap(d, s, fnt, mw):
    out, cur = [], ""
    for w in s.split():
        t = (cur+" "+w).strip()
        if d.textlength(t, font=fnt) <= mw: cur = t
        else: out.append(cur); cur = w
    if cur: out.append(cur)
    return out

def center(d, y, s, fnt, fill):
    d.text(((OW-d.textlength(s, font=fnt))/2, y), s, font=fnt, fill=fill)

def tracked(d, y, s, fnt, fill, tr):
    w = sum(d.textlength(c, font=fnt)+tr for c in s)-tr
    x = (OW-w)/2
    for c in s:
        d.text((x, y), c, font=fnt, fill=fill); x += d.textlength(c, font=fnt)+tr

def caption_png(path, eyebrow, title, subtitle):
    """Clean lower-third caption card that floats over the app's empty lower
    area (keeps the app's own title bar and tab bar clear)."""
    img = Image.new("RGBA", (OW, OH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ef, tfnt, sfnt = tf(30), tf(50), bf(33)
    tlines = wrap(d, title, tfnt, 860)
    slines = wrap(d, subtitle, sfnt, 860)
    pad_x, pad_top, pad_bot = 56, 42, 46
    eb_h, t_lh, s_lh = 46, 60, 44
    content_h = eb_h + len(tlines)*t_lh + 14 + len(slines)*s_lh
    card_w = 984
    card_h = content_h + pad_top + pad_bot
    x0 = (OW - card_w)/2
    bottom = 2116                         # sits just above the tab bar
    top = bottom - card_h
    card = Image.new("RGBA", (OW, OH), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([x0, top, x0+card_w, bottom], 32,
                                           fill=(9, 13, 17, 231))
    img.alpha_composite(card)
    y = top + pad_top
    tracked(d, y, eyebrow.upper(), ef, GOLD, 8); y += eb_h
    for ln in tlines:
        center(d, y, ln, tfnt, WHITE); y += t_lh
    y += 14
    for ln in slines:
        center(d, y, ln, sfnt, SUB); y += s_lh
    img.save(path)

scenes = [
    ("clip01.mp4", 6.0,  "Offerings",  "Browse every Sunday's giving",
        "Move month to month through recorded collections."),
    ("clip02.mp4", 8.2,  "A collection", "See exactly what came in",
        "Checks, cash, on-the-spot reimbursements — and the bank deposit."),
    ("clip03.mp4", 6.8,  "Loose cash", "Count cash by the bill",
        "Enter how many of each note; the total adds up instantly."),
    ("clip04.mp4", 8.5,  "Expenses",   "Track every expense",
        "Filed by category, payment method and payee."),
    ("clip05.mp4", 5.5,  "Reminders",  "Never miss a regular bill",
        "A monthly checklist confirms each recurring expense is recorded."),
    ("clip06.mp4", 10.5, "Reports",    "One-tap monthly report",
        "The whole month becomes a professional PDF to print or share."),
    ("clip07.mp4", 6.5,  "Donors",     "Know every giver",
        "Names, aliases and each person's full giving history."),
    ("clip08.mp4", 7.5,  "Year-end",   "Giving statements for taxes",
        "Year-end receipts for every donor, ready to export."),
    ("clip09.mp4", 6.0,  "Guidance",   "Help built right in",
        "Plain-language answers, in English and Vietnamese."),
]

segs = []
for i, (clip, tail, eye, title, sub) in enumerate(scenes, 1):
    cap = os.path.join(WORK, f"cap_{i:02d}.png")
    caption_png(cap, eye, title, sub)
    out = os.path.join(WORK, f"seg_{i:02d}.mp4")
    cpath = os.path.join(CLIPS, clip)
    dur = probe_dur(cpath)
    start = max(0.0, dur - tail)
    seglen = min(tail, dur)
    # Normalize to CFR 30fps first (simctl records VFR and drops frames on
    # static screens), THEN trim the tail by timestamp — input -ss is unreliable.
    run([FF, "-y", "-i", cpath, "-loop", "1", "-i", cap,
         "-filter_complex",
         f"[0:v]fps={FPS},scale={OW}:{OH},setsar=1,"
         f"trim=start={start:.3f},setpts=PTS-STARTPTS[v];"
         f"[v][1:v]overlay=0:0:eof_action=pass,format=yuv420p[out]",
         "-map", "[out]", "-r", str(FPS), "-t", f"{seglen:.3f}", "-an",
         "-c:v", "libx264", "-crf", "20", "-preset", "medium", out], "seg "+str(i))
    segs.append((out, seglen))

# xfade chain
inputs = []
for p, _ in segs: inputs += ["-i", p]
fc = []; prev = "0:v"; accA = segs[0][1]
for k in range(1, len(segs)):
    off = accA - T; o = f"x{k}"
    fc.append(f"[{prev}][{k}:v]xfade=transition=fade:duration={T}:offset={off:.3f}[{o}]")
    accA += segs[k][1] - T; prev = o
final = os.path.join(BASE, "ChurchTreasury_Walkthrough_Fullscreen.mp4")
run([FF, "-y", *inputs, "-filter_complex", ";".join(fc), "-map", f"[{prev}]",
     "-r", str(FPS), "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p",
     "-crf", "20", "-preset", "medium", final], "xfade")
print("FINAL:", final, "len~", round(accA, 1))
