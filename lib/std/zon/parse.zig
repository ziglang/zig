const std = @import("std");
const Allocator = std.mem.Allocator;
const Ast = std.zig.Ast;
const Zoir = std.zig.Zoir;
const ZonGen = std.zig.ZonGen;
const TokenIndex = std.zig.Ast.TokenIndex;
const Base = std.zig.number_literal.Base;
const StringLiteralError = std.zig.string_literal.Error;
const NumberLiteralError = std.zig.number_literal.Error;
const assert = std.debug.assert;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

gpa: Allocator,
ast: Ast,
zoir: Zoir,
status: ?*Status,

/// Configuration for the runtime parser.
pub const Options = struct {
    /// If true, unknown fields do not error.
    ignore_unknown_fields: bool = false,
    /// If true, the parser cleans up partially parsed values on error. This requires some extra
    /// bookkeeping, so you may want to turn it off if you don't need this feature (e.g. because
    /// you're using arena allocation.)
    free_on_error: bool = true,
};

pub const Error = union(enum) {
    zoir: Zoir.CompileError,
    type_check: TypeCheckFailure,

    pub const Note = union(enum) {
        zoir: Zoir.CompileError.Note,

        pub const Iterator = struct {
            index: usize = 0,
            err: Error,
            status: *const Status,

            pub fn next(self: *@This()) ?Note {
                switch (self.err) {
                    .zoir => |err| {
                        if (self.index >= err.note_count) return null;
                        const zoir = self.status.zoir.?;
                        const note = err.getNotes(zoir)[self.index];
                        self.index += 1;
                        return .{ .zoir = note };
                    },
                    .type_check => return null,
                }
            }
        };

        pub fn getMessage(self: Note, status: *const Status) []const u8 {
            switch (self) {
                .zoir => |note| return note.msg.get(status.zoir.?),
            }
        }

        pub fn getLocation(self: Note, status: *const Status) Ast.Location {
            switch (self) {
                .zoir => |note| return zoirErrorLocation(
                    status.ast.?,
                    note.token,
                    note.node_or_offset,
                ),
            }
        }
    };

    pub const Iterator = struct {
        index: usize = 0,
        status: *const Status,

        pub fn next(self: *@This()) ?Error {
            const zoir = self.status.zoir orelse return null;

            if (self.index < zoir.compile_errors.len) {
                const result: Error = .{ .zoir = zoir.compile_errors[self.index] };
                self.index += 1;
                return result;
            }

            if (self.status.type_check) |err| {
                if (self.index == zoir.compile_errors.len) {
                    const result: Error = .{ .type_check = err };
                    self.index += 1;
                    return result;
                }
            }

            return null;
        }
    };

    const TypeCheckFailure = struct {
        token: Ast.TokenIndex,
        message: []const u8,
    };

    pub fn getMessage(self: @This(), status: *const Status) []const u8 {
        return switch (self) {
            .zoir => |err| err.msg.get(status.zoir.?),
            .type_check => |err| err.message,
        };
    }

    pub fn getLocation(self: @This(), status: *const Status) Ast.Location {
        const ast = status.ast.?;
        return switch (self) {
            .zoir => |err| return zoirErrorLocation(
                status.ast.?,
                err.token,
                err.node_or_offset,
            ),
            .type_check => |err| return ast.tokenLocation(0, err.token),
        };
    }

    pub fn iterateNotes(self: @This(), status: *const Status) Note.Iterator {
        return .{ .err = self, .status = status };
    }

    fn zoirErrorLocation(ast: Ast, maybe_token: Ast.TokenIndex, node_or_offset: u32) Ast.Location {
        if (maybe_token == Zoir.CompileError.invalid_token) {
            const main_tokens = ast.nodes.items(.main_token);
            const ast_node = node_or_offset;
            const token = main_tokens[ast_node];
            return ast.tokenLocation(0, token);
        } else {
            var location = ast.tokenLocation(0, maybe_token);
            location.column += node_or_offset;
            return location;
        }
    }
};

/// Information about the success or failure of a parse.
pub const Status = struct {
    ast: ?Ast = null,
    zoir: ?Zoir = null,
    type_check: ?Error.TypeCheckFailure = null,

    fn assertEmpty(self: Status) void {
        assert(self.ast == null);
        assert(self.zoir == null);
        assert(self.type_check == null);
    }

    pub fn deinit(self: *Status, gpa: Allocator) void {
        if (self.ast) |*ast| ast.deinit(gpa);
        if (self.zoir) |*zoir| zoir.deinit(gpa);
        self.* = undefined;
    }

    pub fn iterateErrors(self: *const Status) Error.Iterator {
        return .{ .status = self };
    }

    pub fn format(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        var errors = self.iterateErrors();
        while (errors.next()) |err| {
            const loc = err.getLocation(self);
            const msg = err.getMessage(self);
            try writer.print("{}:{}: error: {s}\n", .{ loc.line + 1, loc.column + 1, msg });

            var notes = err.iterateNotes(self);
            while (notes.next()) |note| {
                const note_loc = note.getLocation(self);
                const note_msg = note.getMessage(self);
                try writer.print("{}:{}: note: {s}\n", .{ note_loc.line + 1, note_loc.column + 1, note_msg });
            }
        }
    }
};

test "std.zon ast errors" {
    // Test multiple errors
    const gpa = std.testing.allocator;
    var status: Status = .{};
    defer status.deinit(gpa);
    try std.testing.expectError(
        error.ParseZon,
        parseFromSlice(struct {}, gpa, ".{.x = 1 .y = 2}", &status, .{}),
    );
    try std.testing.expectFmt("1:13: error: expected ',' after initializer\n", "{}", .{status});
}

test "std.zon comments" {
    const gpa = std.testing.allocator;

    try std.testing.expectEqual(@as(u8, 10), parseFromSlice(u8, gpa,
        \\// comment
        \\10 // comment
        \\// comment
    , null, .{}));

    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa,
            \\//! comment
            \\10 // comment
            \\// comment
        , &status, .{}));
        try std.testing.expectFmt(
            "1:1: error: expected expression, found 'a document comment'\n",
            "{}",
            .{status},
        );
    }
}

test "std.zon failure/oom formatting" {
    const gpa = std.testing.allocator;
    var failing_allocator = std.testing.FailingAllocator.init(gpa, .{
        .fail_index = 0,
        .resize_fail_index = 0,
    });
    var status: Status = .{};
    defer status.deinit(gpa);
    try std.testing.expectError(error.OutOfMemory, parseFromSlice(
        []const u8,
        failing_allocator.allocator(),
        "\"foo\"",
        &status,
        .{},
    ));
    try std.testing.expectFmt("", "{}", .{status});
}

/// Parses the given slice as ZON.
///
/// Returns `error.OutOfMemory` on allocation failure, or `error.ParseZon` error if the ZON is
/// invalid or can not be deserialized into type `T`.
///
/// When the parser returns `error.ParseZon`, it will also store a human readable explanation in
/// `status` if non null. If status is not null, it must be initialized to `.{}`.
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
    gpa: Allocator,
    source: [:0]const u8,
    status: ?*Status,
    comptime options: Options,
) error{ OutOfMemory, ParseZon }!T {
    if (status) |s| s.assertEmpty();

    var ast = try std.zig.Ast.parse(gpa, source, .zon);
    defer if (status == null) ast.deinit(gpa);
    if (status) |s| s.ast = ast;

    var zoir = try ZonGen.generate(gpa, ast);
    defer if (status == null) zoir.deinit(gpa);
    if (status) |s| s.zoir = zoir;
    if (zoir.hasCompileErrors()) return error.ParseZon;

    if (status) |s| s.* = .{};
    return parseFromZoir(T, gpa, ast, zoir, status, options);
}

test "std.zon parseFromSlice syntax error" {
    try std.testing.expectError(error.ParseZon, parseFromSlice(u8, std.testing.allocator, ".{", null, .{}));
}

/// Like `parseFromSlice`, but operates on `Zoir` instead of ZON source.
pub fn parseFromZoir(
    comptime T: type,
    gpa: Allocator,
    ast: Ast,
    zoir: Zoir,
    status: ?*Status,
    comptime options: Options,
) error{ OutOfMemory, ParseZon }!T {
    return parseFromZoirNode(T, gpa, ast, zoir, .root, status, options);
}

