#import <Foundation/Foundation.h>

@interface FrameModel : NSObject <NSCoding>

@property NSString *name, *extension;
@property NSInteger filesize;
@property NSDate *lastModified;
@property NSInteger width, height;
@property BOOL fileExists, needsReload, needsDelete, newlyAdded, fullsizeSent, thumbsSent, userDidRotate, clearedExifOrientation;

@end
