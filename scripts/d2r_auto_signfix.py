#!/usr/bin/env python3
"""D2R update watcher / iSigner pre-signature repair. Public re-upload is opt-in."""
import hashlib,json,os,plistlib,struct,subprocess,sys,tempfile,urllib.request,urllib.error,zipfile
from pathlib import Path,PurePosixPath

SRC="jiayx/d2r-mobile-build"
NAMES={"D2RMobile-unsigned.ipa":"D2RMobile-standard-SignFix.ipa",
       "D2RMobile-ios18-unsigned.ipa":"D2RMobile-ios18-SignFix.ipa"}
MAGIC=b"\xcf\xfa\xed\xfe"
def die(msg): raise SystemExit("SIGNFIX ERROR: "+str(msg))
def command(*args,cwd=None):
    print("RUN:",*args,flush=True)
    subprocess.run(args,cwd=cwd,check=True)
def ghget(path,notfound=False):
    token=os.getenv("GH_TOKEN")
    if not token: die("GH_TOKEN missing")
    req=urllib.request.Request("https://api.github.com"+path,headers={
        "Authorization":"Bearer "+token,"Accept":"application/vnd.github+json",
        "X-GitHub-Api-Version":"2022-11-28","User-Agent":"D2R-SignFix"})
    try:
        with urllib.request.urlopen(req,timeout=40) as resp:return json.load(resp)
    except urllib.error.HTTPError as exc:
        if notfound and exc.code==404:return None
        die("GitHub API "+path+": HTTP "+str(exc.code))
def sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as stream:
        for block in iter(lambda:stream.read(4*1024*1024),b""):h.update(block)
    return h.hexdigest()
def upstream():
    rel=ghget("/repos/"+SRC+"/releases/latest")
    assets={v["name"]:v for v in rel["assets"]}
    if "D2RMobile-unsigned.ipa" not in assets:die("latest upstream release has no standard IPA")
    selected=[assets[n] for n in NAMES if n in assets]
    for a in selected:
        if not a.get("digest","").startswith("sha256:") or len(a["digest"])!=71:
            die("upstream asset lacks SHA256: "+a["name"])
        if a.get("size",0)<1000000:die("IPA unexpectedly small: "+a["name"])
        if not a["browser_download_url"].startswith("https://github.com/"+SRC+"/releases/download/"):
            die("unexpected download origin")
    tag=rel["tag_name"]
    if len(tag)>110 or not all(c.isalnum() or c in ".-_" for c in tag):die("unsafe upstream release tag")
    seed="\n".join(a["name"]+":"+a["digest"] for a in selected)
    target="d2r-signfix-"+tag+"-"+hashlib.sha256(seed.encode()).hexdigest()[:12]
    return rel,selected,target
def ready(rel,assets,tag):
    repo=os.environ["GITHUB_REPOSITORY"]
    existing=ghget("/repos/"+repo+"/releases/tags/"+tag,True)
    expected={NAMES[a["name"]] for a in assets}|{"SIGNING-REPORT.json","SHA256SUMS.txt"}
    if existing and expected<={a["name"] for a in existing.get("assets",[]) if a["size"]>0}:
        print("Already repaired:",tag);return False
    if existing:print("Existing release incomplete; retry uploading")
    return True
def check():
    rel,assets,tag=upstream()
    update=ready(rel,assets,tag)
    for key,val in (("needs_repair",str(update).lower()),("target_tag",tag)):
        print(key+"="+val)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"],"a") as f:print(key+"="+val,file=f)
    print("Upstream:",rel["html_url"],[a["name"] for a in assets])
def signatures(blob):
    if blob[:4]!=MAGIC or struct.unpack_from("<I",blob,4)[0]!=0x100000c:die("not arm64 Mach-O")
    count,total=struct.unpack_from("<II",blob,16)
    if count>1000 or total>10000000:die("invalid Mach-O commands")
    off=32; matches=[]
    for _ in range(count):
        if off+8>len(blob):die("truncated Mach-O")
        cmd,size=struct.unpack_from("<II",blob,off)
        if size<8 or off+size>len(blob):die("bad Mach-O command")
        if cmd==0x1d:
            dataoff,datasize=struct.unpack_from("<II",blob,off+8)
            if not dataoff or not datasize or dataoff+datasize>len(blob):
                die("bad LC_CODE_SIGNATURE")
            matches.append((dataoff,datasize))
        off+=size
    if off!=32+total:die("Mach-O load command size mismatch")
    return matches
def text_hashes(path):
    blob=path.read_bytes()
    if blob[:4]!=MAGIC:die("expected arm64 Mach-O: "+str(path))
    off=32;ncmds=struct.unpack_from("<I",blob,16)[0];result={}
    for _ in range(ncmds):
        cmd,size=struct.unpack_from("<II",blob,off)
        if cmd==0x19:
            count=struct.unpack_from("<I",blob,off+64)[0]
            if 72+80*count>size:die("invalid segment sections")
            for i in range(count):
                p=off+72+i*80
                name=blob[p:p+16].split(b"\0")[0].decode("ascii","replace")
                segment=blob[p+16:p+32].split(b"\0")[0].decode("ascii","replace")
                length=struct.unpack_from("<Q",blob,p+40)[0]
                foff=struct.unpack_from("<I",blob,p+48)[0]
                if segment=="__TEXT" and length and foff and foff+length<=len(blob):
                    result[segment+"/"+name+"@"+str(foff)]=hashlib.sha256(blob[foff:foff+length]).hexdigest()
        off+=size
    return result
