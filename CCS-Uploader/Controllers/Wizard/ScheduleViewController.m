#import "ScheduleViewController.h"

#import "../Wizard/BrowseViewController.h"
#import "../WizardWindowController.h"
#import "../MainWindowController.h"

#import "../../Models/OrderModel.h"
#import "../../Services/ListEventsService.h"
#import "../../Services/MissingFullSizeImagesByRollService.h"

#import <Quartz/Quartz.h>

@interface MultipleSelectionIKImageBrowserView: IKImageBrowserView

- (void)mouseDown:(NSEvent *)event;

@end

@implementation MultipleSelectionIKImageBrowserView

- (void)mouseDown:(NSEvent *)event
{
    NSPoint pt = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger index = [self indexOfItemAtPoint:pt];

    if (index != NSNotFound) {
        NSUInteger ge, le;
        NSIndexSet *set = self.selectionIndexes;
        NSMutableIndexSet *mutableSet = [NSMutableIndexSet new];
        
        [mutableSet addIndexes:set];
        
        ge = [mutableSet indexGreaterThanOrEqualToIndex:index];
        le = [mutableSet indexLessThanOrEqualToIndex:index];
        
        if (ge == le && ge != NSNotFound) {
            [mutableSet removeIndex:index] ;
        } else {
            [mutableSet addIndex:index] ;
        }
        
        [self setSelectionIndexes:mutableSet byExtendingSelection:NO];
    }
}
@end

@interface ScheduleViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    WizardWindowController *wizardWindowController;
    IBOutlet NSDatePicker *dpScheduleThumbs, *dpScheduleFullsize;
    IBOutlet NSMatrix *scheduleThumbsRadios, *scheduleFullsizeRadios, *whichImagesRadios;
    IBOutlet NSProgressIndicator *missingImagesProgress;
    IBOutlet NSTextField *missingImagesProgressLabel;
    IBOutlet NSPanel *selectImagesSheet;
    IBOutlet NSTableView *tblSelectedRolls;
    IBOutlet MultipleSelectionIKImageBrowserView *selectedImagesBrowser;
    IBOutlet NSTextField *lblSelectedImages;
    NSMutableArray *itemsInBrowser;

    MissingFullSizeImagesByRollService *missingFullSizeImagesByRollService;
}

@end

@implementation ScheduleViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"ScheduleView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
        missingFullSizeImagesByRollService = [MissingFullSizeImagesByRollService new];
        itemsInBrowser = [NSMutableArray new];
    }
    
    return self;
}

- (void)resetFormState
{
    [self view];
    
    NSDate *now = [NSDate date];
    
    dpScheduleThumbs.dateValue = now;
    dpScheduleFullsize.dateValue = now;
    
    [scheduleThumbsRadios selectCellWithTag:1];
    [dpScheduleThumbs setEnabled:NO];
    [[scheduleThumbsRadios cellAtRow:2 column:0] setEnabled:YES];

    [scheduleFullsizeRadios selectCellWithTag:1];
    [dpScheduleFullsize setEnabled:NO];
    [[scheduleFullsizeRadios cellAtRow:2 column:0] setEnabled:YES];
    
    [whichImagesRadios selectCellWithTag:1];
}

- (IBAction)scheduleThumbsChanged:(id)sender
{
    NSButtonCell *selectedCell = [sender selectedCell];
    
    if (selectedCell.tag == 2) {
        [dpScheduleThumbs setEnabled:YES];
    } else {
        [dpScheduleThumbs setEnabled:NO];
    }
    
    if (selectedCell.tag == 3) {
        [[scheduleFullsizeRadios cellAtRow:2 column:0] setEnabled:NO];
    } else {
        [[scheduleFullsizeRadios cellAtRow:2 column:0] setEnabled:YES];
    }
}

