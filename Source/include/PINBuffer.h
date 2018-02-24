//
//  PINBuffer.h
//  PINMessagePack
//
//  Created by Adlai on 2/22/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PINBufferState) {
  PINBufferStateNormal,
  PINBufferStateError,
  PINBufferStateCompleted
};

/**
 * An efficient data buffer, built specifically to avoid copying
 * and to support noncontiguous data.
 *
 * Objects behave basically like a bound pair of NSStreams,
 * but are much faster.
 *
 * All reads must be from the same thread. Writes can be from any thread.
 */
__attribute__((objc_subclassing_restricted))
@interface PINBuffer : NSObject

/**
 * The current state of the buffer.
 */
@property (atomic, readonly) PINBufferState state;

/**
 * Reads `len` bytes, blocking if needed.
 *
 * Returns YES if the read succeeded, or NO if the buffer closed before providing the data.
 *
 * This method should not be used in conjunction with -readAllData.
 */
- (BOOL)read:(uint8_t *)buffer length:(NSUInteger)len;

/**
 * Consume all data in the buffer in one shot.
 *
 * This may only be called once, it must
 * be called after the buffer is closed,
 * should not be called if -read:length: has been called.
 */
- (NSData *)readAllData NS_RETURNS_RETAINED;

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
 *
 * YES indicates that the entire expected message was written,
 * NO indicates that an error/cancellation occurred.
 */
- (void)closeCompleted:(BOOL)completed;

@end

NS_ASSUME_NONNULL_END
