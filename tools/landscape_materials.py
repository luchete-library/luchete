"""Skyline silhouettes and near-ground material marks on the native story grid."""
import math
import random

from PIL import ImageColor


def tone(a,b,t):
    a=ImageColor.getrgb(a); b=ImageColor.getrgb(b)
    return tuple(round(i+(j-i)*t) for i,j in zip(a,b))


def horizon(p,member,scene,h,sky,ground):
    rng=random.Random('ridge/'+member)
    snow=member in ('fuwa','kubby')
    night=member=='yune'
    for y in range(h):
        p.r(0,y,p.w,1,tone(sky,'#e0c5a2' if not night else '#bbb1bd',.25*y/h))
    for i in range(11):
        x=rng.randrange(p.w); y=rng.randrange(3,max(4,h//2))
        if night:
            p.r(x,y,1,.5,'#ded0ae')
        else:
            width=rng.randrange(9,38)
            p.l([(x,y+2),(x+width*.3,y+2),(x+width*.4,y),(x+width*.75,y),(x+width,y+1)],tone(sky,'#f0e4c5',.38),1)
    sun_x=p.w*.81;sun_y=h*.28
    for j in range(-5,6):
        dx=(36-j*j)**.5
        p.r(sun_x-dx,sun_y+j,2*dx,1,tone(sky,'#fff0ca',.68))
    for layer in range(2):
        anchors=[(-22,h*.75)]
        while anchors[-1][0]<p.w+18:
            x,v=anchors[-1]
            anchors.append((x+rng.randrange(13,37),rng.uniform(.30,.84)*h+layer*4))
        ridge=[]
        for (x0,y0),(x1,y1) in zip(anchors,anchors[1:]):
            for x in range(x0,x1,2):
                t=(x-x0)/(x1-x0)
                ridge.append((x,round(y0+(y1-y0)*t+rng.choice([-1,0,0,1]))))
        body=tone(sky,ground,.32+layer*.28)
        p.poly([(ridge[0][0],h),*ridge,(ridge[-1][0],h)],body)
        for i in range(1,len(anchors)-1):
            x,y=anchors[i]; prev,nxt=anchors[i-1],anchors[i+1]
            if y>min(prev[1],nxt[1])-5: continue
            p.poly([(x,y+1),(x+3,y+8),(x+1,h),(nxt[0],h),(nxt[0],nxt[1]+1)],tone(sky,ground,.40+layer*.29))
            if snow:
                p.poly([(x-5,y+6),(x,y),(x+6,y+6),(x+2,y+4),(x+1,y+7),(x-1,y+4)],tone(sky,'#fff2db',.55))
    if night:
        for i in range(20):
            x=rng.randrange(3,p.w-3);y=rng.randrange(4,h)
            p.star(x,y,.7,tone(sky,'#faebc5',.5))
    else:
        # Distant treeline follows the ground; irregular crowns avoid a fence effect.
        for x in range(-3,p.w+3,2):
            tall=2+4*(1+math.sin(x*.077+scene*.31))*.5+rng.uniform(0,3)
            p.poly([(x-2,h),(x,h-tall),(x+2,h-2),(x+3,h)],tone(ground,sky,.42))


def ground_marks(p,member,scene,h,ground):
    rng=random.Random(member+str(scene)+'/surface')
    for _ in range(190):
        x=rng.uniform(5,p.w-5);y=rng.uniform(h+2,p.h-5)
        if member in ('yato','garden'):
            for j in range(rng.randrange(2,6)):
                u=x+rng.uniform(-4,4);v=y+rng.uniform(-1,1)
                p.l([(u-1,v),(u-1.5,v-2),(u,v),(u+1,v-3)],tone(ground,'#acc793',rng.uniform(.10,.28)),.5)
        elif member in ('dori','kubby','fuwa'):
            # The exposed face is one step darker than the top; leave open
            # patches of earth or snow between the compact stone clusters.
            w=rng.uniform(2,6); high=rng.uniform(.8,2.5)
            p.poly([(x,y),(x+1,y-high),(x+w,y-high),(x+w+1,y),(x+w-1,y+.7)],tone(ground,'#473b43',.14))
            p.l([(x+.5,y-.5),(x+1,y-high),(x+w-1,y-high)],tone(ground,'#fff1d1',.25),.5)
        elif member=='yune':
            p.l([(x,y),(x+2,y-.5),(x+4,y)],tone(ground,'#b1a8c5',.21),.5)


def garden_shade(p):
    # Broad patches of shade and penumbra under the northern fence and around
    # the pond. Applied to the terrain before paving and plants are laid down.
    for x in range(8,p.w-8,2):
        h=7+2*math.sin(x*.16)
        p.r(x,44,2,h,'#3e5948')
        if int(x-16)%30<4:
            p.poly([(x,43),(x+2,43),(x-3,54),(x-5,54)],'#354f41')


def water(p,x,y,w,h,dream=False):
    rng=random.Random('water'+str(w))
    # Ripples contract toward the far bank. Vary their lengths, not opacity.
    for j in range(round(w*h/50)):
        u=rng.uniform(x+10,x+w-10); v=rng.uniform(y+7,y+h-7)
        length=min(x+w-u-6,rng.uniform(2,7)*(0.55+(v-y)/h))
        if length<=0: continue
        p.l([(u,v),(u+length*.45,v),(u+length*.6,v-.5),(u+length,v-.5)],
            rng.choice(['#7e7899','#9689a7'] if dream else ['#73958f','#5f898a','#769c99']),.5)
    for side in (-1,1):
        for j in range(6):
            u=x+(13+j*3.4 if side==-1 else w-16-j*2.5)
            v=y+h-(5+j%3) if side==-1 else y+6+j%2
            p.l([(u,v),(u-.5,v-2),(u-2,v-4-j%2)],'#5c6961' if not dream else '#77718a',.5)
