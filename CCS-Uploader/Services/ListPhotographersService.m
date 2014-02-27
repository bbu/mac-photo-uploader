#import "ListPhotographersService.h"

@implementation PhotographerRow
@end

@implementation ListPhotographersResult
@end

@interface ListPhotographersService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ListPhotographersResult *listPhotographersResult;
}
@end

@implementation ListPhotographersService

- (NSString *)serviceURL
{
    if (effectiveServiceRoot == kServiceRootQuicPost) {
        return kQuicPostServiceRoot @"ListPhotographers";
    } else if (effectiveServiceRoot == kServiceRootCore) {
        return [NSString stringWithFormat:kCoreServiceRoot @"ListPhotographers", effectiveCoreDomain];
    }
    
    return @"";
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
        finished(listPhotographersResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, listPhotographersResult.error = error;
    finished(listPhotographersResult);
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
    finished(listPhotographersResult);
}

@end
