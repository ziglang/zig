const std = @import("std");
const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("Type.zig");
const Zir = std.zig.Zir;
const AstGen = std.zig.AstGen;
const CompileError = Zcu.CompileError;
const Ast = std.zig.Ast;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const File = Zcu.File;
const LazySrcLoc = Zcu.LazySrcLoc;
const Ref = std.zig.Zir.Inst.Ref;
const NullTerminatedString = InternPool.NullTerminatedString;
const NumberLiteralError = std.zig.number_literal.Error;
const NodeIndex = std.zig.Ast.Node.Index;

const LowerZon = @This();

sema: *Sema,
file: *File,
file_index: Zcu.File.Index,

/// Lowers the given file as ZON.
pub fn lower(
    sema: *Sema,
    file: *File,
    file_index: Zcu.File.Index,
    res_ty: Type,
) CompileError!InternPool.Index {
    const lower_zon: LowerZon = .{
        .sema = sema,
        .file = file,
        .file_index = file_index,
    };
    const tree = lower_zon.file.getTree(lower_zon.sema.gpa) catch unreachable; // Already validated
    if (tree.errors.len != 0) {
        return lower_zon.lowerAstErrors();
    }

    const data = tree.nodes.items(.data);
    const root = data[0].lhs;
    return lower_zon.lowerExpr(root, res_ty);
}

fn lazySrcLoc(self: LowerZon, loc: LazySrcLoc.Offset) !LazySrcLoc {
    return .{
        .base_node_inst = try self.sema.pt.zcu.intern_pool.trackZir(
            self.sema.pt.zcu.gpa,
            .main,
            .{ .file = self.file_index, .inst = .main_struct_inst },
        ),
        .offset = loc,
    };
}

fn fail(
    self: LowerZon,
    loc: LazySrcLoc.Offset,
    comptime format: []const u8,
    args: anytype,
) (Allocator.Error || error{AnalysisFail}) {
    @branchHint(.cold);
    const src_loc = try self.lazySrcLoc(loc);
    const err_msg = try Zcu.ErrorMsg.create(self.sema.pt.zcu.gpa, src_loc, format, args);
    try self.sema.pt.zcu.failed_files.putNoClobber(self.sema.pt.zcu.gpa, self.file, err_msg);
    return error.AnalysisFail;
}

fn lowerAstErrors(self: LowerZon) CompileError {
    const tree = self.file.tree;
    assert(tree.errors.len > 0);

    const gpa = self.sema.gpa;
    const ip = &self.sema.pt.zcu.intern_pool;
    const parse_err = tree.errors[0];

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(gpa);

    // Create the main error
    buf.clearRetainingCapacity();
    try tree.renderError(parse_err, buf.writer(gpa));
    const err_msg = try Zcu.ErrorMsg.create(
        gpa,
        .{
            .base_node_inst = try ip.trackZir(gpa, .main, .{
                .file = self.file_index,
                .inst = .main_struct_inst,
            }),
            .offset = .{ .token_abs = parse_err.token + @intFromBool(parse_err.token_is_prev) },
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
        try self.sema.pt.zcu.errNote(
            .{
                .base_node_inst = try ip.trackZir(gpa, .main, .{
                    .file = self.file_index,
                    .inst = .main_struct_inst,
                }),
                .offset = .{ .byte_abs = byte_abs },
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
        try self.sema.pt.zcu.errNote(
            .{
                .base_node_inst = try ip.trackZir(gpa, .main, .{
                    .file = self.file_index,
                    .inst = .main_struct_inst,
                }),
                .offset = .{ .token_abs = note.token + @intFromBool(note.token_is_prev) },
            },
            err_msg,
            "{s}",
            .{buf.items},
        );
    }

    try self.sema.pt.zcu.failed_files.putNoClobber(gpa, self.file, err_msg);
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
        const gpa = self.sema.gpa;

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
                return self.fail(
                    .{ .byte_abs = offset + @as(u32, @intCast(err.offset())) },
                    "{}",
                    .{err.fmtWithSource(raw_string)},
                );
            },
        }
    }

    return .{
        .bytes = bytes,
        .owned = false,
    };
}

