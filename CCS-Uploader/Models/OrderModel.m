#import "OrderModel.h"

#define kOrderFileExtension @"ccsorder"
#define kDefaultLocalFolder @"Images/%@"

#define FAIL(retval, fmt, ...) \
    ({ \
        NSString *errorMessage = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; \
        NSLog(@"%s(%u): %@", __FILE__, __LINE__, errorMessage); \
        \
        if (error) { \
            *error = [NSError errorWithDomain:@"Domain" code:1 userInfo:@{NSLocalizedDescriptionKey:errorMessage}]; \
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
    for (RollModel *roll in rolls) {
        for (FrameModel *frame in roll.frames) {
            
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
