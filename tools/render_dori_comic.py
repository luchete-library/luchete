"""Render the Dori preview, or all six source-backed comic atlases with --all."""

import argparse
import json
import math
import os
from functools import cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from bake_pose_transitions import between
from bake_yard_sprites import Motion, frame as field_frame, limb
from comic_cast import KEYS
from draw_fan_pixels import frame_image as fan_frame
from field_face_fit import ETE_FACE
from import_stella_interactions import social_pose
from yard_costumes import Costume, KEYS as WARDROBE


ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ROOT / "assets/characters"
COMICS = ROOT / "assets/comics"
BOOKS = json.loads((COMICS / "debuts.json").read_text(encoding="utf-8"))
NEAREST = Image.Resampling.NEAREST
INK, PAPER, GOLD = "#2a2734", "#ffefd1", "#fac377"
W, H = 228, 110
KEY_FRAMES, SUBSTEPS = 24, 3
FRAMES, COLUMNS = (KEY_FRAMES-1)*SUBSTEPS+1, 12
ROWS_PER_CUT = math.ceil((FRAMES+1)/COLUMNS)
PANEL_POS = [(13, 62), (253, 62), (13, 212), (253, 212)]
FONT_DIR = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
# Keep raised cuffs beside the cheeks in the book's fixed frontal camera.
COMIC_REACH = {("dori","salute"):.65, ("dori","idea"):.80, ("yato","curious"):.45,
               ("danming_origin","ponder"):.80, ("kubby_origin","startled"):.68,
               ("yune","listen"):.90}


@cache
def font(size, bold=False):
    return ImageFont.truetype(str(FONT_DIR / ("malgunbd.ttf" if bold else "malgun.ttf")), size)


def text(draw, xy, words, size, fill, bold=False, anchor="lt"):
    draw.text(xy, words, font=font(size, bold), fill=fill, anchor=anchor)


@cache
def atlas(file):
    return Image.open(CHARACTERS / file).convert("RGBA")


def ease(frame, start, end):
    v=max(0,min(1,(frame-start)/(end-start)))
    return v*v*(3-2*v)


def travel(frame, start, end, first, last):
    return round(first+(last-first)*ease(frame,start,end))


