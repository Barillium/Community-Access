// Aushang-Symbole: eine Quelle für SVG, CSS und die Flutter-Schrift.
// Raster 24, Strich 2, eckige Enden, Gehrung, Punkte sind Quadrate.
// Reihenfolge = Codepunkte ab U+E000. Nur hinten anfügen, nie umsortieren.
const W = 2, H = W / 2;
const deg = Math.PI / 180;
const sub = (a, b) => [a[0] - b[0], a[1] - b[1]], add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const mul = (a, k) => [a[0] * k, a[1] * k], norm = a => { const l = Math.hypot(a[0], a[1]); return [a[0] / l, a[1] / l]; };
const nrm = d => [-d[1], d[0]];
const area = p => p.reduce((s, a, i) => { const b = p[(i + 1) % p.length]; return s + a[0] * b[1] - b[0] * a[1]; }, 0) / 2;
const orient = (p, sign) => (Math.sign(area(p)) === sign ? p : p.slice().reverse());

// Kontur eines Strichs. closed: Rahmen (zwei Konturen), sonst eine Kontur mit Enden.
function stroke(pts, { closed = false, cap = ['square', 'square'] } = {}) {
  const n = pts.length, L = [], R = [];
  for (let i = 0; i < n; i++) {
    const p = pts[i];
    const prev = closed ? pts[(i - 1 + n) % n] : pts[i - 1], next = closed ? pts[(i + 1) % n] : pts[i + 1];
    if (!prev || !next) {
      const d = norm(next ? sub(next, p) : sub(p, prev)), nv = nrm(d);
      let q = p;
      const c = next ? cap[0] : cap[1];
      if (c === 'square') q = next ? sub(p, mul(d, H)) : add(p, mul(d, H));
      L.push(add(q, mul(nv, H))); R.push(sub(q, mul(nv, H)));
      continue;
    }
    const d0 = norm(sub(p, prev)), d1 = norm(sub(next, p)), n0 = nrm(d0), n1 = nrm(d1);
    const m = norm(add(n0, n1)), len = H / (m[0] * n0[0] + m[1] * n0[1]);
    if (len > 2 * H) { // Gehrung zu lang: außen abschrägen, innen begrenzen
      const cr = d0[0] * d1[1] - d0[1] * d1[0], inner = mul(m, Math.min(len, 6 * H));
      if (cr > 0) { R.push(sub(p, mul(n0, H)), sub(p, mul(n1, H))); L.push(add(p, inner)); }
      else { L.push(add(p, mul(n0, H)), add(p, mul(n1, H))); R.push(sub(p, inner)); }
      continue;
    }
    L.push(add(p, mul(m, len))); R.push(sub(p, mul(m, len)));
  }
  if (closed) {
    const a = L, b = R;
    return Math.abs(area(a)) > Math.abs(area(b)) ? [[a, 1], [b, -1]] : [[b, 1], [a, -1]];
  }
  return [[L.concat(R.reverse()), 1]];
}
const circ = (cx, cy, r, a0 = 0, a1 = 360, step = 5) => {
  const out = [], k = Math.max(2, Math.ceil(Math.abs(a1 - a0) / step));
  for (let i = 0; i <= k; i++) { const a = (a0 + (a1 - a0) * i / k) * deg; out.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]); }
  return out;
};
const ell = (cx, cy, rx, ry) => { const o = []; for (let i = 0; i < 72; i++) { const a = i * 5 * deg; o.push([cx + rx * Math.cos(a), cy + ry * Math.sin(a)]); } return o; };
const B = ['butt', 'butt'], SB = ['square', 'butt'], BS = ['butt', 'square'];
const line = (pts, cap) => stroke(pts, { cap });
const frame = pts => stroke(pts, { closed: true });
const ring = (cx, cy, r) => frame(circ(cx, cy, r, 0, 360).slice(0, -1));
const arc = (cx, cy, r, a0, a1) => stroke(circ(cx, cy, r, a0, a1), { cap: B });
const poly = pts => [[pts, 1]];
const rect = (x0, y0, x1, y1) => poly([[x0, y0], [x1, y0], [x1, y1], [x0, y1]]);
const dot = (cx, cy, s = W) => rect(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2);
const disc = (cx, cy, r) => poly(circ(cx, cy, r, 0, 360).slice(0, -1));
const cut = sh => sh.map(([p, s]) => [p, -s]);
const mirror = sh => sh.map(([p, s]) => [p.map(([x, y]) => [24 - x, y]), s]);
const rot90 = sh => sh.map(([p, s]) => [p.map(([x, y]) => [24 - y, x]), s]);

