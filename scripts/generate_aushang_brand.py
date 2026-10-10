"""Compile the selected SVG paths into native Flutter vector drawing."""
from pathlib import Path
import xml.etree.ElementTree as ET,re,math
ROOT = Path(__file__).resolve().parents[1]
src=ROOT / 'client/assets/brand/community-access.svg'
root=ET.fromstring(src.read_text())
lines=["// Vector paths and original colors generated from the user-provided SVG.","import 'package:flutter/material.dart';",'',"class AccessBrand extends StatelessWidget {", "  final double width;", "  const AccessBrand({super.key, this.width = 132});", "  @override", "  Widget build(BuildContext context) => SizedBox(width: width, height: width * 223 / 559, child: const CustomPaint(painter: _BrandPainter()));", "}","class _BrandPainter extends CustomPainter {", "  const _BrandPainter();", "  @override", "  void paint(Canvas canvas, Size size) {", "    canvas.scale(size.width / 559, size.height / 223);", "    final paint = Paint();"]
def visit(e):
 tag=e.tag.rsplit('}',1)[-1]
 if tag not in ['svg','g','rect','path']:return
 transform=e.get('transform')
 if transform:
  lines.append('    canvas.save();')
  for op,args in re.findall(r'(translate|rotate)\(([^)]+)\)',transform):
   vals=[float(x) for x in re.split(r'[, ]+',args)]
   if op=='translate':lines.append(f'    canvas.translate({vals[0]}, {vals[1] if len(vals)>1 else 0.0});')
   else:lines.append(f'    canvas.rotate({vals[0]*math.pi/180});')
 if tag in ['path','rect']:
  fill=e.get('fill')
  if not re.fullmatch(r'#[0-9A-Fa-f]{6}', fill or ''):
   raise ValueError(f'Unsupported SVG fill: {fill}')
  color=f'const Color(0xFF{fill[1:]})'
  lines.append(f'    paint.color = {color};')
 if tag=='rect': lines.append(f"    canvas.drawRect(Rect.fromLTWH(0, 0, {e.get('width')}, {e.get('height')}), paint);")
 if tag=='path':
  tokens=re.findall(r'[MLQHVZ]|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',e.get('d')); i=0;x=y=0.0
  lines.append('    { final path = Path();')
  while i<len(tokens):
   if tokens[i] in 'MLQHVZ':
    command=tokens[i];i+=1
   elif command=='M': command='L'
   count={'M':2,'L':2,'Q':4,'H':1,'V':1,'Z':0}[command];v=[float(t) for t in tokens[i:i+count]]; i+=count
   if command in ['M','L']:
    x,y=v;fn='moveTo' if command=='M' else 'lineTo';lines.append(f'      path.{fn}({x}, {y});')
   if command=='Q': x,y=v[2:];lines.append('      path.quadraticBezierTo('+', '.join(str(n) for n in v)+');')
   if command=='H': x=v[0];lines.append(f'      path.lineTo({x}, {y});')
   if command=='V': y=v[0];lines.append(f'      path.lineTo({x}, {y});')
   if command=='Z': lines.append('      path.close();')
  lines.append('      canvas.drawPath(path, paint); }')
 for c in e:visit(c)
 if transform:lines.append('    canvas.restore();')
visit(root)
lines += ['  }','  @override','  bool shouldRepaint(covariant _BrandPainter old) => false;','}']
output = '\n'.join(lines)+'\n'
(ROOT / 'client/lib/access_brand.dart').write_text(output)
print('Selected SVG preserved and compiled into native Flutter vector paths.')
