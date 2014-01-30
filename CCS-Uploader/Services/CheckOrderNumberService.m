#import "CheckOrderNumberService.h"

@interface CheckOrderNumberResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
    NSString *_ccsPassword;
}
@end

@implementation CheckOrderNumberResult
@end

@interface CheckOrderNumberService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    CheckOrderNumberResult *result;
    void (^checkFinished)(CheckOrderNumberResult *result);
}
@end

@implementation CheckOrderNumberService

- (NSString *)serviceURL
{
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/CheckOrderNumber", coreDomain];
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
    
    result = [CheckOrderNumberResult new];
    checkFinished = block;

    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    urlConnection = nil;
    started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        checkFinished(result);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;
    
    result.error = error;
    checkFinished(result);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        result.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        result.processSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"StringData"]) {
        result.ccsPassword = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    result.error = parseError;
    checkFinished(result);
}

@end
