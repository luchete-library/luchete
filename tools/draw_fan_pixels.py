"""Native 64 px mascots drawn against six verified video references.

Coordinates, palettes and poses are hand-authored here, not downsampled images.
See artifacts/fan_reference_check/sources.json. Preserve the complete silhouette
in every pose; never deform image rows or independently scale face/body parts.
"""
from pathlib import Path
import json
from contextlib import contextmanager
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/fans'
ART = ROOT / 'artifacts'
IDS = ['yato', 'danming', 'kubby', 'yune', 'dori', 'fuwa']
NAMES = ['마토', '버리', '햄님', '몽치', '돌돌이', '텐비']
LABELS = ['흰 토끼 · 남색 옷과 노란 깃', '둥근 벌 · 분홍 날개', '민트색 부유체 · 배 속 빛',
          '둥근 검은 몸 · 보라 꼬리', '롤러 얼굴 · 줄무늬 꼬리', '흰 통몸 · 이마 소용돌이']
SIZE = 64
ANCHOR = (32, 58)
LIGHT = '#fff6df'
FRAME_COUNT = 44
DIRECTIONS = ['down', 'left', 'right', 'up']
ANIMATIONS = {'still':[0], 'blink':[1], 'walk':[f for i in range(8) for f in (2+i,28+i)],
              'run':[f for i in range(8) for f in (10+i,36+i)], 'idle':list(range(18,24)),
              'start':[24,25], 'stop':[26,27]}
MOTION = {
    'yato':dict(walk_stride=104,run_stride=128,walk_fps=0,run_fps=0,shadow_width=12),
    'danming':dict(walk_stride=110,run_stride=130,walk_fps=16,run_fps=22,shadow_width=13),
    'kubby':dict(walk_stride=120,run_stride=144,walk_fps=6,run_fps=9,shadow_width=16),
    'yune':dict(walk_stride=92,run_stride=112,walk_fps=0,run_fps=0,shadow_width=14),
    'dori':dict(walk_stride=88,run_stride=108,walk_fps=0,run_fps=0,shadow_width=12),
    'fuwa':dict(walk_stride=108,run_stride=132,walk_fps=0,run_fps=0,shadow_width=13),
}


def pose_for(member, frame):
    """Whole torso/head translation and overlapping rigid appendages only."""
    if frame >= 28:
        step=(frame-28)%8
        first=2 if frame<36 else 10
        a=pose_for(member,first+step)
        b=pose_for(member,first+(step+1)%8)
        result={}
        for key,value in a.items():
            if isinstance(value,tuple):
                result[key]=tuple(round((x+y)/2) for x,y in zip(value,b[key]))
            elif key=='shadow':
                result[key]=(value+b[key])/2
            else:
                result[key]=round((value+b[key])/2)
        return result
    p=dict(body=(0,0),wing=0,wisp=0,shadow=1.0)
    if frame in [0,1]: return p
    floating=member in ['danming','kubby']
    if frame>=24:
        first=frame in [24,26]
        p['body']=(0,(-1 if first else -2) if floating else (1 if first else 0))
        p['ears']=(0,-1 if first else 0)
        p['tail']=(1 if first else 0,0)
        p['wing']=5 if first else -1
    elif frame>=18:
        i=frame-18
        if member=='danming':
            p.update(body=(0,[-2,-2,-3,-3,-2,-1][i]),wing=[-2,1,5,6,2,-1][i])
            p['antenna']=(0,[0,0,1,1,0,-1][i])
        elif member=='kubby':
            p.update(body=(0,[-2,-3,-4,-4,-3,-2][i]),wisp=[0,1,1,0,-1,-1][i])
            p['glow']=(0,[0,1,1,0,-1,0][i])
            p['left_hand']=(0,[0,-1,-1,0,1,0][i]); p['right_hand']=(0,[0,0,-1,-1,0,0][i])
        else:
            p['ears']=(0,[0,-1,-1,0,0,0][i])
            p['tail']=([0,1,1,0,-1,0][i],[0,0,-1,-1,0,0][i])
            if member in ['yune','fuwa']:
                p['left_hand']=(0,[0,-1,-1,0,0,0][i])
    else:
        running=frame>=10
        i=frame-(10 if running else 2)
        if member=='danming':
            p.update(body=([0,0,1,1,0,0,-1,-1][i],[-2,-3,-4,-4,-3,-2,-1,-1][i]),
                     wing=[-2,0,4,6,4,0,-2,2][i])
            p['antenna']=([0,0,1,1,0,0,-1,-1][i],0)
            p['tuck']=(0,-1 if running else 0)
        elif member=='kubby':
            p.update(body=(0,[-1,-1,-2,-3,-4,-4,-3,-2][i]),wisp=[-1,0,1,2,1,0,-1,-2][i])
            p['glow']=(0,[0,1,1,1,0,-1,-1,0][i])
            p['left_hand']=(0,[0,-1,-1,0,1,1,0,0][i])
            p['right_hand']=(0,[1,1,0,0,0,-1,-1,0][i])
        else:
            # Contact / weight / passing / lift, then the opposite foot.
            stride=[-3,-3,-1,1,3,3,1,-1] if running else [-2,-2,-1,1,2,2,1,-1]
            lift=[0,0,-2,-3,-2,0,-1,-2] if running else [0,0,-1,-2,-1,0,0,0]
            body_y=[0,1,-1,-3,-2,0,-1,-3] if running else [0,1,0,-1,0,1,0,-1]
            p['body']=([0,-1,0,1,0,1,0,-1][i],body_y[i])
            p['left_foot']=(stride[i],lift[i])
            p['right_foot']=(stride[(i+4)%8],lift[(i+4)%8])
            p['left_hand']=(0,[0,1,1,0,-1,-1,0,0][i])
            p['right_hand']=(0,[-1,-1,0,0,0,1,1,0][i])
            p['ears']=(0,[0,-1,0,1,1,0,-1,0][i])
            p['tail']=([0,0,1,1,0,-1,-1,0][i],[0,1,2,1,0,-1,-1,0][i])
            if member=='dori':
                p['body']=(0,body_y[i])
                p['tail']=([0,0,1,2,1,0,-1,-1][i],0)
                for foot in ['left_foot','right_foot']:
                    dx,dy=p[foot]
                    limit=2 if running else 1
                    p[foot]=(max(-limit,min(limit,dx)),dy)
            if min(lift[i],lift[(i+4)%8])<0 and max(lift[i],lift[(i+4)%8])<0: p['shadow']=0.85
    if floating: p['shadow']=round(1+p['body'][1]*0.04,2)
    return p


