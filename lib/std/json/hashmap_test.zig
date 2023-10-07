const std = @import("std");
const testing = std.testing;

const ArrayHashMap = @import("hashmap.zig").ArrayHashMap;

const parseFromSlice = @import("static.zig").parseFromSlice;
const parseFromSliceLeaky = @import("static.zig").parseFromSliceLeaky;
const parseFromTokenSource = @import("static.zig").parseFromTokenSource;
const parseFromValue = @import("static.zig").parseFromValue;
const stringifyAlloc = @import("stringify.zig").stringifyAlloc;
const Value = @import("dynamic.zig").Value;

const jsonReader = @import("./scanner.zig").reader;

const T = struct {
    i: i32,
    s: []const u8,
};

test "parse json hashmap" {
    const doc =
        \\{
        \\  "abc": {"i": 0, "s": "d"},
        \\  "xyz": {"i": 1, "s": "w"}
        \\}
    ;
    const parsed = try parseFromSlice(ArrayHashMap(T), testing.allocator, doc, .{});
    defer parsed.deinit();

    try testing.expectEqual(@as(usize, 2), parsed.value.map.count());
    try testing.expectEqualStrings("d", parsed.value.map.get("abc").?.s);
    try testing.expectEqual(@as(i32, 1), parsed.value.map.get("xyz").?.i);
}

test "parse json hashmap while streaming" {
    const doc =
        \\{
        \\  "abc": {"i": 0, "s": "d"},
        \\  "xyz": {"i": 1, "s": "w"}
        \\}
    ;
    var stream = std.io.fixedBufferStream(doc);
    var json_reader = jsonReader(testing.allocator, stream.reader());

    var parsed = try parseFromTokenSource(
        ArrayHashMap(T),
        testing.allocator,
        &json_reader,
        .{},
    );
    defer parsed.deinit();
    // Deinit our reader to invalidate its buffer
    json_reader.deinit();

    try testing.expectEqual(@as(usize, 2), parsed.value.map.count());
    try testing.expectEqualStrings("d", parsed.value.map.get("abc").?.s);
    try testing.expectEqual(@as(i32, 1), parsed.value.map.get("xyz").?.i);
}

test "parse json hashmap duplicate fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const doc =
        \\{
        \\  "abc": {"i": 0, "s": "d"},
        \\  "abc": {"i": 1, "s": "w"}
        \\}
    ;

    try testing.expectError(error.DuplicateField, parseFromSliceLeaky(ArrayHashMap(T), arena.allocator(), doc, .{
        .duplicate_field_behavior = .@"error",
    }));

    const first = try parseFromSliceLeaky(ArrayHashMap(T), arena.allocator(), doc, .{
        .duplicate_field_behavior = .use_first,
    });
    try testing.expectEqual(@as(usize, 1), first.map.count());
    try testing.expectEqual(@as(i32, 0), first.map.get("abc").?.i);

    const last = try parseFromSliceLeaky(ArrayHashMap(T), arena.allocator(), doc, .{
        .duplicate_field_behavior = .use_last,
    });
    try testing.expectEqual(@as(usize, 1), last.map.count());
    try testing.expectEqual(@as(i32, 1), last.map.get("abc").?.i);
}

test "stringify json hashmap" {
    var value = ArrayHashMap(T){};
    defer value.deinit(testing.allocator);
    {
        const doc = try stringifyAlloc(testing.allocator, value, .{});
        defer testing.allocator.free(doc);
        try testing.expectEqualStrings("{}", doc);
    }

    try value.map.put(testing.allocator, "abc", .{ .i = 0, .s = "d" });
    try value.map.put(testing.allocator, "xyz", .{ .i = 1, .s = "w" });

    {
        const doc = try stringifyAlloc(testing.allocator, value, .{});
        defer testing.allocator.free(doc);
        try testing.expectEqualStrings(
            \\{"abc":{"i":0,"s":"d"},"xyz":{"i":1,"s":"w"}}
        , doc);
    }

    try testing.expect(value.map.swapRemove("abc"));
    {
        const doc = try stringifyAlloc(testing.allocator, value, .{});
        defer testing.allocator.free(doc);
        try testing.expectEqualStrings(
            \\{"xyz":{"i":1,"s":"w"}}
        , doc);
    }

    try testing.expect(value.map.swapRemove("xyz"));
    {
        const doc = try stringifyAlloc(testing.allocator, value, .{});
        defer testing.allocator.free(doc);
        try testing.expectEqualStrings("{}", doc);
    }
}

test "stringify json hashmap whitespace" {
    var value = ArrayHashMap(T){};
    defer value.deinit(testing.allocator);
    try value.map.put(testing.allocator, "abc", .{ .i = 0, .s = "d" });
    try value.map.put(testing.allocator, "xyz", .{ .i = 1, .s = "w" });

    {
        const doc = try stringifyAlloc(testing.allocator, value, .{ .whitespace = .indent_2 });
        defer testing.allocator.free(doc);
        try testing.expectEqualStrings(
            \\{
            \\  "abc": {
            \\    "i": 0,
            \\    "s": "d"
            \\  },
            \\  "xyz": {
            \\    "i": 1,
            \\    "s": "w"
            \\  }
            \\}
        , doc);
    }
}

test "json parse from value hashmap" {
    const doc =
        \\{
        \\  "abc": {"i": 0, "s": "d"},
        \\  "xyz": {"i": 1, "s": "w"}
        \\}
    ;
    const parsed1 = try parseFromSlice(Value, testing.allocator, doc, .{});
    defer parsed1.deinit();

    const parsed2 = try parseFromValue(ArrayHashMap(T), testing.allocator, parsed1.value, .{});
    defer parsed2.deinit();

    try testing.expectEqualStrings("d", parsed2.value.map.get("abc").?.s);
}
