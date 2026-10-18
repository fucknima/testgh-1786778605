// DWG FastView 5.21.2 — DWGLocalFunctionResult 行为测试
// 只用真实 header + Foundation + assert：无测试框架、无 UIKit、无网络/账号/支付构造。
// 本文件不复制判定逻辑，只把"契约"（放行集合/透传/类型边界/精确匹配）写成断言；
// 契约依据见本地研究索引 membership/v2/coverage.md（不入库）。
#include "../LocalFunctions.h"

#include <cassert>
#include <climits>
#include <cstdio>
#include <cstdlib>

static int g_cases = 0;

#define DWG_CHECK(expr)                                                \
    do {                                                               \
        ++g_cases;                                                     \
        if (!(expr)) {                                                 \
            std::printf("FAIL line %d: %s\n", __LINE__, #expr);        \
            std::fflush(stdout);                                       \
            assert(0 && "DWGLocalFunctionResult contract check failed"); \
            std::abort(); /* -DNDEBUG 时 assert 被抹掉，abort 兜底，避免静默通过 */ \
        }                                                              \
    } while (0)

int main() {
    @autoreleasepool {
        // 1) 放行集合契约：原值 0 + 已核本机功能码 → 1（按研究分组，顺序仅用于可读性）
        NSArray<NSString *> *localCodes = @[
            // 测量/统计
            @"mcv_drawing_measure_result",
            @"mcv_drawing_measure_mark_statistic",
            @"mcv_drawing_measurement_total_length",
            // 本地导出
            @"mcv_drawing_export_pdf",
            @"mcv_pdf_export_multipage",
            @"mcv_drawing_export_image",
            // 绘图开关/显示状态
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
            // 编辑/绘图
            @"mcv_drawing_modify_edit_color",
            @"mcv_drawing_modify_edit_linetype",
            @"mcv_drawing_draw_hatch",
            @"mcv_drawing_bookmark",
            @"mcv_drawing_find_replace_text",
            // 测量（本地导出/本地引擎命令）
            @"mcv_drawing_measure_scale",
            @"mcv_drawing_measure_hide_result",
            @"mcv_drawing_measure_continue",
            @"mcv_drawing_measure_mark_export",
            @"mcv_drawing_entity_number",
            // 批注
            @"mcv_drawing_note_find",
            @"mcv_drawing_note_delete",
            @"mcv_drawing_note_edit_text_color",
            @"mcv_drawing_note_edit_text",
            @"mcv_drawing_note_copy",
            @"mcv_drawing_note_edit_color",
            @"mcv_drawing_note_line_weight",
            @"mcv_drawing_note_hide_annotation",
            @"mcv_drawing_note_picture_watermark",
            @"mcv_drawing_draw_text_height",
            // 设置
            @"mcv_drawing_precision_setting",
            @"mcv_drawing_settings_linetype",
            @"mcv_drawing_useful_words",
        ];
        for (NSString *code in localCodes) {
            DWG_CHECK(DWGLocalFunctionResult(code, 0) == 1);
        }
        DWG_CHECK(localCodes.count == 41U);
        // 测试清单自身不得重复（重复项会让"覆盖数"虚高）
        DWG_CHECK([NSSet setWithArray:localCodes].count == localCodes.count);

        // 2) 非 0 原值一律透传（含 -1 未收录、1 限免、2 其他状态、极值）
        const int originals[] = { -1, 1, 2, 3, INT_MIN, INT_MAX };
        for (NSString *code in localCodes) {
            for (int original : originals) {
                DWG_CHECK(DWGLocalFunctionResult(code, original) == original);
            }
        }

        // 3) 未收录 / 云 / 账号 / 购买 / 分享 / 未覆盖候选：原值 0 仍为 0
        NSArray<NSString *> *passthroughCodes = @[
            @"",
            @"mcv_unknown_function",
            @"GSNotShowModelChangeAlertInfo1",       // 非功能码串，原样透传
            @"mcv_drawing_measure_result ",          // 大小写/空白不宽松匹配
            @"MCV_DRAWING_MEASURE_RESULT",
            @"mcv_ad_close",                         // 不能用大过期时间连广告一起放行
            // 云转换 / 云文档 / 分享中转（success 实际体含服务器语义）
            @"mcv_pdf_to_cad",
            @"mcv_service_TArch_Conversion",
            @"dfv_3D_models_format_convert",
            @"dfv_3D_models_documentation",
            @"dfv_3D_models_viewpoint",
            @"dfv_3D_models_libirary_download",
            @"mcv_share_miniapps",
            // 3D 本机查看/测量：未按调用链核完，保持原实现（不按前缀判云，也不放行）
            @"mcv_3D_models_view",
            @"mcv_3D_models_measurement",
            // 未覆盖：混分享会话上下文的保存 / 含发送支路的测量结果导出 / note_video
            @"mcv_file_save_save",
            @"mcv_file_save_save_as",
            @"mcv_drawing_measure_result_export",
            @"mcv_drawing_note_video",
            // 不在执行门槛集合内的其它绘制/编辑码
            @"mcv_drawing_modify_trim",
            @"mcv_drawing_modify_extend",
            @"mcv_drawing_modify_offset",
            @"mcv_drawing_modify_fillet",
            @"mcv_drawing_modify_chamfer",
            @"mcv_drawing_modify_mirror",
            @"mcv_drawing_block_number",
            @"mcv_drawing_dimension_aligned",
        ];
        for (NSString *code in passthroughCodes) {
            DWG_CHECK(DWGLocalFunctionResult(code, 0) == 0);
            DWG_CHECK(DWGLocalFunctionResult(code, -1) == -1);
        }

        // 4) 类型边界：非 NSString 一律透传（原值 0 保持 0，非 0 保持非 0）
        id nonStrings[] = {
            nil,
            [NSNull null],
            @(1),
            @(2.5),
            @[],
            @{},
            @[@""],
            [[NSObject alloc] init],
        };
        for (id value : nonStrings) {
            DWG_CHECK(DWGLocalFunctionResult(value, 0) == 0);
            DWG_CHECK(DWGLocalFunctionResult(value, -1) == -1);
            DWG_CHECK(DWGLocalFunctionResult(value, 7) == 7);
        }

        // 5) 精确匹配：集合内 code 加前缀/后缀/大小写变体都不得命中
        for (NSString *code in localCodes) {
            NSString *prefixed = [@"x" stringByAppendingString:code];
            NSString *suffixed = [code stringByAppendingString:@"2"];
            DWG_CHECK(DWGLocalFunctionResult(prefixed, 0) == 0);
            DWG_CHECK(DWGLocalFunctionResult(suffixed, 0) == 0);
            DWG_CHECK(DWGLocalFunctionResult([code uppercaseString], 0) == 0);
        }

        // 6) NSString 子类按 NSString 处理（isKindOfClass 语义），但 code 文本仍须精确命中
        NSMutableString *mutableHit = [NSMutableString stringWithString:@"mcv_match_properties"];
        NSMutableString *mutableMiss = [NSMutableString stringWithString:@"mcv_match_properties_v2"];
        DWG_CHECK(DWGLocalFunctionResult(mutableHit, 0) == 1);
        DWG_CHECK(DWGLocalFunctionResult(mutableMiss, 0) == 0);
        DWG_CHECK(DWGLocalFunctionResult(mutableHit, -1) == -1);

        // 7) 幂等 / 无状态：重复调用与交错调用结果一致（helper 不写任何全局状态）
        for (NSString *code in localCodes) {
            int first = DWGLocalFunctionResult(code, 0);
            int second = DWGLocalFunctionResult(code, 0);
            DWG_CHECK(first == second && first == 1);
            DWG_CHECK(DWGLocalFunctionResult(code, -1) == -1);  // 中间夹一次透传
            DWG_CHECK(DWGLocalFunctionResult(code, 0) == 1);    // 之后仍能命中
        }

        std::printf("ALL %d CASES PASSED\n", g_cases);
        std::fflush(stdout);
        if (g_cases <= 0) {   // 兜底：不允许"零断言通过"
            std::printf("FAIL: no cases executed\n");
            std::abort();
        }
    }
    return 0;
}
