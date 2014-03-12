#import "../../Utils/FileUtil.h"

#import "BrowseViewController.h"
#import "../WizardWindowController.h"
#import "../../Models/OrderModel.h"

#import "../../Services/CheckOrderNumberService.h"
#import "../../Services/EventSettingsService.h"
#import "../../Services/UploadExtensionsService.h"
#import "../../Services/ListDivisionsService.h"

#import <Quartz/Quartz.h>

@interface ImageInBrowserView : NSObject {
    NSString *filepath;
    FrameModel *frameModel;
}
@end

@implementation ImageInBrowserView

- (id)initWithFrameModel:(FrameModel *)frame path:(NSString *)path
{
    self = [super init];
    
    if (self) {
        filepath = path;
        frameModel = frame;
    }
    
    return self;
}

- (NSString *)imageRepresentationType
{
    return IKImageBrowserPathRepresentationType;
}

- (id)imageRepresentation
{
    return filepath;
}

- (NSString *)imageUID
{
    return filepath;
}

- (id)imageTitle
{
    return [NSString stringWithFormat:@"%@", [frameModel.name stringByAppendingPathExtension:frameModel.extension]];
}

- (id)imageSubtitle
{
    return [NSString stringWithFormat:@"%@%ld × %ld", frameModel.fullsizeSent ? @"[Sent] " : @"", frameModel.width, frameModel.height];
}

- (NSUInteger)imageVersion
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
    return attributes.fileModificationDate.hash + attributes.fileSize;
}
@end

@interface BrowseViewController () <NSTableViewDelegate, NSTableViewDataSource> {
    WizardWindowController *wizardWindowController;

    IBOutlet NSTableView *tblRolls;
    IBOutlet NSTextField *loadingTitle;
    IBOutlet NSProgressIndicator *loadingIndicator;
    IBOutlet NSButton *btnBrowse, *btnGreenScreen, *btnPhotographers, *btnAdvancedOptions;
    IBOutlet NSButton
        *chkAutoCategorizeImages,
        *chkPutImagesInCurrentlySelectedRoll,
        *chkAutoNumberRolls,
        *chkAutoNumberFrames,
        *chkHonourFramesPerRoll;

    IBOutlet NSPopover *advancedOptionsPopover, *viewRollPopover;
    IBOutlet NSPanel *includeNewlyAddedImagesSheet;
    IBOutlet NSTextView *txtNewFiles;
    
    IBOutlet IKImageBrowserView *imageBrowserView;
    IBOutlet NSTextField *imageBrowserTitle;
    IBOutlet NSPopUpButton *btnRotationDegrees, *btnRotationDirection;
    IBOutlet NSButton *btnDeleteSelectedFrames;
    NSMutableArray *imagesInBrowser;
    BOOL rollsNeedReload;
    
    CheckOrderNumberService *checkOrderNumberService;
    EventSettingsService *eventSettingsService;
    UploadExtensionsService *uploadExtensionsService;
    ListDivisionsService *listDivisionsService;
    
    OrderModel *orderModel;
    
    NSInteger framesPerRoll;
    BOOL usingPreloader;
    RollModel *rollModelShown;
    
    EventSettingsResult *eventSettings;
    NSMutableArray *uploadExtensions;
    NSString *ccsPassword;
}

@end

@implementation BrowseViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"BrowseView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
        checkOrderNumberService = [CheckOrderNumberService new];
        eventSettingsService = [EventSettingsService new];
        uploadExtensionsService = [UploadExtensionsService new];
        listDivisionsService = [ListDivisionsService new];
        imagesInBrowser = [NSMutableArray new];
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    [tblRolls registerForDraggedTypes:[NSArray arrayWithObject:(NSString *)kUTTypeFileURL]];
}

