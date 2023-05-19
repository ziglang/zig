const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ObjectMap = @import("dynamic.zig").ObjectMap;
const Array = @import("dynamic.zig").Array;
const Value = @import("dynamic.zig").Value;
const Parser = @import("dynamic.zig").Parser;

test "json.parser.dynamic" {
    var p = Parser.init(testing.allocator, .alloc_if_needed);
    defer p.deinit();

    const s =
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
        \\      "IDs": [116, 943, 234, 38793],
        \\      "ArrayOfObject": [{"n": "m"}],
        \\      "double": 1.3412,
        \\      "LargeInt": 18446744073709551615
        \\    }
        \\}
    ;

    var tree = try p.parse(s);
    defer tree.deinit();

    var root = tree.root;

    var image = root.object.get("Image").?;

    const width = image.object.get("Width").?;
    try testing.expect(width.integer == 800);

    const height = image.object.get("Height").?;
    try testing.expect(height.integer == 600);

    const title = image.object.get("Title").?;
    try testing.expect(mem.eql(u8, title.string, "View from 15th Floor"));

    const animated = image.object.get("Animated").?;
    try testing.expect(animated.bool == false);

    const array_of_object = image.object.get("ArrayOfObject").?;
    try testing.expect(array_of_object.array.items.len == 1);

    const obj0 = array_of_object.array.items[0].object.get("n").?;
    try testing.expect(mem.eql(u8, obj0.string, "m"));

    const double = image.object.get("double").?;
    try testing.expect(double.float == 1.3412);

    const large_int = image.object.get("LargeInt").?;
    try testing.expect(mem.eql(u8, large_int.number_string, "18446744073709551615"));
}

const writeStream = @import("./write_stream.zig").writeStream;
test "write json then parse it" {
    var out_buffer: [1000]u8 = undefined;

    var fixed_buffer_stream = std.io.fixedBufferStream(&out_buffer);
    const out_stream = fixed_buffer_stream.writer();
    var jw = writeStream(out_stream, 4);

    try jw.beginObject();

    try jw.objectField("f");
    try jw.emitBool(false);

    try jw.objectField("t");
    try jw.emitBool(true);

    try jw.objectField("int");
    try jw.emitNumber(1234);

    try jw.objectField("array");
    try jw.beginArray();

    try jw.arrayElem();
    try jw.emitNull();

    try jw.arrayElem();
    try jw.emitNumber(12.34);

    try jw.endArray();

    try jw.objectField("str");
    try jw.emitString("hello");

    try jw.endObject();

    var parser = Parser.init(testing.allocator, .alloc_if_needed);
    defer parser.deinit();
    var tree = try parser.parse(fixed_buffer_stream.getWritten());
    defer tree.deinit();

    try testing.expect(tree.root.object.get("f").?.bool == false);
    try testing.expect(tree.root.object.get("t").?.bool == true);
    try testing.expect(tree.root.object.get("int").?.integer == 1234);
    try testing.expect(tree.root.object.get("array").?.array.items[0].null == {});
    try testing.expect(tree.root.object.get("array").?.array.items[1].float == 12.34);
    try testing.expect(mem.eql(u8, tree.root.object.get("str").?.string, "hello"));
}

fn testParse(arena_allocator: std.mem.Allocator, json_str: []const u8) !Value {
    var p = Parser.init(arena_allocator, .alloc_if_needed);
    return (try p.parse(json_str)).root;
}

test "parsing empty string gives appropriate error" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    try testing.expectError(error.UnexpectedEndOfInput, testParse(arena_allocator.allocator(), ""));
}

test "parse tree should not contain dangling pointers" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    var p = Parser.init(arena_allocator.allocator(), .alloc_if_needed);
    defer p.deinit();

    var tree = try p.parse("[]");
    defer tree.deinit();

    // Allocation should succeed
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try tree.root.array.append(Value{ .integer = 100 });
    }
    try testing.expectEqual(tree.root.array.items.len, 100);
}

test "integer after float has proper type" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const parsed = try testParse(arena_allocator.allocator(),
        \\{
        \\  "float": 3.14,
        \\  "ints": [1, 2, 3]
        \\}
    );
    try std.testing.expect(parsed.object.get("ints").?.array.items[0] == .integer);
}

test "escaped characters" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const input =
        \\{
        \\  "backslash": "\\",
        \\  "forwardslash": "\/",
        \\  "newline": "\n",
        \\  "carriagereturn": "\r",
        \\  "tab": "\t",
        \\  "formfeed": "\f",
        \\  "backspace": "\b",
        \\  "doublequote": "\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    const obj = (try testParse(arena_allocator.allocator(), input)).object;

    try testing.expectEqualSlices(u8, obj.get("backslash").?.string, "\\");
    try testing.expectEqualSlices(u8, obj.get("forwardslash").?.string, "/");
    try testing.expectEqualSlices(u8, obj.get("newline").?.string, "\n");
    try testing.expectEqualSlices(u8, obj.get("carriagereturn").?.string, "\r");
    try testing.expectEqualSlices(u8, obj.get("tab").?.string, "\t");
    try testing.expectEqualSlices(u8, obj.get("formfeed").?.string, "\x0C");
    try testing.expectEqualSlices(u8, obj.get("backspace").?.string, "\x08");
    try testing.expectEqualSlices(u8, obj.get("doublequote").?.string, "\"");
    try testing.expectEqualSlices(u8, obj.get("unicode").?.string, "ą");
    try testing.expectEqualSlices(u8, obj.get("surrogatepair").?.string, "😂");
}

test "string copy option" {
    const input =
        \\{
        \\  "noescape": "aą😂",
        \\  "simple": "\\\/\n\r\t\f\b\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var parser = Parser.init(allocator, .alloc_if_needed);
    const tree_nocopy = try parser.parse(input);
    const obj_nocopy = tree_nocopy.root.object;

    parser = Parser.init(allocator, .alloc_always);
    const tree_copy = try parser.parse(input);
    const obj_copy = tree_copy.root.object;

    for ([_][]const u8{ "noescape", "simple", "unicode", "surrogatepair" }) |field_name| {
        try testing.expectEqualSlices(u8, obj_nocopy.get(field_name).?.string, obj_copy.get(field_name).?.string);
    }

    const nocopy_addr = &obj_nocopy.get("noescape").?.string[0];
    const copy_addr = &obj_copy.get("noescape").?.string[0];

    var found_nocopy = false;
    for (input, 0..) |_, index| {
        try testing.expect(copy_addr != &input[index]);
        if (nocopy_addr == &input[index]) {
            found_nocopy = true;
        }
    }
    try testing.expect(found_nocopy);
}

test "Value.jsonStringify" {
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try @as(Value, .null).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "null");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .bool = true }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "true");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .integer = 42 }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "42");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .number_string = "43" }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "43");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .float = 42 }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "4.2e+01");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .string = "weeee" }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "\"weeee\"");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var vals = [_]Value{
            .{ .integer = 1 },
            .{ .integer = 2 },
            .{ .number_string = "3" },
        };
        try (Value{
            .array = Array.fromOwnedSlice(undefined, &vals),
        }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "[1,2,3]");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var obj = ObjectMap.init(testing.allocator);
        defer obj.deinit();
        try obj.putNoClobber("a", .{ .string = "b" });
        try (Value{ .object = obj }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "{\"a\":\"b\"}");
    }
}
