// DWG FastView 5.21.2 — DWGLocalFunctionResult 行为测试
// 只用真实 header + Foundation + assert：无测试框架、无 UIKit、无网络/账号/支付构造。
// 本文件不复制判定逻辑，只把"契约"（白名单/透传/类型边界）写成断言；契约依据见
// 本地研究索引 membership/supplement.md；可下载源码的功能范围见 ../README.md。
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
        // 1) 白名单契约：原值 0 + 已证本机功能码 → 1
        NSArray<NSString *> *localCodes = @[
            @"mcv_drawing_measure_result",
            @"mcv_drawing_measure_mark_statistic",
            @"mcv_drawing_measurement_total_length",
            @"mcv_drawing_export_pdf",
            @"mcv_match_properties",
            @"mcv_drawing_insert_block",
            @"mcv_drawing_new_block",
            @"mcv_drawing_dimension_settings",
        ];
        for (NSString *code in localCodes) {
            DWG_CHECK(DWGLocalFunctionResult(code, 0) == 1);
        }
        DWG_CHECK(localCodes.count == 8U);

        // 2) 非 0 原值一律透传（含 -1 未收录、1 限免、2 其他状态、极值）
        const int originals[] = { -1, 1, 2, 3, INT_MIN, INT_MAX };
        for (NSString *code in localCodes) {
            for (int original : originals) {
                DWG_CHECK(DWGLocalFunctionResult(code, original) == original);
            }
        }

        // 3) 未收录 / 云 / 账号 / 购买 / 分享 / 未收候选：原值 0 仍为 0
        NSArray<NSString *> *passthroughCodes = @[
            @"",
            @"mcv_unknown_function",
            @"mcv_drawing_measure_result ",        // 大小写/空白不宽松匹配
            @"MCV_DRAWING_MEASURE_RESULT",
            @"mcv_ad_close",
            @"mcv_pdf_to_cad",
            @"mcv_pdf_export_multipage",
            @"mcv_service_TArch_Conversion",
            @"dfv_3D_models_format_convert",
            @"dfv_3D_models_documentation",
            @"dfv_3D_models_viewpoint",
            @"dfv_3D_models_libirary_download",
            @"mcv_3D_models_view",
            @"mcv_share_miniapps",
            @"mcv_file_save_save",
            @"mcv_file_save_save_as",
            @"mcv_drawing_modify_trim",
            @"mcv_drawing_modify_extend",
            @"mcv_drawing_modify_offset",
            @"mcv_drawing_modify_fillet",
            @"mcv_drawing_modify_chamfer",
            @"mcv_drawing_modify_mirror",
            @"mcv_drawing_block_number",
            @"mcv_drawing_entity_number",        // 第三轮移出：success block 的实际操作是未知虚调用（br x2），未闭合
            @"mcv_drawing_dimension_aligned",
            @"mcv_drawing_measure_result_export",
            @"mcv_drawing_measure_mark_export",
            @"mcv_drawing_note_video",
            @"mcv_drawing_layer_layer_list",
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

        // 5) NSString 子类按 NSString 处理（isKindOfClass 语义），但 code 文本仍须精确命中
        NSMutableString *mutableHit = [NSMutableString stringWithString:@"mcv_match_properties"];
        NSMutableString *mutableMiss = [NSMutableString stringWithString:@"mcv_match_properties_v2"];
        DWG_CHECK(DWGLocalFunctionResult(mutableHit, 0) == 1);
        DWG_CHECK(DWGLocalFunctionResult(mutableMiss, 0) == 0);
        DWG_CHECK(DWGLocalFunctionResult(mutableHit, -1) == -1);

        // 6) 幂等：重复调用结果一致（helper 不写任何全局状态）
        for (NSString *code in localCodes) {
            int first = DWGLocalFunctionResult(code, 0);
            int second = DWGLocalFunctionResult(code, 0);
            DWG_CHECK(first == second && first == 1);
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
