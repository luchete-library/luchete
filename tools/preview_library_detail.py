"""Compare original and refined art at identical logical sizes, without filtering."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'
OLD=OUT/'library_detail_v1'
NEW=ROOT/'assets/library_pixels'
META=json.loads((NEW/'manifest.json').read_text(encoding='utf-8'))['sprites']
FONT=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',19)
TITLE=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',27)


def composite(directory,name):
    result=Image.open(directory/(name+'.png')).convert('RGBA')
    if name=='chair_back':
        result.alpha_composite(Image.open(directory/'chair_front.png').convert('RGBA'))
    return result


canvas=Image.new('RGB',(1220,1056),'#253b35')
d=ImageDraw.Draw(canvas)
d.text((24,16),'루체테 도트 디테일 · 같은 크기로 비교',font=TITLE,fill='#f1dfba')
for col,label in enumerate(['이전','보강 후']):
    d.text((24+col*610,62),label,font=FONT,fill='#dec99f')
rows=[('work_table','복원 작업대 · 속지와 깃펜, 서랍의 깊이'),('shelf_west_6','서가 · 제본 띠와 라벨, 선반 음영'),('chair_back','독서 의자와 화분 · 쿠션 봉제선과 잎맥')]
for row,(name,label) in enumerate(rows):
    y=100+row*310
    for col,directory in enumerate([OLD,NEW]):
        x=18+col*610
        d.rectangle((x,y,x+584,y+294),fill='#3d5248')
        im=composite(directory,name)
        w,h=META[name]['size']
        im=im.resize((w*5,h*5),Image.Resampling.NEAREST)
        if name=='chair_back':
            canvas.paste(im,(x+80,y+24),im)
            plant=composite(directory,'plant_lush').resize((140,200),Image.Resampling.NEAREST)
            canvas.paste(plant,(x+368,y+34),plant)
        else:canvas.paste(im,(x+(584-im.width)//2,y+(260-im.height)//2),im)
        d.text((x+16,y+265),label,font=FONT,fill='#eadcb9')
canvas.save(OUT/'library_detail_comparison.png')

# Refresh the component gallery independently from rebuilding the game assets.
names=['work_table','lending_desk','notice_board','window_clear','garden_door','plant_lush','chair_back','chair_front','tea_back','tea_front','mat_back','camera_back','rug_main','ui_panel','ui_accent','icon_bag','keepsake_yato','keepsake_danming','keepsake_kubby','keepsake_yune','keepsake_dori','keepsake_fuwa','icon_loans','icon_ink']
sheet=Image.new('RGB',(1200,1330),'#263b36');draw=ImageDraw.Draw(sheet)
small=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',15)
draw.text((22,15),'루체테 · 촘촘한 도트와 재질 표현',font=TITLE,fill='#f0dfb6')
for i,name in enumerate(names):
    x=20+i%4*295;y=65+i//4*208
    draw.rectangle((x,y,x+280,y+194),fill='#3c5048')
    im=Image.open(NEW/(name+'.png'))
    w,h=META[name]['size'];scale=max(1,min(4,260//w,162//h))
    im=im.resize((w*scale,h*scale),Image.Resampling.NEAREST)
    sheet.paste(im,(x+(280-im.width)//2,y+(165-im.height)//2),im)
    draw.text((x+12,y+170),name,font=small,fill='#e0d3b2')
sheet.save(OUT/'library_pixel_assets.png')
print('Saved equal-size detail comparison and refreshed component gallery.')
