"""SettingsMenu.h / Preferences.h 的源码结构契约测试（只读，可在 Linux 运行）。

声明（必须保留）：这是结构测试，不是编译测试、不是 UIKit 运行测试、不是真机界面测试。
  * 不启动 App、不加载 UIKit、不证明菜单真机可达或布局正确；
  * 编译（-framework UIKit）与真机行为由主会话 macOS CI / 设备完成；
  * 本测试只防结构性回退：依赖方向、目标签名、发布顺序、幂等、只动新增行、
    不 hook 布局回调、诊断不伪造、偏好单一事实源。

运行：python3 dwg/tests/settings_menu_contract_test.py
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
menu_src = (root / "SettingsMenu.h").read_text(encoding="utf-8")
prefs_src = (root / "Preferences.h").read_text(encoding="utf-8")


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


menu = strip_comments(menu_src)
prefs = strip_comments(prefs_src)

# ---------------------------------------------------------------------------
# 1. 依赖方向：菜单复用 Hooks.h 的校验工具，不复制第二套；Hooks.h 不回指菜单
assert '#import "Preferences.h"' in menu_src
assert '#import "Hooks.h"' in menu_src
# 菜单直接复用的三个工具（DWGPathsEqualNormalized 经 DWGClassIsInImage 间接复用）
for name in ("DWGTypeEncodingMatches", "DWGCopyOwnMethod", "DWGClassIsInImage"):
    assert name in menu, f"未复用 Hooks.h 工具: {name}"
for name in ("DWGTypeEncodingMatches", "DWGPathsEqualNormalized",
             "DWGCopyOwnMethod", "DWGClassIsInImage"):
    assert f"bool {name}(" not in menu, f"菜单重复定义了 {name}"
    assert f"Method {name}(" not in menu, f"菜单重复定义了 {name}"
    assert name in (root / "Hooks.h").read_text(encoding="utf-8"), f"Hooks.h 缺少 {name}"
assert "SettingsMenu.h" not in (root / "Hooks.h").read_text(encoding="utf-8")

# ---------------------------------------------------------------------------
# 2. 目标为已核自有方法：类名 / selector / 类型编码 / runtime argc
assert 'objc_getClass("GSSettingViewController")' in menu
assert "@selector(viewDidLoad)" in menu
assert 'kDWGMenuEncSettingsViewDidLoad = "v16@0:8"' in menu_src
assert "kDWGMenuArgcSettingsViewDidLoad = 2" in menu_src
assert "DWGCopyOwnMethod(klass, @selector(viewDidLoad))" in menu
assert "DWGClassIsInImage(klass, mainImagePath)" in menu
assert "method_getNumberOfArguments(own) != kDWGMenuArgcSettingsViewDidLoad" in menu
assert "DWGTypeEncodingMatches(method_getTypeEncoding(own), kDWGMenuEncSettingsViewDidLoad)" in menu

# ---------------------------------------------------------------------------
# 3. 发布顺序：空 IMP 先拒绝 → 原 IMP 写入 typed global → 再 setImplementation → 最后标记已装
assert menu.index('"null-imp"') < menu.index(
    "gDWGOriSettingsViewDidLoad = (DWGSettingsViewDidLoadFn)original;")
assign = menu.index("gDWGOriSettingsViewDidLoad = (DWGSettingsViewDidLoadFn)original;")
publish = menu.index("method_setImplementation(own, (IMP)&DWGSettingsViewDidLoad);")
assert assign < publish
assert publish < menu.index("gDWGInstalledSettingsEntry = true;")
assert menu.count("gDWGOriSettingsViewDidLoad = (DWGSettingsViewDidLoadFn)original;") == 1
assert "gDWGOriSettingsViewDidLoad(self, _cmd);" in menu
assert menu.index("gDWGOriSettingsViewDidLoad(self, _cmd);") < menu.index("DWGSettingsAttachRow(self);")
assert "DWGInstallSettingsEntry(NSString *mainImagePath)" in menu
assert 'if (![mainImagePath isKindOfClass:[NSString class]] || mainImagePath.length == 0)' in menu

# ---------------------------------------------------------------------------
# 4. 幂等：安装器 + 入口行都幂等；入口行按专用视图类判定，不靠 tag 撞名
assert "if (gDWGInstalledSettingsEntry)" in menu
assert "DWGMenuPluginSettingsRowButton" in menu
assert "[subview isKindOfClass:[DWGMenuPluginSettingsRowButton class]]" in menu
assert "viewWithTag" not in menu

# ---------------------------------------------------------------------------
# 5. 只碰已核容器：所有 ui_ 访问器必须落在这 5 个已核 getter 内
getters = set(re.findall(r"\bui_[A-Za-z]+\b", menu))
allowed = {"ui_scrollView", "ui_privacyManageView", "ui_showDebugSettingView",
           "ui_showDebugSettingViewTopConstraint", "ui_contentBottomConstraint"}
assert getters <= allowed, f"出现未核 getter: {getters - allowed}"
for forbidden in ("setHidden", "ui_clearCache", "ui_personalizedAD", "ui_privilegeDiagnosis",
                  "ui_usageAmount", "ui_showOLEInfo", "ui_titleViewHeightConstraint"):
    assert forbidden not in menu, f"不得改动既有入口/其他约束: {forbidden}"

# ---------------------------------------------------------------------------
# 6. 不 hook 布局回调；内容高度只在插入时加一次，不随 layout 累加
for forbidden in ("viewWillLayoutSubviews", "viewDidLayoutSubviews", "layoutSubviews",
                  "viewDidAppear", "method_exchangeImplementations"):
    assert forbidden not in menu, f"不得 hook/交换: {forbidden}"
attach_start = menu.index("static void DWGSettingsAttachRow(id self) {")
attach_end = menu.index("static void DWGSettingsViewDidLoad(id self, SEL _cmd) {", attach_start)
attach = menu[attach_start:attach_end]
assert attach.count("contentBottomConstraint.constant +=") == 1
assert "kDWGMenuPluginSettingsRowHeight + kDWGMenuPluginSettingsRowSpacing" in attach

# ---------------------------------------------------------------------------
# 7. 布局只用 AutoLayout；无硬编码坐标/尺寸，不覆盖宿主既有行
for forbidden in ("CGRectMake", "setFrame:", ".frame =", "NSMakeRect"):
    assert forbidden not in menu, f"不得硬编码坐标/尺寸: {forbidden}"
assert "translatesAutoresizingMaskIntoConstraints = NO" in attach
assert "activateConstraints" in attach
assert "privacyView.superview != scrollView || debugView.superview != scrollView" in attach
assert "privacyIndex >= debugIndex" in attach
assert "debugTopConstraint.active = NO;" in attach
assert "previousDebugTopConstant" in attach
assert "navigationItem" not in attach  # 不猜宿主导航按钮

# ---------------------------------------------------------------------------
# 8. 入口是原设置页内的一行；插件页只模态展示，返回只 dismiss，不接管宿主导航栈
assert "UIModalPresentationPopover" in menu
assert menu.count("userInterfaceIdiom == UIUserInterfaceIdiomPad") >= 2
assert "popoverPresentationController.sourceView" in menu
assert "popoverPresentationController.sourceRect" in menu
assert "pushViewController" not in menu
assert "popViewController" not in menu
assert "setViewControllers" not in menu
assert "dismissViewControllerAnimated:YES completion:nil" in menu

# ---------------------------------------------------------------------------
# 9. 三个开关真实读写 Preferences.h（单一事实源），菜单不自建偏好存储
assert "NSUserDefaults" not in menu
assert "DWGSettingsMasterEnabledKey" not in menu
assert "toggle.on = DWGEnabled();" in menu
assert "toggle.on = DWGAdsEnabled();" in menu
assert "toggle.on = DWGLocalMemberEnabled();" in menu
assert "DWGSetMasterEnabled(toggle.isOn)" in menu
assert "DWGSetAdsEnabled(toggle.isOn)" in menu
assert "DWGSetLocalMemberEnabled(toggle.isOn)" in menu

# ---------------------------------------------------------------------------
# 10. 诊断真实：安装结果/命中上报接口存在；不伪造广告 hook 的 installed/hit
assert "DWGDiagnosticsSetHookState" in menu
assert "DWGDiagnosticsIncrementHit" in menu
assert 'DWGDiagnosticsIncrementHit(@"settingsEntry")' in menu
for reason in ("outlet-missing", "outlet-type-mismatch", "structure-mismatch",
               "anchor-constraint-inactive", "attached"):
    assert f'@"{reason}"' in menu, f"缺少真实 guard 结果: {reason}"
assert 'DWGDiagnosticsSetHookState(@"settingsEntry", YES, @"ok")' in menu
assert 'DWGDiagnosticsSetHookState(@"settingsEntry", NO, [NSString stringWithUTF8String:reason])' in menu
assert 'DWGDiagnosticsStore' not in menu  # 诊断存储只在 Preferences.h
for hook in ("isShowADForAdType", "isExemptAdUserWithKey", "isKindForGongNeng"):
    assert f'DWGDiagnosticsSetHookState(@"{hook}"' not in menu, f"菜单不得伪造 {hook} 状态"
assert "DWGDiagnosticsText()" in menu
assert "UIActivityViewController" in menu

# ---------------------------------------------------------------------------
# 11. Preferences.h：默认开启、类型回退、组合规则、保存保留、并发保护的诊断状态
assert "boolForKey:" not in prefs  # 不用会猜类型的便捷读取
assert "isKindOfClass:[NSNumber class]" in prefs
assert "if (defaults == nil || key.length == 0)" in prefs
assert "return YES;" in prefs
assert prefs.count("DWGEnabledForDefaults(defaults) &&") == 2
assert "DWGAdsEnabledForDefaults" in prefs
assert "DWGLocalMemberEnabledForDefaults" in prefs
assert "[defaults setBool:value forKey:key]" in prefs
assert "DWGSetMasterEnabled" in prefs and "DWGSetAdsEnabled" in prefs and "DWGSetLocalMemberEnabled" in prefs
assert prefs.count("@synchronized (DWGDiagnosticsStore())") == 3
assert "DWGDiagnosticsSnapshot" in prefs
assert "DWGDiagnosticsText" in prefs
assert "mainImagePath" not in prefs
for forbidden in ("NSURLSession", "NSURLConnection", "NSURLRequest", "SecItem", "keychain"):
    assert forbidden.lower() not in prefs.lower(), f"偏好/诊断不得涉及: {forbidden}"
# 只拦独立词（避免误伤 onceToken 这类标识符）；注释已在 prefs 中剥离。
for forbidden in ("token", "cookie", "password", "username"):
    assert not re.search(r"\b" + forbidden + r"\b", prefs.lower()), f"偏好/诊断不得涉及: {forbidden}"

# ---------------------------------------------------------------------------
# 12. 决策字段展示（只读、固定 3 个导出码）：lastCode/original/result/changed + exportDecisions
for token in ("lastCode", "original", "result", "changed", "exportDecisions",
              "mcv_drawing_export_pdf", "mcv_pdf_export_multipage", "mcv_drawing_export_image"):
    assert token in prefs, f"诊断展示缺少契约字段: {token}"
assert "改值 %llu 次" in prefs_src
assert "最近 code=%@ %d→%d" in prefs_src
assert "导出 %@：%d→%d" in prefs_src
assert "导出 %@：未命中" in prefs_src
assert "DWGDiagnosticsTextForDefaults" in prefs
for key in ("lastCode", "original", "result", "changed", "exportDecisions"):
    assert f'entry[@"{key}"] =' not in prefs, f"展示层不得写入决策字段（写入方只有 Hooks.h）: {key}"
assert "lastCode" not in menu
assert "exportDecisions" not in menu
assert "未上报" in prefs_src
attach = menu.split("static void DWGSettingsAttachRow(id self)", 1)[1].split("// typed original", 1)[0]
assert attach.index("isKindOfClass:[DWGMenuPluginSettingsRowButton class]") < attach.index("debugTopConstraint.isActive")
assert "未命中" in prefs_src

print("settings_menu_contract_test: 结构契约全部通过（非编译、非真机测试）")
