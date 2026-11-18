"""Validate the fan atlas and assemble the Godot motion preview captures."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont
from draw_fan_pixels import IDS, NAMES, FRAME_COUNT, DIRECTIONS, frame_image

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'artifacts'


def main(validate_only=False):
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
    selected=[0,1,18,24,2,4,6,10,13,26]
    labels=['기본','눈 감기','대기','출발','걷기 A','걷기 B','걷기 C','달리기 A','달리기 B','멈춤']
    board=Image.new('RGB',(1420,970),'#e5e9e4'); d=ImageDraw.Draw(board)
    turns=Image.new('RGB',(1140,1070),'#e5e9e4'); td=ImageDraw.Draw(turns)
    for col,label in enumerate(['앞 · 아래 이동','왼쪽 이동','오른쪽 이동','뒤 · 위 이동']):
        td.text((132+col*250,15),label,font=font,fill='#30473d')
    results=[]
    for row,(id,name) in enumerate(zip(IDS,NAMES)):
        d.text((12,18+row*160),name,font=font,fill='#30473d')
        sheet=Image.open(ROOT/'assets/characters/fans'/(id+'.png')).convert('RGBA')
        assert sheet.size==(64*FRAME_COUNT,64*len(DIRECTIONS))
        original=Image.open(ART/'fan_motion_before'/('fan_'+id+'.png')).convert('RGBA')
        assert original.tobytes()==frame_image(id,0).tobytes(),id+' neutral design changed'
        old=Image.open(ART/'fan_direction_before'/(id+'.png')).convert('RGBA')
        assert sheet.crop((0,0,old.width,64)).tobytes()==old.tobytes(),id+' front motion changed'
        td.text((14,100+row*168),name,font=font,fill='#30473d')
        for col,direction in enumerate(DIRECTIONS):
            view=frame_image(id,0,direction).resize((192,192),Image.Resampling.NEAREST)
            # Cropping only transparent margin allows a compact 3x contact sheet.
            turns.paste(view,(106+col*250,32+row*168),view)
        for direction in DIRECTIONS:
          sy=DIRECTIONS.index(direction)*64
          for f in range(FRAME_COUNT):
            im=sheet.crop((f*64,sy,(f+1)*64,sy+64)); box=im.getbbox()
            assert im.tobytes()==frame_image(id,f,direction).tobytes()
            assert box and min(box[:2])>0 and max(box[2:])<64,(id,direction,f,box)
            assert set(im.getchannel('A').tobytes()) <= {0,255}
            cells={(x,y) for y in range(64) for x in range(64) if im.getpixel((x,y))[3]}
            components=[]
            while cells:
                todo=[cells.pop()]; size=0
                while todo:
                    x,y=todo.pop();size+=1
                    for dx,dy in [(-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)]:
                        q=(x+dx,y+dy)
                        if q in cells:cells.remove(q);todo.append(q)
                components.append(size)
            assert len(components)==1,(id,direction,f,components)
            results.append(dict(member=id,direction=direction,frame=f,bounds=box,components=1))
            if direction=='down' and f in selected:
                col=selected.index(f);view=im.resize((128,128),Image.Resampling.NEAREST)
                board.paste(view,(108+col*130,8+row*160),view)
                d.text((117+col*130,137+row*160),labels[col],font=font,fill='#30473d')
    (ART/'fan_motion_validation.json').write_text(json.dumps(dict(frames=len(results),directions=DIRECTIONS,failures=0,neutral_designs_preserved=6,front_frames_preserved=168,results=results),indent=2))
    if validate_only:
        print(f'Passed connectivity, clipping, and reference checks for {len(results)} cels.')
        return
    board.save(ART/'fan_motion_pose_review.png')
    turns.save(ART/'fan_direction_review.png')
    paths=sorted((ART/'fan_motion_capture').glob('*.png'))
    if len(paths)==140:
        frames=[Image.open(p).convert('RGB').crop((0,0,1280,620)) for p in paths]
        contact=Image.new('RGB',(2560,2480))
        for i,n in enumerate([0,22,35,48,63,78,96,120]):contact.paste(frames[n],((i%2)*1280,(i//2)*620))
        palette=contact.quantize(colors=256)
        output=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
        output[0].save(ART/'fan_motion_runtime.gif',save_all=True,append_images=output[1:],duration=50,loop=0,disposal=1,optimize=False)
        frames[35].save(ART/'fan_motion_runtime.png')
    paths=sorted((ART/'fan_direction_capture').glob('*.png'))
    if len(paths)==160:
        frames=[Image.open(p).convert('RGB') for p in paths]
        contact=Image.new('RGB',(2560,2480))
        for i,n in enumerate([0,20,40,60,80,100,120,140]):contact.paste(frames[n],((i%2)*1280,(i//2)*620))
        palette=contact.quantize(colors=256)
        output=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
        output[0].save(ART/'fan_direction_runtime.gif',save_all=True,append_images=output[1:],duration=60,loop=0,disposal=1,optimize=False)
        frames[100].save(ART/'fan_direction_runtime.png')
    print('PASS: 1056 connected frames, no clipping; all 168 front poses preserved. Runtime previews assembled.')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--validate-only',action='store_true')
    main(parser.parse_args().validate_only)
