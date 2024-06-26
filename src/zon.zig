const std = @import("std");
const Zcu = @import("Zcu.zig");
const InternPool = @import("InternPool.zig");
const AstGen = std.zig.AstGen;
const CompileError = Zcu.CompileError;
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const File = Zcu.File;
const LazySrcLoc = Zcu.LazySrcLoc;

const LowerZon = @This();

zcu: *Zcu,
file: *File,

pub fn lower(zcu: *Zcu, file: *File) CompileError!InternPool.Index {
    const lower_zon: LowerZon = .{ .zcu = zcu, .file = file };
    const tree = lower_zon.file.getTree(lower_zon.zcu.gpa) catch unreachable; // Already validated
    if (tree.errors.len != 0) {
        return lower_zon.lowerAstErrors();
    }

    const data = tree.nodes.items(.data);
    const root = data[0].lhs;
    return lower_zon.expr(root);
}

fn fail(
    self: LowerZon,
    loc: LazySrcLoc.Offset,
    comptime format: []const u8,
    args: anytype,
) (Allocator.Error || error{AnalysisFail}) {
    @setCold(true);

    const src_loc = .{
        .file_scope = self.file,
        .base_node = 0,
        .lazy = loc,
    };
    const err_msg = try Zcu.ErrorMsg.create(self.zcu.gpa, src_loc, format, args);
    try self.zcu.failed_files.putNoClobber(self.zcu.gpa, self.file, err_msg);
    return error.AnalysisFail;
}

fn failWithStrLitError(
    self: LowerZon,
    _: Ast.TokenIndex,
    byte_abs: u32,
    comptime format: []const u8,
    args: anytype,
) (Allocator.Error || error{AnalysisFail}) {
    return self.fail(.{ .byte_abs = byte_abs }, format, args);
}

fn numberError(
    self: LowerZon,
    _: Ast.TokenIndex,
    byte_abs: u32,
    comptime format: []const u8,
    args: anytype,
    notes: []const u32,
) Allocator.Error!void {
    _ = notes;
    switch (self.fail(.{ .byte_abs = byte_abs }, format, args)) {
        error.AnalysisFail => {},
        else => |err| return err,
    }
}

fn errNote(self: LowerZon, token: Ast.TokenIndex, comptime format: []const u8, args: anytype) Allocator.Error!u32 {
    _ = self;
    _ = token;
    _ = format;
    _ = args;
    return 0;
}

fn lowerAstErrors(self: LowerZon) CompileError {
    const tree = self.file.tree;
    assert(tree.errors.len > 0);

    const gpa = self.zcu.gpa;
    const parse_err = tree.errors[0];

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(gpa);

    // Create the main error
    buf.clearRetainingCapacity();
    try tree.renderError(parse_err, buf.writer(gpa));
    const err_msg = try Zcu.ErrorMsg.create(
        gpa,
        .{
            .file_scope = self.file,
            .base_node = 0,
            .lazy = .{ .token_abs = parse_err.token + @intFromBool(parse_err.token_is_prev) },
        },
        "{s}",
        .{buf.items},
    );

    // Check for invalid bytes
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);
    if (token_tags[parse_err.token + @intFromBool(parse_err.token_is_prev)] == .invalid) {
        const bad_off: u32 = @intCast(tree.tokenSlice(parse_err.token + @intFromBool(parse_err.token_is_prev)).len);
        const byte_abs = token_starts[parse_err.token + @intFromBool(parse_err.token_is_prev)] + bad_off;
        try self.zcu.errNoteNonLazy(
            .{
                .file_scope = self.file,
                .base_node = 0,
                .lazy = .{ .byte_abs = byte_abs },
            },
            err_msg,
            "invalid byte: '{'}'",
            .{std.zig.fmtEscapes(tree.source[byte_abs..][0..1])},
        );
    }

    // Create the notes
    for (tree.errors[1..]) |note| {
        if (!note.is_note) break;

        buf.clearRetainingCapacity();
        try tree.renderError(note, buf.writer(gpa));
        try self.zcu.errNoteNonLazy(
            .{
                .file_scope = self.file,
                .base_node = 0,
                .lazy = .{ .token_abs = note.token + @intFromBool(note.token_is_prev) },
            },
            err_msg,
            "{s}",
            .{buf.items},
        );
    }

    try self.zcu.failed_files.putNoClobber(gpa, self.file, err_msg);
    return error.AnalysisFail;
}

