#import <Foundation/Foundation.h>

#import "Service.h"

@interface SetChromaKeyRollMakePNGOnlyService : Service

- (BOOL)startSetChromaKeyRollMakePNGOnly:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID sourceRoll:(NSString *)sourceRoll
    complete:(void (^)(ServiceResult *result))block;

@end
