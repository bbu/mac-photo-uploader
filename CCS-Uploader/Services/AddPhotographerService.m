#import "AddPhotographerService.h"

@interface AddPhotographerResult () {
    BOOL _loginSuccess, _processSuccess;
}
@end

@implementation AddPhotographerResult
@end

@interface AddPhotographerService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    AddPhotographerResult *addPhotographerResult;
}
@end

@implementation AddPhotographerService

- (NSString *)serviceURL
{
    if (effectiveServiceRoot == kServiceRootQuicPost) {
        return kQuicPostServiceRoot @"AddPhotographer";
    } else if (effectiveServiceRoot == kServiceRootCore) {
        return [NSString stringWithFormat:kCoreServiceRoot @"AddPhotographer", effectiveCoreDomain];
    }
    
    return @"";
}

- (BOOL)startAddPhotographer:(NSString *)email password:(NSString *)password account:(NSString *)account
    photographerEmail:(NSString *)photographerEmail photographerName:(NSString *)photographerName
    complete:(void (^)(AddPhotographerResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"Email=%@&Password=%@&Account=%@&PhotographerEmail=%@&PhotographerName=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerEmail stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    addPhotographerResult = [AddPhotographerResult new];
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
        finished(addPhotographerResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, addPhotographerResult.error = error;
    finished(addPhotographerResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        addPhotographerResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        addPhotographerResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    addPhotographerResult.error = parseError;
    finished(addPhotographerResult);
}

@end
