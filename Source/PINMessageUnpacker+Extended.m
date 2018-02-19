//
//  PINMessageUnpacker+Extended.m
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINMessageUnpacker+Extended.h"
#import "PINMessagePackValues.h"
#import "PINCollections.h"

#if __LP64__
  #define STR_MAX_TAGGED_PTR_LEN 9
#else
  #define STR_MAX_TAGGED_PTR_LEN 0
#endif

@implementation PINMessageUnpacker (Extended)

- (NSString *)readNSStringWithError:(NSError * _Nullable __autoreleasing *)error
{
  uint32_t bufSize;
  if (![self readStringBufferSize:&bufSize]) {
    if (error) {
      *error = self.error;
    }
    return nil;
  }
  
  if (bufSize < 2) {
    // TODO: Have to read this even though it does nothing.
    char buf[bufSize];
    if (![self readString:buf bufferSize:bufSize]) {
      return nil;
    }
    return @"";
  }
  
  // Account for NULL terminator.
  uint32_t len = bufSize - 1;
  
  // For small strings (tagged pointers) read into a stack buffer and pass to string. This will save
  // us a malloc/free pair. For larger strings, go ahead and malloc and 
  NSString *result;
  if (len <= STR_MAX_TAGGED_PTR_LEN) {
    char buf[bufSize];
    if ([self readString:buf bufferSize:bufSize]) {
      result = [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding];
    }
  } else {
    char *buf = malloc(bufSize);
    if ([self readString:buf bufferSize:bufSize]) {
      result = [[NSString alloc] initWithBytesNoCopy:buf length:len encoding:NSUTF8StringEncoding freeWhenDone:YES];
    }
    if (result == nil) {
      free(buf);
    }
  }
  return result;
}

- (NSData *)readNSDataWithError:(NSError * _Nullable __autoreleasing *)error
{
  uint32_t length;
  if (![self readDataLength:&length]) {
    if (error) {
      *error = self.error;
    }
    return nil;
  }
  if (length == 0) {
    // TODO: Have to read this even though it does nothing.
    char buf[length];
    if (![self readData:buf length:length]) {
      return nil;
    }
    return [NSData data];
  }
  
  void *buf = malloc(length);
  if (![self readData:buf length:length]) {
    if (error) {
      *error = self.error;
    }
    return nil;
  }
  return [NSData dataWithBytesNoCopy:buf length:length freeWhenDone:YES];
}

- (NSArray *)readNSArrayWithError:(NSError * _Nullable __autoreleasing *)error
{
  uint32_t count;
  if (![self readArrayCount:&count]) {
    if (error) {
      *error = self.error;
    }
    return nil;
  }
  
  CFTypeRef vals[count];
  for (NSUInteger i = 0; i < count; i++) {
    vals[i] = (__bridge_retained CFTypeRef)[self readObjectWithError:error];
    
    // In case of an error, we don't want to leak these so we need to release them.
    if (vals[i] == NULL) {
      for (NSUInteger j = 0; j < i; j++) {
        CFRelease(vals[j]);
      }
      return nil;
    }
  }
  return [NSArray pin_arrayWithRetainedObjects:vals count:count];
}

- (NSDictionary *)readNSDictionaryWithError:(NSError * _Nullable __autoreleasing *)error
{
  uint32_t count;
  if (![self readMapCount:&count]) {
    if (error) {
      *error = self.error;
    }
    return nil;
  }
  
  CFTypeRef keys[count];
  CFTypeRef vals[count];
  for (NSUInteger i = 0; i < count; i++) {
    
    // Read key
    if (!(keys[i] = (__bridge_retained CFTypeRef)[self readObjectWithError:error])) {
      for (NSUInteger j = 0; j < i; j++) {
        CFRelease(keys[j]);
        CFRelease(vals[j]);
      }
      return nil;
    }
    
    if (CFGetTypeID(keys[i]) == CFDataGetTypeID()) {
      id str = [[NSString alloc] initWithData:(__bridge id)keys[i] encoding:NSUTF8StringEncoding];
      CFRelease(keys[i]);
      keys[i] = (__bridge_retained CFStringRef)str;
    }
    
    // Read val
    if (!(vals[i] = (__bridge_retained CFTypeRef)[self readObjectWithError:error])) {
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

- (id)readObjectWithError:(NSError **)error
{
  switch (self.currentValueType) {
    case PINMessagePackValueMap:
      return [self readNSDictionaryWithError:error];
    case PINMessagePackValueArray:
      return [self readNSArrayWithError:error];
    case PINMessagePackValueNil: {
      BOOL result = [self readNil];
      return result ? (id)kCFNull : nil;
    }
    case PINMessagePackValueString:
      return [self readNSStringWithError:error];
    case PINMessagePackValueBinary:
      return [self readNSDataWithError:error];
    case PINMessagePackValueBool: {
      BOOL val;
      if (![self readBOOL:&val]) {
        *error = self.error;
        return nil;
      } else {
        return (id)(val ? kCFBooleanTrue : kCFBooleanFalse);
      }
    }
    case PINMessagePackValueFloat: {
      float f;
      if (![self readFloat:&f]) {
        *error = self.error;
        return nil;
      } else {
        return @(f);
      }
    }
    case PINMessagePackValueDouble: {
      double d;
      if (![self readDouble:&d]) {
        *error = self.error;
        return nil;
      } else {
        return @(d);
      }
    }
    case PINMessagePackSignedInteger: {
      NSInteger i;
      if (![self readInteger:&i]) {
        *error = self.error;
        return nil;
      } else {
        return @(i);
      }
    }
    case PINMessagePackSignedInt64: {
      int64_t i;
      if (![self readInt64:&i]) {
        *error = self.error;
        return nil;
      } else {
        return @(i);
      }
    }
    case PINMessagePackUnsignedInteger: {
      NSUInteger i;
      if (![self readUnsignedInteger:&i]) {
        *error = self.error;
        return nil;
      } else {
        return @(i);
      }
    }
    case PINMessagePackUnsignedInt64: {
      uint64_t i;
      if (![self readUnsignedInt64:&i]) {
        *error = self.error;
        return nil;
      } else {
        return @(i);
      }
    }
    case PINMessagePackValueUnspecified:
      return nil;
  }
}

@end
