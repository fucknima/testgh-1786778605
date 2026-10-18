// DWG FastView 5.21.2 — 本机功能码白名单（仅用于唯一那个 function hook 改写返回值）
//
// 用途：hook -[AppDelegate isKindForGongNeng:] 时先取原 IMP 结果 original，再调用本函数决定最终返回值。
// 语义（最小、纯内存）：
//   original != 0                                   → 原样透传（-1 未收录 / 1 限免 / 2 等其他状态一律不变）
//   original == 0 且 code 是 NSString 且在下方白名单  → 1（放行 execution 侧判定）
//   其他（nil / NSNull / NSNumber / 数组 / 字典 / 非白名单 code）→ 原样透传（即 0）
//
// 不做的事：本函数不读写 NSUserDefaults、不碰账号/配额/订阅缓存/收据/时钟、不清 Keychain、不联网、
//          不调用原 IMP（由调用方负责先取 original）、不伪造 completion。
//          注：白名单放行后，App 自己的本地流程可能按其原有行为写本地配置（如 configFile.plist、
//          measureResultList），那是 App 原本的行为，不由本函数写入。
//
// 名单证据（逐 code 的调用点、gate 谓词、success block 实际体）见研究目录 membership/supplement.md
// （本地研究索引，不入本仓库）。本文件只写 code 字符串，不写地址。
#pragma once

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

static inline int DWGLocalFunctionResult(id code, int original) {
    if (original != 0) {
        return original;
    }
    if (![code isKindOfClass:[NSString class]]) {
        return original;
    }

    static NSSet *codes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = [NSSet setWithArray:@[
            // ── 测量/统计：gate = -[AppDelegate functionIsOpenAction:codes:sucessBlock:cancelBlock:]
            //    内 `isKindForGongNeng != 0`；success block 经逐函数边界核实为本地视图/本地状态
            @"mcv_drawing_measure_result",           // 记录与查看结果（OnCommandAction / saveResultButtonAction: / 三个设置页）
            @"mcv_drawing_measure_mark_statistic",   // 结果统计（本地统计视图）
            @"mcv_drawing_measurement_total_length", // 批量测线（本地批量测量视图）

            // ── 原生本地功能入口：同一 gate；后续部分引擎虚调用未穷尽，效果仍需真机核验
            @"mcv_drawing_export_pdf",               // 导出 PDF（success → 本地导出对话框 → 本地导出；PDF 转 CAD 另码不收）
            @"mcv_match_properties",                 // 格式刷（success → 本地绘图视图/批注栏切换）
            @"mcv_drawing_insert_block",             // 插入图块（success → 本地插入路径/比例状态）
            @"mcv_drawing_new_block",                // 新建图块（success → 本地命名弹窗）
            @"mcv_drawing_dimension_settings",       // 标注设置面板（success → 本地 push 设置页）
        ]];
    });
    return [codes containsObject:(NSString *)code] ? 1 : original;
}
