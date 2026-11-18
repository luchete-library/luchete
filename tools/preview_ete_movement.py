"""Package real Godot captures; run tests/render.gd -- --ete-preview first."""
from pathlib import Path
from tempfile import gettempdir

from PIL import Image, ImageDraw, ImageFont

from preview_yard_sprites import ARTIFACTS, save_gif

source = Path(gettempdir()) / "lucete-ete-frames"
frames = [Image.open(source / f"ete_{i:03d}.png").convert("RGB") for i in range(49)]
save_gif(frames, ARTIFACTS / "ete_story_walk.gif", [80, 80, 90]*16+[700], disposal=1)

# Fixed camera crop retains world movement and the grounded foot reference.
detail = []
font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 22)
for frame in frames:
    canvas = Image.new("RGB", (1040, 570), "#2e443b")
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 13), "도리 이야기 속 에테 · 실제 게임 화면 2배 확대", font=font, fill="#f3dfb8")
    crop = frame.crop((390, 200, 890, 450)).resize((1000, 500), Image.Resampling.NEAREST)
    canvas.paste(crop, (20, 52))
    detail.append(canvas)
detail[19].save(ARTIFACTS / "ete_walk_detail.png")
save_gif(detail, ARTIFACTS / "ete_walk_detail.gif", [80, 80, 90]*16+[700], disposal=1)
