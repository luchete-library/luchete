"""Authored scene clusters and floor zoning for the six story maps.

Items have explicit small foot collisions and are Y-sorted at runtime. Routes,
clues and the librarian's walk are protected when placing tall decoration.
"""
import json, math
from pathlib import Path
from PIL import ImageColor

ROOT=Path(__file__).resolve().parents[1]
ITEMS={}


def asset(Pixel,save,name,w,h,anchor,paint,foot=None):
    p=Pixel(w,h);paint(p);save(p,'decor_'+name,anchor)
    ITEMS[name]={'asset':'decor_'+name,'size':[w,h],'anchor':list(anchor),'foot':foot}


def crate(p,x,y,w=18,h=15):
    p.r(x,y,w,h,'wood0');p.r(x+1,y+1,w-2,h-2,'wood2')
    for i in range(3):p.r(x+2,y+2+i*(h-3)/3,w-4,.5,'wood4')
    p.l([(x+2,y+2),(x+w-3,y+h-3)],'wood1',2)
    p.r(x+1,y+1,1,h-2,'wood3');p.r(x+w-2,y+1,1,h-2,'wood3')
    for dx in [2,w-3]:
        for dy in [2,h-3]:p.r(x+dx,y+dy,.5,.5,'goldhi')


def bowl(p,x,y):
    p.poly([(x-6,y),(x+6,y),(x+4,y+5),(x-4,y+5)],'wood1')
    p.r(x-6,y,12,1,'wood4');p.r(x-3,y+1,6,1,'paperlo')


def foliage(p,x,y,flower=False):
    for dx,dy in [(-4,1),(2,0),(-1,-4)]:
        p.poly([(x,y+3),(x+dx-2,y+dy),(x+dx,y+dy-2),(x+dx+2,y+dy),(x,y+4)],'green2')
        p.l([(x,y+3),(x+dx,y+dy-1)],'greenhi',.5)
    if flower:p.r(x-1,y-5,3,2,'rose2');p.r(x,y-6,1,4,'paperhi');p.r(x,y-5,1,1,'gold')


