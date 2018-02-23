//
//  PINBuffer.h
//  PINMessagePack
//
//  Created by Adlai on 2/22/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An efficient data buffer built on top of dispatch_data.
 *
 * Objects behave basically like a bound pair of NSStreams,
 * but are much faster.
 *
 * It is safe to call methods from multiple threads.
 */
__attribute__((objc_subclassing_restricted))
@interface PINBuffer : NSObject

/**
 * Reads `len` bytes, blocking if needed.
 *
 * Returns YES if the read succeeded, or NO if the buffer closed before providing the data.
 */
- (BOOL)read:(uint8_t *)buffer length:(NSUInteger)len;

/**
 * Writes a chunk of data.
 *
 * NOTE: PINBuffer is intended to be used with NSURLSession or file I/O,
 * both of which use dispatch_data under the hood to avoid copies.
 *
 * Therefore PINBuffer does not support writing raw bytes, as it does
 * not maintain its own contiguous buffer.
 */
- (void)writeData:(NSData *)data;

/**
 * Indicate that no more data will be put into the buffer.
 */
- (void)close;

@end

NS_ASSUME_NONNULL_END
