// dwg/tests/hooks_test.mm —— Hooks.h 的 macOS 单测（Foundation + objc/runtime，无框架，纯 assert）
//
// 运行（示例，CI 由主会话负责）：
//   clang++ -std=c++17 -fobjc-arc -framework Foundation hooks_test.mm -o hooks_test && ./hooks_test
//   注意：不要定义 NDEBUG（本文件用自己的 DWGAssert，不依赖 assert 宏）。
//
// 隔离原则：
//   * 本测试只 include ../Hooks.h（以及经它引入的 ../LocalFunctions.h），**不链接 Tweak.mm**，
//     因此产品 constructor / bundle guard 不会在测试进程里执行；bundle/版本判定用纯函数直接测。
//   * 需要“类缺失 / 签名不符 / 非自有”的场景无法在同一进程复用同名类注册，
//     统一用 fork + execl(argv[0], argv[0], <scenario>) 在干净子进程里跑，父进程只校验退出码。
//   * 伪宿主方法用精确 type encoding 动态注册（B 用 C++ bool，不用宿主 BOOL）。
#import <Foundation/Foundation.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "../Hooks.h"

// 不用 assert.h：避免 CI 传 -DNDEBUG 时断言被抹掉。
#define DWGAssert(expr)                                                        \
    do {                                                                       \
        if (!(expr)) {                                                         \
            std::fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #expr); \
            std::abort();                                                      \
        }                                                                      \
    } while (0)

// 仅用于类型检查的 selector 声明（放在真实存在的 NSObject 类别里）：
//   * 假宿主类由运行时动态注册，不能声明成 @interface（否则链接期会找 _OBJC_CLASS_$_GSToolLib 符号）；
//   * 类方法用 Class 接收者调用 → clang 在全局类方法池里找到这里的 + 声明，发出真实 objc_msgSend；
//   * 实例方法用 id 接收者调用 → 找到这里的 - 声明。
@interface NSObject (DWGTestFakeHostSelectors)
+ (bool)isShowADForAdType:(id)adTypeKey;
+ (bool)isExemptAdUserWithKey;
- (int)isKindForGongNeng:(id)functionCode;
@end

// ---------------------------------------------------------------------------
// 伪宿主实现 + 计数器（wrapper 必须恰好调用 original 一次）
static int gFakeShowCalls = 0;
static bool gFakeShowReturn = false;
static bool FakeIsShowADForAdType(id self, SEL _cmd, id adTypeKey) {
    ++gFakeShowCalls;
    (void)self; (void)_cmd; (void)adTypeKey;
    return gFakeShowReturn;
}

static int gFakeExemptCalls = 0;
static bool gFakeExemptReturn = false;
static bool FakeIsExemptAdUserWithKey(id self, SEL _cmd) {
    ++gFakeExemptCalls;
    (void)self; (void)_cmd;
    return gFakeExemptReturn;
}

static int gFakeFuncCalls = 0;
static int gFakeFuncReturn = 0;
static int FakeIsKindForGongNeng(id self, SEL _cmd, id functionCode) {
    ++gFakeFuncCalls;
    (void)self; (void)_cmd; (void)functionCode;
    return gFakeFuncReturn;
}

static Class DWGRegisterClass(Class superclass, const char *name) {
    Class cls = objc_allocateClassPair(superclass, name, 0);
    DWGAssert(cls != Nil);
    objc_registerClassPair(cls);
    return cls;
}

static void DWGAddClassMethod(Class cls, SEL sel, IMP imp, const char *types) {
    DWGAssert(class_addMethod(object_getClass((id)cls), sel, imp, types));
}

static void DWGAddInstanceMethod(Class cls, SEL sel, IMP imp, const char *types) {
    DWGAssert(class_addMethod(cls, sel, imp, types));
}

// 真实类所在 image 路径（用于 image 判定测试）
static NSString *DWGImagePathOfClass(Class cls) {
    const char *name = class_getImageName(cls);
    return name != nullptr ? [NSString stringWithUTF8String:name] : nil;
}

static Class DWGToolLibClass(void) {
    return (Class)objc_getClass("GSToolLib");
}

static id DWGAppDelegateInstance(void) {
    Class cls = (Class)objc_getClass("AppDelegate");
    DWGAssert(cls != Nil);
    return [[cls alloc] init];
}

