# D2R Mobile 自动签名兼容修复

本仓库已安装 [自动修复工作流](https://github.com/fucknima/testgh-1786778605/actions/workflows/d2r-auto-signfix.yml)，脚本位于 `scripts/d2r_auto_signfix.py`。

## 工作方式

- 每两小时定时查询 `jiayx/d2r-mobile-build` 的最新 Release；也可在 Actions 页面点击 **Run workflow** 手动检查。
- 比较来源 IPA 的版本及 SHA-256；已经完整处理的同一版本会自动跳过。
- 更新后由 macOS 原生 `codesign` 给 App 和 `Guest.framework` 进行 Ad Hoc 预签名，校验原始 `__TEXT` 代码段、`LC_CODE_SIGNATURE` 和 IPA ZIP 完整性。
- 输出 `D2RMobile-standard-SignFix.ipa`、可用时的 `D2RMobile-ios18-SignFix.ipa`、`SIGNING-REPORT.json` 和 `SHA256SUMS.txt`。
- 任何校验失败都不会生成新 Release。补签名不是正式安装签名：仍须用自己的证书和描述文件重新签名。

## 获取自动修复 IPA

当前仓库是**公开仓库**。由于上游游戏程序涉及专有版权，工作流默认只生成**草稿 Release**，不会把包含游戏代码的修复 IPA 自动公开。仓库所有者可以在 **Releases → Drafts** 查看和下载。

如果改成私有仓库，工作流可以自动发布只有仓库授权成员才能访问的正式 Release。只有确实拥有公开再分发权限时，才可在 **Settings → Secrets and variables → Actions → Variables** 新增 `D2R_ALLOW_PUBLIC_REUPLOAD=true`，将公开发布作为明确的授权选择。

GitHub 定时执行可能延迟；公开仓库长时间无提交活动时，GitHub 可能自动停用定时工作流，可在 Actions 页面重新启用。

外部 18 个 `.data` 游戏资源文件与本工具的签名修复无关，不参与打包。
