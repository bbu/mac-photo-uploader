#import <QuartzCore/QuartzCore.h>

#import "Prefs/FoldersViewController.h"
#import "Prefs/AccountViewController.h"
#import "Prefs/ImageUploadViewController.h"
#import "Prefs/AdvancedViewController.h"
#import "Prefs/MarketSettingsViewController.h"

@interface PrefsWindowController : NSWindowController <NSWindowDelegate> {
@private
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSView *contentView;
    IBOutlet FoldersViewController *foldersViewController;
    IBOutlet AccountViewController *accountViewController;
    IBOutlet ImageUploadViewController *imageUploadViewController;
    IBOutlet AdvancedViewController *advancedViewController;
    IBOutlet MarketSettingsViewController *marketSettingsViewController;
}

- (IBAction)clickedFolders:(id)sender;
- (IBAction)clickedAccount:(id)sender;
- (IBAction)clickedImageUpload:(id)sender;
- (IBAction)clickedAdvanced:(id)sender;
- (IBAction)clickedMarketSettings:(id)sender;
@end

@implementation PrefsWindowController

- (id)init
{
    return self = [super initWithWindowNibName:@"PrefsWindow"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    toolbar.selectedItemIdentifier = @"Folders";
    [contentView addSubview:foldersViewController.view];
}

- (void)swapContentView:(NSView *)newView
{
    CGFloat heightDiff = newView.frame.size.height - contentView.frame.size.height;
    NSRect windowFrame = self.window.frame;
    
    [contentView setFrameSize:NSMakeSize(contentView.frame.size.width, newView.frame.size.height)];
    [newView setFrameOrigin:NSZeroPoint];
    
    windowFrame.size.height += heightDiff;
    windowFrame.origin.y -= heightDiff;
    
    [contentView.subviews[0] removeFromSuperview];
    [self.window setFrame:windowFrame display:YES animate:YES];
    [contentView addSubview:newView];
}

- (IBAction)clickedFolders:(id)sender
{
    [self swapContentView:foldersViewController.view];
}

- (IBAction)clickedAccount:(id)sender
{
    [self swapContentView:accountViewController.view];
}

- (IBAction)clickedImageUpload:(id)sender
{
    [self swapContentView:imageUploadViewController.view];
}

- (IBAction)clickedAdvanced:(id)sender
{
    [self swapContentView:advancedViewController.view];
}

- (IBAction)clickedMarketSettings:(id)sender
{
    [self swapContentView:marketSettingsViewController.view];
}

-(void)windowWillClose:(NSNotification *)notification
{
    [foldersViewController saveState];
    [accountViewController saveState];
    [imageUploadViewController saveState];
    [advancedViewController saveState];
    [marketSettingsViewController saveState];
}

@end
