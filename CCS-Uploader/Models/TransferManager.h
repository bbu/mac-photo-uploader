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

typedef NS_ENUM(NSInteger, ImageTransferState) {
    kImageTransferStateIdle = 0,
    kImageTransferStateGeneratingThumbs,
    kImageTransferStateSendingThumbs,
    kImageTransferStateSendingFullSize,
    kImageTransferStatePostingFullSize,
};

@interface ImageTransferContext : NSObject {
    ImageTransferState state;
    RollModel *roll;
    FrameModel *frame;
    NSThread *imageProcessingThread;
    NSTask *ftpUploadTask;
}

@property ImageTransferState state;
@property RollModel *roll;
@property FrameModel *frame;
@property NSThread *imageProcessingThread;
@property NSTask *ftpUploadTask;
@end

typedef NS_ENUM(NSInteger, RunningTransferState) {
    kRunningTransferStateIdle = 0,
    kRunningTransferStateSetup,
    kRunningTransferStateSendingThumbs,
    kRunningTransferStateActivatingThumbs,
    kRunningTransferStateSendingFullSize,
    kRunningTransferStateActivatingFullSize,
    kRunningTransferStateFinished,
};

@interface RunningTransferContext : NSObject {
    RunningTransferState state;
    RollModel *pendingRoll;
    FrameModel *pendingFrame;
    OrderModel *orderModel;
    EventRow *eventRow;
    NSString *ccsPassword;
    EventSettingsResult *eventSettings;
    VerifyOrderResult *verifyOrderResult;
    NSMutableArray *imageContexts;
}

@property RunningTransferState state;
@property RollModel *pendingRoll;
@property FrameModel *pendingFrame;
@property OrderModel *orderModel;
@property EventRow *eventRow;
@property NSString *ccsPassword;
@property EventSettingsResult *eventSettings;
@property VerifyOrderResult *verifyOrderResult;
@property NSMutableArray *imageContexts;
@end

typedef NS_ENUM(NSInteger, TransferStatus) {
    kTransferStatusQueued,
    kTransferStatusRunning,
    kTransferStatusScheduled,
    kTransferStatusAborted,
    kTransferStatusStopped,
    kTransferStatusComplete,
};

@interface Transfer : NSObject <NSCoding> {
    NSString *orderNumber;
    NSString *eventName;
    TransferStatus status;
    BOOL uploadThumbs, uploadFullsize;
    NSDate *datePushed, *dateScheduled;
    RunningTransferContext *context;
}

@property NSString *orderNumber;
@property NSString *eventName;
@property TransferStatus status;
@property BOOL uploadThumbs, uploadFullsize;
@property NSDate *datePushed, *dateScheduled;
@property RunningTransferContext *context;
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
