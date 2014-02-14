#import "OrderModel.h"

#define kEventFolderExtension @"ccsevent"
#define kOrderFileExtension @"ccsorder"
#define kDefaultLocalFolder @"Events/%@"

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
    NSMutableArray *rollsToHide, *framesToHide;
    BOOL newlyAdded;
    
    NSNumberFormatter *numberFormatter;
    NSFileManager *fileMgr;
    NSUserDefaults *defaults;
}

@end

@implementation OrderModel

@synthesize eventRow;

@synthesize rootDir;
@synthesize rolls;
@synthesize rollsToHide, framesToHide;
@synthesize newlyAdded;

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
        NSString *dirname = [eventRow.orderNumber stringByAppendingPathExtension:kEventFolderExtension];
        
        if (localFolder) {
            rootDir = [localFolder stringByAppendingPathComponent:dirname];
        } else {
            rootDir = [FileUtil pathForDataDir:[NSString stringWithFormat:kDefaultLocalFolder, dirname]];
            
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
    
    [self diffWithExistingFiles];
    
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

- (void)diffWithExistingFiles
{
    NSMutableArray *subdirsInRoot = [FileUtil filesInDirectory:rootDir extensionSet:nil recursive:NO absolutePaths:NO];
    
    rollsToHide = [NSMutableArray new];
    framesToHide = [NSMutableArray new];
    
    if (!subdirsInRoot) {
        for (RollModel *roll in rolls) {
            [rollsToHide addObject:roll.number];
        }
        
        [rolls removeAllObjects];
        return;
    }
    
    NSMutableSet *existingDirs = [NSMutableSet setWithArray:subdirsInRoot];
    
    for (RollModel *roll in rolls) {
        if ([existingDirs containsObject:roll.number]) {
            [existingDirs removeObject:roll.number];

            roll.totalFrameSize = 0;

            if (!roll.frames) {
                roll.frames = [NSMutableArray new];
            }
            
            NSString *path = [rootDir stringByAppendingPathComponent:roll.number];
            NSMutableArray *filesInSubdir = [FileUtil filesInDirectory:path
                extensionSet:[NSSet setWithObjects:@"jpg", @"png", nil]
                recursive:NO absolutePaths:NO];
            
            if (!filesInSubdir) {
                [rollsToHide addObject:roll.number];
                roll.needsDelete = YES;
                continue;
            }
            
            NSMutableSet *existingFiles = [NSMutableSet setWithArray:filesInSubdir];
            
            for (FrameModel *frame in roll.frames) {
                NSString *filename = [frame.name stringByAppendingPathExtension:frame.extension];
                NSString *filepath = [path stringByAppendingPathComponent:filename];
                
                if ([existingFiles containsObject:filename]) {
                    [existingFiles removeObject:filename];
                    
                    NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:filepath error:nil];
                    
                    if (fileAttrs) {
                        if ([frame.lastModified compare:fileAttrs.fileModificationDate] != NSOrderedSame) {
                            CGSize size;
                            NSUInteger orientation;
                            
                            if ([ImageUtil getImageProperties:filepath size:&size type:frame.imageType orientation:&orientation]) {
                                frame.filesize = fileAttrs.fileSize;
                                frame.lastModified = fileAttrs.fileModificationDate;
                                frame.fullsizeSent = NO;
                                frame.thumbsSent = NO;
                                frame.width = size.width;
                                frame.height = size.height;
                                frame.orientation = orientation;
                            } else {
                                // image is corrupt
                                [framesToHide addObject:@[roll.number, frame.name, frame.extension]];
                                frame.needsDelete = YES;
                            }
                        } else {
                            // frame.needsReload = NO;
                        }
                        
                        if (!frame.needsDelete) {
                            roll.totalFrameSize += fileAttrs.fileSize;
                        }
                    } else {
                        [framesToHide addObject:@[roll.number, frame.name, frame.extension]];
                        frame.needsDelete = YES;
                    }
                } else {
                    [framesToHide addObject:@[roll.number, frame.name, frame.extension]];
                    frame.needsDelete = YES;
                }
            }
            
            NSIndexSet *frameIndexesToRemove = [roll.frames
                indexesOfObjectsPassingTest:^BOOL(FrameModel *frame, NSUInteger idx, BOOL *stop) {
                    return frame.needsDelete;
                }
            ];
            
            [roll.frames removeObjectsAtIndexes:frameIndexesToRemove];
            
            for (NSString *newlyAddedFile in existingFiles) {
                newlyAdded = YES;
                
                FrameModel *frame = [FrameModel new];
                frame.name = [newlyAddedFile stringByDeletingPathExtension];
                frame.extension = newlyAddedFile.pathExtension;
                frame.newlyAdded = YES;
                [roll.frames addObject:frame];
            }
        } else {
            [rollsToHide addObject:roll.number];
            roll.needsDelete = YES;
        }
    }
    
    NSIndexSet *rollIndexesToRemove = [rolls
        indexesOfObjectsPassingTest:^BOOL(RollModel *roll, NSUInteger idx, BOOL *stop) {
            return roll.needsDelete;
        }
    ];
    
    [rolls removeObjectsAtIndexes:rollIndexesToRemove];
    
    for (NSString *newlyAddedDir in existingDirs) {
        NSString *path = [rootDir stringByAppendingPathComponent:newlyAddedDir];
        NSMutableArray *filesInSubdir = [FileUtil filesInDirectory:path
            extensionSet:[NSSet setWithObjects:@"jpg", @"png", nil] recursive:NO absolutePaths:NO];
        
        if (!filesInSubdir) {
            continue;
        }
        
        newlyAdded = YES;
        
        RollModel *roll = [RollModel new];
        roll.number = newlyAddedDir;
        roll.newlyAdded = YES;
        roll.frames = [NSMutableArray new];
        [rolls addObject:roll];

        for (NSString *newlyAddedFile in filesInSubdir) {
            FrameModel *frame = [FrameModel new];
            frame.name = [newlyAddedFile stringByDeletingPathExtension];
            frame.extension = newlyAddedFile.pathExtension;
            frame.newlyAdded = YES;
            [roll.frames addObject:frame];
        }
    }
}

