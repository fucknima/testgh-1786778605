// Mugoat 1.1.3 Chinese localization (resource-only, fail-closed).
// Does not swizzle UIKit, buttons, game logic, logs, rendering, controls or WASM.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#if MZH_UI_EXTRAS
#import <UIKit/UIKit.h>
#import "GeneratedExtraUI.h"
#endif
#import "GeneratedTranslations.h"

static NSURL *(*mzh_original_url)(id,SEL,NSString*,NSString*) = NULL;
static NSString *(*mzh_original_path)(id,SEL,NSString*,NSString*) = NULL;
static NSURL *mzh_override_url = nil;
static dispatch_once_t mzh_override_once;

#if MZH_UI_EXTRAS
static void (*mzh_original_label_text)(id, SEL, NSString *) = NULL;
static void (*mzh_original_label_attributed)(id, SEL, NSAttributedString *) = NULL;
static void (*mzh_original_list_text)(id, SEL, NSString *) = NULL;
static void (*mzh_original_list_secondary)(id, SEL, NSString *) = NULL;
static void (*mzh_original_controller_did_appear)(id, SEL, BOOL) = NULL;
static unsigned long mzh_label_hits = 0;

// Only known, complete UI sentences. No regex, no substring replacement, no log interception.
static void MZHLabelTextHook(id label, SEL cmd, NSString *originalText) {
    if (!mzh_original_label_text) return;
    NSString *visibleText = originalText;
    if ([NSThread isMainThread] && [originalText isKindOfClass:NSString.class] && originalText.length <= 1500) {
        NSDictionary<NSString *, NSString *> *knownTexts = MZHExtraUIMap();
        NSString *translation = knownTexts[originalText];
        if (translation) {
            visibleText = translation;
            __sync_fetch_and_add(&mzh_label_hits, 1);
        } else {
            // Only these two status prefixes can contain runtime details.
            for (NSString *prefix in @[@"Game chưa chạy: ", @"Đang kích hoạt cheat: "]) {
                if ([originalText hasPrefix:prefix]) {
                    NSString *replacement = knownTexts[prefix];
                    if (replacement) visibleText = [replacement stringByAppendingString:[originalText substringFromIndex:prefix.length]];
                    break;
                }
            }
        }
    }
    mzh_original_label_text(label, cmd, visibleText);
}

// UITableView/UICollectionView modern cells set text on UIListContentConfiguration.
// Translate display properties BEFORE rendering, including text and secondaryText.
// Exact full sentence match only; all other values go through untouched.
static void MZHListTextHook(id configuration, SEL selector, NSString *text) {
    if (!mzh_original_list_text) return;
    if ([NSThread isMainThread] && [text isKindOfClass:NSString.class] && text.length < 1500) {
        NSString *localized = MZHExtraUIMap()[text];
        if (localized) {
            text = localized;
            __sync_fetch_and_add(&mzh_label_hits, 1);
        }
    }
    mzh_original_list_text(configuration, selector, text);
}
static void MZHListSecondaryHook(id configuration, SEL selector, NSString *text) {
    if (!mzh_original_list_secondary) return;
    if ([NSThread isMainThread] && [text isKindOfClass:NSString.class] && text.length < 1500) {
        NSString *localized = MZHExtraUIMap()[text];
        if (localized) {
            text = localized;
            __sync_fetch_and_add(&mzh_label_hits, 1);
        }
    }
    mzh_original_list_secondary(configuration, selector, text);
}

// UIKit list content configurations sometimes use attributedText, not text.
// Only exact full strings are changed; all original attributes are preserved at index 0.
static void MZHLabelAttributedHook(id label, SEL cmd, NSAttributedString *incoming) {
    if (!mzh_original_label_attributed) return;
    if ([NSThread isMainThread] && [incoming isKindOfClass:NSAttributedString.class] &&
        incoming.length > 0 && incoming.length <= 1500) {
        NSString *translation = MZHExtraUIMap()[incoming.string];
        if (translation) {
            NSDictionary *attrs = [incoming attributesAtIndex:0 effectiveRange:NULL];
            incoming = [[NSAttributedString alloc] initWithString:translation attributes:attrs];
            __sync_fetch_and_add(&mzh_label_hits, 1);
        }
    }
    mzh_original_label_attributed(label, cmd, incoming);
}

// UIKit owns the system "Done" navigation action. Replace only its visible title,
// after the ModManager view appears; do not change the item's target or selector.
static void MZHModManagerDidAppear(id controller, SEL cmd, BOOL animated) {
    if (mzh_original_controller_did_appear)
        mzh_original_controller_did_appear(controller, cmd, animated);
    if (![NSThread isMainThread] || ![controller isKindOfClass:UIViewController.class]) return;
    NSString *className = NSStringFromClass([controller class]);
    if ([className rangeOfString:@"ModManagerViewController"].location == NSNotFound) return;
    UIBarButtonItem *item = ((UIViewController *)controller).navigationItem.rightBarButtonItem;
    if (!item) return;
    if ([item.title isEqualToString:@"Done"] || [item.title isEqualToString:@"Xong"]) {
        item.title = @"完成";
    }
}
__attribute__((visibility("default"))) unsigned long MugoatZH_UILabelTranslations(void) {
    return __sync_fetch_and_add(&mzh_label_hits, 0);
}
#endif

static BOOL MZHMatch(id bundle, NSString *name, NSString *ext) {
    return bundle == NSBundle.mainBundle && [name isKindOfClass:NSString.class] &&
        [ext isKindOfClass:NSString.class] && [name isEqualToString:@"Localizations"] &&
        [ext.lowercaseString isEqualToString:@"json"];
}

