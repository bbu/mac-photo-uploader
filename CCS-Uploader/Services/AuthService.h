#import <Foundation/Foundation.h>

@interface AuthResult : NSObject

@property NSError *error;
@property BOOL success;
@property NSString *accountID;

@end

@interface AuthService : NSObject <NSURLConnectionDelegate, NSXMLParserDelegate>

- (void)start:(NSString *)email password:(NSString *)password complete:(void (^)(AuthResult *result))block;

@end
