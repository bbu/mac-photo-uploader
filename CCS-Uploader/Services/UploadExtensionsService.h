#import <Foundation/Foundation.h>

#import "Service.h"

@interface UploadExtensionsResult : ServiceResult
@property NSString *status, *message;
@property NSMutableArray *extensions;
@end

@interface UploadExtensionsService : Service

- (BOOL)startGetUploadExtensions:(NSString *)account password:(NSString *)password
    complete:(void (^)(UploadExtensionsResult *result))block;

@end
