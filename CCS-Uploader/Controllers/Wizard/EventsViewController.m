#import "EventsViewController.h"

#import "../../Services/ListEventsService.h"

@interface EventsViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSPopover *advancedSearchPopover;
    IBOutlet NSButton *chkHideNonAssigned, *chkHideNullDates, *chkHideActive, *chkFilterDateRange;
    IBOutlet NSDatePicker *dpStartDate, *dpEndDate;
    IBOutlet NSTableView *tblEvents;
    IBOutlet NSProgressIndicator *refreshIndicator;
    NSMutableArray *events;
    NSDateFormatter *dateFormatter;
}

@end

@implementation EventsViewController
@synthesize
    chkHideNonAssigned,
    chkHideNullDates,
    chkHideActive,
    chkFilterDateRange,
    dpStartDate,
    dpEndDate,
    tblEvents,
    events;

- (id)init
{
    self = [super initWithNibName:@"EventsView" bundle:nil];

    if (self) {
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"MM/dd/Y";
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
}

- (IBAction)advancedSearchClicked:(id)sender
{
    [advancedSearchPopover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return events.count;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return NO;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    EventRow *event = events[row];
    
    if ([columnID isEqualToString:@"EventName"]) {
        return event.eventName;
    } else if ([columnID isEqualToString:@"EventNumber"]) {
        return event.eventID;
    } else if ([columnID isEqualToString:@"EventDate"]) {
        return [dateFormatter stringFromDate:event.eventDate];
    } else if ([columnID isEqualToString:@"EventType"]) {
        return event.isQuicPost ? @"QuicPost" : @"";
    }
    
    return nil;
}

- (IBAction)clickedDateRange:(id)sender
{
    BOOL enabled = chkFilterDateRange.state == NSOnState ? YES : NO;

    [dpStartDate setEnabled:enabled];
    [dpEndDate setEnabled:enabled];
}

- (IBAction)clickedRefresh:(id)sender
{
    [refreshIndicator startAnimation:nil];
}

@end