def make_assets(Pixel,save):
    def supplies(p):
        crate(p,4,18,23,17);crate(p,25,25,19,13);crate(p,8,6,16,12)
        for x,y in [(32,15),(42,24)]:
            p.poly([(x-5,y+16),(x-7,y+5),(x-3,y+1),(x-4,y-3),(x+4,y-3),(x+3,y+1),(x+7,y+6),(x+5,y+16)],'paperlo')
            p.l([(x-4,y+1),(x+4,y+1)],'wood1',1);p.l([(x-3,y+4),(x-4,y+11)],'paperhi',1)
        bowl(p,12,35)
    asset(Pixel,save,'supplies',52,44,(26,39),supplies,[-21,-7,44,11])
    def flowers(p):
        p.r(3,25,51,9,'wood0');p.r(4,26,49,6,'wood2');p.r(3,25,51,1,'wood4')
        p.r(6,32,2,5,'wood1');p.r(49,32,2,5,'wood1')
        for x in range(8,51,7):foliage(p,x,22-x%3,True)
    asset(Pixel,save,'flowers',58,38,(29,34),flowers,[-26,-5,52,8])
    def logs(p):
        for x,y in [(5,25),(13,15),(22,25)]:
            p.poly([(x,y),(x+26,y-3),(x+29,y),(x+27,y+8),(x+1,y+10)],'wood0')
            p.r(x+2,y+1,24,5,'wood2');p.r(x+6,y+2,17,.5,'wood4')
            p.r(x,y+1,7,8,'wood4');p.r(x+1,y+2,5,6,'wood2');p.r(x+2,y+3,3,4,'wood4');p.r(x+3,y+4,1,2,'wood1')
        foliage(p,49,29)
    asset(Pixel,save,'logs',56,39,(28,35),logs,[-24,-9,48,13])
    def well(p):
        for x in [9,38]:p.r(x,10,3,36,'wood0');p.r(x+1,11,1,32,'wood3')
        p.poly([(3,14),(24,2),(47,14),(46,18),(3,18)],'wood0')
        p.poly([(6,14),(24,4),(43,14)],'wood3')
        for y in [9,12]:p.r(17-(y-9)*2,y,14+(y-9)*4,.5,'wood4')
        p.r(8,36,35,15,'#716d6a');p.r(6,33,39,5,'#c2b49b');p.r(10,34,31,2,'#484c4d')
        for y in [39,45]:
            p.r(9,y,33,.5,'#ac9d88')
            for x in range(12+(y%2)*4,42,9):p.r(x,y-4,.5,4,'#4d5352')
        p.l([(25,16),(25,35)],'gold0',.5);p.r(22,29,7,6,'wood2');p.r(22,29,7,1,'gold')
    asset(Pixel,save,'well',50,55,(25,50),well,[-20,-14,40,16])
    def market(p):
        for x in [6,56]:p.r(x,18,3,37,'wood1');p.r(x+.5,18,.5,35,'wood4')
        p.poly([(4,7),(59,7),(66,23),(1,23)],'rose0')
        for x in range(5,60,10):p.poly([(x,8),(x+5,8),(x+7,21),(x-2,21)],'paperlo')
        p.r(1,22,64,3,'rose1');p.r(3,22,60,.5,'rose2')
        p.r(4,37,58,6,'wood0');p.r(5,37,56,2,'wood3')
        crate(p,11,42,18,13);crate(p,36,42,19,13)
        for x in [14,24,34,44,54]:bowl(p,x,32)
        for x in [13,23,43]:p.r(x,30,3,2,'gold')
    asset(Pixel,save,'market',68,59,(34,55),market,[-30,-12,60,15])
    def laundry(p):
        for x in [3,63]:p.r(x,3,2,36,'wood1');p.r(x+.5,4,.5,33,'wood4')
        p.l([(4,8),(32,13),(64,8)],'paperlo',.5)
        for x,c in [(12,'blue1'),(29,'paper'),(46,'rose1')]:
            p.poly([(x,11),(x+12,12),(x+11,29),(x+2,28)],c)
            p.r(x+3,14,.5,11,'paperlo');p.r(x+1,10,1,3,'wood2');p.r(x+10,11,1,3,'wood2')
    asset(Pixel,save,'laundry',70,42,(35,38),laundry,[-33,-3,66,5])
    def lantern(p):
        p.r(12,7,3,45,'wood0');p.r(13,9,1,40,'wood3');p.r(8,50,12,3,'wood1')
        p.l([(14,8),(22,8),(24,12)],'wood1',2)
        p.r(18,14,12,18,'wood0');p.r(20,16,8,13,'gold');p.r(21,17,5,10,'paperhi')
        p.r(23,16,1,14,'gold0');p.r(19,23,10,1,'gold0');p.r(17,13,14,2,'wood2')
    asset(Pixel,save,'lantern',34,56,(14,52),lantern,[-5,-4,11,8])
    def shelf(p):
        p.r(3,3,54,47,'wood0');p.r(5,5,50,42,'wood1')
        for y in [19,36,47]:p.r(3,y,54,3,'wood2');p.r(4,y,52,.5,'wood4')
        for x in [3,54]:p.r(x,3,3,50,'wood2');p.r(x+.5,4,.5,46,'wood4')
        for y in [9,26]:
            for x in range(9,51,8):
                p.r(x,y,6,10,'paperlo' if x%3 else 'blue1');p.r(x+.5,y+.5,5,.5,'paperhi')
                p.r(x+2,y+4,2,2,'wood2')
        crate(p,10,39,17,8);p.r(35,39,14,7,'purple0');p.r(36,40,12,1,'gold')
    asset(Pixel,save,'rack',61,56,(30,51),shelf,[-27,-8,54,11])
    def arrows(p):
        crate(p,6,28,25,19)
        for i in range(7):
            x=8+i*4;y=6+i%3*3
            p.l([(x+1,30),(x+4,y)],'gold',.5)
            p.poly([(x+2,y+2),(x,y-1),(x+2,y-3),(x+4,y-1),(x+6,y-3),(x+7,y),(x+4,y+4)],'rose1')
            p.r(x+2,25,2,5,'paper')
    asset(Pixel,save,'arrow_bin',40,51,(20,47),arrows,[-15,-9,30,11])
    def spool(p):
        for x,y in [(11,25),(29,20),(20,38)]:
            p.r(x-5,y-8,10,14,'paperlo');p.r(x-6,y-9,12,2,'wood2');p.r(x-6,y+6,12,2,'wood1')
            for yy in range(y-6,y+6,2):p.r(x-5,yy,10,.5,'paperhi')
        p.l([(33,24),(39,29),(36,38)],'gold',.5)
    asset(Pixel,save,'spools',44,48,(22,44),spool,[-18,-7,36,10])
    def dream_arch(p):
        for x in [6,55]:
            p.r(x,20,7,48,'purple0');p.r(x+1,21,4,46,'purple1');p.r(x+1,22,.5,42,'purple2')
            for y in [33,48,62]:p.r(x,y,7,1,'gold0')
        p.poly([(5,23),(14,8),(34,0),(55,8),(65,23),(60,27),(51,13),(34,6),(18,13),(10,27)],'purple1')
        p.l([(9,21),(18,10),(34,3),(53,11),(61,22)],'gold',.5)
        for x,y in [(16,15),(34,5),(53,15)]:p.star(x,y,2,'paperlo')
        p.r(3,67,13,3,'purple2');p.r(52,67,13,3,'purple2')
    asset(Pixel,save,'dream_arch',70,73,(35,69),dream_arch,[-31,-5,62,8])
    def floating(p):
        p.poly([(2,18),(12,12),(41,12),(53,18),(42,24),(27,35),(13,24)],'purple0')
        p.poly([(3,18),(14,13),(40,13),(51,18),(40,23),(15,23)],'purple1')
        p.l([(7,17),(16,14),(38,14),(46,17)],'purple2',.5)
        for x in [16,34]:
            p.r(x,6,9,11,'paperlo');p.r(x+1,6,8,10,'paper')
            for y in [8,11,14]:p.r(x+3,y,4,.5,'purple1')
        p.star(28,7,2,'gold')
    asset(Pixel,save,'dream_island',57,39,(28,34),floating,[-21,-11,42,13])
    def curtain(p):
        p.r(2,3,48,2,'gold0')
        for x in [4,35]:
            p.poly([(x,6),(x+12,6),(x+10,25),(x+6,43),(x+1,47)],'purple1')
            for dx in [2,5,8]:p.l([(x+dx,7),(x+dx-1,25),(x+2,42)],'purple2',.5)
            p.r(x+2,28,7,2,'gold')
        p.l([(27,5),(27,23)],'gold',.5);p.star(27,25,3,'paperhi')
    asset(Pixel,save,'dream_curtain',55,51,(27,47),curtain,[-25,-2,50,4])
    def snowbank(p):
        p.poly([(1,30),(5,18),(18,12),(24,5),(46,8),(61,16),(71,31),(62,37),(12,37)],'#899fae')
        p.poly([(2,29),(7,18),(19,14),(25,7),(44,10),(60,18),(67,28),(56,31),(25,28),(12,33)],'#dbe5df')
        p.l([(8,20),(20,15),(26,9),(42,12)],'#f2f0e2',1)
        p.l([(20,30),(34,33),(58,32)],'#b6cbd0',.5)
    asset(Pixel,save,'snowbank',74,41,(37,36),snowbank,[-29,-10,58,12])
    def ice(p):
        p.poly([(3,42),(8,24),(17,11),(24,5),(39,12),(47,33),(44,44)],'#566c82')
        p.poly([(5,40),(10,24),(24,7),(25,29),(19,42)],'#97b8c1')
        p.poly([(25,8),(38,14),(45,33),(33,39),(25,29)],'#739aaf')
        p.l([(10,24),(24,9),(24,27),(19,38)],'#d0dfd7',.5)
        p.l([(27,12),(35,16),(40,29)],'#a7c6ce',.5)
        p.r(4,42,40,1,'#d8e4dd')
    asset(Pixel,save,'ice_rock',52,48,(26,44),ice,[-22,-9,44,12])
    def stone_lamp(p):
        p.r(10,37,19,4,'#748286');p.r(13,23,12,14,'#9aa8a5');p.r(14,24,2,10,'#c9d1c3')
        p.r(10,13,19,11,'#637380');p.r(14,15,11,7,'gold');p.r(16,16,6,5,'paperhi')
        p.poly([(6,14),(13,5),(25,5),(33,14)],'#8599a3');p.l([(8,12),(14,6),(25,6),(30,12)],'#edf0df',2)
        p.r(18,2,3,4,'#d9e2d9');p.r(9,37,21,1,'#d9e2d9')
    asset(Pixel,save,'stone_lamp',38,44,(19,40),stone_lamp,[-11,-4,22,8])
    def sign(p):
        p.r(16,10,3,30,'wood0');p.r(17,11,1,28,'wood3')
        p.poly([(4,10),(28,10),(35,16),(28,22),(4,22)],'wood1');p.l([(5,11),(28,11),(32,15)],'wood4',.5)
        p.l([(11,16),(25,16),(22,14),(25,16),(22,18)],'paperlo',.5)
        foliage(p,26,35)
    asset(Pixel,save,'sign',39,43,(18,39),sign,[-4,-4,8,8])
    def fence(p):
        for x in [3,31,59]:
            p.poly([(x,3),(x+2,0),(x+4,3),(x+4,29),(x,29)],'wood1');p.r(x+.5,4,1,22,'wood4')
        for y in [7,20]:p.r(3,y,60,3,'wood2');p.r(4,y,58,.5,'wood4')
    asset(Pixel,save,'fence',67,32,(33,28),fence,[-31,-3,62,5])
    return ITEMS


