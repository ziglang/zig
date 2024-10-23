const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const log = std.log.scoped(.yaml);

const Allocator = mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

pub const Tokenizer = @import("Tokenizer.zig");
pub const parse = @import("parse.zig");

const Node = parse.Node;
const Tree = parse.Tree;
const ParseError = parse.ParseError;

pub const YamlError = error{
    UnexpectedNodeType,
    DuplicateMapKey,
    OutOfMemory,
    CannotEncodeValue,
} || ParseError || std.fmt.ParseIntError;

pub const List = []Value;
pub const Map = std.StringHashMap(Value);

pub const Value = union(enum) {
    empty,
    int: i64,
    float: f64,
    string: []const u8,
    list: List,
    map: Map,

    pub fn asInt(self: Value) !i64 {
        if (self != .int) return error.TypeMismatch;
        return self.int;
    }

    pub fn asFloat(self: Value) !f64 {
        if (self != .float) return error.TypeMismatch;
        return self.float;
    }

    pub fn asString(self: Value) ![]const u8 {
        if (self != .string) return error.TypeMismatch;
        return self.string;
    }

    pub fn asList(self: Value) !List {
        if (self != .list) return error.TypeMismatch;
        return self.list;
    }

    pub fn asMap(self: Value) !Map {
        if (self != .map) return error.TypeMismatch;
        return self.map;
    }

    const StringifyArgs = struct {
        indentation: usize = 0,
        should_inline_first_key: bool = false,
    };

    pub fn stringify(self: Value, writer: anytype, args: StringifyArgs) anyerror!void {
        switch (self) {
            .empty => return,
            .int => |int| return writer.print("{}", .{int}),
            .float => |float| return writer.print("{d}", .{float}),
            .string => |string| return writer.print("{s}", .{string}),
            .list => |list| {
                const len = list.len;
                if (len == 0) return;

                const first = list[0];
                if (first.isCompound()) {
                    for (list, 0..) |elem, i| {
                        try writer.writeByteNTimes(' ', args.indentation);
                        try writer.writeAll("- ");
                        try elem.stringify(writer, .{
                            .indentation = args.indentation + 2,
                            .should_inline_first_key = true,
                        });
                        if (i < len - 1) {
                            try writer.writeByte('\n');
                        }
                    }
                    return;
                }

                try writer.writeAll("[ ");
                for (list, 0..) |elem, i| {
                    try elem.stringify(writer, args);
                    if (i < len - 1) {
                        try writer.writeAll(", ");
                    }
                }
                try writer.writeAll(" ]");
            },
            .map => |map| {
                const len = map.count();
                if (len == 0) return;

                var i: usize = 0;
                var it = map.iterator();
                while (it.next()) |entry| {
                    const key = entry.key_ptr.*;
                    const value = entry.value_ptr.*;

                    if (!args.should_inline_first_key or i != 0) {
                        try writer.writeByteNTimes(' ', args.indentation);
                    }
                    try writer.print("{s}: ", .{key});

                    const should_inline = blk: {
                        if (!value.isCompound()) break :blk true;
                        if (value == .list and value.list.len > 0 and !value.list[0].isCompound()) break :blk true;
                        break :blk false;
                    };

                    if (should_inline) {
                        try value.stringify(writer, args);
                    } else {
                        try writer.writeByte('\n');
                        try value.stringify(writer, .{
                            .indentation = args.indentation + 4,
                        });
                    }

                    if (i < len - 1) {
                        try writer.writeByte('\n');
                    }

                    i += 1;
                }
            },
        }
    }

    fn isCompound(self: Value) bool {
        return switch (self) {
            .list, .map => true,
            else => false,
        };
    }

    fn fromNode(arena: Allocator, tree: *const Tree, node: *const Node) YamlError!Value {
        if (node.cast(Node.Doc)) |doc| {
            const inner = doc.value orelse {
                // empty doc
                return Value{ .empty = {} };
            };
            return Value.fromNode(arena, tree, inner);
        } else if (node.cast(Node.Map)) |map| {
            // TODO use ContextAdapted HashMap and do not duplicate keys, intern
            // in a contiguous string buffer.
            var out_map = std.StringHashMap(Value).init(arena);
            try out_map.ensureUnusedCapacity(math.cast(u32, map.values.items.len) orelse return error.Overflow);

            for (map.values.items) |entry| {
                const key = try arena.dupe(u8, tree.getRaw(entry.key, entry.key));
                const gop = out_map.getOrPutAssumeCapacity(key);
                if (gop.found_existing) {
                    return error.DuplicateMapKey;
                }
                const value = if (entry.value) |value|
                    try Value.fromNode(arena, tree, value)
                else
                    .empty;
                gop.value_ptr.* = value;
            }

            return Value{ .map = out_map };
        } else if (node.cast(Node.List)) |list| {
            var out_list = std.ArrayList(Value).init(arena);
            try out_list.ensureUnusedCapacity(list.values.items.len);

            for (list.values.items) |elem| {
                const value = try Value.fromNode(arena, tree, elem);
                out_list.appendAssumeCapacity(value);
            }

            return Value{ .list = try out_list.toOwnedSlice() };
        } else if (node.cast(Node.Value)) |value| {
            const raw = tree.getRaw(node.start, node.end);

            try_int: {
                // TODO infer base for int
                const int = std.fmt.parseInt(i64, raw, 10) catch break :try_int;
                return Value{ .int = int };
            }

            try_float: {
                const float = std.fmt.parseFloat(f64, raw) catch break :try_float;
                return Value{ .float = float };
            }

            return Value{ .string = try arena.dupe(u8, value.string_value.items) };
        } else {
            log.debug("Unexpected node type: {}", .{node.tag});
            return error.UnexpectedNodeType;
        }
    }

    fn encode(arena: Allocator, input: anytype) YamlError!?Value {
        switch (@typeInfo(@TypeOf(input))) {
            .comptime_int,
            .int,
            => return Value{ .int = math.cast(i64, input) orelse return error.Overflow },

            .float => return Value{ .float = math.lossyCast(f64, input) },

            .@"struct" => |info| if (info.is_tuple) {
                var list = std.ArrayList(Value).init(arena);
                errdefer list.deinit();
                try list.ensureTotalCapacityPrecise(info.fields.len);

                inline for (info.fields) |field| {
                    if (try encode(arena, @field(input, field.name))) |value| {
                        list.appendAssumeCapacity(value);
                    }
                }

                return Value{ .list = try list.toOwnedSlice() };
            } else {
                var map = Map.init(arena);
                errdefer map.deinit();
                try map.ensureTotalCapacity(info.fields.len);

                inline for (info.fields) |field| {
                    if (try encode(arena, @field(input, field.name))) |value| {
                        const key = try arena.dupe(u8, field.name);
                        map.putAssumeCapacityNoClobber(key, value);
                    }
                }

                return Value{ .map = map };
            },

            .@"union" => |info| if (info.tag_type) |tag_type| {
                inline for (info.fields) |field| {
                    if (@field(tag_type, field.name) == input) {
                        return try encode(arena, @field(input, field.name));
                    }
                } else unreachable;
            } else return error.UntaggedUnion,

            .array => return encode(arena, &input),

            .pointer => |info| switch (info.size) {
                .One => switch (@typeInfo(info.child)) {
                    .array => |child_info| {
                        const Slice = []const child_info.child;
                        return encode(arena, @as(Slice, input));
                    },
                    else => {
                        @compileError("Unhandled type: {s}" ++ @typeName(info.child));
                    },
                },
                .Slice => {
                    if (info.child == u8) {
                        return Value{ .string = try arena.dupe(u8, input) };
                    }

                    var list = std.ArrayList(Value).init(arena);
                    errdefer list.deinit();
                    try list.ensureTotalCapacityPrecise(input.len);

                    for (input) |elem| {
                        if (try encode(arena, elem)) |value| {
                            list.appendAssumeCapacity(value);
                        } else {
                            log.debug("Could not encode value in a list: {any}", .{elem});
                            return error.CannotEncodeValue;
                        }
                    }

                    return Value{ .list = try list.toOwnedSlice() };
                },
                else => {
                    @compileError("Unhandled type: {s}" ++ @typeName(@TypeOf(input)));
                },
            },

            // TODO we should probably have an option to encode `null` and also
            // allow for some default value too.
            .optional => return if (input) |val| encode(arena, val) else null,

            .null => return null,

            else => {
                @compileError("Unhandled type: {s}" ++ @typeName(@TypeOf(input)));
            },
        }
    }
};

