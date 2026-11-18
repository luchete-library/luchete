"""Bake closed-book carrying frames from the approved Ink movement atlas.

The character pixels and face are retained exactly; a native pixel book and
hands are drawn only below the cheeks. No image deformation is performed.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/characters/visitors'
OUT=ROOT/'artifacts/growth_20261116'

def carry(cel,direction):
    out=cel.copy();d=ImageDraw.Draw(out)
    lift=cel.getbbox()[1]-8
    if direction=='right':
        return carry(cel.transpose(Image.Transpose.FLIP_LEFT_RIGHT),'left').transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if direction=='left':
        x,y=8,43+lift
        d.polygon([(x,y+1),(x+8,y-1),(x+13,y+2),(x+13,y+12),(x+4,y+13),(x,y+10)],fill='#735641',outline='#29283d')
        d.polygon([(x+2,y+2),(x+8,y+1),(x+10,y+3),(x+10,y+10),(x+4,y+11),(x+2,y+9)],fill='#a77852')
        d.line((x+5,y+3,x+8,y+3),fill='#e6c37b')
        d.line((x+3,y+11,x+10,y+11),fill='#e9dbc0')
        d.ellipse((x+9,y+7,x+14,y+11),fill='#aca8ed',outline='#29283d')
    elif direction=='up':
        # The book sits at the near hip, with the back of the reader in front.
        x,y=39,44+lift
        d.rectangle((x,y,x+10,y+12),fill='#775844',outline='#29283d')
        d.rectangle((x+2,y+2,x+8,y+9),outline='#dfbc75')
        d.line((x+2,y+11,x+8,y+11),fill='#eee0c0')
        d.ellipse((x-2,y+4,x+3,y+8),fill='#aca8ed',outline='#29283d')
    else:
        x,y=21,43+lift
        d.rectangle((x,y,x+17,y+12),fill='#846142',outline='#29283d')
        d.line((x+3,y+1,x+3,y+11),fill='#4e4146')
        d.rectangle((x+6,y+2,x+14,y+8),outline='#dbb675')
        d.line((x+5,y+11,x+15,y+11),fill='#e9dbc0')
        d.ellipse((x-3,y+6,x+2,y+10),fill='#aca8ed',outline='#29283d')
        d.ellipse((x+15,y+6,x+20,y+10),fill='#aca8ed',outline='#29283d')
    # The facial region and crown must remain byte-for-byte unchanged.
    assert np.array_equal(np.asarray(cel)[:38],np.asarray(out)[:38])
    return out

def main():
    source=Image.open(ART/'ink.png').convert('RGBA')
    sheet=Image.new('RGBA',(16*64,4*64));frames=[]
    for row,view in enumerate(['down','left','right','up']):
        for col in range(16):
            cel=source.crop((col*64,row*64,(col+1)*64,(row+1)*64))
            sheet.paste(carry(cel,view),(col*64,row*64))
    sheet.save(ART/'ink_carry.png')
    for col in range(16):
        board=Image.new('RGB',(512,256),'#30454c')
        for row in range(4):
            im=sheet.crop((col*64,row*64,(col+1)*64,(row+1)*64)).resize((128,128),Image.Resampling.NEAREST)
            board.paste(im,(row*128,20),im)
            im=source.crop(((col*2)*64,4*64,(col*2+1)*64,5*64)).resize((128,128),Image.Resampling.NEAREST)
            board.paste(im,(row*128,128),im)
        frames.append(board)
    OUT.mkdir(exist_ok=True)
    frames[0].save(OUT/'ink_carry_preview.png')
    frames[0].save(OUT/'ink_carry_preview.gif',save_all=True,append_images=frames[1:],duration=90,loop=0,disposal=2)
    print('64 carry cels checked: original head pixels unchanged.')
if __name__=='__main__': main()
