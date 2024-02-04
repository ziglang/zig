const std = @import("std");
const debug = std.debug;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const stringify = @import("./stringify.zig").stringify;

const ParseOptions = @import("./static.zig").ParseOptions;
const ParseError = @import("./static.zig").ParseError;
const Parsed = @import("./static.zig").Parsed;

const JsonScanner = @import("./scanner.zig").Scanner;
const AllocWhen = @import("./scanner.zig").AllocWhen;
const Token = @import("./scanner.zig").Token;
const isNumberFormattedLikeAnInteger = @import("./scanner.zig").isNumberFormattedLikeAnInteger;

pub const ObjectMap = StringArrayHashMap(Value);
pub const Array = ArrayList(Value);

/// Represents any JSON value, potentially containing other JSON values.
/// A .float value may be an approximation of the original value.
/// Arbitrary precision numbers can be represented by .number_string values.
pub const Value = union(enum) {
    null,
    bool: bool,
    integer: i64,
    float: f64,
    number_string: []const u8,
    string: []const u8,
    array: Array,
    object: ObjectMap,

    pub fn parseFromNumberSlice(s: []const u8) Value {
        if (!isNumberFormattedLikeAnInteger(s)) {
            const f = std.fmt.parseFloat(f64, s) catch unreachable;
            if (std.math.isFinite(f)) {
                return Value{ .float = f };
            } else {
                return Value{ .number_string = s };
            }
        }
        if (std.fmt.parseInt(i64, s, 10)) |i| {
            return Value{ .integer = i };
        } else |e| {
            switch (e) {
                error.Overflow => return Value{ .number_string = s },
                error.InvalidCharacter => unreachable,
            }
        }
    }

    pub fn dump(self: Value) void {
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();

        const stderr = std.io.getStdErr().writer();
        stringify(self, .{}, stderr) catch return;
    }

    pub fn jsonStringify(value: @This(), jws: anytype) !void {
        switch (value) {
            .null => try jws.write(null),
            .bool => |inner| try jws.write(inner),
            .integer => |inner| try jws.write(inner),
            .float => |inner| try jws.write(inner),
            .number_string => |inner| try jws.print("{s}", .{inner}),
            .string => |inner| try jws.write(inner),
            .array => |inner| try jws.write(inner.items),
            .object => |inner| {
                try jws.beginObject();
                var it = inner.iterator();
                while (it.next()) |entry| {
                    try jws.objectField(entry.key_ptr.*);
                    try jws.write(entry.value_ptr.*);
                }
                try jws.endObject();
            },
        }
    }

    pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) ParseError(@TypeOf(source.*))!@This() {
        // The grammar of the stack is:
        //  (.array | .object .string)*
        var stack = Array.init(allocator);
        defer stack.deinit();

        while (true) {
            // Assert the stack grammar at the top of the stack.
            debug.assert(stack.items.len == 0 or
                stack.items[stack.items.len - 1] == .array or
                (stack.items[stack.items.len - 2] == .object and stack.items[stack.items.len - 1] == .string));

            switch (try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?)) {
                .allocated_string => |s| {
                    return try handleCompleteValue(&stack, allocator, source, Value{ .string = s }, options) orelse continue;
                },
                .allocated_number => |slice| {
                    return try handleCompleteValue(&stack, allocator, source, Value.parseFromNumberSlice(slice), options) orelse continue;
                },

                .null => return try handleCompleteValue(&stack, allocator, source, .null, options) orelse continue,
                .true => return try handleCompleteValue(&stack, allocator, source, Value{ .bool = true }, options) orelse continue,
                .false => return try handleCompleteValue(&stack, allocator, source, Value{ .bool = false }, options) orelse continue,

                .object_begin => {
                    switch (try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?)) {
                        .object_end => return try handleCompleteValue(&stack, allocator, source, Value{ .object = ObjectMap.init(allocator) }, options) orelse continue,
                        .allocated_string => |key| {
                            try stack.appendSlice(&[_]Value{
                                Value{ .object = ObjectMap.init(allocator) },
                                Value{ .string = key },
                            });
                        },
                        else => unreachable,
                    }
                },
                .array_begin => {
                    try stack.append(Value{ .array = Array.init(allocator) });
                },
                .array_end => return try handleCompleteValue(&stack, allocator, source, stack.pop(), options) orelse continue,

                else => unreachable,
            }
        }
    }

    pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
        _ = allocator;
        _ = options;
        return source;
    }

    pub fn fromAnytype(allocator: std.mem.Allocator, value: anytype, options: StringifyOptions) (std.json.Error || std.mem.Allocator.Error)!Parsed(Value) {
        var parsed = Parsed(Value){
            .arena = try allocator.create(ArenaAllocator),
            .value = undefined,
        };
        errdefer allocator.destroy(parsed.arena);
        parsed.arena.* = ArenaAllocator.init(allocator);
        errdefer parsed.arena.deinit();

        parsed.value = try fromAnytypeLeaky(parsed.arena.allocator(), value, options);

        return parsed;
    }

    pub fn fromAnytypeLeaky(allocator: std.mem.Allocator, value: anytype, options: StringifyOptions) (std.json.Error || std.mem.Allocator.Error)!Value {
        const T = @TypeOf(value);
        switch (@typeInfo(T)) {
            .Void => {
                return Value{ .object = ObjectMap.init(allocator) };
            },
            .Int => |info| {
                _ = info;

                if (std.math.cast(i64, value)) |x| {
                    return Value{ .integer = x };
                } else {
                    return Value{ .number_string = try std.fmt.allocPrint(allocator, "{}", .{value}) };
                }
            },
            .ComptimeInt => {
                if (std.math.cast(i64, value)) |x| {
                    return Value{ .integer = x };
                } else {
                    return Value{ .number_string = std.fmt.allocPrint(allocator, "{}", .{value}) };
                }
            },
            .Float, .ComptimeFloat => {
                if (@as(f64, @floatCast(value)) == value) {
                    return Value{ .float = @as(f64, @floatCast(value)) };
                }
                return Value{ .number_string = std.fmt.allocPrint(allocator, "{}", .{value}) };
            },
            .Bool => {
                return Value{ .bool = value };
            },
            .Null => {
                return Value.null;
            },
            .Optional => {
                if (value) |payload| {
                    return fromAnytypeLeaky(allocator, payload);
                } else {
                    return Value.null;
                }
            },
            .Enum => {
                return Value{ .string = @tagName(value) };
            },
            .Union => {
                var map = ObjectMap.init(allocator);
                const info = @typeInfo(T).Union;
                if (info.tag_type) |UnionTagType| {
                    inline for (info.fields) |u_field| {
                        if (value == @field(UnionTagType, u_field.name)) {
                            try map.put(
                                u_field.name,
                                try fromAnytypeLeaky(allocator, @field(value, u_field.name)),
                            );
                            break;
                        }
                    } else {
                        unreachable; // No active tag?
                    }
                    return Value{ .object = map };
                } else {
                    @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
                }
            },
            .Struct => |S| {
                if (S.is_tuple) {
                    var array = Array.init(allocator);
                    inline for (S.fields) |Field| {
                        const field_value = try fromAnytypeLeaky(allocator, @field(value, Field.name));
                        try array.append(field_value);
                    }
                    return Value{ .array = array };
                } else {
                    var map = ObjectMap.init(allocator);
                    inline for (S.fields) |Field| {
                        if (options.emit_null_optional_fields == false and @field(value, Field.name) == null) {
                            // skip field
                        } else {
                            const field_value = try fromAnytypeLeaky(allocator, @field(value, Field.name));
                            try map.put(Field.name, field_value);
                        }
                    }
                    return Value{ .object = map };
                }
                return;
            },
            .ErrorSet => return fromAnytypeLeaky(allocator, @errorName(value)),
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .One => switch (@typeInfo(ptr_info.child)) {
                    .Array => {
                        // Coerce `*[N]T` to `[]const T`.
                        const Slice = []const std.meta.Elem(ptr_info.child);
                        return fromAnytypeLeaky(allocator, @as(Slice, value));
                    },
                    else => {
                        return fromAnytypeLeaky(allocator, value.*);
                    },
                },
                .Many, .Slice => {
                    if (ptr_info.size == .Many and ptr_info.sentinel == null)
                        @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                    const slice = if (ptr_info.size == .Many) std.mem.span(value) else value;

                    if (ptr_info.child == u8) {
                        // This is a []const u8, or some similar Zig string.
                        if (!options.emit_strings_as_arrays and std.unicode.utf8ValidateSlice(slice)) {
                            return Value{ .string = slice };
                        }
                    }

                    var array = Array.init(allocator);
                    for (slice) |x| {
                        const x_value = try fromAnytypeLeaky(allocator, x);
                        try array.append(x_value);
                    }
                    return Value{ .array = array };
                },
                else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
            },
            .Array => {
                // Coerce `[N]T` to `*const [N]T` (and then to `[]const T`).
                return fromAnytypeLeaky(allocator, &value);
            },
            .Vector => |info| {
                const array: [info.len]info.child = value;
                return fromAnytypeLeaky(allocator, &array);
            },
            else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
        }
        unreachable;
    }
};

