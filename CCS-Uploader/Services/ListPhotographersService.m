#import "ListPhotographersService.h"

@interface PhotographerRow () {
    NSString *_ccsPhotographerID;
    NSString *_name;
    NSString *_email;
    NSString *_password;
}
@end

@implementation PhotographerRow
@end

@interface ListPhotographersResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
    NSMutableArray *_photographers;
}
@end

@implementation ListPhotographersResult
@end

@interface ListPhotographersService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ListPhotographersResult *listPhotographersResult;
    void (^listFinished)(ListPhotographersResult *result);
}
@end

@implementation ListPhotographersService

- (NSString *)serviceURL
{
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/ListPhotographers", coreDomain];
}

- (BOOL)startListPhotographers:(NSString *)account email:(NSString *)email password:(NSString *)password
    complete:(void (^)(ListPhotographersResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"Account=%@&Email=%@&Password=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    listPhotographersResult = [ListPhotographersResult new];
    listPhotographersResult.photographers = [NSMutableArray new];
    listFinished = block;

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
        listFinished(listPhotographersResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;
    
    listPhotographersResult.error = error;
    listFinished(listPhotographersResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"Table"]) {
        [listPhotographersResult.photographers addObject:[PhotographerRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        listPhotographersResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        listPhotographersResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
    
    if (!listPhotographersResult.photographers.count) {
        return;
    }

    PhotographerRow *row = listPhotographersResult.photographers.lastObject;
    
    if ([elementName isEqualToString:@"CCSPhotographerID"]) {
        row.ccsPhotographerID = [lastValue copy];
    } else if ([elementName isEqualToString:@"Name"]) {
        row.name = [lastValue copy];
    } else if ([elementName isEqualToString:@"Email"]) {
        row.email = [lastValue copy];
    } else if ([elementName isEqualToString:@"Password"]) {
        row.password = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    listPhotographersResult.error = parseError;
    listFinished(listPhotographersResult);
}

@end
