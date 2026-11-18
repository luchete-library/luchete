"""Bake held full-body poses with a neck joint and integer-pixel limb chains."""
from math import atan2, cos, pi, radians, sin
import json

import numpy as np
from PIL import Image, ImageDraw

from yard_costumes import ART, KEYS, Costume

OUT = ART / "yard"
CELL = (96,112)
KEY_COUNT = 24
SAMPLES = 3
FRAMES = KEY_COUNT * SAMPLES
COLUMNS = 36  # Two rows per outfit; both atlas axes stay below 4096.
ACTIONS = ("pilates","yoga","gym","rope","stream","walk","read","tea")
GROUND = 103
TAU = 2*pi

# Authored holds and transitions. No independent head/waist sine wave.
CURL = (0,0,20,45,75,110,140,140,110,75,45,20,0,0,0,0,0,0,0,0,0,0,0,0)
WAVE = (0,0,0,.25,.5,.75,1,1,1,1,1,1,1,1,1,.75,.5,.25,0,0,0,0,0,0)
PRESS = (0,0,0,1,2,3,4,5,6,6,6,6,6,6,5,4,3,2,1,0,0,0,0,0)
PRAYER = (0,0,0,0,.2,.4,.6,.8,1,1,1,1,1,1,1,1,.8,.6,.4,.2,0,0,0,0)
JUMP = (1,2,0,-4,-7,-8,-8,-5,-1,2,2,1)
STEP = (0,1,2,2,2,1,0,0,0,0,0,0)
SIP = (0,0,0,.2,.4,.6,.8,1,1,1,1,1,1,1,.8,.6,.4,.2,0,0,0,0,0,0)

# frame, hip x/y, torso degrees, head x/y, head-relative degrees.
# A few readable poses with holds replace continuous, unrelated sine waves.
# See the Kairosoft reference notes in the game design document.
BODY_KEYS = {
    "idle": ((0,0,0,0,0,0,0),),
    "walk": ((0,0,0,0,0,0,0),(2,0,1,0,0,0,0),(5,0,0,0,0,0,0),
             (6,0,0,0,0,1,0),(8,0,1,0,0,0,0),(11,0,0,0,0,0,0),
             (14,0,1,0,0,0,0),(17,0,0,0,0,0,0),(18,0,0,0,0,1,0),
             (20,0,1,0,0,0,0),(23,0,0,0,0,0,0)),
    "read": ((0,0,3,0,0,1,0),(4,0,3,0,0,0,0),(6,0,3,0,1,1,2),
             (10,0,3,0,1,1,2),(14,0,3,0,0,1,0),(20,0,3,0,0,0,0)),
    "tea": ((0,0,3,0,0,0,0),(4,0,3,0,1,0,2),(7,0,3,0,1,1,2),
            (12,0,3,0,1,0,2),(16,0,3,0,0,0,0),(21,0,3,0,0,1,0)),
    "gym": ((0,0,0,0,0,0,0),(2,0,1,0,0,1,0),(4,-1,1,-2,0,0,-2),
            (8,-1,1,-2,0,1,-2),(10,0,1,0,0,0,0),(12,0,0,0,0,0,0),
            (14,0,1,0,0,1,0),(16,1,1,2,0,0,2),(20,1,1,2,0,1,2),(22,0,1,0,0,0,0)),
    "pilates": ((0,0,1,0,0,0,0),(3,-1,1,-2,0,0,0),(6,-1,2,-3,0,0,-2),
                (9,0,1,0,0,0,-2),(12,0,1,0,0,0,0),(15,1,2,3,0,0,0),
                (18,1,2,3,0,0,2),(21,0,1,0,0,0,2),(23,0,1,0,0,0,0)),
    "yoga": ((0,0,0,0,0,0,0),(4,0,0,0,0,-1,0),(12,0,1,0,0,0,0),
             (15,0,1,0,0,1,0),(19,0,1,0,0,0,0),(22,0,0,0,0,0,0)),
    "rope": ((0,0,0,0,0,0,0),(1,0,0,0,0,1,0),(4,0,0,0,0,0,0),
             (9,0,0,0,0,1,0),(11,0,0,0,0,0,0)),
    "stream": ((0,0,0,0,0,0,0),(3,0,1,0,1,0,0),(5,1,1,2,1,0,3),
               (8,1,1,2,1,1,3),(10,1,1,2,1,0,3),(12,1,1,2,1,1,3),
               (14,1,1,2,1,0,3),(16,1,1,1,0,0,0),(19,0,0,0,0,0,0),
               (21,0,0,0,0,1,0),(23,0,0,0,0,0,0)),
}