class Pen:
    def __init__(self, member='', frame=0, direction='down'):
        self.im = Image.new('RGBA', (SIZE, SIZE))
        self.d = ImageDraw.Draw(self.im)
        self.motion=pose_for(member,frame)
        self.back = direction == 'up'
        # Profile feet pass each other along the travel axis. Vertical views
        # retain their width and show a smaller depth step instead of skating.
        if direction == 'up' and member not in ['danming','kubby']:
            for foot in ['left_foot','right_foot']:
                dx,dy=self.motion.get(foot,(0,0))
                self.motion[foot]=(0,dy + (1 if dx>0 else -1 if dx<0 else 0))
        if direction in ['left','right']:
            bx,by=self.motion['body']
            self.motion['body']=(0,by)
        self.offset=self.motion['body']

    def points(self, points):
        dx,dy=self.offset
        return [(x+dx,y+dy) for x,y in points]

    @contextmanager
    def part(self, name):
        previous=self.offset
        dx,dy=self.motion.get(name,(0,0))
        # Feet retain the floor anchor while the connected torso shifts weight.
        bx,by=(0,0) if name.endswith('_foot') else self.motion['body']
        self.offset=(bx+dx,by+dy)
        try: yield
        finally: self.offset=previous

    def layer(self, layer, name):
        with self.part(name): self.im.alpha_composite(layer,self.offset)

    def p(self, points, color, edge=None):
        self.d.polygon(self.points(points), fill=color, outline=edge)

    def r(self, x, y, w, h, color):
        self.d.rectangle(self.points([(x,y),(x+w-1,y+h-1)]), fill=color)

    def l(self, points, color, width=1):
        self.d.line(self.points(points), fill=color, width=width)

    def oval(self, box, color, edge=None):
        self.d.ellipse(self.points([(box[0],box[1]),(box[2],box[3])]), fill=color, outline=edge)

    def dots(self, xs, y, blink, ink, width=3, height=4):
        for x in xs:
            if blink:
                self.l([(x-1,y+1),(x,y+2),(x+width-1,y+2),(x+width,y+1)],ink)
            else:
                self.oval((x,y,x+width-1,y+height-1),ink)


def phase(frame):
    return 0, frame == 1


