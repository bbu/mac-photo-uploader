#import "AccountViewController.h"

@interface AccountViewController () {
    IBOutlet NSPopUpButton *btnService;
    IBOutlet NSTextField *txtUser;
    IBOutlet NSSecureTextField *txtPass;
    IBOutlet NSTextField *lblCoreDomain, *txtCoreDomain;
    
    NSString *quicPostUser, *quicPostPass;
    NSString *coreUser, *corePass, *coreDomain;
    NSNumber *quicPostSelected;
}

@end

@implementation AccountViewController

- (void)loadView
{
    [super loadView];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    quicPostUser = [defaults objectForKey:@"quicPostUser"];
    quicPostPass = [defaults objectForKey:@"quicPostPass"];
    coreUser = [defaults objectForKey:@"coreUser"];
    corePass = [defaults objectForKey:@"corePass"];
    coreDomain = [defaults objectForKey:@"coreDomain"];
    quicPostSelected = [defaults objectForKey:@"quicPostSelected"];
    
    if (!quicPostUser) {
        quicPostUser = @"";
    }
    
    if (!quicPostPass) {
        quicPostPass = @"";
    }
    
    if (!coreUser) {
        coreUser = @"";
    }
    
    if (!corePass) {
        corePass = @"";
    }
    
    if (!coreDomain) {
        coreDomain = @"";
    }
    
    if (!quicPostSelected) {
        quicPostSelected = [NSNumber numberWithBool:YES];
    } else {
        [btnService selectItemWithTag:quicPostSelected.boolValue ? 0 : 1];
    }
    
    if (btnService.selectedTag == 0) {
        txtUser.stringValue = quicPostUser;
        txtPass.stringValue = quicPostPass;
        txtCoreDomain.stringValue = @"";
        lblCoreDomain.textColor = [NSColor disabledControlTextColor];
        [txtCoreDomain setEnabled:NO];
    } else {
        txtUser.stringValue = coreUser;
        txtPass.stringValue = corePass;
        txtCoreDomain.stringValue = coreDomain;
        lblCoreDomain.textColor = [NSColor textColor];
        [txtCoreDomain setEnabled:YES];
    }
}

- (IBAction)serviceChanged:(id)sender
{
    if (btnService.selectedTag == 0) {
        coreUser = [txtUser.stringValue copy];
        corePass = [txtPass.stringValue copy];
        coreDomain = [txtCoreDomain.stringValue copy];
        
        txtUser.stringValue = quicPostUser;
        txtPass.stringValue = quicPostPass;
        txtCoreDomain.stringValue = @"";
        lblCoreDomain.textColor = [NSColor disabledControlTextColor];
        [txtCoreDomain setEnabled:NO];
    } else {
        quicPostUser = [txtUser.stringValue copy];
        quicPostPass = [txtPass.stringValue copy];
        
        txtUser.stringValue = coreUser;
        txtPass.stringValue = corePass;
        txtCoreDomain.stringValue = coreDomain;
        lblCoreDomain.textColor = [NSColor textColor];
        [txtCoreDomain setEnabled:YES];
    }
}

- (void)saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (btnService.selectedTag == 0) {
        [defaults setObject:txtUser.stringValue forKey:@"quicPostUser"];
        [defaults setObject:txtPass.stringValue forKey:@"quicPostPass"];
        [defaults setObject:coreUser forKey:@"coreUser"];
        [defaults setObject:corePass forKey:@"corePass"];
        [defaults setObject:coreDomain forKey:@"coreDomain"];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:@"quicPostSelected"];
    } else {
        [defaults setObject:quicPostUser forKey:@"quicPostUser"];
        [defaults setObject:quicPostPass forKey:@"quicPostPass"];
        [defaults setObject:txtUser.stringValue forKey:@"coreUser"];
        [defaults setObject:txtPass.stringValue forKey:@"corePass"];
        [defaults setObject:txtCoreDomain.stringValue forKey:@"coreDomain"];
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:@"quicPostSelected"];
    }
}

@end
