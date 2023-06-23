const std = @import("std");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const jsonStringify = @import("./stringify.zig").stringify;

const Value = @import("./dynamic.zig").Value;

const State = enum {
    complete,
    value,
    array_start,
    array,
    object_start,
    object,
};

/// Writes JSON ([RFC8259](https://tools.ietf.org/html/rfc8259)) formatted data
/// to a stream. `max_depth` is a comptime-known upper bound on the nesting depth.
/// TODO A future iteration of this API will allow passing `null` for this value,
/// and disable safety checks in release builds.
pub fn WriteStream(comptime OutStream: type, comptime max_depth: usize) type {
    return struct {
        const Self = @This();

        pub const Stream = OutStream;

        whitespace: StringifyOptions.Whitespace = StringifyOptions.Whitespace{
            .indent_level = 0,
            .indent = .{ .space = 1 },
        },

        stream: OutStream,
        state_index: usize,
        state: [max_depth]State,

        pub fn init(stream: OutStream) Self {
            var self = Self{
                .stream = stream,
                .state_index = 1,
                .state = undefined,
            };
            self.state[0] = .complete;
            self.state[1] = .value;
            return self;
        }

        pub fn beginArray(self: *Self) !void {
            assert(self.state[self.state_index] == State.value); // need to call arrayElem or objectField
            try self.stream.writeByte('[');
            self.state[self.state_index] = State.array_start;
            self.whitespace.indent_level += 1;
        }

        pub fn beginObject(self: *Self) !void {
            assert(self.state[self.state_index] == State.value); // need to call arrayElem or objectField
            try self.stream.writeByte('{');
            self.state[self.state_index] = State.object_start;
            self.whitespace.indent_level += 1;
        }

        pub fn arrayElem(self: *Self) !void {
            const state = self.state[self.state_index];
            switch (state) {
                .complete => unreachable,
                .value => unreachable,
                .object_start => unreachable,
                .object => unreachable,
                .array, .array_start => {
                    if (state == .array) {
                        try self.stream.writeByte(',');
                    }
                    self.state[self.state_index] = .array;
                    self.pushState(.value);
                    try self.indent();
                },
            }
        }

        pub fn objectField(self: *Self, name: []const u8) !void {
            const state = self.state[self.state_index];
            switch (state) {
                .complete => unreachable,
                .value => unreachable,
                .array_start => unreachable,
                .array => unreachable,
                .object, .object_start => {
                    if (state == .object) {
                        try self.stream.writeByte(',');
                    }
                    self.state[self.state_index] = .object;
                    self.pushState(.value);
                    try self.indent();
                    try self.writeEscapedString(name);
                    try self.stream.writeByte(':');
                    if (self.whitespace.separator) {
                        try self.stream.writeByte(' ');
                    }
                },
            }
        }

        pub fn endArray(self: *Self) !void {
            switch (self.state[self.state_index]) {
                .complete => unreachable,
                .value => unreachable,
                .object_start => unreachable,
                .object => unreachable,
                .array_start => {
                    self.whitespace.indent_level -= 1;
                    try self.stream.writeByte(']');
                    self.popState();
                },
                .array => {
                    self.whitespace.indent_level -= 1;
                    try self.indent();
                    self.popState();
                    try self.stream.writeByte(']');
                },
            }
        }

        pub fn endObject(self: *Self) !void {
            switch (self.state[self.state_index]) {
                .complete => unreachable,
                .value => unreachable,
                .array_start => unreachable,
                .array => unreachable,
                .object_start => {
                    self.whitespace.indent_level -= 1;
                    try self.stream.writeByte('}');
                    self.popState();
                },
                .object => {
                    self.whitespace.indent_level -= 1;
                    try self.indent();
                    self.popState();
                    try self.stream.writeByte('}');
                },
            }
        }

        pub fn emitNull(self: *Self) !void {
            assert(self.state[self.state_index] == State.value);
            try self.stringify(null);
            self.popState();
        }

        pub fn emitBool(self: *Self, value: bool) !void {
            assert(self.state[self.state_index] == State.value);
            try self.stringify(value);
            self.popState();
        }

        pub fn emitNumber(
            self: *Self,
            /// An integer, float, or `std.math.BigInt`. Emitted as a bare number if it fits losslessly
            /// in a IEEE 754 double float, otherwise emitted as a string to the full precision.
            value: anytype,
        ) !void {
            assert(self.state[self.state_index] == State.value);
            switch (@typeInfo(@TypeOf(value))) {
                .Int => |info| {
                    if (info.bits < 53) {
                        try self.stream.print("{}", .{value});
                        self.popState();
                        return;
                    }
                    if (value < 4503599627370496 and (info.signedness == .unsigned or value > -4503599627370496)) {
                        try self.stream.print("{}", .{value});
                        self.popState();
                        return;
                    }
                },
                .ComptimeInt => {
                    return self.emitNumber(@as(std.math.IntFittingRange(value, value), value));
                },
                .Float, .ComptimeFloat => if (@floatCast(f64, value) == value) {
                    try self.stream.print("{}", .{@floatCast(f64, value)});
                    self.popState();
                    return;
                },
                else => {},
            }
            try self.stream.print("\"{}\"", .{value});
            self.popState();
        }

        pub fn emitString(self: *Self, string: []const u8) !void {
            assert(self.state[self.state_index] == State.value);
            try self.writeEscapedString(string);
            self.popState();
        }

        fn writeEscapedString(self: *Self, string: []const u8) !void {
            assert(std.unicode.utf8ValidateSlice(string));
            try self.stringify(string);
        }

        /// Writes the complete json into the output stream
        pub fn emitJson(self: *Self, value: Value) Stream.Error!void {
            assert(self.state[self.state_index] == State.value);
            try self.stringify(value);
            self.popState();
        }

        fn indent(self: *Self) !void {
            assert(self.state_index >= 1);
            try self.whitespace.outputIndent(self.stream);
        }

        fn pushState(self: *Self, state: State) void {
            self.state_index += 1;
            self.state[self.state_index] = state;
        }

        fn popState(self: *Self) void {
            self.state_index -= 1;
        }

        fn stringify(self: *Self, value: anytype) !void {
            try jsonStringify(value, StringifyOptions{
                .whitespace = self.whitespace,
            }, self.stream);
        }
    };
}

pub fn writeStream(
    out_stream: anytype,
    comptime max_depth: usize,
) WriteStream(@TypeOf(out_stream), max_depth) {
    return WriteStream(@TypeOf(out_stream), max_depth).init(out_stream);
}

const ObjectMap = @import("./dynamic.zig").ObjectMap;

test "json write stream" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    var w = writeStream(out, 10);

    try w.beginObject();

    try w.objectField("object");
    try w.emitJson(try getJsonObject(arena_allocator.allocator()));

    try w.objectField("string");
    try w.emitString("This is a string");

    try w.objectField("array");
    try w.beginArray();
    try w.arrayElem();
    try w.emitString("Another string");
    try w.arrayElem();
    try w.emitNumber(@as(i32, 1));
    try w.arrayElem();
    try w.emitNumber(@as(f32, 3.5));
    try w.endArray();

    try w.objectField("int");
    try w.emitNumber(@as(i32, 10));

    try w.objectField("float");
    try w.emitNumber(@as(f32, 3.5));

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
    try value.object.put("one", Value{ .integer = @intCast(i64, 1) });
    try value.object.put("two", Value{ .float = 2.0 });
    return value;
}
