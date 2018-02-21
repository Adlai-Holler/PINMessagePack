//
//  PINCollections.m
//  PINMessagePack
//
//  Created by Adlai on 2/18/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINCollections.h"
#import <pthread/pthread.h>

typedef NS_ENUM(NSInteger, PINFlagOperation) {
  PINFlagRead,
  PINFlagSet,
  PINFlagClear
};

static __attribute__((__noinline__)) BOOL PINSkipRetainFlag(PINFlagOperation op)
{
  static pthread_key_t k;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pthread_key_create(&k, NULL);
  });
  
  switch (op) {
    case PINFlagSet:
      NSCAssert(!PINSkipRetainFlag(PINFlagRead), @"Redundant flag set.");
      pthread_setspecific(k, kCFBooleanTrue);
      return YES;
    case PINFlagRead:
      return (pthread_getspecific(k) == kCFBooleanTrue);
    case PINFlagClear:
      pthread_setspecific(k, NULL);
      return YES;
  }
}

static const void *PINRetainCallback(CFAllocatorRef allocator, const void *value)
{
  if (PINSkipRetainFlag(PINFlagRead)) {
    return value;
  } else {
    return (&kCFTypeArrayCallBacks)->retain(allocator, value);
  }
}

static const void *PINCopyCallback(CFAllocatorRef allocator, const void *value)
{
  if (PINSkipRetainFlag(PINFlagRead)) {
    return value;
  } else {
    return (&kCFTypeDictionaryKeyCallBacks)->retain(allocator, value);
  }
}

@implementation NSArray (PINCollection)

+ (NSArray *)pin_arrayWithRetainedObjects:(CFTypeRef[])objects
                                    count:(NSUInteger)count
{
  // NSArrayZero singleton.
  if (count == 0) {
    return @[];
  }
  // NSSingleObjectArray specialization.
  if (count == 1) {
    return @[ (__bridge_transfer id)objects[0] ];
  }
  static CFArrayCallBacks cb;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cb = kCFTypeArrayCallBacks;
    cb.retain = PINRetainCallback;
  });
  PINSkipRetainFlag(PINFlagSet);
  NSArray *result = (__bridge NSArray *)CFArrayCreate(kCFAllocatorDefault, objects, count, &cb);
  PINSkipRetainFlag(PINFlagClear);
  return result;
}

@end

@implementation NSDictionary (PINCollection)

+ (NSDictionary *)pin_dictionaryWithRetainedObjects:(CFTypeRef  _Nonnull [])objects keys:(CFTypeRef  _Nonnull [])keys count:(NSUInteger)count
{
  // NSDictionaryZero singleton.
  if (count == 0) {
    return @{};
  }
  // NSSingleObjectDictionary specialization.
  if (count == 1) {
    return @{ (__bridge_transfer id)keys[0]: (__bridge_transfer id)objects[0] };
  }
  
  static CFDictionaryKeyCallBacks kCb;
  static CFDictionaryValueCallBacks vCb;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kCb = kCFTypeDictionaryKeyCallBacks;
    kCb.retain = PINCopyCallback;
    vCb = kCFTypeDictionaryValueCallBacks;
    vCb.retain = PINRetainCallback;
  });
  
  PINSkipRetainFlag(PINFlagSet);
  NSDictionary *result = (__bridge NSDictionary *)CFDictionaryCreate(kCFAllocatorDefault, keys, objects, count, &kCb, &vCb);
  PINSkipRetainFlag(PINFlagClear);
  return result;
}

@end

@implementation NSSet (PINCollection)

+ (NSSet *)pin_setWithRetainedObjects:(CFTypeRef  _Nonnull [])objects count:(NSUInteger)count
{
  // NSSetZero singleton.
  if (count == 0) {
    return [NSSet set];
  }
  // NSSingleObjectSet specialization.
  if (count == 1) {
    return [NSSet setWithObject:(__bridge_transfer id)objects[0]];
  }
  static CFSetCallBacks cb;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cb = kCFTypeSetCallBacks;
    cb.retain = PINRetainCallback;
  });
  PINSkipRetainFlag(PINFlagSet);
  NSSet *result = (__bridge NSSet *)CFSetCreate(kCFAllocatorDefault, objects, count, &cb);
  PINSkipRetainFlag(PINFlagClear);
  return result;
}

@end
