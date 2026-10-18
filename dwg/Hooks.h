// dwg/Hooks.h —— DWG FastView 5.21.2 广告净化：三处 exact hook 的安装器（header-only，单 TU 使用）
//
// 目标与边界（静态研究索引在本机保存；公开功能与限制见 README.md）：
//   1) +[GSToolLib isShowADForAdType:]     类型编码 B24@0:8@16（显式 1 参 / runtime argc 3）
//   2) +[GSToolLib isExemptAdUserWithKey]  类型编码 B16@0:8   （显式 0 参 / runtime argc 2）
//   3) -[AppDelegate isKindForGongNeng:]   类型编码 i24@0:8@16（显式 1 参 / runtime argc 3）
//   全部为宿主主程序 image 内的“自有”方法；本文件只负责“按 image 安装”，bundle/版本 guard 在 Tweak.mm。
//
// 纪律：
//   * 三个 wrapper 都先调用原实现一次，再按各自语义决定返回值：
//       hook1：原 false → false 不变；原 true 且 key 命中精确白名单 → false；其余原值透传。
//       hook2：原实现照常执行，随后沿 App 原生“免打扰”分支返回 true。
//       hook3：原值交给 LocalFunctions.h 的本地策略（不在此复制名单/策略）。
//   * 类缺失 / runtime argc 或类型编码不符（'B' 与 'c' 严格区分）/ 方法非自有 / 原 IMP 为空 / 类不在目标 image
//     → 跳过安装，不写默认值，不修改该方法。
//   * 自有多方法查找走 class_copyMethodList，避免误改继承来的父类实现。
//   * 安装即启用；本文件不做任何持久化、不做后台文件 I/O、不逐次调用打日志、不打印用户 code/path/账号/token。
//   * 依赖 Foundation + objc/runtime + C++17；无 UIKit / 无 Logos / 无 Theos / 无第三方 SDK。
//   * 只用到 Foundation/objc-runtime 的通用旧 API，部署目标 iOS 15 即可（宿主 App 自身要求 iOS 18，与本库独立）。
//
// 卸载：移除或替换本库后冷启动即可（无残留状态、无 defaults 写入）。
#pragma once

#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <cstdlib>
#include <cstring>

// 本地功能码策略由会员 agent 的 LocalFunctions.h 提供（DWGLocalFunctionResult）；本文件不复制其名单/策略。
#include "LocalFunctions.h"

// ---------------------------------------------------------------------------
// 纯逻辑：类型编码严格比较 + image 路径归一化（不依赖 runtime 状态，可在测试里直接断言）

// 严格比较 ObjC 类型编码：忽略数字 offset，其余 token 逐个严格相等。
// 例：B24@0:8@16 与 B32@0:8@24 视为相同（offset 差异允许）；c24@0:8@16 与 B24@0:8@16 不同（'c' 不替 'B'）。
static inline bool DWGTypeEncodingMatches(const char *actual, const char *expected) {
    if (actual == nullptr || expected == nullptr) return false;
    const char *a = actual;
    const char *b = expected;
    for (;;) {
        while (*a >= '0' && *a <= '9') ++a;
        while (*b >= '0' && *b <= '9') ++b;
        const bool aIsBlock = (a[0] == '@' && a[1] == '?');
        const bool bIsBlock = (b[0] == '@' && b[1] == '?');
        if (aIsBlock != bIsBlock) return false;
        if (a[0] == '\0' || b[0] == '\0') return a[0] == b[0];
        if (a[0] != b[0]) return false;
        a += aIsBlock ? 2 : 1;
        b += bIsBlock ? 2 : 1;
    }
}

// 路径比较：iOS 上 dyld 的 image 名常带 "/private" 前缀而 NSBundle 的 executablePath 不带，归一化后再比。
static inline bool DWGPathsEqualNormalized(const char *a, const char *b) {
    if (a == nullptr || b == nullptr || a[0] == '\0' || b[0] == '\0') return false;
    const char *pa = (std::strncmp(a, "/private/", 9) == 0) ? a + 8 : a;
    const char *pb = (std::strncmp(b, "/private/", 9) == 0) ? b + 8 : b;
    return std::strcmp(pa, pb) == 0;
}

// ---------------------------------------------------------------------------
// 目标签名常量（静态已核，勿改；runtime argc 已含 self/_cmd）
static const char *const kDWGEncIsShowADForAdType     = "B24@0:8@16";
static const char *const kDWGEncIsExemptAdUserWithKey = "B16@0:8";
static const char *const kDWGEncIsKindForGongNeng     = "i24@0:8@16";

