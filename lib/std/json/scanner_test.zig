const std = @import("std");
const JsonScanner = @import("./scanner.zig").JsonScanner;
const allocatingJsonReader = @import("./scanner.zig").allocatingJsonReader;
const AllocatingJsonReader = @import("./scanner.zig").AllocatingJsonReader;
const AllocatedToken = @import("./scanner.zig").AllocatedToken;

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
}
