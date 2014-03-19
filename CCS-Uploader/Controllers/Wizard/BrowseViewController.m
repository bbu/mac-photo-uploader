#import "../../Utils/FileUtil.h"

#import "BrowseViewController.h"
#import "../WizardWindowController.h"
#import "../MainWindowController.h"
#import "../../Models/OrderModel.h"

#import "../../Services/CheckOrderNumberService.h"
#import "../../Services/EventSettingsService.h"
#import "../../Services/UploadExtensionsService.h"
#import "../../Services/ListDivisionsService.h"
#import "../../Services/ListPhotographersService.h"
#import "../../Services/AddPhotographerService.h"
#import "../../Services/UpdateVisibleService.h"

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
    if (!frameModel.imageErrors.length) {
        return [NSString stringWithFormat:@"%@%ld × %ld", frameModel.fullsizeSent ? @"[Sent] " : @"", frameModel.width, frameModel.height];
    } else {
        return @"[ERRORS]";
    }
}

- (NSUInteger)imageVersion
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];
    return attributes.fileModificationDate.hash + attributes.fileSize;
}
@end

@interface BrowseViewController () <NSTableViewDelegate, NSTableViewDataSource> {
    WizardWindowController *wizardWindowController;

    IBOutlet NSTableView *tblRolls, *tblPhotographers;
    IBOutlet NSTextField *loadingTitle;
    IBOutlet NSProgressIndicator *loadingIndicator;
    IBOutlet NSButton *btnBrowse, *btnGreenScreen, *btnPhotographers, *btnAdvancedOptions;
    IBOutlet NSButton
        *chkAutoCategorizeImages,
        *chkPutImagesInCurrentlySelectedRoll,
        *chkAutoNumberRolls,
        *chkAutoNumberFrames,
        *chkHonourFramesPerRoll;

    IBOutlet NSPopover *advancedOptionsPopover, *viewRollPopover, *photographersPopover;
    IBOutlet NSPanel *includeNewlyAddedImagesSheet, *errorsImportingImagesSheet;
    IBOutlet NSTextView *txtNewFiles, *txtImportErrors;
    IBOutlet NSButton *btnAddPhotographer;
    IBOutlet NSTextField *txtPhotographerName;
    
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
    ListPhotographersService *listPhotographersService;
    AddPhotographerService *addPhotographerService;
    UpdateVisibleService *updateVisibleService;
    
    OrderModel *orderModel;
    NSMutableArray *photographers;
    
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
        listPhotographersService = [ListPhotographersService new];
        addPhotographerService = [AddPhotographerService new];
        updateVisibleService = [UpdateVisibleService new];
        
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
    NSMutableString *errors = [NSMutableString new];
    
    [orderModel addNewImages:params[@"URLs"]
        inRoll:((NSNumber *)params[@"inRoll"]).integerValue
        framesPerRoll:((NSNumber *)params[@"framesPerRoll"]).integerValue
        autoNumberRolls:((NSNumber *)params[@"autoNumberRolls"]).boolValue
        autoNumberFrames:((NSNumber *)params[@"autoNumberFrames"]).boolValue
        photographer:params[@"photographer"]
        statusField:loadingTitle
        errors:errors];

    [orderModel save];

    [tblRolls performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(enableControls) withObject:nil waitUntilDone:YES];
    
    if (errors.length != 0) {
        [self performSelectorOnMainThread:@selector(showImportErrors:) withObject:errors waitUntilDone:YES];
    }
}