// ---------------------------------------------------------------------------
// 纯函数断言（runtime 无关）
static void DWGTestPureFunctions(void) {
    // 目标签名常量（runtime argc 含 self/_cmd）：安装器会拿它和 method_getNumberOfArguments 对照
    DWGAssert(kDWGArgcIsShowADForAdType == 3);
    DWGAssert(kDWGArgcIsExemptAdUserWithKey == 2);
    DWGAssert(kDWGArgcIsKindForGongNeng == 3);

    // 类型编码：offset 允许不同，类型严格（'c' 不替 'B'）
    DWGAssert(DWGTypeEncodingMatches("B24@0:8@16", "B24@0:8@16"));
    DWGAssert(DWGTypeEncodingMatches("B32@0:8@24", "B24@0:8@16"));
    DWGAssert(DWGTypeEncodingMatches("i24@0:8@16", "i24@0:8@16"));
    DWGAssert(DWGTypeEncodingMatches("B16@0:8", "B16@0:8"));
    DWGAssert(DWGTypeEncodingMatches("v24@0:8@?16", "v24@0:8@?16"));
    DWGAssert(!DWGTypeEncodingMatches("c24@0:8@16", "B24@0:8@16"));
    DWGAssert(!DWGTypeEncodingMatches("i24@0:8@16", "B24@0:8@16"));
    DWGAssert(!DWGTypeEncodingMatches("B24@0:8@16", "i24@0:8@16"));
    DWGAssert(!DWGTypeEncodingMatches("B16@0:8", "B24@0:8@16"));    // argc 少
    DWGAssert(!DWGTypeEncodingMatches("B32@0:8@16@24", "B24@0:8@16")); // argc 多
    DWGAssert(!DWGTypeEncodingMatches("B24Q0:8@16", "B24@0:8@16")); // arg0 self
    DWGAssert(!DWGTypeEncodingMatches("B24@0Q8@16", "B24@0:8@16")); // arg1 _cmd
    DWGAssert(!DWGTypeEncodingMatches("B24@0:8Q16", "B24@0:8@16")); // arg2 首个显式参数
    DWGAssert(!DWGTypeEncodingMatches("v24@0:8@16", "v24@0:8@?16"));
    DWGAssert(!DWGTypeEncodingMatches(nullptr, "B24@0:8@16"));
    DWGAssert(!DWGTypeEncodingMatches("B24@0:8@16", nullptr));

    // 白名单判定（NSString 层）：非 NSString 一律不命中（含 NSNull/NSNumber）
    DWGAssert(DWGIsWhitelistedAdTypeKey(@"ad_setting_drawing"));
    DWGAssert(DWGIsWhitelistedAdTypeKey(@"ad_setting_homeFlow"));
    DWGAssert(DWGIsWhitelistedAdTypeKey(@"ad_setting_homeBanner"));
    DWGAssert(DWGIsWhitelistedAdTypeKey(@"ad_setting_tableScreen"));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(@"ad_setting_homeBanner_all"));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(@"ad_setting_home"));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(@"AD_SETTING_DRAWING"));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(@""));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(nil));
    DWGAssert(!DWGIsWhitelistedAdTypeKey([NSNull null]));
    DWGAssert(!DWGIsWhitelistedAdTypeKey(@(7)));

    // image 路径归一化（iOS 上 dyld 常带 /private）
    DWGAssert(DWGPathsEqualNormalized("/private/var/a", "/var/a"));
    DWGAssert(DWGPathsEqualNormalized("/var/a", "/private/var/a"));
    DWGAssert(DWGPathsEqualNormalized("/var/a", "/var/a"));
    DWGAssert(!DWGPathsEqualNormalized("/var/a", "/var/b"));
    DWGAssert(!DWGPathsEqualNormalized("/var/a", "/private/var/ab"));
    DWGAssert(!DWGPathsEqualNormalized("", ""));
    DWGAssert(!DWGPathsEqualNormalized(nullptr, "/var/a"));
    DWGAssert(!DWGPathsEqualNormalized("/var/a", nullptr));

    // bundle/版本 guard：纯函数；非 NSString（nil/NSNull/NSNumber）与错误版本一律不通过
    DWGAssert(DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.2", @"5.21.2"));
    DWGAssert(DWGIsSupportedAdHookBundleInfo((id)[NSMutableString stringWithString:@"com.gstarcad.xian.ocsclient"],
                                             (id)[NSMutableString stringWithString:@"5.21.2"],
                                             (id)[NSMutableString stringWithString:@"5.21.2"])); // NSString 子类允许
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(nil, @"5.21.2", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", nil, @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.2", nil));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo([NSNull null], @"5.21.2", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", [NSNull null], @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.2", [NSNull null]));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@(5212), @"5.21.2", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @(5212), @(5212)));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@[@"com.gstarcad.xian.ocsclient"], @"5.21.2", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.other.app", @"5.21.2", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.3", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.20", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.2 ", @"5.21.2"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"com.gstarcad.xian.ocsclient", @"5.21.2", @"5.21.20"));
    DWGAssert(!DWGIsSupportedAdHookBundleInfo(@"", @"", @""));
}

