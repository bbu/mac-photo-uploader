#import "LoginViewController.h"
#import "../Prefs/AdvancedViewController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (id)init
{
    self = [super initWithNibName:@"LoginView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (IBAction)eventNumberHelp:(id)sender
{
    NSString *label = @"If left empty, you will be prompted to select an event from a list.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(220, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
