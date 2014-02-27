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
    kImageTransferStateFixingOrientation,
    kImageTransferStateSendingFullSize,
    kImageTransferStatePostingFullSize,
};

@interface ImageTransferContext : NSObject {
    ImageTransferState state;
    NSInteger slot;
    RollModel *roll;
    FrameModel *frame;
    NSThread *imageProcessingThread;
    NSTask *ftpUploadTask;
    FullSizePostedService *fullSizePostedService;
    PostImageDataService *postImageDataService;
    UpdateVisibleService *updateVisibleService;
    NSData *fullsizeImage, *previewImage, *thumbnailImage, *pngImage, *mediumResImage;
    NSInteger previewWidth, previewHeight, pngWidth, pngHeight;
}

@property ImageTransferState state;
@property NSInteger slot;
@property RollModel *roll;
@property FrameModel *frame;
@property NSThread *imageProcessingThread;
@property NSTask *ftpUploadTask;
@property FullSizePostedService *fullSizePostedService;
@property PostImageDataService *postImageDataService;
@property UpdateVisibleService *updateVisibleService;
@property NSData *fullsizeImage, *previewImage, *thumbnailImage, *pngImage, *mediumResImage;
@property NSInteger previewWidth, previewHeight, pngWidth, pngHeight;
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
    NSInteger pendingRollIndex;
    NSInteger pendingFrameIndex;
    OrderModel *orderModel;
    EventRow *eventRow;
    NSString *ccsPassword;
    EventSettingsResult *eventSettings;
    VerifyOrderResult *verifyOrderResult;
    NSMutableArray *imageContexts;
}

@property RunningTransferState state;
@property NSInteger pendingRollIndex;
@property NSInteger pendingFrameIndex;
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
    ActivatePreviewsAndThumbsService *activatePreviewsAndThumbsService;
    ActivateFullSizeService *activateFullSizeService;
}

@property (readonly) NSMutableArray *transfers;
@property (readonly) Transfer *currentlyRunningTransfer;

@end