def vec(x,y):
    return np.array([x,y],float)


def snap(v):
    return np.floor(np.asarray(v)+.5)


def px(v):
    return tuple(map(int,snap(v)))


def rotation(a):
    return np.array(((cos(a),-sin(a)),(sin(a),cos(a))))


def place(piece, source, target, angle=0):
    """No scaling. Rigid core copies are integer translations, pixel for pixel."""
    source,target = snap(source),snap(target)
    if angle == 0:
        canvas = Image.new("RGBA",CELL)
        canvas.alpha_composite(piece,px(target-source))
        return canvas
    inverse = rotation(-angle)
    # Pillow transforms pixel centres. Both pieces share the same joint pixel.
    offset = source+.5-inverse@(target+.5)
    matrix = (*inverse[0],offset[0],*inverse[1],offset[1])
    return piece.transform(CELL,Image.Transform.AFFINE,matrix,Image.Resampling.NEAREST)


def angle_between(a,b):
    return atan2(b[1],b[0])-atan2(a[1],a[0])


def sample(values, phase):
    """Sample the cyclic joint track, not the rasterized character."""
    i = int(phase) % len(values)
    t = phase % 1
    return values[i] + (values[(i + 1) % len(values)] - values[i]) * t


def body_pose(act, phase):
    keys = BODY_KEYS[act]
    period = 12 if act == "rope" else KEY_COUNT
    phase %= period
    left = next(p for p in reversed(keys) if p[0] <= phase)
    right = next((p for p in keys if p[0] > phase), (period, *keys[0][1:]))
    t = (phase - left[0]) / (right[0] - left[0])
    t = t*t*(3-2*t)
    return [a+(b-a)*t for a,b in zip(left[1:],right[1:])]


def limb(source, shoulder, upper_turn=0, lower_turn=0):
    """A parent shoulder drives the elbow; that elbow drives the wrist."""
    a,b,c = map(snap,source[:3])
    upper_turn = radians(upper_turn)
    lower_turn = radians(lower_turn)
    elbow = snap(shoulder+rotation(upper_turn)@(b-a))
    wrist = snap(elbow+rotation(lower_turn)@(c-b))
    return (shoulder,elbow,wrist,upper_turn,lower_turn)


def reach(source, shoulder, target, side):
    """Solve one hand target, then rebuild it through the same parent chain."""
    a,b,c = map(snap,source[:3])
    upper,lower = np.linalg.norm(b-a),np.linalg.norm(c-b)
    direction = target-shoulder
    distance = np.linalg.norm(direction)
    unit = direction/max(distance,1e-6)
    distance = np.clip(distance,abs(upper-lower)+.01,upper+lower-.02)
    along = (upper**2-lower**2+distance**2)/(2*distance)
    height = max(0.,upper**2-along**2)**.5
    normal = vec(unit[1],-unit[0])
    if normal[0]*side<0: normal *= -1
    elbow = shoulder+unit*along+normal*height
    wrist = shoulder+unit*distance
    return limb(source,shoulder,
                angle_between(b-a,elbow-shoulder)*180/pi,
                angle_between(c-b,wrist-elbow)*180/pi)


