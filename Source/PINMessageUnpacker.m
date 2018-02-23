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
#import "PINCollections.h"
#import "PINBuffer.h"

// Determined experimentally on iOS 11.2
// If this value is wrong, we'll see a teeny-tiny performance penalty.
// - If it's larger than the real value, then we'll copy small strings
// to the stack and THEN to the heap instead of going straight to the heap.
// - If it's smaller than the real value, then we'll malloc & free when we
// could have just stayed on the stack the whole time.
#if __LP64__
#define TAGGED_PTR_STRING_MAX_LEN 9
#endif

#define CHECK_ERROR() NSCAssert(0 == (&_cmpContext)->error, @"Decoding error: %@", self.error);

#define SET_AND_REPORT_ERROR(code) (&_cmpContext)->error = code; CHECK_ERROR();

/// Checks that the class is either Nil or the specified one.
/// On fail, report error and return nil.
#define ENSURE_CLASS(c, e) \
  if (c && c != e) { \
    SET_AND_REPORT_ERROR(PINMessagePackErrorInvalidType); \
    return nil; \
  }

@implementation PINMessageUnpacker {
  cmp_ctx_t _cmpContext;
  PINBuffer *_buffer;
  
  uint32_t _pendingMapCount;
}

static bool stream_reader(cmp_ctx_t *ctx, void *data, size_t limit) {
  __unsafe_unretained PINBuffer *buffer = (__bridge PINBuffer *)ctx->buf;
  return (bool)[buffer read:data length:limit];
}

