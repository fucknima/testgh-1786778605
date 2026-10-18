// dwg/tests/settings_ui_compile.mm —— 仅编译 TU：验证 SettingsMenu.h 在真实 UIKit SDK 下可编译。
//
// 本文件不运行、不链接 App、不访问网络、不修改任何工程配置；不能用它宣称菜单真机可用。
// 编译与真机验证由主会话 macOS CI / 设备完成。
//
// 主会话 CI 建议命令（与现有 dwg.yml 的严格编译参数一致，另加 -framework UIKit）：
//   xcrun --sdk iphoneos clang++ -std=c++17 -fobjc-arc -fblocks -Wall -Wextra -Werror \
//     -target arm64-apple-ios15.0 -isysroot "$SDKROOT" -framework UIKit \
//     -c dwg/tests/settings_ui_compile.mm -o "$RUNNER_TEMP/settings_ui_compile.o"
#import <UIKit/UIKit.h>
#import "../SettingsMenu.h"

// 非 static 符号：保证导出的产品接口被真实引用，同时避免 -Wunused-function。
void DWGSettingsMenuCompileCheck(void) {
    DWGSettingsEntryOutcome outcome = DWGInstallSettingsEntry(@"");
    (void)outcome.status;
    (void)outcome.reason;

    // Hooks.h 的广告安装器在菜单 TU 里未被调用；取地址避免 -Wunused-function，
    // 不执行、不改变任何 hook 状态。
    (void)&DWGInstallAdHooksForImage;

    Class rowClass = [DWGMenuPluginSettingsRowButton class];
    (void)rowClass;

    DWGPluginSettingsViewController *settings = [[DWGPluginSettingsViewController alloc] init];
    (void)settings;

    DWGPluginSettingsPresenter *presenter = DWGSettingsPresenterShared();
    (void)presenter;
}
