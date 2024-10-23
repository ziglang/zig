const std = @import("std");
const JsonScanner = @import("./scanner.zig").Scanner;
const jsonReader = @import("./scanner.zig").reader;
const JsonReader = @import("./scanner.zig").Reader;
const Token = @import("./scanner.zig").Token;
const TokenType = @import("./scanner.zig").TokenType;
const Diagnostics = @import("./scanner.zig").Diagnostics;
const Error = @import("./scanner.zig").Error;
const validate = @import("./scanner.zig").validate;
const isNumberFormattedLikeAnInteger = @import("./scanner.zig").isNumberFormattedLikeAnInteger;

const example_document_str =
    \\{
    \\  "Image": {
    \\      "Width":  800,
    \\      "Height": 600,
    \\      "Title":  "View from 15th Floor",
    \\      "Thumbnail": {
    \\          "Url":    "http://www.example.com/image/481989943",
    \\          "Height": 125,
    \\          "Width":  100
    \\      },
    \\      "Animated" : false,
    \\      "IDs": [116, 943, 234, 38793]
    \\    }
    \\}
;

fn expectNext(scanner_or_reader: anytype, expected_token: Token) !void {
    return expectEqualTokens(expected_token, try scanner_or_reader.next());
}

fn expectPeekNext(scanner_or_reader: anytype, expected_token_type: TokenType, expected_token: Token) !void {
    try std.testing.expectEqual(expected_token_type, try scanner_or_reader.peekNextTokenType());
    try expectEqualTokens(expected_token, try scanner_or_reader.next());
}

test "token" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, example_document_str);
    defer scanner.deinit();

    try expectNext(&scanner, .object_begin);
    try expectNext(&scanner, Token{ .string = "Image" });
    try expectNext(&scanner, .object_begin);
    try expectNext(&scanner, Token{ .string = "Width" });
    try expectNext(&scanner, Token{ .number = "800" });
    try expectNext(&scanner, Token{ .string = "Height" });
    try expectNext(&scanner, Token{ .number = "600" });
    try expectNext(&scanner, Token{ .string = "Title" });
    try expectNext(&scanner, Token{ .string = "View from 15th Floor" });
    try expectNext(&scanner, Token{ .string = "Thumbnail" });
    try expectNext(&scanner, .object_begin);
    try expectNext(&scanner, Token{ .string = "Url" });
    try expectNext(&scanner, Token{ .string = "http://www.example.com/image/481989943" });
    try expectNext(&scanner, Token{ .string = "Height" });
    try expectNext(&scanner, Token{ .number = "125" });
    try expectNext(&scanner, Token{ .string = "Width" });
    try expectNext(&scanner, Token{ .number = "100" });
    try expectNext(&scanner, .object_end);
    try expectNext(&scanner, Token{ .string = "Animated" });
    try expectNext(&scanner, .false);
    try expectNext(&scanner, Token{ .string = "IDs" });
    try expectNext(&scanner, .array_begin);
    try expectNext(&scanner, Token{ .number = "116" });
    try expectNext(&scanner, Token{ .number = "943" });
    try expectNext(&scanner, Token{ .number = "234" });
    try expectNext(&scanner, Token{ .number = "38793" });
    try expectNext(&scanner, .array_end);
    try expectNext(&scanner, .object_end);
    try expectNext(&scanner, .object_end);
    try expectNext(&scanner, .end_of_document);
}

const all_types_test_case =
    \\[
    \\  "", "a\nb",
    \\  0, 0.0, -1.1e-1,
    \\  true, false, null,
    \\  {"a": {}},
    \\  []
    \\]
;

