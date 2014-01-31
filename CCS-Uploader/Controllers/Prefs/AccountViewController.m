#import "AccountViewController.h"

@interface AccountViewController () {
    IBOutlet NSPopUpButton *btnService;
    IBOutlet NSTextField *txtUser;
    IBOutlet NSSecureTextField *txtPass;
    IBOutlet NSTextField *lblCoreDomain, *txtCoreDomain;
}

@end

@implementation AccountViewController

- (void)reloadAccounts
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *quicPostUser = [defaults objectForKey:kQuicPostUser];
    NSString *quicPostPass = [defaults objectForKey:kQuicPostPass];
    NSString *coreUser = [defaults objectForKey:kCoreUser];
    NSString *corePass = [defaults objectForKey:kCorePass];
    NSString *coreDomain = [defaults objectForKey:kCoreDomain];
    NSNumber *quicPostSelected = [defaults objectForKey:kQuicPostSelected];
    
    if (!quicPostSelected) {
        quicPostSelected = [NSNumber numberWithBool:YES];
    } else {
        [btnService selectItemWithTag:quicPostSelected.boolValue ? 0 : 1];
    }
    
    if (btnService.selectedTag == 0) {
        txtUser.stringValue = quicPostUser ? [quicPostUser copy] : @"";
        txtPass.stringValue = quicPostPass ? [quicPostPass copy] : @"";
        txtCoreDomain.stringValue = @"";
        lblCoreDomain.textColor = [NSColor disabledControlTextColor];
        [txtCoreDomain setEnabled:NO];
    } else {
        txtUser.stringValue = coreUser ? [coreUser copy] : @"";
        txtPass.stringValue = corePass ? [corePass copy] : @"";
        txtCoreDomain.stringValue = coreDomain ? [coreDomain copy] : @"";
        lblCoreDomain.textColor = [NSColor textColor];
        [txtCoreDomain setEnabled:YES];
    }
}

- (void)loadView
{
    [super loadView];
    [self reloadAccounts];
}

- (IBAction)saveClicked:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (btnService.selectedTag == 0) {
        [defaults setObject:txtUser.stringValue forKey:kQuicPostUser];
        [defaults setObject:txtPass.stringValue forKey:kQuicPostPass];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:kQuicPostSelected];
    } else {
        [defaults setObject:txtUser.stringValue forKey:kCoreUser];
        [defaults setObject:txtPass.stringValue forKey:kCorePass];
        [defaults setObject:txtCoreDomain.stringValue forKey:kCoreDomain];
        [defaults setObject:[NSNumber numberWithBool:NO] forKey:kQuicPostSelected];
    }
    
    [defaults synchronize];
}

- (IBAction)serviceChanged:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storedValue;
    
    if (btnService.selectedTag == 0) {
        storedValue = [defaults objectForKey:kQuicPostUser];
        txtUser.stringValue = storedValue ? [storedValue copy] : @"";
        storedValue = [defaults objectForKey:kQuicPostPass];
        txtPass.stringValue = storedValue ? [storedValue copy] : @"";
        txtCoreDomain.stringValue = @"";
        lblCoreDomain.textColor = [NSColor disabledControlTextColor];
        [txtCoreDomain setEnabled:NO];
    } else {
        storedValue = [defaults objectForKey:kCoreUser];
        txtUser.stringValue = storedValue ? [storedValue copy] : @"";
        storedValue = [defaults objectForKey:kCorePass];
        txtPass.stringValue = storedValue ? [storedValue copy] : @"";
        storedValue = [defaults objectForKey:kCoreDomain];
        txtCoreDomain.stringValue = storedValue ? [storedValue copy] : @"";
        lblCoreDomain.textColor = [NSColor textColor];
        [txtCoreDomain setEnabled:YES];
    }
}

- (void)saveState
{
}

@end
