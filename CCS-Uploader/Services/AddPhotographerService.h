#import <Foundation/Foundation.h>

#import "Service.h"

@interface AddPhotographerResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@end

@interface AddPhotographerService : Service

- (BOOL)startAddPhotographer:(NSString *)email password:(NSString *)password account:(NSString *)account
    photographerEmail:(NSString *)photographerEmail photographerName:(NSString *)photographerName
    complete:(void (^)(AddPhotographerResult *result))block;

@end
