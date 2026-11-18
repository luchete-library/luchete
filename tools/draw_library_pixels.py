"""Build the library, restoration states, furniture layers and pixel UI.

The common room combines illustrated plates with native pixel detailing.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
from library_pixel_detail import refine
import library_materials as materials
import reading_room_props as props
import library_interior as interior

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'library_pixels'
OUT.mkdir(parents=True, exist_ok=True)
ART = ROOT / 'artifacts'
P = {
    'ink': '#302d35', 'deep': '#403238', 'wood0': '#553c36',
    'wood1': '#755040', 'wood2': '#97684b', 'wood3': '#b88a60',
    'wood4': '#d3aa75', 'gold0': '#8c6b49', 'gold': '#d2ac6c',
    'goldhi': '#f2d79b', 'paper': '#f0dfb6', 'paperhi': '#fff0cf',
    'paperlo': '#c4b18b', 'green0': '#314b49', 'green1': '#47675e',
    'green2': '#678877', 'green3': '#91ad88', 'greenhi': '#becba0',
    'blue0': '#374e62', 'blue1': '#557886', 'blue2': '#8bb3b5',
    'rose0': '#6b4859', 'rose1': '#9b6978', 'rose2': '#c69091',
    'purple0': '#524966', 'purple1': '#80748f', 'purple2': '#b3a0bb',
}
SPRITES = {}


class Pixel:
    def __init__(self, w, h, density=2):
        self.w, self.h, self.density = w, h, density
        self.im = Image.new('RGBA', (w*density, h*density))
        self.d = ImageDraw.Draw(self.im)

    def c(self, color):
        return P.get(color, color)

    def r(self, x, y, w, h, color):
        if w > 0 and h > 0:
            k=self.density
            self.d.rectangle((round(x*k),round(y*k),round((x+w)*k)-1,round((y+h)*k)-1),fill=self.c(color))

    def l(self, points, color, width=1):
        self.d.line([(round(x*self.density),round(y*self.density)) for x,y in points],fill=self.c(color),width=max(1,round(width*self.density)))

    def dot(self, x, y, color):
        self.r(x,y,1,1,color)

    def poly(self, points, color):
        self.d.polygon([(round(x*self.density),round(y*self.density)) for x,y in points],fill=self.c(color))

    def diamond(self, x, y, radius, color):
        for dy in range(-radius, radius+1):
            half = radius-abs(dy)
            self.r(x-half, y+dy, half*2+1, 1, color)

    def star(self, x, y, radius, color='goldhi'):
        self.l([(x-radius,y),(x+radius,y)],color)
        self.l([(x,y-radius),(x,y+radius)],color)
        self.diamond(x,y,max(1,radius//3),color)

    def paste(self, other, x, y):
        self.im.alpha_composite(other.im if isinstance(other, Pixel) else other,(round(x*self.density),round(y*self.density)))

    def save(self, name, anchor=(0,0), category='environment'):
        illustrated=interior.furnishing(name,self.im.size)
        if illustrated is None:
            refine(self,name)
            materials.finish(self,name)
        else:
            self.im=illustrated
            self.d=ImageDraw.Draw(self.im)
        self.im.save(OUT / f'{name}.png')
        SPRITES[name] = {'size':[self.w,self.h],'native_size':list(self.im.size),'density':self.density,'anchor':list(anchor),'category':category}
        return self


def trim(a,x,y,w,h):
    a.r(x,y,w,h,'wood0')
    a.r(x+1,y+1,w-2,h-2,'wood2')
    a.l([(x+1,y+1),(x+w-2,y+1)],'wood4')
    a.l([(x+1,y+2),(x+1,y+h-2)],'wood3')
    a.l([(x+2,y+h-2),(x+w-2,y+h-2)],'wood1')


def book(a,x,y,w,h,tone='green1',closed=True):
    if closed:
        a.r(x,y,w,h,'wood0')
        a.r(x+1,y+1,w-2,h-2,tone)
        a.r(x+1,y+1,1,h-2,'paperlo')
        if w > 5:
            a.r(x+3,y+2,w-4,1,'gold')
            a.r(x+3,y+h-4,w-4,1,'gold')
            a.r(x+3,y+h//2,max(1,w-5),2,'paperlo')
        a.r(x+1,y+h-1,w-2,1,'wood0')
    else:
        a.poly([(x,y+2),(x+w//2,y),(x+w-1,y+2),(x+w-1,y+h-2),(x+w//2,y+h),(x,y+h-2)],tone)
        a.poly([(x+1,y+1),(x+w//2-1,y),(x+w//2-1,y+h-2),(x+1,y+h-3)],'paperhi')
        a.poly([(x+w//2,y),(x+w-2,y+1),(x+w-2,y+h-3),(x+w//2,y+h-2)],'paper')
        a.l([(x+w//2,y+1),(x+w//2,y+h-2)],'paperlo')
        for yy in range(y+3,y+h-3,3):
            a.r(x+3,yy,max(1,w//2-5),1,'paperlo')
            a.r(x+w//2+3,yy,max(1,w//2-6),1,'paperlo')


def plank(variant):
    a=Pixel(64,16)
    a.r(0,0,64,16,'wood0')
    tones=['#9d7558','#a57d5d','#aa8161','#a17a5c']
    a.r(1,1,62,14,tones[variant])
    a.r(1,1,62,1,'wood3')
    a.r(1,14,62,1,'wood1')
    a.r(1,2,1,11,'wood2')
    # Deliberately placed long grain strokes and a single small knot.
    for x,y,w in [(7,4,19),(34,10,21),(14,12,14),(40,5,13)]:
        yy=(y+variant*3)%10+3
        a.r(x,yy,w,1,'#916c53')
        a.r(x+2,yy+1,max(1,w-6),1,tones[variant])
    kx=20+variant*8
    a.l([(kx-4,8),(kx-2,7),(kx+2,7),(kx+4,8),(kx+2,9),(kx-2,9),(kx-4,8)],'#8a664e')
    a.r(kx-1,8,3,1,'wood2')
    for x in [3,60]:
        a.dot(x,3,'wood1'); a.dot(x,12,'wood1')
    return a.save(f'floor_plank_{variant}')


def shelf(width, stage, story=False):
    a=Pixel(width,50)
    a.r(2,3,width-4,46,'wood0')
    a.r(5,5,width-10,40,'wood1')
    a.r(6,7,width-12,35,'deep')
    for row in range(2):
        yy=6+row*19
        a.r(7,yy,width-14,17,'#584037')
        a.r(7,yy,width-14,3,'#493735')
        if not (story and row==1):
            cursor=9
            idx=0
            while cursor<width-14:
                w=[5,6,4,7,5,4][idx%6]
                h=[13,15,12,14,11][(idx+row)%5]
                if (idx*3+row*2)%7<=stage:
                    tone=['green1','rose0','blue1','wood2','purple1','green2'][(idx+row)%6]
                    book(a,cursor,yy+16-h,w,h,tone)
                cursor+=w+2
                idx+=1
        trim(a,4,yy+17,width-8,3)
    for x in [1,width-5]:
        trim(a,x,3,4,44)
        a.r(x+1,6,1,35,'wood3')
        a.r(x-1,4,6,2,'gold')
        a.r(x-1,42,6,2,'wood4')
    trim(a,0,1,width,4)
    trim(a,0,46,width,3)
    for x in range(9,width-9,10): a.r(x,0,4,1,'wood3')
    if stage>=3:
        for x in [8,width-11]: a.diamond(x,3,1,'goldhi')
    return a.save(f'shelf_{"story" if story else "west"}_{stage}')


def rug(width,height,tone,secondary,name,grand=False):
    a=Pixel(width,height)
    for x in range(4,width-3,4):
        a.r(x,0,1,3,'paperlo'); a.r(x,height-3,1,3,'paperlo')
    a.r(1,3,width-2,height-6,'wood0')
    a.r(2,4,width-4,height-8,tone)
    a.r(4,6,width-8,height-12,'gold0')
    a.r(5,7,width-10,height-14,tone)
    a.r(8,10,width-16,height-20,secondary)
    a.r(9,11,width-18,height-22,tone)
    for x in range(12,width-11,9):
        for y in [8,height-9]:
            a.diamond(x,y,1,'gold')
    for y in range(16,height-15,10):
        a.dot(6,y,'gold'); a.dot(width-7,y,'gold')
    for x in [12,width-13]:
        for y in [14,height-15]:
            a.diamond(x,y,3,'gold0'); a.diamond(x,y,1,'goldhi')
    cx,cy=width//2,height//2
    a.diamond(cx,cy,min(width,height)//5,secondary)
    a.diamond(cx,cy,min(width,height)//5-2,tone)
    a.star(cx,cy,8 if grand else 4,'gold0')
    if grand:
        for dx,dy in [(-19,0),(19,0),(0,-19),(0,19)]:
            a.diamond(cx+dx,cy+dy,3,secondary)
            a.dot(cx+dx,cy+dy,'gold')
        # Woven stitch pairs, deliberately sparse in the walking area.
        for y in range(22,height-20,12):
            for x in range(22,width-20,18):
                if abs(x-cx)+abs(y-cy)>32:
                    a.r(x,y,2,1,secondary)
    return a.save(name)


def window(boarded=False):
    a=Pixel(48,48)
    trim(a,2,1,44,45)
    a.r(5,4,38,37,'green0')
    a.r(7,6,34,33,'blue0')
    a.r(8,7,32,16,'blue1')
    a.r(8,23,32,15,'blue2')
    a.r(8,30,32,8,'green2')
    # Moon and stepped cypress silhouettes, no antialiased circles.
    for dy,w in [(0,3),(1,5),(2,7),(3,7),(4,7),(5,5),(6,3)]:
        a.r(32-w//2,10+dy,w,1,'paperhi')
    for x,y,h in [(10,27,9),(34,24,13),(15,31,5)]:
        a.poly([(x,y),(x+4,y+h),(x-4,y+h)],'green1')
    for x in [14,26]:
        a.r(x,7,1,30,'#a3c2b4')
    a.r(22,4,3,36,'wood1'); a.r(22,4,1,36,'gold')
    a.r(5,23,38,3,'wood1'); a.r(5,23,38,1,'gold')
    trim(a,0,40,48,5)
    a.r(4,45,40,2,'wood0')
    if boarded:
        for y in [12,28]:
            a.poly([(2,y+3),(43,y),(44,y+5),(3,y+8)],'wood0')
            a.poly([(3,y+3),(43,y+1),(43,y+4),(3,y+6)],'wood2')
            a.dot(5,y+4,'ink');a.dot(40,y+3,'ink')
    else:
        # Folded sage curtains do not obscure the glass.
        for x in [1,40]:
            a.poly([(x,3),(x+7,3),(x+5,20),(x+3,25),(x+1,32)],'green1')
            a.l([(x+2,5),(x+3,19),(x+1,28)],'green3')
            a.r(x+1,22,4,2,'gold')
    return a.save('window_boarded' if boarded else 'window_clear')


def lamp(lit):
    a=Pixel(16,32)
    a.r(7,1,2,9,'wood0');a.r(7,2,1,8,'gold')
    a.r(4,9,8,3,'gold0');a.r(5,8,6,1,'goldhi')
    a.poly([(3,12),(12,12),(14,23),(1,23)],'wood0')
    a.poly([(4,13),(11,13),(12,21),(3,21)],'gold' if lit else 'gold0')
    a.r(6,14,3,7,'paperhi' if lit else 'paperlo')
    a.r(1,23,14,2,'wood0');a.r(2,23,12,1,'gold')
    a.r(6,25,4,2,'gold0');a.dot(7,27,'goldhi')
    return a.save('lamp_on' if lit else 'lamp_off')


def plant(lush):
    a=Pixel(28,40)
    a.r(7,37,15,2,'wood0')
    a.poly([(6,28),(23,28),(21,37),(8,37)],'wood1')
    a.poly([(8,29),(21,29),(19,36),(10,36)],'wood3')
    a.r(6,27,18,3,'wood0');a.r(7,27,16,2,'wood4')
    a.r(13,10,2,18,'green1')
    leaves=[(6,19,1),(15,15,-1),(4,10,1),(14,5,-1),(10,2,1)]
    for x,y,direction in leaves[:5 if lush else 3]:
        a.poly([(x,y+2),(x+3,y),(x+9,y+2),(x+10,y+6),(x+6,y+7),(x+2,y+5)],'green1')
        a.poly([(x+1,y+2),(x+4,y+1),(x+8,y+2),(x+7,y+4),(x+3,y+4)],'green3' if lush else 'green2')
        a.l([(x+3,y+3),(14,y+8)],'green2')
    if lush:
        a.dot(9,12,'greenhi');a.dot(20,8,'greenhi')
    return a.save('plant_lush' if lush else 'plant_small')


def table(name,width=98,desk=False):
    a=Pixel(width,48)
    for x in [9,width-15]:
        a.r(x,28,6,16,'wood0');a.r(x+1,29,3,13,'wood2')
        a.r(x-1,42,8,3,'wood0');a.r(x,42,6,1,'gold0')
    a.r(5,23,width-10,13,'wood0')
    a.r(6,24,width-12,10,'wood1')
    for x in range(9,width-18,21):
        a.r(x,26,19,7,'wood0');a.r(x+1,27,17,5,'wood2')
        a.r(x+8,29,4,2,'gold0');a.r(x+8,29,3,1,'goldhi')
    a.r(2,14,width-4,13,'wood0')
    a.r(3,13,width-6,12,'wood3')
    a.r(4,14,width-8,8,'wood4')
    for y in [17,21]: a.r(6,y,width-12,1,'wood3')
    a.r(3,24,width-6,2,'wood1');a.r(3,23,width-6,1,'gold')
    a.r(12,13,width-29,11,'green1')
    a.r(13,14,width-31,9,'green2')
    book(a,18,10,27 if not desk else 22,13,'green0',False)
    if not desk:
        # Loose folios, sealing wax, ink and feather.
        a.r(54,14,12,8,'paperlo');a.r(55,13,12,8,'paper')
        for y in [15,18]:a.r(57,y,7,1,'paperlo')
        a.r(73,15,8,7,'ink');a.r(74,16,6,5,'purple0')
        a.r(75,13,4,3,'gold');a.dot(75,17,'purple2')
        a.l([(77,15),(85,1)],'paperhi')
        a.poly([(80,9),(81,3),(86,0),(85,6)],'paper')
        a.r(49,20,4,2,'rose0');a.r(50,19,3,1,'rose2')
        book(a,5,9,9,9,'rose0')
    else:
        a.r(width-19,16,10,4,'wood0')
        a.r(width-17,9,6,8,'wood2')
        a.r(width-18,7,8,4,'green0');a.r(width-17,7,6,1,'green3')
        a.r(5,29,6,4,'gold0');a.dot(7,30,'goldhi')
    return a.save(name)


def noticeboard():
    a=Pixel(34,26)
    trim(a,1,1,32,24)
    a.r(4,4,26,17,'wood2')
    for x,y in [(5,5),(18,7),(11,13)]:
        a.r(x+1,y+1,9,9,'wood0');a.r(x,y,9,9,'paper')
        a.r(x+2,y+3,5,1,'paperlo');a.r(x+2,y+5,4,1,'paperlo')
        a.dot(x+4,y,'rose0');a.dot(x+4,y-1,'rose2')
    return a.save('notice_board')


def portal():
    a=Pixel(44,50)
    a.r(2,2,40,46,'wood0');a.r(3,3,38,44,'gold0')
    a.r(5,4,34,40,'wood3');a.r(7,6,30,37,'green0')
    a.r(9,8,26,33,'green1');a.r(11,9,22,30,'blue1')
    a.r(13,11,18,26,'green2')
    for y in range(14,34,6):
        a.r(15,y,3,1,'blue2');a.r(26,y+2,3,1,'blue2')
    a.r(21,7,2,35,'gold');a.r(22,9,1,30,'paperlo')
    for x in [5,36]:
        a.r(x,7,2,34,'wood4');a.r(x-1,8,4,2,'goldhi')
        a.r(x-1,39,4,2,'goldhi')
    trim(a,0,44,44,5)
    a.diamond(22,3,2,'goldhi');a.star(22,23,7,'paperhi')
    a.r(17,30,2,2,'goldhi');a.r(25,30,2,2,'goldhi')
    return a.save('garden_door')


def chair(tea=False):
    back=Pixel(48,42);front=Pixel(48,42)
    tone='rose1' if tea else 'green2'
    shade='rose0' if tea else 'green1'
    for x in [13,32]:
        back.r(x,31,3,10,'wood0');back.r(x,32,1,7,'wood3')
    trim(back,11,5,26,25)
    back.r(14,8,20,17,shade);back.r(15,9,18,14,tone)
    back.r(16,9,16,1,'rose2' if tea else 'greenhi')
    for x in [19,29]:
        for y in [13,20]:
            back.dot(x,y,shade);back.dot(x,y-1,'rose2' if tea else 'green3')
    back.r(10,27,28,7,'wood0');back.r(12,26,24,6,tone)
    back.r(13,26,22,1,'rose2' if tea else 'greenhi')
    back.r(14,31,20,1,shade)
    for x in [9,35]:
        front.r(x,22,4,16,'wood0');front.r(x+1,23,2,12,'wood2')
        trim(front,x-1,21,6,4)
    if not tea:
        book(back,38,32,7,5,'rose0')
        back.r(38,34,6,2,'paper');back.r(38,37,9,2,'wood0')
    else:
        # Tea table is the foreground layer; the seated sprite remains visible.
        front=Pixel(48,42)
        for x in [10,36]:
            front.r(x,32,3,10,'wood0');front.r(x+1,32,1,8,'wood3')
        front.r(6,25,36,10,'wood0');front.r(7,25,34,7,'wood3')
        front.r(8,26,32,4,'wood4');front.r(8,31,32,1,'gold')
        front.r(15,26,17,4,'paper');front.r(16,26,15,1,'paperhi')
        front.r(11,27,5,2,'gold0');front.r(12,25,3,2,'paperhi')
        front.r(32,21,6,7,'green2');front.r(33,21,4,5,'greenhi')
        front.r(33,19,4,2,'green1');front.r(37,22,3,3,'green2')
        front.dot(38,23,'wood4')
    back.save('tea_back' if tea else 'chair_back',(24,32),'furniture')
    front.save('tea_front' if tea else 'chair_front',(24,32),'furniture')
    return back,front


def mat():
    a=Pixel(44,18)
    props.yoga_mat(a)
    return a.save('mat_back',(22,9),'furniture')


def camera():
    a=Pixel(48,34)
    props.camera(a)
    return a.save('camera_back',(24,27),'furniture')


def ui_frame(name,kind):
    a=Pixel(32,32,density=1)
    # Eight-pixel corners and repeatable edge strips; center stays transparent.
    a.r(2,0,28,32,'wood0');a.r(0,2,32,28,'wood0')
    a.r(2,2,28,28,'wood2' if kind!='accent' else 'gold0')
    a.r(4,4,24,24,'wood3' if kind!='accent' else 'gold')
    a.r(6,6,20,20,'paperlo')
    a.r(8,8,16,16,(0,0,0,0))
    a.r(4,2,24,2,'wood4' if kind!='accent' else 'goldhi')
    a.r(2,4,2,24,'wood3');a.r(4,28,24,2,'wood1')
    a.r(28,4,2,24,'wood1');a.r(8,6,16,2,'paperhi')
    a.r(6,8,2,16,'paper')
    for x in [3,25]:
        for y in [3,25]:
            a.r(x,y,4,4,'gold0');a.r(x,y,3,2,'goldhi');a.dot(x+1,y+2,'wood0')
    if kind=='slot':
        # Low brass lip instead of heavy outer bolts on toolbar slots.
        for x in [3,25]:
            for y in [3,25]: a.r(x,y,4,4,'wood3')
    return a.save(name,category='ui')


def icon(kind):
    a=Pixel(20,20)
    if kind=='bag':
        a.r(6,1,8,5,'wood0');a.r(8,2,4,3,'wood3')
        a.r(3,6,14,12,'wood0');a.r(4,6,12,11,'wood2')
        a.r(5,7,10,6,'wood3');a.r(5,7,10,1,'wood4')
        a.r(5,14,3,2,'wood1');a.r(12,14,3,2,'wood1')
        a.r(9,9,3,6,'gold0');a.r(9,10,3,3,'goldhi');a.dot(10,11,'wood1')
    elif kind in ['journal','table']:
        book(a,2,4 if kind=='table' else 1,16,13 if kind=='table' else 18,'green1',kind=='journal')
        if kind=='journal':
            a.star(11,9,3,'gold');a.r(12,16,2,4,'rose1')
    elif kind in ['requests','paper']:
        a.r(4,2,13,17,'wood0');a.r(3,1,13,17,'paperlo');a.r(4,2,11,15,'paperhi')
        for y,w in [(6,7),(9,7),(12,5)]:a.r(6,y,w,1,'paperlo')
        if kind=='requests':
            a.r(7,0,5,4,'wood0');a.r(8,1,3,2,'gold')
            a.r(10,14,4,3,'rose0');a.dot(11,14,'rose2')
    elif kind=='portal':
        a.r(2,1,16,18,'wood0');a.r(3,2,14,16,'gold');a.r(5,3,10,14,'green1')
        a.r(6,4,8,12,'blue1');a.star(10,9,4,'paperhi');a.r(1,18,18,2,'wood2')
    elif kind=='loans':
        a.r(3,13,15,5,'wood0');a.r(4,13,13,3,'wood3');a.r(7,6,7,7,'wood1')
        a.r(8,7,4,5,'wood3');a.r(5,1,11,6,'green0');a.r(6,2,9,3,'green2')
        a.r(7,2,7,1,'greenhi');a.r(5,17,11,1,'rose0')
    elif kind=='sleep':
        trim(a,4,1,12,12);a.r(6,3,8,7,'green2');a.r(7,3,6,1,'greenhi')
        a.r(4,12,12,4,'wood0');a.r(5,11,10,3,'green3')
        for x in [3,15]:a.r(x,10,3,7,'wood2');a.r(x,10,3,1,'gold')
        for x in [4,14]:a.r(x,16,2,3,'wood0')
    elif kind=='bookmark':
        a.poly([(6,1),(14,1),(14,19),(10,16),(6,19)],'rose0')
        a.poly([(7,2),(13,2),(13,17),(10,14),(7,17)],'rose1')
        a.r(8,3,4,1,'goldhi');a.diamond(10,8,2,'gold')
    elif kind=='ink':
        a.r(5,1,10,4,'wood0');a.r(6,2,8,2,'gold')
        a.r(6,5,8,3,'purple0');a.r(3,8,14,10,'ink')
        a.r(4,9,12,8,'purple0');a.r(6,10,2,5,'purple2');a.r(9,11,5,4,'paper')
        a.dot(11,12,'purple1');a.r(5,17,10,1,'purple1')
    elif kind=='star':
        a.star(10,10,8,'gold0');a.star(9,9,7,'gold');a.star(9,8,4,'goldhi')
        a.dot(15,3,'gold');a.dot(2,14,'gold')
    elif kind=='sun':
        a.diamond(10,10,6,'gold0');a.r(6,6,9,9,'gold0')
        a.diamond(10,10,5,'gold');a.r(7,7,7,7,'gold')
        a.r(8,7,5,2,'goldhi')
        for x,y,w,h in [(9,0,2,3),(9,18,2,2),(0,9,3,2),(18,9,2,2),(3,3,2,2),(16,3,2,2),(3,16,2,2),(16,16,2,2)]:a.r(x,y,w,h,'gold0')
    elif kind=='leaf':
        a.poly([(3,15),(4,8),(10,3),(17,2),(16,9),(10,15)],'green0')
        a.poly([(5,13),(6,8),(12,4),(16,4),(14,10),(9,14)],'green2')
        a.l([(3,17),(13,7)],'greenhi');a.l([(7,13),(7,9)],'green3')
    return a.save('icon_'+kind,category='ui')


def book_layers(opened):
    w,h=(28,20) if opened else (17,25)
    base,detail=Pixel(w,h),Pixel(w,h)
    if opened:
        base.poly([(0,2),(13,0),(27,2),(27,18),(14,19),(0,17)],'#707070')
        base.poly([(1,3),(13,1),(26,3),(26,16),(14,18),(1,16)],'#ffffff')
        detail.poly([(2,3),(12,2),(12,16),(2,15)],'paperhi')
        detail.poly([(14,2),(25,3),(25,15),(14,16)],'paper')
        detail.r(13,3,1,14,'paperlo')
        for y in [5,8,11]:
            detail.r(4,y,6 if y!=11 else 4,1,'paperlo')
            detail.r(16,y+1,7 if y!=11 else 5,1,'paperlo')
        detail.r(18,15,2,5,'rose1')
    else:
        base.r(2,3,15,22,'#595959');base.r(0,0,16,23,'#707070')
        base.r(1,1,14,20,'#ffffff');base.r(2,1,1,19,'#c4c4c4')
        detail.r(3,22,12,2,'paperlo');detail.r(4,22,11,1,'paper')
        for y in [3,18]:detail.r(5,y,8,1,'gold')
        for x in [5,12]:detail.r(x,4,1,3,'gold0');detail.r(x,15,1,3,'gold0')
        detail.star(9,10,3,'gold');detail.dot(9,9,'goldhi')
        detail.r(2,3,1,1,'goldhi');detail.r(2,17,1,1,'goldhi')
        detail.r(11,21,2,4,'rose0');detail.dot(11,21,'rose2')
    name='book_open' if opened else 'book_closed'
    base.save(name+'_base',category='ui');detail.save(name+'_detail',category='ui')


def keepsake(member):
    a=Pixel(42,48)
    if member in ('yato','dori'):
        props.board(a,member=='dori')
    else:
        draw={'danming':props.mailbox,'kubby':props.lantern,'yune':props.dreamcatcher,'fuwa':props.snow_gate}
        draw[member](a)
    return a.save('keepsake_'+member,(21,44),'keepsake')


def gym():
    a=Pixel(25,19)
    props.weight_rack(a)
    return a.save('gym_rack',(1,16),'furniture')


def mute(image, amount):
    """Palette-only wear: keep exact alpha and hard pixel edges."""
    result=image.copy()
    data=[]
    for r,g,b,a in image.get_flattened_data():
        grey=(r*3+g*5+b*2)//10
        data.append((round(r*(1-amount)+(grey*.85+8)*amount),round(g*(1-amount)+(grey*.85+9)*amount),round(b*(1-amount)+(grey*.85+10)*amount),a))
    result.putdata(data)
    return result


def background(stage):
    a=Pixel(452,289)
    a.im=interior.hall().copy()
    a.d=ImageDraw.Draw(a.im)
    def put(name,x,y):
        with Image.open(OUT/f'{name}.png') as sprite:
            a.im.alpha_composite(sprite.convert('RGBA'),(x-interior.WORLD_ORIGIN[0],y-interior.WORLD_ORIGIN[1]))
    put('shelf_west_'+str(stage),86,158)
    put('shelf_story_'+str(stage),326,158)
    put('window_boarded' if stage<2 else 'window_clear',682,142)
    put('lamp_on' if stage else 'lamp_off',290,154)
    put('lamp_on' if stage else 'lamp_off',640,154)
    put('rug_main',350,340)
    materials.cast(a,184,155,94,7)
    materials.cast(a,312,151,59,7)
    put('work_table',392,378)
    put('lending_desk',650,370)
    put('notice_board',64,238)
    put('garden_door',790,176)
    put('rest_chair',86,564)
    if stage>=1:put('plant_lush' if stage>=4 else 'plant_small',76,380)
    if stage>=3:put('plant_lush' if stage>=5 else 'plant_small',856,386)
    if stage>=4:put('plant_lush',644,160)
    if stage>=5:
        # Fixed stepped garland, mirrored leaf clusters and square bulbs.
        for x in range(81,401):
            y=2+min((x-81)%80,80-(x-81)%80)//8
            a.dot(x,y,'gold0')
            if x%12==0:
                a.r(x,y+1,2,2,'gold');a.dot(x,y+1,'paperhi')
    # Wear disappears gradually, while layout and walkable space stay identical.
    marks=[(116,139),(370,216),(265,83),(166,234),(298,257),(405,119)]
    for x,y in marks[stage:]:
        a.l([(x-10,y),(x-3,y),(x,y+2),(x+7,y-1),(x+12,y-1)],'wood0')
        a.l([(x,y+2),(x+2,y+5)],'wood0')
        for dx,dy in [(-7,4),(5,7),(-11,7),(13,5)]:a.r(x+dx,y+dy,2,1,'paperlo')
    if stage<2:
        for end in [(40,10),(28,29),(11,45)]:a.l([(15,9),end],'#9d9a89')
        a.l([(29,10),(26,16),(21,21),(14,24)],'#9d9a89')
        a.l([(37,10),(30,23),(20,33),(14,38)],'#9d9a89')
    if stage<6:a.im=mute(a.im, max(0,.62-stage*.10))
    return a.save('library_stage_'+str(stage),category='background')


def main():
    for i in range(4):plank(i)
    for stage in range(7):shelf(108,stage);shelf(159,stage,True)
    rug(144,112,'green0','green1','rug_main',True)
    for name,w,h,tone,secondary in [('rug_read',64,68,'green1','green2'),('rug_tea',64,62,'rose0','rose1'),('rug_exercise',100,64,'purple0','purple1'),('rug_stream',70,50,'blue0','blue1')]:
        rug(w,h,tone,secondary,name)
    window(False);window(True);lamp(False);lamp(True);plant(False);plant(True)
    table('work_table');table('lending_desk',64,True);noticeboard();portal()
    back,front=chair();chair(True);mat();camera()
    rest=Pixel(44,42);rest.paste(back.im.crop((4,0,92,84)),0,0);rest.paste(front.im.crop((4,0,92,84)),0,0)
    # A checked lap blanket and embroidered cushion distinguish the rest chair.
    rest.poly([(11,25),(24,24),(27,26),(25,28),(25,35),(22,36),(12,35),(12,28)],'#b79c71')
    rest.l([(11,25),(24,24),(26,26),(24,27),(12,27)],'#e1cba2',.5)
    for x in [14,19,23]:
        rest.l([(x,25),(x+1,27),(x,29),(x,35)],'#658272',1)
        rest.l([(x+1.5,25),(x+2,27),(x+1,29),(x+1,35)],'#e1c39b',.5)
    for y in [29,32,34]:rest.l([(12,y),(19,y+.5),(24.5,y)],'#7b7461',.5)
    for x in range(12,25,2):rest.l([(x,35),(x+.5,37)],'#cfba91',.5)
    rest.save('rest_chair')
    for kind in ['panel','accent','slot']:ui_frame('ui_'+kind,kind)
    for name in ['bag','journal','table','requests','paper','portal','loans','sleep','bookmark','ink','star','sun','leaf']:icon(name)
    book_layers(False);book_layers(True);gym()
    for member in ['yato','danming','kubby','yune','dori','fuwa']:keepsake(member)
    for stage in range(7):background(stage)
    sun=Pixel(195,135)
    sun.im=interior.window_light()
    sun.save('window_light',category='lighting')
    (OUT/'manifest.json').write_text(json.dumps({'revision':5,'pixel_scale':2,'background_origin':list(interior.WORLD_ORIGIN),'sunlight_origin':list(interior.LIGHT_ORIGIN),'sprites':SPRITES},ensure_ascii=False,indent=2),encoding='utf-8')
    # Separate labelled contact sheet for review, artwork enlarged with NEAREST only.
    names=['work_table','lending_desk','notice_board','window_clear','garden_door','plant_lush','chair_back','chair_front','tea_back','tea_front','mat_back','camera_back','rug_main','ui_panel','ui_accent','icon_bag','keepsake_yato','keepsake_danming','keepsake_kubby','keepsake_yune','keepsake_dori','keepsake_fuwa','icon_loans','icon_ink']
    sheet=Image.new('RGB',(1200,1330),'#263b36');d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',15)
    title=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',25)
    d.text((22,15),'루체테 · 직접 찍은 도서관 소품과 UI 도트',font=title,fill='#f0dfb6')
    for i,name in enumerate(names):
        x=20+(i%4)*295;y=65+(i//4)*208
        d.rectangle((x,y,x+280,y+194),fill='#3c5048')
        im=Image.open(OUT/f'{name}.png')
        lw,lh=SPRITES[name]['size']
        scale=max(1,min(4,260//lw,162//lh))
        im=im.resize((lw*scale,lh*scale),Image.Resampling.NEAREST)
        sheet.paste(im,(x+(280-im.width)//2,y+(165-im.height)//2),im)
        d.text((x+12,y+170),name,font=font,fill='#e0d3b2')
    sheet.save(ART/'library_pixel_assets.png')
    print(f'Authored {len(SPRITES)} native pixel PNGs in {OUT}')


if __name__=='__main__':main()
