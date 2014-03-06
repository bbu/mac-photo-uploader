#import "ScheduleViewController.h"

#import "../WizardWindowController.h"
#import "../MainWindowController.h"
#import "../../Services/ListEventsService.h"

@interface ScheduleViewController () {
    WizardWindowController *wizardWindowController;
    IBOutlet NSDatePicker *dpScheduleThumbs, *dpScheduleFullsize;
    IBOutlet NSMatrix *scheduleThumbsRadios, *scheduleFullsizeRadios, *whichImagesRadios;
}

@end

@implementation ScheduleViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"ScheduleView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
    }
    
    return self;
}

- (void)resetFormState
{
    [self view];
    
    dpScheduleThumbs.dateValue = [NSDate date];
    dpScheduleFullsize.dateValue = [NSDate date];
    
    [scheduleThumbsRadios selectCellWithTag:1];
    [dpScheduleThumbs setEnabled:NO];

    [scheduleFullsizeRadios selectCellWithTag:1];
    [dpScheduleFullsize setEnabled:NO];
    
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
}

- (IBAction)scheduleFullsizeChanged:(id)sender
{
    NSButtonCell *selectedCell = [sender selectedCell];

    if (selectedCell.tag == 2) {
        [dpScheduleFullsize setEnabled:YES];
    } else {
        [dpScheduleFullsize setEnabled:NO];
    }
}

- (void)pushTransfer
{
    Transfer *newTransfer1 = [Transfer new];
    Transfer *newTransfer2 = [Transfer new];
    
    if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 1) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer1.eventName = wizardWindowController.eventRow.eventName;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = YES;
        newTransfer1.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer1.dateScheduled = nil;
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        
    } else if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 2) {
        newTransfer1.status = kTransferStatusQueued;
        newTransfer1.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer1.eventName = wizardWindowController.eventRow.eventName;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer1.dateScheduled = nil;
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        
        newTransfer2.status = kTransferStatusScheduled;
        newTransfer2.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer2.eventName = wizardWindowController.eventRow.eventName;
        newTransfer2.uploadThumbs = NO;
        newTransfer2.uploadFullsize = YES;
        newTransfer2.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer2.dateScheduled = [dpScheduleFullsize.dateValue copy];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
        
    } else if (scheduleThumbsRadios.selectedTag == 1 && scheduleFullsizeRadios.selectedTag == 3) {
        
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 1) {
        newTransfer1.status = kTransferStatusScheduled;
        newTransfer1.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer1.eventName = wizardWindowController.eventRow.eventName;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        
        newTransfer2.status = kTransferStatusQueued;
        newTransfer2.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer2.eventName = wizardWindowController.eventRow.eventName;
        newTransfer2.uploadThumbs = NO;
        newTransfer2.uploadFullsize = YES;
        newTransfer2.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer2.dateScheduled = nil;
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
        
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 2) {
        newTransfer1.status = kTransferStatusScheduled;
        newTransfer1.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer1.eventName = wizardWindowController.eventRow.eventName;
        newTransfer1.uploadThumbs = YES;
        newTransfer1.uploadFullsize = NO;
        newTransfer1.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer1.dateScheduled = [dpScheduleThumbs.dateValue copy];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer1 atIndex:0];
        
        newTransfer2.status = kTransferStatusScheduled;
        newTransfer2.orderNumber = wizardWindowController.eventRow.orderNumber;
        newTransfer2.eventName = wizardWindowController.eventRow.eventName;
        newTransfer2.uploadThumbs = NO;
        newTransfer2.uploadFullsize = YES;
        newTransfer2.datePushed = wizardWindowController.eventRow.eventDate;
        newTransfer2.dateScheduled = [dpScheduleFullsize.dateValue copy];
        [wizardWindowController.mainWindowController.transferManager.transfers insertObject:newTransfer2 atIndex:0];
        
    } else if (scheduleThumbsRadios.selectedTag == 2 && scheduleFullsizeRadios.selectedTag == 3) {
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 1) {
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 2) {
    } else if (scheduleThumbsRadios.selectedTag == 3 && scheduleFullsizeRadios.selectedTag == 3) {
        
    }
    
    [wizardWindowController.mainWindowController.transferManager reload];
    [wizardWindowController.mainWindowController showWindow:nil];
}

@end
