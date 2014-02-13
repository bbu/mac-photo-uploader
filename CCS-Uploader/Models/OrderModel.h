#import <Foundation/Foundation.h>

#import "RollModel.h"
#import "FrameModel.h"

#import "../Services/ListEventsService.h"
#import "../Services/CheckOrderNumberService.h"

#import "../Utils/FileUtil.h"
#import "../Utils/ImageUtil.h"

@interface OrderModel : NSObject <NSCoding> {
    
}

@property EventRow *eventRow;
@property (readonly) NSString *rootDir;
@property (readonly) NSMutableArray *rolls;
@property (readonly) NSMutableArray *rollsToHide, *framesToHide;

- (id)initWithEventRow:(EventRow *)event error:(NSError **)error;
- (void)diffWithExistingFiles;
- (BOOL)save;
- (BOOL)delete;

@end
