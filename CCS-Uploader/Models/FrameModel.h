#import <Foundation/Foundation.h>

@interface FrameModel : NSObject <NSCoding>

@property NSString *name, *extension;
@property NSInteger filesize;
@property NSDate *lastModified;
@property NSInteger width, height;
@property NSUInteger orientation;
@property BOOL needsReload, needsDelete, newlyAdded, fullsizeSent, thumbsSent, userDidRotate;

@end
