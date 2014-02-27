#import "PostImageDataService.h"

#import "../Utils/Base64.h"

@implementation PostImageDataResult
@end

@interface PostImageDataService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    PostImageDataResult *postImageDataResult;
}
@end

@implementation PostImageDataService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"postImageData";
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

        fullsizeImage ? [fullsizeImage base64EncodedString] : @"",
        previewImage ? [previewImage base64EncodedString] : @"",
        thumbnailImage ? [thumbnailImage base64EncodedString] : @"",
        pngImage ? [pngImage base64EncodedString] : @"",
        mediumResImage ? [mediumResImage base64EncodedString] : @"",

        originalImageSize,
        originalWidth,
        originalHeight,

        previewWidth,
        previewHeight,
        pngWidth,
        pngHeight,

        [photographer stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        @"",
        createPreviewAndThumb ? @"true" : @"false"
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    postImageDataResult = [PostImageDataResult new];
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
