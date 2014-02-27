#import "ActivateFullSizeService.h"

@implementation ActivateFullSizeResult
@end

@interface ActivateFullSizeService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ActivateFullSizeResult *activateFullSizeResult;
}
@end

@implementation ActivateFullSizeService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"setActivateFullSize";
}

- (BOOL)startActivateFullSize:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(ActivateFullSizeResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@&orderNo=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    activateFullSizeResult = [ActivateFullSizeResult new];
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
        finished(activateFullSizeResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, activateFullSizeResult.error = error;
    finished(activateFullSizeResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        activateFullSizeResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        activateFullSizeResult.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    activateFullSizeResult.error = parseError;
    finished(activateFullSizeResult);
}

@end
