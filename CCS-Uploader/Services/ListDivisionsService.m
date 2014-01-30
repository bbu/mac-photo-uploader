#import "ListDivisionsService.h"

@interface DivisionRow () {
NSString *_divisionID;
NSString *_eventID;
NSString *_name;
NSString *_nameOverride;
NSString *_nameWithModID;
NSString *_modCode;
}
@end

@implementation DivisionRow
@end

@interface ListDivisionsResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
    NSMutableArray *_divisions;
}
@end

@implementation ListDivisionsResult
@end

@interface ListDivisionsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ListDivisionsResult *listDivisionsResult;
    void (^listFinished)(ListDivisionsResult *result);
}
@end

@implementation ListDivisionsService

- (NSString *)serviceURL
{
    NSString *coreDomain = @"coredemo.candid.com";
    return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/ListDivisions", coreDomain];
}

- (BOOL)startListDivisions:(NSString *)email password:(NSString *)password eventID:(NSString *)eventID
    complete:(void (^)(ListDivisionsResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@&EventID=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [eventID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];

    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    listDivisionsResult = [ListDivisionsResult new];
    listDivisionsResult.divisions = [NSMutableArray new];
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
        listFinished(listDivisionsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;
    
    listDivisionsResult.error = error;
    listFinished(listDivisionsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"Table1"]) {
        [listDivisionsResult.divisions addObject:[DivisionRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        listDivisionsResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        listDivisionsResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
    
    if (!listDivisionsResult.divisions.count) {
        return;
    }
    
    DivisionRow *row = listDivisionsResult.divisions.lastObject;
    
    if ([elementName isEqualToString:@"DivisionID"]) {
        row.divisionID = [lastValue copy];
    } else if ([elementName isEqualToString:@"EventID"]) {
        row.eventID = [lastValue copy];
    } else if ([elementName isEqualToString:@"Name"]) {
        row.name = [lastValue copy];
    } else if ([elementName isEqualToString:@"NameOverride"]) {
        row.nameOverride = [lastValue copy];
    } else if ([elementName isEqualToString:@"NameWithModID"]) {
        row.nameWithModID = [lastValue copy];
    } else if ([elementName isEqualToString:@"ModCode"]) {
        row.modCode = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    listDivisionsResult.error = parseError;
    listFinished(listDivisionsResult);
}

@end
