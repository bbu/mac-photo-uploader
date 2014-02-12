#import "RollModel.h"
#import "FrameModel.h"

@interface RollModel () {
    NSString *number;
    NSString *photographer, *photographerID;
    NSInteger totalFrameSize;
    NSObject *greenScreen;
    NSMutableArray *frames;
    BOOL dirExists, needsDelete, newlyAdded;
}
@end

@implementation RollModel

@synthesize number;
@synthesize photographer, photographerID;
@synthesize totalFrameSize;
@synthesize greenScreen;
@synthesize frames;
@synthesize dirExists, needsDelete, newlyAdded;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        number = [decoder decodeObjectForKey:@"number"];
        photographer = [decoder decodeObjectForKey:@"photographer"];
        photographerID = [decoder decodeObjectForKey:@"photographerID"];
        totalFrameSize = [decoder decodeIntegerForKey:@"totalFrameSize"];
        greenScreen = [decoder decodeObjectForKey:@"greenScreen"];
        frames = [decoder decodeObjectForKey:@"frames"];
    }

    return self;
}

- (id)init
{
    self = [super init];
    
    if (self) {
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:number forKey:@"number"];
    [encoder encodeObject:photographer forKey:@"photographer"];
    [encoder encodeObject:photographerID forKey:@"photographerID"];
    [encoder encodeInteger:totalFrameSize forKey:@"totalFrameSize"];
    [encoder encodeObject:greenScreen forKey:@"greenScreen"];
    [encoder encodeObject:frames forKey:@"frames"];
}

- (BOOL)addFrame:(FrameModel *)frame
{
    return YES;
}

- (BOOL)removeFrameAtIndex:(NSUInteger)index
{
    [frames removeObjectAtIndex:index];
    return YES;
}

@end
