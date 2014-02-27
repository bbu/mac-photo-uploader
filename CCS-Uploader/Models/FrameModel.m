#import "FrameModel.h"

@interface FrameModel () {
    NSString *name, *extension;
    NSInteger filesize;
    NSDate *lastModified;
    NSInteger width, height;
    NSUInteger orientation;
    NSMutableString *imageType;
    BOOL fullsizeSent, thumbsSent;
    BOOL needsDelete, newlyAdded, userDidRotate;
}
@end

@implementation FrameModel
@synthesize name, extension;
@synthesize filesize;
@synthesize lastModified;
@synthesize width, height;
@synthesize orientation;
@synthesize imageType;
@synthesize fullsizeSent, thumbsSent;
@synthesize needsDelete, newlyAdded, userDidRotate;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    
    if (self) {
        name = [decoder decodeObjectForKey:@"name"];
        extension = [decoder decodeObjectForKey:@"extension"];
        filesize = [decoder decodeIntegerForKey:@"filesize"];
        lastModified = [decoder decodeObjectForKey:@"lastModified"];
        width = [decoder decodeIntegerForKey:@"width"];
        height = [decoder decodeIntegerForKey:@"height"];
        orientation = [decoder decodeIntegerForKey:@"orientation"];
        imageType = [decoder decodeObjectForKey:@"imageType"];
        fullsizeSent = [decoder decodeBoolForKey:@"fullsizeSent"];
        thumbsSent = [decoder decodeBoolForKey:@"thumbsSent"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:name forKey:@"name"];
    [encoder encodeObject:extension forKey:@"extension"];
    [encoder encodeInteger:filesize forKey:@"filesize"];
    [encoder encodeObject:lastModified forKey:@"lastModified"];
    [encoder encodeInteger:width forKey:@"width"];
    [encoder encodeInteger:height forKey:@"height"];
    [encoder encodeInteger:orientation forKey:@"orientation"];
    [encoder encodeObject:imageType forKey:@"imageType"];
    [encoder encodeBool:fullsizeSent forKey:@"fullsizeSent"];
    [encoder encodeBool:thumbsSent forKey:@"thumbsSent"];
}

@end
