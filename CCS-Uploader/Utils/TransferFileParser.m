#import "TransferFileParser.h"

@interface TransferFileParser () <NSXMLParserDelegate> {
    NSMutableString *lastValue;
    NSMutableDictionary *result;
}
@end

@implementation TransferFileParser

- (NSDictionary *)parse:(NSString *)filename
{
    NSData *data = [NSData dataWithContentsOfFile:filename];
    
    if (!data) {
        NSLog(@"%@: could not read file", filename);
        return nil;
    }
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    
    if (lastValue == nil) {
        lastValue = [NSMutableString new];
    } else {
        lastValue.string = @"";
    }
    
    if (result == nil) {
        result = [NSMutableDictionary new];
    } else {
        [result removeAllObjects];
    }
    
    if ([parser parse]) {
        return result;
    } else {
        NSLog(@"%@: could not parse file", filename);
        return nil;
    }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    lastValue.string = @"";
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [lastValue appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    result[elementName] = [lastValue copy];
}

@end
