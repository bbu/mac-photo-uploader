#import "FrameModel.h"

@interface FrameModel () {
    NSString *filename, *extension;
    NSInteger filesize;
    NSDate *lastModified;
    NSInteger width, height;
}
@end

@implementation FrameModel

@synthesize filename, extension;
@synthesize filesize;
@synthesize lastModified;
@synthesize width, height;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        filename = [decoder decodeObjectForKey:@"filename"];
        extension = [decoder decodeObjectForKey:@"extension"];
        filesize = [decoder decodeIntegerForKey:@"filesize"];
        lastModified = [decoder decodeObjectForKey:@"lastModified"];
        width = [decoder decodeIntegerForKey:@"width"];
        height = [decoder decodeIntegerForKey:@"height"];
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
    [encoder encodeObject:filename forKey:@"filename"];
    [encoder encodeObject:extension forKey:@"extension"];
    [encoder encodeInteger:filesize forKey:@"filesize"];
    [encoder encodeObject:lastModified forKey:@"lastModified"];
    [encoder encodeInteger:width forKey:@"width"];
    [encoder encodeInteger:height forKey:@"height"];
}

@end
