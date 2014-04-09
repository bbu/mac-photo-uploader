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

#import "../../Services/GetSingleImageInfoService.h"
#import "../../Services/GetChromaKeyEventInformationService.h"
#import "../../Services/SetChromaKeyRollMakePNGOnlyService.h"
#import "../../Services/SetChromaKeyRollService.h"
#import "../../Services/RollHasImagesService.h"
#import "../../Services/DeleteChromaKeyRoll2Service.h"
#import "../../Services/DeleteChromaKeyRollService.h"

#import <Quartz/Quartz.h>

@implementation ImageInBrowserView

- (id)initWithFrame:(FrameModel *)frame path:(NSString *)path
{
    self = [super init];
    
    if (self) {
        _path = path;
        _frame = frame;
    }
    
    return self;
}

- (NSString *)imageRepresentationType
{
    return IKImageBrowserPathRepresentationType;
}

- (id)imageRepresentation
{
    return _path;
}

- (NSString *)imageUID
{
    return _path;
}

- (id)imageTitle
{
    return [NSString stringWithFormat:@"%@", [_frame.name stringByAppendingPathExtension:_frame.extension]];
}

- (id)imageSubtitle
{
    if (!_frame.imageErrors.length) {
        return [NSString stringWithFormat:@"%@%ld × %ld", _frame.fullsizeSent ? @"[Sent] " : @"", _frame.width, _frame.height];
    } else {
        return @"[ERRORS]";
    }
}

- (NSUInteger)imageVersion
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:nil];
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
    IBOutlet NSPanel *includeNewlyAddedImagesSheet, *errorsImportingImagesSheet, *greenScreenSheet;
    IBOutlet NSTextView *txtNewFiles, *txtImportErrors;
    IBOutlet NSButton *btnAddPhotographer;
    IBOutlet NSTextField *txtPhotographerName;
    
    IBOutlet IKImageBrowserView *imageBrowserView;
    IBOutlet NSTextField *imageBrowserTitle;
    IBOutlet NSPopUpButton *btnRotationDegrees, *btnRotationDirection;
    IBOutlet NSButton *btnDeleteSelectedFrames;
    NSMutableArray *imagesInBrowser;
    BOOL rollsNeedReload;
    
    IBOutlet NSComboBox *cbFolder;
    IBOutlet NSButton *btnAddFolder;
    IBOutlet NSButton *chkAllImagesAreOnGreenScreen, *chkAllowCustomerToChoose, *chkPreviouslyProvided;
    IBOutlet NSTextField *txtHorzBackgroundEventNumber, *txtHorzBackgroundRoll, *txtHorzBackgroundFrame;
    IBOutlet NSTextField *txtVertBackgroundEventNumber, *txtVertBackgroundRoll, *txtVertBackgroundFrame;
    IBOutlet NSTextField *txtOutputFolder;
    IBOutlet NSButton *btnAddBackground;
    IBOutlet NSTableView *tblBackgrounds;
    IBOutlet NSImageView *imgBackgroundPreview;
    IBOutlet NSButton *btnCancelGreenScreen, *btnConfirmGreenScreen;
    IBOutlet NSTextField *lblGreenScreenStatus;
    IBOutlet NSProgressIndicator *greenScreenProgress;
    
    CheckOrderNumberService *checkOrderNumberService;
    EventSettingsService *eventSettingsService;
    UploadExtensionsService *uploadExtensionsService;
    ListDivisionsService *listDivisionsService;
    ListPhotographersService *listPhotographersService;
    AddPhotographerService *addPhotographerService;
    UpdateVisibleService *updateVisibleService;
    
    GetSingleImageInfoService *getSingleImageInfoService;
    GetChromaKeyEventInformationService *getChromaKeyEventInformationService;
    SetChromaKeyRollMakePNGOnlyService *setChromaKeyRollMakePNGOnlyService;
    SetChromaKeyRollService *setChromaKeyRollService;
    RollHasImagesService *rollHasImagesService;
    DeleteChromaKeyRoll2Service *deleteChromaKeyRoll2Service;
    DeleteChromaKeyRollService *deleteChromaKeyRollService;
    
    OrderModel *orderModel;
    NSMutableArray *photographers, *divisions, *greenScreenBackgrounds, *filteredGreenScreenBackgrounds;
    BOOL allowDynamicBackgrounds;
    
    NSInteger framesPerRoll;
    BOOL usingPreloader;
    RollModel *rollModelShown;
    
    EventSettingsResult *eventSettings;
    NSMutableArray *uploadExtensions;
    NSString *ccsPassword;
}

@end

@implementation BrowseViewController

@synthesize orderModel;
@synthesize ccsPassword;

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
        
        getSingleImageInfoService = [GetSingleImageInfoService new];
        getChromaKeyEventInformationService = [GetChromaKeyEventInformationService new];
        setChromaKeyRollMakePNGOnlyService = [SetChromaKeyRollMakePNGOnlyService new];
        setChromaKeyRollService = [SetChromaKeyRollService new];
        rollHasImagesService = [RollHasImagesService new];
        deleteChromaKeyRoll2Service = [DeleteChromaKeyRoll2Service new];
        deleteChromaKeyRollService = [DeleteChromaKeyRollService new];

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
    
    [self performSelectorOnMainThread:@selector(disableControls:) withObject:@"Preparing to copy files..." waitUntilDone:YES];
    
    [orderModel addNewImages:params[@"URLs"]
        inRoll:((NSNumber *)params[@"inRoll"]).integerValue
        framesPerRoll:((NSNumber *)params[@"framesPerRoll"]).integerValue
        autoNumberRolls:((NSNumber *)params[@"autoNumberRolls"]).boolValue
        autoNumberFrames:((NSNumber *)params[@"autoNumberFrames"]).boolValue
        photographer:params[@"photographer"]
        statusField:loadingTitle
        errors:errors];

    [loadingTitle performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Saving event" waitUntilDone:YES];
    [orderModel save];
    [self performSelectorOnMainThread:@selector(enableControls) withObject:nil waitUntilDone:YES];
    
    if (errors.length != 0) {
        [self performSelectorOnMainThread:@selector(showImportErrors:) withObject:errors waitUntilDone:YES];
    }
}

