#import "LoginViewController.h"
#import "../Prefs/AdvancedViewController.h"

#import "../../Services/AuthService.h"
#import "../../Services/ListEventsService.h"
#import "../../Services/ListPhotographersService.h"
#import "../../Services/AddPhotographerService.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (id)init
{
    self = [super initWithNibName:@"LoginView" bundle:nil];

    if (self) {
    }
    
    return self;
}

- (IBAction)eventNumberHelp:(id)sender
{
    NSString *label = @"If left empty, you will be prompted to select an event from a list.";
    NSPopover *popover = [AdvancedViewController popoverWithLabel:label size:NSMakeSize(220, 34)];
    [popover showRelativeToRect:[sender superview].bounds ofView:sender preferredEdge:NSMaxXEdge];
    
    /*
    AuthService *a = [AuthService new];
    [a startAuth:@"ccsmacuploader" password:@"candid123" complete:^(AuthResult *result) {
        if (result.error != nil) {
            NSLog(@"Auth error: %@", result.error.localizedDescription);
        } else {
            if (result.success) {
                NSLog(@"Logged in successfully: %@.", result.accountID);
            } else {
                NSLog(@"Wrong username/password.");
            }
        }
    }];
    */
    
    /*
    ListEventsService *l = [ListEventsService new];
    [l startListEvents:@"ccsmacuploader" password:@"candid123" filterDateRange:YES
        startDate:[NSDate dateWithNaturalLanguageString:@"1/1/2014"]
        endDate:[NSDate dateWithNaturalLanguageString:@"1/1/2015"]
        hideNullDates:YES hideActive:YES hideNonAssigned:YES hideNullOrderNumbers:YES
        complete:^(ListEventsResult *result) {
            if (result.error) {
                NSLog(@"List events error: %@", result.error.localizedDescription);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    NSLog(@"List events success: %lu events", result.events.count);
                } else {
                    NSLog(@"Service call failed.");
                }
            }
        }
    ];
    */
    
    /*
    [l startListEvent:@"ccsmacuploader" password:@"candid123" orderNumber:@"26709284"
        complete:^(ListEventsResult *result) {
            if (result.error) {
                NSLog(@"List event error: %@", result.error.localizedDescription);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    NSLog(@"List event success: %lu events", result.events.count);
                } else if (result.loginSuccess) {
                    NSLog(@"Event not found.");
                } else {
                    NSLog(@"Login failed.");
                }
            }
        }
    ];
    */
    
    /*
    ListPhotographersService *p = [ListPhotographersService new];
    [p startListPhotographers:@"11420" email:@"ccsmacuploader" password:@"candid123"
        complete:^(ListPhotographersResult *result) {
            if (result.error) {
                NSLog(@"List event error: %@", result.error.localizedDescription);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    NSLog(@"List photographers success: %lu photographers", result.photographers.count);
                } else {
                    NSLog(@"Service call failed.");
                }
            }
        }
    ];
    */
    
    /*
    AddPhotographerService *ap = [AddPhotographerService new];
    [ap startAddPhotographer:@"ccsmacuploader" password:@"candid123" account:@"11420" photographerEmail:@"A mail" photographerName:@"A name"
        complete:^(AddPhotographerResult *result) {
            if (result.error) {
                NSLog(@"Add photographer error: %@", result.error.localizedDescription);
            } else {
                if (result.loginSuccess && result.processSuccess) {
                    NSLog(@"Add photographer success.");
                } else {
                    NSLog(@"Service call failed.");
                }
            }
        }
    ];
    */
}

@end
