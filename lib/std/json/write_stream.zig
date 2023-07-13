const std = @import("std");
const assert = std.debug.assert;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const encodeJsonString = @import("./stringify.zig").encodeJsonString;

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
///    | write
///    | writePreformatted
///  <object> = beginObject ( <string> <value> )* endObject
///  <array> = beginArray ( <value> )* endArray
///  <string> = <it's a <value> which must be just a string>
/// ```
pub fn WriteStream(comptime OutStream: type, comptime max_depth: usize) type {
    return struct {
        const Self = @This();

        pub const Stream = OutStream;

        // TODO: why is this the default?
        options: StringifyOptions = .{
            .whitespace = .{
                .indent = .{ .space = 1 },
            },
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
            self.options.whitespace.indent_level += 1;
        }

        pub fn beginObject(self: *Self) !void {
            try self.valueStart();
            self.pushState(.object_start);
            try self.stream.writeByte('{');
            self.options.whitespace.indent_level += 1;
        }

        pub fn endArray(self: *Self) !void {
            self.options.whitespace.indent_level -= 1;
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
            self.options.whitespace.indent_level -= 1;
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

        fn indent(self: *Self) !void {
            try self.options.whitespace.outputIndent(self.stream);
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
                .object_start, .object_post_value => unreachable, // Expected string or endObject().
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
                    if (self.options.whitespace.separator) {
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

        /// TODO: docs
        pub fn writePreformatted(self: *Self, value_slice: []const u8) !void {
            try self.valueStart(); // TODO: is_string = value_slice.len > 0 and value_slice[0] == '"';
            try self.stream.writeAll(value_slice);
            self.valueDone();
        }

        /// Supported types:
        ///
        /// Number: An integer, float, or `std.math.BigInt`. Emitted as a bare number if it fits losslessly
        /// in a IEEE 754 double float, otherwise emitted as a string to the full precision.
        ///
        /// TODO: more docs.
        pub fn write(self: *Self, value: anytype) OutStream.Error!void {
            const T = @TypeOf(value);
            switch (@typeInfo(T)) {
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
                    try self.valueStart();
                    try self.stream.print("\"{}\"", .{value});
                    self.valueDone();
                    return;
                },
                .ComptimeInt => {
                    return self.write(@as(std.math.IntFittingRange(value, value), value));
                },
                .Float, .ComptimeFloat => {
                    if (@as(f64, @floatCast(value)) == value) {
                        try self.valueStart();
                        try self.stream.print("{}", .{@as(f64, @floatCast(value))});
                        self.valueDone();
                        return;
                    }
                    try self.valueStart();
                    try self.stream.print("\"{}\"", .{value});
                    self.valueDone();
                    return;
                },

                .Bool => {
                    try self.valueStart();
                    try self.stream.writeAll(if (value) "true" else "false");
                    self.valueDone();
                    return;
                },
                .Null => {
                    try self.valueStart();
                    try self.stream.writeAll("null");
                    self.valueDone();
                    return;
                },
                .Optional => {
                    if (value) |payload| {
                        return try self.write(payload);
                    } else {
                        return try self.write(null);
                    }
                },
                .Enum => {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    try self.stringValueStart();
                    try encodeJsonString(@tagName(value), self.options, self.stream);
                    self.valueDone();
                    return;
                },
                .Union => {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    const info = @typeInfo(T).Union;
                    if (info.tag_type) |UnionTagType| {
                        try self.beginObject();
                        inline for (info.fields) |u_field| {
                            if (value == @field(UnionTagType, u_field.name)) {
                                try self.write(u_field.name);
                                if (u_field.type == void) {
                                    // void value is {}
                                    try self.beginObject();
                                    try self.endObject();
                                } else {
                                    try self.write(@field(value, u_field.name));
                                }
                                break;
                            }
                        } else {
                            unreachable; // No active tag?
                        }
                        try self.endObject();
                        return;
                    } else {
                        @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
                    }
                },
                .Struct => |S| {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    if (S.is_tuple) {
                        try self.beginArray();
                    } else {
                        try self.beginObject();
                    }
                    inline for (S.fields) |Field| {
                        // don't include void fields
                        if (Field.type == void) continue;

                        var emit_field = true;

                        // don't include optional fields that are null when emit_null_optional_fields is set to false
                        if (@typeInfo(Field.type) == .Optional) {
                            if (self.options.emit_null_optional_fields == false) {
                                if (@field(value, Field.name) == null) {
                                    emit_field = false;
                                }
                            }
                        }

                        if (emit_field) {
                            if (!S.is_tuple) {
                                try self.write(Field.name);
                            }
                            try self.write(@field(value, Field.name));
                        }
                    }
                    if (S.is_tuple) {
                        try self.endArray();
                    } else {
                        try self.endObject();
                    }
                    return;
                },
                .ErrorSet => return self.write(@as([]const u8, @errorName(value))),
                .Pointer => |ptr_info| switch (ptr_info.size) {
                    .One => switch (@typeInfo(ptr_info.child)) {
                        .Array => {
                            // Coerce `*[N]T` to `[]const T`.
                            const Slice = []const std.meta.Elem(ptr_info.child);
                            return self.write(@as(Slice, value));
                        },
                        else => {
                            // TODO: avoid loops?
                            return self.write(value.*);
                        },
                    },
                    .Many, .Slice => {
                        if (ptr_info.size == .Many and ptr_info.sentinel == null)
                            @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                        const slice = if (ptr_info.size == .Many) std.mem.span(value) else value;

                        if (ptr_info.child == u8) {
                            // This is a []const u8, or some similar Zig string.
                            var render_as_string = switch (self.options.string) {
                                .String => true,
                                .Array => false,
                            };
                            switch (self.state[self.state_index]) {
                                .object_start, .object_post_value => {
                                    // Object keys must always be rendered as strings.
                                    render_as_string = true;
                                    assert(std.unicode.utf8ValidateSlice(slice)); // Object keys must be valid UTF-8 strings.
                                },
                                else => {
                                    // Fallback to array representation for non-UTF-8, even if .String mode was desired.
                                    render_as_string = render_as_string and std.unicode.utf8ValidateSlice(slice);
                                },
                            }
                            if (render_as_string) {
                                try self.stringValueStart();
                                try encodeJsonString(slice, self.options, self.stream);
                                self.valueDone();
                                return;
                            }
                        }

                        try self.beginArray();
                        for (slice) |x| {
                            try self.write(x);
                        }
                        try self.endArray();
                        return;
                    },
                    else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
                },
                .Array => {
                    // Coerce `[N]T` to `*const [N]T` (and then to `[]const T`).
                    return self.write(&value);
                },
                .Vector => |info| {
                    const array: [info.len]info.child = value;
                    return self.write(&array);
                },
                else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
            }
            unreachable;
        }

        pub const arrayElem = @compileError("Deprecated; You don't need to call this anymore.");
        pub const objectField = @compileError("Deprecated; Call write() for object keys instead.");
        pub const emitNull = @compileError("Deprecated; Use .write(null) instead.");
        pub const emitBool = @compileError("Deprecated; Use .write() instead.");
        pub const emitNumber = @compileError("Deprecated; Use .write() instead.");
        pub const emitString = @compileError("Deprecated; Use .write() instead.");
        pub const emitJson = @compileError("Deprecated; Use .write() instead.");
    };
}

pub fn writeStream(
    out_stream: anytype,
    comptime max_depth: usize,
) WriteStream(@TypeOf(out_stream), max_depth) {
    return WriteStream(@TypeOf(out_stream), max_depth).init(out_stream);
}

test {
    _ = @import("write_stream_test.zig");
}
