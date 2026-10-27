import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
def block(name):
    i = src.index(name + ' = {'); j = src.index('};', i)
    return re.sub(r"//[^\n]*", "", src[i:j])
def lits(b):
    return re.findall(r'"((?:[^"\\]|\\.)*)"', b)
font = lits(block('String[] FONT'))
def pairs(name):
    l = lits(block(name)); return [(l[k], l[k+1]) for k in range(0, len(l), 2)]
named = pairs('String[][] NAMED'); cyr = pairs('String[][] CYRILLIC_ALIASES'); gr = pairs('String[][] GREEK_ALIASES')
def sl(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
def jl(s): return s.encode().decode('unicode_escape') if '\\' in s else s
o = ['//\n//  PixelFontData.swift\n//  DR. Mario\n//\n//  OTOMATİK ÜRETİLDİ (tools/font.py): com.rummuscan.game.PixelFont glyph tabloları (VirusHunt).\n//\n\nenum PixelFontData {']
o.append('    static let FONT: [String] = [')
for f in font: o.append('        ' + sl(jl(f)) + ',')
o.append('    ]\n')
for nm, ps in (('NAMED', named), ('CYRILLIC_ALIASES', cyr), ('GREEK_ALIASES', gr)):
    o.append('    static let %s: [(String, String)] = [' % nm)
    for a, b in ps: o.append('        (%s, %s),' % (sl(jl(a)), sl(jl(b))))
    o.append('    ]\n')
o.append('}\n')
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(o))
print(len(font), len(named), len(cyr), len(gr))
