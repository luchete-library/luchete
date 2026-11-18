"""Assemble crops exported by the real Godot interaction walkthrough."""
from pathlib import Path
from tempfile import gettempdir
import json

from PIL import Image, ImageDraw, ImageFont

from preview_yard_sprites import ARTIFACTS, save_gif

ROOT = Path(__file__).resolve().parents[1]
source = Path(gettempdir()) / "lucete-ete-interaction-frames"
manifest = json.loads((ROOT/"assets/characters/interactions/aethe.json").read_text(encoding="utf-8"))
font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",18)
title = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",25)
frames = []
for frame in range(50):
    canvas = Image.new("RGB",(1080,1110),"#2e443b")
    draw = ImageDraw.Draw(canvas)
    draw.text((22,14),"도서관 속 에테 · 실제 게임에서 재생한 상호작용",font=title,fill="#f3dfb8")
    draw.text((22,52),"정면 기준 12종 · 준비 / 반응 / 마무리 / 대기 복귀",font=font,fill="#b7e1c4")
    for row,record in enumerate(manifest["actions"]):
        x,y = 12+(row%4)*268,91+(row//4)*335
        draw.text((x+8,y),record["label"],font=font,fill="#fff1d5")
        crop = Image.open(source/f"ete_{row:02d}_{frame:03d}.png").convert("RGB").resize((248,296),Image.Resampling.NEAREST)
        canvas.paste(crop,(x,y+28))
    frames.append(canvas)
frames[14].save(ARTIFACTS/"aethe_interactions_ingame.png")
save_gif(frames,ARTIFACTS/"aethe_interactions_ingame.gif",[100]*50,disposal=2)
