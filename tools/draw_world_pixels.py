"""Grid-authored surroundings and fan sprites. Rebuild with the bundled Python.

These plates change scenery, not story events or collision coordinates. Fine
details use a half-unit grid, matching the library's two native pixels per unit.
"""
from pathlib import Path
import json, math, random
from PIL import Image, ImageDraw, ImageColor
from draw_library_pixels import Pixel as LibraryPixel, book, trim
from world_dressing import enrich_plate, make_assets as make_dressing, write_layout
import landscape_materials as materials
import chapter_backdrops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world_pixels'
MANIFEST = {}


class Pixel(LibraryPixel):
    def r(self, x, y, w, h, color):
        # The compact comic camera uses a 1 px grid; half-grid accents become
        # single pixels rather than an inverted/empty Pillow rectangle.
        if w <= 0 or h <= 0:return
        k=self.density;left=round(x*k);top=round(y*k)
        self.d.rectangle((left,top,max(left,round((x+w)*k)-1),max(top,round((y+h)*k)-1)),fill=self.c(color))


def mix(a, b, t):
    a, b = ImageColor.getrgb(a), ImageColor.getrgb(b)
    return '#%02x%02x%02x' % tuple(round(x+(y-x)*t) for x,y in zip(a,b))


def save(p, name, anchor=(0,0)):
    p.im.save(OUT/(name+'.png'))
    MANIFEST[name] = dict(size=[p.w,p.h], native_size=list(p.im.size), anchor=list(anchor), density=p.density)
    return p


def ellipse(p, box, color):
    p.d.ellipse(tuple(round(v*p.density) for v in box),fill=p.c(color))


def grain(p, box, base, seed, count, wood=False):
    rng=random.Random(seed)
    x,y,w,h=box
    for _ in range(count):
        px=round(rng.uniform(x,x+w)*2)/2; py=round(rng.uniform(y,y+h)*2)/2
        length=rng.choice([1,1.5,2.5,4] if wood else [.5,1,1.5,2])
        p.r(px,py,min(length,x+w-px),.5,mix(base,'#fff0ca' if rng.random()<.55 else '#202934',.12))


def tree(snow=False):
    p=Pixel(60,72)
    ellipse(p,(10,62,50,70),'#263e3b')
    p.poly([(22,67),(25,55),(25,31),(34,29),(34,56),(39,66),(32,65),(29,69),(27,64)],'wood0')
    p.r(27,34,5,29,'wood2');p.r(27,35,1,24,'wood4')
    p.l([(29,60),(31,52),(29,46),(30,36)],'wood1',.5)
    p.l([(26,49),(18,39),(17,31)],'wood2',2)
    p.l([(32,45),(41,36),(43,28)],'wood1',2)
    tones=['#304e46','#456b52','#5b805e','#7b9b6e','#a5b484'] if not snow else ['#657d86','#859fa4','#b1c8cb','#d5e4df','#f0eee0']
    # Overlapping clusters have a continuous silhouette, with lit upper-left rims.
    clusters=[(15,34,13),(41,35,15),(28,39,18),(12,23,10),(44,23,10),(25,20,18),(32,10,10)]
    for j,(x,y,r) in enumerate(clusters):
        pts=[(x-r,y+5),(x-r,y-3),(x-r+5,y-r+3),(x-4,y-r),(x+5,y-r),(x+r,y-6),(x+r+1,y+3),(x+r-5,y+10),(x-4,y+r-1)]
        p.poly(pts,tones[0]);p.poly([(a,b-1) for a,b in pts[1:-1]]+[(x,y+10),(x-r+2,y+5)],tones[1+j%2])
        p.l([(x-r+4,y-4),(x-r+7,y-r+5),(x-4,y-r+2),(x+3,y-r+2)],tones[3],1)
        for n in range(10):
            lx=x-r+6+(n*7+j*5)%(max(1,r*2-9));ly=y-r+6+(n*5+j*3)%max(1,r+5)
            p.l([(lx,ly+1),(lx+1.5,ly),(lx+3,ly)],tones[2+n%3],.5)
    if not snow:
        for x,y in [(12,28),(39,17),(27,34),(45,39)]:
            p.r(x,y,2,2,'gold');p.r(x,y,.5,.5,'paperhi')
    return p


