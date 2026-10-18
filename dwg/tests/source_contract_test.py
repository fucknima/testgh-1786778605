"""仅核查发布顺序/真实接线的源码契约，不是编译、并发或设备运行测试。"""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
hooks = (root / "Hooks.h").read_text()
entry = (root / "Tweak.mm").read_text()
installer = hooks.split("template <class Fn>", 1)[1].split(
    "static DWGAdHookOutcome DWGInstallAdHooksForClasses", 1
)[0]
assert installer.index("*outOriginal = (Fn)original;") < installer.index(
    "method_setImplementation(own, (IMP)replacement);"
)
assert installer.index('"null-imp"') < installer.index("*outOriginal =")
for name in ("IsShowADForAdType", "IsExemptAdUserWithKey", "IsKindForGongNeng"):
    # 必须直接保存到 wrapper 使用的 typed global，不是中转到局部 IMP。
    assert len(re.findall(r"&gDWGOri" + name + r"\s*\)", hooks)) == 1, name
    assert f"gDWGOri{name}(self, _cmd" in hooks, name
assert "orig == nullptr" not in hooks
assert "objc_copyClassList" not in hooks
assert "UTF8String];" not in hooks
assert "method_getNumberOfArguments(own)" in installer
assert "__attribute__((constructor))" in entry
assert entry.index("if (!DWGIsSupportedAdHookBundleInfo(") < entry.index(
    "DWGInstallAdHooksForImage(bundle.executablePath)"
)
assert "#import \"Hooks.h\"" in entry
assert '#include "LocalFunctions.h"' in hooks
print("source contract passed (not a compiler/concurrency/device test)")
