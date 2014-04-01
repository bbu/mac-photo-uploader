#import <Foundation/Foundation.h>

#import "Service.h"

@interface GetSingleImageInfoResult : ServiceResult
@property NSString *status, *message;
@property NSInteger width, height;
@end

@interface GetSingleImageInfoService : Service

- (BOOL)startGetSingleImageInfo:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll frame:(NSString *)frame
    complete:(void (^)(GetSingleImageInfoResult *result))block;

@end
