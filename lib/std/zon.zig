const std = @import("std");
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;
const NodeIndex = std.zig.Ast.Node.Index;
const TokenIndex = std.zig.Ast.TokenIndex;
const Type = std.builtin.Type;
const Base = std.zig.number_literal.Base;
const FloatBase = std.zig.number_literal.FloatBase;
const StringLiteralError = std.zig.string_literal.Error;
const NumberLiteralError = std.zig.number_literal.Error;
const assert = std.debug.assert;

const Parser = @This();

gpa: Allocator,
ast: *const Ast,
status: ?*Status,
options: ParseOptions,

pub const ParseOptions = struct {
    ignore_unknown_fields: bool = false,
    // TODO: support max_value_len too?
};

const Error = error{ OutOfMemory, Type };

// TODO: make a render errors function...handle underlines as well as point of error like zig? How?
pub const Status = union(enum) {
    success: void,
    expected_type: struct {
        name: []const u8,
        node: NodeIndex,
    },
    cannot_represent: struct {
        name: []const u8,
        node: NodeIndex,
    },
    invalid_string_literal: struct {
        node: NodeIndex,
        reason: StringLiteralError,
    },
    invalid_number_literal: struct {
        node: NodeIndex,
        reason: NumberLiteralError,
    },
    unknown_field: struct {
        node: NodeIndex,
        type_name: []const u8,
        field_name: []const u8,
    },
    missing_field: struct {
        node: NodeIndex,
        type_name: []const u8,
        field_name: []const u8,
    },
    duplicate_field: struct {
        node: NodeIndex,
        field_name: []const u8,
    },
    unsupported_builtin: struct {
        node: NodeIndex,
        name: []const u8,
    },
    bad_arg_count: struct {
        node: NodeIndex,
        expected: u8,
    },
    type_expr: struct {
        node: NodeIndex,
    },
};

pub fn parseFromSlice(comptime T: type, gpa: Allocator, source: [:0]const u8, options: ParseOptions) error{ OutOfMemory, Type, Syntax }!T {
    var ast = try std.zig.Ast.parse(gpa, source, .zon);
    defer ast.deinit(gpa);
    if (ast.errors.len != 0) return error.Syntax;
    return parseFromAst(T, gpa, &ast, null, options);
}

test "parseFromSlice syntax error" {
    try std.testing.expectError(error.Syntax, parseFromSlice(u8, std.testing.allocator, ".{", .{}));
}

pub fn parseFromAst(comptime T: type, gpa: Allocator, ast: *const Ast, err: ?*Status, options: ParseOptions) Error!T {
    const data = ast.nodes.items(.data);
    // TODO: why lhs here?
    const root = data[0].lhs;
    return parseFromAstNode(T, gpa, ast, root, err, options);
}

pub fn parseFromAstNoAlloc(comptime T: type, ast: *const Ast, err: ?*Status, options: ParseOptions) error { Type }!T {
    const data = ast.nodes.items(.data);
    // TODO: why lhs here?
    const root = data[0].lhs;
    return parseFromAstNodeNoAlloc(T, ast, root, err, options);
}

test "parseFromAstNoAlloc" {
    var ast = try std.zig.Ast.parse(std.testing.allocator, ".{ .x = 1.5, .y = 2.5 }", .zon);
    defer ast.deinit(std.testing.allocator);
    try std.testing.expectEqual(ast.errors.len, 0);

    const S = struct { x: f32, y: f32 };
    const found = try parseFromAstNoAlloc(S, &ast, null, .{});
    try std.testing.expectEqual(S{ .x = 1.5, .y = 2.5}, found);
}

pub fn parseFromAstNode(comptime T: type, gpa: Allocator, ast: *const Ast, node: NodeIndex, err: ?*Status, options: ParseOptions) Error!T {
    var parser = Parser{
        .gpa = gpa,
        .ast = ast,
        .status = err,
        .options = options,
    };
    return parser.parseExpr(T, node);
}

pub fn parseFromAstNodeNoAlloc(comptime T: type, ast: *const Ast, node: NodeIndex, err: ?*Status, options: ParseOptions) error { Type }!T {
    if (comptime requiresAllocator(T)) {
        @compileError(@typeName(T) ++ ": requires allocator");
    }
    var buffer: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    return parseFromAstNode(T, fba.allocator(), ast, node, err, options) catch |e| switch (e) {
        error.OutOfMemory => unreachable,
        else => |other| return other,
    };
}

test "parseFromAstNode and parseFromAstNodeNoAlloc" {
    const gpa = std.testing.allocator;

    var ast = try std.zig.Ast.parse(gpa, ".{ .vec = .{ .x = 1.5, .y = 2.5 } }", .zon);
    defer ast.deinit(gpa);
    try std.testing.expect(ast.errors.len == 0);

    const data = ast.nodes.items(.data);
    const root = data[0].lhs;
    var buf: [2]NodeIndex = undefined;
    const init = ast.fullStructInit(&buf, root).?;

    const Vec2 = struct { x: f32, y: f32 };
    const parsed = try parseFromAstNode(Vec2, gpa, &ast, init.ast.fields[0], null, .{});
    const parsed_no_alloc = try parseFromAstNodeNoAlloc(Vec2, &ast, init.ast.fields[0], null, .{});
    try std.testing.expectEqual(Vec2 { .x = 1.5, .y = 2.5 }, parsed);
    try std.testing.expectEqual(Vec2 { .x = 1.5, .y = 2.5 }, parsed_no_alloc    );
}

fn requiresAllocator(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Pointer => true,
        .Array => |Array| requiresAllocator(Array.child),
        .Struct => |Struct| inline for (Struct.fields) |field| {
            if (requiresAllocator(field.type)) {
                break true;
            }
        } else false,
        .Union => |Union| inline for (Union.fields) |field| {
            if (requiresAllocator(field.type)) {
                break true;
            }
        } else false,
        .Optional => |Optional| requiresAllocator(Optional.child),
        else => false,
    };
}

