#import "VersionService.h"

@implementation VersionResult
@end

@interface VersionService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    VersionResult *result;
}
@end

@implementation VersionService

- (NSString *)serviceURL
{
    return @"http://ccstransfer.candid.com/CCSTransferWeb/services/Version.asmx/GetVersionInfo";
}

- (BOOL)startCheckVersion:(void (^)(VersionResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    NSString *postBody = [NSString stringWithFormat:@"softwareName=%@&softwareCurrentVersion=%@",
        @"CCSUploaderMac",
        [currentVersion stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    result = [VersionResult new];
    finished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    urlConnection = nil, started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        finished(result);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, result.error = error;
    finished(result);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"UpgradeRequired"]) {
        result.upgradeRequired = [lastValue.lowercaseString isEqualToString:@"true"] ? YES : NO;
    } else if ([elementName isEqualToString:@"UpgradeAvailable"]) {
        result.upgradeAvailable = [lastValue.lowercaseString isEqualToString:@"true"] ? YES : NO;
    } else if ([elementName isEqualToString:@"LatestVersion"]) {
        result.latestVersion = [lastValue copy];
    } else if ([elementName isEqualToString:@"LatestNotes"]) {
        result.latestNotes = [lastValue copy];
    } else if ([elementName isEqualToString:@"WebsiteURL"]) {
        result.websiteURL = [lastValue copy];
    } else if ([elementName isEqualToString:@"InstallerURL"]) {
        result.installerURL = [lastValue copy];
    } else if ([elementName isEqualToString:@"ReleaseHistoryURL"]) {
        result.releaseHistoryURL = [lastValue copy];
    } else if ([elementName isEqualToString:@"Error"]) {
        result.errorOccurred = [lastValue.lowercaseString isEqualToString:@"true"] ? YES : NO;
    } else if ([elementName isEqualToString:@"Message"]) {
        result.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    result.error = parseError;
    finished(result);
}

@end
