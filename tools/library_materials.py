"""Native-pixel joinery, bindings, woven wool and lighting for Lucete."""
import math
import random

from PIL import Image, ImageDraw


def oval(a, x, y, w, h, color):
    k = a.density
    a.d.ellipse((round(x*k), round(y*k), round((x+w)*k)-1, round((y+h)*k)-1), fill=a.c(color))


def fresh(a):
    a.d.rectangle((0, 0, a.im.width, a.im.height), fill=(0, 0, 0, 0))


def tint(col, value):
    return tuple(max(0, min(255, round(v+value))) for v in col)


def oak(a, x, y, w, h, seed, base=(152, 108, 76)):
    """Long axial grain and split cathedral figure, nested around an occasional knot."""
    rng = random.Random(seed)
    a.r(x, y, w, h, tint(base, -23))
    k = a.density
    # Sparse highlights live in the fibres, not on a uniform grid of nails.
    figure = rng.uniform(.18,.83)*w
    axis = rng.uniform(.28,.73)*h
    spread = rng.uniform(.15,.39)*w
    figured = rng.random() < .57
    for j in range(1, int(h*k)-1):
        fy = j/k
        c = tint(base, 2.2*math.sin(j*.43)+rng.uniform(-2,2))
        a.r(x+.5,y+fy,w-1,1/k,c)
    for j in range(max(3, int(h*1.25))):
        fy = rng.uniform(1,h-1)
        start = rng.uniform(.5,w*.34)
        end = rng.uniform(w*.65,w-1)
        bend = rng.uniform(.15,.62)
        phase = rng.random()*5
        pts = []
        for n in range(int(start*2),int(end*2)+1,3):
            u=n/2
            v = fy + bend*math.sin(phase+u/13)
            if figured:
                v += (1 if fy>axis else -1)*1.8*math.exp(-((u-figure)/spread)**2-abs(fy-axis)/3)
            pts.append((x+u, y+max(.8,min(h-1,v))))
        if len(pts)>1:
            a.l(pts,tint(base,rng.choice([-11,-7,-5,5,8])),.5)
    if figured and rng.random()<.5:
        oval(a,x+figure-2,y+axis-.7,4,1.5,tint(base,-22))
        a.r(x+figure-.5,y+axis,2,.5,tint(base,-9))
    a.r(x+.5,y+.5,w-1,.5,tint(base,18))
    a.r(x+w-1,y+1,.5,h-2,tint(base,-16))


def parquet(a):
    # Stagger board lengths and figure independently. No repeating 2 x 4 knot stamp.
    rng = random.Random(3752)
    floor = type(a)(436,232)
    for row in range(15):
        x = -rng.randint(5,64)
        while x<436:
            width = rng.choice([48,61,77,88,106])
            tone = rng.choice([(148,102,73),(160,115,80),(152,106,73),(163,115,83),(156,108,75)])
            oak(floor,x,row*16,width,16,rng.randrange(100000),tone)
            x += width
    a.paste(floor,8,49)


def bound_book(a,x,y,w,h,cloth,slant=0):
    """A rounded leather spine with raised sewing bands and a foil title plate."""
    a.poly([(x+slant,y),(x+w+slant,y-.5),(x+w,y+h),(x,y+h)],tint(cloth,-22))
    for n in range(max(0,round(w*2)-2)):
        offset=.5+n*.5
        light=round(17*math.sin(math.pi*offset/w)-24*(offset/w)**3)
        a.l([(x+slant+offset,y+.5),(x+offset,y+h-.5)],tint(cloth,light),.5)
    for dy in (2,h-2):
        xx=x+slant*(1-dy/h)
        a.l([(xx+.5,y+dy),(xx+w-1,y+dy)],'#c2a170',.5)
        a.l([(xx+1,y+dy+.5),(xx+w-1,y+dy+.5)],tint(cloth,-14),.5)
    mid=y+h*.42
    xx=x+slant*.58
    if w>=5:
        a.r(xx+1,mid,w-2,3,tint(cloth,-15))
        a.r(xx+1.5,mid+.5,w-3,.5,'#dfbf89')
        a.r(xx+2,mid+2,max(.5,w-4),.5,'#bd9869')
    else:
        a.r(xx+1,mid,1,2,'#bc996b')


