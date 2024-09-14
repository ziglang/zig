//! Verifies that Liveness information is valid.

gpa: std.mem.Allocator,
air: Air,
liveness: Liveness,
live: LiveMap = .{},
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, LiveMap) = .empty,
loops: std.AutoHashMapUnmanaged(Air.Inst.Index, LiveMap) = .empty,
intern_pool: *const InternPool,

pub const Error = error{ LivenessInvalid, OutOfMemory };

pub fn deinit(self: *Verify) void {
    self.live.deinit(self.gpa);
    {
        var it = self.blocks.valueIterator();
        while (it.next()) |block| block.deinit(self.gpa);
        self.blocks.deinit(self.gpa);
    }
    {
        var it = self.loops.valueIterator();
        while (it.next()) |block| block.deinit(self.gpa);
        self.loops.deinit(self.gpa);
    }
    self.* = undefined;
}

pub fn verify(self: *Verify) Error!void {
    self.live.clearRetainingCapacity();
    self.blocks.clearRetainingCapacity();
    self.loops.clearRetainingCapacity();
    try self.verifyBody(self.air.getMainBody());
    // We don't care about `self.live` now, because the loop body was noreturn - everything being dead was checked on `ret` etc
    assert(self.blocks.count() == 0);
    assert(self.loops.count() == 0);
}

const LiveMap = std.AutoHashMapUnmanaged(Air.Inst.Index, void);

