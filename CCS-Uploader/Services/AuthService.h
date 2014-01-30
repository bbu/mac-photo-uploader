#import <Foundation/Foundation.h>

#import "Service.h"

@interface AuthResult : NSObject
@property NSError *error;
@property BOOL success;
@property NSString *accountID;
@end

@interface AuthService : Service
- (BOOL)startAuth:(NSString *)email password:(NSString *)password complete:(void (^)(AuthResult *result))block;
@end
