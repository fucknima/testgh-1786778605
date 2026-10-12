# Muguet 8.8 简体中文显示翻译动态库

本分支独立于主分支，提供运行时文本翻译补丁，不附带游戏本体。
翻译映射共 270 项，源码 `MuguetCN.c` 使用 Objective-C runtime 对 UIKit 控件文本进行完全匹配转换。
运行时不修改主程序 Mach-O 文件，也不主动修改秘籍分类表、秘籍代码、HUD 数据表。

**限制**：SwiftUI 原生 `Text(verbatim:)`、Metal/游戏内绘制文本等未必经过 UIKit setter。构建成功不等于真机汉化覆盖成功。注入仍需具备 dylib 注入能力的工具对 IPA 添加动态库依赖，之后重新签名。仅把 dylib 复制到 IPA 不会自动加载。

构建：GitHub Actions 推送本分支自动运行，或使用 macOS + Xcode `bash build-macos.sh`。
产物：Workflow run Artifacts → `MuguetCN-arm64-ios-dylib`。
