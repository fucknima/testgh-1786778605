// dwg/tests/preferences_test.mm —— 真实 Preferences.h 的机制测试（macOS Foundation + assert）
//
// 覆盖：
//   1. 默认开启 / 已保存 false 保留 / 总开关组合规则 / 类型不符回退默认 / 两个 isolated suite 隔离；
//   2. 诊断展示契约：
//      - 未上报 hook 显示“未上报”；
//      - 已安装但尚未命中显示“最近决策：尚未命中”，不伪造 0→1；
//      - 最近一次功能码决策（lastCode/original/result/changed）与三个公开导出码 original→result；
//      - exportDecisions 采用 copy-on-write 替换时，已取快照不被后续写入影响；
//      - 关闭偏好时文本显示原值组合（总开关关 → 两个子功能都显示关）；
//      - 文本不含路径 / 账号 / 凭据关键字。
//
// 边界：只测产品头文件的纯逻辑，不启动 App、不读写真实 App 容器、不写 standardUserDefaults。
//       Hooks.h 的决策字段写入由主会话 hooks_test 覆盖；本文件直接按契约字段写入 store，
//       仅用于验证“展示层”如实读取、不伪造。
//
// 运行（macOS）：
//   clang++ -std=c++17 -fobjc-arc -fblocks -Wall -Wextra -Werror -framework Foundation \
//     dwg/tests/preferences_test.mm -o /tmp/preferences_test && /tmp/preferences_test
#import <Foundation/Foundation.h>
#import "../Preferences.h"

#include <cassert>
#include <cstdio>
#include <unistd.h>

static NSString *DWGTestSuiteName(const char *tag) {
    return [NSString stringWithFormat:@"dwg-preferences-test-%d-%s", (int)getpid(), tag];
}

static NSUserDefaults *DWGTestDefaults(const char *tag) {
    NSString *suite = DWGTestSuiteName(tag);
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    assert(defaults != nil); // isolated suite 建不出来时直接失败，避免“测试空跑通过”
    [defaults removePersistentDomainForName:suite];
    return defaults;
}

static void DWGTestCleanup(NSUserDefaults *defaults, const char *tag) {
    if (defaults == nil) {
        return;
    }
    [defaults removePersistentDomainForName:DWGTestSuiteName(tag)];
}