static const unsigned int kDWGArgcIsShowADForAdType     = 3;
static const unsigned int kDWGArgcIsExemptAdUserWithKey = 2;
static const unsigned int kDWGArgcIsKindForGongNeng     = 3;

// ---------------------------------------------------------------------------
// bundle/版本 guard 的纯判定。
// 参数取 id：真实 plist 输入不保证是 NSString（NSNull/NSNumber/数组都会出现），
// 非 NSString 一律不通过——不做“未知即当本版本”的兜底。
static inline bool DWGIsSupportedAdHookBundleInfo(id bundleIdentifier,
                                                 id shortVersion,
                                                 id buildVersion) {
    if (![bundleIdentifier isKindOfClass:[NSString class]]) return false;
    if (![shortVersion isKindOfClass:[NSString class]]) return false;
    if (![buildVersion isKindOfClass:[NSString class]]) return false;
    return [(NSString *)bundleIdentifier isEqualToString:@"com.gstarcad.xian.ocsclient"] &&
           [(NSString *)shortVersion isEqualToString:@"5.21.2"] &&
           [(NSString *)buildVersion isEqualToString:@"5.21.2"];
}

typedef enum {
    DWGHookStatusSkipped = 0,          // 未安装（原因见 reason）
    DWGHookStatusInstalled = 1,        // 本次安装成功
    DWGHookStatusAlreadyInstalled = 2, // 之前已安装，本次未改动（幂等）
} DWGHookStatus;

typedef struct {
    DWGHookStatus status;
    const char *reason;
} DWGHookSlot;

typedef struct {
    DWGHookSlot isShowADForAdType;
    DWGHookSlot isExemptAdUserWithKey;
    DWGHookSlot isKindForGongNeng;
} DWGAdHookOutcome;

static inline DWGHookSlot DWGHookSlotMake(DWGHookStatus status, const char *reason) {
    DWGHookSlot slot;
    slot.status = status;
    slot.reason = reason;
    return slot;
}

static inline unsigned int DWGAdHookInstalledCount(DWGAdHookOutcome outcome) {
    unsigned int count = 0;
    if (outcome.isShowADForAdType.status != DWGHookStatusSkipped) ++count;
    if (outcome.isExemptAdUserWithKey.status != DWGHookStatusSkipped) ++count;
    if (outcome.isKindForGongNeng.status != DWGHookStatusSkipped) ++count;
    return count;
}

// ---------------------------------------------------------------------------
// typed original（B = C++ bool（1 字节），不是 ObjC BOOL；i = int；@ = id）
// 这三个全局是 wrapper 唯一的调用入口：安装器在发布 replacement 之前把原 IMP 写进来（见 DWGInstallMethodHook）。
typedef bool (*DWGIsShowADForAdTypeFn)(id self, SEL _cmd, id adTypeKey);
typedef bool (*DWGIsExemptAdUserWithKeyFn)(id self, SEL _cmd);
typedef int (*DWGIsKindForGongNengFn)(id self, SEL _cmd, id functionCode);

static DWGIsShowADForAdTypeFn gDWGOriIsShowADForAdType = nullptr;
static DWGIsExemptAdUserWithKeyFn gDWGOriIsExemptAdUserWithKey = nullptr;
static DWGIsKindForGongNengFn gDWGOriIsKindForGongNeng = nullptr;

static bool gDWGInstalledIsShowADForAdType = false;
static bool gDWGInstalledIsExemptAdUserWithKey = false;
static bool gDWGInstalledIsKindForGongNeng = false;

// ---------------------------------------------------------------------------
// hooks 本体

// 精确匹配 4 个已核广告槽：用 NSString 的 isEqualToString:（长度+内容），
// 不用 UTF8String/strcmp 之类会截断的实现（含嵌入 NUL 的字符串必须判为不命中）。
// nil / NSNull / NSNumber / 数组等非 NSString 一律不命中 → 由 wrapper 原值透传。
static bool DWGIsWhitelistedAdTypeKey(id adTypeKey) {
    if (![adTypeKey isKindOfClass:[NSString class]]) return false;
    NSString *key = (NSString *)adTypeKey;
    return [key isEqualToString:@"ad_setting_drawing"] ||
           [key isEqualToString:@"ad_setting_homeFlow"] ||
           [key isEqualToString:@"ad_setting_homeBanner"] ||
           [key isEqualToString:@"ad_setting_tableScreen"];
}