- (IBAction)scheduleFullsizeChanged:(id)sender
{
    NSButtonCell *selectedCell = [sender selectedCell];

    if (selectedCell.tag == 2) {
        [dpScheduleFullsize setEnabled:YES];
    } else {
        [dpScheduleFullsize setEnabled:NO];
    }

    if (selectedCell.tag == 3) {
        [[scheduleThumbsRadios cellAtRow:2 column:0] setEnabled:NO];
    } else {
        [[scheduleThumbsRadios cellAtRow:2 column:0] setEnabled:YES];
    }
}

- (IBAction)whichImagesChanged:(id)sender
{
    NSButtonCell *selectedCell = [sender selectedCell];
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    
    if (selectedCell.tag == 2) {
        for (RollModel *roll in orderModel.rolls) {
            for (FrameModel *frame in roll.frames) {
                if (!frame.fullsizeSent) {
                    frame.isSelected = YES;
                    frame.isSelectedFullsizeSent = NO;
                    frame.isSelectedThumbsSent = NO;
                } else {
                    frame.isSelected = NO;
                    frame.isSelectedFullsizeSent = NO;
                    frame.isSelectedThumbsSent = NO;
                }
            }
        }
        
        [tblSelectedRolls reloadData];
        [tblSelectedRolls selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        
        [NSApp beginSheet:selectImagesSheet modalForWindow:wizardWindowController.window
            modalDelegate:nil didEndSelector:nil contextInfo:nil];
    } else if (selectedCell.tag == 3) {
        [missingImagesProgress startAnimation:nil];
        [missingImagesProgressLabel setHidden:NO];
        [whichImagesRadios setEnabled:NO];
        
        [wizardWindowController.btnCancel setEnabled:NO];
        [wizardWindowController.btnBack setEnabled:NO];
        [wizardWindowController.btnNext setEnabled:NO];
        
        [missingFullSizeImagesByRollService
            startListImages:wizardWindowController.eventRow.ccsAccount
            password:wizardWindowController.browseViewController.ccsPassword
            orderNumber:wizardWindowController.eventRow.orderNumber
            roll:@""
            complete:^(MissingFullSizeImagesByRollResult *result) {
                if (!result.error && [result.status isEqualToString:@"AuthenticationSuccessful"]) {
                    NSMutableDictionary *missingImageSets = [NSMutableDictionary new];
                    
                    for (MissingFullSizeImageRow *missing in result.missingImages) {
                        if (!missing.roll.length || !missing.frame.length) {
                            continue;
                        }
                        
                        NSMutableSet *imageSet = missingImageSets[missing.roll];
                        
                        if (imageSet == nil) {
                            missingImageSets[missing.roll] = [NSMutableSet new];
                            imageSet = missingImageSets[missing.roll];
                        }
                        
                        [imageSet addObject:missing.frame];
                    }
                    
                    for (RollModel *roll in wizardWindowController.browseViewController.orderModel.rolls) {
                        for (FrameModel *frame in roll.frames) {
                            NSSet *imageSet = missingImageSets[roll.number];
                            
                            if (imageSet != nil && [imageSet containsObject:frame.name]) {
                                frame.isMissing = YES;
                                frame.isMissingFullsizeSent = NO;
                                frame.isMissingThumbsSent = NO;
                            } else {
                                frame.isMissing = NO;
                            }
                        }
                    }
                } else if (result.error) {
                    NSAlert *alert = [NSAlert new];
                    
                    alert.messageText = [NSString stringWithFormat:
                        @"Could not retrieve the list of missing images, an error occurred: %@", result.error.localizedDescription];
                    
                    [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
                } else {
                    NSAlert *alert = [NSAlert new];
                    
                    alert.messageText = [NSString stringWithFormat:
                        @"Could not retrieve the list of missing images.\r\rThe server returned \"%@\" with a status of \"%@\".",
                            result.message, result.status];
                    
                    [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
                }
                
                [missingImagesProgress stopAnimation:nil];
                [missingImagesProgressLabel setHidden:YES];
                [whichImagesRadios setEnabled:YES];

                [wizardWindowController.btnCancel setEnabled:YES];
                [wizardWindowController.btnBack setEnabled:YES];
                [wizardWindowController.btnNext setEnabled:YES];
            }
        ];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    return orderModel.rolls.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    NSView *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    RollModel *roll = orderModel.rolls[row];
    
    if ([columnID isEqualToString:@"Roll"]) {
        NSTableCellView *cell = (NSTableCellView *)view;
        NSUInteger numUnsent = 0;
        
        for (FrameModel *frame in roll.frames) {
            if (!frame.fullsizeSent && !frame.imageErrors.length) {
                numUnsent++;
            }
        }
        
        cell.textField.stringValue = [NSString stringWithFormat:@"%@%@", roll.number, numUnsent ?
            [NSString stringWithFormat:@" [%lu unsent]", numUnsent] : @""];
        
        cell.imageView.image = [NSImage imageNamed:roll.framesHaveErrors ? @"NSCaution" : @"NSFolder"];
    }
    
    return view;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedRow = tblSelectedRolls.selectedRow;
    
    if (selectedRow != -1) {
        OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
        RollModel *roll = orderModel.rolls[selectedRow];
        
        [itemsInBrowser removeAllObjects];
        NSString *rollPath = [orderModel.rootDir stringByAppendingPathComponent:roll.number];
        NSMutableIndexSet *selectedIndexes = [NSMutableIndexSet new];
        NSUInteger currentIndex = 0;
        
        for (FrameModel *frame in roll.frames) {
            if (!frame.imageErrors.length) {
                NSString *filepath = [[rollPath stringByAppendingPathComponent:frame.name]
                    stringByAppendingPathExtension:frame.extension];
                
                ImageInBrowserView *item = [[ImageInBrowserView alloc] initWithFrame:frame path:filepath];
                [itemsInBrowser addObject:item];

                if (frame.isSelected) {
                    [selectedIndexes addIndex:currentIndex];
                }
                
                currentIndex++;
            }
        }
        
        [selectedImagesBrowser reloadData];
        [selectedImagesBrowser setSelectionIndexes:selectedIndexes byExtendingSelection:NO];
        
        lblSelectedImages.stringValue = [NSString stringWithFormat:@"%lu of %lu images selected",
            selectedImagesBrowser.selectionIndexes.count, itemsInBrowser.count];
        
        [selectedImagesBrowser becomeFirstResponder];
    }
}

- (IBAction)sliderDidMove:(id)sender
{
    NSSlider *slider = sender;
    selectedImagesBrowser.zoomValue = slider.floatValue / 100.;
}

- (IBAction)selectAll:(id)sender
{
    [selectedImagesBrowser selectAll:nil];
}

- (IBAction)unselectAll:(id)sender
{
    [selectedImagesBrowser setSelectionIndexes:[NSIndexSet new] byExtendingSelection:NO];
}

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)browser
{
    NSUInteger currentIndex = 0;
    
    lblSelectedImages.stringValue = [NSString stringWithFormat:@"%lu of %lu images selected",
        selectedImagesBrowser.selectionIndexes.count, itemsInBrowser.count];
    
    for (ImageInBrowserView *item in itemsInBrowser) {
        if ([selectedImagesBrowser.selectionIndexes containsIndex:currentIndex]) {
            item.frame.isSelected = YES;
        } else {
            item.frame.isSelected = NO;
        }
        
        currentIndex++;
    }
}

- (void)imageBrowser:(IKImageBrowserView *)browser cellWasDoubleClickedAtIndex:(NSUInteger)index
{
}

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)browser
{
    return itemsInBrowser.count;
}

- (id)imageBrowser:(IKImageBrowserView *)browser itemAtIndex:(NSUInteger)index
{
    return itemsInBrowser[index];
}

- (IBAction)closeSelectImagesSheet:(id)sender
{
    [selectImagesSheet close];
    [NSApp endSheet:selectImagesSheet];
}

- (void)pushTransfer
{
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    
    NSIndexSet *transferIndexesToRemove = [wizardWindowController.mainWindowController.transferManager.transfers indexesOfObjectsPassingTest:
        ^BOOL(Transfer *transfer, NSUInteger idx, BOOL *stop) {
            return [transfer.orderNumber isEqualToString:wizardWindowController.eventRow.orderNumber];
        }
    ];
    
    [wizardWindowController.mainWindowController.transferManager.transfers removeObjectsAtIndexes:transferIndexesToRemove];
    
    Transfer *newTransfer1 = [Transfer new];
    Transfer *newTransfer2 = [Transfer new];
    
    newTransfer1.orderNumber = newTransfer2.orderNumber = wizardWindowController.eventRow.orderNumber;
    newTransfer1.eventName = newTransfer2.eventName = wizardWindowController.eventRow.eventName;
    
    switch (whichImagesRadios.selectedTag) {
        case 1:
            newTransfer1.mode = newTransfer2.mode = kTransferModeUnsent;
            break;
            
        case 2:
            newTransfer1.mode = newTransfer2.mode = kTransferModeSelected;
            [orderModel save];
            break;
            
        case 3:
            newTransfer1.mode = newTransfer2.mode = kTransferModeMissing;
            [orderModel save];
            break;
    }
    
    newTransfer1.datePushed = newTransfer2.datePushed = [NSDate date];
    newTransfer1.isQuicPost = newTransfer2.isQuicPost = wizardWindowController.effectiveService == kServiceRootQuicPost ? YES : NO;
    
    if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 1) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = YES;
        newTransfer1.dateScheduled = nil;
        
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 2) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.dateScheduled = nil;
        
        newTransfer2.status = kTransferStatusScheduled;
        newTransfer2.uploadThumbs = NO;
        newTransfer2.uploadFullsize = YES;
        newTransfer2.dateScheduled = [dpScheduleFullsize.dateValue copy];

        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 3) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.dateScheduled = nil;
        
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 1) {
        newTransfer1.status = kTransferStatusScheduled;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];
        
        newTransfer2.status = kTransferStatusQueued;
        newTransfer2.uploadThumbs = NO;
        newTransfer2.uploadFullsize = YES;
        newTransfer2.dateScheduled = nil;

        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 2) {
        if ([dpScheduleFullsize.dateValue compare:dpScheduleThumbs.dateValue] == NSOrderedSame) {
            newTransfer1.status = kTransferStatusScheduled;
            newTransfer1.uploadThumbs = YES;
            newTransfer1.uploadFullsize = YES;
            newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];

            [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        } else {
            newTransfer1.status = kTransferStatusScheduled;
            newTransfer1.uploadThumbs = YES;
            newTransfer1.uploadFullsize = NO;
            newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];
        
            newTransfer2.status = kTransferStatusScheduled;
            newTransfer2.uploadThumbs = NO;
            newTransfer2.uploadFullsize = YES;
            newTransfer2.dateScheduled = [dpScheduleFullsize.dateValue copy];

            [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
            [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        }
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 3) {
        newTransfer1.status = kTransferStatusScheduled;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];
        
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 1) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.uploadThumbs = NO;
        newTransfer1.uploadFullsize = YES;
        newTransfer1.dateScheduled = nil;
        
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 2) {
        newTransfer1.status = kTransferStatusScheduled;
        newTransfer1.uploadThumbs = NO;
        newTransfer1.uploadFullsize = YES;
        newTransfer1.dateScheduled = [dpScheduleFullsize.dateValue copy];
        
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 3) {
    }
    
    [wizardWindowController.mainWindowController.openedEvents removeObject:wizardWindowController.eventRow.orderNumber];
    [wizardWindowController.mainWindowController.transferManager reload];
    [wizardWindowController.mainWindowController showWindow:nil];
}

@end
