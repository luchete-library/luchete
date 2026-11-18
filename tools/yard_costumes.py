"""Cut the library's costume pixels into overlapping pieces for the yard cels."""
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from ete_field_art import costume_art, drawing


ART = Path(__file__).resolve().parents[1] / "assets" / "characters"
SIZE = (64, 90)
CENTER = 31.5


@dataclass(frozen=True)
class Fit:
    eyes: tuple  # left x, right x, centre y in the centred 64 x 90 miniature
    mouth_y: int
    chin: int
    shoulder: tuple
    elbow: tuple
    hand: tuple
    hip_y: int
    leg_start: int
    sleeve: tuple  # traced outer edge of the left sleeve, cuff and hand


KEYS = {
    "yato": ("yato_idle","yato_hood","yato_headset","yato_bunny","yato_knit","yato_track"),
    "danming": ("odanming_idle","danming_origin","danming_racing"),
    "kubby": ("hamkubby_idle","kubby_origin"),
    "yune": ("amiha_yune_idle","yune_unveiled"),
    "dori": ("shokoko_dori_idle",), "fuwa": ("hakuten_fuwa_idle",),
}

# Width of the painted upper/lower sleeve in miniature pixels, then the
# first exposed leg row. Long gowns retain their train outside the two boots.
TAILORING = {
    'yato_idle':(2.2,2.4,65), 'odanming_idle':(2.3,2.1,67),
    'hamkubby_idle':(2.5,2.2,69), 'amiha_yune_idle':(1.8,1.7,83),
    'shokoko_dori_idle':(2.2,2.1,71), 'hakuten_fuwa_idle':(2.7,2.8,75),
    'yato_hood':(2.1,2.3,62), 'yato_headset':(3.0,3.1,62),
    'yato_bunny':(1.7,1.6,62), 'yato_knit':(2.7,2.7,64),
    'yato_track':(2.5,2.5,62), 'danming_origin':(2.2,2.2,68),
    'danming_racing':(2.7,2.3,64), 'kubby_origin':(2.9,3.0,68),
    'yune_unveiled':(1.8,1.6,82), 'traveler':(2.4,2.4,72), 'aethe':(2.4,2.5,70)
}


def fit_costume(key):
    src=drawing(key)
    cx,crown,eye,gaze,chin,sw,sy,ww,wy,ankle,sole=src.pins
    lx,ey=src.point(cx-gaze,eye)
    rx,_=src.point(cx+gaze,eye)
    sx,sy_native=src.point(cx-sw,sy)
    sh=(sx+(2 if key=="hamkubby_idle" else 1),sy_native)
    palm=src.point(cx-ww,wy)
    el=src.point(cx-(sw+ww)*.5-2,(sy+wy)*.5)
    a,b,leg=TAILORING[key]
    sx,sy=sh;ex,ey2=el;wx,wy=palm
    sleeve=((sx-a,sy-1),(sx+1,sy-1),(sx+a,sy+2),(ex+a,ey2),
            (wx+b,wy),(wx+1,wy+2),(wx-b,wy+2),(wx-b,wy-2),
            (ex-b,ey2-1))
    cy=src.point(cx,chin)[1]
    hip=round(sy+(89-sy)*.39)
    return Fit((lx,rx,ey),round(ey+(cy-ey)*.59),cy,sh,el,palm,hip,leg,sleeve)


def eye_contours(fit):
    left,right,y=fit.eyes
    half=max(1.5,(right-left)*.24)
    return [((x-half,y-1),(x-half+1,y-2),(x+half-1,y-2),(x+half,y-1),
             (x+half,y+1),(x+half-1,y+2),(x-half+1,y+2),(x-half,y+1)) for x in (left,right)]


def poly_mask(points):
    mask = Image.new("L",SIZE)
    ImageDraw.Draw(mask).polygon(points,fill=255)
    return np.asarray(mask)>0


