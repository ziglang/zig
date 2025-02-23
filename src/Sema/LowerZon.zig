const std = @import("std");
const Zcu = @import("../Zcu.zig");
const Sema = @import("../Sema.zig");
const Air = @import("../Air.zig");
const InternPool = @import("../InternPool.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
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
block: *Sema.Block,
base_node_inst: InternPool.TrackedInst.Index,

/// Lowers the given file as ZON.
pub fn run(
    sema: *Sema,
    file: *File,
    file_index: Zcu.File.Index,
    res_ty: Type,
    import_loc: LazySrcLoc,
    block: *Sema.Block,
) CompileError!InternPool.Index {
    const pt = sema.pt;

    const tracked_inst = try pt.zcu.intern_pool.trackZir(pt.zcu.gpa, pt.tid, .{
        .file = file_index,
        .inst = .main_struct_inst, // this is the only trackable instruction in a ZON file
    });

    var lower_zon: LowerZon = .{
        .sema = sema,
        .file = file,
        .file_index = file_index,
        .import_loc = import_loc,
        .block = block,
        .base_node_inst = tracked_inst,
    };

    try lower_zon.checkType(res_ty);

    return lower_zon.lowerExpr(.root, res_ty);
}

/// Validate that `ty` is a valid ZON type. If not, emit a compile error.
/// i.e. no nested optionals, no error sets, etc.
fn checkType(self: *LowerZon, ty: Type) !void {
    var visited: std.AutoHashMapUnmanaged(InternPool.Index, void) = .empty;
    try self.checkTypeInner(ty, null, &visited);
}

fn checkTypeInner(
    self: *LowerZon,
    ty: Type,
    parent_opt_ty: ?Type,
    /// Visited structs and unions (not tuples). These are tracked because they are the only way in
    /// which a type can be self-referential, so must be tracked to avoid loops. Tracking more types
    /// consumes memory unnecessarily, and would be complicated by optionals.
    /// Allocated into `self.sema.arena`.
    visited: *std.AutoHashMapUnmanaged(InternPool.Index, void),
) !void {
    const sema = self.sema;
    const pt = sema.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    switch (ty.zigTypeTag(zcu)) {
        .bool,
        .int,
        .float,
        .null,
        .@"enum",
        .comptime_float,
        .comptime_int,
        .enum_literal,
        => {},

        .noreturn,
        .void,
        .type,
        .undefined,
        .error_union,
        .error_set,
        .@"fn",
        .frame,
        .@"anyframe",
        .@"opaque",
        => return self.failUnsupportedResultType(ty, null),

        .pointer => {
            const ptr_info = ty.ptrInfo(zcu);
            if (!ptr_info.flags.is_const) {
                return self.failUnsupportedResultType(
                    ty,
                    "ZON does not allow mutable pointers",
                );
            }
            switch (ptr_info.flags.size) {
                .one => try self.checkTypeInner(
                    .fromInterned(ptr_info.child),
                    parent_opt_ty, // preserved
                    visited,
                ),
                .slice => try self.checkTypeInner(
                    .fromInterned(ptr_info.child),
                    null,
                    visited,
                ),
                .many => return self.failUnsupportedResultType(ty, "ZON does not allow many-pointers"),
                .c => return self.failUnsupportedResultType(ty, "ZON does not allow C pointers"),
            }
        },
        .optional => if (parent_opt_ty) |p| {
            return self.failUnsupportedResultType(p, "ZON does not allow nested optionals");
        } else try self.checkTypeInner(
            ty.optionalChild(zcu),
            ty,
            visited,
        ),
        .array, .vector => {
            try self.checkTypeInner(ty.childType(zcu), null, visited);
        },
        .@"struct" => if (ty.isTuple(zcu)) {
            const tuple_info = ip.indexToKey(ty.toIntern()).tuple_type;
            const field_types = tuple_info.types.get(ip);
            for (field_types) |field_type| {
                try self.checkTypeInner(.fromInterned(field_type), null, visited);
            }
        } else {
            const gop = try visited.getOrPut(sema.arena, ty.toIntern());
            if (gop.found_existing) return;
            try ty.resolveFields(pt);
            const struct_info = zcu.typeToStruct(ty).?;
            for (struct_info.field_types.get(ip)) |field_type| {
                try self.checkTypeInner(.fromInterned(field_type), null, visited);
            }
        },
        .@"union" => {
            const gop = try visited.getOrPut(sema.arena, ty.toIntern());
            if (gop.found_existing) return;
            try ty.resolveFields(pt);
            const union_info = zcu.typeToUnion(ty).?;
            for (union_info.field_types.get(ip)) |field_type| {
                if (field_type != .void_type) {
                    try self.checkTypeInner(.fromInterned(field_type), null, visited);
                }
            }
        },
    }
}

fn nodeSrc(self: *LowerZon, node: Zoir.Node.Index) LazySrcLoc {
    return .{
        .base_node_inst = self.base_node_inst,
        .offset = .{ .node_abs = node.getAstNode(self.file.zoir.?) },
    };
}

fn failUnsupportedResultType(
    self: *LowerZon,
    ty: Type,
    opt_note: ?[]const u8,
) error{ AnalysisFail, OutOfMemory } {
    @branchHint(.cold);
    const sema = self.sema;
    const gpa = sema.gpa;
    const pt = sema.pt;
    return sema.failWithOwnedErrorMsg(self.block, msg: {
        const msg = try sema.errMsg(self.import_loc, "type '{}' is not available in ZON", .{ty.fmt(pt)});
        errdefer msg.destroy(gpa);
        if (opt_note) |n| try sema.errNote(self.import_loc, msg, "{s}", .{n});
        break :msg msg;
    });
}

fn fail(
    self: *LowerZon,
    node: Zoir.Node.Index,
    comptime format: []const u8,
    args: anytype,
) error{ AnalysisFail, OutOfMemory } {
    @branchHint(.cold);
    const err_msg = try Zcu.ErrorMsg.create(self.sema.pt.zcu.gpa, self.nodeSrc(node), format, args);
    try self.sema.pt.zcu.errNote(self.import_loc, err_msg, "imported here", .{});
    return self.sema.failWithOwnedErrorMsg(self.block, err_msg);
}

fn lowerExpr(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) CompileError!InternPool.Index {
    const pt = self.sema.pt;
    return self.lowerExprInner(node, res_ty) catch |err| switch (err) {
        error.WrongType => return self.fail(
            node,
            "expected type '{}'",
            .{res_ty.fmt(pt)},
        ),
        else => |e| return e,
    };
}

fn lowerExprInner(
    self: *LowerZon,
    node: Zoir.Node.Index,
    res_ty: Type,
) (CompileError || error{WrongType})!InternPool.Index {
    const pt = self.sema.pt;
    switch (res_ty.zigTypeTag(pt.zcu)) {
        .optional => return pt.intern(.{
            .opt = .{
                .ty = res_ty.toIntern(),
                .val = if (node.get(self.file.zoir.?) == .null) b: {
                    break :b .none;
                } else b: {
                    const child_type = res_ty.optionalChild(pt.zcu);
                    break :b try self.lowerExprInner(node, child_type);
                },
            },
        }),
        .pointer => {
            const ptr_info = res_ty.ptrInfo(pt.zcu);
            switch (ptr_info.flags.size) {
                .one => return pt.intern(.{ .ptr = .{
                    .ty = res_ty.toIntern(),
                    .base_addr = .{
                        .uav = .{
                            .orig_ty = res_ty.toIntern(),
                            .val = try self.lowerExprInner(node, .fromInterned(ptr_info.child)),
                        },
                    },
                    .byte_offset = 0,
                } }),
                .slice => return self.lowerSlice(node, res_ty),
                else => {
                    // Unsupported pointer type, checked in `lower`
                    unreachable;
                },
            }
        },
        .bool => return self.lowerBool(node),
        .int, .comptime_int => return self.lowerInt(node, res_ty),
        .float, .comptime_float => return self.lowerFloat(node, res_ty),
        .null => return self.lowerNull(node),
        .@"enum" => return self.lowerEnum(node, res_ty),
        .enum_literal => return self.lowerEnumLiteral(node),
        .array => return self.lowerArray(node, res_ty),
        .@"struct" => return self.lowerStructOrTuple(node, res_ty),
        .@"union" => return self.lowerUnion(node, res_ty),
        .vector => return self.lowerVector(node, res_ty),

        .type,
        .noreturn,
        .undefined,
        .error_union,
        .error_set,
        .@"fn",
        .@"opaque",
        .frame,
        .@"anyframe",
        .void,
        => return self.fail(node, "type '{}' not available in ZON", .{res_ty.fmt(pt)}),
    }
}

fn lowerBool(self: *LowerZon, node: Zoir.Node.Index) !InternPool.Index {
    return switch (node.get(self.file.zoir.?)) {
        .true => .bool_true,
        .false => .bool_false,
        else => return error.WrongType,
    };
}

fn lowerInt(
    self: *LowerZon,
    node: Zoir.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);
    return switch (node.get(self.file.zoir.?)) {
        .int_literal => |int| switch (int) {
            .small => |val| {
                const rhs: i32 = val;

                // If our result is a fixed size integer, check that our value is not out of bounds
                if (res_ty.zigTypeTag(self.sema.pt.zcu) == .int) {
                    const lhs_info = res_ty.intInfo(self.sema.pt.zcu);

                    // If lhs is unsigned and rhs is less than 0, we're out of bounds
                    if (lhs_info.signedness == .unsigned and rhs < 0) return self.fail(
                        node,
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
                                node,
                                "type '{}' cannot represent integer value '{}'",
                                .{ res_ty.fmt(self.sema.pt), rhs },
                            );
                        }
                    }
                }

                return self.sema.pt.intern(.{ .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .i64 = rhs },
                } });
            },
            .big => |val| {
                if (res_ty.zigTypeTag(self.sema.pt.zcu) == .int) {
                    const int_info = res_ty.intInfo(self.sema.pt.zcu);
                    if (!val.fitsInTwosComp(int_info.signedness, int_info.bits)) {
                        return self.fail(
                            node,
                            "type '{}' cannot represent integer value '{}'",
                            .{ res_ty.fmt(self.sema.pt), val },
                        );
                    }
                }

                return self.sema.pt.intern(.{ .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .big_int = val },
                } });
            },
        },
        .float_literal => |val| {
            // Check for fractional components
            if (@rem(val, 1) != 0) {
                return self.fail(
                    node,
                    "fractional component prevents float value '{}' from coercion to type '{}'",
                    .{ val, res_ty.fmt(self.sema.pt) },
                );
            }

            // Create a rational representation of the float
            var rational = try std.math.big.Rational.init(self.sema.arena);
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
                    node,
                    "type '{}' cannot represent integer value '{}'",
                    .{ val, res_ty.fmt(self.sema.pt) },
                );
            }

            return self.sema.pt.intern(.{
                .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .big_int = rational.p.toConst() },
                },
            });
        },
        .char_literal => |val| {
            // If our result is a fixed size integer, check that our value is not out of bounds
            if (res_ty.zigTypeTag(self.sema.pt.zcu) == .int) {
                const dest_info = res_ty.intInfo(self.sema.pt.zcu);
                const unsigned_bits = dest_info.bits - @intFromBool(dest_info.signedness == .signed);
                if (unsigned_bits < 21) {
                    const out_of_range: u21 = @as(u21, 1) << @intCast(unsigned_bits);
                    if (val >= out_of_range) {
                        return self.fail(
                            node,
                            "type '{}' cannot represent integer value '{}'",
                            .{ res_ty.fmt(self.sema.pt), val },
                        );
                    }
                }
            }
            return self.sema.pt.intern(.{
                .int = .{
                    .ty = res_ty.toIntern(),
                    .storage = .{ .i64 = val },
                },
            });
        },

        else => return error.WrongType,
    };
}

