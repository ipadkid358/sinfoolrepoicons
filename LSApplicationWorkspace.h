#import "LSApplicationProxy.h"

@interface LSApplicationWorkspace : NSObject

+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;

@end
