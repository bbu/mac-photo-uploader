#import "DeleteChromaKeyRoll2Service.h"

@interface DeleteChromaKeyRoll2Service () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    ServiceResult *result;
}
@end

@implementation DeleteChromaKeyRoll2Service

- (NSString *)serviceURL
{
    return kCandidEventServiceRoot @"deleteChromaKeyRoll2";
}

- (BOOL)startDeleteChromaKeyRoll2:(NSString *)account password:(NSString *)password
    orderNo:(NSString *)orderNo roll:(NSString *)roll destinationRoll:(NSString *)destinationRoll
    complete:(void (^)(ServiceResult *result))block;
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"custID=%@&custPassword=%@&orderNo=%@&roll=%@&destinationRoll=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNo stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [destinationRoll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
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