// ---------------------------------------------------------------------------
// guard 层断言（必须在注册任何伪宿主之前执行）：
//   * image 判定（真类同 image / 伪造路径 / Nil 类）
//   * 空 image 路径
//   * 宿主类缺失（objc_getClass 为 Nil）
//   * 低层入口的类缺失
static void DWGTestGuardLayers(void) {
    NSString *realImage = DWGImagePathOfClass([NSObject class]);
    DWGAssert(realImage != nil);
    DWGAssert(DWGClassIsInImage([NSObject class], realImage));
    DWGAssert(!DWGClassIsInImage([NSObject class], @"/private/__dwg_no_such_image__"));
    DWGAssert(!DWGClassIsInImage(Nil, realImage));
    // 非法 image 路径一律 false（不抛异常）：空串回归 + nil / NSNumber / NSNull 类型边界
    DWGAssert(!DWGClassIsInImage([NSObject class], [[NSString alloc] init]));
    DWGAssert(!DWGClassIsInImage([NSObject class], nil));
    DWGAssert(!DWGClassIsInImage([NSObject class], (id)@(7)));
    DWGAssert(!DWGClassIsInImage([NSObject class], (id)[NSNull null]));

    DWGAdHookOutcome empty1 = DWGInstallAdHooksForImage(nil);
    DWGAssert(std::strcmp(empty1.isShowADForAdType.reason, "image-path-empty") == 0);
    DWGAdHookOutcome empty2 = DWGInstallAdHooksForImage(@"");
    DWGAssert(std::strcmp(empty2.isExemptAdUserWithKey.reason, "image-path-empty") == 0);
    DWGAssert(std::strcmp(empty2.isKindForGongNeng.reason, "image-path-empty") == 0);
    DWGAssert(DWGAdHookInstalledCount(empty2) == 0);

    // 本测试进程此时不应存在宿主同名类
    DWGAssert(objc_getClass("GSToolLib") == Nil);
    DWGAssert(objc_getClass("AppDelegate") == Nil);
    DWGAdHookOutcome missing = DWGInstallAdHooksForImage(realImage);
    DWGAssert(std::strcmp(missing.isShowADForAdType.reason, "class-missing") == 0);
    DWGAssert(std::strcmp(missing.isExemptAdUserWithKey.reason, "class-missing") == 0);
    DWGAssert(std::strcmp(missing.isKindForGongNeng.reason, "class-missing") == 0);

    // 低层入口：类缺失 → 全跳过，无 default 值
    DWGAdHookOutcome lowMissing = DWGInstallAdHooksForClasses(Nil, Nil);
    DWGAssert(DWGAdHookInstalledCount(lowMissing) == 0);
    DWGAssert(std::strcmp(lowMissing.isShowADForAdType.reason, "class-missing") == 0);
    DWGAssert(std::strcmp(lowMissing.isKindForGongNeng.reason, "class-missing") == 0);
}

