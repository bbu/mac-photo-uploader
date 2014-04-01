#import <Foundation/Foundation.h>

#import "Service.h"

@interface DeleteChromaKeyRoll2Service : Service

- (BOOL)startDeleteChromaKeyRoll2:(NSString *)account password:(NSString *)password
    orderNo:(NSString *)orderNo roll:(NSString *)roll destinationRoll:(NSString *)destinationRoll
    complete:(void (^)(ServiceResult *result))block;

@end
