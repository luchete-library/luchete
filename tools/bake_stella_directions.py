"""Bake three drawn turnarounds per outfit onto the existing 96 x 112 field grid.

Front idle/walk are the original field sheets. The profile rigs use separately
drawn left and right art; the back rig alternates the two visible heels.
"""
from functools import cache
from math import atan2, cos, pi, sin

import numpy as np
from PIL import Image, ImageDraw

from bake_yard_sprites import ART, CELL, GROUND, place
from ete_field_art import costume_art
from character_detail.register_fronts import limited_palette
import json
from bake_pose_transitions import remove_edge_specks

OUT=ART/'directional'
STEPS=16
# Shared row gutters, and the ground axis of each left, right and rear view
# in its full-resolution source. A trailing veil is not the character centre.
SOURCES=(
    ((0,378,744,1103,1536),(
        ('yato_hood',(200,521,819)),('danming_origin',(195,519,814)),
        ('kubby_origin',(191,515,815)),('amiha_yune_idle',(186,533,815)))),
    ((0,384,776,1156,1536),(
        ('shokoko_dori_idle',(189,508,825)),('hakuten_fuwa_idle',(186,512,824)),
        ('odanming_idle',(178,509,825)),('hamkubby_idle',(183,517,825)))),
    ((0,480,966,1461),(
        ('yato_idle',(191,554,853)),('yato_headset',(192,548,853)),
        ('yato_bunny',(188,550,854)))),
    ((0,500,1006,1536),(
        ('yato_knit',(181,521,825)),('yato_track',(180,519,825)),
        ('danming_racing',(168,530,823)))),
)
DIRECTIONS=('left','right','up')

# Approved pet-reference turnaround sheets. Each direction is its own drawing.
SOURCES=(
 ((0,380,746,1106,1536),(
  ('yato_hood',(180,533,823)),('danming_origin',(184,521,820)),
  ('kubby_origin',(182,523,821)),('amiha_yune_idle',(173,518,821)))),
 ((0,384,774,1150,1536),(
  ('shokoko_dori_idle',(178,521,823)),('hakuten_fuwa_idle',(172,521,822)),
  ('aethe',(178,516,827)))),
 ((0,313,627,940,1254),(
  ('yato_idle',(493,783,1040)),('yato_headset',(489,780,1042)),
  ('yato_bunny',(489,780,1041)),('yato_knit',(490,779,1043)))),
 ((0,313,627,940,1254),(
  ('yato_track',(492,778,1041)),('odanming_idle',(490,778,1041)),
  ('danming_racing',(489,778,1042)),('hamkubby_idle',(493,781,1040)))),
)
SOURCE_NAMES=('turns_primary','turns_librarian','turns_alts_a','turns_alts_b')
DETAIL_KEYS=json.loads((ART/'source/detail_v3/registration.json').read_text('utf-8'))


@cache
def source_sheet(group):
    return Image.open(ART/'source/pet_v3'/(SOURCE_NAMES[group]+'.png')).convert('RGBA')