def placements():
    # World-space cluster anchors. Large props sit to the sides of the main route.
    maps={
      'yato':[('supplies',155,402,1.7),('logs',310,326,1.7),('flowers',680,340,1.5),('fence',310,408,1.5),('sign',650,520,1.6),('logs',190,660,1.6),('flowers',531,652,1.7),('supplies',824,575,1.5)],
      'danming':[('rack',140,363,1.8),('rack',805,335,1.8),('arrow_bin',268,360,1.6),('spools',690,337,1.6),('rack',143,586,1.7),('supplies',837,620,1.7),('spools',572,594,1.8),('arrow_bin',625,647,1.6),('lantern',872,457,1.4)],
      'dori':[('market',135,396,1.7),('laundry',410,350,1.5),('well',694,356,1.6),('flowers',185,570,1.5),('supplies',530,635,1.6),('lantern',839,516,1.6),('flowers',745,640,1.7),('sign',480,425,1.5)],
      'kubby':[('ice_rock',125,396,1.5),('supplies',360,350,1.5),('lantern',703,335,1.6),('ice_rock',839,440,1.7),('snowbank',235,671,1.5),('ice_rock',565,641,1.4),('stone_lamp',772,612,1.5),('logs',154,504,1.3)],
      'yune':[('dream_arch',827,367,1.6),('dream_curtain',160,390,1.7),('dream_island',338,339,1.7),('dream_island',223,644,1.5),('dream_curtain',817,631,1.6),('dream_island',563,646,1.6),('flowers',643,562,1.4),('dream_island',891,496,1.2)],
      'fuwa':[('snowbank',143,395,1.8),('stone_lamp',339,333,1.6),('snowbank',703,328,1.5),('ice_rock',850,435,1.6),('stone_lamp',665,575,1.5),('snowbank',235,671,1.7),('snowbank',543,644,1.6),('stone_lamp',834,618,1.5)],
      'garden':[('flowers',358,286,1.7),('flowers',831,329,1.6),('well',659,371,1.5),('logs',128,440,1.5),('supplies',368,661,1.5),('sign',683,541,1.5),('flowers',835,679,1.3)]}
    result={}
    for name,items in maps.items():
        for scene in range(4) if name!='garden' else [0]:
            selected=list(items)
            if name=='dori' and scene==3:selected=list(maps['danming']);selected=[('rack' if k=='arrow_bin' else k,x,y,s) for k,x,y,s in selected]
            if name=='yato' and scene>=2:selected+= [('lantern',673,399,1.5),('supplies',850,375,1.3)]
            if name=='kubby' and scene<2:selected+=[('market',142,341,1.3)]
            if name=='yune' and scene>=2:selected=[v for v in selected if v[0]!='flowers']
            key=name if name=='garden' else f'{name}_{scene}'
            result[key]=[dict(kind=k,pos=[x,y],scale=s) for k,x,y,s in selected]
    return result


