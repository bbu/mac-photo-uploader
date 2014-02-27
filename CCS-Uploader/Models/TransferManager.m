#import "TransferManager.h"
#import "../Utils/ImageUtil.h"

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

#define kTransfersDataFile @"transfers.ccstransfers"
#define kMaxThreads 8

#pragma mark - ImageTransferContext

typedef NS_ENUM(NSInteger, ImageTransferState) {
    kImageTransferStateIdle = 0,
    kImageTransferStateGeneratingThumbs,
    kImageTransferStateSendingThumbs,
    kImageTransferStateFixingOrientation,
    kImageTransferStateSendingFullSize,
    kImageTransferStatePostingFullSize,
};

@interface ImageTransferContext : NSObject
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

@implementation ImageTransferContext
@end

#pragma mark - RunningTransferContext

typedef NS_ENUM(NSInteger, RunningTransferState) {
    kRunningTransferStateIdle = 0,
    kRunningTransferStateSetup,
    kRunningTransferStateSendingThumbs,
    kRunningTransferStateActivatingThumbs,
    kRunningTransferStateSendingFullSize,
    kRunningTransferStateActivatingFullSize,
    kRunningTransferStateFinished,
};

@interface RunningTransferContext : NSObject
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

@implementation RunningTransferContext
@end

#pragma mark - Transfer

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

@implementation Transfer

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        _orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        _eventName = [decoder decodeObjectForKey:@"eventName"];
        _status = [decoder decodeIntegerForKey:@"status"];
        _uploadThumbs = [decoder decodeBoolForKey:@"uploadThumbs"];
        _uploadFullsize = [decoder decodeBoolForKey:@"uploadFullsize"];
        _datePushed = [decoder decodeObjectForKey:@"datePushed"];
        _dateScheduled = [decoder decodeObjectForKey:@"dateScheduled"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_orderNumber forKey:@"orderNumber"];
    [encoder encodeObject:_eventName forKey:@"eventName"];
    [encoder encodeInteger:_status forKey:@"status"];
    [encoder encodeBool:_uploadThumbs forKey:@"uploadThumbs"];
    [encoder encodeBool:_uploadFullsize forKey:@"uploadFullsize"];
    [encoder encodeObject:_datePushed forKey:@"datePushed"];
    [encoder encodeObject:_dateScheduled forKey:@"dateScheduled"];
}

@end

#pragma mark - TransferManager

@implementation TransferManager {
    NSMutableArray *transfers;
    Transfer *currentlyRunningTransfer;
    ListEventsService *listEventService;
    CheckOrderNumberService *checkOrderNumberService;
    EventSettingsService *eventSettingsService;
    VerifyOrderService *verifyOrderService;
    ActivatePreviewsAndThumbsService *activatePreviewsAndThumbsService;
    ActivateFullSizeService *activateFullSizeService;
}

@synthesize transfers;
@synthesize currentlyRunningTransfer;

- (id)init
{
    self = [super init];
    
    if (self) {
        NSString *pathToDataFile = [FileUtil pathForDataFile:kTransfersDataFile];
        
        if (!pathToDataFile) {
            NSLog(@"Could not obtain path to transfers data file!");
            return nil;
        }
        
        transfers = [NSKeyedUnarchiver unarchiveObjectWithFile:pathToDataFile];
        
        if (!transfers) {
            transfers = [NSMutableArray new];
            [NSKeyedArchiver archiveRootObject:transfers toFile:pathToDataFile];
        }
        
        listEventService = [ListEventsService new];
        checkOrderNumberService = [CheckOrderNumberService new];
        eventSettingsService = [EventSettingsService new];
        verifyOrderService = [VerifyOrderService new];
        activatePreviewsAndThumbsService = [ActivatePreviewsAndThumbsService new];
        activateFullSizeService = [ActivateFullSizeService new];
    }
    
    return self;
}

- (void)abortTransfer:(NSString *)message
{
    [currentlyRunningTransfer.context.orderModel save];
    currentlyRunningTransfer.status = kTransferStatusAborted;
    currentlyRunningTransfer.context = nil;
    currentlyRunningTransfer = nil;
}

