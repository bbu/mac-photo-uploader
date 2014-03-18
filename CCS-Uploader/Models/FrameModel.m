#import "FrameModel.h"

@implementation FrameModel

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        _name = [decoder decodeObjectForKey:@"name"];
        _extension = [decoder decodeObjectForKey:@"extension"];
        _filesize = [decoder decodeIntegerForKey:@"filesize"];
        _lastModified = [decoder decodeObjectForKey:@"lastModified"];
        _width = [decoder decodeIntegerForKey:@"width"];
        _height = [decoder decodeIntegerForKey:@"height"];
        _orientation = [decoder decodeIntegerForKey:@"orientation"];
        _imageType = [decoder decodeObjectForKey:@"imageType"];
        _imageErrors = [decoder decodeObjectForKey:@"imageErrors"];
        _fullsizeSent = [decoder decodeBoolForKey:@"fullsizeSent"];
        _thumbsSent = [decoder decodeBoolForKey:@"thumbsSent"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_name forKey:@"name"];
    [encoder encodeObject:_extension forKey:@"extension"];
    [encoder encodeInteger:_filesize forKey:@"filesize"];
    [encoder encodeObject:_lastModified forKey:@"lastModified"];
    [encoder encodeInteger:_width forKey:@"width"];
    [encoder encodeInteger:_height forKey:@"height"];
    [encoder encodeInteger:_orientation forKey:@"orientation"];
    [encoder encodeObject:_imageType forKey:@"imageType"];
    [encoder encodeObject:_imageErrors forKey:@"imageErrors"];
    [encoder encodeBool:_fullsizeSent forKey:@"fullsizeSent"];
    [encoder encodeBool:_thumbsSent forKey:@"thumbsSent"];
}

@end
