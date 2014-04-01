#import <Foundation/Foundation.h>

#import "Service.h"

@interface DeleteChromaKeyRollService : Service

- (BOOL)startDeleteChromaKeyRoll:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID sourceRoll:(NSString *)sourceRoll
    complete:(void (^)(ServiceResult *result))block;

@end
