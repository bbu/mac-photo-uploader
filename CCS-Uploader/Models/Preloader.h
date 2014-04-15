#import <Foundation/Foundation.h>

#import "../Models/OrderModel.h"

@class EventSettingsResult;

@interface Preloader : NSObject

- (id)initWithOrderModel:(OrderModel *)order eventSettings:(EventSettingsResult *)settings ccsPassword:(NSString *)ccsPass;
- (BOOL)isBusy;
- (void)processThumbs;
- (void)stop;
- (void)cancel;

@property (nonatomic, copy) BOOL (^shouldStart)(void);
@property (nonatomic, copy) void (^startedRoll)(RollModel *roll, NSInteger rollIndex);
@property (nonatomic, copy) void (^endedRoll)(RollModel *roll, NSInteger rollIndex);
@property (nonatomic, copy) void (^uploadedThumb)(RollModel *roll, NSInteger rollIndex, NSString *status);

@end
