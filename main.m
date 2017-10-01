#import <UIKit/UIKit.h>
#import "LSApplicationWorkspace.h"

NSString *endPath = @"/private/var/mobile/Library/Sinfool";
NSString *prefsPath = @"/private/var/mobile/Library/Preferences/com.ipadkid.sinfoolrepo.plist";
NSFileManager *fileManager;
CGSize imageSize;
CGRect imageRect;

BOOL shouldRun(NSArray *allAppDirs) {
    if (![fileManager fileExistsAtPath:endPath]) return YES;
    if (![[fileManager contentsOfDirectoryAtPath:endPath error:NULL] count]) return YES;
    if ([allAppDirs isEqualToArray:[NSArray arrayWithContentsOfFile:prefsPath]]) return NO;
    return YES;
}

void appIcon(NSString *appRoot) {
    @autoreleasepool {
        // Get possible icon sets
        NSString *infoPath = [appRoot stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
        if ([[info[@"SBAppTags"] objectAtIndex:0] isEqualToString:@"hidden"]) return;
        
        NSDictionary *smallIconList = info[@"CFBundleIcons"];
        NSDictionary *bigIconList = info[@"CFBundleIcons~ipad"];
        NSArray *fileNames = info[@"CFBundleIconFiles"];
        
        // Validate sets to get the largest
        if (!bigIconList || bigIconList.count < 1) {
            if (smallIconList) bigIconList = smallIconList;
            else if (fileNames) bigIconList = nil;
            else return;
        }
        if (bigIconList) {
            NSDictionary *primaryList = bigIconList[@"CFBundlePrimaryIcon"];
            if (primaryList) fileNames = primaryList[@"CFBundleIconFiles"];
            else return;
        }
        if (fileNames.count < 1) return;
        UIImage *image;
        for (NSString *fileName in fileNames.reverseObjectEnumerator) {
            NSString *imagePath = [appRoot stringByAppendingPathComponent:fileName];
            image = [[UIImage alloc] initWithContentsOfFile:imagePath];
            if (image) break;
        }
        if (!image) return;
        
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
        [[UIBezierPath bezierPathWithRoundedRect:imageRect cornerRadius:9] addClip];
        [image drawInRect:imageRect];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        NSString *bundleIdent = info[@"CFBundleIdentifier"];
        if (!bundleIdent) return;
        
        // doing as much as possible before dispatching back to main thread
        NSString *fullDestPath = [[endPath stringByAppendingPathComponent:bundleIdent] stringByAppendingPathExtension:@"png"];
        NSData *writeable = UIImagePNGRepresentation(newImage);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [writeable writeToFile:fullDestPath atomically:YES];
        });
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSDate *startTime = NSDate.date;
        fileManager = NSFileManager.defaultManager;
        CGFloat size = 120/UIScreen.mainScreen.scale;
        imageSize = CGSizeMake(size, size);
        imageRect = CGRectMake(0, 0, size, size);
        
        NSArray<LSApplicationProxy *> *appProxies = LSApplicationWorkspace.defaultWorkspace.allInstalledApplications;
        NSMutableArray<NSString *> *allAppRoots = NSMutableArray.new;
        for (LSApplicationProxy *appProxy in appProxies) [allAppRoots addObject:appProxy.resourcesDirectoryURL.path];
        if (shouldRun(allAppRoots)) printf("Reloading Sinfool Repo icons\n");
        else {
            printf("Did not run becuase app state has not changed\n"
                   "Check finished in %f seconds\n", [NSDate.date timeIntervalSinceDate:startTime]);
            return 1;
        }
        if (![allAppRoots writeToFile:prefsPath atomically:YES]) printf("Failed to write app state (not fatal)\n");
        
        [fileManager removeItemAtPath:endPath error:NULL];
        setuid(501);
        [fileManager createDirectoryAtPath:endPath withIntermediateDirectories:NO attributes:NULL error:NULL];
        
        // asyn stuff
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        unsigned long appCount = allAppRoots.count;
        __block int completionCount = 0;
        for (int increment = 0; increment < appCount; increment++) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                appIcon(allAppRoots[increment]);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionCount++;
                    if (completionCount == appCount) CFRunLoopStop(runLoop);
                });
            });
        }
        CFRunLoopRun();
        printf("Finished in %f seconds\n", [NSDate.date timeIntervalSinceDate:startTime]);
    }
    return 0;
}