// hook 1：原 false → false；原 true 且命中白名单 → false；其余原值透传。
static bool DWGIsShowADForAdType(id self, SEL _cmd, id adTypeKey) {
    const bool original = gDWGOriIsShowADForAdType(self, _cmd, adTypeKey);
    if (!original) return false;
    return !DWGIsWhitelistedAdTypeKey(adTypeKey);
}

// hook 2：原实现照常执行（时点与读取不变），随后沿 App 原生“免打扰”分支返回 true。
// 不改时钟 / defaults / 地区 / 会员码 / 账号，不补 completion，不写任何状态。
static bool DWGIsExemptAdUserWithKey(id self, SEL _cmd) {
    (void)gDWGOriIsExemptAdUserWithKey(self, _cmd);
    return true;
}

// hook 3：先取原值，再交给 LocalFunctions.h 提供的本地策略（策略与名单不在本文件，勿在此复制）。
// 不默认 0→1、不伪造任何码。
static int DWGIsKindForGongNeng(id self, SEL _cmd, id functionCode) {
    const int original = gDWGOriIsKindForGongNeng(self, _cmd, functionCode);
    return DWGLocalFunctionResult(functionCode, original);
}

// ---------------------------------------------------------------------------
// 安装器

// 只取定义在 klass 自身（类方法则为其 metaclass 自身）的方法，避免动到继承来的父类实现。
static Method DWGCopyOwnMethod(Class klass, SEL sel) {
    if (klass == Nil) return nullptr;
    unsigned int count = 0;
    Method *list = class_copyMethodList(klass, &count);
    if (list == nullptr) return nullptr;
    Method found = nullptr;
    for (unsigned int i = 0; i < count; ++i) {
        if (method_getName(list[i]) == sel) {
            found = list[i];
            break;
        }
    }
    free(list);
    return found;
}

static bool DWGClassIsInImage(Class klass, NSString *expectedImagePath) {
    if (klass == Nil || expectedImagePath == nil) return false;
    const char *actual = class_getImageName(klass);
    return DWGPathsEqualNormalized(actual, expectedImagePath.fileSystemRepresentation);
}

// 签名/归属全部通过才写入。Fn 为该方法的精确函数指针类型；outOriginal 直接指向调用方的 typed global，
// 保证“原 IMP 写入全局”发生在“发布 replacement”之前——wrapper 一旦可被调用，全局必然已就绪。
template <class Fn>
static DWGHookSlot DWGInstallMethodHook(Class klass, bool isClassMethod, SEL sel,
                                        unsigned int expectedArgumentCount, const char *expectedTypes,
                                        Fn replacement, Fn *outOriginal) {
    Class owner = isClassMethod ? object_getClass((id)klass) : klass;
    Method own = DWGCopyOwnMethod(owner, sel);
    if (own == nullptr) return DWGHookSlotMake(DWGHookStatusSkipped, "not-own-method");
    // runtime argc（含 self/_cmd）与类型编码都要对；任一不符都不写。
    if (method_getNumberOfArguments(own) != expectedArgumentCount) {
        return DWGHookSlotMake(DWGHookStatusSkipped, "type-mismatch");
    }
    if (!DWGTypeEncodingMatches(method_getTypeEncoding(own), expectedTypes)) {
        return DWGHookSlotMake(DWGHookStatusSkipped, "type-mismatch");
    }
    IMP original = method_getImplementation(own);
    if (original == nullptr) return DWGHookSlotMake(DWGHookStatusSkipped, "null-imp");
    *outOriginal = (Fn)original;
    method_setImplementation(own, (IMP)replacement);
    return DWGHookSlotMake(DWGHookStatusInstalled, "ok");
}

