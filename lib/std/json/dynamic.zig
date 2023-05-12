const std = @import("std");
const debug = std.debug;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const StringifyOptions = @import("./stringify.zig").StringifyOptions;
const stringify = @import("./stringify.zig").stringify;

const JsonScanner = @import("./scanner.zig").Scanner;
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
                child_options.whitespace.indent_level += 1;
                var it = inner.iterator();
                while (it.next()) |entry| {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    try child_options.whitespace.outputIndent(out_stream);

                    try stringify(entry.key_ptr.*, options, out_stream);
                    try out_stream.writeByte(':');
                    if (child_options.whitespace.separator) {
                        try out_stream.writeByte(' ');
                    }
                    try stringify(entry.value_ptr.*, child_options, out_stream);
                }
                if (field_output) {
                    try options.whitespace.outputIndent(out_stream);
                }
                try out_stream.writeByte('}');
            },
        }
    }

    pub fn dump(self: Value) void {
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();

        const stderr = std.io.getStdErr().writer();
        stringify(self, .{}, stderr) catch return;
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

test {
    _ = @import("dynamic_test.zig");
}