fn lowerFloat(
    self: *LowerZon,
    node: Zoir.Node.Index,
    res_ty: Type,
) !InternPool.Index {
    @setFloatMode(.strict);
    const value = switch (node.get(self.file.zoir.?)) {
        .int_literal => |int| switch (int) {
            .small => |val| try self.sema.pt.floatValue(res_ty, @as(f128, @floatFromInt(val))),
            .big => |val| try self.sema.pt.floatValue(res_ty, val.toFloat(f128)),
        },
        .float_literal => |val| try self.sema.pt.floatValue(res_ty, val),
        .char_literal => |val| try self.sema.pt.floatValue(res_ty, @as(f128, @floatFromInt(val))),
        .pos_inf => b: {
            if (res_ty.toIntern() == .comptime_float_type) return self.fail(
                node,
                "expected type '{}'",
                .{res_ty.fmt(self.sema.pt)},
            );
            break :b try self.sema.pt.floatValue(res_ty, std.math.inf(f128));
        },
        .neg_inf => b: {
            if (res_ty.toIntern() == .comptime_float_type) return self.fail(
                node,
                "expected type '{}'",
                .{res_ty.fmt(self.sema.pt)},
            );
            break :b try self.sema.pt.floatValue(res_ty, -std.math.inf(f128));
        },
        .nan => b: {
            if (res_ty.toIntern() == .comptime_float_type) return self.fail(
                node,
                "expected type '{}'",
                .{res_ty.fmt(self.sema.pt)},
            );
            break :b try self.sema.pt.floatValue(res_ty, std.math.nan(f128));
        },
        else => return error.WrongType,
    };
    return value.toIntern();
}

