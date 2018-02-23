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

  // Only accessed from the reader thread. The current data.
  __unsafe_unretained NSData *_reader_data;
  NSUInteger _reader_dataLength;
  NSUInteger _reader_index;
  
  // Accessed from both threads – guarded by mutex.
  NSMutableArray<NSData *> *_datas;
  NSUInteger _dataCount;
  BOOL _closed;
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

- (void)dealloc
{
  int result = pthread_mutex_destroy(&_mutex);
  NSCAssert(result == noErr, @"error destroying mutex");
  result = pthread_cond_destroy(&_cond);
  NSCAssert(result == noErr, @"error destroying cond");
}

- (BOOL)read:(uint8_t *)buffer length:(NSUInteger)len
{
  NSUInteger needed = len;
  while (needed > 0) {
    
    // Get a data if we don't have one.
    if (_reader_data == nil) {
      pthread_mutex_lock(&_mutex); {
        while (_dataCount == 0 && !_closed) {
          pthread_cond_wait(&_cond, &_mutex);
        }
        if (_closed) {
          return NO;
        }
        _reader_data = [_datas objectAtIndex:0];
      }
      pthread_mutex_unlock(&_mutex);
      _reader_dataLength = _reader_data.length;
    }
    
    // Read data.
    NSUInteger available = _reader_dataLength - _reader_index;
    NSRange range = NSMakeRange(_reader_index, MIN(needed, available));
    [_reader_data getBytes:buffer range:range];
    _reader_index = NSMaxRange(range);
    
    // If we read to the end, try to get another one.
    if (_reader_index == _reader_dataLength) {
      _reader_data = nil;
      _reader_dataLength = 0;
      
      pthread_mutex_lock(&_mutex); {
        [_datas removeObjectAtIndex:0];
        _dataCount -= 1;
        _reader_data = _dataCount ? [_datas objectAtIndex:0] : nil;
      }
      pthread_mutex_unlock(&_mutex);
      
      _reader_dataLength = _reader_data.length;
      _reader_index = 0;
    }
    needed -= range.length;
    buffer += range.length;
  }
  return YES;
}

- (void)writeData:(NSData *)data
{
  NSData *copy = [data copy];
  pthread_mutex_lock(&_mutex); {
    NSCAssert(!_closed, @"Writing after closing PINBuffer.");
    _datas[_dataCount] = copy;
    if (_dataCount == 0) {
      pthread_cond_signal(&_cond);
    }
    _dataCount += 1;
  }
  pthread_mutex_unlock(&_mutex);
}

- (void)close
{
  pthread_mutex_lock(&_mutex); {
    _closed = YES;
    pthread_cond_signal(&_cond);
  }
  pthread_mutex_unlock(&_mutex);
}

@end
