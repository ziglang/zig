const std = @import("std");
const testing = std.testing;
const parseFromSlice = @import("./static.zig").parseFromSlice;
const validate = @import("./scanner.zig").validate;
const JsonScanner = @import("./scanner.zig").Scanner;
const Value = @import("./dynamic.zig").Value;
const stringifyAlloc = @import("./stringify.zig").stringifyAlloc;

// Support for JSONTestSuite.zig
pub fn ok(s: []const u8) !void {
    try testLowLevelScanner(s);
    try testHighLevelDynamicParser(s);
}
pub fn err(s: []const u8) !void {
    try testing.expect(std.meta.isError(testLowLevelScanner(s)));
    try testing.expect(std.meta.isError(testHighLevelDynamicParser(s)));
}
pub fn any(s: []const u8) !void {
    testLowLevelScanner(s) catch {};
    testHighLevelDynamicParser(s) catch {};
}
fn testLowLevelScanner(s: []const u8) !void {
    var scanner = JsonScanner.initCompleteInput(testing.allocator, s);
    defer scanner.deinit();
    while (true) {
        const token = try scanner.next();
        if (token == .end_of_document) break;
    }
}
fn testHighLevelDynamicParser(s: []const u8) !void {
    var parsed = try parseFromSlice(Value, testing.allocator, s, .{});
    defer parsed.deinit();
}

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

fn roundTrip(s: []const u8) !void {
    try testing.expect(try validate(testing.allocator, s));

    var parsed = try parseFromSlice(Value, testing.allocator, s, .{});
    defer parsed.deinit();

    const rendered = try stringifyAlloc(testing.allocator, parsed.value, .{});
    defer testing.allocator.free(rendered);

    try testing.expectEqualStrings(s, rendered);
}

test "truncated UTF-8 sequence" {
    try err("\"\xc2\"");
    try err("\"\xdf\"");
    try err("\"\xed\xa0\"");
    try err("\"\xf0\x80\"");
    try err("\"\xf0\x80\x80\"");
}

test "invalid continuation byte" {
    try err("\"\xc2\x00\"");
    try err("\"\xc2\x7f\"");
    try err("\"\xc2\xc0\"");
    try err("\"\xc3\xc1\"");
    try err("\"\xc4\xf5\"");
    try err("\"\xc5\xff\"");
    try err("\"\xe4\x80\x00\"");
    try err("\"\xe5\x80\x10\"");
    try err("\"\xe6\x80\xc0\"");
    try err("\"\xe7\x80\xf5\"");
    try err("\"\xe8\x00\x80\"");
    try err("\"\xf2\x00\x80\x80\"");
    try err("\"\xf0\x80\x00\x80\"");
    try err("\"\xf1\x80\xc0\x80\"");
    try err("\"\xf2\x80\x80\x00\"");
    try err("\"\xf3\x80\x80\xc0\"");
    try err("\"\xf4\x80\x80\xf5\"");
}

test "disallowed overlong form" {
    try err("\"\xc0\x80\"");
    try err("\"\xc0\x90\"");
    try err("\"\xc1\x80\"");
    try err("\"\xc1\x90\"");
    try err("\"\xe0\x80\x80\"");
    try err("\"\xf0\x80\x80\x80\"");
}

test "out of UTF-16 range" {
    try err("\"\xf4\x90\x80\x80\"");
    try err("\"\xf5\x80\x80\x80\"");
    try err("\"\xf6\x80\x80\x80\"");
    try err("\"\xf7\x80\x80\x80\"");
    try err("\"\xf8\x80\x80\x80\"");
    try err("\"\xf9\x80\x80\x80\"");
    try err("\"\xfa\x80\x80\x80\"");
    try err("\"\xfb\x80\x80\x80\"");
    try err("\"\xfc\x80\x80\x80\"");
    try err("\"\xfd\x80\x80\x80\"");
    try err("\"\xfe\x80\x80\x80\"");
    try err("\"\xff\x80\x80\x80\"");
}
