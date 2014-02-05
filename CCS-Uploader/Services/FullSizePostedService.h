#import <Foundation/Foundation.h>

#import "Service.h"

@interface FullSizePostedResult : ServiceResult
@property NSString *status, *message;
@end

@interface FullSizePostedService : Service

- (BOOL)startFullSizePosted:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    roll:(NSString *)roll frame:(NSString *)frame filename:(NSString *)filename
    version:(NSString *)version bypassPassword:(BOOL)bypassPassword createPreviewAndThumb:(BOOL)createPreviewAndThumb
    complete:(void (^)(FullSizePostedResult *result))block;

@end
