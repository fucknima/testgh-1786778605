// dwg/SettingsMenu.h —— 在原“设置”页内新增一行“插件设置”入口，并提供插件设置页（三个开关）与诊断/分享
//                     （header-only，与 Hooks.h 相同：由单个产品 TU 使用）
//
// ---------------------------------------------------------------------------
// 原布局证据（只读静态核证；目标 GstarCAD 主程序 5.21.2 / SHA-256 02256ad5…bed32e2；分析脚本在
// /tmp/opencode/dwgfastview-5.21.2-research/ui/v2/，本仓库不落研究文件）
//
//   * 类 GSSettingViewController 为宿主主映像自有类；自有 -viewDidLoad 类型编码 v16@0:8（runtime argc 2）。
//   * 界面来自同名 nib（原 IPA：Payload/GstarCAD.app/GSSettingViewController.nib，NIBArchive）：
//       root view 375×1825；标题栏 UIView；其下 ui_scrollView（内容宽 375）。
//   * scrollView 的内容尺寸不由每个行自动撑开，而由两条已核约束 + 一个 1×1 锚点 label 决定：
//       ui_contentTrailingConstraint: scrollView.trailing == 锚点.trailing + (屏宽-1)
//       ui_contentBottomConstraint:   scrollView.bottom  == 锚点.bottom  + 常数
//       （常数 nib 2000 → 运行时 viewDidLoad 先置 1864，中国区再 +99，非中国区再 -0.125）
//   * scrollView 直接子视图顺序（nib 对象表帧序）：1×1 锚点 label → 各设置分组 → 会员诊断
//     (ui_privilegeDiagnosisViIew) → 隐私管理 (ui_privacyManageView) → ui_showDebugSettingView。
//     每条链上 下一组 top = 上一组 bottom + 16。
//   * ui_showDebugSettingView 是链尾占位视图：无子视图、无自身约束；top 由
//     ui_showDebugSettingViewTopConstraint（== ui_privacyManageView.bottom + c）决定，bottom 即内容底部，
//     高度弹性（用于 10 次点击的隐藏调试入口，见 viewDidLoad 原体）。
//   * 生命周期核验（按 LC_FUNCTION_STARTS 导出原体逐行核对）：
//       - viewDidLoad   ：设置 titleView 高度、contentBottom 常数（含地区分支）、showDebug top 常数、contentTrailing；
//       - viewWillLayoutSubviews（0x100940560，全文 90 行）：只 setConstant 到 ui_contentTrailingConstraint，
//         不出现 ui_contentBottomConstraint / ui_showDebugSettingViewTopConstraint；
//       - viewDidAppear:（0x1009403dc）：只设置手势识别器点击数，不碰约束；
//       - statusBarOrientationChange:（0x100940798）：只改 ui_titleViewHeightConstraint 与 ui_contentTrailingConstraint。
//       因此入口行插入放在 viewDidLoad 原实现之后执行一次：不 hook 任何 layout 回调，
//       contentBottom 常数只加一次、不会随 layout 累加，也不会被 layout 覆盖。
//
// ---------------------------------------------------------------------------
// 插入策略（最窄改动；不动任何既有功能行的位置、约束或可见性）
//
//   * 在 ui_privacyManageView 与 ui_showDebugSettingView 之间插入一行专用 UIButton（“插件设置”）。
//   * 新增的约束只针对这一行与已核原容器：
//       row.leading  == scrollView.leading   row.trailing == scrollView.trailing（内容全宽）
//       row.top      == ui_privacyManageView.bottom + 16（与其它行间距一致）
//       row.height   == 50（与链尾视图的 nib 设计高度一致）
//   * 链尾 ui_showDebugSettingView 的 top 约束改为 == row.bottom + 原常数，10 次点击手势区完整保留；
//   * ui_contentBottomConstraint.constant += (16 + 50) 仅一次，为多出的行扩容；
//     即使该常数将来被别处重设为固定值，新行仍位于链尾弹性区之上、内容区之内，只是可滚动留白减少。
//   * 幂等：按专用视图类（DWGMenuPluginSettingsRowButton）在 scrollView 子视图中查找，重复调用不插第二行；
//     不使用“tag 撞名即成功”的判定。
//   * 运行时先复核类 / 自有方法 / 类型编码 / 视图结构（superview、帧序、原约束 active）再动手，
//     任一不符即放弃，不改动宿主任何既有行。
//
// ---------------------------------------------------------------------------
// 接线（主会话在 Tweak.mm 内，与三处广告 hook 并列；本文件不修改 Tweak/Hooks/LocalFunctions）：
//
//   #import "SettingsMenu.h"      // 本文件已 include Hooks.h 与 Preferences.h
//   DWGSettingsEntryOutcome outcome = DWGInstallSettingsEntry(bundle.executablePath);
//   NSLog(@"[DWG-settings] %s (reason=%s)",
//         outcome.status == DWGSettingsEntryStatusSkipped ? "skipped" : "installed", outcome.reason);
//
//   三个开关的读取方（Preferences.h，单一事实源）：
//     去广告两处 wrapper 用 DWGAdsEnabled()；本机功能 wrapper 用 DWGLocalMemberEnabled()；
//     安装结果 / 命中计数用 DWGDiagnosticsSetHookState / DWGDiagnosticsIncrementHit 上报。
#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>