fn lowerNull(self: *LowerZon, node: Zoir.Node.Index) !InternPool.Index {
    switch (node.get(self.file.zoir.?)) {
        .null => return .null_value,
        else => return error.WrongType,
    }
}

fn lowerArray(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const array_info = res_ty.arrayInfo(self.sema.pt.zcu);
    const nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return error.WrongType,
    };

    if (nodes.len != array_info.len) {
        return error.WrongType;
    }

    const elems = try self.sema.arena.alloc(
        InternPool.Index,
        nodes.len + @intFromBool(array_info.sentinel != null),
    );

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

fn lowerEnum(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
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
                    node,
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
        else => return error.WrongType,
    }
}

fn lowerEnumLiteral(self: *LowerZon, node: Zoir.Node.Index) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    switch (node.get(self.file.zoir.?)) {
        .enum_literal => |field_name| {
            const field_name_interned = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                field_name.get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            return self.sema.pt.intern(.{ .enum_literal = field_name_interned });
        },
        else => return error.WrongType,
    }
}

fn lowerStructOrTuple(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    return switch (ip.indexToKey(res_ty.toIntern())) {
        .tuple_type => self.lowerTuple(node, res_ty),
        .struct_type => self.lowerStruct(node, res_ty),
        else => unreachable,
    };
}