const Ident = struct {
    bytes: []const u8,
    owned: bool,

    fn deinit(self: *Ident, allocator: Allocator) void {
        if (self.owned) {
            allocator.free(self.bytes);
        }
        self.* = undefined;
    }
};

fn ident(self: LowerZon, token: Ast.TokenIndex) !Ident {
    var bytes = self.file.tree.tokenSlice(token);

    if (bytes[0] == '@' and bytes[1] == '"') {
        const gpa = self.zcu.gpa;

        const raw_string = bytes[1..bytes.len];
        var parsed = std.ArrayListUnmanaged(u8){};
        defer parsed.deinit(gpa);

        switch (try std.zig.string_literal.parseWrite(parsed.writer(gpa), raw_string)) {
            .success => {
                if (std.mem.indexOfScalar(u8, parsed.items, 0) != null) {
                    return self.fail(.{ .token_abs = token }, "identifier cannot contain null bytes", .{});
                }
                return .{
                    .bytes = try parsed.toOwnedSlice(gpa),
                    .owned = true,
                };
            },
            .failure => |err| {
                const offset = self.file.tree.tokens.items(.start)[token];
                return AstGen.failWithStrLitError(
                    self,
                    failWithStrLitError,
                    err,
                    token,
                    raw_string,
                    offset,
                );
            },
        }
    }

    return .{
        .bytes = bytes,
        .owned = false,
    };
}

fn identAsNullTerminatedString(self: LowerZon, token: Ast.TokenIndex) !InternPool.NullTerminatedString {
    var parsed = try self.ident(token);
    defer parsed.deinit(self.zcu.gpa);
    return try self.zcu.intern_pool.getOrPutString(self.zcu.gpa, parsed.bytes, .no_embedded_nulls);
}

