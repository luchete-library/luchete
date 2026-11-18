"""Compose screenshots of the actual Godot review build; never alter game sprites."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parents[1]/"artifacts"/"growth_20261116"
font=ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",24)
small=ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",17)
sheet=Image.new("RGB",(1280,1010),"#e9d8b3")
draw=ImageDraw.Draw(sheet)
draw.text((22,12),"루체테 · 재건과 사계절 플레이 시안",font=font,fill="#513520")
panels=[("work_corridor","첫 재건 · 야토가 확인한 길로 후와와 상자 옮기기"),
        ("04_visitors","재개관 · 실제 입장·독서·대출로 골드와 기억 쌓기"),
        ("shop_furniture","성장 상점 · 구매한 가구를 여섯 스텔라가 함께 사용"),
        ("shop_costume","추가 의상 · 공개 자료가 확인된 후보부터 시험 등록")]
for i,(name,title) in enumerate(panels):
    x=(i%2)*640; y=54+(i//2)*438
    im=Image.open(OUT/f"{name}.png").convert("RGB").resize((640,400),Image.Resampling.LANCZOS)
    sheet.paste(im,(x,y))
    draw.text((x+13,y+406),title,font=small,fill="#513520")
draw.text((22,947),"입장·대여 수입 → 능력·가구·의상 구매 / 누적 기억의 빛 → 성장 단계 해금",font=small,fill="#513520")
draw.text((22,978),"가격·임계치·계절당 28일은 시험 수치입니다. 기존 본게임과 저장은 바꾸지 않았습니다.",font=small,fill="#806047")
sheet.save(OUT/"growth_review.png")

# Four-second carry excerpt at the authored 24 fps; crop only, no sprite edits.
frames=[]
for path in sorted(OUT.glob("carry_[0-9][0-9][0-9].png")):
    frame=Image.open(path).convert("RGB").crop((220,380,705,600)).resize((970,440),Image.Resampling.NEAREST)
    frames.append(frame)
if frames:
    durations=[50 if i%6==5 else 40 for i in range(len(frames))]
    frames[0].save(OUT/"corridor_carry.gif",save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
print("Review montage and 24 fps carry excerpt exported.")
