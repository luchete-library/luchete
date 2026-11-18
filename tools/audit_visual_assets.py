"""Read-only visual inventory, contact sheets and atlas-boundary review."""
from pathlib import Path
import json, hashlib, math
from collections import Counter
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/visual_audit'
OUT.mkdir(parents=True,exist_ok=True)
FONT=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',13)
TITLE=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',23)


def sheet(name,items,cols=4,cw=270,ch=270):
    rows=math.ceil(len(items)/cols)
    canvas=Image.new('RGB',(cols*cw+20,rows*ch+58),'#263a35')
    d=ImageDraw.Draw(canvas);d.text((14,12),name,font=TITLE,fill='#f0dfbd')
    for i,(label,im) in enumerate(items):
        x=10+i%cols*cw;y=48+i//cols*ch
        d.rectangle((x,y,x+cw-7,y+ch-8),fill='#4a5b50')
        view=im.copy().convert('RGBA')
        box=view.getbbox()
        if box:view=view.crop(box)
        factor=min((cw-20)/view.width,(ch-42)/view.height)
        view=view.resize((max(1,round(view.width*factor)),max(1,round(view.height*factor))),Image.Resampling.NEAREST)
        canvas.paste(view,(x+(cw-7-view.width)//2,y+(ch-35-view.height)//2),view)
        d.text((x+6,y+ch-29),label,font=FONT,fill='#f0dfbd')
    canvas.save(OUT/(name+'.png'))


def main():
    inventory=[];groups={};atlases=[]
    for path in sorted((ROOT/'assets').rglob('*')):
        if path.suffix.lower() not in ['.png','.jpg','.jpeg','.webp']:continue
        im=Image.open(path).convert('RGBA');rel=path.relative_to(ROOT).as_posix()
        item={'path':rel,'size':list(im.size),'alpha_bounds':im.getbbox(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        inventory.append(item)
        if path.parent.name in ['yard','interactions','directional','comics','fans']:
            atlases.append((path,im,item));continue
        group='portraits' if path.parent==ROOT/'assets/characters' else path.parent.name
        groups.setdefault(group,[]).append((path.stem,im))
    for name,items in groups.items():
        for page in range(0,len(items),20):sheet(name+'_%02d'%(page//20+1),items[page:page+20])
    frame_count=0;edge_alerts=[]
    for path,im,item in atlases:
        kind=path.parent.name
        if kind=='comics':
            cw,ch=228,110
            items=[]
            for cut in range(4):
                for frame in (0,10,23,24):
                    col=frame%13
                    row=2*cut+frame//13
                    items.append((f'cut{cut+1} / frame{frame}', im.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch))))
            sheet('comic_'+path.stem,items,4,250,160)
        elif kind=='fans':
            cw,ch=64,64
            items=[('%s / %d'%(['down','left','right','up'][r],c),im.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch))) for r in range(im.height//ch) for c in range(im.width//cw)]
            sheet('fans_'+path.stem,items,8,145,160)
        else:
            cw,ch=96,112
            rows=im.height//ch;cols=im.width//cw
            selected=[0] if cols==1 else [0,cols//2,cols-1] if cols>5 else [0,1,2,3,4]
            items=[('%s r%d f%d'%(path.stem,r,c),im.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch))) for r in range(rows) for c in selected]
            sheet(kind+'_'+path.stem,items,len(selected) if len(selected)>1 else 4,165,160)
        rows=im.height//ch;cols=im.width//cw
        for row in range(rows):
            for col in range(cols):
                bounds=im.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch)).getbbox();frame_count+=1
                if kind!='comics' and bounds and (bounds[0]<=0 or bounds[1]<=0 or bounds[2]>=cw or bounds[3]>=ch):
                    edge_alerts.append({'path':item['path'],'row':row,'col':col,'bounds':bounds})
    report={'images':len(inventory),'atlas_cells':frame_count,'groups':dict(Counter('/'.join(x['path'].split('/')[:-1]) for x in inventory)),'edge_alerts':edge_alerts,'inventory':inventory}
    (OUT/'inventory.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='inventory'},ensure_ascii=False))


if __name__=='__main__':main()
