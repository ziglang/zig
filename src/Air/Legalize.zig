pt: Zcu.PerThread,
air_instructions: std.MultiArrayList(Air.Inst),
air_extra: std.ArrayListUnmanaged(u32),
features: *const Features,

pub const Feature = enum {
    scalarize_not,
    scalarize_clz,
    scalarize_ctz,
    scalarize_popcount,
    scalarize_byte_swap,
    scalarize_bit_reverse,
    scalarize_sqrt,
    scalarize_sin,
    scalarize_cos,
    scalarize_tan,
    scalarize_exp,
    scalarize_exp2,
    scalarize_log,
    scalarize_log2,
    scalarize_log10,
    scalarize_abs,
    scalarize_floor,
    scalarize_ceil,
    scalarize_round,
    scalarize_trunc_float,
    scalarize_neg,
    scalarize_neg_optimized,

    /// Legalize (shift lhs, (splat rhs)) -> (shift lhs, rhs)
    remove_shift_vector_rhs_splat,
    /// Legalize reduce of a one element vector to a bitcast
    reduce_one_elem_to_bitcast,
};

pub const Features = std.enums.EnumSet(Feature);

pub const Error = std.mem.Allocator.Error;

pub fn legalize(air: *Air, backend: std.builtin.CompilerBackend, pt: Zcu.PerThread) Error!void {
    var l: Legalize = .{
        .pt = pt,
        .air_instructions = air.instructions.toMultiArrayList(),
        .air_extra = air.extra,
        .features = &features: switch (backend) {
            .other, .stage1 => unreachable,
            inline .stage2_llvm,
            .stage2_c,
            .stage2_wasm,
            .stage2_arm,
            .stage2_x86_64,
            .stage2_aarch64,
            .stage2_x86,
            .stage2_riscv64,
            .stage2_sparc64,
            .stage2_spirv64,
            .stage2_powerpc,
            => |ct_backend| {
                const Backend = codegen.importBackend(ct_backend) orelse break :features .initEmpty();
                break :features if (@hasDecl(Backend, "legalize_features")) Backend.legalize_features else .initEmpty();
            },
            _ => unreachable,
        },
    };
    if (l.features.bits.eql(.initEmpty())) return;
    defer air.* = l.getTmpAir();
    const main_extra = l.extraData(Air.Block, l.air_extra.items[@intFromEnum(Air.ExtraIndex.main_block)]);
    try l.legalizeBody(main_extra.end, main_extra.data.body_len);
}

fn getTmpAir(l: *const Legalize) Air {
    return .{
        .instructions = l.air_instructions.slice(),
        .extra = l.air_extra,
    };
}

fn typeOf(l: *const Legalize, ref: Air.Inst.Ref) Type {
    return l.getTmpAir().typeOf(ref, &l.pt.zcu.intern_pool);
}

fn typeOfIndex(l: *const Legalize, inst: Air.Inst.Index) Type {
    return l.getTmpAir().typeOfIndex(inst, &l.pt.zcu.intern_pool);
}

fn extraData(l: *const Legalize, comptime T: type, index: usize) @TypeOf(Air.extraData(undefined, T, undefined)) {
    return l.getTmpAir().extraData(T, index);
}

