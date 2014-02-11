#import <Foundation/Foundation.h>

@interface CCSPassword : NSObject
+ (NSData *)decryptCCSPassword:(NSData *)encryptedPassword;
@end