fn testAllTypes(source: anytype, large_buffer: bool) !void {
    try expectPeekNext(source, .array_begin, .array_begin);
    try expectPeekNext(source, .string, Token{ .string = "" });
    try expectPeekNext(source, .string, Token{ .partial_string = "a" });
    try expectPeekNext(source, .string, Token{ .partial_string_escaped_1 = "\n".* });
    if (large_buffer) {
        try expectPeekNext(source, .string, Token{ .string = "b" });
    } else {
        try expectPeekNext(source, .string, Token{ .partial_string = "b" });
        try expectPeekNext(source, .string, Token{ .string = "" });
    }
    if (large_buffer) {
        try expectPeekNext(source, .number, Token{ .number = "0" });
    } else {
        try expectPeekNext(source, .number, Token{ .partial_number = "0" });
        try expectPeekNext(source, .number, Token{ .number = "" });
    }
    if (large_buffer) {
        try expectPeekNext(source, .number, Token{ .number = "0.0" });
    } else {
        try expectPeekNext(source, .number, Token{ .partial_number = "0" });
        try expectPeekNext(source, .number, Token{ .partial_number = "." });
        try expectPeekNext(source, .number, Token{ .partial_number = "0" });
        try expectPeekNext(source, .number, Token{ .number = "" });
    }
    if (large_buffer) {
        try expectPeekNext(source, .number, Token{ .number = "-1.1e-1" });
    } else {
        try expectPeekNext(source, .number, Token{ .partial_number = "-" });
        try expectPeekNext(source, .number, Token{ .partial_number = "1" });
        try expectPeekNext(source, .number, Token{ .partial_number = "." });
        try expectPeekNext(source, .number, Token{ .partial_number = "1" });
        try expectPeekNext(source, .number, Token{ .partial_number = "e" });
        try expectPeekNext(source, .number, Token{ .partial_number = "-" });
        try expectPeekNext(source, .number, Token{ .partial_number = "1" });
        try expectPeekNext(source, .number, Token{ .number = "" });
    }
    try expectPeekNext(source, .true, .true);
    try expectPeekNext(source, .false, .false);
    try expectPeekNext(source, .null, .null);
    try expectPeekNext(source, .object_begin, .object_begin);
    if (large_buffer) {
        try expectPeekNext(source, .string, Token{ .string = "a" });
    } else {
        try expectPeekNext(source, .string, Token{ .partial_string = "a" });
        try expectPeekNext(source, .string, Token{ .string = "" });
    }
    try expectPeekNext(source, .object_begin, .object_begin);
    try expectPeekNext(source, .object_end, .object_end);
    try expectPeekNext(source, .object_end, .object_end);
    try expectPeekNext(source, .array_begin, .array_begin);
    try expectPeekNext(source, .array_end, .array_end);
    try expectPeekNext(source, .array_end, .array_end);
    try expectPeekNext(source, .end_of_document, .end_of_document);
}

test "peek all types" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, all_types_test_case);
    defer scanner.deinit();
    try testAllTypes(&scanner, true);

    var stream = std.io.fixedBufferStream(all_types_test_case);
    var json_reader = jsonReader(std.testing.allocator, stream.reader());
    defer json_reader.deinit();
    try testAllTypes(&json_reader, true);

    var tiny_stream = std.io.fixedBufferStream(all_types_test_case);
    var tiny_json_reader = JsonReader(1, @TypeOf(tiny_stream.reader())).init(std.testing.allocator, tiny_stream.reader());
    defer tiny_json_reader.deinit();
    try testAllTypes(&tiny_json_reader, false);
}

test "token mismatched close" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, "[102, 111, 111 }");
    defer scanner.deinit();
    try expectNext(&scanner, .array_begin);
    try expectNext(&scanner, Token{ .number = "102" });
    try expectNext(&scanner, Token{ .number = "111" });
    try expectNext(&scanner, Token{ .number = "111" });
    try std.testing.expectError(error.SyntaxError, scanner.next());
}

test "token premature object close" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, "{ \"key\": }");
    defer scanner.deinit();
    try expectNext(&scanner, .object_begin);
    try expectNext(&scanner, Token{ .string = "key" });
    try std.testing.expectError(error.SyntaxError, scanner.next());
}

test "JsonScanner basic" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, example_document_str);
    defer scanner.deinit();

    while (true) {
        const token = try scanner.next();
        if (token == .end_of_document) break;
    }
}

test "JsonReader basic" {
    var stream = std.io.fixedBufferStream(example_document_str);

    var json_reader = jsonReader(std.testing.allocator, stream.reader());
    defer json_reader.deinit();

    while (true) {
        const token = try json_reader.next();
        if (token == .end_of_document) break;
    }
}

