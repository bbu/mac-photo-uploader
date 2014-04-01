#import "GetChromaKeyEventInformationService.h"

@implementation BackgroundRow
@end

@implementation GetChromaKeyEventInformationResult
@end

@interface GetChromaKeyEventInformationService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    GetChromaKeyEventInformationResult *chromaInfo;
}
@end

@implementation GetChromaKeyEventInformationService

- (NSString *)serviceURL
{
    return kCandidEventServiceRoot @"getChromaKeyEventInformation";
}

- (BOOL)startGetChromaKeyEventInformation:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID complete:(void (^)(GetChromaKeyEventInformationResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"custID=%@&custPassword=%@&eventID=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [eventID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    chromaInfo = [GetChromaKeyEventInformationResult new];
    chromaInfo.backgrounds = [NSMutableArray new];
    finished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *stringResponse = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSLog(@"String response:\r%@", stringResponse);
    
    urlConnection = nil, started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        finished(chromaInfo);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, chromaInfo.error = error;
    finished(chromaInfo);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"Table"]) {
        [chromaInfo.backgrounds addObject:[BackgroundRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if (!chromaInfo.backgrounds.count) {
        return;
    }
    
    BackgroundRow *row = chromaInfo.backgrounds.lastObject;
    
    if ([elementName isEqualToString:@"OrderNo"]) {
        row.orderNo = [lastValue copy];
    } else if ([elementName isEqualToString:@"SourceRoll"]) {
        row.sourceRoll = [lastValue copy];
    } else if ([elementName isEqualToString:@"HorzBackgroundOrderNo"]) {
        row.horzBackgroundOrderNo = [lastValue copy];
    } else if ([elementName isEqualToString:@"HorzBackgroundRoll"]) {
        row.horzBackgroundRoll = [lastValue copy];
    } else if ([elementName isEqualToString:@"HorzBackgroundFrame"]) {
        row.horzBackgroundFrame = [lastValue copy];
    } else if ([elementName isEqualToString:@"HorzBackgroundWidth"]) {
        row.horzBackgroundWidth = lastValue.integerValue;
    } else if ([elementName isEqualToString:@"HorzBackgroundHeight"]) {
        row.horzBackgroundHeight = lastValue.integerValue;
    } else if ([elementName isEqualToString:@"VertBackgroundOrderNo"]) {
        row.vertBackgroundOrderNo = [lastValue copy];
    } else if ([elementName isEqualToString:@"VertBackgroundRoll"]) {
        row.vertBackgroundRoll = [lastValue copy];
    } else if ([elementName isEqualToString:@"VertBackgroundFrame"]) {
        row.vertBackgroundFrame = [lastValue copy];
    } else if ([elementName isEqualToString:@"VertBackgroundWidth"]) {
        row.vertBackgroundWidth = lastValue.integerValue;
    } else if ([elementName isEqualToString:@"VertBackgroundHeight"]) {
        row.vertBackgroundHeight = lastValue.integerValue;
    } else if ([elementName isEqualToString:@"DestinationRoll"]) {
        row.destinationRoll = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    chromaInfo.error = parseError;
    finished(chromaInfo);
}

@end