def layer(art, mask):
    rgba = art.copy()
    rgba[:,:,3] = np.where(mask,rgba[:,:,3],0)
    rgba[rgba[:,:,3]==0] = 0
    return Image.fromarray(rgba)


def sealed_joint(piece, point, base, radius=2):
    """An opaque overlap tucked under the sleeve on both sides of a hinge."""
    x,y = map(lambda v: int(round(v)),point)
    yy,xx=np.indices(base.shape[:2])
    under=layer(base,(xx-x)**2+(yy-y)**2<=radius**2)
    under.alpha_composite(piece)
    return under


def islands(mask):
    """Yield eight-connected pieces of the source pixels."""
    seen = np.zeros_like(mask)
    for y,x in zip(*np.where(mask)):
        if seen[y,x]: continue
        pending,points = [(y,x)],[]
        seen[y,x] = True
        while pending:
            py,px = pending.pop()
            points.append((py,px))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    q,p = py+dy,px+dx
                    if 0<=q<90 and 0<=p<64 and mask[q,p] and not seen[q,p]:
                        seen[q,p] = True
                        pending.append((q,p))
        island = np.zeros_like(mask)
        for q,p in points: island[q,p] = True
        yield island


def lid_ground(pixels,masks,fit):
    """Sample nearby skin from the same face, excluding eyes, lips and fringe."""
    yy,xx=np.indices(pixels.shape[:2])
    r,g,b=pixels[:,:,:3].astype(int).transpose(2,0,1)
    skin=((r>=183)&(g>=150)&(r-g>=5)&(r-g<=68)&(g-b>=-7)&(g-b<=29)&
          (pixels[:,:,3]>200)&(abs(xx-32)<=14)&(yy>=fit.eyes[2]-3)&(yy<fit.chin))
    skin &= ~((abs(xx-32)<=3)&(yy>=fit.mouth_y-2))
    for mask in masks: skin &= ~mask
    sy,sx=np.where(skin)
    if not len(sx): raise ValueError("No cheek samples for the eyelids")
    ground=pixels.copy()
    for mask in masks:
        for y,x in zip(*np.where(mask)):
            # Favour nose/cheek pigments just below this eye. The lower edge
            # can retain blush without borrowing the pink centre of the mouth.
            dist=(sx-x)**2+(sy-y-1)**2
            near=np.argsort(dist,kind='stable')[:8]
            colors=pixels[sy[near],sx[near],:3]
            ground[y,x,:3]=np.average(colors,axis=0,weights=1/(1+dist[near])).round().astype('uint8')
    return ground