fn lowerTuple(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;

    const tuple_info = ip.indexToKey(res_ty.toIntern()).tuple_type;

    const elem_nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return error.WrongType,
    };

    const field_types = tuple_info.types.get(ip);
    const elems = try self.sema.arena.alloc(InternPool.Index, field_types.len);

    const field_comptime_vals = tuple_info.values.get(ip);
    if (field_comptime_vals.len > 0) {
        @memcpy(elems, field_comptime_vals);
    } else {
        @memset(elems, .none);
    }

    for (0..elem_nodes.len) |i| {
        if (i >= elems.len) {
            const elem_node = elem_nodes.at(@intCast(i));
            return self.fail(
                elem_node,
                "index {} outside tuple of length {}",
                .{
                    elems.len,
                    elem_nodes.at(@intCast(i)).getAstNode(self.file.zoir.?),
                },
            );
        }

        const val = try self.lowerExpr(elem_nodes.at(@intCast(i)), .fromInterned(field_types[i]));

        if (elems[i] != .none and val != elems[i]) {
            const elem_node = elem_nodes.at(@intCast(i));
            return self.fail(
                elem_node,
                "value stored in comptime field does not match the default value of the field",
                .{},
            );
        }

        elems[i] = val;
    }

    for (elems, 0..) |val, i| {
        if (val == .none) {
            return self.fail(node, "missing tuple field with index {}", .{i});
        }
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}

