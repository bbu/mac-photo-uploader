#import "MainWindowController.h"
#import "Prefs/AdvancedViewController.h"

@interface MainWindowController ()

@end

@implementation MainWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"MainWindow"];
    
    if (self) {
    
    }
    
    return self;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    NSInteger rowCount = 0;
    
    if (tableView == tblThumbnails) {
        rowCount = 50;
    } else if (tableView == tblFullSize) {
        rowCount = 15;
    }
    
    return rowCount;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    if (row % 5 == 0) {
        return 13;
    } else {
        return 18;
    }
}

-(IBAction)deleteRowFromThumbnails:(id)sender
{
    NSInteger clickedRow = [tblThumbnails rowForView:sender];

    if (clickedRow != -1) {
        [tblThumbnails removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:clickedRow] withAnimation:NSTableViewAnimationEffectFade];
    }
}

-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return (row % 5 == 0) ? NO : YES;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    //if (tableView == tblThumbnails) {
        if (row % 5 == 0) {
            NSTextField *result = [tableView makeViewWithIdentifier:@"grp" owner:self];

            if (result == nil) {
                result = [[NSTextField alloc] initWithFrame:NSZeroRect];
                result.identifier = tableColumn.identifier;
                result.drawsBackground = NO;
                result.bezeled = NO;
                result.font = [NSFont systemFontOfSize:10];
            }
            
            result.objectValue = @"Completed Transfers";
            return result;
        } else {
            NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
            
            if (result == nil) {
                result = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
                result.identifier = tableColumn.identifier;
            }
            
            if ([tableColumn.identifier isEqualToString:@"Event"]) {
                result.textField.stringValue = @"My Test Event";
            } else if ([tableColumn.identifier isEqualToString:@"Status"]) {
                result.textField.stringValue = @"Complete";
            } else if ([tableColumn.identifier isEqualToString:@"Date"]) {
                result.textField.stringValue = @"1/20/2014 14:12";
            }
            
            return result;
        }
    //} else if (tableView == tblFullSize) {
        //NSTableCellView *view = [tableView makeViewWithIdentifier:@"cell" owner:nil];
        
        //return view;
    //}
    
    return nil;
}

-(BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    return row % 5 == 0 ? YES : NO;
}

- (IBAction)previewsAndThumbnailsHelp:(id)sender
{
    NSString *label = @"Previews and thumbnails are used for displaying online and in CORE/Quicpost.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(260, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)fullSizeImagesHelp:(id)sender
{
    NSString *label = @"Full-size images are used to produce prints and products. Orders cannot be processed without full-size images.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(260, 49)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)startWizard:(id)sender
{
    if (wizardWindowController == nil) {
        wizardWindowController = [WizardWindowController new];
    }
    
    [wizardWindowController showWindow:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [tblThumbnails reloadData];
    [tblFullSize reloadData];
}

- (void)windowWillClose:(NSNotification *)notification
{
}

- (BOOL)windowShouldClose:(id)sender
{
    /*NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to quit?"
        defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@""];
    
    NSModalResponse response = [alert runModal];
    return response == NSModalResponseOK ? YES : NO;*/
    return YES;
}

@end
