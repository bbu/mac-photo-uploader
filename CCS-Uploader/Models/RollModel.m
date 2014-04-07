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
        _frames = [decoder decodeObjectForKey:@"frames"];
        _imagesAutoRenamed = [decoder decodeBoolForKey:@"imagesAutoRenamed"];
        _imagesViewed = [decoder decodeBoolForKey:@"imagesViewed"];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_number forKey:@"number"];
    [encoder encodeObject:_photographer forKey:@"photographer"];
    [encoder encodeObject:_photographerID forKey:@"photographerID"];
    [encoder encodeObject:_frames forKey:@"frames"];
    [encoder encodeBool:_imagesAutoRenamed forKey:@"imagesAutoRenamed"];
    [encoder encodeBool:_imagesViewed forKey:@"imagesViewed"];
}

@end