- (instancetype)initWithBuffer:(PINBuffer *)buffer
{
  if (self = [super init]) {
    _buffer = buffer;
    cmp_init(&_cmpContext, (__bridge void *)buffer, stream_reader, NULL, NULL);
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

- (NSInteger)decodeInteger
{
  if (sizeof(NSInteger) == sizeof(int64_t)) {
    int64_t v;
    if (!cmp_read_long(&_cmpContext, &v)) {
      CHECK_ERROR();
      return 0;
    }
    return (NSInteger)v;
  } else {
    int32_t v;
    if (!cmp_read_int(&_cmpContext, &v)) {
      CHECK_ERROR();
      return 0;
    }
    return (NSInteger)v;
  }
}

- (id)decodeObjectOfClass:(Class)class NS_RETURNS_RETAINED
{
  NSParameterAssert(class != Nil);
  return [self _decodeObjectOfClass:class allowNull:NO];
}

- (id)_decodeObjectOfClass:(Class)class allowNull:(BOOL)allowNull NS_RETURNS_RETAINED
{
  static Class numberClass;
  static Class stringClass;
  static Class dataClass;
  static Class arrayClass;
  static Class dictionaryClass;
  static Class setClass;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    numberClass = [NSNumber class];
    stringClass = [NSString class];
    dataClass = [NSData class];
    arrayClass = [NSArray class];
    dictionaryClass = [NSDictionary class];
    setClass = [NSSet class];
  });
  
  // If we have a custom class, immediately give them control and don't
  // pull any data from the stream.
  if (class && class != numberClass && class != stringClass && class != dataClass && class != arrayClass && class != dictionaryClass && class != setClass) {
    id<PINStreamingDecoding> inst = [class alloc];
    // Currently no production check on this. If they pass an invalid
    // class, they'll get hit with an easily-understandable
    // doesNotRespondToSelector: exception.
    return [inst initWithStreamingDecoder:self];
  }
  
  cmp_object_t o;
  cmp_read_object(&_cmpContext, &o);
  switch (o.type) {
    case CMP_TYPE_NIL:
      return (allowNull ? (id)kCFNull : nil);
    case CMP_TYPE_STR8:
    case CMP_TYPE_STR16:
    case CMP_TYPE_STR32:
    case CMP_TYPE_FIXSTR: {
      ENSURE_CLASS(class, stringClass);
      uint32_t len = o.as.str_size;
      uint32_t bufSize = len + 1;
      
#ifdef TAGGED_PTR_STRING_MAX_LEN
      // If it's a short string, skip the heap and stay on the stack
      // hoping for the system to use a tagged pointer.
      if (len <= TAGGED_PTR_STRING_MAX_LEN) {
        char buf[bufSize];
        if (!cmp_object_to_str(&_cmpContext, &o, buf, bufSize)) {
          CHECK_ERROR();
          return nil;
        }
        return [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding];
      }
#endif
      
      char *buf = malloc(bufSize);
      NSString *result;
      if (!cmp_object_to_str(&_cmpContext, &o, buf, bufSize)) {
        CHECK_ERROR();
        free(buf);
        return nil;
      }
      
      result = [[NSString alloc] initWithBytesNoCopy:buf length:len encoding:NSUTF8StringEncoding freeWhenDone:YES];
      if (result == nil) {
        SET_AND_REPORT_ERROR(PINMessagePackInternalError);
        free(buf);
        return nil;
      }
      
      return result;
    }
    case CMP_TYPE_BIN8:
    case CMP_TYPE_BIN16:
    case CMP_TYPE_BIN32: {
      ENSURE_CLASS(class, dataClass);
      uint32_t size = o.as.bin_size;
      void *data = malloc(size);
      if (!cmp_object_to_bin(&_cmpContext, &o, data, size)) {
        CHECK_ERROR();
        free(data);
        return nil;
      }
      return [[NSData alloc] initWithBytesNoCopy:data length:size];
    }
    case CMP_TYPE_ARRAY16:
    case CMP_TYPE_ARRAY32:
    case CMP_TYPE_FIXARRAY:
      if (!class || class == arrayClass) {
        return [self _decodeArrayOrSet:NO count:o.as.array_size class:Nil];
      } else if (class == setClass) {
        return [self _decodeArrayOrSet:YES count:o.as.array_size class:Nil];
      } else {
        SET_AND_REPORT_ERROR(PINMessagePackErrorInvalidType);
        return nil;
      }
    case CMP_TYPE_MAP16:
    case CMP_TYPE_MAP32:
    case CMP_TYPE_FIXMAP:
      ENSURE_CLASS(class, dictionaryClass);
      return [self _decodeDictionaryWithCount:o.as.map_size keyClass:Nil objectClass:Nil];
    case CMP_TYPE_BOOLEAN:
      ENSURE_CLASS(class, numberClass);
      return (id)(o.as.boolean ? kCFBooleanTrue : kCFBooleanFalse);
    case CMP_TYPE_DOUBLE:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &o.as.dbl);
    case CMP_TYPE_FLOAT:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &o.as.flt);
    case CMP_TYPE_POSITIVE_FIXNUM:
    case CMP_TYPE_NEGATIVE_FIXNUM:
    case CMP_TYPE_SINT8:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &o.as.s8);
    case CMP_TYPE_SINT16:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &o.as.s16);
    case CMP_TYPE_SINT32:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &o.as.s32);
    case CMP_TYPE_SINT64:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &o.as.s64);
    case CMP_TYPE_UINT8:
      // NOTE about unsigned types. Since CFNumber doesn't support unsigned values,
      // we mimic NSNumber and store them in the next-largest signed type. U64
      // is handled specially.
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &o.as.u8);
    case CMP_TYPE_UINT16:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &o.as.u16);
    case CMP_TYPE_UINT32:
      ENSURE_CLASS(class, numberClass);
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &o.as.u32);
    case CMP_TYPE_UINT64:
      ENSURE_CLASS(class, numberClass);
      // Yep, NSNumber does this too. Just pass it as signed64 and rely on them to read it in unsigned form.
      return (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &o.as.u64);
    default:
      NSCAssert(NO, @"Failed to map.");
      return nil;
  }
}

- (NSArray *)decodeArrayOfClass:(Class)class NS_RETURNS_RETAINED
{
  uint32_t count;
  if (!cmp_read_array(&_cmpContext, &count)) {
    CHECK_ERROR();
    return nil;
  }
  return [self _decodeArrayOrSet:NO count:count class:class];
}

- (NSSet *)decodeSetOfClass:(Class)class NS_RETURNS_RETAINED
{
  uint32_t count;
  if (!cmp_read_array(&_cmpContext, &count)) {
    CHECK_ERROR();
    return nil;
  }
  return [self _decodeArrayOrSet:YES count:count class:class];
}

