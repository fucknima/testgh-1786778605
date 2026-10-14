#!/usr/bin/env python3
"""Generate ObjC source from exact display translations. Never rewrites application code."""
import json, pathlib, re
base = pathlib.Path(__file__).resolve().parent
translations = json.loads((base/'translations_zh.json').read_text(encoding='utf-8'))
assert len(translations) == 269

def escape(value):
    return json.dumps(value, ensure_ascii=False).replace('\\u2028', '\\u2028')

out = [
    '// Auto-generated from translations_zh.json. Do not edit by hand.',
    '#import <Foundation/Foundation.h>',
    'static NSDictionary<NSString *, NSString *> *MZHTranslationMap(void) {',
    '    static NSDictionary<NSString *, NSString *> *translations;',
    '    static dispatch_once_t once;',
    '    dispatch_once(&once, ^{ translations = @{'
]
for en, zh in translations.items():
    assert en and zh
    old = re.findall(r'%(?:[-+ #0]*\d*(?:\.\d+)?)?[diouxXfFeEgGaAcCsSp@]', en)
    new = re.findall(r'%(?:[-+ #0]*\d*(?:\.\d+)?)?[diouxXfFeEgGaAcCsSp@]', zh)
    assert sorted(old) == sorted(new),(en,zh)
    out.append('        @'+escape(en)+': @'+escape(zh)+',')
out.extend(['    }; });', '    return translations;', '}'])
(base/'GeneratedTranslations.h').write_text('\n'.join(out)+'\n',encoding='utf-8')
print(f'Generated {len(translations)} translations')

