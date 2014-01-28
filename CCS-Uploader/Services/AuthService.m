#import "AuthService.h"

@interface AuthResult () {
    NSError *_error;
    BOOL _success;
    NSString *_accountID;
}
@end

@implementation AuthResult
@end

@interface AuthService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSMutableData *responseData;
    NSMutableString *lastValue;
    AuthResult *authResult;
    BOOL started;
    void (^authFinished)(AuthResult *result);
}
@end

@implementation AuthService

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
    //return @"http://ccstransfer.candid.com/CCSTransferWeb/dev/CCSTransferQuicPost.asmx";
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/AuthenticateUser", coreDomain];
}

- (BOOL)startAuth:(NSString *)email password:(NSString *)password complete:(void (^)(AuthResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:[self serviceURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];

    request.HTTPMethod = @"POST";
    request.HTTPBody = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    
    started = YES;
    authResult = [AuthResult new];
    authFinished = block;
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
    //NSString *stringResponse = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    //NSLog(@"String response:\r%@", stringResponse);
    //[responseData appendData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];

    started = NO;

    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        authFinished(authResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    started = NO;
    authResult.error = error;
    authFinished(authResult);
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
    if ([elementName isEqualToString:@"IntData"]) {
        authResult.accountID = [lastValue copy];
    } else if ([elementName isEqualToString:@"LoginResult"]) {
        if ([lastValue isEqualToString:@"Failure"]) {
            authResult.success = NO;
        } else if ([lastValue isEqualToString:@"Success"]) {
            authResult.success = YES;
        } else {
            authResult.success = NO;
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [lastValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    authResult.error = parseError;
    authFinished(authResult);
}

@end
