#!/usr/bin/env python3
"""Generate an expanded Husk 3.0 Localizable.strings from its SwiftUI source.

The file is a *resource-only* localization. Dynamic Text(String) in the
precompiled app cannot be repaired without rebuilding the Swift source.
"""
import argparse, concurrent.futures, json, pathlib, random, re, sys, time, urllib.parse, urllib.request

S = re.compile(r'"((?:\\.|[^"\\])*)"', re.DOTALL)
ENTRY = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', re.M)
VISIBLE = re.compile(r'(?:Text|Button|Label|Section|Picker|Toggle|TextField|SecureField|'
                     r'GroupBox|Link|Menu|ProgressView|navigationTitle|alert|'
                     r'confirmationDialog|accessibilityLabel|accessibilityHint|'
                     r'help|prompt|title|subtitle)\s*\(\s*$', re.I)
ALPHA = re.compile(r'[a-zA-Z]')
IDENTIFIER = re.compile(r'^[a-z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)+$')
TECH = re.compile(r'^(?:[a-z0-9_-]+\.){2,}|^[a-z0-9_.-]+://|'
                  r'^[a-z0-9_.-]+/[a-z0-9/_\.-]+|'
                  r'^[a-z0-9_.-]+@', re.I)

def decode_swift(v):
    return (v.replace(r'\"', '"').replace(r'\n', '\n').replace(r'\t', '\t')
             .replace(r'\\', '\\'))

def unescape(v):
    return (v.replace(r'\"', '"').replace(r'\n', '\n').replace(r'\t', '\t')
             .replace(r'\\', '\\'))

def escape(v):
    return v.replace('\\','\\\\').replace('"', r'\"').replace('\r',r'\r').replace('\n',r'\n').replace('\t',r'\t')

def eligible(v, before):
    if not ALPHA.search(v) or not v.strip() or len(v) > 450 or len(v) < 2: return False
    if '\\(' in v: return False  # interpolation needs source changes
    if '\n' in v: return False
    if v.startswith(('$','_', '.', '/', '{','<','#','%','@')): return False
    if any(x in v for x in ('://','"', '\\/', '{','}', ' = ', '0x', '.app/', '.swift','.plist','.dylib','.xcassets','.framework')):
        return False
    if TECH.search(v) or IDENTIFIER.fullmatch(v): return False
    if re.fullmatch(r'[A-Za-z0-9. _+-]+', v) and ('.' in v and ' ' not in v):
        return False
    # Sentence and multiword UI labels; avoids source identifiers and most constants.
    if re.search(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}', v) and (len(v) > 6):
        return True
    # Short action labels only when code context marks them as human-facing.
    short_context = before[-110:]
    if VISIBLE.search(short_context) or re.search(r'(?:return|case\s+[.\w]+:\s*return)\s*$', short_context):
        return bool(re.fullmatch(r"[A-Za-z][A-Za-z0-9 &'!?.:/+–—\-]*", v)) and len(v) < 100
    return False

def gather(root):
    found={}
    for p in sorted(root.rglob('*.swift')):
        if not any(q in p.parts for q in ('Husk','HuskDownloadsWidget','HuskJITHelper','Shared')): continue
        data=p.read_text(encoding='utf-8',errors='replace')
        for m in S.finditer(data):
            raw=m.group(1)
            prefix=data[max(0,m.start()-110):m.start()]
            if not eligible(raw,prefix): continue
            key=decode_swift(raw)
            found.setdefault(key,set()).add(p.name)
    return found

def old_table(path):
    if not path.exists(): return {}
    return {unescape(k):unescape(v) for k,v in ENTRY.findall(path.read_text(encoding='utf-8-sig'))}

def translated_one(pair):
    key, attempts=pair
    q=urllib.parse.urlencode({'client':'gtx','sl':'en','tl':'zh-CN','dt':'t','q':key})
    u='https://translate.googleapis.com/translate_a/single?'+q
    for retry in range(attempts):
        try:
            req=urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0 (compatible; Husk-Localization/1.0)'})
            with urllib.request.urlopen(req,timeout=12) as r:
                obj=json.load(r)
            result=''.join(x[0] for x in obj[0] if x and x[0])
            if result and result.strip() and len(result)<1500: return key,result
        except Exception as e:
            if retry == attempts-1: return key,None
            time.sleep(0.6*(retry+1))
    return key,None

def main():
    a=argparse.ArgumentParser()
    a.add_argument('--source',required=True,type=pathlib.Path)
    a.add_argument('--existing',required=True,type=pathlib.Path)
    a.add_argument('--output',required=True,type=pathlib.Path)
    a.add_argument('--report',required=True,type=pathlib.Path)
    a.add_argument('--max-workers',type=int,default=8)
    args=a.parse_args()
    found=gather(args.source)
    curated=old_table(args.existing)
    keys=sorted(set(found)|set(curated),key=lambda s:s.casefold())
    missing=[s for s in keys if s not in curated]
    print('Swift UI candidates:',len(found),'Existing translations:',len(curated),
          'To translate:',len(missing),flush=True)
    auto={}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as pool:
        futures={pool.submit(translated_one,(key,2)):key for key in missing}
        for i,future in enumerate(concurrent.futures.as_completed(futures)):
            try:k,v=future.result()
            except Exception:v=None;k=futures[future]
            if v: auto[k]=v
            if i%100==0:print('Translated',i,'/',len(missing),flush=True)
    result={}
    for k in keys:
        result[k]=curated.get(k) or auto.get(k) or k
    untouched=[k for k in missing if k not in auto]
    report={'source_strings':len(found),'curated':len(curated),
            'translated_automatically':len(auto),'untranslated':len(untouched),
            'untranslated_samples':untouched[:150],
            'note':'Resource-only build: dynamic SwiftUI Text(String) is not localized.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text('// Husk 3.0 expanded simplified Chinese localization. Not a full source recompile.\n'
        +'\n'.join('"'+escape(k)+'" = "'+escape(v)+'";' for k,v in result.items())+'\n',encoding='utf-8')
    args.report.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2)[:3000],flush=True)
    # Reject mass untranslated fallback to avoid passing a fake localized IPA.
    if len(missing)>100 and len(auto)<len(missing)*0.65:
        raise SystemExit('Translation provider insufficient; rejecting output')
if __name__=='__main__':main()
