// RFC 8529 conformance tests.
//
// Tests are taken from https://github.com/nst/JSONTestSuite
// Read also http://seriot.ch/parsing_json.php for a good overview.

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Parser = @import("./dynamic.zig").Parser;
const validate = @import("./scanner.zig").validate;
const JsonScanner = @import("./scanner.zig").JsonScanner;

fn testLowLevelScanner(s: []const u8) !void {
    var scanner = JsonScanner.initCompleteInput(testing.allocator, s);
    defer scanner.deinit();

    while (true) {
        const token = try scanner.next();
        if (token == .end_of_document) break;
    }
}
fn testHighLevelDynamicParser(s: []const u8) !void {
    var p = Parser.init(testing.allocator, .alloc_if_needed);
    defer p.deinit();

    var tree = try p.parse(s);
    defer tree.deinit();
}

pub fn ok(s: []const u8) !void {
    try testLowLevelScanner(s);

    try testHighLevelDynamicParser(s);
}

pub fn err(s: []const u8) !void {
    try testing.expect(std.meta.isError(testLowLevelScanner(s)));

    try testing.expect(std.meta.isError(testHighLevelDynamicParser(s)));
}

fn utf8Error(s: []const u8) !void {
    return err(s);
}

pub fn any(s: []const u8) !void {
    testLowLevelScanner(s) catch {};

    testHighLevelDynamicParser(s) catch {};
}

fn roundTrip(s: []const u8) !void {
    try testing.expect(try validate(testing.allocator, s));

    var p = Parser.init(testing.allocator, .alloc_if_needed);
    defer p.deinit();

    var tree = try p.parse(s);
    defer tree.deinit();

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try tree.root.jsonStringify(.{}, fbs.writer());

    try testing.expectEqualStrings(s, fbs.getWritten());
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Additional tests not part of test JSONTestSuite.

test "y_trailing_comma_after_empty" {
    try roundTrip(
        \\{"1":[],"2":{},"3":"4"}
    );
}

test "n_object_closed_missing_value" {
    try err(
        \\{"a":}
    );
}

////////////////////////////////////////////////////////////////////////////////////////////////////

test "truncated UTF-8 sequence" {
    try utf8Error("\"\xc2\"");
    try utf8Error("\"\xdf\"");
    try utf8Error("\"\xed\xa0\"");
    try utf8Error("\"\xf0\x80\"");
    try utf8Error("\"\xf0\x80\x80\"");
}

test "invalid continuation byte" {
    try utf8Error("\"\xc2\x00\"");
    try utf8Error("\"\xc2\x7f\"");
    try utf8Error("\"\xc2\xc0\"");
    try utf8Error("\"\xc3\xc1\"");
    try utf8Error("\"\xc4\xf5\"");
    try utf8Error("\"\xc5\xff\"");
    try utf8Error("\"\xe4\x80\x00\"");
    try utf8Error("\"\xe5\x80\x10\"");
    try utf8Error("\"\xe6\x80\xc0\"");
    try utf8Error("\"\xe7\x80\xf5\"");
    try utf8Error("\"\xe8\x00\x80\"");
    try utf8Error("\"\xf2\x00\x80\x80\"");
    try utf8Error("\"\xf0\x80\x00\x80\"");
    try utf8Error("\"\xf1\x80\xc0\x80\"");
    try utf8Error("\"\xf2\x80\x80\x00\"");
    try utf8Error("\"\xf3\x80\x80\xc0\"");
    try utf8Error("\"\xf4\x80\x80\xf5\"");
}

test "disallowed overlong form" {
    try utf8Error("\"\xc0\x80\"");
    try utf8Error("\"\xc0\x90\"");
    try utf8Error("\"\xc1\x80\"");
    try utf8Error("\"\xc1\x90\"");
    try utf8Error("\"\xe0\x80\x80\"");
    try utf8Error("\"\xf0\x80\x80\x80\"");
}

test "out of UTF-16 range" {
    try utf8Error("\"\xf4\x90\x80\x80\"");
    try utf8Error("\"\xf5\x80\x80\x80\"");
    try utf8Error("\"\xf6\x80\x80\x80\"");
    try utf8Error("\"\xf7\x80\x80\x80\"");
    try utf8Error("\"\xf8\x80\x80\x80\"");
    try utf8Error("\"\xf9\x80\x80\x80\"");
    try utf8Error("\"\xfa\x80\x80\x80\"");
    try utf8Error("\"\xfb\x80\x80\x80\"");
    try utf8Error("\"\xfc\x80\x80\x80\"");
    try utf8Error("\"\xfd\x80\x80\x80\"");
    try utf8Error("\"\xfe\x80\x80\x80\"");
    try utf8Error("\"\xff\x80\x80\x80\"");
}
