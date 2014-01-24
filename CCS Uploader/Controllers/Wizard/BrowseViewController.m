#import "BrowseViewController.h"

@interface BrowseViewController () {
    IBOutlet NSPopover *advancedOptionsPopover;
}

@end

@implementation BrowseViewController

- (id)init
{
    self = [super initWithNibName:@"BrowseView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (IBAction)browseForImagesClicked:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *defaultLocation = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultImageBrowseLocation"];
    
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = YES;
    openPanel.message = @"Select files or folders to upload:";
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:defaultLocation]];

    [openPanel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            
        }
    }];
}

- (IBAction)advancedOptionsClicked:(id)sender
{
    [advancedOptionsPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
