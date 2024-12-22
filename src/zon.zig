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
const Zoir = std.zig.Zoir;

const LowerZon = @This();

sema: *Sema,
file: *File,
file_index: Zcu.File.Index,
import_loc: LazySrcLoc,

/// Lowers the given file as ZON.
pub fn lower(
    sema: *Sema,
    file: *File,
    file_index: Zcu.File.Index,
    res_ty: Type,
    import_loc: LazySrcLoc,
) CompileError!InternPool.Index {
    assert(file.tree_loaded);

    const zoir = try file.getZoir(sema.gpa);

    if (zoir.hasCompileErrors()) {
        try sema.pt.zcu.failed_files.putNoClobber(sema.gpa, file, null);
        return error.AnalysisFail;
    }

    const lower_zon: LowerZon = .{
        .sema = sema,
        .file = file,
        .file_index = file_index,
        .import_loc = import_loc,
    };

    return lower_zon.lowerExpr(.root, res_ty);
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
    try self.sema.pt.zcu.errNote(self.import_loc, err_msg, "imported here", .{});
    try self.sema.pt.zcu.failed_files.putNoClobber(self.sema.pt.zcu.gpa, self.file, err_msg);
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
        var parsed: std.ArrayListUnmanaged(u8) = .{};
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

fn lowerExpr(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) CompileError!InternPool.Index {
    switch (Type.zigTypeTag(res_ty, self.sema.pt.zcu)) {
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
        .void,
        => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "type '{}' not available in ZON",
            .{res_ty.fmt(self.sema.pt)},
        ),
    }
}

fn lowerBool(self: LowerZon, node: Zoir.Node.Index) !InternPool.Index {
    return switch (node.get(self.file.zoir.?)) {
        .true => .bool_true,
        .false => .bool_false,
        else => self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type 'bool'",
            .{},
        ),
    };
}

fn lowerInt(
    self: LowerZon,
    node: Zoir.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);
    const gpa = self.sema.gpa;
    return switch (node.get(self.file.zoir.?)) {
        .int_literal => |int| switch (int) {
            .small => |val| {
                const rhs: i32 = val;

                // If our result is a fixed size integer, check that our value is not out of bounds
                if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                    const lhs_info = res_ty.intInfo(self.sema.pt.zcu);

                    // If lhs is unsigned and rhs is less than 0, we're out of bounds
                    if (lhs_info.signedness == .unsigned and rhs < 0) return self.fail(
                        .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                        "type '{}' cannot represent integer value '{}'",
                        .{ res_ty.fmt(self.sema.pt), rhs },
                    );

                    // If lhs has less than the 32 bits rhs can hold, we need to check the max and
                    // min values
                    if (std.math.cast(u5, lhs_info.bits)) |bits| {
                        const min_int: i32 = if (lhs_info.signedness == .unsigned or bits == 0) b: {
                            break :b 0;
                        } else b: {
                            break :b -(@as(i32, 1) << (bits - 1));
                        };
                        const max_int: i32 = if (bits == 0) b: {
                            break :b 0;
                        } else b: {
                            break :b (@as(i32, 1) << (bits - @intFromBool(lhs_info.signedness == .signed))) - 1;
                        };
                        if (rhs < min_int or rhs > max_int) {
                            return self.fail(
                                .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                                "type '{}' cannot represent integer value '{}'",
                                .{ res_ty.fmt(self.sema.pt), rhs },
                            );
                        }
                    }
                }

                return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .i64 = rhs },
                } });
            },
            .big => |val| {
                if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                    const int_info = res_ty.intInfo(self.sema.pt.zcu);
                    if (!val.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                        return self.fail(
                            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                            "type '{}' cannot represent integer value '{}'",
                            .{ res_ty.fmt(self.sema.pt), val },
                        );
                    }
                }

                return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{ .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .big_int = val },
                } });
            },
        },
        .float_literal => |val| {
            // Check for fractional components
            if (@rem(val, 1) != 0) {
                return self.fail(
                    .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                    "fractional component prevents float value '{}' from coercion to type '{}'",
                    .{ val, res_ty.fmt(self.sema.pt) },
                );
            }

            // Create a rational representation of the float
            var rational = try std.math.big.Rational.init(gpa);
            defer rational.deinit();
            rational.setFloat(f128, val) catch |err| switch (err) {
                error.NonFiniteFloat => unreachable,
                error.OutOfMemory => return error.OutOfMemory,
            };

            // The float is reduced in rational.setFloat, so we assert that denominator is equal to
            // one
            const big_one = std.math.big.int.Const{ .limbs = &.{1}, .positive = true };
            assert(rational.q.toConst().eqlAbs(big_one));

            // Check that the result is in range of the result type
            const int_info = res_ty.intInfo(self.sema.pt.zcu);
            if (!rational.p.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                return self.fail(
                    .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                    "float value '{}' cannot be stored in integer type '{}'",
                    .{ val, res_ty.fmt(self.sema.pt) },
                );
            }

            return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{
                .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .big_int = rational.p.toConst() },
                },
            });
        },
        .char_literal => |val| {
            const rhs: u32 = val;
            // If our result is a fixed size integer, check that our value is not out of bounds
            if (Type.zigTypeTag(res_ty, self.sema.pt.zcu) == .int) {
                const lhs_info = res_ty.intInfo(self.sema.pt.zcu);
                // If lhs has less than 64 bits, we bounds check. We check at 64 instead of 32 in
                // case LHS is signed.
                if (std.math.cast(u6, lhs_info.bits)) |bits| {
                    const max_int: i64 = if (bits == 0) b: {
                        break :b 0;
                    } else b: {
                        break :b (@as(i64, 1) << (bits - @intFromBool(lhs_info.signedness == .signed))) - 1;
                    };
                    if (rhs > max_int) {
                        return self.fail(
                            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                            "type '{}' cannot represent integer value '{}'",
                            .{ res_ty.fmt(self.sema.pt), rhs },
                        );
                    }
                }
            }
            return self.sema.pt.zcu.intern_pool.get(gpa, self.sema.pt.tid, .{
                .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .i64 = rhs },
                },
            });
        },

        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };
}

