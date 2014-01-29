#import <Cocoa/Cocoa.h>

@interface EventsViewController : NSViewController

@property NSMutableArray *events;
@property NSButton *chkHideNonAssigned, *chkHideNullDates, *chkHideActive, *chkFilterDateRange;
@property NSDatePicker *dpStartDate, *dpEndDate;
@property NSTableView *tblEvents;

@end
