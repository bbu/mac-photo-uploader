#import "AdvancedViewController.h"

@interface AdvancedViewController () {
    IBOutlet NSPopUpButton *btnDetectRotations;
    IBOutlet NSButton *chkDetectNewFiles;
    IBOutlet NSTextField *txtRemoveStringFromFilenames, *txtReplaceWithStringInFilenames;
    IBOutlet NSButton *chkHideImages;
}
@end

@implementation AdvancedViewController

- (void)loadView
{
    [super loadView];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSNumber *detectRotations = [defaults objectForKey:kDetectRotations];
    NSNumber *detectNewFiles = [defaults objectForKey:kDetectNewFiles];
    NSString *removeStringFromFilenames = [defaults objectForKey:kRemoveStringFromFilenames];
    NSString *replaceWithStringInFilenames = [defaults objectForKey:kReplaceWithStringInFilenames];
    NSNumber *hideImages = [defaults objectForKey:kHideImages];
    
    [btnDetectRotations selectItemWithTag:detectRotations ? detectRotations.integerValue : 0];
    chkDetectNewFiles.state = detectNewFiles ? (detectNewFiles.boolValue ? NSOnState : NSOffState) : NSOnState;
    txtRemoveStringFromFilenames.stringValue = removeStringFromFilenames ? [removeStringFromFilenames copy] : @"";
    txtReplaceWithStringInFilenames.stringValue = replaceWithStringInFilenames ? [replaceWithStringInFilenames copy] : @"";
    chkHideImages.state = hideImages ? (hideImages.boolValue ? NSOnState : NSOffState) : NSOnState;
}

- (void)saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[NSNumber numberWithInteger:btnDetectRotations.selectedTag] forKey:kDetectRotations];
    [defaults setObject:[NSNumber numberWithBool:chkDetectNewFiles.state == NSOnState ? YES : NO] forKey:kDetectNewFiles];
    [defaults setObject:txtRemoveStringFromFilenames.stringValue forKey:kRemoveStringFromFilenames];
    [defaults setObject:txtReplaceWithStringInFilenames.stringValue forKey:kReplaceWithStringInFilenames];
    [defaults setObject:[NSNumber numberWithBool:chkHideImages.state == NSOnState ? YES : NO] forKey:kHideImages];
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
