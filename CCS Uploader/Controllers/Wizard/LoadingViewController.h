#import <Cocoa/Cocoa.h>

@interface LoadingViewController : NSViewController {
    @private
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSTextField *txtMessage;
}

@property NSProgressIndicator *progressIndicator;
@property NSTextField *txtMessage;

@end
