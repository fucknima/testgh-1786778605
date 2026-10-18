// dwg/Preferences.h —— 插件自身偏好（总开关 / 去广告 / 本机会员放行）与无隐私诊断状态
//                    （header-only，与 Hooks.h 相同：由单个产品 TU 使用）
//
// 边界：
//   * 只读写插件私有键（DWGSettings*），不读写宿主账号 / 会员 / 配额 / 收据 / 云缓存等业务键。
//   * 单一事实源：每次调用直接读 NSUserDefaults，不做第二套内存缓存；开关切换即时生效，无需冷启动。
//   * 读取规则：键不存在 → 默认开启（新用户三个开关默认开启）；类型不是 NSNumber → 回退默认开启；
//     已保存的 NO 一律保留，插件不会在升级时重置用户选择。
//   * 组合规则（唯一口径，产品其它地方不得另行解释）：
//       DWGEnabled()            — 总开关
//       DWGAdsEnabled()         = DWGEnabled() && 去广告开关     （总开关关闭时视为关闭）
//       DWGLocalMemberEnabled() = DWGEnabled() && 本机会员开关   （总开关关闭时视为关闭）
//   * 诊断状态：进程内单份 NSMutableDictionary，只记录 hook 简称、guard 结果与数字计数；
//     不记录文件路径、用户名、token、cookie、图纸名称，不联网、不落盘、不扫描账号。
#pragma once

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// ---------------------------------------------------------------------------
// 偏好键（插件私有；不占用宿主任何既有键）

#define DWGSettingsMasterEnabledKey      @"DWGSettingsMasterEnabled"
#define DWGSettingsAdsEnabledKey         @"DWGSettingsAdsEnabled"
#define DWGSettingsLocalMemberEnabledKey @"DWGSettingsLocalMemberEnabled"

// ---------------------------------------------------------------------------
// 读取

// defaults 为 nil / key 为空 / 已存值不是 NSNumber → 默认开启（插件默认行为）。
static inline BOOL DWGPreferenceBool(NSUserDefaults *defaults, NSString *key) {
    if (defaults == nil || key.length == 0) {
        return YES;
    }
    id stored = [defaults objectForKey:key];
    if (![stored isKindOfClass:[NSNumber class]]) {
        return YES;
    }
    return [(NSNumber *)stored boolValue];
}

static inline BOOL DWGEnabledForDefaults(NSUserDefaults *defaults) {
    return DWGPreferenceBool(defaults, DWGSettingsMasterEnabledKey);
}

// 组合规则：总开关关闭时，去广告视为关闭（去广告开关自身保存值保持不变）。
static inline BOOL DWGAdsEnabledForDefaults(NSUserDefaults *defaults) {
    return DWGEnabledForDefaults(defaults) &&
           DWGPreferenceBool(defaults, DWGSettingsAdsEnabledKey);
}

// 组合规则：总开关关闭时，本机会员放行视为关闭（其自身保存值保持不变）。
static inline BOOL DWGLocalMemberEnabledForDefaults(NSUserDefaults *defaults) {
    return DWGEnabledForDefaults(defaults) &&
           DWGPreferenceBool(defaults, DWGSettingsLocalMemberEnabledKey);
}

static inline BOOL DWGEnabled(void) {
    return DWGEnabledForDefaults([NSUserDefaults standardUserDefaults]);
}

static inline BOOL DWGAdsEnabled(void) {
    return DWGAdsEnabledForDefaults([NSUserDefaults standardUserDefaults]);
}

static inline BOOL DWGLocalMemberEnabled(void) {
    return DWGLocalMemberEnabledForDefaults([NSUserDefaults standardUserDefaults]);
}

// ---------------------------------------------------------------------------
// 保存（只写对应键；不删除、不迁移、不写宿主键）

static inline void DWGSetPreferenceBool(NSUserDefaults *defaults, NSString *key, BOOL value) {
    if (defaults == nil || key.length == 0) {
        return;
    }
    [defaults setBool:value forKey:key];
}

static inline void DWGSetMasterEnabled(BOOL value) {
    DWGSetPreferenceBool([NSUserDefaults standardUserDefaults], DWGSettingsMasterEnabledKey, value);
}

static inline void DWGSetAdsEnabled(BOOL value) {
    DWGSetPreferenceBool([NSUserDefaults standardUserDefaults], DWGSettingsAdsEnabledKey, value);
}

static inline void DWGSetLocalMemberEnabled(BOOL value) {
    DWGSetPreferenceBool([NSUserDefaults standardUserDefaults], DWGSettingsLocalMemberEnabledKey, value);
}