pub const Yaml = struct {
    arena: ArenaAllocator,
    tree: ?Tree = null,
    docs: std.ArrayList(Value),

    pub fn deinit(self: *Yaml) void {
        self.arena.deinit();
    }

    pub fn load(allocator: Allocator, source: []const u8) !Yaml {
        var arena = ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        var tree = Tree.init(arena.allocator());
        try tree.parse(source);

        var docs = std.ArrayList(Value).init(arena.allocator());
        try docs.ensureTotalCapacityPrecise(tree.docs.items.len);

        for (tree.docs.items) |node| {
            const value = try Value.fromNode(arena.allocator(), &tree, node);
            docs.appendAssumeCapacity(value);
        }

        return Yaml{
            .arena = arena,
            .tree = tree,
            .docs = docs,
        };
    }

    pub const Error = error{
        Unimplemented,
        TypeMismatch,
        StructFieldMissing,
        ArraySizeMismatch,
        UntaggedUnion,
        UnionTagMissing,
        Overflow,
        OutOfMemory,
    };

    pub fn parse(self: *Yaml, comptime T: type) Error!T {
        if (self.docs.items.len == 0) {
            if (@typeInfo(T) == .void) return {};
            return error.TypeMismatch;
        }

        if (self.docs.items.len == 1) {
            return self.parseValue(T, self.docs.items[0]);
        }

        switch (@typeInfo(T)) {
            .array => |info| {
                var parsed: T = undefined;
                for (self.docs.items, 0..) |doc, i| {
                    parsed[i] = try self.parseValue(info.child, doc);
                }
                return parsed;
            },
            .pointer => |info| {
                switch (info.size) {
                    .Slice => {
                        var parsed = try self.arena.allocator().alloc(info.child, self.docs.items.len);
                        for (self.docs.items, 0..) |doc, i| {
                            parsed[i] = try self.parseValue(info.child, doc);
                        }
                        return parsed;
                    },
                    else => return error.TypeMismatch,
                }
            },
            .@"union" => return error.Unimplemented,
            else => return error.TypeMismatch,
        }
    }

    fn parseValue(self: *Yaml, comptime T: type, value: Value) Error!T {
        return switch (@typeInfo(T)) {
            .int => math.cast(T, try value.asInt()) orelse return error.Overflow,
            .float => if (value.asFloat()) |float| {
                return math.lossyCast(T, float);
            } else |_| {
                return math.lossyCast(T, try value.asInt());
            },
            .@"struct" => self.parseStruct(T, try value.asMap()),
            .@"union" => self.parseUnion(T, value),
            .array => self.parseArray(T, try value.asList()),
            .pointer => if (value.asList()) |list| {
                return self.parsePointer(T, .{ .list = list });
            } else |_| {
                return self.parsePointer(T, .{ .string = try value.asString() });
            },
            .void => error.TypeMismatch,
            .optional => unreachable,
            else => error.Unimplemented,
        };
    }

    fn parseUnion(self: *Yaml, comptime T: type, value: Value) Error!T {
        const union_info = @typeInfo(T).@"union";

        if (union_info.tag_type) |_| {
            inline for (union_info.fields) |field| {
                if (self.parseValue(field.type, value)) |u_value| {
                    return @unionInit(T, field.name, u_value);
                } else |err| {
                    if (@as(@TypeOf(err) || error{TypeMismatch}, err) != error.TypeMismatch) return err;
                }
            }
        } else return error.UntaggedUnion;

        return error.UnionTagMissing;
    }

    fn parseOptional(self: *Yaml, comptime T: type, value: ?Value) Error!T {
        const unwrapped = value orelse return null;
        const opt_info = @typeInfo(T).optional;
        return @as(T, try self.parseValue(opt_info.child, unwrapped));
    }

    fn parseStruct(self: *Yaml, comptime T: type, map: Map) Error!T {
        const struct_info = @typeInfo(T).@"struct";
        var parsed: T = undefined;

        inline for (struct_info.fields) |field| {
            const value: ?Value = map.get(field.name) orelse blk: {
                const field_name = try mem.replaceOwned(u8, self.arena.allocator(), field.name, "_", "-");
                break :blk map.get(field_name);
            };

            if (@typeInfo(field.type) == .optional) {
                @field(parsed, field.name) = try self.parseOptional(field.type, value);
                continue;
            }

            const unwrapped = value orelse {
                log.debug("missing struct field: {s}: {s}", .{ field.name, @typeName(field.type) });
                return error.StructFieldMissing;
            };
            @field(parsed, field.name) = try self.parseValue(field.type, unwrapped);
        }

        return parsed;
    }

    fn parsePointer(self: *Yaml, comptime T: type, value: Value) Error!T {
        const ptr_info = @typeInfo(T).pointer;
        const arena = self.arena.allocator();

        switch (ptr_info.size) {
            .Slice => {
                if (ptr_info.child == u8) {
                    return value.asString();
                }

                var parsed = try arena.alloc(ptr_info.child, value.list.len);
                for (value.list, 0..) |elem, i| {
                    parsed[i] = try self.parseValue(ptr_info.child, elem);
                }
                return parsed;
            },
            else => return error.Unimplemented,
        }
    }

    fn parseArray(self: *Yaml, comptime T: type, list: List) Error!T {
        const array_info = @typeInfo(T).array;
        if (array_info.len != list.len) return error.ArraySizeMismatch;

        var parsed: T = undefined;
        for (list, 0..) |elem, i| {
            parsed[i] = try self.parseValue(array_info.child, elem);
        }

        return parsed;
    }

    pub fn stringify(self: Yaml, writer: anytype) !void {
        for (self.docs.items, 0..) |doc, i| {
            try writer.writeAll("---");
            if (self.tree.?.getDirective(i)) |directive| {
                try writer.print(" !{s}", .{directive});
            }
            try writer.writeByte('\n');
            try doc.stringify(writer, .{});
            try writer.writeByte('\n');
        }
        try writer.writeAll("...\n");
    }
};

pub fn stringify(allocator: Allocator, input: anytype, writer: anytype) !void {
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    const maybe_value = try Value.encode(arena.allocator(), input);

    if (maybe_value) |value| {
        // TODO should we output as an explicit doc?
        // How can allow the user to specify?
        try value.stringify(writer, .{});
    }
}

test {
    std.testing.refAllDecls(Tokenizer);
    std.testing.refAllDecls(parse);
    _ = @import("yaml/test.zig");
}
