// dwg/Tweak.mm —— 宿主守卫、业务 hook 与原设置入口的启动接线。
//
// 开关只读写插件偏好；回退可关闭开关，或移除库重签后冷启动。
// 日志：仅启动安装结果（每条 hook 一行，或 guard 拒绝时 1 行）；
//      不逐次调用打日志，不打印用户 code / 文件路径 / 账号 / token，不做后台文件 I/O。
#import "Hooks.h"
#import "SettingsMenu.h"

static void DWGLogHookSlot(NSString *label, DWGHookSlot slot) {
    DWGDiagnosticsSetHookState(label, slot.status != DWGHookStatusSkipped,
                               slot.reason != nullptr ? [NSString stringWithUTF8String:slot.reason] : @"unknown");
    NSLog(@"[DWG-adhooks] %@: %@ (reason=%s)",
          label,
          slot.status == DWGHookStatusSkipped ? @"skipped" : @"installed",
          slot.reason != nullptr ? slot.reason : "?");
}

// 目标：com.gstarcad.xian.ocsclient / CFBundleShortVersionString 5.21.2 / CFBundleVersion 5.21.2。
// 非该精确版本一概不 attach（不把版本 guard 绕到任何其它 App）。
__attribute__((constructor))
static void DWGAdHooksEntry(void) {
    @autoreleasepool {
        NSBundle *bundle = [NSBundle mainBundle];
        NSDictionary *info = bundle.infoDictionary;
        NSString *bundleIdentifier = bundle.bundleIdentifier;
        NSString *shortVersion = info[@"CFBundleShortVersionString"];
        NSString *buildVersion = info[@"CFBundleVersion"];

        if (!DWGIsSupportedAdHookBundleInfo(bundleIdentifier, shortVersion, buildVersion)) {
            DWGDiagnosticsSetHookState(@"hostCompatibility", NO, @"unsupported-bundle-version");
            NSLog(@"[DWG-adhooks] skipped: unsupported bundle/version");
            return;
        }

        DWGAdHookOutcome outcome = DWGInstallAdHooksForImage(bundle.executablePath);
        DWGLogHookSlot(@"isShowADForAdType", outcome.isShowADForAdType);
        DWGLogHookSlot(@"isExemptAdUserWithKey", outcome.isExemptAdUserWithKey);
        DWGLogHookSlot(@"isKindForGongNeng", outcome.isKindForGongNeng);
        DWGSettingsEntryOutcome settings = DWGInstallSettingsEntry(bundle.executablePath);
        DWGDiagnosticsSetHookState(@"settingsEntry", settings.status != DWGSettingsEntryStatusSkipped,
                                   settings.reason != nullptr ? [NSString stringWithUTF8String:settings.reason] : @"unknown");
        NSLog(@"[DWG-settings] %s (reason=%s)",
              settings.status == DWGSettingsEntryStatusSkipped ? "skipped" : "installed",
              settings.reason != nullptr ? settings.reason : "unknown");
    }
}