def shelves(a,name):
    stage=int(name[-1])
    story='story' in name
    for row in range(2):
        y=6+row*19
        for j in range(34):
            c=tint((77,49,41),-20*math.exp(-j/9)+j*.18)
            a.r(6,y+j*.5,a.w-12,.5,c)
        for x in range(10,a.w-7,11):
            a.r(x,y+.5,.5,15.5,'#48302b')
        if story and row==1: continue
        rng=random.Random(442+row+(80 if story else 0))
        x=8
        while x<a.w-13:
            w=rng.choice([3,3.5,4.5,5,6.5])
            h=rng.choice([10,12,13,14,15.5])
            cloth=rng.choice([(110,61,53),(107,79,61),(72,97,88),(63,82,93),(101,80,109),(136,94,63),(81,103,88)])
            appears=rng.randrange(7)
            slant=rng.choice([0,0,0,.5,1.5])
            if appears<=stage:
                bound_book(a,x,y+16-h,w,h,cloth,slant)
            x+=w+rng.choice([.5,1,1,2.5])
        if stage>=3 and a.w>145 and row==0:
            for j,cloth in enumerate(['#835545','#57665c','#735568']):
                xx=a.w-22+j%2
                a.r(xx,y+13-j*3,13,2.5,cloth)
                a.r(xx+1,y+13.5-j*3,11,1,'#c3aa86')
    for x in (2,a.w-5):
        a.l([(x,5),(x,43)],'#ac8058',1)
        a.l([(x+1.5,7),(x+1.5,41)],'#5c3c30',.5)
    for y in (4,23,42):
        a.r(5,y,a.w-10,1,'#d6ab74')
        a.r(5,y+1,a.w-10,1,'#8b5e42')


