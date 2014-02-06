#import "RollModel.h"
#import "FrameModel.h"

@interface RollModel () {
    NSString *rollNumber;
    NSString *photographer, *photographerID;
    NSInteger totalFrameSize;
    NSObject *greenScreen;
    NSMutableArray *frames;
}
@end

@implementation RollModel
@synthesize rollNumber;
@synthesize photographer, photographerID;
@synthesize totalFrameSize;
@synthesize greenScreen;
@synthesize frames;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        rollNumber = [decoder decodeObjectForKey:@"rollNumber"];
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
    [encoder encodeObject:rollNumber forKey:@"rollNumber"];
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