- (void)copyImagesInBackground:(NSDictionary *)params
{
    [orderModel addNewImages:params[@"URLs"]
        inRoll:((NSNumber *)params[@"inRoll"]).integerValue
        framesPerRoll:((NSNumber *)params[@"framesPerRoll"]).integerValue
        autoNumberRolls:((NSNumber *)params[@"autoNumberRolls"]).boolValue
        autoNumberFrames:((NSNumber *)params[@"autoNumberFrames"]).boolValue
        statusField:loadingTitle];

    [orderModel save];

    [tblRolls performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(enableControls) withObject:nil waitUntilDone:YES];
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *pasteboard = info.draggingPasteboard;
    NSArray *acceptedTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeFolder, nil];
    
    NSArray *URLs = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]]
        options:@{
            NSPasteboardURLReadingFileURLsOnlyKey: [NSNumber numberWithBool:YES],
            NSPasteboardURLReadingContentsConformToTypesKey: acceptedTypes
        }
    ];
    
    NSDictionary *params = @{
        @"URLs": URLs,
        @"inRoll": [NSNumber numberWithInteger:chkPutImagesInCurrentlySelectedRoll.state == NSOnState ? tblRolls.selectedRow : (op == NSTableViewDropOn ? row : -1)],
        @"framesPerRoll": [NSNumber numberWithInteger:chkHonourFramesPerRoll.state == NSOnState ? framesPerRoll : 9999],
        @"autoNumberRolls": [NSNumber numberWithBool:chkAutoNumberRolls.state == NSOnState ? YES : NO],
        @"autoNumberFrames": [NSNumber numberWithBool:chkAutoNumberFrames.state == NSOnState ? YES : NO]
    };
    
    [self disableControls:@"Preparing to copy files"];
    [self performSelectorInBackground:@selector(copyImagesInBackground:) withObject:params];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id<NSDraggingInfo>)info
    proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    return NSDragOperationCopy;
}

- (IBAction)browseForImagesClicked:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *defaultLocation = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultImageBrowseLocation];
    
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = YES;
    openPanel.message = @"Select image files or folders to upload. Any selected folders will be scanned recursively for image files.";

    [openPanel setFrame:NSMakeRect(0, 0, wizardWindowController.window.frame.size.width,
        wizardWindowController.window.frame.size.height) display:YES];
    
    if (defaultLocation) {
        [openPanel setDirectoryURL:[NSURL fileURLWithPath:defaultLocation]];
    }
    
    [openPanel beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                NSDictionary *params = @{
                    @"URLs": openPanel.URLs,
                    @"inRoll": [NSNumber numberWithInteger:chkPutImagesInCurrentlySelectedRoll.state == NSOnState ? tblRolls.selectedRow : -1],
                    @"framesPerRoll": [NSNumber numberWithInteger:chkHonourFramesPerRoll.state == NSOnState ? framesPerRoll : 9999],
                    @"autoNumberRolls": [NSNumber numberWithBool:chkAutoNumberRolls.state == NSOnState ? YES : NO],
                    @"autoNumberFrames": [NSNumber numberWithBool:chkAutoNumberFrames.state == NSOnState ? YES : NO]
                };
                
                [self disableControls:@"Preparing to copy files"];
                [self performSelectorInBackground:@selector(copyImagesInBackground:) withObject:params];
            }
        }
    ];
}

- (void)disableControls:(NSString *)status
{
    [btnBrowse setEnabled:NO];
    [btnGreenScreen setEnabled:NO];
    [btnPhotographers setEnabled:NO];
    [btnAdvancedOptions setEnabled:NO];
    [tblRolls setEnabled:NO];
    
    [wizardWindowController.btnCancel setEnabled:NO];
    [wizardWindowController.btnBack setEnabled:NO];
    [wizardWindowController.btnNext setEnabled:NO];
    
    [loadingIndicator startAnimation:nil];
    [loadingTitle setStringValue:status];
    [loadingTitle setHidden:NO];
}

- (void)enableControls
{
    [btnBrowse setEnabled:YES];
    [btnGreenScreen setEnabled:YES];
    [btnPhotographers setEnabled:YES];
    [btnAdvancedOptions setEnabled:YES];
    [tblRolls setEnabled:YES];
    
    [wizardWindowController.btnCancel setEnabled:YES];
    [wizardWindowController.btnBack setEnabled:YES];
    [wizardWindowController.btnNext setEnabled:YES];
    
    [loadingIndicator stopAnimation:nil];
    [loadingTitle setHidden:YES];
}