const bookmarkPts = [[6, 3], [18, 3], [18, 21], [12, 15.5], [6, 21]];
const cal = [frame([[4, 5], [20, 5], [20, 21], [4, 21]]), line([[4, 10], [20, 10]], B), line([[8, 2], [8, 7]], B), line([[16, 2], [16, 7]], B)];
const door = [line([[6, 21], [6, 3], [18, 3], [18, 21]], B), line([[3, 21], [21, 21]], B)];
const leaf = [[6, 3], [12, 5.5], [12, 19.5], [6, 21]];
const shoulders = circ(12, 21.25, 6.5, 196, 344);
const arrowR = [line([[4, 12], [18, 12]], SB), line([[13, 6], [19, 12], [13, 18]])];
const refreshTip = (() => { const E = circ(12, 12, 8, 315, 315)[0], t = norm([1, 1]), T = add(E, mul(t, 1.4)); return [T, [T[0] - 5.5, T[1]], [T[0], T[1] - 5.5]]; })();

const ICONS = [
  ['arrow-right', 'Weiter', arrowR],
  ['arrow-left', 'Zurück', arrowR.map(mirror)],
  ['check', 'Erledigt', [line([[4, 12.5], [9.5, 18], [20, 7.5]])]],
  ['close', 'Schließen', [line([[5.5, 5.5], [18.5, 18.5]]), line([[18.5, 5.5], [5.5, 18.5]])]],
  ['caret-down', 'Aufklappen', [line([[5, 9], [12, 16], [19, 9]])]],
  ['caret-right', 'Öffnen', [line([[9, 5], [16, 12], [9, 19]])]],
  ['menu', 'Menü', [line([[3, 6], [21, 6]], B), line([[3, 12], [21, 12]], B), line([[3, 18], [21, 18]], B)]],
  ['search', 'Suchen', [ring(10.5, 10.5, 7), line([[15.5, 15.5], [20.5, 20.5]], B)]],
  ['bookmark', 'Merken', [frame(bookmarkPts)]],
  ['bookmark-fill', 'Gemerkt', [frame(bookmarkPts), poly([[6, 7.5], [18, 7.5], ...bookmarkPts.slice(2)])]],
  ['bookmark-remove', 'Entfernen', [frame(bookmarkPts), line([[9, 9], [15, 9]], B)]],
  ['calendar', 'Programm', cal],
  ['calendar-fill', 'Programm, aktiv', [...cal, rect(4, 5, 20, 10)]],
  ['calendar-add', 'In Kalender', [...cal, line([[12, 12.5], [12, 18.5]], B), line([[9, 15.5], [15, 15.5]], B)]],
  ['door', 'Mein Zugang', [...door, line(leaf.slice(0, 3), B), line(leaf.slice(2), B), dot(10, 13)]],
  ['door-fill', 'Mein Zugang, aktiv', [...door, line(leaf.slice(0, 3), B), line(leaf.slice(2), B), poly(leaf), cut(dot(10, 13))]],
  ['user', 'Konto', [ring(12, 12, 9), ring(12, 9.5, 3), stroke(shoulders, { cap: B })]],
  ['user-fill', 'Konto, aktiv', [ring(12, 12, 9), ring(12, 9.5, 3), poly([...circ(12, 21.25, 6.5, 196, 344), ...circ(12, 12, 9, 20, 160)])]],
  ['users', 'Team', [ring(8.5, 8.5, 3), arc(8.5, 20.5, 5.5, 180, 360), ring(17, 7.5, 2.5), arc(17, 19.5, 4.5, 270, 360)]],
  ['lock', 'Gesperrt', [frame([[4, 10], [20, 10], [20, 21], [4, 21]]), line([[8, 10], [8, 4], [16, 4], [16, 10]], B), dot(12, 15.5)]],
  ['shield-check', 'Geprüft', [frame([[12, 2.5], [20, 5], [20, 12.5], [12, 21.5], [4, 12.5], [4, 5]]), line([[8.5, 12], [11, 14.5], [15.5, 10]])]],
  ['clock', 'Uhrzeit', [ring(12, 12, 9), line([[12, 7], [12, 12], [16, 12]], B)]],
  ['globe', 'Sprache', [ring(12, 12, 9), frame(ell(12, 12, 4, 9)), line([[3, 12], [21, 12]], B)]],
  ['map-pin', 'Ort', [frame([...circ(12, 9.5, 6.5, 150, 390), [12, 20.5]]), dot(12, 9.5)]],
  ['warning', 'Hinweis', [ring(12, 12, 9), line([[12, 7], [12, 13]], B), dot(12, 16)]],
  ['help', 'Hilfe', [ring(12, 12, 9), line([[9, 9.5], [9, 7], [15, 7], [15, 11], [12, 11], [12, 13.5]], B), dot(12, 16.5)]],
  ['wifi-off', 'Offline', [arc(12, 19.5, 5, 225, 315), arc(12, 19.5, 11, 228, 312), dot(12, 19.5), line([[4, 4], [20, 20]])]],
  ['refresh', 'Neu laden', [arc(12, 12, 8, 15, 315), line(refreshTip.length ? [refreshTip[1], refreshTip[0], refreshTip[2]] : [])]],
  ['trash', 'Löschen', [line([[3, 6], [21, 6]], B), line([[9, 6], [9, 3], [15, 3], [15, 6]], B), line([[5.5, 6], [5.5, 21], [18.5, 21], [18.5, 6]], B), line([[10, 10], [10, 17]], B), line([[14, 10], [14, 17]], B)]],
  ['pause', 'Pause', [rect(6.5, 5, 9.5, 19), rect(14.5, 5, 17.5, 19)]],
  ['play', 'Abspielen', [poly([[7, 4.5], [19.5, 12], [7, 19.5]])]],
  ['contrast', 'Darstellung', [ring(12, 12, 9), poly([[12, 3], ...circ(12, 12, 9, 270, 450)])]],
  ['share', 'Teilen (iOS)', [line([[8.5, 9], [5, 9], [5, 21], [19, 21], [19, 9], [15.5, 9]], B), line([[12, 4], [12, 15]], B), line([[8, 7], [12, 3], [16, 7]])]],
  ['share-android', 'Teilen (Android)', [line([[6, 12], [18, 5.5]], B), line([[6, 12], [18, 18.5]], B), dot(18, 5.5, 5), dot(6, 12, 5), dot(18, 18.5, 5)]],
  ['more', 'Mehr (iOS)', [dot(5, 12, 3), dot(12, 12, 3), dot(19, 12, 3)]],
  ['more-vertical', 'Mehr (Android)', [dot(12, 5, 3), dot(12, 12, 3), dot(12, 19, 3)]],
  ['bell', 'Benachrichtigungen', [frame([[4.5, 17.5], [6.5, 14.5], ...circ(12, 9.5, 5.5, 180, 360), [17.5, 14.5], [19.5, 17.5]]), line([[10, 21], [14, 21]], B)]],
  ['mail', 'Kontakt', [frame([[3, 5], [21, 5], [21, 19], [3, 19]]), line([[3, 6], [12, 13], [21, 6]], B)]],
  ['flag', 'Melden', [line([[5, 21], [5, 3]], B), frame([[5, 4], [19, 4], [15.5, 8.5], [19, 13], [5, 13]])]],
  ['document', 'Rechtliches', [frame([[5, 3], [19, 3], [19, 21], [5, 21]]), line([[9, 8], [15, 8]], B), line([[9, 12], [15, 12]], B), line([[9, 16], [13, 16]], B)]],
  ['filter', 'Interessen', [line([[3, 8], [21, 8]], B), line([[3, 16], [21, 16]], B), rect(13, 5, 18, 11), rect(6, 13, 11, 19)]],
];

