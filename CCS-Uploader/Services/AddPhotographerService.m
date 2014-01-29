#import "AddPhotographerService.h"

@interface AddPhotographerResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
}
@end

@implementation AddPhotographerResult
@end

@interface AddPhotographerService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSMutableData *responseData;
    NSMutableString *lastValue;
    AddPhotographerResult *addPhotographerResult;
    BOOL started;
    void (^addFinished)(AddPhotographerResult *result);
}
@end

@implementation AddPhotographerService

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
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/AddPhotographer", coreDomain];
}

- (BOOL)startAddPhotographer:(NSString *)email password:(NSString *)password account:(NSString *)account
    photographerEmail:(NSString *)photographerEmail photographerName:(NSString *)photographerName
    complete:(void (^)(AddPhotographerResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:[self serviceURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSString *postBody = [NSString stringWithFormat:
        @"Email=%@&Password=%@&Account=%@&PhotographerEmail=%@&PhotographerName=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerEmail stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [photographerName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    
    started = YES;
    addPhotographerResult = [AddPhotographerResult new];
    addFinished = block;
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
        addFinished(addPhotographerResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    started = NO;
    addPhotographerResult.error = error;
    addFinished(addPhotographerResult);
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
        addPhotographerResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        addPhotographerResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [lastValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    addPhotographerResult.error = parseError;
    addFinished(addPhotographerResult);
}

@end
