"""Package whole imagegen-authored poses; never warp or synthesize body parts."""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from preview_yard_sprites import save_gif
from field_face_fit import ETE_FACE, PoseTrace

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/characters"
OUT = ART / "interactions"
PREVIEW = ROOT / "artifacts"
CELL = (96,112)
FOOT = (48,103)
SOURCES = ("social_v2", "books_v1", "leisure_v1")
# id, label, action hold durations, visible reaction description
ACTIONS = [
    ("greet","손인사",[.35,.4,.9,.4,.45],"에테가 책을 받치고 조용히 손을 흔들어요."),
    ("listen","이야기 나누기",[.35,.5,1.0,.5,.45],"고개를 기울여 이야기에 귀를 기울여요."),
    ("pet","쓰다듬기",[.35,.5,1.1,.5,.45],"눈을 살짝 감고 편안하게 미소 지어요."),
    ("recognize","팬 모습 보여주기",[.4,.5,1.0,.5,.45],"익숙한 책갈피의 모습을 알아보고 반겨요."),
    ("give","책 받아 보기",[.4,.55,1.0,.5,.45],"에테가 읽던 책을 두 손으로 내밀어요."),
    ("receive","책 건네 보기",[.4,.55,1.0,.5,.45],"건넨 책을 받아 들고 살짝 고개를 끄덕여요."),
    ("read","함께 읽기",[.4,.7,1.8,.6,.45],"같은 문장을 짚으며 함께 읽어요."),
    ("transform","변신 책갈피 보기",[.45,.5,1.15,.55,.45],"별표 책갈피를 꺼내 보여 줘요."),
    ("tea","차 한 잔",[.4,.7,1.45,.65,.45],"찻잔을 들고 잠깐 숨을 돌려요."),
    ("rest","잠깐 쉬기",[.6,.7,2.0,.6,.5],"책을 품에 안고 어깨의 힘을 풀어요."),
    ("cheer","응원 받기",[.4,.45,1.0,.5,.45],"작게 주먹을 쥐고 힘을 보태 줘요."),
    ("goodbye","다음에 봐요",[.4,.6,.9,.6,.45],"책을 모아 들고 가볍게 인사해요."),
]


def clean_cel(source, box):
    pixels = np.array(source.crop(box))
    pixels[pixels[:,:,3] <= 32] = 0  # near-transparent generation residue only
    pose = Image.fromarray(pixels)
    bounds = pose.getbbox()
    assert bounds and bounds[0]>0 and bounds[1]>0
    return pose.crop(bounds)


def foot_center(pose):
    pixels = np.array(pose).astype(int)
    r,g,b,a = [pixels[:,:,i] for i in range(4)]
    skin = (a>100)&(r>150)&(r>g+9)&(r>b+4)
    skin[:int(pose.height*.93)] = False
    _,xs = np.nonzero(skin)
    assert len(xs)>2, "Reinspect foot registration when replacing source art"
    return (int(xs.min())+int(xs.max()))/2