// Veredelung als zweite Druckplatte: genau eine flache Fläche in Signalorange je Symbol,
// passgenau in einem Innenraum der Zeichnung, unter der Tinte bis zur Strichmitte.
// Nie außerhalb der Silhouette, keine Striche, kein Zustand: aktiv zeigt nur die Tinte.
// Freie Kanten auf Vielfachen von 1,5 (ganze Pixel bei 16 px). Hinweis, Hilfe und Werkzeuge bleiben einfarbig.
const at = (a, b, y) => a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]); // x auf Strecke a-b bei y
const sector = (cx, cy, r, a0, a1) => poly([[cx, cy], ...circ(cx, cy, r, a0, a1)]);
const shieldBase = (() => { const y = 15; return poly([[at([4, 12.5], [12, 21.5], y), y], [at([20, 12.5], [12, 21.5], y), y], [12, 21.5]]); })();
const pinTip = (() => { const L = circ(12, 9.5, 6.5, 150, 150)[0], R = circ(12, 9.5, 6.5, 30, 30)[0], y = 13.5; return poly([[at(L, [12, 20.5], y), y], [at(R, [12, 20.5], y), y], [12, 20.5]]); })();
const flapTip = (() => { const y = 8; return poly([[at([3, 6], [12, 13], y), y], [at([21, 6], [12, 13], y), y], [12, 13]]); })();
const pennant = (() => { const y = 7.5; return poly([[5, 4], [19, 4], [at([19, 4], [15.5, 8.5], y), y], [5, y]]); })();
const dayLune = poly([...[...Array(19).keys()].map(i => { const a = (-90 + i * 5) * deg; return [12 + 4 * Math.cos(a), 12 + 9 * Math.sin(a)]; }), ...circ(12, 12, 9, 0, -90)]);
const ACCENTS = [
  ['check', [poly([[4, 12.5], [15, 12.5], [9.5, 18]])]],
  ['bookmark', [rect(6, 3, 18, 7.5)]],
  ['bookmark-fill', [rect(6, 3, 18, 7.5)]],
  ['calendar', [rect(12, 13.5, 16.5, 18)]],
  ['calendar-fill', [rect(12, 13.5, 16.5, 18)]],
  ['door', [rect(12, 15, 18, 21)]],
  ['door-fill', [rect(12, 15, 18, 21)]],
  ['user', [disc(12, 9.5, 3)]],
  ['user-fill', [disc(12, 9.5, 3)]],
  ['users', [disc(8.5, 8.5, 3)]],
  ['lock', [rect(8, 4, 16, 10)]],
  ['shield-check', [shieldBase]],
  ['clock', [sector(12, 12, 5, -90, 0)]],
  ['globe', [dayLune]],
  ['map-pin', [pinTip]],
  ['contrast', [sector(12, 12, 5, 90, 180)]],
  ['bell', [rect(9, 13.5, 15, 17.5)]],
  ['mail', [flapTip]],
  ['flag', [pennant]],
  ['document', [rect(15, 15, 19, 21)]],
];
for (const [n, sh] of ACCENTS) ICONS.push([n + '-accent', ICONS.find(i => i[0] === n)[1] + ', Veredelung', sh]);