class Motion:
    def __init__(self,suit,act,n):
        self.act,self.n = act,n
        self.hop = (n%12)/12
        self.air = max(0,-sample(JUMP,n)) if act=="rope" else 0
        self.root = vec(16,GROUND-89)
        if act == "rope": self.root[1] += sample(JUMP,n)
        if act == "yoga": self.root[1] += 4
        phase = n%12 if act=="rope" else n
        dx,dy,lean,hx,hy,tilt = body_pose(act,phase)
        self.root += vec(dx,dy)
        self.pivot = vec(32,suit.fit.hip_y)
        self.lean = radians(lean)
        self.head_offset = vec(hx,hy)
        self.head_angle = radians(lean+tilt)
        self.neck = vec(32,suit.fit.chin)
        self.head_target = self.on_body(self.neck)+self.head_offset
        self.mood = "smile" if act=="stream" and n<13 else "open"
        if act=="yoga":
            if 5<=n<=19: self.mood = "closed"
            if int(n) in (4,20): self.mood = "half"
            if 14<=n<=18: self.mood = "breath"
        elif int(n)==18: self.mood = "closed"
        elif int(n) in (17,19): self.mood = "half"
        self.arms,self.grips = [],[]
        for i,side in enumerate((-1,1)):
            source = suit.arms[i]
            shoulder = self.on_body(source[0])
            if act == "gym":
                arm = limb(source,shoulder,lean,lean-side*sample(CURL,n+12*i))
            elif act == "stream" and i==1:
                amount = sample(WAVE,n)
                wag = sample((0,0,0,-10,-10,0,10,10,0,0,0,0),n)*amount
                arm = limb(source,shoulder,lean-60*amount,lean-150*amount+wag)
            elif act == "rope":
                turn = sample((0,0,5,10,10,5,0,0,-5,-10,-10,-5),n)
                arm = limb(source,shoulder,lean-side*10,lean-side*(20+turn))
            elif act == "pilates":
                target = self.on_body(vec(31.5+side*12,suit.fit.shoulder[1]+6-sample(PRESS,n)))
                arm = reach(source,shoulder,target,side)
            elif act == "yoga":
                low = self.on_body(vec(31.5+side*14,suit.fit.hip_y+3))
                high = self.on_body(vec(31.5+side*2,suit.fit.shoulder[1]+4))
                arm = reach(source,shoulder,low+(high-low)*sample(PRAYER,n),side)
            elif act == "walk":
                swing = 11*sin(TAU*n/12)
                arm = limb(source,shoulder,side*swing,side*swing)
            elif act == "read":
                target = self.on_body(vec(32+side*8,suit.fit.shoulder[1]+9-(1 if 7<=n<=12 and i==1 else 0)))
                arm = reach(source,shoulder,target,side)
            elif act == "tea":
                low = self.on_body(vec(32+side*10,suit.fit.shoulder[1]+10))
                high = self.head_target+vec(5,max(3,suit.fit.mouth_y-suit.fit.chin+5))
                target = low+(high-low)*sample(SIP,n) if i==1 else low
                arm = reach(source,shoulder,target,side)
            elif suit.member=='aethe' and i==0:
                arm=reach(source,shoulder,self.on_body(vec(28,suit.fit.shoulder[1]+14)),side)
            else:
                arm = limb(source,shoulder,lean,lean)
            self.arms.append(arm)
            self.grips.append(arm[2])

    def on_body(self,point):
        return snap(self.root+self.pivot+rotation(self.lean)@(snap(point)-self.pivot))


def arm_layers(suit,m):
    result = []
    for source,pose in zip(suit.arms,m.arms):
        a,b,_,upper,fore = source
        sh,el,_,upper_turn,lower_turn = pose
        result.append((place(upper,a,sh,upper_turn),place(fore,b,el,lower_turn)))
    return result


