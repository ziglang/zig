const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const ObjectMap = @import("dynamic.zig").ObjectMap;
const Array = @import("dynamic.zig").Array;
const Value = @import("dynamic.zig").Value;

const parseFromSlice = @import("static.zig").parseFromSlice;
const parseFromSliceLeaky = @import("static.zig").parseFromSliceLeaky;
const parseFromTokenSource = @import("static.zig").parseFromTokenSource;
const parseFromValueLeaky = @import("static.zig").parseFromValueLeaky;
const ParseOptions = @import("static.zig").ParseOptions;

const jsonReader = @import("scanner.zig").reader;
const JsonReader = @import("scanner.zig").Reader;

test "json.parser.dynamic" {
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

    var parsed = try parseFromSlice(Value, testing.allocator, s, .{});
    defer parsed.deinit();

    var root = parsed.value;

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

const writeStream = @import("./stringify.zig").writeStream;
test "write json then parse it" {
    var out_buffer: [1000]u8 = undefined;

    var fixed_buffer_stream = std.io.fixedBufferStream(&out_buffer);
    const out_stream = fixed_buffer_stream.writer();
    var jw = writeStream(out_stream, .{});
    defer jw.deinit();

    try jw.beginObject();

    try jw.objectField("f");
    try jw.write(false);

    try jw.objectField("t");
    try jw.write(true);

    try jw.objectField("int");
    try jw.write(1234);

    try jw.objectField("array");
    try jw.beginArray();
    try jw.write(null);
    try jw.write(12.34);
    try jw.endArray();

    try jw.objectField("str");
    try jw.write("hello");

    try jw.endObject();

    fixed_buffer_stream = std.io.fixedBufferStream(fixed_buffer_stream.getWritten());
    var json_reader = jsonReader(testing.allocator, fixed_buffer_stream.reader());
    defer json_reader.deinit();
    var parsed = try parseFromTokenSource(Value, testing.allocator, &json_reader, .{});
    defer parsed.deinit();

    try testing.expect(parsed.value.object.get("f").?.bool == false);
    try testing.expect(parsed.value.object.get("t").?.bool == true);
    try testing.expect(parsed.value.object.get("int").?.integer == 1234);
    try testing.expect(parsed.value.object.get("array").?.array.items[0].null == {});
    try testing.expect(parsed.value.object.get("array").?.array.items[1].float == 12.34);
    try testing.expect(mem.eql(u8, parsed.value.object.get("str").?.string, "hello"));
}

fn testParse(allocator: std.mem.Allocator, json_str: []const u8) !Value {
    return parseFromSliceLeaky(Value, allocator, json_str, .{});
}

test "parsing empty string gives appropriate error" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    try testing.expectError(error.UnexpectedEndOfInput, testParse(arena_allocator.allocator(), ""));
}

test "Value.array allocator should still be usable after parsing" {
    var parsed = try parseFromSlice(Value, std.testing.allocator, "[]", .{});
    defer parsed.deinit();

    // Allocation should succeed
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try parsed.value.array.append(Value{ .integer = 100 });
    }
    try testing.expectEqual(parsed.value.array.items.len, 100);
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

test "Value.jsonStringify" {
    var vals = [_]Value{
        .{ .integer = 1 },
        .{ .integer = 2 },
        .{ .number_string = "3" },
    };
    var obj = ObjectMap.init(testing.allocator);
    defer obj.deinit();
    try obj.putNoClobber("a", .{ .string = "b" });
    const array = [_]Value{
        .null,
        .{ .bool = true },
        .{ .integer = 42 },
        .{ .number_string = "43" },
        .{ .float = 42 },
        .{ .string = "weeee" },
        .{ .array = Array.fromOwnedSlice(undefined, &vals) },
        .{ .object = obj },
    };
    var buffer: [0x1000]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    var jw = writeStream(fbs.writer(), .{ .whitespace = .indent_1 });
    defer jw.deinit();
    try jw.write(array);

    const expected =
        \\[
        \\ null,
        \\ true,
        \\ 42,
        \\ 43,
        \\ 4.2e1,
        \\ "weeee",
        \\ [
        \\  1,
        \\  2,
        \\  3
        \\ ],
        \\ {
        \\  "a": "b"
        \\ }
        \\]
    ;
    try testing.expectEqualSlices(u8, expected, fbs.getWritten());
}