fn identAsNullTerminatedString(self: LowerZon, token: Ast.TokenIndex) !NullTerminatedString {
    var parsed = try self.ident(token);
    defer parsed.deinit(self.sema.gpa);
    const ip = &self.sema.pt.zcu.intern_pool;
    return ip.getOrPutString(self.sema.gpa, self.sema.pt.tid, parsed.bytes, .no_embedded_nulls);
}

const FieldTypes = union(enum) {
    st: struct {
        ty: Type,
        loaded: InternPool.LoadedStructType,
    },
    un: struct {
        ty: Type,
        loaded: InternPool.LoadedEnumType,
    },
    none,

    fn init(ty: ?Type, sema: *Sema) !@This() {
        const t = ty orelse return .none;
        const ip = &sema.pt.zcu.intern_pool;
        switch (t.zigTypeTagOrPoison(sema.pt.zcu) catch return .none) {
            .@"struct" => {
                try t.resolveFully(sema.pt);
                const loaded_struct_type = ip.loadStructType(t.toIntern());
                return .{ .st = .{
                    .ty = t,
                    .loaded = loaded_struct_type,
                } };
            },
            .@"union" => {
                try t.resolveFully(sema.pt);
                const loaded_union_type = ip.loadUnionType(t.toIntern());
                const loaded_tag_type = loaded_union_type.loadTagType(ip);
                return .{ .un = .{
                    .ty = t,
                    .loaded = loaded_tag_type,
                } };
            },
            else => return .none,
        }
    }

    fn get(self: *const @This(), name: NullTerminatedString, zcu: *Zcu) ?Type {
        const ip = &zcu.intern_pool;
        const self_ty, const index = switch (self.*) {
            .st => |st| .{ st.ty, st.loaded.nameIndex(ip, name) orelse return null },
            .un => |un| .{ un.ty, un.loaded.nameIndex(ip, name) orelse return null },
            .none => return null,
        };
        return self_ty.fieldType(index, zcu);
    }
};

fn lowerExpr(self: LowerZon, node: Ast.Node.Index, res_ty: Type) CompileError!InternPool.Index {
    switch (Type.zigTypeTag(res_ty, self.sema.pt.zcu)) {
        .void => return self.lowerVoid(node),
        .bool => return self.lowerBool(node),
        .int, .comptime_int => return self.lowerInt(node, res_ty),
        .float, .comptime_float => return self.lowerFloat(node, res_ty),
        .optional => return self.lowerOptional(node, res_ty),
        .null => return self.lowerNull(node),
        .@"enum" => return self.lowerEnum(node, res_ty),
        .enum_literal => return self.lowerEnumLiteral(node, res_ty),
        .array => return self.lowerArray(node, res_ty),
        .@"struct" => return self.lowerStructOrTuple(node, res_ty),
        .@"union" => return self.lowerUnion(node, res_ty),
        .pointer => return self.lowerPointer(node, res_ty),

        .type,
        .noreturn,
        .undefined,
        .error_union,
        .error_set,
        .@"fn",
        .@"opaque",
        .frame,
        .@"anyframe",
        .vector,
        => return self.fail(.{ .node_abs = node }, "invalid ZON value", .{}),
    }
}

fn lowerVoid(self: LowerZon, node: Ast.Node.Index) !InternPool.Index {
    const tags = self.file.tree.nodes.items(.tag);
    const data = self.file.tree.nodes.items(.data);

    if (tags[node] == .block_two and data[node].lhs == 0 and data[node].rhs == 0) {
        return .void_value;
    }

    return self.fail(.{ .node_abs = node }, "expected void", .{});
}

fn lowerBool(self: LowerZon, node: Ast.Node.Index) !InternPool.Index {
    const gpa = self.sema.gpa;
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);

    if (tags[node] == .identifier) {
        const token = main_tokens[node];
        var litIdent = try self.ident(token);
        defer litIdent.deinit(gpa);

        const BoolIdent = enum { true, false };
        const values = std.StaticStringMap(BoolIdent).initComptime(.{
            .{ "true", .true },
            .{ "false", .false },
        });
        if (values.get(litIdent.bytes)) |value| {
            return switch (value) {
                .true => .bool_true,
                .false => .bool_false,
            };
        }
    }
    return self.fail(.{ .node_abs = node }, "expected bool", .{});
}

