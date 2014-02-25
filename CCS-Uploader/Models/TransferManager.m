#import "TransferManager.h"

#define kTransfersDataFile @"transfers.ccstransfers"



@implementation Transfer

@synthesize orderNumber;
@synthesize eventName;
@synthesize status, state;
@synthesize uploadThumbs, uploadFullsize;
@synthesize datePushed, dateScheduled;
@synthesize orderModel;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        eventName = [decoder decodeObjectForKey:@"eventName"];
        status = [decoder decodeIntegerForKey:@"status"];
        state = [decoder decodeIntegerForKey:@"state"];
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
    [encoder encodeInteger:state forKey:@"state"];
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
    }
    
    return self;
}

- (void)process
{
    if (!currentlyRunningTransfer) {
        currentlyRunningTransfer = [self nextRunnableTransfer];
        
        if (!currentlyRunningTransfer) {
            return;
        }
    }
    
    
}

- (Transfer *)nextRunnableTransfer
{
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusRunning) {
            return transfer;
        }
    }
    
    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusQueued) {
            transfer.status = kTransferStatusRunning;
            return transfer;
        }
    }
    
    NSDate *now = [NSDate date];

    for (Transfer *transfer in transfers) {
        if (transfer.status == kTransferStatusScheduled) {
            NSComparisonResult cmp = [now compare:transfer.dateScheduled];
            
            if (cmp == NSOrderedSame || cmp == NSOrderedDescending) {
                transfer.status = kTransferStatusRunning;
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