- (void)showImportErrors:(NSString *)errors
{
    txtImportErrors.string = errors;
    
    [NSApp beginSheet:errorsImportingImagesSheet modalForWindow:wizardWindowController.window
        modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction)viewRollErrors:(id)sender
{
    NSInteger clickedRoll = tblRolls.clickedRow;

    if (clickedRoll == -1) {
        return;
    }
    
    RollModel *roll = orderModel.rolls[clickedRoll];
    
    if (!roll) {
        return;
    }
    
    NSMutableString *errors = [NSMutableString new];

    for (FrameModel *frame in roll.frames) {
        if (frame.imageErrors.length != 0) {
            [errors appendString:frame.imageErrors];
        }
    }

    if (errors.length != 0) {
        txtImportErrors.string = errors;
    
        [NSApp beginSheet:errorsImportingImagesSheet modalForWindow:wizardWindowController.window
            modalDelegate:nil didEndSelector:nil contextInfo:nil];
    } else {
        NSAlert *alert = [NSAlert alertWithMessageText:@"There are no errors in this roll." defaultButton:@"OK"
            alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
        
        [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
    }
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *pasteboard = info.draggingPasteboard;

    NSArray *URLs = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]]
        options:@{
            NSPasteboardURLReadingFileURLsOnlyKey: [NSNumber numberWithBool:YES],
        }
    ];
    
    NSString *photographer = tblPhotographers.selectedRow != -1 ?
        ((PhotographerRow *)photographers[tblPhotographers.selectedRow]).name : @"None";
    
    NSDictionary *params = @{
        @"URLs": URLs,
        @"inRoll": [NSNumber numberWithInteger:chkPutImagesInCurrentlySelectedRoll.state == NSOnState ? tblRolls.selectedRow : (op == NSTableViewDropOn ? row : -1)],
        @"framesPerRoll": [NSNumber numberWithInteger:chkHonourFramesPerRoll.state == NSOnState ? framesPerRoll : 9999],
        @"autoNumberRolls": [NSNumber numberWithBool:chkAutoNumberRolls.state == NSOnState ? YES : NO],
        @"autoNumberFrames": [NSNumber numberWithBool:chkAutoNumberFrames.state == NSOnState ? YES : NO],
        @"photographer": photographer
    };
    
    [self disableControls:@"Preparing to copy files"];
    [self performSelectorInBackground:@selector(copyImagesInBackground:) withObject:params];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id<NSDraggingInfo>)info
    proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    return tblRolls.isEnabled ? NSDragOperationCopy : NSDragOperationNone;
}

- (IBAction)browseForImagesClicked:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *defaultLocation = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultImageBrowseLocation];
    
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = YES;
    openPanel.allowsMultipleSelection = YES;
    openPanel.message =
        @"Select image files or folders to upload. Any selected folders will be scanned recursively for image files.\r"
        @"Only RGB-colorspace images are accepted; Progressive JPEGs are not accepted";

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

- (IBAction)photographersClicked:(id)sender
{
    if (photographersPopover.isShown) {
        [photographersPopover close];
    } else {
        [photographersPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxYEdge];
    }
}