- (BOOL)nextPendingFrame
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    for (NSInteger i = context.pendingRollIndex; i < context.orderModel.rolls.count; ++i) {
        RollModel *roll = context.orderModel.rolls[i];
        
        for (NSInteger j = context.pendingFrameIndex; j < roll.frames.count; ++j) {
            FrameModel *frame = roll.frames[j];
            
            if (context.state == kRunningTransferStateSendingThumbs ? !frame.thumbsSent : !frame.fullsizeSent) {
                context.pendingRollIndex = i;
                context.pendingFrameIndex = j;
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)processImage:(ImageTransferContext *)imageContext
{
    EventSettingsResult *eventSettings = currentlyRunningTransfer.context.eventSettings;
    OrderModel *orderModel = currentlyRunningTransfer.context.orderModel;
    BOOL processed;
    
    NSString *pathToFullSizeImage = [[[orderModel.rootDir stringByAppendingPathComponent:imageContext.roll.number]
        stringByAppendingPathComponent:imageContext.frame.name] stringByAppendingPathExtension:imageContext.frame.extension];
    
    if (imageContext.frame.orientation > 1) {
        [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:pathToFullSizeImage
            resizeToMaxSide:0 rotate:kDontRotate compressionQuality:0.8];
        
        CGSize newSize = CGSizeZero;
        NSUInteger orientation;
        [ImageUtil getImageProperties:pathToFullSizeImage size:&newSize type:imageContext.frame.imageType orientation:&orientation];
        
        imageContext.frame.width = newSize.width;
        imageContext.frame.height = newSize.height;
        
        NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:pathToFullSizeImage error:nil];
        
        if (fileAttrs) {
            imageContext.roll.totalFrameSize -= imageContext.frame.filesize;
            imageContext.frame.lastModified = fileAttrs.fileModificationDate;
            imageContext.frame.filesize = fileAttrs.fileSize;
            imageContext.roll.totalFrameSize += imageContext.frame.filesize;
        } else {
        }
        
        imageContext.frame.fullsizeSent = NO;
        imageContext.frame.thumbsSent = NO;
        imageContext.frame.orientation = 1;
    }
    
    if (imageContext.state == kImageTransferStateGeneratingThumbs) {
        imageContext.fullsizeImage = nil;
        imageContext.previewImage = nil;
        imageContext.thumbnailImage = nil;
        imageContext.pngImage = nil;
        imageContext.mediumResImage = nil;
        imageContext.previewWidth = 0;
        imageContext.previewHeight = 0;
        imageContext.pngWidth = 0;
        imageContext.pngHeight = 0;
        
        if (eventSettings.transferSettings.createThumbnail && eventSettings.thumbnailSettings) {
            NSString *thumbnailFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccsthumb_%ld", imageContext.slot];

            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:thumbnailFilename
                resizeToMaxSide:eventSettings.thumbnailSettings.maxSide rotate:kDontRotate
                compressionQuality:eventSettings.thumbnailSettings.quality / 100.];
            
            if (processed) {
                imageContext.thumbnailImage = [NSData dataWithContentsOfFile:thumbnailFilename];
            }

            [[NSFileManager defaultManager] removeItemAtPath:thumbnailFilename error:nil];
        }
        
        if (eventSettings.transferSettings.createMediumRes && eventSettings.mediumResSettings) {
            NSString *mediumResFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccsmedium_%ld", imageContext.slot];

            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:mediumResFilename
                resizeToMaxSide:eventSettings.mediumResSettings.maxSide rotate:kDontRotate
                compressionQuality:eventSettings.mediumResSettings.quality / 100.];
            
            if (processed) {
                imageContext.mediumResImage = [NSData dataWithContentsOfFile:mediumResFilename];
            }

            [[NSFileManager defaultManager] removeItemAtPath:mediumResFilename error:nil];
        }
        
        if (eventSettings.transferSettings.createPreview && eventSettings.previewSettings) {
            NSString *previewFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccspreview_%ld", imageContext.slot];

            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:previewFilename
                resizeToMaxSide:eventSettings.previewSettings.maxSide rotate:kDontRotate
                compressionQuality:eventSettings.previewSettings.quality / 100.];
            
            if (processed) {
                imageContext.previewImage = [NSData dataWithContentsOfFile:previewFilename];
                CGSize size = CGSizeZero;
                NSUInteger orientation;
                
                if ([ImageUtil getImageProperties:previewFilename size:&size type:nil orientation:&orientation]) {
                    imageContext.previewWidth = size.width;
                    imageContext.previewHeight = size.height;
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:previewFilename error:nil];
        }
    } else if (imageContext.state == kImageTransferStateFixingOrientation) {
    }
}

