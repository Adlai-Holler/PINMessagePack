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
 * It also gives you a variable `uint32_t strBuf_len` that tells
 * you the length of the string (without NULL terminator).
 */
#define PINReadString(unpacker, varName) \
  uint32_t varName ## _len;\
  [unpacker readStringLength:&varName ## _len]; \
  char varName[varName ## _len + 1]; \
  [unpacker readString:varName bufferSize:varName ## _len + 1];

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
 *
 * The input stream must not be opened. The input stream will be closed
 * when the unpacker is deallocated.
 */
- (instancetype)initWithInputStream:(NSInputStream *)inputStream NS_DESIGNATED_INITIALIZER;

/// The most recent error that occurred, if any.
@property (nullable, nonatomic, readonly, copy) NSError *error;

#pragma mark - Reading

/**
 * The value type that's currently pointed to by the unpacker.
 */
@property (nonatomic, readonly) PINMessagePackValueType currentValueType;

/**
 * Read the current value as nil.
 */
- (BOOL)readNil;

/**
 * Read the current value as BOOL.
 */
- (BOOL)readBOOL:(out BOOL *)boolPtr;

/**
 * Read the current value as NSInteger.
 */
- (BOOL)readInteger:(out NSInteger *)intPtr;

/**
 * Read the current value as NSUInteger.
 */
- (BOOL)readUnsignedInteger:(out NSUInteger *)uintPtr;

/**
 * Read the current value as signed 64-bit integer.
 */
- (BOOL)readInt64:(out int64_t *)llPtr;

/**
 * Read the current value as unsigned 64-bit integer.
 */
- (BOOL)readUnsignedInt64:(out uint64_t *)ullPtr;

/**
 * Read the current value as float.
 */
- (BOOL)readFloat:(out float *)floatPtr;

/**
 * Read the current value as double.
 */
- (BOOL)readDouble:(out double *)doublePtr;

/**
 * Reads the length of the current string, without NULL terminator.
 */
- (BOOL)readStringLength:(out uint32_t *)lengthPtr;

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
 * Read the string contents into the given buffer.
 *
 * The buffer should be at least (length + 1).
 *
 * NOTE: You can call -readStringLength: before calling this
 * to get the length.
 */
- (BOOL)readString:(char *)string bufferSize:(uint32_t)size;

/**
 * Read the next binary data into the given buffer.
 *
 * NOTE: You can call -readDataLength: before calling this
 * to get an appropriate length.
 */
- (BOOL)readData:(void *)buffer length:(uint32_t)length;

#pragma mark - Unavailable

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
