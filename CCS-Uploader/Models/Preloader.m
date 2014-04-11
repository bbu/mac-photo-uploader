#import "Preloader.h"

#import "OrderModel.h"

#import "../Utils/FileUtil.h"
#import "../Utils/ImageUtil.h"

#import "../Services/PostImageDataService.h"
#import "../Services/EventSettingsService.h"

#pragma mark - ThumbContext

typedef NS_ENUM(NSInteger, ThumbState) {
    kThumbStateIdle = 0,
    kThumbStateGenerating,
    kThumbStateSending,
};

@interface ThumbContext : NSObject
@property NSInteger slot;
@property ThumbState state;
@property FrameModel *frame;
@property NSString *pathToFullSizeImage;
@property NSThread *imageProcessingThread;
@property PostImageDataService *postImageDataService;
@property NSData *previewImage, *thumbnailImage, *pngImage, *mediumResImage;
@property NSInteger previewWidth, previewHeight, pngWidth, pngHeight;
@end

@implementation ThumbContext
@end

#pragma mark - Preloader

typedef NS_ENUM(NSInteger, PreloaderState) {
    kPreloaderStateIdle = 0,
    kPreloaderStateBusy,
};

@interface Preloader () {
    PreloaderState state;
    OrderModel *orderModel;
    EventSettingsResult *eventSettings;
    RollModel *currentRoll;
    NSInteger pendingFrameIndex;
    NSInteger thumbsSent, totalThumbs;
    NSMutableArray *thumbContexts;
}
@end

@implementation Preloader

- (id)initWithOrderModel:(OrderModel *)order eventSettings:(EventSettingsResult *)settings
{
    self = [super init];
    
    if (self) {
        orderModel = order;
        eventSettings = settings;
        state = kPreloaderStateIdle;
    }
    
    return self;
}

- (BOOL)nextPendingFrame
{
    for (NSInteger i = pendingFrameIndex; i < currentRoll.frames.count; ++i) {
        FrameModel *frame = currentRoll.frames[i];

        BOOL conditionToSend = !frame.thumbsSent && !frame.imageErrors.length;
        
        if (conditionToSend) {
            pendingFrameIndex = i;
            return YES;
        }
    }
    
    return NO;
}

- (void)processThumbs
{
    switch (state) {
        case kPreloaderStateIdle: {
            for (RollModel *roll in orderModel.rolls) {
                if (roll.wantsPreloader) {
                    roll.wantsPreloader = NO;

                    NSNumber *simultaneousPreloaderUploads = [[NSUserDefaults standardUserDefaults] objectForKey:kSimultaneousPreloaderUploads];
                    NSInteger slotCount = 8;
                    
                    if (simultaneousPreloaderUploads && simultaneousPreloaderUploads.integerValue) {
                        slotCount = simultaneousPreloaderUploads.integerValue;
                    }
                    
                    for (NSInteger i = 0; i < slotCount; ++i) {
                        ThumbContext *thumbContext = [ThumbContext new];
                        [thumbContexts addObject:thumbContext];
                    }
                    
                    state = kPreloaderStateBusy;
                    currentRoll = roll;
                    break;
                }
            }
        } break;
            
        case kPreloaderStateBusy: {
            NSInteger numIdle = 0;
            
            for (ThumbContext *thumbContext in thumbContexts) {
                switch (thumbContext.state) {
                    case kThumbStateIdle: {
                        if ([self nextPendingFrame]) {
                            thumbContext.state = kThumbStateGenerating;
                            thumbContext.frame = currentRoll.frames[pendingFrameIndex++];
                            thumbContext.pathToFullSizeImage = @"";
                            thumbContext.imageProcessingThread = [[NSThread alloc] initWithTarget:self selector:@selector(processImage:) object:thumbContext];
                            
                            
                            [thumbContext.imageProcessingThread start];
                        } else {
                            numIdle++;
                        }
                    } break;
                        
                    case kThumbStateGenerating: {
                        if (thumbContext.imageProcessingThread.isFinished) {
                            thumbContext.state = kThumbStateSending;
                        }
                    } break;
                        
                    case kThumbStateSending: {
                        if (!thumbContext.postImageDataService.started) {
                            [thumbContext.postImageDataService
                                startPostImageData:orderModel.eventRow.ccsAccount
                                password:@""
                                orderNumber:orderModel.eventRow.orderNumber
                                roll:currentRoll.number
                                frame:thumbContext.frame.name
                                extension:thumbContext.frame.extension
                                version:[FileUtil versionString]
                                bypassPassword:NO
                                fullsizeImage:nil
                                previewImage:thumbContext.previewImage
                                thumbnailImage:thumbContext.thumbnailImage
                                pngImage:thumbContext.pngImage
                                mediumResImage:thumbContext.mediumResImage
                                originalImageSize:thumbContext.frame.filesize
                                originalWidth:thumbContext.frame.width
                                originalHeight:thumbContext.frame.height
                                previewWidth:-1
                                previewHeight:-1
                                pngWidth:-1
                                pngHeight:-1
                                photographer:currentRoll.photographer
                                photoDateTime:thumbContext.frame.lastModified
                                createPreviewAndThumb:NO
                                complete:^(PostImageDataResult *result) {
                                    thumbContext.state = kThumbStateIdle;
                                }
                            ];
                        }
                    } break;
                }
            }
            
            if (numIdle == thumbContexts.count) {
                currentRoll = nil;
                state = kPreloaderStateIdle;
            }
        } break;
    }
}

