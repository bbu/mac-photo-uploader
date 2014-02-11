#import "CheckOrderNumberService.h"

@interface CheckOrderNumberResult () {
    BOOL _loginSuccess, _processSuccess;
    NSString *_ccsPassword;
}
@end

@implementation CheckOrderNumberResult
@end

@interface CheckOrderNumberService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    CheckOrderNumberResult *checkOrderNumberResult;
}
@end

@implementation CheckOrderNumberService

- (NSString *)serviceURL
{
    if (effectiveServiceRoot == kServiceRootQuicPost) {
        return kQuicPostServiceRoot @"CheckOrderNumber";
    } else if (effectiveServiceRoot == kServiceRootCore) {
        return [NSString stringWithFormat:kCoreServiceRoot @"CheckOrderNumber", effectiveCoreDomain];
    }
    
    return @"";
}

- (BOOL)startCheckOrderNumber:(NSString *)email password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(CheckOrderNumberResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@&OrderNumber=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    checkOrderNumberResult = [CheckOrderNumberResult new];
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
        finished(checkOrderNumberResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, checkOrderNumberResult.error = error;
    finished(checkOrderNumberResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        checkOrderNumberResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        checkOrderNumberResult.processSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"StringData"]) {
        checkOrderNumberResult.ccsPassword = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    checkOrderNumberResult.error = parseError;
    finished(checkOrderNumberResult);
}

@end