@cache
def registered_pose(group,row,column):
    source=source_sheet(group)
    cuts,models=SOURCES[group]
    key,axes=models[row]
    columns=3 if group<2 else 4
    source_column=column if group<2 else column+1
    x0=source_column*source.width//columns
    # The knit front's far curl crosses the atlas gutter by one source pixel.
    # Exclude that neighbouring sprite while keeping the full profile drawing.
    if group==2 and row==3 and column==0: x0+=4
    tile=source.crop((x0,cuts[row],(source_column+1)*source.width//columns,cuts[row+1]))
    pixels=np.array(tile)
    pixels[pixels[:,:,3]<128]=0
    art=Image.fromarray(pixels)
    l,t,r,b=art.getbbox()
    assert l>0 and t>0 and r<art.width and b<art.height,(key,column,'touching gutter')
    front=costume_art(key).getbbox()
    height=front[3]-front[1]
    scale=height/(b-t)
    axis=axes[column]-x0-l
    crop=art.crop((l,t,r,b))
    if key in DETAIL_KEYS:
        # Resolve directly onto the native grid, like the upgraded front art.
        # Avoid the broad prefilter that erased the small hair/cloth clusters.
        art=crop.transform((round((r-l)*scale),height),Image.Transform.AFFINE,
                           (1/scale,0,0,0,1/scale,0),Image.Resampling.BILINEAR)
    else:
        art=crop.resize((round((r-l)*scale),height),Image.Resampling.LANCZOS)
    rgba=np.array(art)
    rgba[:,:,3]=np.where(rgba[:,:,3]>=104,255,0)
    rgba[rgba[:,:,3]==0]=0
    art=Image.fromarray(rgba)
    if key in DETAIL_KEYS: art=limited_palette(art)
    base=Image.new('RGBA',CELL)
    base.paste(art,(48-round(axis*scale),GROUND+1-art.getbbox()[3]))
    return base,scale,GROUND-(cuts[row]+b-1)*scale
# Shoulder/wrist and the emerging pant leg traced on the left profile sheet.
# The right cel is rigged in left-facing space and flipped back after posing.
# Last two values bound the profile leg either side of its axis in native dots.
TRACES={
    'yato_hood':     ((193,155),(196,227),(196,240),7,4),
    'danming_origin':((188,534),(198,608),(199,623),9,5),
    'kubby_origin':  ((194,888),(206,957),(187,968),9,4),
    'amiha_yune_idle':((186,1280),(190,1357),(184,1472),5,4),
    'shokoko_dori_idle':((188,184),(204,260),(189,283),9,6),
    'hakuten_fuwa_idle':((182,557),(201,632),(186,711),9,5),
    'odanming_idle':((176,928),(194,1017),(177,1034),8,4),
    'hamkubby_idle':((182,1310),(202,1389),(180,1404),8,6),
    'yato_idle':    ((194,163),(213,277),(184,327),8,5),
    'yato_headset': ((196,650),(215,774),(193,793),9,7),
    'yato_bunny':   ((189,1128),(211,1242),(187,1220),8,6),
    'yato_knit':    ((183,182),(194,293),(178,307),11,7),
    'yato_track':   ((177,686),(199,805),(177,800),10,6),
    'danming_racing':((168,1202),(186,1318),(166,1321),9,6),
}
Y,X=np.indices((CELL[1],CELL[0]))
TRACES={
 'yato_hood':((172,169),(180,233),(178,252),7,4),
 'danming_origin':((175,542),(189,613),(180,636),9,5),
 'kubby_origin':((169,894),(188,961),(173,984),9,4),
 'amiha_yune_idle':((167,1298),(176,1370),(167,1464),5,4),
 'shokoko_dori_idle':((170,186),(193,255),(166,285),9,6),
 'hakuten_fuwa_idle':((160,572),(181,637),(161,705),9,5),
 'aethe':((170,937),(194,1002),(170,1024),7,5),
 'yato_idle':((485,114),(492,172),(490,187),8,5),
 'yato_headset':((483,432),(491,495),(485,512),9,7),
 'yato_bunny':((480,748),(489,800),(483,820),9,6),
 'yato_knit':((480,1065),(490,1120),(484,1130),10,7),
 'yato_track':((484,123),(495,193),(482,204),10,6),
 'odanming_idle':((481,445),(494,503),(481,541),8,4),
 'danming_racing':((482,750),(493,817),(481,832),9,6),
 'hamkubby_idle':((488,1090),(499,1150),(486,1163),8,5),
}


def masked(art,mask):
    pixels=np.array(art)
    pixels[~mask]=0
    return Image.fromarray(pixels)


def shade(art):
    pixels=np.array(art)
    pixels[:,:,:3]=np.rint(pixels[:,:,:3]*[.74,.76,.80])
    return Image.fromarray(pixels)


def turn(a,b):
    return atan2(b[1],b[0])-atan2(a[1],a[0])


class WalkRig:
    def __init__(self,group,row,column):
        self.key,axes=SOURCES[group][1][row]
        self.column=column
        neutral,_,_=registered_pose(group,row,column)
        self.neutral=neutral
        self.back=column==2
        self.reverse=column==1
        self.art=neutral.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if self.reverse else neutral
        _,scale,dy=registered_pose(group,row,0)
        sh,hand,leg,left,right=TRACES[self.key]
        def point(p):
            return np.rint([48+(p[0]-axes[0])*scale,p[1]*scale+dy]).astype(int)
        self.shoulder,palm,leg=map(point,(sh,hand,leg))
        self.cut=int(leg[1])
        self.draped=self.key=='amiha_yune_idle'
        self.axis=int(leg[0]) if not self.back else 48
        # Include an overlap inside the hem so raising either knee cannot
        # produce a transparent horizontal line between body and legs.
        self.cut-=2
        low=(Y>=self.cut)&(X>=self.axis-left)&(X<=self.axis+right)
        if self.back and not self.draped:
            # Above the heels the long loose coat tails remain on the body.
            low=(Y>=self.cut)&(abs(X-47.5)<=8)
        visible=np.array(self.art)[:,:,3]>0
        self.leg=masked(self.art,low)
        body=masked(self.art,~low|(Y<=self.cut+2))
        self.arms=[]
        if not self.back:
            # Keep the whole near sleeve on the shoulder joint. Paint only
            # the occluded material under that sleeve from adjacent cloth.
            arm_mask=Image.new('L',CELL);d=ImageDraw.Draw(arm_mask)
            width=6 if self.key in ('kubby_origin','hakuten_fuwa_idle','yato_headset','yato_knit','yato_track') else 4
            sx,sy=self.shoulder;wx,wy=palm;half=width/2
            d.polygon([(sx-half,sy+1),(sx-1,sy-2),(sx+half,sy),(wx+half+1,wy),
                       (wx+1,wy+2),(wx-half,wy+1)],fill=255)
            arm=(np.asarray(arm_mask)>0)&visible
            self.arms.append(masked(self.art,arm))
            pixels=np.array(body)
            for y in range(sy-2,wy+3):
                removed=np.where(arm[y])[0]
                neighbors=np.where((~arm[y])&(pixels[y,:,3]>0))[0]
                for x in removed:
                    if not len(neighbors): pixels[y,x]=0;continue
                    index=neighbors[np.argmin(abs(neighbors-x))]
                    if abs(x-index)<=3 or neighbors[0]<x<neighbors[-1]:
                        pixels[y,x]=pixels[y,index]
                    else: pixels[y,x]=0
            body=Image.fromarray(pixels)
        self.body=body
        if self.back:
            self.legs=[masked(self.leg,X<48),masked(self.leg,X>=48)]
        else:
            self.legs=[shade(self.leg),self.leg]

    def leg_pose(self,art,index,angle,bob):
        wave=sin(angle)
        lift=max(0.,cos(angle))
        short=self.draped
        center=(45 if index==0 else 51) if self.back else self.axis
        top=np.array((center,self.cut+1.),float)
        ankle=np.array((center,GROUND-(2 if short else 4)),float)
        knee=top+(ankle-top)*.53
        if self.back:
            stride=np.array((wave*.45,-lift*(1.3 if short else 3.2)))
            flex=np.array((wave*.45,-lift))
        else:
            stride=np.array((-wave*(2.8 if short else 6),-lift*(1.2 if short else 3.2)))
            flex=np.array((-lift*(.5 if short else 2.3),-lift*.45))
        hip=top+[0,bob]
        sole=ankle+stride
        joint=hip+(sole-hip)*.53+flex
        upper=turn(knee-top,joint-hip)
        lower=turn(ankle-knee,sole-joint)
        posed=place(masked(art,Y<=knee[1]+1.5),top,hip,upper)
        posed.alpha_composite(place(masked(art,(Y>=knee[1]-1.5)&(Y<ankle[1]+2)),knee,joint,lower))
        posed.alpha_composite(place(masked(art,Y>=ankle[1]-1),ankle,sole))
        return posed

    def walk(self,n,carrying=False):
        angle=n*2*pi/STEPS
        bob=round(-cos(2*angle)*.8)
        out=Image.new('RGBA',CELL)
        for i,art in enumerate(self.legs):
            out.alpha_composite(self.leg_pose(art,i,angle+i*pi,bob))
        if self.arms:
            sh=self.shoulder
            out.alpha_composite(place(shade(self.arms[0]),sh,sh+[0,bob],-.19*sin(angle)))
        out.alpha_composite(self.body,(0,bob))
        if self.arms:
            out.alpha_composite(place(self.arms[0],sh,sh+[0,bob],.95 if carrying else .23*sin(angle)))
        if self.reverse: out=out.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # Plant the lowest inked sole on the same floor as the front walk.
        box=out.getbbox()
        final=Image.new('RGBA',CELL)
        final.alpha_composite(out,(0,GROUND+1-box[3]))
        pixels=np.array(final)
        remove_edge_specks(pixels,Y>64)
        return Image.fromarray(pixels)


def bake():
    for group,(_,models) in enumerate(SOURCES):
        for row,(key,_) in enumerate(models):
            atlas=Image.new('RGBA',((STEPS+1)*CELL[0],3*CELL[1]))
            for col in range(3):
                rig=WalkRig(group,row,col)
                frames=[rig.neutral]+[rig.walk(i) for i in range(STEPS)]
                assert len({im.tobytes() for im in frames[1:]})>=6,(key,col,'static gait')
                for i,im in enumerate(frames):
                    l,t,r,b=im.getbbox()
                    assert 0<l<r<96 and 0<t<b==104,(key,col,i,im.getbbox())
                    atlas.paste(im,(i*96,col*112))
            atlas.save(OUT/('aethe_turns.png' if key=='aethe' else key+'.png'),optimize=True)
            print(key,flush=True)
    import shutil
    shutil.copy2(OUT/'amiha_yune_idle.png',OUT/'yune_unveiled.png')
    bake_librarian()

def bake_librarian():
    from yard_costumes import Costume
    from bake_yard_sprites import frame
    suit=Costume('aethe','aethe')
    turns=Image.open(OUT/'aethe_turns.png').convert('RGBA')
    keys=Image.new('RGBA',(5*96,4*112))
    walk=Image.new('RGBA',(16*96,4*112))
    for row in range(4):
        neutral=frame(suit,'idle',0,True) if row==0 else turns.crop((0,(row-1)*112,96,row*112))
        keys.paste(neutral,(0,row*112))
        for n in range(16):
            cel=frame(suit,'walk',n*12/16,True) if row==0 else turns.crop(((n+1)*96,(row-1)*112,(n+2)*96,row*112))
            walk.paste(cel,(n*96,row*112))
            if n%4==0:keys.paste(cel,((1+n//4)*96,row*112))
    keys.save(OUT/'aethe.png');walk.save(OUT/'aethe_walk.png')
    front=keys.crop((16,14,80,104));front.save(ART/'field/aethe.png')
    bake_story_librarian()



def bake_story_librarian():
    from yard_costumes import Costume
    from bake_yard_sprites import Motion,frame,limb,reach,vec
    suit=Costume('aethe','aethe')
    sheet=Image.new('RGBA',(17*96,112))
    for col in range(2):
        m=Motion(suit,'idle',0);m.empty_hands=True;m.arms=[]
        for side,source,target in zip((-1,1),suit.arms,((17,57),(30,57))):
            shoulder=m.on_body(source[0])
            arm=reach(source,shoulder,m.on_body(vec(*target)),side) if col else limb(source,shoulder,0,0)
            m.arms.append(arm)
        m.grips=[arm[2] for arm in m.arms]
        sheet.paste(frame(suit,'idle',0,True,m),(col*96,0))
    sheet.crop((0,0,192,112)).save(OUT/'aethe_story.png')
    rig=WalkRig(1,2,0)
    for i in range(16):sheet.paste(rig.walk(i,carrying=True),(i*96,0))
    sheet.crop((0,0,16*96,112)).save(OUT/'aethe_carry_walk.png')

if __name__=='__main__': bake()
