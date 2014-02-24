#import "TransfersModel.h"

#define kTransfersDataFile @"transfers.ccstransfers"



@implementation Transfer

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        eventName = [decoder decodeObjectForKey:@"eventName"];
        status = [decoder decodeIntegerForKey:@"status"];
        orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    
}

@end

@implementation TransfersModel

@end
