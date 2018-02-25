//
//  PINLocker.h
//  PINMessagePack
//
//  Created by Adlai on 2/25/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pthread.h>

/**
 * Attach a mutex to the current scope. Same as std::mutex_locker, but available in C.
 *
 * Currently doesn't support nested scopes.
 */
#define PINLockScope(mutex) \
  const __typeof(mutex) _lclMutex = mutex; \
  pthread_mutex_lock(_lclMutex); \
  __unused _PINLockerState s __attribute__((__cleanup__(_PINLockerStateCleanup))) = { _lclMutex };

typedef struct {
  pthread_mutex_t *mutex;
} _PINLockerState;

NS_INLINE void _PINLockerStateCleanup(_PINLockerState *statePtr)
{
  __unused int result = pthread_mutex_unlock(statePtr->mutex);
  NSCAssert(result == noErr, @"Error unlocking: %s", strerror(result));
}
