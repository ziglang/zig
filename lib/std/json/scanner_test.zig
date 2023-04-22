const std = @import("std");
const JsonScanner = @import("./scanner.zig").JsonScanner;
const allocatingJsonReader = @import("./scanner.zig").allocatingJsonReader;
const AllocatingJsonReader = @import("./scanner.zig").AllocatingJsonReader;

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
        var buf: [0x1000]u8 = undefined;
        const token_value = buf[0..token_len];
        scanner.readValue(token_value);
        try std.testing.expectEqualStrings(token_value, number_str);

        try std.testing.expectEqual(JsonScanner.Token.end_of_document, try scanner.next());
    }
}
