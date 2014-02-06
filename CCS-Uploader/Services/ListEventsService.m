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

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_eventID forKey:@"eventID"];
    [encoder encodeObject:_eventName forKey:@"eventName"];
    [encoder encodeObject:_orderNumber forKey:@"orderNumber"];
    [encoder encodeObject:_ccsAccount forKey:@"ccsAccount"];
    [encoder encodeObject:_eventDate forKey:@"eventDate"];
    [encoder encodeObject:_marketID forKey:@"marketID"];
    [encoder encodeObject:_market forKey:@"market"];
    [encoder encodeObject:_location forKey:@"location"];
    [encoder encodeObject:_hostGroup forKey:@"hostGroup"];
    [encoder encodeBool:_isQuicPost forKey:@"isQuicPost"];
    [encoder encodeBool:_autoCategorizeImages forKey:@"autoCategorizeImages"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    if (self) {
        _eventID = [decoder decodeObjectForKey:@"eventID"];
        _eventName = [decoder decodeObjectForKey:@"eventName"];
        _orderNumber = [decoder decodeObjectForKey:@"orderNumber"];
        _ccsAccount = [decoder decodeObjectForKey:@"ccsAccount"];
        _eventDate = [decoder decodeObjectForKey:@"eventDate"];
        _marketID = [decoder decodeObjectForKey:@"marketID"];
        _market = [decoder decodeObjectForKey:@"market"];
        _location = [decoder decodeObjectForKey:@"location"];
        _hostGroup = [decoder decodeObjectForKey:@"hostGroup"];
        _isQuicPost = [decoder decodeBoolForKey:@"isQuicPost"];
        _autoCategorizeImages = [decoder decodeBoolForKey:@"autoCategorizeImages"];
    }
    
    return self;
}

@end

@interface ListEventsResult () {
    BOOL _loginSuccess, _processSuccess;
    NSMutableArray *_events;
}
@end

@implementation ListEventsResult
@end

@interface ListEventsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSDateFormatter *dateFormatter;
    ListEventsResult *listEventsResult;
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
    NSString *coreDomain = kDefaultCoreDomain;
    
    if (multipleEvents) {
        return [NSString stringWithFormat:kCoreServiceRoot @"ListEvents2", coreDomain];
    } else {
        return [NSString stringWithFormat:kCoreServiceRoot @"ListEvent", coreDomain];
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
    finished = block;

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
        finished(listEventsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, listEventsResult.error = error;
    finished(listEventsResult);
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
    finished(listEventsResult);
}

@end
