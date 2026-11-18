"""Inspect comics in a fresh Chrome profile with an isolated completed-story save."""
from pathlib import Path
import argparse
import functools
import http.server
import json
import math
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.cache/web_test_deps'))
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--url')
parser.add_argument('--label', default='local')
args = parser.parse_args()
OUT = ROOT / 'artifacts/comic_bounds_20261119' / args.label
OUT.mkdir(parents=True, exist_ok=True)
fixture = json.loads((ROOT / 'artifacts/growth_rollout_20261117/production_flow_save.json').read_text(encoding='utf-8'))
fixture['minutes'] = 600
server = None
if not args.url:
    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *values): pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(ROOT / 'build/web')))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    args.url = f'http://127.0.0.1:{server.server_port}/'

def close_position(width, height, dpr):
    pixel_scale = min(width*dpr/1280, height*dpr/800)
    px, py = 1280*pixel_scale, 800*pixel_scale
    unit = min(1, px/624, py/390)
    ax, ay = px/unit, py/unit
    compact = ay < 760
    ratio = min(1 if compact else 1.12, (ax-56)/710)
    x = math.floor((ax-(710*ratio+32))/2)
    x += sum(math.floor(n*ratio)+8 for n in [142,152,122,128])
    x += math.floor(166*ratio)/2
    y = ay-(31 if compact else 52)+(12 if compact else 17)
    return ((width*dpr-px)/2+x*unit)/dpr, ((height*dpr-py)/2+y*unit)/dpr

results = []
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='chrome', headless=True, args=['--enable-unsafe-swiftshader'])
        for name, dpr, touch in [('small_mouse',1,False), ('hidpi_touch',2,True)]:
            context = browser.new_context(viewport={'width':844,'height':390}, device_scale_factor=dpr, is_mobile=touch, has_touch=touch)
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda message: errors.append(message.text) if 'SCRIPT ERROR' in message.text else None)
            def start():
                page.get_by_role('button', name='도서관으로 들어가기').click()
                page.locator('#loading').wait_for(state='detached', timeout=120000)
                page.wait_for_timeout(1800)
                page.keyboard.press('Enter')
                page.wait_for_timeout(1000)
            def key(value):
                page.keyboard.press(value)
                page.wait_for_timeout(250)
            page.goto(args.url)
            start()
            for _ in range(5): key('e')
            key('F5');page.wait_for_timeout(2500)
            # Unload the game before modifying only this disposable browser's save.
            page.goto(args.url.rstrip('/')+'/FONT-LICENSE.txt')
            count = page.evaluate('''async fixture => {
              const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('/userfs');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
              const tx=db.transaction('FILE_DATA','readwrite'), store=tx.objectStore('FILE_DATA');
              let changed=0;
              const request=store.openCursor();
              request.onsuccess=()=>{const cursor=request.result;if(!cursor)return;
                if(String(cursor.key).endsWith('library_valley_v2.json')||String(cursor.key).endsWith('library_valley_v2.json.bak')){
                  const entry=cursor.value;entry.contents=new TextEncoder().encode(JSON.stringify(fixture));entry.timestamp=new Date();cursor.update(entry);changed++;
                }cursor.continue();};
              await new Promise((resolve,reject)=>{tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error)});db.close();return changed;
            }''', fixture)
            assert count >= 1, 'Isolated fixture save not created'
            page.goto(args.url);start()
            for member_key, member in [('6','fuwa'),('1','yato')]:
                key('j');key(member_key);key('v');key('4')
                page.wait_for_timeout(5000)
                page.screenshot(path=str(OUT/(name+'_'+member+'.png')))
                x,y=close_position(844,390,dpr)
                if touch: page.touchscreen.tap(x,y)
                else: page.mouse.click(x,y)
                page.wait_for_timeout(400)
                page.screenshot(path=str(OUT/(name+'_'+member+'_closed.png')))
                key('Escape');key('Escape')
            assert not errors, errors
            results.append({'case':name,'errors':errors,'fixture':'fresh profile only','visual_check_required':'four panels, wrapped captions, footer and book after close'})
            print(name+' complete', flush=True)
            context.close()
        browser.close()
finally:
    (OUT/'report.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if server: server.shutdown()