test "requiresAllocator" {
    try std.testing.expect(!requiresAllocator(u8));
    try std.testing.expect(!requiresAllocator(f32));
    try std.testing.expect(!requiresAllocator(enum { foo }));
    try std.testing.expect(!requiresAllocator(@TypeOf(.foo)));
    try std.testing.expect(!requiresAllocator(struct { f32 }));
    try std.testing.expect(!requiresAllocator(struct { x: f32 }));
    try std.testing.expect(!requiresAllocator([2]u8));
    try std.testing.expect(!requiresAllocator(union { x: f32, y: f32 }));
    try std.testing.expect(!requiresAllocator(union(enum) { x: f32, y: f32 }));
    try std.testing.expect(!requiresAllocator(?f32));
    try std.testing.expect(!requiresAllocator(void));
    try std.testing.expect(!requiresAllocator(@TypeOf(null)));

    try std.testing.expect(requiresAllocator([]u8));
    try std.testing.expect(requiresAllocator(*struct{ u8, u8 }));
    try std.testing.expect(requiresAllocator([1][]const u8));
    try std.testing.expect(requiresAllocator(struct { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(union { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(union(enum) { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(?[]u8));
}

test "error literals" {
    // TODO: can't return error!error, i think, so we need to use an out param, or not support this...
    // const gpa = std.testing.allocator;
    // const parsed = try parseFromSlice(anyerror, gpa, "error.Foo");
    // try std.testing.expectEqual(error.Foo, parsed);
}


pub fn parseFree(gpa: Allocator, value: anytype) void {
    const Value = @TypeOf(value);

    switch (@typeInfo(Value)) {
        .Bool, .Int, .Float, .Enum => {},
        .Pointer => |Pointer| {
            switch (Pointer.size) {
                .One, .Many, .C => @compileError(@typeName(Value) ++ ": parseFree cannot free non slice pointers"),
                .Slice => for (value) |item| {
                    parseFree(gpa, item);
                },
            }
            return gpa.free(value);
        },
        .Array => for (value) |item| {
            parseFree(gpa, item);
        },
        .Struct => |Struct| inline for (Struct.fields) |field| {
            parseFree(gpa, @field(value, field.name));
        },
        .Union => |Union| if (Union.tag_type == null) {
            @compileError(@typeName(Value) ++ ": parseFree cannot free untagged unions");
        } else switch (value) {
            inline else => |_, tag| {
                parseFree(gpa, @field(value, @tagName(tag)));
            },
        },
        .Optional => if (value) |some| {
            parseFree(gpa, some);
        },
        .Void => {},
        .Null => {},
        else => @compileError(@typeName(Value) ++ ": parseFree cannot free this type"),
    }
}

fn parseExpr(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    // TODO: keep in sync with parseFree, stringify, and requiresAllocator
    switch (@typeInfo(T)) {
        // TODO: better errors for this?
        .Bool => return self.parseBool(node),
        .Int, .Float => return self.parseNumber(T, node),
        .Enum => return self.parseEnumLiteral(T, node),
        // TODO: combined for now for strings...
        .Pointer => return self.parsePointer(T, node),
        .Array => return self.parseArray(T, node),
        .Struct => |Struct| if (Struct.is_tuple)
            return self.parseTuple(T, node)
        else
            return self.parseStruct(T, node),
        .Union => return self.parseUnion(T, node),
        .Optional => return self.parseOptional(T, node),
        .Void => return self.parseVoid(node),
        .Null => return self.parseNull(node),

        else => @compileError(@typeName(T) ++ ": cannot parse this type"),
    }
}

fn parseVoid(self: *Parser, node: NodeIndex) Error!void {
    const tags = self.ast.nodes.items(.tag);
    const data = self.ast.nodes.items(.data);
    switch (tags[node]) {
        .block_two => if (data[node].lhs != 0 or data[node].rhs != 0) {
            return self.failExpectedType(void, node);
        },
        .block => if (data[node].lhs != data[node].rhs) {
            return self.failExpectedType(void, node);
        },
        else => return self.failExpectedType(void, node),
    }
}

test "void" {
    const gpa = std.testing.allocator;

    const parsed: void = try parseFromSlice(void, gpa, "{}", .{});
    _ = parsed;

    // Freeing void is a noop, but it should compile!
    const free: void = try parseFromSlice(void, gpa, "{}", .{});
    defer parseFree(gpa, free);

    // Other type
    {
        var ast = try std.zig.Ast.parse(gpa, "123", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(void, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(void), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }

    // Brackets around values
    {
        var ast = try std.zig.Ast.parse(gpa, "{1}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(void, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(void), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }
}

// fn parseNull(self: *Parser, node: NodeIndex) error{Type}!void {
//     const tags = self.ast.nodes.items(.tag);
//     const main_tokens = self.ast.nodes.items(.main_token);
//     const token = main_tokens[node];
//     switch (tags[node]) {
//         .identifier => {
//             const bytes = self.ast.tokenSlice(token);
//             if (std.mem.eql(u8, bytes, "null")) {
//                 return true;
//             }
//         },
//         else => {},
//     }
//     return self.failExpectedType(void, node);
// }

// TODO: see https://github.com/MasonRemaley/WIP-ZON/issues/3
// test "null" {
//     const gpa = std.testing.allocator;

//     const Null = @TypeOf(null);
//     const parsed: @TypeOf(null) = try parseFromSlice(Null, gpa, "null", .{});
//     _ = parsed;

//     // Freeing null is a noop, but it should compile!
//     const free: @TypeOf(null) = try parseFromSlice(void, gpa, "null", .{});
//     defer parseFree(gpa, free);

//     // Other type
//     {
//         var ast = try std.zig.Ast.parse(gpa, "123", .zon);
//         defer ast.deinit(gpa);
//         var status: Status = .success;
//         try std.testing.expectError(error.Type, parseFromAst(@TypeOf(null), gpa, &ast, &status, .{}));
//         try std.testing.expectEqualStrings(@typeName(@TypeOf(null)), status.expected_type.name);
//         const node = status.expected_type.node;
//         const main_tokens = ast.nodes.items(.main_token);
//         const token = main_tokens[node];
//         const location = ast.tokenLocation(0, token);
//         try std.testing.expectEqual(Ast.Location{
//             .line = 0,
//             .column = 0,
//             .line_start = 0,
//             .line_end = 3,
//         }, location);
//     }
// }

fn parseOptional(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    const Optional = @typeInfo(T).Optional;

    const tags = self.ast.nodes.items(.tag);
    if (tags[node] == .identifier) {
        const main_tokens = self.ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const bytes = self.ast.tokenSlice(token);
        if (std.mem.eql(u8, bytes, "null")) {
            return null;
        }
    }

    return try self.parseExpr(Optional.child, node);
}

test "optional" {
    const gpa = std.testing.allocator;

    // Basic usage
    {
        const none = try parseFromSlice(?u32, gpa, "null", .{});
        try std.testing.expect(none == null);
        const some = try parseFromSlice(?u32, gpa, "1", .{});
        try std.testing.expect(some.? == 1);
    }

    // Deep free
    {
        const none = try parseFromSlice(?[]const u8, gpa, "null", .{});
        try std.testing.expect(none == null);
        const some = try parseFromSlice(?[]const u8, gpa, "\"foo\"", .{});
        defer parseFree(gpa, some);
        try std.testing.expectEqualStrings("foo", some.?);
    }
}

fn parseUnion(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    // TODO: some of the array errors point to the brace instead of 0?
    const Union = @typeInfo(T).Union;
    const field_infos = Union.fields;

    if (field_infos.len == 0) {
        @compileError(@typeName(T) ++ ": cannot parse unions with no fields");
    }

    // Gather info on the fields
    const field_indices = b: {
        comptime var kvs_list: [field_infos.len]struct { []const u8, usize } = undefined;
        inline for (field_infos, 0..) |field, i| {
            kvs_list[i] = .{ field.name, i };
        }
        break :b std.ComptimeStringMap(usize, kvs_list);
    };

    // Parse the union
    const main_tokens = self.ast.nodes.items(.main_token);
    const tags = self.ast.nodes.items(.tag);
    if (tags[node] == .enum_literal) {
        // The union must be tagged for an enum literal to coerce to it
        if (Union.tag_type == null) {
            return self.failExpectedType(T, node);
        }

        // Get the index of the named field. We don't use `parseEnum` here as
        // the order of the enum and the order of the union might not match!
        const bytes = self.parseIdentifier(main_tokens[node]);
        const field_index = field_indices.get(bytes) orelse
            return self.failUnknownField(T, node, bytes);

        // Initialize the union from the given field.
        switch (field_index) {
            inline 0...field_infos.len - 1 => |i| {
                // Fail if the field is not void
                if (field_infos[i].type != void)
                    return self.failExpectedType(T, node);

                // Instantiate the union
                return @unionInit(T, field_infos[i].name, {});
            },
            else => unreachable,
        }
    } else {
        var buf: [2]NodeIndex = undefined;
        const field_nodes = try self.elementsOrFields(T, &buf, node);

        if (field_nodes.len != 1) {
            return self.failExpectedType(T, node);
        }

        // Fill in the field we found
        const field_node = field_nodes[0];
        const name = self.parseIdentifier(self.ast.firstToken(field_node) - 2);
        const field_index = field_indices.get(name) orelse
            return self.failUnknownField(T, field_node, name);

        switch (field_index) {
            inline 0...field_infos.len - 1 => |i| {
                const value = try self.parseExpr(field_infos[i].type, field_node);
                return @unionInit(T, field_infos[i].name, value);
            },
            else => unreachable,
        }
    }
}

test "unions" {
    const gpa = std.testing.allocator;

    // Unions
    {
        const Tagged = union(enum) { x: f32, @"y y": bool, z, @"z z" };
        const Untagged = union { x: f32, @"y y": bool, z: void, @"z z": void };

        const tagged_x = try parseFromSlice(Tagged, gpa, ".{.x = 1.5}", .{});
        try std.testing.expectEqual(Tagged{ .x = 1.5 }, tagged_x);
        const tagged_y = try parseFromSlice(Tagged, gpa, ".{.@\"y y\" = true}", .{});
        try std.testing.expectEqual(Tagged{ .@"y y" = true }, tagged_y);
        const tagged_z_shorthand = try parseFromSlice(Tagged, gpa, ".z", .{});
        try std.testing.expectEqual(@as(Tagged, .z), tagged_z_shorthand);
        const tagged_zz_shorthand = try parseFromSlice(Tagged, gpa, ".@\"z z\"", .{});
        try std.testing.expectEqual(@as(Tagged, .@"z z"), tagged_zz_shorthand);
        const tagged_z_explicit = try parseFromSlice(Tagged, gpa, ".{.z = {}}", .{});
        try std.testing.expectEqual(Tagged{ .z = {} }, tagged_z_explicit);
        const tagged_zz_explicit = try parseFromSlice(Tagged, gpa, ".{.@\"z z\" = {}}", .{});
        try std.testing.expectEqual(Tagged{ .@"z z" = {} }, tagged_zz_explicit);

        const untagged_x = try parseFromSlice(Untagged, gpa, ".{.x = 1.5}", .{});
        try std.testing.expect(untagged_x.x == 1.5);
        const untagged_y = try parseFromSlice(Untagged, gpa, ".{.@\"y y\" = true}", .{});
        try std.testing.expect(untagged_y.@"y y");
    }

    // Deep free
    {
        const Union = union(enum) { bar: []const u8, baz: bool };

        const noalloc = try parseFromSlice(Union, gpa, ".{.baz = false}", .{});
        try std.testing.expectEqual(Union{ .baz = false }, noalloc);

        const alloc = try parseFromSlice(Union, gpa, ".{.bar = \"qux\"}", .{});
        defer parseFree(gpa, alloc);
        try std.testing.expectEqualDeep(Union{ .bar = "qux" }, alloc);
    }

    // Unknown field
    {
        const Union = union { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.z=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.unknown_field.type_name);
        try std.testing.expectEqualStrings("z", status.unknown_field.field_name);
        const node = status.unknown_field.node;
        const token = ast.firstToken(node) - 2;
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 3,
            .line_start = 0,
            .line_end = 9,
        }, location);
    }

    // Extra field
    {
        const Union = union { x: f32, y: bool };
        var ast = try std.zig.Ast.parse(gpa, ".{.x = 1.5, .y = true}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 22,
        }, location);
    }

    // No fields
    {
        const Union = union { x: f32, y: bool };
        var ast = try std.zig.Ast.parse(gpa, ".{}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }

    // Enum literals cannot coerce into untagged unions
    {
        const Union = union { x: void };
        var ast = try std.zig.Ast.parse(gpa, ".x", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 2,
        }, location);
    }

    // Unknown field for enum literal coercion
    {
        const Union = union(enum) { x: void };
        var ast = try std.zig.Ast.parse(gpa, ".y", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.unknown_field.type_name);
        try std.testing.expectEqualStrings("y", status.unknown_field.field_name);
        const node = status.unknown_field.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why 1?
            .column = 1,
            .line_start = 0,
            .line_end = 2,
        }, location);
    }

    // Non void field for enum literal coercion
    {
        const Union = union(enum) { x: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".x", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Union), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 2,
        }, location);
    }

    // Union field with @
    {
        const U = union(enum) { x: void };
        const tag = try parseFromSlice(U, gpa, ".@\"x\"", .{});
        try std.testing.expectEqual(@as(U, .x), tag);
        const initializer = try parseFromSlice(U, gpa, ".{.@\"x\" = {}}", .{});
        try std.testing.expectEqual(U{ .x = {} }, initializer);
    }
}

// TODO: modify the parser instead of using this workaround? (is necessary because arrays of size
// 0 are treated as structs)
// TODO: doesn't make error handling weird right?
fn elementsOrFields(
    self: *Parser,
    comptime T: type,
    buf: *[2]NodeIndex,
    node: NodeIndex,
) error{Type}![]const NodeIndex {
    if (self.ast.fullStructInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(init.ast.type_expr);
        }
        return init.ast.fields;
    } else if (self.ast.fullArrayInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(init.ast.type_expr);
        }
        return init.ast.elements;
    } else {
        return self.failExpectedType(T, node);
    }
}

// TODO: can bench with and without comptime string map later?
fn parseStruct(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    // TODO: some of the array errors point to the brace instead of 0?
    const Struct = @typeInfo(T).Struct;
    const field_infos = Struct.fields;

    var result: T = undefined;

    // Gather info on the fields
    const field_indices = b: {
        comptime var kvs_list: [field_infos.len]struct { []const u8, usize } = undefined;
        inline for (field_infos, 0..) |field, i| {
            kvs_list[i] = .{ field.name, i };
        }
        break :b std.ComptimeStringMap(usize, kvs_list);
    };

    // Parse the struct
    var buf: [2]NodeIndex = undefined;
    const field_nodes = try self.elementsOrFields(T, &buf, node);

    // Fill in the fields we found
    var field_found: [field_infos.len]bool = .{false} ** field_infos.len;
    for (field_nodes) |field_node| {
        // TODO: is this the correct way to get the field name? (used in a few places)
        const name = self.parseIdentifier(self.ast.firstToken(field_node) - 2);
        const i = field_indices.get(name) orelse if (self.options.ignore_unknown_fields) {
            continue;
        } else {
            return self.failUnknownField(T, field_node, name);
        };

        // We now know the array is not zero sized (assert this so the code compiles)
        if (field_found.len == 0) unreachable;

        if (field_found[i]) {
            return self.failDuplicateField(name, field_node);
        }
        field_found[i] = true;

        switch (i) {
            inline 0...(field_infos.len - 1) => |j| @field(result, field_infos[j].name) = try self.parseExpr(field_infos[j].type, field_node),
            else => unreachable,
        }
    }

    // Fill in any missing default fields
    inline for (field_found, 0..) |found, i| {
        if (!found) {
            const field_info = Struct.fields[i];
            if (field_info.default_value) |default| {
                const typed: *const field_info.type = @ptrCast(@alignCast(default));
                @field(result, field_info.name) = typed.*;
            } else {
                return self.failMissingField(T, field_infos[i].name, node);
            }
        }
    }

    return result;
}

// TODO: should we be naming tests prefixed with zon?
test "structs" {
    const gpa = std.testing.allocator;

    // Structs (various sizes tested since they're parsed differently)
    {
        const Vec0 = struct {};
        const Vec1 = struct { x: f32 };
        const Vec2 = struct { x: f32, y: f32 };
        const Vec3 = struct { x: f32, y: f32, z: f32 };

        const zero = try parseFromSlice(Vec0, gpa, ".{}", .{});
        try std.testing.expectEqual(Vec0{}, zero);

        const one = try parseFromSlice(Vec1, gpa, ".{.x = 1.2}", .{});
        try std.testing.expectEqual(Vec1{ .x = 1.2 }, one);

        const two = try parseFromSlice(Vec2, gpa, ".{.x = 1.2, .y = 3.4}", .{});
        try std.testing.expectEqual(Vec2{ .x = 1.2, .y = 3.4 }, two);

        const three = try parseFromSlice(Vec3, gpa, ".{.x = 1.2, .y = 3.4, .z = 5.6}", .{});
        try std.testing.expectEqual(Vec3{ .x = 1.2, .y = 3.4, .z = 5.6 }, three);
    }

    // Deep free (structs and arrays)
    {
        const Foo = struct { bar: []const u8, baz: []const []const u8 };

        const parsed = try parseFromSlice(Foo, gpa, ".{.bar = \"qux\", .baz = &.{\"a\", \"b\"}}", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualDeep(Foo{ .bar = "qux", .baz = &.{ "a", "b" } }, parsed);
    }

    // Unknown field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .z=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Vec2), status.unknown_field.type_name);
        try std.testing.expectEqualStrings("z", status.unknown_field.field_name);
        const node = status.unknown_field.node;
        const token = ast.firstToken(node) - 2;
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 11,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Duplicate field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .x=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings("x", status.duplicate_field.field_name);
        const node = status.duplicate_field.node;
        const token = ast.firstToken(node) - 2;
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 11,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Ignore unknown fields
    {
        const Vec2 = struct { x: f32, y: f32 = 2.0 };
        const parsed = try parseFromSlice(Vec2, gpa, ".{ .x = 1.0, .z = 3.0 }", .{ .ignore_unknown_fields = true });
        try std.testing.expectEqual(Vec2{ .x = 1.0, .y = 2.0 }, parsed);
    }

    // Unknown field when struct has no fields (regression test)
    {
        const Vec2 = struct {};
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .z=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Vec2), status.unknown_field.type_name);
        try std.testing.expectEqualStrings("x", status.unknown_field.field_name);
        const node = status.unknown_field.node;
        const token = ast.firstToken(node) - 2;
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 3,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Missing field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Vec2), status.missing_field.type_name);
        try std.testing.expectEqualStrings("y", status.missing_field.field_name);
        const node = status.missing_field.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why not zero?
            .column = 1,
            .line_start = 0,
            .line_end = 9,
        }, location);
    }

    // Default field
    {
        const Vec2 = struct { x: f32, y: f32 = 1.5 };
        const parsed = try parseFromSlice(Vec2, gpa, ".{.x = 1.2}", .{});
        try std.testing.expectEqual(Vec2{ .x = 1.2, .y = 1.5 }, parsed);
    }

    // Enum field (regression test, we were previously getting the field name in an
    // incorrect way that broke for enum values)
    {
        const Vec0 = struct { x: enum { x } };
        const parsed = try parseFromSlice(Vec0, gpa, ".{ .x = .x }", .{});
        try std.testing.expectEqual(Vec0{ .x = .x }, parsed);
    }

    // Enum field and struct field with @
    {
        const Vec0 = struct { @"x x": enum { @"x x" } };
        const parsed = try parseFromSlice(Vec0, gpa, ".{ .@\"x x\" = .@\"x x\" }", .{});
        try std.testing.expectEqual(Vec0{ .@"x x" = .@"x x" }, parsed);
    }

    // Type expressions are not allowed
    {
        // Structs
        {
            const Empty = struct {};

            var ast = try std.zig.Ast.parse(gpa, "Empty{}", .zon);
            defer ast.deinit(gpa);

            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst(Empty, gpa, &ast, &status, .{}));
            const node = status.type_expr.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 7,
            }, location);
        }

        // Arrays
        {
            var ast = try std.zig.Ast.parse(gpa, "[3]u8{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
            const node = status.type_expr.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 14,
            }, location);
        }

        // Slices
        {
            var ast = try std.zig.Ast.parse(gpa, "&[3]u8{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            const node = status.type_expr.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 1,
                .line_start = 0,
                .line_end = 15,
            }, location);
        }

        // Tuples
        {
            const Tuple = struct { i32, i32, i32 };
            var ast = try std.zig.Ast.parse(gpa, "Tuple{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
            const node = status.type_expr.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 14,
            }, location);
        }

        // Functions
        {
            var ast = try std.zig.Ast.parse(gpa, "fn foo() {}", .zon);
            defer ast.deinit(gpa);

            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst(struct {}, gpa, &ast, &status, .{}));
            const node = status.type_expr.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 11,
            }, location);
        }
    }
}

