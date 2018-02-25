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
  __unsafe_unretained PINBuffer *buf = (__bridge PINBuffer *)ctx->buf;
  [buf writeData:[NSData dataWithBytes:data length:count]];
  return count;
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
  PINBuffer *buffer = [[PINBuffer alloc] init];
  cmp_init(&writeCtx, (__bridge void *)buffer, NULL, NULL, stream_writer);
  // Create reader
  u = [[PINMessageUnpacker alloc] initWithBuffer:buffer];
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testAnInteger {
  // Write an int
  int32_t wrote = 5;
  XCTAssertTrue(cmp_write_s32(&writeCtx, wrote));
  
  
  NSInteger v = [u decodeInteger];
  XCTAssertEqual(v, wrote);
  XCTAssertNil(u.error);
}

- (void)testForcingKeysToString {
  int32_t key0 = 5;
  int32_t val0 = 7;
  char key1[] = "Key1";
  int32_t val1 = 10;
  XCTAssertTrue(cmp_write_map(&writeCtx, 2));
  XCTAssertTrue(cmp_write_s32(&writeCtx, key0));
  XCTAssertTrue(cmp_write_s32(&writeCtx, val0));
  XCTAssertTrue(cmp_write_str(&writeCtx, key1, 4));
  XCTAssertTrue(cmp_write_s32(&writeCtx, val1));
  
  u.forcesMapKeysToString = YES;
  NSDictionary *dict = [u decodeDictionaryWithKeyClass:Nil objectClass:Nil];
  XCTAssertNil(u.error);
  XCTAssertEqualObjects(dict, (@{ @(key0).stringValue : @(val0), @(key1) : @(val1) }));
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

- (void)testReadingAllData
{
  PINBuffer *buf = [[PINBuffer alloc] init];
  Byte d0[2] = {0x01, 0x02};
  [buf writeData:[NSData dataWithBytes:d0 length:sizeof(d0)]];
  Byte d1[2] = {0x04, 0x05};
  [buf writeData:[NSData dataWithBytes:d1 length:sizeof(d0)]];
  [buf closeCompleted:YES];
  
  Byte allData[4] = {0x01, 0x02, 0x04, 0x05};
  NSData *expected = [NSData dataWithBytes:allData length:sizeof(allData)];
  
  NSData *read = [buf readAllData];;
  XCTAssertEqualObjects(read, expected);
  // Read again, get nothing.
  XCTAssertEqualObjects([buf readAllData], [NSData data]);
}

- (void)testPreservingAndReadingAllData
{
  PINBuffer *buf = [[PINBuffer alloc] init];
  buf.preserveData = YES;
  Byte d0[2] = {0x01, 0x02};
  [buf writeData:[NSData dataWithBytes:d0 length:sizeof(d0)]];
  Byte d1[2] = {0x04, 0x05};
  [buf writeData:[NSData dataWithBytes:d1 length:sizeof(d0)]];
  [buf closeCompleted:YES];
  
  Byte allData[4] = {0x01, 0x02, 0x04, 0x05};
  NSData *expected = [NSData dataWithBytes:allData length:sizeof(allData)];
  
  XCTAssertEqualObjects([buf readAllData], expected);
  XCTAssertEqualObjects([buf readAllData], expected);
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

- (NSData *)performanceMessagePackData NS_RETURNS_RETAINED
{
  static NSData *msgPackData;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    @autoreleasepool {
      NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:@"SampleDataBase64" ofType:nil];
      NSString *base64Str = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
      base64Str = [base64Str stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
      msgPackData = [[NSData alloc] initWithBase64EncodedString:base64Str options:kNilOptions];
    }
  });
  return msgPackData;
}

// TODO: Bigger object.
- (id)performanceDataObject NS_RETURNS_RETAINED
{
  static id obj;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    @autoreleasepool {
      PINBuffer *buf = [[PINBuffer alloc] init];
      [buf writeData:[self performanceMessagePackData]];
      [buf closeCompleted:YES];
      
      obj = [[[PINMessageUnpacker alloc] initWithBuffer:buf] decodeObjectOfClass:Nil];
    }
  });
  return obj;
}

- (void)testJSONPerformance
{
  id obj = [self performanceDataObject];
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:NULL];
  
  [self measureBlock:^{
    @autoreleasepool {
      dispatch_apply(4, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t i) {
        @autoreleasepool {
          [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        }
      });
    }
  }];
  
}

- (void)testMessagePackPerformance
{
  NSData *msgPackData = [self performanceMessagePackData];
  
  [self measureBlock:^{
    @autoreleasepool {
      dispatch_apply(4, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t i) {
        @autoreleasepool {
          PINBuffer *buf = [[PINBuffer alloc] init];
          [buf writeData:msgPackData];
          [buf closeCompleted:YES];
          
          [[[PINMessageUnpacker alloc] initWithBuffer:buf] decodeObjectOfClass:Nil];
        }
      });
    }
  }];
}

- (NSData *)messagePackDataWithBlock:(void(^)(cmp_ctx_t *ctx))block
{
  PINBuffer *buf = [[PINBuffer alloc] init];
  cmp_ctx_t ctx;
  cmp_init(&ctx, (__bridge void *)buf, NULL, NULL, stream_writer);
  block(&ctx);
  [buf closeCompleted:YES];
  return [buf readAllData];
}

@end