- (IBAction)advancedOptionsClicked:(id)sender
{
    if (advancedOptionsPopover.isShown) {
        [advancedOptionsPopover close];
    } else {
        [advancedOptionsPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return orderModel.rolls.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    id view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if ([columnID isEqualToString:@"Folder"]) {
        NSTableCellView *cell = view;
        cell.imageView.image = [NSImage imageNamed:@"NSFolder"];
        cell.textField.stringValue = ((RollModel *)orderModel.rolls[row]).number;
    } else if ([columnID isEqualToString:@"Photographer"]) {
        NSPopUpButton *btn = view;
        [btn addItemWithTitle:@"None"];
        [btn addItemWithTitle:@"photographer 1"];
        [btn addItemWithTitle:@"photographer 2"];
        [btn addItemWithTitle:@"photographer 3"];
    } else if ([columnID isEqualToString:@"Size"]) {
        NSTableCellView *cell = view;
        cell.textField.stringValue = [FileUtil humanFriendlyFilesize:((RollModel *)orderModel.rolls[row]).totalFrameSize];
    } else if ([columnID isEqualToString:@"Count"]) {
        NSTableCellView *cell = view;
        cell.textField.stringValue = [NSString stringWithFormat:@"%lu", ((RollModel *)orderModel.rolls[row]).frames.count];
    } else if ([columnID isEqualToString:@"GreenScreen"]) {
        NSTableCellView *cell = view;
        //[NSImage imageNamed:@"NSStatusNone"] : [NSImage imageNamed:@"NSMenuOnStateTemplate"]
        //
        cell.imageView.image = row % 2 ? [NSImage imageNamed:@"NSStatusNone"] : [NSImage imageNamed:@"NSStatusNone"];
    } else if ([columnID isEqualToString:@"CurrentTask"]) {
        NSTableCellView *cell = view;
        //cell.textField.stringValue = @"Uploading thumbnails...";
        [((NSProgressIndicator *)cell.subviews[1]) setHidden:YES];
        [((NSTextField *)cell.subviews[0]) setHidden:YES];
        //[((NSProgressIndicator *)cell.subviews[1]) startAnimation:nil];
    }
    
    return view;
}

- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard
{
    void (^terminate)(NSString *) = ^(NSString *message) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = message;
        
        if (fromWizard) {
            [wizardWindowController showStep:kWizardStepEvents];
        }
        
        [alert beginSheetModalForWindow:wizardWindowController.window
            completionHandler:fromWizard ? nil : ^(NSModalResponse response) {
                [wizardWindowController.window close];
            }
        ];
    };
    
    NSString *effectiveUser, *effectivePass;
    NSInteger effectiveService;
    NSString *effectiveCoreDomain;
    
    if (fromWizard) {
        effectiveUser = wizardWindowController.effectiveUser;
        effectivePass = wizardWindowController.effectivePass;
        effectiveService = wizardWindowController.effectiveService;
        effectiveCoreDomain = wizardWindowController.effectiveCoreDomain;
    } else {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *selectedService = [defaults objectForKey:kQuicPostSelected];
        
        if (selectedService == nil || selectedService.boolValue) {
            effectiveUser = [defaults objectForKey:kQuicPostUser];
            effectivePass = [defaults objectForKey:kQuicPostPass];
            effectiveService = kServiceRootQuicPost;
            effectiveCoreDomain = nil;
        } else {
            effectiveUser = [defaults objectForKey:kCoreUser];
            effectivePass = [defaults objectForKey:kCorePass];
            effectiveService = kServiceRootCore;
            effectiveCoreDomain = [defaults objectForKey:kCoreDomain];
        }
        
        wizardWindowController.effectiveUser = effectiveUser;
        wizardWindowController.effectivePass = effectivePass;
        wizardWindowController.effectiveService = effectiveService;
        wizardWindowController.effectiveCoreDomain = effectiveCoreDomain;
    }
    
    [checkOrderNumberService setEffectiveServiceRoot:effectiveService coreDomain:effectiveCoreDomain];
    
    BOOL started = [checkOrderNumberService startCheckOrderNumber:effectiveUser password:effectivePass orderNumber:event.orderNumber
        complete:^(CheckOrderNumberResult *result) {
            if (result.error) {
                terminate([NSString stringWithFormat:@"Could not check the selected event. An error occurred: %@", result.error.localizedDescription]);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    ccsPassword = result.ccsPassword;

                    [eventSettingsService startGetEventSettings:event.ccsAccount password:ccsPassword orderNumber:event.orderNumber
                        complete:^(EventSettingsResult *result) {
                            if (result.error) {
                                terminate([NSString stringWithFormat:@"Could not not obtain the event's settings. An error occurred: %@", result.error.localizedDescription]);
                            } else {
                                if ([result.status isEqualToString:@"AuthenticationSuccessful"]) {
                                    eventSettings = result;
                                    
                                    [uploadExtensionsService startGetUploadExtensions:event.ccsAccount password:ccsPassword
                                        complete:^(UploadExtensionsResult *result) {
                                            if (result.error) {
                                                terminate([NSString stringWithFormat:
                                                    @"Could not obtain allowed upload file extensions. An error occurred: %@",
                                                    result.error.localizedDescription]);
                                            } else {
                                                if ([result.status isEqualToString:@"Successful"]) {
                                                    uploadExtensions = result.extensions;
                                                    NSError *error = nil;
                                                    [self view];
                                                    orderModel = nil;
                                                    [tblRolls reloadData];
                                                    
                                                    orderModel = [[OrderModel alloc] initWithEventRow:event error:&error];
                                                    
                                                    if (orderModel == nil) {
                                                        terminate([NSString stringWithFormat:@"An error occurred while loading up the event. %@", error.localizedDescription]);
                                                    } else {
                                                        [self loadEvent];
                                                    }
                                                } else {
                                                    terminate([NSString stringWithFormat:
                                                        @"Could not obtain allowed upload file extensions. The server returned \"%@\".", result.status]);
                                                }
                                            }
                                        }
                                    ];
                                } else {
                                    terminate([NSString stringWithFormat:@"Could not obtain the event's settings. The server returned \"%@\".", result.status]);
                                }
                            }
                        }
                    ];
                } else {
                    terminate([NSString stringWithFormat:@"The server rejected the selected event \"%@\".", event.orderNumber]);
                }
            }
        }
    ];
    
    if (started) {
        wizardWindowController.loadingViewController.txtMessage.stringValue = @"Checking the event and verifying local files...";
        [wizardWindowController showStep:kWizardStepLoading];
    }
}