// ---------------------------------------------------------------------------
// 正例：三条 hook 全装上，然后逐条验证行为
static void DWGTestInstalledBehavior(void) {
    // 动态注册伪宿主（精确 type encoding）
    Class toolLib = DWGRegisterClass([NSObject class], "GSToolLib");
    DWGAddClassMethod(toolLib, @selector(isShowADForAdType:), (IMP)&FakeIsShowADForAdType, "B24@0:8@16");
    DWGAddClassMethod(toolLib, @selector(isExemptAdUserWithKey), (IMP)&FakeIsExemptAdUserWithKey, "B16@0:8");
    Class appDelegate = DWGRegisterClass([NSObject class], "AppDelegate");
    DWGAddInstanceMethod(appDelegate, @selector(isKindForGongNeng:), (IMP)&FakeIsKindForGongNeng, "i24@0:8@16");

    // nohook 先测：安装前就是原始行为
    gFakeShowReturn = true; gFakeShowCalls = 0;
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing"] == true);
    DWGAssert(gFakeShowCalls == 1);

    // 低层安装（不链接 Tweak.mm；image 判定已在 DWGTestGuardLayers 覆盖）
    DWGAdHookOutcome outcome = DWGInstallAdHooksForClasses(toolLib, appDelegate);
    DWGAssert(outcome.isShowADForAdType.status == DWGHookStatusInstalled);
    DWGAssert(outcome.isExemptAdUserWithKey.status == DWGHookStatusInstalled);
    DWGAssert(outcome.isKindForGongNeng.status == DWGHookStatusInstalled);
    DWGAssert(std::strcmp(outcome.isShowADForAdType.reason, "ok") == 0);
    DWGAssert(DWGAdHookInstalledCount(outcome) == 3);

    // 安装后的 typed global 必须就是原实现；这些串行断言不证明发布时序或并发安全。
    // 保存先于发布的源码契约另由 source_contract_test.py 检查，不冒充并发压测。
    DWGAssert(gDWGOriIsShowADForAdType == (DWGIsShowADForAdTypeFn)&FakeIsShowADForAdType);
    DWGAssert(gDWGOriIsExemptAdUserWithKey == (DWGIsExemptAdUserWithKeyFn)&FakeIsExemptAdUserWithKey);
    DWGAssert(gDWGOriIsKindForGongNeng == (DWGIsKindForGongNengFn)&FakeIsKindForGongNeng);

    // hook1：4 个白名单 key + original==true → false，且 original 恰好被调 1 次
    static const char *const keys[] = {"ad_setting_drawing", "ad_setting_homeFlow",
                                       "ad_setting_homeBanner", "ad_setting_tableScreen"};
    for (unsigned int i = 0; i < 4; ++i) {
        NSString *key = [NSString stringWithUTF8String:keys[i]];
        gFakeShowReturn = true; gFakeShowCalls = 0;
        DWGAssert([DWGToolLibClass() isShowADForAdType:key] == false);
        DWGAssert(gFakeShowCalls == 1);
    }

    // hook1：original==false 不误改（仍是 false，且调用 1 次）
    gFakeShowReturn = false; gFakeShowCalls = 0;
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing"] == false);
    DWGAssert(gFakeShowCalls == 1);

    // hook1：白名单外/类型不符/含嵌入 NUL/前缀后缀/大小写差异一律原值透传
    gFakeShowReturn = true; gFakeShowCalls = 0;
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_other"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_homeBanner_all"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_home"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"AD_SETTING_DRAWING"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing_"] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:nil] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:(id)[NSNull null]] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:(id)@(7)] == true);
    DWGAssert([DWGToolLibClass() isShowADForAdType:(id)@[@"ad_setting_drawing"]] == true);
    DWGAssert(gFakeShowCalls == 10);

    // 嵌入 NUL 的 NSString：必须不命中（用 UTF8String/strcmp 的实现会在此误判为精确 key）
    NSMutableString *nulKey = [NSMutableString stringWithString:@"ad_setting_drawing"];
    [nulKey appendFormat:@"%C", (unichar)0];
    [nulKey appendString:@"x"];
    DWGAssert(nulKey.length == 20);
    DWGAssert(![nulKey isEqualToString:@"ad_setting_drawing"]);
    gFakeShowReturn = true; gFakeShowCalls = 0;
    DWGAssert([DWGToolLibClass() isShowADForAdType:nulKey] == true);
    DWGAssert(gFakeShowCalls == 1);

    // hook2：false / true 都被改成 true，且 original 各调 1 次
    gFakeExemptReturn = false; gFakeExemptCalls = 0;
    DWGAssert([DWGToolLibClass() isExemptAdUserWithKey] == true);
    DWGAssert(gFakeExemptCalls == 1);
    gFakeExemptReturn = true; gFakeExemptCalls = 0;
    DWGAssert([DWGToolLibClass() isExemptAdUserWithKey] == true);
    DWGAssert(gFakeExemptCalls == 1);

    // hook3：先 orig1，再交给真实 LocalFunctions 的公共策略（wrapper 不引入任何默认映射）
    id delegate = DWGAppDelegateInstance();
    static const char *const appCodes[] = {
        // 来自 App 自身 functionList.plist 证据（membership/codes_unique.txt）的候选；
        // 是否“被处理”由真实 LocalFunctions.h 的公共函数判定，本文不再自建名单。
        "mcv_file_save_save",
        "mcv_file_save_save_as",
        "mcv_drawing_export_pdf",
        "mcv_drawing_export_image",
        "mcv_drawing_measure_result",
        "mcv_drawing_measure_distance",
        "mcv_drawing_measure_area",
        "mcv_drawing_note_text",
        "mcv_drawing_layer_new_layer",
        "mcv_drawing_modify_trim",
        "mcv_drawing_modify_offset",
        "mcv_drawing_modify_fillet",
        "mcv_drawing_modify_chamfer",
        "mcv_drawing_insert_block",
        "mcv_drawing_new_block",
        "mcv_match_properties",
        "mcv_pdf_to_cad",
        "mcv_3D_models_view",
        "dfv_3D_models_documentation",
    };
    static const int originals[] = {0, 1, -1, 7};
    for (size_t i = 0; i < sizeof(appCodes) / sizeof(appCodes[0]); ++i) {
        id code = [NSString stringWithUTF8String:appCodes[i]];
        for (size_t j = 0; j < sizeof(originals) / sizeof(originals[0]); ++j) {
            gFakeFuncReturn = originals[j]; gFakeFuncCalls = 0;
            const int got = [delegate isKindForGongNeng:code];
            DWGAssert(got == DWGLocalFunctionResult(code, originals[j]));
            DWGAssert(gFakeFuncCalls == 1);
        }
    }

    // 与真实 LocalFunctions.h 白名单对齐的一例（导出 PDF）：original==0 → 被本机策略放行为 1。
    // 若会员侧将来调整白名单删掉该 code，这里会失败：按 LocalFunctions.h 重新挑一个已核 code 即可。
    {
        id code = @"mcv_drawing_export_pdf";     // provenance: dwg/LocalFunctions.h 当前白名单
        gFakeFuncReturn = 0; gFakeFuncCalls = 0;
        DWGAssert([delegate isKindForGongNeng:code] == 1);
        DWGAssert(gFakeFuncCalls == 1);
    }

    // 未知/非字符串 code：wrapper 与原 header 策略一致，且未知一律保持原值
    static const char *const unknownCodes[] = {"__dwg_no_such_code__", "", "mcv_ad_close"};
    for (size_t i = 0; i < sizeof(unknownCodes) / sizeof(unknownCodes[0]); ++i) {
        id code = [NSString stringWithUTF8String:unknownCodes[i]];
        for (size_t j = 0; j < sizeof(originals) / sizeof(originals[0]); ++j) {
            DWGAssert(DWGLocalFunctionResult(code, originals[j]) == originals[j]);
            gFakeFuncReturn = originals[j]; gFakeFuncCalls = 0;
            DWGAssert([delegate isKindForGongNeng:code] == originals[j]);
            DWGAssert(gFakeFuncCalls == 1);
        }
    }
    {
        id nonStringCode = @(12345); // LocalFunctions 契约：非字符串 code 保持原样
        for (size_t j = 0; j < sizeof(originals) / sizeof(originals[0]); ++j) {
            DWGAssert(DWGLocalFunctionResult(nonStringCode, originals[j]) == originals[j]);
            gFakeFuncReturn = originals[j]; gFakeFuncCalls = 0;
            DWGAssert([delegate isKindForGongNeng:nonStringCode] == originals[j]);
            DWGAssert(gFakeFuncCalls == 1);
        }
    }
    {
        // nil / NSNull functionCode：仍先回调 original 一次，且原值透传（不得 crash、不得伪造码）
        id nullishCodes[] = {nil, [NSNull null]};
        for (size_t i = 0; i < sizeof(nullishCodes) / sizeof(nullishCodes[0]); ++i) {
            for (size_t j = 0; j < sizeof(originals) / sizeof(originals[0]); ++j) {
                gFakeFuncReturn = originals[j]; gFakeFuncCalls = 0;
                DWGAssert([delegate isKindForGongNeng:nullishCodes[i]] == originals[j]);
                DWGAssert(gFakeFuncCalls == 1);
            }
        }
    }

    // 非空集成：至少一个 App 证据 code 被真实 LocalFunctions 处理（用其公共函数判定，不自己维护名单）
    bool anyHandled = false;
    for (size_t i = 0; i < sizeof(appCodes) / sizeof(appCodes[0]); ++i) {
        id code = [NSString stringWithUTF8String:appCodes[i]];
        if (DWGLocalFunctionResult(code, 0) != 0) { anyHandled = true; break; }
    }
    if (!anyHandled) {
        std::fprintf(stderr,
                     "FAIL: LocalFunctions 未处理任何 App 证据 code —— 本地功能接线尚未生效（属 LocalFunctions.h 侧）\n");
    }
    DWGAssert(anyHandled);

    // 幂等：再次安装不二次包装、不递归，original 仍恰好 1 次
    DWGAdHookOutcome again = DWGInstallAdHooksForClasses(toolLib, appDelegate);
    DWGAssert(again.isShowADForAdType.status == DWGHookStatusAlreadyInstalled);
    DWGAssert(again.isExemptAdUserWithKey.status == DWGHookStatusAlreadyInstalled);
    DWGAssert(again.isKindForGongNeng.status == DWGHookStatusAlreadyInstalled);
    gFakeShowReturn = true; gFakeShowCalls = 0;
    DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing"] == false);
    DWGAssert(gFakeShowCalls == 1);
    gFakeFuncCalls = 0;
    (void)[delegate isKindForGongNeng:@"mcv_file_save_save"];
    DWGAssert(gFakeFuncCalls == 1);

    // 开关只决定是否改值，关闭时仍调用原实现一次；仅用进程内参数域，不写用户持久偏好。
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *saved = [defaults volatileDomainForName:NSArgumentDomain];
    for (NSString *disabledKey in @[DWGSettingsMasterEnabledKey, DWGSettingsAdsEnabledKey,
                                    DWGSettingsLocalMemberEnabledKey]) {
        NSMutableDictionary *arguments = [saved mutableCopy];
        arguments[disabledKey] = @NO;
        [defaults setVolatileDomain:arguments forName:NSArgumentDomain];
        const bool adsOn = [disabledKey isEqualToString:DWGSettingsLocalMemberEnabledKey];
        const bool memberOn = [disabledKey isEqualToString:DWGSettingsAdsEnabledKey];
        gFakeShowReturn = true; gFakeShowCalls = 0;
        DWGAssert([toolLib isShowADForAdType:@"ad_setting_drawing"] == !adsOn);
        DWGAssert(gFakeShowCalls == 1);
        gFakeExemptReturn = false; gFakeExemptCalls = 0;
        DWGAssert([toolLib isExemptAdUserWithKey] == adsOn);
        DWGAssert(gFakeExemptCalls == 1);
        gFakeFuncReturn = 0; gFakeFuncCalls = 0;
        DWGAssert([delegate isKindForGongNeng:@"mcv_drawing_export_pdf"] == (memberOn ? 1 : 0));
        DWGAssert(gFakeFuncCalls == 1);
    }
    [defaults setVolatileDomain:saved forName:NSArgumentDomain];
    gFakeFuncReturn = 0;
    DWGAssert([delegate isKindForGongNeng:@"mcv_drawing_export_pdf"] == 1);
    (void)[delegate isKindForGongNeng:@"__unrecognized_private_string__"];
    NSDictionary *diagnostic = DWGDiagnosticsSnapshot()[@"isKindForGongNeng"];
    DWGAssert([diagnostic[@"lastCode"] isEqualToString:@"<未识别功能码>"]);
    DWGAssert([diagnostic[@"changed"] unsignedLongLongValue] > 0);
    DWGAssert([diagnostic[@"exportDecisions"][@"mcv_drawing_export_pdf"][@"result"] intValue] == 1);
}