- (NSArray *)curlParameters:(ImageTransferContext *)imageContext
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    OrderModel *orderModel = context.orderModel;
    
    NSString *pathToFullSizeImage = [[[orderModel.rootDir stringByAppendingPathComponent:imageContext.roll.number]
        stringByAppendingPathComponent:imageContext.frame.name] stringByAppendingPathExtension:imageContext.frame.extension];
    
    NSString *ftpDestinationPath = [NSString stringWithFormat:@"ftp://%@/%@/%@",
        context.verifyOrderResult.remoteHost,
        context.verifyOrderResult.remoteDirectory,
        @""
    ];
    
    NSString *ftpCredentials = [NSString stringWithFormat:@"%@:%@",
        context.verifyOrderResult.username,
        context.verifyOrderResult.password
    ];
    
    return @[@"-T", pathToFullSizeImage, ftpDestinationPath, @"--user", ftpCredentials, @"--silent"];
}

- (void)process
{
    if (!currentlyRunningTransfer) {
        currentlyRunningTransfer = [self nextRunnableTransfer];
        
        if (!currentlyRunningTransfer) {
            return;
        }
    }
    
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    switch (context.state) {
        case kRunningTransferStateIdle: {
            context.state = kRunningTransferStateSetup;
        } break;
            
        case kRunningTransferStateSetup: {
            if ([self setupRunningTransfer]) {
                if (currentlyRunningTransfer.uploadThumbs) {
                    context.state = kRunningTransferStateSendingThumbs;
                } else if (currentlyRunningTransfer.uploadFullsize) {
                    context.state = kRunningTransferStateSendingFullSize;
                } else {
                    context.state = kRunningTransferStateFinished;
                }
            }
        } break;
            
        case kRunningTransferStateSendingThumbs: {
            NSInteger numIdleSlots = 0;
            
            for (ImageTransferContext *imageContext in context.imageContexts) {
                switch (imageContext.state) {
                    case kImageTransferStateIdle: {
                        if ([self nextPendingFrame]) {
                            imageContext.roll = context.orderModel.rolls[context.pendingRollIndex];
                            imageContext.frame = imageContext.roll.frames[context.pendingFrameIndex];
                            imageContext.state = kImageTransferStateGeneratingThumbs;
                            [imageContext.imageProcessingThread start];
                        } else {
                            numIdleSlots++;
                        }
                    } break;
                        
                    case kImageTransferStateGeneratingThumbs: {
                        if ([imageContext.imageProcessingThread isFinished]) {
                            imageContext.state = kImageTransferStateSendingThumbs;
                        }
                    } break;
                        
                    case kImageTransferStateSendingThumbs: {
                        if (![imageContext.postImageDataService isRunning]) {
                            [imageContext.postImageDataService
                                startPostImageData:context.eventRow.ccsAccount
                                password:context.ccsPassword
                                orderNumber:currentlyRunningTransfer.orderNumber
                                roll:imageContext.roll.number
                                frame:imageContext.frame.name
                                extension:imageContext.frame.extension
                                version:@"CCSTransfer 3.0.1.7"
                                bypassPassword:NO
                                fullsizeImage:imageContext.fullsizeImage
                                previewImage:imageContext.previewImage
                                thumbnailImage:imageContext.thumbnailImage
                                pngImage:imageContext.pngImage
                                mediumResImage:imageContext.mediumResImage
                                originalImageSize:imageContext.frame.filesize
                                originalWidth:imageContext.frame.width
                                originalHeight:imageContext.frame.height
                                previewWidth:imageContext.previewWidth
                                previewHeight:imageContext.previewHeight
                                pngWidth:imageContext.pngWidth
                                pngHeight:imageContext.pngHeight
                                photographer:@""
                                photoDateTime:imageContext.frame.lastModified
                                createPreviewAndThumb:NO
                                complete:^(PostImageDataResult *result) {
                                    if (!result.error && [result.status isEqualToString:@"Successful"]) {
                                        imageContext.frame.thumbsSent = YES;
                                    } else {
                                        
                                    }
                                    
                                    imageContext.state = kImageTransferStateIdle;
                                }
                            ];
                        }
                    } break;
                        
                    default: break;
                }
            }
            
            if (numIdleSlots == context.imageContexts.count) {
                context.pendingRollIndex = 0;
                context.pendingFrameIndex = 0;
                context.state = kRunningTransferStateActivatingThumbs;
            }
        } break;
            
        case kRunningTransferStateActivatingThumbs: {
            if (![activatePreviewsAndThumbsService isRunning]) {
                [activatePreviewsAndThumbsService
                    startActivatePreviewsAndThumbs:context.eventRow.ccsAccount
                    password:context.ccsPassword
                    orderNumber:currentlyRunningTransfer.orderNumber
                    complete:^(ActivatePreviewsAndThumbsResult *result) {
                        if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                            if (currentlyRunningTransfer.uploadFullsize) {
                                context.state = kRunningTransferStateSendingFullSize;
                            } else {
                                context.state = kRunningTransferStateFinished;
                            }
                        } else {
                            [self abortTransfer:@"Unable to activate thumbs."];
                        }
                    }
                ];
            }
        } break;
            
        case kRunningTransferStateSendingFullSize: {
            NSInteger numIdleSlots = 0;
            
            for (ImageTransferContext *imageContext in context.imageContexts) {
                switch (imageContext.state) {
                    case kImageTransferStateIdle: {
                        if ([self nextPendingFrame]) {
                            imageContext.roll = context.orderModel.rolls[context.pendingRollIndex];
                            imageContext.frame = imageContext.roll.frames[context.pendingFrameIndex];
                            
                            if (imageContext.frame.orientation > 1) {
                                imageContext.state = kImageTransferStateFixingOrientation;
                                [imageContext.imageProcessingThread start];
                            } else {
                                imageContext.state = kImageTransferStateSendingFullSize;
                                imageContext.ftpUploadTask.arguments = [self curlParameters:imageContext];
                                [imageContext.ftpUploadTask launch];
                            }
                        } else {
                            numIdleSlots++;
                        }
                    } break;
                    
                    case kImageTransferStateFixingOrientation: {
                        if ([imageContext.imageProcessingThread isFinished]) {
                            imageContext.state = kImageTransferStateSendingFullSize;
                            imageContext.ftpUploadTask.arguments = [self curlParameters:imageContext];
                            [imageContext.ftpUploadTask launch];
                        }
                    } break;

                    case kImageTransferStateSendingFullSize: {
                        if (![imageContext.ftpUploadTask isRunning]) {
                            if (!imageContext.ftpUploadTask.terminationStatus) {
                                imageContext.state = kImageTransferStatePostingFullSize;
                            } else {
                                imageContext.state = kImageTransferStateIdle;
                            }
                        }
                    } break;
                        
                    case kImageTransferStatePostingFullSize: {
                        if (![imageContext.fullSizePostedService isRunning]) {
                            [imageContext.fullSizePostedService
                                startFullSizePosted:context.eventRow.ccsAccount
                                password:context.ccsPassword
                                orderNumber:currentlyRunningTransfer.orderNumber
                                roll:imageContext.roll.number
                                frame:imageContext.frame.name
                                filename:[imageContext.frame.name stringByAppendingPathExtension:imageContext.frame.extension]
                                version:@""
                                bypassPassword:NO
                                createPreviewAndThumb:NO
                                complete:^(FullSizePostedResult *result) {
                                    if (!result.error && [result.status isEqualToString:@"Successful"]) {
                                        imageContext.frame.fullsizeSent = YES;
                                    } else {
                                        
                                    }
                                    
                                    imageContext.state = kImageTransferStateIdle;
                                }
                            ];
                        }
                    } break;

                    default: break;
                }
            }
            
            if (numIdleSlots == context.imageContexts.count) {
                context.pendingRollIndex = 0;
                context.pendingFrameIndex = 0;
                context.state = kRunningTransferStateActivatingFullSize;
            }
        } break;

        case kRunningTransferStateActivatingFullSize: {
            if (![activateFullSizeService isRunning]) {
                [activateFullSizeService
                    startActivateFullSize:context.eventRow.ccsAccount
                    password:context.ccsPassword
                    orderNumber:currentlyRunningTransfer.orderNumber
                    complete:^(ActivateFullSizeResult *result) {
                        if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                            context.state = kRunningTransferStateFinished;
                        } else {
                            [self abortTransfer:@"Unable to activate full-size images."];
                        }
                    }
                ];
            }
        } break;
            
        case kRunningTransferStateFinished: {
            [currentlyRunningTransfer.context.orderModel save];
            currentlyRunningTransfer.status = kTransferStatusComplete;
            currentlyRunningTransfer.context = nil;
            currentlyRunningTransfer = nil;
        } break;
    }
}

