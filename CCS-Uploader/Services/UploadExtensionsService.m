#import "UploadExtensionsService.h"

@implementation UploadExtensionsResult
@end

@interface UploadExtensionsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    UploadExtensionsResult *uploadExtensionsResult;
}
@end

@implementation UploadExtensionsService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"getUploadExtensions";
}

- (BOOL)startGetUploadExtensions:(NSString *)account password:(NSString *)password
    complete:(void (^)(UploadExtensionsResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    uploadExtensionsResult = [UploadExtensionsResult new];
    uploadExtensionsResult.extensions = [NSMutableArray new];
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
        finished(uploadExtensionsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, uploadExtensionsResult.error = error;
    finished(uploadExtensionsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        uploadExtensionsResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        uploadExtensionsResult.message = [lastValue copy];
    } else if ([elementName isEqualToString:@"extension"]) {
        [uploadExtensionsResult.extensions addObject:[lastValue copy]];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    uploadExtensionsResult.error = parseError;
    finished(uploadExtensionsResult);
}

@end