fn lowerInt(
    self: LowerZon,
    node: Ast.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);

    const gpa = self.sema.gpa;
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);
    const num_lit_node, const is_negative = if (tags[node] == .negation) b: {
        const data = self.file.tree.nodes.items(.data);
        break :b .{
            data[node].lhs,
            node,
        };
    } else .{
        node,
        null,
    };
    switch (tags[num_lit_node]) {
        .char_literal => {
            const token = main_tokens[num_lit_node];
            const token_bytes = self.file.tree.tokenSlice(token);
            const char = switch (std.zig.string_literal.parseCharLiteral(token_bytes)) {
                .success => |char| char,
                .failure => |err| {
                    const offset = self.file.tree.tokens.items(.start)[token];
                    return self.fail(
                        .{ .byte_abs = offset + @as(u32, @intCast(err.offset())) },
                        "{}",
                        .{err.fmtWithSource(token_bytes)},
                    );
                },
            };
            return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{
                .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .i64 = if (is_negative == null) char else -@as(i64, char) },
                },
            });
        },
        .number_literal => {
            const token = main_tokens[num_lit_node];
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

                            if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                                const int_info = res_ty.intInfo(self.sema.pt.zcu);
                                if (!result.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                                    return self.fail(
                                        .{ .node_abs = num_lit_node },
                                        "type '{}' cannot represent integer value '-{}'",
                                        .{ res_ty.fmt(self.sema.pt), unsigned },
                                    );
                                }
                            }

                            return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                                .ty = res_ty.toIntern(),
                                .storage = .{ .big_int = result.toConst() },
                            } });
                        };

                        if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                            const int_info = res_ty.intInfo(self.sema.pt.zcu);
                            if (std.math.cast(u6, int_info.bits)) |bits| {
                                const min_int: i64 = if (int_info.signedness == .unsigned) 0 else -(@as(i64, 1) << (bits - 1));
                                if (signed < min_int) {
                                    return self.fail(
                                        .{ .node_abs = num_lit_node },
                                        "type '{}' cannot represent integer value '{}'",
                                        .{ res_ty.fmt(self.sema.pt), unsigned },
                                    );
                                }
                            }
                        }

                        return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                            .ty = res_ty.toIntern(),
                            .storage = .{ .i64 = signed },
                        } });
                    } else {
                        if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                            const int_info = res_ty.intInfo(self.sema.pt.zcu);
                            if (std.math.cast(u6, int_info.bits)) |bits| {
                                const max_int: u64 = (@as(u64, 1) << (bits - @intFromBool(int_info.signedness == .signed))) - 1;
                                if (unsigned > max_int) {
                                    return self.fail(
                                        .{ .node_abs = num_lit_node },
                                        "type '{}' cannot represent integer value '{}'",
                                        .{ res_ty.fmt(self.sema.pt), unsigned },
                                    );
                                }
                            }
                        }
                        return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                            .ty = res_ty.toIntern(),
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

                    if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                        const int_info = res_ty.intInfo(self.sema.pt.zcu);
                        if (!big_int.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                            return self.fail(
                                .{ .node_abs = num_lit_node },
                                "type '{}' cannot represent integer value '{}'",
                                .{ res_ty.fmt(self.sema.pt), big_int },
                            );
                        }
                    }

                    return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                        .ty = res_ty.toIntern(),
                        .storage = .{ .big_int = big_int.toConst() },
                    } });
                },
                .float => {
                    const unsigned_float = std.fmt.parseFloat(f128, token_bytes) catch {
                        // Validated by tokenizer
                        unreachable;
                    };
                    const float = if (is_negative == null) unsigned_float else -unsigned_float;

                    // Check for fractional components
                    if (@rem(float, 1) != 0) {
                        return self.fail(
                            .{ .node_abs = num_lit_node },
                            "fractional component prevents float value '{}' from coercion to type '{}'",
                            .{ float, res_ty.fmt(self.sema.pt) },
                        );
                    }

                    // Create a rational representation of the float
                    var rational = try std.math.big.Rational.init(gpa);
                    defer rational.deinit();
                    rational.setFloat(f128, float) catch |err| switch (err) {
                        error.NonFiniteFloat => unreachable,
                        error.OutOfMemory => return error.OutOfMemory,
                    };

                    // The float is reduced in rational.setFloat, so we assert that denominator is equal to one
                    const big_one = std.math.big.int.Const{ .limbs = &.{1}, .positive = true };
                    assert(rational.q.toConst().eqlAbs(big_one));
                    if (is_negative != null) rational.negate();

                    // Check that the result is in range of the result type
                    const int_info = res_ty.intInfo(self.sema.pt.zcu);
                    if (!rational.p.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                        return self.fail(
                            .{ .node_abs = num_lit_node },
                            "float value '{}' cannot be stored in integer type '{}'",
                            .{ float, res_ty.fmt(self.sema.pt) },
                        );
                    }

                    return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{
                        .int = .{
                            .ty = res_ty.toIntern(),
                            .storage = .{ .big_int = rational.p.toConst() },
                        },
                    });
                },
                .failure => |err| return self.failWithNumberError(token, err),
            }
        },
        .identifier => {
            unreachable; // Decide what error to give here
        },
        else => return self.fail(.{ .node_abs = num_lit_node }, "invalid ZON value", .{}),
    }
}