/// Like `parseFromZoir`, but does not take an allocator.
///
/// Asserts at comptime that no values of `T` require dynamic allocation.
pub fn parseFromZoirNoAlloc(
    comptime T: type,
    ast: Ast,
    zoir: Zoir,
    status: ?*Status,
    comptime options: Options,
) error{ParseZon}!T {
    return parseFromZoirNodeNoAlloc(T, ast, zoir, .root, status, options);
}

test "std.zon parseFromZoirNoAlloc" {
    var ast = try std.zig.Ast.parse(std.testing.allocator, ".{ .x = 1.5, .y = 2.5 }", .zon);
    defer ast.deinit(std.testing.allocator);
    var zoir = try ZonGen.generate(std.testing.allocator, ast);
    defer zoir.deinit(std.testing.allocator);
    const S = struct { x: f32, y: f32 };
    const found = try parseFromZoirNoAlloc(S, ast, zoir, null, .{});
    try std.testing.expectEqual(S{ .x = 1.5, .y = 2.5 }, found);
}

/// Like `parseFromZoir`, but the parse starts on `node` instead of root.
pub fn parseFromZoirNode(
    comptime T: type,
    gpa: Allocator,
    ast: Ast,
    zoir: Zoir,
    node: Zoir.Node.Index,
    status: ?*Status,
    comptime options: Options,
) error{ OutOfMemory, ParseZon }!T {
    if (status) |s| {
        s.assertEmpty();
        s.ast = ast;
        s.zoir = zoir;
    }

    if (zoir.hasCompileErrors()) {
        return error.ParseZon;
    }

    var parser = @This(){
        .gpa = gpa,
        .ast = ast,
        .zoir = zoir,
        .status = status,
    };

    return parser.parseExpr(T, options, node);
}

/// See `parseFromZoirNoAlloc` and `parseFromZoirNode`.
pub fn parseFromZoirNodeNoAlloc(
    comptime T: type,
    ast: Ast,
    zoir: Zoir,
    node: Zoir.Node.Index,
    status: ?*Status,
    comptime options: Options,
) error{ParseZon}!T {
    if (comptime requiresAllocator(T)) {
        @compileError(@typeName(T) ++ ": requires allocator");
    }
    var buffer: [0]u8 = .{};
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    return parseFromZoirNode(T, fba.allocator(), ast, zoir, node, status, options) catch |e| switch (e) {
        error.OutOfMemory => unreachable, // No allocations
        else => |other| return other,
    };
}

test "std.zon parseFromZoirNode and parseFromZoirNodeNoAlloc" {
    const gpa = std.testing.allocator;

    var ast = try std.zig.Ast.parse(gpa, ".{ .vec = .{ .x = 1.5, .y = 2.5 } }", .zon);
    defer ast.deinit(gpa);
    var zoir = try ZonGen.generate(gpa, ast);
    defer zoir.deinit(gpa);

    const vec = Zoir.Node.Index.root.get(zoir).struct_literal.vals.at(0);

    const Vec2 = struct { x: f32, y: f32 };
    const parsed = try parseFromZoirNode(Vec2, gpa, ast, zoir, vec, null, .{});
    const parsed_no_alloc = try parseFromZoirNodeNoAlloc(Vec2, ast, zoir, vec, null, .{});
    try std.testing.expectEqual(Vec2{ .x = 1.5, .y = 2.5 }, parsed);
    try std.testing.expectEqual(Vec2{ .x = 1.5, .y = 2.5 }, parsed_no_alloc);
}

fn requiresAllocator(comptime T: type) bool {
    // Keep in sync with parseFree, stringify, and requiresAllocator.
    return switch (@typeInfo(T)) {
        .pointer => true,
        .array => |array| requiresAllocator(array.child),
        .@"struct" => |@"struct"| inline for (@"struct".fields) |field| {
            if (requiresAllocator(field.type)) {
                break true;
            }
        } else false,
        .@"union" => |@"union"| inline for (@"union".fields) |field| {
            if (requiresAllocator(field.type)) {
                break true;
            }
        } else false,
        .optional => |optional| requiresAllocator(optional.child),
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

/// Frees ZON values.
///
/// Provided for convenience, you may also free these values on your own using the same allocator
/// passed into the parser.
///
/// Asserts at comptime that sufficient information is available via the type system to free this
/// value. Untagged unions, for example, will fail this assert.
pub fn parseFree(gpa: Allocator, value: anytype) void {
    const Value = @TypeOf(value);

    // Keep in sync with parseFree, stringify, and requiresAllocator.
    switch (@typeInfo(Value)) {
        .bool, .int, .float, .@"enum" => {},
        .pointer => |pointer| {
            switch (pointer.size) {
                .One, .Many, .C => if (comptime requiresAllocator(Value)) {
                    @compileError(@typeName(Value) ++ ": parseFree cannot free non slice pointers");
                },
                .Slice => for (value) |item| {
                    parseFree(gpa, item);
                },
            }
            return gpa.free(value);
        },
        .array => for (value) |item| {
            parseFree(gpa, item);
        },
        .@"struct" => |@"struct"| inline for (@"struct".fields) |field| {
            parseFree(gpa, @field(value, field.name));
        },
        .@"union" => |@"union"| if (@"union".tag_type == null) {
            if (comptime requiresAllocator(Value)) {
                @compileError(@typeName(Value) ++ ": parseFree cannot free untagged unions");
            }
        } else switch (value) {
            inline else => |_, tag| {
                parseFree(gpa, @field(value, @tagName(tag)));
            },
        },
        .optional => if (value) |some| {
            parseFree(gpa, some);
        },
        .void => {},
        .null => {},
        else => @compileError(@typeName(Value) ++ ": parseFree cannot free this type"),
    }
}

fn parseExpr(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    // Keep in sync with parseFree, stringify, and requiresAllocator.
    switch (@typeInfo(T)) {
        .bool => return self.parseBool(node),
        .int => return self.parseInt(T, node),
        .float => return self.parseFloat(T, node),
        .@"enum" => return self.parseEnumLiteral(T, node),
        .pointer => return self.parsePointer(T, options, node),
        .array => return self.parseArray(T, options, node),
        .@"struct" => |@"struct"| if (@"struct".is_tuple)
            return self.parseTuple(T, options, node)
        else
            return self.parseStruct(T, options, node),
        .@"union" => return self.parseUnion(T, options, node),
        .optional => return self.parseOptional(T, options, node),

        else => @compileError("type '" ++ @typeName(T) ++ "' is not available in ZON"),
    }
}

fn parseOptional(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    if (node.get(self.zoir) == .null) {
        return null;
    }

    return try self.parseExpr(@typeInfo(T).optional.child, options, node);
}

test "std.zon optional" {
    const gpa = std.testing.allocator;

    // Basic usage
    {
        const none = try parseFromSlice(?u32, gpa, "null", null, .{});
        try std.testing.expect(none == null);
        const some = try parseFromSlice(?u32, gpa, "1", null, .{});
        try std.testing.expect(some.? == 1);
    }

    // Deep free
    {
        const none = try parseFromSlice(?[]const u8, gpa, "null", null, .{});
        try std.testing.expect(none == null);
        const some = try parseFromSlice(?[]const u8, gpa, "\"foo\"", null, .{});
        defer parseFree(gpa, some);
        try std.testing.expectEqualStrings("foo", some.?);
    }
}

fn parseUnion(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    const @"union" = @typeInfo(T).@"union";
    const field_infos = @"union".fields;

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
    switch (node.get(self.zoir)) {
        .enum_literal => |string| {
            // The union must be tagged for an enum literal to coerce to it
            if (@"union".tag_type == null) {
                return self.failNode(node, "expected union");
            }

            // Get the index of the named field. We don't use `parseEnum` here as
            // the order of the enum and the order of the union might not match!
            const field_index = b: {
                break :b field_indices.get(string.get(self.zoir)) orelse
                    return self.failUnexpectedField(T, node, null);
            };

            // Initialize the union from the given field.
            switch (field_index) {
                inline 0...field_infos.len - 1 => |i| {
                    // Fail if the field is not void
                    if (field_infos[i].type != void)
                        return self.failNode(node, "expected union");

                    // Instantiate the union
                    return @unionInit(T, field_infos[i].name, {});
                },
                else => unreachable, // Can't be out of bounds
            }
        },
        .struct_literal => |struct_fields| {
            if (struct_fields.names.len != 1) {
                return self.failNode(node, "expected union");
            }

            // Fill in the field we found
            const field_name = struct_fields.names[0];
            const field_val = struct_fields.vals.at(0);
            const field_index = field_indices.get(field_name.get(self.zoir)) orelse
                return self.failUnexpectedField(T, node, 0);

            switch (field_index) {
                inline 0...field_infos.len - 1 => |i| {
                    if (field_infos[i].type == void) {
                        // XXX: remove?
                        return self.failNode(field_val, "expected type 'void'");
                    } else {
                        const value = try self.parseExpr(field_infos[i].type, options, field_val);
                        return @unionInit(T, field_infos[i].name, value);
                    }
                },
                else => unreachable, // Can't be out of bounds
            }
        },
        else => return self.failNode(node, "expected union"),
    }
}

test "std.zon unions" {
    const gpa = std.testing.allocator;

    // Unions
    {
        const Tagged = union(enum) { x: f32, @"y y": bool, z, @"z z" };
        const Untagged = union { x: f32, @"y y": bool, z: void, @"z z": void };

        const tagged_x = try parseFromSlice(Tagged, gpa, ".{.x = 1.5}", null, .{});
        try std.testing.expectEqual(Tagged{ .x = 1.5 }, tagged_x);
        const tagged_y = try parseFromSlice(Tagged, gpa, ".{.@\"y y\" = true}", null, .{});
        try std.testing.expectEqual(Tagged{ .@"y y" = true }, tagged_y);
        const tagged_z_shorthand = try parseFromSlice(Tagged, gpa, ".z", null, .{});
        try std.testing.expectEqual(@as(Tagged, .z), tagged_z_shorthand);
        const tagged_zz_shorthand = try parseFromSlice(Tagged, gpa, ".@\"z z\"", null, .{});
        try std.testing.expectEqual(@as(Tagged, .@"z z"), tagged_zz_shorthand);

        const untagged_x = try parseFromSlice(Untagged, gpa, ".{.x = 1.5}", null, .{});
        try std.testing.expect(untagged_x.x == 1.5);
        const untagged_y = try parseFromSlice(Untagged, gpa, ".{.@\"y y\" = true}", null, .{});
        try std.testing.expect(untagged_y.@"y y");
    }

    // Deep free
    {
        const Union = union(enum) { bar: []const u8, baz: bool };

        const noalloc = try parseFromSlice(Union, gpa, ".{.baz = false}", null, .{});
        try std.testing.expectEqual(Union{ .baz = false }, noalloc);

        const alloc = try parseFromSlice(Union, gpa, ".{.bar = \"qux\"}", null, .{});
        defer parseFree(gpa, alloc);
        try std.testing.expectEqualDeep(Union{ .bar = "qux" }, alloc);
    }

    // Unknown field
    {
        const Union = union { x: f32, y: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".{.z=2.5}", &status, .{}));
        try std.testing.expectFmt("1:4: error: unexpected field, supported fields: x, y\n", "{}", .{status});
    }

    // Explicit void field
    {
        const Union = union(enum) { x: void };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".{.x=1}", &status, .{}));
        try std.testing.expectFmt("1:6: error: expected type 'void'\n", "{}", .{status});
    }

    // Extra field
    {
        const Union = union { x: f32, y: bool };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".{.x = 1.5, .y = true}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected union\n", "{}", .{status});
    }

    // No fields
    {
        const Union = union { x: f32, y: bool };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".{}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected union\n", "{}", .{status});
    }

    // Enum literals cannot coerce into untagged unions
    {
        const Union = union { x: void };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".x", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected union\n", "{}", .{status});
    }

    // Unknown field for enum literal coercion
    {
        const Union = union(enum) { x: void };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".y", &status, .{}));
        try std.testing.expectFmt("1:2: error: unexpected field, supported fields: x\n", "{}", .{status});
    }

    // Non void field for enum literal coercion
    {
        const Union = union(enum) { x: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Union, gpa, ".x", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected union\n", "{}", .{status});
    }
}

