#import <Foundation/Foundation.h>

#define kAppDataRoot @"~/Library/Application Support/CCS Uploader/"

@interface FileUtil : NSObject

+ (NSMutableArray *)filesInDirectory:(NSString *)dir extensionSet:(NSSet *)extensions recursive:(BOOL)recursive absolutePaths:(BOOL)absolutePaths;
+ (NSString *)pathForDataFile:(NSString *)filename;
+ (NSString *)pathForDataDir:(NSString *)dirname;
+ (NSString *)humanFriendlyFilesize:(NSUInteger)value;
+ (NSString *)versionString;

@end
