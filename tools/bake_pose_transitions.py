"""Production CLI delegates to rigid joints; flow helpers serve archived previews."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from field_face_fit import FOOT, JAW

ROOT = Path(__file__).resolve().parents[1] / "assets" / "characters"
CELL = (96,112)
STEPS = 8


def resize(field, size):
    return np.stack([np.asarray(Image.fromarray(v).resize(size, Image.Resampling.BILINEAR))
                     for v in field], axis=0)


def sample(field, x, y):
    h,w = field.shape[1:]
    x = np.clip(x,0,w-1.001); y = np.clip(y,0,h-1.001)
    ix,iy = x.astype(int),y.astype(int)
    fx,fy = x-ix,y-iy
    return ((1-fy)*((1-fx)*field[:,iy,ix]+fx*field[:,iy,ix+1])
            +fy*((1-fx)*field[:,iy+1,ix]+fx*field[:,iy+1,ix+1]))


def box_mean(fields, radius):
    z = np.pad(fields,((0,0),(radius,radius),(radius,radius)),mode='edge')
    z = np.pad(z,((0,0),(1,0),(1,0))).cumsum(1).cumsum(2)
    k = radius*2+1
    return (z[:,k:,k:]-z[:,:-k,k:]-z[:,k:,:-k]+z[:,:-k,:-k])/(k*k)


def features(im):
    v=np.asarray(im).astype('float32')/255
    a=v[:,:,3]
    # Separate the silhouette from colour so the transparent gutter never
    # attracts dark hair more than a pale sleeve.
    return np.stack((a,(v[:,:,0]*.3+v[:,:,1]*.6+v[:,:,2]*.1)*a,
                     (v[:,:,0]-v[:,:,2])*a*.5))


def registration(left,right):
    flow=np.zeros((2,14,12),dtype='float32')
    for w,h in [(24,28),(48,56),CELL]:
        flow=resize(flow,(w,h))*2
        a,b=resize(left,(w,h)),resize(right,(w,h))
        by,bx=np.gradient(b,axis=(1,2))
        y,x=np.indices((h,w),dtype='float32')
        for _ in range(4):
            xx=x+flow[0]; yy=y+flow[1]
            gx=sample(bx,xx,yy); gy=sample(by,xx,yy)
            difference=a-sample(b,xx,yy)
            products=np.stack([np.sum(v,axis=0) for v in
                              (gx*gx,gx*gy,gy*gy,gx*difference,gy*difference)])
            aa,ab,bb,ad,bd=box_mean(products,3)
            aa+=.001; bb+=.001
            det=aa*bb-ab*ab
            delta=np.array([(bb*ad-ab*bd)/det,(aa*bd-ab*ad)/det])
            flow=box_mean(flow+np.clip(delta,-2,2),2).astype('float32')
    return flow


def head_anchors(action, costume):
    return [np.asarray(point) for point in action['head_anchors']]


def remove_edge_specks(cel,below_neck):
    """A moving cuff can leave up to three isolated edge texels behind."""
    mask=cel[:,:,3]>=128
    packed=np.packbits(np.pad(mask,((0,0),(0,8))),axis=1,bitorder='little')
    remaining=int.from_bytes(packed.tobytes(),'little')
    while remaining:
        reached=remaining & -remaining
        while True:
            sides=reached | (reached<<1) | (reached>>1)
            extended=(sides | (sides<<104) | (sides>>104)) & remaining
            if extended==reached: break
            reached=extended
        remaining ^= reached
        if reached.bit_count()<=3:
            while reached:
                bit=reached & -reached
                py,px=divmod(bit.bit_length()-1,104)
                if below_neck[py,px]: cel[py,px]=0
                reached ^= bit


def pose_coordinates(x,y,target,source,jaw):
    """Inverse map through the skull down to the neck, then anchor the feet.
    A seated-to-standing transition can move the eyes by a dozen pixels even
    when the feet don't move. Registering the raw pictures folds the face.
    """
    dx,dy=x-target[0],y-target[1]
    turn=source[2]-target[2]
    co,si=np.cos(turn),np.sin(turn)
    hx=source[0]+co*dx-si*dy
    hy=source[1]+si*dx+co*dy
    depth=-np.sin(target[2])*dx+np.cos(target[2])*dy
    below=np.clip((depth-jaw-2)/18,0,1)
    below=below*below*(3-2*below)
    body_y=FOOT+(y-FOOT)*(FOOT-source[1]-jaw)/(FOOT-target[1]-jaw)
    return hx+(x-hx)*below,hy+(body_y-hy)*below,below


def between(first,second,steps,anchors=None,jaw=JAW):
    yield first
    if first.tobytes()==second.tobytes():
        for _ in range(1,steps): yield first
        return
    a,b=features(first),features(second)
    pixels=[np.asarray(first),np.asarray(second)]
    y,x=np.indices((CELL[1],CELL[0]),dtype='float32')
    if anchors is None:
        fields=[registration(a,b),registration(b,a)]
    else:
        features_pair=(a,b)
        fields=[]
        for side in (0,1):
            sx,sy,_=pose_coordinates(x,y,anchors[side],anchors[1-side],jaw)
            aligned=sample(features_pair[1-side],sx,sy)
            fields.append(registration(features_pair[side],aligned))
    for i in range(1,steps):
        t=i/steps
        side=int(t>=.5)
        xx,yy=x,y
        residual=1.
        if anchors is not None:
            here=(1-t)*anchors[0]+t*anchors[1]
            xx,yy,residual=pose_coordinates(x,y,here,anchors[side],jaw)
        t=min(t,1-t)
        flow=fields[side]
        # Invert the smooth displacement onto the fixed output canvas.
        vx,vy=sample(flow,xx,yy) if anchors is not None else flow
        dx,dy=sample(flow,xx-t*residual*vx,yy-t*residual*vy)
        # A half-pixel translation must select consecutive texels. Round-to-even
        # would repeat even columns and drop odd ones across a whole face.
        ix=np.floor(xx-t*residual*dx+.5).astype(int).clip(0,CELL[0]-1)
        iy=np.floor(yy-t*residual*dy+.5).astype(int).clip(0,CELL[1]-1)
        cel=pixels[side][iy,ix]
        if anchors is not None:
            remove_edge_specks(cel,residual>0)
        yield Image.fromarray(cel)


def bake(path, order, steps, output):
    atlas=Image.open(path).convert('RGBA')
    w,h=CELL
    out=Image.new('RGBA',(w*(1+steps*(len(order)-1)),atlas.height))
    manifest=None
    if path.parent.name=='interactions':
        manifest=json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    jaw=manifest.get("field_face",{}).get("eye_to_chin",JAW) if manifest else JAW
    for row in range(atlas.height//h):
        poses=[atlas.crop((i*w,row*h,(i+1)*w,(row+1)*h)) for i in order]
        col=0
        if manifest and 'head_anchors' in manifest['actions'][row]:
            guides=head_anchors(manifest['actions'][row],path.stem)
        else:
            # The four librarian walk directions have their own drawn contact
            # cels. Register the head to the first cel of the SAME direction.
            from field_face_fit import ETE_FACE, PoseTrace
            cels=[atlas.crop((i*w,row*h,(i+1)*w,(row+1)*h)) for i in range(atlas.width//w)]
            trace=PoseTrace(cels[4] if manifest else cels[0],ETE_FACE)
            guides=[]
            for cel in cels:
                p,_=trace.measure(cel)
                guides.append(np.array((p.x,p.eye,np.radians(p.angle))))
        for segment,(a,b) in enumerate(zip(poses,poses[1:])):
            anchors=(guides[order[segment]],guides[order[segment+1]]) if guides else None
            for im in between(a,b,steps,anchors,jaw):
                assert im.getbbox(), (path,row,col)
                out.paste(im,(col*w,row*h));col+=1
        out.paste(poses[-1],(col*w,row*h))
    out.save(output)
    print(output.name,out.size,flush=True)


if __name__=='__main__':
    # Production characters now share the joint-space baker; optical-flow
    # helpers above remain only for archived previews.
    from bake_rigid_interactions import bake as rigid_bake
    from bake_stella_directions import bake_librarian
    rigid_bake()
    bake_librarian()