def repair(asset,root):
    name=asset["name"];target=root/name
    command("curl","-fL","--retry","4","--retry-delay","3","--connect-timeout","30",
            "--silent","--show-error","-o",str(target),asset["browser_download_url"])
    if target.stat().st_size!=asset["size"] or sha(target)!=asset["digest"][7:]:
        die("upstream SHA256/size mismatch: "+name)
    work=root/name.replace(".ipa","");work.mkdir()
    with zipfile.ZipFile(target) as z:
        if z.testzip() is not None:die("IPA CRC failed")
        for m in z.namelist():
            q=PurePosixPath(m)
            if q.is_absolute() or ".." in q.parts:die("unsafe IPA member")
        z.extractall(work)
    apps=list((work/"Payload").glob("*.app"))
    if len(apps)!=1:die("must have exactly one .app")
    app=apps[0]
    main=app/plistlib.loads((app/"Info.plist").read_bytes())["CFBundleExecutable"]
    guest=app/"Frameworks/Guest.framework/Guest"
    if not main.is_file() or not guest.is_file():die("missing main or Guest.framework")
    def macho_file(path):
        if not path.is_file():return False
        try:
            with open(path,"rb") as stream:return stream.read(4)==MAGIC
        except OSError:return False
    files=sorted(p for p in app.rglob("*") if macho_file(p))
    baseline={p.relative_to(app).as_posix():text_hashes(p) for p in files}
    if not baseline[main.relative_to(app).as_posix()] or not baseline[guest.relative_to(app).as_posix()]:
        die("cannot verify machine code sections")
    targets={p for p in app.rglob("*") if p.is_dir() and p.suffix in (".framework",".appex")}
    targets|={p for p in files if p.suffix==".dylib"}
    for p in sorted(targets,key=lambda x:-len(x.parts)):
        command("codesign","--force","--sign","-","--timestamp=none",str(p))
    command("codesign","--force","--sign","-","--timestamp=none",str(app))
    command("codesign","--verify","--deep","--strict","--verbose=2",str(app))
    after={p.relative_to(app).as_posix():text_hashes(p) for p in files}
    if baseline!=after:die("original machine code changed")
    for p in files:
        if not signatures(p.read_bytes()):die("missing new LC_CODE_SIGNATURE: "+str(p))
    output=root/NAMES[name]
    command("ditto","-c","-k","--keepParent","Payload",str(output),cwd=work)
    with zipfile.ZipFile(output) as z:
        if z.testzip() is not None:die("output IPA corrupted")
        for p in [main,guest]:
            inner="Payload/"+app.name+"/"+p.relative_to(app).as_posix()
            if not signatures(z.read(inner)):die("signature missing after packaging")
    return {"origin":name,"origin_sha256":asset["digest"][7:],
            "output":output.name,"sha256":sha(output),"bytes":output.stat().st_size},output
def build():
    rel,assets,tag=upstream()
    if os.environ.get("EXPECTED_TAG")!=tag:die("new release superseded queued job; next run will retry")
    if not ready(rel,assets,tag):return
    with tempfile.TemporaryDirectory(prefix="d2r-autofix-") as d:
        root=Path(d);results=[];out=[]
        for a in assets:
            row,file=repair(a,root);results.append(row);out.append(str(file))
        (root/"SIGNING-REPORT.json").write_text(json.dumps({
            "upstream_release":rel["html_url"],"upstream_tag":rel["tag_name"],
            "repair":"Apple codesign ad hoc; verify --deep --strict; original __TEXT hashes match",
            "re_sign_required":True,"assets":results},ensure_ascii=False,indent=2)+"\n")
        (root/"SHA256SUMS.txt").write_text("".join(r["sha256"]+"  "+r["output"]+"\n" for r in results))
        notes=root/"notes.md"
        notes.write_text(
            "来源："+rel["html_url"]+"\n\n"
            "已使用 Apple 原生 codesign 补齐签名加载命令并通过验签和原始机器指令一致性检查。\n"
            "IPA 为 Ad Hoc 预签名包，安装前仍需使用你自己的证书在 iSigner 中重新签名。\n"
            "18 个游戏 .data 文件不在 IPA 内。请遵守原始游戏的授权和再分发限制。\n",encoding="utf-8")
        repo=os.environ["GITHUB_REPOSITORY"]
        existing=ghget("/repos/"+repo+"/releases/tags/"+tag,True)
        private=bool(ghget("/repos/"+repo)["private"])
        public_optin=os.getenv("D2R_ALLOW_PUBLIC_REUPLOAD","").lower()=="true"
        args=out+[str(root/"SIGNING-REPORT.json"),str(root/"SHA256SUMS.txt")]
        if existing:
            command("gh","release","upload",tag,*args,"--clobber","--repo",repo)
        else:
            call=["gh","release","create",tag,"--repo",repo,
                  "--title","D2R Mobile 签名兼容修复 · "+rel["name"],
                  "--notes-file",str(notes)]
            if not private and not public_optin:call.append("--draft")
            else:call.append("--latest=false")
            command(*call,*args)
        print("SUCCESS:",tag,"PRIVATE/DRAFT" if not private and not public_optin else "PUBLISHED")
if __name__=="__main__":
    if len(sys.argv)!=2 or sys.argv[1] not in ("check","build"):die("usage: check | build")
    {"check":check,"build":build}[sys.argv[1]]()