fn lowerFloat(
    self: LowerZon,
    node: Ast.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);

    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);
    const num_lit_node, const is_negative = if (tags[node] == .negation) b: {
        const data = self.file.tree.nodes.items(.data);
        break :b .{
            data[node].lhs,
            node,
        };
    } else .{
        node,
        null,
    };
    switch (tags[num_lit_node]) {
        .char_literal => {
            const token = main_tokens[num_lit_node];
            const token_bytes = self.file.tree.tokenSlice(token);
            var char: i64 = switch (std.zig.string_literal.parseCharLiteral(token_bytes)) {
                .success => |char| char,
                .failure => |err| {
                    const offset = self.file.tree.tokens.items(.start)[token];
                    return self.fail(
                        .{ .byte_abs = offset + @as(u32, @intCast(err.offset())) },
                        "{}",
                        .{err.fmtWithSource(token_bytes)},
                    );
                },
            };
            if (is_negative != null) char = -char;
            return self.sema.pt.intern(.{ .float = .{
                .ty = res_ty.toIntern(),
                .storage = switch (res_ty.toIntern()) {
                    .f16_type => .{ .f16 = @floatFromInt(char) },
                    .f32_type => .{ .f32 = @floatFromInt(char) },
                    .f64_type => .{ .f64 = @floatFromInt(char) },
                    .f80_type => .{ .f80 = @floatFromInt(char) },
                    .f128_type, .comptime_float_type => .{ .f128 = @floatFromInt(char) },
                    else => unreachable,
                },
            } });
        },
        .number_literal => {
            const token = main_tokens[num_lit_node];
            const token_bytes = self.file.tree.tokenSlice(token);

            var float = std.fmt.parseFloat(f128, token_bytes) catch |err| switch (err) {
                error.InvalidCharacter => return self.fail(.{ .node_abs = num_lit_node }, "invalid character", .{}),
            };
            if (is_negative != null) float = -float;

            return self.sema.pt.intern(.{
                .float = .{
                    .ty = res_ty.toIntern(),
                    .storage = switch (res_ty.toIntern()) {
                        .f16_type => .{ .f16 = @floatCast(float) },
                        .f32_type => .{ .f32 = @floatCast(float) },
                        .f64_type => .{ .f64 = @floatCast(float) },
                        .f80_type => .{ .f80 = @floatCast(float) },
                        .f128_type, .comptime_float_type => .{ .f128 = float },
                        else => unreachable,
                    },
                },
            });
        },
        .identifier => {
            switch (Type.zigTypeTag(res_ty, self.sema.pt.zcu)) {
                .float, .comptime_float => {},
                else => return self.fail(.{ .node_abs = num_lit_node }, "invalid ZON value", .{}),
            }
            const token = main_tokens[num_lit_node];
            const bytes = self.file.tree.tokenSlice(token);
            const LitIdent = enum { nan, inf };
            const values = std.StaticStringMap(LitIdent).initComptime(.{
                .{ "nan", .nan },
                .{ "inf", .inf },
            });
            if (values.get(bytes)) |value| {
                return switch (value) {
                    .nan => self.sema.pt.intern(.{
                        .float = .{
                            .ty = res_ty.toIntern(),
                            .storage = switch (res_ty.toIntern()) {
                                .f16_type => .{ .f16 = std.math.nan(f16) },
                                .f32_type => .{ .f32 = std.math.nan(f32) },
                                .f64_type => .{ .f64 = std.math.nan(f64) },
                                .f80_type => .{ .f80 = std.math.nan(f80) },
                                .f128_type, .comptime_float_type => .{ .f128 = std.math.nan(f128) },
                                else => unreachable,
                            },
                        },
                    }),
                    .inf => self.sema.pt.intern(.{
                        .float = .{
                            .ty = res_ty.toIntern(),
                            .storage = switch (res_ty.toIntern()) {
                                .f16_type => .{ .f16 = if (is_negative == null) std.math.inf(f16) else -std.math.inf(f16) },
                                .f32_type => .{ .f32 = if (is_negative == null) std.math.inf(f32) else -std.math.inf(f32) },
                                .f64_type => .{ .f64 = if (is_negative == null) std.math.inf(f64) else -std.math.inf(f64) },
                                .f80_type => .{ .f80 = if (is_negative == null) std.math.inf(f80) else -std.math.inf(f80) },
                                .f128_type, .comptime_float_type => .{ .f128 = if (is_negative == null) std.math.inf(f128) else -std.math.inf(f128) },
                                else => unreachable,
                            },
                        },
                    }),
                };
            }
            return self.fail(.{ .node_abs = num_lit_node }, "use of unknown identifier '{s}'", .{bytes});
        },
        else => return self.fail(.{ .node_abs = num_lit_node }, "invalid ZON value", .{}),
    }
}