fn legalizeBody(l: *Legalize, body_start: usize, body_len: usize) Error!void {
    const zcu = l.pt.zcu;
    const ip = &zcu.intern_pool;
    for (body_start..body_start + body_len) |inst_extra_index| {
        const inst: Air.Inst.Index = @enumFromInt(l.air_extra.items[inst_extra_index]);
        inst: switch (l.air_instructions.items(.tag)[@intFromEnum(inst)]) {
            else => {},

            inline .not,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .abs,
            => |air_tag| if (l.features.contains(@field(Feature, "scalarize_" ++ @tagName(air_tag)))) done: {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (!ty_op.ty.toType().isVector(zcu)) break :done;
                continue :inst try l.scalarizeUnary(inst, .ty_op, ty_op.operand);
            },
            inline .sqrt,
            .sin,
            .cos,
            .tan,
            .exp,
            .exp2,
            .log,
            .log2,
            .log10,
            .floor,
            .ceil,
            .round,
            .trunc_float,
            .neg,
            .neg_optimized,
            => |air_tag| if (l.features.contains(@field(Feature, "scalarize_" ++ @tagName(air_tag)))) done: {
                const un_op = l.air_instructions.items(.data)[@intFromEnum(inst)].un_op;
                if (!l.typeOf(un_op).isVector(zcu)) break :done;
                continue :inst try l.scalarizeUnary(inst, .un_op, un_op);
            },

            .shl,
            .shl_exact,
            .shl_sat,
            .shr,
            .shr_exact,
            => |air_tag| if (l.features.contains(.remove_shift_vector_rhs_splat)) done: {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const ty = l.typeOf(bin_op.rhs);
                if (!ty.isVector(zcu)) break :done;
                if (bin_op.rhs.toInterned()) |rhs_ip_index| switch (ip.indexToKey(rhs_ip_index)) {
                    else => {},
                    .aggregate => |aggregate| switch (aggregate.storage) {
                        else => {},
                        .repeated_elem => |splat| continue :inst l.replaceInst(inst, air_tag, .{ .bin_op = .{
                            .lhs = bin_op.lhs,
                            .rhs = Air.internedToRef(splat),
                        } }),
                    },
                } else {
                    const rhs_inst = bin_op.rhs.toIndex().?;
                    switch (l.air_instructions.items(.tag)[@intFromEnum(rhs_inst)]) {
                        else => {},
                        .splat => continue :inst l.replaceInst(inst, air_tag, .{ .bin_op = .{
                            .lhs = bin_op.lhs,
                            .rhs = l.air_instructions.items(.data)[@intFromEnum(rhs_inst)].ty_op.operand,
                        } }),
                    }
                }
            },

            .reduce,
            .reduce_optimized,
            => if (l.features.contains(.reduce_one_elem_to_bitcast)) done: {
                const reduce = l.air_instructions.items(.data)[@intFromEnum(inst)].reduce;
                const vector_ty = l.typeOf(reduce.operand);
                switch (vector_ty.vectorLen(zcu)) {
                    0 => unreachable,
                    1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                        .ty = Air.internedToRef(vector_ty.scalarType(zcu).toIntern()),
                        .operand = reduce.operand,
                    } }),
                    else => break :done,
                }
            },

            .@"try", .try_cold => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.Try, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .try_ptr, .try_ptr_cold => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.TryPtr, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .block, .loop => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.Block, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .dbg_inline_block => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.DbgInlineBlock, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .cond_br => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.CondBr, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.then_body_len);
                try l.legalizeBody(extra.end + extra.data.then_body_len, extra.data.else_body_len);
            },
            .switch_br, .loop_switch_br => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.SwitchBr, pl_op.payload);
                const hint_bag_count = std.math.divCeil(usize, extra.data.cases_len + 1, 10) catch unreachable;
                var extra_index = extra.end + hint_bag_count;
                for (0..extra.data.cases_len) |_| {
                    const case_extra = l.extraData(Air.SwitchBr.Case, extra_index);
                    const case_body_start = case_extra.end + case_extra.data.items_len + case_extra.data.ranges_len * 2;
                    try l.legalizeBody(case_body_start, case_extra.data.body_len);
                    extra_index = case_body_start + case_extra.data.body_len;
                }
                try l.legalizeBody(extra_index, extra.data.else_body_len);
            },
        }
    }
}

