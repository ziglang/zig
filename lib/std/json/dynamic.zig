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
        _ = options;
        // The grammar of the stack is:
        //  (.array | .object .string)*
        var stack = Array.init(allocator);
        defer stack.deinit();

        while (true) {
            // Assert the stack grammar at the top of the stack.
            debug.assert(stack.items.len == 0 or
                stack.items[stack.items.len - 1] == .array or
                (stack.items[stack.items.len - 2] == .object and stack.items[stack.items.len - 1] == .string));

            switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                inline .string, .allocated_string => |s| {
                    return try handleCompleteValue(&stack, allocator, source, Value{ .string = s }) orelse continue;
                },
                inline .number, .allocated_number => |slice| {
                    return try handleCompleteValue(&stack, allocator, source, Value.parseFromNumberSlice(slice)) orelse continue;
                },

                .null => return try handleCompleteValue(&stack, allocator, source, .null) orelse continue,
                .true => return try handleCompleteValue(&stack, allocator, source, Value{ .bool = true }) orelse continue,
                .false => return try handleCompleteValue(&stack, allocator, source, Value{ .bool = false }) orelse continue,

                .object_begin => {
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .object_end => return try handleCompleteValue(&stack, allocator, source, Value{ .object = ObjectMap.init(allocator) }) orelse continue,
                        inline .string, .allocated_string => |key| {
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
                .array_end => return try handleCompleteValue(&stack, allocator, source, stack.pop()) orelse continue,

                else => unreachable,
            }
        }
    }

    pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
        _ = allocator;
        _ = options;
        return source;
    }
};

fn handleCompleteValue(stack: *Array, allocator: Allocator, source: anytype, value_: Value) !?Value {
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
                switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                    .object_end => {
                        // This object is complete.
                        value = stack.pop();
                        // Effectively recurse now that we have a complete value.
                        if (stack.items.len == 0) return value;
                        continue;
                    },
                    inline .string, .allocated_string => |next_key| {
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
