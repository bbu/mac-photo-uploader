#import "ReviewViewController.h"

#import "../WizardWindowController.h"
#import "../../Models/OrderModel.h"

@interface ReviewViewController () <NSTableViewDataSource, NSTableViewDelegate> {
    WizardWindowController *wizardWindowController;
    IBOutlet NSTableView *tblReview;
}

@end

@implementation ReviewViewController

- (id)initWithWizardController:(WizardWindowController *)parent
{
    self = [super initWithNibName:@"ReviewView" bundle:nil];
    
    if (self) {
        wizardWindowController = parent;
    }
    
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    return orderModel.rolls.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnID = tableColumn.identifier;
    NSTableCellView *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    OrderModel *orderModel = wizardWindowController.browseViewController.orderModel;
    RollModel *roll = orderModel.rolls[row];
    
    if ([columnID isEqualToString:@"Roll"]) {
        view.imageView.image = [NSImage imageNamed:roll.framesHaveErrors ? @"NSCaution" : @"NSFolder"];
        view.textField.stringValue = roll.number;
    } else if ([columnID isEqualToString:@"CameraRotations"]) {
        BOOL cameraRotations = NO;
        
        for (FrameModel *frame in roll.frames) {
            if (frame.orientation > 1) {
                cameraRotations = YES;
                break;
            }
        }
        
        view.imageView.image = [NSImage imageNamed:cameraRotations ? @"NSMenuOnStateTemplate" : @"NSStopProgressTemplate"];
    } else if ([columnID isEqualToString:@"UserRotations"]) {
        BOOL userRotations = NO;
        
        for (FrameModel *frame in roll.frames) {
            if (frame.userDidRotate) {
                userRotations = YES;
                break;
            }
        }
        
        view.imageView.image = [NSImage imageNamed:userRotations ? @"NSMenuOnStateTemplate" : @"NSStopProgressTemplate"];
    } else if ([columnID isEqualToString:@"ImagesAutoRenamed"]) {
        view.imageView.image = [NSImage imageNamed:roll.imagesAutoRenamed ? @"NSMenuOnStateTemplate" : @"NSStopProgressTemplate"];
    } else if ([columnID isEqualToString:@"ImagesViewed"]) {
        view.imageView.image = [NSImage imageNamed:roll.imagesViewed ? @"NSMenuOnStateTemplate" : @"NSStopProgressTemplate"];
    }
    
    return view;
}

- (void)reload
{
    [tblReview reloadData];
}

@end