def core_nodes(suit,m):
    rig = suit.seated_rig if m.act=="yoga" else suit.rig
    head,body = rig[m.mood]
    if m.act=='yoga' and hasattr(m,'seated_amount'):
        head,body=suit.rig[m.mood]
        body=body.copy()
        hem=round(89-(89-suit.fit.hip_y-7)*m.seated_amount)
        if hem<89:ImageDraw.Draw(body).rectangle((0,hem+1,63,89),fill=(0,0,0,0))
    # Native-pixel facial artwork is translated rigidly, never rotated/resized.
    # Body weight shifts and nod offsets still move the connected head.
    return (place(head,m.neck,m.head_target,0),
            place(body,m.pivot,m.root+m.pivot,m.lean))


def core_layer(suit,m):
    head,body = core_nodes(suit,m)
    body.alpha_composite(head)
    return body


def leg_layer(suit,m):
    unchanged = m.lean==0 and np.array_equal(m.root,vec(16,GROUND-89))
    airborne = m.act=="rope" and sample(JUMP,m.n)<=0
    if (m.act not in ("yoga","walk") and unchanged) or airborne:
        return place(suit.standing_legs,vec(0,0),m.root)
    canvas = Image.new("RGBA",CELL)
    draw = ImageDraw.Draw(canvas)
    dark = tuple(int(v*.72) for v in suit.sock)
    for i,side in enumerate((-1,1)):
        h,k,a,thigh,shin,shoe = suit.legs[i]
        hip = m.on_body(h)
        if m.act=="yoga":
            target = vec(48-side,GROUND-7-i)
            if hasattr(m,'seated_amount'):
                standing=snap(a)+vec(16,GROUND-89)
                target=standing+(target-standing)*m.seated_amount
            _,knee,ankle,upper_turn,lower_turn = reach((h,k,a),hip,target,side)
            assert np.linalg.norm(ankle-target)<=1.5, (suit.member,m.act,m.n,"foot out of reach")
        else:
            target = snap(a)+vec(16,GROUND-89)
            if m.act=="walk": target += vec(0,-sample(STEP,m.n+6*i))
            # In front view a bent knee moves towards the viewer. Overlap the
            # thigh and shin slightly instead of swinging both knees out wide.
            ankle=target
            knee=snap((hip+ankle)/2)
            upper_turn=angle_between(k-h,knee-hip)
            lower_turn=angle_between(a-k,ankle-knee)
        draw.line([px(hip),px(knee),px(ankle)],fill=dark,width=6,joint="curve")
        draw.line([px(hip),px(knee),px(ankle)],fill=suit.sock,width=4,joint="curve")
        canvas.alpha_composite(place(thigh,h,hip,upper_turn))
        canvas.alpha_composite(place(shin,k,knee,lower_turn))
        # The shin overlaps the boot. Pin the shoe to the floor even when the
        # rounded IK ankle lands one pixel away during a weight transfer.
        canvas.alpha_composite(place(shoe,a,target,-side*pi/2*getattr(m,'seated_amount',1.) if m.act=="yoga" else 0))
    return canvas


def draw_rope(draw,m):
    left,right = m.grips
    mid_y = (left[1]+right[1])*.5
    high = 8-mid_y
    low = GROUND-m.air+3-mid_y
    depth = (low+high)*.5+(high-low)*.5*cos(TAU*(m.hop-.04))
    pts = []
    for u in np.linspace(0,1,39):
        p = left+(right-left)*u+vec(-3.5*sin(TAU*u),depth*sin(pi*u))
        pts.append(px(p))
    draw.line(pts,fill="#966047",width=2)
    draw.line(pts,fill="#f7ce86",width=1)