fn lowerStruct(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    try res_ty.resolveFields(self.sema.pt);
    try res_ty.resolveStructFieldInits(self.sema.pt);
    const struct_info = self.sema.pt.zcu.typeToStruct(res_ty).?;

    const fields: @FieldType(Zoir.Node, "struct_literal") = switch (node.get(self.file.zoir.?)) {
        .struct_literal => |fields| fields,
        .empty_literal => .{ .names = &.{}, .vals = .{ .start = node, .len = 0 } },
        else => return error.WrongType,
    };

    const field_values = try self.sema.arena.alloc(InternPool.Index, struct_info.field_names.len);

    const field_defaults = struct_info.field_inits.get(ip);
    if (field_defaults.len > 0) {
        @memcpy(field_values, field_defaults);
    } else {
        @memset(field_values, .none);
    }

    for (0..fields.names.len) |i| {
        const field_name = try ip.getOrPutString(
            gpa,
            self.sema.pt.tid,
            fields.names[i].get(self.file.zoir.?),
            .no_embedded_nulls,
        );
        const field_node = fields.vals.at(@intCast(i));

        const name_index = struct_info.nameIndex(ip, field_name) orelse {
            return self.fail(field_node, "unexpected field '{}'", .{field_name.fmt(ip)});
        };

        const field_type: Type = .fromInterned(struct_info.field_types.get(ip)[name_index]);
        field_values[name_index] = try self.lowerExpr(field_node, field_type);

        if (struct_info.comptime_bits.getBit(ip, name_index)) {
            const val = ip.indexToKey(field_values[name_index]);
            const default = ip.indexToKey(field_defaults[name_index]);
            if (!val.eql(default, ip)) {
                return self.fail(
                    field_node,
                    "value stored in comptime field does not match the default value of the field",
                    .{},
                );
            }
        }
    }

    const field_names = struct_info.field_names.get(ip);
    for (field_values, field_names) |*value, name| {
        if (value.* == .none) return self.fail(node, "missing field '{}'", .{name.fmt(ip)});
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{
            .elems = field_values,
        },
    } });
}

fn lowerSlice(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    const gpa = self.sema.gpa;

    const ptr_info = res_ty.ptrInfo(self.sema.pt.zcu);

    assert(ptr_info.flags.size == .slice);

    // String literals
    const string_alignment = ptr_info.flags.alignment == .none or ptr_info.flags.alignment == .@"1";
    const string_sentinel = ptr_info.sentinel == .none or ptr_info.sentinel == .zero_u8;
    if (string_alignment and ptr_info.child == .u8_type and string_sentinel) {
        switch (node.get(self.file.zoir.?)) {
            .string_literal => |val| {
                const ip_str = try ip.getOrPutString(gpa, self.sema.pt.tid, val, .maybe_embedded_nulls);
                const str_ref = try self.sema.addStrLit(ip_str, val.len);
                return (try self.sema.coerce(
                    self.block,
                    res_ty,
                    str_ref,
                    self.nodeSrc(node),
                )).toInterned().?;
            },
            else => {},
        }
    }

    // Slice literals
    const elem_nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return error.WrongType,
    };

    const elems = try self.sema.arena.alloc(InternPool.Index, elem_nodes.len + @intFromBool(ptr_info.sentinel != .none));

    for (elems, 0..) |*elem, i| {
        elem.* = try self.lowerExpr(elem_nodes.at(@intCast(i)), .fromInterned(ptr_info.child));
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

    const many_item_ptr_type = try self.sema.pt.intern(.{ .ptr_type = .{
        .child = ptr_info.child,
        .sentinel = ptr_info.sentinel,
        .flags = b: {
            var flags = ptr_info.flags;
            flags.size = .many;
            break :b flags;
        },
        .packed_offset = ptr_info.packed_offset,
    } });

    const many_item_ptr = try self.sema.pt.intern(.{
        .ptr = .{
            .ty = many_item_ptr_type,
            .base_addr = .{
                .uav = .{
                    .orig_ty = (try self.sema.pt.singleConstPtrType(.fromInterned(array_ty))).toIntern(),
                    .val = array,
                },
            },
            .byte_offset = 0,
        },
    });

    const len = (try self.sema.pt.intValue(.usize, elems.len)).toIntern();

    return self.sema.pt.intern(.{ .slice = .{
        .ty = res_ty.toIntern(),
        .ptr = many_item_ptr,
        .len = len,
    } });
}