fn lowerOptional(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);

    if (tags[node] == .identifier) {
        const token = main_tokens[node];
        const bytes = self.file.tree.tokenSlice(token);
        if (std.mem.eql(u8, bytes, "null")) return .null_value;
    }

    return self.sema.pt.intern(.{ .opt = .{
        .ty = res_ty.toIntern(),
        .val = try self.lowerExpr(node, res_ty.optionalChild(self.sema.pt.zcu)),
    } });
}

fn lowerNull(self: LowerZon, node: Ast.Node.Index) !InternPool.Index {
    const tags = self.file.tree.nodes.items(.tag);
    const main_tokens = self.file.tree.nodes.items(.main_token);

    if (tags[node] == .identifier) {
        const token = main_tokens[node];
        const bytes = self.file.tree.tokenSlice(token);
        if (std.mem.eql(u8, bytes, "null")) return .null_value;
    }

    return self.fail(.{ .node_abs = node }, "invalid ZON value", .{});
}

fn lowerArray(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const gpa = self.sema.gpa;

    const array_info = res_ty.arrayInfo(self.sema.pt.zcu);
    var buf: [2]NodeIndex = undefined;
    const elem_nodes = try self.elements(res_ty, &buf, node);

    if (elem_nodes.len != array_info.len) {
        return self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)});
    }

    const elems = try gpa.alloc(InternPool.Index, array_info.len + @intFromBool(array_info.sentinel != null));
    defer gpa.free(elems);

    for (elem_nodes, 0..) |elem_node, i| {
        elems[i] = try self.lowerExpr(elem_node, array_info.elem_type);
    }

    if (array_info.sentinel) |sentinel| {
        elems[elems.len - 1] = sentinel.toIntern();
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}

fn lowerEnum(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const main_tokens = self.file.tree.nodes.items(.main_token);
    const tags = self.file.tree.nodes.items(.tag);
    const ip = &self.sema.pt.zcu.intern_pool;

    if (tags[node] != .enum_literal) {
        return self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)});
    }

    const field_name = try self.identAsNullTerminatedString(main_tokens[node]);
    const field_index = res_ty.enumFieldIndex(field_name, self.sema.pt.zcu) orelse {
        return self.fail(.{ .node_abs = node }, "enum {} has no member named '{}'", .{
            res_ty.fmt(self.sema.pt),
            field_name.fmt(ip),
        });
    };

    const value = try self.sema.pt.enumValueFieldIndex(res_ty, field_index);

    return value.toIntern();
}

