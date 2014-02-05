#import <Foundation/Foundation.h>

#import "Service.h"

@interface MissingFullSizeImageRow : NSObject
@property NSString *orderNumber;
@property NSString *roll;
@property NSString *frame;
@end

@interface MissingFullSizeImagesByRollResult : ServiceResult
@property NSString *status, *message;
@property NSMutableArray *missingImages;
@end

@interface MissingFullSizeImagesByRollService : Service

- (BOOL)startListImages:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll complete:(void (^)(MissingFullSizeImagesByRollResult *result))block;

@end
