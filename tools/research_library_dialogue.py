"""Read only public official profile pages; no accounts, media or player saves."""
import concurrent.futures
import json
import re
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'library_care_20261118' / 'official_sources'


class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hidden = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self.hidden += 1

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.hidden = max(0, self.hidden - 1)

    def handle_data(self, value):
        if not self.hidden and value.strip():
            self.parts.append(value.strip())


def fetch(item):
    member, record = item
    url = record['source']
    result = {'member': member, 'url': url, 'checked_on': '2026-11-18'}
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=18) as response:
            raw = response.read().decode('utf-8')
        parser = VisibleText()
        parser.feed(raw)
        content = '\n'.join(parser.parts)
        (OUT / f'{member}.html').write_text(raw, encoding='utf-8')
        (OUT / f'{member}.txt').write_text(content, encoding='utf-8')
        result.update(status='retrieved', text=content)
    except Exception as exc:
        result.update(status='unavailable', reason=str(exc))
    return result


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    records = json.loads((ROOT / 'assets/story/debut_records.json').read_text(encoding='utf-8-sig'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(fetch, records['books'].items()))
    (OUT / 'profiles.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    for result in results:
        print(result['member'], result['status'], len(result.get('text', '')))
