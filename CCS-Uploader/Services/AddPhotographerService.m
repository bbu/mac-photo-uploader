#import "AddPhotographerService.h"

@interface AddPhotographerResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
}
@end

@implementation AddPhotographerResult
@end

@interface AddPhotographerService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    AddPhotographerResult *addPhotographerResult;
    void (^addFinished)(AddPhotographerResult *result);
}
@end

@implementation AddPhotographerService

- (NSString *)serviceURL
{
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/AddPhotographer", coreDomain];
}

- (BOOL)startAddPhotographer:(NSString *)email password:(NSString *)password account:(NSString *)account
    photographerEmail:(NSString *)photographerEmail photographerName:(NSString *)photographerName
    complete:(void (^)(AddPhotographerResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"Email=%@&Password=%@&Account=%@&PhotographerEmail=%@&PhotographerName=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerEmail stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    addPhotographerResult = [AddPhotographerResult new];
    addFinished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    urlConnection = nil;
    started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        addFinished(addPhotographerResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;

    addPhotographerResult.error = error;
    addFinished(addPhotographerResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        addPhotographerResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        addPhotographerResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    addPhotographerResult.error = parseError;
    addFinished(addPhotographerResult);
}

@end
