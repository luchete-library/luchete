"""Audit public video listings only; no logins, media downloads or save-game writes."""
import concurrent.futures
import datetime
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'artifacts' / 'broadcast_catalogue_20261115'
UA = 'Mozilla/5.0'
CHECKED = '2026-11-15'


def fetch(url, body=None, headers=None):
    url = urllib.parse.quote(url, safe=':/?=&%@,+')
    request_headers = {'User-Agent': UA, 'Accept-Language': 'ko-KR,ko;q=0.9'}
    request_headers.update(headers or {})
    payload = None if body is None else json.dumps(body).encode('utf-8')
    if payload is not None:
        request_headers['Content-Type'] = 'application/json'
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, data=payload, headers=request_headers)
            with urllib.request.urlopen(request, timeout=25) as response:
                return response.read().decode('utf-8')
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt+1)


def save(name, data):
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def nodes(obj, key):
    if isinstance(obj, dict):
        if key in obj:
            yield obj[key]
        for value in obj.values():
            yield from nodes(value, key)
    elif isinstance(obj, list):
        for value in obj:
            yield from nodes(value, key)


def text(obj):
    if isinstance(obj, str):
        return obj
    if not isinstance(obj, dict):
        return ''
    return obj.get('content') or obj.get('simpleText') or ''.join(r.get('text', '') for r in obj.get('runs', []))


def youtube_items(body):
    rows = {}
    for item in nodes(body, 'videoRenderer'):
        key = item.get('videoId')
        if key:
            rows[key] = {'id': key, 'title': text(item.get('title')), 'duration_text': text(item.get('lengthText')),
                         'published_hint': text(item.get('publishedTimeText'))}
    for item in nodes(body, 'lockupViewModel'):
        key = item.get('contentId')
        if not key or item.get('contentType') != 'LOCKUP_CONTENT_TYPE_VIDEO':
            continue
        meta = item.get('metadata', {}).get('lockupMetadataViewModel', {})
        durations = [v.get('text', '') for v in nodes(item.get('contentImage', {}), 'thumbnailBadgeViewModel')]
        hints = [text(v) for v in nodes(meta.get('metadata', {}), 'text')]
        rows[key] = {'id': key, 'title': text(meta.get('title')), 'duration_text': next((s for s in durations if re.fullmatch(r'[\d:]+', s)), ''),
                     'published_hint': ' / '.join(hints)}
    for row in rows.values():
        row['url'] = 'https://www.youtube.com/watch?v='+row['id']
    return rows


def yt_scan(job):
    owner, role, channel, tab = job
    result = {'owner': owner, 'role': role, 'platform': 'youtube', 'url': channel+'/'+tab,
              'tab': tab, 'checked_on': CHECKED, 'complete': False, 'pages': 0, 'items': []}
    collected = {}
    try:
        html = fetch(result['url'])
        found = re.search(r'var ytInitialData\s*=\s*(\{.*?\});', html)
        if not found:
            raise ValueError('Public page did not contain a video listing')
        initial = json.loads(found.group(1))
        meta = initial.get('metadata', {}).get('channelMetadataRenderer', {})
        result['channel'] = {k: meta.get(k) for k in ['title', 'externalId', 'description', 'vanityChannelUrl']}
        tabs = initial.get('contents', {}).get('twoColumnBrowseResultsRenderer', {}).get('tabs', [])
        selected = next((t['tabRenderer'] for t in tabs if t.get('tabRenderer', {}).get('selected')), {})
        selected_url = selected.get('endpoint', {}).get('commandMetadata', {}).get('webCommandMetadata', {}).get('url', '')
        if not selected_url.endswith('/'+tab):
            result.update(complete=True, absent_tab=True)
        else:
            config = {}
            for match in re.finditer(r'ytcfg\.set\(', html):
                try:
                    value, _ = json.JSONDecoder().raw_decode(html[match.end():])
                    config.update(value)
                except (ValueError, TypeError):
                    continue
            context = config.get('INNERTUBE_CONTEXT')
            if not context:
                raise ValueError('Public continuation context missing')
            body = selected.get('content', {})
            visited = set()
            while True:
                collected.update(youtube_items(body))
                result['pages'] += 1
                tokens = [v.get('token') for item in nodes(body, 'continuationItemRenderer')
                          for v in nodes(item, 'continuationCommand') if v.get('token')]
                if not tokens:
                    result['complete'] = True
                    break
                token = tokens[-1]
                if token in visited:
                    raise ValueError('Repeated pagination token')
                visited.add(token)
                body = json.loads(fetch('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false',
                                        {'context': context, 'continuation': token}, {'Origin': 'https://www.youtube.com'}))
                if 'error' in body:
                    raise ValueError('Public continuation rejected')
                time.sleep(.15)
    except Exception as error:
        result['error'] = str(error)
    result['items'] = list(collected.values())
    result['count'] = len(collected)
    save(f'{owner}_{role}_{tab}.json', result)
    print(json.dumps({k: result.get(k) for k in ['owner', 'role', 'tab', 'count', 'pages', 'complete', 'absent_tab', 'error']}, ensure_ascii=False), flush=True)
    return result


