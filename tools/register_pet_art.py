"""Register approved pet-reference art without anisotropic scaling or face warps."""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image
from character_detail.register_fronts import limited_palette

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/source/pet_v3'
OUT=ROOT/'assets/characters/source/detail_v3'
ALT_PINS={
 'yato_idle':('turns_alts_a.png',0,(225,17,77,17,103,30,122,42,178,258,292)),
 'yato_headset':('turns_alts_a.png',1,(225,341,390,17,415,33,437,44,498,568,605)),
 'yato_bunny':('turns_alts_a.png',2,(225,655,704,17,729,27,752,42,799,883,922)),
 'yato_knit':('turns_alts_a.png',3,(225,969,1018,17,1043,29,1068,42,1122,1202,1238)),
 'yato_track':('turns_alts_b.png',0,(223,22,82,18,108,29,130,51,195,272,306)),
 'odanming_idle':('turns_alts_b.png',1,(223,341,395,18,424,31,445,48,508,582,616)),
 'danming_racing':('turns_alts_b.png',2,(223,656,706,18,733,29,760,50,821,896,933)),
 'hamkubby_idle':('turns_alts_b.png',3,(223,980,1032,18,1062,31,1085,48,1141,1212,1241)),
 'aethe':('turns_librarian.png',3,(183,1205,1264,19,1295,31,1322,57,1390,1480,1518)),
}

def register():
 OUT.mkdir(exist_ok=True)
 approved=ROOT/'artifacts/pet_reference_20261116/preview'
 records=json.loads((approved/'registration.json').read_text('utf-8'))
 records.pop('aethe')
 for i,(key,record) in enumerate(records.items()):
  shutil.copy2(approved/(key+'.png'),OUT/(key+'.png'))
  record['source']='assets/characters/source/pet_v3/fronts_approved.png'
  row,col=divmod(i,4);record['box']=[col*384,row*512,(col+1)*384,(row+1)*512]
 for key,(file,row,pins) in ALT_PINS.items():
  image=Image.open(SOURCE/file).convert('RGBA')
  cols=3 if key=='aethe' else 4
  box=(0,row*image.height//4,image.width//cols+(24 if cols==4 else 0),(row+1)*image.height//4)
  tile=image.crop(box); rgba=np.array(tile);rgba[rgba[:,:,3]<128]=0;tile=Image.fromarray(rgba)
  l,t,r,b=tile.getbbox();cx,crown=pins[:2];sole=box[1]+b-1
  scale=min(70/(sole-crown),88/(b-t),30.5/max(cx-l,r-1-cx))
  dx,dy=31.5-cx*scale,89-sole*scale
  inverse=(1/scale,0,(-.5-dx)/scale+.5,0,1/scale,(-.5-dy)/scale+.5-box[1])
  art=tile.transform((64,90),Image.Transform.AFFINE,inverse,Image.Resampling.BILINEAR)
  rgba=np.array(art);rgba[:,:,3]=np.where(rgba[:,:,3]>=110,255,0);rgba[rgba[:,:,3]==0]=0
  art=Image.fromarray(rgba);drop=90-art.getbbox()[3]
  if drop:
   aligned=Image.new('RGBA',(64,90));aligned.paste(art,(0,drop));art=aligned
  art=limited_palette(art,48);art.save(OUT/(key+'.png'))
  records[key]=dict(pins=pins,scale=scale,dx=dx,dy=dy+drop,palette_colors=48,
                    source='assets/characters/source/pet_v3/'+file,box=box)
 # This old hidden key is a compatibility alias, not a newly sold short hairstyle.
 records['yune_unveiled']=dict(records['amiha_yune_idle'])
 records['yune_unveiled']['alias_of']='amiha_yune_idle'
 shutil.copy2(OUT/'amiha_yune_idle.png',OUT/'yune_unveiled.png')
 (OUT/'registration.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),'utf-8')
 regions={}
 for key,r in records.items():
  cx,crown,eye,gap,chin,*_=r['pins'];scale=r['scale'];dx=r['dx'];dy=r['dy']
  ex,ey=cx*scale+dx,eye*scale+dy
  regions[key]={'region':[round(ex-20),round(ey-22),40,37],
                'eyes':[[round(ex-gap*scale),round(ey)],[round(ex+gap*scale),round(ey)]],
                'mouth':[round(ex),round((eye+(chin-eye)*.59)*scale+dy)]}
  shutil.copy2(OUT/(key+'.png'),ROOT/'assets/characters'/(key+'.png'))
 (ROOT/'assets/characters/portrait_regions.json').write_text(json.dumps(regions,indent=2),'utf-8')
 print('Registered',len(records),'costume/librarian keys with uniform X/Y scale.')

if __name__=='__main__':register()
