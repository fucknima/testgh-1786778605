#!/usr/bin/env python3
"""Resource-only localization repack for official Husk 3.0 IPA."""
import hashlib, io, pathlib, plistlib, sys, zipfile
src=pathlib.Path(sys.argv[1])
dst=pathlib.Path(sys.argv[2])
assert src.is_file() and src.stat().st_size > 100000000, "Missing/corrupt official Husk 3.0 IPA"
translations=pathlib.Path(sys.argv[3]) if len(sys.argv)>3 else pathlib.Path(__file__).resolve().parents[1]/"husk-zh/Localizable.strings"
t=translations.read_text(encoding="utf-8")
assert t.count('" = "') >= 200, "Incomplete translation file"
strings=t.encode("utf-16")
info_strings=('\"CFBundleDisplayName\" = \"Husk\";\n'
              '\"NSLocalNetworkUsageDescription\" = \"Husk 需要访问本地网络，以便与 iPhone 配对启用 JIT。\";\n').encode("utf-16")
with zipfile.ZipFile(src) as zin:
    files=set(zin.namelist())
    infos=[n for n in files if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/")==2]
    assert len(infos)==1, "Unexpected IPA structure"
    info_path=infos[0]
    app=info_path.rsplit("/",1)[0]+"/"
    old_plist=zin.read(info_path)
    pl=plistlib.loads(old_plist)
    assert str(pl.get("CFBundleShortVersionString","")).split(".")[0]=="3", "Not Husk 3.x"
    exe=app+pl["CFBundleExecutable"]
    assert exe in files
    original_sha=hashlib.sha256(zin.read(exe)).hexdigest()
    pl["CFBundleDevelopmentRegion"]="zh-Hans"
    pl["CFBundleLocalizations"]=["zh-Hans","en"]
    fmt=plistlib.FMT_BINARY if old_plist.startswith(b"bplist") else plistlib.FMT_XML
    changed={info_path:plistlib.dumps(pl,fmt=fmt,sort_keys=False)}
    for loc in ("zh-Hans","en"):
        changed[app+loc+".lproj/Localizable.strings"]=strings
        changed[app+loc+".lproj/InfoPlist.strings"]=info_strings
    extensions = [n for n in files if n.startswith(app+"PlugIns/") and n.endswith(".appex/Info.plist")]
    for extension_path in extensions:
        ext_root=extension_path.rsplit("/", 1)[0]+"/"
        ext_plist_bytes=zin.read(extension_path)
        ext_info=plistlib.loads(ext_plist_bytes)
        ext_info["CFBundleDevelopmentRegion"]="zh-Hans"
        ext_info["CFBundleLocalizations"]=["zh-Hans","en"]
        ext_fmt=plistlib.FMT_BINARY if ext_plist_bytes.startswith(b"bplist") else plistlib.FMT_XML
        changed[extension_path]=plistlib.dumps(ext_info,fmt=ext_fmt,sort_keys=False)
        for loc in ("zh-Hans","en"):
            changed[ext_root+loc+".lproj/Localizable.strings"]=strings
            changed[ext_root+loc+".lproj/InfoPlist.strings"]=info_strings
    with zipfile.ZipFile(dst,"w",allowZip64=True) as zout:
        for item in zin.infolist():
            n=item.filename
            if "/_CodeSignature/" in n or n.endswith("/CodeResources"): continue
            data=changed.pop(n, None)
            if data is None: data=zin.read(n)
            zout.writestr(item,data,compress_type=item.compress_type)
        for n,data in changed.items():
            zout.writestr(n,data,compress_type=zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(dst) as z:
    assert z.testzip() is None, "Corrupt output ZIP"
    assert hashlib.sha256(z.read(exe)).hexdigest()==original_sha, "Executable changed"
    assert app+"zh-Hans.lproj/Localizable.strings" in z.namelist()
print("Patched:",dst,"/ untranslated dynamic UI text may remain")
print("Kept original Mach-O SHA256:",original_sha)
print("IPA requires resigning with SideStore/AltStore/etc.")
