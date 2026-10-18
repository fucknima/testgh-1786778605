// dwg/Tweak.mm —— 只做 bundle/版本 guard + constructor 入口；hook 安装器在 Hooks.h。
//
// 安装即启用；回退 = 移除或替换本库后冷启动（不写 defaults、不留持久状态）。
// 日志：每次启动最多 3 行（每条 hook 一行 installed/skipped，或 guard 拒绝时 1 行）；
//      不逐次调用打日志，不打印用户 code / 文件路径 / 账号 / token，不做后台文件 I/O。
#import "Hooks.h"

static void DWGLogHookSlot(NSString *label, DWGHookSlot slot) {
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
            NSLog(@"[DWG-adhooks] skipped: unsupported bundle/version");
            return;
        }

        DWGAdHookOutcome outcome = DWGInstallAdHooksForImage(bundle.executablePath);
        DWGLogHookSlot(@"isShowADForAdType", outcome.isShowADForAdType);
        DWGLogHookSlot(@"isExemptAdUserWithKey", outcome.isExemptAdUserWithKey);
        DWGLogHookSlot(@"isKindForGongNeng", outcome.isKindForGongNeng);
    }
}