static NSUInteger DWGTestOccurrences(NSString *text, NSString *needle) {
    NSUInteger count = 0;
    NSRange range = NSMakeRange(0, text.length);
    while (range.length > 0) {
        NSRange found = [text rangeOfString:needle options:0 range:range];
        if (found.location == NSNotFound) {
            break;
        }
        count += 1;
        NSUInteger next = NSMaxRange(found);
        range = NSMakeRange(next, text.length - next);
    }
    return count;
}

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = DWGTestDefaults("main");
        NSUserDefaults *other = DWGTestDefaults("other");

        // ------------------------------------------------------------------
        // 1. 偏好读写
        // 新用户（三个键都未保存）→ 默认全部开启（用户要求“开放”，新用户不需要先改开关）。
        assert([defaults objectForKey:DWGSettingsMasterEnabledKey] == nil);
        assert(DWGEnabledForDefaults(defaults) == YES);
        assert(DWGAdsEnabledForDefaults(defaults) == YES);
        assert(DWGLocalMemberEnabledForDefaults(defaults) == YES);

        // 已保存 false 必须保留：只关去广告时，总开关与本机会员仍为开。
        DWGSetPreferenceBool(defaults, DWGSettingsAdsEnabledKey, NO);
        assert(DWGEnabledForDefaults(defaults) == YES);
        assert(DWGAdsEnabledForDefaults(defaults) == NO);
        assert(DWGLocalMemberEnabledForDefaults(defaults) == YES);

        // 总开关关闭 → 两个子功能都视为关闭（组合规则），子开关保存值不被改写。
        DWGSetPreferenceBool(defaults, DWGSettingsMasterEnabledKey, NO);
        assert(DWGEnabledForDefaults(defaults) == NO);
        assert(DWGAdsEnabledForDefaults(defaults) == NO);
        assert(DWGLocalMemberEnabledForDefaults(defaults) == NO);
        assert([defaults objectForKey:DWGSettingsAdsEnabledKey] != nil);

        // 重新开启总开关 → 之前保存的去广告 false 仍然生效（不因重新开启被重置）。
        DWGSetPreferenceBool(defaults, DWGSettingsMasterEnabledKey, YES);
        assert(DWGEnabledForDefaults(defaults) == YES);
        assert(DWGAdsEnabledForDefaults(defaults) == NO);
        assert(DWGLocalMemberEnabledForDefaults(defaults) == YES);

        // 类型不符 → 回退默认开启，且不覆盖已保存的原始值。
        [defaults setObject:@"not-a-number" forKey:DWGSettingsLocalMemberEnabledKey];
        assert(DWGLocalMemberEnabledForDefaults(defaults) == YES);
        assert([[defaults objectForKey:DWGSettingsLocalMemberEnabledKey] isEqualToString:@"not-a-number"]);

        // 保存恢复 true；nil / 空键防御不改变任何已保存值。
        DWGSetPreferenceBool(defaults, DWGSettingsAdsEnabledKey, YES);
        assert(DWGAdsEnabledForDefaults(defaults) == YES);
        DWGSetPreferenceBool(nil, DWGSettingsAdsEnabledKey, NO);
        DWGSetPreferenceBool(defaults, @"", NO);
        assert(DWGAdsEnabledForDefaults(defaults) == YES);

        // 两个 isolated suite 互不影响（不读也不写真实 standard 域）。
        assert([defaults objectForKey:DWGSettingsAdsEnabledKey] != nil);
        assert([other objectForKey:DWGSettingsAdsEnabledKey] == nil);
        assert([other objectForKey:DWGSettingsMasterEnabledKey] == nil);
        assert(DWGEnabledForDefaults(other) == YES);
        assert(DWGAdsEnabledForDefaults(other) == YES);

        // ------------------------------------------------------------------
        // 2. 诊断展示：未上报
        NSString *text = DWGDiagnosticsTextForDefaults(defaults);
        assert(DWGTestOccurrences(text, @"未上报") == 3); // 三个广告/会员 hook 全部未接线
        assert(DWGTestOccurrences(text, @"导出 ") == 3);  // 固定 3 个导出码行
        assert([text containsString:@"导出 mcv_drawing_export_pdf：未命中"]);
        assert([text containsString:@"导出 mcv_pdf_export_multipage：未命中"]);
        assert([text containsString:@"导出 mcv_drawing_export_image：未命中"]);

        // 已安装但未命中：显示已安装、命中 0 次、最近决策：尚未命中；不伪造 0→1。
        DWGDiagnosticsSetHookState(@"isKindForGongNeng", YES, @"ok");
        text = DWGDiagnosticsTextForDefaults(defaults);
        assert(DWGTestOccurrences(text, @"未上报") == 2);
        assert([text containsString:@"isKindForGongNeng：已安装 (ok) 命中 0 次"]);
        assert([text containsString:@"最近决策：尚未命中"]);
        assert(![text containsString:@"改值 "]);

        // 最近一次功能码决策 + 三个导出码（按 Hooks.h 契约字段直接写入，仅验证展示）。
        @synchronized (DWGDiagnosticsStore()) {
            NSMutableDictionary *entry = DWGDiagnosticsEntry(@"isKindForGongNeng");
            entry[@"hits"] = @7;
            entry[@"lastCode"] = @"mcv_drawing_export_pdf";
            entry[@"original"] = @0;
            entry[@"result"] = @1;
            entry[@"changed"] = @3;
            entry[@"exportDecisions"] = @{
                @"mcv_drawing_export_pdf": @{@"original": @0, @"result": @1},
                @"mcv_drawing_export_image": @{@"original": @1, @"result": @1},
            };
        }
        text = DWGDiagnosticsTextForDefaults(defaults);
        assert([text containsString:@"命中 7 次"]);
        assert([text containsString:@"改值 3 次"]);
        assert([text containsString:@"最近 code=mcv_drawing_export_pdf 0→1"]);
        assert(![text containsString:@"最近决策：尚未命中"]);
        assert([text containsString:@"导出 mcv_drawing_export_pdf：0→1"]);
        assert([text containsString:@"导出 mcv_pdf_export_multipage：未命中"]);
        assert([text containsString:@"导出 mcv_drawing_export_image：1→1"]);
        assert(DWGTestOccurrences(text, @"导出 ") == 3);

        // exportDecisions 采用 copy-on-write 替换：旧快照仍持有旧不可变 map。
        NSDictionary *snapshotBefore = DWGDiagnosticsSnapshot();
        @synchronized (DWGDiagnosticsStore()) {
            NSMutableDictionary *entry = DWGDiagnosticsEntry(@"isKindForGongNeng");
            entry[@"exportDecisions"] = @{
                @"mcv_pdf_export_multipage": @{@"original": @1, @"result": @1},
            };
        }
        NSDictionary *beforeEntry = snapshotBefore[@"isKindForGongNeng"];
        NSDictionary *beforeDecisions = beforeEntry[@"exportDecisions"];
        assert([beforeDecisions[@"mcv_drawing_export_pdf"][@"result"] intValue] == 1);
        assert(beforeDecisions[@"mcv_pdf_export_multipage"] == nil);
        NSDictionary *snapshotAfter = DWGDiagnosticsSnapshot();
        assert([snapshotAfter[@"isKindForGongNeng"][@"exportDecisions"][@"mcv_pdf_export_multipage"][@"original"] intValue] == 1);
        text = DWGDiagnosticsTextForDefaults(defaults);
        assert([text containsString:@"导出 mcv_pdf_export_multipage：1→1"]);
        assert([text containsString:@"导出 mcv_drawing_export_pdf：未命中"]);

        // 关闭偏好时的原值组合：总开关关 → 两个子功能都显示关。
        [defaults setObject:@NO forKey:DWGSettingsMasterEnabledKey];
        [defaults setObject:@YES forKey:DWGSettingsAdsEnabledKey];
        [defaults setObject:@YES forKey:DWGSettingsLocalMemberEnabledKey];
        text = DWGDiagnosticsTextForDefaults(defaults);
        assert([text containsString:@"开关：总开关=关 去广告=关 本机会员=关"]);

        // 总开关开、去广告关 → 只显示去广告关（保存值保留）。
        [defaults setObject:@YES forKey:DWGSettingsMasterEnabledKey];
        [defaults setObject:@NO forKey:DWGSettingsAdsEnabledKey];
        text = DWGDiagnosticsTextForDefaults(defaults);
        assert([text containsString:@"开关：总开关=开 去广告=关 本机会员=开"]);

        // 文本不含路径 / 账号 / 凭据关键字。
        assert([text rangeOfString:@"/Users"].location == NSNotFound);
        assert([text rangeOfString:@"token"].location == NSNotFound);
        assert([text rangeOfString:@"cookie"].location == NSNotFound);
        assert([text rangeOfString:@"password"].location == NSNotFound);

        DWGTestCleanup(defaults, "main");
        DWGTestCleanup(other, "other");
        printf("preferences_test: 全部断言通过\n");
    }
    return 0;
}
