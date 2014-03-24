#import <Foundation/Foundation.h>

@class RunningTransferContext;

typedef NS_ENUM(NSInteger, TransferStatus) {
    kTransferStatusRunning = 1,
    kTransferStatusQueued,
    kTransferStatusStopped,
    kTransferStatusScheduled,
    kTransferStatusErrors,
    kTransferStatusComplete,
    kTransferStatusAborted,
};

typedef NS_ENUM(NSInteger, TransferMode) {
    kTransferModeUnsent,
    kTransferModeAll,
    kTransferModeSelected,
    kTransferModeMissing,
};

@interface Transfer : NSObject <NSCoding>
@property NSString *orderNumber;
@property NSString *eventName;
@property TransferStatus status;
@property TransferMode mode;
@property BOOL uploadThumbs, thumbsUploaded, uploadFullsize, fullsizeUploaded;
@property NSDate *datePushed, *dateScheduled;
@property BOOL isQuicPost;
@property RunningTransferContext *context;
@property NSMutableString *errors;
@end

@interface TransferManager : NSObject

- (void)processTransfers;
- (BOOL)save;
- (void)stopCurrentTransfer;
- (void)reload;

@property (readonly) NSMutableArray *transfers;
@property (readonly) Transfer *currentlyRunningTransfer;
@property (assign) NSSet *openedEvents;

@property (nonatomic, copy) void (^reloadTransfers)(void);
@property (nonatomic, copy) void (^transferStateChanged)(NSString *message);
@property (nonatomic, copy) void (^startedUploadingImage)(NSInteger slot, NSString *pathToImage);
@property (nonatomic, copy) void (^endedUploadingImage)(NSInteger slot);
@property NSProgressIndicator *progressIndicator;
@property NSTextField *progressTitle;

@end
