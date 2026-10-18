# DWGAdBlock · DWG FastView 5.21.2

独立 dylib：拦截已定位的广告判定，放行白名单内的本机功能；**不等于开通账号会员或云权益**。
本目录与本仓库原有 ESign、D2R、Husk 项目无关，不修改它们。

## 使用范围

- 仅匹配 `com.gstarcad.xian.ocsclient`，版本及 build 均为 `5.21.2`。
- 核对输入：IPA SHA-256 `972b773c5a5d9cd7cc7c1082b1bd18b1faf743939bbf84172919b6a675b91b4e`；
  未加密 arm64 主程序 SHA-256 `02256ad5a014d0576c3edf760b583dbe78e2016ad2184ba9697dcfb78bed32e2`。
- 版本、主程序来源、自有方法或类型签名不符时跳过，不猜测新版本地址。
- 输出 arm64、arm64e 和双架构通用库。库部署目标 iOS 15，**不能降低原 App 的 iOS 18 最低要求**。

## 实现边界

仅替换三处自有方法；每次均先调用原实现一次：

| 判定入口 | 改动 |
|---|---|
| `+[GSToolLib isShowADForAdType:]` | 仅对 `ad_setting_drawing`、`ad_setting_homeFlow`、`ad_setting_homeBanner`、`ad_setting_tableScreen` 四个已核广告槽，将原 true 改为 false；未知类型或 key 透传 |
| `+[GSToolLib isExemptAdUserWithKey]` | 走 App 原生广告免打扰分支，不写免打扰日期或修改系统时钟 |
| `-[AppDelegate isKindForGongNeng:]` | 仅本机功能白名单内原返回 0 改为 1；未知码、云功能及其他原值不变，具体清单见 `LocalFunctions.h` |

不伪造 VIP 等级、到期时间、付款、收据、token 或服务器响应；不改账号数据、免费次数、云容量、文件内容、保存设置或配额。
PDF 转 CAD、天正转换、云端 3D 转换/下载、云协作等不在本机放行范围。账号页仍可显示原等级，部分功能可能仍有 VIP/锁图标。

首版白名单共 **8 项**：记录与查看测量结果、测量结果统计、批量测线、导出 PDF、格式刷入口、插入图块、新建图块、标注设置。
已追到这些入口的原生 success block；部分后续 C++ 引擎虚调用未完全解析，**不能据此保证整条操作链离线、算法执行成功或全部会员功能放行**。
修剪、延伸、偏移、圆角、倒角和统计图形数量等未纳入本版。

广告免打扰原分支会跳过退出广告使用的当前文件路径缓存及部分广告初始化，也会跳过原展示分支删除 `AppSetting` 的操作；插件不补写这些数据。
不直接替换开屏展示函数，不伪造完成回调，不遍历全局 UIView，不拦截全部网络或第三方 SDK。
白名单 helper 自身不写业务数据；放行后的原 App 操作仍会按原流程保存文件或本地配置。

## 安装与回退

从本仓库 **main 分支全绿的 `DWG FastView dylib` 工作流**下载 `DWGAdBlock-5.21.2`，
选择通用 `DWGAdBlock.dylib`（或对应单架构库）注入这一版原 App，保留原 Bundle ID、版本及 build，再完整重签、冷启动。
CI 的 ad-hoc 签名不是可直接安装的 IPA，也不能代替你的重签流程。

安装本库即启用以上两项能力，首版不增加菜单或独立开关；需关闭时移除本库并重签、冷启动。
只注入一份，不叠加同名旧库；**不需要删除 App、清理数据或退出账号**。

## 验证与限制

- 静态已核：四个槽位的 23 个 direct-stub 调用点、免打扰判定的 14 个 direct-stub 调用点，以及所查本机功能调用链。
- 未穷尽：泛化消息发送、函数指针等间接调用及独立 SDK 广告链；不能据此承诺所有广告均已覆盖。
- CI 运行真实产品 header 的 macOS 机制测试，使用 iOS SDK 严格编译并检查双架构、签名；**不运行 DWG App**。
- PR/验证分支不上传产物，只有 main 全部成功后上传库和带 commit/SHA-256 的 `manifest.json`；不上传原 IPA 或账号资料。
- 无 iOS 真机验收：广告实际消失、本机功能操作结果、布局、文件打开/保存及稳定性仍需试装核验，编译或机制测试通过不能替代它们。

试装时先用文件副本检查：冷启动/前台恢复、首页列表、从其他 App 打开 DWG、打开/退出 PDF 与 3D 文件，
再检查白名单内的测量或 PDF 导出，以及正常保存/另存为。未列入白名单的编辑命令不保证放行；
账号购买和恢复购买入口应保持原有行为，云功能继续按服务端权限处理。

本机机制测试需 macOS、Xcode Command Line Tools：

```sh
for source in dwg/tests/local_functions_test.mm dwg/tests/hooks_test.mm; do
  binary="${TMPDIR:-/tmp}/$(basename "$source" .mm)"
  clang++ -std=c++17 -fobjc-arc -fblocks -Wall -Wextra -Werror \
    -framework Foundation "$source" -o "$binary"
  "$binary"
done
```
