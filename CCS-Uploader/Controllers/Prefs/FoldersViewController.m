#import "FoldersViewController.h"
#import "../PrefsWindowController.h"

@interface FoldersViewController ()
@end

@implementation FoldersViewController

- (void)loadView
{
    [super loadView];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storedValue = [defaults objectForKey:kApplicationFolder];
    
    if (storedValue != nil) {
        txtApplicationFolder.stringValue = storedValue;
    }
    
    storedValue = [defaults objectForKey:kDefaultImageBrowseLocation];

    if (storedValue != nil) {
        txtDefaultImageBrowseLocation.stringValue = storedValue;
    }
}

- (void)saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:txtApplicationFolder.stringValue forKey:kApplicationFolder];
    [defaults setObject:txtDefaultImageBrowseLocation.stringValue forKey:kDefaultImageBrowseLocation];
}

+ (NSOpenPanel *)openPanelWithMessage:(NSString *)message
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    openPanel.canChooseDirectories = YES;
    openPanel.canCreateDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.message = message;

    return openPanel;
}

- (IBAction)browseForApplicationFolder:(id)sender
{
    NSOpenPanel *openPanel = [self.class openPanelWithMessage:@"Select application folder:"];

    [openPanel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            txtApplicationFolder.stringValue = openPanel.URL.path;
        }
    }];
}

- (IBAction)browseForDefaultImageBrowseLocation:(id)sender
{
    NSOpenPanel *openPanel = [self.class openPanelWithMessage:@"Select default image browsing location:"];
    
    [openPanel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            txtDefaultImageBrowseLocation.stringValue = openPanel.URL.path;
        }
    }];
}

@end