// Konturen einer Figur, Außen gegen den Uhrzeigersinn in y-unten (= im Uhrzeigersinn in der Schrift, y-oben).
const contours = shapes => shapes.flat().map(([p, s]) => orient(p, s));
module.exports = { ICONS, ACCENTS, contours };

if (require.main === module) {
  const fs = require('fs'), out = process.argv[2] || 'out';
  fs.mkdirSync(out + '/svg', { recursive: true });
  const f = n => +n.toFixed(2);
  const d = cs => cs.map(c => 'M' + c.map(([x, y]) => f(x) + ' ' + f(y)).join('L') + 'Z').join('');
  const css = ['/* Aushang-Symbole (Community Access). Erzeugt von icons.js, nicht von Hand ändern. */'];
  const glyphs = [];
  ICONS.forEach(([name, label, shapes], i) => {
    const cs = contours(shapes);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="${d(cs)}"/></svg>`;
    fs.writeFileSync(`${out}/svg/${name}.svg`, svg + '\n');
    css.push(`.ci-${name}{--m:url("data:image/svg+xml,${encodeURIComponent(svg.replace('currentColor', 'black')).replace(/%20/g, ' ').replace(/%2C/g, ',')}")}`);
    glyphs.push({ name, label, cp: 0xE000 + i, contours: cs.map(c => c.map(([x, y]) => [Math.round(x * 40), Math.round((24 - y) * 40)])) });
  });
  // Veredelt: Orange unter dem Strich. Standard für Inhaltssymbole; \`.ink\` zeigt sie einfarbig.
  const url = n => css.find(l => l.startsWith(`.ci-${n}{`)).slice(`.ci-${n}{--m:`.length, -1);
  const V = ACCENTS.map(([n]) => `.i.ci-${n}`);
  css.push(`${V.join(',')}{position:relative;background:none;-webkit-mask:none;mask:none}`,
    `${V.map(s => s + '::before').join(',')},${V.map(s => s + '::after').join(',')}{content:"";position:absolute;inset:0;background:var(--surface-accent,#FF5A1F);-webkit-mask:var(--a) center/contain no-repeat;mask:var(--a) center/contain no-repeat}`,
    `${V.map(s => s + '::after').join(',')}{background:currentColor;-webkit-mask-image:var(--m);mask-image:var(--m)}`,
    '.i.ink::before{content:none}');
  for (const [n] of ACCENTS) {
    css.push(`.ci-${n}{--a:${url(n + '-accent')}}`);
    const p = k => fs.readFileSync(`${out}/svg/${k}.svg`, 'utf8').match(/d="([^"]+)"/)[1];
    fs.writeFileSync(`${out}/svg/${n}-veredelt.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#FF5A1F" d="${p(n + '-accent')}"/><path fill="currentColor" d="${p(n)}"/></svg>\n`);
  }
  fs.writeFileSync(out + '/ca-icons.css', css.join('\n') + '\n');
  fs.writeFileSync(out + '/glyphs.json', JSON.stringify(glyphs));
  const camel = n => n.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  fs.writeFileSync(out + '/icons.dart', `// Erzeugt von tool/icons.js, nicht von Hand ändern.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Aushang-Symbole: Raster 24, Strich 2, eckige Enden, Punkte als Quadrate.
/// Schrift \`fonts/CaIcons.ttf\`, SVG und CSS liegen im Designsystem unter \`icons/\`.
abstract final class CaIcons {
  static const _f = 'CaIcons';
  static const _p = 'ca_design';

${glyphs.map(g => `  /// ${g.label}\n  static const IconData ${camel(g.name)} =\n      IconData(0x${g.cp.toString(16)}, fontFamily: _f, fontPackage: _p);`).join('\n')}

  /// Orange Veredelung zu einem Symbol, sonst \`null\`. \`CaIcon\` legt sie darunter.
  static IconData? accentOf(IconData icon) => switch (icon.codePoint) {
${ACCENTS.map(([n]) => `        0x${glyphs.find(g => g.name === n).cp.toString(16)} => ${camel(n)}Accent,`).join('\n')}
        _ => null,
      };

  static bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Teilen in der Form der Plattform (wie \`Icons.adaptive.share\`).
  static IconData get adaptiveShare => _apple ? share : shareAndroid;

  /// Mehr in der Form der Plattform (wie \`Icons.adaptive.more\`).
  static IconData get adaptiveMore => _apple ? more : moreVertical;
}
`);
  console.log(ICONS.length + ' Symbole');
}
