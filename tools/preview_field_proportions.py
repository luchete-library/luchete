"""Compare the original field images with the shared runtime idle atlas."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "characters"
OUTPUT = ROOT / "artifacts"
FONT = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 20)
TITLE = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 28)
CAST = [("에테", "aethe", 15), ("야토", "yato", 0), ("단밍", "danming", 6),
        ("쿠비", "kubby", 9), ("유네", "yune", 11), ("도리", "dori", 13), ("후와", "fuwa", 14)]
atlas = Image.open(ART / "yard" / "idle.png").convert("RGBA")
canvas = Image.new("RGB", (1260, 690), "#2e443b")
draw = ImageDraw.Draw(canvas)
draw.text((26, 17), "에테와 스텔라 · 같은 발 기준선에서 비교", font=TITLE, fill="#f3dfb8")
for row in range(2):
    top = 66 + row * 300
    baseline = top + 264
    draw.text((27, top), "수정 전" if row == 0 else "수정 후 · 공통 필드 도트", font=FONT,
              fill="#e5c8b0" if row == 0 else "#b7e1c4")
    draw.line((25, baseline, 1234, baseline), fill="#90a695", width=1)
    for i, (name, key, atlas_row) in enumerate(CAST):
        x = 103 + i * 175
        draw.text((x-20, top+33), name, font=FONT, fill="#f0dfbd")
        if row == 0:
            source = OUTPUT / "aethe_field_before.png" if key == "aethe" else ART / "field" / (key+".png")
            cel = Image.open(source).convert("RGBA")
            size = (163, 185) if key == "aethe" else (cel.width*2, cel.height*2)
            cel = cel.resize(size, Image.Resampling.NEAREST)
            origin = (x-cel.width//2, baseline-cel.height)
        else:
            cel = atlas.crop((0, atlas_row*112, 96, (atlas_row+1)*112)).resize((192, 224), Image.Resampling.NEAREST)
            origin = (x-96, baseline-206)
        canvas.paste(cel, origin, cel)
draw.text((26, 655), "머리·몸통 비율과 표시 배율 정리 / 의상과 머리 장식은 각 캐릭터 그대로", font=FONT, fill="#cfdbca")
canvas.save(OUTPUT / "field_proportions_compare.png")
print("Saved field_proportions_compare.png")
