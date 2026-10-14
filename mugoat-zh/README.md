# Mugoat 1.1.3 汉化 v3

针对用户上传的 Mugoat.ipa (PlayGTA5Native)。
上一版额外翻译只 Hook UILabel，SwiftUI 的秘籍子菜单和 Mod 管理页面通常不经过 UILabel。

新版本保留原有 Localizations.json 资源替换，同时仅拦截 SwiftUI LocalizedStringKey 的 stringLiteral 初始化和 Text 的 StringProtocol 初始化，将已知显示文案精确替换成中文。没有修改秘籍代码、分类筛选、Mod 管理操作、游戏引擎、文件读写和控制逻辑。

- MugoatZH-v3.dylib：SwiftUI + JSON 完整版。
- MugoatZH-ResourceOnly-v3.dylib：只替换 JSON 的后备诊断版。
- 不可与旧版汉化库同时注入；用干净的 Mugoat.ipa 重签名。
- GitHub Action 的 macOS SwiftUI 冒烟测试和 iOS arm64 构建通过不等于真实设备启动测试通过。
- 该 dylib 处理 iOS 启动器 UI，不修改 GTA V 游戏内部字幕和菜单。