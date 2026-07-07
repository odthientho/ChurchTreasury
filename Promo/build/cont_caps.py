#!/usr/bin/env python3
"""Overlay time-ranged lower-third captions onto the continuous walkthrough cut."""
import os, subprocess
from PIL import Image, ImageDraw, ImageFont

BASE = "/private/tmp/claude-501/-Users-odthientho-Library-CloudStorage-OneDrive-GeorgiaInstituteofTechnology-ClaudeCode/58ab6775-b864-442e-b7bc-a7ef44688ebd/scratchpad"
WORK = os.path.join(BASE, "capwork"); os.makedirs(WORK, exist_ok=True)
FF = "/opt/homebrew/bin/ffmpeg"
OW, OH = 1080, 2346
GOLD=(232,184,92); WHITE=(248,250,251); SUB=(206,216,221)
AV="/System/Library/Fonts/Avenir Next.ttc"; HV="/System/Library/Fonts/HelveticaNeue.ttc"
def tf(s): return ImageFont.truetype(AV,s)
def bf(s): return ImageFont.truetype(HV,s)

def wrap(d,s,f,mw):
    o,c=[],""
    for w in s.split():
        t=(c+" "+w).strip()
        if d.textlength(t,font=f)<=mw: c=t
        else: o.append(c); c=w
    if c: o.append(c)
    return o
def center(d,y,s,f,fill): d.text(((OW-d.textlength(s,font=f))/2,y),s,font=f,fill=fill)
def tracked(d,y,s,f,fill,tr):
    w=sum(d.textlength(c,font=f)+tr for c in s)-tr; x=(OW-w)/2
    for c in s: d.text((x,y),c,font=f,fill=fill); x+=d.textlength(c,font=f)+tr

def caption_png(path, eyebrow, title, subtitle):
    img=Image.new("RGBA",(OW,OH),(0,0,0,0)); d=ImageDraw.Draw(img)
    ef,tt,ss=tf(30),tf(50),bf(33)
    tl=wrap(d,title,tt,860); sl=wrap(d,subtitle,ss,860)
    ptop,pbot,ebh,tlh,slh=42,46,46,60,44
    ch=ebh+len(tl)*tlh+14+len(sl)*slh
    cw=984; card_h=ch+ptop+pbot; x0=(OW-cw)/2; bottom=2116; top=bottom-card_h
    card=Image.new("RGBA",(OW,OH),(0,0,0,0))
    ImageDraw.Draw(card).rounded_rectangle([x0,top,x0+cw,bottom],32,fill=(9,13,17,231))
    img.alpha_composite(card)
    y=top+ptop; tracked(d,y,eyebrow.upper(),ef,GOLD,8); y+=ebh
    for ln in tl: center(d,y,ln,tt,WHITE); y+=tlh
    y+=14
    for ln in sl: center(d,y,ln,ss,SUB); y+=slh
    img.save(path)

caps = [
 (0.2, 2.9,  "Offerings",     "Browse every Sunday",        "Flip through each month's recorded collections"),
 (3.0, 8.6,  "A collection",  "See exactly what came in",   "Checks, cash, reimbursements — and the bank deposit"),
 (8.9, 13.7, "Expenses",      "Track every expense",        "Organized by category, method and payee"),
 (14.0,17.9, "Regular bills", "A monthly checklist",        "Confirms each recurring bill is recorded"),
 (19.6,29.2, "Reports",       "One-tap monthly report",     "The month becomes a professional treasurer's PDF"),
 (30.6,32.7, "More",          "Everything else",            "Donors, categories & church settings"),
 (33.0,36.9, "Donors",        "Know every giver",           "Profiles, aliases and full giving history"),
]

inputs=["-i", os.path.join(BASE,"cut.mp4")]
for i,(a,b,eye,ttl,sub) in enumerate(caps):
    p=os.path.join(WORK,f"cap_{i}.png"); caption_png(p,eye,ttl,sub); inputs+=["-i",p]

fc=[]; prev="0:v"
for i,(a,b,_,_,_) in enumerate(caps):
    o=f"o{i}"
    fc.append(f"[{prev}][{i+1}:v]overlay=0:0:enable='between(t,{a},{b})'[{o}]")
    prev=o
final=os.path.join(BASE,"ChurchTreasury_Walkthrough_Live.mp4")
cmd=[FF,"-y",*inputs,"-filter_complex",";".join(fc),"-map",f"[{prev}]",
     "-an","-r","30","-c:v","libx264","-pix_fmt","yuv420p","-crf","20","-preset","medium",final]
r=subprocess.run(cmd,capture_output=True,text=True)
if r.returncode!=0: print(r.stderr[-2500:]); raise SystemExit(1)
print("FINAL:",final)
