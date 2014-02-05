#import <Foundation/Foundation.h>

#import "Service.h"

@interface FullSizeImageDimensionRow : NSObject
@property NSString *orderNumber;
@property NSString *roll;
@property NSString *frame;
@property NSUInteger filesize;
@property NSInteger length;
@property NSInteger width;
@property BOOL pngImage;
@end

@interface FullSizeImageDimensionsByRollResult : ServiceResult
@property NSString *status, *message;
@property NSMutableArray *dimensions;
@end

@interface FullSizeImageDimensionsByRollService : Service

- (BOOL)startListDimensions:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll complete:(void (^)(FullSizeImageDimensionsByRollResult *result))block;

@end