def facial_cels(head, fit, member, key):
    """Close each painted eye within its own outline on the native grid."""
    pixels=np.asarray(head)
    masks=[poly_mask(c)&(pixels[:,:,3]>0) for c in eye_contours(fit) if c]
    ground=lid_ground(pixels,masks,fit)
    lids=[]
    for mask in masks:
        ys,xs=np.where(mask)
        left,right=int(xs.min()+1),int(xs.max()-1)
        cy=int((ys.min()+ys.max()+1)//2)
        lashes=pixels[mask,:3]
        darkest=np.argsort(lashes.mean(axis=1))[:max(2,len(lashes)//6)]
        ink=np.median(lashes[darkest],axis=0)
        skin=ground[cy,(left+right)//2,:3]
        color=tuple(np.rint(.83*ink+.17*skin).astype('uint8'))+(255,)
        tip=tuple(np.rint(.62*ink+.38*skin).astype('uint8'))+(255,)
        points=((left,cy),(left+1,cy+1),(right-1,cy+1),(right,cy))
        lids.append((points,color,tip))
    result = {}
    for mood in ("open","half","closed","breath","smile","wink","blush","surprise"):
        blinking=mood in ("half","closed","breath","wink","blush")
        base=pixels.copy()
        if blinking:
            for mask in (masks[1:] if mood=="wink" else masks): base[mask]=ground[mask]
        cel=Image.fromarray(base)
        if mood=="surprise":
            # Lighten one outer iris pixel per eye. The startled gaze reads
            # at lobby scale while the painted lashes and cheek stay intact.
            left,right,y=fit.eyes
            for x,side in ((left,-1),(right,1)):
                point=(x+side,y)
                color=pixels[y,x+side,:3]
                light=np.rint(.40*color+.60*np.array((245,232,222))).astype('uint8')
                cel.putpixel(point,(*map(int,light),int(pixels[y,x+side,3])))
        for mask in (masks if mood=="half" else ()):
            ys,xs = np.where(mask)
            box = (int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
            cy=(box[1]+box[3])//2
            eye=head.crop(box)
            strip = eye.resize((max(3,round(eye.width*.78)),max(2,round(eye.height*.38))),Image.Resampling.NEAREST)
            patch = Image.new("RGBA",SIZE)
            shift=(eye.width-strip.width+int(xs.mean()<CENTER))//2
            patch.paste(strip,(box[0]+shift,cy-strip.height//2))
            cel.alpha_composite(layer(np.array(patch),mask))
        if mood in ("breath","smile","wink","blush","surprise"):
            draw = ImageDraw.Draw(cel)
            x = round((fit.eyes[0]+fit.eyes[1])/2)
            y = fit.mouth_y
            cheek = head.getpixel((x-3,y))
            if cheek[3] > 200 and min(cheek[:3])>120:
                draw.ellipse((x-2,y-1,x+2,y+1),fill=cheek)
                if mood == "breath": draw.line((x,y,x+1,y),fill="#bb8586")
                elif mood=="surprise": draw.line((x,y,x,y+1),fill="#a26e70")
                else: draw.line([(x-1,y),(x,y+1),(x+1,y)],fill="#aa7178")
        if mood=="blush":
            for x in (fit.eyes[0]-1,fit.eyes[1]+1):
                for offset in (0,1):
                    colour=cel.getpixel((x+offset,fit.eyes[2]+3))
                    if min(colour[:2])>145:
                        cel.putpixel((x+offset,fit.eyes[2]+3),tuple(round(.64*c+.36*b) for c,b in zip(colour[:3],(227,144,153)))+(255,))
        result[mood] = cel
    return result,lids


def head_and_body(core, fit, member, key):
    """Cut along the hair silhouette, never horizontally across a long braid."""
    art = np.array(core)
    yy,xx = np.indices((90,64))
    head = yy<=fit.chin
    # Only the side locks follow the chin, leaving dress folds and shoulders
    # with the torso. Their length is measured relative to the new collar.
    locks={'yato_idle':16,'yato_hood':12,'yato_bunny':20,'yato_knit':19,
           'amiha_yune_idle':18,'danming_racing':14,'aethe':39}
    length=locks.get(key,0)
    if length:
        sx,sy=fit.shoulder
        lock=((0,fit.chin),(sx+2,fit.chin),(sx,sy+4),
              (sx-3,fit.chin+length),(0,fit.chin+length))
        head |= poly_mask(lock) | poly_mask([(63-x,y) for x,y in lock])
    visible=art[:,:,3]>0
    # A high, detached feather tip or a fleck of sweater must stay with
    # the torso. A floating halo above the eyes remains on the head.
    for piece in islands(head & visible):
        if np.where(piece)[0].min()>fit.eyes[2]:
            head[piece]=False
    # Conversely, hair tips just below the traced chin follow the head.
    for piece in islands(~head & visible):
        ys=np.where(piece)[0]
        if ys.max()<=fit.chin+3:
            head[piece]=True
    body = layer(art,~head)
    # Paint the small occluded neckline/cloth area BEFORE compositing the source
    # body. It stays under the head when the chin shifts one pixel during a nod.
    under = Image.new("RGBA",SIZE)
    draw = ImageDraw.Draw(under)
    skin = tuple(art[fit.chin-3,32])
    if skin[3]<200 or min(skin[:3])<130: skin=(248,207,194,255)
    draw.rounded_rectangle((28,fit.chin-3,35,fit.chin+5),radius=2,fill=skin)
    body_pixels = np.array(body)
    for y in range(fit.chin+1,fit.hip_y):
        visible = np.where((body_pixels[y,:,3]>0)&(np.arange(64)>24)&(np.arange(64)<40))[0]
        if not len(visible): continue
        for x in range(23,41):
            if head[y,x] and art[y,x,3]>0:
                near = visible[np.argmin(abs(visible-x))]
                draw.point((x,y),tuple(body_pixels[y,near]))
    under.alpha_composite(body)
    if key in ("danming_origin","odanming_idle"):
        # The arms cover the inner wing roots in the reference. Extend each
        # feather under its sleeve so lifting a hand cannot detach the wing.
        wing_y=fit.shoulder[1]+2
        fill=Image.new("RGBA",SIZE)
        paint=ImageDraw.Draw(fill)
        for y in range(wing_y,wing_y+4):
            for left in (True,False):
                outer=np.flatnonzero((art[y,:,3]>0) & ((xx[y]<18) if left else (xx[y]>45)))
                if len(outer):
                    edge=int(outer[-1] if left else outer[0])
                    paint.line((edge,y,27 if left else 36,y),fill=tuple(art[y,edge]))
        fill.alpha_composite(under)
        under=fill
    return layer(art,head),layer(np.array(under),art[:,:,3]>0)


class Costume:
    def __init__(self, member, key):
        self.key = key
        self.fit = f = fit_costume(key)
        self.member = member
        base = np.array(costume_art(key))
        # Crisp alpha and a shared palette for every piece, including joints.
        base[:,:,3] = np.where(base[:,:,3] >= 95,255,0)
        yy, xx = np.indices((90,64))
        self.arms, self.legs = [], []
        # The goblin coat has a narrow open shoulder. Keep a larger concealed
        # overlap there so a raised sleeve cannot separate at a rotated pixel.
        shoulder_overlap = 3 if key == 'kubby_origin' else 2
        # Build the intact source silhouette first. The head/hair split below
        # follows their outline; the skirt never becomes a separately scaled strip.
        core = np.ones((90,64),bool)
        leg_mask = np.zeros((90,64),bool)
        for side in (-1,1):
            mirror = lambda x: x if side == -1 else 63-x
            sleeve = poly_mask([(mirror(x),y) for x,y in f.sleeve])
            sh, el, palm = [np.array([mirror(x),y],float) for x,y in (f.shoulder,f.elbow,f.hand)]
            # Split perpendicular to the arm, with a round overlap at the elbow.
            axis = (palm-sh)/np.linalg.norm(palm-sh)
            along = (xx-el[0])*axis[0]+(yy-el[1])*axis[1]
            upper = sealed_joint(sealed_joint(layer(base,sleeve&(along<2.1)),sh,base,shoulder_overlap),el,base)
            fore = sealed_joint(layer(base,sleeve&(along>-2.1)),el,base)
            self.arms.append((sh,el,palm,upper,fore))
            core &= ~sleeve | (((xx-sh[0])**2+(yy-sh[1])**2)<9)
            hx = CENTER+side*4.0
            hy = f.hip_y
            knee_y = (hy+85)*.5
            h,k,a = [np.array(v,float) for v in ((hx,hy),(hx+side*.3,knee_y),(hx+side*.6,85))]
            leg = (side*(xx-CENTER)>=0)&(abs(xx-CENTER)<8)&(yy>=f.leg_start)
            leg_mask |= leg
            self.legs.append((h,k,a,layer(base,leg&(yy<knee_y+1.6)),
                              layer(base,leg&(yy>knee_y-1.6)&(yy<86)),
                              layer(base,leg&(yy>=83))))
            core &= ~leg
        # A mirrored tracing can leave a few pixels of the opposite cuff behind.
        # Move those pixels with their limb, instead of leaving a floating shard.
        for island in islands(core & (base[:,:,3]>0)):
            ys,xs = np.where(island)
            if len(xs)>40 or ys.min()<=f.chin: continue
            near_wrist=abs(xs.mean()-CENTER)>8 and ys.min()<=f.hand[1]+4
            if ys.min()>=f.leg_start-1 and not near_wrist:
                leg_mask |= island
            else:
                i = int(xs.mean()>CENTER)
                sh,el,palm,upper,fore = self.arms[i]
                axis = (palm-sh)/np.linalg.norm(palm-sh)
                along = (xx-el[0])*axis[0]+(yy-el[1])*axis[1]
                upper.alpha_composite(layer(base,island&(along<2.1)))
                fore.alpha_composite(layer(base,island&(along>-2.1)))
            core &= ~island
        for i,side in enumerate((-1,1)):
            h,k,a,_,_,_ = self.legs[i]
            leg = leg_mask & (side*(xx-CENTER)>=0)
            self.legs[i] = (h,k,a,layer(base,leg&(yy<k[1]+1.6)),
                           layer(base,leg&(yy>k[1]-1.6)&(yy<86)),
                           layer(base,leg&(yy>=83)))
        # Paint the obscured folds underneath a lifted sleeve, using cloth
        # from the same scanline. The painted arms cover this patch at rest.
        torso=base.copy()
        cut=(~core)&(~leg_mask)&(base[:,:,3]>0)
        for y in range(f.shoulder[1]-1,f.hand[1]+4):
            span=np.interp(y,[f.shoulder[1],f.hip_y,f.hand[1]+3],
                           [32-f.shoulder[0]-1,6,10])
            for sign in (-1,1):
                centre=31 if sign<0 else 32
                for offset in range(4,int(span)+1):
                    x=centre+sign*offset
                    inner=centre+sign*3
                    if cut[y,x] and base[y,inner,3]:
                        torso[y,x]=base[y,inner]
                        core[y,x]=True
        # A coat tail, wing or braid can project past the lifted sleeve.
        # Bridge that covered band with the nearest visible fabric on each
        # side; the exact sleeve pixels still composite over it in neutral.
        for y,x in zip(*np.where(cut)):
            if core[y,x]: continue
            visible=np.flatnonzero(core[y] & (base[y,:,3]>0))
            left=visible[visible<x]; right=visible[visible>x]
            if len(left) and len(right):
                near=min((left[-1],right[0]),key=lambda q:abs(q-x))
                torso[y,x]=torso[y,near]
                core[y,x]=True
        # The tech jacket's long panels run vertically behind both cuffs.
        # At their roots the nearest visible cloth is above/below the wrist.
        if key=='yato_headset':
            cloth=core & (torso[:,:,3]>0)
            for y,x in zip(*np.where(cut & ~core)):
                above=np.flatnonzero(cloth[max(0,y-6):y,x])
                below=np.flatnonzero(cloth[y+1:y+7,x])
                if len(above) and len(below):
                    torso[y,x]=torso[y+1+below[0],x]
                    core[y,x]=True
        whole = layer(torso,core)
        for sh,_,_,_,_ in self.arms:
            whole = sealed_joint(whole,sh,base,shoulder_overlap)
        self.cores,self.lids = facial_cels(whole, f, member, key)
        # Named rigid nodes. The body includes the entire hem; the head includes
        # ears, halo and long hair. Only the padded neckline is shared.
        self.rig = {mood:head_and_body(cel,f,member,key) for mood,cel in self.cores.items()}
        self.seated_rig = {mood:(head,layer(np.array(body),yy<=f.hip_y+7))
                           for mood,(head,body) in self.rig.items()}
        self.standing_legs = layer(base,leg_mask)
        patch = base[f.leg_start:min(88,f.leg_start+4),25:30,:].reshape(-1,4)
        sock = patch[patch[:,3]>0]
        self.sock = tuple(map(int,np.median(sock[:,:3],axis=0))) if len(sock) else (81,68,75)
