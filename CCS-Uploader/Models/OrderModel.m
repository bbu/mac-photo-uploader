#import "OrderModel.h"

#define kEventFolderExtension @"ccsevent"
#define kOrderFileExtension @"ccsorder"
#define kTempFolderName @".ccstmp"
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

- (void)addNewImages:(NSInteger)rollIndex urls:(NSArray *)urls frameNumberLimit:(NSInteger)frameNumberLimit
    autoNumberRolls:(BOOL)autoNumberRolls autoNumberFrames:(BOOL)autoNumberFrames
{
    NSError *error = nil;
    NSString *tempDir = [rootDir stringByAppendingPathComponent:kTempFolderName];
    [fileMgr removeItemAtPath:tempDir error:nil];
    
    if (![fileMgr createDirectoryAtPath:tempDir withIntermediateDirectories:NO attributes:nil error:&error]) {
        NSLog(@"Could not create temporary directory \"%@\".", tempDir);
        return;
    }
    
    RollModel *tempRoll = [RollModel new];
    tempRoll.frames = [NSMutableArray new];
    NSString *derivedRollName = nil;
    
    for (NSURL *url in urls) {
        BOOL isDirectory;
        BOOL fileExists = [fileMgr fileExistsAtPath:url.path isDirectory:&isDirectory];
        
        if (fileExists) {
            CGSize size;
            NSUInteger orientation;
            NSMutableString *imageType = [NSMutableString new];
            
            if (isDirectory) {
                NSMutableArray *filesToCopy = [FileUtil filesInDirectory:url.path
                    extensionSet:[NSSet setWithObjects:@"jpg", @"png", nil] recursive:YES absolutePaths:YES];
                
                if (!filesToCopy) {
                    continue;
                }
                
                if (!autoNumberRolls && !derivedRollName) {
                    derivedRollName = url.path.lastPathComponent;
                }
                
                for (NSString *fileToCopy in filesToCopy) {
                    if ([ImageUtil getImageProperties:fileToCopy size:&size type:imageType orientation:&orientation]) {
                        NSString *destFilepath = [tempDir stringByAppendingPathComponent:fileToCopy.lastPathComponent];
                        
                        for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:destFilepath]; dupNumber++) {
                            destFilepath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%ld.%@",
                                [fileToCopy.lastPathComponent stringByDeletingPathExtension], dupNumber, fileToCopy.pathExtension]];
                        }
                        
                        if ([fileMgr copyItemAtPath:fileToCopy toPath:destFilepath error:nil]) {
                            FrameModel *newFrame = [FrameModel new];
                            
                            newFrame.name = [destFilepath.lastPathComponent stringByDeletingPathExtension];
                            newFrame.extension = destFilepath.pathExtension;
                            newFrame.width = size.width;
                            newFrame.height = size.height;
                            newFrame.orientation = orientation;
                            newFrame.imageType = imageType;
                            
                            [tempRoll.frames addObject:newFrame];
                        }
                    }
                }
            } else {
                NSString *fileToCopy = url.path;

                if ([ImageUtil getImageProperties:fileToCopy size:&size type:imageType orientation:&orientation]) {
                    NSString *destFilepath = [tempDir stringByAppendingPathComponent:fileToCopy.lastPathComponent];
                    
                    for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:destFilepath]; dupNumber++) {
                        destFilepath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%ld.%@",
                            [fileToCopy.lastPathComponent stringByDeletingPathExtension], dupNumber, fileToCopy.pathExtension]];
                    }
                    
                    if ([fileMgr copyItemAtPath:fileToCopy toPath:destFilepath error:nil]) {
                        FrameModel *newFrame = [FrameModel new];
                        
                        newFrame.name = [destFilepath.lastPathComponent stringByDeletingPathExtension];
                        newFrame.extension = destFilepath.pathExtension;
                        newFrame.width = size.width;
                        newFrame.height = size.height;
                        newFrame.orientation = orientation;
                        newFrame.imageType = imageType;
                        
                        [tempRoll.frames addObject:newFrame];
                    }
                }
            }
        }
    }
    
    RollModel *targetRoll = (rollIndex == -1) ? nil : [rolls objectAtIndex:rollIndex];
    
    if (!targetRoll) {
        NSInteger rollsToCreate = tempRoll.frames.count ?
            (tempRoll.frames.count - 1) / frameNumberLimit + 1 : 0;
        
        for (NSInteger i = 0, nextRollNumber = [self deriveNextRollNumber]; i < rollsToCreate; ++i, ++nextRollNumber) {
            RollModel *newRoll = [RollModel new];
            
            newRoll.frames = [NSMutableArray new];
            newRoll.number = (autoNumberRolls || !derivedRollName) ?
                [NSString stringWithFormat:@"%05ld", nextRollNumber] : derivedRollName;
            
            NSString *rollPath = [rootDir stringByAppendingPathComponent:newRoll.number];
            
            for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:rollPath]; ++dupNumber) {
                newRoll.number = (autoNumberRolls || !derivedRollName) ?
                    [NSString stringWithFormat:@"%05ld_%ld", nextRollNumber, dupNumber] :
                    [NSString stringWithFormat:@"%@_%ld", derivedRollName, dupNumber];
                
                rollPath = [rootDir stringByAppendingPathComponent:newRoll.number];
            }
            
            if (![fileMgr createDirectoryAtPath:rollPath withIntermediateDirectories:NO attributes:nil error:nil]) {
                continue;
            }
            
            NSInteger startIndex = i * frameNumberLimit;
            NSInteger endIndex = startIndex + frameNumberLimit;
            
            if (endIndex > tempRoll.frames.count) {
                endIndex = tempRoll.frames.count;
            }
            
            for (NSInteger j = startIndex, nextFrameNumber = 1; j < endIndex; ++j, ++nextFrameNumber) {
                FrameModel *frame = tempRoll.frames[j];
                
                NSString *fileToMove = [tempDir stringByAppendingPathComponent:[frame.name stringByAppendingPathExtension:frame.extension]];
                
                if (autoNumberFrames) {
                    frame.name = [NSString stringWithFormat:@"%04ld", nextFrameNumber];
                }
                
                NSString *destFilepath = [rollPath stringByAppendingPathComponent:
                    [frame.name stringByAppendingPathExtension:frame.extension]];
                
                if ([fileMgr moveItemAtPath:fileToMove toPath:destFilepath error:nil]) {
                    NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:destFilepath error:nil];
                    
                    if (fileAttrs) {
                        frame.filesize = fileAttrs.fileSize;
                        frame.lastModified = fileAttrs.fileModificationDate;
                        newRoll.totalFrameSize += fileAttrs.fileSize;
                        [newRoll.frames addObject:frame];
                    }
                }
            }
            
            [rolls addObject:newRoll];
        }
    } else {
        NSInteger framesRemaining = frameNumberLimit - targetRoll.frames.count;
        NSInteger framesMoved = 0;
        
        if (framesRemaining > 0) {
            NSString *rollPath = [rootDir stringByAppendingPathComponent:targetRoll.number];
            
            for (NSInteger nextFrameNumber = [self deriveNextFrameNumber:targetRoll];
                framesMoved < framesRemaining && framesMoved < tempRoll.frames.count;
                ++framesMoved, ++nextFrameNumber) {
                
                FrameModel *frame = tempRoll.frames[framesMoved];
                
                NSString *fileToMove = [tempDir stringByAppendingPathComponent:[frame.name stringByAppendingPathExtension:frame.extension]];
                NSString *originalFrameName = nil;
                
                if (autoNumberFrames) {
                    frame.name = [NSString stringWithFormat:@"%04ld", nextFrameNumber];
                } else {
                    originalFrameName = [frame.name copy];
                }
                
                NSString *destFilepath = [rollPath stringByAppendingPathComponent:
                    [frame.name stringByAppendingPathExtension:frame.extension]];
                
                for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:destFilepath]; ++dupNumber) {
                    frame.name = autoNumberFrames ?
                        [NSString stringWithFormat:@"%04ld_%ld", nextFrameNumber, dupNumber] :
                        [NSString stringWithFormat:@"%@_%ld", originalFrameName, dupNumber];

                    destFilepath = [rollPath stringByAppendingPathComponent:
                        [frame.name stringByAppendingPathExtension:frame.extension]];
                }
                
                if ([fileMgr moveItemAtPath:fileToMove toPath:destFilepath error:&error]) {
                    NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:destFilepath error:nil];
                    
                    if (fileAttrs) {
                        frame.filesize = fileAttrs.fileSize;
                        frame.lastModified = fileAttrs.fileModificationDate;
                        targetRoll.totalFrameSize += fileAttrs.fileSize;
                        [targetRoll.frames addObject:frame];
                    }
                }
            }
        }
        
        NSInteger rollsToCreate = tempRoll.frames.count - framesMoved ?
            (tempRoll.frames.count - framesMoved - 1) / frameNumberLimit + 1 : 0;
        
        for (NSInteger i = 0, nextRollNumber = [self deriveNextRollNumber]; i < rollsToCreate; ++i, ++nextRollNumber) {
            RollModel *newRoll = [RollModel new];
            
            newRoll.frames = [NSMutableArray new];
            newRoll.number = (autoNumberRolls || !derivedRollName) ?
                [NSString stringWithFormat:@"%05ld", nextRollNumber] : derivedRollName;
            
            NSString *rollPath = [rootDir stringByAppendingPathComponent:newRoll.number];
            
            for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:rollPath]; ++dupNumber) {
                newRoll.number = (autoNumberRolls || !derivedRollName) ?
                    [NSString stringWithFormat:@"%05ld_%ld", nextRollNumber, dupNumber] :
                    [NSString stringWithFormat:@"%@_%ld", derivedRollName, dupNumber];
                
                rollPath = [rootDir stringByAppendingPathComponent:newRoll.number];
            }
            
            if (![fileMgr createDirectoryAtPath:rollPath withIntermediateDirectories:NO attributes:nil error:nil]) {
                continue;
            }
            
            NSInteger startIndex = framesMoved + i * frameNumberLimit;
            NSInteger endIndex = framesMoved + startIndex + frameNumberLimit;
            
            if (endIndex > tempRoll.frames.count - framesMoved) {
                endIndex = tempRoll.frames.count - framesMoved;
            }
            
            for (NSInteger j = startIndex, nextFrameNumber = 1; j < endIndex; ++j, ++nextFrameNumber) {
                FrameModel *frame = tempRoll.frames[j];
                
                NSString *fileToMove = [tempDir stringByAppendingPathComponent:[frame.name stringByAppendingPathExtension:frame.extension]];
                
                if (autoNumberFrames) {
                    frame.name = [NSString stringWithFormat:@"%04ld", nextFrameNumber];
                }
                
                NSString *destFilepath = [rollPath stringByAppendingPathComponent:
                    [frame.name stringByAppendingPathExtension:frame.extension]];
                
                if ([fileMgr moveItemAtPath:fileToMove toPath:destFilepath error:nil]) {
                    NSDictionary *fileAttrs = [fileMgr attributesOfItemAtPath:destFilepath error:nil];
                    
                    if (fileAttrs) {
                        frame.filesize = fileAttrs.fileSize;
                        frame.lastModified = fileAttrs.fileModificationDate;
                        newRoll.totalFrameSize += fileAttrs.fileSize;
                        [newRoll.frames addObject:frame];
                    }
                }
            }
            
            [rolls addObject:newRoll];

        }
    }
    
    [fileMgr removeItemAtPath:tempDir error:nil];
}

- (NSInteger)deriveNextRollNumber
{
    NSInteger maxDerivedNumber = 0;
    
    for (RollModel *roll in rolls) {
        NSInteger dirnameAsInt = labs(roll.number.integerValue);
        
        if (dirnameAsInt > maxDerivedNumber) {
            maxDerivedNumber = dirnameAsInt;
        }
    }
    
    if (maxDerivedNumber >= 99999) {
        return 1;
    }
    
    return maxDerivedNumber + 1;
}

- (NSInteger)deriveNextFrameNumber:(RollModel *)roll
{
    NSInteger maxDerivedNumber = 0;
    
    for (FrameModel *frame in roll.frames) {
        NSInteger frameAsInt = labs(frame.name.integerValue);
        
        if (frameAsInt > maxDerivedNumber) {
            maxDerivedNumber = frameAsInt;
        }
    }
    
    if (maxDerivedNumber >= 9999) {
        return 1;
    }
    
    return maxDerivedNumber + 1;
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