const UnaryDataTag = enum { un_op, ty_op };
inline fn scalarizeUnary(l: *Legalize, inst: Air.Inst.Index, data_tag: UnaryDataTag, un_op: Air.Inst.Ref) Error!Air.Inst.Tag {
    return l.replaceInst(inst, .block, try l.scalarizeUnaryBlockPayload(inst, data_tag, un_op));
}
fn scalarizeUnaryBlockPayload(
    l: *Legalize,
    inst: Air.Inst.Index,
    data_tag: UnaryDataTag,
    un_op: Air.Inst.Ref,
) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const res_ty = l.typeOfIndex(inst);
    try l.air_instructions.ensureUnusedCapacity(gpa, 15);
    const res_alloc_inst = l.addInstAssumeCapacity(.{
        .tag = .alloc,
        .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
    });
    const index_alloc_inst = l.addInstAssumeCapacity(.{
        .tag = .alloc,
        .data = .{ .ty = try pt.singleMutPtrType(.usize) },
    });
    const index_init_inst = l.addInstAssumeCapacity(.{
        .tag = .store,
        .data = .{ .bin_op = .{
            .lhs = index_alloc_inst.toRef(),
            .rhs = try pt.intRef(.usize, 0),
        } },
    });
    const cur_index_inst = l.addInstAssumeCapacity(.{
        .tag = .load,
        .data = .{ .ty_op = .{
            .ty = .usize_type,
            .operand = index_alloc_inst.toRef(),
        } },
    });
    const get_elem_inst = l.addInstAssumeCapacity(.{
        .tag = .array_elem_val,
        .data = .{ .bin_op = .{
            .lhs = un_op,
            .rhs = cur_index_inst.toRef(),
        } },
    });
    const op_elem_inst = l.addInstAssumeCapacity(.{
        .tag = l.air_instructions.items(.tag)[@intFromEnum(inst)],
        .data = switch (data_tag) {
            .un_op => .{ .un_op = get_elem_inst.toRef() },
            .ty_op => .{ .ty_op = .{
                .ty = Air.internedToRef(res_ty.scalarType(zcu).toIntern()),
                .operand = get_elem_inst.toRef(),
            } },
        },
    });
    const set_elem_inst = l.addInstAssumeCapacity(.{
        .tag = .vector_store_elem,
        .data = .{ .vector_store_elem = .{
            .vector_ptr = res_alloc_inst.toRef(),
            .payload = try l.addExtra(Air.Bin, .{
                .lhs = cur_index_inst.toRef(),
                .rhs = op_elem_inst.toRef(),
            }),
        } },
    });
    const not_done_inst = l.addInstAssumeCapacity(.{
        .tag = .cmp_lt,
        .data = .{ .bin_op = .{
            .lhs = cur_index_inst.toRef(),
            .rhs = try pt.intRef(.usize, res_ty.vectorLen(zcu)),
        } },
    });
    const next_index_inst = l.addInstAssumeCapacity(.{
        .tag = .add,
        .data = .{ .bin_op = .{
            .lhs = cur_index_inst.toRef(),
            .rhs = try pt.intRef(.usize, 1),
        } },
    });
    const set_index_inst = l.addInstAssumeCapacity(.{
        .tag = .store,
        .data = .{ .bin_op = .{
            .lhs = index_alloc_inst.toRef(),
            .rhs = next_index_inst.toRef(),
        } },
    });
    const loop_inst: Air.Inst.Index = @enumFromInt(l.air_instructions.len + 4);
    const repeat_inst = l.addInstAssumeCapacity(.{
        .tag = .repeat,
        .data = .{ .repeat = .{ .loop_inst = loop_inst } },
    });
    const final_res_inst = l.addInstAssumeCapacity(.{
        .tag = .load,
        .data = .{ .ty_op = .{
            .ty = Air.internedToRef(res_ty.toIntern()),
            .operand = res_alloc_inst.toRef(),
        } },
    });
    const br_res_inst = l.addInstAssumeCapacity(.{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = inst,
            .operand = final_res_inst.toRef(),
        } },
    });
    const done_br_inst = l.addInstAssumeCapacity(.{
        .tag = .cond_br,
        .data = .{ .pl_op = .{
            .operand = not_done_inst.toRef(),
            .payload = try l.addCondBrBodies(&.{
                next_index_inst,
                set_index_inst,
                repeat_inst,
            }, &.{
                final_res_inst,
                br_res_inst,
            }),
        } },
    });
    assert(loop_inst == l.addInstAssumeCapacity(.{
        .tag = .loop,
        .data = .{ .ty_pl = .{
            .ty = .noreturn_type,
            .payload = try l.addBlockBody(&.{
                cur_index_inst,
                get_elem_inst,
                op_elem_inst,
                set_elem_inst,
                not_done_inst,
                done_br_inst,
            }),
        } },
    }));
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(&.{
            res_alloc_inst,
            index_alloc_inst,
            index_init_inst,
            loop_inst,
        }),
    } };
}

fn addInstAssumeCapacity(l: *Legalize, inst: Air.Inst) Air.Inst.Index {
    defer l.air_instructions.appendAssumeCapacity(inst);
    return @enumFromInt(l.air_instructions.len);
}

fn addExtra(l: *Legalize, comptime Extra: type, extra: Extra) Error!u32 {
    const extra_fields = @typeInfo(Extra).@"struct".fields;
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, extra_fields.len);
    defer inline for (extra_fields) |field| l.air_extra.appendAssumeCapacity(switch (field.type) {
        u32 => @field(extra, field.name),
        Air.Inst.Ref => @intFromEnum(@field(extra, field.name)),
        else => @compileError(@typeName(field.type)),
    });
    return @intCast(l.air_extra.items.len);
}

fn addBlockBody(l: *Legalize, body: []const Air.Inst.Index) Error!u32 {
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, 1 + body.len);
    defer {
        l.air_extra.appendAssumeCapacity(@intCast(body.len));
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(body));
    }
    return @intCast(l.air_extra.items.len);
}

fn addCondBrBodies(l: *Legalize, then_body: []const Air.Inst.Index, else_body: []const Air.Inst.Index) Error!u32 {
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, 3 + then_body.len + else_body.len);
    defer {
        l.air_extra.appendSliceAssumeCapacity(&.{
            @intCast(then_body.len),
            @intCast(else_body.len),
            @bitCast(Air.CondBr.BranchHints{
                .true = .none,
                .false = .none,
                .then_cov = .none,
                .else_cov = .none,
            }),
        });
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(then_body));
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(else_body));
    }
    return @intCast(l.air_extra.items.len);
}

// inline to propagate comptime `tag`s
inline fn replaceInst(l: *Legalize, inst: Air.Inst.Index, tag: Air.Inst.Tag, data: Air.Inst.Data) Air.Inst.Tag {
    const orig_ty = if (std.debug.runtime_safety) l.typeOfIndex(inst) else {};
    l.air_instructions.set(@intFromEnum(inst), .{ .tag = tag, .data = data });
    if (std.debug.runtime_safety) assert(l.typeOfIndex(inst).toIntern() == orig_ty.toIntern());
    return tag;
}

const Air = @import("../Air.zig");
const assert = std.debug.assert;
const codegen = @import("../codegen.zig");
const Legalize = @This();
const std = @import("std");
const Type = @import("../Type.zig");
const Zcu = @import("../Zcu.zig");
