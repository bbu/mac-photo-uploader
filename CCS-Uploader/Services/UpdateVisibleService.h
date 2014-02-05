#import <Foundation/Foundation.h>

#import "Service.h"

@interface UpdateVisibleResult : ServiceResult
@property NSString *status, *message;
@end

@interface UpdateVisibleService : Service

- (BOOL)startUpdateVisible:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    roll:(NSString *)roll frame:(NSString *)frame
    visible:(BOOL)visible fullsizeMustNotExist:(BOOL)fullsizeMustNotExist
    complete:(void (^)(UpdateVisibleResult *result))block;

@end