fn parseStruct(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    const fields: std.meta.fieldInfo(Zoir.Node, .struct_literal).type = switch (node.get(self.zoir)) {
        .struct_literal => |nodes| nodes,
        .empty_literal => .{ .names = &.{}, .vals = .{ .start = node, .len = 0 } },
        else => return self.failExpectedContainer(T, node),
    };

    const field_infos = @typeInfo(T).@"struct".fields;

    // Gather info on the fields
    const field_indices = b: {
        comptime var kvs_list: [field_infos.len]struct { []const u8, usize } = undefined;
        inline for (field_infos, 0..) |field, i| {
            kvs_list[i] = .{ field.name, i };
        }
        break :b std.StaticStringMap(usize).initComptime(kvs_list);
    };

    // Parse the struct
    var result: T = undefined;
    var field_found: [field_infos.len]bool = .{false} ** field_infos.len;

    // If we fail partway through, free all already initialized fields
    var initialized: usize = 0;
    errdefer if (options.free_on_error and field_infos.len > 0) {
        for (fields.names[0..initialized]) |name_runtime| {
            switch (field_indices.get(name_runtime.get(self.zoir)) orelse continue) {
                inline 0...(field_infos.len - 1) => |name_index| {
                    const name = field_infos[name_index].name;
                    parseFree(self.gpa, @field(result, name));
                },
                else => unreachable, // Can't be out of bounds
            }
        }
    };

    // Fill in the fields we found
    for (0..fields.names.len) |i| {
        const field_index = b: {
            const name = fields.names[i].get(self.zoir);
            break :b field_indices.get(name) orelse if (options.ignore_unknown_fields) {
                continue;
            } else {
                return self.failUnexpectedField(T, node, i);
            };
        };

        // We now know the array is not zero sized (assert this so the code compiles)
        if (field_found.len == 0) unreachable;

        if (field_found[field_index]) {
            return self.failDuplicateField(node, i);
        }
        field_found[field_index] = true;

        switch (field_index) {
            inline 0...(field_infos.len - 1) => |j| {
                @field(result, field_infos[j].name) = try self.parseExpr(
                    field_infos[j].type,
                    options,
                    fields.vals.at(@intCast(i)),
                );
            },
            else => unreachable, // Can't be out of bounds
        }

        initialized += 1;
    }

    // Fill in any missing default fields
    inline for (field_found, 0..) |found, i| {
        if (!found) {
            const field_info = field_infos[i];
            if (field_info.default_value) |default| {
                const typed: *const field_info.type = @ptrCast(@alignCast(default));
                @field(result, field_info.name) = typed.*;
            } else {
                return self.failMissingField(field_infos[i].name, node);
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

        const zero = try parseFromSlice(Vec0, gpa, ".{}", null, .{});
        try std.testing.expectEqual(Vec0{}, zero);

        const one = try parseFromSlice(Vec1, gpa, ".{.x = 1.2}", null, .{});
        try std.testing.expectEqual(Vec1{ .x = 1.2 }, one);

        const two = try parseFromSlice(Vec2, gpa, ".{.x = 1.2, .y = 3.4}", null, .{});
        try std.testing.expectEqual(Vec2{ .x = 1.2, .y = 3.4 }, two);

        const three = try parseFromSlice(Vec3, gpa, ".{.x = 1.2, .y = 3.4, .z = 5.6}", null, .{});
        try std.testing.expectEqual(Vec3{ .x = 1.2, .y = 3.4, .z = 5.6 }, three);
    }

    // Deep free (structs and arrays)
    {
        const Foo = struct { bar: []const u8, baz: []const []const u8 };

        const parsed = try parseFromSlice(Foo, gpa, ".{.bar = \"qux\", .baz = .{\"a\", \"b\"}}", null, .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualDeep(Foo{ .bar = "qux", .baz = &.{ "a", "b" } }, parsed);
    }

    // Unknown field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Vec2, gpa, ".{.x=1.5, .z=2.5}", &status, .{}));
        try std.testing.expectFmt("1:12: error: unexpected field, supported fields: x, y\n", "{}", .{status});
    }

    // Duplicate field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Vec2, gpa, ".{.x=1.5, .x=2.5}", &status, .{}));
        try std.testing.expectFmt("1:12: error: duplicate field\n", "{}", .{status});
    }

    // Ignore unknown fields
    {
        const Vec2 = struct { x: f32, y: f32 = 2.0 };
        const parsed = try parseFromSlice(Vec2, gpa, ".{ .x = 1.0, .z = 3.0 }", null, .{
            .ignore_unknown_fields = true,
        });
        try std.testing.expectEqual(Vec2{ .x = 1.0, .y = 2.0 }, parsed);
    }

    // Unknown field when struct has no fields (regression test)
    {
        const Vec2 = struct {};
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Vec2, gpa, ".{.x=1.5, .z=2.5}", &status, .{}));
        try std.testing.expectFmt("1:4: error: unexpected field, no fields expected\n", "{}", .{status});
    }

    // Missing field
    {
        const Vec2 = struct { x: f32, y: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Vec2, gpa, ".{.x=1.5}", &status, .{}));
        try std.testing.expectFmt("1:2: error: missing required field y\n", "{}", .{status});
    }

    // Default field
    {
        const Vec2 = struct { x: f32, y: f32 = 1.5 };
        const parsed = try parseFromSlice(Vec2, gpa, ".{.x = 1.2}", null, .{});
        try std.testing.expectEqual(Vec2{ .x = 1.2, .y = 1.5 }, parsed);
    }

    // Enum field (regression test, we were previously getting the field name in an
    // incorrect way that broke for enum values)
    {
        const Vec0 = struct { x: enum { x } };
        const parsed = try parseFromSlice(Vec0, gpa, ".{ .x = .x }", null, .{});
        try std.testing.expectEqual(Vec0{ .x = .x }, parsed);
    }

    // Enum field and struct field with @
    {
        const Vec0 = struct { @"x x": enum { @"x x" } };
        const parsed = try parseFromSlice(Vec0, gpa, ".{ .@\"x x\" = .@\"x x\" }", null, .{});
        try std.testing.expectEqual(Vec0{ .@"x x" = .@"x x" }, parsed);
    }

    // Type expressions are not allowed
    {
        // Structs
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            const parsed = parseFromSlice(struct {}, gpa, "Empty{}", &status, .{});
            try std.testing.expectError(error.ParseZon, parsed);
            try std.testing.expectFmt(
                \\1:1: error: types are not available in ZON
                \\1:1: note: replace the type with '.'
                \\
            , "{}", .{status});
        }

        // Arrays
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            const parsed = parseFromSlice([3]u8, gpa, "[3]u8{1, 2, 3}", &status, .{});
            try std.testing.expectError(error.ParseZon, parsed);
            try std.testing.expectFmt(
                \\1:1: error: types are not available in ZON
                \\1:1: note: replace the type with '.'
                \\
            , "{}", .{status});
        }

        // Slices
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            const parsed = parseFromSlice([]u8, gpa, "[]u8{1, 2, 3}", &status, .{});
            try std.testing.expectError(error.ParseZon, parsed);
            try std.testing.expectFmt(
                \\1:1: error: types are not available in ZON
                \\1:1: note: replace the type with '.'
                \\
            , "{}", .{status});
        }

        // Tuples
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            const parsed = parseFromSlice(struct { u8, u8, u8 }, gpa, "Tuple{1, 2, 3}", &status, .{});
            try std.testing.expectError(error.ParseZon, parsed);
            try std.testing.expectFmt(
                \\1:1: error: types are not available in ZON
                \\1:1: note: replace the type with '.'
                \\
            , "{}", .{status});
        }

        // Nested
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            const parsed = parseFromSlice(struct {}, gpa, ".{ .x = Tuple{1, 2, 3} }", &status, .{});
            try std.testing.expectError(error.ParseZon, parsed);
            try std.testing.expectFmt(
                \\1:9: error: types are not available in ZON
                \\1:9: note: replace the type with '.'
                \\
            , "{}", .{status});
        }
    }
}