#import "Preferences.h"
// 复用 Hooks.h 的 DWGTypeEncodingMatches / DWGPathsEqualNormalized / DWGCopyOwnMethod / DWGClassIsInImage，
// 不复制第二套。包含方向固定为 SettingsMenu.h → Hooks.h；Hooks.h 只依赖 Preferences.h，不回指本文件。
#import "Hooks.h"

// ---------------------------------------------------------------------------
// 已核目标签名（静态已核，勿改；runtime argc 已含 self/_cmd）

static const char *const kDWGMenuEncSettingsViewDidLoad = "v16@0:8";
static const unsigned int kDWGMenuArgcSettingsViewDidLoad = 2;

// 新增行常量（专用 tag 仅作辅助；幂等主判据是下面的专用视图类）
static const NSInteger kDWGMenuPluginSettingsRowTag = 0x44575052; // "DWPR"
static const CGFloat kDWGMenuPluginSettingsRowHeight = 50.0;
static const CGFloat kDWGMenuPluginSettingsRowSpacing = 16.0;

// ---------------------------------------------------------------------------
// 只声明已核 getter 的签名并统一类型（编译期用）；本文件不实现、不改写这些方法，
// 运行时一律先 respondsToSelector + 结果类型检查再调用，任何不符即放弃插入。

@interface NSObject (DWGSettingsViewControllerOutlets)
- (UIScrollView *)ui_scrollView;
- (UIView *)ui_privacyManageView;
- (UIView *)ui_showDebugSettingView;
- (NSLayoutConstraint *)ui_showDebugSettingViewTopConstraint;
- (NSLayoutConstraint *)ui_contentBottomConstraint;
@end

// ---------------------------------------------------------------------------
// 安装结果

typedef enum {
    DWGSettingsEntryStatusSkipped = 0,          // 未安装（原因见 reason）
    DWGSettingsEntryStatusInstalled = 1,        // 本次安装成功
    DWGSettingsEntryStatusAlreadyInstalled = 2, // 之前已安装，本次未改动（幂等）
} DWGSettingsEntryStatus;

typedef struct {
    DWGSettingsEntryStatus status;
    const char *reason; // 短标识，可安全写入诊断（无路径、无用户数据）
} DWGSettingsEntryOutcome;

static inline DWGSettingsEntryOutcome DWGMenuOutcomeMake(DWGSettingsEntryStatus status, const char *reason) {
    DWGSettingsEntryOutcome outcome;
    outcome.status = status;
    outcome.reason = reason;
    return outcome;
}

// ---------------------------------------------------------------------------
// 入口行专用按钮类（幂等判据；无额外行为）

@interface DWGMenuPluginSettingsRowButton : UIButton
@end

@implementation DWGMenuPluginSettingsRowButton
@end

// ---------------------------------------------------------------------------
// 插件设置页（模态；iPad 用 popover；返回只 dismiss 自己，不触碰原设置页与 CAD 状态）

@interface DWGDiagnosticsTextViewController : UIViewController
@end

