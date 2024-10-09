//! For each AIR instruction, we want to know:
//! * Is the instruction unreferenced (e.g. dies immediately)?
//! * For each of its operands, does the operand die with this instruction (e.g. is
//!   this the last reference to it)?
//! Some instructions are special, such as:
//! * Conditional Branches
//! * Switch Branches
const std = @import("std");
const log = std.log.scoped(.liveness);
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Log2Int = std.math.Log2Int;

const Liveness = @This();
const trace = @import("tracy.zig").trace;
const Air = @import("Air.zig");
const InternPool = @import("InternPool.zig");

pub const Verify = @import("Liveness/Verify.zig");

/// This array is split into sets of 4 bits per AIR instruction.
/// The MSB (0bX000) is whether the instruction is unreferenced.
/// The LSB (0b000X) is the first operand, and so on, up to 3 operands. A set bit means the
/// operand dies after this instruction.
/// Instructions which need more data to track liveness have special handling via the
/// `special` table.
tomb_bits: []usize,
/// Sparse table of specially handled instructions. The value is an index into the `extra`
/// array. The meaning of the data depends on the AIR tag.
///  * `cond_br` - points to a `CondBr` in `extra` at this index.
///  * `try`, `try_ptr` - points to a `CondBr` in `extra` at this index. The error path (the block
///    in the instruction) is considered the "else" path, and the rest of the block the "then".
///  * `switch_br` - points to a `SwitchBr` in `extra` at this index.
///  * `loop_switch_br` - points to a `SwitchBr` in `extra` at this index.
///  * `block` - points to a `Block` in `extra` at this index.
///  * `asm`, `call`, `aggregate_init` - the value is a set of bits which are the extra tomb
///    bits of operands.
///    The main tomb bits are still used and the extra ones are starting with the lsb of the
///    value here.
special: std.AutoHashMapUnmanaged(Air.Inst.Index, u32),
/// Auxiliary data. The way this data is interpreted is determined contextually.
extra: []const u32,

/// Trailing is the set of instructions whose lifetimes end at the start of the then branch,
/// followed by the set of instructions whose lifetimes end at the start of the else branch.
pub const CondBr = struct {
    then_death_count: u32,
    else_death_count: u32,
};

/// Trailing is:
/// * For each case in the same order as in the AIR:
///   - case_death_count: u32
///   - Air.Inst.Index for each `case_death_count`: set of instructions whose lifetimes
///     end at the start of this case.
/// * Air.Inst.Index for each `else_death_count`: set of instructions whose lifetimes
///   end at the start of the else case.
pub const SwitchBr = struct {
    else_death_count: u32,
};

/// Trailing is the set of instructions which die in the block. Note that these are not additional
/// deaths (they are all recorded as normal within the block), but backends may use this information
/// as a more efficient way to track which instructions are still alive after a block.
pub const Block = struct {
    death_count: u32,
};

/// Liveness analysis runs in several passes. Each pass iterates backwards over instructions in
/// bodies, and recurses into bodies.
const LivenessPass = enum {
    /// In this pass, we perform some basic analysis of loops to gain information the main pass needs.
    /// In particular, for every `loop` and `loop_switch_br`, we track the following information:
    /// * Every outer block which the loop body contains a `br` to.
    /// * Every outer loop which the loop body contains a `repeat` to.
    /// * Every operand referenced within the loop body but created outside the loop.
    /// This gives the main analysis pass enough information to determine the full set of
    /// instructions which need to be alive when a loop repeats. This data is TEMPORARILY stored in
    /// `a.extra`. It is not re-added to `extra` by the main pass, since it is not useful to
    /// backends.
    loop_analysis,

    /// This pass performs the main liveness analysis, setting up tombs and extra data while
    /// considering control flow etc.
    main_analysis,
};

/// Each analysis pass may wish to pass data through calls. A pointer to a `LivenessPassData(pass)`
/// stored on the stack is passed through calls to `analyzeInst` etc.
fn LivenessPassData(comptime pass: LivenessPass) type {
    return switch (pass) {
        .loop_analysis => struct {
            /// The set of blocks which are exited with a `br` instruction at some point within this
            /// body and which we are currently within. Also includes `loop`s which are the target
            /// of a `repeat` instruction, and `loop_switch_br`s which are the target of a
            /// `switch_dispatch` instruction.
            breaks: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .empty,

            /// The set of operands for which we have seen at least one usage but not their birth.
            live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .empty,

            fn deinit(self: *@This(), gpa: Allocator) void {
                self.breaks.deinit(gpa);
                self.live_set.deinit(gpa);
            }
        },

        .main_analysis => struct {
            /// Every `block` and `loop` currently under analysis.
            block_scopes: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockScope) = .empty,

            /// The set of instructions currently alive in the current control
            /// flow branch.
            live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .empty,

            /// The extra data initialized by the `loop_analysis` pass for this pass to consume.
            /// Owned by this struct during this pass.
            old_extra: std.ArrayListUnmanaged(u32) = .empty,

            const BlockScope = struct {
                /// If this is a `block`, these instructions are alive upon a `br` to this block.
                /// If this is a `loop`, these instructions are alive upon a `repeat` to this block.
                live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void),
            };

            fn deinit(self: *@This(), gpa: Allocator) void {
                var it = self.block_scopes.valueIterator();
                while (it.next()) |block| {
                    block.live_set.deinit(gpa);
                }
                self.block_scopes.deinit(gpa);
                self.live_set.deinit(gpa);
                self.old_extra.deinit(gpa);
            }
        },
    };
}

pub fn analyze(gpa: Allocator, air: Air, intern_pool: *InternPool) Allocator.Error!Liveness {
    const tracy = trace(@src());
    defer tracy.end();

    var a: Analysis = .{
        .gpa = gpa,
        .air = air,
        .tomb_bits = try gpa.alloc(
            usize,
            (air.instructions.len * bpi + @bitSizeOf(usize) - 1) / @bitSizeOf(usize),
        ),
        .extra = .{},
        .special = .{},
        .intern_pool = intern_pool,
    };
    errdefer gpa.free(a.tomb_bits);
    errdefer a.special.deinit(gpa);
    defer a.extra.deinit(gpa);

    @memset(a.tomb_bits, 0);

    const main_body = air.getMainBody();

    {
        var data: LivenessPassData(.loop_analysis) = .{};
        defer data.deinit(gpa);
        try analyzeBody(&a, .loop_analysis, &data, main_body);
    }

    {
        var data: LivenessPassData(.main_analysis) = .{};
        defer data.deinit(gpa);
        data.old_extra = a.extra;
        a.extra = .{};
        try analyzeBody(&a, .main_analysis, &data, main_body);
        assert(data.live_set.count() == 0);
    }

    return .{
        .tomb_bits = a.tomb_bits,
        .special = a.special,
        .extra = try a.extra.toOwnedSlice(gpa),
    };
}

pub fn getTombBits(l: Liveness, inst: Air.Inst.Index) Bpi {
    const usize_index = (@intFromEnum(inst) * bpi) / @bitSizeOf(usize);
    return @as(Bpi, @truncate(l.tomb_bits[usize_index] >>
        @as(Log2Int(usize), @intCast((@intFromEnum(inst) % (@bitSizeOf(usize) / bpi)) * bpi))));
}

