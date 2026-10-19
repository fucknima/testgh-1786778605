# CDTK Swift 原生 iOS 工具箱

这是 CoreDevice Toolkit 的 **100% Swift / SwiftUI** 版本，原项目仅作协议参考；App 不依赖 Python、Node.js 或 WebView。

## 代码与构建

- 完整 XcodeGen 工程位于 [CDTKSwift](./CDTKSwift/)。
- [GitHub Actions](../../actions/workflows/cdtk-swift.yml) 自动校验源码包，解包、生成双外观图标、构建未签名 IPA。
- 该项目放在独立 `feature/cdtk-swift-native` 分支，不改动原有 d2r-mobile 签名相关文件。
- 首次构建时，工作流会将展开后的 Swift 源码直接提交到同一分支，方便在线浏览和后续维护。

## 当前完成范围

已编写 Swift 原生配对文件读取及 Keychain 保存、TCP 探测、Pair Verify / CDTunnel 握手、离线 .ips 崩溃报告分析和 SwiftUI 操作界面。

**还未验证真机 CoreDevice 协议兼容性。** 完整用户态 TCP、RemoteXPC、安装/卸载、系统日志、沙盒管理尚未完成。不应把 UI 项目或通过构建当作上述功能已实现。

配对文件含有设备信任私钥：**不要提交 .plist、.p12 或签名密码到 GitHub**。

参考：[OpenMinis/MinisSkills coredevice-toolkit](https://github.com/OpenMinis/MinisSkills/tree/main/coredevice-toolkit)。
