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
  
  
  NSInteger v = [u decodeInteger];
  XCTAssertEqual(v, wrote);
  XCTAssertNil(u.error);
}

- (void)testAString {
  char wrote[] = "Hello, world";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 12));
  
  NSUInteger l;
  char *str = [u decodeCStringWithReturnedLength:&l];
  XCTAssertEqualObjects(@(wrote), @(str));
  XCTAssertEqual(l, 12);
  XCTAssertNil(u.error);
}

- (void)testATaggedString {
  char wrote[] = "012345678";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 9));

  XCTAssertEqualObjects(@(wrote), [u decodeObjectOfClass:[NSString class]]);
  XCTAssertNil(u.error);
}

- (void)testANonTaggedString {
  char wrote[] = "0123456789";
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote, 10));
  
  XCTAssertEqualObjects(@(wrote), [u decodeObjectOfClass:[NSString class]]);
  XCTAssertNil(u.error);
}

- (void)testAStringNSArray {
  char wrote0[] = "Hello";
  char wrote1[] = "world";
  XCTAssertTrue(cmp_write_array(&writeCtx, 2));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote0, 5));
  XCTAssertTrue(cmp_write_str(&writeCtx, wrote1, 5));
  
  NSArray<NSString *> *arr = [u decodeArrayOfClass:[NSString class]];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(arr, (@[ @"Hello", @"world" ]));
}

- (void)testEmptyNSArray {
  XCTAssertTrue(cmp_write_array(&writeCtx, 0));
  
  NSArray *arr = [u decodeArrayOfClass:[NSString class]];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(arr, @[]);
}

- (void)testEmptyNSDictionary {
  XCTAssertTrue(cmp_write_map(&writeCtx, 0));
  
  NSDictionary *d = [u decodeDictionaryWithKeyClass:[NSString class] objectClass:[NSString class]];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(d, @{});
}

- (void)testAnEmptyString {
  XCTAssertTrue(cmp_write_str(&writeCtx, "", 0));
  
  NSString *str = [u decodeObjectOfClass:[NSString class]];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(str, @"");
}

- (void)testA1CharString {
  XCTAssertTrue(cmp_write_str(&writeCtx, "A", 1));
  
  NSString *str = [u decodeObjectOfClass:[NSString class]];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(str, @"A");
}

- (void)testASimpleData {
  Byte data[3] = {0x01, 0x02, 0x03};
  XCTAssertTrue(cmp_write_bin(&writeCtx, data, 3));
  
  NSData *d = [u decodeObjectOfClass:[NSData class]];
  XCTAssertEqualObjects(d, [NSData dataWithBytes:data length:3]);
  XCTAssertNil(u.error);
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
  
  NSDictionary *dict = [u decodeDictionaryWithKeyClass:[NSString class] objectClass:Nil];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(dict, (@{ @(key0) : @(val0), @(key1) : @(val1) }));
}

- (void)testARealResponse
{
  // TODO: Need new reference MsgPack data in SampleDataBase64 – old data captured from server before fix.
  return;
  
  // Read the ref object from the plist in our bundle.
//  NSString *refPath = [[NSBundle bundleForClass:self.class] pathForResource:@"MessagePackRefObject" ofType:@"plist"];
//  id refObject = [NSKeyedUnarchiver unarchiveObjectWithFile:refPath];
//  XCTAssertNotNil(refObject);
//  
//  NSString *base64String = [NSString stringWithContentsOfFile:[[NSBundle bundleForClass:self.class] pathForResource:@"SampleDataBase64" ofType:nil] encoding:NSUTF8StringEncoding error:NULL];
//  // Strip off trailing newline.
//  base64String = [base64String stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
//  NSData *d = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
//  XCTAssertGreaterThan(d.length, 0);
//  
//  NSInputStream *s = [NSInputStream inputStreamWithData:d];
//  PINMessageUnpacker *u = [[PINMessageUnpacker alloc] initWithInputStream:s];
//  id obj = [u decodeDictionaryWithKeyClass:[NSString class] objectClass:Nil];
//  XCTAssertEqualObjects(obj, refObject);
}

@end
