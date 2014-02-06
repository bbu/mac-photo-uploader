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

@end
