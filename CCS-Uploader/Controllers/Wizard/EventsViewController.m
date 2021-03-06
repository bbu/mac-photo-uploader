#import "EventsViewController.h"

#import "../WizardWindowController.h"

#import "../../Services/ListEventsService.h"

@interface EventsViewController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate> {
    IBOutlet NSPopUpButton *btnSearchType;
    IBOutlet NSSearchField *txtSearch;
    IBOutlet NSPopover *advancedSearchPopover;
    IBOutlet NSButton *chkHideNonAssigned, *chkHideNullDates, *chkHideActive, *chkFilterDateRange;
    IBOutlet NSDatePicker *dpStartDate, *dpEndDate;
    IBOutlet NSTableView *tblEvents;
    IBOutlet NSProgressIndicator *refreshIndicator;
    
    NSMutableArray *events, *filteredEvents;
    NSDateFormatter *dateFormatter;
    ListEventsService *listEventsService;
    WizardWindowController *wizardWindowController;
    NSUInteger popoverState;
}
@end

@implementation EventsViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"EventsView" bundle:nil];

    if (self) {
        events = filteredEvents = [NSMutableArray new];
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"MM/dd/Y";
        listEventsService = [ListEventsService new];
        wizardWindowController = parent;
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    dpStartDate.dateValue = [NSDate dateWithTimeInterval:-60 * 60 * 24 * 30 sinceDate:[NSDate date]];
    dpEndDate.dateValue = [NSDate dateWithTimeInterval:4 * 60 * 60 sinceDate:[NSDate date]];
}

- (void)refreshIfEmpty
{
    if (!events.count) {
        [self clickedRefresh:nil];
    }
}

- (IBAction)advancedSearchClicked:(id)sender
{
    [advancedSearchPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return filteredEvents.count;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    EventRow *event = filteredEvents[row];
    
    if ([columnID isEqualToString:@"EventName"]) {
        return event.eventName;
    } else if ([columnID isEqualToString:@"EventNumber"]) {
        return event.orderNumber;
    } else if ([columnID isEqualToString:@"EventDate"]) {
        return [dateFormatter stringFromDate:event.eventDate];
    } else if ([columnID isEqualToString:@"EventType"]) {
        return event.isQuicPost ? @"QuicPost" : @"";
    }
    
    return nil;
}

- (EventRow *)selectedEventRow
{
    if (tblEvents.selectedRow == -1) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"You must select an event.";
        [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
        return nil;
    }
    
    return filteredEvents[tblEvents.selectedRow];
}

- (IBAction)clickedDateRange:(id)sender
{
    BOOL enabled = chkFilterDateRange.state == NSOnState ? YES : NO;

    [dpStartDate setEnabled:enabled];
    [dpEndDate setEnabled:enabled];
}

- (IBAction)clickedRefresh:(id)sender
{
    [self refreshEvents:NO];
}

- (IBAction)clickedSearchType:(id)sender
{
    [txtSearch becomeFirstResponder];
}

- (void)refreshEvents:(BOOL)fromWizard
{
    [self view];
    
    [tblEvents deselectAll:nil];
    
    [listEventsService setEffectiveServiceRoot:wizardWindowController.effectiveService
        coreDomain:wizardWindowController.effectiveCoreDomain];
    
    BOOL started = [listEventsService
        startListEvents:wizardWindowController.effectiveUser
        password:wizardWindowController.effectivePass
        filterDateRange:chkFilterDateRange.state == NSOnState ? YES : NO
        startDate:dpStartDate.dateValue
        endDate:dpEndDate.dateValue
        hideNullDates:chkHideNullDates.state == NSOnState ? YES : NO
        hideActive:chkHideActive.state == NSOnState ? YES : NO
        hideNonAssigned:chkHideNonAssigned.state == NSOnState ? YES : NO
        hideNullOrderNumbers:YES
        complete:^(ListEventsResult *result) {
            [btnSearchType setEnabled:YES];
            [txtSearch setEnabled:YES];
            [wizardWindowController.btnBack setEnabled:YES];
            [wizardWindowController.btnNext setEnabled:YES];
            [refreshIndicator stopAnimation:nil];
            [tblEvents setEnabled:YES];
            
            if (result.error) {
                NSAlert *alert = [NSAlert alertWithError:result.error];
                
                if (fromWizard) {
                    [wizardWindowController showStep:kWizardStepLogin];
                }
                
                [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            } else if (result.loginSuccess && result.processSuccess) {
                events = filteredEvents = result.events;
                
                if (fromWizard) {
                    [wizardWindowController showStep:kWizardStepEvents];
                }
                
                [tblEvents reloadData];
            } else {
                NSAlert *alert = [NSAlert new];
                alert.messageText = @"The list of events could not be obtained from the server.";
                
                if (fromWizard) {
                    [wizardWindowController showStep:kWizardStepLogin];
                }
                
                [alert beginSheetModalForWindow:wizardWindowController.window completionHandler:nil];
            }
        }
    ];
    
    if (started) {
        [btnSearchType setEnabled:NO];
        txtSearch.stringValue = @"";
        [txtSearch setEnabled:NO];
        [wizardWindowController.btnBack setEnabled:NO];
        [wizardWindowController.btnNext setEnabled:NO];
        [refreshIndicator startAnimation:nil];
        [tblEvents setEnabled:NO];
    }
}

- (IBAction)closeAdvancedSearch:(id)sender
{
    [advancedSearchPopover close];
}

- (void)popoverWillShow:(NSNotification *)notification
{
    popoverState = dpStartDate.dateValue.hash + dpEndDate.dateValue.hash +
        chkHideNonAssigned.state + chkHideNullDates.state +
        chkHideActive.state + chkFilterDateRange.state;
}

- (void)popoverWillClose:(NSNotification *)notification
{
    NSUInteger oldPopoverState = popoverState;
    
    popoverState = dpStartDate.dateValue.hash + dpEndDate.dateValue.hash +
        chkHideNonAssigned.state + chkHideNullDates.state +
        chkHideActive.state + chkFilterDateRange.state;
    
    if (oldPopoverState != popoverState) {
        [self clickedRefresh:nil];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    NSString *needle = txtSearch.stringValue;
    NSRange range;
    
    if (!needle.length) {
        filteredEvents = events;
    } else {
        filteredEvents = [NSMutableArray new];
        
        for (EventRow *event in events) {
            if (btnSearchType.selectedTag == 0) {
                range = [event.orderNumber rangeOfString:needle options:NSCaseInsensitiveSearch];
                
                if (range.location != NSNotFound && range.location == 0) {
                    [filteredEvents addObject:event];
                }
            } else {
                range = [event.eventName rangeOfString:needle options:NSCaseInsensitiveSearch];
                
                if (range.location != NSNotFound) {
                    [filteredEvents addObject:event];
                }
            }
        }
    }
    
    [tblEvents deselectAll:nil];
    [tblEvents reloadData];
}

@end
