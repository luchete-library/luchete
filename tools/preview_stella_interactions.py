"""Review packaged sprites and actual Godot captures without drawing new art."""
import json
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from preview_yard_sprites import save_gif
from import_stella_interactions import ROOT, SPECS, phase

font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
title=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',25)
members=list(SPECS)
frames=[]
atlases={m:Image.open(ROOT/f'assets/characters/interactions/{m}.png').convert('RGBA') for m in members}
manifests={m:json.loads((ROOT/f'assets/characters/interactions/{m}.json').read_text(encoding='utf-8')) for m in members}
for tick in range(96):
    image=Image.new('RGB',(1224,686),'#2e443b')
    d=ImageDraw.Draw(image)
    d.text((18,12),'여섯 스텔라 · 각자 다른 클릭 반응과 가구 자세',font=title,fill='#f4dfb7')
    for i,m in enumerate(members):
        x,y=12+i%3*404,60+i//3*310
        d.rounded_rectangle((x,y,x+392,y+298),5,fill='#41574b')
        d.text((x+12,y+7),SPECS[m]['name'],font=font,fill='#fff0cb')
        for side in range(2):
            index=(tick//24)%4 if side==0 else 4+(i%4)
            action=manifests[m]['actions'][index]
            t=(tick%24)*.1 if side==0 else min(8.0,tick*.1)
            column=phase(action['durations'],t)
            cel=atlases[m].crop((column*96,index*112,(column+1)*96,(index+1)*112)).resize((192,224),Image.Resampling.NEAREST)
            image.paste(cel,(x+side*196,y+30),cel)
            d.text((x+side*196+8,y+266),action['label'],font=font,fill='#d5e4d3')
    frames.append(image)
frames[12].save(ROOT/'artifacts/stella_interactions_overview.png')
save_gif(frames,ROOT/'artifacts/stella_interactions_overview.gif',[100]*96)

capture_dir=Path(tempfile.gettempdir())/'lucete-stella-interaction-frames'
frames=[]
for tick in range(80):
    image=Image.new('RGB',(972,802),'#2e443b')
    d=ImageDraw.Draw(image)
    d.text((18,12),'도서관에서 직접 가구에 놓았을 때 · 실제 게임 확대',font=title,fill='#f4dfb7')
    for i,m in enumerate(members):
        kind=('chair','tea','camera','mat','chair','mat')[i]
        x,y=12+i%3*324,60+i//3*366
        d.text((x+8,y),SPECS[m]['name']+' · '+{'chair':'독서','tea':'차','camera':'방송','mat':'요가'}[kind],font=font,fill='#f4dfb7')
        cel=Image.open(capture_dir/f'{m}_{kind}_{tick:02d}.png').convert('RGB').resize((304,320),Image.Resampling.NEAREST)
        image.paste(cel,(x,y+30))
    frames.append(image)
frames[13].save(ROOT/'artifacts/stella_furniture_ingame.png')
save_gif(frames,ROOT/'artifacts/stella_furniture_ingame.gif',[100]*80)