fn handleCompleteValue(stack: *Array, allocator: Allocator, source: anytype, value_: Value, options: ParseOptions) !?Value {
    if (stack.items.len == 0) return value_;
    var value = value_;
    while (true) {
        // Assert the stack grammar at the top of the stack.
        debug.assert(stack.items[stack.items.len - 1] == .array or
            (stack.items[stack.items.len - 2] == .object and stack.items[stack.items.len - 1] == .string));
        switch (stack.items[stack.items.len - 1]) {
            .string => |key| {
                // stack: [..., .object, .string]
                _ = stack.pop();

                // stack: [..., .object]
                var object = &stack.items[stack.items.len - 1].object;
                try object.put(key, value);

                // This is an invalid state to leave the stack in,
                // so we have to process the next token before we return.
                switch (try source.nextAllocMax(allocator, .alloc_always, options.max_value_len.?)) {
                    .object_end => {
                        // This object is complete.
                        value = stack.pop();
                        // Effectively recurse now that we have a complete value.
                        if (stack.items.len == 0) return value;
                        continue;
                    },
                    .allocated_string => |next_key| {
                        // We've got another key.
                        try stack.append(Value{ .string = next_key });
                        // stack: [..., .object, .string]
                        return null;
                    },
                    else => unreachable,
                }
            },
            .array => |*array| {
                // stack: [..., .array]
                try array.append(value);
                return null;
            },
            else => unreachable,
        }
    }
}

test {
    _ = @import("dynamic_test.zig");
}