pub fn isUnused(l: Liveness, inst: Air.Inst.Index) bool {
    const usize_index = (@intFromEnum(inst) * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @as(Log2Int(usize), @intCast((@intFromEnum(inst) % (@bitSizeOf(usize) / bpi)) * bpi + (bpi - 1)));
    return (l.tomb_bits[usize_index] & mask) != 0;
}

pub fn operandDies(l: Liveness, inst: Air.Inst.Index, operand: OperandInt) bool {
    assert(operand < bpi - 1);
    const usize_index = (@intFromEnum(inst) * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @as(Log2Int(usize), @intCast((@intFromEnum(inst) % (@bitSizeOf(usize) / bpi)) * bpi + operand));
    return (l.tomb_bits[usize_index] & mask) != 0;
}

pub fn clearOperandDeath(l: Liveness, inst: Air.Inst.Index, operand: OperandInt) void {
    assert(operand < bpi - 1);
    const usize_index = (@intFromEnum(inst) * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @as(Log2Int(usize), @intCast((@intFromEnum(inst) % (@bitSizeOf(usize) / bpi)) * bpi + operand));
    l.tomb_bits[usize_index] &= ~mask;
}

const OperandCategory = enum {
    /// The operand lives on, but this instruction cannot possibly mutate memory.
    none,
    /// The operand lives on and this instruction can mutate memory.
    write,
    /// The operand dies at this instruction.
    tomb,
    /// The operand lives on, and this instruction is noreturn.
    noret,
    /// This instruction is too complicated for analysis, no information is available.
    complex,
};

/// Given an instruction that we are examining, and an operand that we are looking for,
/// returns a classification.
pub fn categorizeOperand(
    l: Liveness,
    air: Air,
    inst: Air.Inst.Index,
    operand: Air.Inst.Index,
    ip: *const InternPool,
) OperandCategory {
    const air_tags = air.instructions.items(.tag);
    const air_datas = air.instructions.items(.data);
    const operand_ref = operand.toRef();
    switch (air_tags[@intFromEnum(inst)]) {
        .add,
        .add_safe,
        .add_wrap,
        .add_sat,
        .add_optimized,
        .sub,
        .sub_safe,
        .sub_wrap,
        .sub_sat,
        .sub_optimized,
        .mul,
        .mul_safe,
        .mul_wrap,
        .mul_sat,
        .mul_optimized,
        .div_float,
        .div_trunc,
        .div_floor,
        .div_exact,
        .rem,
        .mod,
        .bit_and,
        .bit_or,
        .xor,
        .cmp_lt,
        .cmp_lte,
        .cmp_eq,
        .cmp_gte,
        .cmp_gt,
        .cmp_neq,
        .bool_and,
        .bool_or,
        .array_elem_val,
        .slice_elem_val,
        .ptr_elem_val,
        .shl,
        .shl_exact,
        .shl_sat,
        .shr,
        .shr_exact,
        .min,
        .max,
        .div_float_optimized,
        .div_trunc_optimized,
        .div_floor_optimized,
        .div_exact_optimized,
        .rem_optimized,
        .mod_optimized,
        .neg_optimized,
        .cmp_lt_optimized,
        .cmp_lte_optimized,
        .cmp_eq_optimized,
        .cmp_gte_optimized,
        .cmp_gt_optimized,
        .cmp_neq_optimized,
        => {
            const o = air_datas[@intFromEnum(inst)].bin_op;
            if (o.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (o.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },

        .store,
        .store_safe,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .set_union_tag,
        .memset,
        .memset_safe,
        .memcpy,
        => {
            const o = air_datas[@intFromEnum(inst)].bin_op;
            if (o.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (o.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            return .write;
        },

        .vector_store_elem => {
            const o = air_datas[@intFromEnum(inst)].vector_store_elem;
            const extra = air.extraData(Air.Bin, o.payload).data;
            if (o.vector_ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .write;
        },

        .arg,
        .alloc,
        .inferred_alloc,
        .inferred_alloc_comptime,
        .ret_ptr,
        .trap,
        .breakpoint,
        .repeat,
        .switch_dispatch,
        .dbg_stmt,
        .unreach,
        .ret_addr,
        .frame_addr,
        .wasm_memory_size,
        .err_return_trace,
        .save_err_return_trace_index,
        .c_va_start,
        .work_item_id,
        .work_group_size,
        .work_group_id,
        => return .none,

        .not,
        .bitcast,
        .load,
        .fpext,
        .fptrunc,
        .intcast,
        .trunc,
        .optional_payload,
        .optional_payload_ptr,
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
            const o = air_datas[@intFromEnum(inst)].ty_op;
            if (o.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .optional_payload_ptr_set,
        .errunion_payload_ptr_set,
        => {
            const o = air_datas[@intFromEnum(inst)].ty_op;
            if (o.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            return .write;
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
        .cmp_lt_errors_len,
        .c_va_end,
        => {
            const o = air_datas[@intFromEnum(inst)].un_op;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .ret,
        .ret_safe,
        .ret_load,
        => {
            const o = air_datas[@intFromEnum(inst)].un_op;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .noret);
            return .noret;
        },

        .set_err_return_trace => {
            const o = air_datas[@intFromEnum(inst)].un_op;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            return .write;
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
            const ty_pl = air_datas[@intFromEnum(inst)].ty_pl;
            const extra = air.extraData(Air.Bin, ty_pl.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },

        .dbg_var_ptr,
        .dbg_var_val,
        .dbg_arg_inline,
        => {
            const o = air_datas[@intFromEnum(inst)].pl_op.operand;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .prefetch => {
            const prefetch = air_datas[@intFromEnum(inst)].prefetch;
            if (prefetch.ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const inst_data = air_datas[@intFromEnum(inst)].pl_op;
            const callee = inst_data.operand;
            const extra = air.extraData(Air.Call, inst_data.payload);
            const args = @as([]const Air.Inst.Ref, @ptrCast(air.extra[extra.end..][0..extra.data.args_len]));
            if (args.len + 1 <= bpi - 1) {
                if (callee == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
                for (args, 0..) |arg, i| {
                    if (arg == operand_ref) return matchOperandSmallIndex(l, inst, @as(OperandInt, @intCast(i + 1)), .write);
                }
                return .write;
            }
            var bt = l.iterateBigTomb(inst);
            if (bt.feed()) {
                if (callee == operand_ref) return .tomb;
            } else {
                if (callee == operand_ref) return .write;
            }
            for (args) |arg| {
                if (bt.feed()) {
                    if (arg == operand_ref) return .tomb;
                } else {
                    if (arg == operand_ref) return .write;
                }
            }
            return .write;
        },
        .select => {
            const pl_op = air_datas[@intFromEnum(inst)].pl_op;
            const extra = air.extraData(Air.Bin, pl_op.payload).data;
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .none;
        },
        .shuffle => {
            const extra = air.extraData(Air.Shuffle, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.a == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.b == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },
        .reduce, .reduce_optimized => {
            const reduce = air_datas[@intFromEnum(inst)].reduce;
            if (reduce.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .cmp_vector, .cmp_vector_optimized => {
            const extra = air.extraData(Air.VectorCmp, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },
        .aggregate_init => {
            const ty_pl = air_datas[@intFromEnum(inst)].ty_pl;
            const aggregate_ty = ty_pl.ty.toType();
            const len = @as(usize, @intCast(aggregate_ty.arrayLenIp(ip)));
            const elements = @as([]const Air.Inst.Ref, @ptrCast(air.extra[ty_pl.payload..][0..len]));

            if (elements.len <= bpi - 1) {
                for (elements, 0..) |elem, i| {
                    if (elem == operand_ref) return matchOperandSmallIndex(l, inst, @as(OperandInt, @intCast(i)), .none);
                }
                return .none;
            }

            var bt = l.iterateBigTomb(inst);
            for (elements) |elem| {
                if (bt.feed()) {
                    if (elem == operand_ref) return .tomb;
                } else {
                    if (elem == operand_ref) return .write;
                }
            }
            return .write;
        },
        .union_init => {
            const extra = air.extraData(Air.UnionInit, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.init == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .struct_field_ptr, .struct_field_val => {
            const extra = air.extraData(Air.StructField, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.struct_operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .field_parent_ptr => {
            const extra = air.extraData(Air.FieldParentPtr, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.field_ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            const extra = air.extraData(Air.Cmpxchg, air_datas[@intFromEnum(inst)].ty_pl.payload).data;
            if (extra.ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.expected_value == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            if (extra.new_value == operand_ref) return matchOperandSmallIndex(l, inst, 2, .write);
            return .write;
        },
        .mul_add => {
            const pl_op = air_datas[@intFromEnum(inst)].pl_op;
            const extra = air.extraData(Air.Bin, pl_op.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .none;
        },
        .atomic_load => {
            const ptr = air_datas[@intFromEnum(inst)].atomic_load.ptr;
            if (ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .atomic_rmw => {
            const pl_op = air_datas[@intFromEnum(inst)].pl_op;
            const extra = air.extraData(Air.AtomicRmw, pl_op.payload).data;
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.operand == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            return .write;
        },

        .br => {
            const br = air_datas[@intFromEnum(inst)].br;
            if (br.operand == operand_ref) return matchOperandSmallIndex(l, operand, 0, .noret);
            return .noret;
        },
        .assembly => {
            return .complex;
        },
        .block, .dbg_inline_block => |tag| {
            const ty_pl = air_datas[@intFromEnum(inst)].ty_pl;
            const body: []const Air.Inst.Index = @ptrCast(switch (tag) {
                inline .block, .dbg_inline_block => |comptime_tag| body: {
                    const extra = air.extraData(switch (comptime_tag) {
                        .block => Air.Block,
                        .dbg_inline_block => Air.DbgInlineBlock,
                        else => unreachable,
                    }, ty_pl.payload);
                    break :body air.extra[extra.end..][0..extra.data.body_len];
                },
                else => unreachable,
            });

            if (body.len == 1 and air_tags[@intFromEnum(body[0])] == .cond_br) {
                // Peephole optimization for "panic-like" conditionals, which have
                // one empty branch and another which calls a `noreturn` function.
                // This allows us to infer that safety checks do not modify memory,
                // as far as control flow successors are concerned.

                const inst_data = air_datas[@intFromEnum(body[0])].pl_op;
                const cond_extra = air.extraData(Air.CondBr, inst_data.payload);
                if (inst_data.operand == operand_ref and operandDies(l, body[0], 0))
                    return .tomb;

                if (cond_extra.data.then_body_len > 2 or cond_extra.data.else_body_len > 2)
                    return .complex;

                const then_body: []const Air.Inst.Index = @ptrCast(air.extra[cond_extra.end..][0..cond_extra.data.then_body_len]);
                const else_body: []const Air.Inst.Index = @ptrCast(air.extra[cond_extra.end + cond_extra.data.then_body_len ..][0..cond_extra.data.else_body_len]);
                if (then_body.len > 1 and air_tags[@intFromEnum(then_body[1])] != .unreach)
                    return .complex;
                if (else_body.len > 1 and air_tags[@intFromEnum(else_body[1])] != .unreach)
                    return .complex;

                var operand_live: bool = true;
                for (&[_]Air.Inst.Index{ then_body[0], else_body[0] }) |cond_inst| {
                    if (l.categorizeOperand(air, cond_inst, operand, ip) == .tomb)
                        operand_live = false;

                    switch (air_tags[@intFromEnum(cond_inst)]) {
                        .br => { // Breaks immediately back to block
                            const br = air_datas[@intFromEnum(cond_inst)].br;
                            if (br.block_inst != inst)
                                return .complex;
                        },
                        .call => {}, // Calls a noreturn function
                        else => return .complex,
                    }
                }
                return if (operand_live) .none else .tomb;
            }

            return .complex;
        },

        .@"try",
        .try_cold,
        .try_ptr,
        .try_ptr_cold,
        .loop,
        .cond_br,
        .switch_br,
        .loop_switch_br,
        => return .complex,

        .wasm_memory_grow => {
            const pl_op = air_datas[@intFromEnum(inst)].pl_op;
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
    }
}

fn matchOperandSmallIndex(
    l: Liveness,
    inst: Air.Inst.Index,
    operand: OperandInt,
    default: OperandCategory,
) OperandCategory {
    if (operandDies(l, inst, operand)) {
        return .tomb;
    } else {
        return default;
    }
}

/// Higher level API.
pub const CondBrSlices = struct {
    then_deaths: []const Air.Inst.Index,
    else_deaths: []const Air.Inst.Index,
};

pub fn getCondBr(l: Liveness, inst: Air.Inst.Index) CondBrSlices {
    var index: usize = l.special.get(inst) orelse return .{
        .then_deaths = &.{},
        .else_deaths = &.{},
    };
    const then_death_count = l.extra[index];
    index += 1;
    const else_death_count = l.extra[index];
    index += 1;
    const then_deaths: []const Air.Inst.Index = @ptrCast(l.extra[index..][0..then_death_count]);
    index += then_death_count;
    return .{
        .then_deaths = then_deaths,
        .else_deaths = @ptrCast(l.extra[index..][0..else_death_count]),
    };
}

/// Indexed by case number as they appear in AIR.
/// Else is the last element.
pub const SwitchBrTable = struct {
    deaths: []const []const Air.Inst.Index,
};

/// Caller owns the memory.
pub fn getSwitchBr(l: Liveness, gpa: Allocator, inst: Air.Inst.Index, cases_len: u32) Allocator.Error!SwitchBrTable {
    var index: usize = l.special.get(inst) orelse return SwitchBrTable{
        .deaths = &.{},
    };
    const else_death_count = l.extra[index];
    index += 1;

    var deaths = std.ArrayList([]const Air.Inst.Index).init(gpa);
    defer deaths.deinit();
    try deaths.ensureTotalCapacity(cases_len + 1);

    var case_i: u32 = 0;
    while (case_i < cases_len - 1) : (case_i += 1) {
        const case_death_count: u32 = l.extra[index];
        index += 1;
        const case_deaths: []const Air.Inst.Index = @ptrCast(l.extra[index..][0..case_death_count]);
        index += case_death_count;
        deaths.appendAssumeCapacity(case_deaths);
    }
    {
        // Else
        const else_deaths: []const Air.Inst.Index = @ptrCast(l.extra[index..][0..else_death_count]);
        deaths.appendAssumeCapacity(else_deaths);
    }
    return SwitchBrTable{
        .deaths = try deaths.toOwnedSlice(),
    };
}

/// Note that this information is technically redundant, but is useful for
/// backends nonetheless: see `Block`.
pub const BlockSlices = struct {
    deaths: []const Air.Inst.Index,
};

pub fn getBlock(l: Liveness, inst: Air.Inst.Index) BlockSlices {
    const index: usize = l.special.get(inst) orelse return .{
        .deaths = &.{},
    };
    const death_count = l.extra[index];
    const deaths: []const Air.Inst.Index = @ptrCast(l.extra[index + 1 ..][0..death_count]);
    return .{
        .deaths = deaths,
    };
}

pub const LoopSlice = struct {
    deaths: []const Air.Inst.Index,
};

pub fn deinit(l: *Liveness, gpa: Allocator) void {
    gpa.free(l.tomb_bits);
    gpa.free(l.extra);
    l.special.deinit(gpa);
    l.* = undefined;
}

pub fn iterateBigTomb(l: Liveness, inst: Air.Inst.Index) BigTomb {
    return .{
        .tomb_bits = l.getTombBits(inst),
        .extra_start = l.special.get(inst) orelse 0,
        .extra_offset = 0,
        .extra = l.extra,
        .bit_index = 0,
        .reached_end = false,
    };
}

/// How many tomb bits per AIR instruction.
pub const bpi = 4;
pub const Bpi = std.meta.Int(.unsigned, bpi);
pub const OperandInt = std.math.Log2Int(Bpi);

/// Useful for decoders of Liveness information.
pub const BigTomb = struct {
    tomb_bits: Liveness.Bpi,
    bit_index: u32,
    extra_start: u32,
    extra_offset: u32,
    extra: []const u32,
    reached_end: bool,

    /// Returns whether the next operand dies.
    pub fn feed(bt: *BigTomb) bool {
        if (bt.reached_end) return false;

        const this_bit_index = bt.bit_index;
        bt.bit_index += 1;

        const small_tombs = bpi - 1;
        if (this_bit_index < small_tombs) {
            const dies = @as(u1, @truncate(bt.tomb_bits >> @as(Liveness.OperandInt, @intCast(this_bit_index)))) != 0;
            return dies;
        }

        const big_bit_index = this_bit_index - small_tombs;
        while (big_bit_index - bt.extra_offset * 31 >= 31) {
            if (@as(u1, @truncate(bt.extra[bt.extra_start + bt.extra_offset] >> 31)) != 0) {
                bt.reached_end = true;
                return false;
            }
            bt.extra_offset += 1;
        }
        const dies = @as(u1, @truncate(bt.extra[bt.extra_start + bt.extra_offset] >>
            @as(u5, @intCast(big_bit_index - bt.extra_offset * 31)))) != 0;
        return dies;
    }
};

/// In-progress data; on successful analysis converted into `Liveness`.
const Analysis = struct {
    gpa: Allocator,
    air: Air,
    intern_pool: *InternPool,
    tomb_bits: []usize,
    special: std.AutoHashMapUnmanaged(Air.Inst.Index, u32),
    extra: std.ArrayListUnmanaged(u32),

    fn storeTombBits(a: *Analysis, inst: Air.Inst.Index, tomb_bits: Bpi) void {
        const usize_index = (inst * bpi) / @bitSizeOf(usize);
        a.tomb_bits[usize_index] |= @as(usize, tomb_bits) <<
            @as(Log2Int(usize), @intCast((inst % (@bitSizeOf(usize) / bpi)) * bpi));
    }

    fn addExtra(a: *Analysis, extra: anytype) Allocator.Error!u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        try a.extra.ensureUnusedCapacity(a.gpa, fields.len);
        return addExtraAssumeCapacity(a, extra);
    }

    fn addExtraAssumeCapacity(a: *Analysis, extra: anytype) u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        const result = @as(u32, @intCast(a.extra.items.len));
        inline for (fields) |field| {
            a.extra.appendAssumeCapacity(switch (field.type) {
                u32 => @field(extra, field.name),
                else => @compileError("bad field type"),
            });
        }
        return result;
    }
};

fn analyzeBody(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    body: []const Air.Inst.Index,
) Allocator.Error!void {
    var i: usize = body.len;
    while (i != 0) {
        i -= 1;
        const inst = body[i];
        try analyzeInst(a, pass, data, inst);
    }
}

fn analyzeInst(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) Allocator.Error!void {
    const ip = a.intern_pool;
    const inst_tags = a.air.instructions.items(.tag);
    const inst_datas = a.air.instructions.items(.data);

    switch (inst_tags[@intFromEnum(inst)]) {
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
            const o = inst_datas[@intFromEnum(inst)].bin_op;
            return analyzeOperands(a, pass, data, inst, .{ o.lhs, o.rhs, .none });
        },

        .vector_store_elem => {
            const o = inst_datas[@intFromEnum(inst)].vector_store_elem;
            const extra = a.air.extraData(Air.Bin, o.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ o.vector_ptr, extra.lhs, extra.rhs });
        },

        .arg,
        .alloc,
        .ret_ptr,
        .breakpoint,
        .dbg_stmt,
        .ret_addr,
        .frame_addr,
        .wasm_memory_size,
        .err_return_trace,
        .save_err_return_trace_index,
        .c_va_start,
        .work_item_id,
        .work_group_size,
        .work_group_id,
        => return analyzeOperands(a, pass, data, inst, .{ .none, .none, .none }),

        .inferred_alloc, .inferred_alloc_comptime => unreachable,

        .trap,
        .unreach,
        => return analyzeFuncEnd(a, pass, data, inst, .{ .none, .none, .none }),

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
            const o = inst_datas[@intFromEnum(inst)].ty_op;
            return analyzeOperands(a, pass, data, inst, .{ o.operand, .none, .none });
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
            const operand = inst_datas[@intFromEnum(inst)].un_op;
            return analyzeOperands(a, pass, data, inst, .{ operand, .none, .none });
        },

        .ret,
        .ret_safe,
        .ret_load,
        => {
            const operand = inst_datas[@intFromEnum(inst)].un_op;
            return analyzeFuncEnd(a, pass, data, inst, .{ operand, .none, .none });
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
            const ty_pl = inst_datas[@intFromEnum(inst)].ty_pl;
            const extra = a.air.extraData(Air.Bin, ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, .none });
        },

        .dbg_var_ptr,
        .dbg_var_val,
        .dbg_arg_inline,
        => {
            const operand = inst_datas[@intFromEnum(inst)].pl_op.operand;
            return analyzeOperands(a, pass, data, inst, .{ operand, .none, .none });
        },

        .prefetch => {
            const prefetch = inst_datas[@intFromEnum(inst)].prefetch;
            return analyzeOperands(a, pass, data, inst, .{ prefetch.ptr, .none, .none });
        },

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const inst_data = inst_datas[@intFromEnum(inst)].pl_op;
            const callee = inst_data.operand;
            const extra = a.air.extraData(Air.Call, inst_data.payload);
            const args = @as([]const Air.Inst.Ref, @ptrCast(a.air.extra[extra.end..][0..extra.data.args_len]));
            if (args.len + 1 <= bpi - 1) {
                var buf = [1]Air.Inst.Ref{.none} ** (bpi - 1);
                buf[0] = callee;
                @memcpy(buf[1..][0..args.len], args);
                return analyzeOperands(a, pass, data, inst, buf);
            }

            var big = try AnalyzeBigOperands(pass).init(a, data, inst, args.len + 1);
            defer big.deinit();
            var i: usize = args.len;
            while (i > 0) {
                i -= 1;
                try big.feed(args[i]);
            }
            try big.feed(callee);
            return big.finish();
        },
        .select => {
            const pl_op = inst_datas[@intFromEnum(inst)].pl_op;
            const extra = a.air.extraData(Air.Bin, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ pl_op.operand, extra.lhs, extra.rhs });
        },
        .shuffle => {
            const extra = a.air.extraData(Air.Shuffle, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.a, extra.b, .none });
        },
        .reduce, .reduce_optimized => {
            const reduce = inst_datas[@intFromEnum(inst)].reduce;
            return analyzeOperands(a, pass, data, inst, .{ reduce.operand, .none, .none });
        },
        .cmp_vector, .cmp_vector_optimized => {
            const extra = a.air.extraData(Air.VectorCmp, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, .none });
        },
        .aggregate_init => {
            const ty_pl = inst_datas[@intFromEnum(inst)].ty_pl;
            const aggregate_ty = ty_pl.ty.toType();
            const len = @as(usize, @intCast(aggregate_ty.arrayLenIp(ip)));
            const elements = @as([]const Air.Inst.Ref, @ptrCast(a.air.extra[ty_pl.payload..][0..len]));

            if (elements.len <= bpi - 1) {
                var buf = [1]Air.Inst.Ref{.none} ** (bpi - 1);
                @memcpy(buf[0..elements.len], elements);
                return analyzeOperands(a, pass, data, inst, buf);
            }

            var big = try AnalyzeBigOperands(pass).init(a, data, inst, elements.len);
            defer big.deinit();
            var i: usize = elements.len;
            while (i > 0) {
                i -= 1;
                try big.feed(elements[i]);
            }
            return big.finish();
        },
        .union_init => {
            const extra = a.air.extraData(Air.UnionInit, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.init, .none, .none });
        },
        .struct_field_ptr, .struct_field_val => {
            const extra = a.air.extraData(Air.StructField, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.struct_operand, .none, .none });
        },
        .field_parent_ptr => {
            const extra = a.air.extraData(Air.FieldParentPtr, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.field_ptr, .none, .none });
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            const extra = a.air.extraData(Air.Cmpxchg, inst_datas[@intFromEnum(inst)].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.ptr, extra.expected_value, extra.new_value });
        },
        .mul_add => {
            const pl_op = inst_datas[@intFromEnum(inst)].pl_op;
            const extra = a.air.extraData(Air.Bin, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, pl_op.operand });
        },
        .atomic_load => {
            const ptr = inst_datas[@intFromEnum(inst)].atomic_load.ptr;
            return analyzeOperands(a, pass, data, inst, .{ ptr, .none, .none });
        },
        .atomic_rmw => {
            const pl_op = inst_datas[@intFromEnum(inst)].pl_op;
            const extra = a.air.extraData(Air.AtomicRmw, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ pl_op.operand, extra.operand, .none });
        },

        .br => return analyzeInstBr(a, pass, data, inst),
        .repeat => return analyzeInstRepeat(a, pass, data, inst),
        .switch_dispatch => return analyzeInstSwitchDispatch(a, pass, data, inst),

        .assembly => {
            const extra = a.air.extraData(Air.Asm, inst_datas[@intFromEnum(inst)].ty_pl.payload);
            var extra_i: usize = extra.end;
            const outputs = @as([]const Air.Inst.Ref, @ptrCast(a.air.extra[extra_i..][0..extra.data.outputs_len]));
            extra_i += outputs.len;
            const inputs = @as([]const Air.Inst.Ref, @ptrCast(a.air.extra[extra_i..][0..extra.data.inputs_len]));
            extra_i += inputs.len;

            const num_operands = simple: {
                var buf = [1]Air.Inst.Ref{.none} ** (bpi - 1);
                var buf_index: usize = 0;
                for (outputs) |output| {
                    if (output != .none) {
                        if (buf_index < buf.len) buf[buf_index] = output;
                        buf_index += 1;
                    }
                }
                if (buf_index + inputs.len > buf.len) {
                    break :simple buf_index + inputs.len;
                }
                @memcpy(buf[buf_index..][0..inputs.len], inputs);
                return analyzeOperands(a, pass, data, inst, buf);
            };

            var big = try AnalyzeBigOperands(pass).init(a, data, inst, num_operands);
            defer big.deinit();
            var i: usize = inputs.len;
            while (i > 0) {
                i -= 1;
                try big.feed(inputs[i]);
            }
            i = outputs.len;
            while (i > 0) {
                i -= 1;
                if (outputs[i] != .none) {
                    try big.feed(outputs[i]);
                }
            }
            return big.finish();
        },

        inline .block, .dbg_inline_block => |comptime_tag| {
            const ty_pl = inst_datas[@intFromEnum(inst)].ty_pl;
            const extra = a.air.extraData(switch (comptime_tag) {
                .block => Air.Block,
                .dbg_inline_block => Air.DbgInlineBlock,
                else => unreachable,
            }, ty_pl.payload);
            return analyzeInstBlock(a, pass, data, inst, ty_pl.ty, @ptrCast(a.air.extra[extra.end..][0..extra.data.body_len]));
        },
        .loop => return analyzeInstLoop(a, pass, data, inst),

        .@"try", .try_cold => return analyzeInstCondBr(a, pass, data, inst, .@"try"),
        .try_ptr, .try_ptr_cold => return analyzeInstCondBr(a, pass, data, inst, .try_ptr),
        .cond_br => return analyzeInstCondBr(a, pass, data, inst, .cond_br),
        .switch_br => return analyzeInstSwitchBr(a, pass, data, inst, false),
        .loop_switch_br => return analyzeInstSwitchBr(a, pass, data, inst, true),

        .wasm_memory_grow => {
            const pl_op = inst_datas[@intFromEnum(inst)].pl_op;
            return analyzeOperands(a, pass, data, inst, .{ pl_op.operand, .none, .none });
        },
    }
}

/// Every instruction should hit this (after handling any nested bodies), in every pass. In the
/// initial pass, it is responsible for marking deaths of the (first three) operands and noticing
/// immediate deaths.
fn analyzeOperands(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
    operands: [bpi - 1]Air.Inst.Ref,
) Allocator.Error!void {
    const gpa = a.gpa;
    const ip = a.intern_pool;

    switch (pass) {
        .loop_analysis => {
            _ = data.live_set.remove(inst);

            for (operands) |op_ref| {
                const operand = op_ref.toIndexAllowNone() orelse continue;
                _ = try data.live_set.put(gpa, operand, {});
            }
        },

        .main_analysis => {
            const usize_index = (@intFromEnum(inst) * bpi) / @bitSizeOf(usize);

            // This logic must synchronize with `will_die_immediately` in `AnalyzeBigOperands.init`.
            const immediate_death = if (data.live_set.remove(inst)) blk: {
                log.debug("[{}] %{}: removed from live set", .{ pass, @intFromEnum(inst) });
                break :blk false;
            } else blk: {
                log.debug("[{}] %{}: immediate death", .{ pass, @intFromEnum(inst) });
                break :blk true;
            };

            var tomb_bits: Bpi = @as(Bpi, @intFromBool(immediate_death)) << (bpi - 1);

            // If our result is unused and the instruction doesn't need to be lowered, backends will
            // skip the lowering of this instruction, so we don't want to record uses of operands.
            // That way, we can mark as many instructions as possible unused.
            if (!immediate_death or a.air.mustLower(inst, ip)) {
                // Note that it's important we iterate over the operands backwards, so that if a dying
                // operand is used multiple times we mark its last use as its death.
                var i = operands.len;
                while (i > 0) {
                    i -= 1;
                    const op_ref = operands[i];
                    const operand = op_ref.toIndexAllowNone() orelse continue;

                    const mask = @as(Bpi, 1) << @as(OperandInt, @intCast(i));

                    if ((try data.live_set.fetchPut(gpa, operand, {})) == null) {
                        log.debug("[{}] %{}: added %{} to live set (operand dies here)", .{ pass, @intFromEnum(inst), operand });
                        tomb_bits |= mask;
                    }
                }
            }

            a.tomb_bits[usize_index] |= @as(usize, tomb_bits) <<
                @as(Log2Int(usize), @intCast((@intFromEnum(inst) % (@bitSizeOf(usize) / bpi)) * bpi));
        },
    }
}

/// Like `analyzeOperands`, but for an instruction which returns from a function, so should
/// effectively kill every remaining live value other than its operands.
fn analyzeFuncEnd(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
    operands: [bpi - 1]Air.Inst.Ref,
) Allocator.Error!void {
    switch (pass) {
        .loop_analysis => {
            // No operands need to be alive if we're returning from the function, so we don't need
            // to touch `breaks` here even though this is sort of like a break to the top level.
        },

        .main_analysis => {
            data.live_set.clearRetainingCapacity();
        },
    }

    return analyzeOperands(a, pass, data, inst, operands);
}

fn analyzeInstBr(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const br = inst_datas[@intFromEnum(inst)].br;
    const gpa = a.gpa;

    switch (pass) {
        .loop_analysis => {
            try data.breaks.put(gpa, br.block_inst, {});
        },

        .main_analysis => {
            const block_scope = data.block_scopes.get(br.block_inst).?; // we should always be breaking from an enclosing block

            const new_live_set = try block_scope.live_set.clone(gpa);
            data.live_set.deinit(gpa);
            data.live_set = new_live_set;
        },
    }

    return analyzeOperands(a, pass, data, inst, .{ br.operand, .none, .none });
}

fn analyzeInstRepeat(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const repeat = inst_datas[@intFromEnum(inst)].repeat;
    const gpa = a.gpa;

    switch (pass) {
        .loop_analysis => {
            try data.breaks.put(gpa, repeat.loop_inst, {});
        },

        .main_analysis => {
            const block_scope = data.block_scopes.get(repeat.loop_inst).?; // we should always be repeating an enclosing loop

            const new_live_set = try block_scope.live_set.clone(gpa);
            data.live_set.deinit(gpa);
            data.live_set = new_live_set;
        },
    }

    return analyzeOperands(a, pass, data, inst, .{ .none, .none, .none });
}

fn analyzeInstSwitchDispatch(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) !void {
    // This happens to be identical to `analyzeInstBr`, but is separated anyway for clarity.

    const inst_datas = a.air.instructions.items(.data);
    const br = inst_datas[@intFromEnum(inst)].br;
    const gpa = a.gpa;

    switch (pass) {
        .loop_analysis => {
            try data.breaks.put(gpa, br.block_inst, {});
        },

        .main_analysis => {
            const block_scope = data.block_scopes.get(br.block_inst).?; // we should always be repeating an enclosing loop

            const new_live_set = try block_scope.live_set.clone(gpa);
            data.live_set.deinit(gpa);
            data.live_set = new_live_set;
        },
    }

    return analyzeOperands(a, pass, data, inst, .{ br.operand, .none, .none });
}

fn analyzeInstBlock(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
    ty: Air.Inst.Ref,
    body: []const Air.Inst.Index,
) !void {
    const gpa = a.gpa;

    // We actually want to do `analyzeOperands` *first*, since our result logically doesn't
    // exist until the block body ends (and we're iterating backwards)
    try analyzeOperands(a, pass, data, inst, .{ .none, .none, .none });

    switch (pass) {
        .loop_analysis => {
            try analyzeBody(a, pass, data, body);
            _ = data.breaks.remove(inst);
        },

        .main_analysis => {
            log.debug("[{}] %{}: block live set is {}", .{ pass, inst, fmtInstSet(&data.live_set) });
            // We can move the live set because the body should have a noreturn
            // instruction which overrides the set.
            try data.block_scopes.put(gpa, inst, .{
                .live_set = data.live_set.move(),
            });
            defer {
                log.debug("[{}] %{}: popped block scope", .{ pass, inst });
                var scope = data.block_scopes.fetchRemove(inst).?.value;
                scope.live_set.deinit(gpa);
            }

            log.debug("[{}] %{}: pushed new block scope", .{ pass, inst });
            try analyzeBody(a, pass, data, body);

            // If the block is noreturn, block deaths not only aren't useful, they're impossible to
            // find: there could be more stuff alive after the block than before it!
            if (!a.intern_pool.isNoReturn(ty.toType().toIntern())) {
                // The block kills the difference in the live sets
                const block_scope = data.block_scopes.get(inst).?;
                const num_deaths = data.live_set.count() - block_scope.live_set.count();

                try a.extra.ensureUnusedCapacity(gpa, num_deaths + std.meta.fields(Block).len);
                const extra_index = a.addExtraAssumeCapacity(Block{
                    .death_count = num_deaths,
                });

                var measured_num: u32 = 0;
                var it = data.live_set.keyIterator();
                while (it.next()) |key| {
                    const alive = key.*;
                    if (!block_scope.live_set.contains(alive)) {
                        // Dies in block
                        a.extra.appendAssumeCapacity(@intFromEnum(alive));
                        measured_num += 1;
                    }
                }
                assert(measured_num == num_deaths); // post-live-set should be a subset of pre-live-set
                try a.special.put(gpa, inst, extra_index);
                log.debug("[{}] %{}: block deaths are {}", .{
                    pass,
                    inst,
                    fmtInstList(@ptrCast(a.extra.items[extra_index + 1 ..][0..num_deaths])),
                });
            }
        },
    }
}

fn writeLoopInfo(
    a: *Analysis,
    data: *LivenessPassData(.loop_analysis),
    inst: Air.Inst.Index,
    old_breaks: std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    old_live: std.AutoHashMapUnmanaged(Air.Inst.Index, void),
) !void {
    const gpa = a.gpa;

    // `loop`s are guaranteed to have at least one matching `repeat`.
    // Similarly, `loop_switch_br`s have a matching `switch_dispatch`.
    // However, we no longer care about repeats of this loop for resolving
    // which operands must live within it.
    assert(data.breaks.remove(inst));

    const extra_index: u32 = @intCast(a.extra.items.len);

    const num_breaks = data.breaks.count();
    try a.extra.ensureUnusedCapacity(gpa, 1 + num_breaks);

    a.extra.appendAssumeCapacity(num_breaks);

    var it = data.breaks.keyIterator();
    while (it.next()) |key| {
        const block_inst = key.*;
        a.extra.appendAssumeCapacity(@intFromEnum(block_inst));
    }
    log.debug("[{}] %{}: includes breaks to {}", .{ LivenessPass.loop_analysis, inst, fmtInstSet(&data.breaks) });

    // Now we put the live operands from the loop body in too
    const num_live = data.live_set.count();
    try a.extra.ensureUnusedCapacity(gpa, 1 + num_live);

    a.extra.appendAssumeCapacity(num_live);
    it = data.live_set.keyIterator();
    while (it.next()) |key| {
        const alive = key.*;
        a.extra.appendAssumeCapacity(@intFromEnum(alive));
    }
    log.debug("[{}] %{}: maintain liveness of {}", .{ LivenessPass.loop_analysis, inst, fmtInstSet(&data.live_set) });

    try a.special.put(gpa, inst, extra_index);

    // Add back operands which were previously alive
    it = old_live.keyIterator();
    while (it.next()) |key| {
        const alive = key.*;
        try data.live_set.put(gpa, alive, {});
    }

    // And the same for breaks
    it = old_breaks.keyIterator();
    while (it.next()) |key| {
        const block_inst = key.*;
        try data.breaks.put(gpa, block_inst, {});
    }
}

/// When analyzing a loop in the main pass, sets up `data.live_set` to be the set
/// of operands known to be alive when the loop repeats.
fn resolveLoopLiveSet(
    a: *Analysis,
    data: *LivenessPassData(.main_analysis),
    inst: Air.Inst.Index,
) !void {
    const gpa = a.gpa;

    const extra_idx = a.special.fetchRemove(inst).?.value;
    const num_breaks = data.old_extra.items[extra_idx];
    const breaks: []const Air.Inst.Index = @ptrCast(data.old_extra.items[extra_idx + 1 ..][0..num_breaks]);

    const num_loop_live = data.old_extra.items[extra_idx + num_breaks + 1];
    const loop_live: []const Air.Inst.Index = @ptrCast(data.old_extra.items[extra_idx + num_breaks + 2 ..][0..num_loop_live]);

    // This is necessarily not in the same control flow branch, because loops are noreturn
    data.live_set.clearRetainingCapacity();

    try data.live_set.ensureUnusedCapacity(gpa, @intCast(loop_live.len));
    for (loop_live) |alive| data.live_set.putAssumeCapacity(alive, {});

    log.debug("[{}] %{}: block live set is {}", .{ LivenessPass.main_analysis, inst, fmtInstSet(&data.live_set) });

    for (breaks) |block_inst| {
        // We might break to this block, so include every operand that the block needs alive
        const block_scope = data.block_scopes.get(block_inst).?;

        var it = block_scope.live_set.keyIterator();
        while (it.next()) |key| {
            const alive = key.*;
            try data.live_set.put(gpa, alive, {});
        }
    }

    log.debug("[{}] %{}: loop live set is {}", .{ LivenessPass.main_analysis, inst, fmtInstSet(&data.live_set) });
}

fn analyzeInstLoop(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const extra = a.air.extraData(Air.Block, inst_datas[@intFromEnum(inst)].ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(a.air.extra[extra.end..][0..extra.data.body_len]);
    const gpa = a.gpa;

    try analyzeOperands(a, pass, data, inst, .{ .none, .none, .none });

    switch (pass) {
        .loop_analysis => {
            var old_breaks = data.breaks.move();
            defer old_breaks.deinit(gpa);

            var old_live = data.live_set.move();
            defer old_live.deinit(gpa);

            try analyzeBody(a, pass, data, body);

            try writeLoopInfo(a, data, inst, old_breaks, old_live);
        },

        .main_analysis => {
            try resolveLoopLiveSet(a, data, inst);

            // Now, `data.live_set` is the operands which must be alive when the loop repeats.
            // Move them into a block scope for corresponding `repeat` instructions to notice.
            try data.block_scopes.putNoClobber(gpa, inst, .{
                .live_set = data.live_set.move(),
            });
            defer {
                log.debug("[{}] %{}: popped loop block scop", .{ pass, inst });
                var scope = data.block_scopes.fetchRemove(inst).?.value;
                scope.live_set.deinit(gpa);
            }
            try analyzeBody(a, pass, data, body);
        },
    }
}

/// Despite its name, this function is used for analysis of not only `cond_br` instructions, but
/// also `try` and `try_ptr`, which are highly related. The `inst_type` parameter indicates which
/// type of instruction `inst` points to.
fn analyzeInstCondBr(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
    comptime inst_type: enum { cond_br, @"try", try_ptr },
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const gpa = a.gpa;

    const extra = switch (inst_type) {
        .cond_br => a.air.extraData(Air.CondBr, inst_datas[@intFromEnum(inst)].pl_op.payload),
        .@"try" => a.air.extraData(Air.Try, inst_datas[@intFromEnum(inst)].pl_op.payload),
        .try_ptr => a.air.extraData(Air.TryPtr, inst_datas[@intFromEnum(inst)].ty_pl.payload),
    };

    const condition = switch (inst_type) {
        .cond_br, .@"try" => inst_datas[@intFromEnum(inst)].pl_op.operand,
        .try_ptr => extra.data.ptr,
    };

    const then_body: []const Air.Inst.Index = switch (inst_type) {
        .cond_br => @ptrCast(a.air.extra[extra.end..][0..extra.data.then_body_len]),
        else => &.{}, // we won't use this
    };

    const else_body: []const Air.Inst.Index = @ptrCast(switch (inst_type) {
        .cond_br => a.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len],
        .@"try", .try_ptr => a.air.extra[extra.end..][0..extra.data.body_len],
    });

    switch (pass) {
        .loop_analysis => {
            switch (inst_type) {
                .cond_br => try analyzeBody(a, pass, data, then_body),
                .@"try", .try_ptr => {},
            }
            try analyzeBody(a, pass, data, else_body);
        },

        .main_analysis => {
            switch (inst_type) {
                .cond_br => try analyzeBody(a, pass, data, then_body),
                .@"try", .try_ptr => {}, // The "then body" is just the remainder of this block
            }
            var then_live = data.live_set.move();
            defer then_live.deinit(gpa);

            try analyzeBody(a, pass, data, else_body);
            var else_live = data.live_set.move();
            defer else_live.deinit(gpa);

            // Operands which are alive in one branch but not the other need to die at the start of
            // the peer branch.

            var then_mirrored_deaths: std.ArrayListUnmanaged(Air.Inst.Index) = .empty;
            defer then_mirrored_deaths.deinit(gpa);

            var else_mirrored_deaths: std.ArrayListUnmanaged(Air.Inst.Index) = .empty;
            defer else_mirrored_deaths.deinit(gpa);

            // Note: this invalidates `else_live`, but expands `then_live` to be their union
            {
                var it = then_live.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    if (else_live.remove(death)) continue; // removing makes the loop below faster

                    // If this is a `try`, the "then body" (rest of the branch) might have
                    // referenced our result. We want to avoid killing this value in the else branch
                    // if that's the case, since it only exists in the (fake) then branch.
                    switch (inst_type) {
                        .cond_br => {},
                        .@"try", .try_ptr => if (death == inst) continue,
                    }

                    try else_mirrored_deaths.append(gpa, death);
                }
                // Since we removed common stuff above, `else_live` is now only operands
                // which are *only* alive in the else branch
                it = else_live.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    try then_mirrored_deaths.append(gpa, death);
                    // Make `then_live` contain the full live set (i.e. union of both)
                    try then_live.put(gpa, death, {});
                }
            }

            log.debug("[{}] %{}: 'then' branch mirrored deaths are {}", .{ pass, inst, fmtInstList(then_mirrored_deaths.items) });
            log.debug("[{}] %{}: 'else' branch mirrored deaths are {}", .{ pass, inst, fmtInstList(else_mirrored_deaths.items) });

            data.live_set.deinit(gpa);
            data.live_set = then_live.move(); // Really the union of both live sets

            log.debug("[{}] %{}: new live set is {}", .{ pass, inst, fmtInstSet(&data.live_set) });

            // Write the mirrored deaths to `extra`
            const then_death_count = @as(u32, @intCast(then_mirrored_deaths.items.len));
            const else_death_count = @as(u32, @intCast(else_mirrored_deaths.items.len));
            try a.extra.ensureUnusedCapacity(gpa, std.meta.fields(CondBr).len + then_death_count + else_death_count);
            const extra_index = a.addExtraAssumeCapacity(CondBr{
                .then_death_count = then_death_count,
                .else_death_count = else_death_count,
            });
            a.extra.appendSliceAssumeCapacity(@ptrCast(then_mirrored_deaths.items));
            a.extra.appendSliceAssumeCapacity(@ptrCast(else_mirrored_deaths.items));
            try a.special.put(gpa, inst, extra_index);
        },
    }

    try analyzeOperands(a, pass, data, inst, .{ condition, .none, .none });
}

fn analyzeInstSwitchBr(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
    is_dispatch_loop: bool,
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const pl_op = inst_datas[@intFromEnum(inst)].pl_op;
    const condition = pl_op.operand;
    const switch_br = a.air.unwrapSwitch(inst);
    const gpa = a.gpa;
    const ncases = switch_br.cases_len;

    switch (pass) {
        .loop_analysis => {
            var old_breaks: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .empty;
            defer old_breaks.deinit(gpa);

            var old_live: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .empty;
            defer old_live.deinit(gpa);

            if (is_dispatch_loop) {
                old_breaks = data.breaks.move();
                old_live = data.live_set.move();
            }

            var it = switch_br.iterateCases();
            while (it.next()) |case| {
                try analyzeBody(a, pass, data, case.body);
            }
            { // else
                const else_body = it.elseBody();
                try analyzeBody(a, pass, data, else_body);
            }

            if (is_dispatch_loop) {
                try writeLoopInfo(a, data, inst, old_breaks, old_live);
            }
        },

        .main_analysis => {
            if (is_dispatch_loop) {
                try resolveLoopLiveSet(a, data, inst);
                try data.block_scopes.putNoClobber(gpa, inst, .{
                    .live_set = data.live_set.move(),
                });
            }
            defer if (is_dispatch_loop) {
                log.debug("[{}] %{}: popped loop block scop", .{ pass, inst });
                var scope = data.block_scopes.fetchRemove(inst).?.value;
                scope.live_set.deinit(gpa);
            };
            // This is, all in all, just a messier version of the `cond_br` logic. If you're trying
            // to understand it, I encourage looking at `analyzeInstCondBr` first.

            const DeathSet = std.AutoHashMapUnmanaged(Air.Inst.Index, void);
            const DeathList = std.ArrayListUnmanaged(Air.Inst.Index);

            var case_live_sets = try gpa.alloc(std.AutoHashMapUnmanaged(Air.Inst.Index, void), ncases + 1); // +1 for else
            defer gpa.free(case_live_sets);

            @memset(case_live_sets, .{});
            defer for (case_live_sets) |*live_set| live_set.deinit(gpa);

            var case_it = switch_br.iterateCases();
            while (case_it.next()) |case| {
                try analyzeBody(a, pass, data, case.body);
                case_live_sets[case.idx] = data.live_set.move();
            }
            { // else
                const else_body = case_it.elseBody();
                try analyzeBody(a, pass, data, else_body);
                case_live_sets[ncases] = data.live_set.move();
            }

            const mirrored_deaths = try gpa.alloc(DeathList, ncases + 1);
            defer gpa.free(mirrored_deaths);

            @memset(mirrored_deaths, .{});
            defer for (mirrored_deaths) |*md| md.deinit(gpa);

            {
                var all_alive: DeathSet = .{};
                defer all_alive.deinit(gpa);

                for (case_live_sets) |*live_set| {
                    try all_alive.ensureUnusedCapacity(gpa, live_set.count());
                    var it = live_set.keyIterator();
                    while (it.next()) |key| {
                        const alive = key.*;
                        all_alive.putAssumeCapacity(alive, {});
                    }
                }

                for (mirrored_deaths, case_live_sets) |*mirrored, *live_set| {
                    var it = all_alive.keyIterator();
                    while (it.next()) |key| {
                        const alive = key.*;
                        if (!live_set.contains(alive)) {
                            // Should die at the start of this branch
                            try mirrored.append(gpa, alive);
                        }
                    }
                }

                for (mirrored_deaths, 0..) |mirrored, i| {
                    log.debug("[{}] %{}: case {} mirrored deaths are {}", .{ pass, inst, i, fmtInstList(mirrored.items) });
                }

                data.live_set.deinit(gpa);
                data.live_set = all_alive.move();

                log.debug("[{}] %{}: new live set is {}", .{ pass, inst, fmtInstSet(&data.live_set) });
            }

            const else_death_count = @as(u32, @intCast(mirrored_deaths[ncases].items.len));
            const extra_index = try a.addExtra(SwitchBr{
                .else_death_count = else_death_count,
            });
            for (mirrored_deaths[0..ncases]) |mirrored| {
                const num = @as(u32, @intCast(mirrored.items.len));
                try a.extra.ensureUnusedCapacity(gpa, num + 1);
                a.extra.appendAssumeCapacity(num);
                a.extra.appendSliceAssumeCapacity(@ptrCast(mirrored.items));
            }
            try a.extra.ensureUnusedCapacity(gpa, else_death_count);
            a.extra.appendSliceAssumeCapacity(@ptrCast(mirrored_deaths[ncases].items));
            try a.special.put(gpa, inst, extra_index);
        },
    }

    try analyzeOperands(a, pass, data, inst, .{ condition, .none, .none });
}

fn AnalyzeBigOperands(comptime pass: LivenessPass) type {
    return struct {
        a: *Analysis,
        data: *LivenessPassData(pass),
        inst: Air.Inst.Index,

        operands_remaining: u32,
        small: [bpi - 1]Air.Inst.Ref = .{.none} ** (bpi - 1),
        extra_tombs: []u32,

        // Only used in `LivenessPass.main_analysis`
        will_die_immediately: bool,

        const Self = @This();

        fn init(
            a: *Analysis,
            data: *LivenessPassData(pass),
            inst: Air.Inst.Index,
            total_operands: usize,
        ) !Self {
            const extra_operands = @as(u32, @intCast(total_operands)) -| (bpi - 1);
            const max_extra_tombs = (extra_operands + 30) / 31;

            const extra_tombs: []u32 = switch (pass) {
                .loop_analysis => &.{},
                .main_analysis => try a.gpa.alloc(u32, max_extra_tombs),
            };
            errdefer a.gpa.free(extra_tombs);

            @memset(extra_tombs, 0);

            const will_die_immediately: bool = switch (pass) {
                .loop_analysis => false, // track everything, since we don't have full liveness information yet
                .main_analysis => !data.live_set.contains(inst),
            };

            return .{
                .a = a,
                .data = data,
                .inst = inst,
                .operands_remaining = @as(u32, @intCast(total_operands)),
                .extra_tombs = extra_tombs,
                .will_die_immediately = will_die_immediately,
            };
        }

        /// Must be called with operands in reverse order.
        fn feed(big: *Self, op_ref: Air.Inst.Ref) !void {
            const ip = big.a.intern_pool;
            // Note that after this, `operands_remaining` becomes the index of the current operand
            big.operands_remaining -= 1;

            if (big.operands_remaining < bpi - 1) {
                big.small[big.operands_remaining] = op_ref;
                return;
            }

            const operand = op_ref.toIndex() orelse return;

            // If our result is unused and the instruction doesn't need to be lowered, backends will
            // skip the lowering of this instruction, so we don't want to record uses of operands.
            // That way, we can mark as many instructions as possible unused.
            if (big.will_die_immediately and !big.a.air.mustLower(big.inst, ip)) return;

            const extra_byte = (big.operands_remaining - (bpi - 1)) / 31;
            const extra_bit = @as(u5, @intCast(big.operands_remaining - (bpi - 1) - extra_byte * 31));

            const gpa = big.a.gpa;

            switch (pass) {
                .loop_analysis => {
                    _ = try big.data.live_set.put(gpa, operand, {});
                },

                .main_analysis => {
                    if ((try big.data.live_set.fetchPut(gpa, operand, {})) == null) {
                        log.debug("[{}] %{}: added %{} to live set (operand dies here)", .{ pass, big.inst, operand });
                        big.extra_tombs[extra_byte] |= @as(u32, 1) << extra_bit;
                    }
                },
            }
        }

        fn finish(big: *Self) !void {
            const gpa = big.a.gpa;

            std.debug.assert(big.operands_remaining == 0);

            switch (pass) {
                .loop_analysis => {},

                .main_analysis => {
                    // Note that the MSB is set on the final tomb to indicate the terminal element. This
                    // allows for an optimisation where we only add as many extra tombs as are needed to
                    // represent the dying operands. Each pass modifies operand bits and so needs to write
                    // back, so let's figure out how many extra tombs we really need. Note that we always
                    // keep at least one.
                    var num: usize = big.extra_tombs.len;
                    while (num > 1) {
                        if (@as(u31, @truncate(big.extra_tombs[num - 1])) != 0) {
                            // Some operand dies here
                            break;
                        }
                        num -= 1;
                    }
                    // Mark final tomb
                    big.extra_tombs[num - 1] |= @as(u32, 1) << 31;

                    const extra_tombs = big.extra_tombs[0..num];

                    const extra_index = @as(u32, @intCast(big.a.extra.items.len));
                    try big.a.extra.appendSlice(gpa, extra_tombs);
                    try big.a.special.put(gpa, big.inst, extra_index);
                },
            }

            try analyzeOperands(big.a, pass, big.data, big.inst, big.small);
        }

        fn deinit(big: *Self) void {
            big.a.gpa.free(big.extra_tombs);
        }
    };
}

fn fmtInstSet(set: *const std.AutoHashMapUnmanaged(Air.Inst.Index, void)) FmtInstSet {
    return .{ .set = set };
}

const FmtInstSet = struct {
    set: *const std.AutoHashMapUnmanaged(Air.Inst.Index, void),

    pub fn format(val: FmtInstSet, comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
        if (val.set.count() == 0) {
            try w.writeAll("[no instructions]");
            return;
        }
        var it = val.set.keyIterator();
        try w.print("%{}", .{it.next().?.*});
        while (it.next()) |key| {
            try w.print(" %{}", .{key.*});
        }
    }
};

fn fmtInstList(list: []const Air.Inst.Index) FmtInstList {
    return .{ .list = list };
}

const FmtInstList = struct {
    list: []const Air.Inst.Index,

    pub fn format(val: FmtInstList, comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
        if (val.list.len == 0) {
            try w.writeAll("[no instructions]");
            return;
        }
        try w.print("%{}", .{val.list[0]});
        for (val.list[1..]) |inst| {
            try w.print(" %{}", .{inst});
        }
    }
};
