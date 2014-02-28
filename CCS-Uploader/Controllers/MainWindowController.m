#import "MainWindowController.h"
#import "Prefs/AdvancedViewController.h"

#import "../Models/TransferManager.h"

@interface MainWindowController () {
    IBOutlet NSTableView *tblTransfers;
    IBOutlet NSMenu *menuThumbnails;
    IBOutlet NSImageView
        *imgUploading1, *imgUploading2, *imgUploading3, *imgUploading4,
        *imgUploading5, *imgUploading6, *imgUploading7, *imgUploading8;
    
    IBOutlet WizardWindowController *wizardWindowController;

    TransferManager *transferManager;
    NSDateFormatter *dateFormatter;
}

@end

@implementation MainWindowController
@synthesize transferManager;

- (id)init
{
    self = [super initWithWindowNibName:@"MainWindow"];
    
    if (self) {
        transferManager = [TransferManager new];
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"MM/dd/Y";
        [transferManager pushTransfer];
    }
    
    return self;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return transferManager.transfers.count;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 18;
}

-(IBAction)deleteRowFromThumbnails:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];

    if (clickedRow != -1) {
        [tblTransfers removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:clickedRow] withAnimation:NSTableViewAnimationEffectFade];
    }
}

/*
-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return (row % 5 == 0) ? NO : YES;
}
*/

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    /*
    if (row % 5 == 0) {
        NSTextField *result = [tableView makeViewWithIdentifier:@"grp" owner:self];

        if (result == nil) {
            result = [[NSTextField alloc] initWithFrame:NSZeroRect];
            result.identifier = tableColumn.identifier;
            result.drawsBackground = NO;
            result.bezeled = NO;
            result.font = [NSFont systemFontOfSize:10];
        }
        
        result.objectValue = @"Completed Transfers";
        return result;
    } else {
    */

    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
        
    if (result == nil) {
        result = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
        result.identifier = tableColumn.identifier;
    }
    
    Transfer *transfer = transferManager.transfers[row];
    
    static NSString *transferStatuses[] = {@"Queued", @"Running", @"Scheduled", @"Aborted", @"Stopped", @"Complete"};
    
    if ([tableColumn.identifier isEqualToString:@"Event"]) {
        result.textField.stringValue = transfer.eventName;
    } else if ([tableColumn.identifier isEqualToString:@"Status"]) {
        result.textField.stringValue = transferStatuses[transfer.status];
    } else if ([tableColumn.identifier isEqualToString:@"Thumbs"]) {
        result.textField.stringValue = @"";
    } else if ([tableColumn.identifier isEqualToString:@"Fullsize"]) {
        result.textField.stringValue = @"";
    } else if ([tableColumn.identifier isEqualToString:@"Date"]) {
        result.textField.stringValue = [dateFormatter stringFromDate:transfer.datePushed];
    }
        
    return result;
    /*
    }
    
    return nil;
    */
}

-(BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    return NO;
}

- (IBAction)previewsAndThumbnailsHelp:(id)sender
{
    NSString *label = @"Previews and thumbnails are used for displaying online and in CORE/Quicpost. Full-size images are used to produce prints and products. Orders cannot be processed without full-size images.";
    
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(260, 81)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)startWizard:(id)sender
{
    if (wizardWindowController == nil) {
        wizardWindowController = [[WizardWindowController alloc] initWithMainWindowController:self];
    }
    
    [wizardWindowController showWindow:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [tblTransfers reloadData];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:transferManager
        selector:@selector(processTransfers) userInfo:nil repeats:YES];

    //NSImage *img = [[NSImage alloc] initWithContentsOfFile:@"/Users/blagovest/Downloads/lotus.jpg"];
    //[imgUploading1 setImage:img];
}

- (void)windowWillClose:(NSNotification *)notification
{
}

- (BOOL)windowShouldClose:(id)sender
{
    /*NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to quit?"
        defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@""];
    
    NSModalResponse response = [alert runModal];
    return response == NSModalResponseOK ? YES : NO;*/
    return YES;
}

@end