- (id)_decodeArrayOrSet:(BOOL)isSet count:(NSUInteger)count class:(Class)class NS_RETURNS_RETAINED
{
  CFTypeRef vals[count];
  for (NSUInteger i = 0; i < count; i++) {
    if (!(vals[i] = (__bridge_retained CFTypeRef)[self _decodeObjectOfClass:class allowNull:YES])) {
      // In case of an error, we don't want to leak these so we need to release them.
      for (NSUInteger j = 0; j < i; j++) {
        CFRelease(vals[j]);
      }
      return nil;
    }
  }
  if (isSet) {
    return [NSSet pin_setWithRetainedObjects:vals count:count];
  } else {
    return [NSArray pin_arrayWithRetainedObjects:vals count:count];
  }
}

- (NSDictionary *)decodeDictionaryWithKeyClass:(Class)keyClass objectClass:(Class)objectClass NS_RETURNS_RETAINED
{
  uint32_t count;
  if (!cmp_read_map(&_cmpContext, &count)) {
    CHECK_ERROR();
    return nil;
  }
  
  return [self _decodeDictionaryWithCount:count keyClass:keyClass objectClass:objectClass];
}

- (NSDictionary *)_decodeDictionaryWithCount:(NSUInteger)count keyClass:(Class)keyClass objectClass:(Class)objectClass NS_RETURNS_RETAINED
{
  CFTypeRef keys[count];
  CFTypeRef vals[count];
  for (NSUInteger i = 0; i < count; i++) {
    
    // Read key
    if (!(keys[i] = (__bridge_retained CFTypeRef)[self _decodeObjectOfClass:keyClass allowNull:YES])) {
      for (NSUInteger j = 0; j < i; j++) {
        CFRelease(keys[j]);
        CFRelease(vals[j]);
      }
      return nil;
    }
    
    // Read val
    if (!(vals[i] = (__bridge_retained CFTypeRef)[self _decodeObjectOfClass:objectClass allowNull:YES])) {
      for (NSUInteger j = 0; j < i; j++) {
        CFRelease(keys[j]);
        CFRelease(vals[j]);
      }
      CFRelease(keys[i]);
      return nil;
    }
  }
  return [NSDictionary pin_dictionaryWithRetainedObjects:vals keys:keys count:count];
}

- (double)decodeDouble
{
  cmp_object_t o;
  if (!cmp_read_object(&_cmpContext, &o)) {
    CHECK_ERROR();
    return 0;
  }
  switch (o.type) {
    case CMP_TYPE_DOUBLE:
      return o.as.dbl;
    case CMP_TYPE_FLOAT:
      return (double)o.as.flt;
    default:
      SET_AND_REPORT_ERROR(PINMessagePackErrorInvalidType);
      return 0;
  }
}

- (BOOL)decodeBOOL
{
  bool b;
  if (!cmp_read_bool(&_cmpContext, &b)) {
    CHECK_ERROR();
    return NO;
  }
  return (BOOL)b;
}

- (void)enumerateKeysInMapWithBlock:(nonnull void (^)(const char * _Nonnull, NSUInteger))block {
  uint32_t c;
  if (_pendingMapCount > 0) {
    c = _pendingMapCount;
  } else {
    if (!cmp_read_map(&_cmpContext, &c)) {
      CHECK_ERROR();
      return;
    }
  }
  for (uint32_t i = 0; i < c; i++) {
    // Can't use cmp_read_str because we want to read
    // into a stack buf and need to get size THEN contents.
    cmp_object_t o;
    cmp_read_object(&_cmpContext, &o);
    switch (o.type) {
      case CMP_TYPE_STR8:
      case CMP_TYPE_STR16:
      case CMP_TYPE_STR32:
      case CMP_TYPE_FIXSTR: {
        uint32_t len = o.as.str_size;
        char key[len+1];
        if (!cmp_object_to_str(&_cmpContext, &o, key, len+1)) {
          CHECK_ERROR();
          return;
        }
        block(key, len);
        break;
      }
      default:
        SET_AND_REPORT_ERROR(PINMessagePackErrorInvalidType);
        return;
    }
  }
}

@end
