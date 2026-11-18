"""Bake joint-space transitions, with rigid faces and discrete native expressions."""
import copy
import json
from math import degrees
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from bake_yard_sprites import Motion,frame,face_fit,limb,reach,vec,CELL,ART
from yard_costumes import Costume,KEYS
from import_stella_interactions import pack,SPECS,social_pose,furniture_pose
from import_ete_interactions import ACTIONS as ETE_ACTIONS

OUT=ART/'interactions'
STEPS=8
checked=0

def blend(suit,a,b,t):
    if t==0:return copy.deepcopy(a)
    m=copy.deepcopy(b)
    for field in ['root','pivot','neck','head_offset','head_target']:
        setattr(m,field,(1-t)*getattr(a,field)+t*getattr(b,field))
    m.lean=(1-t)*a.lean+t*b.lean
    m.n=(1-t)*a.n+t*b.n
    m.head_angle=0.
    m.mood=a.mood if t<.5 else b.mood
    m.act=b.act if b.act!='idle' else a.act
    m.seated_amount=(1-t)*float(a.act=='yoga')+t*float(b.act=='yoga')
    m.arms=[]
    for source,first,last in zip(suit.arms,a.arms,b.arms):
        shoulder=m.on_body(source[0])
        target=(1-t)*first[2]+t*last[2]
        elbow=(1-t)*first[1]+t*last[1]
        # Interpolate the hand path, then solve two rigid bones. Angle-only
        # blends can arc a cup above its endpoint and cover the eye.
        choices=[reach(source,shoulder,target,side) for side in (-1,1)]
        m.arms.append(min(choices,key=lambda pose:np.linalg.norm(pose[1]-elbow)))
    m.grips=[arm[2] for arm in m.arms]
    return m

def grounded(suit,m):
    global checked
    cel=frame(suit,m.act,m.n,True,m)
    dy=104-cel.getbbox()[3]
    if dy:
        result=Image.new('RGBA',CELL);result.alpha_composite(cel,(0,dy));cel=result
    # A whole-source head is translated, never reconstructed from warped rows.
    from bake_yard_sprites import core_nodes
    head,_=core_nodes(suit,m)
    rig=suit.seated_rig if m.act=='yoga' else suit.rig
    assert np.count_nonzero(np.array(head)[:,:,3])==np.count_nonzero(np.array(rig[m.mood][0])[:,:,3])
    checked+=1
    return cel

def atlas_for(suit,actions,make_motion):
    keyframes=Image.new('RGBA',(5*96,len(actions)*112))
    smooth=Image.new('RGBA',((STEPS*5+1)*96,len(actions)*112))
    neutral=Motion(suit,'idle',0)
    for row,item in enumerate(actions):
        poses=[make_motion(item['id'],i) for i in range(4)]+[neutral]
        guides=[];bounds=[]
        for col,m in enumerate(poses):
            cel=grounded(suit,m);keyframes.paste(cel,(col*96,row*112))
            fit=face_fit(suit,m);dy=104-frame(suit,m.act,m.n,motion=m).getbbox()[3]
            guides.append([float(fit.eye_x),float(fit.eye_y+dy),0.]);bounds.append(cel.getbbox())
        item['bounds']=bounds;item['head_anchors']=guides
        sequence=[neutral]+poses
        for segment,(a,b) in enumerate(zip(sequence,sequence[1:])):
            for i in range(STEPS):
                m=blend(suit,a,b,i/STEPS)
                cel=grounded(suit,m)
                smooth.paste(cel,((segment*STEPS+i)*96,row*112))
        smooth.paste(grounded(suit,neutral),(STEPS*5*96,row*112))
    return keyframes,smooth

def ete_pose(suit,action,index):
    if action in ('give','receive','read','tea'):
        return Motion(suit,'tea' if action=='tea' else 'read',(0,4,10,2)[index])
    signatures={'greet':'welcome','listen':'listen','pet':'dreamy','recognize':'curious',
                'transform':'idea','rest':'dreamy','cheer':'cheer','goodbye':'welcome'}
    m=social_pose(suit,signatures[action],index)
    # Keep the librarian's book hand at the waist while her free hand reacts.
    source=suit.arms[0]
    m.arms[0]=reach(source,m.on_body(source[0]),m.on_body(vec(28,suit.fit.shoulder[1]+14)),-1)
    m.grips=[arm[2] for arm in m.arms]
    if action in ('pet','rest') and index==2:m.mood='closed'
    if action=='recognize' and index==2:m.mood='smile'
    return m

def bake(member_filter=None):
    (OUT/'motion').mkdir(exist_ok=True)
    for member,keys in KEYS.items():
        if member_filter is not None and member not in member_filter:continue
        pack(member,False)
        for key in keys:
            filename=member if key==SPECS[member]['costume'] else key
            path=OUT/(filename+'.json');data=json.loads(path.read_text('utf-8'))
            suit=Costume(member,key)
            social={row[0] for row in SPECS[member]['social']}
            def motion(action,index):
                return (social_pose if action in social else furniture_pose)(suit,action,index)
            keys_sheet,sheet=atlas_for(suit,data['actions'],motion)
            keys_sheet.save(OUT/(filename+'.png'));sheet.save(OUT/'motion'/(filename+'.png'))
            data['transition_method']='joint-space; rigid native face; no optical flow'
            path.write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
    suit=Costume('aethe','aethe')
    actions=[dict(id=a,label=b,row=i,durations=c,description=d) for i,(a,b,c,d) in enumerate(ETE_ACTIONS)]
    keys_sheet,sheet=atlas_for(suit,actions,lambda action,index:ete_pose(suit,action,index))
    keys_sheet.save(OUT/'aethe.png');sheet.save(OUT/'motion/aethe.png')
    data=dict(cell=CELL,foot=[48,103],facing='down',actions=actions,
              stages=['준비','동작 시작','반응·표정','마무리','대기'],
              creation='approved pet-reference art; rigid joint-space animation',
              transition_method='joint-space; rigid native face; no optical flow',
              field_face={'eye_to_chin':suit.fit.chin-suit.fit.eyes[2]})
    (OUT/'aethe.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),'utf-8')
    print('RIGID INTERACTIONS:',checked,'checked frames; all faces retain their opaque pixel area.')

if __name__=='__main__':bake()
