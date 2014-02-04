#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IURotation) {
    kRotateCCW270 = -3,
    kRotateCCW180 = -2,
    kRotateCCW90  = -1,
    kDontRotate   =  0,
    kRotateCW90   =  1,
    kRotateCW180  =  2,
    kRotateCW270  =  3,
};

@interface ImageUtil : NSObject

+ (BOOL)getImageProperties:(NSString *)filename size:(CGSize *)size type:(NSMutableString *)imageType orientation:(NSUInteger *)orientation;
+ (void)setExif:(NSString *)imageFilename value:(int)value;
+ (void)generateThumbnailForImage:(NSImage *)image atPath:(NSString *)newFilePath forWidth:(int)width;

+ (BOOL)resizeAndRotateImage:(NSString *)inputImageFilename outputImageFilename:(NSString *)outputImageFilename
    resizeToMaxSide:(CGFloat)maxSide rotate:(IURotation)rotate compressionQuality:(float)compressionQuality;

@end
