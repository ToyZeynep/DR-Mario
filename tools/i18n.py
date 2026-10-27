import re, sys
SRC = sys.argv[1]  # .../core/i18n
OUT = sys.argv[2]

def parse_literal(s, i):
    assert s[i] == '"'
    i += 1; out = []
    while s[i] != '"':
        c = s[i]
        if c == '\\':
            n = s[i+1]
            if n == 'u':
                out.append(chr(int(s[i+2:i+6], 16))); i += 6; continue
            out.append({'n':'\n','t':'\t','"':'"','\\':'\\',"'":"'",'r':'\r'}[n]); i += 2; continue
        out.append(c); i += 1
    return ''.join(out), i+1

def skip_ws_comments(s, i):
    while True:
        while i < len(s) and s[i] in ' \t\r\n': i += 1
        if s.startswith('//', i): i = s.index('\n', i)
        elif s.startswith('/*', i): i = s.index('*/', i) + 2
        else: return i

def swift_lit(v):
    r = []
    for ch in v:
        if ch == '\\': r.append('\\\\')
        elif ch == '"': r.append('\\"')
        elif ch == '\n': r.append('\\n')
        elif ord(ch) < 0x20: r.append('\\u{%x}' % ord(ch))
        else: r.append(ch)
    return '"' + ''.join(r) + '"'

# ---- Txt ----
t = open(SRC + '/Txt.java', encoding='utf-8').read()
body = t[t.index('public enum Txt {') + len('public enum Txt {'):]
i = 0; entries = []
while True:
    i = skip_ws_comments(body, i)
    m = re.match(r'([A-Z_0-9]+)\s*\(', body[i:])
    if not m: break
    name = m.group(1); i += m.end()
    vals = []
    while True:
        i = skip_ws_comments(body, i)
        if body[i] == ')': i += 1; break
        if body[i] == ',': i += 1; continue
        v, i = parse_literal(body, i); vals.append(v)
    entries.append((name, vals))
    i = skip_ws_comments(body, i)
    if body[i] == ';': break
    assert body[i] == ',', body[i:i+40]
    i += 1
langs = re.search(r'EN\("en"\).*?;', open(SRC + '/Lang.java', encoding='utf-8').read(), re.S).group(0)
langs = re.findall(r'([A-Z]+)\("([a-z]+)"\)', langs)
n = len(langs)
for name, vals in entries:
    assert len(vals) == n, (name, len(vals))
o = []
o.append('//\n//  Txt.swift\n//  VirusHunt\n//\n//  OTOMATİK ÜRETİLDİ (tools/i18n.py): com.rummuscan.core.i18n.Txt + Lang (VirusHunt).\n//  Elle düzenleme; Android tarafındaki Txt.java değişince betiği yeniden çalıştır.\n//\n\nimport Foundation\n')
o.append('/// Oyun dili: cihazın dili desteklenenlerden biriyse o, aksi hâlde İngilizce.')
o.append('enum Lang: Int, CaseIterable {')
o.append('    case ' + ', '.join(l for l, _ in langs))
o.append('')
o.append('    var code: String {')
o.append('        switch self {')
for l, c in langs: o.append('        case .%s: return "%s"' % (l, c))
o.append('        }\n    }\n')
o.append('    var ordinal: Int { return rawValue }\n')
o.append('    private static var currentLang = Lang.EN\n')
o.append('    static func current() -> Lang { return currentLang }\n')
o.append('    static func set(_ lang: Lang?) { currentLang = lang ?? .EN }\n')
o.append('    /// Cihaz dilinden seçer; desteklenmeyen diller İngilizceye düşer.')
o.append('    static func detect() -> Lang {')
o.append('        let code = Locale.preferredLanguages.first.map { String($0.split(separator: "-").first ?? "") }')
o.append('        return fromCode(code)\n    }\n')
o.append('    static func fromCode(_ code: String?) -> Lang {')
o.append('        guard let code = code else { return .EN }')
o.append('        var c = code.lowercased()')
o.append('        if c == "in" { c = "id" }')
o.append('        if c == "tl" { c = "fil" }')
o.append('        if c == "no" || c == "nn" { c = "nb" }')
o.append('        for l in Lang.allCases where l.code == c { return l }')
o.append('        return .EN\n    }\n}\n')
o.append('/// Oyundaki TÜM kullanıcı metinleri, %d dilde (Lang sırasıyla). Ekranlar Txt.X.s() ile o anki dilin metnini alır.' % n)
o.append('enum Txt: Int, CaseIterable {')
for name, _ in entries: o.append('    case %s' % name)
o.append('')
o.append('    /// O anki dildeki metin.')
o.append('    func s() -> String { return `in`(Lang.current()) }\n')
o.append('    func `in`(_ lang: Lang) -> String { return Txt.TEXTS[rawValue][lang.rawValue] }\n')
o.append('    func count() -> Int { return Txt.TEXTS[rawValue].count }\n')
o.append('    private static let TEXTS: [[String]] = [')
for name, vals in entries:
    o.append('        [' + ', '.join(swift_lit(v) for v in vals) + '], // ' + name)
o.append('    ]\n}\n')
open(OUT + '/Txt.swift', 'w', encoding='utf-8').write('\n'.join(o))

# ---- HelpText ----
h = open(SRC + '/HelpText.java', encoding='utf-8').read()
consts = dict(re.findall(r'public static final int ([A-Z_]+) = (\d+);', h))
start = h.index('TEXTS = {') + len('TEXTS = ')
def parse_tree(s, i):
    i = skip_ws_comments(s, i)
    if s[i] == '{':
        i += 1; items = []
        while True:
            i = skip_ws_comments(s, i)
            if s[i] == '}': return items, i+1
            if s[i] == ',': i += 1; continue
            v, i = parse_tree(s, i); items.append(v)
    v, i = parse_literal(s, i); return v, i
tree, _ = parse_tree(h, start)
assert len(tree) == n, len(tree)
o = ['//\n//  HelpText.swift\n//  VirusHunt\n//\n//  OTOMATİK ÜRETİLDİ (tools/i18n.py): com.rummuscan.core.i18n.HelpText (VirusHunt).\n//  NASIL OYNANIR ekranının metinleri (Lang sırasıyla). Yer tutucular: {P} {T} {RANKS}.\n//\n\nimport Foundation\n']
o.append('enum HelpText {')
o.append('    struct Page {\n        let title: String\n        let body: String\n    }\n')
for k, v in consts.items(): o.append('    static let %s = %s' % (k, v))
o.append('')
o.append('    static func pages(_ lang: Lang) -> [Page] {')
o.append('        return TEXTS[lang.rawValue].map { Page(title: $0[0], body: $0[1]) }\n    }\n')
o.append('    private static let TEXTS: [[[String]]] = [')
for li, pages in enumerate(tree):
    o.append('        // ---- %s ----' % langs[li][0])
    o.append('        [')
    for p in pages: o.append('            [' + ', '.join(swift_lit(x) for x in p) + '],')
    o.append('        ],')
o.append('    ]\n}\n')
open(OUT + '/HelpText.swift', 'w', encoding='utf-8').write('\n'.join(o))
print(len(entries), 'Txt;', n, 'dil;', sum(len(p) for p in tree), 'yardım sayfası')
