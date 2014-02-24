#import <Foundation/Foundation.h>

#import "OrderModel.h"

typedef NS_ENUM(NSInteger, TransferStatus) {
    kTransferStatusThumbsInProgress,
    kTransferStatusFullSizeInProgress,
    kTransferStatusScheduled,
    kTransferStatusAborted,
    kTransferStatusComplete,
};

@interface Transfer : NSObject <NSCoding> {
    NSString *orderNumber;
    NSString *eventName;
    TransferStatus status;
    NSDate *date;
    NSDate *thumbsScheduledDate, *fullSizeScheduledDate;

    OrderModel *orderModel;
}
@end

@interface TransfersModel : NSObject <NSCoding> {
    @private
    NSMutableArray *transfers;
}

@property (readonly) NSMutableArray *transfers;

@end
