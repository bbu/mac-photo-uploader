#import <Foundation/Foundation.h>

#import "Service.h"

@interface SetChromaKeyRollService : Service

- (BOOL)startSetChromaKeyRoll:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID sourceRoll:(NSString *)sourceRoll
    horzBackgroundOrderNo:(NSString *)horzBackgroundOrderNo horzBackgroundRoll:(NSString *)horzBackgroundRoll horzBackgroundFrame:(NSString *)horzBackgroundFrame
    vertBackgroundOrderNo:(NSString *)vertBackgroundOrderNo vertBackgroundRoll:(NSString *)vertBackgroundRoll vertBackgroundFrame:(NSString *)vertBackgroundFrame
    destinationRoll:(NSString *)destinationRoll
    complete:(void (^)(ServiceResult *result))block;

@end
