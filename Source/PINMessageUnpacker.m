//
//  PINMessageUnpacker.m
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINMessageUnpacker.h"
#import "cmp.h"
#import "PINMessagePackError.h"

#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
  #define NS_INTEGER_IS_64
#endif

#define ACQUIRE_OBJECT(returnType) \
  if (!_currentObjValid) { \
    if (!cmp_read_object(&_cmpContext, &_currentObj)) { \
      return (returnType)NO; \
    } \
    _currentObjValid = YES; \
  }

#define CONSUME_OBJECT(body) \
  BOOL result = body; \
  _currentObjValid = NO; \
  return result;

@implementation PINMessageUnpacker {
  cmp_ctx_t _cmpContext;
  NSInputStream *_inputStream;
  
  cmp_object_t _currentObj;
  BOOL _currentObjValid;
}

static bool stream_reader(cmp_ctx_t *ctx, void *data, size_t limit) {
  // CFReadStream will block until at least 1 byte is available, but it
  // won't block until "limit" is available. So we read in a loop, continually
  // reading until we get as many bytes as we want, or there's an error (-1),
  // or the stream ends (0).
  CFReadStreamRef stream = (CFReadStreamRef)ctx->buf;
  CFIndex totalCount = 0;
  while (totalCount < limit) {
    CFIndex nextChunk = limit - totalCount;
    CFIndex count = CFReadStreamRead(stream, data + totalCount, nextChunk);
    if (count == 0 || count == -1) {
      return false;
    }
    totalCount += count;
  }
  return true;
}

- (instancetype)initWithInputStream:(NSInputStream *)inputStream
{
  NSParameterAssert(inputStream.streamStatus == NSStreamStatusNotOpen);
  
  if (self = [super init]) {
    _inputStream = inputStream;
    [_inputStream open];
    cmp_init(&_cmpContext, (__bridge CFReadStreamRef)inputStream, stream_reader, NULL, NULL);
  }
  return self;
}

- (NSError *)error
{
  uint8_t error = (&_cmpContext)->error;
  if (error) {
    return [NSError errorWithDomain:PINMessagePackErrorDomain code:error userInfo:@{ NSDebugDescriptionErrorKey: @(cmp_strerror(&_cmpContext))}];
  }
  return nil;
}

- (void)dealloc
{
  [_inputStream close];
}

- (PINMessagePackValueType)currentValueType
{
  ACQUIRE_OBJECT(PINMessagePackValueType);
  return PINMessagePackValueTypeFromCMPType((&_currentObj)->type);
}

- (BOOL)readNil
{
  CONSUME_OBJECT(cmp_object_is_nil(&_currentObj));
}

- (BOOL)readBOOL:(out BOOL *)boolPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_bool(&_currentObj, (bool *)boolPtr));
}

- (BOOL)readInteger:(out NSInteger *)intPtr
{
  ACQUIRE_OBJECT(BOOL);
#ifdef NS_INTEGER_IS_64
  return [self readInt64:(int64_t *)intPtr];
#else
  CONSUME_OBJECT(cmp_object_as_int(&_currentObj, intPtr));
#endif
}

- (BOOL)readUnsignedInteger:(out NSUInteger *)uintPtr
{
#ifdef NS_INTEGER_IS_64
  return [self readUnsignedInt64:(uint64_t *)uintPtr];
#else
  CONSUME_OBJECT(cmp_object_as_uint(&_currentObj, uintPtr));
#endif
}

- (BOOL)readInt64:(out int64_t *)llPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_sinteger(&_currentObj, llPtr));
}

- (BOOL)readUnsignedInt64:(out uint64_t *)ullPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_uinteger(&_currentObj, ullPtr));
}

- (BOOL)readFloat:(out float *)floatPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_float(&_currentObj, floatPtr));
}

- (BOOL)readDouble:(out double *)doublePtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_double(&_currentObj, doublePtr));
}

- (BOOL)readStringLength:(out uint32_t *)lengthPtr
{
  ACQUIRE_OBJECT(BOOL);
  return cmp_object_as_str(&_currentObj, lengthPtr);
}

- (BOOL)readDataLength:(out uint32_t *)lengthPtr
{
  ACQUIRE_OBJECT(BOOL);
  return cmp_object_as_bin(&_currentObj, lengthPtr);
}

- (BOOL)readString:(char *)string bufferSize:(uint32_t)size
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_to_str(&_cmpContext, &_currentObj, string, size));
}

- (BOOL)readData:(void *)buffer length:(uint32_t)length
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_to_bin(&_cmpContext, &_currentObj, buffer, length));
}

- (BOOL)readArrayCount:(out uint32_t *)countPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_array(&_currentObj, countPtr));
}

- (BOOL)readMapCount:(out uint32_t *)countPtr
{
  ACQUIRE_OBJECT(BOOL);
  CONSUME_OBJECT(cmp_object_as_map(&_currentObj, countPtr));
}

@end
