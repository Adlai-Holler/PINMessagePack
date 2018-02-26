//
//  PINCollections.m
//  PINMessagePack
//
//  Created by Adlai on 2/18/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINCollections.h"

// Thread-local flag that tells our custom callbacks to skip the initial retain.
// If user explicitly calls CFArrayCreateCopy then CF will make a real copy,
// and at that time we need to do a real retain (no flag).
static _Thread_local BOOL tls_skipRetain;

static const void *PINRetainCallback(CFAllocatorRef allocator, const void *value)
{
  if (tls_skipRetain) {
    return value;
  } else {
    return (&kCFTypeArrayCallBacks)->retain(allocator, value);
  }
}

static const void *PINCopyCallback(CFAllocatorRef allocator, const void *value)
{
  if (tls_skipRetain) {
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
  tls_skipRetain = YES;
  CFArrayRef result = CFArrayCreate(kCFAllocatorDefault, objects, count, &cb);
  tls_skipRetain = NO;
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
  
  tls_skipRetain = YES;
  CFDictionaryRef result = CFDictionaryCreate(kCFAllocatorDefault, keys, objects, count, &kCb, &vCb);
  tls_skipRetain = NO;
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
  tls_skipRetain = YES;
  CFSetRef result = CFSetCreate(kCFAllocatorDefault, objects, count, &cb);
  tls_skipRetain = NO;
  return (__bridge_transfer NSSet *)result;
}

@end
