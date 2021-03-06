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
    
    BOOL includeInList;
    NSString *absolutePath, *relativePath;
    
    if (recursive) {
        NSDirectoryEnumerator *dirEnum = [fileMgr enumeratorAtPath:dir];

        if (dirEnum) {
            contents = [NSMutableArray new];

            while (relativePath = [dirEnum nextObject]) {
                absolutePath = [dir stringByAppendingPathComponent:relativePath];
                existsAndIsDir = [fileMgr fileExistsAtPath:absolutePath isDirectory:&isDir] && isDir;
                
                includeInList =
                    (!existsAndIsDir && extensions && [FileUtil filenameExtensionInSet:extensions filename:relativePath]) ||
                    (existsAndIsDir && !extensions);
                
                if (includeInList) {
                    [contents addObject:absolutePaths ? absolutePath : relativePath];
                }
            }
        } else {
            NSLog(@"Could not enumerate directory '%@' recursively.", dir);
        }
    } else {
        NSError *error = nil;
        NSArray *dirContents = [fileMgr contentsOfDirectoryAtPath:dir error:&error];

        if (!error) {
            contents = [NSMutableArray new];
            
            for (relativePath in dirContents) {
                absolutePath = [dir stringByAppendingPathComponent:relativePath];
                existsAndIsDir = [fileMgr fileExistsAtPath:absolutePath isDirectory:&isDir] && isDir;
                
                includeInList =
                    (!existsAndIsDir && extensions && [FileUtil filenameExtensionInSet:extensions filename:relativePath]) ||
                    (existsAndIsDir && !extensions);
                
                if (includeInList) {
                    [contents addObject:absolutePaths ? absolutePath : relativePath];
                }
            }
        } else {
            NSLog(@"Could not list contents of directory '%@': %@", dir, error.localizedDescription);
        }
    }
    
    return contents;
}

+ (NSString *)pathForDataFile:(NSString *)filename
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSString *dir = [kAppDataRoot stringByExpandingTildeInPath];
    
    BOOL dirExists = [fileMgr fileExistsAtPath:dir];
    BOOL dirCreated = NO;
    
    if (!dirExists) {
        dirCreated = [fileMgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (dirExists || dirCreated) {
        return [dir stringByAppendingPathComponent:filename];
    }
    
    NSLog(@"Could not create application directory!");
    return nil;
}

+ (NSString *)pathForDataDir:(NSString *)dirname
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSString *dir = [[kAppDataRoot stringByExpandingTildeInPath] stringByAppendingPathComponent:dirname];
    
    BOOL dirExists = [fileMgr fileExistsAtPath:dir];
    BOOL dirCreated = NO;
    
    if (!dirExists) {
        dirCreated = [fileMgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    if (dirExists || dirCreated) {
        return dir;
    }
    
    NSLog(@"Could not create application data directory!");
    return nil;
}

+ (BOOL)filenameExtensionInSet:(NSSet *)extensions filename:(NSString *)filename
{
    NSString *extension = filename.pathExtension.lowercaseString;
    return extension && [extensions containsObject:extension] ? YES : NO;
}

+ (NSString *)humanFriendlyFilesize:(NSUInteger)value
{
    if (value < 1024) {
        return [NSString stringWithFormat:@"%lu bytes", value];
    }
    
    double convertedValue = value;
    int multiplyFactor = 0;
    
    NSArray *tokens = @[@"", @"KB", @"MB", @"GB", @"TB"];
    
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }

    return [NSString stringWithFormat:@"%4.2f %@", convertedValue, tokens[multiplyFactor]];
}

+ (NSString *)versionString
{
    static NSString *result;
    
    if (result == nil) {
        NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        result = [NSString stringWithFormat:@"CCSUploaderMac %@", currentVersion];
    }
    
    return result;
}

+ (NSData *)zipDataForFiles:(NSArray *)files
{
    NSString *destZipFile = @"/tmp/ccsuploaderlog.zip";
    NSTask *createZipTask = [NSTask new];
    
    createZipTask.launchPath = @"/usr/bin/zip";
    
    createZipTask.arguments = [@[@"-rqj", destZipFile] arrayByAddingObjectsFromArray:files];
    [createZipTask launch];
    
    while (createZipTask.isRunning) {
        usleep(25);
    }
    
    NSData *zipData = [NSData dataWithContentsOfFile:destZipFile];
    [[NSFileManager defaultManager] removeItemAtPath:destZipFile error:nil];
    
    return zipData;
}

+ (int)createLogFile
{
    return system("syslog -F '$(Sender) $Time <$((Level)(str))>: $Message' | grep -p \"^CCS Uploader \" "
        "> /tmp/ccsuploader.log");
}

@end
