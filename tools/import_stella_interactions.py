"""Render personal library reactions from the same equipped puppet as the lobby."""
import argparse
import json
from math import degrees, radians

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from preview_yard_sprites import save_gif
from bake_yard_sprites import ART, CELL, Motion, face_fit, frame, limb, reach, vec
from field_face_fit import FOOT
from ete_field_art import drawing
from yard_costumes import Costume, KEYS

ROOT=ART.parents[1]
OUT=ART/'interactions'
SPECS=json.loads((ROOT/'tools/stella_interaction_specs.json').read_text(encoding='utf-8'))

# Left and right hand targets in native body space, shoulder lean and head
# tilt. These holds follow each member's existing interaction descriptions.
SOCIAL={
    'welcome': (None,'wave',1,2,'smile'),
    'curious': (None,(35,53),2,5,'open'),
    'cheer': ((27,59),(37,59),0,-2,'closed'),
    'bashful': ((27,60),(36,62),-1,-4,'blush'),
    'heart': ((28,60),(34,59),1,-2,'closed'),
    'ponder': ((29,65),(35,53),-1,-4,'half'),
    'proud': ((21,69),None,-2,2,'smile'),
    'startled': ((22,57),(42,55),-2,-3,'surprise'),
    'relief': (None,(32,59),0,2,'breath'),
    'rhythm': ((23,57),'wave',2,3,'closed'),
    'listen': (None,(42,53),1,5,'open'),
    'dreamy': ((29,63),(36,63),-1,-3,'closed'),
    'reassure': ((28,61),(44,61),0,2,'smile'),
    'salute': (None,(44,44),1,-2,'smile'),
    'inspect': ((29,65),(37,51),2,6,'open'),
    'idea': ((28,65),(46,49),-1,-3,'wink'),
    'resolve': (None,(39,56),-1,-3,'smile'),
    'focus': ((29,59),(35,59),0,2,'open'),
}
PERSONAL={
    ('danming','welcome'): (None,'wave',-1,-3,'wink'),
    ('yune','welcome'): ((30,65),(45,57),0,3,'smile'),
    ('fuwa','welcome'): ((26,61),'wave',2,-3,'closed'),
    ('kubby','curious'): ((27,64),None,-2,-5,'open'),
    ('dori','bashful'): (None,(44,49),1,4,'blush'),
}

# Each pair is (travel, hold), in seconds, for anticipation, reach,
# expression, recovery and return. A quick arrival needn't shorten the hold.
PACING={
    'startle':   ((.09,0),(.12,0),(.18,.26),(.50,.27),(.47,.04)),
    'spark':     ((.12,.02),(.14,.02),(.17,.34),(.26,.09),(.28,.04)),
    'greeting':  ((.15,.03),(.19,.04),(.22,.45),(.30,.08),(.32,.04)),
    'encourage': ((.14,.04),(.19,.08),(.21,.55),(.33,.09),(.30,.05)),
    'consider':  ((.20,.06),(.26,.07),(.29,.60),(.36,.12),(.34,.04)),
    'bashful':   ((.15,.15),(.24,.12),(.26,.48),(.40,.17),(.39,.04)),
    'gentle':    ((.22,.06),(.29,.08),(.33,.61),(.41,.15),(.41,.05)),
    'blink':     ((.23,.05),(.28,.06),(.15,.15),(.29,.21),(.37,.05)),
    # Preserve the existing deliberate listen, including its held head tilt.
    'listen':    ((.249,.051),(.332,.068),(.38,.62),(.332,.068),(.249,.051)),
}
CLICK_PACING={
    'yato':    {'welcome':'greeting','curious':'consider','cheer':'encourage','bashful':'bashful'},
    'danming': {'welcome':'spark','heart':'encourage','ponder':'consider','proud':'greeting'},
    'kubby':   {'startled':'startle','relief':'gentle','curious':'consider','rhythm':'spark'},
    'yune':    {'welcome':'gentle','listen':'listen','dreamy':'blink','reassure':'gentle'},
    'dori':    {'salute':'greeting','inspect':'consider','idea':'spark','bashful':'bashful'},
    'fuwa':    {'welcome':'spark','resolve':'encourage','focus':'consider','relief':'gentle'},
}

def social_pose(suit,action,index):
    left,right,lean,tilt,mood=PERSONAL.get((suit.member,action),SOCIAL[action])
    weight=(.18,.68,1.,.31)[index]
    m=Motion(suit,'idle',0)
    m.lean=radians(lean*weight)
    m.head_angle=radians((lean+tilt)*weight)
    m.head_target=m.on_body(m.neck)+vec(0,1 if index==2 and action in ('proud','focus','relief') else 0)
    m.mood=(mood if index==2 else 'half' if index in (1,3) and mood in ('closed','breath','blush') else 'open')
    shrug=0
    if action=='startled':
        if index<3:
            # Eyes react on the first beat; lift the shoulder under the sleeve
            # before the hands reach the chest. The feet retain their contact.
            m.mood='surprise'
            shrug=1
            m.head_target+=vec(0,-1)
        else:
            # Exhale, lower the near arm and keep one palm on the chest.
            left,right=None,(32,59)
            weight=.86
            m.lean=0.
            m.head_angle=radians(2)
            m.head_target=m.on_body(m.neck)+vec(0,1)
            m.mood='breath'
    m.arms=[]
    for side,source,target in zip((-1,1),suit.arms,(left,right)):
        sh=m.on_body(source[0])-vec(0,shrug)
        if target=='wave':
            turns=(-58,-152 if index==2 else -127)
        elif target is None:
            turns=(lean,lean)
        else:
            x,y=target
            # Retarget the authored hand reach to this costume's collar.
            hand=vec(32+(x-32)*(32-suit.fit.shoulder[0])/10, suit.fit.chin+(y-51))
            # Chin-touch gestures sit below the jaw. The glove/cuff extends
            # above its joint and must not overwrite the cheek or eye pixels.
            if abs(hand[0]-32)<10:
                hand[1]=max(hand[1],suit.fit.chin+6)
            arm=reach(source,sh,m.on_body(hand),side)
            turns=tuple((degrees(a)+180)%360-180 for a in arm[3:])
        m.arms.append(limb(source,sh,turns[0]*weight,turns[1]*weight))
    m.grips=[arm[2] for arm in m.arms]
    return m