fn lowerFloat(
    self: LowerZon,
    node: Zoir.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);
    switch (node.get(self.file.zoir.?)) {
        .int_literal => |int| switch (int) {
            .small => |val| return self.sema.pt.intern(.{ .float = .{
                .ty = res_ty.toIntern(),
                .storage = switch (res_ty.toIntern()) {
                    .f16_type => .{ .f16 = @floatFromInt(val) },
                    .f32_type => .{ .f32 = @floatFromInt(val) },
                    .f64_type => .{ .f64 = @floatFromInt(val) },
                    .f80_type => .{ .f80 = @floatFromInt(val) },
                    .f128_type, .comptime_float_type => .{ .f128 = @floatFromInt(val) },
                    else => unreachable,
                },
            } }),
            .big => {
                const main_tokens = self.file.tree.nodes.items(.main_token);
                const tags = self.file.tree.nodes.items(.tag);
                const data = self.file.tree.nodes.items(.data);
                const ast_node = node.getAstNode(self.file.zoir.?);
                const negative = tags[ast_node] == .negation;
                const num_lit_node = if (negative) data[ast_node].lhs else ast_node;
                const token = main_tokens[num_lit_node];
                const bytes = self.file.tree.tokenSlice(token);
                const val = std.fmt.parseFloat(f128, bytes) catch {
                    // Bytes already validated by big int parser
                    unreachable;
                };
                return self.sema.pt.intern(.{ .float = .{
                    .ty = res_ty.toIntern(),
                    .storage = switch (res_ty.toIntern()) {
                        .f16_type => .{ .f16 = @floatCast(val) },
                        .f32_type => .{ .f32 = @floatCast(val) },
                        .f64_type => .{ .f64 = @floatCast(val) },
                        .f80_type => .{ .f80 = @floatCast(val) },
                        .f128_type, .comptime_float_type => .{ .f128 = val },
                        else => unreachable,
                    },
                } });
            },
        },
        .float_literal => |val| return self.sema.pt.intern(.{ .float = .{
            .ty = res_ty.toIntern(),
            .storage = switch (res_ty.toIntern()) {
                .f16_type => .{ .f16 = @floatCast(val) },
                .f32_type => .{ .f32 = @floatCast(val) },
                .f64_type => .{ .f64 = @floatCast(val) },
                .f80_type => .{ .f80 = @floatCast(val) },
                .f128_type, .comptime_float_type => .{ .f128 = val },
                else => unreachable,
            },
        } }),
        .pos_inf => return self.sema.pt.intern(.{ .float = .{
            .ty = res_ty.toIntern(),
            .storage = switch (res_ty.toIntern()) {
                .f16_type => .{ .f16 = std.math.inf(f16) },
                .f32_type => .{ .f32 = std.math.inf(f32) },
                .f64_type => .{ .f64 = std.math.inf(f64) },
                .f80_type => .{ .f80 = std.math.inf(f80) },
                .f128_type, .comptime_float_type => .{ .f128 = std.math.inf(f128) },
                else => unreachable,
            },
        } }),
        .neg_inf => return self.sema.pt.intern(.{ .float = .{
            .ty = res_ty.toIntern(),
            .storage = switch (res_ty.toIntern()) {
                .f16_type => .{ .f16 = -std.math.inf(f16) },
                .f32_type => .{ .f32 = -std.math.inf(f32) },
                .f64_type => .{ .f64 = -std.math.inf(f64) },
                .f80_type => .{ .f80 = -std.math.inf(f80) },
                .f128_type, .comptime_float_type => .{ .f128 = -std.math.inf(f128) },
                else => unreachable,
            },
        } }),
        .nan => return self.sema.pt.intern(.{ .float = .{
            .ty = res_ty.toIntern(),
            .storage = switch (res_ty.toIntern()) {
                .f16_type => .{ .f16 = std.math.nan(f16) },
                .f32_type => .{ .f32 = std.math.nan(f32) },
                .f64_type => .{ .f64 = std.math.nan(f64) },
                .f80_type => .{ .f80 = std.math.nan(f80) },
                .f128_type, .comptime_float_type => .{ .f128 = std.math.nan(f128) },
                else => unreachable,
            },
        } }),
        .char_literal => |val| return self.sema.pt.intern(.{ .float = .{
            .ty = res_ty.toIntern(),
            .storage = switch (res_ty.toIntern()) {
                .f16_type => .{ .f16 = @floatFromInt(val) },
                .f32_type => .{ .f32 = @floatFromInt(val) },
                .f64_type => .{ .f64 = @floatFromInt(val) },
                .f80_type => .{ .f80 = @floatFromInt(val) },
                .f128_type, .comptime_float_type => .{ .f128 = @floatFromInt(val) },
                else => unreachable,
            },
        } }),
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    }
}

