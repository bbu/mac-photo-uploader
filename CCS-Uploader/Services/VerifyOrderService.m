#import "VerifyOrderService.h"

@implementation VerifyOrderResult
@end

@interface VerifyOrderService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    VerifyOrderResult *verifyOrderResult;
}
@end

@implementation VerifyOrderService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"verifyOrder";
}

- (BOOL)startVerifyOrder:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
    version:(NSString *)version bypassPassword:(BOOL)bypassPassword
    complete:(void (^)(VerifyOrderResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@&orderNo=%@&version=%@&bypassPassword=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        version,
        bypassPassword ? @"1" : @"0"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    verifyOrderResult = [VerifyOrderResult new];
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
        finished(verifyOrderResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, verifyOrderResult.error = error;
    finished(verifyOrderResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        verifyOrderResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        verifyOrderResult.message = [lastValue copy];
    } else if ([elementName isEqualToString:@"RemoteHost"]) {
        verifyOrderResult.remoteHost = [lastValue copy];
    } else if ([elementName isEqualToString:@"RemoteDirectory"]) {
        verifyOrderResult.remoteDirectory = [lastValue copy];
    } else if ([elementName isEqualToString:@"UserName"]) {
        verifyOrderResult.username = [lastValue copy];
    } else if ([elementName isEqualToString:@"Password"]) {
        verifyOrderResult.password = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    verifyOrderResult.error = parseError;
    finished(verifyOrderResult);
}

@end