def enrich_plate(p,member,scene=0,comic=False):
    """Broad walkable ground zones. Tall objects are separate runtime sprites."""
    if comic:return
    def coord(x,y):return ((x-32)/2,(y-140)/2)
    def road(points,color,width):
        k=p.density;radius=width/4
        pts=[coord(x,y) for x,y in points]
        p.d.line([(round(x*k),round(y*k)) for x,y in pts],fill=color,width=round(width*k/2),joint='curve')
        # Filled round joins avoid triangular gaps between wide diagonal segments.
        for x,y in pts:p.d.ellipse((round((x-radius)*k),round((y-radius)*k),round((x+radius)*k),round((y+radius)*k)),fill=color)
        rgb=ImageColor.getrgb(color)
        light='#%02x%02x%02x'%tuple(min(255,v+8) for v in rgb)
        dark='#%02x%02x%02x'%tuple(max(0,v-6) for v in rgb)
        for i,((ax,ay),(bx,by)) in enumerate(zip(pts,pts[1:])):
            dist=math.hypot(bx-ax,by-ay);steps=max(1,int(dist/5));nx,ny=-(by-ay)/dist,(bx-ax)/dist
            for j in range(steps):
                t=j/steps;offset=((j*17+i*7)%23-11)*radius/15
                x=ax+(bx-ax)*t+nx*offset;y=ay+(by-ay)*t+ny*offset
                p.r(round(x*2)/2,round(y*2)/2,1+j%3,.5,light if j%3 else dark)
    if member in ['dori','kubby','yato']:
        pts=[(155,620),(244,548),(390,530),(494,423),(622,409),(800,477)]
        color={'dori':'#b5a28a','kubby':'#8d9ba0','yato':'#8b9170'}[member]
        road(pts,'#776e63' if member=='dori' else '#61756a' if member=='yato' else '#687e89',66)
        road(pts,color,59)
        for x,y in [(280,562),(482,461),(690,459)]:
            a,b=coord(x,y);p.l([(a-6,b),(a+6,b+1)],'#c6b99a' if member!='kubby' else '#b7c8c7',.5)
        if member=='dori' or member=='kubby':
            road([(202,336),(202,392),(345,420),(422,440)],color,40)
    elif member=='danming':
        for x,y,w,h in [(90,301,260,304),(651,291,235,340)]:
            a,b=coord(x,y);p.r(a,b,w/2,h/2,'#806650');p.r(a+2,b+2,w/2-4,h/2-4,'#a68c70')
            p.r(a+3,b+4,w/2-6,1,'#c6af88');p.r(a+3,b+h/2-5,w/2-6,1,'#c6af88')
            for yy in range(int(b)+10,int(b+h/2)-7,8):p.r(a+3,yy,w/2-6,.5,'#998268')
    elif member=='yune':
        for i,(x,y) in enumerate([(170,485),(720,425),(420,655)]):
            a,b=coord(x,y);col='#504c6a' if scene<2 else '#393c53'
            for r in range(4):
                p.poly([(a-38+r*4,b-6+r*2),(a-21,b-16+r*2),(a+25,b-14+r*2),(a+43-r*4,b),(a+22,b+9-r),(a-25,b+10-r)],col)
            for j in range(9):p.r(a-25+(j*11)%50,b-5+(j*7)%13,4,.5,'#857b9b' if scene<2 else '#5a5873')
        for x in range(110,875,37):
            a,b=coord(x,260);p.l([(a,b),(a+7,b+4),(a+15,b)],'#8b7f9a',.5)
    elif member=='fuwa':
        for points in [[(70,355),(160,324),(260,353)],[(625,274),(754,310),(903,290)],[(72,579),(165,560),(251,601)],[(609,679),(724,644),(908,652)]]:
            road(points,'#aec5d0',56);road([(x,y-5) for x,y in points],'#e1e9e3',46)
        road([(170,601),(275,581),(433,499),(508,409),(634,394),(769,457)],'#b8ced4',30)
    elif member=='garden':
        for x,y,w,h in [(215,250,230,60),(710,650,162,35)]:
            a,b=coord(x,y);p.r(a,b,w/2,h/2,'#53694e')
            for i in range(6):
                xx=a+4+i*(w/2-8)/6;p.r(xx,b+3,5,h/2-6,'#796e4f')
                for yy in range(int(b)+5,int(b+h/2)-3,5):foliage(p,xx+2,yy)
        for x,y in [(187,350),(708,448),(555,590)]:
            a,b=coord(x,y)
            for j in range(9):foliage(p,a+(j*13)%35,b+(j*7)%14,j%3==0)


def write_layout():
    (ROOT/'assets/world_pixels/dressing.json').write_text(json.dumps({'items':ITEMS,'maps':placements()},ensure_ascii=False,indent=2),encoding='utf-8')
