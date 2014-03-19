#import "TransferManager.h"
#import "../Utils/ImageUtil.h"
#import "../Utils/FileUtil.h"

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
@property NSString *fileNameOnFtpServer;
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
@property NSString *effectiveUser, *effectivePass;
@property EventRow *eventRow;
@property NSString *ccsPassword;
@property EventSettingsResult *eventSettings;
@property VerifyOrderResult *verifyOrderResult;
@property NSMutableArray *imageContexts;
@property BOOL estimated;
@property NSInteger imagesSent, sizeSent, totalCount, totalSize;
@end

@implementation RunningTransferContext
@end

#pragma mark - Transfer

@implementation Transfer

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        _orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        _eventName = [decoder decodeObjectForKey:@"eventName"];
        _status = [decoder decodeIntegerForKey:@"status"];
        _uploadThumbs = [decoder decodeBoolForKey:@"uploadThumbs"];
        _thumbsUploaded = [decoder decodeBoolForKey:@"thumbsUploaded"];
        _uploadFullsize = [decoder decodeBoolForKey:@"uploadFullsize"];
        _fullsizeUploaded = [decoder decodeBoolForKey:@"fullsizeUploaded"];
        _datePushed = [decoder decodeObjectForKey:@"datePushed"];
        _dateScheduled = [decoder decodeObjectForKey:@"dateScheduled"];
        _isQuicPost = [decoder decodeBoolForKey:@"isQuicPost"];
        _errors = [decoder decodeObjectForKey:@"errors"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_orderNumber forKey:@"orderNumber"];
    [encoder encodeObject:_eventName forKey:@"eventName"];
    [encoder encodeInteger:_status forKey:@"status"];
    [encoder encodeBool:_uploadThumbs forKey:@"uploadThumbs"];
    [encoder encodeBool:_thumbsUploaded forKey:@"thumbsUploaded"];
    [encoder encodeBool:_uploadFullsize forKey:@"uploadFullsize"];
    [encoder encodeBool:_fullsizeUploaded forKey:@"fullsizeUploaded"];
    [encoder encodeObject:_datePushed forKey:@"datePushed"];
    [encoder encodeObject:_dateScheduled forKey:@"dateScheduled"];
    [encoder encodeBool:_isQuicPost forKey:@"isQuicPost"];
    [encoder encodeObject:_errors forKey:@"errors"];
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
@synthesize reloadTransfers;
@synthesize transferStateChanged;
@synthesize startedUploadingImage;
@synthesize endedUploadingImage;
@synthesize progressIndicator;
@synthesize progressTitle;

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
        [listEventService setEffectiveServiceRoot:kServiceRootCore coreDomain:kDefaultCoreDomain];
        checkOrderNumberService = [CheckOrderNumberService new];
        [checkOrderNumberService setEffectiveServiceRoot:kServiceRootCore coreDomain:kDefaultCoreDomain];
        eventSettingsService = [EventSettingsService new];
        [eventSettingsService setEffectiveServiceRoot:kServiceRootCore coreDomain:kDefaultCoreDomain];

        verifyOrderService = [VerifyOrderService new];
        activatePreviewsAndThumbsService = [ActivatePreviewsAndThumbsService new];
        activateFullSizeService = [ActivateFullSizeService new];
    }
    
    return self;
}

- (void)abortTransferWithError:(NSString *)message
{
    [currentlyRunningTransfer.context.orderModel save];
    [currentlyRunningTransfer.errors appendString:message];
    currentlyRunningTransfer.status = kTransferStatusAborted;
    currentlyRunningTransfer.context = nil;
    reloadTransfers();
    currentlyRunningTransfer = nil;
}

