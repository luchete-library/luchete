"""Bake first-reconstruction work on the approved rigid character rigs.

Only assets/characters/growth_work is written. The earlier corridor authoring
track is reused, but all costume pixels are read from today's detail_v3 rig.
"""
from pathlib import Path
import importlib.util
import json
import sys
from math import sin, pi

import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/growth_work'
sys.path.insert(0,str(ROOT/'tools'))
from yard_costumes import Costume
from bake_yard_sprites import Motion, frame, core_nodes, arm_layers, validate_pose, reach, vec, px
from bake_rigid_interactions import blend

FPS=24
COLUMNS=24
FRAMES=12*FPS
CELL=(96,112)
CAST={
    'shelves': [('dori','shokoko_dori_idle'),('danming','danming_origin')],
    'reading': [('yune','amiha_yune_idle'),('kubby','kubby_origin')],
}

def ease(value):
    value=max(0.,min(1.,value))
    return value*value*(3-2*value)

def envelope(t,start,peak,end):
    return ease((t-start)/(peak-start)) if t<peak else 1-ease((t-peak)/(end-peak))

def work_pose(suit,task,t):
    if task=='reading' and suit.member=='yune':
        reading=Motion(suit,'read',t*2)
        return blend(suit,Motion(suit,'idle',0),reading,ease(t/2)) if t<2 else reading
    m=Motion(suit,'idle',0)
    m.act='construction'
    m.head_angle=0.
    m.head_target=m.on_body(m.neck)+vec(0,round(sin(min(1.,t/2)*pi)))
    m.arms=[]
    if task=='shelves':
        for i,source in enumerate(suit.arms):
            side=-1 if i==0 else 1
            base=vec(32+side*8,suit.fit.shoulder[1]+10)
            if i==1:
                amount=envelope(t,2.5,5.0,7.5)
                if suit.member=='danming' and t>=7.5:
                    amount=envelope(t,7.5,9.3,11.5)
                destination=vec(45,suit.fit.shoulder[1]+1)
                base=base+(destination-base)*amount
            m.arms.append(reach(source,m.on_body(source[0]),m.on_body(base),side))
    else:
        for i,source in enumerate(suit.arms):
            side=-1 if i==0 else 1
            base=source[2]
            if i==0:
                amount=envelope(t,1.5,4.5,7.5)
                destination=vec(18,suit.fit.shoulder[1]+2)
                base=base+(destination-base)*amount
            m.arms.append(reach(source,m.on_body(source[0]),m.on_body(base),side))
        if 5.0<t<7.0:
            m.head_target+=vec(0,1)
            m.mood='smile'
    m.grips=[arm[2] for arm in m.arms]
    return m

def draw_book(cel,m,t,member):
    # The book follows the same wrist as the arm. It leaves the hand at the
    # shelf, after which the runtime draws the placed spine at that location.
    if t>=5.0:return
    point=(m.grips[0]+m.grips[1])*.5 if t<2.5 else m.grips[1]
    x,y=px(point)
    d=ImageDraw.Draw(cel)
    color='#af7589' if member=='danming' else '#738e8f'
    d.rectangle((x-5,y-8,x+4,y+2),fill=color,outline='#453b47')
    d.line((x-3,y-6,x-3,y),fill='#d9bb8a')
    d.line((x-1,y-5,x+2,y-5),fill='#eee0ba')
    d.line((x-1,y-2,x+2,y-2),fill='#d7c398')
    d.line((x-4,y+1,x-1,y+1),fill='#f2d4be',width=2)

def bake_corridor():
    path=ROOT/'artifacts/corridor_motion_20261116/bake_motions.py'
    spec=importlib.util.spec_from_file_location('growth_corridor_source',path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.HERE=OUT
    # Keep arms behind the native face, exactly as in the production field
    # renderer. Validate the full connected bones before that occlusion.
    def visible_arms(suit,m):
        head,_=core_nodes(suit,m)
        front=(np.asarray(head.getchannel('A'))>0)&(np.arange(112)[:,None]<=round(m.head_target[1])+1)
        result=[]
        for upper,fore in arm_layers(suit,m):
            parts=[]
            for part in (upper,fore):
                pixels=np.array(part);pixels[front]=0
                parts.append(Image.fromarray(pixels))
            result.append(tuple(parts))
        return result
    module.arm_layers=visible_arms
    module.validate_pose=lambda suit,m,core,parts,complete:validate_pose(suit,m,core,arm_layers(suit,m),complete)
    assert module.build(),'Corridor pose validation failed'
    data=json.loads((OUT/'motions.json').read_text('utf-8'))
    data['production_integrated']=False
    data['purpose']='first-reconstruction review build; approved detail_v3 art'
    (OUT/'motions.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
    return data['validation']

def build():
    OUT.mkdir(exist_ok=True)
    corridor=bake_corridor()
    manifest={'fps':FPS,'columns':COLUMNS,'frames':FRAMES,'cell':CELL,'duration':12,'actors':{},'validation':{'poses':0,'failures':[]}}
    for task,cast in CAST.items():
        for member,key in cast:
            suit=Costume(member,key)
            sheet=Image.new('RGBA',(COLUMNS*96,(FRAMES//COLUMNS)*112))
            hands=[]
            for i in range(FRAMES):
                t=i/FPS
                motion=work_pose(suit,task,t)
                cel=frame(suit,motion.act,motion.n,True,motion)
                head,_=core_nodes(suit,motion)
                expected=suit.rig[motion.mood][0]
                assert np.count_nonzero(np.asarray(head)[:,:,3])==np.count_nonzero(np.asarray(expected)[:,:,3]),(task,member,i,'face scale')
                if task=='shelves':draw_book(cel,motion,t,member)
                assert cel.getbbox() and cel.getbbox()[3]<=108,(task,member,i,'floor bounds')
                sheet.paste(cel,((i%COLUMNS)*96,(i//COLUMNS)*112))
                hands.append([p.round(3).tolist() for p in motion.grips])
                manifest['validation']['poses']+=1
            filename=f'{task}_{member}.png'
            sheet.save(OUT/filename,optimize=True)
            manifest['actors'][member]={'task':task,'costume':key,'file':filename,'hands':hands}
    manifest['validation']['corridor']=corridor
    (OUT/'work.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
    # Inspect actual packed poses, without generated or repainted previews.
    board=Image.new('RGB',(6*192,4*250+50),'#2b3d3d')
    from PIL import ImageFont
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
    d=ImageDraw.Draw(board)
    for row,(member,item) in enumerate(manifest['actors'].items()):
        sheet=Image.open(OUT/item['file']).convert('RGBA')
        for col,t in enumerate([0,2,4,5,7,10]):
            n=t*FPS;x=(n%COLUMNS)*96;y=(n//COLUMNS)*112
            cel=sheet.crop((x,y,x+96,y+112)).resize((192,224),Image.Resampling.NEAREST)
            board.paste(cel,(col*192,row*250+26),cel)
            d.text((col*192+8,row*250+10),f'{member} / {t}s',font=font,fill='#f2dfb7')
    board.save(OUT/'pose_review.png')
    print('GROWTH WORK:',manifest['validation']['poses']+corridor['checked_poses'],'validated native poses; rigid heads and connected joints.')

if __name__=='__main__':build()
