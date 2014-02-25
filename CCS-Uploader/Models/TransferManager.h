#import <Foundation/Foundation.h>

#import "OrderModel.h"

#import "../Services/ListEventsService.h"
#import "../Services/CheckOrderNumberService.h"
#import "../Services/EventSettingsService.h"

#import "../Services/VerifyOrderService.h"
#import "../Services/FullSizePostedService.h"
#import "../Services/PostImageDataService.h"
#import "../Services/UpdateVisibleService.h"

#import "../Services/ActivatePreviewsAndThumbsService.h"
#import "../Services/ActivateFullSizeService.h"

#define kMaxThreads 8

typedef NS_ENUM(NSInteger, TransferStatus) {
    kTransferStatusQueued,
    kTransferStatusRunning,
    kTransferStatusScheduled,
    kTransferStatusAborted,
    kTransferStatusStopped,
    kTransferStatusComplete,
};

typedef NS_ENUM(NSInteger, RunningTransferState) {
    kRunningTransferState,
};

@interface Transfer : NSObject <NSCoding> {
    NSString *orderNumber;
    NSString *eventName;
    TransferStatus status;
    RunningTransferState state;
    BOOL uploadThumbs, uploadFullsize;
    NSDate *datePushed, *dateScheduled;

    OrderModel *orderModel;
    EventRow *eventRow;
    NSString *ccsPassword;
    EventSettingsResult *eventSettings;
}

@property NSString *orderNumber;
@property NSString *eventName;
@property TransferStatus status;
@property RunningTransferState state;
@property BOOL uploadThumbs, uploadFullsize;
@property NSDate *datePushed, *dateScheduled;
@property OrderModel *orderModel;
@end

@interface TransferManager : NSObject {
    @private
    NSMutableArray *transfers;
    Transfer *currentlyRunningTransfer;
    
    ListEventsService *listEventService;
    CheckOrderNumberService *checkOrderNumberService;
    EventSettingsService *eventSettingsService;
    
    VerifyOrderService *verifyOrderService;
    FullSizePostedService *fullSizePostedService[kMaxThreads];
    PostImageDataService *postImageDataService[kMaxThreads];
    UpdateVisibleService *updateVisibleService[kMaxThreads];
    
    ActivatePreviewsAndThumbsService *activatePreviewsAndThumbsService;
    ActivateFullSizeService *activateFullSizeService;
    
}

@property (readonly) NSMutableArray *transfers;
@property (readonly) Transfer *currentlyRunningTransfer;

@end