fn parseTuple(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    const Struct = @typeInfo(T).Struct;
    const field_infos = Struct.fields;

    var result: T = undefined;

    // Parse the struct
    var buf: [2]NodeIndex = undefined;
    const field_nodes = try self.elementsOrFields(T, &buf, node);

    if (field_nodes.len != field_infos.len) {
        // TODO: is this similar to the error zig gives?
        return self.failExpectedType(T, node);
    }

    inline for (field_infos, field_nodes, 0..) |field_info, field_node, i| {
        result[i] = try self.parseExpr(field_info.type, field_node);
    }

    return result;
}

test "tuples" {
    const gpa = std.testing.allocator;

    // Structs (various sizes tested since they're parsed differently)
    {
        const Tuple0 = struct {};
        const Tuple1 = struct { f32 };
        const Tuple2 = struct { f32, bool };
        const Tuple3 = struct { f32, bool, u8 };

        const zero = try parseFromSlice(Tuple0, gpa, ".{}", .{});
        try std.testing.expectEqual(Tuple0{}, zero);

        const one = try parseFromSlice(Tuple1, gpa, ".{1.2}", .{});
        try std.testing.expectEqual(Tuple1{1.2}, one);

        const two = try parseFromSlice(Tuple2, gpa, ".{1.2, true}", .{});
        try std.testing.expectEqual(Tuple2{ 1.2, true }, two);

        const three = try parseFromSlice(Tuple3, gpa, ".{1.2, false, 3}", .{});
        try std.testing.expectEqual(Tuple3{ 1.2, false, 3 }, three);
    }

    // Deep free
    {
        const Tuple = struct { []const u8, []const u8 };
        const parsed = try parseFromSlice(Tuple, gpa, ".{\"hello\", \"world\"}", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualDeep(Tuple{ "hello", "world" }, parsed);
    }

    // Extra field
    {
        const Tuple = struct { f32, bool };
        var ast = try std.zig.Ast.parse(gpa, ".{0.5, true, 123}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Tuple), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Extra field
    {
        const Tuple = struct { f32, bool };
        var ast = try std.zig.Ast.parse(gpa, ".{0.5}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Tuple), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            // TODO: why column 1?
            .column = 1,
            .line_start = 0,
            .line_end = 6,
        }, location);
    }
}

fn parseArray(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    const Array = @typeInfo(T).Array;
    // TODO: passing in a buffer is a reasonable pattern for this kinda thing, could use elsewhere?
    // TODO: why .ast?
    // Parse the array
    var array: T = undefined;
    var buf: [2]NodeIndex = undefined;
    const element_nodes = try self.elementsOrFields(T, &buf, node);

    // Check if the size matches
    if (element_nodes.len != Array.len) {
        return self.failExpectedType(T, node);
    }

    // Parse the elements and return the array
    for (&array, element_nodes) |*element, element_node| {
        element.* = try self.parseExpr(Array.child, element_node);
    }
    return array;
}

// Test sizes 0 to 3 since small sizes get parsed differently
test "arrays and slices" {
    const gpa = std.testing.allocator;

    // Literals
    {
        // Arrays
        {
            const zero = try parseFromSlice([0]u8, gpa, ".{}", .{});
            try std.testing.expectEqualSlices(u8, &@as([0]u8, .{}), &zero);

            const one = try parseFromSlice([1]u8, gpa, ".{'a'}", .{});
            try std.testing.expectEqualSlices(u8, &@as([1]u8, .{'a'}), &one);

            const two = try parseFromSlice([2]u8, gpa, ".{'a', 'b'}", .{});
            try std.testing.expectEqualSlices(u8, &@as([2]u8, .{ 'a', 'b' }), &two);

            const two_comma = try parseFromSlice([2]u8, gpa, ".{'a', 'b',}", .{});
            try std.testing.expectEqualSlices(u8, &@as([2]u8, .{ 'a', 'b' }), &two_comma);

            const three = try parseFromSlice([3]u8, gpa, ".{'a', 'b', 'c'}", .{});
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, &three);

            const sentinel = try parseFromSlice([3:'z']u8, gpa, ".{'a', 'b', 'c'}", .{});
            const expected_sentinel: [3:'z']u8 = .{ 'a', 'b', 'c' };
            try std.testing.expectEqualSlices(u8, &expected_sentinel, &sentinel);
        }

        // Slice literals
        {
            const zero = try parseFromSlice([]const u8, gpa, "&.{}", .{});
            defer parseFree(gpa, zero);
            try std.testing.expectEqualSlices(u8, @as([]const u8, &.{}), zero);

            const one = try parseFromSlice([]u8, gpa, "&.{'a'}", .{});
            defer parseFree(gpa, one);
            try std.testing.expectEqualSlices(u8, &.{'a'}, one);

            const two = try parseFromSlice([]const u8, gpa, "&.{'a', 'b'}", .{});
            defer parseFree(gpa, two);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two);

            const two_comma = try parseFromSlice([]const u8, gpa, "&.{'a', 'b',}", .{});
            defer parseFree(gpa, two_comma);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two_comma);

            const three = try parseFromSlice([]u8, gpa, "&.{'a', 'b', 'c'}", .{});
            defer parseFree(gpa, three);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, three);

            const sentinel = try parseFromSlice([:'z']const u8, gpa, "&.{'a', 'b', 'c'}", .{});
            defer parseFree(gpa, sentinel);
            const expected_sentinel: [:'z']const u8 = &.{ 'a', 'b', 'c' };
            try std.testing.expectEqualSlices(u8, expected_sentinel, sentinel);
        }
    }

    // Deep free
    {
        // Arrays
        {
            const parsed = try parseFromSlice([1][]const u8, gpa, ".{\"abc\"}", .{});
            defer parseFree(gpa, parsed);
            const expected: [1][]const u8 = .{"abc"};
            try std.testing.expectEqualDeep(expected, parsed);
        }

        // Slice literals
        {
            const parsed = try parseFromSlice([]const []const u8, gpa, "&.{\"abc\"}", .{});
            defer parseFree(gpa, parsed);
            const expected: []const []const u8 = &.{"abc"};
            try std.testing.expectEqualDeep(expected, parsed);
        }
    }

    // Senintels and alignment
    {
        // Arrays
        {
            const sentinel = try parseFromSlice([1:2]u8, gpa, ".{1}", .{});
            try std.testing.expectEqual(@as(usize, 1), sentinel.len);
            try std.testing.expectEqual(@as(u8, 1), sentinel[0]);
            try std.testing.expectEqual(@as(u8, 2), sentinel[1]);
        }

        // Slice literals
        {
            const sentinel = try parseFromSlice([:2]align(4) u8, gpa, "&.{1}", .{});
            defer parseFree(gpa, sentinel);
            try std.testing.expectEqual(@as(usize, 1), sentinel.len);
            try std.testing.expectEqual(@as(u8, 1), sentinel[0]);
            try std.testing.expectEqual(@as(u8, 2), sentinel[1]);
        }
    }

    // Expect 0 find 3
    {
        var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b', 'c'}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst([0]u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName([0]u8), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 1,
            .line_start = 0,
            .line_end = 16,
        }, location);
    }

    // Expect 1 find 2
    {
        var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b'}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst([1]u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName([1]u8), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 1,
            .line_start = 0,
            .line_end = 11,
        }, location);
    }

    // Expect 2 find 1
    {
        var ast = try std.zig.Ast.parse(gpa, ".{'a'}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst([2]u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName([2]u8), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 1,
            .line_start = 0,
            .line_end = 6,
        }, location);
    }

    // Expect 3 find 0
    {
        var ast = try std.zig.Ast.parse(gpa, ".{}", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName([3]u8), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 1,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }

    // Wrong inner type
    {
        // Array
        {
            var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([3]bool, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName(bool), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 2,
                .line_start = 0,
                .line_end = 16,
            }, location);
        }

        // Slice
        {
            var ast = try std.zig.Ast.parse(gpa, "&.{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]bool, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName(bool), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 3,
                .line_start = 0,
                .line_end = 17,
            }, location);
        }
    }

    // Complete wrong type
    {
        // Array
        {
            var ast = try std.zig.Ast.parse(gpa, "'a'", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([3]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 3,
            }, location);
        }

        // Slice
        {
            var ast = try std.zig.Ast.parse(gpa, "'a'", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 3,
            }, location);
        }
    }

    // Mixing up arrays and slices
    {
        // Array
        {
            var ast = try std.zig.Ast.parse(gpa, "&.{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([3]bool, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([3]bool), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 17,
            }, location);
        }

        // Slice
        {
            var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]bool, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]bool), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 1,
                .line_start = 0,
                .line_end = 16,
            }, location);
        }
    }
}

fn parsePointer(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    const tags = self.ast.nodes.items(.tag);
    const data = self.ast.nodes.items(.data);
    return switch (tags[node]) {
        .string_literal => try self.parseStringLiteral(T, node),
        .multiline_string_literal => try self.parseMultilineStringLiteral(T, node),
        .address_of => try self.parseAddressOf(T, data[node].lhs),
        else => self.failExpectedType(T, node),
    };
}

fn parseAddressOf(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    const Ptr = @typeInfo(T).Pointer;
    // TODO: it may make sense to support coercing into these even though it won't often be used, since
    // zig does, so it's consistent. Not gonna bother for now though can revisit later and decide.
    // Make sure we're working with a slice
    switch (Ptr.size) {
        .One, .Many, .C => @compileError(@typeName(T) ++ ": cannot parse pointers that are not slices"),
        .Slice => {},
    }

    // Parse the array literal
    var buf: [2]NodeIndex = undefined;
    const element_nodes = try self.elementsOrFields(T, &buf, node);

    // Allocate the slice
    const sentinel = if (Ptr.sentinel) |s| @as(*const Ptr.child, @ptrCast(s)).* else null;
    const slice = try self.gpa.allocWithOptions(
        Ptr.child,
        element_nodes.len,
        Ptr.alignment,
        sentinel,
    );
    errdefer self.gpa.free(slice);

    // Parse the elements and return the slice
    for (slice, element_nodes) |*element, element_node| {
        element.* = try self.parseExpr(Ptr.child, element_node);
    }
    return slice;
}

fn parseStringLiteral(self: *Parser, comptime T: type, node: NodeIndex) !T {
    switch (@typeInfo(T)) {
        .Pointer => |Pointer| {
            if (Pointer.size != .Slice) {
                @compileError(@typeName(T) ++ ": cannot parse pointers that are not slices");
            }

            const main_tokens = self.ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const raw = self.ast.tokenSlice(token);

            if (Pointer.child != u8 or !Pointer.is_const or Pointer.alignment != 1) {
                return self.failExpectedType(T, node);
            }
            var buf = std.ArrayListUnmanaged(u8){};
            defer buf.deinit(self.gpa);
            switch (try std.zig.string_literal.parseWrite(buf.writer(self.gpa), raw)) {
                .success => {},
                .failure => |reason| return self.failInvalidStringLiteral(node, reason),
            }

            if (Pointer.sentinel) |sentinel| {
                if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
                    return self.failExpectedType(T, node);
                }

                // TODO: see multiline string too
                // TODO: why couldn't I use from owned slice for this before when it was getting converted
                // back and forth?
                // var temp = std.ArrayListUnmanaged(u8).fromOwnedSlice(result);
                // errdefer temp.deinit(self.gpa);
                // try temp.append(self.gpa, 0);
                // return temp.items[0 .. temp.items.len - 1 :0];

                try buf.append(self.gpa, 0);
                // TODO: doesn't alloc right?
                const result = try buf.toOwnedSlice(self.gpa);
                return result[0 .. result.len - 1 :0];
            }

            return try buf.toOwnedSlice(self.gpa);
        },
        else => unreachable,
    }
}

