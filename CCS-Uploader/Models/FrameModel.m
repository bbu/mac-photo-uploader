#import "FrameModel.h"

@interface FrameModel () {
    NSString *name, *extension;
    NSInteger filesize;
    NSDate *lastModified;
    NSInteger width, height;
    NSUInteger orientation;
    
    BOOL needsReload, needsDelete, newlyAdded, fullsizeSent, thumbsSent, userDidRotate;
}
@end

@implementation FrameModel

@synthesize name, extension;
@synthesize filesize;
@synthesize lastModified;
@synthesize width, height;
@synthesize orientation;
@synthesize needsReload, needsDelete, newlyAdded, fullsizeSent, thumbsSent, userDidRotate;

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
    [encoder encodeObject:name forKey:@"name"];
    [encoder encodeObject:extension forKey:@"extension"];
    [encoder encodeInteger:filesize forKey:@"filesize"];
    [encoder encodeObject:lastModified forKey:@"lastModified"];
    [encoder encodeInteger:width forKey:@"width"];
    [encoder encodeInteger:height forKey:@"height"];
    [encoder encodeInteger:orientation forKey:@"orientation"];
}

@end
