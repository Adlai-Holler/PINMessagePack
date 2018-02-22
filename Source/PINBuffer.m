//
//  PINBuffer.m
//  PINMessagePack
//
//  Created by Adlai on 2/22/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINBuffer.h"
#import <pthread/pthread.h>

@interface PINBuffer ()
@end

@implementation PINBuffer {
  pthread_cond_t _cond;
  pthread_mutex_t _mutex;
  // How far into the first data we are.
  NSUInteger _index;
  
  NSMutableArray<NSData *> *_datas;
  __unsafe_unretained NSData *_firstData;
  NSUInteger _firstDataLength;
  NSUInteger _dataCount;
}

- (instancetype)init
{
  if (self = [super init]) {
    int result = pthread_cond_init(&_cond, NULL);
    NSAssert(result == noErr, @"Failed to create condition.");
    result = pthread_mutex_init(&_mutex, NULL);
    NSAssert(result == noErr, @"Failed to create mutex.");
    _datas = [NSMutableArray array];
  }
  return self;
}

- (void)read:(uint8_t *)buffer length:(NSUInteger)len
{
  NSUInteger needed = len;
  BOOL haveLock = NO;
  while (needed > 0) {
    if (!haveLock) {
      pthread_mutex_lock(&_mutex);
      while (_firstData == nil) {
        pthread_cond_wait(&_cond, &_mutex);
      }
      haveLock = YES;
    }
    NSUInteger available = _firstDataLength - _index;
    NSRange range = NSMakeRange(_index, MIN(needed, available));
    [_firstData getBytes:buffer range:range];
    if (range.length == available) {
      [_datas removeObjectAtIndex:0];
      _dataCount -= 1;
      _firstData = _dataCount ? [_datas objectAtIndex:0] : nil;
      _firstDataLength = _firstData.length;
      _index = 0;
    } else {
      _index = NSMaxRange(range);
    }
    needed -= range.length;
    
    // If we ran out of datas, unlock so that the writer can give us more.
    if (_dataCount == 0) {
      pthread_mutex_unlock(&_mutex);
      haveLock = NO;
    }
  }
  
  if (haveLock) {
    pthread_mutex_unlock(&_mutex);
    haveLock = NO;
  }
}

- (void)writeData:(NSData *)data
{
  pthread_mutex_lock(&_mutex);
  _datas[_dataCount] = data;
  if (_dataCount == 0) {
    _firstData = data;
    _firstDataLength = data.length;
  }
  _dataCount += 1;
  pthread_cond_signal(&_cond);
  pthread_mutex_unlock(&_mutex);
}

@end
