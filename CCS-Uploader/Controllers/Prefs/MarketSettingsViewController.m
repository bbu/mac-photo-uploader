#import "MarketSettingsViewController.h"
#import "AdvancedViewController.h"

@interface MarketSettingsViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    IBOutlet NSTableView *tblMarketSettings;
    NSMutableArray *marketSettingsRows;
}
@end

@implementation MarketSettingsViewController

- (void)loadView
{
    [super loadView];

    tblMarketSettings.focusRingType = NSFocusRingTypeNone;
    tblMarketSettings.allowsColumnReordering = NO;
    tblMarketSettings.allowsColumnResizing = NO;
    
    NSData *storedRows = [[NSUserDefaults standardUserDefaults] objectForKey:@"marketSettingsRows"];

    if (storedRows != nil) {
        marketSettingsRows = [[NSKeyedUnarchiver unarchiveObjectWithData:storedRows] mutableCopy];
        
        if (marketSettingsRows.count != 0) {
            return;
        }
    }
    
    marketSettingsRows = [NSMutableArray arrayWithObjects:
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"GRAD",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"GRUP",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"PROM",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"QPIC",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"RACE",                        @"Market",
            [NSNumber numberWithInt:100],   @"Images",
            [NSNumber numberWithBool:YES],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"SCHL",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil
        ],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"SPRT",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"WEDD",                        @"Market",
            [NSNumber numberWithInt:9999],  @"Images",
            [NSNumber numberWithBool:NO],   @"UsePreloader", nil],

        nil
    ];
    
    [self saveState];
}

- (void)saveState
{
    [[NSUserDefaults standardUserDefaults] setObject:
        [NSKeyedArchiver archivedDataWithRootObject:marketSettingsRows]
        forKey:@"marketSettingsRows"];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return marketSettingsRows.count;
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