// 私有方法声明（避免调用点早于定义时出现 -Wundeclared-selector / 返回类型告警）。
@interface DWGDiagnosticsTextViewController ()
- (void)dwg_done;
@end

@implementation DWGDiagnosticsTextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"诊断状态";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    textView.editable = NO;
    textView.alwaysBounceVertical = YES;
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    textView.adjustsFontForContentSizeCategory = YES;
    textView.text = DWGDiagnosticsText();
    [self.view addSubview:textView];

    [NSLayoutConstraint activateConstraints:@[
        [textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(dwg_done)];
}

- (void)dwg_done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface DWGPluginSettingsViewController : UITableViewController
@end

// 私有方法声明（同上；也保证 @selector 在解析时可见）。
@interface DWGPluginSettingsViewController ()
- (void)dwg_done;
- (void)dwg_toggleChanged:(UISwitch *)toggle;
- (void)dwg_presentDiagnosticsFromCell:(UITableViewCell *)cell;
- (void)dwg_shareDiagnosticsFromCell:(UITableViewCell *)cell;
@end

static const NSInteger kDWGMenuSwitchTagBase = 4400;

typedef NS_ENUM(NSInteger, DWGPluginSettingsSwitchRow) {
    DWGPluginSettingsSwitchRowMaster = 0,
    DWGPluginSettingsSwitchRowAds = 1,
    DWGPluginSettingsSwitchRowLocalMember = 2,
};

typedef NS_ENUM(NSInteger, DWGPluginSettingsDiagnosticsRow) {
    DWGPluginSettingsDiagnosticsRowView = 0,
    DWGPluginSettingsDiagnosticsRowShare = 1,
};

@implementation DWGPluginSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"插件设置";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 48.0;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(dwg_done)];
}

- (void)dwg_done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? 3 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"插件开关" : @"诊断";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) {
        return @"开关即时生效（无需重启）：每次功能判定都会读取这里的选择。仅改变插件本地行为，"
               @"不代表账号 VIP，也不影响订阅、收据或云端权益。";
    }
    return @"诊断信息只含 hook 名称、安装结果与调用次数，不含文件路径、账号、图纸内容；"
           @"分享使用系统面板，不会自动上传。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const switchCellIdentifier = @"DWGPluginSwitchCell";
    static NSString *const textCellIdentifier = @"DWGPluginTextCell";

    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                         reuseIdentifier:switchCellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
            [toggle addTarget:self action:@selector(dwg_toggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
        }
        UISwitch *toggle = (UISwitch *)cell.accessoryView;
        toggle.tag = kDWGMenuSwitchTagBase + indexPath.row;
        UIListContentConfiguration *content = [cell defaultContentConfiguration];
        switch (indexPath.row) {
            case DWGPluginSettingsSwitchRowMaster:
                content.text = @"启用插件";
                toggle.on = DWGEnabled();
                toggle.enabled = YES;
                break;
            case DWGPluginSettingsSwitchRowAds:
                content.text = @"去除广告";
                toggle.on = DWGAdsEnabled();
                toggle.enabled = DWGEnabled();
                break;
            case DWGPluginSettingsSwitchRowLocalMember:
                content.text = @"本机会员功能放行";
                toggle.on = DWGLocalMemberEnabled();
                toggle.enabled = DWGEnabled();
                break;
            default:
                break;
        }
        toggle.accessibilityLabel = content.text;
        cell.contentConfiguration = content;
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:textCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:textCellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = indexPath.row == DWGPluginSettingsDiagnosticsRowView ? @"查看诊断状态" : @"分享诊断信息";
    cell.contentConfiguration = content;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) {
        return;
    }
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (indexPath.row == DWGPluginSettingsDiagnosticsRowView) {
        [self dwg_presentDiagnosticsFromCell:cell];
    } else {
        [self dwg_shareDiagnosticsFromCell:cell];
    }
}

// 开关写入偏好（Preferences.h 单一事实源）；随后刷新从属开关的可用状态与显示值。
- (void)dwg_toggleChanged:(UISwitch *)toggle {
    switch (toggle.tag - kDWGMenuSwitchTagBase) {
        case DWGPluginSettingsSwitchRowMaster:
            DWGSetMasterEnabled(toggle.isOn);
            break;
        case DWGPluginSettingsSwitchRowAds:
            DWGSetAdsEnabled(toggle.isOn);
            break;
        case DWGPluginSettingsSwitchRowLocalMember:
            DWGSetLocalMemberEnabled(toggle.isOn);
            break;
        default:
            return;
    }
    [self.tableView reloadData];
}