- (IBAction)addPhotographer:(id)sender
{
    if (!txtPhotographerName.stringValue.length) {
        return;
    }
    
    [btnAddPhotographer setEnabled:NO];
    [txtPhotographerName setEnabled:NO];
    [tblPhotographers setEnabled:NO];
    
    [addPhotographerService
        startAddPhotographer:wizardWindowController.effectiveUser
        password:wizardWindowController.effectivePass
        account:orderModel.eventRow.ccsAccount
        photographerEmail:@""
        photographerName:txtPhotographerName.stringValue
        complete:^(AddPhotographerResult *result) {
            [listPhotographersService
                startListPhotographers:orderModel.eventRow.ccsAccount
                email:wizardWindowController.effectiveUser
                password:wizardWindowController.effectivePass
                complete:^(ListPhotographersResult *result) {
                    if (result.loginSuccess && result.processSuccess) {
                        photographers = result.photographers;
                        PhotographerRow *photographerNone = [PhotographerRow new];
                        photographerNone.name = @"None";
                        [photographers insertObject:photographerNone atIndex:0];
                        [tblRolls reloadData];
                        [tblPhotographers reloadData];
                    }
                    
                    [btnAddPhotographer setEnabled:YES];
                    [txtPhotographerName setEnabled:YES];
                    [tblPhotographers setEnabled:YES];
                    txtPhotographerName.stringValue = @"";
                }
            ];
        }
    ];
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
    if (tableView == tblRolls) {
        return orderModel.rolls.count;
    } else {
        return photographers.count;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    id view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if (tableView == tblRolls) {
        RollModel *roll = orderModel.rolls[row];
        
        if ([columnID isEqualToString:@"Folder"]) {
            NSTableCellView *cell = view;
            
            cell.imageView.image = roll.framesHaveErrors ? [NSImage imageNamed:@"NSCaution"] : [NSImage imageNamed:@"NSFolder"];
            cell.textField.stringValue = roll.number;
        } else if ([columnID isEqualToString:@"Photographer"]) {
            NSPopUpButton *btn = view;
            [btn removeAllItems];
            [btn addItemWithTitle:@"None"];
            
            if (photographers) {
                for (PhotographerRow *photographer in photographers) {
                    [btn addItemWithTitle:photographer.name];
                }
            }

            if (roll.photographer.length) {
                [btn selectItemWithTitle:roll.photographer];
            } else {
                [btn selectItemAtIndex:0];
            }
        } else if ([columnID isEqualToString:@"Size"]) {
            NSTableCellView *cell = view;
            cell.textField.stringValue = [FileUtil humanFriendlyFilesize:roll.totalFrameSize];
        } else if ([columnID isEqualToString:@"Count"]) {
            NSTableCellView *cell = view;
            cell.textField.stringValue = [NSString stringWithFormat:@"%lu", roll.frames.count];
        } else if ([columnID isEqualToString:@"GreenScreen"]) {
            NSTableCellView *cell = view;
            cell.imageView.image = row % 2 ? [NSImage imageNamed:@"NSStatusNone"] : [NSImage imageNamed:@"NSStatusNone"];
        } else if ([columnID isEqualToString:@"CurrentTask"]) {
            NSTableCellView *cell = view;
            //cell.textField.stringValue = @"Uploading thumbnails...";
            [((NSProgressIndicator *)cell.subviews[1]) setHidden:YES];
            [((NSTextField *)cell.subviews[0]) setHidden:YES];
            //[((NSProgressIndicator *)cell.subviews[1]) startAnimation:nil];
        }
    } else if (tableView == tblPhotographers) {
        NSTableCellView *cell = view;
        PhotographerRow *photographer = photographers[row];
        
        if ([columnID isEqualToString:@"Name"]) {
            cell.textField.stringValue = photographer.name;
        }
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
            completionHandler:^(NSModalResponse response) {
                if (!fromWizard) {
                    [wizardWindowController.window close];
                }
            }
        ];
    };
    
    if ([wizardWindowController.mainWindowController.openedEvents containsObject:event.orderNumber]) {
        terminate([NSString stringWithFormat:@"The event \"%@\" (%@) is already open in another window.", event.eventName, event.orderNumber]);
        return;
    }
    
    [wizardWindowController.mainWindowController.openedEvents addObject:event.orderNumber];
    
    /*
    NSString *effectiveUser = wizardWindowController.effectiveUser;
    NSString *effectivePass = wizardWindowController.effectivePass;
    NSInteger effectiveService = wizardWindowController.effectiveService;
    NSString *effectiveCoreDomain = wizardWindowController.effectiveCoreDomain;
     
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
    */
    
    [checkOrderNumberService
        setEffectiveServiceRoot:wizardWindowController.effectiveService
        coreDomain:wizardWindowController.effectiveCoreDomain];

    [listPhotographersService
        setEffectiveServiceRoot:wizardWindowController.effectiveService
        coreDomain:wizardWindowController.effectiveCoreDomain];
    
    [addPhotographerService
        setEffectiveServiceRoot:wizardWindowController.effectiveService
        coreDomain:wizardWindowController.effectiveCoreDomain];
    
    BOOL started = [checkOrderNumberService
        startCheckOrderNumber:wizardWindowController.effectiveUser
        password:wizardWindowController.effectivePass
        orderNumber:event.orderNumber
        complete:^(CheckOrderNumberResult *result) {
            if (result.error) {
                [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                terminate([NSString stringWithFormat:@"Could not check the selected event. An error occurred: %@", result.error.localizedDescription]);
            } else if (result.loginSuccess && result.processSuccess) {
                ccsPassword = result.ccsPassword;

                [eventSettingsService startGetEventSettings:event.ccsAccount password:ccsPassword orderNumber:event.orderNumber
                    complete:^(EventSettingsResult *result) {
                        if (result.error) {
                            [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                            terminate([NSString stringWithFormat:@"Could not not obtain the event's settings. An error occurred: %@", result.error.localizedDescription]);
                        } else if ([result.status isEqualToString:@"AuthenticationSuccessful"]) {
                            eventSettings = result;
                            
                            [uploadExtensionsService startGetUploadExtensions:event.ccsAccount password:ccsPassword
                                complete:^(UploadExtensionsResult *result) {
                                    if (result.error) {
                                        [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                        terminate([NSString stringWithFormat:
                                            @"Could not obtain allowed upload file extensions. An error occurred: %@",
                                            result.error.localizedDescription]);
                                        
                                    } else if ([result.status isEqualToString:@"Successful"]) {
                                        uploadExtensions = result.extensions;
                                        
                                        [listPhotographersService startListPhotographers:event.ccsAccount
                                            email:wizardWindowController.effectiveUser
                                            password:wizardWindowController.effectivePass
                                            complete:^(ListPhotographersResult *result) {
                                                if (result.error) {
                                                    [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                    terminate([NSString stringWithFormat:
                                                        @"Could not obtain the list of photographers. An error occurred: %@",
                                                        result.error.localizedDescription]);
                                                    
                                                } else if (result.loginSuccess && result.processSuccess) {
                                                    photographers = result.photographers;
                                                    PhotographerRow *photographerNone = [PhotographerRow new];
                                                    photographerNone.name = @"None";
                                                    [photographers insertObject:photographerNone atIndex:0];

                                                    NSError *error = nil;
                                                    [self view];
                                                    orderModel = nil;
                                                    [tblRolls reloadData];
                                                    
                                                    orderModel = [[OrderModel alloc] initWithEventRow:event error:&error];
                                                    
                                                    if (orderModel == nil) {
                                                        [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                        terminate([NSString stringWithFormat:@"An error occurred while loading up the event. %@", error.localizedDescription]);
                                                    } else {
                                                        [self loadEvent];
                                                    }
                                                } else {
                                                    [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                    terminate(@"Could not obtain the list of photographers.");
                                                }
                                            }
                                        ];
                                    } else {
                                        [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];

                                        terminate([NSString stringWithFormat:
                                            @"Could not obtain allowed upload file extensions. The server returned \"%@\".", result.status]);
                                    }
                                }
                            ];
                        } else {
                            [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                            terminate([NSString stringWithFormat:@"Could not obtain the event's settings. The server returned \"%@\".", result.status]);
                        }
                    }
                ];
            } else {
                [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                terminate([NSString stringWithFormat:@"The server rejected the selected event \"%@\".", event.orderNumber]);
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
    [tblPhotographers reloadData];
    
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

- (IBAction)closeErrors:(id)sender
{
    [errorsImportingImagesSheet close];
    [NSApp endSheet:errorsImportingImagesSheet];
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
    NSPopUpButton *btn = sender;
    NSInteger rollIndex = [tblRolls rowForView:sender];
    
    if (rollIndex >= 0) {
        RollModel *roll = orderModel.rolls[rollIndex];
        roll.photographer = [btn.selectedItem.title copy];
        [tblRolls reloadData];
    }
}

- (void)saveOrderModel
{
    [orderModel save];
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
    NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:rollModelShown.number];
    
    [imageBrowserView.selectionIndexes
        enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            FrameModel *frame = rollModelShown.frames[index];
            
            NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
                stringByAppendingPathExtension:frame.extension];
            
            if (frame.orientation > 1) {
                [ImageUtil resizeAndRotateImage:filepath outputImageFilename:filepath
                    resizeToMaxSide:0 rotate:kDontRotate horizontalWatermark:nil verticalWatermark:nil compressionQuality:1];
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
                resizeToMaxSide:0 rotate:rotation horizontalWatermark:nil verticalWatermark:nil compressionQuality:0.8];
            
            CGSize newSize = CGSizeZero;
            NSUInteger orientation = 0;
            frame.imageErrors = [NSMutableString new];
            frame.imageType = [NSMutableString new];
            
            [ImageUtil getImageProperties:filepath size:&newSize type:frame.imageType
                orientation:&orientation errors:frame.imageErrors];
            
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
    
    rollModelShown.framesHaveErrors = NO;
    
    for (FrameModel *frame in rollModelShown.frames) {
        if (frame.imageErrors.length != 0) {
            rollModelShown.framesHaveErrors = YES;
            break;
        }
    }
    
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
    
    rollModelShown.framesHaveErrors = NO;
    
    for (FrameModel *frame in rollModelShown.frames) {
        if (frame.imageErrors.length != 0) {
            rollModelShown.framesHaveErrors = YES;
            break;
        }
    }
    
    rollsNeedReload = YES;
}

- (IBAction)refreshImages:(id)sender
{
    [imageBrowserView reloadData];
}

- (IBAction)sliderDidMove:(id)sender
{
    NSSlider *slider = sender;
    imageBrowserView.zoomValue = slider.floatValue / 100.;
}

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)view
{
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