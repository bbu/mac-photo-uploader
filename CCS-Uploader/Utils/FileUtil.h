#import <Foundation/Foundation.h>

@interface FileUtil : NSObject

+ (NSMutableArray *)filesInDirectory:(NSString *)dir extensionSet:(NSSet *)extensions recursive:(BOOL)recursive absolutePaths:(BOOL)absolutePaths;
+ (NSString *)pathForDataFile:(NSString *)filename;
+ (NSSet *)extensionSetWithJpeg:(BOOL)jpeg withPng:(BOOL)png;

@end