fn lowerEnumLiteral(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const main_tokens = self.file.tree.nodes.items(.main_token);
    const tags = self.file.tree.nodes.items(.tag);
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    if (tags[node] != .enum_literal) {
        return self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)});
    }

    return ip.get(gpa, self.sema.pt.tid, .{
        .enum_literal = try self.identAsNullTerminatedString(main_tokens[node]),
    });
}

fn lowerStructOrTuple(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    return switch (ip.indexToKey(res_ty.toIntern())) {
        .tuple_type => self.lowerTuple(node, res_ty),
        .struct_type => self.lowerStruct(node, res_ty),
        else => self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)}),
    };
}

fn lowerTuple(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    const tuple_info = ip.indexToKey(res_ty.toIntern()).tuple_type;

    var buf: [2]Ast.Node.Index = undefined;
    const elem_nodes = try self.elements(res_ty, &buf, node);

    const field_types = tuple_info.types.get(ip);
    if (elem_nodes.len < field_types.len) {
        return self.fail(.{ .node_abs = node }, "missing tuple field with index {}", .{elem_nodes.len});
    } else if (elem_nodes.len > field_types.len) {
        return self.fail(.{ .node_abs = node }, "index {} outside tuple of length {}", .{
            field_types.len,
            elem_nodes[field_types.len],
        });
    }

    const elems = try gpa.alloc(InternPool.Index, field_types.len);
    defer gpa.free(elems);

    for (elems, elem_nodes, field_types) |*elem, elem_node, field_type| {
        elem.* = try self.lowerExpr(elem_node, Type.fromInterned(field_type));
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}

fn lowerStruct(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    try res_ty.resolveFully(self.sema.pt);
    const struct_info = self.sema.pt.zcu.typeToStruct(res_ty).?;

    var buf: [2]Ast.Node.Index = undefined;
    const field_nodes = try self.fields(res_ty, &buf, node);

    const field_values = try gpa.alloc(InternPool.Index, struct_info.field_names.len);
    defer gpa.free(field_values);

    const field_defaults = struct_info.field_inits.get(ip);
    for (0..field_values.len) |i| {
        field_values[i] = if (i < field_defaults.len) field_defaults[i] else .none;
    }

    for (field_nodes) |field_node| {
        const field_name_token = self.file.tree.firstToken(field_node) - 2;
        const field_name = try self.identAsNullTerminatedString(field_name_token);

        const name_index = struct_info.nameIndex(ip, field_name) orelse {
            return self.fail(
                .{ .node_abs = field_node },
                "unexpected field {}",
                .{field_name.fmt(ip)},
            );
        };

        const field_type = Type.fromInterned(struct_info.field_types.get(ip)[name_index]);
        if (field_values[name_index] != .none) {
            return self.fail(
                .{ .node_abs = field_node },
                "duplicate field {}",
                .{field_name.fmt(ip)},
            );
        }
        field_values[name_index] = try self.lowerExpr(field_node, field_type);
    }

    const field_names = struct_info.field_names.get(ip);
    for (field_values, field_names) |*value, name| {
        if (value.* == .none) return self.fail(
            .{ .node_abs = node },
            "missing field {}",
            .{name.fmt(ip)},
        );
    }

    return self.sema.pt.intern(.{ .aggregate = .{ .ty = res_ty.toIntern(), .storage = .{
        .elems = field_values,
    } } });
}

fn lowerPointer(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const tags = self.file.tree.nodes.items(.tag);

    const ptr_info = res_ty.ptrInfo(self.sema.pt.zcu);

    if (ptr_info.flags.size != .Slice) {
        return self.fail(
            .{ .node_abs = node },
            "ZON import cannot be coerced to non slice pointer",
            .{},
        );
    }

    const string_alignment = ptr_info.flags.alignment == .none or ptr_info.flags.alignment == .@"1";
    const string_sentinel = ptr_info.sentinel == .none or ptr_info.sentinel == .zero_u8;
    if (string_alignment and ptr_info.child == .u8_type and string_sentinel) {
        if (tags[node] == .string_literal or tags[node] == .multiline_string_literal) {
            return self.lowerStringLiteral(node, res_ty);
        }
    }

    var buf: [2]Ast.Node.Index = undefined;
    const elem_nodes = try self.elements(res_ty, &buf, node);
    _ = elem_nodes;
    @panic("unimplemented");
}

fn lowerStringLiteral(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const gpa = self.sema.gpa;
    const ip = &self.sema.pt.zcu.intern_pool;
    const main_tokens = self.file.tree.nodes.items(.main_token);
    const tags = self.file.tree.nodes.items(.tag);
    const data = self.file.tree.nodes.items(.data);

    const token = main_tokens[node];
    const raw_string = self.file.tree.tokenSlice(token);

    var bytes = std.ArrayListUnmanaged(u8){};
    defer bytes.deinit(gpa);
    switch (tags[node]) {
        .string_literal => switch (try std.zig.string_literal.parseWrite(bytes.writer(gpa), raw_string)) {
            .success => {},
            .failure => |err| {
                const offset = self.file.tree.tokens.items(.start)[token];
                return self.fail(
                    .{ .byte_abs = offset + @as(u32, @intCast(err.offset())) },
                    "{}",
                    .{err.fmtWithSource(raw_string)},
                );
            },
        },
        .multiline_string_literal => {
            var parser = std.zig.string_literal.multilineParser(bytes.writer(gpa));
            var tok_i = data[node].lhs;
            while (tok_i <= data[node].rhs) : (tok_i += 1) {
                try parser.line(self.file.tree.tokenSlice(tok_i));
            }
        },
        else => unreachable,
    }

    const string = try ip.getOrPutString(gpa, self.sema.pt.tid, bytes.items, .maybe_embedded_nulls);
    const array_ty = try self.sema.pt.intern(.{ .array_type = .{
        .len = bytes.items.len,
        .sentinel = .zero_u8,
        .child = .u8_type,
    } });
    const array_val = try self.sema.pt.intern(.{ .aggregate = .{
        .ty = array_ty,
        .storage = .{ .bytes = string },
    } });
    return self.sema.pt.intern(.{ .slice = .{
        .ty = res_ty.toIntern(),
        .ptr = try self.sema.pt.intern(.{ .ptr = .{
            .ty = .manyptr_const_u8_sentinel_0_type,
            .base_addr = .{ .uav = .{
                .orig_ty = .slice_const_u8_sentinel_0_type,
                .val = array_val,
            } },
            .byte_offset = 0,
        } }),
        .len = (try self.sema.pt.intValue(Type.usize, bytes.items.len)).toIntern(),
    } });
}

fn lowerUnion(self: LowerZon, node: Ast.Node.Index, res_ty: Type) !InternPool.Index {
    const tags = self.file.tree.nodes.items(.tag);
    const ip = &self.sema.pt.zcu.intern_pool;
    const main_tokens = self.file.tree.nodes.items(.main_token);

    try res_ty.resolveFully(self.sema.pt);
    const union_info = self.sema.pt.zcu.typeToUnion(res_ty).?;
    const enum_tag_info = union_info.loadTagType(ip);

    const field_name, const maybe_field_node = if (tags[node] == .enum_literal) b: {
        const field_name = try self.identAsNullTerminatedString(main_tokens[node]);
        break :b .{ field_name, null };
    } else b: {
        var buf: [2]Ast.Node.Index = undefined;
        const field_nodes = try self.fields(res_ty, &buf, node);
        if (field_nodes.len > 1) {
            return self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)});
        }
        const field_node = field_nodes[0];
        const field_name_token = self.file.tree.firstToken(field_node) - 2;
        const field_name = try self.identAsNullTerminatedString(field_name_token);
        break :b .{ field_name, field_node };
    };

    const name_index = enum_tag_info.nameIndex(ip, field_name) orelse {
        return self.fail(.{ .node_abs = node }, "expected {}", .{res_ty.fmt(self.sema.pt)});
    };
    const tag_int = if (enum_tag_info.values.len == 0) b: {
        // Auto numbered fields
        break :b try self.sema.pt.intern(.{ .int = .{
            .ty = enum_tag_info.tag_ty,
            .storage = .{ .u64 = name_index },
        } });
    } else b: {
        // Explicitly numbered fields
        break :b enum_tag_info.values.get(ip)[name_index];
    };
    const tag = try self.sema.pt.intern(.{ .enum_tag = .{
        .ty = union_info.enum_tag_ty,
        .int = tag_int,
    } });
    const field_type = Type.fromInterned(union_info.field_types.get(ip)[name_index]);
    const val = if (maybe_field_node) |field_node| b: {
        break :b try self.lowerExpr(field_node, field_type);
    } else b: {
        if (field_type.toIntern() != .void_type) {
            return self.fail(.{ .node_abs = node }, "expected {}", .{field_type.fmt(self.sema.pt)});
        }
        break :b .void_value;
    };
    return ip.getUnion(self.sema.pt.zcu.gpa, self.sema.pt.tid, .{
        .ty = res_ty.toIntern(),
        .tag = tag,
        .val = val,
    });
}

