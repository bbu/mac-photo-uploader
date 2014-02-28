#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ServiceRoot) {
    kServiceRootQuicPost = 0,
    kServiceRootCore = 1,
};

@interface ServiceResult : NSObject
@property NSError *error;
@end

@interface Service : NSObject {
@protected
    ServiceRoot effectiveServiceRoot;
    NSString *effectiveCoreDomain;
    NSMutableData *responseData;
    NSMutableString *lastValue;
    NSNumberFormatter *numberFormatter;
    BOOL started;
    NSURLConnection *urlConnection;
    void (^finished)(id result);
}

- (void)setEffectiveServiceRoot:(ServiceRoot)serviceRoot coreDomain:(NSString *)coreDomain;
- (void)cancel;
+ (NSMutableURLRequest *)postRequestWithURL:(NSString *)urlString body:(NSString *)body;

@property (readonly) BOOL started;

@end