def rabbit(a, frame):
    step, blink = phase(frame)
    ink, white, shade = '#505469', '#f5f8f4', '#cbd8d9'
    navy, navy_lit, gold, gold_dark = '#374563', '#566986', '#edcc73', '#ac854d'
    # White feet below a navy outfit; no invented front-view tail or crest.
    for x,s,part in [(24,step,'left_foot'),(35,-step,'right_foot')]:
        with a.part(part):
            a.p([(x,51),(x+4,51),(x+4+s,55),(x+3+s,57),(x-1+s,57),(x-2+s,55)],white,ink)
            a.l([(x-1+s,56),(x+2+s,56)],shade)
    a.p([(22,35),(40,35),(44,41),(42,52),(39,55),(24,55),(21,51),(19,41)],navy,ink)
    a.p([(23,41),(29,42),(30,49),(28,52),(24,51),(22,47)],navy_lit)
    a.p([(30,44),(37,43),(40,44),(39,50),(36,53),(29,53),(31,49)],'#415370')
    a.p([(40,43),(42,42),(41,51),(38,54),(25,54),(23,52),(36,52),(39,49)],'#293850')
    a.l([(25,45),(25,48),(26,49)],'#697c95')
    a.l([(34,46),(34,50),(36,51)],'#2d3c56')
    with a.part('left_hand'):
        a.p([(20,36),(23,37),(22,43),(19,45),(16,42),(17,38)],white,ink)
        a.l([(18,38),(21,40),(20,42),(17,40)],gold_dark)
        a.l([(19,38),(22,40)],gold,2)
    with a.part('right_hand'):
        a.p([(42,36),(45,38),(47,42),(44,45),(41,42),(40,38)],white,ink)
        a.l([(42,38),(45,39),(44,42)],gold,2)
    with a.part('ears'):
        a.p([(22,28),(19,16),(19,11),(21,8),(24,8),(27,11),(29,26)],white,ink)
        a.p([(35,26),(36,13),(38,9),(41,8),(44,10),(44,16),(41,29)],white,ink)
        a.l([(23,12),(24,20),(25,24)],'#e0e6e6',2)
        a.l([(40,12),(40,19),(39,24)],'#e0e6e6',2)
        a.l([(21,12),(22,10),(24,10)],'#ffffff')
        a.l([(38,13),(40,10),(41,10)],'#ffffff')
        a.l([(26,14),(27,20),(27,25)],'#b8cbd0')
        a.l([(43,13),(42,20),(40,25)],'#b8cbd0')
    a.p([(25,23),(37,23),(40,25),(42,28),(43,31),(45,33),(45,36),
         (43,38),(39,40),(24,40),(20,38),(18,36),(18,33),(20,30),(21,27),(23,25)],white,ink)
    a.p([(42,30),(44,33),(44,36),(41,38),(37,39),(26,39),(22,37),(21,35),
         (24,36),(28,37),(37,37),(40,35)],shade)
    a.p([(24,26),(28,24),(35,24),(38,26),(29,27),(24,30),(22,32),(21,31)],'#ffffff')
    a.l([(20,34),(20,36),(23,38)],'#adbec8')
    if not a.back:
        a.dots([26,35],29,blink,'#3d4355',2,3)
        a.r(31,33,2,1,'#bb8e9d'); a.r(31,34,1,1,'#967383')
        a.l([(31,35),(30,36),(29,35)],'#697083')
        a.l([(32,35),(33,36),(34,35)],'#697083')
        a.r(23,34,3,1,'#e6c2cc'); a.r(38,34,3,1,'#e6c2cc')
    else:
        a.l([(26,35),(29,36),(34,36),(37,35)],'#e4ece7')
    a.p([(21,38),(26,40),(32,41),(39,39),(43,38),(42,42),(38,44),
         (26,44),(22,42)],gold,gold_dark)
    a.l([(23,39),(28,41),(34,42),(40,40)],'#fff1b6')
    a.l([(24,42),(28,43),(36,43),(39,42)],'#c9a456')
    a.r(26,40,3,1,'#fff6c8'); a.r(38,40,2,1,'#fff0ad')


