#import "RollHasImagesService.h"

@implementation RollHasImagesResult
@end

@interface RollHasImagesService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    RollHasImagesResult *rollHasImagesResult;
}
@end

@implementation RollHasImagesService

- (NSString *)serviceURL
{
    return kCandidEventServiceRoot @"RollHasImages";
}

- (BOOL)startRollHasImages:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll
    complete:(void (^)(RollHasImagesResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"custID=%@&custPassword=%@&orderNo=%@&roll=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    rollHasImagesResult = [RollHasImagesResult new];
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
        finished(rollHasImagesResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, rollHasImagesResult.error = error;
    finished(rollHasImagesResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"boolean"]) {
        rollHasImagesResult.hasImages = [lastValue.lowercaseString isEqualToString:@"true"] ? YES : NO;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    rollHasImagesResult.error = parseError;
    finished(rollHasImagesResult);
}

@end