fn verifyBody(self: *Verify, body: []const Air.Inst.Index) Error!void {
    const ip = self.intern_pool;
    const tags = self.air.instructions.items(.tag);
    const data = self.air.instructions.items(.data);
    for (body) |inst| {
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip)) {
            // This instruction will not be lowered and should be ignored.
            continue;
        }

        switch (tags[@intFromEnum(inst)]) {
            // no operands
            .arg,
            .alloc,
            .inferred_alloc,
            .inferred_alloc_comptime,
            .ret_ptr,
            .breakpoint,
            .dbg_stmt,
            .fence,
            .ret_addr,
            .frame_addr,
            .wasm_memory_size,
            .err_return_trace,
            .save_err_return_trace_index,
            .c_va_start,
            .work_item_id,
            .work_group_size,
            .work_group_id,
            => try self.verifyInstOperands(inst, .{ .none, .none, .none }),

            .trap, .unreach => {
                try self.verifyInstOperands(inst, .{ .none, .none, .none });
                // This instruction terminates the function, so everything should be dead
                if (self.live.count() > 0) return invalid("%{}: instructions still alive", .{inst});
            },

            // unary
            .not,
            .bitcast,
            .load,
            .fpext,
            .fptrunc,
            .intcast,
            .trunc,
            .optional_payload,
            .optional_payload_ptr,
            .optional_payload_ptr_set,
            .errunion_payload_ptr_set,
            .wrap_optional,
            .unwrap_errunion_payload,
            .unwrap_errunion_err,
            .unwrap_errunion_payload_ptr,
            .unwrap_errunion_err_ptr,
            .wrap_errunion_payload,
            .wrap_errunion_err,
            .slice_ptr,
            .slice_len,
            .ptr_slice_len_ptr,
            .ptr_slice_ptr_ptr,
            .struct_field_ptr_index_0,
            .struct_field_ptr_index_1,
            .struct_field_ptr_index_2,
            .struct_field_ptr_index_3,
            .array_to_slice,
            .int_from_float,
            .int_from_float_optimized,
            .float_from_int,
            .get_union_tag,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .splat,
            .error_set_has_value,
            .addrspace_cast,
            .c_va_arg,
            .c_va_copy,
            .abs,
            => {
                const ty_op = data[@intFromEnum(inst)].ty_op;
                try self.verifyInstOperands(inst, .{ ty_op.operand, .none, .none });
            },
            .is_null,
            .is_non_null,
            .is_null_ptr,
            .is_non_null_ptr,
            .is_err,
            .is_non_err,
            .is_err_ptr,
            .is_non_err_ptr,
            .int_from_ptr,
            .int_from_bool,
            .is_named_enum_value,
            .tag_name,
            .error_name,
            .sqrt,
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
            .cmp_lt_errors_len,
            .set_err_return_trace,
            .c_va_end,
            => {
                const un_op = data[@intFromEnum(inst)].un_op;
                try self.verifyInstOperands(inst, .{ un_op, .none, .none });
            },
            .ret,
            .ret_safe,
            .ret_load,
            => {
                const un_op = data[@intFromEnum(inst)].un_op;
                try self.verifyInstOperands(inst, .{ un_op, .none, .none });
                // This instruction terminates the function, so everything should be dead
                if (self.live.count() > 0) return invalid("%{}: instructions still alive", .{inst});
            },
            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            .wasm_memory_grow,
            => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                try self.verifyInstOperands(inst, .{ pl_op.operand, .none, .none });
            },
            .prefetch => {
                const prefetch = data[@intFromEnum(inst)].prefetch;
                try self.verifyInstOperands(inst, .{ prefetch.ptr, .none, .none });
            },
            .reduce,
            .reduce_optimized,
            => {
                const reduce = data[@intFromEnum(inst)].reduce;
                try self.verifyInstOperands(inst, .{ reduce.operand, .none, .none });
            },
            .union_init => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.init, .none, .none });
            },
            .struct_field_ptr, .struct_field_val => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.struct_operand, .none, .none });
            },
            .field_parent_ptr => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.field_ptr, .none, .none });
            },
            .atomic_load => {
                const atomic_load = data[@intFromEnum(inst)].atomic_load;
                try self.verifyInstOperands(inst, .{ atomic_load.ptr, .none, .none });
            },

            // binary
            .add,
            .add_safe,
            .add_optimized,
            .add_wrap,
            .add_sat,
            .sub,
            .sub_safe,
            .sub_optimized,
            .sub_wrap,
            .sub_sat,
            .mul,
            .mul_safe,
            .mul_optimized,
            .mul_wrap,
            .mul_sat,
            .div_float,
            .div_float_optimized,
            .div_trunc,
            .div_trunc_optimized,
            .div_floor,
            .div_floor_optimized,
            .div_exact,
            .div_exact_optimized,
            .rem,
            .rem_optimized,
            .mod,
            .mod_optimized,
            .bit_and,
            .bit_or,
            .xor,
            .cmp_lt,
            .cmp_lt_optimized,
            .cmp_lte,
            .cmp_lte_optimized,
            .cmp_eq,
            .cmp_eq_optimized,
            .cmp_gte,
            .cmp_gte_optimized,
            .cmp_gt,
            .cmp_gt_optimized,
            .cmp_neq,
            .cmp_neq_optimized,
            .bool_and,
            .bool_or,
            .store,
            .store_safe,
            .array_elem_val,
            .slice_elem_val,
            .ptr_elem_val,
            .shl,
            .shl_exact,
            .shl_sat,
            .shr,
            .shr_exact,
            .atomic_store_unordered,
            .atomic_store_monotonic,
            .atomic_store_release,
            .atomic_store_seq_cst,
            .set_union_tag,
            .min,
            .max,
            .memset,
            .memset_safe,
            .memcpy,
            => {
                const bin_op = data[@intFromEnum(inst)].bin_op;
                try self.verifyInstOperands(inst, .{ bin_op.lhs, bin_op.rhs, .none });
            },
            .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            .ptr_add,
            .ptr_sub,
            .ptr_elem_ptr,
            .slice_elem_ptr,
            .slice,
            => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.lhs, extra.rhs, .none });
            },
            .shuffle => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.Shuffle, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.a, extra.b, .none });
            },
            .cmp_vector,
            .cmp_vector_optimized,
            => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.lhs, extra.rhs, .none });
            },
            .atomic_rmw => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;
                try self.verifyInstOperands(inst, .{ pl_op.operand, extra.operand, .none });
            },

            // ternary
            .select => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
                try self.verifyInstOperands(inst, .{ pl_op.operand, extra.lhs, extra.rhs });
            },
            .mul_add => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
                try self.verifyInstOperands(inst, .{ extra.lhs, extra.rhs, pl_op.operand });
            },
            .vector_store_elem => {
                const vector_store_elem = data[@intFromEnum(inst)].vector_store_elem;
                const extra = self.air.extraData(Air.Bin, vector_store_elem.payload).data;
                try self.verifyInstOperands(inst, .{ vector_store_elem.vector_ptr, extra.lhs, extra.rhs });
            },
            .cmpxchg_strong,
            .cmpxchg_weak,
            => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
                try self.verifyInstOperands(inst, .{ extra.ptr, extra.expected_value, extra.new_value });
            },

            // big tombs
            .aggregate_init => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const aggregate_ty = ty_pl.ty.toType();
                const len = @as(usize, @intCast(aggregate_ty.arrayLenIp(ip)));
                const elements = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[ty_pl.payload..][0..len]));

                var bt = self.liveness.iterateBigTomb(inst);
                for (elements) |element| {
                    try self.verifyOperand(inst, element, bt.feed());
                }
                try self.verifyInst(inst);
            },
            .call, .call_always_tail, .call_never_tail, .call_never_inline => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.Call, pl_op.payload);
                const args = @as(
                    []const Air.Inst.Ref,
                    @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]),
                );

                var bt = self.liveness.iterateBigTomb(inst);
                try self.verifyOperand(inst, pl_op.operand, bt.feed());
                for (args) |arg| {
                    try self.verifyOperand(inst, arg, bt.feed());
                }
                try self.verifyInst(inst);
            },
            .assembly => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.Asm, ty_pl.payload);
                var extra_i = extra.end;
                const outputs = @as(
                    []const Air.Inst.Ref,
                    @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]),
                );
                extra_i += outputs.len;
                const inputs = @as(
                    []const Air.Inst.Ref,
                    @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]),
                );
                extra_i += inputs.len;

                var bt = self.liveness.iterateBigTomb(inst);
                for (outputs) |output| {
                    if (output != .none) {
                        try self.verifyOperand(inst, output, bt.feed());
                    }
                }
                for (inputs) |input| {
                    try self.verifyOperand(inst, input, bt.feed());
                }
                try self.verifyInst(inst);
            },

            // control flow
            .@"try", .try_cold => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.Try, pl_op.payload);
                const try_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);

                const cond_br_liveness = self.liveness.getCondBr(inst);

                try self.verifyOperand(inst, pl_op.operand, self.liveness.operandDies(inst, 0));

                var live = try self.live.clone(self.gpa);
                defer live.deinit(self.gpa);

                for (cond_br_liveness.else_deaths) |death| try self.verifyDeath(inst, death);
                try self.verifyBody(try_body);

                self.live.deinit(self.gpa);
                self.live = live.move();

                for (cond_br_liveness.then_deaths) |death| try self.verifyDeath(inst, death);

                try self.verifyInst(inst);
            },
            .try_ptr, .try_ptr_cold => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
                const try_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);

                const cond_br_liveness = self.liveness.getCondBr(inst);

                try self.verifyOperand(inst, extra.data.ptr, self.liveness.operandDies(inst, 0));

                var live = try self.live.clone(self.gpa);
                defer live.deinit(self.gpa);

                for (cond_br_liveness.else_deaths) |death| try self.verifyDeath(inst, death);
                try self.verifyBody(try_body);

                self.live.deinit(self.gpa);
                self.live = live.move();

                for (cond_br_liveness.then_deaths) |death| try self.verifyDeath(inst, death);

                try self.verifyInst(inst);
            },
            .br => {
                const br = data[@intFromEnum(inst)].br;
                const gop = try self.blocks.getOrPut(self.gpa, br.block_inst);

                try self.verifyOperand(inst, br.operand, self.liveness.operandDies(inst, 0));
                if (gop.found_existing) {
                    try self.verifyMatchingLiveness(br.block_inst, gop.value_ptr.*);
                } else {
                    gop.value_ptr.* = try self.live.clone(self.gpa);
                }
                try self.verifyInst(inst);
            },
            .repeat => {
                const repeat = data[@intFromEnum(inst)].repeat;
                const expected_live = self.loops.get(repeat.loop_inst) orelse
                    return invalid("%{}: loop %{} not in scope", .{ @intFromEnum(inst), @intFromEnum(repeat.loop_inst) });

                try self.verifyMatchingLiveness(repeat.loop_inst, expected_live);
            },
            .switch_dispatch => {
                const br = data[@intFromEnum(inst)].br;

                try self.verifyOperand(inst, br.operand, self.liveness.operandDies(inst, 0));

                const expected_live = self.loops.get(br.block_inst) orelse
                    return invalid("%{}: loop %{} not in scope", .{ @intFromEnum(inst), @intFromEnum(br.block_inst) });

                try self.verifyMatchingLiveness(br.block_inst, expected_live);
            },
            .block, .dbg_inline_block => |tag| {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const block_ty = ty_pl.ty.toType();
                const block_body: []const Air.Inst.Index = @ptrCast(switch (tag) {
                    inline .block, .dbg_inline_block => |comptime_tag| body: {
                        const extra = self.air.extraData(switch (comptime_tag) {
                            .block => Air.Block,
                            .dbg_inline_block => Air.DbgInlineBlock,
                            else => unreachable,
                        }, ty_pl.payload);
                        break :body self.air.extra[extra.end..][0..extra.data.body_len];
                    },
                    else => unreachable,
                });
                const block_liveness = self.liveness.getBlock(inst);

                var orig_live = try self.live.clone(self.gpa);
                defer orig_live.deinit(self.gpa);

                assert(!self.blocks.contains(inst));
                try self.verifyBody(block_body);

                // Liveness data after the block body is garbage, but we want to
                // restore it to verify deaths
                self.live.deinit(self.gpa);
                self.live = orig_live.move();

                for (block_liveness.deaths) |death| try self.verifyDeath(inst, death);

                if (ip.isNoReturn(block_ty.toIntern())) {
                    assert(!self.blocks.contains(inst));
                } else {
                    var live = self.blocks.fetchRemove(inst).?.value;
                    defer live.deinit(self.gpa);

                    try self.verifyMatchingLiveness(inst, live);
                }

                try self.verifyInstOperands(inst, .{ .none, .none, .none });
            },
            .loop => {
                const ty_pl = data[@intFromEnum(inst)].ty_pl;
                const extra = self.air.extraData(Air.Block, ty_pl.payload);
                const loop_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);

                // The same stuff should be alive after the loop as before it.
                const gop = try self.loops.getOrPut(self.gpa, inst);
                if (gop.found_existing) return invalid("%{}: loop already exists", .{@intFromEnum(inst)});
                defer {
                    var live = self.loops.fetchRemove(inst).?;
                    live.value.deinit(self.gpa);
                }
                gop.value_ptr.* = try self.live.clone(self.gpa);

                try self.verifyBody(loop_body);

                try self.verifyInstOperands(inst, .{ .none, .none, .none });
            },
            .cond_br => {
                const pl_op = data[@intFromEnum(inst)].pl_op;
                const extra = self.air.extraData(Air.CondBr, pl_op.payload);
                const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
                const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
                const cond_br_liveness = self.liveness.getCondBr(inst);

                try self.verifyOperand(inst, pl_op.operand, self.liveness.operandDies(inst, 0));

                var live = try self.live.clone(self.gpa);
                defer live.deinit(self.gpa);

                for (cond_br_liveness.then_deaths) |death| try self.verifyDeath(inst, death);
                try self.verifyBody(then_body);

                self.live.deinit(self.gpa);
                self.live = live.move();

                for (cond_br_liveness.else_deaths) |death| try self.verifyDeath(inst, death);
                try self.verifyBody(else_body);

                try self.verifyInst(inst);
            },
            .switch_br, .loop_switch_br => {
                const switch_br = self.air.unwrapSwitch(inst);
                const switch_br_liveness = try self.liveness.getSwitchBr(
                    self.gpa,
                    inst,
                    switch_br.cases_len + 1,
                );
                defer self.gpa.free(switch_br_liveness.deaths);

                try self.verifyOperand(inst, switch_br.operand, self.liveness.operandDies(inst, 0));

                // Excluding the operand (which we just handled), the same stuff should be alive
                // after the loop as before it.
                {
                    const gop = try self.loops.getOrPut(self.gpa, inst);
                    if (gop.found_existing) return invalid("%{}: loop already exists", .{@intFromEnum(inst)});
                    gop.value_ptr.* = self.live.move();
                }
                defer {
                    var live = self.loops.fetchRemove(inst).?;
                    live.value.deinit(self.gpa);
                }

                var it = switch_br.iterateCases();
                while (it.next()) |case| {
                    self.live.deinit(self.gpa);
                    self.live = try self.loops.get(inst).?.clone(self.gpa);

                    for (switch_br_liveness.deaths[case.idx]) |death| try self.verifyDeath(inst, death);
                    try self.verifyBody(case.body);
                }

                const else_body = it.elseBody();
                if (else_body.len > 0) {
                    self.live.deinit(self.gpa);
                    self.live = try self.loops.get(inst).?.clone(self.gpa);
                    for (switch_br_liveness.deaths[switch_br.cases_len]) |death| try self.verifyDeath(inst, death);
                    try self.verifyBody(else_body);
                }

                try self.verifyInst(inst);
            },
        }
    }
}

