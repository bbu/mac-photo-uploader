#import <Foundation/Foundation.h>

#import "Service.h"

@interface SendFeedbackService : Service

- (BOOL)startSendFeedback:(NSString *)version
    credentials:(NSString *)credentials
    url:(NSString *)url
    ccsAccount:(NSString *)ccsAccount
    orderNumber:(NSString *)orderNumber
    system:(NSString *)system
    program:(NSString *)program
    description:(NSString *)description
    type:(NSString *)type
    name:(NSString *)name
    email:(NSString *)email
    files:(NSData *)files
    complete:(void (^)(ServiceResult *result))block;

@end
