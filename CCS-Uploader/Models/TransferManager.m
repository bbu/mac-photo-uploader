#import "TransferManager.h"

#define kTransfersDataFile @"transfers.ccstransfers"

@implementation ImageTransferContext
@synthesize state;
@synthesize roll;
@synthesize frame;
@synthesize imageProcessingThread;
@synthesize ftpUploadTask;
@end

@implementation RunningTransferContext
@synthesize state;
@synthesize pendingRoll;
@synthesize pendingFrame;
@synthesize orderModel;
@synthesize eventRow;
@synthesize ccsPassword;
@synthesize eventSettings;
@synthesize verifyOrderResult;
@synthesize imageContexts;
@end

@implementation Transfer
@synthesize orderNumber;
@synthesize eventName;
@synthesize status;
@synthesize uploadThumbs, uploadFullsize;
@synthesize datePushed, dateScheduled;
@synthesize context;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        eventName = [decoder decodeObjectForKey:@"eventName"];
        status = [decoder decodeIntegerForKey:@"status"];
        uploadThumbs = [decoder decodeBoolForKey:@"uploadThumbs"];
        uploadFullsize = [decoder decodeBoolForKey:@"uploadFullsize"];
        datePushed = [decoder decodeObjectForKey:@"datePushed"];
        dateScheduled = [decoder decodeObjectForKey:@"dateScheduled"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:orderNumber forKey:@"orderNumber"];
    [encoder encodeObject:eventName forKey:@"eventName"];
    [encoder encodeInteger:status forKey:@"status"];
    [encoder encodeBool:uploadThumbs forKey:@"uploadThumbs"];
    [encoder encodeBool:uploadFullsize forKey:@"uploadFullsize"];
    [encoder encodeObject:datePushed forKey:@"datePushed"];
    [encoder encodeObject:dateScheduled forKey:@"dateScheduled"];
}

@end

@implementation TransferManager

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
        
        for (NSInteger i = 0; i < kMaxThreads; ++i) {
            fullSizePostedService[i] = [FullSizePostedService new];
            postImageDataService[i] = [PostImageDataService new];
            updateVisibleService[i] = [UpdateVisibleService new];
        }
        
        activatePreviewsAndThumbsService = [ActivatePreviewsAndThumbsService new];
        activateFullSizeService = [ActivateFullSizeService new];
    }
    
    return self;
}

- (void)abortTransfer:(NSString *)message
{
    currentlyRunningTransfer.status = kTransferStatusAborted;
    currentlyRunningTransfer.context = nil;
    currentlyRunningTransfer = nil;
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
        case kRunningTransferStateIdle:
            context.state = kRunningTransferStateSetup;
            break;
            
        case kRunningTransferStateSetup:
            if ([self setupRunningTransfer]) {
                if (currentlyRunningTransfer.uploadThumbs) {
                    context.state = kRunningTransferStateSendingThumbs;
                } else if (currentlyRunningTransfer.uploadFullsize) {
                    context.state = kRunningTransferStateSendingFullSize;
                } else {
                    context.state = kRunningTransferStateFinished;
                }
            }
            break;
            
        case kRunningTransferStateSendingThumbs:
            if (!context.orderModel.rolls.count) {
                context.state = kRunningTransferStateFinished;
                return;
            }
            
            if (!context.pendingRoll) {
                context.pendingRoll = context.orderModel.rolls[0];
            }
            
            if (!context.pendingFrame) {
                context.pendingFrame = context.orderModel.rolls[0];
            }
            break;
            
        case kRunningTransferStateActivatingThumbs: {
            [activatePreviewsAndThumbsService startActivatePreviewsAndThumbs:context.eventRow.ccsAccount
                password:context.ccsPassword orderNumber:currentlyRunningTransfer.orderNumber
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
        } break;
            
        case kRunningTransferStateSendingFullSize:
            break;
            
        case kRunningTransferStateActivatingFullSize: {
            [activateFullSizeService startActivateFullSize:context.eventRow.ccsAccount
                password:context.ccsPassword orderNumber:currentlyRunningTransfer.orderNumber
                complete:^(ActivateFullSizeResult *result) {
                    if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                        context.state = kRunningTransferStateFinished;
                    } else {
                        [self abortTransfer:@"Unable to activate full-size images."];
                    }
                }
            ];
        } break;
            
        case kRunningTransferStateFinished:
            currentlyRunningTransfer.status = kTransferStatusComplete;
            currentlyRunningTransfer.context = nil;
            currentlyRunningTransfer = nil;
            break;
    }
}

- (void)processImageTransfers
{
    for (ImageTransferContext *imageContext in currentlyRunningTransfer.context.imageContexts) {
        
    }
}

- (BOOL)setupRunningTransfer
{
    RunningTransferContext *context = currentlyRunningTransfer.context;
    
    if (!context.eventRow) {
        [listEventService startListEvent:@"ccsmacuploader" password:@"candid123"
            orderNumber:currentlyRunningTransfer.orderNumber complete:^(ListEventsResult *result) {
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
        [checkOrderNumberService startCheckOrderNumber:@"ccsmacuploader" password:@"candid123"
            orderNumber:currentlyRunningTransfer.orderNumber complete:^(CheckOrderNumberResult *result) {
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
        [eventSettingsService startGetEventSettings:context.eventRow.ccsAccount password:context.ccsPassword
            orderNumber:currentlyRunningTransfer.orderNumber complete:^(EventSettingsResult *result) {
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
        [verifyOrderService startVerifyOrder:context.eventRow.ccsAccount password:context.ccsPassword
            orderNumber:currentlyRunningTransfer.orderNumber version:@"" bypassPassword:NO complete:^(VerifyOrderResult *result) {
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
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusRunning) {
            transfer.context = [RunningTransferContext new];
            return transfer;
        }
    }
    
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusQueued) {
            transfer.status = kTransferStatusRunning;
            transfer.context = [RunningTransferContext new];
            return transfer;
        }
    }
    
    NSDate *now = [NSDate date];

    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusScheduled) {
            NSComparisonResult cmp = [now compare:transfer.dateScheduled];
            
            if (cmp == NSOrderedSame || cmp == NSOrderedDescending) {
                transfer.status = kTransferStatusRunning;
                transfer.context = [RunningTransferContext new];
                return transfer;
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
    
    return [NSKeyedArchiver archiveRootObject:transfers toFile:pathToDataFile];
}

@end
