#import "MarketSettingsViewController.h"
#import "AdvancedViewController.h"

@interface MarketSettingsViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSTableView *tblMarketSettings;
    NSMutableArray *marketSettingsRows;
    IBOutlet NSPopUpButton *btnSimultaneousPreloaderUploads;
}
@end

@implementation MarketSettingsViewController

- (void)loadView
{
    [super loadView];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *simultaneousPreloaderUploads = [defaults objectForKey:kSimultaneousPreloaderUploads];
    
    [btnSimultaneousPreloaderUploads
        selectItemAtIndex:simultaneousPreloaderUploads ? simultaneousPreloaderUploads.integerValue - 1 : 0];
    
    NSData *storedRows = [defaults objectForKey:kMarketSettings];

    if (storedRows != nil) {
        marketSettingsRows = [[NSKeyedUnarchiver unarchiveObjectWithData:storedRows] mutableCopy];
        
        if (marketSettingsRows.count != 0) {
            return;
        }
    }
    
    marketSettingsRows = [@[
        [@{@"Market": @"GRAD", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"GRUP", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"PROM", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"QPIC", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"RACE", @"Images": [NSNumber numberWithInt: 100], @"UsePreloader": [NSNumber numberWithBool:YES]} mutableCopy],
        [@{@"Market": @"SCHL", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"SPRT", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
        [@{@"Market": @"WEDD", @"Images": [NSNumber numberWithInt:9999], @"UsePreloader": [NSNumber numberWithBool: NO]} mutableCopy],
    ] mutableCopy];

    [self saveState];
}

- (void)saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:marketSettingsRows]
        forKey:kMarketSettings];
    
    [defaults setObject:[NSNumber numberWithInteger:btnSimultaneousPreloaderUploads.selectedItem.title.integerValue]
        forKey:kSimultaneousPreloaderUploads];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return marketSettingsRows.count;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    
    if ([columnID isEqualToString:@"Images"]) {
        return YES;
    }
    
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger col = [tblMarketSettings columnWithIdentifier:@"Images"];
    NSInteger row = tblMarketSettings.selectedRow;
    [tblMarketSettings editColumn:col row:row withEvent:NULL select:YES];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return marketSettingsRows[row][tableColumn.identifier];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSNumber *number = object;
    
    if (number.integerValue < 0) {
        return;
    }
    
    marketSettingsRows[row][tableColumn.identifier] = object;
    [tableView reloadData];
}

- (IBAction)simultaneousUploadsHelp:(id)sender
{
    NSString *label = @"When enabled, you may queue image imports in the wizard and assign photographers, simulating multiple drag and drops. This setting also enables preview and thumbnail generation in the wizard.";
    
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(260, 97)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

@end
