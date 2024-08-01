const std = @import("std");
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;
const NodeIndex = std.zig.Ast.Node.Index;
const TokenIndex = std.zig.Ast.TokenIndex;
const Base = std.zig.number_literal.Base;
const StringLiteralError = std.zig.string_literal.Error;
const NumberLiteralError = std.zig.number_literal.Error;
const assert = std.debug.assert;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

gpa: Allocator,
ast: *const Ast,
status: ?*ParseStatus,
ident_buf: []u8,

/// Configuration for the runtime parser.
pub const ParseOptions = struct {
    /// If true, unknown fields do not error.
    ignore_unknown_fields: bool = false,
    /// If true, the parser cleans up partially parsed values on error. This requires some extra
    /// bookkeeping, so you may want to turn it off if you don't need this feature (e.g. because
    /// you're using arena allocation.)
    free_on_error: bool = true,
};

/// Information about the success or failure of a parse.
pub const ParseStatus = union {
    success: void,
    failure: ParseFailure,
};

/// Information about a parse failure for presentation to the user via the format functions.
pub const ParseFailure = struct {
    ast: *const Ast,
    token: TokenIndex,
    reason: Reason,

    const Reason = union(enum) {
        out_of_memory: void,
        expected_union: void,
        expected_struct: void,
        expected_primitive: struct { type_name: []const u8 },
        expected_enum: void,
        expected_tuple_with_fields: struct {
            fields: usize,
        },
        expected_tuple: void,
        expected_string: void,
        cannot_represent: struct { type_name: []const u8 },
        negative_integer_zero: void,
        invalid_string_literal: struct {
            err: StringLiteralError,
        },
        invalid_number_literal: struct {
            err: NumberLiteralError,
        },
        unexpected_field: struct {
            fields: []const []const u8,
        },
        missing_field: struct {
            field_name: []const u8,
        },
        duplicate_field: void,
        type_expr: void,
        address_of: void,
    };

    pub fn fmtLocation(self: *const @This()) std.fmt.Formatter(formatLocation) {
        return .{ .data = self };
    }

    fn formatLocation(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        const l = self.ast.tokenLocation(0, self.token);
        const offset = switch (self.reason) {
            .invalid_string_literal => |r| r.err.offset(),
            .invalid_number_literal => |r| r.err.offset(),
            else => 0,
        };
        try writer.print("{}:{}", .{ l.line + 1, l.column + 1 + offset });
    }

    pub fn fmtError(self: *const @This()) std.fmt.Formatter(formatError) {
        return .{ .data = self };
    }

    fn formatError(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        return switch (self.reason) {
            .out_of_memory => writer.writeAll("out of memory"),
            .expected_union => writer.writeAll("expected union"),
            .expected_struct => writer.writeAll("expected struct"),
            .expected_primitive => |r| writer.print("expected {s}", .{r.type_name}),
            .expected_enum => writer.writeAll("expected enum literal"),
            .expected_tuple_with_fields => |r| {
                const plural = if (r.fields == 1) "" else "s";
                try writer.print("expected tuple with {} field{s}", .{ r.fields, plural });
            },
            .expected_tuple => writer.writeAll("expected tuple"),
            .expected_string => writer.writeAll("expected string"),
            .cannot_represent => |r| writer.print("{s} cannot represent value", .{r.type_name}),
            .negative_integer_zero => writer.writeAll("integer literal '-0' is ambiguous"),
            .invalid_string_literal => |r| writer.print("{}", .{r.err.fmtWithSource(self.ast.tokenSlice(self.token))}),
            .invalid_number_literal => |r| writer.print("{}", .{r.err.fmtWithSource(self.ast.tokenSlice(self.token))}),
            .unexpected_field => |r| {
                try writer.writeAll("unexpected field, ");
                if (r.fields.len == 0) {
                    try writer.writeAll("no fields expected");
                } else {
                    try writer.writeAll("supported fields: ");
                    for (0..r.fields.len) |i| {
                        if (i != 0) try writer.writeAll(", ");
                        try writer.print("{}", .{std.zig.fmtId(r.fields[i])});
                    }
                }
            },
            .missing_field => |r| writer.print("missing required field {s}", .{r.field_name}),
            .duplicate_field => writer.writeAll("duplicate field"),
            .type_expr => writer.writeAll("ZON cannot contain type expressions"),
            .address_of => writer.writeAll("ZON cannot take the address of a value"),
        };
    }

    pub fn noteCount(self: *const @This()) usize {
        switch (self.reason) {
            .invalid_number_literal => |r| {
                const source = self.ast.tokenSlice(self.token);
                return if (r.err.noteWithSource(source) != null) 1 else 0;
            },
            else => return 0,
        }
    }

    const FormatNote = struct {
        failure: *const ParseFailure,
        index: usize,
    };

    pub fn fmtNote(self: *const @This(), index: usize) std.fmt.Formatter(formatNote) {
        return .{ .data = .{ .failure = self, .index = index } };
    }

    fn formatNote(
        self: FormatNote,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        switch (self.failure.reason) {
            .invalid_number_literal => |r| {
                std.debug.assert(self.index == 0);
                const source = self.failure.ast.tokenSlice(self.failure.token);
                try writer.writeAll(r.err.noteWithSource(source).?);
                return;
            },
            else => {},
        }

        unreachable;
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{}: {}", .{ self.fmtLocation(), self.fmtError() });
    }
};

test "std.zon failure/oom formatting" {
    const gpa = std.testing.allocator;

    // Generate a failure
    var ast = try std.zig.Ast.parse(gpa, "\"foo\"", .zon);
    defer ast.deinit(gpa);
    var failing_allocator = std.testing.FailingAllocator.init(gpa, .{
        .fail_index = 0,
        .resize_fail_index = 0,
    });
    var status: ParseStatus = undefined;
    try std.testing.expectError(error.OutOfMemory, parseFromAst(
        []const u8,
        failing_allocator.allocator(),
        &ast,
        &status,
        .{},
    ));

    // Verify that we can format the entire failure.
    const full = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
    defer gpa.free(full);
    try std.testing.expectEqualStrings("1:1: out of memory", full);
    try std.testing.expectEqual(0, status.failure.noteCount());

    // Verify that we can format the location by itself
    const location = try std.fmt.allocPrint(gpa, "{}", .{status.failure.fmtLocation()});
    defer gpa.free(location);
    try std.testing.expectEqualStrings("1:1", location);

    // Verify that we can format the reason by itself
    const reason = try std.fmt.allocPrint(gpa, "{}", .{status.failure.fmtError()});
    defer std.testing.allocator.free(reason);
    try std.testing.expectEqualStrings("out of memory", reason);
}

/// Parses the given ZON source.
///
/// Returns `error.OutOfMemory` on allocator failure, a `error.Type` error if the ZON could not be
/// deserialized into `T`, or `error.Syntax` error if the ZON was invalid.
///
/// If detailed failure information is needed, see `parseFromAst`.
pub fn parseFromSlice(
    /// The type to deserialize into. May only transitively contain the following supported types:
    /// * bools
    /// * fixed sized numeric types
    /// * enums
    /// * slices
    /// * arrays
    /// * structures
    /// * unions
    /// * optionals
    /// * null
    comptime T: type,
    /// The allocator. Used to temporarily allocate an AST, and to allocate any parts of `T` that
    /// require dynamic allocation.
    gpa: Allocator,
    /// The ZON source.
    source: [:0]const u8,
    /// Options for the parser.
    comptime options: ParseOptions,
) error{ OutOfMemory, Type, Syntax }!T {
    if (@inComptime()) {
        // Happens if given e.g. @typeOf(null), the default error we get is hard
        // to understand.
        @compileError("Runtime parser cannot run at comptime.");
    }
    var ast = try std.zig.Ast.parse(gpa, source, .zon);
    defer ast.deinit(gpa);
    if (ast.errors.len != 0) return error.Syntax;
    return parseFromAst(T, gpa, &ast, null, options);
}

test "std.zon parseFromSlice syntax error" {
    try std.testing.expectError(error.Syntax, parseFromSlice(u8, std.testing.allocator, ".{", .{}));
}

