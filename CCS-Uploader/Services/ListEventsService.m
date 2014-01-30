#import "ListEventsService.h"

@interface EventRow () {
    NSString *_eventID;
    NSString *_eventName;
    NSString *_orderNumber;
    NSString *_ccsAccount;
    NSDate *_eventDate;
    NSString *_marketID;
    NSString *_market;
    NSString *_location;
    NSString *_hostGroup;
    BOOL _isQuicPost;
    BOOL _autoCategorizeImages;
}
@end

@implementation EventRow
@end

@interface ListEventsResult () {
    NSError *_error;
    BOOL _loginSuccess, _processSuccess;
    NSMutableArray *_events;
}
@end

@implementation ListEventsResult
@end

@interface ListEventsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSDateFormatter *dateFormatter;
    ListEventsResult *listEventsResult;
    void (^listFinished)(ListEventsResult *result);
}
@end

@implementation ListEventsService

- (id)init
{
    self = [super init];
    
    if (self) {
        dateFormatter = [NSDateFormatter new];
        dateFormatter.dateFormat = @"MM/dd/Y";
    }
    
    return self;
}

- (NSString *)serviceURL:(BOOL)multipleEvents
{
    NSString *coreDomain = @"coredemo.candid.com";
    
    if (multipleEvents) {
        return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/ListEvents2", coreDomain];
    } else {
        return [NSString stringWithFormat:@"http://%@/core/xml/CORECCSTransfer2.asmx/ListEvent", coreDomain];
    }
}

- (BOOL)startListEvents:(NSString *)email password:(NSString *)password
    filterDateRange:(BOOL)filterDateRange
    startDate:(NSDate *)startDate
    endDate:(NSDate *)endDate
    hideNullDates:(BOOL)hideNullDates
    hideActive:(BOOL)hideActive
    hideNonAssigned:(BOOL)hideNonAssigned
    hideNullOrderNumbers:(BOOL)hideNullOrderNumbers
    complete:(void (^)(ListEventsResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"Email=%@&Password=%@&FilterDateRange=%@&StartDate=%@&EndDate=%@&"
        @"HideNullDates=%@&HideActive=%@&HideNonAssigned=%@&HideNullOrderNumbers=%@",
        
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        filterDateRange ? @"true" : @"false",
        startDate ? [[dateFormatter stringFromDate:startDate] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : @"",
        endDate ? [[dateFormatter stringFromDate:endDate] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : @"",
        hideNullDates ? @"true" : @"false",
        hideActive ? @"true" : @"false",
        hideNonAssigned ? @"true" : @"false",
        hideNullOrderNumbers ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL:YES] body:postBody];
    
    listEventsResult = [ListEventsResult new];
    listEventsResult.events = [NSMutableArray new];
    listFinished = block;

    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

- (BOOL)startListEvent:(NSString *)email password:(NSString *)password
    orderNumber:(NSString *)orderNumber
    complete:(void (^)(ListEventsResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"Email=%@&Password=%@&OrderNumber=%@",
        [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL:NO] body:postBody];
    
    listEventsResult = [ListEventsResult new];
    listEventsResult.events = [NSMutableArray new];
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
        listFinished(listEventsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil;
    started = NO;

    listEventsResult.error = error;
    listFinished(listEventsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"Table"]) {
        [listEventsResult.events addObject:[EventRow new]];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
    namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"LoginResult"]) {
        listEventsResult.loginSuccess = [lastValue isEqualToString:@"Success"];
    } else if ([elementName isEqualToString:@"ProcessResult"]) {
        listEventsResult.processSuccess = [lastValue isEqualToString:@"Success"];
    }
    
    if (!listEventsResult.events.count) {
        return;
    }
    
    EventRow *row = listEventsResult.events.lastObject;
    
    if ([elementName isEqualToString:@"EventID"]) {
        row.eventID = [lastValue copy];
    } else if ([elementName isEqualToString:@"EventName"]) {
        row.eventName = [lastValue copy];
    } else if ([elementName isEqualToString:@"OrderNumber"]) {
        row.orderNumber = [lastValue copy];
    } else if ([elementName isEqualToString:@"CCSAccount"]) {
        row.ccsAccount = [lastValue copy];
    } else if ([elementName isEqualToString:@"EventDate"]) {
        row.eventDate = [NSDate dateWithNaturalLanguageString:lastValue];
    } else if ([elementName isEqualToString:@"MarketID"]) {
        row.marketID = [lastValue copy];
    } else if ([elementName isEqualToString:@"Market"]) {
        row.market = [lastValue copy];
    } else if ([elementName isEqualToString:@"Location"]) {
        row.location = [lastValue copy];
    } else if ([elementName isEqualToString:@"HostGroup"]) {
        row.hostGroup = [lastValue copy];
    } else if ([elementName isEqualToString:@"IsQuicPost"]) {
        row.isQuicPost = [lastValue caseInsensitiveCompare:@"true"] == NSOrderedSame ? YES : NO;
    } else if ([elementName isEqualToString:@"AutoCategorizeImages"]) {
        row.autoCategorizeImages = [lastValue caseInsensitiveCompare:@"true"] == NSOrderedSame ? YES : NO;
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    listEventsResult.error = parseError;
    listFinished(listEventsResult);
}

@end