const number_test_stems = .{
    .{ "", "-" },
    .{ "0", "1", "10", "9999999999999999999999999" },
    .{ "", ".0", ".999999999999999999999999" },
    .{ "", "e0", "E0", "e+0", "e-0", "e9999999999999999999999999999" },
};
const number_test_items = blk: {
    var ret: []const []const u8 = &[_][]const u8{};
    for (number_test_stems[0]) |s0| {
        for (number_test_stems[1]) |s1| {
            for (number_test_stems[2]) |s2| {
                for (number_test_stems[3]) |s3| {
                    ret = ret ++ &[_][]const u8{s0 ++ s1 ++ s2 ++ s3};
                }
            }
        }
    }
    break :blk ret;
};

test "numbers" {
    for (number_test_items) |number_str| {
        var scanner = JsonScanner.initCompleteInput(std.testing.allocator, number_str);
        defer scanner.deinit();

        const token = try scanner.next();
        const value = token.number; // assert this is a number
        try std.testing.expectEqualStrings(number_str, value);

        try std.testing.expectEqual(Token.end_of_document, try scanner.next());
    }
}

const string_test_cases = .{
    // The left is JSON without the "quotes".
    // The right is the expected unescaped content.
    .{ "", "" },
    .{ "\\\\", "\\" },
    .{ "a\\\\b", "a\\b" },
    .{ "a\\\"b", "a\"b" },
    .{ "\\n", "\n" },
    .{ "\\u000a", "\n" },
    .{ "𝄞", "\u{1D11E}" },
    .{ "\\uD834\\uDD1E", "\u{1D11E}" },
    .{ "\\uD87F\\uDFFE", "\u{2FFFE}" },
    .{ "\\uff20", "＠" },
};

test "strings" {
    inline for (string_test_cases) |tuple| {
        var stream = std.io.fixedBufferStream("\"" ++ tuple[0] ++ "\"");
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var json_reader = jsonReader(std.testing.allocator, stream.reader());
        defer json_reader.deinit();

        const token = try json_reader.nextAlloc(arena.allocator(), .alloc_if_needed);
        const value = switch (token) {
            .string => |value| value,
            .allocated_string => |value| value,
            else => return error.ExpectedString,
        };
        try std.testing.expectEqualStrings(tuple[1], value);

        try std.testing.expectEqual(Token.end_of_document, try json_reader.next());
    }
}

const nesting_test_cases = .{
    .{ null, "[]" },
    .{ null, "{}" },
    .{ error.SyntaxError, "[}" },
    .{ error.SyntaxError, "{]" },
    .{ null, "[" ** 1000 ++ "]" ** 1000 },
    .{ null, "{\"\":" ** 1000 ++ "0" ++ "}" ** 1000 },
    .{ error.SyntaxError, "[" ** 1000 ++ "]" ** 999 ++ "}" },
    .{ error.SyntaxError, "{\"\":" ** 1000 ++ "0" ++ "}" ** 999 ++ "]" },
    .{ error.SyntaxError, "[" ** 1000 ++ "]" ** 1001 },
    .{ error.SyntaxError, "{\"\":" ** 1000 ++ "0" ++ "}" ** 1001 },
    .{ error.UnexpectedEndOfInput, "[" ** 1000 ++ "]" ** 999 },
    .{ error.UnexpectedEndOfInput, "{\"\":" ** 1000 ++ "0" ++ "}" ** 999 },
};

test "nesting" {
    inline for (nesting_test_cases) |tuple| {
        const maybe_error = tuple[0];
        const document_str = tuple[1];

        expectMaybeError(document_str, maybe_error) catch |err| {
            std.debug.print("in json document: {s}\n", .{document_str});
            return err;
        };
    }
}

fn expectMaybeError(document_str: []const u8, maybe_error: ?Error) !void {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, document_str);
    defer scanner.deinit();

    while (true) {
        const token = scanner.next() catch |err| {
            if (maybe_error) |expected_err| {
                if (err == expected_err) return;
            }
            return err;
        };
        if (token == .end_of_document) break;
    }
    if (maybe_error != null) return error.ExpectedError;
}

