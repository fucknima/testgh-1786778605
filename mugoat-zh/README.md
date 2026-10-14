# Mugoat 1.1.3 中文补丁 v4

## 实际根因（对照上传的 IPA 和截图）
游戏二级模组界面是 UIKit 的 ModManagerViewController，不是纯 SwiftUI；上一版 v3 构建将 MZH_UI_EXTRAS 设为 0，导致 UIKit 文案拦截未编入二级菜单汉化逻辑，虽然字典中已有全部截图文本。
v4 将其设为 1，并保留原有 SwiftUI LocalizedStringKey / Text 翻译、Localizations.json 资源覆写。针对 UILabel 的 text 和 attributedText 进行 **整条文本严格匹配** 的显示翻译；“Done” 仅在 ModManagerViewController 页面改为“完成”，不修改按钮 target/action。

- 截图中的 5 个模组名称 + 5 段说明 + 底部提示均校验字典覆盖。
- 不修改游戏逻辑、秘籍代码、模组操作、路径、存档、渲染。
- 请务必从原始未注入的 Mugoat.ipa 开始，**只注入** MugoatZH-v4.dylib，重新签名。
- 备用 MugoatZH-ResourceOnly-v4.dylib 仍仅处理 485 条 JSON 资源，供故障定位。
- GitHub 上的编译/冒烟测试不等于真机启动验证。