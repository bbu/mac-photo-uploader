#import "FullSizePostedService.h"

@interface FullSizePostedResult () {
    NSString *_status, *_message;
}
@end

@implementation FullSizePostedResult
@end

@interface FullSizePostedService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    FullSizePostedResult *fullSizePostedResult;
}
@end

@implementation FullSizePostedService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"fullsizePosted2";
}

- (BOOL)startFullSizePosted:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    roll:(NSString *)roll frame:(NSString *)frame filename:(NSString *)filename
    version:(NSString *)version bypassPassword:(BOOL)bypassPassword createPreviewAndThumb:(BOOL)createPreviewAndThumb
    complete:(void (^)(FullSizePostedResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@&orderNo=%@&roll=%@&frame=%@&fileName=%@&version=%@&bypassPassword=%@&createPreviewandThumb=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [frame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [version stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        bypassPassword ? @"1" : @"0",
        createPreviewAndThumb ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    fullSizePostedResult = [FullSizePostedResult new];
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
        finished(fullSizePostedResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, fullSizePostedResult.error = error;
    finished(fullSizePostedResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        fullSizePostedResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        fullSizePostedResult.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    fullSizePostedResult.error = parseError;
    finished(fullSizePostedResult);
}

@end
