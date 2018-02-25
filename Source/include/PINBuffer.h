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
 * Whether this buffer should preserve all data written to it.
 *
 * Since it increases memory consumption, this option should
 * only be used for debugging.
 *
 * Defaults to NO.
 */
@property (atomic) BOOL preserveData;

/**
 * Reads `len` bytes, blocking if needed.
 *
 * Returns YES if the read succeeded, or NO if the buffer closed before providing the data.
 *
 * This method should not be used in conjunction with -readAllData.
 */
- (BOOL)read:(uint8_t *)buffer length:(NSUInteger)len;

/**
 * Retrieve all data in the buffer.
 *
 * If `preserveData` is set, this is all the data that
 * has been written into the buffer. If not, this returns _at least_
 * all the unread data in the buffer.
 *
 * If `preserveData` is not set, the buffer must be closed before accessing
 * this property. Accessing this property on an open buffer should
 * only be used for debugging.
 *
 * This method should not be used in conjunction with -read:length: except
 * for debugging.
 */
@property (atomic, copy, readonly) NSData *allData;

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
