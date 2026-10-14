# Mugoat 1.1.3 简体中文 dylib（iOS arm64）

对应用户上传的 `Mugoat.ipa`（`PlayGTA5Native`，`vn.iosvn.mugoat`，1.1.3）。

## 原理（严格限制显示层）

- 从 IPA 原有 `Localizations.json`（485 个键，269 条不同英文文本）读取数据，并在**缓存目录**写入仅含简体中文显示值的副本。**不修改原版 JSON、游戏数据、WASM、控制/秘籍/模组执行逻辑**。
- 仅对主包的 `Localizations.json` 资源查询做定向重定向（两个 `NSBundle` 查询方法）。原 IPA 读其他资源的路径保持原样。
- 二级秘籍与模组菜单还有 128 条未收录于原 JSON 的越南语文本。完整模式对 `UILabel.setText:` 施加**仅精确匹配**的显示层翻译；对两个已知动态状态前缀做有限替换。游戏日志、文本输入、触屏事件、画面渲染均不 Hook。
- 用 `mugoat-zh/translations_zh.json` 与 `mugoat-zh/ui_extras_zh.json` 保存翻译，不改字符串键名、指令码、文件路径或格式占位符。

## 文件区别

- `MugoatZH.dylib`：完整模式，485 条资源键 + 128 条额外界面文本。优先使用。
- `MugoatZH-ResourceOnly.dylib`：保守模式，只重定向 485 条资源键，不 Hook UILabel。用于排查启动兼容问题。
- `Mugoat_简体中文待签名.ipa`（如果提供）：直接仅替换原 IPA 的 Localizations.json，未注入 dylib，执行文件与上传版本的 SHA256 不变；必须重新签名才能安装。

**注意：** 上述数字是可辨识的 iOS 应用 UI 文字，不包含 GTA V 引擎直接渲染的剧情字幕、内建任务界面及游戏语言包。GitHub Actions 编译通过不等于真机启动测试通过。

## 安装

将**其中一个** dylib 注入原始 IPA，重新签名安装。动态库必须位于 `Payload/PlayGTA5Native.app/Frameworks/` 下，执行文件须添加正确的依赖 `@executable_path/Frameworks/<文件名>`，切勿同时注入两种版本。不要和先前 GTA5ZH.dylib 混装。

如果注入后无法启动，优先使用保守版或原始 IPA 验证，并检查崩溃日志中的 `dyld`、`Code Signature`、`Termination Reason`。