fn parseMultilineStringLiteral(self: *Parser, comptime T: type, node: NodeIndex) !T {
    switch (@typeInfo(T)) {
        .Pointer => |Pointer| {
            if (Pointer.size != .Slice) {
                @compileError(@typeName(T) ++ ": cannot parse pointers that are not slices");
            }

            if (Pointer.child != u8 or !Pointer.is_const or Pointer.alignment != 1) {
                return self.failExpectedType(T, node);
            }

            var buf = std.ArrayListUnmanaged(u8){};
            defer buf.deinit(self.gpa);
            const writer = buf.writer(self.gpa);

            var parser = std.zig.string_literal.multilineParser(writer);
            const data = self.ast.nodes.items(.data);
            var tok_i = data[node].lhs;
            while (tok_i <= data[node].rhs) : (tok_i += 1) {
                try parser.line(self.ast.tokenSlice(tok_i));
            }

            if (Pointer.sentinel) |sentinel| {
                if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
                    return self.failExpectedType(T, node);
                }
                return buf.toOwnedSliceSentinel(self.gpa, 0);
            } else {
                return buf.toOwnedSlice(self.gpa);
            }
        },
        else => unreachable,
    }
}

test "string literal" {
    const gpa = std.testing.allocator;

    // Basic string literal
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"abc\"", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "abc"), parsed);
    }

    // String literal with escape characters
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"ab\\nc\"", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "ab\nc"), parsed);
    }

    // Passing string literal to a mutable slice
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abcd\"", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 6,
            }, location);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abcd", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 6,
            }, location);
        }
    }

    // Passing string literal to a array
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abcd\"", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([4:0]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([4:0]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 6,
            }, location);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abcd", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([4:0]u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([4:0]u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 6,
            }, location);
        }
    }

    // Zero termianted slices
    {
        {
            const parsed: [:0]const u8 = try parseFromSlice([:0]const u8, gpa, "\"abc\"", .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("abc", parsed);
            try std.testing.expectEqual(@as(u8, 0), parsed[3]);
        }

        {
            const parsed: [:0]const u8 = try parseFromSlice([:0]const u8, gpa, "\\\\abc", .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("abc", parsed);
            try std.testing.expectEqual(@as(u8, 0), parsed[3]);
        }
    }

    // Other value terminated slices
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"foo\"", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([:1]const u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([:1]const u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 5,
            }, location);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\foo", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([:1]const u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([:1]const u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 5,
            }, location);
        }
    }

    // Invalid string literal
    {
        var ast = try std.zig.Ast.parse(gpa, "\"\\a\"", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst([]const u8, gpa, &ast, &status, .{}));
        const node = status.invalid_string_literal.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }

    // Slice wrong child type
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"a\"", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]const i8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]const i8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 3,
            }, location);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\a", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]const i8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]const i8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 3,
            }, location);
        }
    }

    // Bad alignment
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abc\"", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]align(2) const u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]align(2) const u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 5,
            }, location);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abc", .zon);
            defer ast.deinit(gpa);
            var status: Status = .success;
            try std.testing.expectError(error.Type, parseFromAst([]align(2) const u8, gpa, &ast, &status, .{}));
            try std.testing.expectEqualStrings(@typeName([]align(2) const u8), status.expected_type.name);
            const node = status.expected_type.node;
            const main_tokens = ast.nodes.items(.main_token);
            const token = main_tokens[node];
            const location = ast.tokenLocation(0, token);
            try std.testing.expectEqual(Ast.Location{
                .line = 0,
                .column = 0,
                .line_start = 0,
                .line_end = 5,
            }, location);
        }
    }

    // Multi line strings
    inline for (.{[]const u8, [:0]const u8}) |String| {
        // Nested
        {
            const S = struct {
                message: String,
                message2: String,
                message3: String,
            };
            const parsed = try parseFromSlice(S, gpa,
                \\.{
                \\    .message =
                \\        \\hello, world!
                \\
                \\        \\this is a multiline string!
                \\        \\
                \\        \\...
                \\
                \\    ,
                \\    .message2 =
                \\        \\this too...sort of.
                \\    ,
                \\    .message3 = 
                \\        \\
                \\        \\and this.
                \\}
            , .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("hello, world!\nthis is a multiline string!\n\n...", parsed.message);
            try std.testing.expectEqualStrings("this too...sort of.", parsed.message2);
            try std.testing.expectEqualStrings("\nand this.", parsed.message3);
        }
    }
}

// TODO: cannot represent not quite right error for unknown field right?
fn parseEnumLiteral(self: *Parser, comptime T: type, node: NodeIndex) error{Type}!T {
    const tags = self.ast.nodes.items(.tag);
    return switch (tags[node]) {
        .enum_literal => try self.parseEnumTag(T, node),
        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => try self.parseEnumFromInt(T, node),
        else => return self.failExpectedType(T, node),
    };
}

fn parseEnumFromInt(self: *Parser, comptime T: type, node: NodeIndex) error{Type}!T {
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    const bytes = self.ast.tokenSlice(token);
    if (!std.mem.eql(u8, bytes, "@enumFromInt")) {
        return self.failUnsupportedBuiltin(bytes, node);
    }

    const tags = self.ast.nodes.items(.tag);
    const arg = switch (tags[node]) {
        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => b: {
            const data = self.ast.nodes.items(.data);
            const lhs = data[node].lhs;
            const rhs = data[node].rhs;
            if ((lhs == rhs) or (lhs != 0 and rhs != 0)) {
                return self.failBadArgCount(node, 1);
            }
            break :b if (lhs == 0) rhs else lhs;
        },
        else => unreachable,
    };

    // TODO: kinda weird dup error handling?
    const number = self.parseNumber(@typeInfo(T).Enum.tag_type, arg) catch
        return self.failCannotRepresent(T, node);
    // TODO: should this be renamed too?
    return std.meta.intToEnum(T, number) catch
        self.failCannotRepresent(T, node);
}

fn parseEnumTag(self: *Parser, comptime T: type, node: NodeIndex) error{Type}!T {
    // Create a comptime string map for the enum fields
    const enum_fields = @typeInfo(T).Enum.fields;
    comptime var kvs_list: [enum_fields.len]struct { []const u8, T } = undefined;
    inline for (enum_fields, 0..) |field, i| {
        kvs_list[i] = .{ field.name, @enumFromInt(field.value) };
    }
    const tags = std.ComptimeStringMap(T, kvs_list);

    // TODO: could technically optimize getter for the case where it doesn't fail
    // TODO: the optimizer is smart enough to move the getters into the orelse case for these sorts
    // of things right?
    // Get the tag if it exists
    const main_tokens = self.ast.nodes.items(.main_token);
    const data = self.ast.nodes.items(.data);
    const token = main_tokens[node];
    const bytes = self.parseIdentifier(token);
    const dot_node = data[node].lhs;
    return tags.get(bytes) orelse
        self.failCannotRepresent(T, dot_node);
}

// TODO: is this built in anywhere?
fn parseIdentifier(self: *const Parser, token: TokenIndex) []const u8 {
    var bytes = self.ast.tokenSlice(token);
    if (bytes[0] == '@' and bytes[1] == '"')
        return bytes[2 .. bytes.len - 1];
    return bytes;
}

test "enum literals" {
    const gpa = std.testing.allocator;

    const Enum = enum {
        foo,
        bar,
        baz,
    };

    // Tags that exist
    try std.testing.expectEqual(Enum.foo, try parseFromSlice(Enum, gpa, ".foo", .{}));
    try std.testing.expectEqual(Enum.bar, try parseFromSlice(Enum, gpa, ".bar", .{}));
    try std.testing.expectEqual(Enum.baz, try parseFromSlice(Enum, gpa, ".baz", .{}));

    // Bad tag
    {
        var ast = try std.zig.Ast.parse(gpa, ".qux", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(Enum));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }

    // Bad type
    {
        var ast = try std.zig.Ast.parse(gpa, "true", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Enum), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }
}

test "@enumFromInt" {
    const gpa = std.testing.allocator;

    const Enum = enum(u8) {
        zero,
        three = 3,
    };

    const NonExhaustive = enum(u8) {
        zero,
        _,
    };

    const SignedEnum = enum(i8) {
        zero,
        three = -3,
    };

    // Test parsing numbers as enums
    try std.testing.expectEqual(@as(Enum, @enumFromInt(0)), try parseFromSlice(Enum, gpa, "@enumFromInt(0)", .{}));
    try std.testing.expectEqual(@as(Enum, @enumFromInt(3)), try parseFromSlice(Enum, gpa, "@enumFromInt(3)", .{}));
    try std.testing.expectEqual(@as(SignedEnum, @enumFromInt(0)), try parseFromSlice(SignedEnum, gpa, "@enumFromInt(0)", .{}));
    try std.testing.expectEqual(@as(SignedEnum, @enumFromInt(-3)), try parseFromSlice(SignedEnum, gpa, "@enumFromInt(-3)", .{}));
    try std.testing.expectEqual(@as(NonExhaustive, @enumFromInt(123)), try parseFromSlice(NonExhaustive, gpa, "@enumFromInt(123)", .{}));

    // Bad tag
    {
        var ast = try std.zig.Ast.parse(gpa, "@enumFromInt(2)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(Enum));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 15,
        }, location);
    }

    // Out of range tag
    {
        var ast = try std.zig.Ast.parse(gpa, "@enumFromInt(256)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(Enum));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Unexpected negative tag
    {
        var ast = try std.zig.Ast.parse(gpa, "@enumFromInt(-3)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(Enum));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 16,
        }, location);
    }

    // Float tag
    {
        var ast = try std.zig.Ast.parse(gpa, "@enumFromInt(1.5)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(Enum));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 17,
        }, location);
    }

    // Wrong builtin
    {
        var ast = try std.zig.Ast.parse(gpa, "@fooBarBaz(1)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.unsupported_builtin.name, "@fooBarBaz");
        const node = status.unsupported_builtin.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 13,
        }, location);
    }

    // Bad arg count
    {
        var ast = try std.zig.Ast.parse(gpa, "@enumFromInt(1, 2)", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqual(status.bad_arg_count.expected, 1);
        const node = status.bad_arg_count.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 18,
        }, location);
    }

    // Bad coercion
    {
        var ast = try std.zig.Ast.parse(gpa, "1", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(Enum), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 1,
        }, location);
    }
}

// TODO: How do I free the results if failure occurs?
fn fail(self: *Parser, status: Status) error{Type} {
    @setCold(true);
    // TODO: prevent or is this fine?
    assert(status != .success);
    // TODO: ...commented out cause of dup error handling
    // assert(self.err == null);
    if (self.status) |s| {
        s.* = status;
    }
    return error.Type;
}

fn failInvalidStringLiteral(self: *Parser, node: NodeIndex, reason: StringLiteralError) error{Type} {
    @setCold(true);
    return self.fail(.{ .invalid_string_literal = .{
        .node = node,
        .reason = reason,
    } });
}

fn failInvalidNumberLiteral(self: *Parser, node: NodeIndex, reason: NumberLiteralError) error{Type} {
    @setCold(true);
    return self.fail(.{ .invalid_number_literal = .{
        .node = node,
        .reason = reason,
    } });
}

fn failExpectedType(self: *Parser, comptime T: type, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .expected_type = .{
        .name = @typeName(T),
        .node = node,
    } });
}

fn failCannotRepresent(self: *Parser, comptime T: type, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .cannot_represent = .{
        .name = @typeName(T),
        .node = node,
    } });
}

// TODO: order of node vs name inconsistent with others?
fn failUnknownField(self: *Parser, comptime T: type, node: NodeIndex, name: []const u8) error{Type} {
    // TODO: should we be using setCold anywhere else?
    @setCold(true);
    return self.fail(.{ .unknown_field = .{
        .node = node,
        .type_name = @typeName(T),
        .field_name = name,
    } });
}

fn failMissingField(self: *Parser, comptime T: type, name: []const u8, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .missing_field = .{
        .node = node,
        .type_name = @typeName(T),
        .field_name = name,
    } });
}

fn failDuplicateField(self: *Parser, name: []const u8, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .duplicate_field = .{
        .node = node,
        .field_name = name,
    } });
}

fn failUnsupportedBuiltin(self: *Parser, name: []const u8, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .unsupported_builtin = .{
        .node = node,
        .name = name,
    } });
}

fn failBadArgCount(self: *Parser, node: NodeIndex, expected: u8) error{Type} {
    @setCold(true);
    return self.fail(.{ .bad_arg_count = .{
        .node = node,
        .expected = expected,
    } });
}

fn failTypeExpr(self: *Parser, node: NodeIndex) error{Type} {
    @setCold(true);
    return self.fail(.{ .type_expr = .{
        .node = node,
    } });
}

fn parseBool(self: *Parser, node: NodeIndex) error{Type}!bool {
    const tags = self.ast.nodes.items(.tag);
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    switch (tags[node]) {
        .identifier => {
            const bytes = self.ast.tokenSlice(token);
            if (std.mem.eql(u8, bytes, "true")) {
                return true;
            } else if (std.mem.eql(u8, bytes, "false")) {
                return false;
            }
        },
        else => {},
    }
    return self.failExpectedType(bool, node);
}

