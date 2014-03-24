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
    BOOL autoCategorizeImages;
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
@synthesize autoCategorizeImages;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    if (self) {
        eventRow = [decoder decodeObjectForKey:@"eventRow"];
        rootDir = [decoder decodeObjectForKey:@"rootDir"];
        rolls = [decoder decodeObjectForKey:@"rolls"];
        autoCategorizeImages = [decoder decodeBoolForKey:@"autoCategorizeImages"];
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
        return FAIL(nil, @"Could not get path to order file!");
    }
    
    OrderModel *unarchivedOrder = [NSKeyedUnarchiver unarchiveObjectWithFile:pathToOrderFile];

    if (unarchivedOrder) {
        rolls = unarchivedOrder.rolls ? unarchivedOrder.rolls : [NSMutableArray new];
        rootDir = unarchivedOrder.rootDir;
        autoCategorizeImages = unarchivedOrder.autoCategorizeImages;
        
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

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:eventRow forKey:@"eventRow"];
    [encoder encodeObject:rootDir forKey:@"rootDir"];
    [encoder encodeObject:rolls forKey:@"rolls"];
    [encoder encodeBool:autoCategorizeImages forKey:@"autoCategorizeImages"];
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
    NSSet *allowedExtensions = [NSSet setWithObjects:@"jpg", @"jpeg", @"png", nil];
    
    for (RollModel *roll in rolls) {
        roll.framesHaveErrors = NO;
        
        if ([existingDirs containsObject:roll.number]) {
            [existingDirs removeObject:roll.number];

            roll.totalFrameSize = 0;

            if (!roll.frames) {
                roll.frames = [NSMutableArray new];
            }
            
            NSString *path = [rootDir stringByAppendingPathComponent:roll.number];
            
            NSMutableArray *filesInSubdir = [FileUtil filesInDirectory:path
                extensionSet:allowedExtensions recursive:NO absolutePaths:NO];
            
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
                            [self checkFrameImage:frame filename:filepath];
                            
                            frame.filesize = fileAttrs.fileSize;
                            frame.lastModified = fileAttrs.fileModificationDate;
                            frame.fullsizeSent = NO;
                            frame.thumbsSent = NO;
                        }
                        
                        if (frame.imageErrors.length != 0) {
                            roll.framesHaveErrors = YES;
                        }
                        
                        roll.totalFrameSize += fileAttrs.fileSize;
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
            extensionSet:allowedExtensions recursive:NO absolutePaths:NO];
        
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
                    [self checkFrameImage:frame filename:filepath];
                    
                    frame.filesize = fileAttrs.fileSize;
                    frame.lastModified = fileAttrs.fileModificationDate;
                    frame.fullsizeSent = NO;
                    frame.thumbsSent = NO;
                    frame.newlyAdded = NO;
                    roll.totalFrameSize += fileAttrs.fileSize;
                    
                    if (frame.imageErrors.length != 0) {
                        roll.framesHaveErrors = YES;
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

- (void)addNewImages:(NSArray *)URLs inRoll:(NSInteger)rollIndex framesPerRoll:(NSInteger)framesPerRoll
    autoNumberRolls:(BOOL)autoNumberRolls autoNumberFrames:(BOOL)autoNumberFrames photographer:(NSString *)photographer
    statusField:(NSTextField *)statusField errors:(NSMutableString *)errors
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
    NSInteger copiedFiles = 0;
    
    NSSet *allowedExtensions = [NSSet setWithObjects:@"jpg", @"jpeg", @"png", nil];
    
    for (NSURL *url in URLs) {
        BOOL isDirectory;
        BOOL fileExists = [fileMgr fileExistsAtPath:url.path isDirectory:&isDirectory];
        
        if (fileExists) {
            if (isDirectory) {
                NSMutableArray *filesToCopy = [FileUtil filesInDirectory:url.path
                    extensionSet:allowedExtensions recursive:YES absolutePaths:YES];
                
                if (!filesToCopy) {
                    continue;
                }
                
                if (!autoNumberRolls && !derivedRollName) {
                    derivedRollName = url.path.lastPathComponent;
                }
                
                for (NSString *fileToCopy in filesToCopy) {
                    NSString *destFilepath = [tempDir stringByAppendingPathComponent:fileToCopy.lastPathComponent];
                    
                    for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:destFilepath]; dupNumber++) {
                        destFilepath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%ld.%@",
                            [fileToCopy.lastPathComponent stringByDeletingPathExtension], dupNumber, fileToCopy.pathExtension]];
                    }
                    
                    NSError *error = nil;
                    
                    if ([fileMgr copyItemAtPath:fileToCopy toPath:destFilepath error:&error]) {
                        FrameModel *newFrame = [FrameModel new];
                        
                        newFrame.name = [destFilepath.lastPathComponent stringByDeletingPathExtension];
                        newFrame.extension = destFilepath.pathExtension;
                        [tempRoll.frames addObject:newFrame];
                        
                        [statusField performSelectorOnMainThread:@selector(setStringValue:)
                            withObject:[NSString stringWithFormat:@"%ld files copied", ++copiedFiles] waitUntilDone:YES];
                    } else {
                        [errors appendFormat:@"%@: %@\r", fileToCopy, error.localizedDescription];
                    }
                }
            } else {
                NSString *fileToCopy = url.path;
                
                if ([allowedExtensions containsObject:fileToCopy.pathExtension.lowercaseString]) {
                    NSString *destFilepath = [tempDir stringByAppendingPathComponent:fileToCopy.lastPathComponent];
                    
                    for (NSInteger dupNumber = 1; [fileMgr fileExistsAtPath:destFilepath]; dupNumber++) {
                        destFilepath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%ld.%@",
                            [fileToCopy.lastPathComponent stringByDeletingPathExtension], dupNumber, fileToCopy.pathExtension]];
                    }
                    
                    NSError *error = nil;
                    
                    if ([fileMgr copyItemAtPath:fileToCopy toPath:destFilepath error:&error]) {
                        FrameModel *newFrame = [FrameModel new];
                        
                        newFrame.name = [destFilepath.lastPathComponent stringByDeletingPathExtension];
                        newFrame.extension = destFilepath.pathExtension;
                        [tempRoll.frames addObject:newFrame];
                        
                        [statusField performSelectorOnMainThread:@selector(setStringValue:)
                            withObject:[NSString stringWithFormat:@"%ld files copied", ++copiedFiles] waitUntilDone:YES];
                    } else {
                        [errors appendFormat:@"%@: %@\r", fileToCopy, error.localizedDescription];
                    }
                } else {
                    [errors appendFormat:@"%@: file type not supported\r", fileToCopy];
                }
            }
        }
    }
    
    copiedFiles = 0;
    RollModel *targetRoll = (rollIndex == -1) ? nil : [rolls objectAtIndex:rollIndex];
    
    if (!targetRoll) {
        NSInteger rollsToCreate = tempRoll.frames.count ?
            (tempRoll.frames.count - 1) / framesPerRoll + 1 : 0;
        
        for (NSInteger i = 0, nextRollNumber = [self deriveNextRollNumber]; i < rollsToCreate; ++i, ++nextRollNumber) {
            RollModel *newRoll = [RollModel new];
            
            newRoll.frames = [NSMutableArray new];
            newRoll.imagesAutoRenamed = autoNumberFrames;
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
            
            NSInteger startIndex = i * framesPerRoll;
            NSInteger endIndex = startIndex + framesPerRoll;
            
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
                        [self checkFrameImage:frame filename:destFilepath];
                        newRoll.totalFrameSize += fileAttrs.fileSize;
                        newRoll.photographer = photographer;
                        [newRoll.frames addObject:frame];
                        
                        if (frame.imageErrors.length != 0) {
                            newRoll.framesHaveErrors = YES;
                        }
                        
                        [statusField performSelectorOnMainThread:@selector(setStringValue:)
                            withObject:[NSString stringWithFormat:@"%ld images added", ++copiedFiles] waitUntilDone:YES];
                    }
                }
            }
            
            [rolls addObject:newRoll];
        }
    } else {
        NSInteger framesRemaining = framesPerRoll - targetRoll.frames.count;
        NSInteger framesInTargetRoll = 0;
        
        if (framesRemaining > 0) {
            targetRoll.imagesAutoRenamed = autoNumberFrames;
            targetRoll.imagesViewed = NO;
            
            NSString *rollPath = [rootDir stringByAppendingPathComponent:targetRoll.number];
            
            for (NSInteger nextFrameNumber = [self deriveNextFrameNumber:targetRoll];
                framesInTargetRoll < framesRemaining && framesInTargetRoll < tempRoll.frames.count;
                ++framesInTargetRoll, ++nextFrameNumber) {
                
                FrameModel *frame = tempRoll.frames[framesInTargetRoll];
                
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
                        [self checkFrameImage:frame filename:destFilepath];
                        targetRoll.totalFrameSize += fileAttrs.fileSize;
                        [targetRoll.frames addObject:frame];
                        
                        if (frame.imageErrors.length != 0) {
                            targetRoll.framesHaveErrors = YES;
                        }
                        
                        [statusField performSelectorOnMainThread:@selector(setStringValue:)
                            withObject:[NSString stringWithFormat:@"%ld images added", ++copiedFiles] waitUntilDone:YES];
                    }
                }
            }
        }
        
        NSInteger rollsToCreate = tempRoll.frames.count - framesInTargetRoll ?
            (tempRoll.frames.count - framesInTargetRoll - 1) / framesPerRoll + 1 : 0;
        
        for (NSInteger i = 0, nextRollNumber = [self deriveNextRollNumber]; i < rollsToCreate; ++i, ++nextRollNumber) {
            RollModel *newRoll = [RollModel new];
            
            newRoll.frames = [NSMutableArray new];
            newRoll.imagesAutoRenamed = autoNumberFrames;
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
            
            NSInteger startIndex = framesInTargetRoll + i * framesPerRoll;
            NSInteger endIndex = startIndex + framesPerRoll;
            
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
                        [self checkFrameImage:frame filename:destFilepath];
                        newRoll.totalFrameSize += fileAttrs.fileSize;
                        newRoll.photographer = photographer;
                        [newRoll.frames addObject:frame];
                        
                        if (frame.imageErrors.length != 0) {
                            newRoll.framesHaveErrors = YES;
                        }
                        
                        [statusField performSelectorOnMainThread:@selector(setStringValue:)
                            withObject:[NSString stringWithFormat:@"%ld images added", ++copiedFiles] waitUntilDone:YES];
                    }
                }
            }
            
            [rolls addObject:newRoll];
        }
    }
    
    [fileMgr removeItemAtPath:tempDir error:nil];
}

