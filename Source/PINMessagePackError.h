//
//  PINMessagePackError.h
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const PINMessagePackErrorDomain;

NS_ERROR_ENUM(PINMessagePackErrorDomain)
{
  PINMessagePackErrorStringDataTooLong = 1,
  PINMessagePackErrorBinaryDataTooLong,
  PINMessagePackErrorArrayTooLong,
  PINMessagePackErrorMapTooLong,
  PINMessagePackErrorInputTooLarge,
  PINMessagePackErrorWritingFixedValue,
  PINMessagePackErrorReadingTypeMarker,
  PINMessagePackErrorWritingTypeMarker,
  PINMessagePackErrorReadingData,
  PINMessagePackErrorWritingData,
  PINMessagePackErrorReadingExtType,
  PINMessagePackErrorWritingExtType,
  PINMessagePackErrorInvalidType,
  PINMessagePackErrorReadingLength,
  PINMessagePackErrorWritingLength,
  PINMessagePackErrorSkipDepthLimitExceeded,
  PINMessagePackInternalError
};

NS_ASSUME_NONNULL_END
