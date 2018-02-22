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
                                    count:(NSUInteger)count NS_RETURNS_RETAINED
{
  // NSArrayZero singleton.
  if (count == 0) {
    return [[NSArray alloc] init];
  }
  // NSSingleObjectArray specialization.
  if (count == 1) {
    return [[NSArray alloc] initWithObjects:(__bridge_transfer id)objects[0], nil];
  }
  static CFArrayCallBacks cb;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cb = kCFTypeArrayCallBacks;
    cb.retain = PINRetainCallback;
  });
  PINSkipRetainFlag(PINFlagSet);
  CFArrayRef result = CFArrayCreate(kCFAllocatorDefault, objects, count, &cb);
  PINSkipRetainFlag(PINFlagClear);
  return (__bridge_transfer NSArray *)result;
}

@end

@implementation NSDictionary (PINCollection)

+ (NSDictionary *)pin_dictionaryWithRetainedObjects:(CFTypeRef  _Nonnull [])objects keys:(CFTypeRef  _Nonnull [])keys count:(NSUInteger)count NS_RETURNS_RETAINED
{
  // NSDictionaryZero singleton.
  if (count == 0) {
    return [[NSDictionary alloc] init];
  }
  // NSSingleObjectDictionary specialization.
  if (count == 1) {
    return [[NSDictionary alloc] initWithObjectsAndKeys:(__bridge_transfer id)objects[0], (__bridge_transfer id)keys[0], nil];
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
  CFDictionaryRef result = CFDictionaryCreate(kCFAllocatorDefault, keys, objects, count, &kCb, &vCb);
  PINSkipRetainFlag(PINFlagClear);
  return (__bridge_transfer NSDictionary *)result;
}

@end

@implementation NSSet (PINCollection)

+ (NSSet *)pin_setWithRetainedObjects:(CFTypeRef  _Nonnull [])objects count:(NSUInteger)count NS_RETURNS_RETAINED
{
  // NSSetZero singleton.
  if (count == 0) {
    return [[NSSet alloc] init];
  }
  // NSSingleObjectSet specialization.
  if (count == 1) {
    return [[NSSet alloc] initWithObjects:(__bridge_transfer id)objects[0], nil];
  }
  static CFSetCallBacks cb;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cb = kCFTypeSetCallBacks;
    cb.retain = PINRetainCallback;
  });
  PINSkipRetainFlag(PINFlagSet);
  CFSetRef result = CFSetCreate(kCFAllocatorDefault, objects, count, &cb);
  PINSkipRetainFlag(PINFlagClear);
  return (__bridge_transfer NSSet *)result;
}

@end
