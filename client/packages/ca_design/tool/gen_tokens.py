"""Erzeugt lib/src/tokens.dart aus client/design/aushang3.tokens.json."""
import json, pathlib, re

root = pathlib.Path(__file__).resolve().parents[1]
t = json.loads((root.parents[1] / 'design/aushang3.tokens.json').read_text())

def flat(d, p=''):
    for k, v in d.items():
        if k.startswith('$'):
            continue
        if isinstance(v, dict) and '$value' in v:
            yield (p + '.' + k).lstrip('.'), v['$value']
        elif isinstance(v, dict):
            yield from flat(v, p + '.' + k)

prim = dict(flat(t['primitive'], 'primitive'))
sem = dict(flat(t['semantic'], 'semantic'))
comp = dict(flat(t['component'], 'component'))
dark = dict(flat(t['dark'], 'dark'))
allv = {**prim, **sem, **comp}

def res(v, seen=0):
    m = re.fullmatch(r'\{(.+)\}', str(v))
    return res(allv[m.group(1)], seen + 1) if m else v

def camel(s):
    parts = re.split(r'[.\-]', s)
    out = parts[0] + ''.join(x[:1].upper() + x[1:] for x in parts[1:])
    return re.sub(r'^(\d)', r'n\1', out)

def color(v):
    v = res(v).lstrip('#')
    return f'Color(0xFF{v.upper()})'

lines = ['// Erzeugt von tool/gen_tokens.py aus aushang3.tokens.json. Nicht von Hand ändern.',
         "import 'package:flutter/material.dart';", '']

lines.append('/// Grundwerte. In Widgets nur über [CaColors] oder Theme verwenden.')
lines.append('abstract final class CaPrimitive {')
for k, v in prim.items():
    if k.startswith('primitive.color.'):
        lines.append(f'  static const {camel(k[16:])} = {color(v)};')
lines.append('}\n')

lines.append('abstract final class CaSpace {')
for k, v in prim.items():
    if k.startswith('primitive.space.'):
        lines.append(f'  static const double s{k[16:]} = {float(v[:-2])};')
lines.append(f"  static const double gutter = {float(res(sem['semantic.layout.gutter-mobile'])[:-2])};")
lines.append(f"  static const double section = {float(res(sem['semantic.layout.section-mobile'])[:-2])};")
lines.append(f"  static const double target = {float(sem['semantic.layout.target'][:-2])};")
lines.append('}\n')

lines.append('abstract final class CaLine {')
for k, v in prim.items():
    if k.startswith('primitive.line.'):
        lines.append(f'  static const double {camel(k[15:])} = {float(v[:-2])};')
lines.append('}\n')

lines.append('abstract final class CaDuration {')
for k, v in prim.items():
    if k.startswith('primitive.duration.'):
        lines.append(f'  static const {camel(k[19:])} = Duration(milliseconds: {int(v[:-2])});')
lines.append('}\n')

lines.append('abstract final class CaEase {')
for k, v in prim.items():
    if k.startswith('primitive.ease.'):
        a = [x.strip() for x in v[v.index('(') + 1:-1].split(',')]
        lines.append(f'  static const {camel(k[15:])} = Cubic({", ".join(a)});')
lines.append('}\n')

lines.append('abstract final class CaTilt {')
for k, v in prim.items():
    if k.startswith('primitive.tilt.'):
        lines.append(f'  /// {v}')
        lines.append(f'  static const double {camel(k[15:])} = {float(v[:-3])} * 3.141592653589793 / 180;')
lines.append('}\n')

lines.append('abstract final class CaSize {')
for k, v in comp.items():
    v = res(v)
    if isinstance(v, str) and v.endswith('px'):
        lines.append(f'  static const double {camel(k[10:])} = {float(v[:-2])};')
lines.append('}\n')

# Semantische Farben hell und dunkel als ThemeExtension
keys = [k for k in sem if k.split('.')[1] in ('surface', 'text', 'border', 'action')]
extra = ('component.marker.stroke', 'component.stamp.color', 'component.door.current', 'component.emboss.fill')
names = [camel(k[9:]) for k in keys] + [camel(k[10:]) for k in extra]
def mode(src):
    vals = [src.get('dark.' + k, sem[k]) for k in keys] + [src.get('dark.semantic.' + k[10:], comp[k]) for k in extra]
    return ',\n'.join(f'    {n}: {color(v)}' for n, v in zip(names, vals))
lines += [
  '/// Bedeutungsfarben. Zugriff: `CaColors.of(context).textPrimary`.',
  'class CaColors extends ThemeExtension<CaColors> {',
  '  const CaColors({' + ', '.join(f'required this.{n}' for n in names) + '});',
  *[f'  final Color {n};' for n in names],
  '',
  f'  static const light = CaColors(\n{mode({})},\n  );',
  f'  static const dark = CaColors(\n{mode(dark)},\n  );',
  '',
  '  static CaColors of(BuildContext context) => Theme.of(context).extension<CaColors>()!;',
  '',
  '  @override',
  '  CaColors copyWith() => this;',
  '',
  '  @override',
  '  CaColors lerp(CaColors? other, double t) {',
  '    if (other == null) return this;',
  '    return CaColors(' + ', '.join(f'{n}: Color.lerp({n}, other.{n}, t)!' for n in names) + ');',
  '  }',
  '}',
]
(root / 'lib/src/tokens.dart').write_text('\n'.join(lines) + '\n')
print('lib/src/tokens.dart', len(lines), 'Zeilen')