// ---------------------------------------------------------------------------
// 诊断状态（供菜单诊断页与分享文本使用）
//
// 主会话接线（唯一写入方）：
//   * 安装结果：  DWGDiagnosticsSetHookState(@"isShowADForAdType", installed, reason)
//                 reason 用短标识（如 "ok" / "type-mismatch" / "class-missing"），不得放路径或用户数据。
//   * 命中计数：  DWGDiagnosticsIncrementHit(@"isShowADForAdType")   // wrapper 每次被调用时一次
//   * 功能码决策（isKindForGongNeng 条目，由 Hooks.h 写入；本文件只读展示）：
//       lastCode         NSString      最近一次精确识别的公开码，或 <未识别功能码>/<非字符串>
//                                      （Hooks.h 不保留任意用户字符串）
//       original         NSNumber int  原实现返回值
//       result           NSNumber int  插件最终返回值
//       changed          NSNumber u64  发生过改值的累积次数（原 0→1 或任何变化才 +1）
//       exportDecisions  NSDictionary  不可变 map，key 仅三个公开导出码
//                                      mcv_drawing_export_pdf / mcv_pdf_export_multipage /
//                                      mcv_drawing_export_image，value 为不可变 @{original, result}；
//                                      Hooks.h 用 copy-on-write 替换，快照浅拷贝安全
//   文本固定展示三个导出码的最近 original→result（未出现显示“未命中”），不扩 ring buffer。
//   未接线的 hook 在诊断文本里显示“未上报”，插件不伪造 installed/hit，也不把决策元组当作 installed=true。

static inline NSString *DWGPluginVersionString(void) {
    return @"DWGAdBlock 5.21.2-2";
}

// 进程内单份状态；@synchronized 保护读写（hook 命中频率低，锁开销可忽略）。
static inline NSMutableDictionary *DWGDiagnosticsStore(void) {
    static NSMutableDictionary *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [NSMutableDictionary dictionary];
    });
    return store;
}

// 清洗外部输入：只保留短、无换行的文本（防止把路径/多行内容带进分享文本）。
static inline NSString *DWGDiagnosticsCleanString(NSString *text, NSUInteger maxLength) {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        return nil;
    }
    NSString *cleaned = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    if (cleaned.length > maxLength) {
        cleaned = [cleaned substringToIndex:maxLength];
    }
    return cleaned;
}

static inline NSMutableDictionary *DWGDiagnosticsEntry(NSString *hook) {
    NSMutableDictionary *entry = DWGDiagnosticsStore()[hook];
    if (entry == nil) {
        entry = [NSMutableDictionary dictionary];
        DWGDiagnosticsStore()[hook] = entry;
    }
    return entry;
}

static inline void DWGDiagnosticsSetHookState(NSString *hook, BOOL installed, NSString *reason) {
    NSString *name = DWGDiagnosticsCleanString(hook, 64);
    if (name == nil) {
        return;
    }
    @synchronized (DWGDiagnosticsStore()) {
        NSMutableDictionary *entry = DWGDiagnosticsEntry(name);
        entry[@"installed"] = @(installed);
        NSString *cleanedReason = DWGDiagnosticsCleanString(reason, 64);
        if (cleanedReason != nil) {
            entry[@"reason"] = cleanedReason;
        }
    }
}

static inline void DWGDiagnosticsIncrementHit(NSString *hook) {
    NSString *name = DWGDiagnosticsCleanString(hook, 64);
    if (name == nil) {
        return;
    }
    @synchronized (DWGDiagnosticsStore()) {
        NSMutableDictionary *entry = DWGDiagnosticsEntry(name);
        entry[@"hits"] = @([entry[@"hits"] integerValue] + 1);
    }
}

// 只读快照（深一层拷贝，调用方拿到后不受后续写入影响）。
static inline NSDictionary *DWGDiagnosticsSnapshot(void) {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    @synchronized (DWGDiagnosticsStore()) {
        for (NSString *hook in DWGDiagnosticsStore()) {
            snapshot[hook] = [DWGDiagnosticsStore()[hook] copy];
        }
    }
    return snapshot;
}

// 单条导出码的展示（固定 3 行之一）：只有不可变 @{original:NSNumber, result:NSNumber} 才显示数值，
// 字段缺失或类型不符时如实标注，不补造 0→1。
static inline NSString *DWGDiagnosticsDescribeExportDecision(NSString *code, NSDictionary *decisions) {
    id decision = decisions[code];
    if ([decision isKindOfClass:[NSDictionary class]]) {
        id original = ((NSDictionary *)decision)[@"original"];
        id result = ((NSDictionary *)decision)[@"result"];
        BOOL hasOriginal = [original isKindOfClass:[NSNumber class]];
        BOOL hasResult = [result isKindOfClass:[NSNumber class]];
        if (hasOriginal && hasResult) {
            return [NSString stringWithFormat:@"  导出 %@：%d→%d\n", code,
                                              [(NSNumber *)original intValue],
                                              [(NSNumber *)result intValue]];
        }
        if (hasOriginal || hasResult) {
            return [NSString stringWithFormat:@"  导出 %@：记录不完整\n", code];
        }
    }
    return [NSString stringWithFormat:@"  导出 %@：未命中\n", code];
}

