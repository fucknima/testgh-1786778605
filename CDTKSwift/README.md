# CDTK Swift — CoreDevice 原生 iPhone 工具箱

这是一个使用 **SwiftUI + Network.framework + CryptoKit + Keychain** 编写的原生 iOS App 工程。没有 Python、Node.js、shell 执行器、WebView 控制台或本地 HTTP 服务。

> 版本：**0.1.0 native preview（协议探针）**。本仓库当前只完成 CoreDevice 配对验证与隧道握手路径，不包含可正常工作的安装/卸载 IPA、应用沙盒或系统日志直接读取。未经目标设备实测的协议行为不能保证可用。

## 已实现（源码）

- SwiftUI 深色/浅色自动适配、系统原生导航、状态卡、详细执行日志。
- Remote Pairing `plist` 导入并验证 `identifier/private_key/public_key`，Keychain 本机加密保存和删除。
- Surge 回环服务 TCP 探测，带连接超时及可见错误说明。
- Swift 原生实现 `RPPairing` 二进制帧、TLV8、X25519 Pair-Verify、Ed25519 签名、HKDF-SHA512、ChaCha20-Poly1305。
- `createListener` 加密请求，Network.framework TLS-PSK 客户端，`CDTunnel` JSON 握手和隧道参数检查（**需要真机实测**）。
- 使用 iOS 公开 API 查看系统版本、电量、内存及存储量；并且离线导入解析 `.ips` 文件。

## 未完成（不提供虚假的按钮）

- Swift 用户态 IPv6/TCP 栈：将 `CDTunnel` 中转后的原始 IPv6 流复用为应用内 TCP 流（无 root、无 utun）。
- RemoteXPC / HTTP2 / RSD 发现、Lockdown 及各服务消息模型。
- installation_proxy / appservice / AFC / house_arrest / MCInstall / WebInspector / SpringBoard 的真实执行适配。
- iOS 最新版本真机、签名工具及 Surge 兼容性回归测试。

## 编译

需要 **macOS、Xcode 16 或更新、XcodeGen**。在工程目录运行：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project CDTKSwift.xcodeproj -scheme CDTKSwift -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

在 GitHub 仓库 `main` 分支推送后，`Actions` 的 **Build iOS IPA** 会构建并上传 `CDTKSwift-unsigned.ipa`（未签名，需用你自己的证书/签名工具签名）。

## 使用说明

1. 在 iPhone 设置里启用开发者模式，准备好 Remote Pairing 格式的设备配对文件（不是普通 Lockdown 的 `HostID` 文件）。
2. Surge 按官方文档配置 `[IP Rewrite] 10.7.0.1 = reflect` 及 `tun-included-routes = 10.7.0.1/32`。确保该网络配置允许本机回环的系统服务。
3. 在「连接」页导入配对 plist，再按「检测端口」；成功后点击「验证配对与隧道」。
4. 如果 TLS-PSK 不兼容，App 会显示失败的阶段和错误，而不会谎报 RSD 服务已经连接。

**安全**：配对 plist 私钥等价于设备信任凭据，不得公开到 GitHub、云盘或日志。应用没有配置额外系统权限、没有尝试绕过官方签名沙盒规则。不要将测试版当作可直接签名安装或更改系统设置的工具。

## 致谢

核心协议设计参考 [OpenMinis/MinisSkills — coredevice-toolkit](https://github.com/OpenMinis/MinisSkills/tree/main/coredevice-toolkit)，本工程 Swift 代码重新实现，没有复制原来的 Python/Node 可执行代码。