- (void)dwg_presentDiagnosticsFromCell:(UITableViewCell *)cell {
    if (self.presentedViewController != nil) return;
    DWGDiagnosticsTextViewController *controller = [[DWGDiagnosticsTextViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && cell != nil) {
        navigation.modalPresentationStyle = UIModalPresentationPopover;
        navigation.popoverPresentationController.sourceView = cell;
        navigation.popoverPresentationController.sourceRect = cell.bounds;
        navigation.preferredContentSize = CGSizeMake(380.0, 460.0);
    }
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)dwg_shareDiagnosticsFromCell:(UITableViewCell *)cell {
    if (self.presentedViewController != nil) return;
    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[DWGDiagnosticsText()] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIView *anchor = cell != nil ? cell : self.view;
        activity.popoverPresentationController.sourceView = anchor;
        activity.popoverPresentationController.sourceRect = anchor.bounds;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

@end

// ---------------------------------------------------------------------------
// 入口行的点击目标（按钮 target 用本单例，不给宿主类添加方法）

// 从视图沿响应链找承载它的 view controller（不假设导航控制器，不碰 navigationItem）。
static UIViewController *DWGSettingsHostViewController(UIView *view) {
    UIResponder *responder = view;
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

@interface DWGPluginSettingsPresenter : NSObject
- (void)dwg_openFromRow:(UIButton *)row;
@end

@implementation DWGPluginSettingsPresenter

- (void)dwg_openFromRow:(UIButton *)row {
    UIViewController *host = DWGSettingsHostViewController(row);
    if (host == nil || host.presentedViewController != nil) {
        return;
    }
    DWGPluginSettingsViewController *settings = [[DWGPluginSettingsViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        navigation.modalPresentationStyle = UIModalPresentationPopover;
        navigation.popoverPresentationController.sourceView = row;
        navigation.popoverPresentationController.sourceRect = row.bounds;
        navigation.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
        navigation.preferredContentSize = CGSizeMake(380.0, 460.0);
    }
    [host presentViewController:navigation animated:YES completion:nil];
}

@end

static DWGPluginSettingsPresenter *DWGSettingsPresenterShared(void) {
    static DWGPluginSettingsPresenter *presenter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        presenter = [[DWGPluginSettingsPresenter alloc] init];
    });
    return presenter;
}

// ---------------------------------------------------------------------------
// 入口行插入（在 viewDidLoad 原实现之后调用；自身幂等，结构不符则不动宿主）

// 入口行的真实结果上报（诊断页与分享文本据此显示；未跑到的路径不会写入，保持“未上报”）。
// 只写 hook 简称 + 短 guard 结果，无路径、无用户数据。
static void DWGSettingsReportRowState(BOOL attached, NSString *reason) {
    DWGDiagnosticsSetHookState(@"settingsEntryRow", attached, reason);
}

static void DWGSettingsAttachRow(id self) {
    if (self == nil) {
        return;
    }
    if (![self respondsToSelector:@selector(ui_scrollView)] ||
        ![self respondsToSelector:@selector(ui_privacyManageView)] ||
        ![self respondsToSelector:@selector(ui_showDebugSettingView)] ||
        ![self respondsToSelector:@selector(ui_showDebugSettingViewTopConstraint)] ||
        ![self respondsToSelector:@selector(ui_contentBottomConstraint)]) {
        DWGSettingsReportRowState(NO, @"outlet-missing");
        return;
    }

    UIScrollView *scrollView = [self ui_scrollView];
    UIView *privacyView = [self ui_privacyManageView];
    UIView *debugView = [self ui_showDebugSettingView];
    NSLayoutConstraint *debugTopConstraint = [self ui_showDebugSettingViewTopConstraint];
    NSLayoutConstraint *contentBottomConstraint = [self ui_contentBottomConstraint];
    if (![scrollView isKindOfClass:[UIScrollView class]] ||
        ![privacyView isKindOfClass:[UIView class]] ||
        ![debugView isKindOfClass:[UIView class]] ||
        ![debugTopConstraint isKindOfClass:[NSLayoutConstraint class]] ||
        ![contentBottomConstraint isKindOfClass:[NSLayoutConstraint class]]) {
        DWGSettingsReportRowState(NO, @"outlet-type-mismatch");
        return;
    }

    // 已核结构复核：两个锚点视图都是 scrollView 直接子视图，privacy 在 debug 之前（nib 帧序），原约束仍生效。
    if (privacyView.superview != scrollView || debugView.superview != scrollView) {
        DWGSettingsReportRowState(NO, @"structure-mismatch");
        return;
    }
    NSUInteger privacyIndex = [scrollView.subviews indexOfObjectIdenticalTo:privacyView];
    NSUInteger debugIndex = [scrollView.subviews indexOfObjectIdenticalTo:debugView];
    if (privacyIndex == NSNotFound || debugIndex == NSNotFound || privacyIndex >= debugIndex) {
        DWGSettingsReportRowState(NO, @"structure-mismatch");
        return;
    }
    // 已插入后原 debugTopConstraint 已被停用，因此必须先做幂等判断。
    for (UIView *subview in scrollView.subviews) {
        if ([subview isKindOfClass:[DWGMenuPluginSettingsRowButton class]]) {
            DWGSettingsReportRowState(YES, @"attached");
            return;
        }
    }
    if (!debugTopConstraint.isActive || !contentBottomConstraint.isActive) {
        DWGSettingsReportRowState(NO, @"anchor-constraint-inactive");
        return;
    }
    if (debugTopConstraint.firstItem != debugView ||
        debugTopConstraint.firstAttribute != NSLayoutAttributeTop ||
        debugTopConstraint.secondItem != privacyView ||
        debugTopConstraint.secondAttribute != NSLayoutAttributeBottom ||
        debugTopConstraint.relation != NSLayoutRelationEqual || debugTopConstraint.multiplier != 1.0 ||
        contentBottomConstraint.firstItem != scrollView ||
        contentBottomConstraint.firstAttribute != NSLayoutAttributeBottom ||
        contentBottomConstraint.secondAttribute != NSLayoutAttributeBottom ||
        contentBottomConstraint.relation != NSLayoutRelationEqual || contentBottomConstraint.multiplier != 1.0) {
        DWGSettingsReportRowState(NO, @"structure-mismatch");
        return;
    }

    DWGMenuPluginSettingsRowButton *row = [[DWGMenuPluginSettingsRowButton alloc] initWithFrame:CGRectZero];
    row.tag = kDWGMenuPluginSettingsRowTag;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.attributedTitle =
        [[NSAttributedString alloc] initWithString:@"插件设置"
                                        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16.0]}];
    configuration.baseForegroundColor = [UIColor labelColor];
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.contentInsets =
        NSDirectionalEdgeInsetsMake(0, kDWGMenuPluginSettingsRowSpacing, 0, kDWGMenuPluginSettingsRowSpacing);
    row.configuration = configuration;
    row.accessibilityLabel = @"插件设置";
    [row addTarget:DWGSettingsPresenterShared()
            action:@selector(dwg_openFromRow:)
  forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:row];

    // 链尾视图 top 约束由“privacy.bottom + c”改接到“row.bottom + c”，原常数保留。
    const CGFloat previousDebugTopConstant = debugTopConstraint.constant;
    debugTopConstraint.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        [NSLayoutConstraint constraintWithItem:row
                                     attribute:NSLayoutAttributeLeading
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:scrollView
                                     attribute:NSLayoutAttributeLeading
                                    multiplier:1.0
                                      constant:0.0],
        [NSLayoutConstraint constraintWithItem:scrollView
                                     attribute:NSLayoutAttributeTrailing
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:row
                                     attribute:NSLayoutAttributeTrailing
                                    multiplier:1.0
                                      constant:0.0],
        [NSLayoutConstraint constraintWithItem:row
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:privacyView
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0
                                      constant:kDWGMenuPluginSettingsRowSpacing],
        [NSLayoutConstraint constraintWithItem:row
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1.0
                                      constant:kDWGMenuPluginSettingsRowHeight],
        [NSLayoutConstraint constraintWithItem:debugView
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:row
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0
                                      constant:previousDebugTopConstant],
    ]];

    // 内容高度只加一次（不 hook layout；viewWillLayoutSubviews 只改 contentTrailing，不会覆盖此值）。
    contentBottomConstraint.constant += kDWGMenuPluginSettingsRowHeight + kDWGMenuPluginSettingsRowSpacing;

    DWGSettingsReportRowState(YES, @"attached");
}