fn lowerUnion(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;
    try res_ty.resolveFields(self.sema.pt);
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
            const fields: @FieldType(Zoir.Node, "struct_literal") = switch (node.get(self.file.zoir.?)) {
                .struct_literal => |fields| fields,
                else => return self.fail(node, "expected type '{}'", .{res_ty.fmt(self.sema.pt)}),
            };
            if (fields.names.len != 1) {
                return error.WrongType;
            }
            const field_name = try ip.getOrPutString(
                self.sema.gpa,
                self.sema.pt.tid,
                fields.names[0].get(self.file.zoir.?),
                .no_embedded_nulls,
            );
            break :b .{ field_name, fields.vals.at(0) };
        },
        else => return error.WrongType,
    };

    const name_index = enum_tag_info.nameIndex(ip, field_name) orelse {
        return error.WrongType;
    };
    const tag = try self.sema.pt.enumValueFieldIndex(.fromInterned(union_info.enum_tag_ty), name_index);
    const field_type: Type = .fromInterned(union_info.field_types.get(ip)[name_index]);
    const val = if (maybe_field_node) |field_node| b: {
        if (field_type.toIntern() == .void_type) {
            return self.fail(field_node, "expected type 'void'", .{});
        }
        break :b try self.lowerExpr(field_node, field_type);
    } else b: {
        if (field_type.toIntern() != .void_type) {
            return error.WrongType;
        }
        break :b .void_value;
    };
    return ip.getUnion(self.sema.pt.zcu.gpa, self.sema.pt.tid, .{
        .ty = res_ty.toIntern(),
        .tag = tag.toIntern(),
        .val = val,
    });
}

fn lowerVector(self: *LowerZon, node: Zoir.Node.Index, res_ty: Type) !InternPool.Index {
    const ip = &self.sema.pt.zcu.intern_pool;

    const vector_info = ip.indexToKey(res_ty.toIntern()).vector_type;

    const elem_nodes: Zoir.Node.Index.Range = switch (node.get(self.file.zoir.?)) {
        .array_literal => |nodes| nodes,
        .empty_literal => .{ .start = node, .len = 0 },
        else => return error.WrongType,
    };

    const elems = try self.sema.arena.alloc(InternPool.Index, vector_info.len);

    if (elem_nodes.len != vector_info.len) {
        return self.fail(
            node,
            "expected {} vector elements; found {}",
            .{ vector_info.len, elem_nodes.len },
        );
    }

    for (elems, 0..) |*elem, i| {
        elem.* = try self.lowerExpr(elem_nodes.at(@intCast(i)), .fromInterned(vector_info.child));
    }

    return self.sema.pt.intern(.{ .aggregate = .{
        .ty = res_ty.toIntern(),
        .storage = .{ .elems = elems },
    } });
}
