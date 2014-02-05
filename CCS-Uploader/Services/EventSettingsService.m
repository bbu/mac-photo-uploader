#import "EventSettingsService.h"

@interface EventSettingsTransferRow () {
    NSInteger _createPreview;
    NSInteger _createThumbnail;
    NSInteger _previewWatermarkID;
    NSInteger _thumbnailWatermarkID;
    NSInteger _ftp;
    NSString *_webServiceURL;
    NSUInteger _createMediumRes;
}
@end

@implementation EventSettingsTransferRow
@end

@interface EventSettingsImageRow () {
    NSInteger _quality;
    NSInteger _maxSide;
    NSInteger _sharpen;
    NSInteger _resizeMethod;
}
@end

@implementation EventSettingsImageRow
@end

@interface EventSettingsWatermarkRow () {
    NSInteger _watermarkID;
    NSString *_description;
    NSString *_hFile, *_vFile;
    NSString *_hFileData, *_vFileData;
}
@end

@implementation EventSettingsWatermarkRow
@end

@interface EventSettingsResult () {
    NSString *_status, *_message;
    EventSettingsTransferRow *_transferSettings;
    EventSettingsImageRow *_previewSettings;
    EventSettingsImageRow *_thumbnailSettings;
    EventSettingsWatermarkRow *_watermarkSettings;
    EventSettingsImageRow *_pngSettings;
    EventSettingsImageRow *_mediumResSettings;
}
@end

@implementation EventSettingsResult
@end

@interface EventSettingsService () <NSURLConnectionDelegate, NSXMLParserDelegate> {
    EventSettingsImageRow *lastImageRow;
    EventSettingsResult *eventSettingsResult;
}
@end

@implementation EventSettingsService

- (NSString *)serviceURL
{
    return kCandidServiceRoot @"getEventSettings";
}

- (BOOL)startGetEventSettings:(NSString *)account password:(NSString *)password
    orderNumber:(NSString *)orderNumber complete:(void (^)(EventSettingsResult *result))block
{
    if (started) {
        return NO;
    }
    
    NSString *postBody = [NSString stringWithFormat:@"acctNo=%@&password=%@&orderNo=%@",
        [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
        [orderNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
    ];
    
    NSMutableURLRequest *request = [Service postRequestWithURL:[self serviceURL] body:postBody];
    
    eventSettingsResult = [EventSettingsResult new];
    lastImageRow = nil;
    finished = block;
    
    urlConnection = [NSURLConnection connectionWithRequest:request delegate:self];
    return started = YES;
}

#pragma mark - NSURLConnectionDelegate

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    urlConnection = nil, started = NO;
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
    parser.delegate = self;
    
    if ([parser parse]) {
        finished(eventSettingsResult);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    urlConnection = nil, started = NO, eventSettingsResult.error = error;
    finished(eventSettingsResult);
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    [lastValue setString:@""];
    
    if ([elementName isEqualToString:@"TransferSettings"]) {
        eventSettingsResult.transferSettings = [EventSettingsTransferRow new];
    } else if ([elementName isEqualToString:@"PreviewSettings"]) {
        eventSettingsResult.previewSettings = [EventSettingsImageRow new];
        lastImageRow = eventSettingsResult.previewSettings;
    } else if ([elementName isEqualToString:@"ThumbnailSettings"]) {
        eventSettingsResult.thumbnailSettings = [EventSettingsImageRow new];
        lastImageRow = eventSettingsResult.thumbnailSettings;
    } else if ([elementName isEqualToString:@"PNGSettings"]) {
        eventSettingsResult.pngSettings = [EventSettingsImageRow new];
        lastImageRow = eventSettingsResult.pngSettings;
    } else if ([elementName isEqualToString:@"MediumResSettings"]) {
        eventSettingsResult.mediumResSettings = [EventSettingsImageRow new];
        lastImageRow = eventSettingsResult.mediumResSettings;
    } else if ([elementName isEqualToString:@"WatermarkSettings"]) {
        eventSettingsResult.watermarkSettings = [EventSettingsWatermarkRow new];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"status"]) {
        eventSettingsResult.status = [lastValue copy];
        return;
    } else if ([elementName isEqualToString:@"message"]) {
        eventSettingsResult.message = [lastValue copy];
        return;
    }
    
    if ([elementName isEqualToString:@"CreatePreview"]) {
        eventSettingsResult.transferSettings.createPreview = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"CreateThumbnail"]) {
        eventSettingsResult.transferSettings.createThumbnail = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"PreviewWatermarkID"]) {
        eventSettingsResult.transferSettings.previewWatermarkID = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"ThumbnailWatermarkID"]) {
        eventSettingsResult.transferSettings.thumbnailWatermarkID = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"FTP"]) {
        eventSettingsResult.transferSettings.ftp = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"WebServiceURL"]) {
        eventSettingsResult.transferSettings.webServiceURL = [lastValue copy];
    } else if ([elementName isEqualToString:@"CreateMediumRes"]) {
        eventSettingsResult.transferSettings.createMediumRes = [numberFormatter numberFromString:lastValue].unsignedIntegerValue;
    }
    
    if ([elementName isEqualToString:@"Quality"]) {
        lastImageRow.quality = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"MaxSide"]) {
        lastImageRow.maxSide = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"Sharpen"]) {
        lastImageRow.sharpen = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"ResizeMethod"]) {
        lastImageRow.resizeMethod = [numberFormatter numberFromString:lastValue].integerValue;
    }

    if ([elementName isEqualToString:@"WatermarkID"]) {
        eventSettingsResult.watermarkSettings.watermarkID = [numberFormatter numberFromString:lastValue].integerValue;
    } else if ([elementName isEqualToString:@"Description"]) {
        eventSettingsResult.watermarkSettings.description = [lastValue copy];
    } else if ([elementName isEqualToString:@"HFile"]) {
        eventSettingsResult.watermarkSettings.hFile = [lastValue copy];
    } else if ([elementName isEqualToString:@"VFile"]) {
        eventSettingsResult.watermarkSettings.vFile = [lastValue copy];
    } else if ([elementName isEqualToString:@"HFileData"]) {
        eventSettingsResult.watermarkSettings.hFileData = [lastValue copy];
    } else if ([elementName isEqualToString:@"VFileData"]) {
        eventSettingsResult.watermarkSettings.vFileData = [lastValue copy];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    eventSettingsResult.error = parseError;
    finished(eventSettingsResult);
}

@end