def bee(a, frame):
    step, blink = phase(frame)
    edge, dark, cream = '#a7744e', '#705a3d', '#fff0bd'
    wing = a.motion['wing']
    # Paired pink wings behind one continuous round front-facing body.
    for mirror in ([] if a.back else [False,True]):
        points=[(19,26),(14,26),(10+wing,28),(8+wing,32),(8+wing,36),
                (10+wing,39),(8+wing,43),(9+wing,48),(12+wing,51),(20,51),(23,42),(23,31)]
        if mirror: points=[(64-x,y) for x,y in points]
        a.p(points,'#f7a79d','#cf7870')
        # Short colour clusters describe the wing fold, not a dark vein network.
        detail=[(12+wing,30),(16,28),(19,28),(18,33),(15,35),(12+wing,35)]
        low=[(11+wing,42),(14+wing,40),(18,41),(19,49),(14+wing,50),(11+wing,47)]
        if mirror:
            detail=[(64-x,y) for x,y in detail]; low=[(64-x,y) for x,y in low]
        a.p(detail,'#ffc6b4'); a.p(low,'#ec9696')
        x=11+wing if not mirror else 52-wing
        a.l([(x,31),(x-1 if not mirror else x+1,34)],'#ffd0b9')
    with a.part('antenna'):
        a.l([(26,23),(24,17),(24,14)],edge,2)
        a.l([(38,23),(40,17),(40,14)],edge,2)
        a.oval((21,10,26,15),'#f5ac79',edge)
        a.oval((38,10,43,15),'#f5ac79',edge)
        a.r(22,11,2,1,'#ffd9a7'); a.r(39,11,2,1,'#ffd9a7')
        a.r(24,14,2,1,'#d78b62'); a.r(41,14,2,1,'#d78b62')
    a.p([(27,20),(37,20),(43,23),(46,28),(47,35),(50,42),(50,47),
         (47,52),(42,55),(36,57),(27,57),(21,55),(17,52),(14,48),(14,43),
         (17,36),(18,29),(21,24)],'#f7cc6c',edge)
    a.p([(27,22),(37,22),(42,25),(45,30),(45,35),(42,37),(23,37),
         (19,35),(20,29),(23,25)],'#ffdc87' if a.back else cream)
    a.p([(43,27),(45,30),(45,35),(42,37),(23,37),(20,35),(24,35),
         (39,35),(42,33)],'#f5dca2')
    a.p([(24,25),(29,23),(35,23),(37,24),(29,25),(24,28),(22,30),(22,27)],'#fff9dc')
    a.l([(18,37),(24,39),(39,39),(46,36)],'#ffe2a0')
    a.l([(47,38),(49,42),(49,46)],'#dbaa5a')
    a.p([(18,40),(24,42),(40,42),(47,40),(49,44),(49,47),(46,51),
         (41,53),(23,53),(18,51),(15,47),(15,44)],dark)
    a.p([(17,44),(21,43),(27,44),(27,49),(23,51),(19,49)],'#836b48')
    a.p([(43,44),(47,43),(48,46),(46,50),(41,52),(27,52),(25,51),(40,50)],'#594c39')
    a.l([(21,44),(24,45),(26,45)],'#937a50')
    a.l([(23,55),(29,56),(36,56),(41,55)],'#ffdf86')
    with a.part('tuck'):
        for x in [22,40]:
            a.oval((x,50,x+3,54),cream,'#c08b54')
            a.r(x+1,51,1,2,'#fff8d5')
    if not a.back:
        a.dots([25,38],28,blink,'#403d2e',2,3)
        a.oval((21,31,25,34),'#f3d7a7'); a.oval((39,31,43,34),'#f3d7a7')
        a.p([(30,30),(34,30),(35,31),(35,33),(33,35),(31,35),(29,33),(29,31)],'#e77453','#ac634c')
        a.r(30,31,4,1,'#ffbb85'); a.r(31,34,2,1,'#f79470')
    else:
        # The wing roots are visible from behind; their lobes keep the same
        # coral palette as the reference and the same flap timing as the front.
        for mirror in [False,True]:
            points=[(31,35),(25,28),(16+wing,26),(11+wing,28),(8+wing,32),
                    (8+wing,36),(11+wing,39),(9+wing,43),(10+wing,47),
                    (14+wing,51),(20,51),(26,46),(29,40)]
            highlight=[(27,34),(21+wing,29),(15+wing,28),(12+wing,31),
                       (12+wing,34),(18+wing,36),(23,37)]
            if mirror:
                points=[(64-x,y) for x,y in points]
                highlight=[(64-x,y) for x,y in highlight]
            a.p(points,'#f7a79d','#cf7870'); a.p(highlight,'#ffc6b4')


def hamster(a, frame):
    step, blink = phase(frame)
    ink, mint, shade = '#547c76', '#b0dcca', '#87bcb3'
    # Bottom is a spirit wisp, never normal feet or a flame above the head.
    a.p([(19,25),(17,20),(17,17),(19,15),(22,15),(25,19),
         (29,18),(36,18),(40,20),(43,16),(46,16),(48,19),(47,25),
         (49,30),(52,34),(54,38),(54,42),(52,46),(49,49),(44,51),
         (40,53),(43+a.motion['wisp'],56),(38,55),(34,56),(29,56),(25,54),
         (22,52),(17,50),(13,47),(11,44),(10,40),(11,36),(14,31),(16,29)],mint,ink)
    a.p([(19,19),(20,17),(22,18),(23,20),(20,23)],'#c6e9d7')
    a.p([(43,20),(45,18),(46,19),(45,24)],'#c6e9d7')
    a.p([(49,32),(52,36),(53,39),(53,43),(50,46),(47,48),(40,51),(36,53),
         (30,54),(25,52),(21,50),(18,49),(16,47),(22,49),(29,51),(36,50),
         (44,47),(48,43),(49,39)],'#9ccfc0')
    a.l([(14,44),(17,48),(23,51),(28,54),(34,55),(38,54)],shade)
    a.l([(20,26),(22,23),(27,21),(33,21)],'#ccebd9')
    a.l([(12,38),(12,41),(14,44)],'#c1e5d2')
    a.l([(46,18),(47,21),(46,24)],'#87b8ad')
    # Soft irregular light surrounds two little pink-violet forms, not a bullseye.
    with a.part('glow'):
        # Rear surface is opaque mint; the pink forms belong inside the belly.
        if a.back:
            a.p([(27,40),(34,39),(39,42),(40,46),(35,50),(28,50),(24,46)],'#abd9c7')
        else:
            hamster_glow(a)
    a.r(29,54,2,1,'#c6e7dc'); a.r(34,54,2,1,'#c6e7dc')
    if not a.back:
        a.dots([24,38],27,blink,'#313e36',3,5)
        a.oval((18,31,24,34),'#f0aab5'); a.oval((40,31,46,34),'#f0aab5')
        a.l([(28,33),(30,33),(32,31),(34,33),(37,33)],ink)
        for x,part in [(20,'left_hand'),(43,'right_hand')]:
            with a.part(part):
                a.l([(x-2,42),(x-2,44),(x-1,45),(x+1,45),(x+2,44),(x+2,42)],'#7caf9e')


