#import <Foundation/Foundation.h>

#import "Service.h"

@interface PhotographerRow : NSObject
@property NSString *ccsPhotographerID;
@property NSString *name;
@property NSString *email;
@property NSString *password;
@end

@interface ListPhotographersResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@property NSMutableArray *photographers;
@end

@interface ListPhotographersService : Service

- (BOOL)startListPhotographers:(NSString *)account email:(NSString *)email password:(NSString *)password
    complete:(void (^)(ListPhotographersResult *result))block;

@end
