#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ESign 5.0.2: compatibility shim for an existing document-open entry point.
// A system Share Extension requires a separate .appex and cannot be added by
// a dylib alone. Does not touch signing or certificate logic.

typedef BOOL (*OpenImp)(id,SEL,UIApplication *,NSURL *,NSDictionary *);
typedef BOOL (*OldImp)(id,SEL,UIApplication *,NSURL *);
typedef BOOL (*LegacyImp)(id,SEL,UIApplication *,NSURL *,NSString *,id);

static OpenImp originalOpen;
static OldImp originalOld;
static LegacyImp originalLegacy;

static NSURL *stageFile(NSURL *source) {
    if (!source || !source.isFileURL) return nil;
    if ([source.path containsString:@"/ESignShareFix/"]) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *folder = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"ESignShareFix"]
                        stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSError *error = nil;
    if (![fm createDirectoryAtPath:folder withIntermediateDirectories:YES
                        attributes:nil error:&error]) {
        NSLog(@"[ESignShareFix] staging mkdir failed: %@", error);
        return nil;
    }
    NSURL *destination = [NSURL fileURLWithPath:
                            [folder stringByAppendingPathComponent:source.lastPathComponent]];
    BOOL scoped = [source startAccessingSecurityScopedResource];
    BOOL copied = [fm copyItemAtURL:source toURL:destination error:&error];
    if (!copied) {
        [fm removeItemAtURL:destination error:NULL];
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block BOOL coordinatedCopy = NO;
        [coordinator coordinateReadingItemAtURL:source
                                       options:0
                                         error:&error
                                    byAccessor:^(NSURL *readableURL) {
            NSError *copyError = nil;
            coordinatedCopy = [fm copyItemAtURL:readableURL toURL:destination error:&copyError];
            if (!coordinatedCopy) NSLog(@"[ESignShareFix] coordinated copy: %@", copyError);
        }];
        copied = coordinatedCopy;
    }
    if (scoped) [source stopAccessingSecurityScopedResource];
    if (!copied) NSLog(@"[ESignShareFix] file staging failed: %@", error);
    return copied ? destination : nil;
}

// Last-resort fallback when the app explicitly rejects its native URL handler.
static BOOL copyIntoDocuments(NSURL *staged) {
    if (!staged) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    [fm createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *name = staged.lastPathComponent;
    NSString *target = [docs stringByAppendingPathComponent:name];
    if ([fm fileExistsAtPath:target]) {
        NSString *stem = name.stringByDeletingPathExtension;
        NSString *ext = name.pathExtension;
        NSString *newName = [NSString stringWithFormat:@"%@-%@", stem, [NSUUID UUID].UUIDString];
        if (ext.length) newName = [newName stringByAppendingPathExtension:ext];
        target = [docs stringByAppendingPathComponent:newName];
    }
    NSError *error = nil;
    BOOL ok = [fm copyItemAtURL:staged toURL:[NSURL fileURLWithPath:target] error:&error];
    if (!ok) NSLog(@"[ESignShareFix] Documents fallback failed: %@", error);
    return ok;
}

static BOOL openHook(id self, SEL cmd, UIApplication *app, NSURL *url, NSDictionary *options) {
    NSURL *staged = stageFile(url);
    BOOL ok = originalOpen ? originalOpen(self,cmd,app,staged ?: url,options) : NO;
    if (staged && !ok && copyIntoDocuments(staged)) {
        NSLog(@"[ESignShareFix] imported into Documents via fallback");
        return YES;
    }
    return ok;
}
static BOOL oldHook(id self, SEL cmd, UIApplication *app, NSURL *url) {
    NSURL *staged = stageFile(url);
    BOOL ok = originalOld ? originalOld(self,cmd,app,staged ?: url) : NO;
    return (staged && !ok && copyIntoDocuments(staged)) ? YES : ok;
}
static BOOL legacyHook(id self, SEL cmd, UIApplication *app, NSURL *url, NSString *source, id annotation) {
    NSURL *staged = stageFile(url);
    BOOL ok = originalLegacy ? originalLegacy(self,cmd,app,staged ?: url,source,annotation) : NO;
    return (staged && !ok && copyIntoDocuments(staged)) ? YES : ok;
}
__attribute__((constructor)) static void installESignImportFix(void) {
    Class cls = objc_getClass("AppDelegate");
    if (!cls) return;
    Method method = class_getInstanceMethod(cls, @selector(application:openURL:options:));
    if (method) originalOpen = (OpenImp)method_setImplementation(method, (IMP)openHook);
    method = class_getInstanceMethod(cls, @selector(application:handleOpenURL:));
    if (method) originalOld = (OldImp)method_setImplementation(method, (IMP)oldHook);
    method = class_getInstanceMethod(cls, @selector(application:openURL:sourceApplication:annotation:));
    if (method) originalLegacy = (LegacyImp)method_setImplementation(method, (IMP)legacyHook);
    NSLog(@"[ESignShareFix] ESign 5.0.2 import-hook installed");
}