def cottage():
    p=Pixel(70,59)
    p.r(6,26,58,32,'wood0');p.r(8,27,54,28,'#d0b89c')
    p.r(8,29,54,3,'#ac9079');p.r(8,51,54,4,'#a18c7b')
    p.poly([(1,28),(34,3),(68,27),(66,31),(4,31)],'#493c49')
    p.poly([(4,27),(34,5),(65,27)],'#746574')
    for row in range(5):
        y=10+row*4; left=34-(y-5)*1.4; right=34+(y-5)*1.4
        p.l([(left,y),(right,y)],'#a68c8a',.5)
        for x in range(12+row%2*4,59,8):
            if left+1<x<right-1:p.l([(x,y-2),(x-2,y)],'#544958',.5)
    p.r(3,28,64,2,'#d7ad81');p.r(5,30,60,1,'#9b725c')
    p.r(13,3,7,13,'wood1');p.r(12,2,9,3,'wood3');p.r(14,6,3,.5,'wood4')
    for x in [9,58]:p.r(x,31,3,21,'wood1');p.r(x+.5,31,.5,20,'wood3')
    p.r(28,34,15,22,'wood0');p.r(30,35,11,20,'wood1')
    for x in [31,34,37,40]:p.r(x,36,.5,18,'wood3')
    p.r(29,36,12,2,'wood2');p.r(29,48,12,2,'wood2');p.r(38,44,1.5,1.5,'goldhi')
    for x in [15,47]:
        p.r(x-1,35,11,12,'wood0');p.r(x,36,9,9,'blue1')
        p.r(x+.5,36.5,8,3,'blue2');p.l([(x+1,42),(x+5,38)],'paperlo',.5)
        p.r(x+4,35,1,11,'wood1');p.r(x,40,9,1,'wood1')
        p.r(x-2,46,13,2,'wood3');p.r(x-2,45.5,13,.5,'wood4')
    for y in [32,40,49]:
        for x in [24,44]:p.r(x,y,2,.5,'#ac9079')
    p.r(26,55,19,3,'#a7a396');p.r(25,58,21,1,'#ddd4b8')
    return p


def bench():
    p=Pixel(65,35)
    for x in [8,54]:
        p.r(x,16,4,17,'wood0');p.r(x+1,17,1,13,'wood3')
    p.r(9,25,47,3,'wood1');p.r(10,25,45,.5,'wood3')
    p.poly([(4,6),(57,6),(63,14),(2,14)],'wood4')
    p.r(2,14,61,5,'wood0');p.r(3,14,59,2,'wood2');p.r(4,14,57,.5,'wood4')
    grain(p,(5,8,53,5),'#b88a60',84,32,True)
    p.r(9,8,15,5,'paperlo');p.r(10,7,14,5,'paper')
    for y in [8.5,10]:p.r(12,y,8,.5,'wood2')
    p.r(48,8,4,4,'blue0');p.r(48.5,8,3,.5,'blue2')
    p.l([(50,9),(55,2)],'paperhi',1)
    return p


def pond(p,x,y,w,h,dream=False):
    border='#81768d' if dream else '#777f6e'; edge='#b8a8b8' if dream else '#b4b79a'
    p.poly([(x+10,y),(x+w-12,y),(x+w,y+9),(x+w,y+h-8),(x+w-12,y+h),(x+8,y+h),(x,y+h-9),(x,y+10)],border)
    p.poly([(x+12,y+4),(x+w-13,y+4),(x+w-5,y+12),(x+w-5,y+h-10),(x+w-14,y+h-4),(x+11,y+h-4),(x+5,y+h-12),(x+5,y+12)],'#484865' if dream else '#2d5660')
    p.r(x+12,y+12,w-24,h-24,'#655e86' if dream else '#477d83')
    materials.water(p,x,y,w,h,dream)
    for i in range(17):
        xx=x+12+(i*17)%max(1,int(w-31));yy=y+11+(i*13)%max(1,int(h-22))
        p.r(xx,yy,3+i%7,.5,'#a69bbd' if dream else '#81aa9f')
    for xx in range(round(x+10),round(x+w-7),10):
        p.l([(xx,y+1),(xx+6,y+1),(xx+8,y+3)],edge,.5)
        p.l([(xx+2,y+h-4),(xx+8,y+h-4)],edge,.5)
        p.r(xx,y+h-3,.5,2,'#535d59')
    if not dream:
        for xx,yy in [(x+17,y+15),(x+w-28,y+h-17)]:
            ellipse(p,(xx-4,yy-2,xx+4,yy+2),'#65866a');p.l([(xx,yy),(xx+3,yy-1)],'#b3c189',.5)
            p.r(xx,yy-2,2,1,'#e0b5a4');p.r(xx+.5,yy-2.5,1,.5,'paperhi')
        for xx in [x+6,x+w-6]:
            p.l([(xx,y+h-6),(xx-2,y+h-18)],'#577354',1)
            p.l([(xx,y+h-7),(xx+3,y+h-14)],'#8b9b69',1)


PALETTES={
    'yato':('#b1c1aa','#53694e'), 'danming':('#b1948c','#94745f'),
    'kubby':('#68758d','#777b80'), 'yune':('#666080','#625877'),
    'dori':('#c5ada0','#948276'), 'fuwa':('#a1b6c4','#c9d8da'),
}


