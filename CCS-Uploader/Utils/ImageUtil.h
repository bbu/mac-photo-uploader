#import <Foundation/Foundation.h>

@interface ImageUtil : NSObject

+ (void)exif:(NSString *)imageFilename;
+ (void)setExif:(NSString *)imageFilename;
+ (void)generateThumbnailForImage:(NSImage *)image atPath:(NSString *)newFilePath forWidth:(int)width;

@end
