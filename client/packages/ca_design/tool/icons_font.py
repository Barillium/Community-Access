"""Baut CaIcons.ttf aus glyphs.json (von icons.js). Einheiten: 24 Raster * 40 = 960 je Geviert."""
import json, sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

src, out = sys.argv[1], sys.argv[2]
glyphs = json.load(open(src))
UPM = 960
fb = FontBuilder(UPM, isTTF=True)
order = ['.notdef'] + [g['name'] for g in glyphs]
fb.setupGlyphOrder(order)
fb.setupCharacterMap({g['cp']: g['name'] for g in glyphs})
outlines = {'.notdef': TTGlyphPen(None).glyph()}
for g in glyphs:
    pen = TTGlyphPen(None)
    for c in g['contours']:
        pen.moveTo(tuple(c[0]))
        for p in c[1:]:
            pen.lineTo(tuple(p))
        pen.closePath()
    outlines[g['name']] = pen.glyph()
fb.setupGlyf(outlines)
fb.setupHorizontalMetrics({n: (UPM, 0) for n in order})
fb.setupHorizontalHeader(ascent=UPM, descent=0)
fb.setupNameTable({'familyName': 'CaIcons', 'styleName': 'Regular',
                   'copyright': 'Community Access, Aushang-Symbole'})
fb.setupOS2(sTypoAscender=UPM, sTypoDescender=0, sTypoLineGap=0, usWinAscent=UPM, usWinDescent=0)
fb.setupPost()
fb.save(out)
print(len(glyphs), 'Glyphen ->', out)