- (BOOL)setupRunningTransfer
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    if (!context.eventRow) {
        [listEventService
            startListEvent:@"ccsmacuploader"
            password:@"candid123"
            orderNumber:currentlyRunningTransfer.orderNumber
            complete:^(ListEventsResult *result) {
                if (!result.error && result.loginSuccess && result.processSuccess && result.events.count == 1) {
                    context.eventRow = result.events[0];
                } else {
                    [self abortTransfer:@"Unable to list event."];
                }
            }
        ];
        
        return NO;
    }
    
    if (!context.ccsPassword) {
        [checkOrderNumberService
            startCheckOrderNumber:@"ccsmacuploader"
            password:@"candid123"
            orderNumber:currentlyRunningTransfer.orderNumber
            complete:^(CheckOrderNumberResult *result) {
                if (!result.error && result.loginSuccess && result.processSuccess) {
                    context.ccsPassword = result.ccsPassword;
                } else {
                    [self abortTransfer:@"Unable to fetch CCS password."];
                }
            }
        ];
        
        return NO;
    }
    
    if (!context.eventSettings) {
        [eventSettingsService
            startGetEventSettings:context.eventRow.ccsAccount
            password:context.ccsPassword
            orderNumber:currentlyRunningTransfer.orderNumber
            complete:^(EventSettingsResult *result) {
                if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                    context.eventSettings = result;
                } else {
                    [self abortTransfer:@"Unable to fetch event settings."];
                }
            }
        ];
        
        return NO;
    }
    
    if (!context.verifyOrderResult) {
        [verifyOrderService
            startVerifyOrder:context.eventRow.ccsAccount
            password:context.ccsPassword
            orderNumber:currentlyRunningTransfer.orderNumber
            version:@"CCSTransfer 3.0.1.7"
            bypassPassword:NO
            complete:^(VerifyOrderResult *result) {
                if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                    context.verifyOrderResult = result;
                } else {
                    [self abortTransfer:@"Unable to verify order."];
                }
            }
        ];
        
        return NO;
    }
    
    if (!context.orderModel) {
        NSError *error = nil;
        context.orderModel = [[OrderModel alloc] initWithEventRow:context.eventRow error:&error];
        
        if (!context.orderModel) {
            [self abortTransfer:@"Unable to create order model."];
            return NO;
        }
        
        [context.orderModel ignoreNewlyAdded];
    }
    
    return YES;
}

