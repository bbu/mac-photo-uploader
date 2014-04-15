#import "MainWindowController.h"
#import "Prefs/AdvancedViewController.h"

#import "../Models/TransferManager.h"
#import "../Services/VersionService.h"

@interface MainWindowController () {
    IBOutlet NSPopUpButton *btnFilterTransfers;
    IBOutlet NSTableView *tblTransfers;
    IBOutlet NSMenu *menuThumbnails;
    IBOutlet NSBox *currentTransfer;
    IBOutlet NSProgressIndicator *transferProgress;
    IBOutlet NSTextField *transferProgressTitle;
    
    IBOutlet NSImageView
        *imgUploading1, *imgUploading2, *imgUploading3, *imgUploading4,
        *imgUploading5, *imgUploading6, *imgUploading7, *imgUploading8;
    
    IBOutlet NSTextField
        *lblUploading1, *lblUploading2, *lblUploading3, *lblUploading4,
        *lblUploading5, *lblUploading6, *lblUploading7, *lblUploading8;

    IBOutlet NSPopover *errorsPopover;
    IBOutlet NSTextView *txtErrors;
    
    TransferManager *transferManager;
    NSMutableSet *openedEvents;
    NSMutableArray *filteredTransfers;
    NSDateFormatter *dateFormatter, *timeFormatter;
    
    VersionService *versionService;
}

@end

static NSString *transferStatuses[] = {
    @"",
    @"Running",
    @"Queued",
    @"Stopped",
    @"Scheduled",
    @"Failed with errors",
    @"Complete",
    @"Aborted",
};

@implementation MainWindowController
@synthesize transferManager;
@synthesize openedEvents;

- (id)init
{
    self = [super initWithWindowNibName:@"MainWindow"];
    
    if (self) {
        transferManager = [TransferManager new];
        filteredTransfers = [transferManager.transfers copy];
        
        openedEvents = [NSMutableSet new];
        
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"MM/dd/Y";
        
        timeFormatter = [NSDateFormatter new];
        timeFormatter.dateFormat = @"MM/dd/Y, hh:mm a";

        versionService = [VersionService new];
    }
    
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return filteredTransfers.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    Transfer *transfer = filteredTransfers[row];
    return transfer.status == 0 ? 13 : 18;
}

- (IBAction)stopOrResumeTransfer:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];

    if (clickedRow != -1) {
        Transfer *transfer = filteredTransfers[clickedRow];
        
        if (transfer.status == kTransferStatusStopped) {
            transfer.status = kTransferStatusQueued;
            transferManager.reloadTransfers();
        } else if (transfer.status == kTransferStatusRunning) {
            [transferManager stopCurrentTransfer];
        } else if (transfer.status == kTransferStatusQueued) {
            transfer.status = kTransferStatusStopped;
            transferManager.reloadTransfers();
        } else if (transfer.status == kTransferStatusAborted || transfer.status == kTransferStatusComplete || transfer.status == kTransferStatusErrors) {
            transfer.status = kTransferStatusQueued;
            transferManager.reloadTransfers();
        }
    }
}

- (IBAction)removeTransfer:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];

    if (clickedRow != -1) {
        Transfer *transfer = filteredTransfers[clickedRow];
        
        [tblTransfers removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:clickedRow] withAnimation:NSTableViewAnimationEffectFade];
        [filteredTransfers removeObjectAtIndex:clickedRow];
        [transferManager.transfers removeObject:transfer];
    }
}

- (IBAction)viewTransferErrors:(id)sender
{
    NSInteger clickedRow = [tblTransfers rowForView:sender];
    
    if (clickedRow != -1) {
        Transfer *transfer = filteredTransfers[clickedRow];
        
        txtErrors.string = transfer.errors;
        [errorsPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxYEdge];
    }
}

