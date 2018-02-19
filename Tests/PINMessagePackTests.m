//
//  PINMessagePackTests.m
//  PINMessagePackTests
//
//  Created by Adlai on 2/16/18.
//  Copyright © 2018 Pinterest. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "cmp.h"
#import "PINMessagePack.h"

static size_t stream_writer(cmp_ctx_t *ctx, const void *data, size_t count)
{
  CFWriteStreamRef w = (CFWriteStreamRef)ctx->buf;
  CFIndex result = CFWriteStreamWrite(w, data, count);
  return (size_t)result;
}

@interface PINMessagePackTests : XCTestCase

@end

@implementation PINMessagePackTests {
  cmp_ctx_t writeCtx;
  PINMessageUnpacker *u;
  NSOutputStream *outputStream;
}

- (void)setUp {
  [super setUp];
  NSInputStream *input;
  NSOutputStream *lclOutputStream;
  [NSStream getBoundStreamsWithBufferSize:1048576 inputStream:&input outputStream:&lclOutputStream];
  outputStream = lclOutputStream;
  // Create writer
  [lclOutputStream open];
  cmp_init(&writeCtx, (__bridge void *)outputStream, NULL, NULL, stream_writer);
  // Create reader
  u = [[PINMessageUnpacker alloc] initWithInputStream:input];
}

- (void)tearDown
{
  [super tearDown];
  [outputStream close];
}

- (void)testAnInteger {
  // Write an int
  int32_t wrote = 5;
  XCTAssertTrue(cmp_write_s32(&writeCtx, wrote));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackSignedInteger);
  NSInteger v;
  XCTAssertTrue([u readInteger:&v]);
  XCTAssertEqual(v, wrote);
}

- (void)testAString {
  char wrote[] = "Hello, world";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 12));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueString);
  PINReadString(u, str);
  XCTAssertEqualObjects(@(wrote), @(str));
  XCTAssertNil(u.error);
}

- (void)testATaggedString {
  char wrote[] = "012345678";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 9));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueString);
  NSError *e;
  XCTAssertEqualObjects(@(wrote), [u readNSStringWithError:&e]);
  XCTAssertNil(e);
}

- (void)testANonTaggedString {
  char wrote[] = "0123456789";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 10));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueString);
  NSError *e;
  XCTAssertEqualObjects(@(wrote), [u readNSStringWithError:&e]);
  XCTAssertNil(e);
}

- (void)testAStringArray {
  char wrote0[] = "Hello";
  char wrote1[] = "world";
  XCTAssertTrue(cmp_write_array(&writeCtx, 2));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote0, 5));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote1, 5));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueArray);
  uint32_t c;
  XCTAssertTrue([u readArrayCount:&c]);
  XCTAssertEqual(c, 2);
  PINReadString(u, str0);
  PINReadString(u, str1);
  XCTAssertEqualObjects(@(wrote0), @(str0));
  XCTAssertEqualObjects(@(wrote1), @(str1));
  XCTAssertNil(u.error);
}

- (void)testAStringNSArray {
  char wrote0[] = "Hello";
  char wrote1[] = "world";
  XCTAssertTrue(cmp_write_array(&writeCtx, 2));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote0, 5));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote1, 5));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueArray);
  NSError *e;
  NSArray<NSString *> *arr = [u readNSArrayWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(arr, (@[ @"Hello", @"world" ]));
}

- (void)testEmptyNSArray {
  XCTAssertTrue(cmp_write_array(&writeCtx, 0));
  
  NSError *e;
  NSArray *arr = [u readNSArrayWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(arr, @[]);
}

- (void)testEmptyNSDictionary {
  XCTAssertTrue(cmp_write_map(&writeCtx, 0));
  
  NSError *e;
  NSDictionary *arr = [u readNSDictionaryWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(arr, @{});
}

- (void)testAnEmptyString {
  XCTAssertTrue(cmp_write_str(&writeCtx, "", 0));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueString);
  NSError *e;
  NSString *str = [u readNSStringWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(str, @"");
}

- (void)testA1CharString {
  XCTAssertTrue(cmp_write_str(&writeCtx, "A", 1));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueString);
  NSError *e;
  NSString *str = [u readNSStringWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(str, @"A");
}

- (void)testASimpleData {
  Byte data[3] = {0x01, 0x02, 0x03};
  XCTAssertTrue(cmp_write_bin(&writeCtx, data, 3));
  
  uint32_t bufSize;
  XCTAssertTrue([u readDataLength:&bufSize]);
  XCTAssertEqual(bufSize, 3);
  Byte buf[bufSize];
  XCTAssertTrue([u readData:buf length:bufSize]);
  XCTAssertEqual(memcmp(data, buf, 3), 0);
}

- (void)testASimpleNSData {
  Byte data[3] = {0x01, 0x02, 0x03};
  XCTAssertTrue(cmp_write_bin(&writeCtx, data, 3));
  
  NSError *e;
  NSData *d = [u readNSDataWithError:&e];
  XCTAssertEqualObjects(d, [NSData dataWithBytes:data length:3]);
  XCTAssertNil(e);
}

- (void)testASimpleMapNSDictionary {
  char key0[] = "Key0";
  int32_t val0 = 7;
  char key1[] = "Key1";
  char val1[] = "Val1";
  XCTAssertTrue(cmp_write_map(&writeCtx, 2));
  XCTAssertTrue(cmp_write_str(&writeCtx, key0, 4));
  XCTAssertTrue(cmp_write_s32(&writeCtx, val0));
  XCTAssertTrue(cmp_write_str(&writeCtx, key1, 4));
  XCTAssertTrue(cmp_write_str(&writeCtx, val1, 4));
  
  XCTAssertEqual(u.currentValueType, PINMessagePackValueMap);
  NSError *e;
  NSDictionary *dict = [u readNSDictionaryWithError:&e];
  XCTAssertNil(e);
  XCTAssertEqualObjects(dict, (@{ @(key0) : @(val0), @(key1) : @(val1) }));
}

@end
