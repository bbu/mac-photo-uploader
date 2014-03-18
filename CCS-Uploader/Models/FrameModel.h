#import <Foundation/Foundation.h>

@interface FrameModel : NSObject <NSCoding>
@property NSString *name, *extension;
@property NSInteger filesize;
@property NSDate *lastModified;
@property NSInteger width, height;
@property NSUInteger orientation;
@property NSMutableString *imageType;
@property NSMutableString *imageErrors;
@property BOOL fullsizeSent, thumbsSent;
@property BOOL needsDelete, newlyAdded, userDidRotate;
@end
