#import <Foundation/Foundation.h>

@interface FrameModel : NSObject <NSCoding>

@property NSString *filename, *extension;
@property NSInteger filesize;
@property NSDate *lastModified;
@property NSInteger width, height;

@end