def scenery(member,scene=0,w=452,h=289,density=2,comic=False):
    """Plate without story actors; camera framing is explicit, never stretches bodies."""
    p=Pixel(w,h,density);sky,ground=PALETTES[member]
    indoor=member=='danming' or (member=='dori' and scene==3) or (comic and member=='fuwa' and scene==3)
    library=(member=='dori' or (comic and scene==3)) and indoor
    if member=='yune' and scene>=2:
        sky=mix(sky,'#242638',.58);ground=mix(ground,'#252737',.4)
    horizon=round(h*(.62 if comic else .215))
    p.r(0,0,w,h,'#2d3b3b');p.r(7 if not comic else 0,7 if not comic else 0,w-14 if not comic else w,h-14 if not comic else h,sky)
    if indoor:
        p.r(0,0,w,horizon,'#51413f' if library else '#69555c')
        bays=5 if comic else 8
        bw=w/bays
        for i in range(bays):
            x=round(i*bw+5);width=round(bw-10)
            if library:
                p.r(x,4,width,horizon-8,'wood0')
                rng=random.Random(i)
                for yy in range(8,horizon-8,18):
                    for xx in range(x+3,x+width-5,5):book(p,xx,yy,4,10+rng.randrange(4),rng.choice(['green1','blue1','rose1','purple1']))
                    p.r(x,yy+14,width,2,'wood3');p.r(x,yy+14,width,.5,'wood4')
            else:
                trim(p,x,10,width,horizon-18)
                p.r(x+4,14,width-8,horizon-27,'#b9a0a0')
                for yy in range(15,horizon-13,7):p.r(x+4,yy,width-8,1,'#d6b7a2')
                p.r(x+width/2,13,2,horizon-25,'wood1')
                p.l([(x+5,horizon-18),(x+width-7,17)],'#f0cda9',.5)
            p.r(x-4,2,2,horizon,'wood0');p.r(x-3,3,.5,horizon-4,'wood3')
        p.r(0,horizon-3,w,4,'wood0');p.r(0,horizon-3,w,1,'wood3')
        p.r(0,horizon+1,w,h-horizon-1,ground)
        for yy in range(horizon+2,h,12):
            p.r(0,yy,w,.5,mix(ground,'#382f36',.30));p.r(0,yy+.5,w,.5,mix(ground,'#e9c49b',.15))
            for xx in range(-(yy%4)*14,w,47):
                p.r(xx,yy, .5,11,mix(ground,'#382f36',.25))
                p.r(xx+2,yy+2,.5,.5,'wood0');p.r(xx+44,yy+9,.5,.5,'wood0')
        grain(p,(2,horizon+3,w-4,h-horizon-7),ground,member+str(scene),round(w*h/300),True)
    else:
        # Three discrete sky bands and two mountain layers, not a blurred gradient.
        for j in range(3):p.r(0,j*horizon/3,w,horizon/3+1,mix(sky,'#f2e2b7',j*.045))
        ellipse(p,(w*.81-10,12,w*.81+10,32),mix(sky,'#f6e2b3',.7))
        for layer in range(2):
            tone=mix(sky,ground,.24+layer*.17)
            for j in range(10):
                x=j*w/8-24; peak=round(19+(j*17+layer*7)%max(10,horizon-27))
                p.poly([(x,horizon+7),(x+26,peak),(x+57,horizon+7)],tone)
                if member in ['kubby','fuwa']:
                    p.poly([(x+17,peak+12),(x+26,peak),(x+35,peak+12),(x+28,peak+9),(x+25,peak+13)],mix(tone,'#eef0df',.65))
        p.r(0,horizon,w,h-horizon,ground)
        # Irregular patches make the large walkable floor readable without visual noise.
        rng=random.Random(member+str(scene))
        for j in range(22 if not comic else 8):
            x=rng.randrange(w);y=rng.randrange(horizon+3,h-7);rw=rng.randrange(6,26)
            p.poly([(x,y),(x+rw,y-1),(x+rw+7,y+2),(x+rw,y+5),(x-6,y+4)],mix(ground,sky,.11))
        grain(p,(5,horizon+4,w-10,h-horizon-9),ground,member,round(w*h/210))
        if member in ['dori','kubby'] or (member=='yato' and scene>=2):
            for yy in range(horizon+8,h,16):
                for xx in range(7+(yy//16%2)*17,w-10,34):
                    if (xx*3+yy)%7<3:
                        p.l([(xx,yy),(xx+12,yy),(xx+14,yy+1)],mix(ground,'#d9c3a0',.24),.5)
                        p.l([(xx+15,yy+2),(xx+13,yy+5),(xx+5,yy+5)],mix(ground,'#303947',.15),.5)
        elif member=='fuwa':
            for j in range(18):
                x=13+j*59%(w-25);y=horizon+10+j*37%(h-horizon-20)
                p.l([(x-5,y+2),(x,y),(x+13,y),(x+17,y+1)],'#e5e9df',.5)
                p.r(x-3,y+3,18,.5,'#afc1c9')
        elif member=='yato':
            for j in range(75 if not comic else 20):
                x=6+j*37%(w-12);y=horizon+4+j*47%(h-horizon-10)
                p.l([(x-1,y),(x-2,y-2),(x,y),(x+1,y-3)],mix(ground,'#c3c396',.35),.5)
        elif member=='yune':
            for j in range(20):
                x=12+j*61%(w-24);y=horizon+8+j*37%(h-horizon-14)
                p.star(x,y,1,mix(ground,'#e3d3b4',.4))
        if comic:
            if member in ['dori','kubby'] and (member=='dori' or scene<2) or member=='yato' and scene>=2:
                house=cottage()
                for x in [-14,62,w-73]:p.paste(house.im.resize((70*density,59*density),Image.Resampling.NEAREST),x,horizon-53)
            if member=='yato':
                tr=tree()
                for x in [-25,w-31]:p.paste(tr.im.resize((60*density,72*density),Image.Resampling.NEAREST),x,horizon-60)
            if member=='fuwa' and scene==0:
                for x in [23,56]:p.r(x,35,4,35,'#8b5a56');p.r(x,35,1,32,'#d09b84')
                p.r(17,31,49,5,'#694d53');p.r(19,31,45,1,'#c89c86');p.r(20,40,44,3,'#ac776b')
    if not comic:
        if not indoor:
            materials.horizon(p,member,scene,horizon,sky,ground)
            materials.ground_marks(p,member,scene,horizon,ground)
        else:
            # Low raking light between the desk bays.
            for bay in range(1,8):
                x=bay*w/8
                for stripe in (0,5):
                    p.poly([(x+stripe,horizon+2),(x+stripe+3,horizon+2),(x+stripe-5,horizon+18),(x+stripe-10,horizon+18)],mix(ground,'#f5d2a1',.20))
        enrich_plate(p,'danming' if member=='dori' and scene==3 else member,scene)
        p.r(0,0,w,4,'#303a3c');p.r(0,h-4,w,4,'#303a3c');p.r(0,0,4,h,'#303a3c');p.r(w-4,0,4,h,'#303a3c')
        p.l([(4,h-5),(4,4),(w-5,4)],mix(sky,'#ebe0ba',.20),.5)
    return p


def garden():
    p=Pixel(452,289);p.r(0,0,452,289,'#253e36');p.r(7,7,438,276,'#42624e')
    # Soft, low-contrast moss islands, detailed only near edges and landmarks.
    for j in range(44):
        x=10+j*73%428;y=12+j*47%263
        p.poly([(x,y),(x+13,y-2),(x+24,y+2),(x+21,y+6),(x-4,y+7)],'#486950')
    grain(p,(9,9,431,269),'#42624e',552,610)
    materials.garden_shade(p)
    materials.ground_marks(p,'garden',0,7,'#42624e')
    for j in range(100):
        x=9+j*137%430;y=13+j*89%264
        p.l([(x-1,y),(x-2,y-2),(x,y),(x+1,y-3),(x+1,y)],'#719063',.5)
        if j%4==0:p.r(x,y-3,1,1,'#d3c499');p.r(x+.5,y-3.5,.5,.5,'paperhi')
    for i in range(23):
        x=(130+i*31-32)/2;y=(560-math.sin(i*.2)*100-140)/2
        p.poly([(x+2,y),(x+16,y),(x+19,y+3),(x+18,y+14),(x+2,y+16),(x-1,y+12)],'#68725a')
        p.poly([(x+2,y),(x+16,y),(x+18,y+3),(x+17,y+12),(x+3,y+14),(x,y+11)],'#b4ac88')
        p.l([(x+2,y+1),(x+15,y+1),(x+17,y+3)],'#d6cba3',.5)
        p.l([(x+3,y+13),(x+16,y+11)],'#89896f',.5)
        p.l([(x+8,y+1),(x+7,y+4),(x+10,y+6)],'#96977b',.5)
        p.r(x+4,y+9,3,.5,'#c9bf99')
    pond(p,184,87.5,96,60)
    for x in range(16,434,30):
        p.r(x,23.5,4,23,'wood0');p.poly([(x,24),(x+2,21),(x+4,24)],'wood3')
        p.r(x+.5,24,2.5,20,'wood2');p.r(x+.5,24,.5,20,'wood4')
        for y in [28,38]:
            p.r(x+2,y,29,3,'wood1');p.r(x+2,y,29,.5,'wood4')
            p.r(x+3,y+1,.5,.5,'wood0')
    enrich_plate(p,'garden')
    p.r(5,282,442,2,'#657554');p.r(5,5,442,1,'#657554')
    return p


def fan_sprites():
    from draw_fan_pixels import build, frame_image, IDS, ANCHOR, SIZE
    build(update_world=False)
    for member in IDS:
        p=Pixel(SIZE,SIZE,density=1);p.im=frame_image(member,0)
        save(p,'fan_'+member,ANCHOR)


def prop(kind):
    p=Pixel(40,48);ink='wood0';paper='paperhi'
    if kind in ['notice','card','charm']:
        if kind=='notice':
            p.r(18,29,4,16,'wood0');p.r(19,30,1,14,'wood3');trim(p,6,6,28,30)
        p.poly([(10,8),(29,8),(31,11),(30,33),(10,34)],'paperlo')
        p.r(11,9,18,23,'paper');p.r(12,9,17,.5,paper)
        for i in range(4):p.r(14,14+i*3,11-i%3*2,.5,'wood2')
        p.r(24,26,4,4,'rose1');p.r(24.5,26.5,3,.5,'rose2')
        if kind=='charm':p.l([(19,9),(19,4),(23,4),(23,7)],'rose1',.5)
    elif kind=='stone':
        p.poly([(3,33),(7,22),(17,16),(28,18),(36,29),(34,37),(9,38)],'#574b5c')
        p.poly([(5,32),(9,23),(17,18),(27,20),(34,29),(31,35),(10,36)],'#a195a0')
        p.poly([(9,23),(17,18),(27,20),(19,24),(12,24)],'#d1c2b8')
        p.poly([(19,34),(27,28),(33,28),(32,34),(24,36)],'#796c81')
        p.l([(11,28),(14,29),(16,28)],'#554956',.5);p.l([(23,28),(26,29),(28,28)],'#554956',.5)
        p.r(19,31,2,.5,'#795f71')
        for x,y in [(7,30),(18,20),(29,24),(24,34)]:p.r(x,y,1,.5,'#b7a8b4')
    elif kind in ['sack','satchel']:
        p.d.arc((24,22,57,56),180,360,fill=p.c('wood0'),width=4)
        p.poly([(8,19),(31,19),(34,36),(29,40),(11,40),(6,36)],'wood0')
        p.r(9,21,22,17,'wood2');p.r(10,22,20,13,'wood3')
        p.poly([(8,18),(31,18),(30,25),(22,28),(17,28),(9,24)],'wood1')
        p.l([(9,19),(29,19),(29,23),(22,26)],'wood4',.5)
        p.r(19,23,4,7,'gold');p.r(20,24,2,3,'wood0')
        for x in range(12,29,2):p.r(x,36,.5,.5,'paperlo')
    elif kind in ['library_door','shutter']:
        trim(p,7,3,27,40);p.r(10,7,21,33,'green0')
        for x in [11,22]:
            p.r(x,8,8,30,'green1');p.r(x+1,9,6,12,'blue1');p.l([(x+1,16),(x+6,11)],'blue2',.5)
            p.r(x+1,24,6,11,'green2');p.r(x+1,24,6,.5,'greenhi')
        p.r(19,6,2,35,'gold');p.r(17,23,1,2,'goldhi');p.r(23,23,1,2,'goldhi')
        if kind=='library_door':p.star(20,13,4,'goldhi')
        p.r(5,42,31,2,'paperlo');p.r(6,42,29,.5,'paperhi')
    elif kind in ['ring','chime']:
        p.l([(20,0),(20,8)],'gold',.5)
        ellipse(p,(8,8,32,32),'wood0');ellipse(p,(9,9,31,31),'gold');ellipse(p,(10,10,30,30),'purple0')
        p.l([(20,11),(29,24),(12,17),(28,17),(13,26),(20,11)],'purple2',.5)
        p.l([(12,15),(20,29),(28,14),(11,24),(29,24)],'paperlo',.5)
        for x in [12,20,28]:
            end=41-abs(20-x)/2;p.l([(x,31),(x,end)],'gold',.5)
            p.poly([(x,end-2),(x+2,end),(x+1,end+5),(x-2,end+2)],'purple2')
            p.l([(x,end),(x,end+3)],'paperhi',.5)
        # Braided hoop, tiny knots and feather barbs on the same native grid.
        # Keep the centre open so the crossing threads read individually.
        for i in range(24):
            a=2*math.pi*i/24
            x=20+10.9*math.cos(a);y=20+10.9*math.sin(a)
            p.l([(x-.4,y-.5),(x+.5,y+.3)],'goldhi' if i<13 else 'gold0',.5)
        for x,y in [(20,12),(28,17),(27,24),(20,28),(13,24),(12,17)]:
            p.r(x-.5,y-.5,1,1,'gold');p.r(x-.5,y-.5,.5,.5,'paperhi')
        p.r(19,19,2,2,'gold0');p.r(19,19,1.5,1,'goldhi')
        for x in [12,20,28]:
            end=41-abs(20-x)/2
            p.r(x-.5,32,1,1.5,'goldhi')
            for n in range(3):
                p.l([(x-1,end+n),(x,end+n+1),(x+1,end+n)],'purple1',.5)
            p.r(x-.5,end-1.5,1,1,'paperhi')
    elif kind=='lens':
        p.l([(22,26),(33,38)],'wood0',5);p.l([(23,27),(32,37)],'wood3',2)
        ellipse(p,(4,7,28,31),'wood0');ellipse(p,(5,8,27,30),'gold');ellipse(p,(7,10,25,28),'blue0');ellipse(p,(8,11,24,27),'blue2')
        p.poly([(9,20),(18,11),(22,13),(11,24)],'#c5ddcd');p.l([(11,14),(16,12)],'paperhi',.5)
        p.l([(9,26),(16,28),(23,24)],'blue1',.5)
    elif kind=='gate':
        for x in [8,28]:
            p.r(x,11,4,32,'wood0');p.r(x+1,13,2,28,'rose1');p.r(x+1,13,.5,27,'rose2');p.r(x-1,40,6,3,'wood0')
        p.poly([(2,8),(7,10),(33,10),(38,8),(36,13),(4,13)],'wood0')
        p.r(5,10,30,1,'rose2');p.r(6,18,28,3,'rose1');p.r(6,18,28,.5,'gold')
        p.l([(10,21),(20,25),(30,21)],'paperlo',1)
        for x in [14,23]:p.poly([(x,23),(x+2,24),(x+1,28),(x+3,29),(x+1,31),(x-1,27)],'paperhi')
    elif kind in ['bell','lantern','ember']:
        if kind=='bell':
            p.l([(20,3),(20,11)],'wood1',2);ellipse(p,(11,10,29,30),'gold0');ellipse(p,(12,11,28,29),'gold')
            p.r(10,26,20,4,'gold0');p.r(11,26,18,1,'goldhi');p.r(18,30,4,3,'wood1');p.r(14,16,1,8,'goldhi')
        else:
            if kind=='lantern':
                p.l([(16,10),(16,5),(24,5),(24,10)],'gold0',1)
                trim(p,8,10,24,31);p.r(11,14,18,23,'blue0')
            p.poly([(13,34),(11,27),(17,19),(19,12),(24,23),(27,19),(30,29),(26,36)],'green2')
            p.poly([(15,31),(18,23),(21,26),(23,21),(26,31),(23,35),(18,35)],'#9dd5b3')
            p.poly([(18,31),(21,27),(23,32),(21,35)],'paperhi')
    elif kind in ['glow','rift','nightmare']:
        if kind=='nightmare':
            for i in range(4):
                x=7+i*7;p.l([(x,7),(x+5,16),(x-2,25),(x+3,37)],'purple0',3)
                p.l([(x,8),(x+3,16),(x-1,25)],'purple1',.5)
            p.r(20,22,2,1,'rose2')
        else:
            p.poly([(20,3),(27,19),(24,28),(20,43),(13,26),(16,17)],'purple1')
            p.poly([(20,7),(24,20),(21,35),(18,28),(18,17)],'gold')
            p.l([(20,10),(21,22),(20,34)],'paperhi',1)
            for x,y in [(8,14),(32,27),(10,33)]:p.star(x,y,2,'paperlo')
    elif kind in ['arrows','quill']:
        if kind=='arrows':
            for x,y in [(6,38),(13,39),(20,37)]:
                p.l([(x,y),(x+13,y-27)],'wood0',1.5);p.l([(x,y-1),(x+12,y-26)],'gold',.5)
                p.poly([(x+9,y-27),(x+11,y-30),(x+14,y-29),(x+16,y-30),(x+17,y-27),(x+13,y-23)],'rose1')
                p.l([(x-2,y-2),(x+3,y-6)],'paperhi',2)
        else:
            p.poly([(9,37),(12,21),(25,6),(32,4),(30,13),(21,27)],'green1')
            p.poly([(12,32),(16,20),(28,7),(28,14),(21,26)],'greenhi')
            p.l([(7,40),(27,10)],'paperlo',1)
            for j in range(5):p.l([(14+j*2,29-j*3),(20+j*2,24-j*3)],'green2',.5)
    elif kind=='boot':
        p.poly([(10,12),(24,12),(23,27),(33,31),(34,38),(8,38)],'wood0')
        p.poly([(12,14),(22,14),(21,29),(30,32),(31,36),(10,36)],'wood2')
        p.r(11,15,11,3,'wood4');p.r(10,36,23,2,'paperlo')
        for y in [21,24,27]:p.l([(17,y),(21,y+1)],'gold',.5)
        p.r(12,19,1,12,'wood3')
    elif kind=='hamster':
        for x in [10,25]:ellipse(p,(x-3,13,x+5,22),'wood0');ellipse(p,(x-2,14,x+4,21),'rose2')
        ellipse(p,(6,18,34,39),'wood1');ellipse(p,(7,18,33,37),'wood3');ellipse(p,(11,24,29,37),'paper')
        for x in [13,25]:p.r(x,24,1.5,2.5,'wood0');p.r(x,24,.5,.5,'paperhi')
        p.r(19,29,2,1,'rose1');p.r(10,29,3,1,'rose2');p.r(27,29,3,1,'rose2')
        p.r(10,37,5,2,'wood2');p.r(26,37,5,2,'wood2')
    elif kind=='paw':
        for x,y in [(9,32),(20,22),(29,12)]:
            ellipse(p,(x-3,y,x+3,y+4),'blue1')
            for dx in [-3,0,3]:ellipse(p,(x+dx-1,y-3,x+dx,y-1),'blue1')
    return p


def bookmark(member,step=0):
    # Paper role figures are deliberately distinct from the library mascots.
    p=Pixel(42,56);accent={'yato':'#d9a564','danming':'#ca8394','kubby':'#87bda0','yune':'#a995c8','dori':'#c19d87','fuwa':'#97bdcd','traveler':'#a8bba2'}[member]
    trim=mix(accent,'#493c52',.36)
    for x,dy in [(14,step),(24,-step)]:
        p.r(x,47,5,6+dy,'wood0');p.r(x+.5,48,3,3+dy,'wood2');p.r(x-1,52+dy,6,1,'wood0');p.r(x,52+dy,3,.5,'wood4')
    p.poly([(13,32),(29,32),(32,47),(26,48),(22,46),(18,49),(11,47)],'wood0')
    p.poly([(14,34),(28,34),(30,46),(25,46),(21,44),(18,47),(13,46)],trim)
    p.r(16,34,10,9,accent);p.r(16,34,1,9,mix(accent,'#fff0ca',.4))
    p.l([(19,35),(21,38),(24,35)],'paperhi',1);p.r(21,39,1,2,'goldhi')
    for x in [10,29]:
        swing=step*(1 if x==10 else -1) if member=='traveler' else 0
        p.r(x,35,4,8+swing,trim);p.r(x+.5,40+swing,3,3,'paperlo');p.r(x+.5,40+swing,2,1,'paperhi')
    p.poly([(12,15),(29,15),(33,20),(32,29),(28,33),(14,33),(10,29),(10,20)],'wood0')
    p.poly([(13,17),(28,17),(31,21),(30,29),(27,31),(15,31),(12,28),(12,21)],'#edc6a0' if member=='traveler' else 'paper')
    p.l([(13,21),(14,18),(27,18)],'paperhi',1)
    p.r(16,23,2,3,'wood0');p.r(25,23,2,3,'wood0');p.r(16,23,.5,.5,'paperhi');p.r(25,23,.5,.5,'paperhi')
    p.r(14,27,3,.5,'rose2');p.r(27,27,3,.5,'rose2');p.r(21,28,2,.5,'wood2')
    if member=='traveler':
        p.poly([(11,19),(14,16),(29,16),(31,20),(27,23),(24,20),(20,21),(18,20),(13,24)],'wood1')
        p.r(10,21,3,11,'wood1');p.r(29,21,3,11,'wood1');p.r(11,22,.5,8,'wood3');p.r(29,24,.5,6,'wood3')
        p.r(10,14,23,4,'gold0');p.r(11,14,21,2,'gold');p.r(15,7,13,8,'gold');p.r(16,8,11,1,'goldhi');p.r(15,12,13,2,'wood2')
        for x in range(17,27,2):p.r(x,10,.5,.5,'gold0')
        p.r(18,37,8,9,'paperlo');p.r(19,38,6,6,'paper');p.r(23,41,1,1,'wood3')
        p.l([(14,35),(28,44)],'wood2',1);p.r(27,42,5,5,'wood1');p.r(27,42,5,1,'wood3');p.r(29,44,1,1,'gold')
    elif member=='yato':
        p.poly([(10,19),(15,10),(24,7),(30,19)],'wood0');p.poly([(12,18),(17,11),(24,9),(28,18)],'#da9654')
        p.r(23,4,2,6,'green1');p.r(25,4,4,2,'green2');p.l([(16,14),(20,14)],'goldhi',.5)
        p.r(24,35,10,7,'paperlo');p.r(25,35,7,6,'paperhi');p.r(29,35,1,7,'gold')
    elif member=='danming':
        p.r(10,15,23,4,'rose0');p.r(14,10,15,6,'rose1');p.r(15,11,13,1,'rose2');p.star(26,15,2,'goldhi')
        p.r(18,37,13,8,'paperlo');p.r(19,37,11,7,'paperhi');p.l([(19,38),(25,42),(30,38)],'rose1',.5)
    elif member=='kubby':
        for x in [12,25]:ellipse(p,(x,9,x+6,17),trim);ellipse(p,(x+1,10,x+5,15),'rose2')
        p.r(12,16,19,2,accent);p.r(30,38,6,9,'wood0');p.r(31,40,4,5,'gold');p.r(32,40,1,4,'paperhi')
    elif member=='yune':
        for x,y in [(12,17),(18,14),(25,17)]:ellipse(p,(x-2,y-5,x+8,y+3),'purple1');ellipse(p,(x-1,y-5,x+7,y+1),'purple2')
        p.l([(29,39),(35,31)],'gold',1);ellipse(p,(31,27,38,34),'gold');ellipse(p,(32,28,37,33),'purple0')
    elif member=='dori':
        p.r(10,16,23,3,'wood0');p.r(14,9,15,8,'wood1');p.r(15,10,13,4,accent);p.r(20,7,4,3,'wood0')
        p.l([(29,42),(35,35)],'wood1',2);ellipse(p,(30,28,39,37),'gold0');ellipse(p,(31,29,38,36),'blue2');p.l([(32,33),(35,30)],'paperhi',.5)
    else:
        for x in [12,25]:p.poly([(x,18),(x+1,6),(x+7,17)],'blue0');p.poly([(x+1,16),(x+2,9),(x+5,16)],'paperhi')
        p.r(19,36,9,12,'paperhi');p.r(22,38,1,7,'rose1');p.r(20,40,5,1,'rose1')
    return p


def small_scenery():
    bed=Pixel(66,34)
    for x in [4,57]:bed.r(x,22,3,10,'wood0');bed.r(x+.5,23,1,7,'wood3')
    bed.r(3,19,58,8,'wood0');bed.r(4,20,56,4,'wood2');bed.r(4,20,56,.5,'wood4')
    bed.r(5,12,54,9,'purple0');bed.r(7,11,18,10,'paperlo');bed.r(8,12,16,7,'paperhi')
    # Anonymous sleeping child already present in the scene; no new story actor.
    bed.poly([(15,8),(23,7),(27,11),(26,17),(22,20),(16,18),(13,14)],'wood1')
    bed.poly([(17,11),(25,11),(25,16),(22,18),(17,17)],'#e0b49b')
    bed.l([(21,14),(24,14)],'wood0',.5)
    bed.poly([(28,10),(53,12),(57,17),(57,22),(27,22)],'purple1')
    bed.poly([(28,10),(52,12),(55,17),(27,17)],'purple2')
    bed.r(28,17,28,1,'paperlo');bed.l([(32,12),(34,15),(33,20)],'#9989a9',.5)
    for x in range(30,55,4):bed.r(x,20,.5,.5,'paperlo')
    save(bed,'dream_bed',(33,28))
    bush=Pixel(36,24)
    for x,y,r in [(9,14,8),(24,15,10),(18,9,9)]:
        bush.poly([(x-r,y+4),(x-r,y-2),(x-3,y-r),(x+3,y-r),(x+r,y-2),(x+r,y+4),(x+4,y+r),(x-4,y+r)],'green0')
        bush.poly([(x-r+2,y),(x-3,y-r+1),(x+3,y-r+1),(x+r-1,y),(x+2,y+5)],'green1')
        bush.l([(x-r+3,y-1),(x-3,y-r+3),(x+2,y-r+3)],'green2',.5)
        for n in range(5):bush.r(x-4+n*2,y-2+n%3,1,.5,'green3')
    save(bush,'bush',(18,23))
    burrow=Pixel(48,32)
    burrow.poly([(2,27),(4,15),(13,5),(29,3),(40,9),(46,25),(44,30),(5,30)],'green0')
    burrow.poly([(4,23),(6,15),(14,7),(29,5),(38,11),(43,24)],'green1')
    burrow.l([(7,16),(15,8),(26,7),(33,9)],'green3',1)
    ellipse(burrow,(14,14,35,35),'wood0');burrow.r(13,29,24,3,'#53694e')
    burrow.l([(14,28),(15,20),(20,16),(27,16),(31,20)],'wood1',1)
    for x,y in [(7,25),(12,10),(34,12),(38,24)]:burrow.l([(x,y),(x+1,y-2),(x+2,y)],'green2',.5)
    save(burrow,'burrow',(24,30))
    rabbit=Pixel(22,26)
    ellipse(rabbit,(2,13,17,23),'wood2');ellipse(rabbit,(3,13,16,22),'paperlo');ellipse(rabbit,(9,7,21,19),'paperlo')
    for x,y in [(12,1),(17,2)]:rabbit.r(x,y,3,10,'paperlo');rabbit.r(x+1,y+2,.5,6,'rose2')
    rabbit.l([(12,8),(17,8),(19,10)],'paperhi',1);rabbit.r(17,12,1,2,'wood0');rabbit.r(20,15,1,.5,'rose1')
    rabbit.r(7,22,5,1,'paperhi');rabbit.r(16,21,4,2,'paperlo');ellipse(rabbit,(0,16,5,21),'paperhi')
    save(rabbit,'rabbit',(11,23))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    save(tree(),'tree',(30,67));save(tree(True),'snow_tree',(30,67))
    save(cottage(),'cottage',(35,58));save(bench(),'bench',(32,32))
    save(garden(),'garden')
    chapter_backdrops.build()
    for member in PALETTES:
        for scene in range(4):
            MANIFEST[f'story_{member}_{scene}'] = dict(size=list(chapter_backdrops.GRID),
                native_size=list(chapter_backdrops.NATIVE), anchor=[0,0], density=2)
    fan_sprites()
    for kind in ['notice','card','charm','stone','sack','satchel','library_door','shutter','ring','chime','lens','gate','bell','lantern','ember','glow','rift','nightmare','arrows','quill','boot','hamster','paw']:
        save(prop(kind),'prop_'+kind,(20,34))
    for member in PALETTES:
        for phase,step in enumerate([0,1,-1]):save(bookmark(member,step),'role_%s_%d'%(member,phase),(21,53))
    for phase,step in enumerate([0,1,-1]):save(bookmark('traveler',step),'traveler_%d'%phase,(21,53))
    # Draw at half-grid precision (two native pixels per unit). Keep the feet
    # planted as the body transfers its weight. The field clock selects 24 cels.
    for n in range(24):
        step=round(4*math.sin(n*math.tau/24))*.5
        save(bookmark('traveler',step),'traveler_walk_%02d'%n,(21,53))
    pool=Pixel(104,48);pond(pool,2,2,100,44,True);save(pool,'dream_pool',(52,24))
    small_scenery()
    make_dressing(Pixel,save)
    write_layout()
    (OUT/'manifest.json').write_text(json.dumps(dict(revision=1,sprites=MANIFEST),ensure_ascii=False,indent=2),encoding='utf-8')
    print('World/fan pixel assets:',len(MANIFEST))


if __name__=='__main__':main()