fn lowerOptional(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    return switch (node.get(self.file.zoir.?)) {
        .null => .null_value,
        else => try self.lowerExpr(node, res_ty.optionalChild(self.sema.pt.zcu)),
    };
}

fn lowerNull(self: LowerZon, node: Zoir.Node.Index) !InternPool.Index {
    switch (node.get(self.file.zoir.?)) {
        .null => return .null_value,
        else => return self.fail(.{ .node_abs = node.getAstNode(self.file.zoir.?) }, "expected null", .{}),
    }
}

fn lowerArray(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const gpa = self.sema.gpa;

    const array_info = res_ty.arrayInfo(self.sema.pt.zcu);
    const nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };

    if (nodes.len != array_info.len) {
        return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        );
    }

    const elems = try gpa.alloc(
        InternPool.Index,
        nodes.len + @intFromBool(array_info.sentinel != null),
    );
    defer gpa.free(elems);

    for (0..nodes.len) |i| {
        elems[i] = try self.lowerExpr(nodes.at(@intCast(i)), array_info.elem_type);
    }

    if (array_info.sentinel) |sentinel| {
        elems[elems.len - 1] = sentinel.toIntern();
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}

fn lowerEnum(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    switch (node.get(self.file.zoir.?)) {
        .enum_literal => |field_name| {
            const field_name_interned = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                field_name.get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            const field_index = res_ty.enumFieldIndex(field_name_interned, self.sema.pt.zcu) orelse {
                return self.fail(
                    .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                    "enum {} has no member named '{}'",
                    .{
                        res_ty.fmt(self.sema.pt),
                        std.zig.fmtId(field_name.get(self.file.zoir.?)),
                    },
                );
            };

            const value = try self.sema.pt.enumValueFieldIndex(res_ty, field_index);

            return value.toIntern();
        },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    }
}

