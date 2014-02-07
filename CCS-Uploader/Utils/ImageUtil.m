#import "ImageUtil.h"

#import <CoreGraphics/CGImage.h>

@implementation ImageUtil

+ (BOOL)getImageProperties:(NSString *)filename size:(CGSize *)size type:(NSMutableString *)imageType orientation:(NSUInteger *)orientation
{
    NSURL *imageFileURL = [NSURL fileURLWithPath:filename];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)imageFileURL, NULL);
    
    if (imageSource == NULL) {
        NSLog(@"Could not create image source for %@", filename);
        return NO;
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache,
        nil];
    
    BOOL result = NO;
    
    [imageType setString:(__bridge NSString *)CGImageSourceGetType(imageSource)];
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
    
    if (imageProperties) {
        NSNumber *width = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
        NSNumber *height = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
        NSNumber *orientationNumber = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation);
        
        size->width = width.floatValue;
        size->height = height.floatValue;
        *orientation = orientationNumber.unsignedIntegerValue;
        
        CFRelease(imageProperties);
        result = YES;
    } else {
        NSLog(@"Could not get image properties for %@", filename);
    }

    CFRelease(imageSource);
    return result;
}

+ (BOOL)setExif:(NSString *)imageFilename value:(NSInteger)value
{
    NSURL *imageFileURL = [NSURL fileURLWithPath:imageFilename];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageFileURL, NULL);
    
    if (source == NULL) {
        NSLog(@"Could not create image source for '%@' to set EXIF orientation.", imageFilename);
        return NO;
    }
    
    NSDictionary *metadata = (__bridge NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSMutableDictionary *metadataAsMutable = [metadata mutableCopy];
    
    [metadataAsMutable setObject:[NSNumber numberWithInteger:value] forKey:(NSString *)kCGImagePropertyOrientation];
    
    CFStringRef UTI = CGImageSourceGetType(source);
    NSMutableData *data = [NSMutableData data];
    BOOL result = NO;
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef) data, UTI, 1, NULL);
    
    if (destination == NULL) {
        NSLog(@"Could not create image destination for '%@' to set EXIF orientation.", imageFilename);
        goto releaseSource;
    }
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadataAsMutable);

    if ((result = CGImageDestinationFinalize(destination))) {
        result = [data writeToURL:imageFileURL atomically:YES];
    }
    
releaseDestination:
    CFRelease(destination);
releaseSource:
    CFRelease(source);

    return result;
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

+ (void)resizeToMaxSide:(CGFloat)maxSide imageSize:(CGSize)imageSize newSize:(CGSize *)newSize scaleRatio:(CGFloat *)scaleRatio
{
    if (imageSize.width > maxSide || imageSize.height > maxSide) {
        CGFloat ratio = imageSize.width / imageSize.height;
        
        if (ratio > 1) {
            *newSize = CGSizeMake(maxSide, roundf(maxSide / ratio));
        } else {
            *newSize = CGSizeMake(roundf(maxSide * ratio), maxSide);
        }
        
        *scaleRatio = newSize->width / imageSize.width;
    } else {
        *newSize = imageSize;
        *scaleRatio = 1.0;
    }
}

+ (CGAffineTransform)transformToHonourExifOrientation:(NSInteger)orientation imageSize:(CGSize)imageSize bounds:(CGSize *)bounds
{
    CGAffineTransform transform;
    BOOL swapWidthAndHeight = NO;

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
            swapWidthAndHeight = YES;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case 6:
            swapWidthAndHeight = YES;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case 7:
            swapWidthAndHeight = YES;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case 8:
            swapWidthAndHeight = YES;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            transform = CGAffineTransformIdentity;
    }
    
    if (swapWidthAndHeight) {
        CGFloat temp = bounds->height;
        bounds->height = bounds->width;
        bounds->width = temp;
    }
    
    return transform;
}

+ (CGAffineTransform)transformToRotate:(IURotation)rotation imageSize:(CGSize)imageSize bounds:(CGSize *)bounds
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    if (rotation != kDontRotate) {
        if (rotation == kRotateCCW90 || rotation == kRotateCW270) {
            transform = CGAffineTransformTranslate(transform, imageSize.height, 0);
        } else if (rotation == kRotateCW90 || rotation == kRotateCCW270) {
            transform = CGAffineTransformTranslate(transform, 0, imageSize.width);
        } else if (rotation == kRotateCCW180 || rotation == kRotateCW180) {
            transform = CGAffineTransformTranslate(transform, imageSize.width, imageSize.height);
        }
        
        transform = CGAffineTransformRotate(transform, -rotation * (M_PI / 2.0));
        
        if (labs(rotation) % 2 == 1) {
            CGFloat temp = bounds->width;
            bounds->width = bounds->height;
            bounds->height = temp;
        }
    }

    return transform;
}