def pack():
    neutral = Image.open(ART/"directional/aethe.png").convert("RGBA").crop((0,0,*CELL))
    atlas = Image.new("RGBA", (CELL[0]*5,CELL[1]*12))
    records = []
    trace=PoseTrace(neutral,ETE_FACE)
    for group,name in enumerate(SOURCES):
        source = Image.open(ART/"source"/f"aethe_interactions_{name}.png").convert("RGBA")
        assert 1230<=source.width<=1235 and 1274<=source.height<=1278
        xcut,ycut = (0,270,510,740,970,source.width),(0,310,630,950,source.height)
        for row in range(4):
            index = group*4+row
            poses = [clean_cel(source,(xcut[c],ycut[row],xcut[c+1],ycut[row+1])) for c in range(5)]
            # One uniform scale per action, calibrated from its neutral cel.
            # A bow/relaxed shoulder stays lower instead of being stretched tall.
            scale = 88/poses[4].height
            bounds = []
            anchors = []
            for column,pose in enumerate(poses):
                if column==4:
                    cel = neutral.copy()  # return to the exact runtime idle pixels
                else:
                    pose = pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.NEAREST)
                    cel = Image.new("RGBA",CELL)
                    x = round(FOOT[0]-foot_center(pose))
                    cel.alpha_composite(pose,(x,FOOT[1]+1-pose.height))
                box = cel.getbbox()
                assert box and box[0]>0 and box[1]>0 and box[2]<96 and box[3]==104
                assert box[2]-box[0]<=68 and box[3]-box[1]<=90
                atlas.alpha_composite(cel,(column*96,index*112))
                bounds.append(box)
                p=ETE_FACE if column==4 else trace.measure(cel)[0]
                anchors.append([round(p.x,3),round(p.eye,3),round(np.radians(p.angle),6)])
            key,label,durations,description = ACTIONS[index]
            records.append({"id":key,"label":label,"row":index,"durations":durations,
                            "description":description,"source":f"aethe_interactions_{name}.png",
                            "bounds":bounds,"head_anchors":anchors})
    OUT.mkdir(parents=True,exist_ok=True)
    atlas.save(OUT/"aethe.png")
    manifest = {"cell":CELL,"foot":FOOT,"facing":"down",
                "stages":["준비","동작 시작","반응·표정","마무리","대기"],
                "actions":records,"creation":"Built-in imagegen; whole poses with common original idle."}
    (OUT/"aethe.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return atlas,manifest


def frame_at(record,seconds):
    for column,duration in enumerate(record["durations"]):
        if seconds<duration: return column
        seconds-=duration
    return 4


def preview(atlas,manifest):
    font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",17)
    title = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf",25)
    images = []
    for tick in range(100):
        canvas = Image.new("RGB",(1080,1014),"#2e443b")
        draw = ImageDraw.Draw(canvas)
        draw.text((22,14),"에테 · 상호작용 준비 자세와 표정 12종",font=title,fill="#f3dfb8")
        draw.text((22,52),"준비 → 동작 시작 → 반응·표정 → 마무리 → 같은 대기 자세",font=font,fill="#b7e1c4")
        for i,record in enumerate(manifest["actions"]):
            x,y = 12+(i%4)*268,88+(i//4)*300
            phase = frame_at(record,max(0,tick*.05-.25)) if tick>=5 else 4
            draw.rounded_rectangle((x,y,x+254,y+288),radius=5,fill="#41574b")
            draw.text((x+12,y+9),record["label"],font=font,fill="#fff1d5")
            cel = atlas.crop((phase*96,i*112,(phase+1)*96,(i+1)*112)).resize((192,224),Image.Resampling.NEAREST)
            canvas.paste(cel,(x+30,y+30),cel)
            draw.text((x+12,y+260),manifest["stages"][phase],font=font,fill="#d1dbcb")
        images.append(canvas)
    PREVIEW.mkdir(exist_ok=True)
    images[30].save(PREVIEW/"aethe_interactions.png")
    save_gif(images,PREVIEW/"aethe_interactions.gif",[50]*len(images),disposal=2)
    # All five phases of the petting sequence, enlarged for expression review.
    stages = Image.new("RGB",(1240,420),"#2e443b")
    draw = ImageDraw.Draw(stages)
    draw.text((20,12),"쓰다듬기 · 준비부터 대기 복귀까지",font=title,fill="#f3dfb8")
    for col in range(5):
        cel = atlas.crop((col*96,224,(col+1)*96,336)).resize((240,280),Image.Resampling.NEAREST)
        stages.paste(cel,(col*246+5,78),cel)
        draw.text((col*246+20,366),manifest["stages"][col],font=font,fill="#f0dfbd")
    stages.save(PREVIEW/"aethe_petting_stages.png")


if __name__=="__main__":
    # The legacy pack remains available for archived comparisons only.
    from bake_rigid_interactions import bake
    bake(['aethe'])
    print("Packed Ete's approved art with rigid joint transitions.")
