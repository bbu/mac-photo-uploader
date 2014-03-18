#import <Foundation/Foundation.h>

@interface RollModel : NSObject <NSCoding>
@property NSString *number;
@property NSString *photographer, *photographerID;
@property NSInteger totalFrameSize;
@property NSObject *greenScreen;
@property NSMutableArray *frames;
@property BOOL framesHaveErrors, needsDelete, newlyAdded;
@end
