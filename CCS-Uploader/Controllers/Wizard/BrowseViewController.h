#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "../../Models/Preloader.h"

@class WizardWindowController, EventRow, OrderModel, FrameModel;

@interface ImageInBrowserView : NSObject

- (id)initWithFrame:(FrameModel *)frame path:(NSString *)path;

@property FrameModel *frame;
@property NSString *path;
@end

@interface BrowseViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard;
- (void)saveOrderModel;

@property (readonly) OrderModel *orderModel;
@property (readonly) Preloader *preloader;
@property (readonly) NSString *ccsPassword;

@end