test "parse bool" {
    const gpa = std.testing.allocator;

    // Correct floats
    try std.testing.expectEqual(true, try parseFromSlice(bool, gpa, "true", .{}));
    try std.testing.expectEqual(false, try parseFromSlice(bool, gpa, "false", .{}));

    // Errors
    {
        var ast = try std.zig.Ast.parse(gpa, " foo", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(bool, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(bool), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 1,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }
    {
        var ast = try std.zig.Ast.parse(gpa, "123", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(bool, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(bool), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }
}

// TODO: could set unused lhs/rhs to undefined?
fn parseNumber(
    self: *Parser,
    comptime T: type,
    node: NodeIndex,
) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const tags = self.ast.nodes.items(.tag);
    switch (tags[num_lit_node]) {
        .number_literal => return self.parseNumberLiteral(T, node),
        .char_literal => return self.parseCharLiteral(T, node),
        else => return self.failExpectedType(T, num_lit_node),
    }
}

fn parseNumberLiteral(self: *Parser, comptime T: type, node: NodeIndex) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const token_bytes = self.ast.tokenSlice(num_lit_token);
    const number = std.zig.number_literal.parseNumberLiteral(token_bytes);

    switch (number) {
        .int => |int| return self.applySignToInt(T, node, int),
        .big_int => |base| return self.parseBigNumber(T, node, base),
        .float => return self.parseFloat(T, node),
        .failure => |reason| return self.failInvalidNumberLiteral(node, reason),
    }
}

fn applySignToInt(self: *Parser, comptime T: type, node: NodeIndex, int: anytype) error{Type}!T {
    if (self.isNegative(node)) {
        switch (@typeInfo(T)) {
            .Int => |int_type| switch (int_type.signedness) {
                .signed => {
                    const Positive = @Type(.{ .Int = .{
                        .bits = int_type.bits + 1,
                        .signedness = .signed,
                    } });
                    if (int > std.math.maxInt(T) + 1) {
                        return self.failCannotRepresent(T, node);
                    }
                    const positive: Positive = @intCast(int);
                    return @as(T, @intCast(-positive));
                },
                .unsigned => return self.failCannotRepresent(T, node),
            },
            .Float => return -@as(T, @floatFromInt(int)),
            else => @compileError("expected numeric type"),
        }
    } else {
        switch (@typeInfo(T)) {
            .Int => return std.math.cast(T, int) orelse
                self.failCannotRepresent(T, node),
            .Float => return @as(T, @floatFromInt(int)),
            else => @compileError("expected numeric type"),
        }
    }
}

fn parseBigNumber(
    self: *Parser,
    comptime T: type,
    node: NodeIndex,
    base: Base,
) error{Type}!T {
    switch (@typeInfo(T)) {
        .Int => return self.parseBigInt(T, node, base),
        // TODO: passing in f128 to work around possible float parsing bug
        .Float => return @as(T, @floatCast(try self.parseFloat(f128, node))),
        else => unreachable,
    }
}

fn parseBigInt(self: *Parser, comptime T: type, node: NodeIndex, base: Base) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    // TODO: was wrong, passed in node by mistake! we could edit the ast to make this stuff typesafe..?
    const bytes = self.ast.tokenSlice(num_lit_token);
    const prefix_offset = @as(u8, 2) * @intFromBool(base != .decimal);
    var result: T = 0;
    for (bytes[prefix_offset..]) |char| {
        if (char == '_') continue;
        const d = std.fmt.charToDigit(char, @intFromEnum(base)) catch unreachable;
        result = std.math.mul(T, result, @as(T, @intCast(@intFromEnum(base)))) catch
            return self.failCannotRepresent(T, node);
        if (self.isNegative(node)) {
            result = std.math.sub(T, result, @as(T, @intCast(d))) catch
                return self.failCannotRepresent(T, node);
        } else {
            result = std.math.add(T, result, @as(T, @intCast(d))) catch
                return self.failCannotRepresent(T, node);
        }
    }
    return result;
}

fn parseFloat(
    self: *Parser,
    comptime T: type,
    node: NodeIndex,
) error{Type}!T {
    const Float = switch (@typeInfo(T)) {
        .Float => T,
        .Int => f128,
        else => unreachable,
    };
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const bytes = self.ast.tokenSlice(num_lit_token);
    const unsigned_float = std.fmt.parseFloat(Float, bytes) catch unreachable;
    const result = if (self.isNegative(node)) -unsigned_float else unsigned_float;
    if (T == Float) {
        return result;
    } else {
        return intFromFloat(T, result) orelse
            self.failCannotRepresent(T, node);
    }
}

fn parseCharLiteral(self: *Parser, comptime T: type, node: NodeIndex) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const token_bytes = self.ast.tokenSlice(num_lit_token);
    const char = std.zig.string_literal.parseCharLiteral(token_bytes).success;
    return self.applySignToInt(T, node, char);
}

// TODO: technically I can cache the results of this and numLitNode, but it's confusing. could maybe
// wrap in a struct that's like main node, negative node? or something.
fn isNegative(self: *const Parser, node: NodeIndex) bool {
    const tags = self.ast.nodes.items(.tag);
    return tags[node] == .negation;
}

fn numLitNode(self: *const Parser, node: NodeIndex) NodeIndex {
    if (self.isNegative(node)) {
        const data = self.ast.nodes.items(.data);
        return data[node].lhs;
    } else {
        return node;
    }
}

// TODO: move to std.math? did the int equivalent there get renamed to match the builtin style like this too or no?
fn intFromFloat(comptime T: type, value: anytype) ?T {
    switch (@typeInfo(@TypeOf(value))) {
        .Float, .ComptimeFloat => {},
        else => @compileError(@typeName(@TypeOf(value)) ++ " is not a floating point type"),
    }
    switch (@typeInfo(T)) {
        .Int, .ComptimeInt => {},
        else => @compileError(@typeName(T) ++ " is not an integer type"),
    }

    if (T == comptime_int or (value > std.math.maxInt(T) or value < std.math.minInt(T))) {
        return null;
    }

    if (std.math.isNan(value) or std.math.trunc(value) != value) {
        return null;
    }

    return @as(T, @intFromFloat(value));
}

test "intFromFloat" {
    // Valid conversions
    try std.testing.expectEqual(@as(u8, 10), intFromFloat(u8, 10.0).?);
    try std.testing.expectEqual(@as(i8, -123), intFromFloat(i8, @as(f64, -123.0)).?);
    try std.testing.expectEqual(@as(i16, 45), intFromFloat(i16, @as(f128, 45.0)).?);
    try std.testing.expectEqual(@as(comptime_int, 10), comptime intFromFloat(i16, @as(f32, 10.0)).?);
    try std.testing.expectEqual(
        @as(comptime_int, 10),
        comptime intFromFloat(i16, @as(comptime_float, 10.0)).?,
    );
    try std.testing.expectEqual(@as(u8, 5), intFromFloat(u8, @as(comptime_float, 5.0)).?);

    // Out of range
    try std.testing.expectEqual(@as(?u4, null), intFromFloat(u4, @as(f32, 16.0)));
    try std.testing.expectEqual(@as(?i4, null), intFromFloat(i4, -17.0));
    try std.testing.expectEqual(@as(?u8, null), intFromFloat(u8, -2.0));

    // Not a whole number
    try std.testing.expectEqual(@as(?u8, null), intFromFloat(u8, 0.5));
    try std.testing.expectEqual(@as(?i8, null), intFromFloat(i8, 0.01));

    // Infinity and NaN
    try std.testing.expectEqual(@as(?u8, null), intFromFloat(u8, std.math.inf(f32)));
    try std.testing.expectEqual(@as(?u8, null), intFromFloat(u8, -std.math.inf(f32)));
    try std.testing.expectEqual(@as(?u8, null), intFromFloat(u8, std.math.nan(f32)));
    try std.testing.expectEqual(
        @as(?comptime_int, null),
        comptime intFromFloat(comptime_int, std.math.inf(f32)),
    );
}

test "parse int" {
    const gpa = std.testing.allocator;

    // Test various numbers and types
    try std.testing.expectEqual(@as(u8, 10), try parseFromSlice(u8, gpa, "10", .{}));
    try std.testing.expectEqual(@as(i16, 24), try parseFromSlice(i16, gpa, "24", .{}));
    try std.testing.expectEqual(@as(i14, -4), try parseFromSlice(i14, gpa, "-4", .{}));
    try std.testing.expectEqual(@as(i32, -123), try parseFromSlice(i32, gpa, "-123", .{}));

    // Test limits
    try std.testing.expectEqual(@as(i8, 127), try parseFromSlice(i8, gpa, "127", .{}));
    try std.testing.expectEqual(@as(i8, -128), try parseFromSlice(i8, gpa, "-128", .{}));

    // Test characters
    try std.testing.expectEqual(@as(u8, 'a'), try parseFromSlice(u8, gpa, "'a'", .{}));
    try std.testing.expectEqual(@as(u8, 'z'), try parseFromSlice(u8, gpa, "'z'", .{}));
    try std.testing.expectEqual(@as(i16, -'a'), try parseFromSlice(i16, gpa, "-'a'", .{}));
    try std.testing.expectEqual(@as(i16, -'z'), try parseFromSlice(i16, gpa, "-'z'", .{}));

    // Test big integers
    try std.testing.expectEqual(
        @as(u65, 36893488147419103231),
        try parseFromSlice(u65, gpa, "36893488147419103231", .{}),
    );
    try std.testing.expectEqual(
        @as(u65, 36893488147419103231),
        try parseFromSlice(u65, gpa, "368934_881_474191032_31", .{}),
    );

    // Test big integer limits
    try std.testing.expectEqual(
        @as(i66, 36893488147419103231),
        try parseFromSlice(i66, gpa, "36893488147419103231", .{}),
    );
    try std.testing.expectEqual(
        @as(i66, -36893488147419103232),
        try parseFromSlice(i66, gpa, "-36893488147419103232", .{}),
    );
    {
        var ast = try std.zig.Ast.parse(gpa, "36893488147419103232", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(i66, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(i66));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 20,
        }, location);
    }
    {
        var ast = try std.zig.Ast.parse(gpa, "-36893488147419103233", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(i66, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(i66));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 21,
        }, location);
    }

    // Test parsing whole number floats as integers
    try std.testing.expectEqual(@as(i8, -1), try parseFromSlice(i8, gpa, "-1.0", .{}));
    try std.testing.expectEqual(@as(i8, 123), try parseFromSlice(i8, gpa, "123.0", .{}));

    // Test non-decimal integers
    try std.testing.expectEqual(@as(i16, 0xff), try parseFromSlice(i16, gpa, "0xff", .{}));
    try std.testing.expectEqual(@as(i16, -0xff), try parseFromSlice(i16, gpa, "-0xff", .{}));
    try std.testing.expectEqual(@as(i16, 0o77), try parseFromSlice(i16, gpa, "0o77", .{}));
    try std.testing.expectEqual(@as(i16, -0o77), try parseFromSlice(i16, gpa, "-0o77", .{}));
    try std.testing.expectEqual(@as(i16, 0b11), try parseFromSlice(i16, gpa, "0b11", .{}));
    try std.testing.expectEqual(@as(i16, -0b11), try parseFromSlice(i16, gpa, "-0b11", .{}));

    // Test non-decimal big integers
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0x1ffffffffffffffff",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0x1ffffffffffffffff",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0x1ffffffffffffffff",
        .{},
    ));
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0o3777777777777777777777",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0o3777777777777777777777",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0o3777777777777777777777",
        .{},
    ));
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0b11111111111111111111111111111111111111111111111111111111111111111",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0b11111111111111111111111111111111111111111111111111111111111111111",
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0b11111111111111111111111111111111111111111111111111111111111111111",
        .{},
    ));

    // Number with invalid character in the middle
    {
        var ast = try std.zig.Ast.parse(gpa, "32a32", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqual(status.invalid_number_literal.reason, .{ .invalid_digit = .{
            .i = 2,
            .base = @enumFromInt(10),
        } });
        const node = status.invalid_number_literal.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 5,
        }, location);
    }

    // Failing to parse as int
    {
        var ast = try std.zig.Ast.parse(gpa, "true", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(@typeName(u8), status.expected_type.name);
        const node = status.expected_type.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }

    // Failing because an int is out of range
    {
        var ast = try std.zig.Ast.parse(gpa, "256", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(u8));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }

    // Failing because a negative int is out of range
    {
        var ast = try std.zig.Ast.parse(gpa, "-129", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(i8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(i8));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }

    // Failing because an unsigned int is negative
    {
        var ast = try std.zig.Ast.parse(gpa, "-1", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(u8));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 2,
        }, location);
    }

    // Failing because a float is non-whole
    {
        var ast = try std.zig.Ast.parse(gpa, "1.5", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(u8));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 3,
        }, location);
    }

    // Failing because a float is negative
    {
        var ast = try std.zig.Ast.parse(gpa, "-1.0", .zon);
        defer ast.deinit(gpa);
        var status: Status = .success;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectEqualStrings(status.cannot_represent.name, @typeName(u8));
        const node = status.cannot_represent.node;
        const main_tokens = ast.nodes.items(.main_token);
        const token = main_tokens[node];
        const location = ast.tokenLocation(0, token);
        try std.testing.expectEqual(Ast.Location{
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 4,
        }, location);
    }
}

