#import "EventsViewController.h"

@interface EventsViewController () {
    IBOutlet NSPopover *advancedSearchPopover;
}

@end

@implementation EventsViewController

- (id)init
{
    self = [super initWithNibName:@"EventsView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (IBAction)advancedSearchClicked:(id)sender
{
    [advancedSearchPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
