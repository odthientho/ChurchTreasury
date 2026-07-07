#!/usr/bin/env python3
"""Assemble the promo: Ken Burns push-in per slide, crossfades, ambient music."""
import os, subprocess

BASE = "/private/tmp/claude-501/-Users-odthientho-Library-CloudStorage-OneDrive-GeorgiaInstituteofTechnology-ClaudeCode/58ab6775-b864-442e-b7bc-a7ef44688ebd/scratchpad"
SLIDES = os.path.join(BASE, "slides")
FF = "/opt/homebrew/bin/ffmpeg"
FPS = 30
T = 0.6                       # crossfade seconds

n = len([f for f in os.listdir(SLIDES) if f.startswith("slide_")])
# durations: intro, 12 features, outro
durs = [5.0] + [9.5] * (n - 2) + [6.5]
assert len(durs) == n, (len(durs), n)

# ---- Build silent video with zoompan + xfade chain ----
inputs = []
for i in range(n):
    inputs += ["-loop", "1", "-t", f"{durs[i]}", "-i", os.path.join(SLIDES, f"slide_{i:02d}.png")]

fc = []
for i in range(n):
    frames = int(round(durs[i] * FPS))
    inc = 0.06 / frames
    fc.append(
        f"[{i}:v]scale=2160:3840,"
        f"zoompan=z='min(zoom+{inc:.6f},1.06)':d={frames}:"
        f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1080x1920:fps={FPS},"
        f"setsar=1,format=yuv420p[v{i}]"
    )

# xfade chain
prev = "v0"
accA = durs[0]
for k in range(1, n):
    off = accA - T
    out = f"x{k}"
    fc.append(f"[{prev}][v{k}]xfade=transition=fade:duration={T}:offset={off:.3f}[{out}]")
    accA = accA + durs[k] - T
    prev = out

final_len = accA
fc_str = ";".join(fc)

video = os.path.join(BASE, "video.mp4")
cmd = [FF, "-y", *inputs,
       "-filter_complex", fc_str,
       "-map", f"[{prev}]",
       "-r", str(FPS), "-c:v", "libx264", "-pix_fmt", "yuv420p",
       "-crf", "18", "-preset", "medium", video]
print("video length ~", round(final_len, 1), "s")
r = subprocess.run(cmd, capture_output=True, text=True)
if r.returncode != 0:
    print("VIDEO FFMPEG ERROR:\n", r.stderr[-3000:]); raise SystemExit(1)
print("video.mp4 done")

# ---- Ambient music bed (soft sustained pad, gentle movement) ----
D = final_len
tones = [(65.41, 0.16), (130.81, 0.13), (196.00, 0.10),
         (261.63, 0.095), (329.63, 0.07), (392.00, 0.05)]
minputs = []
for f, _ in tones:
    minputs += ["-f", "lavfi", "-i", f"sine=frequency={f}:duration={D:.2f}"]
mix = ""
for idx, (f, v) in enumerate(tones):
    mix += f"[{idx}]volume={v}[m{idx}];"
mix += "".join(f"[m{idx}]" for idx in range(len(tones)))
mix += (f"amix=inputs={len(tones)}:normalize=0,"
        "tremolo=f=0.13:d=0.35,"
        "aecho=0.8:0.9:70|130:0.35|0.22,"
        "lowpass=f=2400,highpass=f=45,"
        "volume=2.2,"
        f"afade=t=in:st=0:d=2.5,afade=t=out:st={D-3.5:.2f}:d=3.5[a]")
music = os.path.join(BASE, "music.wav")
mcmd = [FF, "-y", *minputs, "-filter_complex", mix, "-map", "[a]", music]
r = subprocess.run(mcmd, capture_output=True, text=True)
if r.returncode != 0:
    print("MUSIC FFMPEG ERROR:\n", r.stderr[-3000:]); raise SystemExit(1)
print("music.wav done")

# ---- Mux ----
final = os.path.join(BASE, "ChurchTreasury_Promo.mp4")
mux = [FF, "-y", "-i", video, "-i", music,
       "-map", "0:v", "-map", "1:a",
       "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", final]
r = subprocess.run(mux, capture_output=True, text=True)
if r.returncode != 0:
    print("MUX FFMPEG ERROR:\n", r.stderr[-3000:]); raise SystemExit(1)
print("FINAL:", final)