+ (BOOL)resizeAndRotateImage:(NSString *)inputImageFilename outputImageFilename:(NSString *)outputImageFilename
    resizeToMaxSide:(CGFloat)maxSide rotate:(IURotation)rotation compressionQuality:(float)compressionQuality
{
    BOOL result = NO;
    
    CFURLRef imageFileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:inputImageFilename];
    CGImageSourceRef inputImageSource = CGImageSourceCreateWithURL(imageFileURL, NULL);
    
    if (inputImageSource == NULL) {
        NSLog(@"Could not create image source for %@", inputImageFilename);
        return NO;
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache, nil];
    
    NSMutableDictionary *outputImageProperties = [NSMutableDictionary new];
    NSMutableDictionary *inputImageProperties =
        [(__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(inputImageSource, 0, (__bridge CFDictionaryRef)options) mutableCopy];
    
    CFStringRef inputImageType = CGImageSourceGetType(inputImageSource);
    CGImageRef inputImage = CGImageSourceCreateImageAtIndex(inputImageSource, 0, NULL);

    if (inputImage == NULL) {
        NSLog(@"Could not create image for %@", inputImageFilename);
        goto releaseInputImageSource;
    }
    
    CGSize inputImageSize = CGSizeMake(CGImageGetWidth(inputImage), CGImageGetHeight(inputImage));
    CGSize outputImageSize;
    CGFloat scaleRatio;
    
    if (maxSide != 0) {
        [ImageUtil resizeToMaxSide:maxSide imageSize:inputImageSize newSize:&outputImageSize scaleRatio:&scaleRatio];
    } else {
        outputImageSize = inputImageSize;
        scaleRatio = 1.0;
    }
    
    NSInteger exifOrientationValue = ((NSNumber *)[inputImageProperties objectForKey:(NSString *)kCGImagePropertyOrientation]).integerValue;
    
    CGAffineTransform exifTransform = [ImageUtil transformToHonourExifOrientation:exifOrientationValue
        imageSize:inputImageSize bounds:&outputImageSize];
    
    CGAffineTransform rotationTransform = [ImageUtil transformToRotate:rotation
        imageSize:inputImageSize bounds:&outputImageSize];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (colorSpace == NULL) {
        NSLog(@"Could not create color space for %@", inputImageFilename);
        goto releaseInputImage;
    }

    CGContextRef drawingContext = CGBitmapContextCreate(NULL, outputImageSize.width, outputImageSize.height, 8,
        outputImageSize.width * 4, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    
    //CGContextRef drawingContext = CGBitmapContextCreate(NULL, outputImageSize.width, outputImageSize.height,
    //    CGImageGetBitsPerComponent(inputImage), 0, CGImageGetColorSpace(inputImage), CGImageGetBitmapInfo(inputImage));
    
    if (drawingContext == NULL) {
        NSLog(@"Could not create drawing context for %@", inputImageFilename);
        goto releaseColorSpace;
    }

    CGContextScaleCTM(drawingContext, scaleRatio, scaleRatio);
    CGContextTranslateCTM(drawingContext, 0, 0);
    CGContextConcatCTM(drawingContext, exifTransform);
    CGContextConcatCTM(drawingContext, rotationTransform);
    CGContextDrawImage(drawingContext, CGRectMake(0, 0, inputImageSize.width, inputImageSize.height), inputImage);
    CGImageRef outputImage = CGBitmapContextCreateImage(drawingContext);
    
    if (outputImage == NULL) {
        NSLog(@"Could not create output image for %@", inputImageFilename);
        goto releaseDrawingContext;
    }

    if (outputImageFilename != nil) {
        imageFileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:outputImageFilename];
    }
    
    CGImageDestinationRef outputImageDestination = CGImageDestinationCreateWithURL(imageFileURL, inputImageType, 1, NULL);
    
    if (outputImageDestination == NULL) {
        NSLog(@"Could not create output image destination for %@",
            outputImageFilename ? outputImageFilename : inputImageFilename);
        
        goto releaseOutputImage;
    }

    [outputImageProperties setObject:[NSNumber numberWithInt:1]
        forKey:(NSString *)kCGImagePropertyOrientation];

    if (!CFStringCompare(inputImageType, kUTTypeJPEG, 0)) {
        [outputImageProperties setObject:[NSNumber numberWithFloat:compressionQuality]
            forKey:(NSString *)kCGImageDestinationLossyCompressionQuality];
    }
    
    CGImageDestinationAddImage(outputImageDestination, outputImage, (__bridge CFDictionaryRef)outputImageProperties);

    if (!CGImageDestinationFinalize(outputImageDestination)) {
        NSLog(@"Failed to write image to %@", inputImageFilename);
    } else {
        result = YES;
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
releaseInputImageSource:
    CFRelease(inputImageSource);
    
    return result;
}

@end
