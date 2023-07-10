const std = @import("std");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const jsonStringify = @import("./stringify.zig").stringify;

const Value = @import("./dynamic.zig").Value;

const State = enum {
    start,
    array_start,
    array_post_value,
    object_start,
    object_post_key,
    object_post_value,
    complete,
};

/// Writes JSON ([RFC8259](https://tools.ietf.org/html/rfc8259)) formatted data
/// to a stream. `max_depth` is a comptime-known upper bound on the nesting depth.
/// TODO A future iteration of this API will allow passing `null` for this value,
/// and disable safety checks in release builds.
///
/// The seqeunce of method calls to write JSON content must follow this grammar:
/// ```
///  <once> = <value>
///  <value> =
///    | <object>
///    | <array>
///    | emitNumber
///    | emitString
///    | emitBool
///    | emitNull
///    | emitJson
///  <object> = beginObject ( emitString <value> )* endObject
///  <array> = beginArray ( <value> )* endArray
/// ```
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
                .state_index = 0,
                .state = undefined,
            };
            self.state[0] = .start;
            return self;
        }

        pub fn beginArray(self: *Self) !void {
            try self.valueStart();
            self.pushState(.array_start);
            try self.stream.writeByte('[');
            self.whitespace.indent_level += 1;
        }

        pub fn beginObject(self: *Self) !void {
            try self.valueStart();
            self.pushState(.object_start);
            try self.stream.writeByte('{');
            self.whitespace.indent_level += 1;
        }

        pub fn endArray(self: *Self) !void {
            self.whitespace.indent_level -= 1;
            switch (self.state[self.state_index]) {
                .array_start => {},
                .array_post_value => {
                    try self.indent();
                },
                else => unreachable,
            }
            try self.stream.writeByte(']');
            self.popState();
        }

        pub fn endObject(self: *Self) !void {
            self.whitespace.indent_level -= 1;
            switch (self.state[self.state_index]) {
                .object_start => {},
                .object_post_value => {
                    try self.indent();
                },
                else => unreachable,
            }
            try self.stream.writeByte('}');
            self.popState();
        }

        pub fn emitNull(self: *Self) !void {
            try self.valueStart();
            try self.stringify(null);
            self.valueDone();
        }

        pub fn emitBool(self: *Self, value: bool) !void {
            try self.valueStart();
            try self.stringify(value);
            self.valueDone();
        }

        pub fn emitNumber(
            self: *Self,
            /// An integer, float, or `std.math.BigInt`. Emitted as a bare number if it fits losslessly
            /// in a IEEE 754 double float, otherwise emitted as a string to the full precision.
            value: anytype,
        ) !void {
            switch (@typeInfo(@TypeOf(value))) {
                .Int => |info| {
                    if (info.bits < 53) {
                        try self.valueStart();
                        try self.stream.print("{}", .{value});
                        self.valueDone();
                        return;
                    }
                    if (value < 4503599627370496 and (info.signedness == .unsigned or value > -4503599627370496)) {
                        try self.valueStart();
                        try self.stream.print("{}", .{value});
                        self.valueDone();
                        return;
                    }
                },
                .ComptimeInt => {
                    return self.emitNumber(@as(std.math.IntFittingRange(value, value), value));
                },
                .Float, .ComptimeFloat => if (@as(f64, @floatCast(value)) == value) {
                    try self.valueStart();
                    try self.stream.print("{}", .{@as(f64, @floatCast(value))});
                    self.valueDone();
                    return;
                },
                else => {},
            }
            try self.valueStart();
            try self.stream.print("\"{}\"", .{value});
            self.valueDone();
        }

        pub fn emitString(self: *Self, string: []const u8) !void {
            try self.stringValueStart();
            try self.writeEscapedString(string);
            self.valueDone();
        }

        fn writeEscapedString(self: *Self, string: []const u8) !void {
            assert(std.unicode.utf8ValidateSlice(string));
            try self.stringify(string);
        }

        /// Writes the complete json into the output stream
        pub fn emitJson(self: *Self, value: Value) Stream.Error!void {
            try self.valueStart();
            try self.stringify(value);
            self.valueDone();
        }

        fn indent(self: *Self) !void {
            try self.whitespace.outputIndent(self.stream);
        }

        fn pushState(self: *Self, state: State) void {
            if (self.state[self.state_index] == .start) {
                // Use the top level state for this container.
                self.state[self.state_index] = state;
            } else {
                self.state_index += 1;
                self.state[self.state_index] = state;
            }
        }

        fn popState(self: *Self) void {
            if (self.state_index > 0) {
                // Done with a nested container.
                self.state_index -= 1;
                self.valueDone();
            } else {
                // Done with everything.
                assert(self.state[self.state_index] != .complete);
                self.state[self.state_index] = .complete;
            }
        }

        fn valueStart(self: *Self) !void {
            // Non-strings are banned as object keys.
            switch (self.state[self.state_index]) {
                .object_start, .object_post_value => unreachable, // Expected emitString() or endObject().
                else => {},
            }
            return self.valueStartAssumeTypeOk();
        }
        fn stringValueStart(self: *Self) !void {
            // Strings are allowed as values in every position.
            return self.valueStartAssumeTypeOk();
        }
        fn valueStartAssumeTypeOk(self: *Self) !void {
            switch (self.state[self.state_index]) {
                .start => {},
                .array_start, .object_start => {
                    try self.indent();
                },
                .array_post_value, .object_post_value => {
                    try self.stream.writeByte(',');
                    try self.indent();
                },
                .object_post_key => {
                    try self.stream.writeByte(':');
                    if (self.whitespace.separator) {
                        try self.stream.writeByte(' ');
                    }
                },
                .complete => unreachable, // JSON document already complete.
            }
        }
        fn valueDone(self: *Self) void {
            self.state[self.state_index] = switch (self.state[self.state_index]) {
                .start => .complete, // Only happens for top-level scalar values.
                .array_start => .array_post_value,
                .array_post_value => return,
                .object_start => .object_post_key,
                .object_post_key => .object_post_value,
                .object_post_value => .object_post_key,
                .complete => unreachable,
            };
        }

        fn stringify(self: *Self, value: anytype) !void {
            try jsonStringify(value, StringifyOptions{
                .whitespace = self.whitespace,
            }, self.stream);
        }

        pub const arrayElem = @compileError("Deprecated; You don't need to call this anymore.");
        pub const objectField = @compileError("Deprecated; Call emitString() for object keys instead.");
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

    try w.emitString("object");
    try w.emitJson(try getJsonObject(arena_allocator.allocator()));

    try w.emitString("string");
    try w.emitString("This is a string");

    try w.emitString("array");
    try w.beginArray();
    try w.emitString("Another string");
    try w.emitNumber(@as(i32, 1));
    try w.emitNumber(@as(f32, 3.5));
    try w.endArray();

    try w.emitString("int");
    try w.emitNumber(@as(i32, 10));

    try w.emitString("float");
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
    try value.object.put("one", Value{ .integer = @as(i64, @intCast(1)) });
    try value.object.put("two", Value{ .float = 2.0 });
    return value;
}
