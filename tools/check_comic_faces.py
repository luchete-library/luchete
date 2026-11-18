"""Compare each shipped comic face with its field drawing at the final panel size."""
from functools import cache
from unittest.mock import patch

import numpy as np
from PIL import Image

import render_dori_comic as comic
from bake_yard_sprites import Motion, frame
from yard_costumes import KEYS as WARDROBE


@cache
def references(name,view):
    if view is None:
        suit=comic.comic_suit(name)
        left,right,eye=suit.fit.eyes
        # Include the fringe, both eye sockets, cheeks and chin.
        box=(16+left-3,14+eye-16,16+right+4,14+suit.fit.chin+1)
        row=[key for keys in WARDROBE.values() for key in keys].index(suit.key)
        lobby=comic.atlas("yard/lobby_idle.png")
        heads=[lobby.crop((col*96+box[0],row*112+box[1],col*96+box[2],row*112+box[3]))
               for col in range(3)]
        for mood in suit.rig.keys()-{"open","half","closed"}:
            m=Motion(suit,"idle",0)
            m.mood=mood
            heads.append(frame(suit,"idle",0,motion=m).crop(box))
        return box,heads
    if name=="aethe":
        sheet=comic.atlas("directional/aethe.png")
        row=("down","left","right","up").index(view)
        columns=range(5)
        from yard_costumes import Costume
        suit=Costume('aethe','aethe')
        box=(22,16,74,suit.fit.shoulder[1]+10)
        offsets=range(-4,5)
    else:
        key=comic.KEYS.get(name,name)
        sheet=comic.atlas(f"directional/{key}.png")
        row=("left","right","up").index(view)
        columns=(0,)
        box=(22,16,74,53)
        # Front registration can change the profile's total height. Trace the
        # lower head bound above the shoulder instead of testing a moving
        # sleeve/collar as facial ink (Yune's new collar starts at row 50).
        from bake_stella_directions import SOURCES, TRACES, registered_pose
        for group,(_,models) in enumerate(SOURCES):
            for index,(costume,_) in enumerate(models):
                if costume==key:
                    _,scale,dy=registered_pose(group,index,0)
                    shoulder=round(TRACES[key][0][1]*scale+dy)
                    box=(*box[:3],min(box[3],shoulder-4))
        offsets=range(-4,5)  # An integer lift of the whole head is fine during a step.
    heads=[sheet.crop((i*96+box[0],row*112+box[1]+dy,i*96+box[2],row*112+box[3]+dy))
           for i in columns for dy in offsets]
    return box,heads


def check():
    front,profile,draw=comic.front,comic.profile,comic.draw_grounded
    actor=None
    samples=[]
    count=0

    def draw_front(im,name,*args,**kwargs):
        nonlocal actor
        actor=(name,None)
        return front(im,name,*args,**kwargs)

    def draw_profile(im,name,x,floor,view,*args,**kwargs):
        nonlocal actor
        actor=(name,view)
        return profile(im,name,x,floor,view,*args,**kwargs)

    def draw_and_measure(im,cel,x,floor,opacity=255,shadow=False,shadow_floor=None):
        box,heads=references(*actor)
        # Hands may appear beside the cheeks. Every opaque pixel of the
        # reference face itself must still match one complete expression.
        actual=np.asarray(cel.crop(box))
        for head in heads:
            pixels=np.asarray(head)
            region=pixels[:,:,3]>0
            if np.array_equal(actual[region],pixels[region]):
                break
        else:
            raise AssertionError((member,cut+1,t+1,actor,'head differs from source'))
        screen=tuple(v+(round(x)-48 if i%2==0 else round(floor)-104) for i,v in enumerate(box))
        expected=im.crop(screen).convert("RGBA")
        ink=head.copy()
        alpha=head.getchannel("A").point(lambda v:v*opacity//255)
        if shadow: ink=Image.new("RGBA",head.size,"#443c50")
        ink.putalpha(alpha)
        expected.alpha_composite(ink)
        if opacity:
            samples.append((screen,np.asarray(expected.convert("RGB")),region))
        draw(im,cel,x,floor,opacity,shadow,shadow_floor=shadow_floor)

    with patch.object(comic,"front",draw_front),patch.object(comic,"profile",draw_profile),patch.object(comic,"draw_grounded",draw_and_measure):
        for member in comic.BOOKS:
            with Image.open(comic.COMICS/(member+".png")) as sheet:
                for cut in range(4):
                    for t in range(comic.FRAMES):
                        samples.clear()
                        panel=comic.render_panel(member,cut,t)
                        x=t%comic.COLUMNS*comic.W
                        y=(cut*comic.ROWS_PER_CUT+t//comic.COLUMNS)*comic.H
                        packed=sheet.crop((x,y,x+comic.W,y+comic.H))
                        assert packed.tobytes()==panel.tobytes(),(member,cut+1,t+1,'stale atlas')
                        for screen,expected,region in samples:
                            face=np.asarray(packed.crop(screen))
                            assert np.array_equal(face[region],expected[region]),(member,cut+1,t+1,'face scaled, covered or misplaced')
                        count+=1
    print(f"Checked {len(comic.BOOKS)} books, {count} packed frames against field faces.")


if __name__=="__main__":
    check()