fn parseTuple(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    const nodes: Zoir.Node.Index.Range = switch (node.get(self.zoir)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return self.failExpectedContainer(T, node),
    };

    var result: T = undefined;

    const field_infos = @typeInfo(T).@"struct".fields;
    if (nodes.len != field_infos.len) {
        return self.failExpectedContainer(T, node);
    }

    inline for (0..field_infos.len) |i| {
        // If we fail to parse this field, free all fields before it
        errdefer if (options.free_on_error) {
            inline for (0..i) |j| {
                if (j >= i) break;
                parseFree(self.gpa, result[j]);
            }
        };

        result[i] = try self.parseExpr(field_infos[i].type, options, nodes.at(i));
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

        const zero = try parseFromSlice(Tuple0, gpa, ".{}", null, .{});
        try std.testing.expectEqual(Tuple0{}, zero);

        const one = try parseFromSlice(Tuple1, gpa, ".{1.2}", null, .{});
        try std.testing.expectEqual(Tuple1{1.2}, one);

        const two = try parseFromSlice(Tuple2, gpa, ".{1.2, true}", null, .{});
        try std.testing.expectEqual(Tuple2{ 1.2, true }, two);

        const three = try parseFromSlice(Tuple3, gpa, ".{1.2, false, 3}", null, .{});
        try std.testing.expectEqual(Tuple3{ 1.2, false, 3 }, three);
    }

    // Deep free
    {
        const Tuple = struct { []const u8, []const u8 };
        const parsed = try parseFromSlice(Tuple, gpa, ".{\"hello\", \"world\"}", null, .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualDeep(Tuple{ "hello", "world" }, parsed);
    }

    // Extra field
    {
        const Tuple = struct { f32, bool };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Tuple, gpa, ".{0.5, true, 123}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 2 fields\n", "{}", .{status});
    }

    // Extra field
    {
        const Tuple = struct { f32, bool };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Tuple, gpa, ".{0.5}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 2 fields\n", "{}", .{status});
    }

    // Tuple with unexpected field names
    {
        const Tuple = struct { f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Tuple, gpa, ".{.foo = 10.0}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 1 field\n", "{}", .{status});
    }

    // Struct with missing field names
    {
        const Struct = struct { foo: f32 };
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Struct, gpa, ".{10.0}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected struct\n", "{}", .{status});
    }
}

