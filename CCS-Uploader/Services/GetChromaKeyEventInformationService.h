#import <Foundation/Foundation.h>

#import "Service.h"

@interface BackgroundRow : NSObject
@property NSString *orderNo;
@property NSString *sourceRoll;
@property NSString *horzBackgroundOrderNo, *horzBackgroundRoll, *horzBackgroundFrame;
@property NSInteger horzBackgroundWidth, horzBackgroundHeight;
@property NSString *vertBackgroundOrderNo, *vertBackgroundRoll, *vertBackgroundFrame;
@property NSInteger vertBackgroundWidth, vertBackgroundHeight;
@property NSString *destinationRoll;
@end

@interface GetChromaKeyEventInformationResult : ServiceResult
@property NSMutableArray *backgrounds;
@end

@interface GetChromaKeyEventInformationService : Service

- (BOOL)startGetChromaKeyEventInformation:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID complete:(void (^)(GetChromaKeyEventInformationResult *result))block;

@end