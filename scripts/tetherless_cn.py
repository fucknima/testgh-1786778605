#!/usr/bin/env python3
"""Resource-only Simplified Chinese localization for original Tetherless IPA.
Modifies app resources and Info.plist, not the executable; re-sign before install.
"""
import argparse, hashlib, plistlib, re, zipfile
from pathlib import Path

DATA = '''Library|应用库
Sign|签名
Decrypt|解密
Pair|配对
Files|文件
Settings|设置
Home|首页
Apps|应用
About|关于
Help|帮助
More|更多
Tools|工具
General|通用
Account|账户
Accounts|账户
Appearance|外观
Activity|活动记录
History|历史记录
Downloads|下载
Unsigned|未签名
Signed|已签名
Installed|已安装
Not Installed|未安装
Signing|正在签名
Installing|正在安装
Downloading|正在下载
Decrypting|正在解密
Processing|正在处理
Ready|就绪
Success|成功
Failed|失败
Error|错误
Warning|警告
Connected|已连接
Disconnected|已断开
Connecting|正在连接
Not Connected|未连接
Paired|已配对
Not Paired|未配对
Expired|已过期
Valid|有效
Invalid|无效
Completed|已完成
Complete|完成
Pending|等待中
Active|已启用
Inactive|未启用
None|无
Unknown|未知
Loading...|正在加载…
Please wait...|请稍候…
OK|确定
Ok|确定
Cancel|取消
Done|完成
Close|关闭
Continue|继续
Back|返回
Next|下一步
Previous|上一步
Save|保存
Apply|应用
Edit|编辑
Delete|删除
Remove|移除
Clear|清除
Reset|重置
Retry|重试
Refresh|刷新
Reload|重新加载
Update|更新
Check|检查
Start|开始
Stop|停止
Pause|暂停
Resume|继续
Open|打开
Import|导入
Export|导出
Share|分享
Copy|复制
Paste|粘贴
Move|移动
Rename|重命名
Duplicate|创建副本
Browse|浏览
Choose|选择
Select|选择
Select All|全选
Deselect All|取消全选
Search|搜索
Filter|筛选
Sort|排序
Add|添加
Add App|添加应用
Add File|添加文件
Confirm|确认
Yes|是
No|否
Skip|跳过
Details|详细信息
Advanced|高级
Advanced Options|高级选项
Options|选项
Manage|管理
View|查看
Learn More|了解更多
Get Started|开始使用
All|全部
Name|名称
Size|大小
Date|日期
Type|类型
Status|状态
Version|版本
File|文件
Folder|文件夹
New Folder|新建文件夹
No files|没有文件
No apps|没有应用
No results|没有结果
Empty|空
Sign App|签名应用
Sign IPA|签名 IPA
Sign & Install|签名并安装
Sign and Install|签名并安装
Sign Now|立即签名
Install|安装
Install Now|立即安装
Resign|重新签名
Re-sign|重新签名
Resign App|重新签名应用
Export Unsigned IPA|导出未签名 IPA
Export Signed IPA|导出已签名 IPA
Unsigned IPA|未签名 IPA
Signed IPA|已签名 IPA
Installation|安装
Signing Options|签名选项
Signing Method|签名方式
Signing Mode|签名模式
Free Apple ID|免费 Apple 账户
Apple ID|Apple 账户
Apple Account|Apple 账户
Custom Certificate|自定义证书
Certificate|证书
Certificates|证书
Select Certificate|选择证书
Import Certificate|导入证书
Certificate Password|证书密码
Password|密码
Passphrase|密码短语
Provisioning Profile|描述文件
Provisioning|配置描述文件
Mobile Provision|描述文件
Bundle ID|软件包标识符
Bundle Identifier|软件包标识符
App Name|应用名称
Application|应用
App Icon|应用图标
Minimum iOS Version|最低 iOS 版本
Entitlements|授权权限
Team ID|团队 ID
Device|设备
Devices|设备
UDID|设备标识符
Valid Until|有效期至
Expires|到期时间
Expiration|到期时间
Days Remaining|剩余天数
Tweak Injection|插件注入
Inject Tweaks|注入插件
Tweak|插件
Tweaks|插件
Add Tweak|添加插件
Import Tweak|导入插件
Select IPA|选择 IPA
Import IPA|导入 IPA
Choose IPA|选择 IPA
Open IPA|打开 IPA
Choose File|选择文件
Select File|选择文件
Select Files|选择文件
Import File|导入文件
Export IPA|导出 IPA
IPA File|IPA 文件
Install App|安装应用
App Installed|应用已安装
Installation Failed|安装失败
Signing Failed|签名失败
Signing Complete|签名完成
Installation Complete|安装完成
Ready to Install|可以安装
No certificate selected|尚未选择证书
Import a certificate|导入证书
Use Custom Certificate|使用自定义证书
Use Apple ID|使用 Apple 账户
Pair Device|配对设备
Pairing|配对
Pairing File|配对文件
Import Pairing File|导入配对文件
Start Pairing|开始配对
Pair with…|与设备配对…
Pair with...|与设备配对…
Pairing Code|配对码
Pairing Status|配对状态
Connection Status|连接状态
Connect|连接
Disconnect|断开连接
VPN|VPN
Enable VPN|启用 VPN
LocalDevVPN|LocalDevVPN
Wi-Fi|无线局域网
Waiting for connection|正在等待连接
Pairing successful|配对成功
Pairing failed|配对失败
Import Pairing|导入配对信息
Developer Mode|开发者模式
Device Pairing|设备配对
Decrypt App|解密应用
Decrypt IPA|解密 IPA
Decrypted|已解密
App Store|App Store
Download App|下载应用
Search Apps|搜索应用
Download and Decrypt|下载并解密
Download & Decrypt|下载并解密
Decrypt Now|立即解密
Download Now|立即下载
Download Complete|下载完成
Download Failed|下载失败
Decryption Failed|解密失败
Decryption Complete|解密完成
Verification Code|验证码
Two-Factor Authentication|双重认证
Sign In|登录
Sign Out|退出登录
Log In|登录
Log Out|退出登录
Username|用户名
Email|电子邮箱
Country|国家或地区
Region|地区
File Manager|文件管理
File Browser|文件浏览器
New Download|新建下载
Download URL|下载地址
Download IPA|下载 IPA
Import from Files|从“文件”导入
Open in Files|在“文件”中打开
Save to Files|存储到“文件”
Share IPA|分享 IPA
Copy Path|复制路径
File Information|文件信息
Storage|存储空间
Documents|文稿
Recent|最近使用
Software Update|软件更新
Check for Updates|检查更新
Check for Update|检查更新
Checking for Updates|正在检查更新
Checking for Updates...|正在检查更新…
Update Available|发现新版本
Up to Date|已是最新版本
You are up to date|当前已是最新版本
Download Update|下载更新
Install Update|安装更新
Current Version|当前版本
Latest Version|最新版本
Automatic Updates|自动更新
Auto Update|自动更新
Language|语言
System|跟随系统
Dark|深色
Light|浅色
Dark Mode|深色模式
Light Mode|浅色模式
System Default|跟随系统
Notifications|通知
Privacy|隐私
Security|安全
Support|支持
Credits|鸣谢
License|许可证
Open Source|开源
Release Notes|更新说明
Send Feedback|发送反馈
Are you sure?|确定要继续吗？
Are you sure you want to delete this file?|确定要删除此文件吗？
This action cannot be undone.|此操作无法撤销。
Something went wrong|发生错误
An error occurred|发生错误
Please try again|请重试
Operation completed successfully|操作成功完成
No internet connection|没有网络连接
Network error|网络错误
Permission denied|没有权限
File not found|找不到文件
Invalid file|文件无效
Invalid certificate|证书无效
No apps found|没有找到应用'''
TRANSLATIONS = dict(line.split('|', 1) for line in DATA.splitlines() if '|' in line)

