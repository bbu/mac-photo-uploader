#import "FullSizeImageDimensionsByRollService.h"

@interface FullSizeImageDimensionRow () {
    NSString *_orderNumber;
    NSString *_roll;
    NSString *_frame;
    NSUInteger _filesize;
    NSInteger _length;
    NSInteger _width;
    BOOL _pngImage;
}
@end

@implementation FullSizeImageDimensionRow
@end

@interface FullSizeImageDimensionsByRollResult () {
    NSString *_status, *_message;
    NSMutableArray *_dimensions;
}
@end

@implementation FullSizeImageDimensionsByRollResult
@end

@interface FullSizeImageDimensionsByRollService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    FullSizeImageDimensionsByRollResult *listDimensionsResult;
}
@end

@implementation FullSizeImageDimensionsByRollService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"FullSizeImageDimensionsByRoll";
}

- (BOOL)startListDimensions:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll complete:(void (^)(FullSizeImageDimensionsByRollResult *result))block
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
    
    listDimensionsResult = [FullSizeImageDimensionsByRollResult new];
    listDimensionsResult.dimensions = [NSMutableArray new];
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
        finished(listDimensionsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, listDimensionsResult.error = error;
    finished(listDimensionsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"FullSizeImageDimensionsByRoll"]) {
        [listDimensionsResult.dimensions addObject:[FullSizeImageDimensionRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        listDimensionsResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        listDimensionsResult.message = [lastValue copy];
    }
    
    if (!listDimensionsResult.dimensions.count) {
        return;
    }
    
    FullSizeImageDimensionRow *row = listDimensionsResult.dimensions.lastObject;
    
    if ([elementName isEqualToString:@"orderno"]) {
        row.orderNumber = [lastValue copy];
    } else if ([elementName isEqualToString:@"roll"]) {
        row.roll = [lastValue copy];
    } else if ([elementName isEqualToString:@"frame"]) {
        row.frame = [lastValue copy];
    } else if ([elementName isEqualToString:@"filesize"]) {
        row.filesize = [numberFormatter numberFromString:lastValue].unsignedIntegerValue;
    } else if ([elementName isEqualToString:@"length"]) {
        row.length = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"width"]) {
        row.width = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"PNGImage"]) {
        row.pngImage = [lastValue caseInsensitiveCompare:@"true"] == NSOrderedSame ? YES : NO;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    listDimensionsResult.error = parseError;
    finished(listDimensionsResult);
}

@end
