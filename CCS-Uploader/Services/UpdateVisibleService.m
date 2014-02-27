#import "UpdateVisibleService.h"

@implementation UpdateVisibleResult
@end

@interface UpdateVisibleService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    UpdateVisibleResult *updateVisibleResult;
}
@end

@implementation UpdateVisibleService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"updateVisible2";
}

- (BOOL)startUpdateVisible:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    roll:(NSString *)roll frame:(NSString *)frame
    visible:(BOOL)visible fullsizeMustNotExist:(BOOL)fullsizeMustNotExist
    complete:(void (^)(UpdateVisibleResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@&orderNo=%@&roll=%@&frame=%@&visible=%@&fullsizeMustNotExist=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [frame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        visible ? @"true" : @"false",
        fullsizeMustNotExist ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    updateVisibleResult = [UpdateVisibleResult new];
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
        finished(updateVisibleResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, updateVisibleResult.error = error;
    finished(updateVisibleResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        updateVisibleResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        updateVisibleResult.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    updateVisibleResult.error = parseError;
    finished(updateVisibleResult);
}

@end
