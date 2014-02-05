#import <Foundation/Foundation.h>

#import "Service.h"

@interface VerifyOrderResult : ServiceResult
@property NSString *status, *message;
@property NSString *remoteHost, *remoteDirectory, *username, *password;
@end

@interface VerifyOrderService : Service

- (BOOL)startVerifyOrder:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    version:(NSString *)version bypassPassword:(BOOL)bypassPassword
    complete:(void (^)(VerifyOrderResult *result))block;

@end
