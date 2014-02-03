#import "../../Utils/FileUtil.h"

#import "BrowseViewController.h"
#import "../WizardWindowController.h"

@interface BrowseViewController () <NSTableViewDelegate, NSTableViewDataSource> {
    IBOutlet NSTableView *tblRolls;
    IBOutlet NSPopover *advancedOptionsPopover, *viewRollPopover;
    WizardWindowController *wizardWindowController;
}

@end

@implementation BrowseViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"BrowseView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
    }
    
    return self;
}

- (IBAction)browseForImagesClicked:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *defaultLocation = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultImageBrowseLocation];
    
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = YES;
    openPanel.message = @"Select files or folders to upload:";
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:defaultLocation]];

    [openPanel beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                for (NSURL *url in openPanel.URLs) {
                    
                    NSMutableArray *contents = [FileUtil filesInDirectory:url.path extensionSet:[FileUtil extensionSetWithJpeg:YES withPng:YES] recursive:YES absolutePaths:YES];
                    
                    for (NSString *filename in contents) {
                        NSLog(@"%@", filename);
                    }
                }
            }
        }
    ];
}

- (IBAction)advancedOptionsClicked:(id)sender
{
    [advancedOptionsPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return 45;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    id view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if ([columnID isEqualToString:@"Folder"]) {
        NSTableCellView *cell = view;
        [cell.textField setEditable:YES];
        cell.imageView.image = [NSImage imageNamed:@"NSFolder"];
        cell.textField.stringValue = @"Test name";
    } else if ([columnID isEqualToString:@"Photographer"]) {
        NSPopUpButton *btn = view;
        
        [btn addItemWithTitle:@"None"];
        [btn addItemWithTitle:@"photographer 1"];
        [btn addItemWithTitle:@"photographer 2"];
        [btn addItemWithTitle:@"photographer 3"];
        
    } else if ([columnID isEqualToString:@"Size"]) {
        NSTableCellView *cell = view;
        cell.textField.stringValue = @"123";
    } else if ([columnID isEqualToString:@"Count"]) {
        NSTableCellView *cell = view;
        cell.textField.stringValue = [NSString stringWithFormat:@"%lu", row * 2];
    } else if ([columnID isEqualToString:@"GreenScreen"]) {
        NSTableCellView *cell = view;
        //@"NSMenuOnStateTemplate"
        cell.imageView.image = row % 2 ? [NSImage imageNamed:@"NSStatusNone"] : [NSImage imageNamed:@"NSStatusAvailable"];
    } else if ([columnID isEqualToString:@"CurrentTask"]) {
        NSTableCellView *cell = view;
        cell.textField.stringValue = @"Uploading";
        //[((NSProgressIndicator *)cell.subviews[1]) startAnimation:nil];
    }
    
    return view;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    
    if ([columnID isEqualToString:@"Folder"]) {
        return [NSNumber numberWithInt:1];
    }
    
    return @"test";
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
}

- (IBAction)changedPhotographer:(id)sender
{
    NSLog(@"%lu", [tblRolls rowForView:sender]);
    [tblRolls reloadData];
}

- (IBAction)clickedDeleteRoll:(id)sender
{
    NSInteger row = [tblRolls rowForView:sender];
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to delete this roll?" defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];
    
    [alert beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [tblRolls removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationEffectNone];
            }
        }
    ];
}

- (IBAction)clickedViewRoll:(id)sender
{
    [viewRollPopover close];
    [viewRollPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}


@end
