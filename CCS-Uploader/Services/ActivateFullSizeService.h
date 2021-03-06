#import <Foundation/Foundation.h>

#import "Service.h"

@interface ActivateFullSizeResult : ServiceResult
@property NSString *status, *message;
@end

@interface ActivateFullSizeService : Service

- (BOOL)startActivateFullSize:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(ActivateFullSizeResult *result))block;

@end