- (void)importImagesInBackground
{
    [self performSelectorOnMainThread:@selector(disableControls:) withObject:@"Importing files..." waitUntilDone:YES];
    
    [orderModel includeNewlyAdded:loadingTitle];
    [loadingTitle performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Saving event" waitUntilDone:YES];
    [orderModel save];
    
    [self performSelectorOnMainThread:@selector(enableControls) withObject:nil waitUntilDone:YES];
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
    [self matchRollsWithGreenScreen];

    NSInteger selectedRow = tblRolls.selectedRow;
    [tblRolls reloadData];
    [tblRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:YES];
    [tblRolls becomeFirstResponder];
    
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

- (IBAction)greenScreenClicked:(id)sender
{
    NSInteger rollIndex = tblRolls.clickedRow;
    
    if (rollIndex == -1) {
        rollIndex = tblRolls.selectedRow;
        
        if (rollIndex == -1) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"You must select a folder first." defaultButton:@"OK"
                alternateButton:@"" otherButton:@"" informativeTextWithFormat:@""];
            
            [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            return;
        }
    }
    
    rollModelShown = orderModel.rolls[rollIndex];
    [self prepareGreenScreenSheet:NO];
    
    [NSApp beginSheet:greenScreenSheet modalForWindow:wizardWindowController.window
        modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (void)matchRollsWithGreenScreen
{
    for (RollModel *roll in orderModel.rolls) {
        roll.greenScreen = NO;
        
        for (BackgroundRow *background in greenScreenBackgrounds) {
            if ([background.sourceRoll isEqualToString:roll.number]) {
                roll.greenScreen = YES;
                break;
            }
        }
    }
}

- (void)switchGreenScreenBackgroundControls:(BOOL)enabled clearFields:(BOOL)clearFields
{
    NSArray *controlsToSwitch = @[
        txtHorzBackgroundEventNumber, txtHorzBackgroundRoll, txtHorzBackgroundFrame,
        txtVertBackgroundEventNumber, txtVertBackgroundRoll, txtVertBackgroundFrame,
        txtOutputFolder, btnAddBackground, tblBackgrounds, imgBackgroundPreview
    ];
    
    for (NSControl *control in controlsToSwitch) {
        [control setEnabled:enabled];
    }
    
    if (clearFields) {
        txtHorzBackgroundEventNumber.stringValue = txtVertBackgroundEventNumber.stringValue = orderModel.eventRow.orderNumber;
        txtHorzBackgroundRoll.stringValue = txtHorzBackgroundFrame.stringValue = @"";
        txtVertBackgroundRoll.stringValue = txtVertBackgroundFrame.stringValue = @"";
        txtOutputFolder.stringValue = @"";
    }
}

- (void)switchGreenScreenControls:(BOOL)enabled
{
    if (enabled) {
        [chkAllImagesAreOnGreenScreen setEnabled:YES];
        
        if (chkAllImagesAreOnGreenScreen.state == NSOnState) {
            [chkAllowCustomerToChoose setEnabled:YES];
            [chkPreviouslyProvided setEnabled:YES];
            
            if (chkPreviouslyProvided.state == NSOnState) {
                [self switchGreenScreenBackgroundControls:YES clearFields:NO];
            } else {
                [self switchGreenScreenBackgroundControls:NO clearFields:NO];
            }
        } else {
            [chkAllowCustomerToChoose setEnabled:NO];
            [chkPreviouslyProvided setEnabled:NO];
            [self switchGreenScreenBackgroundControls:NO clearFields:NO];
        }
    } else {
        [chkAllImagesAreOnGreenScreen setEnabled:NO];
        [chkAllowCustomerToChoose setEnabled:NO];
        [chkPreviouslyProvided setEnabled:NO];
        [self switchGreenScreenBackgroundControls:NO clearFields:NO];
    }
    
    [btnCancelGreenScreen setEnabled:enabled];
    [btnConfirmGreenScreen setEnabled:enabled];
}

- (IBAction)allImagesAreOnGreenScreenChecked:(id)sender
{
    BOOL enabled = chkAllImagesAreOnGreenScreen.state == NSOnState ? YES : NO;
    
    [chkAllowCustomerToChoose setEnabled:enabled];
    [chkPreviouslyProvided setEnabled:enabled];
    
    if (enabled && chkPreviouslyProvided.state == NSOnState) {
        [self switchGreenScreenBackgroundControls:YES clearFields:YES];
    } else {
        [self switchGreenScreenBackgroundControls:NO clearFields:YES];
    }
}

- (IBAction)allowCustomerToChooseChecked:(id)sender
{
    
}

- (IBAction)previouslyProvidedChecked:(id)sender
{
    BOOL enabled = chkPreviouslyProvided.state == NSOnState ? YES : NO;
    [self switchGreenScreenBackgroundControls:enabled clearFields:YES];
}

- (IBAction)deleteGreenScreenBackground:(id)sender
{
    if (![tblBackgrounds isEnabled]) {
        return;
    }
    
    void (^restoreForm)(NSString *) = ^(NSString *message) {
        lblGreenScreenStatus.stringValue = message;
        [greenScreenProgress stopAnimation:nil];
        [self switchGreenScreenControls:YES];
    };
    
    NSInteger row = [tblBackgrounds rowForView:sender];
    BackgroundRow *background = filteredGreenScreenBackgrounds[row];
    
    lblGreenScreenStatus.stringValue = @"Checking whether the roll has images...";
    [greenScreenProgress startAnimation:nil];
    [self switchGreenScreenControls:NO];
    
    [rollHasImagesService
        startRollHasImages:orderModel.eventRow.ccsAccount
        password:ccsPassword
        orderNumber:orderModel.eventRow.orderNumber
        roll:rollModelShown.number
        complete:^(RollHasImagesResult *result) {
            if (result.error) {
                restoreForm([NSString stringWithFormat:@"Could not check whether the roll has images: %@", result.error.localizedDescription]);
            } else if (result.hasImages) {
                restoreForm(@"Unable to delete background, roll has images sent");
            } else {
                lblGreenScreenStatus.stringValue = @"Deleting selected background...";
                
                [deleteChromaKeyRoll2Service
                    startDeleteChromaKeyRoll2:orderModel.eventRow.ccsAccount
                    password:ccsPassword
                    orderNo:orderModel.eventRow.orderNumber
                    roll:background.sourceRoll
                    destinationRoll:background.destinationRoll
                    complete:^(ServiceResult *result) {
                        if (result.error) {
                            restoreForm([NSString stringWithFormat:@"Could not delete background: %@", result.error.localizedDescription]);
                        } else {
                            [getChromaKeyEventInformationService
                                startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                password:ccsPassword
                                eventID:orderModel.eventRow.eventID
                                complete:^(GetChromaKeyEventInformationResult *result) {
                                    if (result.error) {
                                        restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                    } else {
                                        restoreForm(@"");
                                        greenScreenBackgrounds = result.backgrounds;
                                        [self matchRollsWithGreenScreen];
                                        [self prepareGreenScreenSheet:YES];
                                        NSInteger selectedRow = tblRolls.selectedRow;
                                        [tblRolls reloadData];
                                        [tblRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
                                    }
                                }
                            ];
                        }
                    }
                ];
            }
        }
    ];
}

- (IBAction)addGreenScreenBackground:(id)sender
{
    void (^restoreForm)(NSString *) = ^(NSString *message) {
        lblGreenScreenStatus.stringValue = message;
        [greenScreenProgress stopAnimation:nil];
        [self switchGreenScreenControls:YES];
    };
    
    if (!txtVertBackgroundRoll.stringValue.length && !txtHorzBackgroundRoll.stringValue.length) {
        [txtHorzBackgroundRoll becomeFirstResponder];
        return;
    }
    
    [txtHorzBackgroundEventNumber becomeFirstResponder];
    
    lblGreenScreenStatus.stringValue = @"Checking whether the background exists at CCS...";
    [greenScreenProgress startAnimation:nil];
    [self switchGreenScreenControls:NO];
    
    BOOL isVertical = txtVertBackgroundRoll.stringValue.length ? YES : NO;

    [getSingleImageInfoService
        startGetSingleImageInfo:orderModel.eventRow.ccsAccount
        password:ccsPassword
        orderNumber:isVertical ? txtVertBackgroundEventNumber.stringValue : txtHorzBackgroundEventNumber.stringValue
        roll:isVertical ? txtVertBackgroundRoll.stringValue : txtHorzBackgroundRoll.stringValue
        frame:isVertical ? txtVertBackgroundFrame.stringValue : txtHorzBackgroundFrame.stringValue
        complete:^(GetSingleImageInfoResult *result) {
            if (result.error) {
                restoreForm([NSString stringWithFormat:@"Could not check image: %@", result.error.localizedDescription]);
            } else if (result.width && result.height) {
                NSInteger firstWidth = result.width;
                NSInteger firstHeight = result.height;
                
                if (isVertical && txtHorzBackgroundRoll.stringValue.length) {
                    [getSingleImageInfoService
                        startGetSingleImageInfo:orderModel.eventRow.ccsAccount
                        password:ccsPassword
                        orderNumber:txtHorzBackgroundEventNumber.stringValue
                        roll:txtHorzBackgroundRoll.stringValue
                        frame:txtHorzBackgroundFrame.stringValue
                        complete:^(GetSingleImageInfoResult *result) {
                            if (result.error) {
                                restoreForm([NSString stringWithFormat:@"Could not check image: %@", result.error.localizedDescription]);
                            } else if (result.width && result.height) {
                                NSInteger secondWidth = result.width;
                                NSInteger secondHeight = result.height;

                                BOOL allPassed = YES;
                                
                                for (FrameModel *frame in rollModelShown.frames) {
                                    if (![ImageUtil dimensionsAreValidForGreenScreen:frame.width fgHeight:frame.height bgWidth:firstWidth bgHeight:firstHeight]) {
                                        allPassed = NO;
                                        break;
                                    }
                                }
                                
                                if (allPassed) {
                                    for (FrameModel *frame in rollModelShown.frames) {
                                        if (![ImageUtil dimensionsAreValidForGreenScreen:frame.width fgHeight:frame.height bgWidth:secondWidth bgHeight:secondHeight]) {
                                            allPassed = NO;
                                            break;
                                        }
                                    }
                                }
                                
                                if (allPassed) {
                                    [setChromaKeyRollService
                                        startSetChromaKeyRoll:orderModel.eventRow.ccsAccount
                                        password:ccsPassword
                                        eventID:orderModel.eventRow.eventID
                                        sourceRoll:rollModelShown.number
                                        horzBackgroundOrderNo:txtHorzBackgroundEventNumber.stringValue
                                        horzBackgroundRoll:txtHorzBackgroundRoll.stringValue
                                        horzBackgroundFrame:txtHorzBackgroundFrame.stringValue
                                        vertBackgroundOrderNo:txtVertBackgroundEventNumber.stringValue
                                        vertBackgroundRoll:txtVertBackgroundRoll.stringValue
                                        vertBackgroundFrame:txtVertBackgroundFrame.stringValue
                                        destinationRoll:txtOutputFolder.stringValue
                                        complete:^(SetChromaKeyRollResult *result) {
                                            if (result.error) {
                                                restoreForm(result.error.localizedDescription);
                                            } else if (result.message.length) {
                                                restoreForm(result.message);
                                            } else {
                                                lblGreenScreenStatus.stringValue = @"Background added, refreshing green screen information";
                                                
                                                [getChromaKeyEventInformationService
                                                    startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                                    password:ccsPassword
                                                    eventID:orderModel.eventRow.eventID
                                                    complete:^(GetChromaKeyEventInformationResult *result) {
                                                        if (result.error) {
                                                            restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                                        } else {
                                                            restoreForm(@"");
                                                            greenScreenBackgrounds = result.backgrounds;
                                                            [self matchRollsWithGreenScreen];
                                                            [self prepareGreenScreenSheet:YES];
                                                            NSInteger selectedRow = tblRolls.selectedRow;
                                                            [tblRolls reloadData];
                                                            [tblRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
                                                        }
                                                    }
                                                ];
                                            }
                                        }
                                    ];
                                } else {
                                    restoreForm(@"Some of the images in the roll do not pass the dimension check against the background.");
                                }
                            } else {
                                restoreForm(@"The specified background image does not exist at CCS.");
                            }
                        }
                    ];
                    
                } else {
                    BOOL allPassed = YES;
                    
                    for (FrameModel *frame in rollModelShown.frames) {
                        if (![ImageUtil dimensionsAreValidForGreenScreen:frame.width fgHeight:frame.height bgWidth:firstWidth bgHeight:firstHeight]) {
                            allPassed = NO;
                            break;
                        }
                    }
                    
                    if (allPassed) {
                        [setChromaKeyRollService
                            startSetChromaKeyRoll:orderModel.eventRow.ccsAccount
                            password:ccsPassword
                            eventID:orderModel.eventRow.eventID
                            sourceRoll:rollModelShown.number
                            horzBackgroundOrderNo:isVertical ? @"" : txtHorzBackgroundEventNumber.stringValue
                            horzBackgroundRoll:isVertical ? @"" : txtHorzBackgroundRoll.stringValue
                            horzBackgroundFrame:isVertical ? @"" : txtHorzBackgroundFrame.stringValue
                            vertBackgroundOrderNo:isVertical ? txtVertBackgroundEventNumber.stringValue : @""
                            vertBackgroundRoll:isVertical ? txtVertBackgroundRoll.stringValue : @""
                            vertBackgroundFrame:isVertical ? txtVertBackgroundFrame.stringValue : @""
                            destinationRoll:txtOutputFolder.stringValue
                            complete:^(SetChromaKeyRollResult *result) {
                                if (result.error) {
                                    restoreForm(result.error.localizedDescription);
                                } else if (result.message.length) {
                                    restoreForm(result.message);
                                } else {
                                    lblGreenScreenStatus.stringValue = @"Background added, refreshing green screen information";
                                    
                                    [getChromaKeyEventInformationService
                                        startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                        password:ccsPassword
                                        eventID:orderModel.eventRow.eventID
                                        complete:^(GetChromaKeyEventInformationResult *result) {
                                            if (result.error) {
                                                restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                            } else {
                                                restoreForm(@"");
                                                greenScreenBackgrounds = result.backgrounds;
                                                [self matchRollsWithGreenScreen];
                                                [self prepareGreenScreenSheet:YES];
                                                NSInteger selectedRow = tblRolls.selectedRow;
                                                [tblRolls reloadData];
                                                [tblRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
                                            }
                                        }
                                    ];
                                }
                            }
                        ];
                    } else {
                        restoreForm(@"Some of the images in the roll do not pass the dimension check against the background.");
                    }
                }
            } else {
                restoreForm(@"The specified background image does not exist at CCS.");
            }
        }
    ];
}

- (void)prepareGreenScreenSheet:(BOOL)keepSelection
{
    lblGreenScreenStatus.stringValue = @"";
    chkAllImagesAreOnGreenScreen.state = rollModelShown.greenScreen ? NSOnState : NSOffState;
    [tblBackgrounds reloadData];
    
    if (!keepSelection) {
        chkAllowCustomerToChoose.state = NSOffState;
    }
    
    for (BackgroundRow *background in greenScreenBackgrounds) {
        if ([background.sourceRoll isEqualToString:rollModelShown.number] &&
            !background.horzBackgroundOrderNo && !background.vertBackgroundOrderNo) {
            
            chkAllowCustomerToChoose.state = NSOnState;
            break;
        }
    }
    
    [chkAllowCustomerToChoose setEnabled:rollModelShown.greenScreen];
    [chkPreviouslyProvided setEnabled:rollModelShown.greenScreen];
    
    chkPreviouslyProvided.state = filteredGreenScreenBackgrounds.count ? NSOnState : NSOffState;
    [self switchGreenScreenBackgroundControls:(rollModelShown.greenScreen && chkPreviouslyProvided.state == NSOnState) ? YES : NO clearFields:YES];
}

- (IBAction)cancelGreenScreen:(id)sender
{
    rollModelShown = nil;
    [greenScreenSheet close];
    [NSApp endSheet:greenScreenSheet];
}

- (IBAction)confirmGreenScreen:(id)sender
{
    void (^restoreForm)(NSString *) = ^(NSString *message) {
        lblGreenScreenStatus.stringValue = message;
        [greenScreenProgress stopAnimation:nil];
        [self switchGreenScreenControls:YES];
    };
    
    void (^obtainBackgrounds)(GetChromaKeyEventInformationResult *) = ^(GetChromaKeyEventInformationResult *result) {
        greenScreenBackgrounds = result.backgrounds;
        [self matchRollsWithGreenScreen];
        [self prepareGreenScreenSheet:YES];
        NSInteger selectedRow = tblRolls.selectedRow;
        [tblRolls reloadData];
        [tblRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
        rollModelShown = nil;
        [greenScreenSheet close];
        [NSApp endSheet:greenScreenSheet];
    };
    
    if (chkAllImagesAreOnGreenScreen.state == NSOffState ||
        (chkAllowCustomerToChoose.state == NSOffState && chkPreviouslyProvided.state == NSOffState)) {
        
        lblGreenScreenStatus.stringValue = @"Checking whether the roll has images...";
        [greenScreenProgress startAnimation:nil];
        [self switchGreenScreenControls:NO];
        
        [rollHasImagesService
            startRollHasImages:orderModel.eventRow.ccsAccount
            password:ccsPassword
            orderNumber:orderModel.eventRow.orderNumber
            roll:rollModelShown.number
            complete:^(RollHasImagesResult *result) {
                if (result.error) {
                    restoreForm([NSString stringWithFormat:@"Could not check whether the roll has images: %@", result.error.localizedDescription]);
                } else if (result.hasImages) {
                    restoreForm(@"Unable to delete green screen info, roll has images sent");
                } else {
                    lblGreenScreenStatus.stringValue = @"Deleting green screen info...";
                    
                    [deleteChromaKeyRollService
                        startDeleteChromaKeyRoll:orderModel.eventRow.ccsAccount
                        password:ccsPassword
                        eventID:orderModel.eventRow.eventID
                        sourceRoll:rollModelShown.number
                        complete:^(ServiceResult *result) {
                            if (result.error) {
                                restoreForm([NSString stringWithFormat:@"Could not delete green screen info: %@", result.error.localizedDescription]);
                            } else {
                                lblGreenScreenStatus.stringValue = @"Background added, refreshing green screen information...";
                                
                                [getChromaKeyEventInformationService
                                    startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                    password:ccsPassword
                                    eventID:orderModel.eventRow.eventID
                                    complete:^(GetChromaKeyEventInformationResult *result) {
                                        if (result.error) {
                                            restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                        } else {
                                            restoreForm(@"");
                                            obtainBackgrounds(result);
                                        }
                                    }
                                ];
                            }
                        }
                    ];
                }
            }
        ];
    } else if (chkAllowCustomerToChoose.state == NSOnState && chkPreviouslyProvided.state == NSOffState) {
        lblGreenScreenStatus.stringValue = @"Checking whether the roll has images...";
        [greenScreenProgress startAnimation:nil];
        [self switchGreenScreenControls:NO];
        
        [rollHasImagesService
            startRollHasImages:orderModel.eventRow.ccsAccount
            password:ccsPassword
            orderNumber:orderModel.eventRow.orderNumber
            roll:rollModelShown.number
            complete:^(RollHasImagesResult *result) {
                if (result.error) {
                    restoreForm([NSString stringWithFormat:@"Could not check whether the roll has images: %@", result.error.localizedDescription]);
                } else if (result.hasImages) {
                    restoreForm(@"Unable to alter green screen info, roll has images sent");
                } else {
                    lblGreenScreenStatus.stringValue = @"Deleting green screen info...";
                    
                    [deleteChromaKeyRollService
                        startDeleteChromaKeyRoll:orderModel.eventRow.ccsAccount
                        password:ccsPassword
                        eventID:orderModel.eventRow.eventID
                        sourceRoll:rollModelShown.number
                        complete:^(ServiceResult *result) {
                            if (result.error) {
                                restoreForm([NSString stringWithFormat:@"Could not delete green screen info: %@", result.error.localizedDescription]);
                            } else {
                                lblGreenScreenStatus.stringValue = @"Setting dynamic green screen info...";
                                
                                [setChromaKeyRollMakePNGOnlyService
                                    startSetChromaKeyRollMakePNGOnly:orderModel.eventRow.ccsAccount
                                    password:ccsPassword
                                    eventID:orderModel.eventRow.eventID
                                    sourceRoll:rollModelShown.number
                                    complete:^(ServiceResult *result) {
                                        if (result.error) {
                                            restoreForm([NSString stringWithFormat:@"Could not set dynamic green screen info: %@", result.error.localizedDescription]);
                                        } else {
                                            lblGreenScreenStatus.stringValue = @"Refreshing green screen info...";
                                            
                                            [getChromaKeyEventInformationService
                                                startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                                password:ccsPassword
                                                eventID:orderModel.eventRow.eventID
                                                complete:^(GetChromaKeyEventInformationResult *result) {
                                                    if (result.error) {
                                                        restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                                    } else {
                                                        restoreForm(@"");
                                                        obtainBackgrounds(result);
                                                    }
                                                }
                                            ];
                                        }
                                    }
                                ];
                            }
                        }
                    ];
                }
            }
        ];
    } else if (chkAllowCustomerToChoose.state == NSOnState && chkPreviouslyProvided.state == NSOnState) {
        lblGreenScreenStatus.stringValue = @"Setting green screen info...";
        [greenScreenProgress startAnimation:nil];
        [self switchGreenScreenControls:NO];
        
        [setChromaKeyRollMakePNGOnlyService
            startSetChromaKeyRollMakePNGOnly:orderModel.eventRow.ccsAccount
            password:ccsPassword
            eventID:orderModel.eventRow.eventID
            sourceRoll:rollModelShown.number
            complete:^(ServiceResult *result) {
                if (result.error) {
                    restoreForm([NSString stringWithFormat:@"Could not set green screen info: %@", result.error.localizedDescription]);
                } else {
                    lblGreenScreenStatus.stringValue = @"Green screen set, refreshing green screen information...";
                    
                    [getChromaKeyEventInformationService
                        startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                        password:ccsPassword
                        eventID:orderModel.eventRow.eventID
                        complete:^(GetChromaKeyEventInformationResult *result) {
                            if (result.error) {
                                restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                            } else {
                                restoreForm(@"");
                                obtainBackgrounds(result);
                            }
                        }
                    ];
                }
            }
        ];
    } else if (chkAllowCustomerToChoose.state == NSOffState && chkPreviouslyProvided.state == NSOnState) {
        lblGreenScreenStatus.stringValue = @"Setting green screen info...";
        [greenScreenProgress startAnimation:nil];
        [self switchGreenScreenControls:NO];
        
        [rollHasImagesService
            startRollHasImages:orderModel.eventRow.ccsAccount
            password:ccsPassword
            orderNumber:orderModel.eventRow.orderNumber
            roll:rollModelShown.number
            complete:^(RollHasImagesResult *result) {
                if (result.error) {
                    restoreForm([NSString stringWithFormat:@"Could not check whether the roll has images: %@", result.error.localizedDescription]);
                } else if (result.hasImages) {
                    restoreForm(@"Unable to alter green screen info, roll has images sent");
                } else {
                    lblGreenScreenStatus.stringValue = @"Deleting green screen info...";
                    
                    [deleteChromaKeyRoll2Service
                        startDeleteChromaKeyRoll2:orderModel.eventRow.ccsAccount
                        password:ccsPassword
                        orderNo:orderModel.eventRow.orderNumber
                        roll:rollModelShown.number
                        destinationRoll:@""
                        complete:^(ServiceResult *result) {
                            if (result.error) {
                                restoreForm([NSString stringWithFormat:@"Could not delete dynamic green screen info: %@", result.error.localizedDescription]);
                            } else {
                                lblGreenScreenStatus.stringValue = @"Refreshing green screen info...";
                                
                                [getChromaKeyEventInformationService
                                    startGetChromaKeyEventInformation:orderModel.eventRow.ccsAccount
                                    password:ccsPassword
                                    eventID:orderModel.eventRow.eventID
                                    complete:^(GetChromaKeyEventInformationResult *result) {
                                        if (result.error) {
                                            restoreForm([NSString stringWithFormat:@"Could not refresh green screen info: %@", result.error.localizedDescription]);
                                        } else {
                                            restoreForm(@"");
                                            obtainBackgrounds(result);
                                        }
                                    }
                                ];
                            }
                        }
                    ];
                }
            }
        ];
    }
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
    
    [wizardWindowController.btnCancel setEnabled:NO];
    [wizardWindowController.btnBack setEnabled:NO];
    [wizardWindowController.btnNext setEnabled:NO];
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
                    if (!result.error && result.loginSuccess && result.processSuccess) {
                        photographers = result.photographers;
                        PhotographerRow *photographerNone = [PhotographerRow new];
                        photographerNone.name = @"None";
                        [photographers insertObject:photographerNone atIndex:0];
                        [tblRolls reloadData];
                        [tblPhotographers reloadData];
                    }
                    
                    [wizardWindowController.btnCancel setEnabled:YES];
                    [wizardWindowController.btnBack setEnabled:YES];
                    [wizardWindowController.btnNext setEnabled:YES];
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
    } else if (tableView == tblPhotographers) {
        return photographers.count;
    } else if (tableView == tblBackgrounds) {
        filteredGreenScreenBackgrounds = [NSMutableArray new];
        
        for (BackgroundRow *background in greenScreenBackgrounds) {
            if ([background.sourceRoll isEqualToString:rollModelShown.number] &&
                (background.horzBackgroundOrderNo || background.vertBackgroundOrderNo)) {
                
                [filteredGreenScreenBackgrounds addObject:background];
            }
        }
        
        return filteredGreenScreenBackgrounds.count;
    }
    
    return 0;
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
            cell.imageView.image = roll.greenScreen ?
                [NSImage imageNamed:@"NSStatusAvailable"] : [NSImage imageNamed:@"NSStatusNone"];
            
        } else if ([columnID isEqualToString:@"CurrentTask"]) {
            NSTableCellView *cell = view;
            //cell.textField.stringValue = @"1234 of 9999 thumbs sent";
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
    } else if (tableView == tblBackgrounds) {
        NSTableCellView *cell = view;
        BackgroundRow *background = filteredGreenScreenBackgrounds[row];
        
        if ([columnID isEqualToString:@"Icon"]) {
            
        } else if ([columnID isEqualToString:@"HorzBackground"]) {
            cell.textField.stringValue = background.horzBackgroundOrderNo ? [NSString stringWithFormat:@"%@/%@/%@",
                background.horzBackgroundOrderNo, background.horzBackgroundRoll, background.horzBackgroundFrame] : @"Not specified";
            
        } else if ([columnID isEqualToString:@"HorzDimensions"]) {
            cell.textField.stringValue = !background.horzBackgroundWidth && !background.horzBackgroundHeight ?
                @"N/A" : [NSString stringWithFormat:@"%ld × %ld", background.horzBackgroundWidth, background.horzBackgroundHeight];

        } else if ([columnID isEqualToString:@"VertBackground"]) {
            cell.textField.stringValue = background.vertBackgroundOrderNo ? [NSString stringWithFormat:@"%@/%@/%@",
                background.vertBackgroundOrderNo, background.vertBackgroundRoll, background.vertBackgroundFrame] : @"Not specified";

        } else if ([columnID isEqualToString:@"VertDimensions"]) {
            cell.textField.stringValue = !background.vertBackgroundWidth && !background.vertBackgroundHeight ?
                @"N/A" : [NSString stringWithFormat:@"%ld × %ld", background.vertBackgroundWidth, background.vertBackgroundHeight];
            
        } else if ([columnID isEqualToString:@"OutputFolder"]) {
            cell.textField.stringValue = background.destinationRoll;
        } else if ([columnID isEqualToString:@"Delete"]) {
            
        }
    }
    
    return view;
}

- (void)startLoadEvent:(EventRow *)event fromWizard:(BOOL)fromWizard
{
    void (^terminate)(NSString *) = ^(NSString *message) {
        wizardWindowController.eventRow = nil;

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
    
    wizardWindowController.eventRow = event;
    
    for (Transfer *transfer in wizardWindowController.mainWindowController.transferManager.transfers) {
        if ([transfer.orderNumber isEqualToString:event.orderNumber] &&
            (transfer.status == kTransferStatusRunning || transfer.status == kTransferStatusQueued)) {
            
            terminate([NSString stringWithFormat:
                @"The event \"%@\" (%@) is currently being transferred.\r\rYou can either stop it or wait for it to finish in order to open it.",
                event.eventName, event.orderNumber]);
            
            return;
        }
    }
    
    if ([wizardWindowController.mainWindowController.openedEvents containsObject:event.orderNumber]) {
        terminate([NSString stringWithFormat:@"The event \"%@\" (%@) is already open in another window.", event.eventName, event.orderNumber]);
        return;
    }
    
    [wizardWindowController.mainWindowController.openedEvents addObject:event.orderNumber];
    
    for (Service *service in @[checkOrderNumberService, listPhotographersService, addPhotographerService, listDivisionsService]) {
        [service setEffectiveServiceRoot:wizardWindowController.effectiveService
            coreDomain:wizardWindowController.effectiveCoreDomain];
    }
    
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

                                                    [listDivisionsService startListDivisions:wizardWindowController.effectiveUser
                                                        password:wizardWindowController.effectivePass
                                                        eventID:event.eventID
                                                        complete:^(ListDivisionsResult *result) {
                                                            if (result.error) {
                                                                [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                                terminate([NSString stringWithFormat:
                                                                    @"Could not obtain the list of divisions. An error occurred: %@", result.error.localizedDescription]);

                                                            } else if (result.loginSuccess && result.processSuccess) {
                                                                divisions = result.divisions;

                                                                [getChromaKeyEventInformationService
                                                                    startGetChromaKeyEventInformation:event.ccsAccount
                                                                    password:ccsPassword
                                                                    eventID:event.eventID
                                                                    complete:^(GetChromaKeyEventInformationResult *result) {
                                                                        if (result.error) {
                                                                            [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                                            terminate([NSString stringWithFormat:
                                                                                @"Could not obtain green screen information. An error occurred: %@", result.error.localizedDescription]);
                                                                        } else {
                                                                            greenScreenBackgrounds = result.backgrounds;
                                                                            NSError *error = nil;
                                                                            [self view];
                                                                            orderModel = nil;
                                                                            [tblRolls reloadData];
                                                                            
                                                                            orderModel = [[OrderModel alloc] initWithEventRow:event extensions:uploadExtensions error:&error];
                                                                            
                                                                            if (orderModel == nil) {
                                                                                [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                                                terminate([NSString stringWithFormat:@"An error occurred while loading up the event. %@", error.localizedDescription]);
                                                                            } else {
                                                                                [self loadEvent];
                                                                            }
                                                                        }
                                                                    }
                                                                ];
                                                            } else {
                                                                [wizardWindowController.mainWindowController.openedEvents removeObject:event.orderNumber];
                                                                terminate(@"Could not obtain the list of divisions.");
                                                            }
                                                        }
                                                    ];
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
    wizardWindowController.window.title = [NSString stringWithFormat:@"%@: %@",
        orderModel.eventRow.orderNumber, orderModel.eventRow.eventName];
    
    //wizardWindowController.eventRow = orderModel.eventRow;
    
    NSData *storedMarketRows = [[NSUserDefaults standardUserDefaults] objectForKey:kMarketSettings];
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
    
    chkAutoCategorizeImages.state = orderModel.autoCategorizeImages ? NSOnState : NSOffState;
    chkHonourFramesPerRoll.title = [NSString stringWithFormat:@"Create new folder after %ld images", framesPerRoll];
    [tblPhotographers reloadData];
    
    for (DivisionRow *division in divisions) {
        if ([division.name isEqualToString:@"Default Division"]) {
            continue;
        }
        
        BOOL found = NO;
        
        for (RollModel *roll in orderModel.rolls) {
            if ([roll.number isEqualToString:division.name]) {
                found = YES;
                break;
            }
        }
        
        if (!found) {
            BOOL dirCreated = [[NSFileManager defaultManager]
                createDirectoryAtPath:[orderModel.rootDir stringByAppendingPathComponent:division.name]
                withIntermediateDirectories:NO attributes:nil error:nil];
            
            if (dirCreated) {
                RollModel *roll = [RollModel new];
                roll.number = division.name;
                roll.photographer = @"None";
                roll.frames = [NSMutableArray new];
                [orderModel.rolls addObject:roll];
            }
        }
    }
    
    if (orderModel.newlyAdded) {
        NSNumber *detectNewFiles = [[NSUserDefaults standardUserDefaults] objectForKey:kDetectNewFiles];

        if (!detectNewFiles || detectNewFiles.boolValue) {
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
            [orderModel ignoreNewlyAdded];
        }
    }
    
    [self matchRollsWithGreenScreen];
    [tblRolls reloadData];

    wizardWindowController.txtStepTitle.stringValue = orderModel.eventRow.eventName;
    wizardWindowController.txtStepDescription.stringValue =
        [NSString stringWithFormat:@"Event Number: %@; Market: %@", orderModel.eventRow.orderNumber, orderModel.eventRow.market];
    
    [wizardWindowController showStep:kWizardStepBrowse];
}

- (IBAction)autoCategorizeClicked:(id)sender
{
    orderModel.autoCategorizeImages = (chkAutoCategorizeImages.state == NSOnState ? YES : NO);
}

- (IBAction)ignoreNewFiles:(id)sender
{
    [orderModel ignoreNewlyAdded];
    [includeNewlyAddedImagesSheet close];
    [tblRolls reloadData];
    //[orderModel save];
    [NSApp endSheet:includeNewlyAddedImagesSheet];
}

- (IBAction)importNewFiles:(id)sender
{
    [includeNewlyAddedImagesSheet close];
    [NSApp endSheet:includeNewlyAddedImagesSheet];

    [self performSelectorInBackground:@selector(importImagesInBackground) withObject:nil];
    
    //[tblRolls reloadData];
    //[orderModel save];
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
            [tblRolls reloadData];
            //[orderModel save];
        }
    }
}

- (IBAction)clickedAutoRenumberRoll:(id)sender
{
    NSInteger rollIndex = [tblRolls clickedRow];
    [orderModel autoRenumberRollAtIndex:rollIndex];
    //[orderModel save];
}

- (IBAction)clickedAutoRenumberAllRolls:(id)sender
{
    for (NSInteger rollIndex = 0; rollIndex < orderModel.rolls.count; ++rollIndex) {
        [orderModel autoRenumberRollAtIndex:rollIndex];
    }

    //[orderModel save];
}

- (IBAction)changedPhotographer:(id)sender
{
    NSPopUpButton *btn = sender;
    NSInteger rollIndex = [tblRolls rowForView:sender];
    
    if (rollIndex >= 0) {
        RollModel *roll = orderModel.rolls[rollIndex];
        roll.photographer = [btn.selectedItem.title copy];
        //[tblRolls reloadData];
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
    if (!tblRolls.isEnabled) {
        return;
    }
    
    NSInteger row = [tblRolls rowForView:sender];
    
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to delete this roll?"
        defaultButton:@"Yes" alternateButton:@"No" otherButton:@"" informativeTextWithFormat:@""];
    
    [alert beginSheetModalForWindow:wizardWindowController.window
        completionHandler:^(NSModalResponse response) {
            if (response == NSModalResponseOK) {
                [orderModel deleteRollAtIndex:row];
                //[orderModel save];
                [tblRolls removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationEffectFade];
            }
        }
    ];
}

- (IBAction)clickedViewRoll:(id)sender
{
    if (!tblRolls.isEnabled) {
        return;
    }
    
    NSInteger row = [tblRolls rowForView:sender];
    RollModel *targetRoll = orderModel.rolls[row];
    
    if (rollModelShown == targetRoll) {
        [viewRollPopover close];
        rollModelShown = nil;
        return;
    }
    
    [viewRollPopover close];
    rollModelShown = targetRoll;
    rollModelShown.imagesViewed = YES;
    
    [imagesInBrowser removeAllObjects];
    NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:targetRoll.number];
    
    imageBrowserTitle.stringValue = rollPath;
    
    for (FrameModel *frame in targetRoll.frames) {
        NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
            stringByAppendingPathExtension:frame.extension];
        
        ImageInBrowserView *newEntry = [[ImageInBrowserView alloc] initWithFrame:frame path:filepath];
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
        //[orderModel save];
        [tblRolls performSelector:@selector(reloadData) withObject:nil afterDelay:0];
        rollsNeedReload = NO;
    }
}

@end