fn verifyDeath(self: *Verify, inst: Air.Inst.Index, operand: Air.Inst.Index) Error!void {
    try self.verifyOperand(inst, operand.toRef(), true);
}

fn verifyOperand(self: *Verify, inst: Air.Inst.Index, op_ref: Air.Inst.Ref, dies: bool) Error!void {
    const operand = op_ref.toIndexAllowNone() orelse {
        assert(!dies);
        return;
    };
    if (dies) {
        if (!self.live.remove(operand)) return invalid("%{}: dead operand %{} reused and killed again", .{ inst, operand });
    } else {
        if (!self.live.contains(operand)) return invalid("%{}: dead operand %{} reused", .{ inst, operand });
    }
}

fn verifyInstOperands(
    self: *Verify,
    inst: Air.Inst.Index,
    operands: [Liveness.bpi - 1]Air.Inst.Ref,
) Error!void {
    for (operands, 0..) |operand, operand_index| {
        const dies = self.liveness.operandDies(inst, @as(Liveness.OperandInt, @intCast(operand_index)));
        try self.verifyOperand(inst, operand, dies);
    }
    try self.verifyInst(inst);
}

fn verifyInst(self: *Verify, inst: Air.Inst.Index) Error!void {
    if (self.liveness.isUnused(inst)) {
        assert(!self.live.contains(inst));
    } else {
        try self.live.putNoClobber(self.gpa, inst, {});
    }
}

fn verifyMatchingLiveness(self: *Verify, block: Air.Inst.Index, live: LiveMap) Error!void {
    if (self.live.count() != live.count()) return invalid("%{}: different deaths across branches", .{block});
    var live_it = self.live.keyIterator();
    while (live_it.next()) |live_inst| if (!live.contains(live_inst.*)) return invalid("%{}: different deaths across branches", .{block});
}

fn invalid(comptime fmt: []const u8, args: anytype) error{LivenessInvalid} {
    log.err(fmt, args);
    return error.LivenessInvalid;
}

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.liveness_verify);

const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const InternPool = @import("../InternPool.zig");
const Verify = @This();