def playback_cue(cue):
    """Subdivide motion, retaining every authored cue and final reading hold."""
    assert len(cue["frames_ms"])==KEY_FRAMES
    durations=[]
    for ms in cue["frames_ms"][:-1]:
        assert ms%10==0
        # GIF durations are centiseconds. Balanced 20/30/40ms samples sum to
        # the exact original interval instead of accumulating playback drift.
        boundaries=[round(i*(ms//10)/SUBSTEPS)*10 for i in range(SUBSTEPS+1)]
        durations.extend(b-a for a,b in zip(boundaries,boundaries[1:]))
    durations.append(cue["frames_ms"][-1])
    assert len(durations)==FRAMES and sum(durations)==sum(cue["frames_ms"])
    return {"reveal":cue["reveal"]*SUBSTEPS,"frames_ms":durations}


def write_playback():
    data={"frames":FRAMES,"key_frames":KEY_FRAMES,"columns":COLUMNS,
          "rows_per_cut":ROWS_PER_CUT,"substeps":SUBSTEPS,
          "books":{member:{"cues":[playback_cue(cue) for cue in book["cues"]]}
                   for member,book in BOOKS.items()}}
    (COMICS/"playback.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")


@cache
def comic_suit(name):
    key=KEYS.get(name,name)
    member=next(member for member,keys in WARDROBE.items() if key in keys)
    return Costume(member,key)


@cache
def gesture(name,action):
    suit=comic_suit(name)
    ready=social_pose(suit,action,1)
    peak=social_pose(suit,action,2)
    return peak.arms,ready.mood,peak.mood


def front(im,name,x,floor,action=None,amount=0,eyes=None,opacity=255,shadow=False,rim=None,motion=None):
    # Interpolate the joints before rasterising. The face keeps its field
    # transform and switches directly between the artist's discrete expressions.
    suit=comic_suit(name)
    m=motion if motion is not None else Motion(suit,"idle",0)
    if action:
        targets,ready,peak=gesture(name,action)
        reach=amount*COMIC_REACH.get((name,action),1.)
        m.arms=[limb(source,m.on_body(source[0]),math.degrees(upper)*reach,
                     math.degrees(lower)*reach)
                for source,(_,_,_,upper,lower) in zip(suit.arms,targets)]
        m.grips=[arm[2] for arm in m.arms]
        m.mood=peak if amount>=.82 else ready if amount>=.42 else "open"
    if eyes is not None: m.mood=eyes
    cel=field_frame(suit,"idle",0,motion=m)
    if rim: draw_rim(im,cel,x,floor,rim,opacity)
    draw_grounded(im,cel,x,floor,opacity,shadow)


@cache
def librarian_stride(row):
    art=atlas("directional/aethe_walk.png")
    return [art.crop((i*96,row*112,(i+1)*96,(row+1)*112)) for i in range(16)]


def profile(im,name,x,floor,view,walk=0,opacity=255,shadow=False,carrying=False,rim=None,pickup=None):
    if name=="aethe":
        if pickup is not None:
            pose=dori_pickup_placement(pickup)
            cel=dori_pickup_cel(pickup)
            draw_grounded(im,cel,x+pose["dx"],floor+pose["crouch"],opacity,shadow,shadow_floor=floor)
            return
        if carrying:
            col=int(abs(walk)/2)%16
            cel=atlas("directional/aethe_carry_walk.png").crop((col*96,0,(col+1)*96,112))
            draw_grounded(im,cel,x,floor,opacity,shadow)
            return
        file="directional/aethe.png"
        row=("down","left","right","up").index(view)
        if walk:
            cel=librarian_stride(row)[int(abs(walk)/2)%16]
            draw_grounded(im,cel,x,floor,opacity,shadow)
            return
        col=0
    else:
        file=f"directional/{KEYS.get(name,name)}.png"
        row=("left","right","up").index(view)
        col=1+int(abs(walk)/2)%16 if walk else 0
    cel=atlas(file).crop((col*96,row*112,(col+1)*96,(row+1)*112))
    if rim: draw_rim(im,cel,x,floor,rim,opacity)
    draw_grounded(im,cel,x,floor,opacity,shadow)


def draw_rim(im,cel,x,floor,color,opacity=255):
    """Contrast only in empty neighbouring pixels; never repaint a face or body."""
    mask=np.asarray(cel.getchannel("A"))>0
    padded=np.pad(mask,1)
    surround=(padded[:-2,1:-1]|padded[2:,1:-1]|padded[1:-1,:-2]|padded[1:-1,2:])&~mask
    edge=Image.new("RGBA",cel.size,color)
    edge.putalpha(Image.fromarray(surround.astype(np.uint8)*round(190*opacity/255)))
    im.alpha_composite(edge,(round(x)-48,round(floor)-104))


def draw_grounded(im,cel,x,floor,opacity=255,shadow=False,shadow_floor=None):
    # Whole-pixel travel on a 1:1 grid also keeps a profile's single visible
    # eye intact when a step lifts its head by one native pixel.
    if shadow:
        mask=cel.getchannel("A")
        cel=Image.new("RGBA",cel.size,"#443c50")
        cel.putalpha(mask)
    if opacity<255:
        cel.putalpha(cel.getchannel("A").point(lambda a:a*opacity//255))
    foot_shadow=Image.new("RGBA",(32,7))
    ImageDraw.Draw(foot_shadow).ellipse((1,0,30,5),fill=(34,24,47,round(70*opacity/255)))
    im.alpha_composite(foot_shadow,(round(x)-16,round(floor if shadow_floor is None else shadow_floor)-3))
    im.alpha_composite(cel,(round(x)-48,round(floor)-104))


def sparkle(d, x, y, r, c):
    d.line((x-r, y, x+r, y), fill=c)
    d.line((x, y-r, x, y+r), fill=c)
    if r > 3:
        d.rectangle((x-1, y-1, x+1, y+1), fill=c)


def rock(d, x, y, scale=1, asleep=True):
    def poly(coords, color):
        d.polygon([(x+a*scale,y+b*scale) for a,b in coords], fill=color)
    poly([(-14,-2),(-10,-12),(-2,-16),(8,-14),(15,-5),(14,0),(7,3),(-10,3)],"#514957")
    poly([(-12,-3),(-9,-11),(-1,-14),(7,-13),(12,-6),(9,0),(-7,1)],"#a195a0")
    poly([(-9,-10),(-2,-14),(6,-12),(1,-9)],"#d5c8bf")
    poly([(-1,0),(7,-2),(12,-6),(11,-1),(6,1)],"#807688")
    # Broad mineral facets and a few grain clusters, never noise over the face.
    poly([(-12,-3),(-9,-9),(-6,-8),(-9,-3)],"#8b808f")
    poly([(3,-12),(8,-11),(10,-7),(6,-9)],"#b8abb2")
    for ox,oy,c in ((-7,-11,"#d9cbc0"),(-4,-10,"#b4a6ac"),(9,-5,"#746a7c"),
                    (-9,-1,"#b5a7af"),(5,0,"#8f818f"),(8,-9,"#c5b5b9")):
        d.rectangle((x+ox*scale,y+oy*scale,x+(ox+1)*scale-1,y+(oy+1)*scale-1),fill=c)
    for ox in [-6,3]:
        d.line((x+ox*scale,y-5*scale,x+(ox+3)*scale,y-5*scale),fill="#554956",width=scale)
        if not asleep:
            d.point((x+(ox+1)*scale,y-6*scale),fill="#332d3b")
    d.point((x,y-2*scale),fill="#6c5861")


def burst(d,x,y,age):
    for a in range(7):
        ang=a*math.tau/7
        r=11+age*3
        px,py=round(x+r*math.cos(ang)),round(y+r*.72*math.sin(ang))
        d.line((px,py,round(px+5*math.cos(ang)),round(py+4*math.sin(ang))),fill="#ffe8ae",width=2)
        if age < 3:
            d.rectangle((px-2,py-2,px+2,py+1),fill=PAPER)


def dori_pickup_placement(tick):
    """One contact track shared by the wrist and the rock; no free-floating lift."""
    crouch=round(20*ease(tick,6,10)*(1-ease(tick,12,17)))
    dx=round(-8*crouch/20)
    lift=ease(tick,12,17)
    stone=(round(112+4*lift),round(91-32*lift))
    contact=(round(stone[0]+6-2*lift),round(stone[1]-8+11*lift))
    # While lowering, the palm reaches from its neutral point to the stone rim.
    reach_amount=ease(tick,6,10)
    hand=(round(134+(contact[0]-134)*reach_amount),round(63+(contact[1]-63)*reach_amount))
    return {"crouch":crouch,"dx":dx,"stone":stone,"hand":hand,"lift":lift}


@cache
def dori_pickup_rig():
    from bake_stella_directions import WalkRig
    return WalkRig(1,2,0)


@cache
def dori_pickup_cel(tick):
    """Kneel on articulated limbs while copying the head/torso without scaling."""
    from bake_stella_directions import masked,shade,X,Y
    from bake_yard_sprites import place,reach,vec
    rig=dori_pickup_rig()
    pose=dori_pickup_placement(tick)
    q=pose["crouch"]/20
    canvas=Image.new("RGBA",(96,112))
    hip=vec(rig.axis,rig.cut+1)
    ankle=vec(rig.axis,100)
    knee=hip+(ankle-hip)*.52
    # The walking rig's narrow leg trace leaves a three-pixel boot edge on
    # the body. Include that edge in the bending leg so kneeling cannot leave
    # a straight fragment below the ankle or outside the comic panel.
    leg_mask=(Y>=rig.cut)&(X>=rig.axis-7)&(X<=rig.axis+8)
    leg=masked(rig.art,leg_mask)
    body=masked(rig.body,~leg_mask|(Y<=rig.cut+2))
    for i,piece in enumerate((shade(leg),leg)):
        target=ankle+vec(-pose["dx"]+i*2, -pose["crouch"])
        chain=reach((hip,knee,ankle),hip,target,-1)
        knee_at,ankle_at=chain[1:3]
        canvas.alpha_composite(place(masked(piece,Y<=knee[1]+1.5),hip,hip,chain[3]))
        canvas.alpha_composite(place(masked(piece,(Y>=knee[1]-1.5)&(Y<100)),knee,knee_at,chain[4]))
        canvas.alpha_composite(place(masked(piece,Y>=99),ankle,ankle_at))
    # The trailing braid follows its lower joint as she kneels; its upper hair,
    # cheeks, eyes and body core remain the exact original pixel drawing.
    braid_mask=(X>=55)&(Y>=73)
    canvas.alpha_composite(masked(body,~braid_mask|(Y<75)))
    canvas.alpha_composite(place(masked(body,braid_mask),vec(58,74),vec(58,74),-.72*q))
    shoulder=rig.shoulder.astype(float)
    palm=vec(52,73)
    elbow=shoulder+(palm-shoulder)*.52
    offset=vec(130+pose["dx"]-48,94+pose["crouch"]-104)
    target=np.array(pose["hand"],float)-offset
    chain=reach((shoulder,elbow,palm),shoulder,target,-1)
    arm=rig.arms[0]
    canvas.alpha_composite(place(masked(arm,Y<=elbow[1]+1.5),shoulder,shoulder,chain[3]))
    canvas.alpha_composite(place(masked(arm,Y>=elbow[1]-1.5),elbow,chain[1],chain[4]))
    return canvas


def dori_panel(cut, tick):
    im=setting("dori",cut).copy()
    d=ImageDraw.Draw(im)
    if cut==0:
        if tick<10:
            front(im,"dori",130,93-travel(tick,6,9,0,4),action="salute",amount=ease(tick,0,8))
        else:
            rock(d,130,travel(tick,10,15,67,90))
            if tick<16: burst(d,130,71,tick-10)
    elif cut==1:
        rock(d,102,89,asleep=tick>=9)
        if tick>=9:
            for j in range(2):
                lift=(tick-9+6*j)%15
                text(d,(112+lift,65-lift),"z" if j==0 else "Z",8+j*2,"#fff1d8",True)
        else:
            # Eyes peep out from the stone during the stakeout.
            for x in (97,106): d.rectangle((x,82,x+1,84),fill=INK)
    elif cut==2:
        if tick<6:
            x=travel(tick,0,5,158,130)
            profile(im,"aethe",x,94,"left",walk=158-x if tick<5 else 0)
            rock(d,112,91)
        elif tick<18:
            # Both the reaching hand and stone follow the same authored grip.
            # The stone stays grounded until the hand has made contact.
            profile(im,"aethe",130,94,"left",pickup=tick)
            pose=dori_pickup_placement(tick)
            rock(d,*pose["stone"])
            if tick>=10:
                hx,hy=pose["hand"]
                d.line((hx-1,hy,hx+1,hy+1),fill="#8b6975",width=3)
                d.line((hx-1,hy-1,hx+1,hy),fill="#f4cbbb",width=2)
        else:
            x=travel(tick,18,23,130,99)
            profile(im,"aethe",x,94,"left",walk=130-x,carrying=True)
            rock(d,x-14,59)
            d.line((x-18,61,x-13,63,x-6,61),fill="#facab0",width=2)
    else:
        if tick<4:
            rock(d,91,88)
        else:
            front(im,"dori",91,95,action="idea",amount=ease(tick,4,16))
            if tick<8: burst(d,91,66,tick-4)
        if tick>=15:
            # A caption cartouche: the source does not identify a speaker.
            d.rectangle((136,28,208,54),fill=INK)
            d.rectangle((138,30,206,52),fill=PAPER)
            text(d,(149,33),"탐정님",14,INK,True)
            sparkle(d,132,34,3,GOLD)
        # Three bound volumes, with distinct covers, page blocks and spine bands.
        d.ellipse((165,91,218,97),fill="#4d3b424a")
        for x,y,w,cover,edge in ((170,87,43,"#526570","#90a39c"),(167,81,42,"#9c744e","#dfbd87"),(173,75,37,"#a66c61","#dca285")):
            d.rectangle((x,y,x+w,y+6),fill="#46393c")
            d.rectangle((x+1,y+1,x+w-1,y+5),fill=cover)
            d.line((x+2,y+1,x+w-2,y+1),fill=edge)
            d.rectangle((x+7,y+2,x+w-2,y+4),fill="#e2d3ad")
            d.line((x+9,y+3,x+w-3,y+3),fill="#b4a28c")
            d.line((x+4,y+1,x+4,y+5),fill=edge)
            d.point((x+2,y+3),fill="#e5c488")
        d.line((201,76,201,83),fill="#796f83")
    return im.convert("RGB")


@cache
def setting(member,cut):
    with Image.open(COMICS/"source"/(member+".png")) as strip:
        return strip.crop((0,cut*H,W,(cut+1)*H)).convert("RGBA")


@cache
def animal_sprite(kind,flip):
    filename="rabbit" if kind=="rabbit" else "prop_hamster"
    with Image.open(ROOT/"assets/world_pixels"/(filename+".png")) as source:
        src=source.convert("RGBA")
    src=src.crop(src.getbbox())
    height=24 if kind=="rabbit" else 17
    src=src.resize((round(src.width*height/src.height),height),NEAREST)
    if kind=="rabbit":
        pixels=np.array(src)
        ink=pixels[:,:,3]>0
        body=ink&(pixels[:,:,0]>155)&(pixels[:,:,1]>140)&(pixels[:,:,2]>95)
        # Keep the approved silhouette and eye. Shade only the existing fur.
        for y,x in zip(*np.nonzero(body)):
            if y+2>=height or not ink[min(height-1,y+2),x]:
                pixels[y,x,:3]=np.rint(pixels[y,x,:3]*[.78,.77,.74])
            elif y>height*.6 and (x+2*y)%11<2:
                pixels[y,x,:3]=np.rint(pixels[y,x,:3]*[.91,.9,.87])
            elif y>0 and not ink[y-1,x]:
                pixels[y,x,:3]=np.minimum(255,pixels[y,x,:3].astype(int)+[13,12,8])
        src=Image.fromarray(pixels)
        fur=ImageDraw.Draw(src)
        for x,y in ((round(src.width*.32),height-5),(round(src.width*.48),height-3),
                    (round(src.width*.76),height-2)):
            if 0<=x<src.width and body[y,x]:
                fur.line((x,y,min(src.width-1,x+2),y),fill="#d9cca5")
    return src.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else src


def animal(im,x,y,kind,flip=False):
    src=animal_sprite(kind,flip)
    if kind=="rabbit":
        shadow=Image.new("RGBA",(src.width+6,5))
        ImageDraw.Draw(shadow).ellipse((0,0,src.width+5,4),fill=(50,39,36,65))
        im.alpha_composite(shadow,(x-src.width//2-3,y-2))
    im.alpha_composite(src,(x-src.width//2,y-src.height))


def mascot(layer, member, x, floor, tick, height=28):
    """Reuse the verified fan design; only the whole sprite is scaled for staging."""
    src=fan_frame(member,1 if 9<=tick<11 else 0)
    src=src.crop(src.getbbox())
    src=src.resize((round(src.width*height/src.height),height),NEAREST)
    layer.alpha_composite(src,(round(x-src.width/2),round(floor-height)))


def dreamcatcher(d,x,y,bob):
    d.line((x+1,0,x+1,y-23),fill="#776179")
    d.line((x,0,x,y-23),fill="#d9b886")
    d.ellipse((x-21,y-22,x+21,y+20),outline="#6d5372",width=2)
    d.ellipse((x-20,y-22,x+20,y+18),outline="#e5bd84",width=2)
    d.arc((x-19,y-21,x+19,y+17),192,304,fill="#fff0bc",width=1)
    d.arc((x-18,y-20,x+18,y+16),12,134,fill="#ae845f",width=1)
    d.line([(x,y-20),(x+17,y+6),(x-16,y-6),(x+16,y-6),(x-14,y+9),(x,y-20)],fill="#c6b5d8")
    d.line((x-16,y-6,x+10,y+12,x,y-20,x-9,y+13,x+16,y-6),fill="#a08bb7")
    for dx,dy in ((0,-20),(17,6),(-16,-6),(16,-6),(-14,9)):
        d.point((x+dx,y+dy),fill="#fff1c2")
    d.rectangle((x-2,y-4,x+2,y),fill="#776184")
    d.rectangle((x-1,y-4,x+1,y-2),fill="#f6d89c")
    for dx in [-12,0,12]:
        end=y+35-abs(dx)//2+bob
        d.line((x+dx,y+16,x+dx+bob,end),fill="#eed6a5")
        fx=x+dx+bob
        d.rectangle((fx-1,end-8,fx+1,end-5),fill="#c19cb9")
        d.point((fx-1,end-8),fill="#ffe5b4")
        d.polygon([(fx,end-3),(fx+3,end),(fx-2,end+7),(fx-3,end+2)],fill="#907caa")
        d.polygon([(fx,end-3),(fx+2,end),(fx-1,end+5),(fx-1,end)],fill="#e0cde5")
        d.line((fx,end-2,fx-2,end+6),fill="#f4e7eb")


def arrow(d,x,y):
    # A shaft, metal ferrule, heart tip and two feather faces share one axis.
    d.line((x,y+1,x+24,y-9),fill="#674b46",width=2)
    d.line((x,y,x+23,y-10),fill="#dfb784")
    d.line((x+17,y-7,x+20,y-8),fill="#f5dbaa",width=2)
    d.polygon([(x+20,y-12),(x+23,y-14),(x+25,y-12),(x+28,y-15),
               (x+30,y-13),(x+30,y-10),(x+24,y-5)],fill="#783a50")
    d.polygon([(x+22,y-12),(x+24,y-11),(x+27,y-13),(x+28,y-11),(x+24,y-7)],fill="#ce7182")
    d.line((x+23,y-12,x+24,y-11),fill="#f1b2ad")
    d.polygon([(x-1,y-4),(x+4,y-3),(x+7,y-1),(x+3,y+1)],fill="#a69c99")
    d.line((x-1,y-4,x+5,y-1),fill="#fff0cc")
    d.polygon([(x,y+1),(x+4,y-1),(x+5,y+3),(x+2,y+5)],fill="#d9c8aa")
    d.line((x+1,y+2,x+3,y+4),fill="#fff0d0")


def flame(d,x,y,t):
    sway=round(math.sin(t*.65))
    outline=[(x-8,y+4),(x-10,y-2),(x-5,y-9),(x-2+sway,y-15),
             (x+2,y-9),(x+6+sway,y-12),(x+10,y-3),(x+7,y+5),(x,y+7)]
    d.polygon(outline,fill="#477f95")
    d.polygon([(x-7,y+3),(x-8,y-2),(x-3,y-8),(x-2+sway,y-12),
               (x+2,y-6),(x+6+sway,y-9),(x+8,y-2),(x+5,y+5),(x,y+6)],fill="#81d9ca")
    d.polygon([(x-4,y+3),(x-4,y-3),(x,y-8),(x+2,y-4),(x+5,y-2),(x+4,y+4),(x,y+5)],fill="#b7f0d8")
    d.ellipse((x-3,y-3,x+3,y+4),fill="#f7edac")
    d.line((x-1,y-2,x,y+2,x+2,y+2),fill="#fff7d7")
    if 2<=t%8<5: d.point((x+4+sway,y-14),fill="#b4e7d4")


def snow(d, t):
    for j in range(18):
        x=(j*37-2*t)%W
        y=(j*17+t)%H
        d.line((x,y,x+2,y-1),fill="#e6eff0")


def yato_scene(im,d,cut,t):
    if cut==0:
        if t<10:
            d.ellipse((96,65,135,85),fill="#806d62")
            d.ellipse((98,64,133,82),fill="#e6c994")
            d.arc((99,65,132,80),6,170,fill="#f2dcb2",width=2)
            d.line((100,77,112,82,130,76),fill="#b69a72",width=2)
            d.ellipse((105,62,119,74),fill="#e6b79b")
            d.arc((107,64,115,70),0,175,fill="#69545c")
            d.line((99,72,108,78,129,69),fill="#ac946f",width=2)
            d.line((100,71,108,76,125,70),fill="#f3dcb4")
        else:
            # Match cut on the same clearing years later. The cast art stays rigid.
            front(im,"yato",115,94,action="welcome",amount=ease(t,10,21))
        for x in (travel(t,0,10,59,78),travel(t,3,13,161,145)):
            animal(im,x,85-int(t<13 and 2<=t%6<4),"rabbit",x>110)
    elif cut==1:
        # Empty stores in the foreground; the character registers the news.
        d.ellipse((39,84,86,91),fill="#654d43")
        d.polygon(((42,76),(82,76),(76,88),(48,88)),fill="#7d5a40",outline="#574236")
        d.polygon(((44,77),(80,77),(75,84),(49,84)),fill="#4d3e35")
        d.line((42,76,82,76),fill="#d4ac7d",width=2)
        for x in range(49,77,5): d.line((x,86,x+1,89),fill="#a7835c")
        for x,y in ((53,81),(66,82),(71,80)):
            d.point((x,y),fill="#b89d69")
        animal(im,92,91,"rabbit")
        if t<10: profile(im,"yato",136,96,"left")
        else:
            # This is the shock of hearing she is human, not a bashful greeting.
            recoil=travel(t,10,13,0,2)-travel(t,17,21,0,1)
            front(im,"yato",136+recoil,96,action="startled",amount=.56*ease(t,10,16),eyes="surprise")
    elif cut==2:
        x=travel(t,0,14,55,114)
        profile(im,"yato",x,96,"right",walk=x-55 if 0<t<14 else 0)
        for j,cx in enumerate((151,174,193)):
            # Shoulders turn away as she reaches the village.
            turn=travel(t,10+j,16+j,0,3)
            top=49+j%2*3
            coat=("#58616c","#6b5e69","#647071")[j]
            light=("#7b8890","#92808b","#8a9693")[j]
            d.ellipse((cx-7,80,cx+9,84),fill="#51515c")
            d.line((cx-3,75,cx-4,81),fill="#41434e",width=3)
            d.line((cx+3,75,cx+4,81),fill="#3a3e4b",width=3)
            d.ellipse((cx-4+turn,top,cx+4+turn,top+9),fill="#4c4552")
            d.arc((cx-4+turn,top,cx+4+turn,top+9),185,335,fill="#7e7277")
            d.line((cx+turn,top+8,cx+turn,top+12),fill="#a1938d",width=2)
            d.polygon(((cx-4,top+10),(cx+4,top+9),(cx+8,78),(cx-7,78)),fill=coat,outline="#464653")
            d.line((cx-3+turn,top+11,cx+turn,top+17,cx+1,76),fill=light)
            d.line((cx-4,top+13,cx-6,72),fill=light)
            d.line((cx+3,top+14,cx+6,73),fill="#494b58")
    else:
        if t>=12:
            spread=ease(t,12,23)
            for j in range(10):
                a=j*math.tau/10
                r=5+spread*(22+5*(j%3))
                sparkle(d,round(113+math.cos(a)*r),round(62+math.sin(a)*r),1+round(spread),GOLD)
        front(im,"yato",113,96,action="curious",amount=ease(t,0,12))
        if t>=12: sparkle(d,113,62,3,"#fff1ba")


def yune_scene(im,d,cut,t):
    if cut==0:
        dreamcatcher(d,84,36,round(math.sin(t/4)))
        for j in range(6):
            k=(t+4*j)%24
            sparkle(d,90+k*2,48+round(math.sin(k/5+j)*9),1,"#fbe0ba")
        front(im,"yune",135,94,opacity=travel(t,7,17,0,255),action="dreamy",amount=ease(t,7,18))
    elif cut==1:
        # Nightmares move toward the mouth before the intact face is drawn.
        # A lavender edge distinguishes their dark core from the purple room.
        for j in range(4):
            k=ease(t,1+j,12+2*j)
            x=round((39+5*j)*(1-k)+112*k)
            r=round(8*(1-k))
            y=round((40+7*j)*(1-k)+41*k)
            if r>0:
                cloud=[(x-r,y-r//2),(x-r//2,y-r),(x+1,y-r+1),(x+r,y-r//2),
                       (x+r-1,y+2),(x+r//2,y+r),(x-1,y+r-2),(x-r,y+r//2)]
                d.polygon(cloud,fill="#40344f",outline="#ae91bf")
                d.arc((x-r+1,y-r+1,x+r-1,y+r-1),50,260,fill="#79688d",width=2 if r>4 else 1)
                if r>4: d.line((x-r+2,y,x-1,y-2,x+2,y),fill="#29283e")
        front(im,"yune",113,95,action="listen",amount=ease(t,2,15),eyes="breath" if 6<=t<17 else "open")
        for j in range(4):
            sparkle(d,154+j*13,42+j%2*10,2+int((t+j)%10<3),"#ffdfa0")
    elif cut==2:
        for j in range(9):
            if t<5+2*j: sparkle(d,28+j*20,27+(j*13)%29,2,"#f4dbba")
        front(im,"yune",109,94,opacity=travel(t,7,21,254,65))
    else:
        # Threshold and figure share one ground plane; this is a full doorway.
        d.rectangle((147,2,217,98),fill="#413b51")
        d.rectangle((150,4,214,96),fill="#9c7c5b")
        door=library_prop("garden_door",(63,92))
        im.alpha_composite(door,(151,4))
        d.line((151,6,151,94),fill="#edcea0")
        d.line((214,8,214,95),fill="#66516a")
        d.polygon(((145,96),(217,96),(223,101),(141,101)),fill="#735b61")
        d.line((146,96,217,96),fill="#dfbd8b")
        if t>=7:
            glow=Image.new("RGBA",im.size)
            gd=ImageDraw.Draw(glow)
            alpha=travel(t,7,17,20,105)
            gd.polygon(((180,94),(184,94),(207,109),(150,109)),fill=(255,225,160,alpha))
            im.alpha_composite(glow)
            d.line((181,13,181,94),fill="#ffe9b0",width=2)
        sparkle(d,181,47,3+int(4<=t%8<6),"#ffe6aa")
        x=travel(t,3,17,70,149)
        profile(im,"yune",x,95,"right",walk=x-70 if 3<t<17 else 0,opacity=travel(t,3,21,125,205))


@cache
def library_prop(name,size):
    with Image.open(ROOT/"assets/library_pixels"/(name+".png")) as source:
        return source.convert("RGBA").resize(size,NEAREST)


def polishing_detail(d,t,grips,tired=False):
    # The prop is attached to the actual authored palms in the main panel.
    # No separate inset performs an action that the character does not do.
    left,right=[(round(p[0])+59,round(p[1])-8) for p in grips]
    lx,ly=left; rx,ry=right
    d.line((lx-7,ly+2,lx+27,ly-3),fill="#5d433e",width=2)
    d.line((lx-7,ly+1,lx+27,ly-4),fill="#e7be8d")
    tipx,tipy=lx+27,ly-4
    d.polygon(((tipx-2,tipy-2),(tipx,tipy-4),(tipx+3,tipy-2),
               (tipx+5,tipy-5),(tipx+7,tipy-3),(tipx+6,tipy),
               (tipx+2,tipy+4)),fill="#823b50")
    d.polygon(((tipx,tipy-2),(tipx+3,tipy),(tipx+5,tipy-3),
               (tipx+5,tipy-1),(tipx+2,tipy+2)),fill="#d87d8b")
    d.point((tipx+1,tipy-2),fill="#ffd0bc")
    d.line((lx-7,ly-1,lx-3,ly+1,lx-6,ly+4),fill="#fff0c6",width=2)
    # The cloth covers the shaft just below the moving right palm.
    d.ellipse((rx-6,ry+2,rx+6,ry+5),fill="#73504e")
    d.polygon(((rx-5,ry),(rx,ry-2),(rx+5,ry+1),(rx+2,ry+5),(rx-3,ry+4)),fill="#76677b")
    d.polygon(((rx-4,ry),(rx,ry-1),(rx+3,ry+1),(rx+1,ry+4),(rx-3,ry+3)),fill="#d9c4da")
    d.line((rx-3,ry,rx+1,ry+2,rx,ry+4),fill="#f5e4e8")
    # Tiny fingertip edges are foreground, never a detached extra hand.
    d.line((lx-1,ly-1,lx+1,ly),fill="#a46f65",width=3)
    d.line((lx-1,ly-2,lx+1,ly-1),fill="#f5c9b1",width=2)
    d.line((rx-1,ry-1,rx+1,ry),fill="#f5c9b1",width=2)
    if not tired and (8<=t<10 or 17<=t<19): sparkle(d,tipx+2,tipy-5,1,"#fff3c5")


def worktop(d,t,tired):
    # The surface is waist height, not below the palms. Warm light comes
    # from the right-hand window shared with the painted workshop.
    for x in (25,186):
        d.ellipse((x-4,103,x+11,108),fill="#49383d")
        d.rectangle((x,79,x+6,105),fill="#573e3c")
        d.line((x+1,80,x+1,103),fill="#98684f")
        d.line((x+4,93,x+4,104),fill="#42343a")
        d.rectangle((x-1,101,x+7,103),fill="#765143")
    d.line((31,94,186,94),fill="#6d4a40",width=3)
    d.line((32,93,185,93),fill="#a77552")
    d.polygon(((27,64),(195,64),(201,74),(20,74)),fill="#bd885c",outline="#6e4b42")
    d.polygon(((137,65),(194,65),(199,72),(131,72)),fill="#ce9a67")
    for y in (66,70):
        d.line((29,y,192,y),fill="#8f6147")
        d.line((32,y+1,188,y+1),fill="#d7a570")
    for x,y in ((42,66),(72,70),(124,66),(167,70)):
        d.line((x,y,x+13,y),fill="#e5b67c")
        d.line((x+4,y+1,x+9,y+1),fill="#9c6d4f")
    d.arc((65,67,76,70),0,280,fill="#7a5545")
    d.arc((160,65,172,68),20,230,fill="#a36f4b")
    d.rectangle((21,74,201,82),fill="#725043")
    d.line((20,74,201,74),fill="#edbf88",width=2)
    d.line((24,81,197,81),fill="#9d7054")
    for x in (31,114):
        d.rectangle((x,76,x+69,80),outline="#513b37")
        d.line((x+2,76,x+67,76),fill="#ac7a56")
        d.line((x+29,78,x+38,78),fill="#d2ad6b")
    for x in (26,107,194): d.point((x,78),fill="#d5a666")
    d.line((35,74,64,74),fill="#67483f",width=2)
    for j in range(3): arrow(d,36+j*4,72-j*2)
    for j in range(int((3+min(t,14)//4) if tired else min(t,21)//9)): arrow(d,153+j*3,73-j*2)
    for x,y in ((74,71),(80,70),(140,71)):
        d.line((x,y,x+2,y-1),fill="#efd2a1")


def danming_work_pose(t,tired):
    """One connected rig controls the palms and a small whole-body weight drop."""
    from bake_yard_sprites import reach,vec
    suit=comic_suit("danming_origin")
    motion=Motion(suit,"idle",0)
    # Keep the native face at its registered coordinates. The shoulder/wing
    # body drops by one pixel, an ordinary neck overlap rather than face warp.
    sag=round(ease(t,9,17)) if tired else 0
    motion.root[1]+=sag
    motion.mood="half" if tired and t>=14 else "open"
    phase=min(t,11) if tired else t
    stroke=round(3*math.sin(phase*.75))
    # After eleven cels the tired hands stop polishing and rest on the table.
    targets=[vec(38,76),vec(57+stroke,74)]
    motion.arms=[reach(source,motion.on_body(source[0]),target,side)
                 for source,target,side in zip(suit.arms,targets,(-1,1))]
    motion.grips=[arm[2] for arm in motion.arms]
    return suit,motion


def danming_work_foreground(im,t,tired,motion):
    from bake_yard_sprites import arm_layers
    suit=comic_suit("danming_origin")
    # Only wrists covered by the tabletop need a second foreground pass.
    # The original arm pieces and their joints are reused, not redrawn limbs.
    for upper,fore in arm_layers(suit,motion):
        for piece in (upper,fore):
            layer=piece.copy()
            ImageDraw.Draw(layer).rectangle((0,0,95,72),fill=(0,0,0,0))
            im.alpha_composite(layer,(59,-8))
    polishing_detail(ImageDraw.Draw(im),t,motion.grips,tired)


def danming_at_work(im,d,t,tired):
    suit,motion=danming_work_pose(t,tired)
    front(im,"danming_origin",107,96,motion=motion)
    worktop(d,t,tired)
    danming_work_foreground(im,t,tired,motion)


def danming_arrival_pose(t):
    # When the page removes the workshop, release the same two wrists into
    # the neutral pose. Moving joints avoids a one-cel jump to raised hands.
    suit,rest=danming_work_pose(23,True)
    motion=Motion(suit,"idle",0)
    amount=ease(t,13,21)
    motion.root[1]+=round(1-amount)
    motion.mood="half" if t<16 else "open"
    motion.arms=[limb(source,motion.on_body(source[0]),
                      math.degrees(pose[3])*(1-amount),
                      math.degrees(pose[4])*(1-amount))
                 for source,pose in zip(suit.arms,rest.arms)]
    motion.grips=[arm[2] for arm in motion.arms]
    return motion


def danming_scene(im,d,cut,t):
    if cut==0:
        engaged=t<12
        front(im,"danming_origin",111,95,action="welcome" if engaged else "ponder",
             amount=ease(t,0,10) if engaged else ease(t,12,22))
        if engaged:
            for j,x in enumerate((48,153)):
                d.rounded_rectangle((x,27+j*7,x+27,40+j*7),radius=4,fill=PAPER,outline="#846c73")
                for k in range(1+int(min(2,t//3))): d.point((x+7+5*k,33+j*7),fill=INK)
    elif cut in (1,2):
        danming_at_work(im,d,t,cut==2)
    else:
        # Turn the scenery behind a single figure. A wipe between two drawn
        # faces at different positions used to splice them together mid-turn.
        edge=travel(t,5,15,W,0)
        if edge: im.paste(setting("danming",2).crop((0,0,edge,H)),(0,0))
        if 0<edge<W:
            d.rectangle((edge-3,0,edge,H),fill=PAPER)
            d.line((edge-4,0,edge-4,H),fill="#ad896e")
        motion=danming_arrival_pose(t)
        front(im,"danming_origin",107,96,motion=motion)
        if edge:
            props=Image.new("RGBA",im.size)
            worktop(ImageDraw.Draw(props),23,True)
            danming_work_foreground(props,23,True,motion)
            im.alpha_composite(props.crop((0,0,edge,H)),(0,0))


def kubby_scene(im,d,cut,t):
    if cut==0:
        x=travel(t,3,21,64,137)
        profile(im,"kubby_origin",x,94,"right",walk=x-64 if 3<t<21 else 0,shadow=True,rim="#96b5d2")
    elif cut==1:
        hx=travel(t,0,8,62,105)
        if t<11:
            # Settle before the pickup starts; a residual offset at tick 11
            # otherwise snaps the entire silhouette back by six pixels.
            recoil=travel(t,5,9,0,10)-travel(t,9,11,0,10)
            profile(im,"kubby_origin",135+recoil,95-recoil//2,"left",shadow=True,rim="#96b5d2")
            animal(im,hx,89,"hamster")
            if 6<=t<=9:
                edge=164+recoil
                d.line((edge,34,edge+4,29),fill="#d9e7ec",width=1)
                d.line((edge+2,41,edge+7,39),fill="#a5bad2",width=1)
        else:
            # Touch the animal first, then lift it with a shadowed forearm.
            # The pre-transformation outfit remains deliberately undisclosed.
            x=travel(t,17,23,135,114)
            profile(im,"kubby_origin",x,95,"left",walk=135-x if t>17 else 0,shadow=True,rim="#96b5d2")
            hy=travel(t,11,16,89,75)
            hx=travel(t,11,16,105,123) if t<17 else x-12
            elbow=(x-4,64)
            grip=(hx+5,hy-7)
            d.line((x+1,57,*elbow,*grip),fill="#443c50",width=5)
            d.line((elbow[0]-1,elbow[1]+2,grip[0],grip[1]+2),fill="#94afc7",width=1)
            animal(im,hx,hy,"hamster")
            d.line((hx+4,hy-5,hx+6,hy-5,hx+6,hy-8),fill="#b3c7d8",width=1)
    elif cut==2:
        if 6<=t<11: burst(d,134,64,t-6)
        front(im,"kubby_origin",134,95,action="startled",amount=ease(t,5,16),shadow=t<8,rim="#96b5d2" if t<8 else None)
        if t<13: animal(im,83,88,"hamster")
        else: flame(d,86,travel(t,13,21,84,70),t)
        if 12<=t<17: burst(d,85,75,t-12)
    else:
        # The encounter has no specified scenery or cast. A night journey
        # carries the final caption; its companion is the transformed wisp.
        for j in range(7): sparkle(d,21+j*29,15+j%3*5,1+int((t+j)%13<3),"#efdfbd")
        x=travel(t,1,20,52,144)
        profile(im,"kubby_origin",x,97,"right",walk=x-52 if 1<t<20 else 0)
        flame(d,x+23,69+round(2*math.sin(t/3)),t)


def fuwa_scene(im,d,cut,t):
    if cut==0:
        front(im,"fuwa",125,95,"focus",ease(t,0,14))
        mascot(im,"fuwa",83,91-round(2*math.sin(t/3)),t,32)
    elif cut==1:
        if t<8:
            im.paste(setting("fuwa",0))
            profile(im,"fuwa",125,95,"left")
        else:
            x=travel(t,8,23,54,141)
            snow(d,t)
            profile(im,"fuwa",x,96,"right",walk=x-54,rim="#596d96")
    elif cut==2:
        x=travel(t,0,12,58,113)
        snow(d,t)
        profile(im,"fuwa",x,96,"right",walk=x-58 if 0<t<12 else 0,rim="#596d96")
        # A camera reveal at the reunion, with no invented trail or call.
        if t>=12: mascot(im,"fuwa",147,93-round(math.sin(t/3)),t,32)
    else:
        # Only scenery changes beneath the single rigid figure. The previous
        # face-splicing wipe is never used, even while the rift blooms.
        blend=float(np.interp(t,[10,11,12,13,14],[0,.24,.52,.78,1]))
        im.paste(Image.blend(setting("fuwa",2),setting("fuwa",3),blend))
        if 4<=t<15:
            w=travel(t,4,11,1,9)
            fade=1.0 if t<12 else (15-t)/4
            glow=Image.new("RGBA",im.size)
            gd=ImageDraw.Draw(glow)
            path=[(157,7),(162,35),(158,49),(164,70),(171,93)]
            gd.line(path,fill=(243,197,121,round(55*fade)),width=w*2+8)
            gd.line(path,fill=(255,225,170,round(105*fade)),width=w+5)
            gd.line(path,fill=(238,177,110,round(210*fade)),width=max(2,w))
            gd.line(path,fill=(255,243,202,round(250*fade)),width=max(1,w//3))
            gd.line(((160,35),(171,30),(174,17)),fill=(255,235,187,round(220*fade)),width=1)
            gd.line(((163,69),(178,76),(184,88)),fill=(255,235,187,round(210*fade)),width=1)
            # The opening's light lies on the snow, not over the face.
            gd.polygon(((163,90),(174,92),(211,108),(128,108)),fill=(255,219,162,round(75*fade)))
            gd.line((144,102,191,102),fill=(255,237,196,round(100*fade)),width=1)
            im.alpha_composite(glow)
        if t<12: mascot(im,"fuwa",69,93,t,31)
        reveal=BOOKS["fuwa"]["cues"][cut]["reveal"]
        if t<14:
            front(im,"fuwa",107,97,"focus",ease(t,0,7),eyes="closed" if t>=11 else None,rim="#596d96")
        else:
            eyes="closed" if t<reveal else "half" if t<reveal+2 else "open"
            front(im,"fuwa",107,97,"relief",1-.85*ease(t,reveal,23),eyes)


SCENES={"yato":yato_scene,"yune":yune_scene,"danming":danming_scene,
        "kubby":kubby_scene,"fuwa":fuwa_scene}


def illustrated_panel(member,cut,t):
    im=setting(member,cut).copy()
    SCENES[member](im,ImageDraw.Draw(im),cut,t)
    return im.convert("RGB")


@cache
def book_page(member):
    book=BOOKS[member]
    page=Image.new("RGB",(496,378),"#f2e5c8")
    d=ImageDraw.Draw(page)
    # Two stitched edges and an archival header.
    d.rectangle((0,0,4,377),fill="#816b67")
    d.line((6,0,6,377),fill="#d2bd9f")
    d.line((489,0,489,377),fill="#d2bd9f")
    d.rectangle((13,9,16,16),fill="#9f5957")
    text(d,(22,7),"루체테 도서관   /   "+book["fan"]+"의 책갈피",9,"#75585b",True)
    text(d,(13,23),book["title"],22,INK,True)
    text(d,(483,33),book["name"]+" 편",12,"#77565b",True,"rt")
    d.line((13,52,482,52),fill="#9b7c73")
    d.line((13,354,482,354),fill="#bca68c")
    text(d,(13,361),"공식 프로필 기반 · 비공식 팬게임 연출",9,"#876c67")
    text(d,(482,361),book["source"].split("//")[1],9,"#876c67",False,"rt")
    return page


def render_panel(member,cut,frame_index):
    tick=frame_index/SUBSTEPS
    if member == "dori": return dori_panel(cut,tick)
    return illustrated_panel(member,cut,tick)


@cache
def still(member,cut,frame_index):
    return render_panel(member,cut,frame_index)


@cache
def unopened(member,cut):
    # Closed cuts show the same embossed book ornament, concealing locations too.
    paper=Image.new("RGB",(W,H),"#d9c8ad")
    d=ImageDraw.Draw(paper)
    d.rectangle((4,4,W-5,H-5),outline="#c6b498")
    for x,y,dx,dy in ((8,8,1,1),(W-9,8,-1,1),(8,H-9,1,-1),(W-9,H-9,-1,-1)):
        d.line((x+dx*10,y,x,y,x,y+dy*10),fill="#aa9478")
    x,y=W//2,H//2
    for sign in (-1,1):
        d.polygon([(x,y-5),(x+sign*6,y-9),(x+sign*14,y-8),(x+sign*14,y+6),(x+sign*6,y+5),(x,y+9)],fill="#c1ad8f",outline="#a79073")
    sparkle(d,x,y-18,2,"#af9577")
    return paper


def frame(member,active,tick):
    page=book_page(member).copy()
    d=ImageDraw.Draw(page)
    for i,(x,y) in enumerate(PANEL_POS):
        art=unopened(member,i) if i>active else still(member,i,tick if i==active else FRAMES-1)
        edge = "#a05a50" if i == active else "#7e7274"
        d.rectangle((x,y,x+230,y+139),fill=edge)
        page.paste(art,(x+1,y+1))
        d.rectangle((x+1,y+111,x+229,y+138),fill="#f9eed7")
        d.rectangle((x+6,y+117,x+26,y+132),fill=edge)
        text(d,(x+16,y+120),f"{i+1:02}",10,"#fff0ce",True,"mt")
        if i<=active:
            lines=BOOKS[member]["captions"][i].split("\n")
            if i==active and tick<BOOKS[member]["cues"][i]["reveal"]*SUBSTEPS:
                lines=lines[:1]
            for row,line in enumerate(lines):
                # Full-width letters use the available paper, even on a long line.
                size=10 if d.textlength(line,font=font(10,True))<=193 else 9
                assert d.textlength(line,font=font(size,True))<=193,(member,line)
                text(d,(x+33,y+115+row*12),line,size,INK,True)
        else:
            d.line((x+35,y+125,x+60,y+125),fill="#cbb8a7")
        if i==active:
            d.rectangle((x+1,y+1,x+19,y+3),fill=GOLD)
            d.rectangle((x+1,y+1,x+3,y+16),fill=GOLD)
    for i in range(4):
        x=225+i*14
        d.polygon([(x,364),(x+3,361),(x+6,364),(x+3,367)],fill="#994f55" if active==i else "#c8ad91")
    return page


def render(member):
    write_playback()
    sheet=Image.new("RGB",(COLUMNS*W,4*ROWS_PER_CUT*H))
    for i,cue in enumerate(BOOKS[member]["cues"]):
        assert len(cue["frames_ms"])==KEY_FRAMES and 0<cue["reveal"]<KEY_FRAMES
        for t in range(FRAMES+1):
            cel=unopened(member,i) if t==FRAMES else still(member,i,t)
            sheet.paste(cel,((t%COLUMNS)*W,(i*ROWS_PER_CUT+t//COLUMNS)*H))
    sheet.save(COMICS / (member+".png"),optimize=True)
    frames=[frame(member,i,t) for i in range(4) for t in range(FRAMES)]
    # Sample the revealed scenes too, so the last panel keeps its palette.
    sampler=Image.new("RGB",(496*2,378*4))
    for i,(cut,tick) in enumerate([(0,5),(0,21),(1,7),(1,22),(2,6),(2,22),(3,7),(3,22)]):
        n=cut*FRAMES+tick*SUBSTEPS
        sampler.paste(frames[n],((i%2)*496,(i//2)*378))
    palette=sampler.quantize(colors=256)
    output=[im.quantize(palette=palette,dither=Image.Dither.NONE).resize((992,756),NEAREST) for im in frames]
    durations=[ms for cue in BOOKS[member]["cues"] for ms in playback_cue(cue)["frames_ms"]]
    out = ROOT / "artifacts" / (member+"_pixel_comic.gif")
    out.parent.mkdir(exist_ok=True)
    output[0].save(out,save_all=True,append_images=output[1:],duration=durations,loop=0,disposal=1,optimize=False)
    print(out.name)
    # Full-colour counterpart avoids GIF's 256-colour reduction altogether.
    full_color=[im.resize((992,756),NEAREST) for im in frames]
    preview_dir=ROOT/"artifacts/comic_previews"
    preview_dir.mkdir(exist_ok=True)
    (preview_dir/".gdignore").write_text("",encoding="utf-8")
    lossless=preview_dir/(member+"_pixel_comic_smooth.png")
    full_color[0].save(lossless,save_all=True,append_images=full_color[1:],duration=durations,
                       loop=0,disposal=0,blend=0,optimize=True)
    print(lossless.name)
    still.cache_clear()


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all",action="store_true")
    for member in BOOKS if parser.parse_args().all else ["dori"]:
        render(member)