fn expr(self: LowerZon, node: Ast.Node.Index) !InternPool.Index {
    const gpa = self.zcu.gpa;
    const data = self.file.tree.nodes.items(.data);
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);
    switch (tags[node]) {
        .identifier => {
            const token = main_tokens[node];
            var litIdent = try self.ident(token);
            defer litIdent.deinit(gpa);

            const LitIdent = enum { true, false, null, nan, inf };
            const values = std.StaticStringMap(LitIdent).initComptime(.{
                .{ "true", .true },
                .{ "false", .false },
                .{ "null", .null },
                .{ "nan", .nan },
                .{ "inf", .inf },
            });
            if (values.get(litIdent.bytes)) |value| {
                return switch (value) {
                    .true => .bool_true,
                    .false => .bool_false,
                    .null => .null_value,
                    .nan => self.zcu.intern(.{ .float = .{
                        .ty = try self.zcu.intern(.{ .simple_type = .comptime_float }),
                        .storage = .{ .f128 = std.math.nan(f128) },
                    } }),
                    .inf => try self.zcu.intern(.{ .float = .{
                        .ty = try self.zcu.intern(.{ .simple_type = .comptime_float }),
                        .storage = .{ .f128 = std.math.inf(f128) },
                    } }),
                };
            }
            return self.fail(.{ .node_abs = node }, "use of unknown identifier '{s}'", .{litIdent.bytes});
        },
        .number_literal, .char_literal => return self.number(node, null),
        .negation => return self.number(data[node].lhs, node),
        .enum_literal => return self.zcu.intern_pool.get(gpa, .{
            .enum_literal = try self.identAsNullTerminatedString(main_tokens[node]),
        }),
        .string_literal => {
            const token = main_tokens[node];
            const raw_string = self.file.tree.tokenSlice(token);

            var bytes = std.ArrayListUnmanaged(u8){};
            defer bytes.deinit(gpa);

            switch (try std.zig.string_literal.parseWrite(bytes.writer(gpa), raw_string)) {
                .success => {},
                .failure => |err| {
                    const offset = self.file.tree.tokens.items(.start)[token];
                    return AstGen.failWithStrLitError(
                        self,
                        failWithStrLitError,
                        err,
                        token,
                        raw_string,
                        offset,
                    );
                },
            }

            const array_ty = try self.zcu.arrayType(.{
                .len = bytes.items.len,
                .sentinel = .zero_u8,
                .child = .u8_type,
            });
            const val = try self.zcu.intern(.{ .aggregate = .{
                .ty = array_ty.toIntern(),
                .storage = .{ .bytes = try self.zcu.intern_pool.getOrPutString(gpa, bytes.items, .maybe_embedded_nulls) },
            } });
            const ptr_ty = (try self.zcu.ptrType(.{
                .child = array_ty.toIntern(),
                .flags = .{
                    .alignment = .none,
                    .is_const = true,
                    .address_space = .generic,
                },
            })).toIntern();
            return try self.zcu.intern(.{ .ptr = .{
                .ty = ptr_ty,
                .base_addr = .{ .anon_decl = .{ .val = val, .orig_ty = ptr_ty } },
                .byte_offset = 0,
            } });
        },
        .multiline_string_literal => {
            var bytes = std.ArrayListUnmanaged(u8){};
            defer bytes.deinit(gpa);

            var parser = std.zig.string_literal.multilineParser(bytes.writer(gpa));
            var tok_i = data[node].lhs;
            while (tok_i <= data[node].rhs) : (tok_i += 1) {
                try parser.line(self.file.tree.tokenSlice(tok_i));
            }

            const array_ty = try self.zcu.arrayType(.{ .len = bytes.items.len, .sentinel = .zero_u8, .child = .u8_type });
            const val = try self.zcu.intern(.{ .aggregate = .{
                .ty = array_ty.toIntern(),
                .storage = .{
                    .bytes = (try self.zcu.intern_pool.getOrPutString(gpa, bytes.items, .no_embedded_nulls)).toString(),
                },
            } });
            const ptr_ty = (try self.zcu.ptrType(.{
                .child = array_ty.toIntern(),
                .flags = .{
                    .alignment = .none,
                    .is_const = true,
                    .address_space = .generic,
                },
            })).toIntern();
            return try self.zcu.intern(.{ .ptr = .{
                .ty = ptr_ty,
                .base_addr = .{ .anon_decl = .{ .val = val, .orig_ty = ptr_ty } },
                .byte_offset = 0,
            } });
        },
        .struct_init_one, .struct_init_one_comma, .struct_init_dot_two, .struct_init_dot_two_comma, .struct_init_dot, .struct_init_dot_comma, .struct_init, .struct_init_comma => {
            var buf: [2]Ast.Node.Index = undefined;
            const struct_init = self.file.tree.fullStructInit(&buf, node).?;
            if (struct_init.ast.type_expr != 0) {
                return self.fail(.{ .node_abs = struct_init.ast.type_expr }, "type expressions not allowed in ZON", .{});
            }
            const types = try gpa.alloc(InternPool.Index, struct_init.ast.fields.len);
            defer gpa.free(types);

            const values = try gpa.alloc(InternPool.Index, struct_init.ast.fields.len);
            defer gpa.free(values);

            var names = std.AutoArrayHashMapUnmanaged(InternPool.NullTerminatedString, void){};
            defer names.deinit(gpa);
            try names.ensureTotalCapacity(gpa, struct_init.ast.fields.len);

            for (struct_init.ast.fields, 0..) |field, i| {
                values[i] = try self.expr(field);
                types[i] = self.zcu.intern_pool.typeOf(values[i]);

                const name_token = self.file.tree.firstToken(field) - 2;
                const name = try self.identAsNullTerminatedString(name_token);
                const gop = names.getOrPutAssumeCapacity(name);
                if (gop.found_existing) {
                    return self.fail(.{ .token_abs = name_token }, "duplicate field", .{});
                }
            }

            const struct_type = try self.zcu.intern_pool.getAnonStructType(gpa, .{
                .types = types,
                .names = names.entries.items(.key),
                .values = values,
            });
            return self.zcu.intern_pool.get(gpa, .{ .aggregate = .{
                .ty = struct_type,
                .storage = .{ .elems = values },
            } });
        },
        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const array_init = self.file.tree.fullArrayInit(&buf, node).?;
            if (array_init.ast.type_expr != 0) {
                return self.fail(.{ .node_abs = array_init.ast.type_expr }, "type expressions not allowed in ZON", .{});
            }
            const types = try gpa.alloc(InternPool.Index, array_init.ast.elements.len);
            defer gpa.free(types);
            const values = try gpa.alloc(InternPool.Index, array_init.ast.elements.len);
            defer gpa.free(values);
            for (array_init.ast.elements, 0..) |element, i| {
                values[i] = try self.expr(element);
                types[i] = self.zcu.intern_pool.typeOf(values[i]);
            }
            const tuple_type = try self.zcu.intern_pool.getAnonStructType(gpa, .{
                .types = types,
                .names = &.{},
                .values = values,
            });
            return self.zcu.intern_pool.get(gpa, .{ .aggregate = .{
                .ty = tuple_type,
                .storage = .{ .elems = values },
            } });
        },
        .block_two => if (data[node].lhs == 0 and data[node].rhs == 0) {
            return .void_value;
        } else {
            return self.fail(.{ .node_abs = node }, "invalid ZON value", .{});
        },
        .address_of => {
            const child_node = data[node].lhs;
            switch (tags[child_node]) {
                .array_init_one, .array_init_one_comma, .array_init_dot_two, .array_init_dot_two_comma, .array_init_dot, .array_init_dot_comma, .array_init, .array_init_comma => {
                    const value = try self.expr(child_node);
                    const ty = try self.zcu.intern_pool.get(gpa, .{ .ptr_type = .{
                        .child = self.zcu.intern_pool.typeOf(value),
                    } });
                    return self.zcu.intern_pool.get(gpa, .{ .ptr = .{
                        .ty = ty,
                        .base_addr = .{ .anon_decl = .{ .orig_ty = ty, .val = value } },
                        .byte_offset = 0,
                    } });
                },
                .struct_init_one,
                .struct_init_one_comma,
                .struct_init_dot_two,
                .struct_init_dot_two_comma,
                .struct_init_dot,
                .struct_init_dot_comma,
                .struct_init,
                .struct_init_comma,
                => {
                    var buf: [2]Ast.Node.Index = undefined;
                    const full = self.file.tree.fullStructInit(&buf, child_node).?.ast.fields;
                    if (full.len == 0) {
                        const value = .empty_struct;
                        const ty = try self.zcu.intern_pool.get(gpa, .{ .ptr_type = .{
                            .child = self.zcu.intern_pool.typeOf(value),
                        } });
                        return self.zcu.intern_pool.get(gpa, .{ .ptr = .{
                            .ty = ty,
                            .base_addr = .{ .anon_decl = .{ .orig_ty = ty, .val = value } },
                            .byte_offset = 0,
                        } });
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    return self.fail(.{ .node_abs = node }, "invalid ZON value", .{});
}

fn numberOrNegation(self: LowerZon, node: Ast.Node.Index) !InternPool.Index {
    const data = self.file.tree.nodes.items(.data);
    const tags = self.file.tree.nodes.items(.tag);
    switch (tags[node]) {
        .negation => self.number(data[node].lhs, true),
        _ => self.number(node, false),
    }
}

fn number(self: LowerZon, node: Ast.Node.Index, is_negative: ?Ast.Node.Index) !InternPool.Index {
    const gpa = self.zcu.gpa;
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);
    switch (tags[node]) {
        .char_literal => {
            const token = main_tokens[node];
            const token_bytes = self.file.tree.tokenSlice(token);
            const char = switch (std.zig.string_literal.parseCharLiteral(token_bytes)) {
                .success => |char| char,
                .failure => |err| return AstGen.failWithStrLitError(
                    self,
                    failWithStrLitError,
                    err,
                    token,
                    token_bytes,
                    0,
                ),
            };
            return self.zcu.intern_pool.get(gpa, .{ .int = .{
                .ty = try self.zcu.intern(.{ .simple_type = .comptime_int }),
                .storage = .{ .i64 = if (is_negative == null) char else -@as(i64, char) },
            } });
        },
        .number_literal => {
            const token = main_tokens[node];
            const token_bytes = self.file.tree.tokenSlice(token);
            const parsed = std.zig.number_literal.parseNumberLiteral(token_bytes);
            switch (parsed) {
                .int => |unsigned| {
                    if (is_negative) |negative_node| {
                        if (unsigned == 0) {
                            return self.fail(.{ .node_abs = negative_node }, "integer literal '-0' is ambiguous", .{});
                        }
                        const signed = std.math.negateCast(unsigned) catch {
                            var result = try std.math.big.int.Managed.initSet(gpa, unsigned);
                            defer result.deinit();
                            result.negate();
                            return self.zcu.intern_pool.get(gpa, .{ .int = .{
                                .ty = .comptime_int_type,
                                .storage = .{ .big_int = result.toConst() },
                            } });
                        };
                        return self.zcu.intern_pool.get(gpa, .{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .i64 = signed },
                        } });
                    } else {
                        return self.zcu.intern_pool.get(gpa, .{ .int = .{
                            .ty = .comptime_int_type,
                            .storage = .{ .u64 = unsigned },
                        } });
                    }
                },
                .big_int => |base| {
                    var big_int = try std.math.big.int.Managed.init(gpa);
                    defer big_int.deinit();

                    const prefix_offset: usize = if (base == .decimal) 0 else 2;
                    big_int.setString(@intFromEnum(base), token_bytes[prefix_offset..]) catch |err| switch (err) {
                        error.InvalidCharacter => unreachable, // caught in `parseNumberLiteral`
                        error.InvalidBase => unreachable, // we only pass 16, 8, 2, see above
                        error.OutOfMemory => return error.OutOfMemory,
                    };

                    assert(big_int.isPositive());

                    if (is_negative != null) big_int.negate();

                    return self.zcu.intern_pool.get(gpa, .{ .int = .{
                        .ty = try self.zcu.intern(.{ .simple_type = .comptime_int }),
                        .storage = .{ .big_int = big_int.toConst() },
                    } });
                },
                .float => {
                    const unsigned_float = std.fmt.parseFloat(f128, token_bytes) catch unreachable; // Already validated
                    const float = if (is_negative == null) unsigned_float else -unsigned_float;
                    return try self.zcu.intern(.{ .float = .{
                        .ty = try self.zcu.intern(.{ .simple_type = .comptime_float }),
                        .storage = .{ .f128 = float },
                    } });
                },
                .failure => |err| return AstGen.failWithNumberError(
                    self,
                    numberError,
                    errNote,
                    err,
                    token,
                    token_bytes,
                ),
            }
        },
        .identifier => {
            const token = main_tokens[node];
            const bytes = self.file.tree.tokenSlice(token);
            const LitIdent = enum { nan, inf };
            const values = std.StaticStringMap(LitIdent).initComptime(.{
                .{ "nan", .nan },
                .{ "inf", .inf },
            });
            if (values.get(bytes)) |value| {
                return switch (value) {
                    .nan => self.zcu.intern(.{ .float = .{
                        .ty = try self.zcu.intern(.{ .simple_type = .comptime_float }),
                        .storage = .{ .f128 = std.math.nan(f128) },
                    } }),
                    .inf => try self.zcu.intern(.{
                        .float = .{ .ty = try self.zcu.intern(.{ .simple_type = .comptime_float }), .storage = .{ .f128 = if (is_negative == null) std.math.inf(f128) else -std.math.inf(f128) } },
                    }),
                };
            }
            return self.fail(.{ .node_abs = node }, "use of unknown identifier '{s}'", .{bytes});
        },
        else => return self.fail(.{ .node_abs = node }, "invalid ZON value", .{}),
    }
}
