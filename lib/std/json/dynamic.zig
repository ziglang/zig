const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const stringify = @import("./stringify.zig").stringify;

const JsonScanner = @import("./scanner.zig").JsonScanner;
const AllocWhen = @import("./scanner.zig").AllocWhen;
const Token = @import("./scanner.zig").Token;
const isNumberFormattedLikeAnInteger = @import("./scanner.zig").isNumberFormattedLikeAnInteger;

pub const ValueTree = struct {
    arena: *ArenaAllocator,
    root: Value,

    pub fn deinit(self: *ValueTree) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

pub const ObjectMap = StringArrayHashMap(Value);
pub const Array = ArrayList(Value);

/// Represents a JSON value
/// Currently only supports numbers that fit into i64 or f64.
pub const Value = union(enum) {
    null,
    bool: bool,
    integer: i64,
    float: f64,
    number_string: []const u8,
    string: []const u8,
    array: Array,
    object: ObjectMap,

    pub fn jsonStringify(
        value: @This(),
        options: StringifyOptions,
        out_stream: anytype,
    ) @TypeOf(out_stream).Error!void {
        switch (value) {
            .null => try stringify(null, options, out_stream),
            .bool => |inner| try stringify(inner, options, out_stream),
            .integer => |inner| try stringify(inner, options, out_stream),
            .float => |inner| try stringify(inner, options, out_stream),
            .number_string => |inner| try out_stream.writeAll(inner),
            .string => |inner| try stringify(inner, options, out_stream),
            .array => |inner| try stringify(inner.items, options, out_stream),
            .object => |inner| {
                try out_stream.writeByte('{');
                var field_output = false;
                var child_options = options;
                if (child_options.whitespace) |*child_whitespace| {
                    child_whitespace.indent_level += 1;
                }
                var it = inner.iterator();
                while (it.next()) |entry| {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }

                    try stringify(entry.key_ptr.*, options, out_stream);
                    try out_stream.writeByte(':');
                    if (child_options.whitespace) |child_whitespace| {
                        if (child_whitespace.separator) {
                            try out_stream.writeByte(' ');
                        }
                    }
                    try stringify(entry.value_ptr.*, child_options, out_stream);
                }
                if (field_output) {
                    if (options.whitespace) |whitespace| {
                        try whitespace.outputIndent(out_stream);
                    }
                }
                try out_stream.writeByte('}');
            },
        }
    }

    pub fn dump(self: Value) void {
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();

        const stderr = std.io.getStdErr().writer();
        stringify(self, StringifyOptions{ .whitespace = null }, stderr) catch return;
    }
};