fn parseArray(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    const nodes: Zoir.Node.Index.Range = switch (node.get(self.zoir)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return self.failExpectedContainer(T, node),
    };

    const array_info = @typeInfo(T).array;

    // Check if the size matches
    if (nodes.len != array_info.len) {
        return self.failExpectedContainer(T, node);
    }

    // Parse the elements and return the array
    var result: T = undefined;
    for (0..result.len) |i| {
        // If we fail to parse this field, free all fields before it
        errdefer if (options.free_on_error) {
            for (result[0..i]) |item| {
                parseFree(self.gpa, item);
            }
        };

        result[i] = try self.parseExpr(array_info.child, options, nodes.at(@intCast(i)));
    }
    return result;
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
            const zero = try parseFromSlice([0]u8, gpa, ".{}", null, .{});
            try std.testing.expectEqualSlices(u8, &@as([0]u8, .{}), &zero);

            const one = try parseFromSlice([1]u8, gpa, ".{'a'}", null, .{});
            try std.testing.expectEqualSlices(u8, &@as([1]u8, .{'a'}), &one);

            const two = try parseFromSlice([2]u8, gpa, ".{'a', 'b'}", null, .{});
            try std.testing.expectEqualSlices(u8, &@as([2]u8, .{ 'a', 'b' }), &two);

            const two_comma = try parseFromSlice([2]u8, gpa, ".{'a', 'b',}", null, .{});
            try std.testing.expectEqualSlices(u8, &@as([2]u8, .{ 'a', 'b' }), &two_comma);

            const three = try parseFromSlice([3]u8, gpa, ".{'a', 'b', 'c'}", null, .{});
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, &three);

            const sentinel = try parseFromSlice([3:'z']u8, gpa, ".{'a', 'b', 'c'}", null, .{});
            const expected_sentinel: [3:'z']u8 = .{ 'a', 'b', 'c' };
            try std.testing.expectEqualSlices(u8, &expected_sentinel, &sentinel);
        }

        // Slice literals
        {
            const zero = try parseFromSlice([]const u8, gpa, ".{}", null, .{});
            defer parseFree(gpa, zero);
            try std.testing.expectEqualSlices(u8, @as([]const u8, &.{}), zero);

            const one = try parseFromSlice([]u8, gpa, ".{'a'}", null, .{});
            defer parseFree(gpa, one);
            try std.testing.expectEqualSlices(u8, &.{'a'}, one);

            const two = try parseFromSlice([]const u8, gpa, ".{'a', 'b'}", null, .{});
            defer parseFree(gpa, two);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two);

            const two_comma = try parseFromSlice([]const u8, gpa, ".{'a', 'b',}", null, .{});
            defer parseFree(gpa, two_comma);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b' }, two_comma);

            const three = try parseFromSlice([]u8, gpa, ".{'a', 'b', 'c'}", null, .{});
            defer parseFree(gpa, three);
            try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, three);

            const sentinel = try parseFromSlice([:'z']const u8, gpa, ".{'a', 'b', 'c'}", null, .{});
            defer parseFree(gpa, sentinel);
            const expected_sentinel: [:'z']const u8 = &.{ 'a', 'b', 'c' };
            try std.testing.expectEqualSlices(u8, expected_sentinel, sentinel);
        }
    }

    // Deep free
    {
        // Arrays
        {
            const parsed = try parseFromSlice([1][]const u8, gpa, ".{\"abc\"}", null, .{});
            defer parseFree(gpa, parsed);
            const expected: [1][]const u8 = .{"abc"};
            try std.testing.expectEqualDeep(expected, parsed);
        }

        // Slice literals
        {
            const parsed = try parseFromSlice([]const []const u8, gpa, ".{\"abc\"}", null, .{});
            defer parseFree(gpa, parsed);
            const expected: []const []const u8 = &.{"abc"};
            try std.testing.expectEqualDeep(expected, parsed);
        }
    }

    // Sentinels and alignment
    {
        // Arrays
        {
            const sentinel = try parseFromSlice([1:2]u8, gpa, ".{1}", null, .{});
            try std.testing.expectEqual(@as(usize, 1), sentinel.len);
            try std.testing.expectEqual(@as(u8, 1), sentinel[0]);
            try std.testing.expectEqual(@as(u8, 2), sentinel[1]);
        }

        // Slice literals
        {
            const sentinel = try parseFromSlice([:2]align(4) u8, gpa, ".{1}", null, .{});
            defer parseFree(gpa, sentinel);
            try std.testing.expectEqual(@as(usize, 1), sentinel.len);
            try std.testing.expectEqual(@as(u8, 1), sentinel[0]);
            try std.testing.expectEqual(@as(u8, 2), sentinel[1]);
        }
    }

    // Expect 0 find 3
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice([0]u8, gpa, ".{'a', 'b', 'c'}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 0 fields\n", "{}", .{status});
    }

    // Expect 1 find 2
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice([1]u8, gpa, ".{'a', 'b'}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 1 field\n", "{}", .{status});
    }

    // Expect 2 find 1
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice([2]u8, gpa, ".{'a'}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 2 fields\n", "{}", .{status});
    }

    // Expect 3 find 0
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice([3]u8, gpa, ".{}", &status, .{}));
        try std.testing.expectFmt("1:2: error: expected tuple with 3 fields\n", "{}", .{status});
    }

    // Wrong inner type
    {
        // Array
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([3]bool, gpa, ".{'a', 'b', 'c'}", &status, .{}));
            try std.testing.expectFmt("1:3: error: expected type 'bool'\n", "{}", .{status});
        }

        // Slice
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]bool, gpa, ".{'a', 'b', 'c'}", &status, .{}));
            try std.testing.expectFmt("1:3: error: expected type 'bool'\n", "{}", .{status});
        }
    }

    // Complete wrong type
    {
        // Array
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([3]u8, gpa, "'a'", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple with 3 fields\n", "{}", .{status});
        }

        // Slice
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]u8, gpa, "'a'", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }
    }

    // Address of is not allowed (indirection for slices in ZON is implicit)
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice([]u8, gpa, "  &.{'a', 'b', 'c'}", &status, .{}));
        try std.testing.expectFmt("1:3: error: pointers are not available in ZON\n", "{}", .{status});
    }
}

fn parsePointer(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    node: Zoir.Node.Index,
) error{ OutOfMemory, ParseZon }!T {
    switch (node.get(self.zoir)) {
        .string_literal => |str| return try self.parseString(T, node, str),
        .array_literal => |nodes| return try self.parseSlice(T, options, nodes),
        .empty_literal => return try self.parseSlice(T, options, .{ .start = node, .len = 0 }),
        else => return self.failExpectedContainer(T, node),
    }
}

fn parseString(
    self: *@This(),
    comptime T: type,
    node: Zoir.Node.Index,
    str: []const u8,
) !T {
    const pointer = @typeInfo(T).pointer;

    if (pointer.child != u8 or
        pointer.size != .Slice or
        !pointer.is_const or
        (pointer.sentinel != null and @as(*const u8, @ptrCast(pointer.sentinel)).* != 0) or
        pointer.alignment != 1)
    {
        return self.failExpectedContainer(T, node);
    }

    if (pointer.sentinel) |sentinel| {
        if (@as(*const u8, @ptrCast(sentinel)).* != 0) {
            return self.failExpectedContainer(T, node);
        }
        return try self.gpa.dupeZ(u8, str);
    }

    return self.gpa.dupe(pointer.child, str);
}

fn parseSlice(
    self: *@This(),
    comptime T: type,
    comptime options: Options,
    nodes: Zoir.Node.Index.Range,
) error{ OutOfMemory, ParseZon }!T {
    const pointer = @typeInfo(T).pointer;

    // Make sure we're working with a slice
    switch (pointer.size) {
        .Slice => {},
        .One, .Many, .C => @compileError(@typeName(T) ++ ": non slice pointers not supported"),
    }

    // Allocate the slice
    const sentinel = if (pointer.sentinel) |s| @as(*const pointer.child, @ptrCast(s)).* else null;
    const slice = try self.gpa.allocWithOptions(
        pointer.child,
        nodes.len,
        pointer.alignment,
        sentinel,
    );
    errdefer self.gpa.free(slice);

    // Parse the elements and return the slice
    for (0..nodes.len) |i| {
        errdefer if (options.free_on_error) {
            for (slice[0..i]) |item| {
                parseFree(self.gpa, item);
            }
        };
        slice[i] = try self.parseExpr(pointer.child, options, nodes.at(@intCast(i)));
    }

    return slice;
}

test "std.zon string literal" {
    const gpa = std.testing.allocator;

    // Basic string literal
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"abc\"", null, .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "abc"), parsed);
    }

    // String literal with escape characters
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"ab\\nc\"", null, .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "ab\nc"), parsed);
    }

    // String literal with embedded null
    {
        const parsed = try parseFromSlice([]const u8, gpa, "\"ab\\x00c\"", null, .{});
        defer parseFree(gpa, parsed);
        try std.testing.expectEqualStrings(@as([]const u8, "ab\x00c"), parsed);
    }

    // Passing string literal to a mutable slice
    {
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([]u8, gpa, "\"abcd\"", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }

        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([]u8, gpa, "\\\\abcd", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }
    }

    // Passing string literal to a array
    {
        {
            var ast = try std.zig.Ast.parse(gpa, "\"abcd\"", .zon);
            defer ast.deinit(gpa);
            var zoir = try ZonGen.generate(gpa, ast);
            defer zoir.deinit(gpa);
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([4:0]u8, gpa, "\"abcd\"", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple with 4 fields\n", "{}", .{status});
        }

        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([4:0]u8, gpa, "\\\\abcd", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple with 4 fields\n", "{}", .{status});
        }
    }

    // Zero termianted slices
    {
        {
            const parsed: [:0]const u8 = try parseFromSlice([:0]const u8, gpa, "\"abc\"", null, .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("abc", parsed);
            try std.testing.expectEqual(@as(u8, 0), parsed[3]);
        }

        {
            const parsed: [:0]const u8 = try parseFromSlice([:0]const u8, gpa, "\\\\abc", null, .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("abc", parsed);
            try std.testing.expectEqual(@as(u8, 0), parsed[3]);
        }
    }

    // Other value terminated slices
    {
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([:1]const u8, gpa, "\"foo\"", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }

        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(
                error.ParseZon,
                parseFromSlice([:1]const u8, gpa, "\\\\foo", &status, .{}),
            );
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }
    }

    // Expecting string literal, getting something else
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(
            error.ParseZon,
            parseFromSlice([]const u8, gpa, "true", &status, .{}),
        );
        try std.testing.expectFmt("1:1: error: expected string\n", "{}", .{status});
    }

    // Expecting string literal, getting an incompatible tuple
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(
            error.ParseZon,
            parseFromSlice([]const u8, gpa, ".{false}", &status, .{}),
        );
        try std.testing.expectFmt("1:3: error: expected type 'u8'\n", "{}", .{status});
    }

    // Invalid string literal
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(
            error.ParseZon,
            parseFromSlice([]const i8, gpa, "\"\\a\"", &status, .{}),
        );
        try std.testing.expectFmt("1:3: error: invalid escape character: 'a'\n", "{}", .{status});
    }

    // Slice wrong child type
    {
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]const i8, gpa, "\"a\"", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }

        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]const i8, gpa, "\\\\a", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }
    }

    // Bad alignment
    {
        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]align(2) const u8, gpa, "\"abc\"", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
        }

        {
            var status: Status = .{};
            defer status.deinit(gpa);
            try std.testing.expectError(error.ParseZon, parseFromSlice([]align(2) const u8, gpa, "\\\\abc", &status, .{}));
            try std.testing.expectFmt("1:1: error: expected tuple\n", "{}", .{status});
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
            , null, .{});
            defer parseFree(gpa, parsed);
            try std.testing.expectEqualStrings("hello, world!\nthis is a multiline string!\n\n...", parsed.message);
            try std.testing.expectEqualStrings("this too...sort of.", parsed.message2);
            try std.testing.expectEqualStrings("\nand this.", parsed.message3);
        }
    }
}

