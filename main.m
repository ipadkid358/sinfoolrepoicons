// UIImage, and Foundation
#import <UIKit/UIKit.h>
// needed for dlopen and dlclose
#import <dlfcn.h>

#define imageDataForAppBundleID(b) UIImagePNGRepresentation([UIImage _applicationIconImageForBundleIdentifier:(b) format:1 scale:scale])

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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // some constants
        NSString *const endPath = @"/private/var/mobile/Library/Sinfool";
        CGFloat const scale = UIScreen.mainScreen.scale;
        NSString *const pngExt = @"png";
        NSFileManager *fileManager = NSFileManager.defaultManager;
        NSArray<LSApplicationProxy *> *appProxies = LSApplicationWorkspace.defaultWorkspace.allInstalledApplications;
        NSUInteger appCount = appProxies.count;
        
        // delete entire directory and recreate so we don't have to worry about deleted apps
        if ([fileManager fileExistsAtPath:endPath]) {
            [fileManager removeItemAtPath:endPath error:NULL];
        }
        setuid(501); // setting to mobile because permissions for running in terminal default
        [fileManager createDirectoryAtPath:endPath withIntermediateDirectories:NO attributes:0 error:NULL];
        
        // due to theos debug defaults, a lot of tweaks that inject UIKit will log to console, this forwards those to /dev/null
        FILE *devNull = freopen("/dev/null", "w", stderr);
        
        // load Substrate so icons are themed, if necessary
        void *cynject = dlopen("/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateInjection.dylib", RTLD_NOW);
        
        // get a blank icon image
        NSData *badImage = imageDataForAppBundleID(@"");
        
        // needed for command line tools which don't have a runloop
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        
        // block indicates the variable will be mutated within a block
        __block NSUInteger completionCount = 0;
        for (LSApplicationProxy *appProxy in appProxies) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                NSString *bundleID = appProxy.bundleIdentifier;
                NSString *fullDestPath = [[endPath stringByAppendingPathComponent:bundleID] stringByAppendingPathExtension:pngExt];
                
                // the data that's going to be written
                NSData *writeable = imageDataForAppBundleID(bundleID);
                
                // check if we got a blank icon
                BOOL badData = [writeable isEqualToData:badImage];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!badData) {
                        [writeable writeToFile:fullDestPath atomically:NO];
                    }
                    completionCount++;
                    
                    // now we're done, and can run the stuff under CFRunLoopRun()
                    if (completionCount == appCount) {
                        CFRunLoopStop(runLoop);
                    }
                });
            });
        }
        
        // once this line is run, nothing under it will be run until CFRunLoopStop() is called on this runloop
        CFRunLoopRun();
        
        // close things opened earlier
        dlclose(cynject);
        fclose(devNull);
    }
    return 0;
}
