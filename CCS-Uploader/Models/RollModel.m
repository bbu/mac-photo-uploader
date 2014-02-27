#import "RollModel.h"
#import "FrameModel.h"

@implementation RollModel

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        _number = [decoder decodeObjectForKey:@"number"];
        _photographer = [decoder decodeObjectForKey:@"photographer"];
        _photographerID = [decoder decodeObjectForKey:@"photographerID"];
        _greenScreen = [decoder decodeObjectForKey:@"greenScreen"];
        _frames = [decoder decodeObjectForKey:@"frames"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_number forKey:@"number"];
    [encoder encodeObject:_photographer forKey:@"photographer"];
    [encoder encodeObject:_photographerID forKey:@"photographerID"];
    [encoder encodeObject:_greenScreen forKey:@"greenScreen"];
    [encoder encodeObject:_frames forKey:@"frames"];
}

@end
