const std = @import("std");
const JsonScanner = @import("./scanner.zig").JsonScanner;
const allocatingJsonReader = @import("./scanner.zig").allocatingJsonReader;
const AllocatingJsonReader = @import("./scanner.zig").AllocatingJsonReader;
const AllocatedToken = @import("./scanner.zig").AllocatedToken;
const JsonError = @import("./scanner.zig").JsonError;

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

test "JsonScanner basic" {
    var scanner = JsonScanner.init(std.testing.allocator);
    defer scanner.deinit();

    scanner.feedInput(example_document_str);
    scanner.endInput();

    while (true) {
        const token = try scanner.next();
        if (token == .end_of_document) break;
    }
}

test "AllocatingJsonReader basic" {
    var stream = std.io.fixedBufferStream(example_document_str);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var json_reader = allocatingJsonReader(std.testing.allocator, arena.allocator(), stream.reader());
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
        var scanner = JsonScanner.init(std.testing.allocator);
        defer scanner.deinit();

        scanner.feedInput(number_str);
        scanner.endInput();
        const token = try scanner.next();
        const token_len = token.number; // assert this is a number
        try std.testing.expectEqualStrings(number_str, scanner.peekValue(token_len));

        try std.testing.expectEqual(JsonScanner.Token.end_of_document, try scanner.next());
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
        var json_reader = allocatingJsonReader(std.testing.allocator, arena.allocator(), stream.reader());
        defer json_reader.deinit();

        const token = try json_reader.next();
        const value = token.string; // assert this is a string
        try std.testing.expectEqualStrings(tuple[1], value);

        try std.testing.expectEqual(AllocatedToken.end_of_document, try json_reader.next());
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
    .{ error.UnexpectedEndOfDocument, "[" ** 1000 ++ "]" ** 999 },
    .{ error.UnexpectedEndOfDocument, "{\"\":" ** 1000 ++ "0" ++ "}" ** 999 },
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
    var scanner = JsonScanner.init(std.testing.allocator);
    defer scanner.deinit();

    scanner.feedInput(document_str);
    scanner.endInput();

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

fn expectEqualTokens(expected_token: AllocatedToken, actual_token: AllocatedToken) !void {
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

    var tiny_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer tiny_arena.deinit();
    var normal_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer normal_arena.deinit();

    var tiny_json_reader = AllocatingJsonReader(1, @TypeOf(tiny_stream.reader())){
        .scanner = JsonScanner.init(std.testing.allocator),
        .reader = tiny_stream.reader(),
        .value_allocator = tiny_arena.allocator(),
    };
    defer tiny_json_reader.deinit();
    var normal_json_reader = AllocatingJsonReader(0x1000, @TypeOf(normal_stream.reader())){
        .scanner = JsonScanner.init(std.testing.allocator),
        .reader = normal_stream.reader(),
        .value_allocator = normal_arena.allocator(),
    };
    defer normal_json_reader.deinit();

    expectEqualStreamOfTokens(&normal_json_reader, &tiny_json_reader) catch |err| {
        std.debug.print("in json document: {s}\n", .{document_str});
        return err;
    };
}
fn expectEqualStreamOfTokens(control_json_reader: anytype, test_json_reader: anytype) !void {
    while (true) {
        const control_token = try control_json_reader.next();
        const test_token = try test_json_reader.next();
        try expectEqualTokens(control_token, test_token);
        if (control_token == .end_of_document) break;
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
