#import <Foundation/Foundation.h>

@interface CheckOrderNumberResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@property NSString *ccsPassword;
@end

@interface CheckOrderNumberService : NSObject

- (BOOL)startCheckOrderNumber:(NSString *)email password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(CheckOrderNumberResult *result))block;

@end
