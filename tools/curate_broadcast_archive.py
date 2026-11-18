"""Build a reviewable event catalogue from the complete public listing audit.

Only source titles/descriptions are evidence; this does not claim full VOD viewing.
Output stays under artifacts until the user approves the new shelf arrangement.
"""
import concurrent.futures
import datetime
import json
import re
import sys
from pathlib import Path
from catalogue_public_broadcasts import DEST, ROOT, fetch, save

# owner | YYYY-MM-DD or blank (upload date only) | video ID[,part 2] | display title
SELECTION = """
yato|2023-06-03|H5TE0hFUlLM|야토의 데뷔 방송
yato|2023-06-04|sTk8yUao-gw|팬네임을 정하던 날
yato|2024-01-18|FO3Ot3LRojQ|야탄일 · 생일 방송
yato|2024-03-04|AQDL_yrEkWA|2024년 3D 데뷔
yato|2024-05-05|nfymca0B20I|어린이날 · 새로운 모습
yato|2024-06-03|qC8rhRWMtw8|첫 번째 주년
yato|2024-07-19|rcYgpdoRcBE|3D 1.5 공개
yato|2024-07-26|iTt_ju65sNE|새 의상을 공개한 날
yato|2024-10-14|0GvMWMQBE1w|데뷔 500일
yato|2024-12-31|C3rXt0aBepI|2024년을 보내며
yato|2025-06-03|hNzZzTyANRY|두 번째 주년
yato|2025-12-14|VGy1Md2LNSk|리스텔라 신년 타로
yato|2026-01-18|MPU9S-njCFk|2026년 생일 방송
yato|2026-04-01|3AIMkjjUkFk|만우절 · 몸이 바뀐다면
yato|2026-05-05|oWPa0JYo9DY|야리 탄신 2주년
yato|2026-06-03|Al2ogQY4F_c,MnVDcZoMieg|세 번째 주년
yato|2026-06-21|69gwK2UEKyI|팬미팅 후기
yato|2026-11-07|16061701,eRxPwMe2Qvw|3D 리뉴얼 공개
danming|2024-09-15|eHZJ-elBDXI|단밍의 데뷔 방송
danming|2024-09-16|V2ay38gIJTM|팬네임 맞추기 이벤트
danming|2024-09-18|zThNkKqyXtM|클리프 릴레이 노래방
danming|2024-12-31|zYcaQ6rQBrw|2024년 연말결산
danming|2025-03-14|cYpAJR4XCxg|양갈래 머리와 커버곡
danming|2025-04-01|m2bWetJBqfQ|만우절 · 흑단밍 데뷔
danming|2025-06-01|-n4kFm5wkYs|첫 번째 생일 방송
danming|2025-09-15|p0y1Kr795lg,sDAgxio7xeo|1주년 · 예열과 후열
danming|2025-12-25|YOXTshrr7qg|크리스마스 트리 읽기
danming|2025-12-31|HW5zsvjWJ6s|2025년 연말정산
danming|2026-02-22|S23dgOEiSbs|서큐버스 신의상 공개
danming|2026-04-01|SDiW4m8hofw|만우절 · 몸 바꾸기
danming|2026-06-01|E1GsBFeZUUw|두 번째 생일 방송
danming|2026-06-25|Fej3AQ7jUzU|메챠 카멜레온 합방
danming|2026-06-28|4GaKNnbCtk8|두 번째 팬미팅 후기
danming|2026-09-15|3wTQ9REYoos|2주년 후열 방송
danming|2026-10-17|r0oktscqoos|레이싱 신의상 공개
danming|2026-10-19|U6dyZAT_KyU|에테 데뷔 · 공지 같이보기
kubby|2024-09-15|gj_0ibrZmds|쿠비의 데뷔 방송
kubby|2024-09-18|bxxxJpwpUCA|클리프 릴레이 노래방
kubby|2024-09-22|2p_wERFMpSU|팬네임을 정하던 날
kubby|2024-12-23|UGE9CwaKV2c|데뷔 100일 방송
kubby|2024-12-31|MBF1_0Eju8A|2024 HAMTY와 새해맞이
kubby|2025-01-01|V8Mo6j1EwBM|새해 햄님 설문조사
kubby|2025-04-01|4SApKr3uFQc|만우절 · 텐시비 강림
kubby|2025-04-12|LGecQPBS1WU|첫 번째 생일 파티
kubby|2025-09-15|f9vhhvz2000|햄님과 1주년 파티
kubby|2025-10-31|CWKoXxh6ItE|할로윈 · 시청자 담력시험
kubby|2025-12-31|wibUJfNgEgE|2025 HAMTY와 해돋이
kubby|2026-04-01|dhBUnLiUUWg|만우절 · 영혼 바꾸기
kubby|2026-04-12|SrEwDsxoi9U,yW5j92uGWp0|두 번째 생일 파티
kubby|2026-04-25|WIhKjXGmlGA|첫 신의상과 커버곡
kubby|2026-06-25|MuxKkSGmR4A|메챠 카멜레온 합방
kubby|2026-11-14|16173929|2026년 3D 데뷔
yune|2026-05-25|_Tsj7FsImlE|유네의 데뷔 방송
yune|2026-05-26|3_jvAGsD-Kk|데뷔 다음 날의 이야기
yune|2026-05-29|kUwV07ysdvg|구독 오픈과 노래 극복기
yune|2026-09-01|vN7qV6vmQk0|100일 후열 방송
yune|2026-09-07|sB2ganASzNc,nVHW6j3qjCU|앵스텔라 합방
yune|2026-10-21|VgQJv0PpABU|동기들과 봄바나나
yune|2026-10-31|Ly0E-lg_bRc|유네와 첫 할로윈
dori|2026-05-25|0m9bYVeaKj0|도리의 데뷔 방송
dori|2026-06-20|jmJr-TtiNlM|유네와 게릴라 합방
dori|2026-06-25|1oJJWLXMTx8|메챠 카멜레온 합방
dori|2026-08-28|fSBoqOuOPuU,i38XRuT6Hc0|첫 번째 생일 파티
dori|2026-09-01|OvNyIVUYKNg|100일 후열 · 뉴텔라
dori|2026-09-17|repvLE78oWw|리스텔라 싱크룸 노래방
dori|2026-10-21|yn0mQfhQJQ8|동기들과 봄바나나
dori|2026-10-31|WPITUa28Nps|할로윈 · 다른 옷으로
fuwa|2026-05-25|JvqjP_BAX6U|후와의 데뷔 방송
fuwa|2026-05-26|YzWr_LxNy8Q|데뷔 방송 후기
fuwa|2026-05-28|FiOyC_RyKxU|후와의 첫 노래방
fuwa|2026-06-25|3Mu16r5BrlI|메챠 카멜레온 합방
fuwa|2026-09-01|XMgAxshaaYA|100일 후열 방송
fuwa|2026-10-21|15799452|동기들과 봄바나나
fuwa|2026-11-04|aSiDR3Ayhuo|라면집 합방
official|2024-09-15|BUP01PtwsiY|클리프 데뷔 후열 합방
official|2024-09-17|8DNraivZD3U|추석 · 송편 대작전
official|2024-09-18|DLVMl9XQ2Io|클리프 단체 싱크룸
official|2024-09-29|R0KcgJS2KwY|다 함께 피코파크 2
official|2024-10-01|S8WTwvJ1ghQ|괴식탐구회
official|2024-12-23|_VThNqjyYVo|클리프 100일 · 이상한 초대
official|2025-01-24|sp4gU0LnG5o|신년 듀엣 가요제
official|2025-02-07|RWXOVHS-JpQ|월간 2월 · 집 정리
official|2025-03-06|Mk45wdTss4w|월간 3월 · 벚꽃놀이
official|2025-04-05|R_eKP34HWJQ|월간 4월 · 만우절 장난
official||aon-V07e0OI|리스텔라 유치원
official|2025-08-31|m_nSA76fd3g|패션왕 · 단밍과 쿠비
official|2025-09-15|BQpc5CHIjR4|단밍·쿠비 1주년
official|2025-09-29|g9hq8iHtHF4|루체테 문화센터
official|2025-09-30|lTRZxyn12FI|2025년 공지 방송
official|2026-01-17|VKrYwlN09n4|패션왕 두 번째 시간
official||YfuY45kWNV8|한국·말레이시아 과자 리뷰
official|2026-02-18|Sk9JactTkVw|설 특집 · 훈민정음 윷놀이
official|2026-03-30|l8MqWJ8kTuc|월간 리스텔라 퀴즈왕
official||Qvp5rP24HN4|3등분의 단밍과 쿠비
official|2026-06-20|5hMTmRiDI-w|신입생 오리엔테이션
official||hhk0DDqlxG8|그로서리 서울 라이브 방송
official|2026-08-23|9TnZPG06Nj4|서새봄의 스텔라 상담소
official|2026-09-01|mSvIP6EjvSc|유네·도리·후와 100일
official|2026-09-15|cEeVNDSjL9c|단밍·쿠비 2주년
official|2026-10-19|3hIAel12pbw|2026년 하반기 공지
"""


