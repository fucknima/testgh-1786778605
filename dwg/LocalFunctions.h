// DWG FastView 5.21.2 — 本机功能码放行集合（仅用于唯一那个 function hook 改写返回值）
//
// 用途：hook -[AppDelegate isKindForGongNeng:] 时先取原 IMP 结果 original，再调用本函数决定最终返回值。
// 语义（最小、纯内存）：
//   original != 0                                   → 原样透传（-1 未收录 / 1 限免 / 2 等其他状态一律不变）
//   original == 0 且 code 是 NSString 且精确命中集合 → 1（放行 execution 侧判定）
//   其他（nil / NSNull / NSNumber / 数组 / 字典 / 非集合 code）→ 原样透传（即 0）
//
// 集合来源（逐组、逐 code 的 gate 站点 / success block 实际体证据见本地研究索引
// membership/v2/coverage.md 与 root-cause.md，不入本仓库）：
//   * 只收：success 实际体为本地 UI、本地引擎命令（CMD_* 派发）、本地文件/defaults 的 code；
//   * 不收：success 实际体含服务器语义（云转换/云文档/云容量/分享中转）、购买/试用/收据/配额链路；
//   * 未核：文件保存/另存为（混分享会话上下文）、测量结果"发送"面板、note_video、3D 本机查看/测量
//     等，一律保持原实现；未知 code / 非 NSString / 原值 -1 不提升。
//   * 不以 mcv_* 之类前缀通配，避免把服务端功能误当本机功能。
//
// 不做的事：本函数不读写 NSUserDefaults、不碰账号/配额/订阅缓存/收据/时钟、不清 Keychain、不联网、
//          不调用原 IMP（由调用方负责先取 original）、不伪造 completion。
//          注：放行后 App 自己的本地流程仍按其原有行为写本地配置（如 configFile.plist、
//          measureResultList），那是 App 原本的行为，不由本函数写入。
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
            // ── 测量/统计（首轮已核）
            @"mcv_drawing_measure_result",
            @"mcv_drawing_measure_mark_statistic",
            @"mcv_drawing_measurement_total_length",

            // ── 本地导出（success = 本地导出设置/引擎导出命令）
            @"mcv_drawing_export_pdf",               // CMD_EXPORTPDF / toExport → 本地导出
            @"mcv_pdf_export_multipage",             // CMD_EXPORTPDFPAGES
            @"mcv_drawing_export_image",             // CMD_EXPORTIMAGE（默认限免，兼容服务端置 0）

            // ── 绘图开关/显示状态（success = 本地视图/渲染状态）
            @"mcv_match_properties",
            @"mcv_drawing_insert_block",
            @"mcv_drawing_new_block",
            @"mcv_drawing_dimension_settings",
            @"mcv_drawing_layer_layer_list",
            @"mcv_drawing_layout",
            @"mcv_drawing_color",
            @"mcv_drawing_visual_style_2D",
            @"mcv_drawing_visual_style_3D_wireframe",
            @"mcv_drawing_visual_style_realistic",
            @"mcv_drawing_visual_style_hide",
            @"mcv_drawing_view_regen",

            // ── 编辑/绘图（本地命令或本地选择器）
            @"mcv_drawing_modify_edit_color",
            @"mcv_drawing_modify_edit_linetype",
            @"mcv_drawing_draw_hatch",
            @"mcv_drawing_bookmark",
            @"mcv_drawing_find_replace_text",

            // ── 测量（本地参数/本地导出/本地引擎命令）
            @"mcv_drawing_measure_scale",
            @"mcv_drawing_measure_hide_result",
            @"mcv_drawing_measure_continue",         // CMD_MEASURE 本地参数
            @"mcv_drawing_measure_mark_export",      // 本地 Excel 生成
            @"mcv_drawing_entity_number",            // CMD_COUNTPATTERN

            // ── 批注（本地视图 / 本地引擎命令 / 本地拍摄）
            @"mcv_drawing_note_find",
            @"mcv_drawing_note_delete",
            @"mcv_drawing_note_edit_text_color",
            @"mcv_drawing_note_edit_text",           // CMD_NOTE_TEXTCONTENT
            @"mcv_drawing_note_copy",                // CMD_NOTE_COPY
            @"mcv_drawing_note_edit_color",
            @"mcv_drawing_note_line_weight",
            @"mcv_drawing_note_hide_annotation",
            @"mcv_drawing_note_picture_watermark",
            @"mcv_drawing_draw_text_height",

            // ── 设置（本地设置页 / 本地常用词列表）
            @"mcv_drawing_precision_setting",
            @"mcv_drawing_settings_linetype",
            @"mcv_drawing_useful_words",
        ]];
    });
    return [codes containsObject:(NSString *)code] ? 1 : original;
}
