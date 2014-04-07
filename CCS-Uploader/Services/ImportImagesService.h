#import <Foundation/Foundation.h>

#import "Service.h"

@interface ImportImagesResult : ServiceResult
@property NSInteger status;
@property NSString *message;
@end

@interface ImportImagesService : Service

- (BOOL)startImportImages:(NSString *)username password:(NSString *)password
    orderNumber:(NSString *)orderNumber
    eventID:(NSString *)eventID
    spotImagesToRollDivision:(BOOL)spotImagesToRollDivision
    complete:(void (^)(ImportImagesResult *result))block;

@end