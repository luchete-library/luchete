"""Preview the shipped atlas cels at integer zoom, with a stable GIF palette."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from bake_yard_sprites import ACTIONS, OUT

ARTIFACTS = OUT.parents[2]/"artifacts"
FPS = {"pilates":8,"yoga":6,"gym":12,"rope":12,"stream":8,"walk":12,"read":6,"tea":8}
LABELS = {"rope":"줄넘기","yoga":"요가","gym":"헬스","pilates":"필라테스","stream":"방송","walk":"산책","read":"독서","tea":"차 마시기"}
FONT = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",18)
TITLE = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",24)
CAST = [("야토","rope",0),("오단밍","yoga",6),("햄쿠비","gym",9),
        ("유네","pilates",11),("도리","stream",13),("후와","yoga",14)]


def sheets(directory):
    return {a:Image.open(directory/(a+".png")).convert("RGBA") for a in ACTIONS if (directory/(a+".png")).exists()}


def cel(atlas,action,row,t,scale):
    sheet = atlas[action]
    samples = 3 if sheet.width == 36*96 else 1
    columns = sheet.width//96
    n = int(t*FPS[action]*samples)%(24*samples)
    x = (n%columns)*96
    y = (row*(2 if samples==3 else 1)+n//columns)*112
    return sheet.crop((x,y,x+96,y+112)).resize((96*scale,112*scale),Image.Resampling.NEAREST)


def save_gif(frames,path,durations,disposal=2):
    sample = Image.new("RGB",(frames[0].width,frames[0].height*12))
    for i in range(12): sample.paste(frames[i*len(frames)//12],(0,i*frames[0].height))
    palette = sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
    sequence = [f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    sequence[0].save(path,save_all=True,append_images=sequence[1:],duration=durations,
                     loop=0,optimize=False,disposal=disposal)
    print(path.name)


def detail(atlas):
    frames = []
    for k in range(72):
        im = Image.new("RGB",(660,610),"#253a35")
        d = ImageDraw.Draw(im)
        d.text((20,15),"수정한 필드 도트 · 2배 확대",font=TITLE,fill="#f7ebc7")
        for i,(name,action,row) in enumerate(CAST):
            x,y = 12+(i%3)*216,60+(i//3)*272
            d.rounded_rectangle((x,y,x+204,y+260),radius=6,fill="#60796a")
            d.text((x+12,y+8),name+" · "+LABELS[action],font=FONT,fill="#fff4d4")
            tile = cel(atlas,action,row,k/12,2)
            im.paste(tile,(x+6,y+30),tile)
        frames.append(im)
    frames[12].save(ARTIFACTS/"yard_motion_detail.png")
    save_gif(frames,ARTIFACTS/"yard_motion_detail.gif",[80,80,90]*24)


def compare(old,new):
    examples = [("야토","pilates",0),("햄쿠비","gym",9),("도리","stream",13)]
    frames = []
    for k in range(72):
        im = Image.new("RGB",(940,860),"#253a35")
        d = ImageDraw.Draw(im)
        d.text((20,12),"고개·체중 이동 추가 전후 비교",font=TITLE,fill="#f7ebc7")
        for row,atlas in enumerate((old,new)):
            top = 65+row*390
            d.text((20,top),"수정 전" if row==0 else "수정 후",font=FONT,
                   fill="#ffe0bc" if row==0 else "#bfe5c4")
            for i,(name,action,r) in enumerate(examples):
                x,y = 12+i*308,top+28
                d.rounded_rectangle((x,y,x+296,y+354),radius=6,fill="#60796a")
                d.text((x+12,y+6),name+" · "+LABELS[action],font=FONT,fill="#fff4d4")
                tile = cel(atlas,action,r,k/12,3)
                im.paste(tile,(x+4,y+22),tile)
        frames.append(im)
    frames[6].save(ARTIFACTS/"yard_motion_compare.png")
    save_gif(frames,ARTIFACTS/"yard_motion_compare.gif",[80,80,90]*24)


if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--before",type=Path)
    parser.add_argument("--field-frames",type=Path)
    args = parser.parse_args()
    current = sheets(OUT)
    detail(current)
    if args.before: compare(sheets(args.before),current)
    if args.field_frames:
        frames = [Image.open(args.field_frames/("yard_%02d.png"%i)).convert("RGB") for i in range(48)]
        save_gif(frames,ARTIFACTS/"garden_activities.gif",[120,130]*24)
