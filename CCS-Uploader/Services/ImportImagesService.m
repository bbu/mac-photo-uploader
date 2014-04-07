#import "ImportImagesService.h"

@implementation ImportImagesResult
@end

@interface ImportImagesService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ImportImagesResult *result;
}
@end

@implementation ImportImagesService

- (NSString *)serviceURL
{
    if (effectiveServiceRoot == kServiceRootQuicPost) {
        return @"http://quicpost.candid.com/CORE/XML/General.asmx/ImportImages2";
    } else if (effectiveServiceRoot == kServiceRootCore) {
        return [NSString stringWithFormat:@"%@/XML/General.asmx/ImportImages2", effectiveCoreDomain];
    }
    
    return @"";
}

- (BOOL)startImportImages:(NSString *)username password:(NSString *)password
    orderNumber:(NSString *)orderNumber
    eventID:(NSString *)eventID
    spotImagesToRollDivision:(BOOL)spotImagesToRollDivision
    complete:(void (^)(ImportImagesResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"Username=%@&Password=%@&OrderNumber=%@&EventID=%@&SpotImagesToRollDivision=%@",
        [username stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [eventID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        spotImagesToRollDivision ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    result = [ImportImagesResult new];
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
    if ([elementName isEqualToString:@"Status"]) {
        result.status = lastValue.integerValue;
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
