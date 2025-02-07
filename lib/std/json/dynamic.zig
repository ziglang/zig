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

const JsonScanner = @import("./scanner.zig").Scanner;
const AllocWhen = @import("./scanner.zig").AllocWhen;
const Token = @import("./scanner.zig").Token;
const isNumberFormattedLikeAnInteger = @import("./scanner.zig").isNumberFormattedLikeAnInteger;

pub const ObjectMap = StringArrayHashMap(Value);
pub const Array = ArrayList(Value);

/// Represents any JSON value, potentially containing other JSON values.
/// A .float value may be an approximation of the original value.
/// Arbitrary precision numbers can be represented by .number_string values.
/// See also `std.json.ParseOptions.parse_numbers`.
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
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();

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
                    if (options.parse_numbers) {
                        return try handleCompleteValue(&stack, allocator, source, Value.parseFromNumberSlice(slice), options) orelse continue;
                    } else {
                        return try handleCompleteValue(&stack, allocator, source, Value{ .number_string = slice }, options) orelse continue;
                    }
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

    pub const GetError = std.fmt.ParseIntError || std.fmt.ParseFloatError || error{
        /// The type of the value does not match the requested type
        WrongType,

        /// The index into an array value is not an integer
        InvalidIndex,
    };

    /// Get a value from a `std.json.Value` based on a type and a key path.  For
    /// example, given the following JSON:
    ///
    /// ```
    /// {
    ///     "a": [1, {"x": 2, "y": 3}, 4],
    ///     "b": "something else"
    /// }
    /// ```
    ///
    /// Calling `get(i64, &.{"a", "1", "y"})` will return 3, and `get([]const u8, &.{"b"})` will return "something else".
    ///
    /// Valid types are `i64`, `f64`, `[]const u8`, `bool`, std.json.Value, std.json.Array, and std.json.ObjectMap.
    ///
    /// Returns `null` if the key path cannot be found and `error.WrongType` if the data in the value
    /// is incompatible with the requested type.
    pub fn get(self: Value, comptime T: type, key: []const []const u8) GetError!?T {
        if (T != i64 and T != f64 and T != []const u8 and T != bool and T != std.json.Value and T != std.json.Array and T != std.json.ObjectMap) {
            @compileError("Unsupported type: " ++ @typeName(T));
        }

        if (T == std.json.Value) return self;

        switch (self) {
            .null => return null,

            .bool => |b| {
                if (key.len == 0 and T == bool) return b;
                return error.WrongType;
            },

            .integer => |i| {
                if (key.len == 0) {
                    if (T == i64) return i;
                    if (T == f64) return @floatFromInt(i);
                }
                return error.WrongType;
            },

            .float => |f| {
                if (key.len == 0) {
                    if (T == f64) return f;
                    if (T == i64) return @intFromFloat(f);
                }
                return error.WrongType;
            },

            .string => |s| {
                if (key.len == 0 and T == []const u8) return s;
                return error.WrongType;
            },

            .number_string => |s| {
                if (key.len == 0) {
                    if (T == []const u8) return s;
                    if (T == f64) return try std.fmt.parseFloat(f64, s);
                    if (T == i64) return try std.fmt.parseInt(i64, s, 10);
                }
                return error.WrongType;
            },

            .array => |arr| {
                if (key.len == 0) {
                    if (T == std.json.Array) return arr;
                    return error.WrongType;
                }

                const index = std.fmt.parseInt(usize, key[0], 10) catch return error.InvalidIndex;

                if (index >= arr.items.len) return null;

                const child = arr.items[index];

                return child.get(T, key[1..]);
            },

            .object => |obj| {
                if (key.len == 0) {
                    if (T == std.json.ObjectMap) return obj;
                    return error.WrongType;
                }

                const child = obj.get(key[0]) orelse return null;

                return child.get(T, key[1..]);
            },
        }
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

                const gop = try object.getOrPut(key);
                if (gop.found_existing) {
                    switch (options.duplicate_field_behavior) {
                        .use_first => {},
                        .@"error" => return error.DuplicateField,
                        .use_last => {
                            gop.value_ptr.* = value;
                        },
                    }
                } else {
                    gop.value_ptr.* = value;
                }

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
