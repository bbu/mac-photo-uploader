#import <Foundation/Foundation.h>

#import "Service.h"

@interface RollHasImagesResult : ServiceResult
@property BOOL hasImages;
@end

@interface RollHasImagesService : Service

- (BOOL)startRollHasImages:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll
    complete:(void (^)(RollHasImagesResult *result))block;

@end