fn expectEqualTokens(expected_token: Token, actual_token: Token) !void {
    try std.testing.expectEqual(std.meta.activeTag(expected_token), std.meta.activeTag(actual_token));
    switch (expected_token) {
        .number => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.number);
        },
        .allocated_number => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.allocated_number);
        },
        .partial_number => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.partial_number);
        },

        .string => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.string);
        },
        .allocated_string => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.allocated_string);
        },
        .partial_string => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.partial_string);
        },
        .partial_string_escaped_1 => |expected_value| {
            try std.testing.expectEqualStrings(&expected_value, &actual_token.partial_string_escaped_1);
        },
        .partial_string_escaped_2 => |expected_value| {
            try std.testing.expectEqualStrings(&expected_value, &actual_token.partial_string_escaped_2);
        },
        .partial_string_escaped_3 => |expected_value| {
            try std.testing.expectEqualStrings(&expected_value, &actual_token.partial_string_escaped_3);
        },
        .partial_string_escaped_4 => |expected_value| {
            try std.testing.expectEqualStrings(&expected_value, &actual_token.partial_string_escaped_4);
        },

        .object_begin,
        .object_end,
        .array_begin,
        .array_end,
        .true,
        .false,
        .null,
        .end_of_document,
        => {},
    }
}

fn testTinyBufferSize(document_str: []const u8) !void {
    var tiny_stream = std.io.fixedBufferStream(document_str);
    var normal_stream = std.io.fixedBufferStream(document_str);

    var tiny_json_reader = JsonReader(1, @TypeOf(tiny_stream.reader())).init(std.testing.allocator, tiny_stream.reader());
    defer tiny_json_reader.deinit();
    var normal_json_reader = JsonReader(0x1000, @TypeOf(normal_stream.reader())).init(std.testing.allocator, normal_stream.reader());
    defer normal_json_reader.deinit();

    expectEqualStreamOfTokens(&normal_json_reader, &tiny_json_reader) catch |err| {
        std.debug.print("in json document: {s}\n", .{document_str});
        return err;
    };
}
fn expectEqualStreamOfTokens(control_json_reader: anytype, test_json_reader: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    while (true) {
        const control_token = try control_json_reader.nextAlloc(arena.allocator(), .alloc_always);
        const test_token = try test_json_reader.nextAlloc(arena.allocator(), .alloc_always);
        try expectEqualTokens(control_token, test_token);
        if (control_token == .end_of_document) break;
        _ = arena.reset(.retain_capacity);
    }
}

test "BufferUnderrun" {
    try testTinyBufferSize(example_document_str);
    for (number_test_items) |number_str| {
        try testTinyBufferSize(number_str);
    }
    inline for (string_test_cases) |tuple| {
        try testTinyBufferSize("\"" ++ tuple[0] ++ "\"");
    }
}

