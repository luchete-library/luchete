"""Check the marked face contours and packed pixels used by the field renderer."""
import json
from functools import lru_cache
from math import cos, radians, sin

import numpy as np
from PIL import Image

from field_face_fit import FOOT, JAW
from ete_field_art import drawing, source_cell
from bake_pose_transitions import STEPS, head_anchors
from bake_yard_sprites import ACTIONS, COLUMNS, FRAMES, Motion, face_fit
from yard_costumes import ART, KEYS, Costume, fit_costume


def cel(atlas,x,y):
    return atlas.crop((96*x,112*y,96*(x+1),112*(y+1))).tobytes()


@lru_cache(maxsize=4096)
def silhouette_parts(bits):
    # Eight-neighbour flood fill on packed rows. Eight clear bits at the end
    # of each 96-pixel row keep the opposite edges from ever joining.
    stride=104
    remaining=int.from_bytes(bits,'little')
    parts=[]
    while remaining:
        reached=remaining & -remaining
        while True:
            sideways=reached | (reached<<1) | (reached>>1)
            expanded=(sideways | (sideways<<stride) | (sideways>>stride)) & remaining
            if expanded==reached: break
            reached=expanded
        parts.append((reached.bit_count(),(reached.bit_length()-1)//stride))
        remaining ^= reached
    return sorted(parts,reverse=True)


def check_outline(alpha,key,action,n):
    mask=np.asarray(alpha)
    box=alpha.getbbox()
    assert box and 0<box[0]<box[2]<96 and 0<box[1]<box[3]<112,(key,action,n,box)
    padded=np.pad(mask>=128,((0,0),(0,8)))
    parts=silhouette_parts(np.packbits(padded,axis=1,bitorder='little').tobytes())
    assert parts,(key,action,n,'empty silhouette')
    for area,bottom in parts[1:]:
        # The original moon outfit has a floating gold halo/butterfly.
        assert key=='danming_origin' and bottom<48,(key,action,n,'detached pixels',area,bottom)


def check_blinks():
    # The face dimensions may pass even if an eyelid breaks into isolated dots.
    # Inspect the ink on the shipped exercise frames, including the tilted pose.
    gym=Image.open(ART/'yard/gym.png').convert('RGBA')
    widths=[];margins=[]
    yy,xx=np.indices((112,96))
    row=0
    for member,keys in KEYS.items():
        for key in keys:
            suit=Costume(member,key)
            for n in (54,55,56):
                m=Motion(suit,'gym',n/3)
                assert m.mood=='closed'
                fit=face_fit(suit,m)
                pixels=np.frombuffer(cel(gym,n%COLUMNS,row*2+n//COLUMNS),dtype='uint8').reshape(112,96,4)
                u=(xx-fit.eye_x)*cos(m.head_angle)+(yy-fit.eye_y)*sin(m.head_angle)
                v=-(xx-fit.eye_x)*sin(m.head_angle)+(yy-fit.eye_y)*cos(m.head_angle)
                for points,ink,tip in suit.lids:
                    side=-1 if np.mean([points[0][0],points[-1][0]])<32 else 1
                    marks=((np.all(pixels==ink,axis=2)|np.all(pixels==tip,axis=2))&
                           (side*u>0)&(abs(u)<(suit.fit.eyes[1]-suit.fit.eyes[0])+1)&(abs(v)<3.5))
                    mask=np.zeros((112,104),dtype=bool)
                    mask[:,:96]=marks
                    parts=silhouette_parts(np.packbits(mask,axis=1,bitorder='little').tobytes())
                    width=marks.any(axis=0).sum()
                    assert len(parts)==1 and 2<=width<=5,(key,n,'eyelid extent',width)
                    half_face=(suit.fit.eyes[1]-suit.fit.eyes[0])*.96
                    margin=half_face-np.max(abs(u[marks]))-.5
                    assert margin>=1.0,(key,n,'eyelid too close to the cheek',margin)
                    widths.append(width);margins.append(margin)
            row+=1
    print(f'15 outfits: closed eyelids {min(widths)}-{max(widths)} native columns; minimum cheek clearance {min(margins):.1f}px.')


def check_intermediate_heads(master,motion,row,action,costume,jaw):
    # Compare opaque facial pixels with whole native expressions. Moving hands
    # are independent joints. Permit integer translation only, never rescaling.
    from bake_yard_sprites import frame as draw_frame
    member='aethe' if costume=='aethe' else next(m for m,keys in KEYS.items() if costume in keys)
    suit=Costume(member,costume)
    left,right,eye=suit.fit.eyes
    # The outer fringe can legitimately be covered by a hand at the temple.
    # Keep both eyes, central fringe, cheeks, mouth and chin inside the check.
    box=(left+14,eye,right+19,suit.fit.chin+14)
    examples=[]
    yy,xx=np.indices((box[3]-box[1],box[2]-box[0]))
    x=xx+box[0]-16;y=yy+box[1]-14
    cheek=(right-left)/2+2
    jaw_width=cheek-(cheek-1.5)*np.clip((y-eye-1)/max(1,suit.fit.chin-eye-1),0,1)
    facial_area=abs(x-(left+right)/2)<=jaw_width
    if action['id']=='tea':
        facial_area &= y<suit.fit.mouth_y  # The raised cup deliberately covers the mouth.
    for mood in suit.rig:
        pose=Motion(suit,'idle',0);pose.mood=mood
        image=np.array(draw_frame(suit,'idle',0,motion=pose).crop(box))
        examples.append((image,(image[:,:,3]>0)&facial_area))
    guides=head_anchors(action,costume);order=(4,0,1,2,3,4)
    for column in range(41):
        segment=min(column//8,4);t=(column-segment*8)/8
        first,last=order[segment:segment+2]
        where=(1-t)*guides[first]+t*guides[last]
        dx=int(round(where[0]-(left+right)/2-16));dy=int(round(where[1]-eye-14))
        actual=motion.crop((column*96,row*112,(column+1)*96,(row+1)*112))
        matched=False
        for oy in sorted(range(dy-12,dy+13),key=lambda v:abs(v-dy)):
            for ox in sorted(range(dx-2,dx+3),key=lambda v:abs(v-dx)):
                sample=np.array(actual.crop((box[0]+ox,box[1]+oy,box[2]+ox,box[3]+oy)))
                if any(np.array_equal(sample[mask],ref[mask]) for ref,mask in examples):
                    matched=True;break
            if matched:break
        assert matched,(costume,action['id'],column,'native facial pixels distorted or covered')


def check_legacy_flow_heads(master,motion,row,action,costume,jaw):
    # Compare the actual packed colours, including transparent holes in hair
    # and halos. A bounding box can pass even when a face folds into stripes.
    guides=head_anchors(action,costume)
    order=(4,0,1,2,3,4)
    y,x=np.indices((112,96),dtype='float32')
    for segment,(first,last) in enumerate(zip(order,order[1:])):
        for i in range(1,STEPS):
            t=i/STEPS
            here=(1-t)*guides[first]+t*guides[last]
            near=first if 2*i<STEPS else last
            dx,dy=x-here[0],y-here[1]
            theta=guides[near][2]-here[2]
            sx=np.floor(guides[near][0]+np.cos(theta)*dx-np.sin(theta)*dy+.5).astype(int).clip(0,95)
            sy=np.floor(guides[near][1]+np.sin(theta)*dx+np.cos(theta)*dy+.5).astype(int).clip(0,111)
            head=(-np.sin(here[2])*dx+np.cos(here[2])*dy)<=jaw+1
            reference=np.frombuffer(cel(master,near,row),dtype=np.uint8).reshape(112,96,4)[sy,sx]
            frame=segment*STEPS+i
            actual=np.frombuffer(cel(motion,frame,row),dtype=np.uint8).reshape(112,96,4)
            assert np.array_equal(reference[head],actual[head]),(costume,action['id'],frame,'head outline or ink drift')


def check_source_art(key,rest):
    native=drawing(key)
    assert rest.crop((16,14,80,104)).tobytes()==native.art.tobytes(),(key,'altered neutral')
    # Independently resize the entire opaque silhouette in a single operation.
    # A pin-by-pin squish or clipped hat/wing can pass the seam tests below.
    source,_,_=source_cell(key)
    alpha=source.getchannel('A').point(lambda value:255 if value>=100 else 0)
    ref=alpha.crop(alpha.getbbox())
    target=rest.getchannel('A');box=target.getbbox();target=target.crop(box)
    assert max(abs(np.array(target.size)-np.array(ref.size)*native.scale))<2,(key,'cropped source bounds')
    mask=np.asarray(ref.resize(target.size,Image.Resampling.BOX))>=128
    live=np.asarray(target)>=128
    overlap=(mask&live).sum()/(mask|live).sum()
    assert overlap>.88,(key,'changed silhouette aspect',overlap)
    return overlap


def check_fuwa_comic():
    # Check the shipped comic after compositing and any scaling. A clean
    # source rig alone cannot catch shifted eye columns in the final close-up.
    comics=ART.parent/'comics'
    sheet=Image.open(comics/'fuwa.png').convert('RGB')
    scenery=Image.open(comics/'source/fuwa.png').convert('RGB')
    lobby=Image.open(ART/'yard/lobby_idle.png').convert('RGBA')
    row=[key for keys in KEYS.values() for key in keys].index('hakuten_fuwa_idle')
    cue=json.loads((comics/'debuts.json').read_text(encoding='utf-8'))['fuwa']['cues'][3]['reveal']
    for cut,feet_x,feet_y in ((0,125,95),(3,107,97)):
        for t in range(24):
            in_library=cut==3 and t>=13
            lid=2 if in_library and t<cue else 1 if in_library and t<cue+2 else 0
            # Halo, ears, fringe, cheeks and chin, including transparent gaps.
            head=lobby.crop((96*lid+28,112*row+20,96*lid+68,112*row+55))
            x,y=feet_x-48+28,feet_y-104+20
            setting=(3 if in_library else 2) if cut==3 else 0
            top=setting*110+y
            expected=scenery.crop((x,top,x+head.width,top+head.height))
            expected.paste(head,(0,0),head)
            left=(t%13)*228+x
            top=(2*cut+t//13)*110+y
            actual=sheet.crop((left,top,left+head.width,top+head.height))
            assert actual.tobytes()==expected.tobytes(),('fuwa comic',cut+1,t+1,'head or eyelids drifted')
    print('Fuwa comic: all 48 frontal cels match the native lobby head and staged eyelids.')


def main():
    from check_comic_faces import check as check_comic_faces
    check_comic_faces()
    check_fuwa_comic()
    check_blinks()
    idle=Image.open(ART/'yard/idle.png').convert('RGBA')
    lobby=Image.open(ART/'yard/lobby_idle.png').convert('RGBA')
    outfits=[key for keys in KEYS.values() for key in keys]
    overlaps=[]
    for row in range(idle.height//112):
        ete_fit=fit_costume('aethe')
        left,right,eye=ete_fit.eyes[0]+16,ete_fit.eyes[1]+16,ete_fit.eyes[2]+14
        if row<len(outfits):
            fit=fit_costume(outfits[row])
            l,r,y=fit.eyes
            left,right,eye=l+16,r+16,y+14
            overlaps.append(check_source_art(outfits[row],idle.crop((0,row*112,96,row*112+112))))
        assert cel(lobby,0,row)==cel(idle,0,row)
        opened=np.frombuffer(cel(lobby,0,row),dtype='uint8').reshape(112,96,4)
        for col in (1,2):
            shut=np.frombuffer(cel(lobby,col,row),dtype='uint8').reshape(112,96,4)
            y,x=np.where(np.any(opened!=shut,axis=2))
            assert len(x) and min(x)>=left-4 and max(x)<=right+4 and min(y)>=eye-4 and max(y)<=eye+4,(row,col,'blink escaped eye band')
            assert np.array_equal(opened[:,:,3],shut[:,:,3]),(row,col,'blink changed silhouette')
    traveler=Image.open(ART/'yard/traveler.png').convert('RGBA')
    overlaps.append(check_source_art('traveler',traveler.crop((0,0,96,112))))
    for n in range(FRAMES):
        x=(n%COLUMNS)*96;y=(1+n//COLUMNS)*112
        check_outline(traveler.crop((x,y,x+96,y+112)).getchannel('A'),'traveler','walk',n)
    path=ART/'interactions'
    body_lengths=[]
    row_index=0
    count=0
    for member,keys in {**KEYS,'aethe':('aethe',)}.items():
        for i,key in enumerate(keys):
            name=member if i==0 else key
            master=Image.open(path/(name+'.png')).convert('RGBA')
            motion=Image.open(path/'motion'/(name+'.png')).convert('RGBA')
            manifest=json.loads((path/(name+'.json')).read_text(encoding='utf-8'))
            actions=manifest['actions']
            jaw=manifest.get('field_face',{}).get('eye_to_chin',JAW)
            for action in actions:
                row=action['row']
                check_intermediate_heads(master,motion,row,action,key,jaw)
                if action.get('kind')=='social':
                    anchors=head_anchors(action,key)
                    for col,(x,y,a) in enumerate(anchors):
                        sole=master.crop((96*col,112*row,96*(col+1),112*(row+1))).getbbox()[3]-1
                        length=sole-(y+jaw*cos(a))
                        assert abs(length-(FOOT-manifest['field_face']['standing_chin']))<=1.51,(key,action['id'],col,length)
                        body_lengths.append(length)
                for col in range(5):
                    assert cel(master,col,row)==cel(motion,(col+1)*8,row),(key,row,col)
                for col in (0,40):
                    assert cel(motion,col,row)==cel(idle,0,row_index),(key,row,'neutral')
                for col in range(41):
                    alpha=motion.crop((96*col,112*row,96*(col+1),112*(row+1))).getchannel('A')
                    if member=='aethe':
                        # Authored wisps, gold ornament and book ribbon can float.
                        # Compare her entire crown against its source above instead.
                        l,t,r,b=alpha.getbbox()
                        assert 0<l<r<96 and 0<t<b<112
                    else: check_outline(alpha,key,action['id'],col)
                count+=1
            row_index+=1
    print(f'{len(overlaps)} neutral outfits/player match source pixels. Independent silhouette overlap: {min(overlaps):.1%} or better.')
    for action in ACTIONS:
        atlas=Image.open(ART/'yard'/(action+'.png')).getchannel('A')
        for row,key in enumerate(outfits):
            for n in range(FRAMES):
                x=(n%COLUMNS)*96
                y=(row*2+n//COLUMNS)*112
                check_outline(atlas.crop((x,y,x+96,y+112)),key,action,n)
    print(f'{len(body_lengths)//5} standing reactions: chin to sole {min(body_lengths):.1f}-{max(body_lengths):.1f}px.')
    print(f'{count} interaction sequences, {count*41} cels, {count*35} rigid head transitions.')
    print(f'{row_index} lobby sprites; all neutral endpoints identical; {len(ACTIONS)*len(outfits)*FRAMES} activity outlines checked.')


if __name__=='__main__': main()
