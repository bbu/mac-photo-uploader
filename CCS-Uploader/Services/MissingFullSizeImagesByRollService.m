#import "MissingFullSizeImagesByRollService.h"

@implementation MissingFullSizeImageRow
@end

@implementation MissingFullSizeImagesByRollResult
@end

@interface MissingFullSizeImagesByRollService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    MissingFullSizeImagesByRollResult *listImagesResult;
}
@end

@implementation MissingFullSizeImagesByRollService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"MissingFullSizeImagesByRoll";
}

- (BOOL)startListImages:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll complete:(void (^)(MissingFullSizeImagesByRollResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"acctNo=%@&password=%@&orderNo=%@&roll=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    listImagesResult = [MissingFullSizeImagesByRollResult new];
    listImagesResult.missingImages = [NSMutableArray new];
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
        finished(listImagesResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, listImagesResult.error = error;
    finished(listImagesResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"MissingFullSizeImagesByRoll"]) {
        [listImagesResult.missingImages addObject:[MissingFullSizeImageRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        listImagesResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        listImagesResult.message = [lastValue copy];
    }
    
    if (!listImagesResult.missingImages.count) {
        return;
    }
    
    MissingFullSizeImageRow *row = listImagesResult.missingImages.lastObject;
    
    if ([elementName isEqualToString:@"orderno"]) {
        row.orderNumber = [lastValue copy];
    } else if ([elementName isEqualToString:@"roll"]) {
        row.roll = [lastValue copy];
    } else if ([elementName isEqualToString:@"frame"]) {
        row.frame = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    listImagesResult.error = parseError;
    finished(listImagesResult);
}

@end
