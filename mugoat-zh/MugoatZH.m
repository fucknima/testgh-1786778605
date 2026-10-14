// Mugoat 1.1.3 Chinese localization (resource-only, fail-closed).
// Does not swizzle UIKit, buttons, game logic, logs, rendering, controls or WASM.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import "GeneratedTranslations.h"

static NSURL *(*mzh_original_url)(id,SEL,NSString*,NSString*) = NULL;
static NSString *(*mzh_original_path)(id,SEL,NSString*,NSString*) = NULL;
static NSURL *mzh_override_url = nil;
static dispatch_once_t mzh_override_once;

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
        NSLog(@"[MugoatZH] resource-only localization installed");
    }
}

