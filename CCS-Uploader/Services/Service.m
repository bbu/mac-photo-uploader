#import "Service.h"

@implementation ServiceResult
@end

@interface Service () <NSURLConnectionDelegate, NSXMLParserDelegate>
@end

@implementation Service

- (id)init
{
    self = [super init];
    
    if (self) {
        responseData = [NSMutableData new];
        lastValue = [NSMutableString new];
        numberFormatter = [NSNumberFormatter new];
    }
    
    return self;
}

- (void)setEffectiveServiceRoot:(ServiceRoot)serviceRoot coreDomain:(NSString *)coreDomain
{
    effectiveServiceRoot = serviceRoot;
    effectiveCoreDomain = coreDomain;
}

@synthesize started;

- (void)cancel
{
    started = NO;
    [urlConnection cancel];
    urlConnection = nil;
}

+ (NSMutableURLRequest *)postRequestWithURL:(NSString *)urlString body:(NSString *)body
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    return request;
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

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [lastValue appendString:string];
}

@end
