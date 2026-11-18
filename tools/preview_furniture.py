"""Package frames captured by the real Godot furniture walkthrough."""
from pathlib import Path
from tempfile import gettempdir

from PIL import Image, ImageDraw, ImageFont

from preview_yard_sprites import ARTIFACTS, save_gif

source = Path(gettempdir()) / "lucete-furniture-frames"
frames = [Image.open(source / f"furniture_{i:03d}.png").convert("RGB") for i in range(192)]
save_gif(frames, ARTIFACTS / "furniture_interactions.gif", [120, 130] * 96, disposal=1)

# These are crops of actual residents using the placed furniture, not mockups.
font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 19)
title = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 25)
examples = [
    ("독서 의자", (234, 187, 354, 317), 40),
    ("티 테이블", (234, 379, 354, 509), 64),
    ("요가 매트", (849, 437, 969, 567), 48),
    ("방송 세트", (849, 149, 969, 279), 80),
]
sequence = []
for n in range(32):
    canvas = Image.new("RGB", (1040, 366), "#253a35")
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 12), "도서관에서 함께 보내는 하루 · 실제 게임 화면 2배 확대", font=title, fill="#f7ebc7")
    for column, (label, box, start) in enumerate(examples):
        x = 12 + column * 258
        draw.text((x + 6, 55), label, font=font, fill="#e4d7b6")
        crop = frames[start + n].crop(box).resize((240, 260), Image.Resampling.NEAREST)
        canvas.paste(crop, (x, 89))
    sequence.append(canvas)
sequence[8].save(ARTIFACTS / "furniture_detail.png")
save_gif(sequence, ARTIFACTS / "furniture_detail.gif", [120, 130] * 16, disposal=1)