// ---------------------------------------------------------------------------
// 负例场景（各自干净子进程；需要“同名类只注册一次”的差异签名/继承场景无法在同进程复用）
// 每个场景返回 0 表示通过。注：运行期 objc_allocateClassPair 的类没有 dyld image（class_getImageName 为 NULL），
// 所以行为类场景走低层入口 DWGInstallAdHooksForClasses；image 判定由 DWGTestGuardLayers 与 wrongimage 单独覆盖。
static int DWGRunChildScenario(const char *scenario) {
    @autoreleasepool {
        if (std::strcmp(scenario, "wrongimage") == 0) {
            Class toolLib = DWGRegisterClass([NSObject class], "GSToolLib");
            DWGAddClassMethod(toolLib, @selector(isShowADForAdType:), (IMP)&FakeIsShowADForAdType, "B24@0:8@16");
            DWGAddClassMethod(toolLib, @selector(isExemptAdUserWithKey), (IMP)&FakeIsExemptAdUserWithKey, "B16@0:8");
            Class appDelegate = DWGRegisterClass([NSObject class], "AppDelegate");
            DWGAddInstanceMethod(appDelegate, @selector(isKindForGongNeng:), (IMP)&FakeIsKindForGongNeng, "i24@0:8@16");

            IMP beforeShow = method_getImplementation(class_getClassMethod(toolLib, @selector(isShowADForAdType:)));
            DWGAdHookOutcome out = DWGInstallAdHooksForImage(@"/private/__dwg_no_such_image__");
            DWGAssert(std::strcmp(out.isShowADForAdType.reason, "image-mismatch") == 0);
            DWGAssert(std::strcmp(out.isExemptAdUserWithKey.reason, "image-mismatch") == 0);
            DWGAssert(std::strcmp(out.isKindForGongNeng.reason, "image-mismatch") == 0);
            // 一点都不能改
            DWGAssert(method_getImplementation(class_getClassMethod(toolLib, @selector(isShowADForAdType:))) == beforeShow);
            gFakeShowReturn = true; gFakeShowCalls = 0;
            DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing"] == true);
            DWGAssert(gFakeShowCalls == 1);
            return 0;
        }

        if (std::strcmp(scenario, "badret_c") == 0 || std::strcmp(scenario, "badret_i") == 0 ||
            std::strcmp(scenario, "badargc") == 0 || std::strcmp(scenario, "badself") == 0 ||
            std::strcmp(scenario, "badcmd") == 0 || std::strcmp(scenario, "badarg") == 0 ||
            std::strcmp(scenario, "badargc_exempt") == 0) {
            const char *badShowTypes = "B24@0:8@16";
            const char *badExemptTypes = "B16@0:8";
            bool expectShowInstalled = true;
            bool expectExemptInstalled = true;
            if (std::strcmp(scenario, "badret_c") == 0) { badShowTypes = "c24@0:8@16"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badret_i") == 0) { badShowTypes = "i24@0:8@16"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badargc") == 0) { badShowTypes = "B16@0:8"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badself") == 0) { badShowTypes = "B24Q0:8@16"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badcmd") == 0) { badShowTypes = "B24@0Q8@16"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badarg") == 0) { badShowTypes = "B24@0:8Q16"; expectShowInstalled = false; }
            else if (std::strcmp(scenario, "badargc_exempt") == 0) { badExemptTypes = "B24@0:8@16"; expectExemptInstalled = false; }

            Class toolLib = DWGRegisterClass([NSObject class], "GSToolLib");
            DWGAddClassMethod(toolLib, @selector(isShowADForAdType:), (IMP)&FakeIsShowADForAdType, badShowTypes);
            DWGAddClassMethod(toolLib, @selector(isExemptAdUserWithKey), (IMP)&FakeIsExemptAdUserWithKey, badExemptTypes);
            Class appDelegate = DWGRegisterClass([NSObject class], "AppDelegate");
            DWGAddInstanceMethod(appDelegate, @selector(isKindForGongNeng:), (IMP)&FakeIsKindForGongNeng, "i24@0:8@16");

            DWGAdHookOutcome out = DWGInstallAdHooksForClasses(toolLib, appDelegate);
            if (expectShowInstalled) {
                DWGAssert(out.isShowADForAdType.status == DWGHookStatusInstalled);
            } else {
                DWGAssert(out.isShowADForAdType.status == DWGHookStatusSkipped);
                DWGAssert(std::strcmp(out.isShowADForAdType.reason, "type-mismatch") == 0);
            }
            if (expectExemptInstalled) {
                DWGAssert(out.isExemptAdUserWithKey.status == DWGHookStatusInstalled);
            } else {
                DWGAssert(out.isExemptAdUserWithKey.status == DWGHookStatusSkipped);
                DWGAssert(std::strcmp(out.isExemptAdUserWithKey.reason, "type-mismatch") == 0);
            }
            DWGAssert(out.isKindForGongNeng.status == DWGHookStatusInstalled);
            return 0;
        }

        if (std::strcmp(scenario, "inherited_class") == 0 || std::strcmp(scenario, "inherited_instance") == 0) {
            SEL showSel = @selector(isShowADForAdType:);
            SEL exemptSel = @selector(isExemptAdUserWithKey);
            SEL funcSel = @selector(isKindForGongNeng:);

            if (std::strcmp(scenario, "inherited_class") == 0) {
                Class base = DWGRegisterClass([NSObject class], "DWGFakeToolLibBase");
                DWGAddClassMethod(base, showSel, (IMP)&FakeIsShowADForAdType, "B24@0:8@16");
                DWGAddClassMethod(base, exemptSel, (IMP)&FakeIsExemptAdUserWithKey, "B16@0:8");
                IMP baseShowBefore = method_getImplementation(class_getClassMethod(base, showSel));
                IMP baseExemptBefore = method_getImplementation(class_getClassMethod(base, exemptSel));

                Class sub = DWGRegisterClass(base, "GSToolLib");  // 自身不实现 → 继承来的

                DWGAdHookOutcome out = DWGInstallAdHooksForClasses(sub, Nil);
                DWGAssert(out.isShowADForAdType.status == DWGHookStatusSkipped);
                DWGAssert(std::strcmp(out.isShowADForAdType.reason, "not-own-method") == 0);
                DWGAssert(out.isExemptAdUserWithKey.status == DWGHookStatusSkipped);
                DWGAssert(std::strcmp(out.isExemptAdUserWithKey.reason, "not-own-method") == 0);
                // 父类 IMP 未修改
                DWGAssert(method_getImplementation(class_getClassMethod(base, showSel)) == baseShowBefore);
                DWGAssert(method_getImplementation(class_getClassMethod(base, exemptSel)) == baseExemptBefore);
                // 仍走父类实现
                gFakeShowReturn = false; gFakeShowCalls = 0;
                DWGAssert([DWGToolLibClass() isShowADForAdType:@"ad_setting_drawing"] == false);
                DWGAssert(gFakeShowCalls == 1);
                return 0;
            }

            Class base = DWGRegisterClass([NSObject class], "DWGFakeAppDelegateBase");
            DWGAddInstanceMethod(base, funcSel, (IMP)&FakeIsKindForGongNeng, "i24@0:8@16");
            IMP baseFuncBefore = method_getImplementation(class_getInstanceMethod(base, funcSel));

            Class sub = DWGRegisterClass(base, "AppDelegate");

            DWGAdHookOutcome out = DWGInstallAdHooksForClasses(Nil, sub);
            DWGAssert(out.isKindForGongNeng.status == DWGHookStatusSkipped);
            DWGAssert(std::strcmp(out.isKindForGongNeng.reason, "not-own-method") == 0);
            DWGAssert(method_getImplementation(class_getInstanceMethod(base, funcSel)) == baseFuncBefore);
            gFakeFuncReturn = 5; gFakeFuncCalls = 0;
            DWGAssert([DWGAppDelegateInstance() isKindForGongNeng:@"mcv_file_save_save"] == 5);
            DWGAssert(gFakeFuncCalls == 1);
            return 0;
        }

        std::fprintf(stderr, "unknown scenario: %s\n", scenario);
        return 2;
    }
}

