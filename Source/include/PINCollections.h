//
//  PINCollections.h
//  PINMessagePack
//
//  Created by Adlai on 2/18/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (PINCollection)

/**
 * Creates an array with an array of +1 CFTypeRefs, transferring the
 * +1 into the array. This is useful because it avoids retaining each of the objects
 * and then releasing each of them, as would happen if you take a C-array
 * of 
 */
+ (NSArray *)pin_arrayWithRetainedObjects:(CFTypeRef _Nonnull [_Nonnull])objects
                                    count:(NSUInteger)count NS_RETURNS_RETAINED;

@end

@interface NSDictionary (PINCollection)

+ (NSDictionary *)pin_dictionaryWithRetainedObjects:(CFTypeRef _Nonnull [_Nonnull])objects
                                               keys:(CFTypeRef _Nonnull [_Nonnull])keys
                                              count:(NSUInteger)count NS_RETURNS_RETAINED;

@end

@interface NSSet (PINCollection)

+ (NSSet *)pin_setWithRetainedObjects:(CFTypeRef _Nonnull [_Nonnull])objects
                                count:(NSUInteger)count NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END

