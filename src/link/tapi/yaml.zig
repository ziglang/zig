const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const testing = std.testing;
const log = std.log.scoped(.tapi);

const Allocator = mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

pub const Tokenizer = @import("Tokenizer.zig");
pub const parse = @import("parse.zig");

const Node = parse.Node;
const Tree = parse.Tree;
const ParseError = parse.ParseError;

pub const YamlError = error{
    UnexpectedNodeType,
    OutOfMemory,
} || ParseError || std.fmt.ParseIntError;

pub const ValueType = enum {
    empty,
    int,
    float,
    string,
    list,
    map,
};

pub const List = []Value;
pub const Map = std.StringArrayHashMap(Value);

pub const Value = union(ValueType) {
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

    pub const StringifyError = std.os.WriteError;

    pub fn stringify(self: Value, writer: anytype, args: StringifyArgs) StringifyError!void {
        switch (self) {
            .empty => return,
            .int => |int| return writer.print("{}", .{int}),
            .float => |float| return writer.print("{d}", .{float}),
            .string => |string| return writer.print("{s}", .{string}),
            .list => |list| {
                const len = list.len;
                if (len == 0) return;

                const first = list[0];
                if (first.is_compound()) {
                    for (list) |elem, i| {
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
                for (list) |elem, i| {
                    try elem.stringify(writer, args);
                    if (i < len - 1) {
                        try writer.writeAll(", ");
                    }
                }
                try writer.writeAll(" ]");
            },
            .map => |map| {
                const keys = map.keys();
                const len = keys.len;
                if (len == 0) return;

                for (keys) |key, i| {
                    if (!args.should_inline_first_key or i != 0) {
                        try writer.writeByteNTimes(' ', args.indentation);
                    }
                    try writer.print("{s}: ", .{key});

                    const value = map.get(key) orelse unreachable;
                    const should_inline = blk: {
                        if (!value.is_compound()) break :blk true;
                        if (value == .list and value.list.len > 0 and !value.list[0].is_compound()) break :blk true;
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
                }
            },
        }
    }

    fn is_compound(self: Value) bool {
        return switch (self) {
            .list, .map => true,
            else => false,
        };
    }

    fn fromNode(arena: *Allocator, tree: *const Tree, node: *const Node, type_hint: ?ValueType) YamlError!Value {
        if (node.cast(Node.Doc)) |doc| {
            const inner = doc.value orelse {
                // empty doc
                return Value{ .empty = .{} };
            };
            return Value.fromNode(arena, tree, inner, null);
        } else if (node.cast(Node.Map)) |map| {
            var out_map = std.StringArrayHashMap(Value).init(arena);
            try out_map.ensureUnusedCapacity(map.values.items.len);

            for (map.values.items) |entry| {
                const key_tok = tree.tokens[entry.key];
                const key = try arena.dupe(u8, tree.source[key_tok.start..key_tok.end]);
                const value = try Value.fromNode(arena, tree, entry.value, null);

                out_map.putAssumeCapacityNoClobber(key, value);
            }

            return Value{ .map = out_map };
        } else if (node.cast(Node.List)) |list| {
            var out_list = std.ArrayList(Value).init(arena);
            try out_list.ensureUnusedCapacity(list.values.items.len);

            if (list.values.items.len > 0) {
                const hint = if (list.values.items[0].cast(Node.Value)) |value| hint: {
                    const start = tree.tokens[value.start.?];
                    const end = tree.tokens[value.end.?];
                    const raw = tree.source[start.start..end.end];
                    _ = std.fmt.parseInt(i64, raw, 10) catch {
                        _ = std.fmt.parseFloat(f64, raw) catch {
                            break :hint ValueType.string;
                        };
                        break :hint ValueType.float;
                    };
                    break :hint ValueType.int;
                } else null;

                for (list.values.items) |elem| {
                    const value = try Value.fromNode(arena, tree, elem, hint);
                    out_list.appendAssumeCapacity(value);
                }
            }

            return Value{ .list = out_list.toOwnedSlice() };
        } else if (node.cast(Node.Value)) |value| {
            const start = tree.tokens[value.start.?];
            const end = tree.tokens[value.end.?];
            const raw = tree.source[start.start..end.end];

            if (type_hint) |hint| {
                return switch (hint) {
                    .int => Value{ .int = try std.fmt.parseInt(i64, raw, 10) },
                    .float => Value{ .float = try std.fmt.parseFloat(f64, raw) },
                    .string => Value{ .string = try arena.dupe(u8, raw) },
                    else => unreachable,
                };
            }

            try_int: {
                // TODO infer base for int
                const int = std.fmt.parseInt(i64, raw, 10) catch break :try_int;
                return Value{ .int = int };
            }
            try_float: {
                const float = std.fmt.parseFloat(f64, raw) catch break :try_float;
                return Value{ .float = float };
            }
            return Value{ .string = try arena.dupe(u8, raw) };
        } else {
            log.err("Unexpected node type: {}", .{node.tag});
            return error.UnexpectedNodeType;
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

    pub fn stringify(self: Yaml, writer: anytype) !void {
        for (self.docs.items) |doc| {
            // if (doc.directive) |directive| {
            //     try writer.print("--- !{s}\n", .{directive});
            // }
            try doc.stringify(writer, .{});
            // if (doc.directive != null) {
            //     try writer.writeAll("...\n");
            // }
        }
    }

    pub fn load(allocator: *Allocator, source: []const u8) !Yaml {
        var arena = ArenaAllocator.init(allocator);

        var tree = Tree.init(&arena.allocator);
        try tree.parse(source);

        var docs = std.ArrayList(Value).init(&arena.allocator);
        try docs.ensureUnusedCapacity(tree.docs.items.len);

        for (tree.docs.items) |node| {
            const value = try Value.fromNode(&arena.allocator, &tree, node, null);
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
            if (@typeInfo(T) == .Void) return {};
            return error.TypeMismatch;
        }

        if (self.docs.items.len == 1) {
            return self.parseValue(T, self.docs.items[0]);
        }

        switch (@typeInfo(T)) {
            .Array => |info| {
                var parsed: T = undefined;
                for (self.docs.items) |doc, i| {
                    parsed[i] = try self.parseValue(info.child, doc);
                }
                return parsed;
            },
            .Pointer => |info| {
                switch (info.size) {
                    .Slice => {
                        var parsed = try self.arena.allocator.alloc(info.child, self.docs.items.len);
                        for (self.docs.items) |doc, i| {
                            parsed[i] = try self.parseValue(info.child, doc);
                        }
                        return parsed;
                    },
                    else => return error.TypeMismatch,
                }
            },
            .Union => return error.Unimplemented,
            else => return error.TypeMismatch,
        }
    }

    fn parseValue(self: *Yaml, comptime T: type, value: Value) Error!T {
        return switch (@typeInfo(T)) {
            .Int => math.cast(T, try value.asInt()),
            .Float => math.lossyCast(T, try value.asFloat()),
            .Struct => self.parseStruct(T, try value.asMap()),
            .Union => self.parseUnion(T, value),
            .Array => self.parseArray(T, try value.asList()),
            .Pointer => {
                if (value.asList()) |list| {
                    return self.parsePointer(T, .{ .list = list });
                } else |_| {
                    return self.parsePointer(T, .{ .string = try value.asString() });
                }
            },
            .Void => error.TypeMismatch,
            .Optional => unreachable,
            else => error.Unimplemented,
        };
    }

    fn parseUnion(self: *Yaml, comptime T: type, value: Value) Error!T {
        const union_info = @typeInfo(T).Union;

        if (union_info.tag_type) |_| {
            inline for (union_info.fields) |field| {
                if (self.parseValue(field.field_type, value)) |u_value| {
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
        const opt_info = @typeInfo(T).Optional;
        return @as(T, try self.parseValue(opt_info.child, unwrapped));
    }

    fn parseStruct(self: *Yaml, comptime T: type, map: Map) Error!T {
        const struct_info = @typeInfo(T).Struct;
        var parsed: T = undefined;

        inline for (struct_info.fields) |field| {
            const value: ?Value = map.get(field.name) orelse blk: {
                const field_name = try mem.replaceOwned(u8, &self.arena.allocator, field.name, "_", "-");
                break :blk map.get(field_name);
            };

            if (@typeInfo(field.field_type) == .Optional) {
                @field(parsed, field.name) = try self.parseOptional(field.field_type, value);
                continue;
            }

            const unwrapped = value orelse {
                log.err("missing struct field: {s}: {s}", .{ field.name, @typeName(field.field_type) });
                return error.StructFieldMissing;
            };
            @field(parsed, field.name) = try self.parseValue(field.field_type, unwrapped);
        }

        return parsed;
    }

    fn parsePointer(self: *Yaml, comptime T: type, value: Value) Error!T {
        const ptr_info = @typeInfo(T).Pointer;
        const arena = &self.arena.allocator;

        switch (ptr_info.size) {
            .Slice => {
                const child_info = @typeInfo(ptr_info.child);
                if (child_info == .Int and child_info.Int.bits == 8) {
                    return value.asString();
                }

                var parsed = try arena.alloc(ptr_info.child, value.list.len);
                for (value.list) |elem, i| {
                    parsed[i] = try self.parseValue(ptr_info.child, elem);
                }
                return parsed;
            },
            else => return error.Unimplemented,
        }
    }

    fn parseArray(self: *Yaml, comptime T: type, list: List) Error!T {
        const array_info = @typeInfo(T).Array;
        if (array_info.len != list.len) return error.ArraySizeMismatch;

        var parsed: T = undefined;
        for (list) |elem, i| {
            parsed[i] = try self.parseValue(array_info.child, elem);
        }

        return parsed;
    }
};

test {
    testing.refAllDecls(@This());
}

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expect(mem.eql(u8, list[0].string, "a"));
    try testing.expect(mem.eql(u8, list[1].string, "b"));
    try testing.expect(mem.eql(u8, list[2].string, "c"));
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3][]const u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expect(mem.eql(u8, arr[0], "a"));
    try testing.expect(mem.eql(u8, arr[1], "b"));
    try testing.expect(mem.eql(u8, arr[2], "c"));
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3]u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqual(arr[0], 0);
    try testing.expectEqual(arr[1], 1);
    try testing.expectEqual(arr[2], 2);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const arr = try yaml.parse([3]i8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqual(arr[0], 0);
    try testing.expectEqual(arr[1], -1);
    try testing.expectEqual(arr[2], 2);
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqual(map.get("a").?.int, 0);
}

test "simple map typed" {
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct { a: usize, b: []const u8, c: []const u8 });
    try testing.expectEqual(simple.a, 0);
    try testing.expect(mem.eql(u8, simple.b, "hello there"));
    try testing.expect(mem.eql(u8, simple.c, "wait, what?"));
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const simple = try yaml.parse(struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    try testing.expect(mem.eql(u8, simple.a.b, "hello there"));
    try testing.expect(mem.eql(u8, simple.a.c, "wait, what?"));
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    {
        const result = try yaml.parse([2]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }

    {
        const result = try yaml.parse([]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    const result = try yaml.parse([]struct { a: usize, b: ?[]const u8, c: ?f16 });
    try testing.expectEqual(result.len, 2);

    try testing.expectEqual(result[0].a, 0);
    try testing.expect(result[0].b == null);
    try testing.expect(result[0].c != null);
    try testing.expectEqual(result[0].c.?, 1.0);

    try testing.expectEqual(result[1].a, 1);
    try testing.expect(result[1].b != null);
    try testing.expect(mem.eql(u8, result[1].b.?, "different field"));
    try testing.expect(result[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";
    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();
    const result = try yaml.parse(void);
    try testing.expect(@TypeOf(result) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;

    var yaml = try Yaml.load(testing.allocator, source);
    defer yaml.deinit();

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse([1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse([5]usize));
}