- (Transfer *)nextRunnableTransfer
{
    Transfer *(^initRunningTransfer)(Transfer *transfer) = ^(Transfer *transfer) {
        transfer.status = kTransferStatusRunning;
        transfer.context = [RunningTransferContext new];
        transfer.context.imageContexts = [NSMutableArray new];
        
        for (NSInteger i = 0; i < kMaxThreads; ++i) {
            ImageTransferContext *imageTransferContext = [ImageTransferContext new];
            
            imageTransferContext.slot = i;
            imageTransferContext.ftpUploadTask = [NSTask new];
            imageTransferContext.ftpUploadTask.launchPath = @"/usr/bin/curl";

            imageTransferContext.imageProcessingThread = [[NSThread alloc] initWithTarget:self
                selector:@selector(processImage:) object:imageTransferContext];
            
            imageTransferContext.fullSizePostedService = [FullSizePostedService new];
            imageTransferContext.postImageDataService = [PostImageDataService new];
            imageTransferContext.updateVisibleService = [UpdateVisibleService new];
            
            [transfer.context.imageContexts addObject:imageTransferContext];
        }
        
        return transfer;
    };
    
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusRunning) {
            return initRunningTransfer(transfer);
        }
    }
    
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusQueued) {
            return initRunningTransfer(transfer);
        }
    }
    
    NSDate *now = [NSDate date];

    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusScheduled) {
            NSComparisonResult cmp = [now compare:transfer.dateScheduled];
            
            if (cmp == NSOrderedSame || cmp == NSOrderedDescending) {
                return initRunningTransfer(transfer);
            }
        }
    }

    return nil;
}

- (void)pushTransfer
{
    
}

- (BOOL)save
{
    NSString *pathToDataFile = [FileUtil pathForDataFile:kTransfersDataFile];
    
    if (!pathToDataFile) {
        return NO;
    }
    
    return [NSKeyedArchiver archiveRootObject:transfers toFile:pathToDataFile] &&
        (currentlyRunningTransfer.context.orderModel ? [currentlyRunningTransfer.context.orderModel save] : YES);
}

@end