- (void)openEvent:(NSDictionary *)params filename:(NSString *)filename
{
    WizardWindowController *wizardWindowController = [[WizardWindowController alloc] initWithMainWindowController:self];

    [wizardWindowController showEvent:params[@"OrderNumber"]
        user:params[@"Email"] pass:params[@"Password"] url:params[@"URL"] source:params[@"Source"] filename:filename];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    Transfer *transfer = filteredTransfers[row];
    return transfer.status != 0;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    Transfer *transfer = filteredTransfers[row];

    if (transfer.status == 0) {
        NSTextField *result = [tableView makeViewWithIdentifier:@"grp" owner:self];
        
        if (result == nil) {
            result = [[NSTextField alloc] initWithFrame:NSZeroRect];
            result.identifier = tableColumn.identifier;
            result.drawsBackground = NO;
            result.bezeled = NO;
            result.font = [NSFont systemFontOfSize:10];
        }
        
        result.objectValue = transfer.eventName;
        return result;
    } else {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
        
        if (cellView == nil) {
            cellView = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
            cellView.identifier = tableColumn.identifier;
        }
        
        if ([tableColumn.identifier isEqualToString:@"Event"]) {
            cellView.textField.stringValue = [NSString stringWithFormat:@"%@: %@", transfer.orderNumber, transfer.eventName];
        } else if ([tableColumn.identifier isEqualToString:@"Status"]) {
            if (transfer.status != kTransferStatusScheduled) {
                cellView.textField.stringValue = transferStatuses[transfer.status];
            } else {
                cellView.textField.stringValue = [NSString stringWithFormat:@"Scheduled for %@",
                    [timeFormatter stringFromDate:transfer.dateScheduled]];
            }
        } else if ([tableColumn.identifier isEqualToString:@"Thumbs"] || [tableColumn.identifier isEqualToString:@"Fullsize"]) {
            BOOL doUpload = [tableColumn.identifier isEqualToString:@"Thumbs"] ? transfer.uploadThumbs : transfer.uploadFullsize;
            BOOL uploaded = [tableColumn.identifier isEqualToString:@"Thumbs"] ? transfer.thumbsUploaded : transfer.fullsizeUploaded;
            
            if (transfer.status == kTransferStatusComplete) {
                cellView.textField.stringValue = doUpload ? (uploaded ? @"Uploaded" : @"In progress") : @"Not included";
            } else if (transfer.status == kTransferStatusAborted || transfer.status == kTransferStatusErrors) {
                cellView.textField.stringValue = doUpload ? (uploaded ? @"Attempted" : @"Not attempted") : @"Not included";
            } else if (transfer.status == kTransferStatusRunning) {
                cellView.textField.stringValue = doUpload ? (uploaded ? @"Uploaded" : @"In progress") : @"Not included";
            } else if (transfer.status == kTransferStatusQueued || transfer.status == kTransferStatusScheduled) {
                cellView.textField.stringValue = doUpload ? (uploaded ? @"Uploaded" : @"To be uploaded") : @"Not included";
            } else if (transfer.status == kTransferStatusStopped) {
                cellView.textField.stringValue = doUpload ? (uploaded ? @"Uploaded" : @"Stopped") : @"Not included";
            }
        } else if ([tableColumn.identifier isEqualToString:@"Date"]) {
            cellView.textField.stringValue = [timeFormatter stringFromDate:transfer.datePushed];
        } else if ([tableColumn.identifier isEqualToString:@"Progress"]) {
            NSProgressIndicator *progressIndicator = (NSProgressIndicator *)cellView.subviews[0];
            
            if (transfer.status == kTransferStatusQueued || transfer.status == kTransferStatusRunning) {
                [progressIndicator startAnimation:nil];
                [progressIndicator setHidden:NO];
            } else {
                [progressIndicator stopAnimation:nil];
                [progressIndicator setHidden:YES];
            }
        } else if ([tableColumn.identifier isEqualToString:@"Stop"]) {
            NSButtonCell *btn = (NSButtonCell *)cellView;
            
            if (transfer.status == kTransferStatusRunning || transfer.status == kTransferStatusQueued) {
                btn.title = @"Stop";
                [cellView setHidden:NO];
            } else if (transfer.status == kTransferStatusStopped) {
                btn.title = @"Resume";
                [cellView setHidden:NO];
            } else if (transfer.status == kTransferStatusAborted || transfer.status == kTransferStatusErrors) {
                btn.title = @"Retry";
                [cellView setHidden:NO];
            } else {
                [cellView setHidden:YES];
            }
        } else if ([tableColumn.identifier isEqualToString:@"Delete"]) {
            if (transfer.status == kTransferStatusRunning) {
                [cellView setHidden:YES];
            } else {
                [cellView setHidden:NO];
            }
        } else if ([tableColumn.identifier isEqualToString:@"Errors"]) {
            if (transfer.errors && transfer.errors.length != 0) {
                [cellView setHidden:NO];
            } else {
                [cellView setHidden:YES];
            }
        }

        return cellView;
    }
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    Transfer *transfer = filteredTransfers[row];
    return transfer.status == 0;
}

