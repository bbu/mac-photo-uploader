#import <Foundation/Foundation.h>

#import "Service.h"

@interface PostImageDataResult : ServiceResult
@property NSString *status, *message;
@end

@interface PostImageDataService : Service

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
                  complete:(void (^)(PostImageDataResult *result))block;

@end