def hamster_glow(a):
    a.p([(28,38),(35,38),(39,41),(41,46),(38,51),(32,53),(26,51),(23,47),(24,42)],'#b4d2d0')
    a.p([(29,40),(35,40),(38,42),(39,46),(37,49),(33,51),(28,50),(25,47),(26,43)],'#bfc8dc')
    a.oval((27,43,33,49),'#c49de0')
    a.oval((32,42,37,46),'#d6b4e9')
    a.r(29,43,2,1,'#d4b1e9'); a.r(28,46,2,2,'#bd95d9')
    a.oval((32,40,34,42),'#eadcf4')
    a.oval((33,48,35,50),'#dfc1ee')


def cat(a, frame):
    step, blink = phase(frame)
    edge, coat = '#272631', '#24232d'
    tail_y=1 if step>0 else 0
    with a.part('tail'):
        a.p([(36,48),(42,49),(47,48),(50,50),(50,54),(45,56),(39,55),(35,53)],coat,edge)
        a.oval((43,42+tail_y,55,54+tail_y),'#9d6abb','#654974')
        a.oval((43,38+tail_y,51,47+tail_y),'#b987d1','#8e68a6')
        a.oval((50,37+tail_y,58,46+tail_y),'#cca0e1','#a176ba')
        a.oval((50,44+tail_y,59,52+tail_y),'#ad7cc9','#7f5997')
        a.oval((47,44+tail_y,55,53+tail_y),'#b685cd')
        a.oval((47,40+tail_y,50,43+tail_y),'#dfbcec')
        a.l([(45,47+tail_y),(46,50+tail_y),(49,52+tail_y),(53,52+tail_y)],'#8d60a5')
        a.l([(52,39+tail_y),(54,38+tail_y),(56,39+tail_y)],'#e6c5f0')
        a.r(57,46+tail_y,1,3,'#c499d8')
        for x,y in [(54,42+tail_y),(49,49+tail_y)]:
            a.l([(x-1,y),(x+1,y)],'#ecd0f4'); a.l([(x,y-1),(x,y+1)],'#ecd0f4')
    for x,s,part in [(16,step,'left_foot'),(34,-step,'right_foot')]:
        with a.part(part): a.oval((x+s,51,x+5+s,57),coat,edge)
    # A single fluffy black body with tiny integrated ears.
    a.p([(12,26),(11,17),(12,14),(14,14),(21,19),(25,18),(28,19),(32,18),(35,19),
         (40,15),(42,14),(43,16),(42,26),(44,29),(44,32),(45,35),(44,38),
         (45,41),(44,45),(43,48),(41,51),(38,54),(34,55),(20,55),(16,53),
         (13,51),(11,48),(11,45),(9,42),(10,38),(9,35),(10,31)],coat,edge)
    # Broad soft fur clusters keep the black body readable in the dark library.
    a.p([(14,27),(17,24),(21,23),(27,23),(25,25),(19,27),(16,31),(14,35),
         (14,40),(12,42),(11,38),(11,32)],'#37323f')
    a.p([(41,27),(43,31),(42,35),(43,40),(42,46),(39,50),(34,53),(21,53),
         (17,51),(15,47),(19,49),(25,50),(34,49),(38,46),(40,39)],'#191d25')
    a.p([(22,40),(26,39),(32,40),(36,43),(35,49),(27,51),(22,48),(20,44)],'#2c2733')
    a.p([(13,16),(19,21),(14,24)],'#45404e' if a.back else '#b980cb')
    a.p([(35,22),(41,17),(40,25)],'#383341' if a.back else '#ba82d1')
    a.l([(14,17),(15,21),(17,22)],'#5b4c61' if a.back else '#dfacdf')
    a.l([(39,19),(38,22)],'#4a3f54' if a.back else '#e0b1e8')
    a.l([(13,26),(15,24),(18,23)],'#514352')
    a.l([(11,35),(12,32)],'#4b3d4c')
    a.l([(14,45),(16,48),(19,49)],'#423440')
    a.l([(23,52),(29,53),(33,52)],'#30303a')
    if a.back:
        a.l([(24,27),(27,25),(30,27),(33,26)],'#37313e')
        a.l([(20,40),(22,43),(25,44)],'#35303e')
        # A low, joined tail root seen over the back instead of front paw pads.
        with a.part('tail'):
            a.p([(29,48),(34,49),(41,49),(45,50),(45,54),(39,55),(33,53),(29,51)],coat,edge)
            a.l([(32,49),(36,51),(42,51)],'#45394e')
        return
    for x in [15,31]:
        a.oval((x,32,x+10,39),'#6d5279')
        a.oval((x+1,34,x+9,38),'#b190c6')
        if blink:
            a.l([(x+1,31),(x+2,33),(x+7,33),(x+9,31)],'#dad7e4')
            a.r(x+2,36,2,1,'#ead0eb')
        else:
            a.oval((x+1,25,x+9,36),'#a9a1b7')
            a.oval((x+1,25,x+8,35),'#e4e0e7')
            a.oval((x+2,26,x+7,34),'#3c3948')
            a.l([(x+3,29),(x+6,29)],'#f6eff3')
            a.l([(x+4,27),(x+4,31)],'#f6eff3')
            a.r(x+6,32,1,1,'#cabed6')
            a.r(x+1,36,2,1,'#f2daef')
    a.oval((25,36,31,40),'#d995b0','#9c6c8a')
    a.oval((26,36,30,39),'#efb6cb')
    a.r(27,37,2,1,'#ffdae5')
    for x,part in [(18,'left_hand'),(33,'right_hand')]:
        with a.part(part):
            a.oval((x-2,43,x+4,49),'#161c26')
            a.l([(x-1,47),(x-1,45),(x,43),(x+2,43),(x+3,44)],'#bd9eae')
            a.l([(x+3,45),(x+3,47)],'#826b84')
            a.r(x,46,2,2,'#ce9bb5')
            a.r(x,44,1,1,'#e5baca'); a.r(x+2,44,1,1,'#e5baca')


