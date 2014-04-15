#import <Foundation/Foundation.h>

@interface RollModel : NSObject <NSCoding>
@property NSString *number;
@property NSString *photographer, *photographerID;
@property NSInteger totalFrameSize;
@property BOOL greenScreen;
@property NSMutableArray *frames;
@property BOOL imagesAutoRenamed, imagesViewed;
@property BOOL framesHaveErrors, preloaderRunning, wantsPreloaderForAll, wantsPreloaderForUnsent, needsDelete, newlyAdded;
@end