def draw_gear(draw,m):
    left,right = m.grips
    if getattr(m,'member','')=='aethe' and m.act=='idle' and not getattr(m,'empty_hands',False):
        x,y=px(left)
        draw.rectangle((x-4,y-9,x+4,y+2),fill='#70472f',outline='#342c38')
        draw.rectangle((x-2,y-7,x+2,y),outline='#cba65f')
        draw.line((x,y-6,x,y-2),fill='#e7c271')
        draw.line((x-1,y-4,x+1,y-4),fill='#e7c271')
        draw.line((x-2,y+1,x+1,y+1),fill='#f3d0b7',width=2)
    elif m.act=="pilates":
        middle = (left+right)/2
        axis = (right-left)/2
        normal = vec(-axis[1],axis[0])/np.linalg.norm(axis)
        points = [px(middle+axis*cos(a)+normal*4*sin(a)) for a in np.linspace(0,TAU,41)]
        draw.line(points,fill="#3e726d",width=3,joint="curve")
        draw.line(points,fill="#b2e5cb",width=1)
    elif m.act=="gym":
        for hand in m.grips:
            x,y = px(hand)
            draw.line((x-7,y,x+7,y),fill="#c7cbc1",width=2)
            for dx in (-6,6):
                draw.rectangle((x+dx-2,y-4,x+dx+1,y+3),fill="#384655")
                draw.line((x+dx,y-3,x+dx,y+1),fill="#87acb7",width=2)
    elif m.act=="rope":
        for i,hand in enumerate(m.grips):
            x,y = px(hand)
            draw.line((x,y,x+(-3 if i==0 else 3),y+2),fill="#98664c",width=2)
    elif m.act=="read":
        x,y = px((left+right)/2)
        draw.polygon([(x-10,y-3),(x-2,y-2),(x,y),(x+2,y-2),(x+10,y-3),
                      (x+10,y+6),(x+2,y+7),(x,y+5),(x-2,y+7),(x-10,y+6)],fill="#735347")
        draw.polygon([(x-9,y-4),(x-2,y-3),(x,y-1),(x+2,y-3),(x+9,y-4),
                      (x+9,y+4),(x+2,y+5),(x,y+3),(x-2,y+5),(x-9,y+4)],fill="#f5deb0")
        draw.line((x,y-1,x,y+3),fill="#c9a678")
        for side in (-1,1): draw.line((x+side*3,y,x+side*7,y-1),fill="#c9a678")
        if 7<=m.n<=12:
            edge = x+6-(m.n-7)*2
            draw.line((x,y+3,edge,y-5),fill="#fff0d1",width=2)
    elif m.act=="tea":
        x,y = px(right)
        draw.rectangle((x+2,y-4,x+5,y),outline="#729f9a",width=1)
        draw.rectangle((x-4,y-5,x+2,y+1),fill="#b4d4c9")
        draw.line((x-4,y-5,x+2,y-5),fill="#f1e6c1",width=2)
        draw.line((x-3,y-4,x+1,y-4),fill="#977151",width=1)
    if m.act in ("gym","pilates","rope","read","tea"):
        for hand in m.grips:
            x,y = px(hand)
            draw.line((x-1,y-1,x+1,y),fill="#f3d0b7",width=2)


def isolated_body_pixels(mask,eye_y,keep_halo=False):
    # A sampled cuff or tiny hair tip can become a detached one- or two-pixel
    # island. Both pixels of a detached pair have only each other as a neighbour.
    h,w=mask.shape
    padded=np.pad(mask,1)
    count=np.zeros(mask.shape,dtype='uint8')
    for y in range(3):
        for x in range(3):
            if (x,y)!=(1,1): count+=padded[y:y+h,x:x+w]
    ends=mask&(count==1)
    pad_ends=np.pad(ends,1)
    pairs=np.zeros_like(mask)
    for y in range(3):
        for x in range(3):
            if (x,y)!=(1,1): pairs |= ends & pad_ends[y:y+h,x:x+w]
    dots=(mask&(count==0))|pairs
    return dots & (np.arange(h)[:,None]>eye_y) if keep_halo else dots


