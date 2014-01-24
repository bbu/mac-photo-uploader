#import "LoadingViewController.h"

@interface LoadingViewController ()

@end

@implementation LoadingViewController
@synthesize progressIndicator, txtMessage;

- (id)init
{
    self = [super initWithNibName:@"LoadingView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    [progressIndicator startAnimation:nil];
}

@end
