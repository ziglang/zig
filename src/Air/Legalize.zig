zcu: *const Zcu,
air: Air,
features: std.enums.EnumSet(Feature),

pub const Feature = enum {
    /// Legalize (shift lhs, (splat rhs)) -> (shift lhs, rhs)
    remove_shift_vector_rhs_splat,
    /// Legalize reduce of a one element vector to a bitcast
    reduce_one_elem_to_bitcast,
};

pub const Features = std.enums.EnumFieldStruct(Feature, bool, false);

pub fn legalize(air: *Air, backend: std.builtin.CompilerBackend, zcu: *const Zcu) std.mem.Allocator.Error!void {
    var l: Legalize = .{
        .zcu = zcu,
        .air = air.*,
        .features = features: switch (backend) {
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
                break :features if (@hasDecl(Backend, "legalize_features"))
                    .init(Backend.legalize_features)
                else
                    .initEmpty();
            },
            _ => unreachable,
        },
    };
    defer air.* = l.air;
    if (!l.features.bits.eql(.initEmpty())) try l.legalizeBody(l.air.getMainBody());
}

fn legalizeBody(l: *Legalize, body: []const Air.Inst.Index) std.mem.Allocator.Error!void {
    const zcu = l.zcu;
    const ip = &zcu.intern_pool;
    const tags = l.air.instructions.items(.tag);
    const data = l.air.instructions.items(.data);
    for (body) |inst| inst: switch (tags[@intFromEnum(inst)]) {
        else => {},

        .shl,
        .shl_exact,
        .shl_sat,
        .shr,
        .shr_exact,
        => |air_tag| if (l.features.contains(.remove_shift_vector_rhs_splat)) done: {
            const bin_op = data[@intFromEnum(inst)].bin_op;
            const ty = l.air.typeOf(bin_op.rhs, ip);
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
                switch (tags[@intFromEnum(rhs_inst)]) {
                    else => {},
                    .splat => continue :inst l.replaceInst(inst, air_tag, .{ .bin_op = .{
                        .lhs = bin_op.lhs,
                        .rhs = data[@intFromEnum(rhs_inst)].ty_op.operand,
                    } }),
                }
            }
        },

        .reduce,
        .reduce_optimized,
        => if (l.features.contains(.reduce_one_elem_to_bitcast)) done: {
            const reduce = data[@intFromEnum(inst)].reduce;
            const vector_ty = l.air.typeOf(reduce.operand, ip);
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
            const pl_op = data[@intFromEnum(inst)].pl_op;
            const extra = l.air.extraData(Air.Try, pl_op.payload);
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end..][0..extra.data.body_len]));
        },
        .try_ptr, .try_ptr_cold => {
            const ty_pl = data[@intFromEnum(inst)].ty_pl;
            const extra = l.air.extraData(Air.TryPtr, ty_pl.payload);
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end..][0..extra.data.body_len]));
        },
        .block, .loop => {
            const ty_pl = data[@intFromEnum(inst)].ty_pl;
            const extra = l.air.extraData(Air.Block, ty_pl.payload);
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end..][0..extra.data.body_len]));
        },
        .dbg_inline_block => {
            const ty_pl = data[@intFromEnum(inst)].ty_pl;
            const extra = l.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end..][0..extra.data.body_len]));
        },
        .cond_br => {
            const pl_op = data[@intFromEnum(inst)].pl_op;
            const extra = l.air.extraData(Air.CondBr, pl_op.payload);
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end..][0..extra.data.then_body_len]));
            try l.legalizeBody(@ptrCast(l.air.extra.items[extra.end + extra.data.then_body_len ..][0..extra.data.else_body_len]));
        },
        .switch_br, .loop_switch_br => {
            const switch_br = l.air.unwrapSwitch(inst);
            var it = switch_br.iterateCases();
            while (it.next()) |case| try l.legalizeBody(case.body);
            try l.legalizeBody(it.elseBody());
        },
    };
}

// inline to propagate comptime `tag`s
inline fn replaceInst(l: *Legalize, inst: Air.Inst.Index, tag: Air.Inst.Tag, data: Air.Inst.Data) Air.Inst.Tag {
    const ip = &l.zcu.intern_pool;
    const orig_ty = if (std.debug.runtime_safety) l.air.typeOfIndex(inst, ip) else {};
    l.air.instructions.items(.tag)[@intFromEnum(inst)] = tag;
    l.air.instructions.items(.data)[@intFromEnum(inst)] = data;
    if (std.debug.runtime_safety) std.debug.assert(l.air.typeOfIndex(inst, ip).toIntern() == orig_ty.toIntern());
    return tag;
}

const Air = @import("../Air.zig");
const codegen = @import("../codegen.zig");
const Legalize = @This();
const std = @import("std");
const Zcu = @import("../Zcu.zig");
