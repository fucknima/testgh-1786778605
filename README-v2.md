# GTA V iOS Port 安全修订版 v2
参考源码: https://github.com/kevinerikjs/gta5-ios-port

旧版过度 Hook UIKit, 同时扫描持续刷新的 UITextView 游戏日志。此前 GitHub 编译通过并不能证明注入后能启动。
v2 只 Hook 四个 UIKit 文本显示 setter、只做短文本精确翻译、不拦截 UITextView、
不修改游戏引擎逻辑、不开启正则替换或缓存。

**请严格顺序测试：**
1. 从未修改的原版 IPA 开始，只注入 GTA5ZH-Probe.dylib，然后完整重签名安装。该文件无 Hook、无构造函数。
2. 若第一步能进入游戏，重新从干净 IPA 开始，只注入 GTA5ZH-Safe.dylib 并重签名安装。
3. 不要叠加 v1 和 v2。若探针版也无法进入游戏，则可能是注入方式、LC_LOAD_DYLIB、签名或游戏本体问题。
4. 收集 iOS 崩溃报告的 Exception Type / Termination Reason / Triggered by Thread 与 backtrace 定位真正根因。

本版本为降低风险，某些按钮和动态文案可能暂时保持英文。
GitHub Actions 编译验证不能替代真机启动测试。