test "parse float" {
    const gpa = std.testing.allocator;

    // Test decimals
    try std.testing.expectEqual(@as(f16, 0.5), try parseFromSlice(f16, gpa, "0.5", .{}));
    try std.testing.expectEqual(@as(f32, 123.456), try parseFromSlice(f32, gpa, "123.456", .{}));
    try std.testing.expectEqual(@as(f64, -123.456), try parseFromSlice(f64, gpa, "-123.456", .{}));
    try std.testing.expectEqual(@as(f128, 42.5), try parseFromSlice(f128, gpa, "42.5", .{}));

    // Test whole numbers with and without decimals
    try std.testing.expectEqual(@as(f16, 5.0), try parseFromSlice(f16, gpa, "5.0", .{}));
    try std.testing.expectEqual(@as(f16, 5.0), try parseFromSlice(f16, gpa, "5", .{}));
    try std.testing.expectEqual(@as(f32, -102), try parseFromSlice(f32, gpa, "-102.0", .{}));
    try std.testing.expectEqual(@as(f32, -102), try parseFromSlice(f32, gpa, "-102", .{}));

    // Test characters and negated characters
    try std.testing.expectEqual(@as(f32, 'a'), try parseFromSlice(f32, gpa, "'a'", .{}));
    try std.testing.expectEqual(@as(f32, 'z'), try parseFromSlice(f32, gpa, "'z'", .{}));
    try std.testing.expectEqual(@as(f32, -'z'), try parseFromSlice(f32, gpa, "-'z'", .{}));

    // Test big integers
    try std.testing.expectEqual(
        @as(f32, 36893488147419103231),
        try parseFromSlice(f32, gpa, "36893488147419103231", .{}),
    );
    try std.testing.expectEqual(
        @as(f32, -36893488147419103231),
        try parseFromSlice(f32, gpa, "-36893488147419103231", .{}),
    );
    try std.testing.expectEqual(@as(f128, 0x1ffffffffffffffff), try parseFromSlice(
        f128,
        gpa,
        "0x1ffffffffffffffff",
        .{},
    ));
    try std.testing.expectEqual(@as(f32, 0x1ffffffffffffffff), try parseFromSlice(
        f32,
        gpa,
        "0x1ffffffffffffffff",
        .{},
    ));

    // Exponents, underscores
    try std.testing.expectEqual(@as(f32, 123.0E+77), try parseFromSlice(f32, gpa, "12_3.0E+77", .{}));

    // Hexadecimal
    try std.testing.expectEqual(@as(f32, 0x103.70p-5), try parseFromSlice(f32, gpa, "0x103.70p-5", .{}));
    try std.testing.expectEqual(@as(f32, -0x103.70), try parseFromSlice(f32, gpa, "-0x103.70", .{}));
    try std.testing.expectEqual(
        @as(f32, 0x1234_5678.9ABC_CDEFp-10),
        try parseFromSlice(f32, gpa, "0x1234_5678.9ABC_CDEFp-10", .{}),
    );
}

// TODO: zig float parsing bug example
// test "bug" {
//     const float: f32 = 0xffffffffffffffff;
//     const parsed = try std.fmt.parseFloat(f32, "0xffffffffffffffff.0p0");
//     try std.testing.expectEqual(float, parsed);
// }

pub const StringifierOptions = struct {
    whitespace: bool = true,
};

pub const StringifyValueOptions = struct {
    emit_utf8_codepoints: bool = false,
    emit_strings_as_containers: bool = false,
    emit_default_optional_fields: bool = true,
};

pub const StringifyOptions = struct {
    whitespace: bool = true,
    emit_utf8_codepoints: bool = false,
    emit_strings_as_containers: bool = false,
    emit_default_optional_fields: bool = true,
};

pub const StringifyContainerOptions = struct {
    whitespace_style: union(enum) {
        wrap: bool,
        fields: usize,
    } = .{ .wrap = true },

    fn shouldWrap(self: StringifyContainerOptions) bool {
        return switch (self.whitespace_style) {
            .wrap => |wrap| wrap,
            .fields => |fields| fields > 2,
        };
    }
};

pub fn stringify(val: anytype, comptime options: StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{
        .whitespace = options.whitespace,
    });
    try stringifier.value(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

pub fn stringifyMaxDepth(val: anytype, comptime options: StringifyOptions, writer: anytype, depth: usize) Stringifier(@TypeOf(writer)).MaxDepthError!void {
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{
        .whitespace = options.whitespace,
    });
    try stringifier.valueMaxDepth(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    }, depth);
}

pub fn stringifyUnchecked(val: anytype, comptime options: StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{
        .whitespace = options.whitespace,
    });
    try stringifier.valueUnchecked(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

const RecursiveTypeBuffer = [32]type;

fn typeIsRecursive(comptime T: type) bool {
    comptime var buf: RecursiveTypeBuffer = undefined;
    return typeIsRecursiveImpl(T, buf[0..0]);
}

fn typeIsRecursiveImpl(comptime T: type, comptime visited_arg: []type) bool {
    comptime var visited = visited_arg;

    // Check if we've already seen this type
    inline for (visited) |found| {
        if (T == found) {
            return true;
        }
    }

    // Add this type to the stack
    if (visited.len >= @typeInfo(RecursiveTypeBuffer).Array.len) {
        @compileError("recursion limit");
    }
    visited.ptr[visited.len] = T;
    visited.len += 1;

    // Recurse
    switch (@typeInfo(T)) {
        .Pointer => |Pointer| return typeIsRecursiveImpl(Pointer.child, visited),
        .Array => |Array| return typeIsRecursiveImpl(Array.child, visited),
        .Struct => |Struct| inline for (Struct.fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) {
                return true;
            }
        },
        .Union => |Union| inline for (Union.fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) {
                return true;
            }
        },
        .Optional => |Optional| return typeIsRecursiveImpl(Optional.child, visited),
        else => {},
    }
    return false;
}

test "typeIsRecursive" {
    try std.testing.expect(!typeIsRecursive(bool));
    try std.testing.expect(!typeIsRecursive(struct { x: i32, y: i32 }));
    try std.testing.expect(!typeIsRecursive(struct { i32, i32 }));
    try std.testing.expect(typeIsRecursive(struct { x: i32, y: i32, z: *@This() }));
    try std.testing.expect(typeIsRecursive(struct {
        a: struct {
            const A = @This();
            b: struct {
                c: *struct {
                    a: ?A,
                },
            },
        },
    }));
    try std.testing.expect(typeIsRecursive(struct {
        a: [3]*@This(),
    }));
    try std.testing.expect(typeIsRecursive(struct {
        a: union { a: i32, b: *@This() },
    }));
}

fn checkValueDepth(val: anytype, depth: usize) error { MaxDepth }!void {
    if (depth == 0) return error.MaxDepth;
    const child_depth = depth - 1;

    switch (@typeInfo(@TypeOf(val))) {
        .Pointer => |Pointer| switch (Pointer.size) {
            .One => try checkValueDepth(val.*, child_depth),
            .Slice => for (val) |item| {
                try checkValueDepth(item, child_depth);
            },
            .C, .Many => {},
        },
        .Array => for (val) |item| {
            try checkValueDepth(item, child_depth);
        },
        .Struct => |Struct| inline for (Struct.fields) |field_info| {
            try checkValueDepth(@field(val, field_info.name), child_depth);
        },
        .Union => |Union| if (Union.tag_type == null) {
            return;
        } else switch (val) {
            inline else => |payload| {
                return checkValueDepth(payload, child_depth);
            },
        },
        .Optional => if (val) |inner| try checkValueDepth(inner, child_depth),
        else => {},
    }
}

fn expectValueDepthEquals(expected: usize, value: anytype) !void {
    try checkValueDepth(value, expected);
    try std.testing.expectError(error.MaxDepth, checkValueDepth(value, expected - 1));
}

test "checkValueDepth" {
    try expectValueDepthEquals(1, 10);
    try expectValueDepthEquals(2, .{ .x = 1, .y = 2 });
    try expectValueDepthEquals(2, .{ 1, 2 });
    try expectValueDepthEquals(3, .{ 1, .{ 2, 3 } });
    try expectValueDepthEquals(3, .{ .{ 1, 2 }, 3 });
    try expectValueDepthEquals(3, .{ .x = 0, .y = 1, .z = .{ .x = 3 } });
    try expectValueDepthEquals(3, .{ .x = 0, .y = .{ .x = 1 }, .z = 2 });
    try expectValueDepthEquals(3, .{ .x = .{ .x = 0 }, .y = 1, .z = 2 });
    try expectValueDepthEquals(2, @as(?u32, 1));
    try expectValueDepthEquals(1, @as(?u32, null));
    try expectValueDepthEquals(1, null);
    try expectValueDepthEquals(2, &1);
    try expectValueDepthEquals(3, &@as(?u32, 1));

    const Union = union(enum) {
        x: u32,
        y: struct { x: u32 },
    };
    try expectValueDepthEquals(2, Union{.x = 1});
    try expectValueDepthEquals(3, Union{.y = .{.x = 1 }});

    const Recurse = struct { r: ?*const @This() };
    try expectValueDepthEquals(2, Recurse { .r = null });
    try expectValueDepthEquals(5, Recurse { .r = &Recurse { .r = null } });
    try expectValueDepthEquals(8, Recurse { .r = &Recurse { .r = &Recurse { .r = null }} });

    try expectValueDepthEquals(2, @as([]const u8, &.{1, 2, 3}));
    try expectValueDepthEquals(3, @as([]const []const u8, &.{&.{1, 2, 3}}));
}