test "validate" {
    try std.testing.expectEqual(true, try validate(std.testing.allocator, "{}"));
    try std.testing.expectEqual(true, try validate(std.testing.allocator, "[]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "[{[[[[{}]]]]}]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "{]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "[}"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "{{{{[]}}}]"));
}

fn testSkipValue(s: []const u8) !void {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, s);
    defer scanner.deinit();
    try scanner.skipValue();
    try expectEqualTokens(.end_of_document, try scanner.next());

    var stream = std.io.fixedBufferStream(s);
    var json_reader = jsonReader(std.testing.allocator, stream.reader());
    defer json_reader.deinit();
    try json_reader.skipValue();
    try expectEqualTokens(.end_of_document, try json_reader.next());
}

test "skipValue" {
    try testSkipValue("false");
    try testSkipValue("true");
    try testSkipValue("null");
    try testSkipValue("42");
    try testSkipValue("42.0");
    try testSkipValue("\"foo\"");
    try testSkipValue("[101, 111, 121]");
    try testSkipValue("{}");
    try testSkipValue("{\"foo\": \"bar\\nbaz\"}");

    // An absurd number of nestings
    const nestings = 1000;
    try testSkipValue("[" ** nestings ++ "]" ** nestings);

    // Would a number token cause problems in a deeply-nested array?
    try testSkipValue("[" ** nestings ++ "0.118, 999, 881.99, 911.9, 725, 3" ++ "]" ** nestings);

    // Mismatched brace/square bracket
    try std.testing.expectError(error.SyntaxError, testSkipValue("[102, 111, 111}"));
}

fn testEnsureStackCapacity(do_ensure: bool) !void {
    var fail_alloc = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const failing_allocator = fail_alloc.allocator();

    const nestings = 999; // intentionally not a power of 2.
    var scanner = JsonScanner.initCompleteInput(failing_allocator, "[" ** nestings ++ "]" ** nestings);
    defer scanner.deinit();

    if (do_ensure) {
        try scanner.ensureTotalStackCapacity(nestings);
    }

    try scanner.skipValue();
    try std.testing.expectEqual(Token.end_of_document, try scanner.next());
}
test "ensureTotalStackCapacity" {
    // Once to demonstrate failure.
    try std.testing.expectError(error.OutOfMemory, testEnsureStackCapacity(false));
    // Then to demonstrate it works.
    try testEnsureStackCapacity(true);
}

fn testDiagnosticsFromSource(expected_error: ?anyerror, line: u64, col: u64, byte_offset: u64, source: anytype) !void {
    var diagnostics = Diagnostics{};
    source.enableDiagnostics(&diagnostics);

    if (expected_error) |expected_err| {
        try std.testing.expectError(expected_err, source.skipValue());
    } else {
        try source.skipValue();
        try std.testing.expectEqual(Token.end_of_document, try source.next());
    }
    try std.testing.expectEqual(line, diagnostics.getLine());
    try std.testing.expectEqual(col, diagnostics.getColumn());
    try std.testing.expectEqual(byte_offset, diagnostics.getByteOffset());
}
fn testDiagnostics(expected_error: ?anyerror, line: u64, col: u64, byte_offset: u64, s: []const u8) !void {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, s);
    defer scanner.deinit();
    try testDiagnosticsFromSource(expected_error, line, col, byte_offset, &scanner);

    var tiny_stream = std.io.fixedBufferStream(s);
    var tiny_json_reader = JsonReader(1, @TypeOf(tiny_stream.reader())).init(std.testing.allocator, tiny_stream.reader());
    defer tiny_json_reader.deinit();
    try testDiagnosticsFromSource(expected_error, line, col, byte_offset, &tiny_json_reader);

    var medium_stream = std.io.fixedBufferStream(s);
    var medium_json_reader = JsonReader(5, @TypeOf(medium_stream.reader())).init(std.testing.allocator, medium_stream.reader());
    defer medium_json_reader.deinit();
    try testDiagnosticsFromSource(expected_error, line, col, byte_offset, &medium_json_reader);
}
test "enableDiagnostics" {
    try testDiagnostics(error.UnexpectedEndOfInput, 1, 1, 0, "");
    try testDiagnostics(null, 1, 3, 2, "[]");
    try testDiagnostics(null, 2, 2, 3, "[\n]");
    try testDiagnostics(null, 14, 2, example_document_str.len, example_document_str);

    try testDiagnostics(error.SyntaxError, 3, 1, 25,
        \\{
        \\  "common": "mistake",
        \\}
    );

    inline for ([_]comptime_int{ 5, 6, 7, 99 }) |reps| {
        // The error happens 1 byte before the end.
        const s = "[" ** reps ++ "}";
        try testDiagnostics(error.SyntaxError, 1, s.len, s.len - 1, s);
    }
}

test isNumberFormattedLikeAnInteger {
    try std.testing.expect(isNumberFormattedLikeAnInteger("0"));
    try std.testing.expect(isNumberFormattedLikeAnInteger("1"));
    try std.testing.expect(isNumberFormattedLikeAnInteger("123"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("-0"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("0.0"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("1.0"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("1.23"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("1e10"));
    try std.testing.expect(!isNumberFormattedLikeAnInteger("1E10"));
}
