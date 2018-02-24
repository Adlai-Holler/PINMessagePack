//
//  PINStreamingDecoding.h
//  PINMessagePack
//
//  Created by Adlai on 2/20/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PINStreamingDecoder;

@protocol PINStreamingDecoding <NSObject>

/**
 * Attempt to initialize this instance using the given streaming decoder.
 *
 * You do not call this method directly. Instead, create a decoder and call
 * -decodeObjectOfClass: on it.
 */
- (nullable instancetype)initWithStreamingDecoder:(id<PINStreamingDecoder>)decoder;

@end

@protocol PINStreamingDecoder <NSObject>

/**
 * The most recent error that occurred during decoding, if any.
 */
@property (nonatomic, nullable, copy, readonly) NSError *error;

/**
 * A fast way to enumerate keys in an encoded map.
 *
 * Useful for directly decoding messagepack into an object in
 * your -initWithStreamingDecoder implementation.
 */
- (void)enumerateKeysInMapWithBlock:(void (^NS_NOESCAPE)(const char *key, NSUInteger keyLen))block;

/**
 * Decode a boolean value.
 */
- (BOOL)decodeBOOL;

/**
 * Decode a floating point value as double.
 */
- (double)decodeDouble;

/**
 * Decode an integer.
 */
- (NSInteger)decodeInteger;

/**
 * Decode an object of the given class.
 *
 * For arrays, sets, and dictionaries you should prefer -decodeArray et al.
 *
 * Possible return types are NSNumber, NSString,
 * NSData, NSArray, NSDictionary, or the class you provide.
 *
 * Mutable collection types are not currently supported.
 *
 * NSNull will not be returned. Nils will be decoded as nil.
 */
- (nullable id)decodeObjectOfClass:(nullable Class)class NS_RETURNS_RETAINED;

/**
 * Decodes an array.
 *
 * @param class The class of elements. Heterogenous collections are not supported.
 * WARNING: Nils inside the collection will be decoded as NSNull.
 */
- (nullable NSArray *)decodeArrayOfClass:(nullable Class)class NS_RETURNS_RETAINED;

/**
 * Decodes a set.
 *
 * @param class The class of elements. Heterogenous collections are not supported.
 * WARNING: Nils inside the collection will be decoded as NSNull.
 */
- (nullable NSSet *)decodeSetOfClass:(nullable Class)class NS_RETURNS_RETAINED;

/**
 * Decodes a dictionary.
 *
 * @param keyClass The class of keys in the dictionary, or Nil to accept any class.
 * @param objectClass The class of values in the dictionary, or Nil to accept any class.
 */
- (nullable NSDictionary *)decodeDictionaryWithKeyClass:(nullable Class)keyClass
                                            objectClass:(nullable Class)objectClass NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END

