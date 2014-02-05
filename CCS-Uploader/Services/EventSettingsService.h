#import <Foundation/Foundation.h>

#import "Service.h"

@interface EventSettingsTransferRow : NSObject
@property NSInteger createPreview;
@property NSInteger createThumbnail;
@property NSInteger previewWatermarkID;
@property NSInteger thumbnailWatermarkID;
@property NSInteger ftp;
@property NSString *webServiceURL;
@property NSUInteger createMediumRes;
@end

@interface EventSettingsImageRow : NSObject
@property NSInteger quality;
@property NSInteger maxSide;
@property NSInteger sharpen;
@property NSInteger resizeMethod;
@end

@interface EventSettingsWatermarkRow : NSObject
@property NSInteger watermarkID;
@property NSString *description;
@property NSString *hFile, *vFile;
@property NSData *hFileData, *vFileData;
@end

@interface EventSettingsResult : ServiceResult
@property NSString *status, *message;
@property EventSettingsTransferRow *transferSettings;
@property EventSettingsImageRow *previewSettings;
@property EventSettingsImageRow *thumbnailSettings;
@property EventSettingsWatermarkRow *watermarkSettings;
@property EventSettingsImageRow *pngSettings;
@property EventSettingsImageRow *mediumResSettings;
@end

@interface EventSettingsService : Service

- (BOOL)startGetEventSettings:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber complete:(void (^)(EventSettingsResult *result))block;

@end
