"""Register each new costume drawing ONCE against the librarian's native cel.

Coordinates below were traced on the two full-resolution sheets. Hats, curls
and halos use the free space above the crown; soles and eyelids share a grid.
"""
from dataclasses import dataclass
from functools import cache
from pathlib import Path
import json

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[1] / 'assets/characters'

# Centre X, main crown Y, eye Y, half interocular distance, chin Y,
# outer shoulder X distance and Y, wrist X distance and Y, ankle Y, sole Y.
CAST = {
    'yato_idle':          (310,60,165,23,197,46,220,71,331,413,482),
    'odanming_idle':      (764,58,164,22,197,44,220,73,330,422,481),
    'hamkubby_idle':      (1217,53,171,22,204,45,225,69,331,420,481),
    'amiha_yune_idle':    (316,582,685,22,716,41,741,60,831,930,989),
    'shokoko_dori_idle':  (762,600,690,22,719,40,746,75,846,931,987),
    'hakuten_fuwa_idle':  (1214,603,688,22,717,41,742,79,841,937,989),
}
WARDROBE = {
    'yato_hood':       (231,56,126,17,148,32,169,57,247,338,386),
    'yato_headset':    (626,30,111,18,140,35,161,54,248,335,386),
    'yato_bunny':      (1020,30,111,19,139,31,162,51,248,327,385),
    'yato_knit':       (231,435,514,18,538,34,562,52,647,740,798),
    'yato_track':      (625,439,514,19,538,33,559,56,646,737,800),
    'danming_origin':  (1023,446,517,18,543,36,565,68,654,740,798),
    'danming_racing':  (231,854,930,19,955,35,979,59,1073,1170,1232),
    'kubby_origin':    (625,842,931,19,955,36,981,70,1077,1170,1232),
    'yune_unveiled':   (1022,843,930,18,955,33,980,60,1073,1171,1230),
}

TRAVELER=(579,473,656,76,750,103,807,162,985,1158,1241)
SIZE=(64,90)


@dataclass
class Drawing:
    art: Image.Image
    pins: tuple
    scale: float
    dx: float
    dy: float

    def point(self,x,y):
        return round(self.dx+x*self.scale),round(self.dy+y*self.scale)


@cache
def sheet(name):
    return Image.open(ART/'source'/name).convert('RGBA')


def source_cell(key):
    approved=ART/'source/detail_v3/registration.json'
    if approved.exists():
        entries=json.loads(approved.read_text('utf-8'))
        if key in entries:
            item=entries[key];box=tuple(item['box'])
            source=Image.open(ART.parents[1]/item['source']).convert('RGBA')
            return source.crop(box),box,tuple(item['pins'])
    detail=ART/'source'/'detail_v2'/'registration.json'
    if detail.exists():
        entries=json.loads(detail.read_text(encoding='utf-8'))
        if key in entries:
            entry=entries[key]
            source=Image.open(ART.parents[1]/entry['source']).convert('RGBA')
            row,col=divmod(list(entries).index(key),3)
            box=(col*source.width//3,row*607,(col+1)*source.width//3,(row+1)*607)
            return source.crop(box),box,tuple(entry['pins'])
    if key=='traveler':
        source=sheet('field_traveler_ete.png')
        pins=TRAVELER
        box=(0,0,*source.size)
    else:
        cast=key in CAST
        entries=CAST if cast else WARDROBE
        pins=entries[key]
        source=sheet('field_cast_ete.png' if cast else 'field_wardrobe_ete.png')
        row,col=divmod(list(entries).index(key),3)
        cuts=(0,510,1024) if cast else (0,400,810,1254)
        box=(col*source.width//3,cuts[row],(col+1)*source.width//3,cuts[row+1])
    return source.crop(box),box,pins


@cache
def drawing(key):
    approved=ART/'source'/'detail_v3'
    if (approved/(key+'.png')).exists():
        item=json.loads((approved/'registration.json').read_text(encoding='utf-8'))[key]
        return Drawing(Image.open(approved/(key+'.png')).convert('RGBA'),
                       tuple(item['pins']),item['scale'],item['dx'],item['dy'])
    detail = ART/'source'/'detail_v2'
    if (detail/(key+'.png')).exists():
        item=json.loads((detail/'registration.json').read_text(encoding='utf-8'))[key]
        return Drawing(Image.open(detail/(key+'.png')).convert('RGBA'),
                       tuple(item['pins']),item['scale'],item['dx'],item['dy'])
    crop,box,pins=source_cell(key)
    pixels=np.array(crop)
    pixels[pixels[:,:,3]<96]=0
    region=Image.fromarray(pixels)
    l,t,r,b=region.getbbox()
    cx,crown=pins[:2]
    sole=box[1]+b-1
    # Aethe's 70 px from crown to sole is the shared room scale. Fit a large
    # hat or wings by reducing the entire figure, with a pixel of clear margin.
    scale=min(70/(sole-crown),88/(b-t),30.5/max(cx-box[0]-l,box[0]+r-1-cx))
    dx,dy=31.5-cx*scale,89-sole*scale
    # Sample in premultiplied RGBA on a subpixel grid, then resolve coverage
    # once. X and Y have the same derivative through the entire drawing.
    sub=4
    inverse=(1/(sub*scale),0,(-.5-dx)/scale+.5-box[0],
             0,1/(sub*scale),(-.5-dy)/scale+.5-box[1])
    sampled=region.transform((64*sub,90*sub),Image.Transform.AFFINE,inverse,
                             Image.Resampling.BILINEAR).resize(SIZE,Image.Resampling.BOX)
    arr=np.array(sampled)
    arr[:,:,3]=np.where(arr[:,:,3]>=100,255,0)
    arr[arr[:,:,3]==0]=0
    art=Image.fromarray(arr)
    drop=90-art.getbbox()[3]
    if drop:
        aligned=Image.new('RGBA',SIZE)
        aligned.paste(art,(0,drop))
        art=aligned
    return Drawing(art,pins,scale,dx,dy+drop)


def costume_art(key):
    return drawing(key).art.copy()
