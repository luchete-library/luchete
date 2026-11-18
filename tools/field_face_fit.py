"""Calibrate field artwork in native cel pixels, before it reaches Godot.

The six pins are eye midpoint, chin, crown of the main head mass, cheek width
and cranium width. Floating ornaments, loose hair and hats' ears sit outside
the last two contours. Wardrobe and authored gestures share the target.
"""
from dataclasses import dataclass
from math import cos, radians, sin

import numpy as np


@dataclass(frozen=True)
class Face:
    x: float
    eye: float
    chin: float
    crown: float
    cheeks: float
    skull: float
    angle: float = 0


# Traced on directional/aethe.png, front idle. The monocle, halo and
# curled locks sit outside the skin/cranium landmarks.
CHEEKS, SKULL = 26, 42
JAW, DOME = 8, 24
STANDING_CHIN = 65
FOOT = 103
from ete_field_art import drawing
_ete=drawing('aethe')
_cx,_crown,_eye,_gap,_chin,*_=_ete.pins
_ex,_ey=_ete.point(_cx,_eye)
_jaw=_ete.point(_cx,_chin)[1]
_top=_ete.point(_cx,_crown)[1]
CHEEKS,SKULL=20,30
JAW,DOME=_jaw-_ey,_ey-_top
STANDING_CHIN=_jaw+14
ETE_FACE=Face(_ex+16,_ey+14,_jaw+14,_top+14,CHEEKS,SKULL)

def head_features(image):
    rgba=np.asarray(image,dtype='float32')
    # Hair outline, iris value and bright headpiece edges give matches even
    # when a cel closes both eyes or brings a hand in front of the cheek.
    return ((rgba[:,:,0]*.36+rgba[:,:,1]*.48+rgba[:,:,2]*.16-90)*rgba[:,:,3]/255).astype('int16')


class PoseTrace:
    """Register the marked head against other authored keys of the same sheet.
    One rigid similarity per key preserves the tilt of the original drawing.
    """
    def __init__(self, source, pins):
        self.pins=pins
        self.top=source.getbbox()[1]
        p=pins
        xx,yy=np.meshgrid(np.arange(p.x-p.skull*.54,p.x+p.skull*.54,2),
                          np.arange(p.crown-2,p.chin+1,2))
        x,y=np.rint(xx).astype(int).ravel(),np.rint(yy).astype(int).ravel()
        self.values=head_features(source)[y,x]
        self.coords=(x-p.x,y-p.eye)

    def measure(self, image):
        p=self.pins
        target=head_features(image)
        x,y=self.coords
        base_y=p.eye+image.getbbox()[1]-self.top
        best=(float('inf'),p.x,base_y,1.,0.)

        def search(anchor, offsets, angles, scales):
            nonlocal best
            dx,dy=np.meshgrid(offsets,offsets)
            cx=anchor[1]+dx.reshape(-1,1)
            cy=anchor[2]+dy.reshape(-1,1)
            for angle in angles:
                co,si=cos(radians(angle)),sin(radians(angle))
                u,v=co*x-si*y,si*x+co*y
                for scale in scales:
                    ix=np.rint(cx+scale*u).astype(int).clip(0,95)
                    iy=np.rint(cy+scale*v).astype(int).clip(0,111)
                    error=np.minimum(np.abs(target[iy,ix]-self.values),58).mean(axis=1)
                    k=error.argmin()
                    if error[k]<best[0]:
                        best=(float(error[k]),float(cx[k,0]),float(cy[k,0]),float(scale),float(angle))
        search(best,np.arange(-12,13,3),range(-24,25,8),(.84,.92,1.,1.08,1.16))
        _,cx,cy,s,a=best
        search(best,np.arange(-2,2.1,1),np.arange(a-5,a+6,2.5),np.arange(s-.045,s+.05,.0225))
        _,cx,cy,s,a=best
        search(best,(-.5,0,.5),[a-1,a,a+1],[s-.01,s,s+.01])
        cost,cx,cy,s,angle=best
        return Face(cx,cy,cy+(p.chin-p.eye)*s,cy-(p.eye-p.crown)*s,
                    p.cheeks*s,p.skull*s,angle),cost
