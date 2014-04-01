#import "GetSingleImageInfoService.h"

@implementation GetSingleImageInfoResult
@end

@interface GetSingleImageInfoService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    GetSingleImageInfoResult *imageInfoResult;
}
@end

@implementation GetSingleImageInfoService

- (NSString *)serviceURL
{
    return @"http://webservices.candid.com/imageinfo/imageinfo.asmx/Get_Single_ImageInfo";
}

- (BOOL)startGetSingleImageInfo:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber roll:(NSString *)roll frame:(NSString *)frame
    complete:(void (^)(GetSingleImageInfoResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"CustID=%@&Password=%@&OrderNo=%@&Roll=%@&Frame=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [frame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    imageInfoResult = [GetSingleImageInfoResult new];
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
        finished(imageInfoResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, imageInfoResult.error = error;
    finished(imageInfoResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"Status"]) {
        imageInfoResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"Message"]) {
        imageInfoResult.message = [lastValue copy];
    } else if ([elementName isEqualToString:@"Width"]) {
        imageInfoResult.width = lastValue.integerValue;
    } else if ([elementName isEqualToString:@"Height"]) {
        imageInfoResult.height = lastValue.integerValue;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    imageInfoResult.error = parseError;
    finished(imageInfoResult);
}

@end
