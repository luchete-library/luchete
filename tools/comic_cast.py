"""Use the unwarped field artwork for the in-book comic cast at every zoom."""
from pathlib import Path
from functools import cache
import json
from PIL import Image
from ete_field_art import ART,costume_art

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/comics/cast'
KEYS={'yato':'yato_idle','danming':'odanming_idle','kubby':'hamkubby_idle','yune':'amiha_yune_idle','dori':'shokoko_dori_idle','fuwa':'hakuten_fuwa_idle'}
@cache
def fitted(name):
    if name=='aethe':
        art=Image.open(ART/'field/aethe.png').convert('RGBA')
    else:
        art=costume_art(KEYS.get(name,name))
    return art.crop(art.getbbox())


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    names=['aethe','yato','danming_origin','kubby_origin','kubby','yune','dori','fuwa']
    data={}
    for name in names:
        im=fitted(name)
        im.save(OUT/(name+'.png'))
        data[name]={'size':list(im.size),'source':'field artwork at original aspect ratio'}
    (OUT/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Comic cast:',len(names))


if __name__=='__main__':main()