def selections():
    rows = []
    inventory = json.loads((DEST/'unique_items.json').read_text(encoding='utf-8'))
    by_key = {(r['owner'], r['id']): r for r in inventory}
    for line in SELECTION.strip().splitlines():
        owner, date, ids, title = line.split('|')
        sources = []
        for video_id in ids.split(','):
            source = by_key[(owner, video_id)]
            if source.get('restricted'):
                raise ValueError('Restricted public source: '+video_id)
            sources.append(source)
        rows.append({'owner': owner, 'date': date, 'title': title, 'sources': sources})
    return rows


def detail(source):
    key = source['id']
    target = DEST/'details'/f'{key}.json'
    if target.exists():
        return json.loads(target.read_text(encoding='utf-8'))
    result = {'id': key, 'url': source['url'], 'owner': source['owner'], 'platform': source['platform'],
              'checked_on': '2026-11-15', 'evidence_level': 'title_description', 'full_video_watched': False}
    try:
        if source['platform'] == 'youtube':
            html = fetch(source['url'])
            match = re.search(r'var ytInitialPlayerResponse\s*=\s*(\{.*?\});', html)
            if not match:
                raise ValueError('No public player metadata')
            player = json.loads(match.group(1))
            video = player.get('videoDetails', {})
            meta = player.get('microformat', {}).get('playerMicroformatRenderer', {})
            result.update(title=video.get('title'), description=video.get('shortDescription', ''),
                          author=video.get('author'), channel_id=video.get('channelId'),
                          duration_seconds=int(video.get('lengthSeconds', 0)),
                          status=player.get('playabilityStatus', {}).get('status'),
                          publish_date=meta.get('publishDate'), upload_date=meta.get('uploadDate'),
                          live=meta.get('liveBroadcastDetails'))
            result['timestamps'] = [line.strip() for line in result['description'].splitlines()
                                    if re.search(r'(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)', line)]
        else:
            payload = json.loads(fetch('https://api.chzzk.naver.com/service/v2/videos/'+key))
            video = payload.get('content')
            if payload.get('code') != 200 or not video:
                raise ValueError('No public VOD metadata')
            # Explicit allow-list: never persist playback tokens, cookies or signed stream URLs.
            result.update(title=video.get('videoTitle'), author=video.get('channel', {}).get('channelName'),
                          channel_id=video.get('channel', {}).get('channelId'),
                          duration_seconds=video.get('duration'), publish_date=video.get('publishDate'),
                          live_open_date=video.get('liveOpenDate'), status=video.get('vodStatus'),
                          chapters=video.get('chapters'), description='', timestamps=[])
        result['verified'] = bool(result.get('title'))
    except Exception as error:
        result.update(verified=False, error=str(error))
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(key, 'verified' if result['verified'] else result.get('error'), flush=True)
    return result


def main():
    rows = selections()
    save('selected_events.json', rows)
    sources = {s['id']: s for r in rows for s in r['sources']}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        result = list(pool.map(detail, sources.values()))
    save('selected_details.json', result)
    print(json.dumps({'events': len(rows), 'sources': len(sources),
                      'verified': sum(r['verified'] for r in result)}, ensure_ascii=False))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