// Copy only UI translation values from the original JSON into an independent temporary
// JSON document. The original resources are never modified. Unknown versions fail closed.
static NSURL *MZHMakeOverride(NSURL *original) {
    if (!original || !original.isFileURL) return nil;
    NSData *data = [NSData dataWithContentsOfURL:original options:0 error:nil];
    if (!data || data.length < 1000) return nil;
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error || ![object isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *root = (NSMutableDictionary *)object;
    if (root.count != 485) return nil; // Mugoat 1.1.3 resource layout only
    NSDictionary *sentinel = root[@"Play"];
    if (![sentinel isKindOfClass:NSDictionary.class] || ![sentinel[@"en"] isEqualToString:@"Play"]) return nil;
    NSDictionary<NSString *, NSString *> *translations = MZHTranslationMap();
    __block NSUInteger found = 0;
    [root enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (![value isKindOfClass:NSMutableDictionary.class]) return;
        NSMutableDictionary *entry = value;
        NSString *english = entry[@"en"];
        if (![english isKindOfClass:NSString.class] || ![entry[@"vi"] isKindOfClass:NSString.class]) return;
        NSString *chinese = translations[english];
        if (!chinese) return;
        entry[@"en"] = chinese;
        entry[@"vi"] = chinese;
        found++;
    }];
    if (found != root.count) return nil; // Require complete coverage, never partially translate.
    NSData *result = [NSJSONSerialization dataWithJSONObject:root options:0 error:&error];
    if (!result || error) return nil;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Mugoat-v113-zh-Hans-localizations.json"];
    if (path.length == 0) return nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    if (![result writeToURL:url options:NSDataWritingAtomic error:&error] || error) return nil;
    NSLog(@"[MugoatZH] Localizations.json localized: %lu entries", (unsigned long)found);
    return url;
}

static NSURL *MZHRedirect(NSURL *original) {
    if (!original) return nil;
    dispatch_once(&mzh_override_once, ^{ mzh_override_url = MZHMakeOverride(original); });
    return mzh_override_url ?: original;
}

static NSURL *MZHURLHook(id bundle, SEL selector, NSString *name, NSString *ext) {
    if (!mzh_original_url) return nil;
    NSURL *original = mzh_original_url(bundle,selector,name,ext);
    return MZHMatch(bundle,name,ext) ? MZHRedirect(original) : original;
}

static NSString *MZHPathHook(id bundle, SEL selector, NSString *name, NSString *ext) {
    if (!mzh_original_path) return nil;
    NSString *original = mzh_original_path(bundle,selector,name,ext);
    if (!MZHMatch(bundle,name,ext) || original.length == 0) return original;
    return MZHRedirect([NSURL fileURLWithPath:original]).path;
}

__attribute__((constructor)) static void MZHInstall(void) {
    @autoreleasepool {
        NSString *exe = NSBundle.mainBundle.executablePath.lastPathComponent;
        if (![exe isEqualToString:@"PlayGTA5Native"]) return;
        Class cls = NSBundle.class;
        Method urlMethod = class_getInstanceMethod(cls,@selector(URLForResource:withExtension:));
        Method pathMethod = class_getInstanceMethod(cls,@selector(pathForResource:ofType:));
        if (urlMethod) {
            IMP previous = method_setImplementation(urlMethod,(IMP)MZHURLHook);
            mzh_original_url = (NSURL *(*)(id,SEL,NSString*,NSString*))previous;
        }
        if (pathMethod) {
            IMP previous = method_setImplementation(pathMethod,(IMP)MZHPathHook);
            mzh_original_path = (NSString *(*)(id,SEL,NSString*,NSString*))previous;
        }
#if MZH_UI_EXTRAS
        Method labelMethod = class_getInstanceMethod(UILabel.class, @selector(setText:));
        if (labelMethod) {
            IMP oldLabelIMP = method_setImplementation(labelMethod, (IMP)MZHLabelTextHook);
            mzh_original_label_text = (void (*)(id,SEL,NSString*))oldLabelIMP;
        }
        Method attributed = class_getInstanceMethod(UILabel.class, @selector(setAttributedText:));
        if (attributed) {
            IMP old = method_setImplementation(attributed, (IMP)MZHLabelAttributedHook);
            mzh_original_label_attributed = (void (*)(id,SEL,NSAttributedString*))old;
        }
        Class listContent = NSClassFromString(@"UIListContentConfiguration");
        if (listContent) {
            Method primaryText = class_getInstanceMethod(listContent, @selector(setText:));
            if (primaryText) {
                IMP old = method_setImplementation(primaryText, (IMP)MZHListTextHook);
                mzh_original_list_text = (void (*)(id,SEL,NSString*))old;
            }
            Method secondaryText = class_getInstanceMethod(listContent, @selector(setSecondaryText:));
            if (secondaryText) {
                IMP old = method_setImplementation(secondaryText, (IMP)MZHListSecondaryHook);
                mzh_original_list_secondary = (void (*)(id,SEL,NSString*))old;
            }
        }
        // Guard the lifecycle hook by exact controller type inside the callback.
        Method appeared = class_getInstanceMethod(UIViewController.class, @selector(viewDidAppear:));
        if (appeared) {
            IMP old = method_setImplementation(appeared, (IMP)MZHModManagerDidAppear);
            mzh_original_controller_did_appear = (void (*)(id,SEL,BOOL))old;
        }
        NSLog(@"[MugoatZH] resource + UIKit exact text/attributedText mappings installed");
#else
        NSLog(@"[MugoatZH] resource-only localization installed");
#endif
    }
}

