#import <Foundation/Foundation.h>

#import "Service.h"

@interface CheckOrderNumberResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@property NSString *ccsPassword;
@end

@interface CheckOrderNumberService : Service

- (BOOL)startCheckOrderNumber:(NSString *)email password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(CheckOrderNumberResult *result))block;

@end
