//! JSON parsing and stringification conforming to RFC 8259. https://datatracker.ietf.org/doc/html/rfc8259
//!
//! The low-level `Scanner` API produces `Token`s from an input slice or successive slices of inputs,
//! The `Reader` API connects a `std.io.Reader` to a `Scanner`.
//!
//! The high-level `parseFromSlice` and `parseFromTokenSource` deserialize a JSON document into a Zig type.
//! Parse into a dynamically-typed `Value` to load any JSON value for runtime inspection.
//!
//! The low-level `writeStream` emits syntax-conformant JSON tokens to a `std.io.Writer`.
//! The high-level `stringify` serializes a Zig or `Value` type into JSON.

const testing = @import("std").testing;
const ArrayList = @import("std").ArrayList;

test Scanner {
    var scanner = Scanner.initCompleteInput(testing.allocator, "{\"foo\": 123}\n");
    defer scanner.deinit();
    try testing.expectEqual(Token.object_begin, try scanner.next());
    try testing.expectEqualSlices(u8, "foo", (try scanner.next()).string);
    try testing.expectEqualSlices(u8, "123", (try scanner.next()).number);
    try testing.expectEqual(Token.object_end, try scanner.next());
    try testing.expectEqual(Token.end_of_document, try scanner.next());
}

test parseFromSlice {
    var parsed_str = try parseFromSlice([]const u8, testing.allocator, "\"a\\u0020b\"", .{});
    defer parsed_str.deinit();
    try testing.expectEqualSlices(u8, "a b", parsed_str.value);

    const T = struct { a: i32 = -1, b: [2]u8 };
    var parsed_struct = try parseFromSlice(T, testing.allocator, "{\"b\":\"xy\"}", .{});
    defer parsed_struct.deinit();
    try testing.expectEqual(@as(i32, -1), parsed_struct.value.a); // default value
    try testing.expectEqualSlices(u8, "xy", parsed_struct.value.b[0..]);
}

test Value {
    var parsed = try parseFromSlice(Value, testing.allocator, "{\"anything\": \"goes\"}", .{});
    defer parsed.deinit();
    try testing.expectEqualSlices(u8, "goes", parsed.value.object.get("anything").?.string);
}

test writeStream {
    var out = ArrayList(u8).init(testing.allocator);
    defer out.deinit();
    var write_stream = writeStream(out.writer(), .{ .whitespace = .indent_2 });
    defer write_stream.deinit();
    try write_stream.beginObject();
    try write_stream.objectField("foo");
    try write_stream.write(123);
    try write_stream.endObject();
    const expected =
        \\{
        \\  "foo": 123
        \\}
    ;
    try testing.expectEqualSlices(u8, expected, out.items);
}

test stringify {
    var out = ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    const T = struct { a: i32, b: []const u8 };
    try stringify(T{ .a = 123, .b = "xy" }, .{}, out.writer());
    try testing.expectEqualSlices(u8, "{\"a\":123,\"b\":\"xy\"}", out.items);
}

pub const ObjectMap = @import("json/dynamic.zig").ObjectMap;
pub const Array = @import("json/dynamic.zig").Array;
pub const Value = @import("json/dynamic.zig").Value;

pub const ArrayHashMap = @import("json/hashmap.zig").ArrayHashMap;

pub const validate = @import("json/scanner.zig").validate;
pub const Error = @import("json/scanner.zig").Error;
pub const reader = @import("json/scanner.zig").reader;
pub const default_buffer_size = @import("json/scanner.zig").default_buffer_size;
pub const Token = @import("json/scanner.zig").Token;
pub const TokenType = @import("json/scanner.zig").TokenType;
pub const Diagnostics = @import("json/scanner.zig").Diagnostics;
pub const AllocWhen = @import("json/scanner.zig").AllocWhen;
pub const default_max_value_len = @import("json/scanner.zig").default_max_value_len;
pub const Reader = @import("json/scanner.zig").Reader;
pub const Scanner = @import("json/scanner.zig").Scanner;
pub const isNumberFormattedLikeAnInteger = @import("json/scanner.zig").isNumberFormattedLikeAnInteger;

pub const ParseOptions = @import("json/static.zig").ParseOptions;
pub const Parsed = @import("json/static.zig").Parsed;
pub const parseFromSlice = @import("json/static.zig").parseFromSlice;
pub const parseFromSliceLeaky = @import("json/static.zig").parseFromSliceLeaky;
pub const parseFromTokenSource = @import("json/static.zig").parseFromTokenSource;
pub const parseFromTokenSourceLeaky = @import("json/static.zig").parseFromTokenSourceLeaky;
pub const innerParse = @import("json/static.zig").innerParse;
pub const parseFromValue = @import("json/static.zig").parseFromValue;
pub const parseFromValueLeaky = @import("json/static.zig").parseFromValueLeaky;
pub const innerParseFromValue = @import("json/static.zig").innerParseFromValue;
pub const ParseError = @import("json/static.zig").ParseError;
pub const ParseFromValueError = @import("json/static.zig").ParseFromValueError;

pub const StringifyOptions = @import("json/stringify.zig").StringifyOptions;
pub const stringify = @import("json/stringify.zig").stringify;
pub const stringifyMaxDepth = @import("json/stringify.zig").stringifyMaxDepth;
pub const stringifyArbitraryDepth = @import("json/stringify.zig").stringifyArbitraryDepth;
pub const stringifyAlloc = @import("json/stringify.zig").stringifyAlloc;
pub const writeStream = @import("json/stringify.zig").writeStream;
pub const writeStreamMaxDepth = @import("json/stringify.zig").writeStreamMaxDepth;
pub const writeStreamArbitraryDepth = @import("json/stringify.zig").writeStreamArbitraryDepth;
pub const WriteStream = @import("json/stringify.zig").WriteStream;
pub const encodeJsonString = @import("json/stringify.zig").encodeJsonString;
pub const encodeJsonStringChars = @import("json/stringify.zig").encodeJsonStringChars;

// Deprecations
pub const parse = @compileError("Deprecated; use parseFromSlice() or parseFromTokenSource() instead.");
pub const parseFree = @compileError("Deprecated; call Parsed(T).deinit() instead.");
pub const Parser = @compileError("Deprecated; use parseFromSlice(Value) or parseFromTokenSource(Value) instead.");
pub const ValueTree = @compileError("Deprecated; use Parsed(Value) instead.");
pub const StreamingParser = @compileError("Deprecated; use json.Scanner or json.Reader instead.");
pub const TokenStream = @compileError("Deprecated; use json.Scanner or json.Reader instead.");

test {
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/dynamic.zig");
    _ = @import("json/hashmap.zig");
    _ = @import("json/static.zig");
    _ = @import("json/stringify.zig");
    _ = @import("json/JSONTestSuite_test.zig");
}
