"""Smoke-test the exported game in an isolated local Chrome profile.

Requires playwright (pip install playwright) and installed Chrome. No user
browser profile or native game save is read or changed.
"""
from pathlib import Path
import functools
import http.server
import json
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.cache/web_test_deps'))
from playwright.sync_api import sync_playwright

OUT = ROOT / 'artifacts/web_deploy_20261118'
OUT.mkdir(parents=True, exist_ok=True)
class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(ROOT / 'build/web')))
threading.Thread(target=server.serve_forever, daemon=True).start()
messages = []
errors = []
results = {}
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='chrome', headless=True, args=['--enable-unsafe-swiftshader'])
        context = browser.new_context(viewport={'width':1280, 'height':800})
        page = context.new_page()
        page.on('console', lambda message: messages.append({'type':message.type, 'text':message.text}))
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
        page.screenshot(path=str(OUT/'web_loading.png'))
        page.get_by_role('button', name='도서관으로 들어가기').click()
        page.locator('#loading').wait_for(state='detached', timeout=120000)
        page.wait_for_timeout(5000)
        page.screenshot(path=str(OUT/'web_title.png'))
        print('Browser game started', flush=True)
        page.keyboard.press('Enter')
        page.wait_for_timeout(2000)
        page.screenshot(path=str(OUT/'web_intro.png'))
        for _ in range(10):
            page.keyboard.press('e')
            page.wait_for_timeout(250)
        page.keyboard.press('Escape')
        page.keyboard.press('F5')
        page.wait_for_timeout(4000)
        page.screenshot(path=str(OUT/'web_library.png'))
        results['indexed_db'] = page.evaluate('''async () => {
            const databases = await indexedDB.databases();
            const result = [];
            for (const info of databases) {
                const db = await new Promise((resolve,reject) => {const request=indexedDB.open(info.name);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});
                for (const store of db.objectStoreNames) {
                    const keys = await new Promise((resolve,reject) => {const request=db.transaction(store).objectStore(store).getAllKeys();request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});
                    result.push({database:info.name,store,keys});
                }
                db.close();
            }
            return result;
        }''')
        assert any('library_valley_v2.json' in str(item['keys']) for item in results['indexed_db']), 'Save missing from IndexedDB'
        page.reload()
        page.get_by_role('button', name='도서관으로 들어가기').click()
        page.locator('#loading').wait_for(state='detached', timeout=120000)
        page.wait_for_timeout(3000)
        page.keyboard.press('Enter')
        page.wait_for_timeout(2500)
        page.screenshot(path=str(OUT/'web_reload.png'))
        results['reload_completed'] = True
        results['page_errors'] = errors
        results['console'] = messages
        (OUT/'browser_report.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
        assert not errors, errors
        assert not any('SCRIPT ERROR' in item['text'] for item in messages), 'GDScript runtime error'
        print('WEB SMOKE OK: load, keyboard, save persistence, reload; see screenshots for visual review', flush=True)
        browser.close()
finally:
    (OUT/'browser_report.json').write_text(json.dumps({**results,'page_errors':errors,'console':messages},ensure_ascii=False,indent=2),encoding='utf-8')
    server.shutdown()
