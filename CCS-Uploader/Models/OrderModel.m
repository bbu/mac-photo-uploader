#import "OrderModel.h"

#define kOrderFileExtension @"ccsorder"
#define kDefaultLocalFolder @"Images/%@"

#define FAIL(retval, fmt, ...) \
    ({ \
        NSString *errorMessage = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; \
        NSLog(@"%s(%u): %@", __FILE__, __LINE__, errorMessage); \
        \
        if (error) { \
            *error = [NSError errorWithDomain:@"Order initialization" code:1 userInfo:@{ NSLocalizedDescriptionKey: errorMessage }]; \
        } \
        \
        (retval); \
    })

@interface OrderModel () {
    EventRow *eventRow;
    NSString *rootDir;
    NSMutableArray *rolls;
    
    NSNumberFormatter *numberFormatter;
    NSFileManager *fileMgr;
    NSUserDefaults *defaults;
    NSInteger rollAutoIncrementCount;
}

@end

@implementation OrderModel

@synthesize eventRow;
@synthesize rootDir;
@synthesize rolls;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    if (self) {
        eventRow = [decoder decodeObjectForKey:@"eventRow"];
        rootDir = [decoder decodeObjectForKey:@"rootDir"];
        rolls = [decoder decodeObjectForKey:@"rolls"];
    }
    
    return self;
}

- (id)initWithEventRow:(EventRow *)event error:(NSError **)error
{
    if (!(self = [super init])) {
        return nil;
    }
    
    eventRow = event;
    numberFormatter = [NSNumberFormatter new];
    fileMgr = [NSFileManager defaultManager];
    defaults = [NSUserDefaults standardUserDefaults];
    
    if (!eventRow.orderNumber) {
        return FAIL(nil, @"Event row does not specify an order number!");
    }
    
    NSString *pathToOrderFile = [OrderModel pathToOrderFile:eventRow.orderNumber];
    
    if (!pathToOrderFile) {
        return FAIL(nil, @"Event row does not specify an order number!");
    }
    
    OrderModel *unarchivedOrder = [NSKeyedUnarchiver unarchiveObjectWithFile:pathToOrderFile];

    if (unarchivedOrder) {
        rolls = unarchivedOrder.rolls ? unarchivedOrder.rolls : [NSMutableArray new];
        rootDir = unarchivedOrder.rootDir;
        
        if (!rootDir) {
            return FAIL(nil, @"Archived order '%@' does not specify a root directory!", pathToOrderFile);
        }
    } else {
        rolls = [NSMutableArray new];
        NSString *localFolder = [defaults objectForKey:kApplicationFolder];
        
        if (localFolder) {
            rootDir = [localFolder stringByAppendingPathComponent:eventRow.orderNumber];
        } else {
            rootDir = [FileUtil pathForDataDir:[NSString stringWithFormat:kDefaultLocalFolder, eventRow.orderNumber]];
            
            if (!rootDir) {
                return FAIL(nil, @"Could not obtain application data directory path.");
            }
        }
    }

    BOOL isDirectory = NO;
    BOOL fileExists = [fileMgr fileExistsAtPath:rootDir isDirectory:&isDirectory];

    if (fileExists && !isDirectory) {
        return FAIL(nil, @"A file exists with the same name as the root directory of the order.");
    } else if (!fileExists) {
        NSError *dirError = nil;
        BOOL dirCreated = [fileMgr createDirectoryAtPath:rootDir withIntermediateDirectories:YES attributes:nil error:&dirError];
        
        if (!dirCreated) {
            return FAIL(nil, @"Could not create order root directory: %@", dirError.localizedDescription);
        }
    }
    
    return self;
}

- (id)initWithOrderNumber:(NSString *)orderNumber
{
    NSString *orderFilename = [eventRow.orderNumber stringByAppendingPathExtension:kOrderFileExtension];
    NSString *path = [FileUtil pathForDataFile:orderFilename];
    
    self = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    
    if (self) {
        
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:eventRow forKey:@"eventRow"];
    [encoder encodeObject:rootDir forKey:@"rootDir"];
    [encoder encodeObject:rolls forKey:@"rolls"];
}

