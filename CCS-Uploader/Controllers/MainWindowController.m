#import "MainWindowController.h"
#import "Prefs/AdvancedViewController.h"

#import "../Models/TransferManager.h"

@interface MainWindowController () {
    IBOutlet NSTableView *tblTransfers;
    IBOutlet NSMenu *menuThumbnails;
    IBOutlet NSBox *currentTransfer;
    IBOutlet NSProgressIndicator *transferProgress;
    IBOutlet NSTextField *transferProgressTitle;
    IBOutlet NSImageView
        *imgUploading1, *imgUploading2, *imgUploading3, *imgUploading4,
        *imgUploading5, *imgUploading6, *imgUploading7, *imgUploading8;
    
    TransferManager *transferManager;
    NSMutableArray *filteredTransfers;
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
    }
    
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return transferManager.transfers.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 18;
}

- (IBAction)stopOrResumeTransfer:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];

    if (clickedRow != -1) {
        Transfer *transfer = transferManager.transfers[clickedRow];
        
        if (transfer.status == kTransferStatusStopped) {
            transfer.status = kTransferStatusQueued;
            transferManager.reloadTransfers();
        } else if (transfer.status == kTransferStatusRunning) {
            [transferManager stopCurrentTransfer];
        }
    }
}

- (IBAction)removeTransfer:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];

    if (clickedRow != -1) {
        [tblTransfers removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:clickedRow] withAnimation:NSTableViewAnimationEffectFade];
        [transferManager.transfers removeObjectAtIndex:clickedRow];
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
    
    static NSString *transferStatuses[] = {@"Queued to run", @"Running", @"Scheduled", @"Aborted", @"Stopped", @"Complete"};
    
    if ([tableColumn.identifier isEqualToString:@"Event"]) {
        result.textField.stringValue = [NSString stringWithFormat:@"%@ (%@)", transfer.eventName, transfer.orderNumber];
    } else if ([tableColumn.identifier isEqualToString:@"Status"]) {
        if (transfer.status != kTransferStatusScheduled) {
            result.textField.stringValue = transferStatuses[transfer.status];
        } else {
            result.textField.stringValue = [NSString stringWithFormat:@"Scheduled for %@", transfer.dateScheduled];
        }
    } else if ([tableColumn.identifier isEqualToString:@"Thumbs"]) {
        result.textField.stringValue = transfer.uploadThumbs ?
            (transfer.thumbsUploaded ? @"Uploaded" : @"Not yet active") : @"Not included";
    } else if ([tableColumn.identifier isEqualToString:@"Fullsize"]) {
        result.textField.stringValue = transfer.uploadFullsize ?
            (transfer.fullsizeUploaded ? @"Uploaded" : @"Not yet active") : @"Not included";
    } else if ([tableColumn.identifier isEqualToString:@"Date"]) {
        result.textField.stringValue = [dateFormatter stringFromDate:transfer.datePushed];
    } else if ([tableColumn.identifier isEqualToString:@"Progress"]) {
        NSProgressIndicator *progressIndicator = (NSProgressIndicator *)result.subviews[0];
        
        if (transfer.status == kTransferStatusQueued || transfer.status == kTransferStatusRunning) {
            [progressIndicator startAnimation:nil];
            [progressIndicator setHidden:NO];
        } else {
            [progressIndicator stopAnimation:nil];
            [progressIndicator setHidden:YES];
        }
    } else if ([tableColumn.identifier isEqualToString:@"Stop"]) {
        NSButtonCell *btn = (NSButtonCell *)result;
        
        if (transfer.status == kTransferStatusRunning) {
            btn.title = @"Stop";
            [result setHidden:NO];
        } else if (transfer.status == kTransferStatusStopped) {
            btn.title = @"Resume";
            [result setHidden:NO];
        } else {
            [result setHidden:YES];
        }
    } else if ([tableColumn.identifier isEqualToString:@"Delete"]) {
        if (transfer.status == kTransferStatusRunning) {
            [result setHidden:YES];
        } else {
            [result setHidden:NO];
        }
    }
    
    return result;
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
    WizardWindowController *wizardWindowController = [[WizardWindowController alloc] initWithMainWindowController:self];
    [wizardWindowController showWindow:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    transferManager.reloadTransfers = ^(void) {
        NSInteger selectedRow = tblTransfers.selectedRow;
        [tblTransfers reloadData];
        [tblTransfers selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
    };
    
    transferManager.startedUploadingImage = ^(NSInteger slot, NSString *pathToImage) {
        NSArray *imageViews = [NSArray arrayWithObjects:
            imgUploading1, imgUploading2, imgUploading3, imgUploading4,
            imgUploading5, imgUploading6, imgUploading7, imgUploading8, nil];
        
        NSImageView *imageView = imageViews[slot];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
        imageView.image = image;
    };
    
    transferManager.endedUploadingImage = ^(NSInteger slot) {
        NSArray *imageViews = [NSArray arrayWithObjects:
            imgUploading1, imgUploading2, imgUploading3, imgUploading4,
            imgUploading5, imgUploading6, imgUploading7, imgUploading8, nil];
        
        NSImageView *imageView = imageViews[slot];
        imageView.image = nil;
    };
    
    transferManager.transferStateChanged = ^(NSString *message) {
        currentTransfer.title = [NSString stringWithFormat:@"%@ (%@): %@",
            transferManager.currentlyRunningTransfer.eventName,
            transferManager.currentlyRunningTransfer.orderNumber,
            message];
    };

    [transferProgress startAnimation:nil];
    transferProgressTitle.stringValue = @"";
    transferManager.progressIndicator = transferProgress;
    transferManager.progressTitle = transferProgressTitle;
    currentTransfer.title = @"";
    
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:transferManager
        selector:@selector(processTransfers) userInfo:nil repeats:YES];
}

@end
