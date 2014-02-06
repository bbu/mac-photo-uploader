#import <Foundation/Foundation.h>

@interface RollModel : NSObject <NSCoding>

@property NSString *rollNumber;
@property NSString *photographer, *photographerID;
@property (readonly) NSInteger totalFrameSize;
@property (readonly) NSObject *greenScreen;
@property (readonly) NSMutableArray *frames;

@end