def make_strings(entries):
    def q(value):
        return '"' + value.replace('\\', '\\\\').replace('"','\\"').replace('\n','\\n').replace('\r','\\r') + '"'
    return ('/* Tetherless 简体中文语言资源 */\n' +
            ''.join(q(k) + ' = ' + q(v) + ';\n' for k,v in sorted(entries.items()))).encode('utf-8')

def patch(src:Path, dst:Path):
    with zipfile.ZipFile(src) as original:
        infolist=original.infolist()
        plist_paths=[i.filename for i in infolist if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist',i.filename)]
        if len(plist_paths)!=1:
            raise RuntimeError('Expected exactly one main iOS app: ' + repr(plist_paths))
        info_path=plist_paths[0]
        root=info_path.rsplit('/',1)[0]+'/'
        info=plistlib.loads(original.read(info_path))
        locs=info.get('CFBundleLocalizations',[])
        if not isinstance(locs,list): locs=[]
        info['CFBundleLocalizations']=list(dict.fromkeys(locs+['zh-Hans']))
        info.setdefault('CFBundleDevelopmentRegion','en')
        replacements={
            info_path:plistlib.dumps(info,fmt=plistlib.FMT_BINARY),
            root+'zh-Hans.lproj/Localizable.strings':make_strings(TRANSLATIONS),
            root+'zh-Hans.lproj/InfoPlist.strings':make_strings({'CFBundleDisplayName':'Tetherless 中文版','CFBundleName':'Tetherless'}),
        }
        with zipfile.ZipFile(dst,'w') as out:
            for member in infolist:
                if member.filename in replacements: continue
                with original.open(member) as reader, out.open(member,'w',force_zip64=True) as writer:
                    while True:
                        block=reader.read(1<<20)
                        if not block: break
                        writer.write(block)
            for name,content in replacements.items():
                out.writestr(name,content,compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(dst) as check:
        assert check.testzip() is None
        assert 'zh-Hans' in plistlib.loads(check.read(info_path))['CFBundleLocalizations']
        binary=check.read(root+info['CFBundleExecutable'])
    matching=sorted(k for k in TRANSLATIONS if k.encode() in binary)
    report=dst.with_suffix('.report.txt')
    report.write_text(
        'Original file: '+src.name+'\nBundle ID: '+str(info.get('CFBundleIdentifier'))+
        '\nVersion: '+str(info.get('CFBundleShortVersionString'))+
        '\nLocalization entries: '+str(len(TRANSLATIONS))+
        '\nEnglish keys detected as raw bytes in main binary: '+str(len(matching))+
        '\nIMPORTANT: This is resource-level localization, NOT confirmed 100% translation. '
        'UI labels dynamically constructed or hardcoded in native code may remain English.\n'
        'Re-sign this IPA with your own certificate before installing.\n\n'+
        '\n'.join(matching)+'\n', encoding='utf-8')
    print('Created',dst,'size',dst.stat().st_size,'bytes, keys matched',len(matching))

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('source',type=Path)
    ap.add_argument('dest',type=Path)
    ap.add_argument('--sha256',default='')
    a=ap.parse_args()
    got=hashlib.sha256(a.source.read_bytes()).hexdigest()
    if a.sha256 and a.sha256.lower()!=got.lower():
        raise RuntimeError('SHA-256 mismatch: '+got)
    patch(a.source,a.dest)
