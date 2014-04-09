#import "SetChromaKeyRollService.h"

@implementation SetChromaKeyRollResult
@end

@interface SetChromaKeyRollService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    SetChromaKeyRollResult *result;
}
@end

@implementation SetChromaKeyRollService

- (NSString *)serviceURL
{
    return kCandidEventServiceRoot @"setChromaKeyRoll2";
}

- (BOOL)startSetChromaKeyRoll:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID sourceRoll:(NSString *)sourceRoll
    horzBackgroundOrderNo:(NSString *)horzBackgroundOrderNo horzBackgroundRoll:(NSString *)horzBackgroundRoll horzBackgroundFrame:(NSString *)horzBackgroundFrame
    vertBackgroundOrderNo:(NSString *)vertBackgroundOrderNo vertBackgroundRoll:(NSString *)vertBackgroundRoll vertBackgroundFrame:(NSString *)vertBackgroundFrame
    destinationRoll:(NSString *)destinationRoll
    complete:(void (^)(SetChromaKeyRollResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"custID=%@&custPassword=%@&eventID=%@&sourceRoll=%@&"
        @"horzBackgroundOrderNo=%@&horzBackgroundRoll=%@&horzBackgroundFrame=%@&"
        @"vertBackgroundOrderNo=%@&vertBackgroundRoll=%@&vertBackgroundFrame=%@&"
        @"destinationRoll=%@",
        
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [eventID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [sourceRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          
        [horzBackgroundOrderNo stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [horzBackgroundRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [horzBackgroundFrame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],

        [vertBackgroundOrderNo stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [vertBackgroundRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [vertBackgroundFrame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                          
        [destinationRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    result = [SetChromaKeyRollResult new];
    finished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    result.message = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    urlConnection = nil, started = NO;
    finished(result);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, result.error = error;
    finished(result);
}

@end
