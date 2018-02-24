//
//  PINBuffer.m
//  PINMessagePack
//
//  Created by Adlai on 2/22/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINBuffer.h"
#import <pthread/pthread.h>
#import <stdatomic.h>

@interface PINBuffer ()
@end

@implementation PINBuffer {
  // Fixed
  pthread_cond_t _cond;
  pthread_mutex_t _mutex;

  // Atomic
  _Atomic(PINBufferState) _state;
  
  // Only accessed from the reader thread. The current data.
  __unsafe_unretained NSData *_reader_data;
  NSUInteger _reader_dataLength;
  NSUInteger _reader_index;
  
  // Accessed from both threads – guarded by mutex.
  NSMutableArray<NSData *> *_datas;
  NSUInteger _dataCount;
}

- (instancetype)init
{
  if (self = [super init]) {
    int result = pthread_cond_init(&_cond, NULL);
    NSAssert(result == noErr, @"Failed to create condition: %s", strerror(result));
    result = pthread_mutex_init(&_mutex, NULL);
    NSAssert(result == noErr, @"Failed to create mutex: %s", strerror(result));
    _datas = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc
{
  int result = pthread_mutex_destroy(&_mutex);
  NSCAssert(result == noErr, @"error destroying mutex: %s", strerror(result));
  result = pthread_cond_destroy(&_cond);
  NSCAssert(result == noErr, @"error destroying cond: %s", strerror(result));
}

- (BOOL)read:(uint8_t *)buffer length:(NSUInteger)len
{
  NSUInteger needed = len;
  while (needed > 0) {
    
    // Get a data if we don't have one.
    if (_reader_data == nil) {
      pthread_mutex_lock(&_mutex); {
        // While we're open and have no data, wait.
        while (_dataCount == 0 && self.state == PINBufferStateNormal) {
          pthread_cond_wait(&_cond, &_mutex);
        }
        
        // We have data and/or we're closed. Handle each case.
        if (_dataCount > 0) {
          _reader_data = [_datas objectAtIndex:0];
        } else {
          pthread_mutex_unlock(&_mutex);
          return NO;
        }
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

- (NSData *)readAllData NS_RETURNS_RETAINED
{
  NSCAssert(self.state != PINBufferStateNormal, @"Cannot read NSData on open PINBuffer.");
  NSUInteger bufSize = 0;
  for (NSData *data in _datas) {
    bufSize += data.length;
  }
  if (bufSize == 0) {
    return [[NSData alloc] init];
  }
  
  void *buf = malloc(bufSize);
  __block NSUInteger read = 0;
  for (NSData *data in _datas) {
    [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
      memcpy(buf + read, bytes, byteRange.length);
      read += byteRange.length;
    }];
  }
  [_datas removeAllObjects];
  return [[NSData alloc] initWithBytesNoCopy:buf length:bufSize];
}

- (void)writeData:(NSData *)data
{
  NSData *copy = [data copy];
  pthread_mutex_lock(&_mutex); {
    NSCAssert(self.state == PINBufferStateNormal, @"Writing after closing PINBuffer.");
    _datas[_dataCount] = copy;
    if (_dataCount == 0) {
      pthread_cond_signal(&_cond);
    }
    _dataCount += 1;
  }
  pthread_mutex_unlock(&_mutex);
}

- (void)closeCompleted:(BOOL)completed
{
  NSCAssert(self.state == PINBufferStateNormal, @"Cannot close already-closed buffer.");
  pthread_mutex_lock(&_mutex);
  atomic_store(&_state, completed ? PINBufferStateCompleted : PINBufferStateError);
  pthread_cond_signal(&_cond);
  pthread_mutex_unlock(&_mutex);
}

- (PINBufferState)state
{
  return atomic_load(&_state);
}

@end
