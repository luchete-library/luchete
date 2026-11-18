"""Register generated source art to the game's existing native skeleton grid.

This is an import step: equal X/Y scaling, alpha coverage and palette mapping.
No anatomy is stretched and no invented detail is painted by this importer.
"""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'assets/characters/source/detail_v2'
# x axis, crown, eyes, half eye gap, chin, shoulder half width/y,
# wrist half width/y, ankle, sole. Traced on fronts_v2.png (1295 x 1214).
PINS = {
    'yato_hood': (225,106,198,29,227,57,255,76,345,490,534),
    'danming_origin': (648,100,176,27,211,56,247,91,344,477,534),
    'kubby_origin': (1073,87,169,28,206,59,249,87,345,472,534),
    'amiha_yune_idle': (235,720,804,29,835,48,879,72,973,1115,1150),
    'shokoko_dori_idle': (650,729,803,29,836,48,884,91,971,1119,1150),
    'hakuten_fuwa_idle': (1072,724,802,29,836,54,881,86,973,1110,1150),
}


def limited_palette(art, colors=40):
    rgba = np.array(art)
    visible = rgba[:, :, 3] > 0
    swatch = Image.fromarray(rgba[:, :, :3][visible][None, :, :])
    reduced = np.array(swatch.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                     dither=Image.Dither.NONE).convert('RGB'))[0]
    rgba[:, :, :3][visible] = reduced
    rgba[~visible] = 0
    return Image.fromarray(rgba)


def register():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(HERE / 'fronts_v2.png').convert('RGBA')
    metadata = {}
    for i, (key, pins) in enumerate(PINS.items()):
        row, col = divmod(i, 3)
        box = (col*source.width//3, row*607, (col+1)*source.width//3, (row+1)*607)
        region = source.crop(box)
        arr = np.array(region)
        arr[arr[:, :, 3] < 128] = 0
        region = Image.fromarray(arr)
        l,t,r,b = region.getbbox()
        cx, crown = pins[:2]
        sole = box[1] + b - 1
        scale = min(70/(sole-crown), 88/(b-t), 30.5/max(cx-box[0]-l, box[0]+r-1-cx))
        dx,dy = 31.5-cx*scale, 89-sole*scale
        # Sample once at the native grid. A supersample/BOX reduction washed
        # each small highlight into its neighbours, losing the authored trim.
        inverse = (1/scale,0,(-.5-dx)/scale+.5-box[0],
                   0,1/scale,(-.5-dy)/scale+.5-box[1])
        art = region.transform((64,90),Image.Transform.AFFINE,inverse,
                               Image.Resampling.BILINEAR)
        arr = np.array(art)
        arr[:, :, 3] = np.where(arr[:, :, 3]>=110,255,0)
        arr[arr[:, :, 3]==0] = 0
        art = Image.fromarray(arr)
        drop = 90-art.getbbox()[3]
        if drop:
            shifted=Image.new('RGBA',(64,90));shifted.paste(art,(0,drop));art=shifted
        art = limited_palette(art)
        art.save(OUT / (key+'.png'))
        metadata[key] = dict(pins=pins, scale=scale, dx=dx, dy=dy+drop,
                             palette_colors=40, source='tools/character_detail/fronts_v2.png')
    (OUT/'registration.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    # A review sheet only. Nearest neighbour preserves the actual imported dots.
    canvas=Image.new('RGB',(6*256,430),'#34453f')
    d=ImageDraw.Draw(canvas)
    for i,key in enumerate(PINS):
        art=Image.open(OUT/(key+'.png')).convert('RGBA').resize((256,360),Image.Resampling.NEAREST)
        canvas.paste(art,(i*256,40),art)
        d.text((i*256+8,12),key,fill='#eee2c3')
    canvas.save(HERE/'registered_preview.png')


if __name__=='__main__': register()
