#import <Cocoa/Cocoa.h>

@interface FoldersViewController : NSViewController {
    @private
    IBOutlet NSTextField *txtApplicationFolder, *txtDefaultImageBrowseLocation;
}

-(IBAction)browseForApplicationFolder:(id)sender;
-(IBAction)browseForDefaultImageBrowseLocation:(id)sender;

- (void)saveState;

@end
