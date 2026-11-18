"""Draw the Ink visitor study and a reopening layout mock-up outside the runtime.

Ink reference: Shopfanpick, 잉크티콘, Naver OGQ 6462fee09632b.
Poses 3 and 12 guide the face, 14 the tail. The magazine is a game prop.
"""
from pathlib import Path
import math
import sys

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "ink_visitor_draft"
LIB = ROOT / "assets" / "library_pixels"
CAST = ROOT / "assets" / "characters"
PAPER, DARK, MUTED = "#f4efdf", "#292f35", "#566260"
EDGE, BODY = "#28263d", "#98b9ed"
NEAREST = Image.Resampling.NEAREST


def font(size, bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/malgun" + ("bd" if bold else "") + ".ttf", size)


def pixel_ink(pose, direction="down", step=0, lift=0, swing=0, page=0, gaze=0, blink=False):
    """One native-grid cel. Neutral defaults reproduce the approved front study."""
    if direction=="right":
        return pixel_ink(pose,"left",step,lift,swing,page,gaze,blink).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(im)
    # Thin curling tail ends in the pale two-lobed tip visible in the stickers.
    d.line([(34, 53), (40, 55), (45, 55), (51, 53+swing//2), (55, 49+swing), (56, 44+swing)], fill=EDGE, width=1)
    tail = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(tail)
    d.polygon([(52, 43), (52, 40), (54, 39), (53, 37), (54, 35), (56, 35), (57, 38),
               (59, 37), (61, 37), (62, 39), (59, 41), (59, 44), (57, 46), (54, 46)], fill=EDGE)
    d.polygon([(53, 43), (54, 40), (56, 39), (55, 36), (56, 37), (57, 40),
               (60, 38), (60, 39), (58, 41), (58, 44), (55, 45)], fill="#b1b1c9")
    d.point((54, 42), fill="#ece7ec")
    im.alpha_composite(tail,(0,swing))
    d = ImageDraw.Draw(im)

    contour = [(17,16),(21,13),(25,11),(30,9),(35,8),(41,8),(43,9),(43,11),
               (42,12),(44,15),(46,19),(48,24),(49,29),(49,32),(48,36),(46,39),
               (42,42),(38,43),(38,47),(39,51),(41,54),(40,56),(37,57),(24,57),
               (21,56),(19,56),(18,54),(18,49),(17,45),(17,42),(14,41),(11,38),(9,34),
               (9,29),(10,25),(12,21),(14,19)]
    if direction=="left":
        contour=[(18,16),(23,12),(28,10),(36,8),(42,8),(43,10),(41,13),(42,17),
                 (44,21),(45,26),(45,32),(43,37),(39,40),(36,42),(35,46),(36,50),
                 (39,54),(38,56),(35,57),(23,57),(21,56),(19,56),(18,54),(18,49),
                 (18,45),(18,42),(14,40),(11,38),(9,35),(8,30),(9,26),(12,21)]
    contour=[(x+(step if y>=54 and x>=31 else -step if y>=54 and x<27 else 0),y) for x,y in contour]
    mask = Image.new("L", im.size)
    md = ImageDraw.Draw(mask)
    md.polygon(contour, fill=255)
    body = Image.new("RGBA", im.size, BODY)
    b = ImageDraw.Draw(body)
    # Overlapping colour clusters keep the blue-to-lilac transition on the same grid.
    for y, colour in [(29,"#9ab6ed"),(34,"#a0b1ed"),(38,"#a4acec"),
                      (42,"#aaa8ec"),(47,"#aea4ed"),(53,"#b39fee")]:
        b.rectangle((0, y, 63, 63), fill=colour)
    b.polygon([(45,17),(48,22),(49,26),(49,34),(46,39),(40,43),(38,47),
               (37,44),(38,41),(43,38),(46,34),(47,28)], fill="#969fdf")
    b.line([(19,16),(25,12),(31,10),(36,9),(41,9)], fill="#b5d3f3")
    b.line([(20,55),(23,56),(39,56)], fill="#9f91dc")
    b.line(contour + [contour[0]],fill=EDGE,width=1)
    im.alpha_composite(Image.composite(body, Image.new("RGBA", im.size), mask))
    # The dot and its glint are a marking on the forehead, distinct from the two eyes.
    side = direction=="left"
    if direction!="up":
        x=23 if side else 36
        d.ellipse((x,13,x+6,19),fill="#6387cb")
        d.rectangle((x+4,12,x+5,13),fill="#fbfbf2")
    for x,y in ([] if direction=="up" else [(18,33)] if side else [(16,33),(39,32)]):
        d.ellipse((x-3,y-2,x+3,y+2),fill="#9fa6e8")
        d.ellipse((x-2,y-1,x+2,y+1),fill="#a59ae4")
    eye_y = 30 if pose=="magazine" else 28
    for x in ([] if direction=="up" else [12] if side else [19,34]):
        x+=gaze
        if blink: d.line([(x,eye_y+1),(x+2,eye_y+1)],fill=EDGE)
        else:
            d.rectangle((x,eye_y,x+1,eye_y+2),fill="#191923")
            d.point((x,eye_y),fill="#e4e8f5")
    if direction!="up":
        x=14 if side else 21
        d.line([(x,eye_y-4),(x+1,eye_y-2)],fill=EDGE)
    if direction=="up":
        d.line([(15,41),(14,43+swing),(16,45+swing),(18,45)],fill=EDGE)
        d.line([(38,45),(41,44-swing),(43,42-swing),(42,41)],fill=EDGE)
        d.line([(28,50),(31,53),(35,54),(40,55)],fill=EDGE)
        im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    elif side:
        d.line([(26,41),(25+step,44),(25+step,46),(27+step,47),(30,44)],fill=EDGE)
    elif pose=="hello":
        d.polygon([(20,42),(17,44),(13,43),(9,41),(6,38),(5,35),(6,33),(8,33),
                   (10,36),(13,38),(16,39)], fill="#a3afec",outline=EDGE)
        d.line([(19,41),(20,42)],fill="#a3afec")
        d.polygon([(37,43),(42,43),(46,41),(49,38),(49,36),(47,35),(45,37),(41,39)],
                  fill="#a3afec",outline=EDGE)
        d.line([(38,42),(39,41),(41,40)],fill="#a3afec")
    elif pose=="magazine":
        d.polygon([(17,40),(25,41),(30,43),(38,40),(40,40),(39,52),(31,55),
                   (25,53),(17,52)], fill="#436e71",outline=EDGE)
        d.polygon([(19,42),(25,43),(29,45),(29,51),(24,49),(19,49)], fill="#ecdab1")
        d.polygon([(31,45),(37,42),(38,42),(37,49),(31,52)], fill="#f8e6bc")
        d.line([(21,45),(26,46)],fill="#a76d50")
        d.line([(33,46),(36,45)],fill="#a98462")
        if page:
            # Fore-edge crosses the binding right to left, showing the back of the leaf.
            tip_x=[0,37,35,32,29,26,23,20][page]
            tip_y=[0,41,39,38,38,39,40,42][page]
            d.polygon([(30,44),(tip_x,tip_y),(tip_x,tip_y+7),(30,52)],
                      fill="#fff2ce" if page<5 else "#dec69c",outline="#947b67")
        d.ellipse((15,45,19,48),fill="#acaaeb",outline=EDGE)
        d.ellipse((37,45,41,48),fill="#acaaeb",outline=EDGE)
    else:
        d.line([(17,41),(15,42+swing),(15,44+swing),(17,45+swing),(20,45)],fill=EDGE)
        d.line([(38,45),(41,44-swing),(43,42-swing),(42,41)],fill=EDGE)
    if lift:
        raised=Image.new("RGBA", im.size)
        raised.alpha_composite(im,(0,-lift))
        return raised
    return im


def text_at(draw, xy, label, size, colour=DARK, bold=False):
    draw.text(xy,label,font=font(size,bold),fill=colour,anchor="lt")


def standing(scene, sprite, xy, scale=1):
    if scale != 1:
        sprite = sprite.resize(tuple(round(n*scale) for n in sprite.size),NEAREST)
    x,y = xy
    shadow = Image.new("RGBA",scene.size)
    radius = max(6,round(sprite.width*.22))
    ImageDraw.Draw(shadow).ellipse((x-radius,y-3,x+radius,y+2),fill=(45,35,48,62))
    scene.alpha_composite(shadow)
    scene.alpha_composite(sprite,(x-sprite.width//2,y-sprite.height))


def visitor(im):
    return im.crop((4,4,64,58))


def first_cel(path, row=0):
    with Image.open(path) as sheet:
        im=sheet.convert("RGBA").crop((0,row*112,96,(row+1)*112))
    return im.crop(im.getbbox())


def lobby():
    scene = Image.open(LIB/"library_stage_6.png").convert("RGBA")
    player=first_cel(CAST/"yard/traveler.png")
    standing(scene, first_cel(CAST/"directional/aethe.png"),(477,249),.83)
    standing(scene, player,(585,362),64/player.height)
    standing(scene,visitor(pixel_ink("hello")),(267,301))
    standing(scene,visitor(pixel_ink("magazine")),(335,373))
    standing(scene,visitor(pixel_ink("idle")),(529,450))
    return scene


def character_board(scene):
    board=Image.new("RGBA",(1096,494),PAPER)
    d=ImageDraw.Draw(board)
    text_at(d,(34,25),"루체테 도서관  /  방문객 도트 시안",17,MUTED)
    text_at(d,(32,61),"잉크",46,DARK,True)
    d.line((34,132,1062,132),fill="#bab7a5",width=1)
    for x,label,pose in [(48,"기본","idle"),(277,"인사","hello"),(506,"잡지 읽기","magazine")]:
        art=pixel_ink(pose)
        board.alpha_composite(art.resize((192,192),NEAREST),(x,169))
        text_at(d,(x+20,393),label,21,DARK,True)
    # Use an integer zoom for the pixel-art review and 1:1 pixels for the scene inset.
    frame=(750,157,1061,369)
    crop=scene.crop((223,166,534,378))
    board.alpha_composite(crop,frame[:2])
    d.rectangle(frame,outline="#66594b",width=2)
    text_at(d,(750,394),"도서관 배경 위 · 1배",19,DARK,True)
    text_at(d,(34,456),"네이버 OGQ  ·  샵팬픽 『잉크티콘』 참고",15,MUTED)
    return board


def floor_plan(scene):
    board=Image.new("RGBA",(1280,688),PAPER)
    d=ImageDraw.Draw(board)
    text_at(d,(38,26),"재개관 운영 화면",32,DARK,True)
    text_at(d,(38,92),"공용 도서관",22,DARK,True)
    text_at(d,(676,92),"스텔라 개인실",22,DARK,True)
    text_at(d,(872,99),"방 위치 시안 · 실제 방송 배경은 제작 전",15,MUTED)
    area=(32,139,645,539)
    d.rectangle(area,fill="#46453b")
    board.alpha_composite(scene.resize((609,390),NEAREST),(34,144))
    roster=[("야토",1),("오단밍",7),("햄쿠비",10),("아미하 유네",11),("쇼코코 도리",13),("하쿠텐 후와",14)]
    base=["#dfd3b7","#e4cad7","#ccd5bd","#d8cbde","#dacdbc","#c6d4da"]
    for i,(name,row) in enumerate(roster):
        x=673+i%3*195
        y=137+i//3*206
        side=190
        d.rectangle((x,y,x+side-1,y+side-1),fill=base[i],outline="#55534c",width=3)
        d.rectangle((x+3,y+3,x+side-4,y+37),fill="#414a48")
        text_at(d,(x+12,y+10),name,16,"#fff4dc",True)
        # Architectural placeholder. No invented streaming-room furnishings.
        d.line((x+12,y+53,x+12,y+side-14,x+side-13,y+side-14),fill="#b3ab9d",width=1)
        sprite=first_cel(CAST/"yard/lobby_idle.png",row)
        standing(board,sprite,(x+side//2,y+side-31))
    d.line((38,568,1240,568),fill="#bab7a5")
    text_at(d,(38,595),"홍보 주제",17,MUTED,True)
    text_at(d,(156,590),"처음 온 잉크에게 권하는 책",24,DARK,True)
    text_at(d,(38,644),"플레이어는 도서관에서 잉크를 맞고, 스텔라들은 주제에 맞춰 방송·잡지 배포·거리 공연을 진행한다.",17,MUTED)
    return board


def main():
    OUT.mkdir(exist_ok=True,parents=True)
    if "--motion" in sys.argv:
        build_motion()
        return
    scene=lobby()
    character_board(scene).convert("RGB").save(OUT/"ink-study.png")
    floor_plan(scene).convert("RGB").save(OUT/"reopened-layout.png")
    pixel_ink("idle").save(OUT/"ink-front-64.png")


def build_motion():
    sheet=Image.new("RGBA",(32*64,5*64))
    for row,direction in enumerate(["down","left","right","up"]):
        for frame in range(16):
            angle=math.tau*frame/16
            # The trailing tail catches up a few cels after the body shifts weight.
            swing=round(1.6*math.sin(angle)*(1-math.cos(angle))+math.sin(2*angle))
            im=pixel_ink("idle",direction,step=round(2*math.sin(angle)),
                         lift=round(2*math.sin(angle)**2),swing=swing)
            sheet.alpha_composite(im,(frame*64,row*64))
    for frame in range(32):
        page=(frame-18) if 19<=frame<=25 else 0
        gaze=-1 if frame<6 or frame>=24 else 0 if frame<11 else 1
        im=pixel_ink("magazine",page=page,gaze=gaze,blink=frame==27)
        sheet.alpha_composite(im,(64*frame,4*64))
    dest=CAST/"visitors"
    dest.mkdir(exist_ok=True)
    sheet.save(dest/"ink.png")
    frames=[]
    for frame in range(64):
        board=Image.new("RGB",(760,180),PAPER)
        d=ImageDraw.Draw(board)
        for row,label in enumerate(["앞","왼쪽","오른쪽","뒤","책 읽기"]):
            col=frame//2 if row==4 else frame%16
            cel=sheet.crop((col*64,row*64,col*64+64,row*64+64)).resize((128,128),NEAREST)
            board.paste(cel,(row*152+12,8),cel)
            d.text((row*152+76,145),label,font=font(17,True),fill=DARK,anchor="mt")
        frames.append(board)
    frames[0].save(OUT/"ink-motion.gif",save_all=True,append_images=frames[1:],duration=60,loop=0,disposal=2)


if __name__=="__main__":
    main()
