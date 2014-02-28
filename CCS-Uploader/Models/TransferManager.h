#import <Foundation/Foundation.h>

@class RunningTransferContext;

typedef NS_ENUM(NSInteger, TransferStatus) {
    kTransferStatusQueued,
    kTransferStatusRunning,
    kTransferStatusScheduled,
    kTransferStatusAborted,
    kTransferStatusStopped,
    kTransferStatusComplete,
};

@interface Transfer : NSObject <NSCoding>
@property NSString *orderNumber;
@property NSString *eventName;
@property TransferStatus status;
@property BOOL uploadThumbs, uploadFullsize;
@property NSDate *datePushed, *dateScheduled;
@property RunningTransferContext *context;
@end

@interface TransferManager : NSObject

- (void)processTransfers;
- (void)pushTransfer;
- (BOOL)save;

@property (readonly) NSMutableArray *transfers;
@property (readonly) Transfer *currentlyRunningTransfer;
@end