- (BOOL)nextPendingFrame
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    for (NSInteger i = context.pendingRollIndex; i < context.orderModel.rolls.count; ++i) {
        RollModel *roll = context.orderModel.rolls[i];
        
        for (NSInteger j = context.pendingFrameIndex; j < roll.frames.count; ++j) {
            FrameModel *frame = roll.frames[j];
            BOOL conditionToSend;
            
            if (context.state == kRunningTransferStateSendingThumbs) {
                conditionToSend = !frame.thumbsSent && !frame.imageErrors.length;
            } else {
                conditionToSend = !frame.fullsizeSent && !frame.imageErrors.length;
            }
            
            if (conditionToSend) {
                context.pendingRollIndex = i;
                context.pendingFrameIndex = j;
                return YES;
            }
        }
        
        context.pendingRollIndex++;
        context.pendingFrameIndex = 0;
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
            resizeToMaxSide:0 rotate:kDontRotate horizontalWatermark:nil verticalWatermark:nil compressionQuality:0.82];
        
        CGSize newSize = CGSizeZero;
        NSUInteger orientation;
        [ImageUtil getImageProperties:pathToFullSizeImage size:&newSize type:imageContext.frame.imageType orientation:&orientation errors:nil];
        
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
        imageContext.previewWidth = -1;
        imageContext.previewHeight = -1;
        imageContext.pngWidth = -1;
        imageContext.pngHeight = -1;
        
        if (eventSettings.transferSettings.createThumbnail && eventSettings.thumbnailSettings) {
            NSString *thumbnailFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccsthumb_%ld", imageContext.slot];
            NSData *hWatermark = nil, *vWatermark = nil;
            
            if (eventSettings.watermarkSettings && eventSettings.transferSettings.thumbnailWatermarkID == eventSettings.watermarkSettings.watermarkID) {
                hWatermark = eventSettings.watermarkSettings.hFileData;
                vWatermark = eventSettings.watermarkSettings.vFileData;
            }
            
            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:thumbnailFilename
                resizeToMaxSide:eventSettings.thumbnailSettings.maxSide rotate:kDontRotate
                horizontalWatermark:hWatermark verticalWatermark:vWatermark
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
                horizontalWatermark:nil verticalWatermark:nil
                compressionQuality:eventSettings.mediumResSettings.quality / 100.];
            
            if (processed) {
                imageContext.mediumResImage = [NSData dataWithContentsOfFile:mediumResFilename];
            }

            [[NSFileManager defaultManager] removeItemAtPath:mediumResFilename error:nil];
        }
        
        if (eventSettings.transferSettings.createPreview && eventSettings.previewSettings) {
            NSString *previewFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccspreview_%ld", imageContext.slot];
            NSData *hWatermark = nil, *vWatermark = nil;

            if (eventSettings.watermarkSettings && eventSettings.transferSettings.previewWatermarkID == eventSettings.watermarkSettings.watermarkID) {
                hWatermark = eventSettings.watermarkSettings.hFileData;
                vWatermark = eventSettings.watermarkSettings.vFileData;
            }
            
            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:previewFilename
                resizeToMaxSide:eventSettings.previewSettings.maxSide rotate:kDontRotate
                horizontalWatermark:hWatermark verticalWatermark:vWatermark
                compressionQuality:eventSettings.previewSettings.quality / 100.];
            
            if (processed) {
                imageContext.previewImage = [NSData dataWithContentsOfFile:previewFilename];
                CGSize size = CGSizeZero;
                NSUInteger orientation;
                
                if ([ImageUtil getImageProperties:previewFilename size:&size type:nil orientation:&orientation errors:nil]) {
                    imageContext.previewWidth = size.width;
                    imageContext.previewHeight = size.height;
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:previewFilename error:nil];
        }
        
        if (eventSettings.pngSettings) {
            NSString *pngFilename = [pathToFullSizeImage stringByAppendingFormat:@"_ccspng_%ld.png", imageContext.slot];
            
            processed = [ImageUtil resizeAndRotateImage:pathToFullSizeImage outputImageFilename:pngFilename
                resizeToMaxSide:eventSettings.pngSettings.maxSide rotate:kDontRotate
                horizontalWatermark:nil verticalWatermark:nil
                compressionQuality:eventSettings.pngSettings.quality / 100.];
            
            if (processed) {
                imageContext.pngImage = [NSData dataWithContentsOfFile:pngFilename];
                CGSize size = CGSizeZero;
                NSUInteger orientation;
                
                if ([ImageUtil getImageProperties:pngFilename size:&size type:nil orientation:&orientation errors:nil]) {
                    imageContext.pngWidth = size.width;
                    imageContext.pngHeight = size.height;
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:pngFilename error:nil];
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
    
    imageContext.fileNameOnFtpServer = [NSString stringWithFormat:@"%@_%@_%@_%08lu.%@",
        currentlyRunningTransfer.orderNumber,
        imageContext.roll.number,
        imageContext.frame.name,
        [NSDate date].hash,
        imageContext.frame.extension
    ];
    
    NSString *ftpDestinationPath = [NSString stringWithFormat:@"ftp://%@/%@/%@",
        context.verifyOrderResult.remoteHost,
        context.verifyOrderResult.remoteDirectory,
        imageContext.fileNameOnFtpServer
    ];
    
    NSString *ftpCredentials = [NSString stringWithFormat:@"%@:%@",
        context.verifyOrderResult.username,
        context.verifyOrderResult.password
    ];
    
    return @[@"-T", pathToFullSizeImage, ftpDestinationPath, @"--user", ftpCredentials, @"--silent"];
}

- (void)estimateTransfer
{
    RunningTransferContext *context = currentlyRunningTransfer.context;

    progressTitle.stringValue = @"";
    progressIndicator.minValue = 0;
    progressIndicator.doubleValue = 0;
    
    context.totalCount = 0;
    context.totalSize = 0;
    context.imagesSent = 0;
    context.sizeSent = 0;

    if (context.state == kRunningTransferStateSendingThumbs) {
        for (RollModel *roll in context.orderModel.rolls) {
            for (FrameModel *frame in roll.frames) {
                if (!frame.thumbsSent && !frame.imageErrors.length) {
                    context.totalCount++;
                }
            }
        }
        
        progressIndicator.maxValue = context.totalCount;
    } else if (context.state == kRunningTransferStateSendingFullSize) {
        for (RollModel *roll in context.orderModel.rolls) {
            for (FrameModel *frame in roll.frames) {
                if (!frame.fullsizeSent && !frame.imageErrors.length) {
                    context.totalCount++;
                    context.totalSize += frame.filesize;
                }
            }
        }
        
        progressIndicator.maxValue = context.totalSize;
    }
    
    context.estimated = YES;
}

- (void)processTransfers
{
    if (!currentlyRunningTransfer) {
        currentlyRunningTransfer = [self nextRunnableTransfer];
        
        if (!currentlyRunningTransfer) {
            return;
        }
        
        reloadTransfers();
    }
    
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    switch (context.state) {
        case kRunningTransferStateIdle: {
            transferStateChanged(@"Setting up transfer");
            context.state = kRunningTransferStateSetup;
        } break;
            
        case kRunningTransferStateSetup: {
            if ([self setupRunningTransfer]) {
                if (currentlyRunningTransfer.uploadThumbs) {
                    transferStateChanged(@"Sending previews and thumbnails");
                    context.state = kRunningTransferStateSendingThumbs;
                } else if (currentlyRunningTransfer.uploadFullsize) {
                    transferStateChanged(@"Sending full-size images");
                    context.state = kRunningTransferStateSendingFullSize;
                } else {
                    transferStateChanged(@"Finished");
                    context.state = kRunningTransferStateFinished;
                }
            }
        } break;
            
        case kRunningTransferStateSendingThumbs: {
            NSInteger numIdleSlots = 0;
            
            if (!context.estimated) {
                [self estimateTransfer];
            }
            
            for (ImageTransferContext *imageContext in context.imageContexts) {
                switch (imageContext.state) {
                    case kImageTransferStateIdle: {
                        if ([self nextPendingFrame]) {
                            imageContext.roll = context.orderModel.rolls[context.pendingRollIndex];
                            imageContext.frame = imageContext.roll.frames[context.pendingFrameIndex++];
                            imageContext.state = kImageTransferStateGeneratingThumbs;
                            
                            imageContext.imageProcessingThread = [[NSThread alloc] initWithTarget:self
                                selector:@selector(processImage:) object:imageContext];
                            
                            [imageContext.imageProcessingThread start];
                        } else {
                            numIdleSlots++;
                        }
                    } break;
                        
                    case kImageTransferStateGeneratingThumbs: {
                        if (imageContext.imageProcessingThread.isFinished) {
                            imageContext.state = kImageTransferStateSendingThumbs;
                            
                            NSString *pathToFullSizeImage = [[[context.orderModel.rootDir stringByAppendingPathComponent:imageContext.roll.number]
                                stringByAppendingPathComponent:imageContext.frame.name] stringByAppendingPathExtension:imageContext.frame.extension];
                            
                            startedUploadingImage(imageContext.slot, pathToFullSizeImage);
                        }
                    } break;
                        
                    case kImageTransferStateSendingThumbs: {
                        if (!imageContext.postImageDataService.started) {
                            [imageContext.postImageDataService
                                startPostImageData:context.eventRow.ccsAccount
                                password:context.ccsPassword
                                orderNumber:currentlyRunningTransfer.orderNumber
                                roll:imageContext.roll.number
                                frame:imageContext.frame.name
                                extension:imageContext.frame.extension
                                version:@"CCSUploaderMac 1.0"
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
                                photographer:imageContext.roll.photographer
                                photoDateTime:imageContext.frame.lastModified
                                createPreviewAndThumb:NO
                                complete:^(PostImageDataResult *result) {
                                    if (!result.error && [result.status isEqualToString:@"Successful"]) {
                                        imageContext.frame.thumbsSent = YES;
                                        context.imagesSent++;
                                        
                                        progressTitle.stringValue = [NSString stringWithFormat:@"%ld of %ld thumbs sent",
                                            context.imagesSent, context.totalCount];
                                        
                                        progressIndicator.doubleValue++;
                                    } else {
                                        if (result.error) {
                                            [currentlyRunningTransfer.errors appendFormat:
                                                @"%@/%@.%@: could not send thumbnails, an error occurred: %@\r",
                                                imageContext.roll.number, imageContext.frame.name, imageContext.frame.extension,
                                                result.error.localizedDescription];
                                        } else {
                                            [currentlyRunningTransfer.errors appendFormat:
                                                @"%@/%@.%@: could not send thumbnails, the server returned \"%@\" with a status of \"%@\"\r\r",
                                                imageContext.roll.number, imageContext.frame.name, imageContext.frame.extension,
                                                result.message, result.status];
                                        }
                                    }
                                    
                                    endedUploadingImage(imageContext.slot);
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
                context.estimated = NO;
                progressIndicator.doubleValue = 0;
                progressIndicator.minValue = 0;
                progressIndicator.maxValue = 1;
                progressTitle.stringValue = @"";
                transferStateChanged(@"Activating previews and thumbnails");
                context.state = kRunningTransferStateActivatingThumbs;
            }
        } break;
            
        case kRunningTransferStateActivatingThumbs: {
            if (!activatePreviewsAndThumbsService.started) {
                [activatePreviewsAndThumbsService
                    startActivatePreviewsAndThumbs:context.eventRow.ccsAccount
                    password:context.ccsPassword
                    orderNumber:currentlyRunningTransfer.orderNumber
                    complete:^(ActivatePreviewsAndThumbsResult *result) {
                        if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                            currentlyRunningTransfer.thumbsUploaded = YES;
                        } else {
                            if (result.error) {
                                [currentlyRunningTransfer.errors appendFormat:
                                    @"Could not activate thumbs and previews, an error occurred: %@\r",
                                    result.error.localizedDescription];
                            } else {
                                [currentlyRunningTransfer.errors appendFormat:
                                    @"Could not activate thumbs and previews, the server returned \"%@\" with a status of \"%@\"\r",
                                    result.message, result.status];
                            }
                        }
                        
                        if (currentlyRunningTransfer.uploadFullsize) {
                            transferStateChanged(@"Sending full-size images");
                            context.state = kRunningTransferStateSendingFullSize;
                        } else {
                            transferStateChanged(@"Finished");
                            context.state = kRunningTransferStateFinished;
                        }

                        reloadTransfers();
                    }
                ];
            }
        } break;
            
        case kRunningTransferStateSendingFullSize: {
            NSInteger numIdleSlots = 0;
            
            if (!context.estimated) {
                [self estimateTransfer];
            }
            
            for (ImageTransferContext *imageContext in context.imageContexts) {
                switch (imageContext.state) {
                    case kImageTransferStateIdle: {
                        if ([self nextPendingFrame]) {
                            imageContext.roll = context.orderModel.rolls[context.pendingRollIndex];
                            imageContext.frame = imageContext.roll.frames[context.pendingFrameIndex++];

                            if (imageContext.frame.orientation > 1) {
                                imageContext.state = kImageTransferStateFixingOrientation;
                                
                                imageContext.imageProcessingThread = [[NSThread alloc] initWithTarget:self
                                    selector:@selector(processImage:) object:imageContext];
                                
                                [imageContext.imageProcessingThread start];
                            } else {
                                imageContext.state = kImageTransferStateSendingFullSize;
                                imageContext.ftpUploadTask = [NSTask new];
                                imageContext.ftpUploadTask.launchPath = @"/usr/bin/curl";
                                imageContext.ftpUploadTask.arguments = [self curlParameters:imageContext];
                                [imageContext.ftpUploadTask launch];
                                
                                NSString *pathToFullSizeImage = [[[context.orderModel.rootDir stringByAppendingPathComponent:imageContext.roll.number]
                                    stringByAppendingPathComponent:imageContext.frame.name] stringByAppendingPathExtension:imageContext.frame.extension];
                                
                                startedUploadingImage(imageContext.slot, pathToFullSizeImage);
                            }
                        } else {
                            numIdleSlots++;
                        }
                    } break;
                    
                    case kImageTransferStateFixingOrientation: {
                        if (imageContext.imageProcessingThread.isFinished) {
                            imageContext.state = kImageTransferStateSendingFullSize;
                            imageContext.ftpUploadTask = [NSTask new];
                            imageContext.ftpUploadTask.launchPath = @"/usr/bin/curl";
                            imageContext.ftpUploadTask.arguments = [self curlParameters:imageContext];
                            [imageContext.ftpUploadTask launch];
                            
                            NSString *pathToFullSizeImage = [[[context.orderModel.rootDir stringByAppendingPathComponent:imageContext.roll.number]
                                stringByAppendingPathComponent:imageContext.frame.name] stringByAppendingPathExtension:imageContext.frame.extension];
                            
                            startedUploadingImage(imageContext.slot, pathToFullSizeImage);
                        }
                    } break;

                    case kImageTransferStateSendingFullSize: {
                        if (!imageContext.ftpUploadTask.isRunning) {
                            NSInteger status = imageContext.ftpUploadTask.terminationStatus;
                            
                            if (!status) {
                                imageContext.state = kImageTransferStatePostingFullSize;
                            } else {
                                [currentlyRunningTransfer.errors appendFormat:
                                    @"%@/%@.%@: could not upload full-size image, cURL returned %ld.\r",
                                    //@"Error codes are available at http://curl.haxx.se/libcurl/c/libcurl-errors.html",
                                    imageContext.roll.number, imageContext.frame.name, imageContext.frame.extension, status];
                                
                                endedUploadingImage(imageContext.slot);
                                imageContext.state = kImageTransferStateIdle;
                            }
                        }
                    } break;
                        
                    case kImageTransferStatePostingFullSize: {
                        if (!imageContext.fullSizePostedService.started) {
                            [imageContext.fullSizePostedService
                                startFullSizePosted:context.eventRow.ccsAccount
                                password:context.ccsPassword
                                orderNumber:currentlyRunningTransfer.orderNumber
                                roll:imageContext.roll.number
                                frame:imageContext.frame.name
                                filename:imageContext.fileNameOnFtpServer
                                version:@"CCSUploaderMac 1.0"
                                bypassPassword:NO
                                createPreviewAndThumb:NO
                                complete:^(FullSizePostedResult *result) {
                                    if (!result.error && [result.status isEqualToString:@"Successful"]) {
                                        imageContext.frame.fullsizeSent = YES;
                                        context.imagesSent++;
                                        context.sizeSent += imageContext.frame.filesize;
                                        
                                        progressIndicator.doubleValue += imageContext.frame.filesize;
                                        progressTitle.stringValue = [NSString stringWithFormat:@"%ld of %ld full-size images sent (%@ of %@)",
                                            context.imagesSent,
                                            context.totalCount,
                                            [FileUtil humanFriendlyFilesize:context.sizeSent],
                                            [FileUtil humanFriendlyFilesize:context.totalSize]
                                        ];
                                    } else {
                                        if (result.error) {
                                            [currentlyRunningTransfer.errors appendFormat:
                                                @"%@/%@.%@: could not post full-size image, an error occurred: %@\r",
                                                imageContext.roll.number, imageContext.frame.name, imageContext.frame.extension,
                                                result.error.localizedDescription];
                                        } else {
                                            [currentlyRunningTransfer.errors appendFormat:
                                                @"%@/%@.%@: could not post full-size image, the server returned \"%@\" with a status of \"%@\"\r",
                                                imageContext.roll.number, imageContext.frame.name, imageContext.frame.extension,
                                                result.message, result.status];
                                        }
                                    }
                                    
                                    endedUploadingImage(imageContext.slot);
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
                context.estimated = NO;
                progressIndicator.doubleValue = 0;
                progressIndicator.minValue = 0;
                progressIndicator.maxValue = 1;
                progressTitle.stringValue = @"";
                transferStateChanged(@"Activating full-size images");
                context.state = kRunningTransferStateActivatingFullSize;
            }
        } break;

        case kRunningTransferStateActivatingFullSize: {
            if (!activateFullSizeService.started) {
                [activateFullSizeService
                    startActivateFullSize:context.eventRow.ccsAccount
                    password:context.ccsPassword
                    orderNumber:currentlyRunningTransfer.orderNumber
                    complete:^(ActivateFullSizeResult *result) {
                        if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                            currentlyRunningTransfer.fullsizeUploaded = YES;
                        } else {
                            if (result.error) {
                                [currentlyRunningTransfer.errors appendFormat:
                                    @"Could not activate full-size images, an error occurred: %@\r",
                                    result.error.localizedDescription];
                            } else {
                                [currentlyRunningTransfer.errors appendFormat:
                                    @"Could not activate full-size images, the server returned \"%@\" with a status of \"%@\"\r",
                                    result.message, result.status];
                            }
                        }
                        
                        context.state = kRunningTransferStateFinished;
                        transferStateChanged(@"Finished");
                    }
                ];
            }
        } break;
            
        case kRunningTransferStateFinished: {
            [currentlyRunningTransfer.context.orderModel save];
            currentlyRunningTransfer.status = kTransferStatusComplete;
            currentlyRunningTransfer.context = nil;
            currentlyRunningTransfer = nil;
            reloadTransfers();
        } break;
    }
}

- (BOOL)setupRunningTransfer
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    if (!context.effectiveUser) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        if (currentlyRunningTransfer.isQuicPost) {
            context.effectiveUser = [defaults objectForKey:kQuicPostUser];
            context.effectivePass = [defaults objectForKey:kQuicPostPass];
            
            [listEventService setEffectiveServiceRoot:kServiceRootQuicPost coreDomain:nil];
            [checkOrderNumberService setEffectiveServiceRoot:kServiceRootQuicPost coreDomain:nil];
        } else {
            context.effectiveUser = [defaults objectForKey:kCoreUser];
            context.effectivePass = [defaults objectForKey:kCorePass];

            [listEventService setEffectiveServiceRoot:kServiceRootCore coreDomain:[defaults objectForKey:kCoreDomain]];
            [checkOrderNumberService setEffectiveServiceRoot:kServiceRootCore coreDomain:[defaults objectForKey:kCoreDomain]];
        }
    }
    
    if (!context.eventRow) {
        if (!listEventService.started) {
            [listEventService
                startListEvent:context.effectiveUser
                password:context.effectivePass
                orderNumber:currentlyRunningTransfer.orderNumber
                complete:^(ListEventsResult *result) {
                    if (!result.error && result.loginSuccess && result.processSuccess && result.events.count == 1) {
                        context.eventRow = result.events[0];
                    } else if (result.error) {
                        [self abortTransferWithError:[NSString stringWithFormat:@"Unable to list event: %@", result.error.localizedDescription]];
                    } else {
                        [self abortTransferWithError:[NSString stringWithFormat:
                            @"Unable to list event%@", result.loginSuccess ? @"" : @": the server denied the credentials"]];
                    }
                }
            ];
        }
        
        return NO;
    }
    
    if (!context.ccsPassword) {
        if (!checkOrderNumberService.started) {
            [checkOrderNumberService
                startCheckOrderNumber:context.effectiveUser
                password:context.effectivePass
                orderNumber:currentlyRunningTransfer.orderNumber
                complete:^(CheckOrderNumberResult *result) {
                    if (!result.error && result.loginSuccess && result.processSuccess) {
                        context.ccsPassword = result.ccsPassword;
                    } else if (result.error) {
                        [self abortTransferWithError:[NSString stringWithFormat:@"Unable to fetch CCS password: %@", result.error.localizedDescription]];
                    } else {
                        [self abortTransferWithError:@"Unable to fetch CCS password."];
                    }
                }
            ];
        }
        
        return NO;
    }
    
    if (!context.eventSettings) {
        if (!eventSettingsService.started) {
            [eventSettingsService
                startGetEventSettings:context.eventRow.ccsAccount
                password:context.ccsPassword
                orderNumber:currentlyRunningTransfer.orderNumber
                complete:^(EventSettingsResult *result) {
                    if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                        context.eventSettings = result;
                    } else if (result.error) {
                        [self abortTransferWithError:[NSString stringWithFormat:
                            @"Unable to fetch event settings: %@",
                            result.error.localizedDescription]];
                    } else {
                        [self abortTransferWithError:[NSString stringWithFormat:
                            @"Unable to fetch event settings, the server returned \"%@\" with a status of \"%@\"",
                            result.message, result.status]];
                    }
                }
            ];
        }
        
        return NO;
    }
    
    if (!context.verifyOrderResult) {
        if (!verifyOrderService.started) {
            [verifyOrderService
                startVerifyOrder:context.eventRow.ccsAccount
                password:context.ccsPassword
                orderNumber:currentlyRunningTransfer.orderNumber
                version:@"CCSUploaderMac 1.0"
                bypassPassword:NO
                complete:^(VerifyOrderResult *result) {
                    if (!result.error && [result.status isEqualToString:@"Successful"]) {
                        context.verifyOrderResult = result;
                    } else if (result.error) {
                        [self abortTransferWithError:[NSString stringWithFormat:
                            @"Unable to verify order: %@",
                            result.error.localizedDescription]];
                    } else {
                        [self abortTransferWithError:[NSString stringWithFormat:
                            @"Unable to verify order, the server returned \"%@\" with a status of \"%@\"",
                            result.message, result.status]];
                    }
                }
            ];
        }
        
        return NO;
    }
    
    if (!context.orderModel) {
        NSError *error = nil;
        context.orderModel = [[OrderModel alloc] initWithEventRow:context.eventRow error:&error];
        
        if (!context.orderModel) {
            [self abortTransferWithError:[NSString stringWithFormat:@"Unable to create order model: %@", error.localizedDescription]];
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
        transfer.errors = [NSMutableString new];
        transfer.context = [RunningTransferContext new];
        transfer.context.imageContexts = [NSMutableArray new];
        
        for (NSInteger i = 0; i < 8; ++i) {
            ImageTransferContext *imageTransferContext = [ImageTransferContext new];
            
            imageTransferContext.slot = i;
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
                transfer.status = kTransferStatusQueued;
            }
        }
    }

    return nil;
}

- (void)stopCurrentTransfer
{
    if (currentlyRunningTransfer) {
        currentlyRunningTransfer.status = kTransferStatusStopped;
        [currentlyRunningTransfer.context.orderModel save];
        transferStateChanged(@"Stopped");
        
        for (ImageTransferContext *imageContext in currentlyRunningTransfer.context.imageContexts) {
            [imageContext.ftpUploadTask terminate];
            [imageContext.postImageDataService cancel];
            [imageContext.fullSizePostedService cancel];
            endedUploadingImage(imageContext.slot);
        }
        
        [listEventService cancel];
        [checkOrderNumberService cancel];
        [eventSettingsService cancel];
        [verifyOrderService cancel];
        
        [activateFullSizeService cancel];
        [activatePreviewsAndThumbsService cancel];
        
        progressIndicator.doubleValue = 0;
        progressTitle.stringValue = @"";
        
        currentlyRunningTransfer = nil;
        reloadTransfers();
    }
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

- (void)reload
{
    reloadTransfers();
}

@end
