#import <Foundation/Foundation.h>

@interface ImageUtil : NSObject

+ (void)exif:(NSString *)imageFilename;
+ (void)setExif:(NSString *)imageFilename value:(int)value;
+ (void)generateThumbnailForImage:(NSImage *)image atPath:(NSString *)newFilePath forWidth:(int)width;
+ (void)scaleAndRotateImage:(NSString *)imageFilename;

@end