def roller(a, frame):
    step, blink = phase(frame)
    ink, white, shade = '#485553', '#f7faf5', '#c8d7ce'
    sway=1 if step>0 else 0
    tail=Image.new('RGBA',(64,64)); td=ImageDraw.Draw(tail)
    tail_shape=[(27+sway,29),(26+sway,20),(25+sway,13),(26+sway,8),
                (28+sway,6),(32+sway,6),(35+sway,8),(36+sway,12),
                (35+sway,20),(33+sway,29)]
    td.polygon(tail_shape,fill='#565c5a',outline=ink)
    mask=Image.new('L',(64,64)); ImageDraw.Draw(mask).polygon(tail_shape,fill=255)
    stripes=Image.new('RGBA',(64,64)); sd=ImageDraw.Draw(stripes)
    for y in [13,20,27]:
        sd.polygon([(25+sway,y),(31+sway,y-1),(36+sway,y+1),
                    (35+sway,y+3),(30+sway,y+2),(26+sway,y+3)],fill='#c9cfca')
    stripes.putalpha(Image.composite(stripes.getchannel('A'),Image.new('L',(64,64)),mask))
    tail.alpha_composite(stripes)
    ImageDraw.Draw(tail).line(tail_shape+[tail_shape[0]],fill=ink)
    ImageDraw.Draw(tail).line([(27+sway,11),(28+sway,9),(31+sway,8)],fill='#7c8980')
    ImageDraw.Draw(tail).line([(34+sway,11),(35+sway,15),(34+sway,21),(32+sway,27)],fill='#46524d')
    a.layer(tail,'tail')
    # Tiny body and feet replace the old cleaning-tool handle.
    for x,s,part in [(25,step,'left_foot'),(35,-step,'right_foot')]:
        with a.part(part):
            a.p([(x,50),(x+4,50),(x+4+s,56),(x+2+s,57),(x+s,56)],white,ink)
    a.p([(25,40),(38,40),(39,45),(41,47),(39,48),(39,54),
         (36,55),(27,55),(24,54),(24,48),(22,47),(24,44)],white,ink)
    a.l([(26,53),(29,54),(36,54)],shade)
    a.p([(37,44),(38,46),(38,51),(36,54),(28,54),(26,52),(34,52),(36,50)],'#d9e5db')
    a.l([(26,46),(26,50)],'#ffffff')
    for x in [21,36]:a.oval((x,25,x+6,32),white,ink)
    a.oval((9,30,20,43),'#a7cc7e',ink)
    a.oval((44,30,55,43),'#a7cc7e',ink)
    a.l([(11,35),(17,35),(17,38),(10,38)],'#6e975b')
    a.p([(19,28),(45,28),(49,31),(51,35),(50,39),(47,43),
         (18,43),(14,41),(12,37),(13,33),(16,30)],white,ink)
    a.p([(18,39),(24,40),(42,40),(46,38),(48,37),(48,40),(45,42),(20,42),(16,40)],shade)
    a.l([(19,30),(24,29),(41,29),(44,30)],'#b0c3b6')
    a.l([(20,31),(43,31)],'#ffffff')
    a.l([(18,32),(17,35),(17,37)],'#ffffff')
    a.l([(17,32),(15,35),(15,38),(18,41)],'#9ca99f')
    a.l([(21,42),(43,42)],shade)
    a.oval((46,31,54,42),'#b4d58e',ink)
    a.l([(48,32),(51,32),(53,34)],'#d7e9af')
    a.l([(53,37),(52,40),(49,41)],'#7fa86d')
    for x,y in [(49,33),(47,35),(51,35),(49,37)]:a.oval((x,y,x+2,y+2),'#739e5b')
    a.r(49,35,2,3,'#82ae65'); a.l([(50,38),(50,40)],'#678a52')
    if not a.back:
        a.dots([22,39],34,blink,ink,2,4)
        a.l([(29,37),(30,36),(32,36),(33,37)],ink); a.r(31,37,1,1,ink)