pub fn Stringifier(comptime Writer: type) type {
    return struct {
        const Self = @This();

        pub const MaxDepthError = error { MaxDepth } || Writer.Error;

        options: StringifierOptions,
        indent_level: u8,
        writer: Writer,

        pub fn init(writer: Writer, options: StringifierOptions) Self {
            return .{
                .options = options,
                .writer = writer,
                .indent_level = 0,
            };
        }

        pub fn value(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            comptimeAssertNoRecursion(@TypeOf(val));
            return self.valueUnchecked(val, options);
        }

        pub fn valueMaxDepth(self: *Self, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
            try checkValueDepth(val, depth);
            return self.valueUnchecked(val, options);
        }

        pub fn valueUnchecked(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            switch (@typeInfo(@TypeOf(val))) {
                .Int => |Int| if (options.emit_utf8_codepoints and
                    Int.signedness == .unsigned and
                    Int.bits <= 21 and std.unicode.utf8ValidCodepoint(val))
                {
                    self.utf8Codepoint(val) catch |err| switch (err) {
                        error.InvalidCodepoint => unreachable,
                        else => |e| return e,
                    };
                } else {
                    try self.int(val);
                },
                .ComptimeInt => if (options.emit_utf8_codepoints and
                    val > 0 and
                    val <= std.math.maxInt(u21) and
                    std.unicode.utf8ValidCodepoint(val))
                {
                    self.utf8Codepoint(val) catch |err| switch (err) {
                        error.InvalidCodepoint => unreachable,
                        else => |e| return e,
                    };
                } else {
                    try self.int(val);
                },
                .Float, .ComptimeFloat => try self.float(val),
                .Bool, .Null => try std.fmt.format(self.writer, "{}", .{val}),
                .EnumLiteral => {
                    try self.writer.writeByte('.');
                    try self.ident(@tagName(val));
                },
                .Enum => |Enum| if (std.enums.tagName(@TypeOf(val), val)) |name| {
                    try self.writer.writeByte('.');
                    try self.ident(name);
                } else {
                    try self.int(@as(Enum.tag_type, @intFromEnum(val)));
                },
                .Void => try self.writer.writeAll("{}"),
                .Pointer => |Pointer| {
                    const child_type = switch (@typeInfo(Pointer.child)) {
                        .Array => |Array| Array.child,
                        else => if (Pointer.size != .Slice) @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify pointer to this type") else Pointer.child,
                    };
                    if (child_type == u8 and !options.emit_strings_as_containers) {
                        try self.string(val);
                    } else {
                        try self.sliceImpl(val, options);
                    }
                },
                .Array => {
                    var container = try self.startTuple(.{ .whitespace_style = .{ .fields = val.len } });
                    for (val) |item_val| {
                        try container.fieldUnchecked(item_val, options);
                    }
                    try container.finish();
                },
                .Struct => |StructInfo| if (StructInfo.is_tuple) {
                    var container = try self.startTuple(.{ .whitespace_style = .{ .fields = StructInfo.fields.len } });
                    inline for (val) |field_value| {
                        try container.fieldUnchecked(field_value, options);
                    }
                    try container.finish();
                } else {
                    // Decide which fields to emit
                    const fields, const skipped = if (options.emit_default_optional_fields) b: {
                        break :b .{ StructInfo.fields.len, [1]bool{false} ** StructInfo.fields.len};
                    } else b: {
                        var fields = StructInfo.fields.len;
                        var skipped = [1]bool {false} ** StructInfo.fields.len;
                        inline for (StructInfo.fields, &skipped) |field_info, *skip| {
                            if (field_info.default_value) |default_field_value_opaque| {
                                const field_value = @field(val, field_info.name);
                                const default_field_value: *const @TypeOf(field_value) = @ptrCast(@alignCast(default_field_value_opaque));
                                if (std.meta.eql(field_value, default_field_value.*)) {
                                    skip.* = true;
                                    fields -= 1;
                                }
                            }
                        }
                        break :b .{ fields, skipped };
                    };

                    // Emit those fields
                    var container = try self.startStruct(.{ .whitespace_style = .{ .fields = fields } });
                    inline for (StructInfo.fields, skipped) |field_info, skip| {
                        if (!skip) {
                            try container.fieldUnchecked(field_info.name, @field(val, field_info.name), options);
                        }
                    }
                    try container.finish();
                },
                .Union => |Union| if (Union.tag_type == null) {
                    @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify untagged unions");
                } else {
                    var container = try self.startStruct(.{ .whitespace_style = .{ .fields = 1 } });
                    switch (val) {
                        inline else => |pl, tag| try container.fieldUnchecked(@tagName(tag), pl, options),
                    }
                    try container.finish();
                },
                .Optional => if (val) |inner| {
                    try self.valueUnchecked(inner, options);
                } else {
                    try self.writer.writeAll("null");
                },

                else => @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify this type"),
            }
        }

        pub fn int(self: *Self, val: anytype) Writer.Error!void {
            try std.fmt.formatInt(val, 10, .lower, .{}, self.writer);
        }

        pub fn float(self: *Self, val: anytype) Writer.Error!void {
            try std.fmt.formatFloatDecimal(val, .{}, self.writer);
        }

        fn identNeedsEscape(name: []const u8) bool {
            std.debug.assert(name.len != 0);
            for (name, 0..) |c, i| {
                switch (c) {
                    'A'...'Z', 'a'...'z', '_' => {},
                    '0'...'9' => if (i == 0) return true,
                    else => return true,
                }
            }
            return std.zig.Token.keywords.has(name);
        }

        pub fn ident(self: *Self, name: []const u8) Writer.Error!void {
            if (identNeedsEscape(name)) {
                try self.writer.writeAll("@\"");
                try self.writer.writeAll(name);
                try self.writer.writeByte('"');
            } else {
                try self.writer.writeAll(name);
            }
        }

        pub fn utf8Codepoint(self: *Self, val: u21) (Writer.Error || error{InvalidCodepoint})!void {
            var buf: [8]u8 = undefined;
            const len = std.unicode.utf8Encode(val, &buf) catch return error.InvalidCodepoint;
            const str = buf[0..len];
            try std.fmt.format(self.writer, "'{'}'", .{std.zig.fmtEscapes(str)});
        }

        pub fn slice(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            comptimeAssertNoRecursion(@TypeOf(val));
            try self.sliceImpl(val, options);
        }

        pub fn sliceDepthLimit(self: *Self, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
            try checkValueDepth(val, depth);
            try self.sliceImpl(val, options, depth);
        }

        fn sliceImpl(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            var container = try self.startSlice(.{ .whitespace_style = .{ .fields = val.len } });
            for (val) |item_val| {
                try container.itemUnchecked(item_val, options);
            }
            try container.finish();
        }

        pub fn string(self: *Self, val: []const u8) Writer.Error!void {
            try std.fmt.format(self.writer, "\"{}\"", .{std.zig.fmtEscapes(val)});
        }

        pub const MultilineStringOptions = struct {
            top_level: bool = false,
        };

        pub const MultilineStringError = Writer.Error || error { InnerCarriageReturn };

        pub fn multilineString(self: *Self, val: []const u8, options: MultilineStringOptions) MultilineStringError!void {
            // Make sure the string does not contain any carriage returns not followed by a newline
            var i: usize = 0;
            while (i < val.len) : (i += 1) {
                if (val[i] == '\r') {
                    if (i + 1 < val.len) {
                        if (val[i + 1] == '\n') {
                            i += 1;
                            continue;
                        }
                    }
                    return error.InnerCarriageReturn;
                }
            }

            if (!options.top_level) {
                try self.newline();
                try self.indent();
            }

            try self.writer.writeAll("\\\\");
            for (val) |c| {
                if (c != '\r') {
                    try self.writer.writeByte(c); // We write newlines here even if whitespace off
                    if (c == '\n') {
                        try self.indent();
                        try self.writer.writeAll("\\\\");
                    }
                }
            }

            if (!options.top_level) {
                try self.writer.writeByte('\n'); // Even if whitespace off
                try self.indent();
            }
        }

        pub fn startStruct(self: *Self, options: StringifyContainerOptions) Writer.Error!Struct {
            return Struct.start(self, options);
        }

        pub fn startTuple(self: *Self, options: StringifyContainerOptions) Writer.Error!Tuple {
            return Tuple.start(self, options);
        }

        pub fn startSlice(self: *Self, options: StringifyContainerOptions) Writer.Error!Slice {
            return Slice.start(self, options);
        }

        fn indent(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByteNTimes(' ', 4 * self.indent_level);
            }
        }

        fn newline(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByte('\n');
            }
        }

        fn newlineOrSpace(self: *Self, len: usize) Writer.Error!void {
            if (self.containerShouldWrap(len)) {
                try self.newline();
            } else {
                try self.space();
            }
        }

        fn space(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByte(' ');
            }
        }

        pub const Tuple = struct {
            container: Container,

            pub fn start(stringifier: *Self, options: StringifyContainerOptions) Writer.Error!Tuple {
                return .{
                    .container = try Container.start(stringifier, .anon, options),
                };
            }

            pub fn finish(self: *Tuple) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            pub fn fieldPrefix(self: *Tuple) Writer.Error!void {
                try self.container.fieldPrefix(null);
            }

            pub fn field(self: *Tuple, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(null, val, options);
            }

            pub fn fieldMaxDepth(self: *Tuple, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(null, val, options,  depth);
            }

            pub fn fieldUnchecked(self: *Tuple, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldUnchecked(null, val, options);
            }
        };

        pub const Struct = struct {
            container: Container,

            pub fn start(stringifier: *Self, options: StringifyContainerOptions) Writer.Error!Struct {
                return .{
                    .container = try Container.start(stringifier, .named, options),
                };
            }

            pub fn finish(self: *Struct) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            pub fn fieldPrefix(self: *Struct, name: []const u8) Writer.Error!void {
                try self.container.fieldPrefix(name);
            }

            pub fn field(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(name, val, options);
            }

            pub fn fieldMaxDepth(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(name, val, options, depth);
            }

            pub fn fieldUnchecked(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldUnchecked(name, val, options);
            }
        };

        pub const Slice = struct {
            container: Container,

            pub fn start(stringifier: *Self, options: StringifyContainerOptions) Writer.Error!Slice {
                try stringifier.writer.writeByte('&');
                return .{
                    .container = try Container.start(stringifier, .anon, options),
                };
            }

            pub fn finish(self: *Slice) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            pub fn itemPrefix(self: *Slice) Writer.Error!void {
                try self.container.fieldPrefix(null);
            }

            pub fn item(self: *Slice, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(null, val, options);
            }

            pub fn itemMaxDepth(self: *Slice, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(null, val, options, depth);
            }

            pub fn itemUnchecked(self: *Slice, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldUnchecked(null, val, options);
            }
        };

        const Container = struct {
            const FieldStyle = enum { named, anon };

            stringifier: *Self,
            field_style: FieldStyle,
            options: StringifyContainerOptions,
            empty: bool,

            fn start(stringifier: *Self, field_style: FieldStyle, options: StringifyContainerOptions) Writer.Error!Container {
                if (options.shouldWrap()) stringifier.indent_level +|= 1;
                try stringifier.writer.writeAll(".{");
                return .{
                    .stringifier = stringifier,
                    .field_style = field_style,
                    .options = options,
                    .empty = true,
                };
            }

            fn finish(self: *Container) Writer.Error!void {
                if (self.options.shouldWrap()) self.stringifier.indent_level -|= 1;
                if (!self.empty) {
                    if (self.options.shouldWrap()) {
                        if (self.stringifier.options.whitespace) {
                            try self.stringifier.writer.writeByte(',');
                        }
                        try self.stringifier.newline();
                        try self.stringifier.indent();
                    } else if (!self.shouldElideSpaces()) {
                        try self.stringifier.space();
                    }
                }
                try self.stringifier.writer.writeByte('}');
                self.* = undefined;
            }

            fn fieldPrefix(self: *Container, name: ?[]const u8) Writer.Error!void {
                if (!self.empty) {
                    try self.stringifier.writer.writeByte(',');
                }
                self.empty = false;
                if (self.options.shouldWrap()) {
                    try self.stringifier.newline();
                } else if (!self.shouldElideSpaces()) {
                    try self.stringifier.space();
                }
                if (self.options.shouldWrap()) try self.stringifier.indent();
                if (name) |n| {
                    try self.stringifier.writer.writeByte('.');
                    try self.stringifier.ident(n);
                    try self.stringifier.space();
                    try self.stringifier.writer.writeByte('=');
                    try self.stringifier.space();
                }
            }

            fn field(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                comptimeAssertNoRecursion(@TypeOf(val));
                try self.fieldUnchecked(name, val, options);
            }

            fn fieldMaxDepth(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try checkValueDepth(val, depth);
                try self.fieldUnchecked(name, val, options);
            }

            fn fieldUnchecked(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.fieldPrefix(name);
                try self.stringifier.valueUnchecked(val, options);
            }

            fn shouldElideSpaces(self: *const Container) bool {
                return switch (self.options.whitespace_style) {
                    .fields => |fields| self.field_style != .named and fields == 1,
                    else => false,
                };
            }
        };

        fn comptimeAssertNoRecursion(comptime T: type) void {
            if (comptime typeIsRecursive(T)) {
                @compileError(@typeName(T) ++ ": recursive type stringified without depth limit");
            }
        }
    };
}

fn expectStringifyEqual(expected: []const u8, value: anytype, comptime options: StringifyOptions) !void {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try stringify(value, options, buf.writer());
    try std.testing.expectEqualStrings(expected, buf.items);
}

test "stringify whitespace, high level API" {
    try expectStringifyEqual(".{}", .{}, .{});
    try expectStringifyEqual(".{}", .{}, .{ .whitespace = false });

    try expectStringifyEqual(".{1}", .{1}, .{});
    try expectStringifyEqual(".{1}", .{1}, .{ .whitespace = false });

    try expectStringifyEqual(".{1}", @as([1]u32, .{1}), .{});
    try expectStringifyEqual(".{1}", @as([1]u32, .{1}), .{ .whitespace = false });

    try expectStringifyEqual("&.{1}", @as([]const u32, &.{1}), .{});
    try expectStringifyEqual("&.{1}", @as([]const u32, &.{1}), .{ .whitespace = false });

    try expectStringifyEqual(".{ .x = 1 }", .{ .x = 1 }, .{});
    try expectStringifyEqual(".{.x=1}", .{ .x = 1 }, .{ .whitespace = false });

    try expectStringifyEqual(".{ 1, 2 }", .{ 1, 2 }, .{});
    try expectStringifyEqual(".{1,2}", .{ 1, 2 }, .{ .whitespace = false });

    try expectStringifyEqual(".{ 1, 2 }", @as([2]u32, .{ 1, 2 }), .{});
    try expectStringifyEqual(".{1,2}", @as([2]u32, .{ 1, 2 }), .{ .whitespace = false });

    try expectStringifyEqual("&.{ 1, 2 }", @as([]const u32, &.{ 1, 2 }), .{});
    try expectStringifyEqual("&.{1,2}", @as([]const u32, &.{ 1, 2 }), .{ .whitespace = false });

    try expectStringifyEqual(".{ .x = 1, .y = 2 }", .{ .x = 1, .y = 2 }, .{});
    try expectStringifyEqual(".{.x=1,.y=2}", .{ .x = 1, .y = 2 }, .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , .{ 1, 2, 3 }, .{});
    try expectStringifyEqual(".{1,2,3}", .{ 1, 2, 3 }, .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([3]u32, .{ 1, 2, 3 }), .{});
    try expectStringifyEqual(".{1,2,3}", @as([3]u32, .{ 1, 2, 3 }), .{ .whitespace = false });

    try expectStringifyEqual(
        \\&.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([]const u32, &.{ 1, 2, 3 }), .{});
    try expectStringifyEqual("&.{1,2,3}", @as([]const u32, &.{ 1, 2, 3 }), .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    .x = 1,
        \\    .y = 2,
        \\    .z = 3,
        \\}
    , .{ .x = 1, .y = 2, .z = 3 }, .{});
    try expectStringifyEqual(".{.x=1,.y=2,.z=3}", .{ .x = 1, .y = 2, .z = 3 }, .{ .whitespace = false });

    const Union = union(enum) { a: bool, b: i32, c: u8 };

    try expectStringifyEqual(".{ .b = 1 }", Union{ .b = 1 }, .{});
    try expectStringifyEqual(".{.b=1}", Union{ .b = 1 }, .{ .whitespace = false });

    // Nested indentation where outer object doesn't wrap
    try expectStringifyEqual(
        \\.{ .inner = .{
        \\    1,
        \\    2,
        \\    3,
        \\} }
    , .{ .inner = .{ 1, 2, 3 } }, .{});
}

