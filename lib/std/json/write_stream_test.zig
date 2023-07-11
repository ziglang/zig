const std = @import("std");

const ObjectMap = @import("./dynamic.zig").ObjectMap;
const Value = @import("./dynamic.zig").Value;

const writeStream = @import("./write_stream.zig").writeStream;

test "json write stream" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    var w = writeStream(out, 10);

    try w.beginObject();

    try w.write("object");
    try w.write(try getJsonObject(arena_allocator.allocator()));

    try w.write("string");
    try w.write("This is a string");

    try w.write("array");
    try w.beginArray();
    try w.write("Another string");
    try w.write(@as(i32, 1));
    try w.write(@as(f32, 3.5));
    try w.endArray();

    try w.write("int");
    try w.write(@as(i32, 10));

    try w.write("float");
    try w.write(@as(f32, 3.5));

    try w.endObject();

    const result = slice_stream.getWritten();
    const expected =
        \\{
        \\ "object": {
        \\  "one": 1,
        \\  "two": 2.0e+00
        \\ },
        \\ "string": "This is a string",
        \\ "array": [
        \\  "Another string",
        \\  1,
        \\  3.5e+00
        \\ ],
        \\ "int": 10,
        \\ "float": 3.5e+00
        \\}
    ;
    try std.testing.expect(std.mem.eql(u8, expected, result));
}

fn getJsonObject(allocator: std.mem.Allocator) !Value {
    var value = Value{ .object = ObjectMap.init(allocator) };
    try value.object.put("one", Value{ .integer = @as(i64, @intCast(1)) });
    try value.object.put("two", Value{ .float = 2.0 });
    return value;
}

test "json write stream primatives" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var w = writeStream(out, 1);
    try w.write(null);
    // TODO
}
