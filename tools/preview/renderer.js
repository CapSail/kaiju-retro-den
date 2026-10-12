// Draws the project's REAL Rainmeter skin files (window.SKINS, window.THEME) on top of the real wallpaper canvas, to make the README picture.
// It understands only the small part of Rainmeter the skins use: Shape meters (Rectangle, Ellipse, Line, Path, Combine/Exclude, linear gradients),
// String meters, Bar meters, Calc measures and simple IfCondition show/hide. Everything dynamic is given sample values below.
(function () {
  const W = 1920, H = 1080;
  const SAMPLE = {   // measure name -> { num, text }   (illustration values; the TV shows a test card, not a real movie)
    TVRemote: { mVol: { num: 35, text: '35' }, mRun: { num: 1, text: 'ON' }, mHid: { num: 0, text: '0' }, mHidT: { text: 'HIDE' }, mPause: { text: 'PAUSE' }, mMute: { text: 'SOUND' }, mSubs: { text: 'SUBS ON' }, mTitle: { text: 'Drive-In Double Feature (1977)' } },
    Scene: { mTitle: { text: 'NEON SKYLINE' }, mArtist: { text: 'The Kaiju Quartet' }, mProg: { num: 38 }, mCtl: { num: 0 } },
    Systems: { mCPU: { num: 23 }, mRAM: { num: 7.7 }, mRAMt: { num: 16 }, mDfree: { num: 61 }, mDtot: { num: 100 }, mIn: { text: '12.4 K' }, mOut: { text: '3.1 K' }, mUp: { text: '2d 07h 41m' } },
    Console: { mGame: { text: 'KAIJU GAME GUIDE' } }
  };
  const BUILTIN = { SCREENAREAWIDTH: W, SCREENAREAHEIGHT: H };

  function parseIni(text) {
    const secs = []; let cur = null;
    text.replace(/\r/g, '').split('\n').forEach(l => {
      if (!l.trim() || l[0] === ';') return;
      const m = l.match(/^\[(.+)\]\s*$/); if (m) { cur = { name: m[1], opts: {}, keys: [] }; secs.push(cur); return; }
      const i = l.indexOf('='); if (i < 0 || !cur) return;
      const k = l.slice(0, i).trim(); cur.opts[k] = l.slice(i + 1).trim(); cur.keys.push(k);
    });
    return secs;
  }
  const theme = {}; parseIni(window.THEME).forEach(s => { if (s.name === 'Variables') Object.assign(theme, s.opts); });

  function makeSkin(name, text) {
    const secs = parseIni(text), vars = Object.assign({}, theme);
    secs.forEach(s => { if (s.name === 'Variables') Object.assign(vars, s.opts); });
    const lower = {}; Object.keys(vars).forEach(k => lower[k.toLowerCase()] = vars[k]); Object.keys(BUILTIN).forEach(k => lower[k.toLowerCase()] = String(BUILTIN[k]));
    const sample = SAMPLE[name] || {}, measures = {}, hide = {};
    const sub = s => { for (let i = 0; i < 12 && /#[A-Za-z0-9_]+#/.test(s); i++) s = s.replace(/#([A-Za-z0-9_]+)#/g, (m, n) => (n.toLowerCase() in lower) ? lower[n.toLowerCase()] : m); s = s.replace(/\[([A-Za-z_]\w*)\]/g, (m, n) => secs.some(x => x.name === n) ? String(measureNum(n)) : m); return s; };   // [measure] references -> their value (gauge needles)
    const calc = expr => { try { return Function('"use strict";return (' + expr + ')')(); } catch (e) { return 0; } };
    const evalFormula = (f, depth = 0) => {                       // Calc: identifiers are measure names or sin/cos
      const e = f.replace(/\b(sin|cos)\b/g, 'Math.$1').replace(/\b[A-Za-z_]\w*\b/g, id => (/^(Math|sin|cos)$/.test(id) ? id : String(measureNum(id, depth + 1))));
      return calc(e);
    };
    function measureNum(id, depth = 0) {
      if (depth > 10) return 0; if (measures[id] !== undefined) return measures[id];
      const s = secs.find(x => x.name === id); let v = 0;
      if (sample[id] && sample[id].num !== undefined) v = sample[id].num;
      else if (s && s.opts.Measure === 'Calc') v = evalFormula(sub(s.opts.Formula || '0'), depth);
      return measures[id] = v;
    }
    const measureText = id => { if (sample[id] && sample[id].text !== undefined) return sample[id].text; return String(Math.round(measureNum(id))); };
    secs.forEach(s => {                                          // IfCondition: show/hide meters (the TV glass and lamp)
      if (s.opts.Measure !== 'Calc' || !s.opts.IfCondition) return;
      const cond = s.opts.IfCondition.replace(/\b[A-Za-z_]\w*\b/g, id => String(measureNum(id)));
      const act = calc(cond) ? s.opts.IfTrueAction : s.opts.IfFalseAction; if (!act) return;
      (act.match(/\[!(Show|Hide)Meter ([^\]]+)\]/g) || []).forEach(a => { const m = a.match(/!(Show|Hide)Meter ([^\]]+)/); hide[m[2]] = (m[1] === 'Hide'); });
    });
    const value = v => { v = sub(v == null ? '' : v); return /^\(.*\)$/.test(v) ? calc(v) : parseFloat(v); };
    return { name, secs, sub, value, measureNum, measureText, hide };
  }

  const rgba = (c, a) => { const p = c.split(',').map(Number); const al = p.length > 3 ? p[3] / 255 : 1; return `rgba(${p[0]},${p[1]},${p[2]},${al})`; };
  function style(skin, sec, mods) {
    const st = { fill: 'rgba(255,255,255,1)', stroke: 'rgba(0,0,0,0)', sw: 1, cap: 'butt', grad: null };
    mods.forEach(m => {
      let r;
      if ((r = m.match(/^Fill Color (.+)$/))) st.fill = rgba(r[1]);
      else if ((r = m.match(/^Fill LinearGradient (\w+)/))) st.grad = r[1];
      else if ((r = m.match(/^StrokeWidth ([\d.]+)/))) st.sw = parseFloat(r[1]);
      else if ((r = m.match(/^Stroke Color (.+)$/))) st.stroke = rgba(r[1]);
      else if (/^Stroke(Start|End)Cap Round/.test(m)) st.cap = 'round';
    });
    return st;
  }
  function makeGradient(ctx, def, bbox) {
    const parts = def.split('|').map(s => s.trim()), ang = parseFloat(parts[0]) * Math.PI / 180;
    const dx = Math.cos(ang), dy = Math.sin(ang), cx = bbox.x + bbox.w / 2, cy = bbox.y + bbox.h / 2, half = (Math.abs(bbox.w * dx) + Math.abs(bbox.h * dy)) / 2;
    const g = ctx.createLinearGradient(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half);
    parts.slice(1).forEach(p => { const q = p.split(';'); g.addColorStop(Math.min(1, Math.max(0, parseFloat(q[1]))), rgba(q[0].trim())); });
    return g;
  }
  // geometry of one Shape token -> { path: Path2D, bbox, isLine }
  function geometry(skin, sec, tokens) {
    const g = tokens[0], num = a => a.split(',').map(x => skin.value(x.trim()));
    let m;
    if ((m = g.match(/^Rectangle (.+)$/))) { const [x, y, w, h, r] = num(m[1]); const p = new Path2D(); p.roundRect(x, y, w, h, r || 0); return { path: p, bbox: { x, y, w, h } }; }
    if ((m = g.match(/^Ellipse (.+)$/))) { const [x, y, rx, ry] = num(m[1]); const p = new Path2D(); p.ellipse(x, y, rx, ry == null || isNaN(ry) ? rx : ry, 0, 0, Math.PI * 2); return { path: p, bbox: { x: x - rx, y: y - (ry || rx), w: 2 * rx, h: 2 * (ry || rx) } }; }
    if ((m = g.match(/^Line (.+)$/))) { const [x1, y1, x2, y2] = num(m[1]); const p = new Path2D(); p.moveTo(x1, y1); p.lineTo(x2, y2); return { path: p, bbox: { x: Math.min(x1, x2), y: Math.min(y1, y2), w: Math.abs(x2 - x1) || 1, h: Math.abs(y2 - y1) || 1 }, isLine: true }; }
    if ((m = g.match(/^Path (\w+)$/))) {
      const p = new Path2D(); let minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9;
      sec.opts[m[1]].split('|').map(s => s.trim()).forEach((seg, i) => {
        let q; const pt = a => { const [x, y] = num(a); minx = Math.min(minx, x); miny = Math.min(miny, y); maxx = Math.max(maxx, x); maxy = Math.max(maxy, y); return [x, y]; };
        if (i === 0) { const [x, y] = pt(seg); p.moveTo(x, y); } else if ((q = seg.match(/^LineTo (.+)$/))) { const [x, y] = pt(q[1]); p.lineTo(x, y); } else if (/^ClosePath/.test(seg)) p.closePath();
      });
      return { path: p, bbox: { x: minx, y: miny, w: maxx - minx, h: maxy - miny } };
    }
    return null;
  }
  function drawShapeMeter(ctx, skin, sec) {
    const shapeKeys = sec.keys.filter(k => /^Shape\d*$/.test(k)), items = {}, consumed = {};
    shapeKeys.forEach(k => { const toks = skin.sub(sec.opts[k]).split('|').map(s => s.trim()); items[k] = toks;
      if (/^Combine /.test(toks[0])) { consumed[toks[0].replace('Combine ', '')] = true; toks.slice(1).forEach(t => { const m = t.match(/^Exclude (\w+)/); if (m) consumed[m[1]] = true; }); } });
    const ox = sec.opts.X ? skin.value(sec.opts.X) : 0, oy = sec.opts.Y ? skin.value(sec.opts.Y) : 0;
    ctx.save(); ctx.translate(ox, oy);
    shapeKeys.forEach(k => {
      const toks = items[k]; let geo, st;
      if (/^Combine /.test(toks[0])) {
        const baseKey = toks[0].replace('Combine ', ''), base = items[baseKey]; geo = geometry(skin, sec, base); st = style(skin, sec, base.slice(1));
        const hole = toks.slice(1).map(t => t.match(/^Exclude (\w+)/)).filter(Boolean).map(m => geometry(skin, sec, items[m[1]]));
        const p = new Path2D(); p.addPath(geo.path); hole.forEach(h => p.addPath(h.path)); geo = { path: p, bbox: geo.bbox, evenodd: true };
      } else { if (consumed[k]) return; geo = geometry(skin, sec, toks); if (!geo) return; st = style(skin, sec, toks.slice(1)); }
      const fillStyle = st.grad ? makeGradient(ctx, sec.opts[st.grad], geo.bbox) : st.fill;
      if (!geo.isLine) { ctx.fillStyle = fillStyle; ctx.fill(geo.path, geo.evenodd ? 'evenodd' : 'nonzero'); }
      if (st.sw > 0) { ctx.strokeStyle = st.stroke; ctx.lineWidth = st.sw; ctx.lineCap = st.cap; ctx.stroke(geo.path); }
    });
    ctx.restore();
  }
  function drawString(ctx, skin, sec) {
    let text = sec.opts.Text != null ? skin.sub(sec.opts.Text) : '';
    const mn = sec.opts.MeasureName;
    if (mn) { const mt = skin.measureText(mn); text = sec.opts.Text != null ? text.replace(/%1/g, mt) : mt; }
    if (!text) return;
    const x = skin.value(sec.opts.X), y = skin.value(sec.opts.Y), size = skin.value(sec.opts.FontSize || '8') * 96 / 72;
    const align = (sec.opts.StringAlign || 'Left'), bold = /Bold/.test(sec.opts.StringStyle || '');
    ctx.save();
    if (sec.opts.ClipString === '1' && sec.opts.W) { ctx.beginPath(); ctx.rect(x, y, skin.value(sec.opts.W), skin.value(sec.opts.H || '99')); ctx.clip(); }
    ctx.font = `${bold ? 'bold ' : ''}${size}px "${(sec.opts.FontFace || 'Courier New').replace(/#Font#/, 'Courier New')}", monospace`;
    ctx.fillStyle = rgba(skin.sub(sec.opts.FontColor || '255,255,255')); ctx.textBaseline = 'top';
    ctx.textAlign = /Center/.test(align) ? 'center' : /Right/.test(align) ? 'right' : 'left'; ctx.fillText(text, x, y); ctx.restore();
  }
  function drawBar(ctx, skin, sec) {
    const x = skin.value(sec.opts.X), y = skin.value(sec.opts.Y), w = skin.value(sec.opts.W), h = skin.value(sec.opts.H), v = Math.min(1, skin.measureNum(sec.opts.MeasureName) / 100);
    ctx.fillStyle = rgba(sec.opts.SolidColor || '0,0,0,0'); ctx.fillRect(x, y, w, h); ctx.fillStyle = rgba(sec.opts.BarColor || '255,255,255'); ctx.fillRect(x, y, w * v, h);
  }
  function drawSkin(ctx, skin, ox, oy, under) {
    ctx.save(); ctx.translate(ox, oy); if (under) under(ctx);
    skin.secs.forEach(sec => {
      const t = sec.opts.Meter; if (!t) return;
      const hidden = (sec.name in skin.hide) ? skin.hide[sec.name] : sec.opts.Hidden === '1'; if (hidden) return;
      if (t === 'Shape') drawShapeMeter(ctx, skin, sec); else if (t === 'String') drawString(ctx, skin, sec); else if (t === 'Bar') drawBar(ctx, skin, sec);
    });
    ctx.restore();
  }
  function testCard(ctx) {                                   // the TV picture: a retro colour-bar test card with scanlines (no copyrighted movie in the README)
    const x = 16, y = 72, w = 300, h = 225; ctx.save(); ctx.beginPath(); ctx.roundRect(x, y, w, h, 10); ctx.clip();
    const bars = ['#c8c8c8', '#c8c800', '#00c8c8', '#00c800', '#c800c8', '#c80000', '#0000c8'], bw = w / 7;
    bars.forEach((c, i) => { ctx.fillStyle = c; ctx.fillRect(x + i * bw, y, bw + 1, h * 0.66); });
    const lo = ['#0000c8', '#101010', '#c800c8', '#101010', '#00c8c8', '#101010', '#c8c8c8'];
    lo.forEach((c, i) => { ctx.fillStyle = c; ctx.fillRect(x + i * bw, y + h * 0.66, bw + 1, h * 0.12); });
    ctx.fillStyle = '#101010'; ctx.fillRect(x, y + h * 0.78, w, h * 0.22); ctx.fillStyle = '#e8e0c8'; ctx.fillRect(x + w * 0.1, y + h * 0.84, w * 0.8, h * 0.07);
    ctx.fillStyle = '#101010'; ctx.font = 'bold 13px "Courier New", monospace'; ctx.textAlign = 'center'; ctx.fillText('KAIJU TV', x + w / 2, y + h * 0.895);
    for (let yy = y; yy < y + h; yy += 3) { ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.fillRect(x, yy, w, 1); }
    const g = ctx.createRadialGradient(x + w / 2, y + h / 2, h * 0.3, x + w / 2, y + h / 2, w * 0.62); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,.55)'); ctx.fillStyle = g; ctx.fillRect(x, y, w, h);
    ctx.restore();
  }

  window.renderRoom = function (opts) {
    opts = opts || {};
    const cv = document.getElementById('c'), out = document.createElement('canvas'); out.width = W; out.height = H;
    const ctx = out.getContext('2d'); ctx.drawImage(cv, 0, 0, W, H);
    const S = {}; Object.keys(window.SKINS).forEach(n => S[n] = makeSkin(n, window.SKINS[n]));
    drawSkin(ctx, S.Scene, 0, 0);
    drawSkin(ctx, S.Systems, 1528, 24);
    drawSkin(ctx, S.TVRemote, 34, 546, testCard);               // the test card sits UNDER the frame and shows through its cut-out window
    drawSkin(ctx, S.Console, 335, 524);
    if (opts.drawer && S.Cabinet) { const ch = S.Cabinet.secs.find(s => s.name === 'BG'); const chh = parseFloat(ch.opts.H); drawSkin(ctx, S.Cabinet, 1240, Math.max(8, 883 - chh)); }
    return out;
  };
  window.saveRoom = async function (url, opts) {
    const c = window.renderRoom(opts); const blob = await new Promise(r => c.toBlob(r, 'image/jpeg', 0.92));
    const res = await fetch(url, { method: 'POST', body: blob, headers: { 'Content-Type': 'text/plain' } }); return res.status + ' ' + blob.size;
  };
})();