fn fields(
    self: LowerZon,
    container: Type,
    buf: *[2]NodeIndex,
    node: NodeIndex,
) ![]const NodeIndex {
    if (self.file.tree.fullStructInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.fail(.{ .node_abs = node }, "ZON cannot contain type expressions", .{});
        }
        return init.ast.fields;
    }

    if (self.file.tree.fullArrayInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.fail(.{ .node_abs = node }, "ZON cannot contain type expressions", .{});
        }
        if (init.ast.elements.len != 0) {
            return self.fail(.{ .node_abs = node }, "expected {}", .{container.fmt(self.sema.pt)});
        }
        return init.ast.elements;
    }

    return self.fail(.{ .node_abs = node }, "expected {}", .{container.fmt(self.sema.pt)});
}

fn elements(
    self: LowerZon,
    container: Type,
    buf: *[2]NodeIndex,
    node: NodeIndex,
) ![]const NodeIndex {
    if (self.file.tree.fullArrayInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.fail(.{ .node_abs = node }, "ZON cannot contain type expressions", .{});
        }
        return init.ast.elements;
    }

    if (self.file.tree.fullStructInit(buf, node)) |init| {
        if (init.ast.type_expr != 0) {
            return self.fail(.{ .node_abs = node }, "ZON cannot contain type expressions", .{});
        }
        if (init.ast.fields.len == 0) {
            return init.ast.fields;
        }
    }

    return self.fail(.{ .node_abs = node }, "expected {}", .{container.fmt(self.sema.pt)});
}

