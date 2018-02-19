//
//  PINMessagePackValue.h
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const char *PINMessagePackArrayType;
extern const char *PINMessagePackMapType;

typedef NS_ENUM(NSInteger, PINMessagePackValueType) {
  PINMessagePackValueUnspecified,
  PINMessagePackValueNil,
  PINMessagePackValueBool,
  PINMessagePackValueArray,
  PINMessagePackValueMap,
  PINMessagePackValueString,
  PINMessagePackValueFloat,
  PINMessagePackValueDouble,
  PINMessagePackValueBinary,
  PINMessagePackUnsignedInteger,
  PINMessagePackUnsignedInt64,
  PINMessagePackSignedInteger,
  PINMessagePackSignedInt64
};

extern PINMessagePackValueType PINMessagePackValueTypeFromCMPType(int cmpType);

NS_ASSUME_NONNULL_END