- (void)ignoreNewlyAdded
{
    NSIndexSet *rollIndexesToRemove = [rolls
        indexesOfObjectsPassingTest:^BOOL(RollModel *roll, NSUInteger idx, BOOL *stop) {
            return roll.newlyAdded;
        }
    ];
    
    [rolls removeObjectsAtIndexes:rollIndexesToRemove];
    
    for (RollModel *roll in rolls) {
        NSIndexSet *frameIndexesToRemove = [roll.frames
            indexesOfObjectsPassingTest:^BOOL(FrameModel *frame, NSUInteger idx, BOOL *stop) {
                return frame.newlyAdded;
            }
        ];
        
        [roll.frames removeObjectsAtIndexes:frameIndexesToRemove];
    }
    
    newlyAdded = NO;
}

- (void)includeNewlyAdded
{
    for (RollModel *roll in rolls) {
        if (roll.newlyAdded) {
            roll.newlyAdded = NO;
        }

        NSString *path = [rootDir stringByAppendingPathComponent:roll.number];

        for (FrameModel *frame in roll.frames) {
            if (frame.newlyAdded) {
                NSString *filename = [frame.name stringByAppendingPathExtension:frame.extension];
                NSString *filepath = [path stringByAppendingPathComponent:filename];
                
                NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:filepath error:nil];
                
                if (fileAttrs) {
                    CGSize size;
                    NSUInteger orientation;
                    
                    if ([ImageUtil getImageProperties:filepath size:&size type:frame.imageType orientation:&orientation]) {
                        frame.filesize = fileAttrs.fileSize;
                        frame.lastModified = fileAttrs.fileModificationDate;
                        frame.width = size.width;
                        frame.height = size.height;
                        frame.orientation = orientation;
                        frame.fullsizeSent = NO;
                        frame.thumbsSent = NO;
                        frame.newlyAdded = NO;
                        roll.totalFrameSize += fileAttrs.fileSize;
                    } else {
                        // image is corrupt
                    }
                }
            }
        }
        
        NSIndexSet *frameIndexesToRemove = [roll.frames
            indexesOfObjectsPassingTest:^BOOL(FrameModel *frame, NSUInteger idx, BOOL *stop) {
                return frame.newlyAdded;
            }
        ];
        
        [roll.frames removeObjectsAtIndexes:frameIndexesToRemove];
    }
    
    newlyAdded = NO;
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
