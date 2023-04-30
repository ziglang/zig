const std = @import("std");
const JsonScanner = @import("./scanner.zig").JsonScanner;
const jsonReader = @import("./scanner.zig").jsonReader;
const JsonReader = @import("./scanner.zig").JsonReader;
const Token = @import("./scanner.zig").Token;
const JsonError = @import("./scanner.zig").JsonError;
const validate = @import("./scanner.zig").validate;

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

fn expectNext(p: *JsonScanner, expected_token: Token) !void {
    return expectEqualTokens(expected_token, try p.next());
}

test "json.token" {
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

test "json.token mismatched close" {
    var scanner = JsonScanner.initCompleteInput(std.testing.allocator, "[102, 111, 111 }");
    defer scanner.deinit();
    try expectNext(&scanner, .array_begin);
    try expectNext(&scanner, Token{ .number = "102" });
    try expectNext(&scanner, Token{ .number = "111" });
    try expectNext(&scanner, Token{ .number = "111" });
    try std.testing.expectError(error.SyntaxError, scanner.next());
}

test "json.token premature object close" {
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
    comptime var ret: []const []const u8 = &[_][]const u8{};
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
    .{ "\\uff20", "＠" },
};

test "strings" {
    inline for (string_test_cases) |tuple| {
        var stream = std.io.fixedBufferStream("\"" ++ tuple[0] ++ "\"");
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var json_reader = jsonReader(std.testing.allocator, stream.reader());
        defer json_reader.deinit();

        const token = try json_reader.nextAlwaysAlloc(arena.allocator(), 0x1000);
        const value = token.allocated_string; // assert this is a string
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

fn expectMaybeError(document_str: []const u8, maybe_error: ?JsonError) !void {
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
        .string => |expected_value| {
            try std.testing.expectEqualStrings(expected_value, actual_token.string);
        },
        else => {},
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
        const control_token = try control_json_reader.nextAlwaysAlloc(arena.allocator(), 0x1000);
        const test_token = try test_json_reader.nextAlwaysAlloc(arena.allocator(), 0x1000);
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

test "json.validate" {
    try std.testing.expectEqual(true, try validate(std.testing.allocator, "{}"));
    try std.testing.expectEqual(true, try validate(std.testing.allocator, "[]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "[{[[[[{}]]]]}]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "{]"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "[}"));
    try std.testing.expectEqual(false, try validate(std.testing.allocator, "{{{{[]}}}]"));
}
