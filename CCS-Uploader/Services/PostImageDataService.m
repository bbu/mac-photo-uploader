#import "PostImageDataService.h"

#import "../Utils/Base64.h"

@implementation PostImageDataResult
@end

@interface PostImageDataService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    NSDateFormatter *dateFormatter;
    PostImageDataResult *postImageDataResult;
}
@end

@implementation PostImageDataService

- (id)init
{
    self = [super init];
    
    if (self) {
        dateFormatter = [NSDateFormatter new];
        //dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
        dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    }
    
    return self;
}

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"postImageDataMac";
}

- (NSString *)escapedBase64:(NSString *)base64
{
    return [[base64
        stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"]
        stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
}

- (BOOL)startPostImageData:(NSString *)account password:(NSString *)password orderNumber:(NSString *)orderNumber
                      roll:(NSString *)roll
                     frame:(NSString *)frame
                 extension:(NSString *)extension
                   version:(NSString *)version
            bypassPassword:(BOOL)bypassPassword
             fullsizeImage:(NSData *)fullsizeImage
              previewImage:(NSData *)previewImage
            thumbnailImage:(NSData *)thumbnailImage
                  pngImage:(NSData *)pngImage
            mediumResImage:(NSData *)mediumResImage
         originalImageSize:(NSInteger)originalImageSize
             originalWidth:(NSInteger)originalWidth
            originalHeight:(NSInteger)originalHeight
              previewWidth:(NSInteger)previewWidth
             previewHeight:(NSInteger)previewHeight
                  pngWidth:(NSInteger)pngWidth
                 pngHeight:(NSInteger)pngHeight
              photographer:(NSString *)photographer
             photoDateTime:(NSDate *)photoDateTime
     createPreviewAndThumb:(BOOL)createPreviewAndThumb
                  complete:(void (^)(PostImageDataResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:
        @"acctNo=%@&password=%@&orderNo=%@&roll=%@&frame=%@&extension=%@&version=%@&bypassPassword=%@&"
        @"fullsizeImage=%@&previewImage=%@&thumbnailImage=%@&pngImage=%@&mediumresImage=%@&"
        @"OriginalImageSize=%ld&OriginalWidth=%ld&OriginalHeight=%ld&"
        @"previewWidth=%ld&previewHeight=%ld&pngWidth=%ld&pngHeight=%ld&"
        @"photographer=%@&photodatetime=%@&createPreviewandThumb=%@",
        
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [roll stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [frame stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [extension stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [version stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        bypassPassword ? @"1" : @"0",

        fullsizeImage ? [self escapedBase64:fullsizeImage.base64EncodedString] : @"",
        previewImage ? [self escapedBase64:previewImage.base64EncodedString] : @"",
        thumbnailImage ? [self escapedBase64:thumbnailImage.base64EncodedString] : @"",
        pngImage ? [self escapedBase64:pngImage.base64EncodedString] : @"",
        mediumResImage ? [self escapedBase64:mediumResImage.base64EncodedString] : @"",

        originalImageSize,
        originalWidth,
        originalHeight,

        previewWidth,
        previewHeight,
        pngWidth,
        pngHeight,

        [photographer stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [[dateFormatter stringFromDate:photoDateTime] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        createPreviewAndThumb ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    //NSLog(@"%@", postBody);
    //NSLog(@"---------");
    
    postImageDataResult = [PostImageDataResult new];
    finished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    urlConnection = nil, started = NO;
    
    //NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    //NSLog(@"Response: %@", response);
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        finished(postImageDataResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, postImageDataResult.error = error;
    finished(postImageDataResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        postImageDataResult.status = [lastValue copy];
    } else if ([elementName isEqualToString:@"message"]) {
        postImageDataResult.message = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    postImageDataResult.error = parseError;
    finished(postImageDataResult);
}

@end
