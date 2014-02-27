#import <Foundation/Foundation.h>

@class Transfer;

@interface TransferManager : NSObject
@property (readonly) NSMutableArray *transfers;
@property (readonly) Transfer *currentlyRunningTransfer;
@end
