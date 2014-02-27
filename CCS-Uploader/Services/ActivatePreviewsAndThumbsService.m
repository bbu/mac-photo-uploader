#import "ActivatePreviewsAndThumbsService.h"

@implementation ActivatePreviewsAndThumbsResult
@end

@interface ActivatePreviewsAndThumbsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ActivatePreviewsAndThumbsResult *activatePreviewsAndThumbsResult;
}
@end

@implementation ActivatePreviewsAndThumbsService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"setActivatePreviewsandThumbs";
}

- (BOOL)startActivatePreviewsAndThumbs:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(ActivatePreviewsAndThumbsResult *result))block
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
    
    activatePreviewsAndThumbsResult = [ActivatePreviewsAndThumbsResult new];
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
        finished(activatePreviewsAndThumbsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, activatePreviewsAndThumbsResult.error = error;
    finished(activatePreviewsAndThumbsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        activatePreviewsAndThumbsResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        activatePreviewsAndThumbsResult.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    activatePreviewsAndThumbsResult.error = parseError;
    finished(activatePreviewsAndThumbsResult);
}

@end