- (void)checkFrameImage:(FrameModel *)frame filename:(NSString *)filename
{
    CGSize size = CGSizeZero;
    NSUInteger orientation = 0;
    
    frame.imageErrors = [NSMutableString new];
    frame.imageType = [NSMutableString new];
    
    [ImageUtil getImageProperties:filename size:&size type:frame.imageType
        orientation:&orientation errors:frame.imageErrors];
    
    frame.width = size.width;
    frame.height = size.height;
    frame.orientation = orientation;
}

- (void)deleteRollAtIndex:(NSInteger)rollIndex
{
    RollModel *targetRoll = (rollIndex == -1) ? nil : [rolls objectAtIndex:rollIndex];

    if (targetRoll) {
        NSString *dirToDelete = [rootDir stringByAppendingPathComponent:targetRoll.number];
        [fileMgr removeItemAtPath:dirToDelete error:nil];
        [rollsToHide addObject:targetRoll.number];
        [rolls removeObjectAtIndex:rollIndex];
    }
}

- (BOOL)renameRollAtIndex:(NSInteger)rollIndex newName:(NSString *)newName error:(NSError **)error
{
    RollModel *targetRoll = (rollIndex == -1) ? nil : [rolls objectAtIndex:rollIndex];
    
    if (targetRoll) {
        NSString *oldRollPath = [rootDir stringByAppendingPathComponent:targetRoll.number];
        NSString *newRollPath = [rootDir stringByAppendingPathComponent:newName];
        
        if ([fileMgr moveItemAtPath:oldRollPath toPath:newRollPath error:error]) {
            targetRoll.number = [newName copy];
            return YES;
        }
    }
    
    return NO;
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

- (BOOL)save
{
    NSString *path = [OrderModel pathToOrderFile:eventRow.orderNumber];
    return [NSKeyedArchiver archiveRootObject:self toFile:path];
}

- (BOOL)delete
{
    NSString *path = [OrderModel pathToOrderFile:eventRow.orderNumber];
    [fileMgr removeItemAtPath:rootDir error:nil];
    return [fileMgr removeItemAtPath:path error:nil];
}

@end
