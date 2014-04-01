#import "SetChromaKeyRollMakePNGOnlyService.h"

@interface SetChromaKeyRollMakePNGOnlyService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ServiceResult *result;
}
@end

@implementation SetChromaKeyRollMakePNGOnlyService

- (NSString *)serviceURL
{
    return kCandidEventServiceRoot @"setChromaKeyRollMakePNGOnly";
}

- (BOOL)startSetChromaKeyRollMakePNGOnly:(NSString *)account password:(NSString *)password
    eventID:(NSString *)eventID sourceRoll:(NSString *)sourceRoll
    complete:(void (^)(ServiceResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"custID=%@&custPassword=%@&eventID=%@&sourceRoll=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [eventID stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [sourceRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
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
    urlConnection = nil, started = NO;
    finished(result);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, result.error = error;
    finished(result);
}

@end
