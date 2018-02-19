//
//  PINMessageUnpacker.h
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PINMessagePack/PINMessagePackValues.h>

/**
 * Convenient way to read a string into the current scope.
 * Example: PINReadString(myUnpacker, strBuf);
 * gives you a variable `char strBuf[]` with the string in it.
 *
 * It also gives you a variable `uint32_t strBuf_size` that tells
 * you the size of the string (including NULL terminator).
 */
#define PINReadString(unpacker, varName) \
  uint32_t varName ## _size;\
  [unpacker readStringBufferSize:&varName ## _size]; \
  char varName[varName ## _size]; \
  [unpacker readString:varName bufferSize:varName ## _size];

NS_ASSUME_NONNULL_BEGIN

/**
 * Objects of this class are not thread-safe, and must be paired with a lock to
 * be accessed from multiple threads.
 *
 * Unpackers take responsibility for opening and closing their input streams.
 */
__attribute__((objc_subclassing_restricted))
@interface PINMessageUnpacker : NSObject

/**
 * Initialize an unpacker using the given input stream.
 */
- (instancetype)initWithInputStream:(NSInputStream *)inputStream NS_DESIGNATED_INITIALIZER;

/// The most recent error that occurred, if any.
@property (nullable, nonatomic, readonly, copy) NSError *error;

#pragma mark - Reading

@property (nonatomic, readonly) PINMessagePackValueType currentValueType;

- (BOOL)readNil;

/**
 * Read the next BOOL value.
 */
- (BOOL)readBOOL:(out BOOL *)boolPtr;

/**
 * Read the next signed integer value.
 */
- (BOOL)readInteger:(out NSInteger *)intPtr;

- (BOOL)readInt64:(out int64_t *)llPtr;

- (BOOL)readUnsignedInt64:(out uint64_t *)ullPtr;

/**
 * Read the next unsigned integer value.
 */
- (BOOL)readUnsignedInteger:(out NSUInteger *)uintPtr;

/**
 * Read the next float value.
 */
- (BOOL)readFloat:(out float *)floatPtr;

/**
 * Read the next double value.
 */
- (BOOL)readDouble:(out double *)doublePtr;

/**
 * Reads the size of the buffer needed to hold the next string.
 *
 * The size will be the string's length, plus 1 for the NULL terminator.
 */
- (BOOL)readStringBufferSize:(out uint32_t *)bufferSizePtr;

/**
 * Reads the length of the binary data that's pointed to.
 */
- (BOOL)readDataLength:(out uint32_t *)lengthPtr;

/**
 * Reads the size of the current array.
 */
- (BOOL)readArrayCount:(out uint32_t *)countPtr;

/**
 * Reads the size of the current map.
 */
- (BOOL)readMapCount:(out uint32_t *)countPtr;

/**
 * Read the next string into the given buffer.
 *
 * NOTE: You must call -readStringBufferSize: before calling this.
 */
- (BOOL)readString:(char *)string bufferSize:(uint32_t)size;

/**
 * Read the next binary data into the given buffer.
 *
 * NOTE: You must call -readDataLength: before calling this.
 */
- (BOOL)readData:(void *)buffer length:(uint32_t)size;

#pragma mark - Unavailable

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
