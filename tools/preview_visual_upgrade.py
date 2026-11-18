"""Review plates built from the actual no-save render captures and original assets."""
from pathlib import Path
import json,re
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'artifacts'
FONT=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',19)
BOLD=ImageFont.truetype('C:/Windows/Fonts/malgunbd.ttf',26)


def scene_grid():
    items=[('정원 · 돌길과 연못','visual_garden'),('도리 · 마을과 사건 소품','visual_dori_0'),('유네 · 꿈의 연못과 드림캐처','visual_yune_1'),('단밍 · 화살을 손질하는 작업실','visual_danming_1'),('쿠비 · 새로운 발걸음','visual_kubby_3'),('후와 · 눈산과 앞발 자국','visual_fuwa_1')]
    out=Image.new('RGB',(1280,1410),'#273c35');d=ImageDraw.Draw(out)
    d.text((24,14),'루체테 도서관 · 전체 도트 점검과 보강',font=BOLD,fill='#f0dfb6')
    for i,(label,name) in enumerate(items):
        x=i%2*640;y=60+i//2*450
        im=Image.open(ART/(name+'.png')).resize((640,400),Image.Resampling.NEAREST)
        out.paste(im,(x,y+33));d.text((x+14,y+5),label,font=FONT,fill='#f0dfb6')
    out.save(ART/'visual_upgrade_scenes.png')


def comparisons():
    out=Image.new('RGB',(1280,1040),'#273c35');d=ImageDraw.Draw(out)
    d.text((24,14),'변경 전',font=BOLD,fill='#f0dfb6');d.text((664,14),'변경 후',font=BOLD,fill='#f0dfb6')
    for col,root in enumerate([ART/'visual_upgrade_before',ART]):
        im=Image.open(root/('garden.png' if col==0 else 'visual_garden.png')).resize((640,400),Image.Resampling.NEAREST)
        out.paste(im,(col*640,55))
        for i,member in enumerate(['danming','dori']):
            path=ART/'visual_upgrade_before'/(member+'.png') if col==0 else ROOT/'assets/comics'/(member+'.png')
            sheet=Image.open(path)
            row=0 if member=='danming' else 1
            if col==1: row*=2  # Current atlas packs each cut across two rows.
            cut=sheet.crop((8*228,row*110,9*228,(row+1)*110)).resize((592,286),Image.Resampling.NEAREST)
            out.paste(cut,(col*640+24,465+i*286))
    out.save(ART/'visual_upgrade_comparison.png')


def parts():
    items=['tree','cottage','dream_bed','prop_ring','prop_lens','prop_library_door','prop_hamster','prop_satchel','traveler_0','role_dori_0','role_yune_0','role_fuwa_0','fan_yato','fan_danming','fan_kubby','fan_yune','fan_dori','fan_fuwa']
    out=Image.new('RGB',(1080,950),'#273c35');d=ImageDraw.Draw(out)
    d.text((20,14),'직접 찍은 새 도트 · 일부 부품 확대',font=BOLD,fill='#f0dfb6')
    for i,name in enumerate(items):
        x=i%6*180;y=60+i//6*295
        d.rectangle((x+5,y,x+175,y+285),fill='#465a4e')
        im=Image.open(ROOT/'assets/world_pixels'/(name+'.png')).convert('RGBA');im=im.crop(im.getbbox())
        scale=min(154/im.width,240/im.height);im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
        out.paste(im,(x+(180-im.width)//2,y+(250-im.height)//2),im)
        d.text((x+12,y+255),name.replace('prop_','').replace('role_',''),font=FONT,fill='#f0dfb6')
    out.save(ART/'visual_upgrade_parts.png')


def audit_delta():
    previous=json.loads((ART/'visual_upgrade_before/inventory.json').read_text(encoding='utf-8'))
    current=json.loads((ART/'visual_audit/inventory.json').read_text(encoding='utf-8'))
    before={i['path']:i['sha256'] for i in previous['inventory']}
    after={i['path']:i['sha256'] for i in current['inventory']}
    result={'previous_images':len(before),'current_images':len(after),'new':[p for p in after if p not in before],'changed':[p for p in after if p in before and before[p]!=after[p]],'preserved':sum(before.get(p)==h for p,h in after.items()),'atlas_cells':current['atlas_cells'],'frame_edge_alerts':current['edge_alerts']}
    manifest=json.loads((ROOT/'assets/world_pixels/manifest.json').read_text(encoding='utf-8'))
    alpha_errors=[]
    for name,data in manifest['sprites'].items():
        im=Image.open(ROOT/'assets/world_pixels'/(name+'.png')).convert('RGBA')
        assert list(im.size)==data['native_size'],name
        if not set(im.getchannel('A').get_flattened_data()).issubset({0,255}):alpha_errors.append(name)
    result['new_pixel_alpha_errors']=alpha_errors
    (ART/'visual_audit/change_report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print({k:len(v) if isinstance(v,list) else v for k,v in result.items()})


def story_details():
    """Assemble actual render captures; this does not repaint game assets."""
    folder=ART/'story_visual_upgrade'
    after=folder/'after'
    after.mkdir(exist_ok=True)
    entries=[('야토 · 토끼 가족의 곳간','yato_storehouse'),
             ('단밍 · 버리의 돋보기','danming_workbench_loupe'),
             ('도리 · 돌돌이의 탁본','dori_alley_rubbing'),
             ('유네 · 꿈빛이 옅어지는 밤','yune_nights_first'),
             ('쿠비 · 햄스터와의 만남','kubby_village_hamster'),
             ('후와 · 신사에서 결계 수련','fuwa_shrine_training')]
    out=Image.new('RGB',(1280,1370),'#28352f')
    d=ImageDraw.Draw(out)
    d.text((20,12),'책 속 체험 · 도트 디테일 개선 / 실제 게임 화면',font=BOLD,fill='#f3dfb3')
    for i,(label,name) in enumerate(entries):
        shot=Image.open(ART/(name+'.png')).convert('RGB')
        shot.save(after/(name+'.png'))
        x=i%2*640;y=56+i//2*434
        d.text((x+14,y),label,font=FONT,fill='#f3dfb3')
        out.paste(shot.resize((640,400),Image.Resampling.NEAREST),(x,y+30))
    out.save(folder/'six_scenes.png')
    comparison=Image.new('RGB',(1280,918),'#28352f')
    d=ImageDraw.Draw(comparison)
    d.text((20,12),'개선 전',font=BOLD,fill='#f3dfb3')
    d.text((660,12),'개선 후 · 실제 게임 화면',font=BOLD,fill='#f3dfb3')
    for row,(label,name) in enumerate(entries[:2]):
        for col,location in enumerate([folder/'before',after]):
            y=56+row*430
            d.text((col*640+14,y),label,font=FONT,fill='#f3dfb3')
            shot=Image.open(location/(name+'.png')).resize((640,400),Image.Resampling.NEAREST)
            comparison.paste(shot,(col*640,y+26))
    comparison.save(folder/'before_after.png')


if __name__=='__main__':
    import sys
    if '--story-details' in sys.argv:
        story_details()
    else:
        scene_grid();comparisons();parts();audit_delta()
