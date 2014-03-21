#import "ImageUploadViewController.h"

@interface ImageUploadViewController () {
    IBOutlet NSPopUpButton *btnSimultaneousThumbUploads;
    
    IBOutlet NSTextField *txtRetryDelay, *txtNumRetries;
    IBOutlet NSTextField *txtConnectionTimeout;
    IBOutlet NSPopUpButton *btnSimultaneousFullSizeUploads;

    IBOutlet NSButton *chkUseProxy;
    IBOutlet NSTextField *txtProxyHost, *txtProxyUser, *txtProxyPass, *txtProxyPort;
    IBOutlet NSPopUpButton *btnProxyType;
}
@end

@implementation ImageUploadViewController

- (void)loadView
{
    [super loadView];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSNumber *simultaneousThumbUploads = [defaults objectForKey:kSimultaneousThumbUploads];
    
    NSNumber *retryDelay = [defaults objectForKey:kRetryDelay];
    NSNumber *numRetries = [defaults objectForKey:kNumRetries];
    NSNumber *connectionTimeout = [defaults objectForKey:kConnectionTimeout];
    NSNumber *simultaneousFullSizeUploads = [defaults objectForKey:kSimultaneousFullSizeUploads];
    
    NSNumber *useProxy = [defaults objectForKey:kUseProxy];
    NSString *proxyHost = [defaults objectForKey:kProxyHost];
    NSString *proxyUser = [defaults objectForKey:kProxyUser];
    NSString *proxyPass = [defaults objectForKey:kProxyPass];
    NSNumber *proxyPort = [defaults objectForKey:kProxyPort];
    NSString *proxyType = [defaults objectForKey:kProxyType];
    
    [btnSimultaneousThumbUploads
        selectItemAtIndex:simultaneousThumbUploads ? simultaneousThumbUploads.integerValue - 1 : 0];

    txtRetryDelay.integerValue = retryDelay ? retryDelay.integerValue : kDefaultRetryDelay;
    txtNumRetries.integerValue = numRetries ? numRetries.integerValue : kDefaultNumRetries;
    txtConnectionTimeout.integerValue = connectionTimeout ? connectionTimeout.integerValue : kDefaultConnectionTimeout;
    
    [btnSimultaneousFullSizeUploads
        selectItemAtIndex:simultaneousFullSizeUploads ? simultaneousFullSizeUploads.integerValue - 1 : 0];

    chkUseProxy.state = useProxy ? (useProxy.boolValue ? NSOnState : NSOffState) : NSOffState;
    [self useProxyClicked:nil];
    
    txtProxyHost.stringValue = proxyHost ? [proxyHost copy] : @"";
    txtProxyUser.stringValue = proxyUser ? [proxyUser copy] : @"";
    txtProxyPass.stringValue = proxyPass ? [proxyPass copy] : @"";
    txtProxyPort.integerValue = proxyPort ? proxyPort.integerValue : 0;
    
    if (proxyType) {
        [btnProxyType selectItemWithTitle:proxyType];
    } else {
        [btnProxyType selectItemAtIndex:0];
    }
}

- (IBAction)useProxyClicked:(id)sender
{
    BOOL enabled = (chkUseProxy.state == NSOnState) ? YES : NO;
    
    for (NSControl *control in @[txtProxyHost, txtProxyUser, txtProxyPass, txtProxyPort, btnProxyType]) {
        [control setEnabled:enabled];
    }
}

- (void)saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setObject:
        [NSNumber numberWithInteger:btnSimultaneousThumbUploads.selectedItem.title.integerValue]
        forKey:kSimultaneousThumbUploads];
    
    [defaults setObject:[NSNumber numberWithInteger:txtRetryDelay.integerValue] forKey:kRetryDelay];
    [defaults setObject:[NSNumber numberWithInteger:txtNumRetries.integerValue] forKey:kNumRetries];
    [defaults setObject:[NSNumber numberWithInteger:txtConnectionTimeout.integerValue] forKey:kConnectionTimeout];

    [defaults setObject:
        [NSNumber numberWithInteger:btnSimultaneousFullSizeUploads.selectedItem.title.integerValue]
        forKey:kSimultaneousFullSizeUploads];
    
    [defaults setObject:[NSNumber numberWithBool:chkUseProxy.state == NSOnState ? YES : NO] forKey:kUseProxy];
    [defaults setObject:txtProxyHost.stringValue forKey:kProxyHost];
    [defaults setObject:txtProxyUser.stringValue forKey:kProxyUser];
    [defaults setObject:txtProxyPass.stringValue forKey:kProxyPass];
    [defaults setObject:txtProxyPort.stringValue forKey:kProxyPort];
    [defaults setObject:btnProxyType.selectedItem.title forKey:kProxyType];
}

@end
