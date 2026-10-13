// GTA5ZH safe-v2. Original game engine and program code are not modified.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "ZHGeneratedRules.h"

typedef void (*ZHSetter)(id, SEL, NSString *);
static ZHSetter originalLabelSetText = NULL;
static ZHSetter originalNavigationSetTitle = NULL;
static ZHSetter originalControllerSetTitle = NULL;
static ZHSetter originalTextFieldSetPlaceholder = NULL;

static NSString *ZHExactDisplayText(NSString *text) {
    if (text == nil || ![text isKindOfClass:NSString.class] ||
        text.length == 0 || text.length > 256) return text;
    static NSDictionary<NSString *, NSString *> *rules = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ rules = ZHExactRules(); });
    return rules[text] ?: text;
}
static void ZHUILabelSetText(id receiver, SEL cmd, NSString *text) {
    ZHSetter call = originalLabelSetText;
    if (call == NULL) return;
    call(receiver, cmd, [NSThread isMainThread] ? ZHExactDisplayText(text) : text);
}
static void ZHUINavigationSetTitle(id receiver, SEL cmd, NSString *text) {
    ZHSetter call = originalNavigationSetTitle;
    if (call == NULL) return;
    call(receiver, cmd, [NSThread isMainThread] ? ZHExactDisplayText(text) : text);
}
static void ZHUIViewControllerSetTitle(id receiver, SEL cmd, NSString *text) {
    ZHSetter call = originalControllerSetTitle;
    if (call == NULL) return;
    call(receiver, cmd, [NSThread isMainThread] ? ZHExactDisplayText(text) : text);
}
static void ZHUITextFieldSetPlaceholder(id receiver, SEL cmd, NSString *text) {
    ZHSetter call = originalTextFieldSetPlaceholder;
    if (call == NULL) return;
    call(receiver, cmd, [NSThread isMainThread] ? ZHExactDisplayText(text) : text);
}
static void ZHInstallHook(Class cls, SEL selector, IMP replacement, ZHSetter *previous) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return;
    IMP current = method_getImplementation(method);
    if (current == replacement) return;
    *previous = (ZHSetter)current;
    method_setImplementation(method, replacement);
}
static void ZHInstallConservativeHooks(void) {
    ZHInstallHook(UILabel.class, @selector(setText:), (IMP)ZHUILabelSetText, &originalLabelSetText);
    ZHInstallHook(UINavigationItem.class, @selector(setTitle:), (IMP)ZHUINavigationSetTitle, &originalNavigationSetTitle);
    ZHInstallHook(UIViewController.class, @selector(setTitle:), (IMP)ZHUIViewControllerSetTitle, &originalControllerSetTitle);
    ZHInstallHook(UITextField.class, @selector(setPlaceholder:), (IMP)ZHUITextFieldSetPlaceholder, &originalTextFieldSetPlaceholder);
    NSLog(@"[GTA5ZH-v2] Safe localization hooks installed");
}
__attribute__((constructor)) static void GTA5ZHSafeStart(void) {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        NSString *exe = bundle.executablePath.lastPathComponent ?: @"";
        NSString *bundleID = bundle.bundleIdentifier ?: @"";
        if (![exe isEqualToString:@"PlayGTA5Native"] &&
            ![bundleID isEqualToString:@"io.github.playgta5ios.app"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{ ZHInstallConservativeHooks(); });
    }
}