fn parseEnumLiteral(self: @This(), comptime T: type, node: Zoir.Node.Index) error{ParseZon}!T {
    switch (node.get(self.zoir)) {
        .enum_literal => |string| {
            // Create a comptime string map for the enum fields
            const enum_fields = @typeInfo(T).@"enum".fields;
            comptime var kvs_list: [enum_fields.len]struct { []const u8, T } = undefined;
            inline for (enum_fields, 0..) |field, i| {
                kvs_list[i] = .{ field.name, @enumFromInt(field.value) };
            }
            const enum_tags = std.StaticStringMap(T).initComptime(kvs_list);

            // Get the tag if it exists
            return enum_tags.get(string.get(self.zoir)) orelse
                self.failUnexpectedField(T, node, null);
        },
        else => return self.failNode(node, "expected enum literal"),
    }
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
    try std.testing.expectEqual(Enum.foo, try parseFromSlice(Enum, gpa, ".foo", null, .{}));
    try std.testing.expectEqual(Enum.bar, try parseFromSlice(Enum, gpa, ".bar", null, .{}));
    try std.testing.expectEqual(Enum.baz, try parseFromSlice(Enum, gpa, ".baz", null, .{}));
    try std.testing.expectEqual(Enum.@"ab\nc", try parseFromSlice(Enum, gpa, ".@\"ab\\nc\"", null, .{}));

    // Bad tag
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Enum, gpa, ".qux", &status, .{}));
        try std.testing.expectFmt(
            "1:2: error: unexpected field, supported fields: foo, bar, baz, @\"ab\\nc\"\n",
            "{}",
            .{status},
        );
    }

    // Bad tag that's too long for parser
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Enum, gpa, ".@\"foobarbaz\"", &status, .{}));
        try std.testing.expectFmt(
            "1:2: error: unexpected field, supported fields: foo, bar, baz, @\"ab\\nc\"\n",
            "{}",
            .{status},
        );
    }

    // Bad type
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(Enum, gpa, "true", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected enum literal\n", "{}", .{status});
    }

    // Test embedded nulls in an identifier
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(
            error.ParseZon,
            parseFromSlice(Enum, gpa, ".@\"\\x00\"", &status, .{}),
        );
        try std.testing.expectFmt("1:2: error: identifier cannot contain null bytes\n", "{}", .{status});
    }
}

fn failToken(self: @This(), token: Ast.TokenIndex, message: []const u8) error{ParseZon} {
    @branchHint(.cold);
    if (self.status) |s| s.type_check = .{
        .token = token,
        .message = message,
    };
    return error.ParseZon;
}

fn failNode(self: @This(), node: Zoir.Node.Index, message: []const u8) error{ParseZon} {
    @branchHint(.cold);
    const main_tokens = self.ast.nodes.items(.main_token);
    const token = main_tokens[node.getAstNode(self.zoir)];
    return self.failToken(token, message);
}

fn failCannotRepresent(self: @This(), comptime T: type, node: Zoir.Node.Index) error{ParseZon} {
    @branchHint(.cold);
    return self.failNode(node, "type '" ++ @typeName(T) ++ "' cannot represent value");
}

fn failUnexpectedField(self: @This(), T: type, node: Zoir.Node.Index, field: ?usize) error{ParseZon} {
    @branchHint(.cold);
    const token = if (field) |f| b: {
        var buf: [2]Ast.Node.Index = undefined;
        const struct_init = self.ast.fullStructInit(&buf, node.getAstNode(self.zoir)).?;
        const field_node = struct_init.ast.fields[f];
        break :b self.ast.firstToken(field_node) - 2;
    } else b: {
        const main_tokens = self.ast.nodes.items(.main_token);
        break :b main_tokens[node.getAstNode(self.zoir)];
    };
    switch (@typeInfo(T)) {
        inline .@"struct", .@"union", .@"enum" => |info| {
            if (info.fields.len == 0) {
                return self.failToken(token, "unexpected field, no fields expected");
            } else {
                comptime var message: []const u8 = "unexpected field, supported fields: ";
                inline for (info.fields, 0..) |field_info, i| {
                    if (i != 0) message = message ++ ", ";
                    const id_formatter = comptime std.zig.fmtId(field_info.name);
                    message = message ++ std.fmt.comptimePrint("{}", .{id_formatter});
                }
                return self.failToken(token, message);
            }
        },
        else => @compileError("unreachable, should not be called for type " ++ @typeName(T)),
    }
}

fn failExpectedTupleWithField(
    self: @This(),
    node: Zoir.Node.Index,
    comptime fields: usize,
) error{ParseZon} {
    const plural = if (fields == 1) "" else "s";
    return self.failNode(
        node,
        std.fmt.comptimePrint("expected tuple with {} field{s}", .{ fields, plural }),
    );
}

fn failExpectedContainer(self: @This(), T: type, node: Zoir.Node.Index) error{ParseZon} {
    @branchHint(.cold);
    switch (@typeInfo(T)) {
        .@"struct" => |@"struct"| if (@"struct".is_tuple) {
            return self.failExpectedTupleWithField(node, @"struct".fields.len);
        } else {
            return self.failNode(node, "expected struct");
        },
        .@"union" => return self.failNode(node, "expected union"),
        .array => |array| return self.failExpectedTupleWithField(node, array.len),
        .pointer => |pointer| {
            if (pointer.child == u8 and
                pointer.size == .Slice and
                pointer.is_const and
                (pointer.sentinel == null or @as(*const u8, @ptrCast(pointer.sentinel)).* == 0) and
                pointer.alignment == 1)
            {
                return self.failNode(node, "expected string");
            } else {
                return self.failNode(node, "expected tuple");
            }
        },
        else => @compileError("unreachable, should not be called for type " ++ @typeName(T)),
    }
}

fn failMissingField(self: @This(), comptime name: []const u8, node: Zoir.Node.Index) error{ParseZon} {
    @branchHint(.cold);
    return self.failNode(node, "missing required field " ++ name);
}

fn failDuplicateField(self: @This(), node: Zoir.Node.Index, field: usize) error{ParseZon} {
    @branchHint(.cold);
    var buf: [2]Ast.Node.Index = undefined;
    const struct_init = self.ast.fullStructInit(&buf, node.getAstNode(self.zoir)).?;
    const field_node = struct_init.ast.fields[field];
    const token = self.ast.firstToken(field_node) - 2;
    return self.failToken(token, "duplicate field");
}

fn parseBool(self: @This(), node: Zoir.Node.Index) error{ParseZon}!bool {
    switch (node.get(self.zoir)) {
        .true => return true,
        .false => return false,
        else => return self.failNode(node, "expected type 'bool'"),
    }
}

