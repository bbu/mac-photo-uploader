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
    AuthResult *authResult;
    void (^authFinished)(AuthResult *result);
}
@end

@implementation AuthService

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
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];

    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    started = YES;
    authResult = [AuthResult new];
    authFinished = block;
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];

    return started;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    //NSString *stringResponse = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    //NSLog(@"String response:\r%@", stringResponse);
    urlConnection = nil;
    started = NO;

    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        authFinished(authResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;
    
    authResult.error = error;
    authFinished(authResult);
}

#pragma mark - NSXMLParserDelegate

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

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    authResult.error = parseError;
    authFinished(authResult);
}

@end