// 低层安装：直接给类（不含 image 判定）。测试用这一层；产品入口在下面按 image 解析后复用它。
// 幂等：已安装过的 hook 不再二次包装（标志在任何写入之前检查）。
static DWGAdHookOutcome DWGInstallAdHooksForClasses(Class toolLib, Class appDelegate) {
    DWGAdHookOutcome outcome;
    outcome.isShowADForAdType = DWGHookSlotMake(DWGHookStatusSkipped, "class-missing");
    outcome.isExemptAdUserWithKey = DWGHookSlotMake(DWGHookStatusSkipped, "class-missing");
    outcome.isKindForGongNeng = DWGHookSlotMake(DWGHookStatusSkipped, "class-missing");

    // GSToolLib（两个类方法）
    if (toolLib != Nil) {
        if (gDWGInstalledIsShowADForAdType) {
            outcome.isShowADForAdType = DWGHookSlotMake(DWGHookStatusAlreadyInstalled, "already-installed");
        } else {
            DWGHookSlot slot = DWGInstallMethodHook(toolLib, true, @selector(isShowADForAdType:),
                                                    kDWGArgcIsShowADForAdType, kDWGEncIsShowADForAdType,
                                                    (DWGIsShowADForAdTypeFn)&DWGIsShowADForAdType,
                                                    &gDWGOriIsShowADForAdType);
            if (slot.status == DWGHookStatusInstalled) gDWGInstalledIsShowADForAdType = true;
            outcome.isShowADForAdType = slot;
        }
        if (gDWGInstalledIsExemptAdUserWithKey) {
            outcome.isExemptAdUserWithKey = DWGHookSlotMake(DWGHookStatusAlreadyInstalled, "already-installed");
        } else {
            DWGHookSlot slot = DWGInstallMethodHook(toolLib, true, @selector(isExemptAdUserWithKey),
                                                    kDWGArgcIsExemptAdUserWithKey, kDWGEncIsExemptAdUserWithKey,
                                                    (DWGIsExemptAdUserWithKeyFn)&DWGIsExemptAdUserWithKey,
                                                    &gDWGOriIsExemptAdUserWithKey);
            if (slot.status == DWGHookStatusInstalled) gDWGInstalledIsExemptAdUserWithKey = true;
            outcome.isExemptAdUserWithKey = slot;
        }
    }

    // AppDelegate（实例方法）
    if (appDelegate != Nil) {
        if (gDWGInstalledIsKindForGongNeng) {
            outcome.isKindForGongNeng = DWGHookSlotMake(DWGHookStatusAlreadyInstalled, "already-installed");
        } else {
            DWGHookSlot slot = DWGInstallMethodHook(appDelegate, false, @selector(isKindForGongNeng:),
                                                    kDWGArgcIsKindForGongNeng, kDWGEncIsKindForGongNeng,
                                                    (DWGIsKindForGongNengFn)&DWGIsKindForGongNeng,
                                                    &gDWGOriIsKindForGongNeng);
            if (slot.status == DWGHookStatusInstalled) gDWGInstalledIsKindForGongNeng = true;
            outcome.isKindForGongNeng = slot;
        }
    }

    return outcome;
}

// 产品入口（Tweak.mm 调用）：按名字取实际被选中的类，判 image 归属；
// 同名类若只存在于其它库则直接跳过（reason=image-mismatch），不去别处偷偷找另一个同名类。
static DWGAdHookOutcome DWGInstallAdHooksForImage(NSString *imagePath) {
    if (imagePath == nil || imagePath.length == 0) {
        DWGAdHookOutcome empty;
        empty.isShowADForAdType = DWGHookSlotMake(DWGHookStatusSkipped, "image-path-empty");
        empty.isExemptAdUserWithKey = DWGHookSlotMake(DWGHookStatusSkipped, "image-path-empty");
        empty.isKindForGongNeng = DWGHookSlotMake(DWGHookStatusSkipped, "image-path-empty");
        return empty;
    }

    Class toolLib = (Class)objc_getClass("GSToolLib");
    const char *toolLibReason = "ok";
    if (toolLib == Nil) {
        toolLibReason = "class-missing";
    } else if (!DWGClassIsInImage(toolLib, imagePath)) {
        toolLib = Nil;
        toolLibReason = "image-mismatch";
    }

    Class appDelegate = (Class)objc_getClass("AppDelegate");
    const char *appDelegateReason = "ok";
    if (appDelegate == Nil) {
        appDelegateReason = "class-missing";
    } else if (!DWGClassIsInImage(appDelegate, imagePath)) {
        appDelegate = Nil;
        appDelegateReason = "image-mismatch";
    }

    DWGAdHookOutcome outcome = DWGInstallAdHooksForClasses(toolLib, appDelegate);
    if (toolLib == Nil) {
        outcome.isShowADForAdType = DWGHookSlotMake(DWGHookStatusSkipped, toolLibReason);
        outcome.isExemptAdUserWithKey = DWGHookSlotMake(DWGHookStatusSkipped, toolLibReason);
    }
    if (appDelegate == Nil) {
        outcome.isKindForGongNeng = DWGHookSlotMake(DWGHookStatusSkipped, appDelegateReason);
    }
    return outcome;
}