// ---------------------------------------------------------------------------
// typed original（原 IMP 先写入全局，再发布 replacement；wrapper 一旦可被调用即已就绪）
typedef void (*DWGSettingsViewDidLoadFn)(id self, SEL _cmd);

static DWGSettingsViewDidLoadFn gDWGOriSettingsViewDidLoad = nullptr;
static bool gDWGInstalledSettingsEntry = false;

// hook 本体：先调用原实现一次，再插入入口行。
static void DWGSettingsViewDidLoad(id self, SEL _cmd) {
    gDWGOriSettingsViewDidLoad(self, _cmd);
    DWGDiagnosticsIncrementHit(@"settingsEntry");
    DWGSettingsAttachRow(self);
}

// ---------------------------------------------------------------------------
// 安装器（Tweak.mm 调用）

static DWGSettingsEntryOutcome DWGMenuSkippedOutcome(const char *reason) {
    DWGDiagnosticsSetHookState(@"settingsEntry", NO, [NSString stringWithUTF8String:reason]);
    return DWGMenuOutcomeMake(DWGSettingsEntryStatusSkipped, reason);
}

static DWGSettingsEntryOutcome DWGInstallSettingsEntry(NSString *mainImagePath) {
    if (gDWGInstalledSettingsEntry) {
        return DWGMenuOutcomeMake(DWGSettingsEntryStatusAlreadyInstalled, "already-installed");
    }
    if (![mainImagePath isKindOfClass:[NSString class]] || mainImagePath.length == 0) {
        return DWGMenuSkippedOutcome("image-path-empty");
    }

    Class klass = (Class)objc_getClass("GSSettingViewController");
    if (klass == Nil) {
        return DWGMenuSkippedOutcome("class-missing");
    }
    if (!DWGClassIsInImage(klass, mainImagePath)) {
        return DWGMenuSkippedOutcome("image-mismatch");
    }

    // 在消息发送之前检查 getter 的 ABI，不能等误读整数为对象后才做 isKindOfClass。
    for (NSString *name in @[@"ui_scrollView", @"ui_privacyManageView", @"ui_showDebugSettingView",
                             @"ui_showDebugSettingViewTopConstraint", @"ui_contentBottomConstraint"]) {
        Method getter = DWGCopyOwnMethod(klass, NSSelectorFromString(name));
        if (getter == nullptr || method_getNumberOfArguments(getter) != 2 ||
            !DWGTypeEncodingMatches(method_getTypeEncoding(getter), "@16@0:8")) {
            return DWGMenuSkippedOutcome("outlet-signature-mismatch");
        }
    }

    Method own = DWGCopyOwnMethod(klass, @selector(viewDidLoad));
    if (own == nullptr) {
        return DWGMenuSkippedOutcome("not-own-method");
    }
    if (method_getNumberOfArguments(own) != kDWGMenuArgcSettingsViewDidLoad) {
        return DWGMenuSkippedOutcome("type-mismatch");
    }
    if (!DWGTypeEncodingMatches(method_getTypeEncoding(own), kDWGMenuEncSettingsViewDidLoad)) {
        return DWGMenuSkippedOutcome("type-mismatch");
    }
    IMP original = method_getImplementation(own);
    if (original == nullptr) {
        return DWGMenuSkippedOutcome("null-imp");
    }

    gDWGOriSettingsViewDidLoad = (DWGSettingsViewDidLoadFn)original;
    method_setImplementation(own, (IMP)&DWGSettingsViewDidLoad);
    gDWGInstalledSettingsEntry = true;
    DWGDiagnosticsSetHookState(@"settingsEntry", YES, @"ok");
    return DWGMenuOutcomeMake(DWGSettingsEntryStatusInstalled, "ok");
}