test "stringify whitespace, low level API" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

    inline for (.{ true, false }) |whitespace| {
        stringifier.options = .{ .whitespace = whitespace };

        // Empty containers
        {
            var container = try stringifier.startStruct(.{});
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{});
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .fields = 0 } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .fields = 0 } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        // Size 1
        {
            var container = try stringifier.startStruct(.{});
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{});
            try container.field(1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            // We get extra spaces here, since we didn't know up front that there would only be one
            // field.
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field(1, .{});
            try container.finish();
            try std.testing.expectEqualStrings(".{1}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        // Size 2
        {
            var container = try stringifier.startStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        // Size 3
        {
            var container = try stringifier.startStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2, .c = 3 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2, 3 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try stringifier.startTuple(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        // Nested objects where the outer container doesn't wrap but the inner containers do
        {
            var container = try stringifier.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("first", .{ 1, 2, 3 }, .{});
            try container.field("second", .{ 4, 5, 6 }, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{ .first = .{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}, .second = .{
                    \\    4,
                    \\    5,
                    \\    6,
                    \\} }
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.first=.{1,2,3},.second=.{4,5,6}}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }
    }
}

test "stringify utf8 codepoints" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

    // Minimal case
    try stringifier.utf8Codepoint('a');
    try std.testing.expectEqualStrings("'a'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.int('a');
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('a', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'a'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('a', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    // Short escaped codepoint
    try stringifier.utf8Codepoint('\n');
    try std.testing.expectEqualStrings("'\\n'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.int('\n');
    try std.testing.expectEqualStrings("10", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('\n', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'\\n'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('\n', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("10", buffer.items);
    buffer.clearRetainingCapacity();

    // Large codepoint
    try stringifier.utf8Codepoint('⚡');
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.int('⚡');
    try std.testing.expectEqualStrings("9889", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('⚡', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value('⚡', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("9889", buffer.items);
    buffer.clearRetainingCapacity();

    // Invalid codepoint
    try std.testing.expectError(error.InvalidCodepoint, stringifier.utf8Codepoint(0x110000 + 1));

    try stringifier.int(0x110000 + 1);
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value(0x110000 + 1, .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value(0x110000 + 1, .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    // Valid codepoint, not a codepoint type
    try stringifier.value(@as(u22, 'a'), .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value(@as(i32, 'a'), .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    // Make sure value options are passed to children
    try stringifier.value(.{ .c = '⚡' }, .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings(".{ .c = '\\xe2\\x9a\\xa1' }", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value(.{ .c = '⚡' }, .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings(".{ .c = 9889 }", buffer.items);
    buffer.clearRetainingCapacity();
}

test "stringify strings" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

    // Minimal case
    try stringifier.string("abc⚡\n");
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.slice("abc⚡\n", .{});
    try std.testing.expectEqualStrings(
        \\&.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value("abc⚡\n", .{});
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value("abc⚡\n", .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\&.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Value options are inherited by children
    try stringifier.value(.{ .str = "abc" }, .{});
    try std.testing.expectEqualStrings(".{ .str = \"abc\" }", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.value(.{ .str = "abc" }, .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\.{ .str = &.{
        \\    97,
        \\    98,
        \\    99,
        \\} }
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Arrays (rather than pointers to arrays) of u8s are not considered strings, so that data can round trip
    // correctly.
    try stringifier.value("abc".*, .{});
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();
}

test "stringify multiline strings" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer();
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

    {
        try stringifier.multilineString("", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("abc⚡", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\abc⚡", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("abc⚡\ndef", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("abc⚡\r\ndef", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("\nabc⚡", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("\r\nabc⚡", .{.top_level = true});
        try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try stringifier.multilineString("abc\ndef", .{});
        try std.testing.expectEqualStrings("\n\\\\abc\n\\\\def\n", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        const str: []const u8 = &.{'a', '\r', 'c'};
        try stringifier.string(str);
        try std.testing.expectEqualStrings("\"a\\rc\"", buf.items);
        buf.clearRetainingCapacity();
    }

    {
        try std.testing.expectError(error.InnerCarriageReturn, stringifier.multilineString(@as([]const u8, &.{'a', '\r', 'c'}), .{}));
        try std.testing.expectError(error.InnerCarriageReturn, stringifier.multilineString(@as([]const u8, &.{'a', '\r', 'c', '\n'}), .{}));
        try std.testing.expectError(error.InnerCarriageReturn, stringifier.multilineString(@as([]const u8, &.{'a', '\r', 'c', '\r', '\n'}), .{}));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }
}

test "stringify skip default fields" {
    const Struct = struct {
        x: i32 = 2,
        y: i8,
        z: u32 = 4,
        inner1: struct { a: u8 = 'z', b: u8 = 'y', c: u8 } = .{
            .a = '1',
            .b = '2',
            .c = '3',
        },
        inner2: struct { u8, u8, u8 } = .{
            'a',
            'b',
            'c',
        },
        inner3: struct { u8, u8, u8 } = .{
            'a',
            'b',
            'c',
        },
    };

    // Not skipping if not set
    try expectStringifyEqual(
        \\.{
        \\    .x = 2,
        \\    .y = 3,
        \\    .z = 4,
        \\    .inner1 = .{
        \\        .a = '1',
        \\        .b = '2',
        \\        .c = '3',
        \\    },
        \\    .inner2 = .{
        \\        'a',
        \\        'b',
        \\        'c',
        \\    },
        \\    .inner3 = .{
        \\        'a',
        \\        'b',
        \\        'd',
        \\    },
        \\}
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = '1',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{ .emit_utf8_codepoints = true },
    );

    // Top level defaults
    try expectStringifyEqual(
        \\.{ .y = 3, .inner3 = .{
        \\    'a',
        \\    'b',
        \\    'd',
        \\} }
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = '1',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{
            .emit_default_optional_fields = false,
            .emit_utf8_codepoints = true,
        },
    );

    // Inner types having defaults, and defaults changing the number of fields affecting the formatting
    try expectStringifyEqual(
        \\.{
        \\    .y = 3,
        \\    .inner1 = .{ .b = '2', .c = '3' },
        \\    .inner3 = .{
        \\        'a',
        \\        'b',
        \\        'd',
        \\    },
        \\}
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = 'z',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{
            .emit_default_optional_fields = false,
            .emit_utf8_codepoints = true,
        },
    );

    const DefaultStrings = struct {
        foo: []const u8 = "abc",
    };
    try expectStringifyEqual(
        \\.{}
        , DefaultStrings { .foo = "abc" },
        .{.emit_default_optional_fields = false},
    );
    try expectStringifyEqual(
        \\.{ .foo = "abcd" }
        , DefaultStrings { .foo = "abcd" },
        .{.emit_default_optional_fields = false},
    );
}

test "depth limits" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    const Recurse = struct { r: []const @This() };

    // Normal operation
    try stringifyMaxDepth(.{ 1, .{ 2, 3 } }, .{}, buf.writer(), 16);
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    try stringifyUnchecked(.{ 1, .{ 2, 3 } }, .{}, buf.writer());
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    // Max depth failing on non recursive type
    try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(.{ 1, .{ 2, .{ 3, 4 } } }, .{}, buf.writer(), 3));
    try std.testing.expectEqualStrings("", buf.items);
    buf.clearRetainingCapacity();

    // Max depth passing on recursive type
    {
        const maybe_recurse = Recurse { .r = &.{} };
        try stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2);
        try std.testing.expectEqualStrings(".{ .r = &.{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Unchecked passing on recursive type
    {
        const maybe_recurse = Recurse { .r = &.{} };
        try stringifyUnchecked(maybe_recurse, .{}, buf.writer());
        try std.testing.expectEqualStrings(".{ .r = &.{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to depth
    {
        var maybe_recurse = Recurse { .r = &.{} };
        maybe_recurse.r = &.{ .{ .r = &.{} } };
        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Same but for a slice
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // A slice succeeding
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        const maybe_recurse: []const Recurse = &temp;

        try stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 3);
        try std.testing.expectEqualStrings("&.{.{ .r = &.{} }}", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to recursion
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        temp[0].r = &temp;
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 128));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth on the lower level API
    {
        const writer = buf.writer();
        var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

        const maybe_recurse: []const Recurse = &.{};

        try std.testing.expectError(error.MaxDepth, stringifier.valueMaxDepth(1, .{}, 0));
        try stringifier.valueMaxDepth(2, .{}, 1);
        try stringifier.value(3, .{});
        try stringifier.valueUnchecked(maybe_recurse, .{});

        var s = try stringifier.startStruct(.{});
        try std.testing.expectError(error.MaxDepth, s.fieldMaxDepth("a", 1, .{}, 0));
        try s.fieldMaxDepth("b", 4, .{}, 1);
        try s.field("c", 5, .{});
        try s.fieldUnchecked("d", maybe_recurse, .{});
        try s.finish();

        var t = try stringifier.startTuple(.{});
        try std.testing.expectError(error.MaxDepth, t.fieldMaxDepth(1, .{}, 0));
        try t.fieldMaxDepth(6, .{}, 1);
        try t.field(7, .{});
        try t.fieldUnchecked(maybe_recurse, .{});
        try t.finish();

        var a = try stringifier.startSlice(.{});
        try std.testing.expectError(error.MaxDepth, a.itemMaxDepth(1, .{}, 0));
        try a.itemMaxDepth(8, .{}, 1);
        try a.item(9, .{});
        try a.itemUnchecked(maybe_recurse, .{});
        try a.finish();

        try std.testing.expectEqualStrings(
            \\23&.{}.{
            \\    .b = 4,
            \\    .c = 5,
            \\    .d = &.{},
            \\}.{
            \\    6,
            \\    7,
            \\    &.{},
            \\}&.{
            \\    8,
            \\    9,
            \\    &.{},
            \\}
        , buf.items);
    }
}

test "stringify primitives" {
    try expectStringifyEqual(
        \\.{
        \\    .a = 1.5,
        \\    .b = 0.3333333333333333,
        \\    .c = 3.141592653589793,
        \\    .d = 0,
        \\    .e = -0,
        \\    .f = inf,
        \\    .g = -inf,
        \\    .h = nan,
        \\}
        , .{
            .a = 1.5,
            .b = 1.0 / 3.0,
            .c = std.math.pi,
            .d = 0.0,
            .e = -0.0,
            .f = std.math.inf(f32),
            .g = -std.math.inf(f32),
            .h = std.math.nan(f32),
        },
        .{},
    );

    try expectStringifyEqual(
        \\.{
        \\    .a = 18446744073709551616,
        \\    .b = -18446744073709551616,
        \\    .c = 680564733841876926926749214863536422912,
        \\    .d = -680564733841876926926749214863536422912,
        \\    .e = 0,
        \\}
        , .{
            .a = 18446744073709551616,
            .b = -18446744073709551616,
            .c = 680564733841876926926749214863536422912,
            .d = -680564733841876926926749214863536422912,
            .e = 0,
        },
        .{},
    );

    try expectStringifyEqual(
        \\.{
        \\    .a = true,
        \\    .b = false,
        \\    .c = .foo,
        \\    .d = {},
        \\    .e = null,
        \\}
        , .{
            .a = true,
            .b = false,
            .c = .foo,
            .d = {},
            .e = null,
        },
        .{},
    );

    const Struct = struct { x: f32, y: f32 };
    try expectStringifyEqual(
        ".{ .a = .{ .x = 1, .y = 2 }, .b = null }"
        , .{
            .a = @as(?Struct, .{ .x = 1, .y = 2 }),
            .b = @as(?Struct, null),
        },
        .{},
    );

    const E = enum (u8) {
        foo,
        bar,
        _
    };
    try expectStringifyEqual(
        \\.{
        \\    .a = .foo,
        \\    .b = .foo,
        \\    .c = 10,
        \\}
        , .{
            .a = .foo,
            .b = E.foo,
            .c = @as(E, @enumFromInt(10)),
        },
        .{},
    );
}

test "stringify ident" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var stringifier = Stringifier(@TypeOf(writer)).init(writer, .{});

    try stringifier.ident("a");
    try std.testing.expectEqualStrings("a", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("foo_1");
    try std.testing.expectEqualStrings("foo_1", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("_foo_1");
    try std.testing.expectEqualStrings("_foo_1", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("foo bar");
    try std.testing.expectEqualStrings("@\"foo bar\"", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("1foo");
    try std.testing.expectEqualStrings("@\"1foo\"", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("var");
    try std.testing.expectEqualStrings("@\"var\"", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("true");
    try std.testing.expectEqualStrings("true", buffer.items);
    buffer.clearRetainingCapacity();

    try stringifier.ident("_");
    try std.testing.expectEqualStrings("_", buffer.items);
    buffer.clearRetainingCapacity();

    const Enum = enum {
        @"foo bar",
    };
    try expectStringifyEqual(".{ .@\"var\" = .@\"foo bar\", .@\"1\" = .@\"foo bar\" }", .{
        .@"var" = .@"foo bar",
        .@"1" = Enum.@"foo bar",
    }, .{});
}
