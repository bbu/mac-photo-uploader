#import "FileUtil.h"

@implementation FileUtil

+ (NSMutableArray *)filesInDirectory:(NSString *)dir extensionSet:(NSSet *)extensions recursive:(BOOL)recursive absolutePaths:(BOOL)absolutePaths
{
    NSMutableArray *contents = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];

    BOOL isDir;
    BOOL existsAndIsDir = [fileMgr fileExistsAtPath:dir isDirectory:&isDir] && isDir;
    
    if (!existsAndIsDir) {
        return contents;
    }
    
    NSString *absolutePath, *relativePath;
    
    if (recursive) {
        NSDirectoryEnumerator *dirEnum = [fileMgr enumeratorAtPath:dir];

        if (dirEnum) {
            contents = [NSMutableArray new];

            while (relativePath = [dirEnum nextObject]) {
                absolutePath = [dir stringByAppendingPathComponent:relativePath];
                existsAndIsDir = [fileMgr fileExistsAtPath:absolutePath isDirectory:&isDir] && isDir;
                
                if (!existsAndIsDir && [FileUtil filenameExtensionInSet:extensions filename:relativePath]) {
                    [contents addObject:absolutePaths ? absolutePath : relativePath];
                }
            }
        }
    } else {
        NSError *error = nil;
        NSArray *dirContents = [fileMgr contentsOfDirectoryAtPath:dir error:&error];

        if (!error) {
            contents = [NSMutableArray new];
            
            for (relativePath in dirContents) {
                absolutePath = [dir stringByAppendingPathComponent:relativePath];
                existsAndIsDir = [fileMgr fileExistsAtPath:absolutePath isDirectory:&isDir] && isDir;
                
                if (!existsAndIsDir && [FileUtil filenameExtensionInSet:extensions filename:relativePath]) {
                    [contents addObject:absolutePaths ? absolutePath : relativePath];
                }
            }
        }
    }
    
    return contents;
}

+ (NSString *)pathForDataFile:(NSString *)filename
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSString *dir = [@"~/Library/Application Support/CCS Uploader/" stringByExpandingTildeInPath];
    
    BOOL dirExists = [fileMgr fileExistsAtPath:dir];
    BOOL dirCreated = NO;
    
    if (!dirExists) {
        dirCreated = [fileMgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (dirExists || dirCreated) {
        return [dir stringByAppendingPathComponent:filename];
    }
    
    return nil;
}

+ (BOOL)filenameExtensionInSet:(NSSet *)extensions filename:(NSString *)filename
{
    if (!extensions) {
        return YES;
    }
    
    NSString *extension = [filename.pathExtension lowercaseString];
    return extension && [extensions containsObject:extension] ? YES : NO;
}

+ (NSSet *)extensionSetWithJpeg:(BOOL)jpeg withPng:(BOOL)png
{
    static NSSet *jpegAndPngSet, *jpegSet, *pngSet;
    
    if (jpeg && png) {
        if (!jpegAndPngSet) {
            jpegAndPngSet = [NSSet setWithObjects:@"jpeg", @"jpg", @"png", nil];
        }
        
        return jpegAndPngSet;
    } else if (jpeg) {
        if (!jpegSet) {
            jpegSet = [NSSet setWithObjects:@"jpeg", @"jpg", nil];
        }
        
        return jpegSet;
    } else if (png) {
        if (!pngSet) {
            pngSet = [NSSet setWithObjects:@"png", nil];
        }
        
        return pngSet;
    } else {
        return nil;
    }
}

@end
