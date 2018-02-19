//
//  PINMessagePackValues.m
//  PINMessagePack
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import "PINMessagePackValues.h"
#import "cmp.h"

extern PINMessagePackValueType PINMessagePackValueTypeFromCMPType(int cmpType)
{
  switch (cmpType) {
    case CMP_TYPE_BOOLEAN:
      return PINMessagePackValueBool;
    case CMP_TYPE_NIL:
      return PINMessagePackValueNil;
    case CMP_TYPE_STR8:
    case CMP_TYPE_STR16:
    case CMP_TYPE_STR32:
    case CMP_TYPE_FIXSTR:
      return PINMessagePackValueString;
    case CMP_TYPE_BIN8:
    case CMP_TYPE_BIN16:
    case CMP_TYPE_BIN32:
      return PINMessagePackValueBinary;
    case CMP_TYPE_DOUBLE:
      return PINMessagePackValueDouble;
    case CMP_TYPE_FLOAT:
      return PINMessagePackValueFloat;
    case CMP_TYPE_ARRAY16:
    case CMP_TYPE_ARRAY32:
    case CMP_TYPE_FIXARRAY:
      return PINMessagePackValueArray;
    case CMP_TYPE_MAP16:
    case CMP_TYPE_MAP32:
    case CMP_TYPE_FIXMAP:
      return PINMessagePackValueMap;
    case CMP_TYPE_SINT8:
    case CMP_TYPE_SINT16:
    case CMP_TYPE_SINT32:
      return PINMessagePackSignedInteger;
    case CMP_TYPE_SINT64:
      return PINMessagePackSignedInt64;
    case CMP_TYPE_POSITIVE_FIXNUM:
    case CMP_TYPE_UINT8:
    case CMP_TYPE_UINT16:
    case CMP_TYPE_UINT32:
      return PINMessagePackUnsignedInteger;
    case CMP_TYPE_UINT64:
      return PINMessagePackUnsignedInt64;
    default:
      NSCAssert(NO, @"Failed to map.");
      return PINMessagePackValueUnspecified;
  }
}
