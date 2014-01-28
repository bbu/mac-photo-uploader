#import <Foundation/Foundation.h>

@interface EventRow : NSObject
@property NSString *eventID;
@property NSString *eventName;
@property NSString *orderNumber;
@property NSString *ccsAccount;
@property NSDate *eventDate;
@property NSString *marketID;
@property NSString *market;
@property NSString *location;
@property NSString *hostGroup;
@property BOOL isQuicPost;
@property BOOL autoCategorizeImages;
@end

@interface ListEventsResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@property NSMutableArray *events;
@end

@interface ListEventsService : NSObject

- (BOOL)startListEvents:(NSString *)email password:(NSString *)password
    filterDateRange:(BOOL)filterDateRange
    startDate:(NSDate *)startDate
    endDate:(NSDate *)endDate
    hideNullDates:(BOOL)hideNullDates
    hideActive:(BOOL)hideActive
    hideNonAssigned:(BOOL)hideNonAssigned
    hideNullOrderNumbers:(BOOL)hideNullOrderNumbers
    complete:(void (^)(ListEventsResult *result))block;

- (BOOL)startListEvent:(NSString *)email password:(NSString *)password
    orderNumber:(NSString *)orderNumber
    complete:(void (^)(ListEventsResult *result))block;

@end
