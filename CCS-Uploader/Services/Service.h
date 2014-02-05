#import <Foundation/Foundation.h>

@interface ServiceResult : NSObject
@property NSError *error;
@end

@interface Service : NSObject {
@protected
    NSMutableData *responseData;
    NSMutableString *lastValue;
    NSNumberFormatter *numberFormatter;
    BOOL started;
    NSURLConnection *urlConnection;
    void (^finished)(id result);
}

- (BOOL)isRunning;
- (void)cancel;
+ (NSMutableURLRequest *)postRequestWithURL:(NSString *)urlString body:(NSString *)body;

@end
