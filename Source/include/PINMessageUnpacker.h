//
//  PINMessageUnpacker.h
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PINMessagePack/PINStreamingDecoding.h>

@class PINBuffer;

NS_ASSUME_NONNULL_BEGIN

/**
 * Objects of this class are not thread-safe, and must be paired with a lock to
 * be accessed from multiple threads.
 */
__attribute__((objc_subclassing_restricted))
@interface PINMessageUnpacker : NSObject<PINStreamingDecoder>

/**
 * Initialize an unpacker using the given buffer.
 */
- (instancetype)initWithBuffer:(PINBuffer *)buffer NS_DESIGNATED_INITIALIZER;

#pragma mark - Unavailable

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
