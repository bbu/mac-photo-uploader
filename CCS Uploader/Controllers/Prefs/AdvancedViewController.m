#import "AdvancedViewController.h"

@interface AdvancedViewController ()

@end

@implementation AdvancedViewController

- (void)loadView
{
    [super loadView];
}

- (void)saveState
{
    
}

+ (NSPopover *)popoverWithLabel:(NSString *)text size:(NSSize)size
{
    NSPopover *popover = [NSPopover new];
    NSViewController *controller = [NSViewController new];
    NSTextField *label = [NSTextField new];

    label.stringValue = text;
    [label setFrameSize:size];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];

    controller.view = label;
    
    popover.behavior = NSPopoverBehaviorTransient;
    popover.animates = YES;
    popover.contentViewController = controller;
    
    return popover;
}

- (IBAction)detectNewFoldersHelp:(id)sender
{
    NSString *label = @"Select this to automatically scan for new Rolls and Frames when setting up an event in the wizard.\r\rIf this is not selected, you can still reload images by right clicking on the roll.";
    
    NSPopover *popover = [self.class popoverWithLabel:label size:NSMakeSize(260, 97)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)hideImagesHelp:(id)sender
{
    NSString *label = @"When enabled, if an image is deleted locally and previews and thumbnails have been generated, CCS Uploader attempts to hide the image online. Images will not be hidden if the full-size image has not been sent.";
    
    NSPopover *popover = [self.class popoverWithLabel:label size:NSMakeSize(300, 80)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