test "parseFromValue(std.json.Value,...)" {
    const str =
        \\{
        \\  "int": 32,
        \\  "float": 3.2,
        \\  "str": "str",
        \\  "array": [3, 2],
        \\  "object": {}
        \\}
    ;

    const parsed_tree = try parseFromSlice(Value, testing.allocator, str, .{});
    defer parsed_tree.deinit();
    const tree = try parseFromValueLeaky(Value, parsed_tree.arena.allocator(), parsed_tree.value, .{});
    try testing.expect(std.meta.eql(parsed_tree.value, tree));
}

test "polymorphic parsing" {
    if (true) return error.SkipZigTest; // See https://github.com/ziglang/zig/issues/16108
    const doc =
        \\{ "type": "div",
        \\  "color": "blue",
        \\  "children": [
        \\    { "type": "button",
        \\      "caption": "OK" },
        \\    { "type": "button",
        \\      "caption": "Cancel" } ] }
    ;
    const Node = union(enum) {
        div: Div,
        button: Button,
        const Self = @This();
        const Div = struct {
            color: enum { red, blue },
            children: []Self,
        };
        const Button = struct {
            caption: []const u8,
        };

        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            if (source != .object) return error.UnexpectedToken;
            const type_value = source.object.get("type") orelse return error.UnexpectedToken; // Missing "type" field.
            if (type_value != .string) return error.UnexpectedToken; // "type" expected to be string.
            const type_str = type_value.string;
            var child_options = options;
            child_options.ignore_unknown_fields = true;
            if (std.mem.eql(u8, type_str, "div")) return .{ .div = try parseFromValueLeaky(Div, allocator, source, child_options) };
            if (std.mem.eql(u8, type_str, "button")) return .{ .button = try parseFromValueLeaky(Button, allocator, source, child_options) };
            return error.UnexpectedToken; // unknown type.
        }
    };

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const dynamic_tree = try parseFromSliceLeaky(Value, arena.allocator(), doc, .{});
    const tree = try parseFromValueLeaky(Node, arena.allocator(), dynamic_tree, .{});

    try testing.expect(tree.div.color == .blue);
    try testing.expectEqualStrings("Cancel", tree.div.children[1].button.caption);
}

test "long object value" {
    const value = "01234567890123456789";
    const doc = "{\"key\":\"" ++ value ++ "\"}";
    var fbs = std.io.fixedBufferStream(doc);
    var reader = smallBufferJsonReader(testing.allocator, fbs.reader());
    defer reader.deinit();
    var parsed = try parseFromTokenSource(Value, testing.allocator, &reader, .{});
    defer parsed.deinit();

    try testing.expectEqualStrings(value, parsed.value.object.get("key").?.string);
}

test "ParseOptions.max_value_len" {
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const str = "\"0800fc577294c34e0b28ad2839435945\"";

    const value = try std.json.parseFromSliceLeaky(std.json.Value, arena.allocator(), str, .{ .max_value_len = 32 });

    try testing.expect(value == .string);
    try testing.expect(value.string.len == 32);

    try testing.expectError(error.ValueTooLong, std.json.parseFromSliceLeaky(std.json.Value, arena.allocator(), str, .{ .max_value_len = 31 }));
}

test "many object keys" {
    const doc =
        \\{
        \\  "k1": "v1",
        \\  "k2": "v2",
        \\  "k3": "v3",
        \\  "k4": "v4",
        \\  "k5": "v5"
        \\}
    ;
    var fbs = std.io.fixedBufferStream(doc);
    var reader = smallBufferJsonReader(testing.allocator, fbs.reader());
    defer reader.deinit();
    var parsed = try parseFromTokenSource(Value, testing.allocator, &reader, .{});
    defer parsed.deinit();

    try testing.expectEqualStrings("v1", parsed.value.object.get("k1").?.string);
    try testing.expectEqualStrings("v2", parsed.value.object.get("k2").?.string);
    try testing.expectEqualStrings("v3", parsed.value.object.get("k3").?.string);
    try testing.expectEqualStrings("v4", parsed.value.object.get("k4").?.string);
    try testing.expectEqualStrings("v5", parsed.value.object.get("k5").?.string);
}

test "negative zero" {
    const doc = "-0";
    var fbs = std.io.fixedBufferStream(doc);
    var reader = smallBufferJsonReader(testing.allocator, fbs.reader());
    defer reader.deinit();
    var parsed = try parseFromTokenSource(Value, testing.allocator, &reader, .{});
    defer parsed.deinit();

    try testing.expect(std.math.isNegativeZero(parsed.value.float));
}

fn smallBufferJsonReader(allocator: Allocator, io_reader: anytype) JsonReader(16, @TypeOf(io_reader)) {
    return JsonReader(16, @TypeOf(io_reader)).init(allocator, io_reader);
}