def spirit(a, frame):
    step, blink = phase(frame)
    ink, white, shade = '#53596e', '#f6f8ff', '#ccd6e8'
    tail_y=1 if step>0 else 0
    with a.part('tail'):
        a.p([(39,49),(45,48),(49,45+tail_y),(52,43+tail_y),(55,43+tail_y),
             (57,45+tail_y),(57,48+tail_y),(54,50+tail_y),(53,52+tail_y),
             (49,54),(44,55),(39,54)],white,ink)
        a.p([(48,47+tail_y),(51,44+tail_y),(54,44+tail_y),(56,46+tail_y),
             (56,48+tail_y),(53,49+tail_y),(52,52+tail_y),(50,53),(47,53)],'#b9c7e8')
        a.l([(52,45+tail_y),(54,45+tail_y)],'#d1dcf4')
        a.l([(49,52),(52,51+tail_y),(55,48+tail_y)],'#92a5cb')
    for x,s,part in [(23,step,'left_foot'),(33,-step,'right_foot')]:
        with a.part(part):
            a.p([(x,51),(x+4,51),(x+4+s,56),(x+3+s,58),(x+s,58),(x-1+s,56)],white,ink)
    # A single tall white body; small ears, no head/body seam or neckband.
    a.p([(16,21),(15,14),(16,10),(18,9),(24,12),(28,12),(33,12),
         (37,13),(42,9),(45,10),(46,13),(45,23),(47,29),(48,33),
         (46,37),(46,44),(44,49),(41,53),(36,55),(25,55),(20,53),
         (17,50),(15,45),(14,38),(13,34),(13,30)],white,ink)
    a.p([(18,13),(23,16),(18,19)],'#e0e7f5' if a.back else '#bac8e9')
    a.p([(39,16),(43,12),(43,19)],'#d9e2f1' if a.back else '#bfc6eb')
    a.p([(43,23),(46,30),(47,33),(45,38),(45,44),(43,49),(40,52),(36,54),
         (26,54),(22,52),(20,50),(26,51),(35,51),(39,49),(42,44),(43,37)],'#e0e7f5')
    a.l([(46,31),(46,34),(44,38),(44,44),(42,49),(39,52),(35,53)],shade)
    a.p([(19,23),(22,20),(26,20),(24,25),(20,29),(18,35),(17,32),(17,28)],'#ffffff')
    a.p([(18,38),(21,38),(22,42),(21,47),(19,45)],'#ffffff')
    a.l([(18,48),(21,51),(25,53)],'#e6edf8')
    a.l([(17,13),(18,11),(20,12)],'#ffffff')
    a.l([(41,12),(43,11),(44,13)],'#e3eafa')
    if a.back:
        a.l([(22,28),(24,26),(27,25)],'#e9eef9')
        with a.part('tail'):
            a.p([(31,48),(36,47),(42,48),(46,49),(47,53),(42,55),(36,54),(32,52)],white,ink)
            a.l([(34,49),(39,50),(44,51)],'#ffffff')
            a.l([(36,53),(41,54),(45,52)],shade)
        return
    a.l([(31,17),(28,18),(27,20),(27,23),(29,25),(32,25),(34,23),
         (34,21),(32,20),(30,20),(29,21),(30,23),(31,23),(31,22)],ink)
    a.dots([22,38],29,blink,'#343843',2,3)
    a.oval((18,33,23,35),'#efd5e1'); a.oval((40,33,44,35),'#efd5e1')
    a.r(30,33,2,1,'#6c6880')
    a.l([(28,35),(29,36),(30,36),(31,35),(32,36),(33,36),(34,35)],'#50556a')
    for x,part in [(23,'left_hand'),(37,'right_hand')]:
        with a.part(part):
            a.l([(x-1,43),(x-1,45),(x,46),(x+1,46),(x+2,45),(x+2,43)],'#636b80')
            a.r(x,44,1,1,'#ffffff')


DRAW = dict(zip(IDS,[rabbit,bee,hamster,cat,roller,spirit]))


def frame_image(member, frame, direction='down'):
    assert direction in DIRECTIONS, direction
    a=Pen(member,frame,direction)
    if direction in ['left','right']:
        from draw_fan_directions import draw_profile
        draw_profile(a,member,frame)
        if direction=='left':
            # Reflect around the shared x=32 foot anchor, not x=31.5.
            mirrored=a.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            a.im=Image.new('RGBA',(SIZE,SIZE))
            a.im.alpha_composite(mirrored,(1,0))
    else:
        DRAW[member](a,frame)
    return a.im