- (void)loadEvent
{
    wizardWindowController.eventRow = orderModel.eventRow;
    
    NSData *storedMarketRows = [[NSUserDefaults standardUserDefaults] objectForKey:@"marketSettingsRows"];
    NSArray *marketSettingsRows = nil;
    
    if (storedMarketRows) {
        marketSettingsRows = [NSKeyedUnarchiver unarchiveObjectWithData:storedMarketRows];
    }
    
    BOOL found = NO;

    if (marketSettingsRows) {
        for (NSDictionary *marketRow in marketSettingsRows) {
            if ([marketRow[@"Market"] isEqualToString:orderModel.eventRow.market]) {
                found = YES;
                
                NSNumber *usePreloader = marketRow[@"UsePreloader"];
                NSNumber *imageCount = marketRow[@"Images"];
                
                usingPreloader = usePreloader ? usePreloader.boolValue : NO;
                framesPerRoll = imageCount ? imageCount.integerValue : 9999;
                
                break;
            }
        }
    }
    
    if (!found) {
        usingPreloader = NO;
        framesPerRoll = 9999;
    }
    
    chkHonourFramesPerRoll.title = [NSString stringWithFormat:@"Create new folder after %ld images", framesPerRoll];
    
    if (orderModel.newlyAdded) {
        NSMutableString *newFiles = [NSMutableString new];
        
        for (RollModel *roll in orderModel.rolls) {
            if (roll.newlyAdded) {
                [newFiles appendFormat:@"%@/\r", roll.number];
            }
            
            for (FrameModel *frame in roll.frames) {
                if (frame.newlyAdded) {
                    [newFiles appendFormat:@"%@/%@.%@\r", roll.number, frame.name, frame.extension];
                }
            }
        }
        
        txtNewFiles.string = newFiles;
        
        [NSApp beginSheet:includeNewlyAddedImagesSheet modalForWindow:wizardWindowController.window
            modalDelegate:nil didEndSelector:nil contextInfo:nil];
    } else {
        [tblRolls reloadData];
        [orderModel save];
    }
    
    wizardWindowController.txtStepTitle.stringValue = orderModel.eventRow.eventName;
    wizardWindowController.txtStepDescription.stringValue =
        [NSString stringWithFormat:@"Event Number: %@; Market: %@", orderModel.eventRow.orderNumber, orderModel.eventRow.market];
    
    [wizardWindowController showStep:kWizardStepBrowse];
}

