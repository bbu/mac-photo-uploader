#import "SendFeedbackService.h"
#import "../Utils/Base64.h"

@interface SendFeedbackService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ServiceResult *result;
}
@end

@implementation SendFeedbackService

- (NSString *)serviceURL
{
    return @"http://ccstransfer.candid.com/CCSTransferWeb/dev/Feedback.asmx/SendFeedback";
}

- (NSString *)escapedBase64:(NSString *)base64
{
    return [[base64
        stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"]
        stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
}

- (BOOL)startSendFeedback:(NSString *)version
    credentials:(NSString *)credentials
    ccsAccount:(NSString *)ccsAccount
    orderNumber:(NSString *)orderNumber
    system:(NSString *)system
    program:(NSString *)program
    description:(NSString *)description
    type:(NSString *)type
    name:(NSString *)name
    email:(NSString *)email
    files:(NSData *)files
    complete:(void (^)(ServiceResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"version=%@&Credentials=%@&ccsaccount=%@&ordernumber=%@&"
        @"system=%@&program=%@&description=%@&type=%@&"
        @"name=%@&returnemail=%@&files=%@",
        
        [version stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [credentials stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [ccsAccount stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          
        [system stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [program stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [type stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],

        [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        files ? [self escapedBase64:files.base64EncodedString] : @""
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    result = [ServiceResult new];
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
    finished(result);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, result.error = error;
    finished(result);
}

@end