def fitted_lid(points,m,fit):
    # Measure in the face's own axes so a tilted head keeps both strokes well
    # inside the cheeks. Shortening each end leaves space beside the hair.
    axes=rotation(fit.angle)
    eye=vec(fit.eye_x,fit.eye_y)
    middle=np.mean([points[0],points[-1]],axis=0)
    marked=snap(m.head_target)+axes@(middle-snap(m.neck))
    u,v=axes.T@(marked-eye)
    v=np.clip(v,-.25,1.)
    radius=min(1.65,max(.9,(points[-1][0]-points[0][0])*.45))
    curve=((-radius,-.2),(0,.3),(radius,-.2))
    return [px(eye+axes@vec(u+dx,v+dy)) for dx,dy in curve]


def draw_closed_lids(body,suit,m,fit,arms):
    # Rasterize the one-pixel curve after fitting. Reducing a pre-drawn curve
    # a second time can remove a middle pixel or leave two dots at a corner.
    ink=Image.new('RGBA',CELL)
    draw=ImageDraw.Draw(ink)
    for points,color,tip in (suit.lids[1:] if m.mood=="wink" else suit.lids):
        final=fitted_lid(points,m,fit)
        draw.line(final,fill=color)
        draw.point(final[0],fill=tip)
        draw.point(final[-1],fill=tip)
    # Hands and sleeves remain in front if the pose covers an eye.
    visible=np.array(ink)
    for upper,fore in arms:
        for piece in (upper,fore):
            covered=np.asarray(piece.getchannel('A'))>0
            visible[covered]=0
    body.alpha_composite(Image.fromarray(visible))


class NativeFace:
    """A posed librarian-grid head is already at runtime resolution."""

    def __init__(self, eye, angle):
        self.eye_x,self.eye_y=eye
        self.angle=angle


def face_fit(suit,m):
    left,right,y=suit.fit.eyes
    eye=m.head_target+vec((left+right)/2,y)-m.neck
    return NativeFace(eye,0.)


def frame(suit,action,n,validate=False,motion=None):
    m = motion if motion is not None else Motion(suit,action,n)
    m.member=suit.member
    canvas = Image.new("RGBA",CELL)
    legs = leg_layer(suit,m)
    canvas.alpha_composite(legs)
    core = core_layer(suit,m)
    canvas.alpha_composite(core)
    arms = arm_layers(suit,m)
    joint_layers=arms  # Validate connected bones before head occlusion.
    # Forearms pass behind the head. Long sleeves beside a cup must not
    # repaint an eye/cheek; below the jaw, hands still overlap the torso.
    head,_=core_nodes(suit,m)
    face_front=(np.asarray(head.getchannel('A'))>0)&(np.arange(CELL[1])[:,None]<=round(m.head_target[1])+1)
    clipped=[]
    for upper,fore in arms:
        layers=[]
        for piece in (upper,fore):
            pixels=np.array(piece);pixels[face_front]=0
            layers.append(Image.fromarray(pixels))
        clipped.append(tuple(layers))
    arms=clipped
    for upper,fore in arms:
        canvas.alpha_composite(upper)
        canvas.alpha_composite(fore)
    if action=="yoga":
        front = legs.copy()
        ImageDraw.Draw(front).rectangle((0,0,CELL[0],int(suit.fit.hip_y+m.root[1]+6)),fill=(0,0,0,0))
        canvas.alpha_composite(front)
    if validate: validate_pose(suit,m,core,joint_layers,canvas)
    fit=face_fit(suit,m)
    body=canvas
    if m.mood in ("closed","breath","wink","blush"): draw_closed_lids(body,suit,m,fit,arms)
    rgba=np.array(body)
    rgba[isolated_body_pixels(rgba[:,:,3]>0,fit.eye_y,suit.key=="danming_origin")]=0
    body=Image.fromarray(rgba)
    output=Image.new("RGBA",CELL)
    draw=ImageDraw.Draw(output)
    if action=="rope" and m.hop<.5: draw_rope(draw,m)
    output.alpha_composite(body)
    if action=="rope" and m.hop>=.5: draw_rope(draw,m)
    draw_gear(draw,m)
    if validate:
        l,t,r,b=output.getbbox()
        assert 0<l<r<CELL[0] and 0<t<b<CELL[1],(suit.key,action,n,"fitted pose clipped",(l,t,r,b))
    return output


