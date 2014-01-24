#import <Cocoa/Cocoa.h>

@interface AdvancedViewController : NSViewController

- (void)saveState;
+ (NSPopover *)popoverWithLabel:(NSString *)text size:(NSSize)size;

@end
