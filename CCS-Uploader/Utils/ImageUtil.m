#import "ImageUtil.h"

@implementation ImageUtil

+ (void)exif:(NSString *)imageFilename
{
    NSURL *imageFileURL = [NSURL fileURLWithPath:imageFilename];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageFileURL, NULL);
    
    if (imageSource == NULL) {
        return;
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache,
        nil];
    
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
    
    if (imageProperties) {
        NSNumber *width = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
        NSNumber *height = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
        NSNumber *orientation = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation);
        NSLog(@"Image dimensions: %@ x %@ px, orientation: %@", width, height, orientation);
        CFRelease(imageProperties);
    }
    
    CFRelease(imageSource);
}

+ (void)setExif:(NSString *)imageFilename
{
    NSURL *imageFileURL = [NSURL fileURLWithPath:imageFilename];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageFileURL, NULL);
    
    NSDictionary *metadata = (__bridge NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSMutableDictionary *metadataAsMutable = [metadata mutableCopy];
    
    [metadataAsMutable setObject:[NSNumber numberWithInt:11] forKey:(NSString *)kCGImagePropertyOrientation];
    
    CFStringRef UTI = CGImageSourceGetType(source);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef) data, UTI, 1, NULL);
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadataAsMutable);
    
    BOOL success = NO;
    success = CGImageDestinationFinalize(destination);
    
    [data writeToURL:imageFileURL atomically:YES];
    
    CFRelease(destination);
    CFRelease(source);
}

+ (void)generateThumbnailForImage:(NSImage *)image atPath:(NSString *)newFilePath forWidth:(int)width
{
    CGSize size = CGSizeMake(width, image.size.height * (float)width / (float)image.size.width);
    CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
    
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, size.width * 4, rgbColorspace, bitmapInfo);
    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
    [NSGraphicsContext setCurrentContext:graphicsContext];
    
    [image drawInRect:NSMakeRect(0, 0, size.width, size.height) fromRect:NSMakeRect(0, 0, image.size.width, image.size.height) operation:NSCompositeCopy fraction:1.0];
    
    CGImageRef outImage = CGBitmapContextCreateImage(context);
    CFURLRef outURL = (__bridge CFURLRef)[NSURL fileURLWithPath:newFilePath];
    CGImageDestinationRef outDestination = CGImageDestinationCreateWithURL(outURL, kUTTypeJPEG, 1, NULL);
    CGImageDestinationAddImage(outDestination, outImage, NULL);
    
    if (!CGImageDestinationFinalize(outDestination)) {
        NSLog(@"Failed to write image to %@", newFilePath);
    }
    
    CFRelease(outDestination);
    CGImageRelease(outImage);
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorspace);
}

@end