/// A non-stream JSON parser which constructs a tree of Value's.
pub const Parser = struct {
    allocator: Allocator,
    state: State,
    alloc_when: AllocWhen,
    // Stores parent nodes and un-combined Values.
    stack: Array,

    const State = enum {
        object_key,
        object_value,
        array_value,
        simple,
    };

    pub fn init(allocator: Allocator, alloc_when: AllocWhen) Parser {
        return Parser{
            .allocator = allocator,
            .state = .simple,
            .alloc_when = alloc_when,
            .stack = Array.init(allocator),
        };
    }

    pub fn deinit(p: *Parser) void {
        p.stack.deinit();
    }

    pub fn reset(p: *Parser) void {
        p.state = .simple;
        p.stack.shrinkRetainingCapacity(0);
    }

    pub fn parse(p: *Parser, input: []const u8) !ValueTree {
        var scanner = JsonScanner.initCompleteInput(p.allocator, input);
        defer scanner.deinit();

        var arena = try p.allocator.create(ArenaAllocator);
        errdefer p.allocator.destroy(arena);

        arena.* = ArenaAllocator.init(p.allocator);
        errdefer arena.deinit();

        const allocator = arena.allocator();

        while (true) {
            const token = try scanner.nextAlloc(allocator, p.alloc_when);
            if (token == .end_of_document) break;
            try p.transition(allocator, token);
        }

        debug.assert(p.stack.items.len == 1);

        return ValueTree{
            .arena = arena,
            .root = p.stack.items[0],
        };
    }

    // Even though p.allocator exists, we take an explicit allocator so that allocation state
    // can be cleaned up on error correctly during a `parse` on call.
    fn transition(p: *Parser, allocator: Allocator, token: Token) !void {
        switch (p.state) {
            .object_key => switch (token) {
                .object_end => {
                    if (p.stack.items.len == 1) {
                        return;
                    }

                    var value = p.stack.pop();
                    try p.pushToParent(&value);
                },
                .string => |s| {
                    try p.stack.append(Value{ .string = s });
                    p.state = .object_value;
                },
                .allocated_string => |s| {
                    try p.stack.append(Value{ .string = s });
                    p.state = .object_value;
                },
                else => unreachable,
            },
            .object_value => {
                var object = &p.stack.items[p.stack.items.len - 2].object;
                var key = p.stack.items[p.stack.items.len - 1].string;

                switch (token) {
                    .object_begin => {
                        try p.stack.append(Value{ .object = ObjectMap.init(allocator) });
                        p.state = .object_key;
                    },
                    .array_begin => {
                        try p.stack.append(Value{ .array = Array.init(allocator) });
                        p.state = .array_value;
                    },
                    .string => |s| {
                        try object.put(key, Value{ .string = s });
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .allocated_string => |s| {
                        try object.put(key, Value{ .string = s });
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .number => |slice| {
                        try object.put(key, try p.parseNumber(slice));
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .allocated_number => |slice| {
                        try object.put(key, try p.parseNumber(slice));
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .true => {
                        try object.put(key, Value{ .bool = true });
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .false => {
                        try object.put(key, Value{ .bool = false });
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .null => {
                        try object.put(key, .null);
                        _ = p.stack.pop();
                        p.state = .object_key;
                    },
                    .object_end, .array_end, .end_of_document => unreachable,
                    .partial_number, .partial_string, .partial_string_escaped_1, .partial_string_escaped_2, .partial_string_escaped_3, .partial_string_escaped_4 => unreachable,
                }
            },
            .array_value => {
                var array = &p.stack.items[p.stack.items.len - 1].array;

                switch (token) {
                    .array_end => {
                        if (p.stack.items.len == 1) {
                            return;
                        }

                        var value = p.stack.pop();
                        try p.pushToParent(&value);
                    },
                    .object_begin => {
                        try p.stack.append(Value{ .object = ObjectMap.init(allocator) });
                        p.state = .object_key;
                    },
                    .array_begin => {
                        try p.stack.append(Value{ .array = Array.init(allocator) });
                        p.state = .array_value;
                    },
                    .string => |s| {
                        try array.append(Value{ .string = s });
                    },
                    .allocated_string => |s| {
                        try array.append(Value{ .string = s });
                    },
                    .number => |slice| {
                        try array.append(try p.parseNumber(slice));
                    },
                    .allocated_number => |slice| {
                        try array.append(try p.parseNumber(slice));
                    },
                    .true => {
                        try array.append(Value{ .bool = true });
                    },
                    .false => {
                        try array.append(Value{ .bool = false });
                    },
                    .null => {
                        try array.append(.null);
                    },
                    .object_end, .end_of_document => unreachable,
                    .partial_number, .partial_string, .partial_string_escaped_1, .partial_string_escaped_2, .partial_string_escaped_3, .partial_string_escaped_4 => unreachable,
                }
            },
            .simple => switch (token) {
                .object_begin => {
                    try p.stack.append(Value{ .object = ObjectMap.init(allocator) });
                    p.state = .object_key;
                },
                .array_begin => {
                    try p.stack.append(Value{ .array = Array.init(allocator) });
                    p.state = .array_value;
                },
                .string => |s| {
                    try p.stack.append(Value{ .string = s });
                },
                .allocated_string => |s| {
                    try p.stack.append(Value{ .string = s });
                },
                .number => |slice| {
                    try p.stack.append(try p.parseNumber(slice));
                },
                .allocated_number => |slice| {
                    try p.stack.append(try p.parseNumber(slice));
                },
                .true => {
                    try p.stack.append(Value{ .bool = true });
                },
                .false => {
                    try p.stack.append(Value{ .bool = false });
                },
                .null => {
                    try p.stack.append(.null);
                },
                .object_end, .array_end, .end_of_document => unreachable,
                .partial_number, .partial_string, .partial_string_escaped_1, .partial_string_escaped_2, .partial_string_escaped_3, .partial_string_escaped_4 => unreachable,
            },
        }
    }

    fn pushToParent(p: *Parser, value: *const Value) !void {
        switch (p.stack.items[p.stack.items.len - 1]) {
            // Object Parent -> [ ..., object, <key>, value ]
            .string => |key| {
                _ = p.stack.pop();

                var object = &p.stack.items[p.stack.items.len - 1].object;
                try object.put(key, value.*);
                p.state = .object_key;
            },
            // Array Parent -> [ ..., <array>, value ]
            .array => |*array| {
                try array.append(value.*);
                p.state = .array_value;
            },
            else => {
                unreachable;
            },
        }
    }

    fn parseNumber(p: *Parser, slice: []const u8) !Value {
        _ = p;
        return if (isNumberFormattedLikeAnInteger(slice))
            Value{
                .integer = std.fmt.parseInt(i64, slice, 10) catch |e| switch (e) {
                    error.Overflow => return Value{ .number_string = slice },
                    error.InvalidCharacter => |err| return err,
                },
            }
        else
            Value{ .float = try std.fmt.parseFloat(f64, slice) };
    }
};

const testing = std.testing;

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
