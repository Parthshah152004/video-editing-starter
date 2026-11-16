// Screenshot a web page with system Chrome over CDP (Node 24 global WebSocket).
// usage: node page_shot.mjs <url> <out.png> [width=540] [height=1100] [scale=2] [hideCss]
// Overlays (cookie / consent banners) are hidden with injected CSS and DOM removal; nothing is clicked or accepted.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, out, w = '540', h = '1100', s = '2', extraCss = ''] = process.argv.slice(2);
const chrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9300 + Math.floor(Math.random() * 500);
const prof = mkdtempSync(join(tmpdir(), 'shot-'));
const p = spawn(chrome, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`, '--no-first-run', 'about:blank'], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let targets;
for (let i = 0; i < 40; i++) {
  try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); if (targets.length) break; } catch {}
  await sleep(250);
}
const ws = new WebSocket(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const waits = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && waits.has(d.id)) { waits.get(d.id)(d); waits.delete(d.id); } };
const send = (method, params = {}) => new Promise((r) => { const i = ++id; waits.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: +w, height: +h, deviceScaleFactor: +s, mobile: true });
await send('Page.navigate', { url });
await sleep(9000);
await send('Runtime.evaluate', { expression: `(()=>{
  const css=document.createElement('style');
  css.textContent='[id*=consent],[class*=consent],[id*=cookie],[class*=cookie],[id*=onetrust],[class*=onetrust],[id*=privacy],[class*=Privacy],[class*=modal],[class*=overlay],[class*=backdrop],[role=dialog],[aria-modal=true]{display:none!important} html,body{overflow:auto!important;filter:none!important;position:static!important} ${extraCss}';
  document.head.appendChild(css);
  document.querySelectorAll('div,section').forEach(e=>{const c=getComputedStyle(e); if((c.position==='fixed'||c.position==='sticky') && e.offsetHeight>150 && !/header|nav/i.test(e.tagName+e.className)) e.style.display='none';});
  document.querySelectorAll('*').forEach(e=>{ const tx=(e.innerText||'').trim(); if(/^BREAKING/i.test(tx) && e.offsetHeight>0 && e.offsetHeight<130 && e.getBoundingClientRect().top<60) e.style.display='none'; });
  document.body.style.overflow='auto'; return document.title; })()` });
await sleep(1500);
// Optional: HL='["snippet one","snippet two"]' writes <out>.rects.json with each snippet's line rectangles in output pixels.
if (process.env.HL) {
  const q = await send('Runtime.evaluate', { returnByValue: true, expression: `(()=>{
    const snips=${process.env.HL}; const S=${+s}; const res={};
    for(const sn of snips){ res[sn]=[];
      if(sn.startsWith('sel:')){ const el=document.querySelector(sn.slice(4)); if(el){ const r=document.createRange(); r.selectNodeContents(el);
        for(const c of r.getClientRects()) res[sn].push([Math.round(c.left*S),Math.round(c.top*S),Math.round(c.width*S),Math.round(c.height*S)]); } continue; }
      const tw=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);
      let n; while((n=tw.nextNode())){ const i=n.nodeValue.indexOf(sn); if(i<0) continue;
        const r=document.createRange(); r.setStart(n,i); r.setEnd(n,i+sn.length);
        for(const c of r.getClientRects()) res[sn].push([Math.round(c.left*S),Math.round(c.top*S),Math.round(c.width*S),Math.round(c.height*S)]);
        break; } }
    return res; })()` });
  writeFileSync(out + '.rects.json', JSON.stringify(q.result.result.value, null, 1));
}
const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
writeFileSync(out, Buffer.from(r.result.data, 'base64'));
ws.close(); p.kill();
console.log('saved', out);
