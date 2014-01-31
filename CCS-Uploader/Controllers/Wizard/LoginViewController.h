#import <Cocoa/Cocoa.h>

@class WizardWindowController;

@interface LoginViewController : NSViewController

- (id)initWithWizardController:(WizardWindowController *)parent;
- (void)reloadAccounts;
- (void)startLogin;

@end
