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


# Existing binary contains additional Vietnamese strings in cheat and mod submenus
# which are absent from Localizations.json. Translate only exact UILabel display text.
extras = json.loads((base/'ui_extras_zh.json').read_text(encoding='utf-8'))
assert len(extras) == 128
extra_lines = [
    '// Auto-generated from the uploaded Mugoat 1.1.3 binary; display text only.',
    '#import <Foundation/Foundation.h>',
    'static NSDictionary<NSString *, NSString *> *MZHExtraUIMap(void) {',
    '    static NSDictionary<NSString *, NSString *> *translations;',
    '    static dispatch_once_t once;',
    '    dispatch_once(&once, ^{ translations = @{'
]
for vi, zh in extras.items():
    assert vi and zh
    extra_lines.append('        @'+escape(vi)+': @'+escape(zh)+',')
extra_lines.extend(['    }; });', '    return translations;', '}'])
(base/'GeneratedExtraUI.h').write_text('\n'.join(extra_lines)+'\n',encoding='utf-8')
print(f'Generated {len(extras)} extra UI translations')