- (IBAction)ignoreNewFiles:(id)sender
{
    [orderModel ignoreNewlyAdded];
    [includeNewlyAddedImagesSheet close];
    [tblRolls reloadData];
    [orderModel save];
    [NSApp endSheet:includeNewlyAddedImagesSheet];
}

- (IBAction)importNewFiles:(id)sender
{
    [orderModel includeNewlyAdded];
    [includeNewlyAddedImagesSheet close];
    [tblRolls reloadData];
    [orderModel save];
    [NSApp endSheet:includeNewlyAddedImagesSheet];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    NSTextField *textField = notification.object;
    NSInteger row = [tblRolls rowForView:textField];
    NSString *oldName = ((RollModel *)orderModel.rolls[row]).number;
    
    if (![textField.stringValue isEqualToString:oldName]) {
        NSError *error = nil;
        
        if (![orderModel renameRollAtIndex:row newName:textField.stringValue error:&error]) {
            NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:@"Unable to rename roll: %@", error.localizedDescription]
                defaultButton:@"OK" alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
            
            [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            textField.stringValue = oldName;
        } else {
            [orderModel save];
        }
    }
}

- (IBAction)changedPhotographer:(id)sender
{
    //NSLog(@"%lu", [tblRolls rowForView:sender]);
    //[tblRolls reloadData];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [tableColumn.identifier isEqualToString:@"Folder"];
}

- (IBAction)clickedDeleteRoll:(id)sender
{
    NSInteger row = [tblRolls rowForView:sender];
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to delete this roll?"
        defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];
    
    [alert beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [orderModel deleteRollAtIndex:row];
                [orderModel save];
                [tblRolls removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationEffectFade];
            }
        }
    ];
}

- (IBAction)clickedViewRoll:(id)sender
{
    NSInteger row = [tblRolls rowForView:sender];
    RollModel *targetRoll = orderModel.rolls[row];
    
    if (rollModelShown == targetRoll) {
        [viewRollPopover close];
        rollModelShown = nil;
        return;
    }
    
    [viewRollPopover close];
    rollModelShown = targetRoll;
    [imagesInBrowser removeAllObjects];
    NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:targetRoll.number];
    
    imageBrowserTitle.stringValue = rollPath;
    
    for (FrameModel *frame in targetRoll.frames) {
        NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
            stringByAppendingPathExtension:frame.extension];
        
        ImageInBrowserView *newEntry = [[ImageInBrowserView alloc] initWithFrameModel:frame path:filepath];
        [imagesInBrowser addObject:newEntry];
    }

    [imageBrowserView reloadData];
    [viewRollPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)selectAllFrames:(id)sender
{
    [imageBrowserView selectAll:nil];    
}

- (IBAction)invertSelectedFrames:(id)sender
{
    NSIndexSet *oldIndexSet = imageBrowserView.selectionIndexes;
    NSMutableIndexSet *invertedIndexSet = [NSMutableIndexSet new];

    for (NSUInteger index = 0; index < rollModelShown.frames.count; ++index) {
        if (![oldIndexSet containsIndex:index]) {
            [invertedIndexSet addIndex:index];
        }
    }
    
    [imageBrowserView setSelectionIndexes:invertedIndexSet byExtendingSelection:NO];
}

