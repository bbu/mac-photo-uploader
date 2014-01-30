#import <Foundation/Foundation.h>

@interface Service : NSObject {
@protected
    NSMutableData *responseData;
    NSMutableString *lastValue;
    BOOL started;
    NSURLConnection *urlConnection;
}

- (void)cancel;
+ (NSMutableURLRequest *)postRequestWithURL:(NSString *)urlString body:(NSString *)body;

@end
