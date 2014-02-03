#import "ImageUtil.h"

#import <CoreGraphics/CGImage.h>

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

+ (void)setExif:(NSString *)imageFilename value:(int)value
{
    NSURL *imageFileURL = [NSURL fileURLWithPath:imageFilename];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageFileURL, NULL);
    
    NSDictionary *metadata = (__bridge NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSMutableDictionary *metadataAsMutable = [metadata mutableCopy];
    
    [metadataAsMutable setObject:[NSNumber numberWithInt:value] forKey:(NSString *)kCGImagePropertyOrientation];
    
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
    
    [image drawInRect:NSMakeRect(0, 0, size.width, size.height)
        fromRect:NSMakeRect(0, 0, image.size.width, image.size.height)
        operation:NSCompositeCopy fraction:1.0];
    
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

+ (CGAffineTransform)transformToHonourExifOrientation:(NSInteger)orientation imageSize:(CGSize)imageSize bounds:(CGSize *)bounds
{
    CGAffineTransform transform;
    CGFloat boundHeight;

    switch (orientation) {
        case 1:
            transform = CGAffineTransformIdentity;
            break;
            
        case 2:
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
            
        case 3:
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case 4:
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
            
        case 5:
            boundHeight = bounds->height;
            bounds->height = bounds->width;
            bounds->width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case 6:
            boundHeight = bounds->height;
            bounds->height = bounds->width;
            bounds->width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case 7:
            boundHeight = bounds->height;
            bounds->height = bounds->width;
            bounds->width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case 8:
            boundHeight = bounds->height;
            bounds->height = bounds->width;
            bounds->width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            transform = CGAffineTransformIdentity;
    }
    
    return transform;
}

+ (void)scaleAndRotateImage:(NSString *)imageFilename
{
    int kMaxResolution = 400;
    
    CFURLRef imageFileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:imageFilename];
    
    CGImageSourceRef inputImageSource = CGImageSourceCreateWithURL(imageFileURL, NULL);
    
    if (inputImageSource == NULL) {
        NSLog(@"Could not create image source for %@", imageFilename);
        return;
    }
    
    CFStringRef inputImageType = CGImageSourceGetType(inputImageSource);
    CGImageRef inputImage = CGImageSourceCreateImageAtIndex(inputImageSource, 0, NULL);
    
    if (inputImage == NULL) {
        NSLog(@"Could not create image for %@", imageFilename);
        CFRelease(inputImageSource);
        return;
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache,
        nil];
    
    NSMutableDictionary *newProperties = [NSMutableDictionary new];
    NSMutableDictionary *properties =
        [(__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(inputImageSource, 0, (__bridge CFDictionaryRef)options) mutableCopy];
    
    CGSize inputImageSize = CGSizeMake(CGImageGetWidth(inputImage), CGImageGetHeight(inputImage));
    CGSize outputImageSize = inputImageSize;
    
    if (inputImageSize.width > kMaxResolution || inputImageSize.height > kMaxResolution) {
        CGFloat ratio = inputImageSize.width / inputImageSize.height;
        
        if (ratio > 1) {
            outputImageSize.width = kMaxResolution;
            outputImageSize.height = roundf(outputImageSize.width / ratio);
        } else {
            outputImageSize.height = kMaxResolution;
            outputImageSize.width = roundf(outputImageSize.height * ratio);
        }
    }
    
    CGFloat scaleRatio = outputImageSize.width / inputImageSize.width;
    
    NSNumber *orientation = [properties objectForKey:(NSString *)kCGImagePropertyOrientation];
    NSInteger exifOrientationValue = orientation.integerValue;
    
    CGAffineTransform transform = [ImageUtil transformToHonourExifOrientation:exifOrientationValue
        imageSize:inputImageSize bounds:&outputImageSize];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (colorSpace == NULL) {
        NSLog(@"Could not create color space for %@", imageFilename);
        goto releaseInputImage;
    }

    CGContextRef drawingContext = CGBitmapContextCreate(NULL, outputImageSize.width, outputImageSize.height, 8,
        outputImageSize.width * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    if (drawingContext == NULL) {
        NSLog(@"Could not create drawing context for %@", imageFilename);
        goto releaseColorSpace;
    }

    CGContextScaleCTM(drawingContext, scaleRatio, scaleRatio);
    CGContextTranslateCTM(drawingContext, 0, 0);

    CGContextConcatCTM(drawingContext, transform);
    CGContextDrawImage(drawingContext, CGRectMake(0, 0, inputImageSize.width, inputImageSize.height), inputImage);
    
    CGImageRef outputImage = CGBitmapContextCreateImage(drawingContext);
    
    if (outputImage == NULL) {
        NSLog(@"Could not create output image for %@", imageFilename);
        goto releaseDrawingContext;
    }

    CGImageDestinationRef outputImageDestination = CGImageDestinationCreateWithURL(imageFileURL, inputImageType, 1, NULL);
    
    if (outputImageDestination == NULL) {
        NSLog(@"Could not create output image destination for %@", imageFilename);
        goto releaseOutputImage;
    }

    [newProperties setObject:[NSNumber numberWithInt:1] forKey:(NSString *)kCGImagePropertyOrientation];

    if (!CFStringCompare(inputImageType, kUTTypeJPEG, 0)) {
        [newProperties setObject:[NSNumber numberWithFloat:1.0] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality];
    }
    
    CGImageDestinationAddImage(outputImageDestination, outputImage, (__bridge CFDictionaryRef)newProperties);

    if (!CGImageDestinationFinalize(outputImageDestination)) {
        NSLog(@"Failed to write image to %@", imageFilename);
    }

releaseOutputImageDestination:
    CFRelease(outputImageDestination);
releaseOutputImage:
    CGImageRelease(outputImage);
releaseDrawingContext:
    CGContextRelease(drawingContext);
releaseColorSpace:
    CGColorSpaceRelease(colorSpace);
releaseInputImage:
    CGImageRelease(inputImage);
    CFRelease(inputImageSource);
}

@end