/// Like `parseFromSlice`, but operates on an AST instead of on ZON source. Asserts that the AST's
/// `errors` field is empty.
///
/// Returns `error.OutOfMemory` if allocation fails, or `error.Type` if the ZON could not be
/// deserialized into `T`.
///
/// If `status` is not null, its success field will be set on success, and its failure field will be
/// set on failure. See `ParseFailure` for formatting ZON parse failures in a  human readable
/// manner. For formatting AST errors, see `std.zig.Ast.renderError`.
pub fn parseFromAst(comptime T: type, gpa: Allocator, ast: *const Ast, status: ?*ParseStatus, comptime options: ParseOptions) error{ OutOfMemory, Type }!T {
    assert(ast.errors.len == 0);
    const data = ast.nodes.items(.data);
    const root = data[0].lhs;
    return parseFromAstNode(T, gpa, ast, root, status, options);
}

/// Like `parseFromAst`, but does not take an allocator.
///
/// Asserts at comptime that no value of type `T` requires dynamic allocation.
pub fn parseFromAstNoAlloc(comptime T: type, ast: *const Ast, status: ?*ParseStatus, comptime options: ParseOptions) error{Type}!T {
    assert(ast.errors.len == 0);
    const data = ast.nodes.items(.data);
    const root = data[0].lhs;
    return parseFromAstNodeNoAlloc(T, ast, root, status, options);
}

test "std.zon parseFromAstNoAlloc" {
    var ast = try std.zig.Ast.parse(std.testing.allocator, ".{ .x = 1.5, .y = 2.5 }", .zon);
    defer ast.deinit(std.testing.allocator);
    try std.testing.expectEqual(ast.errors.len, 0);

    const S = struct { x: f32, y: f32 };
    const found = try parseFromAstNoAlloc(S, &ast, null, .{});
    try std.testing.expectEqual(S{ .x = 1.5, .y = 2.5 }, found);
}

/// Like `parseFromAst`, but the parse starts on `node` instead of on the root of the AST.
pub fn parseFromAstNode(comptime T: type, gpa: Allocator, ast: *const Ast, node: NodeIndex, status: ?*ParseStatus, comptime options: ParseOptions) error{ OutOfMemory, Type }!T {
    assert(ast.errors.len == 0);
    var ident_buf: [maxIdentLength(T)]u8 = undefined;
    var parser = @This(){
        .gpa = gpa,
        .ast = ast,
        .status = status,
        .ident_buf = &ident_buf,
    };

    // Attempt the parse, setting status and returning early if it fails
    const result = parser.parseExpr(T, options, node) catch |err| switch (err) {
        error.ParserOutOfMemory => return error.OutOfMemory,
        error.Type => return error.Type,
    };

    // Set status to success and return the result
    if (status) |s| s.* = .{ .success = {} };
    return result;
}

/// Like `parseFromAstNode`, but does not take an allocator.
///
/// Asserts at comptime that no value of type `T` requires dynamic allocation.
pub fn parseFromAstNodeNoAlloc(comptime T: type, ast: *const Ast, node: NodeIndex, status: ?*ParseStatus, comptime options: ParseOptions) error{Type}!T {
    assert(ast.errors.len == 0);
    if (comptime requiresAllocator(T)) {
        @compileError(@typeName(T) ++ ": requires allocator");
    }
    var buffer: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    return parseFromAstNode(T, fba.allocator(), ast, node, status, options) catch |e| switch (e) {
        error.OutOfMemory => unreachable, // No allocations
        else => |other| return other,
    };
}

test "std.zon parseFromAstNode and parseFromAstNodeNoAlloc" {
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
    try std.testing.expectEqual(Vec2{ .x = 1.5, .y = 2.5 }, parsed);
    try std.testing.expectEqual(Vec2{ .x = 1.5, .y = 2.5 }, parsed_no_alloc);
}

