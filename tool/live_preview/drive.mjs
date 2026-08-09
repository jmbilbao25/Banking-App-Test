// Minimal Chrome DevTools Protocol driver, no dependencies.
//
// Flutter web renders into a canvas, so there is nothing in the DOM to select.
// Every interaction here is a real mouse event at a coordinate, which is also a
// fair way to test a touch interface: if a control cannot be hit at the place it
// appears, it is broken.
//
// Node 22 ships a global WebSocket, so this needs nothing from npm.

const PORT = process.env.CDP_PORT || '9222';
const BASE = process.env.APP_URL || 'http://127.0.0.1:8099/index.html';
const OUT = process.env.SHOT_DIR || '/projects/sandbox/.kiro/artifacts/screenshots';

const fs = await import('node:fs/promises');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function targetUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json`);
      const list = await res.json();
      const page = list.find((t) => t.type === 'page');
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
    } catch {
      /* chrome not up yet */
    }
    await sleep(500);
  }
  throw new Error('no CDP page target');
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener('message', (e) => {
      const msg = JSON.parse(e.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
      }
    });
  }

  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`timeout ${method}`));
        }
      }, 30000);
    });
  }
}

async function connect(url) {
  const ws = new WebSocket(url);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });
  return new Cdp(ws);
}

const cdp = await connect(await targetUrl());
await cdp.send('Page.enable');
await cdp.send('Runtime.enable');

/// Pinned to the same canvas the golden suite uses, so a coordinate in this
/// script means the same thing as a coordinate measured off a golden. Without the
/// override Chrome reports whatever the window happens to be and every click
/// lands somewhere else.
const VW = Number(process.env.VW || 390);
const VH = Number(process.env.VH || 844);
await cdp.send('Emulation.setDeviceMetricsOverride', {
  width: VW,
  height: VH,
  deviceScaleFactor: 2,
  mobile: true,
});
if (process.env.TOUCH !== '0') {
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
}

async function shot(label) {
  const { data } = await cdp.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  const path = `${OUT}/${label}.png`;
  await fs.writeFile(path, Buffer.from(data, 'base64'));
  console.log(`shot ${label}`);
}

async function click(x, y, { label } = {}) {
  const common = { x, y, button: 'left', clickCount: 1 };
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', ...common });
  await sleep(60);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...common });
  await sleep(90);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...common });
  if (label) console.log(`click ${label} (${x},${y})`);
  await sleep(500);
}

async function type(text) {
  await cdp.send('Input.insertText', { text });
  await sleep(250);
}

async function evaluate(expression) {
  const r = await cdp.send('Runtime.evaluate', { expression, returnByValue: true });
  return r.result?.value;
}

/// Flutter web signals readiness by putting a glass pane in the DOM. Waiting on
/// a fixed sleep instead makes the run flaky on a cold canvaskit fetch.
async function waitForApp() {
  for (let i = 0; i < 60; i++) {
    const ready = await evaluate(
      `!!document.querySelector('flutter-view, flt-glass-pane, canvas')`,
    );
    if (ready) {
      await sleep(2500);
      return true;
    }
    await sleep(500);
  }
  return false;
}

/// Flutter web only builds a semantics DOM once it thinks assistive technology is
/// present, and it advertises that with a hidden placeholder button. Clicking it
/// turns the canvas into a real accessibility tree, which is worth far more than
/// coordinate guessing: elements can be addressed by the label a screen reader
/// would read, so a click that lands proves the control is both hittable and named.
async function enableSemantics() {
  const clicked = await evaluate(`(() => {
    const p = document.querySelector('flt-semantics-placeholder')
      || document.querySelector('[aria-label="Enable accessibility"]');
    if (!p) return 'no-placeholder';
    p.click();
    return 'clicked';
  })()`);
  await sleep(1500);
  return clicked;
}

/// Every labelled node in the semantics tree, with its centre in CSS pixels.
async function semantics() {
  return evaluate(`(() => {
    const out = [];
    const seen = new Set();
    for (const el of document.querySelectorAll('flt-semantics, input, textarea')) {
      const r = el.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;
      // Flutter hangs the readable string off a descendant node rather than the
      // node carrying the role, so both have to be considered.
      const label =
        el.getAttribute('aria-label') ||
        el.getAttribute('placeholder') ||
        (el.textContent || '').trim().slice(0, 60);
      if (!label) continue;
      const key = label + r.x + r.y;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({
        label,
        role: el.getAttribute('role') || el.tagName.toLowerCase(),
        x: Math.round(r.x + r.width / 2),
        y: Math.round(r.y + r.height / 2),
        w: Math.round(r.width),
        h: Math.round(r.height),
      });
    }
    return JSON.stringify(out);
  })()`);
}

/// Clicks the centre of the first semantics node whose label contains `needle`.
async function clickLabel(needle, { exact = false } = {}) {
  const nodes = JSON.parse((await semantics()) || '[]');
  const want = needle.toLowerCase();
  const matches = nodes.filter((n) =>
    exact ? n.label === needle : n.label.toLowerCase().includes(want),
  );
  if (matches.length === 0) {
    console.log(`MISS "${needle}"`);
    return false;
  }
  // The root of the tree carries every string on the screen concatenated, so a
  // naive first match reliably clicks the middle of the page. Prefer something
  // interactive, then the tightest label, then the smallest box.
  const interactive = new Set(['button', 'input', 'textbox', 'link', 'checkbox']);
  matches.sort((a, b) => {
    const ai = interactive.has(a.role) ? 0 : 1;
    const bi = interactive.has(b.role) ? 0 : 1;
    if (ai !== bi) return ai - bi;
    if (a.label.length !== b.label.length) return a.label.length - b.label.length;
    return a.w * a.h - b.w * b.h;
  });
  const hit = matches[0];
  await click(hit.x, hit.y, { label: `${needle} -> [${hit.role}] "${hit.label}"` });
  return true;
}

const script = JSON.parse(process.env.STEPS || '[]');

await cdp.send('Page.navigate', { url: BASE });
const ready = await waitForApp();
console.log(`app ready: ${ready}`);
console.log('viewport:', await evaluate('[innerWidth, innerHeight]'));

if (process.env.A11Y !== '0') {
  console.log('semantics:', await enableSemantics());
}

for (const step of script) {
  if (step.shot) await shot(step.shot);
  if (step.click) await click(step.click[0], step.click[1], { label: step.label });
  if (step.tap) await clickLabel(step.tap, { exact: step.exact });
  if (step.type !== undefined) await type(step.type);
  if (step.eval) {
    console.log(`eval -> ${JSON.stringify(await evaluate(step.eval))}`);
  }
  if (step.dump) {
    const nodes = JSON.parse((await semantics()) || '[]');
    console.log(`--- semantics (${nodes.length}) ---`);
    for (const n of nodes) {
      console.log(`  [${n.role}] "${n.label}" ${n.w}x${n.h} @${n.x},${n.y}`);
    }
  }
  if (step.wait) await sleep(step.wait);
}

console.log('done');
process.exit(0);