def validate_pose(suit,m,core,arms,canvas):
    """Check rendered seam pixels, not just mathematical bone lengths."""
    mask = np.array(core)[:,:,3]>0
    for source,pose,(upper,fore) in zip(suit.arms,m.arms,arms):
        sh,el,wr,_,_ = pose
        up,lo = np.array(upper)[:,:,3]>0,np.array(fore)[:,:,3]>0
        assert (mask&up).sum()>=3, (suit.member,m.act,m.n,"shoulder separation")
        assert (up&lo).sum()>=3, (suit.member,m.act,m.n,"elbow separation")
        for before,after in ((snap(source[1])-snap(source[0]),el-sh),
                             (snap(source[2])-snap(source[1]),wr-el)):
            assert abs(np.linalg.norm(before)-np.linalg.norm(after))<.8
    head,body = core_nodes(suit,m)
    head_mask,body_mask = np.array(head)[:,:,3]>0,np.array(body)[:,:,3]>0
    neck = np.zeros_like(head_mask)
    x,y = px(m.on_body(m.neck))
    neck[y-5:y+6,x-6:x+7] = True
    assert (head_mask&body_mask&neck).sum()>=5, (suit.member,m.act,m.n,"open neck seam")
    rig = suit.seated_rig if m.act=="yoga" else suit.rig
    expected_parts=rig[m.mood]
    if m.act=='yoga' and hasattr(m,'seated_amount'):
        body_source=suit.rig[m.mood][1].copy()
        hem=round(89-(89-suit.fit.hip_y-7)*m.seated_amount)
        if hem<89:ImageDraw.Draw(body_source).rectangle((0,hem+1,63,89),fill=(0,0,0,0))
        expected_parts=(rig[m.mood][0],body_source)
    for expected,actual in zip(expected_parts,(head,body)):
        before = np.count_nonzero(np.array(expected)[:,:,3])
        after = np.count_nonzero(np.array(actual)[:,:,3])
        assert abs(before-after)<=max(8,before*.025), (suit.member,m.act,m.n,"scaled body part")
    box = canvas.getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<CELL[0] and box[3]<CELL[1], (suit.member,m.act,m.n,box)


def bake_broadcast():
    # Close-ups use the same face and collar as the field, while the presenter
    # can still point, clap or hold a prop at the program-specific hand targets.
    bank=Image.new("RGBA",(CELL[0]*5,CELL[1]*sum(map(len,KEYS.values()))))
    joints={}
    for member,keys in KEYS.items():
        for key in keys:
            suit=Costume(member,key)
            m=Motion(suit,"idle",0)
            fit=face_fit(suit,m)
            pieces=[core_layer(suit,m)]
            for upper,lower in arm_layers(suit,m): pieces.extend((upper,lower))
            row=len(joints)
            fitted=[np.array(piece) for piece in pieces]
            specks=isolated_body_pixels(np.maximum.reduce([p[:,:,3] for p in fitted])>0,fit.eye_y,key=="danming_origin")
            for col,piece in enumerate(fitted):
                piece[specks]=0
                bank.paste(Image.fromarray(piece),(96*col,112*row))
            joints[key]={"row":row,"hip_y":int(m.pivot[1]+14),"chin_y":int(suit.fit.chin+14),"arms":[[v.round(2).tolist() for v in arm[:3]] for arm in m.arms]}
    bank.save(OUT/"broadcast_parts.png",optimize=True)
    (OUT/"broadcast_joints.json").write_text(json.dumps(joints,indent=2)+'\n',encoding="utf-8")