- (BOOL)diffWithExistingFiles
{
    NSMutableArray *subdirsInRoot = [FileUtil filesInDirectory:rootDir extensionSet:nil recursive:NO absolutePaths:NO];
    
    if (!subdirsInRoot) {
        return NO;
    }
    
    NSMutableSet *existingDirs = [NSMutableSet setWithArray:subdirsInRoot];
    
    for (RollModel *roll in rolls) {
        if ([existingDirs containsObject:roll.number]) {
            [existingDirs removeObject:roll.number];

            roll.dirExists = YES;

            NSMutableArray *filesInSubdir = [FileUtil filesInDirectory:[rootDir stringByAppendingPathComponent:roll.number]
                extensionSet:[NSSet setWithObjects:@"jpg", @"png", nil]
                recursive:NO absolutePaths:NO];
            
            if (!filesInSubdir) {
                continue;
            }
            
            NSMutableSet *existingFiles = [NSMutableSet setWithArray:filesInSubdir];
            
            for (FrameModel *frame in roll.frames) {
                NSString *path = [rootDir stringByAppendingPathComponent:roll.number];
                NSString *filename = [frame.name stringByAppendingPathExtension:frame.extension];
                NSString *filepath = [path stringByAppendingPathComponent:filename];
                
                if ([existingFiles containsObject:filename]) {
                    [existingFiles removeObject:filename];
                    
                    frame.fileExists = YES;

                    NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:filepath error:nil];
                    
                    if (fileAttrs && [frame.lastModified compare:fileAttrs.fileModificationDate] != NSOrderedSame) {
                        frame.needsReload = YES;
                        frame.filesize = fileAttrs.fileSize;
                        frame.lastModified = fileAttrs.fileModificationDate;
                        frame.fullsizeSent = NO;
                        frame.thumbsSent = NO;
                    }
                } else {
                    frame.needsDelete = YES;
                }
            }
            
            for (NSString *newlyAddedFile in existingFiles) {
                FrameModel *frame = [FrameModel new];
                frame.name = [newlyAddedFile stringByDeletingPathExtension];
                frame.extension = newlyAddedFile.pathExtension;
                frame.needsReload = YES;
                frame.newlyAdded = YES;
                frame.fileExists = YES;
                [roll.frames addObject:frame];
            }
        } else {
            roll.dirExists = NO;
            roll.needsDelete = YES;
        }
    }
    
    for (NSString *newlyAddedDir in existingDirs) {
        RollModel *roll = [RollModel new];
        roll.number = newlyAddedDir;
        roll.newlyAdded = YES;
        roll.dirExists = YES;
        roll.frames = [NSMutableArray new];
        
        NSMutableArray *filesInSubdir = [FileUtil filesInDirectory:[rootDir stringByAppendingPathComponent:newlyAddedDir]
            extensionSet:[NSSet setWithObjects:@"jpg", @"png", nil] recursive:NO absolutePaths:NO];
        
        if (!filesInSubdir) {
            continue;
        }
        
        for (NSString *newlyAddedFile in filesInSubdir) {
            FrameModel *frame = [FrameModel new];
            frame.name = [newlyAddedFile stringByDeletingPathExtension];
            frame.extension = newlyAddedFile.pathExtension;
            frame.needsReload = YES;
            frame.newlyAdded = YES;
            frame.fileExists = YES;
            [roll.frames addObject:frame];
        }
    }
    
    return YES;
}

+ (NSString *)pathToOrderFile:(NSString *)orderNumber
{
    NSString *orderFilename = [orderNumber stringByAppendingPathExtension:kOrderFileExtension];
    return [FileUtil pathForDataFile:orderFilename];
}

- (BOOL)addRoll:(RollModel *)roll renumber:(BOOL)renumber
{
    [rolls addObject:roll];
    return YES;
}

- (BOOL)save
{
    NSString *path = [OrderModel pathToOrderFile:eventRow.orderNumber];
    return [NSKeyedArchiver archiveRootObject:self toFile:path];
}

- (BOOL)delete
{
    NSString *path = [OrderModel pathToOrderFile:eventRow.orderNumber];
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end