def textile(a,name):
    palettes={'rug_main':((45,75,68),(103,126,101)), 'rug_read':((65,91,73),(146,146,103)),
              'rug_tea':((108,64,67),(169,114,105)), 'rug_exercise':((78,68,88),(140,120,146)),
              'rug_stream':((54,78,89),(118,143,139))}
    base,leaf=palettes[name]
    w,h=a.w,a.h
    fresh(a)
    for x in range(3,w-3,2):
        fringe=1+(x*13%3)
        a.r(x,3-fringe,.5,fringe+1,'#b59f7e')
        a.r(x,h-3,.5,fringe,'#ae9877')
    a.r(1,3,w-2,h-6,tint(base,-16))
    a.r(2,4,w-4,h-8,'#c29d70')
    a.r(3,5,w-6,h-10,tint(base,12))
    a.r(5,7,w-10,h-14,'#977d5f')
    a.r(6,8,w-12,h-16,base)
    # Woven selvage and reciprocal leaf border.
    for x in range(7,w-7,5):
        for y in (5,h-6):
            a.l([(x-2,y+1),(x,y-1),(x+2,y+1)],'#d7b78b',.5)
    for y in range(12,h-11,5):
        for x in (3,w-4):
            a.l([(x,y-1),(x+1,y),(x,y+1)],'#cead83',.5)
    cx,cy=w/2,h/2
    # Four corner sprays frame an eight-petal rosette. Keep character feet legible.
    for sx in (-1,1):
        for sy in (-1,1):
            ox=7 if sx==1 else w-8
            oy=10 if sy==1 else h-11
            def pt(x,y):return (ox+x*sx,oy+y*sy)
            a.l([pt(0,0),pt(3,2),pt(5,6),pt(8,8),pt(12,9)],tint(leaf,-6),.5)
            for x,y in [(1,1),(4,4),(7,7)]:
                a.poly([pt(x,y),pt(x+2,y-1),pt(x+4,y),pt(x+2,y+1)],leaf)
                a.poly([pt(x,y),pt(x-1,y+2),pt(x,y+4),pt(x+1,y+2)],tint(leaf,-5))
    radius=min(w,h)*.19
    for angle in range(0,360,45):
        t=math.radians(angle)
        def petal(r,s):return cx+r*math.cos(t)-s*math.sin(t),cy+r*math.sin(t)+s*math.cos(t)
        a.poly([petal(1,0),petal(radius*.57,-2),petal(radius,0),petal(radius*.57,2)],tint(leaf,-9))
        a.l([petal(2,0),petal(radius*.77,0)],'#be9e75',.5)
    a.diamond(int(cx),int(cy),2,'#cead7c')
    rng=random.Random(w)
    for _ in range(w*h//11):
        x=rng.uniform(7,w-8); y=rng.uniform(9,h-10)
        if (x-cx)**2+(y-cy)**2>radius**2 and min(x,w-x)+min(y,h-y)>33:
            a.r(x,y,rng.choice([.5,1,1.5]),.5,tint(base,rng.choice([-4,4,7])))


def leg(a,x,y,h,width=4):
    for j in range(h):
        t=j/h
        size=width*(1-.45*t)+1.3*math.exp(-((t-.20)/.15)**2)
        xx=x+(width-size)/2
        a.r(xx,y+j,size,1,'#4e352d')
        a.r(xx+.5,y+j,max(.5,size-1.5),1,'#85593c')
        a.r(xx+1,y+j,.5,1,'#b3895a')
    for dy in (1,round(h*.28),h-2):
        a.r(x-.5,y+dy,width+.5,1,'#5c4032')
        a.r(x,y+dy,width-1,.5,'#bb8d59')


def sheet(a,x,y,w,h):
    # The fore-edge consists of three steps below the open, slightly curled page.
    for offset,c in [(2,'#634635'),(1.5,'#b7a183'),(.5,'#dfcba8'),(0,'#f3e4bf')]:
        a.poly([(x,y+1+offset),(x+w*.24,y-.5+offset),(x+w*.5,y+1.5+offset),
                (x+w*.76,y+offset),(x+w,y+1+offset),(x+w-1,y+h+offset),
                (x+w*.72,y+h-.5+offset),(x+w*.5,y+h+1+offset),(x+w*.25,y+h-.5+offset),(x-1,y+h+offset)],c)
    a.l([(x+w*.5,y+2),(x+w*.5-1,y+h)],'#a38b68',.5)
    for side in range(2):
        left=x+w*.5*side+2
        for i in range(4):
            yy=y+3+i*1.45
            a.l([(left,yy),(left+2,yy-.5),(left+w*.29-(i%2),yy)],'#ad9b80',.5)
    a.l([(x+w*.53,y+h),(x+w*.54,y+h+3),(x+w*.59,y+h+2)],'#97504a',1)


def brass_lamp(a,x,y):
    oval(a,x-5,y-2,10,3,'#614939')
    oval(a,x-4,y-3,8,3,'#af8c52')
    a.r(x-1,y-10,2,8,'#815e3c'); a.r(x-1,y-10,.5,7,'#e4c17f')
    a.l([(x,y-9),(x-2,y-11),(x-2,y-13)],'#bc9b60',1)
    a.poly([(x-7,y-14),(x-4,y-16),(x+4,y-16),(x+7,y-14),(x+8,y-11),(x-8,y-11)],'#245452')
    a.l([(x-6,y-14),(x-4,y-15),(x+4,y-15),(x+5,y-14)],'#8fb49b',1)
    a.r(x-6,y-11,13,.5,'#f9db9f'); a.r(x+5,y-10,.5,4,'#c7ab7a')


def table(a,desk):
    fresh(a); w=a.w
    for x in (10,w-15):
        leg(a,x,23,12,3)
    for x in (6,w-12):
        leg(a,x,28,17,5)
    a.poly([(4,22),(w-4,22),(w-5,33),(w-10,36),(w-14,32),(14,32),(11,35),(6,33)],'#5d3d30')
    oak(a,8,23,w-16,9,761,(130,85,57))
    drawer_count=2 if desk else 3
    span=(w-18)/drawer_count
    for i in range(drawer_count):
        x=9+i*span
        a.r(x,24,span-1,7,'#51382f');oak(a,x+1,24.5,span-3,5.5,i+701,(144,98,64))
        cx=x+span/2-1
        oval(a,cx-1.5,26,3,2,'#654a36');a.l([(cx-1.5,26.5),(cx-1,28),(cx+1,28),(cx+1.5,26.5)],'#d8ad68',.5)
    a.poly([(5,13),(w-6,13),(w-1,21),(w-1,24),(2,24),(1,21)],'#4e352d')
    a.poly([(5,12.5),(w-6,12.5),(w-1,21),(1,21)],'#be9366')
    a.r(2,21,w-4,1,'#e2b782');a.r(3,22.5,w-6,1,'#926448')
    for i in range(4):
        a.l([(5+i*4,14+i*1.6),(w-6-i*3,14+i*1.6)],'#aa7c56',.5)
    a.poly([(10,13.5),(w-15,13.5),(w-12,20.5),(8,20.5)],'#547168')
    a.l([(10,14),(w-16,14)],'#a0a47f',.5)
    sheet(a,15 if desk else 29,10.5,18 if desk else 26,8)
    if desk:
        brass_lamp(a,w-16,17)
        a.r(4,15,8,4,'#6d4c37');a.r(5,14,7,3,'#987451')
        a.r(7,11,2,4,'#493b36');oval(a,6,10,4,2,'#79634c')
    else:
        for i,c in enumerate(['#65505a','#54665f','#8e5949']):
            x=8+i%2; y=17-i*3
            a.r(x,y,14,2.5,c);a.r(x+1,y+.5,12,1,'#dac39c')
        a.poly([(61,12),(73,13),(72,19),(60,18)],'#c2a47f')
        a.poly([(60,11),(73,12),(71,17),(59,16)],'#e8d5ae')
        a.l([(62,13),(68,14)],'#ab9879',.5)
        oval(a,67,14.5,3,2,'#985149')
        a.r(78,13,6,5,'#363742');a.r(79,12,4,2,'#695955')
        a.r(78.5,14,1,2,'#a9bac1')
        a.poly([(81,12),(82,7),(87,2),(90,1),(88,7),(84,10)],'#e1ca9c')
        a.l([(80,15),(84,8),(89,2)],'#8b7559',.5)


def chair(a,tea):
    fresh(a)
    cloth=(133,77,83) if tea else (75,105,88)
    for x in (12,32):leg(a,x,28,13,3)
    crest=[(10,26),(10,9),(12,5),(17,4),(20,2.5),(27,2.5),(31,4),(34,4.5),(37,8),(36,26)]
    a.poly(crest,'#513a30')
    a.l(crest[1:-1],'#b48a5c',1.5)
    a.poly([(13,24),(13,9),(15,6.5),(20,6),(23,4.5),(27,5),(32,7),(34,9),(33,24)],tint(cloth,-15))
    for i in range(12):
        oval(a,13+i*.28,6.5+i*.15,21-i*.7,18-i*.55,tint(cloth,i*1.35-6))
    for cx,cy in [(19,11),(29,11),(24,16),(19,21),(29,21)]:
        for dx,dy in [(-4,-3),(4,-3),(-4,3),(4,3)]:
            a.l([(cx+dx,cy+dy),(cx,cy)],tint(cloth,-12),.5)
        a.r(cx,cy,1,1,tint(cloth,-27));a.r(cx+.5,cy+1,1,.5,tint(cloth,29))
    for side in (11.5,35):
        for y in (8,11,14,17,20,23):a.r(side,y,.5,.5,'#dfbd80')
    a.poly([(12,24),(34,24),(37,28),(36,31),(12,32),(10,29)],'#50443b')
    a.poly([(13,24),(33,24),(36,28),(33,29),(13,29),(11,28)],tint(cloth,11))
    a.l([(12,29),(16,30),(33,30),(36,28.5)],tint(cloth,27),.5)
    if not tea:
        a.r(38,34,8,4,'#664c3e');a.r(38,32,7,2.5,'#80515a');a.r(39,33,6,1,'#dbc69f')


def tea_tray(a):
    fresh(a)
    leg(a,9,30,12,3);leg(a,36,30,12,3)
    oval(a,3,24,42,11,'#50392f');oval(a,3,22,42,11,'#936646')
    oval(a,3,21,42,10,'#c0986a');oval(a,6,22,36,7,'#b4895e')
    a.poly([(12,22),(27,21.5),(32,30),(16,31)],'#e4d4ad')
    a.l([(16,29.5),(31,28.5)],'#b5a17d',.5)
    for x in range(17,32,2):a.r(x,30,.5,1,'#bca480')
    # Shallow saucer, glazed cup, tea surface; the teapot spout clears the rim.
    oval(a,8,25,9,2.5,'#59645b');oval(a,8,24.5,9,2,'#ded6b3')
    oval(a,10,22,5,4,'#8da9a2');oval(a,10,21.5,5,1.5,'#f4dfb0')
    oval(a,11,22,3,.8,'#8b5132');a.l([(15,22.5),(16,22.5),(16,24),(14.5,24)],'#b4c5b5',.5)
    a.l([(36,19),(39,18),(40,20),(39,22),(36,23)],'#3f685f',1.5)
    a.poly([(29,20),(25,16),(24,16),(26,21),(31,24)],'#729687')
    oval(a,28,16,10,9,'#42665b');oval(a,28.5,16,8,7,'#83a393')
    oval(a,29.5,17,3,4,'#b5c4a5');oval(a,30,15,6,2,'#486f66')
    a.r(32.5,14,1.5,1.5,'#d6bb85')


def potted_plant(a,lush):
    fresh(a)
    # Back leaves are cool; lit leaves curl around a lighter midrib.
    leaves=[(12,24,-9,-5),(15,21,9,-5),(14,17,-8,-7),(14,13,8,-7),(13,10,-2,-8)]
    if lush: leaves += [(14,22,5,-12),(13,17,-10,-2),(15,13,9,-3)]
    for i,(x,y,dx,dy) in enumerate(leaves):
        tip=(x+dx,y+dy); mx=x+dx*.52;my=y+dy*.55
        nx=-dy*.23;ny=dx*.23
        a.l([(14,29),(x,y),tip],'#4b5c43',.8)
        a.poly([(x,y),(mx+nx,my+ny),tip,(mx-nx,my-ny)],'#375449')
        a.poly([(x,y),(mx+nx,my+ny),tip,(mx,my)],['#6e926d','#84a17c','#678e70'][i%3])
        a.l([(x,y),(mx,my),tip],'#adc093',.5)
    for j in range(10):
        w=16-j*.45
        a.r(14-w/2,28+j,w,1,'#76503b')
        a.r(14-w/2+1,28+j,w-4,1,'#b88359')
        a.r(14-w/2+2,28+j,2,1,'#c89569')
    oval(a,4,25.5,20,5,'#856046');oval(a,4,25,20,4,'#d4a779')
    oval(a,6,25.5,16,2,'#513c33');a.r(13,24,1.5,3,'#5f734d')
    a.l([(9,36),(11,37),(18,37),(20,36.5)],'#8e634b',.5)


def glazing(a):
    # Four separate panes keep the muntins intact. A low tree line gives the
    # opening depth, with daylight catching just one fold on each drape.
    for left,right in [(7,22),(25,41)]:
        for top,bottom in [(6,23),(26,39)]:
            for y in range(top,bottom):
                for x in range(left,right):
                    hills=30+2*math.sin(x*.23)+1.5*math.sin(x*.52)
                    c=(100+y*1.5,148+y,160+y*.55)
                    if y>hills:c=(108,140,126)
                    if y>hills+3:c=(73,108,98)
                    a.r(x,y,1,1,tuple(int(v) for v in c))
            a.l([(left,top),(left,bottom-.5)],'#718b87',.5)
            a.r(left+1,top+1,right-left-2,.5,'#c3d9c7')
    for sx in (1,-1):
        x=2 if sx==1 else 45
        def pt(u,v): return (x+sx*u,v)
        a.poly([pt(0,3),pt(9,3),pt(7,14),pt(3,23),pt(5,33),pt(0,36)],'#45655e')
        for u in (2,4,6):
            a.l([pt(u,4),pt(u-.5,12),pt(1+u*.2,23)],'#789581',1)
        a.l([pt(0,22),pt(3.5,22),pt(4.5,24)],'#d6b77d',1)
        a.l([pt(1,24),pt(2.5,30),pt(2,33)],'#8ca38b',.5)


def finish(a,name):
    if name.startswith('shelf_'): shelves(a,name)
    elif name.startswith('rug_'): textile(a,name)
    elif name in ('work_table','lending_desk'): table(a,name=='lending_desk')
    elif name in ('tea_back','chair_back'): chair(a,name=='tea_back')
    elif name=='tea_front': tea_tray(a)
    elif name.startswith('plant_'): potted_plant(a,name=='plant_lush')
    elif name=='window_clear': glazing(a)
    elif name=='chair_front':
        fresh(a)
        for x in (9,35):
            leg(a,x,25,14,3)
            a.poly([(x-1,24),(x+.5,20),(x+2,20),(x+3.5,23),(x+2,26),(x,26)],'#6e4a35')
            a.l([(x,23.5),(x+1,21),(x+2,21)],'#d3a673',1)


def light_floor(a,stage):
    """Cast a raked four-pane window across floorboards, under rugs and actors."""
    import numpy as np
    k=a.density
    x,y=np.meshgrid(np.arange(8*k,444*k)/k,np.arange(54*k,281*k)/k)
    depth=y-54
    u=x+depth*.72-322
    attenuation=.88*np.exp(-depth/81)
    panes=(u>=0)&(u<=40)&(abs(u-20)>1.5)&(abs(depth-40)>2)&(depth<93)
    light=panes*attenuation*(.12 if stage<2 else 1)
    # Quantized exposure preserves the pixel edges of the timber.
    light=np.round(light*9)/9
    edge=6*np.exp(-np.minimum(x-8,444-x)/12)+12*np.exp(-depth/8)
    patch=a.im.crop((8*k,54*k,444*k,281*k))
    vals=np.array(patch).astype(float)
    for j,gain in enumerate((35,31,19)):
        vals[:,:,j]=np.clip(vals[:,:,j]+gain*light-edge,0,255)
    a.im.paste(Image.fromarray(vals.astype('uint8')), (8*k,54*k))


def cast(a,x,y,w,h):
    # Two stepped penumbra bands, oriented away from the upper right window.
    shadow=Image.new('RGBA',a.im.size)
    d=ImageDraw.Draw(shadow);k=a.density
    for inset,alpha in [(0,28),(1.5,39)]:
        pts=[(x-5+inset,y+h),(x+1,y+3),(x+w-inset,y+2),(x+w-4,y+h-1),(x+w-10,y+h+2),(x-5+inset,y+h+2)]
        d.polygon([(round(u*k),round(v*k)) for u,v in pts], fill=(44,32,39,alpha))
    a.im.alpha_composite(shadow)