fn lowerEnumLiteral(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;
    switch (node.get(self.file.zoir.?)) {
        .enum_literal => |field_name| {
            const field_name_interned = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                field_name.get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            return ip.get(gpa, self.sema.pt.tid, .{ .enum_literal = field_name_interned });
        },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    }
}

fn lowerStructOrTuple(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    return switch (ip.indexToKey(res_ty.toIntern())) {
        .tuple_type => self.lowerTuple(node, res_ty),
        .struct_type => self.lowerStruct(node, res_ty),
        else => unreachable,
    };
}

fn lowerTuple(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    const tuple_info = ip.indexToKey(res_ty.toIntern()).tuple_type;

    const elem_nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };

    const field_types = tuple_info.types.get(ip);
    if (elem_nodes.len < field_types.len) {
        return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "missing tuple field with index {}",
            .{elem_nodes.len},
        );
    } else if (elem_nodes.len > field_types.len) {
        return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "index {} outside tuple of length {}",
            .{
                field_types.len,
                elem_nodes.at(@intCast(field_types.len)),
            },
        );
    }

    const elems = try gpa.alloc(InternPool.Index, field_types.len);
    defer gpa.free(elems);

    for (0..elem_nodes.len) |i| {
        elems[i] = try self.lowerExpr(elem_nodes.at(@intCast(i)), Type.fromInterned(field_types[i]));
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}

fn lowerStruct(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    try res_ty.resolveFully(self.sema.pt);
    const struct_info = self.sema.pt.zcu.typeToStruct(res_ty).?;

    const fields: std.meta.fieldInfo(Zoir.Node, .struct_literal).type = switch (node.get(self.file.zoir.?)) {
        .struct_literal => |fields| fields,
        .empty_literal => .{ .names = &.{}, .vals = .{ .start = node, .len = 0 } },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };

    const field_values = try gpa.alloc(InternPool.Index, struct_info.field_names.len);
    defer gpa.free(field_values);

    const field_defaults = struct_info.field_inits.get(ip);
    for (0..field_values.len) |i| {
        field_values[i] = if (i < field_defaults.len) field_defaults[i] else .none;
    }

    for (0..fields.names.len) |i| {
        const field_name = try ip.getOrPutString(
            gpa,
            self.sema.pt.tid,
            fields.names[i].get(self.file.zoir.?),
            .no_embedded_nulls,
        );
        const field_node = fields.vals.at(@intCast(i));
        const field_node_ast = field_node.getAstNode(self.file.zoir.?);
        const field_name_token = self.file.tree.firstToken(field_node_ast) - 2;

        const name_index = struct_info.nameIndex(ip, field_name) orelse {
            return self.fail(
                .{ .node_abs = field_node.getAstNode(self.file.zoir.?) },
                "unexpected field '{}'",
                .{field_name.fmt(ip)},
            );
        };

        const field_type = Type.fromInterned(struct_info.field_types.get(ip)[name_index]);
        if (field_values[name_index] != .none) {
            return self.fail(
                .{ .token_abs = field_name_token },
                "duplicate field '{}'",
                .{field_name.fmt(ip)},
            );
        }

        field_values[name_index] = try self.lowerExpr(field_node, field_type);
    }

    const field_names = struct_info.field_names.get(ip);
    for (field_values, field_names) |*value, name| {
        if (value.* == .none) return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "missing field {}",
            .{name.fmt(ip)},
        );
    }

    return self.sema.pt.intern(.{ .aggregate = .{ .ty = res_ty.toIntern(), .storage = .{
        .elems = field_values,
    } } });
}