def furniture_pose(suit,action,index):
    n=(0,4,10,2)[index]
    if action=='stream':
        signature={'yato':'welcome','danming':'heart','kubby':'rhythm',
                   'yune':'reassure','dori':'salute','fuwa':'resolve'}[suit.member]
        return social_pose(suit,signature,index)
    m=Motion(suit,action,n)
    if index==2 and action=='tea': m.mood='breath' if suit.member in ('fuwa','yune') else 'closed'
    if index==2 and action=='read': m.mood='half' if suit.member=='yune' else 'open'
    return m


def pack(member, make_preview=True):
    spec=SPECS[member]
    for key in KEYS[member]:
        suit=Costume(member,key)
        neutral=frame(suit,'idle',0,True)
        atlas=Image.new('RGBA',(480,896))
        actions=[]
        for kind in ('social','furniture'):
            for action,label,description in spec[kind]:
                row=len(actions)
                anchors=[]; bounds=[]
                for col in range(5):
                    m=(social_pose if kind=='social' else furniture_pose)(suit,action,min(col,3))
                    if col==4:
                        cel=neutral; m=Motion(suit,'idle',0)
                    else:
                        cel=frame(suit,m.act,m.n,True,m)
                    fit=face_fit(suit,m)
                    dy=FOOT+1-cel.getbbox()[3]
                    if dy:
                        grounded=Image.new('RGBA',CELL)
                        grounded.alpha_composite(cel,(0,dy)); cel=grounded
                    if member=='dori' and action=='read' and col in (1,2):
                        # A tiny blue glass and brass rim sit over the book, below the chin.
                        x,y=np.rint(m.grips[1]+[1,-4+dy]).astype(int)
                        d=ImageDraw.Draw(cel)
                        d.line((x,y+1,x+3,y+5),fill='#826443',width=2)
                        d.ellipse((x-3,y-4,x+2,y+1),fill='#b0d3d2',outline='#755944')
                        d.point((x-1,y-3),fill='#f1f5dc')
                    anchors.append([round(fit.eye_x,3),round(fit.eye_y+dy,3),round(fit.angle,6)])
                    bounds.append(cel.getbbox())
                    atlas.paste(cel,(col*96,row*112))
                entry=dict(id=action,label=label,description=description,kind=kind,row=row,
                           bounds=bounds,head_anchors=anchors)
                if kind=='social':
                    phases=PACING[CLICK_PACING[member][action]]
                    entry['durations']=[round(travel+hold,3) for travel,hold in phases]
                    entry['travel_seconds']=[travel for travel,_ in phases]
                else:
                    entry['durations']=[.45,.55,5.6,.7,.7]
                actions.append(entry)
        base=key==spec['costume']
        filename=member if base else key
        src=drawing(key)
        cx,crown=src.pins[:2]
        left,right,eye=suit.fit.eyes
        field_face=dict(skull=round((right-left)*2.9),eye_to_chin=suit.fit.chin-eye,
                        crown_to_eye=eye-src.point(cx,crown)[1],standing_chin=suit.fit.chin+14)
        manifest=dict(member=member,name=spec['name'],costume=key,cell=CELL,foot=[48,FOOT],
                      actions=actions,basis=spec['basis'],source=spec['source'],
                      stages=['준비','동작 시작','반응','마무리','대기'],
                      field_face=field_face)
        atlas.save(OUT/(filename+'.png'))
        (OUT/(filename+'.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        if make_preview and base: preview(member,atlas,manifest)
        print(filename,'8 reactions',flush=True)


def phase(times,t):
    for i,d in enumerate(times):
        if t<d:return i
        t-=d
    return 4

def preview(member,atlas,data):
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
    title=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',25)
    frames=[]
    # Display each sequence once, then hold its original idle. No body warping.
    for tick in range(80):
        image=Image.new('RGB',(1080,680),'#2e443b')
        d=ImageDraw.Draw(image)
        d.text((20,12),data['name']+' · 클릭 반응 4종 / 가구 동작 4종',font=title,fill='#f5e2bd')
        for i,action in enumerate(data['actions']):
            x,y=12+(i%4)*268,64+(i//4)*300
            d.rounded_rectangle((x,y,x+254,y+288),5,fill='#41574b')
            d.text((x+10,y+8),action['label'],font=font,fill='#fff1d5')
            t=tick*.1
            col=phase(action['durations'],t)
            cel=atlas.crop((col*96,i*112,(col+1)*96,(i+1)*112)).resize((192,224),Image.Resampling.NEAREST)
            image.paste(cel,(x+30,y+28),cel)
            d.text((x+10,y+260),data['stages'][col],font=font,fill='#cee0cc')
        frames.append(image)
    frames[13].save(ROOT/f'artifacts/{member}_interactions.png')
    save_gif(frames,ROOT/f'artifacts/{member}_interactions.gif',[100]*80)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('members',nargs='*',default=list(SPECS))
    parser.add_argument('--atlas-only',action='store_true')
    args=parser.parse_args()
    from bake_rigid_interactions import bake
    bake(args.members)
    if not args.atlas_only:
        from preview_pet_rollout import main
        main()
