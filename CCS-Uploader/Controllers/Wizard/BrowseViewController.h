#import <Cocoa/Cocoa.h>

@class WizardWindowController, EventRow, OrderModel;

@interface BrowseViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard;
- (void)saveOrderModel;

@property (readonly) OrderModel *orderModel;

@end