def build(update_world=True):
    OUT.mkdir(parents=True,exist_ok=True)
    data={'revision':7,'cell':[SIZE,SIZE],'anchor':list(ANCHOR),'frames':FRAME_COUNT,
          'directions':DIRECTIONS,'frames_per_member':FRAME_COUNT*len(DIRECTIONS),
          'direction_notes':'Side/back game adaptations of verified designs; Doldori also has a source back view. No official turnaround claimed.',
          'animations':ANIMATIONS,'idle':ANIMATIONS['idle'],'blink':[1],
          'walk':ANIMATIONS['walk'],'run':ANIMATIONS['run'],'walk_fps':24,
          'reference_review':'2026-11-06','detail_pass':'material clusters, soft edge colours, clearer small faces',
          'reference_sources':'artifacts/fan_reference_check/sources.json','members':{}}
    for member,name,label in zip(IDS,NAMES,LABELS):
        sheet=Image.new('RGBA',(SIZE*FRAME_COUNT,SIZE*len(DIRECTIONS)))
        for row,direction in enumerate(DIRECTIONS):
            for frame in range(FRAME_COUNT):
                sheet.paste(frame_image(member,frame,direction),(frame*SIZE,row*SIZE))
        sheet.save(OUT/(member+'.png'))
        motion=dict(MOTION[member],shadow_scale=[pose_for(member,f)['shadow'] for f in range(FRAME_COUNT)])
        data['members'][member]={'name':name,'motif':label,'frames':FRAME_COUNT,'motion':motion}
        frame_image(member,0).save(ROOT/'assets/world_pixels'/('fan_'+member+'.png'))
    (OUT/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    if update_world:
        path=ROOT/'assets/world_pixels/manifest.json'
        world=json.loads(path.read_text(encoding='utf-8'))
        for member in IDS:world['sprites']['fan_'+member]={'size':[SIZE,SIZE],'native_size':[SIZE,SIZE],'anchor':list(ANCHOR),'density':1}
        path.write_text(json.dumps(world,ensure_ascii=False,indent=2),encoding='utf-8')
    return data


def previews(before='fan_reference_before', prefix='fan_redraw', detail=False):
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',16)
    bold=ImageFont.truetype('C:/Windows/Fonts/malgunbd.ttf',24)
    board=Image.new('RGB',(1320,640),'#293d39');d=ImageDraw.Draw(board)
    d.text((22,15),'팬 도트 디테일 보강 · 위: 보강 전 / 아래: 보강 후' if detail else '팬 원본 반영 · 위: 수정 전 / 아래: 다시 찍은 도트',font=bold,fill=LIGHT)
    for i,(member,name,label) in enumerate(zip(IDS,NAMES,LABELS)):
        x=i*220
        d.text((x+20,60),name,font=bold,fill=LIGHT)
        d.text((x+10,600),label,font=font,fill='#d6cbb6')
        for row in range(2):
            y=99+row*244
            d.rectangle((x+8,y,x+212,y+232),fill='#465a51')
            d.line((x+12,y+200,x+208,y+200),fill='#829080')
            src=Image.open(ART/before/('fan_'+member+'.png')).convert('RGBA') if row==0 else frame_image(member,0)
            view=src.resize((192,192),Image.Resampling.NEAREST)
            board.paste(view,(x+110-32*3,y+200-58*3),view)
    board.save(ART/(prefix+'_comparison.png'))
    frames=[]
    for tick in range(70):
        plate=Image.new('RGB',(1320,352),'#293d39');d=ImageDraw.Draw(plate)
        walk=14<=tick<36
        running=36<=tick<56
        label='달리기' if running else '걷기 / 부유' if walk else '멈춤' if 56<=tick<60 else '대기'
        d.text((22,12),('디테일 보강 팬 도트 · ' if detail else '원본 반영 팬 도트 · ')+label,font=bold,fill=LIGHT)
        for i,(member,name) in enumerate(zip(IDS,NAMES)):
            if tick in [14,15]: frame=24+tick-14
            elif walk or running:
                gait='run' if running else 'walk'
                rate=MOTION[member][gait+'_fps'] or (240 if running else 170)/MOTION[member][gait+'_stride']*8
                cycle=(tick-(36 if running else 16))*.1*rate/8
                sequence=ANIMATIONS[gait]
                frame=sequence[int(cycle*len(sequence))%len(sequence)]
            elif 56<=tick<58: frame=26+tick-56
            else: frame=1 if tick in [9,10] else 18+int(tick*.1*(12 if member=='danming' else 3.5 if member=='kubby' else 5))%6
            a=frame_image(member,frame)
            view=a.resize((192,192),Image.Resampling.NEAREST)
            plate.paste(view,(14+i*220,62),view)
            d.text((i*220+72,276),name,font=bold,fill=LIGHT)
        frames.append(plate)
    frames[0].save(ART/(prefix+'_motion.gif'),save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2)
    print(prefix+': 6 mascots / '+str(6*FRAME_COUNT*len(DIRECTIONS))+' atlas cells / front preview updated.')


if __name__=='__main__':
    build();previews()
    if (ART/'fan_detail_before').exists():
        previews('fan_detail_before','fan_detail',detail=True)
