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

pub const Error = error{ OutOfMemory, Type };

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

pub fn parseFromAst(comptime T: type, gpa: Allocator, ast: *const Ast, err: ?*Status, options: ParseOptions) Error!T {
    var parser = Parser{
        .gpa = gpa,
        .ast = ast,
        .status = err,
        .options = options,
    };
    const data = ast.nodes.items(.data);
    // TODO: why lhs here?
    const root = data[0].lhs;
    return parser.parseExpr(T, root);
}

test "error literals" {
    // TODO: can't return error!error, i think, so we need to use an out param, or not support this...
    // const gpa = std.testing.allocator;
    // const parsed = try parseFromSlice(anyerror, gpa, "error.Foo");
    // try std.testing.expectEqual(error.Foo, parsed);
}

pub fn parseFromSlice(comptime T: type, gpa: Allocator, source: [:0]const u8, options: ParseOptions) Error!T {
    var ast = try std.zig.Ast.parse(gpa, source, .zon);
    defer ast.deinit(gpa);
    assert(ast.errors.len == 0);
    return parseFromAst(T, gpa, &ast, null, options);
}

pub fn parseFree(gpa: Allocator, value: anytype) void {
    const Value = @TypeOf(value);

    switch (@typeInfo(Value)) {
        .Bool, .Int, .Float, .Enum => {},
        .Pointer => |Pointer| {
            switch (Pointer.size) {
                .One, .Many, .C => failFreeType(Value),
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
        .Union => switch (value) {
            inline else => |_, tag| {
                parseFree(gpa, @field(value, @tagName(tag)));
            },
        },
        .Optional => if (value) |some| {
            parseFree(gpa, some);
        },
        .Void => {},
        .Null => {},
        // TODO: ...
        else => failFreeType(Value),
    }
}

fn parseExpr(self: *Parser, comptime T: type, node: NodeIndex) Error!T {
    // TODO: keep in sync with parseFree
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
        // .Null => return self.parseNull(node),

        else => failToParseType(T),
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

fn parseNull(self: *Parser, node: NodeIndex) error{Type}!void {
    const tags = self.ast.nodes.items(.tag);
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    switch (tags[node]) {
        .identifier => {
            const bytes = self.ast.tokenSlice(token);
            if (std.mem.eql(u8, bytes, "void")) {
                return true;
            }
        },
        else => {},
    }
    return self.failExpectedType(void, node);
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

    // XXX: will this fail properly comptime?
    // Brackets around values (will eventually be parser error)
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

// XXX: what's going on here?
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
        failToParseType(T);
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
        .One, .Many, .C => failToParseType(T),
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
                failToParseType(T);
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
        .Array => |Array| {
            if (Array.sentinel) |sentinel| {
                if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
                    return self.failExpectedType(T, node);
                }
            }

            if (Array.child != u8) {
                return self.failExpectedType(T, node);
            }

            const data = self.ast.nodes.items(.data);
            const literal = data[node].lhs;
            const main_tokens = self.ast.nodes.items(.main_token);
            const token = main_tokens[literal];
            const raw = self.ast.tokenSlice(token);

            // TODO: are undefined zero terminated arrays still terminated?
            var result: T = undefined;
            var fsw = std.io.fixedBufferStream(&result);
            const status = std.zig.string_literal.parseWrite(fsw.writer(), raw) catch |e| switch (e) {
                error.NoSpaceLeft => return self.failExpectedType(T, node),
            };
            switch (status) {
                .success => {},
                .failure => |reason| return self.failInvalidStringLiteral(literal, reason),
            }
            if (Array.len != fsw.pos) {
                return self.failExpectedType(T, node);
            }

            return result;
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
        try std.testing.expectEqualSlices(u8, @as([]const u8, "abc"), parsed);
    }

    // String literal with escape characters
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"ab\\nc\"", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualSlices(u8, @as([]const u8, "ab\nc"), parsed);
    }

    // Passing string literal to a mutable slice
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

    // Zero termianted slices
    {
        const parsed: [:0]const u8 = try parseFromSlice([:0]const u8, gpa, "\"abc\"", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualSlices(u8, "abc", parsed);
        try std.testing.expectEqual(@as(u8, 0), parsed[3]);
    }

    // Other value terminated slices
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

    // Bad alignment
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

    // TODO: ...
    // // Multi line strins
    // {
    //     const parsed = try parseFromSlice([]const u8, gpa, "\\foo\\bar", .{});
    //     defer parseFree(gpa, parsed);
    //     try std.testing.expectEqualSlices(u8, "foo\nbar", parsed);
    // }
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(Enum));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(Enum));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(Enum));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(Enum));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(Enum));
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
        try std.testing.expectEqualSlices(u8, status.unsupported_builtin.name, "@fooBarBaz");
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

fn failToParseType(comptime T: type) noreturn {
    @compileError("Unable to parse into type '" ++ @typeName(T) ++ "'");
}

fn failFreeType(comptime T: type) noreturn {
    @compileError("Unable to free type '" ++ @typeName(T) ++ "'");
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(i66));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(i66));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(u8));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(i8));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(u8));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(u8));
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
        try std.testing.expectEqualSlices(u8, status.cannot_represent.name, @typeName(u8));
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