def librarian_blink(rest,mood):
    if mood=='open': return rest
    image=rest.copy()
    # Work INSIDE the monocle rim. Keep the brass ellipse, chain, fringe
    # and her mouth intact while the smaller right eye follows the same beat.
    for box in ((38,53,46,61),(53,53,60,61)):
        x,y,r,b=box
        eye=rest.crop(box)
        skin=rest.getpixel((48,60))
        d=ImageDraw.Draw(image)
        d.ellipse((x,y,r-1,b-1),fill=skin)
        if mood=='half':
            image.alpha_composite(eye.resize((r-x,4),Image.Resampling.NEAREST),(x,y+2))
        else:
            d.line([(x+1,y+4),(x+2,y+5),(r-3,y+5),(r-2,y+4)],fill='#785969')
    image.putalpha(rest.getchannel('A'))
    return image


def bake_traveler():
    suit=Costume("traveler","traveler")
    # Pack the walk over two rows like the resident atlases.
    atlas=Image.new("RGBA",(COLUMNS*96,3*112))
    for i,mood in enumerate(('open','half','closed')):
        m=Motion(suit,'idle',0); m.mood=mood
        atlas.paste(frame(suit,'idle',0,True,m),(i*96,0))
    for i in range(FRAMES):
        atlas.paste(frame(suit,'walk',i/SAMPLES,True),((i%COLUMNS)*96,(1+i//COLUMNS)*112))
    atlas.save(OUT/'traveler.png',optimize=True)


def bake():
    OUT.mkdir(exist_ok=True)
    count = sum(map(len,KEYS.values()))
    sheets = {act:Image.new("RGBA",(CELL[0]*COLUMNS,CELL[1]*count*2)) for act in ACTIONS}
    # A shared neutral pose for every outfit. This uses the exact same fitted
    # costume and skeleton as walking/exercise, rather than shrinking portraits.
    idle = Image.new("RGBA",(CELL[0],CELL[1]*(count+1)))
    blinking=Image.new("RGBA",(CELL[0]*3,idle.height))
    row = 0
    for member,costumes in KEYS.items():
        for key in costumes:
            suit = Costume(member,key)
            rest=frame(suit,"idle",0,validate=True)
            idle.paste(rest,(0,CELL[1]*row))
            if key==costumes[0]: rest.crop((16,14,80,104)).save(ART/"field"/(member+".png"))
            for col,mood in enumerate(('open','half','closed')):
                m=Motion(suit,"idle",0)
                m.mood=mood
                blinking.paste(frame(suit,"idle",0,True,m),(col*96,row*112))
            for act,sheet in sheets.items():
                for n in range(FRAMES):
                    sheet.paste(frame(suit,act,n/SAMPLES,validate=True),
                                (CELL[0]*(n%COLUMNS),CELL[1]*(row*2+n//COLUMNS)))
            row += 1
    for act,sheet in sheets.items(): sheet.save(OUT/(act+".png"),optimize=True)
    # Ete's approved neutral pose now comes from her authored directional atlas.
    # Keep compatibility exports identical to the actual runtime image.
    librarian = Image.open(ART/"directional"/"aethe.png").convert("RGBA").crop((0,0,*CELL))
    librarian.crop((16,14,80,104)).save(ART/"field"/"aethe.png")
    librarian.crop((16,14,80,104)).save(ART/"aethe.png")
    idle.paste(librarian,(0,CELL[1]*count))
    ete=Costume('aethe','aethe')
    for col,mood in enumerate(('open','half','closed')):
        m=Motion(ete,'idle',0);m.mood=mood
        blinking.paste(frame(ete,'idle',0,True,m),(col*96,count*112))
    blinking.save(OUT/'lobby_idle.png',optimize=True)
    idle.save(OUT/"idle.png",optimize=True)
    bake_broadcast()
    bake_traveler()
    print(f"Validated {count*len(ACTIONS)*FRAMES} cels: rigid head/body, closed neck/shoulder/elbow seams, limb lengths and margins.")
    print(f"Saved {count+1} shared-scale idle poses, including Aethe; source grid 64x90, feet at (48,103) in a 96x112 cel.")


if __name__=="__main__":
    bake()
