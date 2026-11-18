"""Review actual shipped atlas cels; no repainting or image interpolation."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from yard_costumes import ART,KEYS
ROOT=ART.parents[1]
OUT=ROOT/'artifacts/pet_rollout_20261116'
CAST=[('aethe','aethe','에테'),('yato','yato_hood','야토'),('danming','danming_origin','단밍'),('kubby','kubby_origin','쿠비'),('yune','amiha_yune_idle','유네'),('dori','shokoko_dori_idle','도리'),('fuwa','hakuten_fuwa_idle','후와')]
FONT=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
TITLE=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',25)
ORDER=[k for keys in KEYS.values() for k in keys]
CACHE={}
def atlas(path):
    if path not in CACHE:CACHE[path]=Image.open(ART/path).convert('RGBA')
    return CACHE[path]
def cel(path,x,y):return atlas(path).crop((x*96,y*112,(x+1)*96,(y+1)*112))
def base(title,rows):
    out=Image.new('RGB',(1440,75+rows*260),'#222b32')
    d=ImageDraw.Draw(out);d.text((22,16),title,font=TITLE,fill='#f7e5b6')
    return out
def place(out,im,col,row,name):
    x=20+col*200;y=70+row*260
    d=ImageDraw.Draw(out);d.rounded_rectangle((x,y,x+190,y+248),8,fill='#34454a',outline='#64706a')
    d.text((x+12,y+8),name,font=FONT,fill='#fff0ce')
    im=im.resize((192,224),Image.Resampling.NEAREST)
    out.paste(im,(x-1,y+24),im)
def walking(member,key,view,t):
    if member=='aethe':return cel('directional/aethe_walk.png',t,view)
    if view==0:
        n=t*72//16;row=ORDER.index(key)
        return cel('yard/walk.png',n%36,row*2+n//36)
    return cel('directional/'+key+'.png',1+t,view-1)
def interaction(member,key,action,t):
    name=member if member=='aethe' or key==KEYS[member][0] else key
    data=json.loads((ART/'interactions'/f'{name}.json').read_text('utf-8'))
    row=next(a['row'] for a in data['actions'] if a['id']==action) if action else 0
    return cel('interactions/motion/'+name+'.png',t,row)
def gif(frames,name,duration):
    frames[0].save(OUT/name,save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=False,disposal=2)
def main():
    labels=['정면','왼쪽','오른쪽','뒷모습']
    board=base('본게임 적용 도트 · 4방향 · 정수 2배 확대',4)
    for view in range(4):
        for col,(member,key,name) in enumerate(CAST):place(board,walking(member,key,view,0),col,view,name+' · '+labels[view])
    board.save(OUT/'four_directions.png')
    frames=[]
    for view in range(4):
        for t in range(16):
            board=base('본게임 이동 프레임 · '+labels[view],1)
            for col,(member,key,name) in enumerate(CAST):place(board,walking(member,key,view,t),col,0,name)
            frames.append(board)
    gif(frames,'four_directions.gif',90)
    frames=[]
    for t in range(41):
        board=base('본게임 상호작용 · 인사 / 독서 / 차 마시기',3)
        for row,(action,label) in enumerate([(None,'인사'),('read','독서'),('tea','차')]):
            for col,(member,key,name) in enumerate(CAST):place(board,interaction(member,key,action,t),col,row,name+' · '+label)
        frames.append(board)
    frames[24].save(OUT/'interactions.png')
    gif(frames,'interactions.gif',60)
    print('Saved seven-character direction and interaction PNG/GIF reviews.')
if __name__=='__main__':main()
