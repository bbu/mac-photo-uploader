#import <Foundation/Foundation.h>

#import "Service.h"

@interface VersionResult : ServiceResult
@property BOOL upgradeRequired, upgradeAvailable;
@property NSString *latestVersion;
@property NSString *latestNotes;
@property NSString *websiteURL, *installerURL, *releaseHistoryURL;
@property BOOL errorOccurred;
@property NSString *message;
@end

@interface VersionService : Service

- (BOOL)startCheckVersion:(void (^)(VersionResult *result))block;

@end
