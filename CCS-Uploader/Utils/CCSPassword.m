#import "CCSPassword.h"

#import <CommonCrypto/CommonCryptor.h>

@implementation CCSPassword

+ (NSData *)decryptCCSPassword:(NSData *)encryptedPassword
{
    size_t bufferSize = encryptedPassword.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    
    static const uint8_t iv[kCCBlockSizeAES128] = {
        0x75, 0xDC, 0x09, 0x37, 0x9D, 0x2C, 0xE3, 0x76, 0x11, 0xC8, 0x3C, 0xBA, 0x1C, 0x51, 0x50, 0xA8,
    };
    
    static const uint8_t key[kCCKeySizeAES256] = {
        0x65, 0xC4, 0xBC, 0xF2, 0x39, 0xF6, 0x19, 0xA7, 0x83, 0x68, 0x6E, 0xBC, 0xB5, 0x24, 0x71, 0x19,
        0x59, 0xFB, 0xE7, 0x5B, 0xB8, 0x14, 0x6C, 0x04, 0xBB, 0x2D, 0x21, 0x83, 0x31, 0xE5, 0x4B, 0xDF,
    };
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
        key, kCCKeySizeAES256, iv, encryptedPassword.bytes, encryptedPassword.length, buffer, bufferSize, &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer);
    return nil;
}

@end