test "std.zon parse bool" {
    const gpa = std.testing.allocator;

    // Correct floats
    try std.testing.expectEqual(true, try parseFromSlice(bool, gpa, "true", null, .{}));
    try std.testing.expectEqual(false, try parseFromSlice(bool, gpa, "false", null, .{}));

    // Errors
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(bool, gpa, " foo", &status, .{}));
        try std.testing.expectFmt(
            \\1:2: error: invalid expression
            \\1:2: note: ZON allows identifiers 'true', 'false', 'null', 'inf', and 'nan'
            \\1:2: note: precede identifier with '.' for an enum literal
            \\
        , "{}", .{status});
    }
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(bool, gpa, "123", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'bool'\n", "{}", .{status});
    }
}

fn parseInt(
    self: @This(),
    comptime T: type,
    node: Zoir.Node.Index,
) error{ParseZon}!T {
    switch (node.get(self.zoir)) {
        .int_literal => |int| switch (int) {
            .small => |val| return std.math.cast(T, val) orelse
                self.failCannotRepresent(T, node),
            .big => |val| return val.toInt(T) catch
                self.failCannotRepresent(T, node),
        },
        .float_literal => |val| return intFromFloatExact(T, val) orelse
            self.failCannotRepresent(T, node),

        .char_literal => |val| return std.math.cast(T, val) orelse
            self.failCannotRepresent(T, node),
        else => return self.failNode(node, "expected type '" ++ @typeName(T) ++ "'"),
    }
}

fn parseFloat(
    self: @This(),
    comptime T: type,
    node: Zoir.Node.Index,
) error{ParseZon}!T {
    switch (node.get(self.zoir)) {
        .int_literal => |int| switch (int) {
            .small => |val| return @floatFromInt(val),
            .big => |val| return val.toFloat(T),
        },
        .float_literal => |val| return @floatCast(val),
        .pos_inf => return std.math.inf(T),
        .neg_inf => return -std.math.inf(T),
        .nan => return std.math.nan(T),
        .char_literal => |val| return @floatFromInt(val),
        else => return self.failNode(node, "expected type '" ++ @typeName(T) ++ "'"),
    }
}

fn intFromFloatExact(comptime T: type, value: anytype) ?T {
    switch (@typeInfo(@TypeOf(value))) {
        .float => {},
        else => @compileError(@typeName(@TypeOf(value)) ++ " is not a runtime floating point type"),
    }
    switch (@typeInfo(T)) {
        .int => {},
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
    try std.testing.expectEqual(@as(u8, 10), try parseFromSlice(u8, gpa, "10", null, .{}));
    try std.testing.expectEqual(@as(i16, 24), try parseFromSlice(i16, gpa, "24", null, .{}));
    try std.testing.expectEqual(@as(i14, -4), try parseFromSlice(i14, gpa, "-4", null, .{}));
    try std.testing.expectEqual(@as(i32, -123), try parseFromSlice(i32, gpa, "-123", null, .{}));

    // Test limits
    try std.testing.expectEqual(@as(i8, 127), try parseFromSlice(i8, gpa, "127", null, .{}));
    try std.testing.expectEqual(@as(i8, -128), try parseFromSlice(i8, gpa, "-128", null, .{}));

    // Test characters
    try std.testing.expectEqual(@as(u8, 'a'), try parseFromSlice(u8, gpa, "'a'", null, .{}));
    try std.testing.expectEqual(@as(u8, 'z'), try parseFromSlice(u8, gpa, "'z'", null, .{}));

    // Test big integers
    try std.testing.expectEqual(
        @as(u65, 36893488147419103231),
        try parseFromSlice(u65, gpa, "36893488147419103231", null, .{}),
    );
    try std.testing.expectEqual(
        @as(u65, 36893488147419103231),
        try parseFromSlice(u65, gpa, "368934_881_474191032_31", null, .{}),
    );

    // Test big integer limits
    try std.testing.expectEqual(
        @as(i66, 36893488147419103231),
        try parseFromSlice(i66, gpa, "36893488147419103231", null, .{}),
    );
    try std.testing.expectEqual(
        @as(i66, -36893488147419103232),
        try parseFromSlice(i66, gpa, "-36893488147419103232", null, .{}),
    );
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i66, gpa, "36893488147419103232", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'i66' cannot represent value\n", "{}", .{status});
    }
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i66, gpa, "-36893488147419103233", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'i66' cannot represent value\n", "{}", .{status});
    }

    // Test parsing whole number floats as integers
    try std.testing.expectEqual(@as(i8, -1), try parseFromSlice(i8, gpa, "-1.0", null, .{}));
    try std.testing.expectEqual(@as(i8, 123), try parseFromSlice(i8, gpa, "123.0", null, .{}));

    // Test non-decimal integers
    try std.testing.expectEqual(@as(i16, 0xff), try parseFromSlice(i16, gpa, "0xff", null, .{}));
    try std.testing.expectEqual(@as(i16, -0xff), try parseFromSlice(i16, gpa, "-0xff", null, .{}));
    try std.testing.expectEqual(@as(i16, 0o77), try parseFromSlice(i16, gpa, "0o77", null, .{}));
    try std.testing.expectEqual(@as(i16, -0o77), try parseFromSlice(i16, gpa, "-0o77", null, .{}));
    try std.testing.expectEqual(@as(i16, 0b11), try parseFromSlice(i16, gpa, "0b11", null, .{}));
    try std.testing.expectEqual(@as(i16, -0b11), try parseFromSlice(i16, gpa, "-0b11", null, .{}));

    // Test non-decimal big integers
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0x1ffffffffffffffff",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0x1ffffffffffffffff",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0x1ffffffffffffffff",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0o3777777777777777777777",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0o3777777777777777777777",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0o3777777777777777777777",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(u65, 0x1ffffffffffffffff), try parseFromSlice(
        u65,
        gpa,
        "0b11111111111111111111111111111111111111111111111111111111111111111",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, 0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "0b11111111111111111111111111111111111111111111111111111111111111111",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(i66, -0x1ffffffffffffffff), try parseFromSlice(
        i66,
        gpa,
        "-0b11111111111111111111111111111111111111111111111111111111111111111",
        null,
        .{},
    ));

    // Number with invalid character in the middle
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "32a32", &status, .{}));
        try std.testing.expectFmt("1:3: error: invalid digit 'a' for decimal base\n", "{}", .{status});
    }

    // Failing to parse as int
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "true", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'u8'\n", "{}", .{status});
    }

    // Failing because an int is out of range
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "256", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'u8' cannot represent value\n", "{}", .{status});
    }

    // Failing because a negative int is out of range
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "-129", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'i8' cannot represent value\n", "{}", .{status});
    }

    // Failing because an unsigned int is negative
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "-1", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'u8' cannot represent value\n", "{}", .{status});
    }

    // Failing because a float is non-whole
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "1.5", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'u8' cannot represent value\n", "{}", .{status});
    }

    // Failing because a float is negative
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "-1.0", &status, .{}));
        try std.testing.expectFmt("1:1: error: type 'u8' cannot represent value\n", "{}", .{status});
    }

    // Negative integer zero
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "-0", &status, .{}));
        try std.testing.expectFmt(
            \\1:2: error: integer literal '-0' is ambiguous
            \\1:2: note: use '0' for an integer zero
            \\1:2: note: use '-0.0' for a floating-point signed zero
            \\
        , "{}", .{status});
    }

    // Negative integer zero casted to float
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "-0", &status, .{}));
        try std.testing.expectFmt(
            \\1:2: error: integer literal '-0' is ambiguous
            \\1:2: note: use '0' for an integer zero
            \\1:2: note: use '-0.0' for a floating-point signed zero
            \\
        , "{}", .{status});
    }

    // Negative float 0 is allowed
    try std.testing.expect(std.math.isNegativeZero(try parseFromSlice(f32, gpa, "-0.0", null, .{})));
    try std.testing.expect(std.math.isPositiveZero(try parseFromSlice(f32, gpa, "0.0", null, .{})));

    // Double negation is not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "--2", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }

    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "--2.0", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }

    // Invalid int literal
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "0xg", &status, .{}));
        try std.testing.expectFmt("1:3: error: invalid digit 'g' for hex base\n", "{}", .{status});
    }

    // Notes on invalid int literal
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(u8, gpa, "0123", &status, .{}));
        try std.testing.expectFmt(
            \\1:1: error: number '0123' has leading zero
            \\1:1: note: use '0o' prefix for octal literals
            \\
        , "{}", .{status});
    }
}