- (IBAction)rotateSelectedFrames:(id)sender
{
    /*
    static NSInteger exifTransTable[2][8][3] = {
        {
            {8, 3, 6},
            {7, 4, 5},
            {6, 1, 8},
            {5, 2, 7},
            {2, 7, 4},
            {1, 8, 3},
            {4, 5, 2},
            {3, 6, 1},
        },
        {
            {6, 3, 8},
            {5, 4, 7},
            {8, 1, 6},
            {7, 2, 5},
            {4, 7, 2},
            {3, 8, 1},
            {2, 5, 4},
            {1, 6, 3},
        },
    };
    */
    
    NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:rollModelShown.number];
    
    [imageBrowserView.selectionIndexes
        enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            FrameModel *frame = rollModelShown.frames[index];
            
            NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
                stringByAppendingPathExtension:frame.extension];
            
            if (frame.orientation > 1) {
                [ImageUtil resizeAndRotateImage:filepath outputImageFilename:filepath
                    resizeToMaxSide:0 rotate:kDontRotate compressionQuality:1];
            }
            
            IURotation rotation = kDontRotate;
            
            if (btnRotationDegrees.selectedTag == 1) {
                rotation = btnRotationDirection.selectedTag == 1 ? kRotateCW90 : kRotateCCW90;
            } else if (btnRotationDegrees.selectedTag == 2) {
                rotation = btnRotationDirection.selectedTag == 1 ? kRotateCW180 : kRotateCCW180;
            } else if (btnRotationDegrees.selectedTag == 3) {
                rotation = btnRotationDirection.selectedTag == 1 ? kRotateCW270 : kRotateCCW270;
            }

            [ImageUtil resizeAndRotateImage:filepath outputImageFilename:filepath
                resizeToMaxSide:0 rotate:rotation compressionQuality:0.8];
            
            CGSize newSize = CGSizeZero;
            NSUInteger orientation;
            [ImageUtil getImageProperties:filepath size:&newSize type:frame.imageType orientation:&orientation];
            
            frame.width = newSize.width;
            frame.height = newSize.height;

            NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
            
            if (fileAttrs) {
                rollModelShown.totalFrameSize -= frame.filesize;
                frame.lastModified = fileAttrs.fileModificationDate;
                frame.filesize = fileAttrs.fileSize;
                rollModelShown.totalFrameSize += frame.filesize;
            }
            
            frame.fullsizeSent = NO;
            frame.thumbsSent = NO;
            frame.orientation = 1;
            frame.userDidRotate = YES;
        }
    ];
    
    [imageBrowserView reloadData];
    rollsNeedReload = YES;
}

- (IBAction)deleteSelectedFrames:(id)sender
{
    NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:rollModelShown.number];
    
    [imageBrowserView.selectionIndexes
        enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            FrameModel *frame = rollModelShown.frames[index];

            NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
                stringByAppendingPathExtension:frame.extension];

            frame.needsDelete = YES;
            rollModelShown.totalFrameSize -= frame.filesize;
            
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        }
    ];
    
    NSIndexSet *frameIndexesToRemove = [rollModelShown.frames
        indexesOfObjectsPassingTest:^BOOL(FrameModel *frame, NSUInteger idx, BOOL *stop) {
            return frame.needsDelete;
        }
    ];
    
    [rollModelShown.frames removeObjectsAtIndexes:frameIndexesToRemove];
    [imagesInBrowser removeObjectsAtIndexes:frameIndexesToRemove];
    [imageBrowserView reloadData];
    
    rollsNeedReload = YES;
}

- (IBAction)sliderDidMove:(id)sender
{
    NSSlider *slider = sender;
    imageBrowserView.zoomValue = slider.floatValue / 100.;
}

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)view
{
    //NSLog(@"selection changed: %lu", imageBrowserView.selectionIndexes.count);
    NSUInteger numSelected = imageBrowserView.selectionIndexes.count;
    
    if (numSelected == 1) {
        btnDeleteSelectedFrames.title = @"Delete Selected";
        [btnDeleteSelectedFrames setEnabled:YES];
    } else if (numSelected > 1) {
        btnDeleteSelectedFrames.title = [NSString stringWithFormat:@"Delete Selected (%lu)", numSelected];
        [btnDeleteSelectedFrames setEnabled:YES];
    } else {
        btnDeleteSelectedFrames.title = @"Delete Selected";
        [btnDeleteSelectedFrames setEnabled:NO];
    }
}

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)view
{
    return imagesInBrowser.count;
}

- (id)imageBrowser:(IKImageBrowserView *)view itemAtIndex:(NSUInteger)index
{
    return imagesInBrowser[index];
}

- (void)popoverWillClose:(NSNotification *)notification
{
    rollModelShown = nil;
}

- (void)popoverDidClose:(NSNotification *)notification
{
    if (rollsNeedReload) {
        [orderModel save];
        [tblRolls performSelector:@selector(reloadData) withObject:nil afterDelay:0];
        rollsNeedReload = NO;
    }
}

@end