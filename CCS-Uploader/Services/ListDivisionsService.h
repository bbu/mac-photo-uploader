#import <Foundation/Foundation.h>

@interface DivisionRow : NSObject
@property NSString *divisionID;
@property NSString *eventID;
@property NSString *name;
@property NSString *nameOverride;
@property NSString *nameWithModID;
@property NSString *modCode;
@end

@interface ListDivisionsResult : NSObject
@property NSError *error;
@property BOOL loginSuccess, processSuccess;
@property NSMutableArray *divisions;
@end

@interface ListDivisionsService : NSObject

- (BOOL)startListDivisions:(NSString *)email password:(NSString *)password eventID:(NSString *)eventID
    complete:(void (^)(ListDivisionsResult *result))block;

@end