test "std.zon negative char" {
    const gpa = std.testing.allocator;

    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "-'a'", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i16, gpa, "-'a'", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }
}

test "std.zon parse float" {
    const gpa = std.testing.allocator;

    // Test decimals
    try std.testing.expectEqual(@as(f16, 0.5), try parseFromSlice(f16, gpa, "0.5", null, .{}));
    try std.testing.expectEqual(@as(f32, 123.456), try parseFromSlice(f32, gpa, "123.456", null, .{}));
    try std.testing.expectEqual(@as(f64, -123.456), try parseFromSlice(f64, gpa, "-123.456", null, .{}));
    try std.testing.expectEqual(@as(f128, 42.5), try parseFromSlice(f128, gpa, "42.5", null, .{}));

    // Test whole numbers with and without decimals
    try std.testing.expectEqual(@as(f16, 5.0), try parseFromSlice(f16, gpa, "5.0", null, .{}));
    try std.testing.expectEqual(@as(f16, 5.0), try parseFromSlice(f16, gpa, "5", null, .{}));
    try std.testing.expectEqual(@as(f32, -102), try parseFromSlice(f32, gpa, "-102.0", null, .{}));
    try std.testing.expectEqual(@as(f32, -102), try parseFromSlice(f32, gpa, "-102", null, .{}));

    // Test characters and negated characters
    try std.testing.expectEqual(@as(f32, 'a'), try parseFromSlice(f32, gpa, "'a'", null, .{}));
    try std.testing.expectEqual(@as(f32, 'z'), try parseFromSlice(f32, gpa, "'z'", null, .{}));

    // Test big integers
    try std.testing.expectEqual(
        @as(f32, 36893488147419103231),
        try parseFromSlice(f32, gpa, "36893488147419103231", null, .{}),
    );
    try std.testing.expectEqual(
        @as(f32, -36893488147419103231),
        try parseFromSlice(f32, gpa, "-36893488147419103231", null, .{}),
    );
    try std.testing.expectEqual(@as(f128, 0x1ffffffffffffffff), try parseFromSlice(
        f128,
        gpa,
        "0x1ffffffffffffffff",
        null,
        .{},
    ));
    try std.testing.expectEqual(@as(f32, 0x1ffffffffffffffff), try parseFromSlice(
        f32,
        gpa,
        "0x1ffffffffffffffff",
        null,
        .{},
    ));

    // Exponents, underscores
    try std.testing.expectEqual(@as(f32, 123.0E+77), try parseFromSlice(f32, gpa, "12_3.0E+77", null, .{}));

    // Hexadecimal
    try std.testing.expectEqual(@as(f32, 0x103.70p-5), try parseFromSlice(f32, gpa, "0x103.70p-5", null, .{}));
    try std.testing.expectEqual(@as(f32, -0x103.70), try parseFromSlice(f32, gpa, "-0x103.70", null, .{}));
    try std.testing.expectEqual(
        @as(f32, 0x1234_5678.9ABC_CDEFp-10),
        try parseFromSlice(f32, gpa, "0x1234_5678.9ABC_CDEFp-10", null, .{}),
    );

    // inf, nan
    try std.testing.expect(std.math.isPositiveInf(try parseFromSlice(f32, gpa, "inf", null, .{})));
    try std.testing.expect(std.math.isNegativeInf(try parseFromSlice(f32, gpa, "-inf", null, .{})));
    try std.testing.expect(std.math.isNan(try parseFromSlice(f32, gpa, "nan", null, .{})));

    // Negative nan not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "-nan", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }

    // nan as int not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "nan", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'i8'\n", "{}", .{status});
    }

    // nan as int not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "nan", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'i8'\n", "{}", .{status});
    }

    // inf as int not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "inf", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'i8'\n", "{}", .{status});
    }

    // -inf as int not allowed
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(i8, gpa, "-inf", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'i8'\n", "{}", .{status});
    }

    // Bad identifier as float
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "foo", &status, .{}));
        try std.testing.expectFmt(
            \\1:1: error: invalid expression
            \\1:1: note: ZON allows identifiers 'true', 'false', 'null', 'inf', and 'nan'
            \\1:1: note: precede identifier with '.' for an enum literal
            \\
        , "{}", .{status});
    }

    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "-foo", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected number or 'inf' after '-'\n", "{}", .{status});
    }

    // Non float as float
    {
        var status: Status = .{};
        defer status.deinit(gpa);
        try std.testing.expectError(error.ParseZon, parseFromSlice(f32, gpa, "\"foo\"", &status, .{}));
        try std.testing.expectFmt("1:1: error: expected type 'f32'\n", "{}", .{status});
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
        try std.testing.expectError(error.ParseZon, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    .x = "hello",
            \\    .y = "world",
            \\    .z = "fail",
            \\}
        , null, .{}));
    }

    // Test freeing partially allocated tuples
    {
        const Struct = struct {
            []const u8,
            []const u8,
            bool,
        };
        try std.testing.expectError(error.ParseZon, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    "world",
            \\    "fail",
            \\}
        , null, .{}));
    }

    // Test freeing structs with missing fields
    {
        const Struct = struct {
            x: []const u8,
            y: bool,
        };
        try std.testing.expectError(error.ParseZon, parseFromSlice(Struct, std.testing.allocator,
            \\.{
            \\    .x = "hello",
            \\}
        , null, .{}));
    }

    // Test freeing partially allocated arrays
    {
        try std.testing.expectError(error.ParseZon, parseFromSlice([3][]const u8, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    false,
            \\    false,
            \\}
        , null, .{}));
    }

    // Test freeing partially allocated slices
    {
        try std.testing.expectError(error.ParseZon, parseFromSlice([][]const u8, std.testing.allocator,
            \\.{
            \\    "hello",
            \\    "world",
            \\    false,
            \\}
        , null, .{}));
    }

    // We can parse types that can't be freed, as long as they contain no allocations, e.g. untagged
    // unions.
    try std.testing.expectEqual(
        @as(f32, 1.5),
        (try parseFromSlice(union { x: f32 }, std.testing.allocator, ".{ .x = 1.5 }", null, .{})).x,
    );

    // We can also parse types that can't be freed if it's impossible for an error to occur after
    // the allocation, as is the case here.
    {
        const result = try parseFromSlice(
            union { x: []const u8 },
            std.testing.allocator,
            ".{ .x = \"foo\" }",
            null,
            .{},
        );
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
        const result = try parseFromSlice(S, std.testing.allocator, ".{ .{ .x = \"foo\" }, true }", null, .{
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
        const result = try parseFromSlice(
            S,
            std.testing.allocator,
            ".{ .a = .{ .x = \"foo\" }, .b = true }",
            null,
            .{
                .free_on_error = false,
            },
        );
        defer parseFree(std.testing.allocator, result.a.x);
        try std.testing.expectEqualStrings("foo", result.a.x);
        try std.testing.expect(result.b);
    }

    // Again but for arrays.
    {
        const S = [2]union { x: []const u8 };
        const result = try parseFromSlice(
            S,
            std.testing.allocator,
            ".{ .{ .x = \"foo\" }, .{ .x = \"bar\" } }",
            null,
            .{
                .free_on_error = false,
            },
        );
        defer parseFree(std.testing.allocator, result[0].x);
        defer parseFree(std.testing.allocator, result[1].x);
        try std.testing.expectEqualStrings("foo", result[0].x);
        try std.testing.expectEqualStrings("bar", result[1].x);
    }

    // Again but for slices.
    {
        const S = []union { x: []const u8 };
        const result = try parseFromSlice(
            S,
            std.testing.allocator,
            ".{ .{ .x = \"foo\" }, .{ .x = \"bar\" } }",
            null,
            .{
                .free_on_error = false,
            },
        );
        defer std.testing.allocator.free(result);
        defer parseFree(std.testing.allocator, result[0].x);
        defer parseFree(std.testing.allocator, result[1].x);
        try std.testing.expectEqualStrings("foo", result[0].x);
        try std.testing.expectEqualStrings("bar", result[1].x);
    }
}