fn lowerPointer(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    const ptr_info = res_ty.ptrInfo(self.sema.pt.zcu);

    if (ptr_info.flags.size != .Slice) {
        return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "non slice pointers are not available in ZON",
            .{},
        );
    }

    // String literals
    const string_alignment = ptr_info.flags.alignment == .none or ptr_info.flags.alignment == .@"1";
    const string_sentinel = ptr_info.sentinel == .none or ptr_info.sentinel == .zero_u8;
    if (string_alignment and ptr_info.child == .u8_type and string_sentinel) {
        switch (node.get(self.file.zoir.?)) {
            .string_literal => |val| {
                const string = try ip.getOrPutString(gpa, self.sema.pt.tid, val, .maybe_embedded_nulls);
                const array_ty = try self.sema.pt.intern(.{ .array_type = .{
                    .len = val.len,
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
                    .len = (try self.sema.pt.intValue(Type.usize, val.len)).toIntern(),
                } });
            },
            else => {},
        }
    }

    // Slice literals
    const elem_nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };

    const elems = try gpa.alloc(InternPool.Index, elem_nodes.len + @intFromBool(ptr_info.sentinel != .none));
    defer gpa.free(elems);

    for (0..elem_nodes.len) |i| {
        elems[i] = try self.lowerExpr(elem_nodes.at(@intCast(i)), Type.fromInterned(ptr_info.child));
    }

    if (ptr_info.sentinel != .none) {
        elems[elems.len - 1] = ptr_info.sentinel;
    }

    const array_ty = try self.sema.pt.intern(.{ .array_type = .{
        .len = elems.len,
        .sentinel = ptr_info.sentinel,
        .child = ptr_info.child,
    } });

    const array = try self.sema.pt.intern(.{ .aggregate = .{
        .ty = array_ty,
        .storage = .{ .elems = elems },
    } });

    const many_item_ptr_type = try ip.get(gpa, self.sema.pt.tid, .{ .ptr_type = .{
        .child = ptr_info.child,
        .sentinel = ptr_info.sentinel,
        .flags = b: {
            var flags = ptr_info.flags;
            flags.size = .Many;
            break :b flags;
        },
        .packed_offset = ptr_info.packed_offset,
    } });

    const many_item_ptr = try ip.get(gpa, self.sema.pt.tid, .{
        .ptr = .{
            .ty = many_item_ptr_type,
            .base_addr = .{
                .uav = .{
                    .orig_ty = res_ty.toIntern(),
                    .val = array,
                },
            },
            .byte_offset = 0,
        },
    });

    const len = (try self.sema.pt.intValue(Type.usize, elems.len)).toIntern();

    return ip.get(gpa, self.sema.pt.tid, .{ .slice = .{
        .ty = res_ty.toIntern(),
        .ptr = many_item_ptr,
        .len = len,
    } });
}

fn lowerUnion(self: LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    try res_ty.resolveFully(self.sema.pt);
    const union_info = self.sema.pt.zcu.typeToUnion(res_ty).?;
    const enum_tag_info = union_info.loadTagType(ip);

    const field_name, const maybe_field_node = switch (node.get(self.file.zoir.?)) {
        .enum_literal => |name| b: {
            const field_name = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                name.get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            break :b .{ field_name, null };
        },
        .struct_literal => b: {
            const fields: std.meta.fieldInfo(Zoir.Node, .struct_literal).type = switch (node.get(self.file.zoir.?)) {
                .struct_literal => |fields| fields,
                else => return self.fail(
                    .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                    "expected type '{}'",
                    .{res_ty.fmt(self.sema.pt)},
                ),
            };
            if (fields.names.len != 1) {
                return self.fail(
                    .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                    "expected type '{}'",
                    .{res_ty.fmt(self.sema.pt)},
                );
            }
            const field_name = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                fields.names[0].get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            break :b .{ field_name, fields.vals.at(0) };
        },
        else => return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        ),
    };

    const name_index = enum_tag_info.nameIndex(ip, field_name) orelse {
        return self.fail(
            .{ .node_abs = node.getAstNode(self.file.zoir.?) },
            "expected type '{}'",
            .{res_ty.fmt(self.sema.pt)},
        );
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
        if (field_type.toIntern() == .void_type) {
            return self.fail(
                .{ .node_abs = field_node.getAstNode(self.file.zoir.?) },
                "expected type 'void'",
                .{},
            );
        }
        break :b try self.lowerExpr(field_node, field_type);
    } else b: {
        if (field_type.toIntern() != .void_type) {
            return self.fail(
                .{ .node_abs = node.getAstNode(self.file.zoir.?) },
                "expected type '{}'",
                .{res_ty.fmt(self.sema.pt)},
            );
        }
        break :b .void_value;
    };
    return ip.getUnion(self.sema.pt.zcu.gpa, self.sema.pt.tid, .{
        .ty = res_ty.toIntern(),
        .tag = tag,
        .val = val,
    });
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