- (void)processImage:(ThumbContext *)thumbContext
{
    BOOL processed;
    
    if (thumbContext.frame.orientation > 1) {
        [ImageUtil resizeAndRotateImage:thumbContext.pathToFullSizeImage outputImageFilename:thumbContext.pathToFullSizeImage
            resizeToMaxSide:0 rotate:kDontRotate horizontalWatermark:nil verticalWatermark:nil compressionQuality:0.85];
        
        CGSize newSize = CGSizeZero;
        NSUInteger orientation;
        
        [ImageUtil getImageProperties:thumbContext.pathToFullSizeImage size:&newSize
            type:thumbContext.frame.imageType orientation:&orientation errors:thumbContext.frame.imageErrors];
        
        thumbContext.frame.width = newSize.width;
        thumbContext.frame.height = newSize.height;
        
        NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:thumbContext.pathToFullSizeImage error:nil];
        
        if (fileAttrs) {
            currentRoll.totalFrameSize -= thumbContext.frame.filesize;
            thumbContext.frame.lastModified = fileAttrs.fileModificationDate;
            thumbContext.frame.filesize = fileAttrs.fileSize;
            currentRoll.totalFrameSize += thumbContext.frame.filesize;
        } else {
        }
        
        thumbContext.frame.fullsizeSent = thumbContext.frame.isSelectedFullsizeSent = thumbContext.frame.isMissingFullsizeSent = NO;
        thumbContext.frame.thumbsSent = thumbContext.frame.isSelectedThumbsSent = thumbContext.frame.isMissingThumbsSent = NO;
        thumbContext.frame.orientation = 1;
    }
    
    thumbContext.previewImage = nil;
    thumbContext.thumbnailImage = nil;
    thumbContext.pngImage = nil;
    thumbContext.mediumResImage = nil;
    thumbContext.previewWidth = -1;
    thumbContext.previewHeight = -1;
    thumbContext.pngWidth = -1;
    thumbContext.pngHeight = -1;
    
    if (eventSettings.transferSettings.createThumbnail && eventSettings.thumbnailSettings) {
        NSString *thumbnailFilename = [thumbContext.pathToFullSizeImage stringByAppendingFormat:@"_ccsthumb_%ld", thumbContext.slot];
        NSData *hWatermark = nil, *vWatermark = nil;
        
        if (eventSettings.watermarkSettings && eventSettings.transferSettings.thumbnailWatermarkID == eventSettings.watermarkSettings.watermarkID) {
            hWatermark = eventSettings.watermarkSettings.hFileData;
            vWatermark = eventSettings.watermarkSettings.vFileData;
        }
        
        processed = [ImageUtil resizeAndRotateImage:thumbContext.pathToFullSizeImage outputImageFilename:thumbnailFilename
            resizeToMaxSide:eventSettings.thumbnailSettings.maxSide rotate:kDontRotate
            horizontalWatermark:hWatermark verticalWatermark:vWatermark
            compressionQuality:eventSettings.thumbnailSettings.quality / 100.];
        
        if (processed) {
            thumbContext.thumbnailImage = [NSData dataWithContentsOfFile:thumbnailFilename];
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:thumbnailFilename error:nil];
    }
    
    if (eventSettings.transferSettings.createMediumRes && eventSettings.mediumResSettings) {
        NSString *mediumResFilename = [thumbContext.pathToFullSizeImage stringByAppendingFormat:@"_ccsmedium_%ld", thumbContext.slot];
        
        processed = [ImageUtil resizeAndRotateImage:thumbContext.pathToFullSizeImage outputImageFilename:mediumResFilename
            resizeToMaxSide:eventSettings.mediumResSettings.maxSide rotate:kDontRotate
            horizontalWatermark:nil verticalWatermark:nil
            compressionQuality:eventSettings.mediumResSettings.quality / 100.];
        
        if (processed) {
            thumbContext.mediumResImage = [NSData dataWithContentsOfFile:mediumResFilename];
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:mediumResFilename error:nil];
    }
    
    if (eventSettings.transferSettings.createPreview && eventSettings.previewSettings) {
        NSString *previewFilename = [thumbContext.pathToFullSizeImage stringByAppendingFormat:@"_ccspreview_%ld", thumbContext.slot];
        NSData *hWatermark = nil, *vWatermark = nil;
        
        if (eventSettings.watermarkSettings && eventSettings.transferSettings.previewWatermarkID == eventSettings.watermarkSettings.watermarkID) {
            hWatermark = eventSettings.watermarkSettings.hFileData;
            vWatermark = eventSettings.watermarkSettings.vFileData;
        }
        
        processed = [ImageUtil resizeAndRotateImage:thumbContext.pathToFullSizeImage outputImageFilename:previewFilename
            resizeToMaxSide:eventSettings.previewSettings.maxSide rotate:kDontRotate
            horizontalWatermark:hWatermark verticalWatermark:vWatermark
            compressionQuality:eventSettings.previewSettings.quality / 100.];
        
        if (processed) {
            thumbContext.previewImage = [NSData dataWithContentsOfFile:previewFilename];
            CGSize size = CGSizeZero;
            NSUInteger orientation;
            
            if ([ImageUtil getImageProperties:previewFilename size:&size type:nil orientation:&orientation errors:nil]) {
                thumbContext.previewWidth = size.width;
                thumbContext.previewHeight = size.height;
            }
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:previewFilename error:nil];
    }
    
    if (eventSettings.pngSettings && [thumbContext.frame.imageType isEqualToString:@"public.png"]) {
        NSString *pngFilename = [thumbContext.pathToFullSizeImage stringByAppendingFormat:@"_ccspng_%ld.png", thumbContext.slot];
        
        processed = [ImageUtil resizeAndRotateImage:thumbContext.pathToFullSizeImage outputImageFilename:pngFilename
            resizeToMaxSide:eventSettings.pngSettings.maxSide rotate:kDontRotate
            horizontalWatermark:nil verticalWatermark:nil
            compressionQuality:eventSettings.pngSettings.quality / 100.];
        
        if (processed) {
            thumbContext.pngImage = [NSData dataWithContentsOfFile:pngFilename];
            CGSize size = CGSizeZero;
            NSUInteger orientation;
            
            if ([ImageUtil getImageProperties:pngFilename size:&size type:nil orientation:&orientation errors:nil]) {
                thumbContext.pngWidth = size.width;
                thumbContext.pngHeight = size.height;
            }
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:pngFilename error:nil];
    }
}

@end
