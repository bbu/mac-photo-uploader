#import "RollModel.h"
#import "FrameModel.h"

@interface RollModel () {
    NSString *number;
    NSString *photographer, *photographerID;
    NSInteger totalFrameSize;
    NSObject *greenScreen;
    NSMutableArray *frames;
    BOOL needsDelete, newlyAdded;
}
@end

@implementation RollModel
@synthesize number;
@synthesize photographer, photographerID;
@synthesize totalFrameSize;
@synthesize greenScreen;
@synthesize frames;
@synthesize needsDelete, newlyAdded;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        number = [decoder decodeObjectForKey:@"number"];
        photographer = [decoder decodeObjectForKey:@"photographer"];
        photographerID = [decoder decodeObjectForKey:@"photographerID"];
        greenScreen = [decoder decodeObjectForKey:@"greenScreen"];
        frames = [decoder decodeObjectForKey:@"frames"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:number forKey:@"number"];
    [encoder encodeObject:photographer forKey:@"photographer"];
    [encoder encodeObject:photographerID forKey:@"photographerID"];
    [encoder encodeObject:greenScreen forKey:@"greenScreen"];
    [encoder encodeObject:frames forKey:@"frames"];
}

@end
