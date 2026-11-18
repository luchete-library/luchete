"""Compose captured public reference frames beside the current in-game sprites.

This makes a research comparison, not new character art. Run from any directory.
"""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'fan_reference_check'
FONT = 'C:/Windows/Fonts/malgun.ttf'
BOLD = 'C:/Windows/Fonts/malgunbd.ttf'

ROWS = [
    dict(id='yato', name='마토 · 야토', capture='yato_0010.jpg', time='0:10',
         url='https://www.youtube.com/watch?v=rROj9W7AKHw&t=10s', crop=(289, 289, 337, 354),
         feature='흰 토끼 + 남색 옷 + 노란 깃', error='현재: 옷이 없는 크림색 토끼',
         note='공식 영상의 작은 아이콘 · 얼굴 세부 미확정'),
    dict(id='danming', name='버리 · 단밍', capture='danming_5737.jpg', time='57:38',
         url='https://www.youtube.com/watch?v=V2ay38gIJTM&t=3457s', crop=(232, 212, 460, 414),
         feature='둥근 정면형 + 분홍 날개 + 넓은 배 띠', error='현재: 옆으로 기운 몸과 청록 날개',
         note='오단밍 다시보기 · 팬네임 공개'),
    dict(id='kubby', name='햄님 · 쿠비', capture='kubby_5400.jpg', time='54:01',
         url='https://www.youtube.com/watch?v=gj_0ibrZmds&t=3240s', crop=(142, 231, 340, 418),
         feature='민트색 부유형 몸 + 배 안의 보랏빛', error='현재: 머리 위 불꽃과 햄스터 발',
         note='햄쿠비 데뷔 방송 · 팬네임 공모 화면'),
    dict(id='yune', name='몽치 · 유네', capture='yune_0350.jpg', time='3:53',
         url='https://www.youtube.com/watch?v=yGwptbkUFUE&t=233s', crop=(53, 102, 255, 242),
         feature='둥근 검은 몸 + 큰 눈 + 보라색 꼬리 뭉치', error='현재: 길쭉한 고양이와 긴 깃털 꼬리',
         note='유네 본인 소개 영상 · 팬 캐릭터'),
    dict(id='dori', name='돌돌이 · 도리', capture='dori_0432.jpg', time='4:32',
         url='https://www.youtube.com/watch?v=d_fB7FrD_s8&t=272s', crop=(157, 78, 342, 300),
         feature='롤러 얼굴 + 작은 몸 + 위로 솟은 줄무늬 꼬리', error='현재: 갈색 손잡이가 달린 청소도구',
         note='도리 본인 소개 영상 · 당시 이름은 미정'),
    dict(id='fuwa', name='텐비 · 후와', capture='fuwa_0440.jpg', time='4:42',
         url='https://www.youtube.com/watch?v=j_E6l-2vSso&t=280s', crop=(339, 98, 585, 391),
         feature='흰 통몸 + 이마 소용돌이 + 낮은 꼬리', error='현재: 목띠와 큰 귀·꼬리가 있는 고양이형',
         note='후와 본인 소개 영상 · 팬 캐릭터'),
]


def main(redrawn=False):
    board = Image.new('RGB', (1280, 1240), '#ecede7')
    d = ImageDraw.Draw(board)
    title = ImageFont.truetype(BOLD, 30)
    heading = ImageFont.truetype(BOLD, 23)
    body = ImageFont.truetype(FONT, 19)
    small = ImageFont.truetype(FONT, 16)
    d.text((28, 20), '실제 원본을 기준으로 다시 찍은 팬 도트' if redrawn else '팬 캐릭터 원본 재확인', font=title, fill='#223d38')
    d.text((30, 66), '왼쪽: 공식·본인 영상 캡처   /   오른쪽: 원본을 반영한 게임 도트' if redrawn else '왼쪽: 공식·본인 영상 캡처   /   오른쪽: 현재 게임 도트 (수정 전)', font=body, fill='#394c47')
    for i, row in enumerate(ROWS):
        x, y = 24 + (i % 2) * 628, 108 + (i // 2) * 366
        d.rounded_rectangle((x, y, x + 604, y + 350), radius=12, fill='#ffffff', outline='#cdd4cd', width=2)
        d.text((x + 18, y + 14), row['name'], font=heading, fill='#263f39')
        d.text((x + 18, y + 51), '영상 원본', font=small, fill='#496c5d')
        d.text((x + 350, y + 51), '다시 찍은 도트' if redrawn else '수정 전 도트', font=small, fill='#496c5d' if redrawn else '#8a5646')
        reference = Image.open(OUT / row['capture']).crop(row['crop']).convert('RGB')
        ratio = min(295 / reference.width, 182 / reference.height)
        resample = Image.Resampling.NEAREST if row['id'] == 'yato' else Image.Resampling.LANCZOS
        reference = reference.resize((round(reference.width * ratio), round(reference.height * ratio)), resample)
        board.paste(reference, (x + 165 - reference.width // 2, y + 167 - reference.height // 2))
        d.rounded_rectangle((x + 337, y + 76, x + 579, y + 259), radius=6, fill='#e8ebe6')
        sprite_dir = ROOT / 'assets' / 'world_pixels' if redrawn else ROOT / 'artifacts' / 'fan_reference_before'
        sprite = Image.open(sprite_dir / f"fan_{row['id']}.png").convert('RGBA')
        sprite = sprite.crop(sprite.getbbox())
        scale = max(1, min(200 // sprite.width, 166 // sprite.height))
        sprite = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
        board.paste(sprite, (x + 458 - sprite.width // 2, y + 167 - sprite.height // 2), sprite)
        d.text((x + 17, y + 269), row['feature'], font=body, fill='#294a3e')
        d.text((x + 17, y + 297), '정면 · 눈 깜빡임 · 이동  /  게임에 적용' if redrawn else row['error'], font=body, fill='#65706a' if redrawn else '#8e5146')
        d.text((x + 17, y + 327), row['note'] + ' ' + row['time'], font=small, fill='#65706a')
    d.text((28, 1210), '2026-11-06 확인 · 공개 영상 속 기준 도안 비교 · 원본 링크와 확인 범위는 참고자료 문서에 기록', font=small, fill='#52665d')
    output = OUT / ('reference_vs_redrawn.png' if redrawn else 'reference_vs_current.png')
    board.save(output)
    if redrawn:
        sources_path = OUT / 'sources.json'
        payload = json.loads(sources_path.read_text(encoding='utf-8'))
        manifest = json.loads((ROOT / 'assets/characters/fans/manifest.json').read_text(encoding='utf-8'))
        payload['status'] = 'reference_applied_to_sprite_revision_' + str(manifest['revision'])
        payload['implementation'] = {
            'date': '2026-11-06', 'frames': sum(v['frames'] for v in manifest['members'].values()),
            'atlas_directory': 'assets/characters/fans',
            'comparison': 'artifacts/fan_reference_check/reference_vs_redrawn.png',
            'scope': 'Six playable fans and static icons; Tenbi and transformed Hamnim in existing comic scenes.',
            'limitation': 'Mato reference remains a small official-video icon; unconfirmed fine details are not added.'}
        sources_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(output)
        return
    payload = dict(reviewed_at='2026-11-06', status='reference_review_only_sprites_not_replaced',
                   scope='Observed designs in the linked public videos; not an exhaustive audit of all later variants.', references=ROWS)
    (OUT / 'sources.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(OUT / 'reference_vs_current.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--redrawn', action='store_true')
    main(parser.parse_args().redrawn)