def chzzk_scan(channel):
    owner = channel['id']
    channel_id = channel['chzzk'].rsplit('/', 1)[-1]
    result = {'owner': owner, 'platform': 'chzzk', 'url': channel['chzzk']+'/videos', 'checked_on': CHECKED,
              'complete': False, 'pages': 0, 'items': []}
    seen = set()
    try:
        page = 0
        while True:
            url = f'https://api.chzzk.naver.com/service/v1/channels/{channel_id}/videos?sortType=LATEST&page={page}&size=50'
            payload = json.loads(fetch(url))
            if payload.get('code') != 200 or payload.get('content') is None:
                raise ValueError('Public list unavailable: '+str(payload.get('code')))
            body = payload['content']
            result['total_count'] = body.get('totalCount')
            result['pages'] += 1
            added = 0
            for item in body.get('data', []):
                key = str(item['videoNo'])
                if key in seen:
                    continue
                seen.add(key)
                added += 1
                result['items'].append({'id': key, 'url': 'https://chzzk.naver.com/video/'+key,
                                        'title': item.get('videoTitle'), 'published': item.get('publishDate'),
                                        'duration': item.get('duration'), 'video_type': item.get('videoType'),
                                        'tags': item.get('tags', []), 'category': item.get('videoCategoryValue'),
                                        'restricted': bool(item.get('adult') or item.get('paidProductId') or item.get('blindType'))})
            if page+1 >= body.get('totalPages', 1):
                result['complete'] = True
                break
            if not added:
                raise ValueError('No new items before the advertised last page')
            page += 1
            time.sleep(.15)
    except Exception as error:
        result['error'] = str(error)
    result['count'] = len(result['items'])
    save(f'{owner}_chzzk.json', result)
    print(json.dumps({k: result.get(k) for k in ['owner', 'platform', 'count', 'total_count', 'pages', 'complete', 'error']}, ensure_ascii=False), flush=True)
    return result


def channels():
    existing = json.loads((ROOT/'artifacts/broadcast_research/2026-11-06.json').read_text(encoding='utf-8'))['channels']
    result = [{k: c[k] for k in ['id', 'name', 'youtube', 'replay', 'chzzk']} for c in existing]
    result.append({'id': 'official', 'name': '리스텔라 공식', 'youtube': 'https://www.youtube.com/@listella_Official',
                   'replay': 'https://www.youtube.com/@listella_archive',
                   'chzzk': 'https://chzzk.naver.com/4571aa8b47759fa7e2983a59cfb0aee6'})
    return result


def inventory():
    entries = channels()
    save('channels.json', entries)
    jobs = [(c['id'], role, c[key], tab) for c in entries for role, key in [('main', 'youtube'), ('archive', 'replay')]
            for tab in ['videos', 'streams']]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(yt_scan, jobs))
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results += list(pool.map(chzzk_scan, entries))
    summary = {'checked_on': CHECKED, 'scope': 'Public videos/streams tabs and CHZZK video lists. Titles/metadata only, not full video viewing. Shorts, private, deleted and paid archives excluded.',
               'channels': entries, 'scans': [{k: r.get(k) for k in ['owner', 'role', 'platform', 'url', 'count', 'pages', 'complete', 'error']} for r in results]}
    save('inventory.json', summary)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    inventory()
