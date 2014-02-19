#import "../../Utils/FileUtil.h"
#import "../../Utils/CCSPassword.h"
#import "../../Utils/Base64.h"

#import "BrowseViewController.h"
#import "../WizardWindowController.h"
#import "../../Models/OrderModel.h"

#import "../../Services/CheckOrderNumberService.h"
#import "../../Services/EventSettingsService.h"
#import "../../Services/UploadExtensionsService.h"

@interface BrowseViewController () <NSTableViewDelegate, NSTableViewDataSource> {
    IBOutlet NSTableView *tblRolls;
    IBOutlet NSButton *chkAutoNumberRolls, *chkAutoNumberFrames, *chkPutImagesInCurrentlySelectedRoll;
    IBOutlet NSPopover *advancedOptionsPopover, *viewRollPopover;
    IBOutlet NSPanel *includeNewlyAddedImagesSheet;
    IBOutlet NSTextView *txtNewFiles;
    
    WizardWindowController *wizardWindowController;
    
    OrderModel *orderModel;
    
    CheckOrderNumberService *checkOrderNumberService;
    EventSettingsService *eventSettingsService;
    UploadExtensionsService *uploadExtensionsService;
    
    EventSettingsResult *eventSettings;
    NSMutableArray *uploadExtensions;
    NSString *ccsPassword;
    
    NSInteger autoIncRollName;
    NSMutableArray *rolls;
}

@end

@implementation BrowseViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"BrowseView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
        rolls = [NSMutableArray new];
        checkOrderNumberService = [CheckOrderNumberService new];
        eventSettingsService = [EventSettingsService new];
        uploadExtensionsService = [UploadExtensionsService new];
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

    [openPanel setFrame:NSMakeRect(0, 0, wizardWindowController.window.frame.size.width + 80,
        wizardWindowController.window.frame.size.height - 60) display:YES];
    
    if (defaultLocation) {
        [openPanel setDirectoryURL:[NSURL fileURLWithPath:defaultLocation]];
    }

    [openPanel beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                [orderModel addNewImages:
                    chkPutImagesInCurrentlySelectedRoll.state == NSOnState ? tblRolls.selectedRow : -1
                    urls:openPanel.URLs
                    frameNumberLimit:9999
                    autoNumberRolls:chkAutoNumberRolls.state == NSOnState ? YES : NO
                    autoNumberFrames:chkAutoNumberFrames.state == NSOnState ? YES : NO];

                [tblRolls reloadData];
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
        //NSPopUpButton *btn = view;
        //[btn addItemWithTitle:@"None"];
        //[btn addItemWithTitle:@"photographer 1"];
        //[btn addItemWithTitle:@"photographer 2"];
        //[btn addItemWithTitle:@"photographer 3"];
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
        cell.textField.stringValue = @"Uploading";
        [((NSProgressIndicator *)cell.subviews[1]) setHidden:YES];
        [((NSTextField *)cell.subviews[0]) setHidden:YES];
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

- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard
{
    autoIncRollName = 0;
    [rolls removeAllObjects];
    
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
    }
    
    [checkOrderNumberService setEffectiveServiceRoot:effectiveService coreDomain:effectiveCoreDomain];
    
    BOOL started = [checkOrderNumberService startCheckOrderNumber:effectiveUser password:effectivePass orderNumber:event.orderNumber
        complete:^(CheckOrderNumberResult *result) {
            if (result.error) {
                terminate([NSString stringWithFormat:@"Could not check the selected event. An error occurred: %@", result.error.localizedDescription]);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    NSData *encryptedPassword = [NSData dataWithBase64EncodedString:result.ccsPassword];
                    NSData *decryptedPassword = [CCSPassword decryptCCSPassword:encryptedPassword];
                    ccsPassword = [[NSString alloc] initWithData:decryptedPassword encoding:NSUTF16LittleEndianStringEncoding];

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
                                                            
                                                            [NSApp beginSheet:includeNewlyAddedImagesSheet modalForWindow:wizardWindowController.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
                                                        } else {
                                                            [tblRolls reloadData];
                                                            [orderModel save];
                                                        }
                                                        
                                                        wizardWindowController.txtStepTitle.stringValue = event.eventName;
                                                        wizardWindowController.txtStepDescription.stringValue =
                                                            [NSString stringWithFormat:@"Event Number: %@", event.orderNumber];
                                                        
                                                        [wizardWindowController showStep:kWizardStepBrowse];
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
    NSTextField *textField = [notification object];
    NSLog(@"controlTextDidChange: stringValue == %@, row == %ld", [textField stringValue], [tblRolls rowForView:textField]);
}

- (IBAction)changedPhotographer:(id)sender
{
    //NSLog(@"%lu", [tblRolls rowForView:sender]);
    //[tblRolls reloadData];
}

- (IBAction)clickedDeleteRoll:(id)sender
{
    NSInteger row = [tblRolls rowForView:sender];
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to delete this roll?" defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];
    
    [alert beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [rolls removeObjectAtIndex:row];
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