fn createErrorWithOptionalNote(
    self: LowerZon,
    src_loc: LazySrcLoc,
    comptime fmt: []const u8,
    args: anytype,
    note: ?[]const u8,
) error{OutOfMemory}!*Zcu.ErrorMsg {
    const notes = try self.sema.pt.zcu.gpa.alloc(Zcu.ErrorMsg, if (note == null) 0 else 1);
    errdefer self.sema.pt.zcu.gpa.free(notes);
    if (note) |n| {
        notes[0] = try Zcu.ErrorMsg.init(
            self.sema.pt.zcu.gpa,
            src_loc,
            "{s}",
            .{n},
        );
    }

    const err_msg = try Zcu.ErrorMsg.create(
        self.sema.pt.zcu.gpa,
        src_loc,
        fmt,
        args,
    );
    err_msg.*.notes = notes;
    return err_msg;
}

fn failWithNumberError(
    self: LowerZon,
    token: Ast.TokenIndex,
    err: NumberLiteralError,
) (Allocator.Error || error{AnalysisFail}) {
    const offset = self.file.tree.tokens.items(.start)[token];
    const src_loc = try self.lazySrcLoc(.{ .byte_abs = offset + @as(u32, @intCast(err.offset())) });
    const token_bytes = self.file.tree.tokenSlice(token);
    const err_msg = try self.createErrorWithOptionalNote(
        src_loc,
        "{}",
        .{err.fmtWithSource(token_bytes)},
        err.noteWithSource(token_bytes),
    );
    try self.sema.pt.zcu.failed_files.putNoClobber(self.sema.pt.zcu.gpa, self.file, err_msg);
    return error.AnalysisFail;
}
