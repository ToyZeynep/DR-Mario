import re, sys, os, html
res = sys.argv[1]; out = sys.argv[2]
keys = ['rs_feedback_title','rs_feedback_rating','rs_feedback_hint','rs_feedback_email_hint','rs_feedback_privacy',
        'rs_feedback_send','rs_feedback_cancel','rs_feedback_empty','rs_feedback_email_invalid','rs_feedback_thanks','rs_feedback_failed']
table = {}
for d in sorted(os.listdir(res)):
    if not d.startswith('values'): continue
    f = os.path.join(res, d, 'strings.xml')
    if not os.path.exists(f): continue
    code = 'en' if d == 'values' else d.split('-', 1)[1]
    code = {'in': 'id', 'nb': 'nb'}.get(code, code)
    x = open(f, encoding='utf-8').read()
    m = {}
    for k in keys:
        mm = re.search(r'<string name="%s"[^>]*>(.*?)</string>' % k, x, re.S)
        if mm:
            v = html.unescape(mm.group(1)).replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
            v = v.replace('Android-Version', 'iOS-Version').replace('Android', 'iOS')
            m[k] = v
    if m: table[code] = m
def lit(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'
o = ['//\n//  FeedbackStrings.swift\n//  VirusHunt\n//\n//  OTOMATİK ÜRETİLDİ (tools/fbstrings.py): Android res/values-*/strings.xml içindeki rs_feedback_*\n//  metinleri ("Android" -> "iOS"). Geri bildirim penceresi bunları cihaz diline göre kullanır.\n//\n\nenum FeedbackStrings {']
o.append('    static let TABLE: [String: [String: String]] = [')
for code, m in table.items():
    o.append('        "%s": [' % code)
    for k in keys:
        if k in m: o.append('            "%s": %s,' % (k[len('rs_feedback_'):], lit(m[k])))
    o.append('        ],')
o.append('    ]\n')
o.append('    static func get(_ key: String) -> String {')
o.append('        let code = Lang.current().code')
o.append('        return TABLE[code]?[key] ?? TABLE["en"]?[key] ?? key\n    }\n}\n')
open(out, 'w', encoding='utf-8').write('\n'.join(o))
print(len(table), 'dil', sorted(table))
