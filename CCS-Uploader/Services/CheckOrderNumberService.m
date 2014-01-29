#import "CheckOrderNumberService.h"

@interface CheckOrderNumberResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
    NSString *_ccsPassword;
}
@end

@implementation CheckOrderNumberResult
@end

@interface CheckOrderNumberService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSMutableData *responseData;
    NSMutableString *lastValue;
    CheckOrderNumberResult *result;
    BOOL started;
    void (^checkFinished)(CheckOrderNumberResult *result);
}
@end

@implementation CheckOrderNumberService

- (id)init
{
    self = [super init];
    
    if (self) {
        responseData = [NSMutableData new];
        lastValue = [NSMutableString new];
    }
    
    return self;
}

- (NSString *)serviceURL
{
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/CheckOrderNumber", coreDomain];
}

- (BOOL)startCheckOrderNumber:(NSString *)email password:(NSString *)password orderNumber:(NSString *)orderNumber
    complete:(void (^)(CheckOrderNumberResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:[self serviceURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@&OrderNumber=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    
    started = YES;
    result = [CheckOrderNumberResult new];
    checkFinished = block;
    [NSURLConnection connectionWithRequest:request delegate:self];
    
    return started;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        checkFinished(result);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    started = NO;
    result.error = error;
    checkFinished(result);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        result.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        result.processSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"StringData"]) {
        result.ccsPassword = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [lastValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    result.error = parseError;
    checkFinished(result);
}

@end