// 单条 hook 的展示：安装结果、guard 原因、命中次数；
// isKindForGongNeng 另显示最近一次功能码决策与三个公开导出码的最近 original→result。
// 任何字段缺失都如实写“未上报/未命中/记录不完整”，不伪造 0→1，也不把决策元组当作 installed=true。
static inline NSString *DWGDiagnosticsDescribeEntry(NSString *hook, NSDictionary *entry) {
    NSInteger hits = [entry[@"hits"] integerValue];
    id installedValue = entry[@"installed"];
    NSString *reason = DWGDiagnosticsCleanString(entry[@"reason"], 64);
    NSMutableString *line = [NSMutableString string];
    if (installedValue == nil) {
        [line appendFormat:@"- %@：安装结果未上报 命中 %ld 次", hook, (long)hits];
    } else {
        [line appendFormat:@"- %@：%@%@ 命中 %ld 次",
                           hook,
                           [installedValue boolValue] ? @"已安装" : @"未安装",
                           reason.length > 0 ? [NSString stringWithFormat:@" (%@)", reason] : @"",
                           (long)hits];
    }

    id changedValue = entry[@"changed"];
    if ([changedValue isKindOfClass:[NSNumber class]]) {
        [line appendFormat:@" 改值 %llu 次", [(NSNumber *)changedValue unsignedLongLongValue]];
    }

    NSString *lastCode = DWGDiagnosticsCleanString(entry[@"lastCode"], 64);
    id originalValue = entry[@"original"];
    id resultValue = entry[@"result"];
    BOOL hasOriginal = [originalValue isKindOfClass:[NSNumber class]];
    BOOL hasResult = [resultValue isKindOfClass:[NSNumber class]];
    BOOL isFunctionDecisionHook = [hook isEqualToString:@"isKindForGongNeng"];
    if (lastCode.length > 0 && hasOriginal && hasResult) {
        [line appendFormat:@" 最近 code=%@ %d→%d", lastCode,
                           [(NSNumber *)originalValue intValue], [(NSNumber *)resultValue intValue]];
    } else if (lastCode.length > 0) {
        [line appendFormat:@" 最近 code=%@", lastCode];
    } else if (hasOriginal && hasResult) {
        [line appendFormat:@" 最近 %d→%d",
                           [(NSNumber *)originalValue intValue], [(NSNumber *)resultValue intValue]];
    } else if (isFunctionDecisionHook) {
        [line appendString:@" 最近决策：尚未命中"];
    }
    [line appendString:@"\n"];

    if (isFunctionDecisionHook) {
        // 三个公开导出码固定展示；exportDecisions 由 Hooks.h 以不可变 map copy-on-write 替换，
        // 本文件只读取快照里的引用，不原地修改。
        id decisions = entry[@"exportDecisions"];
        NSDictionary *decisionsMap = [decisions isKindOfClass:[NSDictionary class]] ? decisions : nil;
        NSArray<NSString *> *exportCodes = @[@"mcv_drawing_export_pdf",
                                             @"mcv_pdf_export_multipage",
                                             @"mcv_drawing_export_image"];
        for (NSString *code in exportCodes) {
            [line appendString:DWGDiagnosticsDescribeExportDecision(code, decisionsMap)];
        }
    }
    return line;
}

// 分享文本的可测入口：开关状态按传入 defaults 读取（测试用 isolated suite，不写 standard domain）。
static inline NSString *DWGDiagnosticsTextForDefaults(NSUserDefaults *defaults) {
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"DWG FastView 插件诊断（本地生成，无上传）\n"];
    [text appendFormat:@"插件版本：%@\n", DWGPluginVersionString()];

    NSBundle *bundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = bundle.bundleIdentifier;
    id shortVersion = bundle.infoDictionary[@"CFBundleShortVersionString"];
    id buildVersion = bundle.infoDictionary[@"CFBundleVersion"];
    [text appendFormat:@"宿主：%@ %@ (%@)\n",
                       bundleIdentifier.length > 0 ? bundleIdentifier : @"未知",
                       [shortVersion isKindOfClass:[NSString class]] ? shortVersion : @"未知",
                       [buildVersion isKindOfClass:[NSString class]] ? buildVersion : @"未知"];

    [text appendFormat:@"开关：总开关=%@ 去广告=%@ 本机会员=%@\n",
                       DWGEnabledForDefaults(defaults) ? @"开" : @"关",
                       DWGAdsEnabledForDefaults(defaults) ? @"开" : @"关",
                       DWGLocalMemberEnabledForDefaults(defaults) ? @"开" : @"关"];

    // 三个广告/会员 hook 固定出现：已接线的显示真实状态，未接线的明确“未上报”，不伪造。
    NSArray<NSString *> *expectedHooks = @[@"isShowADForAdType",
                                           @"isExemptAdUserWithKey",
                                           @"isKindForGongNeng"];
    NSDictionary *snapshot = DWGDiagnosticsSnapshot();
    [text appendString:@"Hook 状态：\n"];
    for (NSString *hook in expectedHooks) {
        [text appendString:DWGDiagnosticsDescribeEntry(hook, snapshot[hook])];
    }
    for (NSString *hook in [snapshot.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([expectedHooks containsObject:hook]) {
            continue;
        }
        [text appendString:DWGDiagnosticsDescribeEntry(hook, snapshot[hook])];
    }
    return text;
}

static inline NSString *DWGDiagnosticsText(void) {
    return DWGDiagnosticsTextForDefaults([NSUserDefaults standardUserDefaults]);
}
