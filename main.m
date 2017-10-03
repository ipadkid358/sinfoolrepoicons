#import <dlfcn.h>

@import UIKit;
@import MobileCoreServices;

@interface LSApplicationProxy
@property (readonly) NSString *bundleIdentifier;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
@end

@interface UIImage (BlackJacketPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(nonnull NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

NSString *endPath = @"/private/var/mobile/Library/Sinfool";
NSString *prefsPath = @"/private/var/mobile/Library/Preferences/com.ipadkid.sinfoolrepo.plist";
NSFileManager *fileManager;

BOOL sameAppSet(NSArray *allAppDirs) {
    if (![fileManager fileExistsAtPath:endPath]) return NO;
    if (![[fileManager contentsOfDirectoryAtPath:endPath error:NULL] count]) return NO;
    if ([allAppDirs isEqualToArray:[NSArray arrayWithContentsOfFile:prefsPath]]) return YES;
    return NO;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        fileManager = NSFileManager.defaultManager;
        
        NSArray<LSApplicationProxy *> *appProxies = LSApplicationWorkspace.defaultWorkspace.allInstalledApplications;
        NSMutableArray<NSString *> *allAppRoots = NSMutableArray.new;
        for (LSApplicationProxy *appProxy in appProxies) [allAppRoots addObject:appProxy.bundleIdentifier];
        if (sameAppSet(allAppRoots)) return 0;
        
        CGFloat scale = UIScreen.mainScreen.scale;
        void *cynject = dlopen("/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateInjection.dylib", RTLD_NOW);
        NSData *badImage = UIImagePNGRepresentation([UIImage _applicationIconImageForBundleIdentifier:@"" format:1 scale:scale]);
        NSString *png = @"png";
        
        [fileManager removeItemAtPath:endPath error:NULL];
        setuid(501);
        [allAppRoots writeToFile:prefsPath atomically:YES];
        [fileManager createDirectoryAtPath:endPath withIntermediateDirectories:NO attributes:NULL error:NULL];
        
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        NSUInteger appCount = appProxies.count;
        
        __block NSUInteger completionCount = 0;
        for (LSApplicationProxy *appProxy in appProxies) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSString *bundleID = appProxy.bundleIdentifier;
                NSString *fullDestPath = [[endPath stringByAppendingPathComponent:bundleID] stringByAppendingPathExtension:png];
                
                NSData *writeable = UIImagePNGRepresentation([UIImage _applicationIconImageForBundleIdentifier:bundleID format:1 scale:scale]);
                BOOL goodWrite = ![writeable isEqualToData:badImage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (goodWrite) [writeable writeToFile:fullDestPath atomically:NO];
                    
                    completionCount++;
                    if (completionCount == appCount) CFRunLoopStop(runLoop);
                });
            });
        }
        CFRunLoopRun();
        
        dlclose(cynject);
    }
    return 0;
}
