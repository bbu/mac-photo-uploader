#import <Foundation/Foundation.h>

@interface FrameModel : NSObject <NSCoding>
@property NSString *name, *extension;
@property NSInteger filesize;
@property NSDate *lastModified;
@property NSInteger width, height;
@property NSUInteger orientation;
@property NSMutableString *imageType;
@property NSMutableString *imageErrors;
@property BOOL userDidRotate;
@property BOOL
    fullsizeSent, thumbsSent,
    isSelected, isSelectedFullsizeSent, isSelectedThumbsSent,
    isMissing, isMissingFullsizeSent, isMissingThumbsSent;

@property BOOL needsDelete, newlyAdded;
@end