- (IBAction)rowDoubleClicked:(id)sender
{
    NSInteger clickedRow = tblTransfers.selectedRow;

    if (clickedRow == -1) {
        return;
    }
    
    Transfer *transfer = filteredTransfers[clickedRow];
    
    if (transfer.status == 0) {
        return;
    }
    
    WizardWindowController *wizardWindowController = [[WizardWindowController alloc] initWithMainWindowController:self];
    [wizardWindowController openEvent:transfer.orderNumber isQuicPost:transfer.isQuicPost];
}

- (IBAction)previewsAndThumbnailsHelp:(id)sender
{
    NSString *label =
        @"Previews and thumbnails are used for displaying online and in CORE/Quicpost. "
        @"Full-size images are used to produce prints and products. "
        @"Orders cannot be processed without full-size images.";
    
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(260, 81)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)startWizard:(id)sender
{
    WizardWindowController *wizardWindowController = [[WizardWindowController alloc] initWithMainWindowController:self];
    [wizardWindowController showWindow:self];
}

- (IBAction)filterTransfersClicked:(id)sender
{
    transferManager.reloadTransfers();
}

- (void)checkForUpdate
{
    [versionService startCheckVersion:
        ^(VersionResult *result) {
            if (!result.error && !result.errorOccurred && result.upgradeAvailable) {
                NSAlert *alert;
                
                if (result.upgradeRequired) {
                    alert = [NSAlert alertWithMessageText:result.message
                        defaultButton:[NSString stringWithFormat:@"Update to %@", result.latestVersion]
                        alternateButton:@"Release History"
                        otherButton:@"Visit Website"
                        informativeTextWithFormat:@"%@", result.latestNotes ? result.latestNotes : @""];
                } else {
                    alert = [NSAlert alertWithMessageText:@""
                        defaultButton:@"Yes"
                        alternateButton:@"No"
                        otherButton:@"Visit Website"
                        informativeTextWithFormat:@"%@", result.latestNotes ? result.latestNotes : @""];

                    alert.messageText = [NSString stringWithFormat:@"A new version is available.\r\rWould you like to update to version %@ now?", result.latestVersion];
                }
                
                NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
                
                [alert beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse response) {
                        if (response == NSModalResponseOK) {
                            [workspace openURL:[NSURL URLWithString:result.installerURL]];
                            [transferManager save];
                            [NSApp terminate:nil];
                        } else if (response == -1) {
                            [workspace openURL:[NSURL URLWithString:result.websiteURL]];
                        } else if (response == NSModalResponseCancel) {
                            if (result.upgradeRequired) {
                                [workspace openURL:[NSURL URLWithString:result.releaseHistoryURL]];
                            }
                        }
                    }
                ];
            }
        }
    ];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    transferManager.reloadTransfers = ^(void) {
        filteredTransfers = [[transferManager.transfers
            sortedArrayUsingComparator:^NSComparisonResult(Transfer *transfer1, Transfer *transfer2) {
                if (transfer1.status < transfer2.status) {
                    return NSOrderedAscending;
                } else if (transfer1.status == transfer2.status) {
                    return NSOrderedSame;
                } else {
                    return NSOrderedDescending;
                }
            }
        ] mutableCopy];
        
        NSIndexSet *transferIndexesToFilterOut = [filteredTransfers
            indexesOfObjectsPassingTest:^BOOL(Transfer *transfer, NSUInteger idx, BOOL *stop) {
                return btnFilterTransfers.selectedTag ? btnFilterTransfers.selectedTag != transfer.status : NO;
            }
        ];
        
        [filteredTransfers removeObjectsAtIndexes:transferIndexesToFilterOut];
        
        if (btnFilterTransfers.selectedTag == 0) {
            NSMutableIndexSet *groupIndexes = [NSMutableIndexSet new];
            NSMutableArray *groups = [NSMutableArray new];
            TransferStatus currentStatus = 0;
            NSUInteger currentIndex = 0;
            NSUInteger groupsAdded = 0;
            
            for (Transfer *transfer in filteredTransfers) {
                if (!currentStatus || transfer.status != currentStatus) {
                    currentStatus = transfer.status;
                    
                    Transfer *group = [Transfer new];
                    group.status = 0;
                    group.eventName = transferStatuses[currentStatus];
                    
                    [groupIndexes addIndex:currentIndex + groupsAdded];
                    [groups addObject:group];
                    
                    groupsAdded++;
                }
                
                currentIndex++;
            }

            [filteredTransfers insertObjects:groups atIndexes:groupIndexes];
        }
        
        [tblTransfers reloadData];
    };
    
    transferManager.startedUploadingImage = ^(NSInteger slot, NSString *pathToImage) {
        NSArray *imageViews = @[
            imgUploading1, imgUploading2, imgUploading3, imgUploading4,
            imgUploading5, imgUploading6, imgUploading7, imgUploading8,
        ];
        
        NSArray *labels = @[
            lblUploading1, lblUploading2, lblUploading3, lblUploading4,
            lblUploading5, lblUploading6, lblUploading7, lblUploading8,
        ];
        
        NSImageView *imageView = imageViews[slot];
        NSTextField *label = labels[slot];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
        label.stringValue = pathToImage;
        
        NSArray *pathComponents = pathToImage.pathComponents;
        
        if (pathComponents.count >= 2) {
            NSString *roll = pathComponents[pathComponents.count - 2];
            NSString *frame = pathComponents[pathComponents.count - 1];
            label.stringValue = [NSString stringWithFormat:@"%@\r%@", roll, frame];
        }
        
        imageView.image = image;
    };
    
    transferManager.endedUploadingImage = ^(NSInteger slot) {
        NSArray *imageViews = @[
            imgUploading1, imgUploading2, imgUploading3, imgUploading4,
            imgUploading5, imgUploading6, imgUploading7, imgUploading8,
        ];
        
        NSArray *labels = @[
            lblUploading1, lblUploading2, lblUploading3, lblUploading4,
            lblUploading5, lblUploading6, lblUploading7, lblUploading8,
        ];

        NSImageView *imageView = imageViews[slot];
        NSTextField *label = labels[slot];
        label.stringValue = @"";
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
    transferManager.openedEvents = openedEvents;
    [transferManager reload];
    
    [NSTimer scheduledTimerWithTimeInterval:0.2 target:transferManager
        selector:@selector(processTransfers) userInfo:nil repeats:YES];
    
    [self checkForUpdate];
    
    [NSTimer scheduledTimerWithTimeInterval:12 * 3600 target:self
        selector:@selector(checkForUpdate) userInfo:nil repeats:YES];
    
    self.window.title = [NSString stringWithFormat:@"CCS Uploader %@",
        [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
}

@end