static bool DWGRunScenarioForked(const char *selfPath, const char *scenario) {
    pid_t pid = fork();
    if (pid == 0) {
        execl(selfPath, selfPath, scenario, (char *)nullptr);
        _exit(127); // exec 失败
    }
    if (pid < 0) return false;
    int status = 0;
    if (waitpid(pid, &status, 0) != pid) return false;
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *arguments = [[defaults volatileDomainForName:NSArgumentDomain] mutableCopy];
        arguments[DWGSettingsMasterEnabledKey] = @YES;
        arguments[DWGSettingsAdsEnabledKey] = @YES;
        arguments[DWGSettingsLocalMemberEnabledKey] = @YES;
        [defaults setVolatileDomain:arguments forName:NSArgumentDomain];
        if (argc == 2) return DWGRunChildScenario(argv[1]);

        DWGTestPureFunctions();
        DWGTestGuardLayers();   // 必须在注册任何伪宿主之前

        static const char *const scenarios[] = {
            "wrongimage",      "badret_c",       "badret_i",        "badargc",
            "badself",         "badcmd",         "badarg",          "badargc_exempt",
            "inherited_class", "inherited_instance",
        };
        for (unsigned int i = 0; i < sizeof(scenarios) / sizeof(scenarios[0]); ++i) {
            if (!DWGRunScenarioForked(argv[0], scenarios[i])) {
                std::fprintf(stderr, "FAIL: scenario '%s' did not pass\n", scenarios[i]);
                return 1;
            }
        }

        DWGTestInstalledBehavior();
        std::fprintf(stdout, "[dwg-hooks-test] all passed\n");
        return 0;
    }
}
