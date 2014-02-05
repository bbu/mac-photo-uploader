#import <Foundation/Foundation.h>

#import "Service.h"

@interface ActivatePreviewsAndThumbsResult : ServiceResult
@property NSString *status, *message;
@end

@interface ActivatePreviewsAndThumbsService : Service

- (BOOL)startActivatePreviewsAndThumbs:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(ActivatePreviewsAndThumbsResult *result))block;

@end