fn requiresAllocator(comptime T: type) bool {
    // Keep in sync with parseFree, stringify, and requiresAllocator.
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

test "std.zon requiresAllocator" {
    try std.testing.expect(!requiresAllocator(u8));
    try std.testing.expect(!requiresAllocator(f32));
    try std.testing.expect(!requiresAllocator(enum { foo }));
    try std.testing.expect(!requiresAllocator(struct { f32 }));
    try std.testing.expect(!requiresAllocator(struct { x: f32 }));
    try std.testing.expect(!requiresAllocator([2]u8));
    try std.testing.expect(!requiresAllocator(union { x: f32, y: f32 }));
    try std.testing.expect(!requiresAllocator(union(enum) { x: f32, y: f32 }));
    try std.testing.expect(!requiresAllocator(?f32));
    try std.testing.expect(!requiresAllocator(void));
    try std.testing.expect(!requiresAllocator(@TypeOf(null)));

    try std.testing.expect(requiresAllocator([]u8));
    try std.testing.expect(requiresAllocator(*struct { u8, u8 }));
    try std.testing.expect(requiresAllocator([1][]const u8));
    try std.testing.expect(requiresAllocator(struct { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(union { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(union(enum) { x: i32, y: []u8 }));
    try std.testing.expect(requiresAllocator(?[]u8));
}

fn maxIdentLength(comptime T: type) usize {
    // Keep in sync with `parseExpr`.
    comptime var max = 0;
    switch (@typeInfo(T)) {
        .Bool, .Int, .Float, .Null, .Void => {},
        .Pointer => |Pointer| max = comptime maxIdentLength(Pointer.child),
        .Array => |Array| if (Array.len > 0) {
            max = comptime maxIdentLength(Array.child);
        },
        .Struct => |Struct| inline for (Struct.fields) |field| {
            if (!Struct.is_tuple) {
                max = @max(max, field.name.len);
            }
            max = @max(max, comptime maxIdentLength(field.type));
        },
        .Union => |Union| inline for (Union.fields) |field| {
            max = @max(max, field.name.len);
            max = @max(max, comptime maxIdentLength(field.type));
        },
        .Enum => |Enum| inline for (Enum.fields) |field| {
            max = @max(max, field.name.len);
        },
        .Optional => |Optional| max = comptime maxIdentLength(Optional.child),
        else => unreachable,
    }
    return max;
}

test "std.zon maxIdentLength" {
    // Primitives
    try std.testing.expectEqual(0, maxIdentLength(bool));
    try std.testing.expectEqual(0, maxIdentLength(u8));
    try std.testing.expectEqual(0, maxIdentLength(f32));
    try std.testing.expectEqual(0, maxIdentLength(@TypeOf(null)));
    try std.testing.expectEqual(0, maxIdentLength(void));

    // Arrays
    try std.testing.expectEqual(0, maxIdentLength([0]u8));
    try std.testing.expectEqual(0, maxIdentLength([5]u8));
    try std.testing.expectEqual(3, maxIdentLength([5]struct { abc: f32 }));
    try std.testing.expectEqual(0, maxIdentLength([0]struct { abc: f32 }));

    // Structs
    try std.testing.expectEqual(0, maxIdentLength(struct {}));
    try std.testing.expectEqual(1, maxIdentLength(struct { a: f32, b: f32 }));
    try std.testing.expectEqual(3, maxIdentLength(struct { abc: f32, a: f32 }));
    try std.testing.expectEqual(3, maxIdentLength(struct { a: f32, abc: f32 }));

    try std.testing.expectEqual(1, maxIdentLength(struct { a: struct { a: f32 }, b: struct { a: f32 } }));
    try std.testing.expectEqual(3, maxIdentLength(struct { a: struct { abc: f32 }, b: struct { a: f32 } }));
    try std.testing.expectEqual(3, maxIdentLength(struct { a: struct { a: f32 }, b: struct { abc: f32 } }));

    // Tuples
    try std.testing.expectEqual(0, maxIdentLength(struct { f32, u32 }));
    try std.testing.expectEqual(3, maxIdentLength(struct { struct { a: u32 }, struct { abc: u32 } }));
    try std.testing.expectEqual(3, maxIdentLength(struct { struct { abc: u32 }, struct { a: u32 } }));

    // Unions
    try std.testing.expectEqual(0, maxIdentLength(union {}));

    try std.testing.expectEqual(1, maxIdentLength(union { a: f32, b: f32 }));
    try std.testing.expectEqual(3, maxIdentLength(union { abc: f32, a: f32 }));
    try std.testing.expectEqual(3, maxIdentLength(union { a: f32, abc: f32 }));

    try std.testing.expectEqual(1, maxIdentLength(union { a: union { a: f32 }, b: union { a: f32 } }));
    try std.testing.expectEqual(3, maxIdentLength(union { a: union { abc: f32 }, b: union { a: f32 } }));
    try std.testing.expectEqual(3, maxIdentLength(union { a: union { a: f32 }, b: union { abc: f32 } }));

    // Enums
    try std.testing.expectEqual(0, maxIdentLength(enum {}));
    try std.testing.expectEqual(3, maxIdentLength(enum { a, abc }));
    try std.testing.expectEqual(3, maxIdentLength(enum { abc, a }));
    try std.testing.expectEqual(1, maxIdentLength(enum { a, b }));

    // Optionals
    try std.testing.expectEqual(0, maxIdentLength(?u32));
    try std.testing.expectEqual(3, maxIdentLength(?struct { abc: u32 }));

    // Pointers
    try std.testing.expectEqual(0, maxIdentLength(*u32));
    try std.testing.expectEqual(3, maxIdentLength(*struct { abc: u32 }));
}

/// Frees values created by the runtime parser.
///
/// Provided for convenience, you may also free these values on your own using the same allocator
/// passed into the parser.
///
/// Asserts at comptime that sufficient information is available to free this type of value.
/// Untagged unions, for example, can be parsed but not freed.
pub fn parseFree(gpa: Allocator, value: anytype) void {
    const Value = @TypeOf(value);

    // Keep in sync with parseFree, stringify, and requiresAllocator.
    switch (@typeInfo(Value)) {
        .Bool, .Int, .Float, .Enum => {},
        .Pointer => |Pointer| {
            switch (Pointer.size) {
                .One, .Many, .C => if (comptime requiresAllocator(Value)) {
                    @compileError(@typeName(Value) ++ ": parseFree cannot free non slice pointers");
                },
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
            if (comptime requiresAllocator(Value)) {
                @compileError(@typeName(Value) ++ ": parseFree cannot free untagged unions");
            }
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

fn parseExpr(
    self: *@This(),
    comptime T: type,
    comptime options: ParseOptions,
    node: NodeIndex,
) error{ ParserOutOfMemory, Type }!T {
    // Check for address of up front so we can emit a friendlier error (otherwise it will just say
    // that the type is wrong, which may be confusing.)
    const tags = self.ast.nodes.items(.tag);
    if (tags[node] == .address_of) {
        const main_tokens = self.ast.nodes.items(.main_token);
        const token = main_tokens[node];
        return self.fail(token, .address_of);
    }

    // Keep in sync with parseFree, stringify, and requiresAllocator.
    switch (@typeInfo(T)) {
        .Bool => return self.parseBool(node),
        .Int, .Float => return self.parseNumber(T, node),
        .Enum => return self.parseEnumLiteral(T, node),
        .Pointer => return self.parsePointer(T, options, node),
        .Array => return self.parseArray(T, options, node),
        .Struct => |Struct| if (Struct.is_tuple)
            return self.parseTuple(T, options, node)
        else
            return self.parseStruct(T, options, node),
        .Union => return self.parseUnion(T, options, node),
        .Optional => return self.parseOptional(T, options, node),
        .Void => return self.parseVoid(node),

        else => @compileError(@typeName(T) ++ ": cannot parse this type"),
    }
}

fn parseVoid(self: @This(), node: NodeIndex) error{ ParserOutOfMemory, Type }!void {
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    const tags = self.ast.nodes.items(.tag);
    const data = self.ast.nodes.items(.data);
    switch (tags[node]) {
        .block_two => if (data[node].lhs != 0 or data[node].rhs != 0) {
            return self.fail(token, .{ .expected_primitive = .{ .type_name = "void" } });
        },
        .block => if (data[node].lhs != data[node].rhs) {
            return self.fail(token, .{ .expected_primitive = .{ .type_name = "void" } });
        },
        else => return self.fail(token, .{ .expected_primitive = .{ .type_name = "void" } }),
    }
}

test "std.zon void" {
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(void, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected void", formatted);
    }
}

fn parseOptional(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
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

    return try self.parseExpr(Optional.child, options, node);
}

test "std.zon optional" {
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

fn parseUnion(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
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
        break :b std.StaticStringMap(usize).initComptime(kvs_list);
    };

    // Parse the union
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    const tags = self.ast.nodes.items(.tag);
    if (tags[node] == .enum_literal) {
        // The union must be tagged for an enum literal to coerce to it
        if (Union.tag_type == null) {
            return self.fail(main_tokens[node], .expected_union);
        }

        // Get the index of the named field. We don't use `parseEnum` here as
        // the order of the enum and the order of the union might not match!
        const field_index = b: {
            const bytes = try self.parseIdent(T, token);
            break :b field_indices.get(bytes) orelse
                return self.failUnexpectedField(T, token);
        };

        // Initialize the union from the given field.
        switch (field_index) {
            inline 0...field_infos.len - 1 => |i| {
                // Fail if the field is not void
                if (field_infos[i].type != void)
                    return self.fail(token, .expected_union);

                // Instantiate the union
                return @unionInit(T, field_infos[i].name, {});
            },
            else => unreachable, // Can't be out of bounds
        }
    } else {
        var buf: [2]NodeIndex = undefined;
        const field_nodes = try self.fields(T, &buf, node);

        if (field_nodes.len != 1) {
            return self.fail(token, .expected_union);
        }

        // Fill in the field we found
        const field_node = field_nodes[0];
        const field_token = self.ast.firstToken(field_node) - 2;
        const field_index = b: {
            const name = try self.parseIdent(T, field_token);
            break :b field_indices.get(name) orelse
                return self.failUnexpectedField(T, field_token);
        };

        switch (field_index) {
            inline 0...field_infos.len - 1 => |i| {
                const value = try self.parseExpr(field_infos[i].type, options, field_node);
                return @unionInit(T, field_infos[i].name, value);
            },
            else => unreachable, // Can't be out of bounds
        }
    }
}

test "std.zon unions" {
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:4: unexpected field, supported fields: x, y", formatted);
    }

    // Unknown field with name that's too long for parse
    {
        const Union = union { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.@\"abc\"=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:4: unexpected field, supported fields: x, y", formatted);
    }

    // Extra field
    {
        const Union = union { x: f32, y: bool };
        var ast = try std.zig.Ast.parse(gpa, ".{.x = 1.5, .y = true}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected union", formatted);
    }

    // No fields
    {
        const Union = union { x: f32, y: bool };
        var ast = try std.zig.Ast.parse(gpa, ".{}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected union", formatted);
    }

    // Enum literals cannot coerce into untagged unions
    {
        const Union = union { x: void };
        var ast = try std.zig.Ast.parse(gpa, ".x", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected union", formatted);
    }

    // Unknown field for enum literal coercion
    {
        const Union = union(enum) { x: void };
        var ast = try std.zig.Ast.parse(gpa, ".y", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: unexpected field, supported fields: x", formatted);
    }

    // Unknown field for enum literal coercion that's too long for parse
    {
        const Union = union(enum) { x: void };
        var ast = try std.zig.Ast.parse(gpa, ".@\"abc\"", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: unexpected field, supported fields: x", formatted);
    }

    // Non void field for enum literal coercion
    {
        const Union = union(enum) { x: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".x", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Union, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected union", formatted);
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

fn elements(
    self: @This(),
    comptime T: type,
    buf: *[2]NodeIndex,
    node: NodeIndex,
) error{Type}![]const NodeIndex {
    const main_tokens = self.ast.nodes.items(.main_token);

    // Attempt to parse as an array
    if (self.ast.fullArrayInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(main_tokens[init.ast.type_expr]);
        }
        return init.ast.elements;
    }

    // Attempt to parse as a struct with no fields
    if (self.ast.fullStructInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(main_tokens[init.ast.type_expr]);
        }
        if (init.ast.fields.len == 0) {
            return init.ast.fields;
        }
    }

    // Fail
    return self.failExpectedContainer(T, main_tokens[node]);
}

fn fields(
    self: @This(),
    comptime T: type,
    buf: *[2]NodeIndex,
    node: NodeIndex,
) error{Type}![]const NodeIndex {
    const main_tokens = self.ast.nodes.items(.main_token);

    // Attempt to parse as a struct
    if (self.ast.fullStructInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(main_tokens[init.ast.type_expr]);
        }
        return init.ast.fields;
    }

    // Attempt to parse as a zero length array
    if (self.ast.fullArrayInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.failTypeExpr(main_tokens[init.ast.type_expr]);
        }
        if (init.ast.elements.len != 0) {
            return self.failExpectedContainer(T, main_tokens[node]);
        }
        return init.ast.elements;
    }

    // Fail otherwise
    return self.failExpectedContainer(T, main_tokens[node]);
}

fn parseStruct(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const Struct = @typeInfo(T).Struct;
    const field_infos = Struct.fields;

    // Gather info on the fields
    const field_indices = b: {
        comptime var kvs_list: [field_infos.len]struct { []const u8, usize } = undefined;
        inline for (field_infos, 0..) |field, i| {
            kvs_list[i] = .{ field.name, i };
        }
        break :b std.StaticStringMap(usize).initComptime(kvs_list);
    };

    // Parse the struct
    var buf: [2]NodeIndex = undefined;
    const field_nodes = try self.fields(T, &buf, node);

    var result: T = undefined;
    var field_found: [field_infos.len]bool = .{false} ** field_infos.len;

    // If we fail partway through, free all already initialized fields
    var initialized: usize = 0;
    errdefer if (options.free_on_error and field_infos.len > 0) {
        for (field_nodes[0..initialized]) |initialized_field_node| {
            const name_runtime = self.parseIdent(T, self.ast.firstToken(initialized_field_node) - 2) catch unreachable;
            switch (field_indices.get(name_runtime) orelse continue) {
                inline 0...(field_infos.len - 1) => |name_index| {
                    const name = field_infos[name_index].name;
                    parseFree(self.gpa, @field(result, name));
                },
                else => unreachable, // Can't be out of bounds
            }
        }
    };

    // Fill in the fields we found
    for (field_nodes) |field_node| {
        const name_token = self.ast.firstToken(field_node) - 2;
        const i = b: {
            const name = try self.parseIdent(T, name_token);
            break :b field_indices.get(name) orelse if (options.ignore_unknown_fields) {
                continue;
            } else {
                return self.failUnexpectedField(T, name_token);
            };
        };

        // We now know the array is not zero sized (assert this so the code compiles)
        if (field_found.len == 0) unreachable;

        if (field_found[i]) {
            return self.failDuplicateField(name_token);
        }
        field_found[i] = true;

        switch (i) {
            inline 0...(field_infos.len - 1) => |j| @field(result, field_infos[j].name) = try self.parseExpr(field_infos[j].type, options, field_node),
            else => unreachable, // Can't be out of bounds
        }

        initialized += 1;
    }

    // Fill in any missing default fields
    inline for (field_found, 0..) |found, i| {
        if (!found) {
            const field_info = Struct.fields[i];
            if (field_info.default_value) |default| {
                const typed: *const field_info.type = @ptrCast(@alignCast(default));
                @field(result, field_info.name) = typed.*;
            } else {
                const main_tokens = self.ast.nodes.items(.main_token);
                return self.failMissingField(field_infos[i].name, main_tokens[node]);
            }
        }
    }

    return result;
}

test "std.zon structs" {
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

        const parsed = try parseFromSlice(Foo, gpa, ".{.bar = \"qux\", .baz = .{\"a\", \"b\"}}", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualDeep(Foo{ .bar = "qux", .baz = &.{ "a", "b" } }, parsed);
    }

    // Unknown field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .z=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:12: unexpected field, supported fields: x, y", formatted);
    }

    // Unknown field too long for parse
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .@\"abc\"=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:12: unexpected field, supported fields: x, y", formatted);
    }

    // Duplicate field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .x=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:12: duplicate field", formatted);
    }

    // Ignore unknown fields
    {
        const Vec2 = struct { x: f32, y: f32 = 2.0 };
        const parsed = try parseFromSlice(Vec2, gpa, ".{ .x = 1.0, .z = 3.0 }", .{
            .ignore_unknown_fields = true,
        });
        try std.testing.expectEqual(Vec2{ .x = 1.0, .y = 2.0 }, parsed);
    }

    // Unknown field when struct has no fields (regression test)
    {
        const Vec2 = struct {};
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5, .z=2.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:4: unexpected field, no fields expected", formatted);
    }

    // Missing field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.x=1.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Vec2, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: missing required field y", formatted);
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

            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst(Empty, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: ZON cannot contain type expressions", formatted);
        }

        // Arrays
        {
            var ast = try std.zig.Ast.parse(gpa, "[3]u8{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: ZON cannot contain type expressions", formatted);
        }

        // Slices
        {
            var ast = try std.zig.Ast.parse(gpa, "[]u8{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: ZON cannot contain type expressions", formatted);
        }

        // Tuples
        {
            const Tuple = struct { i32, i32, i32 };
            var ast = try std.zig.Ast.parse(gpa, "Tuple{1, 2, 3}", .zon);
            defer ast.deinit(gpa);

            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: ZON cannot contain type expressions", formatted);
        }
    }
}

fn parseTuple(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const Struct = @typeInfo(T).Struct;
    const field_infos = Struct.fields;

    var result: T = undefined;

    // Parse the struct
    var buf: [2]NodeIndex = undefined;
    const field_nodes = try self.elements(T, &buf, node);

    if (field_nodes.len != field_infos.len) {
        const main_tokens = self.ast.nodes.items(.main_token);
        return self.failExpectedContainer(T, main_tokens[node]);
    }

    inline for (field_infos, field_nodes, 0..) |field_info, field_node, initialized| {
        // If we fail to parse this field, free all fields before it
        errdefer if (options.free_on_error) {
            inline for (0..field_infos.len) |i| {
                if (i >= initialized) break;
                parseFree(self.gpa, result[i]);
            }
        };

        result[initialized] = try self.parseExpr(field_info.type, options, field_node);
    }

    return result;
}

test "std.zon tuples" {
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 2 fields", formatted);
    }

    // Extra field
    {
        const Tuple = struct { f32, bool };
        var ast = try std.zig.Ast.parse(gpa, ".{0.5}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 2 fields", formatted);
    }

    // Tuple with unexpected field names
    {
        const Tuple = struct { f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{.foo = 10.0}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Tuple, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 1 field", formatted);
    }

    // Struct with missing field names
    {
        const Struct = struct { foo: f32 };
        var ast = try std.zig.Ast.parse(gpa, ".{10.0}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Struct, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected struct", formatted);
    }
}

fn parseArray(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const Array = @typeInfo(T).Array;
    // Parse the array
    var array: T = undefined;
    var buf: [2]NodeIndex = undefined;
    const element_nodes = try self.elements(T, &buf, node);

    // Check if the size matches
    if (element_nodes.len != Array.len) {
        const main_tokens = self.ast.nodes.items(.main_token);
        return self.failExpectedContainer(T, main_tokens[node]);
    }

    // Parse the elements and return the array
    for (&array, element_nodes, 0..) |*element, element_node, initialized| {
        // If we fail to parse this field, free all fields before it
        errdefer if (options.free_on_error) {
            for (array[0..initialized]) |initialized_item| {
                parseFree(self.gpa, initialized_item);
            }
        };

        element.* = try self.parseExpr(Array.child, options, element_node);
    }
    return array;
}

// Test sizes 0 to 3 since small sizes get parsed differently
test "std.zon arrays and slices" {
    // Issue: https://github.com/ziglang/zig/issues/20881
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest;

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
            const zero = try parseFromSlice([]const u8, gpa, ".{}", .{});
            defer parseFree(gpa, zero);
            try std.testing.expectEqualSlices(u8, @as([]const u8, &.{}), zero);

            const one = try parseFromSlice([]u8, gpa, ".{'a'}", .{});
            defer parseFree(gpa, one);
            try std.testing.expectEqualSlices(u8, &.{'a'}, one);

            const two = try parseFromSlice([]const u8, gpa, ".{'a', 'b'}", .{});
            defer parseFree(gpa, two);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two);

            const two_comma = try parseFromSlice([]const u8, gpa, ".{'a', 'b',}", .{});
            defer parseFree(gpa, two_comma);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two_comma);

            const three = try parseFromSlice([]u8, gpa, ".{'a', 'b', 'c'}", .{});
            defer parseFree(gpa, three);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, three);

            const sentinel = try parseFromSlice([:'z']const u8, gpa, ".{'a', 'b', 'c'}", .{});
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
            const parsed = try parseFromSlice([]const []const u8, gpa, ".{\"abc\"}", .{});
            defer parseFree(gpa, parsed);
            const expected: []const []const u8 = &.{"abc"};
            try std.testing.expectEqualDeep(expected, parsed);
        }
    }

    // Sentinels and alignment
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
            const sentinel = try parseFromSlice([:2]align(4) u8, gpa, ".{1}", .{});
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([0]u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 0 fields", formatted);
    }

    // Expect 1 find 2
    {
        var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b'}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([1]u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 1 field", formatted);
    }

    // Expect 2 find 1
    {
        var ast = try std.zig.Ast.parse(gpa, ".{'a'}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([2]u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 2 fields", formatted);
    }

    // Expect 3 find 0
    {
        var ast = try std.zig.Ast.parse(gpa, ".{}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected tuple with 3 fields", formatted);
    }

    // Wrong inner type
    {
        // Array
        {
            var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([3]bool, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:3: expected bool", formatted);
        }

        // Slice
        {
            var ast = try std.zig.Ast.parse(gpa, ".{'a', 'b', 'c'}", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]bool, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:3: expected bool", formatted);
        }
    }

    // Complete wrong type
    {
        // Array
        {
            var ast = try std.zig.Ast.parse(gpa, "'a'", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([3]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple with 3 fields", formatted);
        }

        // Slice
        {
            var ast = try std.zig.Ast.parse(gpa, "'a'", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }
    }

    // Address of is not allowed (indirection for slices in ZON is implicit)
    {
        var ast = try std.zig.Ast.parse(gpa, "&.{'a', 'b', 'c'}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([3]bool, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: ZON cannot take the address of a value", formatted);
    }
}

fn parsePointer(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const tags = self.ast.nodes.items(.tag);
    return switch (tags[node]) {
        .string_literal => try self.parseStringLiteral(T, node),
        .multiline_string_literal => try self.parseMultilineStringLiteral(T, node),
        else => self.parseSlice(T, options, node),
    };
}

fn parseSlice(self: *@This(), comptime T: type, comptime options: ParseOptions, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const Ptr = @typeInfo(T).Pointer;
    // Make sure we're working with a slice
    switch (Ptr.size) {
        .Slice => {},
        .One, .Many, .C => @compileError(@typeName(T) ++ ": non slice pointers not supported"),
    }

    // Parse the array literal
    const main_tokens = self.ast.nodes.items(.main_token);
    var buf: [2]NodeIndex = undefined;
    const element_nodes = try self.elements(T, &buf, node);

    // Allocate the slice
    const sentinel = if (Ptr.sentinel) |s| @as(*const Ptr.child, @ptrCast(s)).* else null;
    const slice = self.gpa.allocWithOptions(
        Ptr.child,
        element_nodes.len,
        Ptr.alignment,
        sentinel,
    ) catch |err| switch (err) {
        error.OutOfMemory => return self.failOutOfMemory(main_tokens[node]),
    };
    errdefer self.gpa.free(slice);

    // Parse the elements and return the slice
    for (slice, element_nodes, 0..) |*element, element_node, initialized| {
        errdefer if (options.free_on_error) {
            for (0..initialized) |i| {
                parseFree(self.gpa, slice[i]);
            }
        };
        element.* = try self.parseExpr(Ptr.child, options, element_node);
    }
    return slice;
}

fn parseStringLiteral(self: *@This(), comptime T: type, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const Pointer = @typeInfo(T).Pointer;

    if (Pointer.size != .Slice) {
        @compileError(@typeName(T) ++ ": cannot parse pointers that are not slices");
    }

    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    const raw = self.ast.tokenSlice(token);

    if (Pointer.child != u8 or !Pointer.is_const or Pointer.alignment != 1) {
        return self.failExpectedContainer(T, token);
    }
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(self.gpa);
    const parse_write_result = std.zig.string_literal.parseWrite(
        buf.writer(self.gpa),
        raw,
    ) catch |err| switch (err) {
        error.OutOfMemory => return self.failOutOfMemory(token),
    };
    switch (parse_write_result) {
        .success => {},
        .failure => |reason| return self.failInvalidStringLiteral(token, reason),
    }

    if (Pointer.sentinel) |sentinel| {
        if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
            return self.failExpectedContainer(T, token);
        }
        return buf.toOwnedSliceSentinel(self.gpa, 0) catch |err| switch (err) {
            error.OutOfMemory => return self.failOutOfMemory(token),
        };
    }

    return buf.toOwnedSlice(self.gpa) catch |err| switch (err) {
        error.OutOfMemory => return self.failOutOfMemory(token),
    };
}

fn parseMultilineStringLiteral(self: *@This(), comptime T: type, node: NodeIndex) error{ ParserOutOfMemory, Type }!T {
    const main_tokens = self.ast.nodes.items(.main_token);

    const Pointer = @typeInfo(T).Pointer;

    if (Pointer.size != .Slice) {
        @compileError(@typeName(T) ++ ": cannot parse pointers that are not slices");
    }

    if (Pointer.child != u8 or !Pointer.is_const or Pointer.alignment != 1) {
        return self.failExpectedContainer(T, main_tokens[node]);
    }

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(self.gpa);
    const writer = buf.writer(self.gpa);

    var parser = std.zig.string_literal.multilineParser(writer);
    const data = self.ast.nodes.items(.data);
    var tok_i = data[node].lhs;
    while (tok_i <= data[node].rhs) : (tok_i += 1) {
        const token_slice = self.ast.tokenSlice(tok_i);
        parser.line(token_slice) catch |err| switch (err) {
            error.OutOfMemory => return self.failOutOfMemory(tok_i),
        };
    }

    if (Pointer.sentinel) |sentinel| {
        if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
            return self.failExpectedContainer(T, main_tokens[node]);
        }
        return buf.toOwnedSliceSentinel(self.gpa, 0) catch |err| switch (err) {
            error.OutOfMemory => return self.failOutOfMemory(main_tokens[node]),
        };
    } else {
        return buf.toOwnedSlice(self.gpa) catch |err| switch (err) {
            error.OutOfMemory => return self.failOutOfMemory(main_tokens[node]),
        };
    }
}

test "std.zon string literal" {
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

    // String literal with embedded null
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"ab\\x00c\"", .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "ab\x00c"), parsed);
    }

    // Passing string literal to a mutable slice
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abcd\"", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abcd", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }
    }

    // Passing string literal to a array
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abcd\"", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([4:0]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple with 4 fields", formatted);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abcd", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([4:0]u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple with 4 fields", formatted);
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
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([:1]const u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\foo", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([:1]const u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }
    }

    // Expecting string literal, getting something else
    {
        var ast = try std.zig.Ast.parse(gpa, "true", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([]const u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected string", formatted);
    }

    // Expecting string literal, getting an incompatible tuple
    {
        var ast = try std.zig.Ast.parse(gpa, ".{false}", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([]const u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:3: expected u8", formatted);
    }

    // Invalid string literal
    {
        var ast = try std.zig.Ast.parse(gpa, "\"\\a\"", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst([]const u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:3: invalid escape character: 'a'", formatted);
    }

    // Slice wrong child type
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"a\"", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]const i8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\a", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]const i8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }
    }

    // Bad alignment
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abc\"", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]align(2) const u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }

        {
            var ast = try std.zig.Ast.parse(gpa, "\\\\abc", .zon);
            defer ast.deinit(gpa);
            var status: ParseStatus = undefined;
            try std.testing.expectError(error.Type, parseFromAst([]align(2) const u8, gpa, &ast, &status, .{}));
            const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
            defer gpa.free(formatted);
            try std.testing.expectEqualStrings("1:1: expected tuple", formatted);
        }
    }

    // Multi line strings
    inline for (.{ []const u8, [:0]const u8 }) |String| {
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

fn parseEnumLiteral(self: @This(), comptime T: type, node: NodeIndex) error{Type}!T {
    const tags = self.ast.nodes.items(.tag);
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];

    switch (tags[node]) {
        .enum_literal => {
            // Create a comptime string map for the enum fields
            const enum_fields = @typeInfo(T).Enum.fields;
            comptime var kvs_list: [enum_fields.len]struct { []const u8, T } = undefined;
            inline for (enum_fields, 0..) |field, i| {
                kvs_list[i] = .{ field.name, @enumFromInt(field.value) };
            }
            const enum_tags = std.StaticStringMap(T).initComptime(kvs_list);

            // Get the tag if it exists
            const bytes = try self.parseIdent(T, token);
            return enum_tags.get(bytes) orelse
                self.failUnexpectedField(T, token);
        },
        else => return self.fail(token, .expected_enum),
    }
}

// Note that `parseIdent` may reuse the same buffer when called repeatedly, invalidating
// previous results.
// The resulting bytes may reference a buffer on `self` that can be reused in future calls to
// `parseIdent`. They should only be held onto temporarily.
fn parseIdent(self: @This(), T: type, token: TokenIndex) error{Type}![]const u8 {
    var unparsed = self.ast.tokenSlice(token);

    if (unparsed[0] == '@' and unparsed[1] == '"') {
        var fba = std.heap.FixedBufferAllocator.init(self.ident_buf);
        const alloc = fba.allocator();
        var parsed = std.ArrayListUnmanaged(u8).initCapacity(alloc, self.ident_buf.len) catch unreachable;

        const raw = unparsed[1..unparsed.len];
        const result = std.zig.string_literal.parseWrite(parsed.writer(alloc), raw) catch |err| switch (err) {
            // If it's too long for our preallocated buffer, it must be incorrect
            error.OutOfMemory => return self.failUnexpectedField(T, token),
        };
        switch (result) {
            .failure => |reason| return self.failInvalidStringLiteral(token, reason),
            .success => {},
        }
        if (std.mem.indexOfScalar(u8, parsed.items, 0) != null) {
            return self.failUnexpectedField(T, token);
        }
        return parsed.items;
    }

    return unparsed;
}

test "std.zon enum literals" {
    const gpa = std.testing.allocator;

    const Enum = enum {
        foo,
        bar,
        baz,
        @"ab\nc",
    };

    // Tags that exist
    try std.testing.expectEqual(Enum.foo, try parseFromSlice(Enum, gpa, ".foo", .{}));
    try std.testing.expectEqual(Enum.bar, try parseFromSlice(Enum, gpa, ".bar", .{}));
    try std.testing.expectEqual(Enum.baz, try parseFromSlice(Enum, gpa, ".baz", .{}));
    try std.testing.expectEqual(Enum.@"ab\nc", try parseFromSlice(Enum, gpa, ".@\"ab\\nc\"", .{}));

    // Bad tag
    {
        var ast = try std.zig.Ast.parse(gpa, ".qux", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: unexpected field, supported fields: foo, bar, baz, @\"ab\\nc\"", formatted);
    }

    // Bad tag that's too long for parser
    {
        var ast = try std.zig.Ast.parse(gpa, ".@\"foobarbaz\"", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: unexpected field, supported fields: foo, bar, baz, @\"ab\\nc\"", formatted);
    }

    // Bad type
    {
        var ast = try std.zig.Ast.parse(gpa, "true", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(Enum, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected enum literal", formatted);
    }

    // Test embedded nulls in an identifier
    {
        var ast = try std.zig.Ast.parse(gpa, ".@\"\\x00\"", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(enum { a }, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: unexpected field, supported fields: a", formatted);
    }
}

fn fail(self: @This(), token: TokenIndex, reason: ParseFailure.Reason) error{Type} {
    @setCold(true);
    if (self.status) |s| s.* = .{ .failure = .{
        .ast = self.ast,
        .token = token,
        .reason = reason,
    } };
    return error.Type;
}

fn failOutOfMemory(self: *@This(), token: TokenIndex) error{ParserOutOfMemory} {
    // Set our failure state, but ignore the type error because users may want to handle out of
    // memory separately from other input errors
    self.fail(token, .out_of_memory) catch {};

    // We don't return error.OutOfMemory directly so that we can't forget to call this function,
    // this error will be converted to error.OutOfMemory before returning to the user
    return error.ParserOutOfMemory;
}

fn failInvalidStringLiteral(self: @This(), token: TokenIndex, err: StringLiteralError) error{Type} {
    @setCold(true);
    return self.fail(token, .{
        .invalid_string_literal = .{ .err = err },
    });
}

fn failInvalidNumberLiteral(self: @This(), token: TokenIndex, err: NumberLiteralError) error{Type} {
    @setCold(true);
    return self.fail(token, .{
        .invalid_number_literal = .{ .err = err },
    });
}

fn failCannotRepresent(self: @This(), comptime T: type, token: TokenIndex) error{Type} {
    @setCold(true);
    return self.fail(token, .{
        .cannot_represent = .{ .type_name = @typeName(T) },
    });
}

fn failNegativeIntegerZero(self: @This(), token: TokenIndex) error{Type} {
    @setCold(true);
    return self.fail(token, .negative_integer_zero);
}

fn failUnexpectedField(self: @This(), T: type, token: TokenIndex) error{Type} {
    @setCold(true);
    switch (@typeInfo(T)) {
        .Struct, .Union, .Enum => return self.fail(token, .{ .unexpected_field = .{
            .fields = std.meta.fieldNames(T),
        } }),
        else => @compileError("unreachable, should not be called for type " ++ @typeName(T)),
    }
}

fn failExpectedContainer(self: @This(), T: type, token: TokenIndex) error{Type} {
    @setCold(true);
    switch (@typeInfo(T)) {
        .Struct => |Struct| if (Struct.is_tuple) {
            return self.fail(token, .{ .expected_tuple_with_fields = .{
                .fields = Struct.fields.len,
            } });
        } else {
            return self.fail(token, .expected_struct);
        },
        .Union => return self.fail(token, .expected_union),
        .Array => |Array| return self.fail(token, .{ .expected_tuple_with_fields = .{
            .fields = Array.len,
        } }),
        .Pointer => |Pointer| {
            if (Pointer.child == u8 and
                Pointer.size == .Slice and
                Pointer.is_const and
                (Pointer.sentinel == null or @as(*const u8, @ptrCast(Pointer.sentinel)).* == 0) and
                Pointer.alignment == 1)
            {
                return self.fail(token, .expected_string);
            } else {
                return self.fail(token, .expected_tuple);
            }
        },
        else => @compileError("unreachable, should not be called for type " ++ @typeName(T)),
    }
}

fn failMissingField(self: @This(), name: []const u8, token: TokenIndex) error{Type} {
    @setCold(true);
    return self.fail(token, .{ .missing_field = .{ .field_name = name } });
}

fn failDuplicateField(self: @This(), token: TokenIndex) error{Type} {
    @setCold(true);
    return self.fail(token, .duplicate_field);
}

fn failTypeExpr(self: @This(), token: TokenIndex) error{Type} {
    @setCold(true);
    return self.fail(token, .type_expr);
}

fn parseBool(self: @This(), node: NodeIndex) error{Type}!bool {
    const tags = self.ast.nodes.items(.tag);
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node];
    switch (tags[node]) {
        .identifier => {
            const bytes = self.ast.tokenSlice(token);
            const map = std.StaticStringMap(bool).initComptime(.{
                .{ "true", true },
                .{ "false", false },
            });
            if (map.get(bytes)) |value| {
                return value;
            }
        },
        else => {},
    }
    return self.fail(token, .{ .expected_primitive = .{ .type_name = "bool" } });
}

test "std.zon parse bool" {
    const gpa = std.testing.allocator;

    // Correct floats
    try std.testing.expectEqual(true, try parseFromSlice(bool, gpa, "true", .{}));
    try std.testing.expectEqual(false, try parseFromSlice(bool, gpa, "false", .{}));

    // Errors
    {
        var ast = try std.zig.Ast.parse(gpa, " foo", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(bool, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:2: expected bool", formatted);
    }
    {
        var ast = try std.zig.Ast.parse(gpa, "123", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(bool, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected bool", formatted);
    }
}

fn parseNumber(
    self: @This(),
    comptime T: type,
    node: NodeIndex,
) error{Type}!T {
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_node = self.numLitNode(node);
    const tags = self.ast.nodes.items(.tag);
    switch (tags[num_lit_node]) {
        .number_literal => return self.parseNumberLiteral(T, node),
        .char_literal => return self.parseCharLiteral(T, node),
        .identifier => switch (@typeInfo(T)) {
            .Float => {
                const token = main_tokens[num_lit_node];
                const bytes = self.ast.tokenSlice(token);
                const Ident = enum { inf, nan };
                const map = std.StaticStringMap(Ident).initComptime(.{
                    .{ "inf", .inf },
                    .{ "nan", .nan },
                });
                if (map.get(bytes)) |value| {
                    switch (value) {
                        .inf => if (self.isNegative(node)) {
                            return -std.math.inf(T);
                        } else {
                            return std.math.inf(T);
                        },
                        .nan => return std.math.nan(T),
                    }
                }
            },
            else => {},
        },
        else => {},
    }
    return self.fail(main_tokens[node], .{
        .expected_primitive = .{ .type_name = @typeName(T) },
    });
}

fn parseNumberLiteral(self: @This(), comptime T: type, node: NodeIndex) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const token_bytes = self.ast.tokenSlice(num_lit_token);
    const number = std.zig.number_literal.parseNumberLiteral(token_bytes);

    switch (number) {
        .int => |int| return self.applySignToInt(T, node, int),
        .big_int => |base| return self.parseBigNumber(T, node, base),
        .float => return self.parseFloat(T, node),
        .failure => |reason| return self.failInvalidNumberLiteral(main_tokens[node], reason),
    }
}

fn applySignToInt(self: @This(), comptime T: type, node: NodeIndex, int: anytype) error{Type}!T {
    const main_tokens = self.ast.nodes.items(.main_token);
    if (self.isNegative(node)) {
        if (int == 0) {
            return self.failNegativeIntegerZero(main_tokens[node]);
        }
        switch (@typeInfo(T)) {
            .Int => |int_type| switch (int_type.signedness) {
                .signed => {
                    const In = @TypeOf(int);
                    if (std.math.maxInt(In) > std.math.maxInt(T) and int == @as(In, std.math.maxInt(T)) + 1) {
                        return std.math.minInt(T);
                    }

                    return -(std.math.cast(T, int) orelse return self.failCannotRepresent(T, main_tokens[node]));
                },
                .unsigned => return self.failCannotRepresent(T, main_tokens[node]),
            },
            .Float => return -@as(T, @floatFromInt(int)),
            else => @compileError("internal error: expected numeric type"),
        }
    } else {
        switch (@typeInfo(T)) {
            .Int => return std.math.cast(T, int) orelse
                self.failCannotRepresent(T, main_tokens[node]),
            .Float => return @as(T, @floatFromInt(int)),
            else => @compileError("internal error: expected numeric type"),
        }
    }
}

fn parseBigNumber(
    self: @This(),
    comptime T: type,
    node: NodeIndex,
    base: Base,
) error{Type}!T {
    switch (@typeInfo(T)) {
        .Int => return self.parseBigInt(T, node, base),
        .Float => {
            const result = @as(T, @floatCast(try self.parseFloat(f128, node)));
            if (std.math.isNegativeZero(result)) {
                const main_tokens = self.ast.nodes.items(.main_token);
                return self.failNegativeIntegerZero(main_tokens[node]);
            }
            return result;
        },
        else => @compileError("internal error: expected integer or float type"),
    }
}

fn parseBigInt(self: @This(), comptime T: type, node: NodeIndex, base: Base) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const prefix_offset: usize = if (base == .decimal) 0 else 2;
    const bytes = self.ast.tokenSlice(num_lit_token)[prefix_offset..];
    const result = if (self.isNegative(node))
        std.fmt.parseIntWithSign(T, u8, bytes, @intFromEnum(base), .neg)
    else
        std.fmt.parseIntWithSign(T, u8, bytes, @intFromEnum(base), .pos);
    return result catch |err| switch (err) {
        error.InvalidCharacter => unreachable,
        error.Overflow => return self.failCannotRepresent(T, main_tokens[node]),
    };
}

fn parseFloat(
    self: @This(),
    comptime T: type,
    node: NodeIndex,
) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const bytes = self.ast.tokenSlice(num_lit_token);
    const Float = if (@typeInfo(T) == .Float) T else f128;
    const unsigned_float = std.fmt.parseFloat(Float, bytes) catch unreachable; // Already validated
    const result = if (self.isNegative(node)) -unsigned_float else unsigned_float;
    switch (@typeInfo(T)) {
        .Float => return @as(T, @floatCast(result)),
        .Int => return intFromFloatExact(T, result) orelse
            return self.failCannotRepresent(T, main_tokens[node]),
        else => @compileError("internal error: expected integer or float type"),
    }
}

fn parseCharLiteral(self: @This(), comptime T: type, node: NodeIndex) error{Type}!T {
    const num_lit_node = self.numLitNode(node);
    const main_tokens = self.ast.nodes.items(.main_token);
    const num_lit_token = main_tokens[num_lit_node];
    const token_bytes = self.ast.tokenSlice(num_lit_token);
    const char = std.zig.string_literal.parseCharLiteral(token_bytes).success;
    return self.applySignToInt(T, node, char);
}

fn isNegative(self: *const @This(), node: NodeIndex) bool {
    const tags = self.ast.nodes.items(.tag);
    return tags[node] == .negation;
}

fn numLitNode(self: *const @This(), node: NodeIndex) NodeIndex {
    if (self.isNegative(node)) {
        const data = self.ast.nodes.items(.data);
        return data[node].lhs;
    } else {
        return node;
    }
}

fn intFromFloatExact(comptime T: type, value: anytype) ?T {
    switch (@typeInfo(@TypeOf(value))) {
        .Float => {},
        else => @compileError(@typeName(@TypeOf(value)) ++ " is not a runtime floating point type"),
    }
    switch (@typeInfo(T)) {
        .Int => {},
        else => @compileError(@typeName(T) ++ " is not a runtime integer type"),
    }

    if (value > std.math.maxInt(T) or value < std.math.minInt(T)) {
        return null;
    }

    if (std.math.isNan(value) or std.math.trunc(value) != value) {
        return null;
    }

    return @as(T, @intFromFloat(value));
}

test "std.zon intFromFloatExact" {
    // Valid conversions
    try std.testing.expectEqual(@as(u8, 10), intFromFloatExact(u8, @as(f32, 10.0)).?);
    try std.testing.expectEqual(@as(i8, -123), intFromFloatExact(i8, @as(f64, @as(f64, -123.0))).?);
    try std.testing.expectEqual(@as(i16, 45), intFromFloatExact(i16, @as(f128, @as(f128, 45.0))).?);

    // Out of range
    try std.testing.expectEqual(@as(?u4, null), intFromFloatExact(u4, @as(f32, 16.0)));
    try std.testing.expectEqual(@as(?i4, null), intFromFloatExact(i4, @as(f64, -17.0)));
    try std.testing.expectEqual(@as(?u8, null), intFromFloatExact(u8, @as(f128, -2.0)));

    // Not a whole number
    try std.testing.expectEqual(@as(?u8, null), intFromFloatExact(u8, @as(f32, 0.5)));
    try std.testing.expectEqual(@as(?i8, null), intFromFloatExact(i8, @as(f64, 0.01)));

    // Infinity and NaN
    try std.testing.expectEqual(@as(?u8, null), intFromFloatExact(u8, std.math.inf(f32)));
    try std.testing.expectEqual(@as(?u8, null), intFromFloatExact(u8, -std.math.inf(f32)));
    try std.testing.expectEqual(@as(?u8, null), intFromFloatExact(u8, std.math.nan(f32)));
}

test "std.zon parse int" {
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(i66, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: i66 cannot represent value", formatted);
    }
    {
        var ast = try std.zig.Ast.parse(gpa, "-36893488147419103233", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(i66, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: i66 cannot represent value", formatted);
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
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:3: invalid digit 'a' for decimal base", formatted);
    }

    // Failing to parse as int
    {
        var ast = try std.zig.Ast.parse(gpa, "true", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected u8", formatted);
    }

    // Failing because an int is out of range
    {
        var ast = try std.zig.Ast.parse(gpa, "256", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: u8 cannot represent value", formatted);
    }

    // Failing because a negative int is out of range
    {
        var ast = try std.zig.Ast.parse(gpa, "-129", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(i8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: i8 cannot represent value", formatted);
    }

    // Failing because an unsigned int is negative
    {
        var ast = try std.zig.Ast.parse(gpa, "-1", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: u8 cannot represent value", formatted);
    }

    // Failing because a float is non-whole
    {
        var ast = try std.zig.Ast.parse(gpa, "1.5", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: u8 cannot represent value", formatted);
    }

    // Failing because a float is negative
    {
        var ast = try std.zig.Ast.parse(gpa, "-1.0", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: u8 cannot represent value", formatted);
    }

    // Negative integer zero
    {
        var ast = try std.zig.Ast.parse(gpa, "-0", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(i8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: integer literal '-0' is ambiguous", formatted);
    }

    // Negative integer zero casted to float
    {
        var ast = try std.zig.Ast.parse(gpa, "-0", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(f32, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: integer literal '-0' is ambiguous", formatted);
    }

    // Negative float 0 is allowed
    try std.testing.expect(std.math.isNegativeZero(try parseFromSlice(f32, gpa, "-0.0", .{})));
    try std.testing.expect(std.math.isPositiveZero(try parseFromSlice(f32, gpa, "0.0", .{})));

    // Double negation is not allowed
    {
        var ast = try std.zig.Ast.parse(gpa, "--2", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(i8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected i8", formatted);
    }

    {
        var ast = try std.zig.Ast.parse(gpa, "--2.0", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(f32, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected f32", formatted);
    }

    // Invalid int literal
    {
        var ast = try std.zig.Ast.parse(gpa, "0xg", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:3: invalid digit 'g' for hex base", formatted);
    }

    // Notes on invalid int literal
    {
        var ast = try std.zig.Ast.parse(gpa, "0123", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(u8, gpa, &ast, &status, .{}));
        try std.testing.expectFmt("1:1: number '0123' has leading zero", "{}", .{status.failure});
        try std.testing.expectEqual(1, status.failure.noteCount());
        try std.testing.expectFmt("use '0o' prefix for octal literals", "{}", .{status.failure.fmtNote(0)});
    }
}

test "std.zon parse float" {
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

    // inf, nan
    try std.testing.expect(std.math.isPositiveInf(try parseFromSlice(f32, gpa, "inf", .{})));
    try std.testing.expect(std.math.isNegativeInf(try parseFromSlice(f32, gpa, "-inf", .{})));
    try std.testing.expect(std.math.isNan(try parseFromSlice(f32, gpa, "nan", .{})));
    try std.testing.expect(std.math.isNan(try parseFromSlice(f32, gpa, "-nan", .{})));

    // Bad identifier as float
    {
        var ast = try std.zig.Ast.parse(gpa, "foo", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(f32, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected f32", formatted);
    }

    {
        var ast = try std.zig.Ast.parse(gpa, "-foo", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(f32, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected f32", formatted);
    }

    // Non float as float
    {
        var ast = try std.zig.Ast.parse(gpa, "\"foo\"", .zon);
        defer ast.deinit(gpa);
        var status: ParseStatus = undefined;
        try std.testing.expectError(error.Type, parseFromAst(f32, gpa, &ast, &status, .{}));
        const formatted = try std.fmt.allocPrint(gpa, "{}", .{status.failure});
        defer gpa.free(formatted);
        try std.testing.expectEqualStrings("1:1: expected f32", formatted);
    }
}

test "std.zon free on error" {
    // Test freeing partially allocated structs
    {
        const Struct = struct {
            x: []const u8,
            y: []const u8,
            z: bool,
        };
        try std.testing.expectError(error.Type, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    .x = "hello",
            \\    .y = "world",
            \\    .z = "fail",
            \\}
        , .{}));
    }

    // Test freeing partially allocated tuples
    {
        const Struct = struct {
            []const u8,
            []const u8,
            bool,
        };
        try std.testing.expectError(error.Type, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    "world",
            \\    "fail",
            \\}
        , .{}));
    }

    // Test freeing structs with missing fields
    {
        const Struct = struct {
            x: []const u8,
            y: bool,
        };
        try std.testing.expectError(error.Type, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    .x = "hello",
            \\}
        , .{}));
    }

    // Test freeing partially allocated arrays
    {
        try std.testing.expectError(error.Type, parseFromSlice([3][]const u8, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    false,
            \\    false,
            \\}
        , .{}));
    }

    // Test freeing partially allocated slices
    {
        try std.testing.expectError(error.Type, parseFromSlice([][]const u8, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    "world",
            \\    false,
            \\}
        , .{}));
    }

    // We can parse types that can't be freed, as long as they contain no allocations, e.g. untagged
    // unions.
    try std.testing.expectEqual(
        @as(f32, 1.5),
        (try parseFromSlice(union { x: f32 }, std.testing.allocator, ".{ .x = 1.5 }", .{})).x,
    );

    // We can also parse types that can't be freed if it's impossible for an error to occur after
    // the allocation, as is the case here.
    {
        const result = try parseFromSlice(union { x: []const u8 }, std.testing.allocator, ".{ .x = \"foo\" }", .{});
        defer parseFree(std.testing.allocator, result.x);
        try std.testing.expectEqualStrings("foo", result.x);
    }

    // However, if it's possible we could get an error requiring we free the value, but the value
    // cannot be freed (e.g. untagged unions) then we need to turn off `free_on_error` for it to
    // compile.
    {
        const S = struct {
            union { x: []const u8 },
            bool,
        };
        const result = try parseFromSlice(S, std.testing.allocator, ".{ .{ .x = \"foo\" }, true }", .{
            .free_on_error = false,
        });
        defer parseFree(std.testing.allocator, result[0].x);
        try std.testing.expectEqualStrings("foo", result[0].x);
        try std.testing.expect(result[1]);
    }

    // Again but for structs.
    {
        const S = struct {
            a: union { x: []const u8 },
            b: bool,
        };
        const result = try parseFromSlice(S, std.testing.allocator, ".{ .a = .{ .x = \"foo\" }, .b = true }", .{
            .free_on_error = false,
        });
        defer parseFree(std.testing.allocator, result.a.x);
        try std.testing.expectEqualStrings("foo", result.a.x);
        try std.testing.expect(result.b);
    }

    // Again but for arrays.
    {
        const S = [2]union { x: []const u8 };
        const result = try parseFromSlice(S, std.testing.allocator, ".{ .{ .x = \"foo\" }, .{ .x = \"bar\" } }", .{
            .free_on_error = false,
        });
        defer parseFree(std.testing.allocator, result[0].x);
        defer parseFree(std.testing.allocator, result[1].x);
        try std.testing.expectEqualStrings("foo", result[0].x);
        try std.testing.expectEqualStrings("bar", result[1].x);
    }

    // Again but for slices.
    {
        const S = []union { x: []const u8 };
        const result = try parseFromSlice(S, std.testing.allocator, ".{ .{ .x = \"foo\" }, .{ .x = \"bar\" } }", .{
            .free_on_error = false,
        });
        defer std.testing.allocator.free(result);
        defer parseFree(std.testing.allocator, result[0].x);
        defer parseFree(std.testing.allocator, result[1].x);
        try std.testing.expectEqualStrings("foo", result[0].x);
        try std.testing.expectEqualStrings("bar", result[1].x);
    }
}
