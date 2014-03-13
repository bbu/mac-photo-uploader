#import <Foundation/Foundation.h>

#import "RollModel.h"
#import "FrameModel.h"

#import "../Services/ListEventsService.h"
#import "../Services/CheckOrderNumberService.h"

#import "../Utils/FileUtil.h"
#import "../Utils/ImageUtil.h"

@interface OrderModel : NSObject <NSCoding>
@property EventRow *eventRow;
@property (readonly) NSString *rootDir;
@property (readonly) NSMutableArray *rolls;
@property (readonly) NSMutableArray *rollsToHide, *framesToHide;
@property (readonly) BOOL newlyAdded;

- (id)initWithEventRow:(EventRow *)event error:(NSError **)error;
- (void)diffWithExistingFiles;
- (void)ignoreNewlyAdded;
- (void)includeNewlyAdded;
- (void)addNewImages:(NSArray *)urls inRoll:(NSInteger)rollIndex framesPerRoll:(NSInteger)framesPerRoll
    autoNumberRolls:(BOOL)autoNumberRolls autoNumberFrames:(BOOL)autoNumberFrames
    statusField:(NSTextField *)statusField errors:(NSMutableString *)errors;

- (void)deleteRollAtIndex:(NSInteger)rollIndex;
- (BOOL)renameRollAtIndex:(NSInteger)rollIndex newName:(NSString *)newName error:(NSError **)error;
- (BOOL)save;
- (BOOL)delete;

@end
