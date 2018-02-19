//
//  PINMessageUnpacker+Extended.h
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINMessageUnpacker.h"

NS_ASSUME_NONNULL_BEGIN

@interface PINMessageUnpacker (Extended)

- (nullable NSString *)readNSStringWithError:(NSError **)error;

- (nullable NSData *)readNSDataWithError:(NSError **)error;

- (nullable NSArray *)readNSArrayWithError:(NSError **)error;

- (nullable NSDictionary *)readNSDictionaryWithError:(NSError **)error;

- (nullable id)readObjectWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
