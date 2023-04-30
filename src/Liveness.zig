//! For each AIR instruction, we want to know:
//! * Is the instruction unreferenced (e.g. dies immediately)?
//! * For each of its operands, does the operand die with this instruction (e.g. is
//!   this the last reference to it)?
//! Some instructions are special, such as:
//! * Conditional Branches
//! * Switch Branches
const Liveness = @This();
const std = @import("std");
const trace = @import("tracy.zig").trace;
const log = std.log.scoped(.liveness);
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Air = @import("Air.zig");
const Log2Int = std.math.Log2Int;

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
    /// In this pass, we perform some basic analysis of loops to gain information the main pass
    /// needs. In particular, for every `loop`, we track the following information:
    /// * Every block which the loop body contains a `br` to.
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
            /// body and which we are currently within.
            breaks: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},

            /// The set of operands for which we have seen at least one usage but not their birth.
            live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},

            fn deinit(self: *@This(), gpa: Allocator) void {
                self.breaks.deinit(gpa);
                self.live_set.deinit(gpa);
            }
        },

        .main_analysis => struct {
            /// Every `block` currently under analysis.
            block_scopes: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockScope) = .{},

            /// The set of deaths which should be made to occur at the earliest possible point in
            /// this control flow branch. These instructions die when they are last referenced in
            /// the current branch; if unreferenced, they die at the start of the branch. Populated
            /// when a `br` instruction is reached. If deaths are common to all branches of control
            /// flow, they may be bubbled up to the parent branch.
            branch_deaths: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},

            /// The set of instructions currently alive. Instructions which must die in this branch
            /// (i.e. those in `branch_deaths`) are not in this set, because they must die before
            /// this point.
            live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},

            /// The extra data initialized by the `loop_analysis` pass for this pass to consume.
            /// Owned by this struct during this pass.
            old_extra: std.ArrayListUnmanaged(u32) = .{},

            const BlockScope = struct {
                /// The set of instructions which are alive upon a `br` to this block.
                live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void),
            };

            fn deinit(self: *@This(), gpa: Allocator) void {
                var it = self.block_scopes.valueIterator();
                while (it.next()) |block| {
                    block.live_set.deinit(gpa);
                }
                self.block_scopes.deinit(gpa);
                self.branch_deaths.deinit(gpa);
                self.live_set.deinit(gpa);
                self.old_extra.deinit(gpa);
            }
        },
    };
}

pub fn analyze(gpa: Allocator, air: Air) Allocator.Error!Liveness {
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
        assert(data.branch_deaths.count() == 0);
    }

    return .{
        .tomb_bits = a.tomb_bits,
        .special = a.special,
        .extra = try a.extra.toOwnedSlice(gpa),
    };
}

pub fn getTombBits(l: Liveness, inst: Air.Inst.Index) Bpi {
    const usize_index = (inst * bpi) / @bitSizeOf(usize);
    return @truncate(Bpi, l.tomb_bits[usize_index] >>
        @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi));
}

pub fn isUnused(l: Liveness, inst: Air.Inst.Index) bool {
    const usize_index = (inst * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi + (bpi - 1));
    return (l.tomb_bits[usize_index] & mask) != 0;
}

pub fn operandDies(l: Liveness, inst: Air.Inst.Index, operand: OperandInt) bool {
    assert(operand < bpi - 1);
    const usize_index = (inst * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi + operand);
    return (l.tomb_bits[usize_index] & mask) != 0;
}

pub fn clearOperandDeath(l: Liveness, inst: Air.Inst.Index, operand: OperandInt) void {
    assert(operand < bpi - 1);
    const usize_index = (inst * bpi) / @bitSizeOf(usize);
    const mask = @as(usize, 1) <<
        @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi + operand);
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
) OperandCategory {
    const air_tags = air.instructions.items(.tag);
    const air_datas = air.instructions.items(.data);
    const operand_ref = Air.indexToRef(operand);
    switch (air_tags[inst]) {
        .add,
        .addwrap,
        .add_sat,
        .sub,
        .subwrap,
        .sub_sat,
        .mul,
        .mulwrap,
        .mul_sat,
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
        .add_optimized,
        .addwrap_optimized,
        .sub_optimized,
        .subwrap_optimized,
        .mul_optimized,
        .mulwrap_optimized,
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
            const o = air_datas[inst].bin_op;
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
            const o = air_datas[inst].bin_op;
            if (o.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (o.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            return .write;
        },

        .vector_store_elem => {
            const o = air_datas[inst].vector_store_elem;
            const extra = air.extraData(Air.Bin, o.payload).data;
            if (o.vector_ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .write;
        },

        .arg,
        .alloc,
        .ret_ptr,
        .constant,
        .const_ty,
        .trap,
        .breakpoint,
        .dbg_stmt,
        .dbg_inline_begin,
        .dbg_inline_end,
        .dbg_block_begin,
        .dbg_block_end,
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

        .fence => return .write,

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
        .float_to_int,
        .float_to_int_optimized,
        .int_to_float,
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
        => {
            const o = air_datas[inst].ty_op;
            if (o.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .optional_payload_ptr_set,
        .errunion_payload_ptr_set,
        => {
            const o = air_datas[inst].ty_op;
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
        .ptrtoint,
        .bool_to_int,
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
        .fabs,
        .floor,
        .ceil,
        .round,
        .trunc_float,
        .neg,
        .cmp_lt_errors_len,
        .c_va_end,
        => {
            const o = air_datas[inst].un_op;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .ret,
        .ret_load,
        => {
            const o = air_datas[inst].un_op;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .noret);
            return .noret;
        },

        .set_err_return_trace => {
            const o = air_datas[inst].un_op;
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
            const ty_pl = air_datas[inst].ty_pl;
            const extra = air.extraData(Air.Bin, ty_pl.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },

        .dbg_var_ptr,
        .dbg_var_val,
        => {
            const o = air_datas[inst].pl_op.operand;
            if (o == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .prefetch => {
            const prefetch = air_datas[inst].prefetch;
            if (prefetch.ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const inst_data = air_datas[inst].pl_op;
            const callee = inst_data.operand;
            const extra = air.extraData(Air.Call, inst_data.payload);
            const args = @ptrCast([]const Air.Inst.Ref, air.extra[extra.end..][0..extra.data.args_len]);
            if (args.len + 1 <= bpi - 1) {
                if (callee == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
                for (args, 0..) |arg, i| {
                    if (arg == operand_ref) return matchOperandSmallIndex(l, inst, @intCast(OperandInt, i + 1), .write);
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
            const pl_op = air_datas[inst].pl_op;
            const extra = air.extraData(Air.Bin, pl_op.payload).data;
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .none;
        },
        .shuffle => {
            const extra = air.extraData(Air.Shuffle, air_datas[inst].ty_pl.payload).data;
            if (extra.a == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.b == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },
        .reduce, .reduce_optimized => {
            const reduce = air_datas[inst].reduce;
            if (reduce.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .cmp_vector, .cmp_vector_optimized => {
            const extra = air.extraData(Air.VectorCmp, air_datas[inst].ty_pl.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            return .none;
        },
        .aggregate_init => {
            const ty_pl = air_datas[inst].ty_pl;
            const aggregate_ty = air.getRefType(ty_pl.ty);
            const len = @intCast(usize, aggregate_ty.arrayLen());
            const elements = @ptrCast([]const Air.Inst.Ref, air.extra[ty_pl.payload..][0..len]);

            if (elements.len <= bpi - 1) {
                for (elements, 0..) |elem, i| {
                    if (elem == operand_ref) return matchOperandSmallIndex(l, inst, @intCast(OperandInt, i), .none);
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
            const extra = air.extraData(Air.UnionInit, air_datas[inst].ty_pl.payload).data;
            if (extra.init == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .struct_field_ptr, .struct_field_val => {
            const extra = air.extraData(Air.StructField, air_datas[inst].ty_pl.payload).data;
            if (extra.struct_operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .field_parent_ptr => {
            const extra = air.extraData(Air.FieldParentPtr, air_datas[inst].ty_pl.payload).data;
            if (extra.field_ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            const extra = air.extraData(Air.Cmpxchg, air_datas[inst].ty_pl.payload).data;
            if (extra.ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.expected_value == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            if (extra.new_value == operand_ref) return matchOperandSmallIndex(l, inst, 2, .write);
            return .write;
        },
        .mul_add => {
            const pl_op = air_datas[inst].pl_op;
            const extra = air.extraData(Air.Bin, pl_op.payload).data;
            if (extra.lhs == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            if (extra.rhs == operand_ref) return matchOperandSmallIndex(l, inst, 1, .none);
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 2, .none);
            return .none;
        },
        .atomic_load => {
            const ptr = air_datas[inst].atomic_load.ptr;
            if (ptr == operand_ref) return matchOperandSmallIndex(l, inst, 0, .none);
            return .none;
        },
        .atomic_rmw => {
            const pl_op = air_datas[inst].pl_op;
            const extra = air.extraData(Air.AtomicRmw, pl_op.payload).data;
            if (pl_op.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .write);
            if (extra.operand == operand_ref) return matchOperandSmallIndex(l, inst, 1, .write);
            return .write;
        },

        .br => {
            const br = air_datas[inst].br;
            if (br.operand == operand_ref) return matchOperandSmallIndex(l, inst, 0, .noret);
            return .noret;
        },
        .assembly => {
            return .complex;
        },
        .block => {
            const extra = air.extraData(Air.Block, air_datas[inst].ty_pl.payload);
            const body = air.extra[extra.end..][0..extra.data.body_len];

            if (body.len == 1 and air_tags[body[0]] == .cond_br) {
                // Peephole optimization for "panic-like" conditionals, which have
                // one empty branch and another which calls a `noreturn` function.
                // This allows us to infer that safety checks do not modify memory,
                // as far as control flow successors are concerned.

                const inst_data = air_datas[body[0]].pl_op;
                const cond_extra = air.extraData(Air.CondBr, inst_data.payload);
                if (inst_data.operand == operand_ref and operandDies(l, body[0], 0))
                    return .tomb;

                if (cond_extra.data.then_body_len != 1 or cond_extra.data.else_body_len != 1)
                    return .complex;

                var operand_live: bool = true;
                for (air.extra[cond_extra.end..][0..2]) |cond_inst| {
                    if (l.categorizeOperand(air, cond_inst, operand) == .tomb)
                        operand_live = false;

                    switch (air_tags[cond_inst]) {
                        .br => { // Breaks immediately back to block
                            const br = air_datas[cond_inst].br;
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
        .@"try" => {
            return .complex;
        },
        .try_ptr => {
            return .complex;
        },
        .loop => {
            return .complex;
        },
        .cond_br => {
            return .complex;
        },
        .switch_br => {
            return .complex;
        },
        .wasm_memory_grow => {
            const pl_op = air_datas[inst].pl_op;
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
    const then_deaths = l.extra[index..][0..then_death_count];
    index += then_death_count;
    return .{
        .then_deaths = then_deaths,
        .else_deaths = l.extra[index..][0..else_death_count],
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
        const case_deaths = l.extra[index..][0..case_death_count];
        index += case_death_count;
        deaths.appendAssumeCapacity(case_deaths);
    }
    {
        // Else
        const else_deaths = l.extra[index..][0..else_death_count];
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
    const deaths = l.extra[index + 1 ..][0..death_count];
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
            const dies = @truncate(u1, bt.tomb_bits >> @intCast(Liveness.OperandInt, this_bit_index)) != 0;
            return dies;
        }

        const big_bit_index = this_bit_index - small_tombs;
        while (big_bit_index - bt.extra_offset * 31 >= 31) {
            if (@truncate(u1, bt.extra[bt.extra_start + bt.extra_offset] >> 31) != 0) {
                bt.reached_end = true;
                return false;
            }
            bt.extra_offset += 1;
        }
        const dies = @truncate(u1, bt.extra[bt.extra_start + bt.extra_offset] >>
            @intCast(u5, big_bit_index - bt.extra_offset * 31)) != 0;
        return dies;
    }
};

/// In-progress data; on successful analysis converted into `Liveness`.
const Analysis = struct {
    gpa: Allocator,
    air: Air,
    tomb_bits: []usize,
    special: std.AutoHashMapUnmanaged(Air.Inst.Index, u32),
    extra: std.ArrayListUnmanaged(u32),

    fn storeTombBits(a: *Analysis, inst: Air.Inst.Index, tomb_bits: Bpi) void {
        const usize_index = (inst * bpi) / @bitSizeOf(usize);
        a.tomb_bits[usize_index] |= @as(usize, tomb_bits) <<
            @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi);
    }

    fn addExtra(a: *Analysis, extra: anytype) Allocator.Error!u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        try a.extra.ensureUnusedCapacity(a.gpa, fields.len);
        return addExtraAssumeCapacity(a, extra);
    }

    fn addExtraAssumeCapacity(a: *Analysis, extra: anytype) u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        const result = @intCast(u32, a.extra.items.len);
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

const ControlBranchInfo = struct {
    branch_deaths: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},
    live_set: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{},
};

/// Helper function for running `analyzeBody`, but resetting `branch_deaths` and `live_set` to their
/// original states before returning, returning the modified versions of them. Only makes sense in
/// the `main_analysis` pass.
fn analyzeBodyResetBranch(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    body: []const Air.Inst.Index,
) !ControlBranchInfo {
    switch (pass) {
        .main_analysis => {},
        else => @compileError("Liveness.analyzeBodyResetBranch only makes sense in LivenessPass.main_analysis"),
    }

    const gpa = a.gpa;

    const old_branch_deaths = try data.branch_deaths.clone(a.gpa);
    defer {
        data.branch_deaths.deinit(gpa);
        data.branch_deaths = old_branch_deaths;
    }

    const old_live_set = try data.live_set.clone(a.gpa);
    defer {
        data.live_set.deinit(gpa);
        data.live_set = old_live_set;
    }

    try analyzeBody(a, pass, data, body);

    return .{
        .branch_deaths = data.branch_deaths.move(),
        .live_set = data.live_set.move(),
    };
}

fn analyzeInst(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) Allocator.Error!void {
    const inst_tags = a.air.instructions.items(.tag);
    const inst_datas = a.air.instructions.items(.data);

    switch (inst_tags[inst]) {
        .add,
        .add_optimized,
        .addwrap,
        .addwrap_optimized,
        .add_sat,
        .sub,
        .sub_optimized,
        .subwrap,
        .subwrap_optimized,
        .sub_sat,
        .mul,
        .mul_optimized,
        .mulwrap,
        .mulwrap_optimized,
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
            const o = inst_datas[inst].bin_op;
            return analyzeOperands(a, pass, data, inst, .{ o.lhs, o.rhs, .none });
        },

        .vector_store_elem => {
            const o = inst_datas[inst].vector_store_elem;
            const extra = a.air.extraData(Air.Bin, o.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ o.vector_ptr, extra.lhs, extra.rhs });
        },

        .arg,
        .alloc,
        .ret_ptr,
        .breakpoint,
        .dbg_stmt,
        .dbg_inline_begin,
        .dbg_inline_end,
        .dbg_block_begin,
        .dbg_block_end,
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
        => return analyzeOperands(a, pass, data, inst, .{ .none, .none, .none }),

        .constant,
        .const_ty,
        => unreachable,

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
        .float_to_int,
        .float_to_int_optimized,
        .int_to_float,
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
        => {
            const o = inst_datas[inst].ty_op;
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
        .ptrtoint,
        .bool_to_int,
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
        .fabs,
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
            const operand = inst_datas[inst].un_op;
            return analyzeOperands(a, pass, data, inst, .{ operand, .none, .none });
        },

        .ret,
        .ret_load,
        => {
            const operand = inst_datas[inst].un_op;
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
            const ty_pl = inst_datas[inst].ty_pl;
            const extra = a.air.extraData(Air.Bin, ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, .none });
        },

        .dbg_var_ptr,
        .dbg_var_val,
        => {
            const operand = inst_datas[inst].pl_op.operand;
            return analyzeOperands(a, pass, data, inst, .{ operand, .none, .none });
        },

        .prefetch => {
            const prefetch = inst_datas[inst].prefetch;
            return analyzeOperands(a, pass, data, inst, .{ prefetch.ptr, .none, .none });
        },

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const inst_data = inst_datas[inst].pl_op;
            const callee = inst_data.operand;
            const extra = a.air.extraData(Air.Call, inst_data.payload);
            const args = @ptrCast([]const Air.Inst.Ref, a.air.extra[extra.end..][0..extra.data.args_len]);
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
            const pl_op = inst_datas[inst].pl_op;
            const extra = a.air.extraData(Air.Bin, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ pl_op.operand, extra.lhs, extra.rhs });
        },
        .shuffle => {
            const extra = a.air.extraData(Air.Shuffle, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.a, extra.b, .none });
        },
        .reduce, .reduce_optimized => {
            const reduce = inst_datas[inst].reduce;
            return analyzeOperands(a, pass, data, inst, .{ reduce.operand, .none, .none });
        },
        .cmp_vector, .cmp_vector_optimized => {
            const extra = a.air.extraData(Air.VectorCmp, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, .none });
        },
        .aggregate_init => {
            const ty_pl = inst_datas[inst].ty_pl;
            const aggregate_ty = a.air.getRefType(ty_pl.ty);
            const len = @intCast(usize, aggregate_ty.arrayLen());
            const elements = @ptrCast([]const Air.Inst.Ref, a.air.extra[ty_pl.payload..][0..len]);

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
            const extra = a.air.extraData(Air.UnionInit, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.init, .none, .none });
        },
        .struct_field_ptr, .struct_field_val => {
            const extra = a.air.extraData(Air.StructField, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.struct_operand, .none, .none });
        },
        .field_parent_ptr => {
            const extra = a.air.extraData(Air.FieldParentPtr, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.field_ptr, .none, .none });
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            const extra = a.air.extraData(Air.Cmpxchg, inst_datas[inst].ty_pl.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.ptr, extra.expected_value, extra.new_value });
        },
        .mul_add => {
            const pl_op = inst_datas[inst].pl_op;
            const extra = a.air.extraData(Air.Bin, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ extra.lhs, extra.rhs, pl_op.operand });
        },
        .atomic_load => {
            const ptr = inst_datas[inst].atomic_load.ptr;
            return analyzeOperands(a, pass, data, inst, .{ ptr, .none, .none });
        },
        .atomic_rmw => {
            const pl_op = inst_datas[inst].pl_op;
            const extra = a.air.extraData(Air.AtomicRmw, pl_op.payload).data;
            return analyzeOperands(a, pass, data, inst, .{ pl_op.operand, extra.operand, .none });
        },

        .br => return analyzeInstBr(a, pass, data, inst),

        .assembly => {
            const extra = a.air.extraData(Air.Asm, inst_datas[inst].ty_pl.payload);
            var extra_i: usize = extra.end;
            const outputs = @ptrCast([]const Air.Inst.Ref, a.air.extra[extra_i..][0..extra.data.outputs_len]);
            extra_i += outputs.len;
            const inputs = @ptrCast([]const Air.Inst.Ref, a.air.extra[extra_i..][0..extra.data.inputs_len]);
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

        .block => return analyzeInstBlock(a, pass, data, inst),
        .loop => return analyzeInstLoop(a, pass, data, inst),

        .@"try" => return analyzeInstCondBr(a, pass, data, inst, .@"try"),
        .try_ptr => return analyzeInstCondBr(a, pass, data, inst, .try_ptr),
        .cond_br => return analyzeInstCondBr(a, pass, data, inst, .cond_br),
        .switch_br => return analyzeInstSwitchBr(a, pass, data, inst),

        .wasm_memory_grow => {
            const pl_op = inst_datas[inst].pl_op;
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
    const inst_tags = a.air.instructions.items(.tag);

    switch (pass) {
        .loop_analysis => {
            _ = data.live_set.remove(inst);

            for (operands) |op_ref| {
                const operand = Air.refToIndex(op_ref) orelse continue;

                // Don't compute any liveness for constants
                switch (inst_tags[operand]) {
                    .constant, .const_ty => continue,
                    else => {},
                }

                _ = try data.live_set.put(gpa, operand, {});
            }
        },

        .main_analysis => {
            const usize_index = (inst * bpi) / @bitSizeOf(usize);

            // This logic must synchronize with `will_die_immediately` in `AnalyzeBigOperands.init`.
            var immediate_death = false;
            if (data.branch_deaths.remove(inst)) {
                log.debug("[{}] %{}: resolved branch death to birth (immediate death)", .{ pass, inst });
                immediate_death = true;
                assert(!data.live_set.contains(inst));
            } else if (data.live_set.remove(inst)) {
                log.debug("[{}] %{}: removed from live set", .{ pass, inst });
            } else {
                log.debug("[{}] %{}: immediate death", .{ pass, inst });
                immediate_death = true;
            }

            var tomb_bits: Bpi = @as(Bpi, @boolToInt(immediate_death)) << (bpi - 1);

            // If our result is unused and the instruction doesn't need to be lowered, backends will
            // skip the lowering of this instruction, so we don't want to record uses of operands.
            // That way, we can mark as many instructions as possible unused.
            if (!immediate_death or a.air.mustLower(inst)) {
                // Note that it's important we iterate over the operands backwards, so that if a dying
                // operand is used multiple times we mark its last use as its death.
                var i = operands.len;
                while (i > 0) {
                    i -= 1;
                    const op_ref = operands[i];
                    const operand = Air.refToIndex(op_ref) orelse continue;

                    // Don't compute any liveness for constants
                    switch (inst_tags[operand]) {
                        .constant, .const_ty => continue,
                        else => {},
                    }

                    const mask = @as(Bpi, 1) << @intCast(OperandInt, i);

                    if ((try data.live_set.fetchPut(gpa, operand, {})) == null) {
                        log.debug("[{}] %{}: added %{} to live set (operand dies here)", .{ pass, inst, operand });
                        tomb_bits |= mask;
                        if (data.branch_deaths.remove(operand)) {
                            log.debug("[{}] %{}: resolved branch death of %{} to this usage", .{ pass, inst, operand });
                        }
                    }
                }
            }

            a.tomb_bits[usize_index] |= @as(usize, tomb_bits) <<
                @intCast(Log2Int(usize), (inst % (@bitSizeOf(usize) / bpi)) * bpi);
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
            const gpa = a.gpa;

            // Note that we preserve previous branch deaths - anything that needs to die in our
            // "parent" branch also needs to die for us.

            try data.branch_deaths.ensureUnusedCapacity(gpa, data.live_set.count());
            var it = data.live_set.keyIterator();
            while (it.next()) |key| {
                const alive = key.*;
                data.branch_deaths.putAssumeCapacity(alive, {});
            }
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
    const br = inst_datas[inst].br;
    const gpa = a.gpa;

    switch (pass) {
        .loop_analysis => {
            try data.breaks.put(gpa, br.block_inst, {});
        },

        .main_analysis => {
            const block_scope = data.block_scopes.get(br.block_inst).?; // we should always be breaking from an enclosing block

            // We mostly preserve previous branch deaths - anything that should die for our
            // enclosing branch should die for us too. However, if our break target requires such an
            // operand to be alive, it's actually not something we want to kill, since its "last
            // use" (i.e. the point at which it should die) is outside of our scope.
            var it = block_scope.live_set.keyIterator();
            while (it.next()) |key| {
                const alive = key.*;
                _ = data.branch_deaths.remove(alive);
            }
            log.debug("[{}] %{}: preserved branch deaths are {}", .{ pass, inst, fmtInstSet(&data.branch_deaths) });

            // Anything that's currently alive but our target doesn't need becomes a branch death.
            it = data.live_set.keyIterator();
            while (it.next()) |key| {
                const alive = key.*;
                if (!block_scope.live_set.contains(alive)) {
                    _ = try data.branch_deaths.put(gpa, alive, {});
                    log.debug("[{}] %{}: added branch death of {}", .{ pass, inst, alive });
                }
            }
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
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const ty_pl = inst_datas[inst].ty_pl;
    const extra = a.air.extraData(Air.Block, ty_pl.payload);
    const body = a.air.extra[extra.end..][0..extra.data.body_len];

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
            try data.block_scopes.put(gpa, inst, .{
                .live_set = try data.live_set.clone(gpa),
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
            if (!a.air.getRefType(ty_pl.ty).isNoReturn()) {
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
                        a.extra.appendAssumeCapacity(alive);
                        measured_num += 1;
                    }
                }
                assert(measured_num == num_deaths); // post-live-set should be a subset of pre-live-set
                try a.special.put(gpa, inst, extra_index);
                log.debug("[{}] %{}: block deaths are {}", .{
                    pass,
                    inst,
                    fmtInstList(a.extra.items[extra_index + 1 ..][0..num_deaths]),
                });
            }
        },
    }
}

fn analyzeInstLoop(
    a: *Analysis,
    comptime pass: LivenessPass,
    data: *LivenessPassData(pass),
    inst: Air.Inst.Index,
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const extra = a.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
    const body = a.air.extra[extra.end..][0..extra.data.body_len];
    const gpa = a.gpa;

    try analyzeOperands(a, pass, data, inst, .{ .none, .none, .none });

    switch (pass) {
        .loop_analysis => {
            var old_breaks = data.breaks.move();
            defer old_breaks.deinit(gpa);

            var old_live = data.live_set.move();
            defer old_live.deinit(gpa);

            try analyzeBody(a, pass, data, body);

            const num_breaks = data.breaks.count();
            try a.extra.ensureUnusedCapacity(gpa, 1 + num_breaks);

            const extra_index = @intCast(u32, a.extra.items.len);
            a.extra.appendAssumeCapacity(num_breaks);

            var it = data.breaks.keyIterator();
            while (it.next()) |key| {
                const block_inst = key.*;
                a.extra.appendAssumeCapacity(block_inst);
            }
            log.debug("[{}] %{}: includes breaks to {}", .{ pass, inst, fmtInstSet(&data.breaks) });

            // Now we put the live operands from the loop body in too
            const num_live = data.live_set.count();
            try a.extra.ensureUnusedCapacity(gpa, 1 + num_live);

            a.extra.appendAssumeCapacity(num_live);
            it = data.live_set.keyIterator();
            while (it.next()) |key| {
                const alive = key.*;
                a.extra.appendAssumeCapacity(alive);
            }
            log.debug("[{}] %{}: maintain liveness of {}", .{ pass, inst, fmtInstSet(&data.live_set) });

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
        },

        .main_analysis => {
            const extra_idx = a.special.fetchRemove(inst).?.value; // remove because this data does not exist after analysis

            const num_breaks = data.old_extra.items[extra_idx];
            const breaks = data.old_extra.items[extra_idx + 1 ..][0..num_breaks];

            const num_loop_live = data.old_extra.items[extra_idx + num_breaks + 1];
            const loop_live = data.old_extra.items[extra_idx + num_breaks + 2 ..][0..num_loop_live];

            // This is necessarily not in the same control flow branch, because loops are noreturn
            data.live_set.clearRetainingCapacity();

            try data.live_set.ensureUnusedCapacity(gpa, @intCast(u32, loop_live.len));
            for (loop_live) |alive| {
                data.live_set.putAssumeCapacity(alive, {});
                // If the loop requires a branch death operand to be alive, it's not something we
                // want to kill: its "last use" (i.e. the point at which it should die) is the loop
                // body itself.
                _ = data.branch_deaths.remove(alive);
            }

            log.debug("[{}] %{}: block live set is {}", .{ pass, inst, fmtInstSet(&data.live_set) });

            for (breaks) |block_inst| {
                // We might break to this block, so include every operand that the block needs alive
                const block_scope = data.block_scopes.get(block_inst).?;

                var it = block_scope.live_set.keyIterator();
                while (it.next()) |key| {
                    const alive = key.*;
                    try data.live_set.put(gpa, alive, {});
                }
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
        .cond_br => a.air.extraData(Air.CondBr, inst_datas[inst].pl_op.payload),
        .@"try" => a.air.extraData(Air.Try, inst_datas[inst].pl_op.payload),
        .try_ptr => a.air.extraData(Air.TryPtr, inst_datas[inst].ty_pl.payload),
    };

    const condition = switch (inst_type) {
        .cond_br, .@"try" => inst_datas[inst].pl_op.operand,
        .try_ptr => extra.data.ptr,
    };

    const then_body = switch (inst_type) {
        .cond_br => a.air.extra[extra.end..][0..extra.data.then_body_len],
        else => {}, // we won't use this
    };

    const else_body = switch (inst_type) {
        .cond_br => a.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len],
        .@"try", .try_ptr => a.air.extra[extra.end..][0..extra.data.body_len],
    };

    switch (pass) {
        .loop_analysis => {
            switch (inst_type) {
                .cond_br => try analyzeBody(a, pass, data, then_body),
                .@"try", .try_ptr => {},
            }
            try analyzeBody(a, pass, data, else_body);
        },

        .main_analysis => {
            var then_info: ControlBranchInfo = switch (inst_type) {
                .cond_br => try analyzeBodyResetBranch(a, pass, data, then_body),
                .@"try", .try_ptr => blk: {
                    var branch_deaths = try data.branch_deaths.clone(gpa);
                    errdefer branch_deaths.deinit(gpa);
                    var live_set = try data.live_set.clone(gpa);
                    errdefer live_set.deinit(gpa);
                    break :blk .{
                        .branch_deaths = branch_deaths,
                        .live_set = live_set,
                    };
                },
            };
            defer then_info.branch_deaths.deinit(gpa);
            defer then_info.live_set.deinit(gpa);

            // If this is a `try`, the "then body" (rest of the branch) might have referenced our
            // result. If so, we want to avoid this value being considered live while analyzing the
            // else branch.
            switch (inst_type) {
                .cond_br => {},
                .@"try", .try_ptr => _ = data.live_set.remove(inst),
            }

            try analyzeBody(a, pass, data, else_body);
            var else_info: ControlBranchInfo = .{
                .branch_deaths = data.branch_deaths.move(),
                .live_set = data.live_set.move(),
            };
            defer else_info.branch_deaths.deinit(gpa);
            defer else_info.live_set.deinit(gpa);

            // Any queued deaths shared between both branches can be queued for us instead
            {
                var it = then_info.branch_deaths.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    if (else_info.branch_deaths.remove(death)) {
                        // We'll remove it from then_deaths below
                        try data.branch_deaths.put(gpa, death, {});
                    }
                }
                log.debug("[{}] %{}: bubbled deaths {}", .{ pass, inst, fmtInstSet(&data.branch_deaths) });
                it = data.branch_deaths.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    assert(then_info.branch_deaths.remove(death));
                }
            }

            log.debug("[{}] %{}: remaining 'then' branch deaths are {}", .{ pass, inst, fmtInstSet(&then_info.branch_deaths) });
            log.debug("[{}] %{}: remaining 'else' branch deaths are {}", .{ pass, inst, fmtInstSet(&else_info.branch_deaths) });

            // Deaths that occur in one branch but not another need to be made to occur at the start
            // of the other branch.

            var then_mirrored_deaths: std.ArrayListUnmanaged(Air.Inst.Index) = .{};
            defer then_mirrored_deaths.deinit(gpa);

            var else_mirrored_deaths: std.ArrayListUnmanaged(Air.Inst.Index) = .{};
            defer else_mirrored_deaths.deinit(gpa);

            // Note: this invalidates `else_info.live_set`, but expands `then_info.live_set` to
            // be their union
            {
                var it = then_info.live_set.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    if (else_info.live_set.remove(death)) continue; // removing makes the loop below faster
                    if (else_info.branch_deaths.contains(death)) continue;

                    // If this is a `try`, the "then body" (rest of the branch) might have
                    // referenced our result. We want to avoid killing this value in the else branch
                    // if that's the case, since it only exists in the (fake) then branch.
                    switch (inst_type) {
                        .cond_br => {},
                        .@"try", .try_ptr => if (death == inst) continue,
                    }

                    try else_mirrored_deaths.append(gpa, death);
                }
                // Since we removed common stuff above, `else_info.live_set` is now only operands
                // which are *only* alive in the else branch
                it = else_info.live_set.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    if (!then_info.branch_deaths.contains(death)) {
                        try then_mirrored_deaths.append(gpa, death);
                    }
                    // Make `then_info.live_set` contain the full live set (i.e. union of both)
                    try then_info.live_set.put(gpa, death, {});
                }
            }

            log.debug("[{}] %{}: 'then' branch mirrored deaths are {}", .{ pass, inst, fmtInstList(then_mirrored_deaths.items) });
            log.debug("[{}] %{}: 'else' branch mirrored deaths are {}", .{ pass, inst, fmtInstList(else_mirrored_deaths.items) });

            data.live_set.deinit(gpa);
            data.live_set = then_info.live_set.move();

            log.debug("[{}] %{}: new live set is {}", .{ pass, inst, fmtInstSet(&data.live_set) });

            // Write the branch deaths to `extra`
            const then_death_count = then_info.branch_deaths.count() + @intCast(u32, then_mirrored_deaths.items.len);
            const else_death_count = else_info.branch_deaths.count() + @intCast(u32, else_mirrored_deaths.items.len);

            try a.extra.ensureUnusedCapacity(gpa, std.meta.fields(CondBr).len + then_death_count + else_death_count);
            const extra_index = a.addExtraAssumeCapacity(CondBr{
                .then_death_count = then_death_count,
                .else_death_count = else_death_count,
            });
            a.extra.appendSliceAssumeCapacity(then_mirrored_deaths.items);
            {
                var it = then_info.branch_deaths.keyIterator();
                while (it.next()) |key| a.extra.appendAssumeCapacity(key.*);
            }
            a.extra.appendSliceAssumeCapacity(else_mirrored_deaths.items);
            {
                var it = else_info.branch_deaths.keyIterator();
                while (it.next()) |key| a.extra.appendAssumeCapacity(key.*);
            }
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
) !void {
    const inst_datas = a.air.instructions.items(.data);
    const pl_op = inst_datas[inst].pl_op;
    const condition = pl_op.operand;
    const switch_br = a.air.extraData(Air.SwitchBr, pl_op.payload);
    const gpa = a.gpa;
    const ncases = switch_br.data.cases_len;

    switch (pass) {
        .loop_analysis => {
            var air_extra_index: usize = switch_br.end;
            for (0..ncases) |_| {
                const case = a.air.extraData(Air.SwitchBr.Case, air_extra_index);
                const case_body = a.air.extra[case.end + case.data.items_len ..][0..case.data.body_len];
                air_extra_index = case.end + case.data.items_len + case_body.len;
                try analyzeBody(a, pass, data, case_body);
            }
            { // else
                const else_body = a.air.extra[air_extra_index..][0..switch_br.data.else_body_len];
                try analyzeBody(a, pass, data, else_body);
            }
        },

        .main_analysis => {
            // This is, all in all, just a messier version of the `cond_br` logic. If you're trying
            // to understand it, I encourage looking at `analyzeInstCondBr` first.

            const DeathSet = std.AutoHashMapUnmanaged(Air.Inst.Index, void);
            const DeathList = std.ArrayListUnmanaged(Air.Inst.Index);

            var case_infos = try gpa.alloc(ControlBranchInfo, ncases + 1); // +1 for else
            defer gpa.free(case_infos);

            @memset(case_infos, .{});
            defer for (case_infos) |*info| {
                info.branch_deaths.deinit(gpa);
                info.live_set.deinit(gpa);
            };

            var air_extra_index: usize = switch_br.end;
            for (case_infos[0..ncases]) |*info| {
                const case = a.air.extraData(Air.SwitchBr.Case, air_extra_index);
                const case_body = a.air.extra[case.end + case.data.items_len ..][0..case.data.body_len];
                air_extra_index = case.end + case.data.items_len + case_body.len;
                info.* = try analyzeBodyResetBranch(a, pass, data, case_body);
            }
            { // else
                const else_body = a.air.extra[air_extra_index..][0..switch_br.data.else_body_len];
                try analyzeBody(a, pass, data, else_body);
                case_infos[ncases] = .{
                    .branch_deaths = data.branch_deaths.move(),
                    .live_set = data.live_set.move(),
                };
            }

            // Queued deaths common to all cases can be bubbled up
            {
                // We can't remove from the set we're iterating over, so we'll store the shared deaths here
                // temporarily to remove them
                var shared_deaths: DeathSet = .{};
                defer shared_deaths.deinit(gpa);

                var it = case_infos[0].branch_deaths.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    for (case_infos[1..]) |*info| {
                        if (!info.branch_deaths.contains(death)) break;
                    } else try shared_deaths.put(gpa, death, {});
                }

                log.debug("[{}] %{}: bubbled deaths {}", .{ pass, inst, fmtInstSet(&shared_deaths) });

                try data.branch_deaths.ensureUnusedCapacity(gpa, shared_deaths.count());
                it = shared_deaths.keyIterator();
                while (it.next()) |key| {
                    const death = key.*;
                    data.branch_deaths.putAssumeCapacity(death, {});
                    for (case_infos) |*info| {
                        _ = info.branch_deaths.remove(death);
                    }
                }

                for (case_infos, 0..) |*info, i| {
                    log.debug("[{}] %{}: case {} remaining branch deaths are {}", .{ pass, inst, i, fmtInstSet(&info.branch_deaths) });
                }
            }

            const mirrored_deaths = try gpa.alloc(DeathList, ncases + 1);
            defer gpa.free(mirrored_deaths);

            @memset(mirrored_deaths, .{});
            defer for (mirrored_deaths) |*md| md.deinit(gpa);

            {
                var all_alive: DeathSet = .{};
                defer all_alive.deinit(gpa);

                for (case_infos) |*info| {
                    try all_alive.ensureUnusedCapacity(gpa, info.live_set.count());
                    var it = info.live_set.keyIterator();
                    while (it.next()) |key| {
                        const alive = key.*;
                        all_alive.putAssumeCapacity(alive, {});
                    }
                }

                for (mirrored_deaths, case_infos) |*mirrored, *info| {
                    var it = all_alive.keyIterator();
                    while (it.next()) |key| {
                        const alive = key.*;
                        if (!info.live_set.contains(alive) and !info.branch_deaths.contains(alive)) {
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

            const else_death_count = case_infos[ncases].branch_deaths.count() + @intCast(u32, mirrored_deaths[ncases].items.len);

            const extra_index = try a.addExtra(SwitchBr{
                .else_death_count = else_death_count,
            });
            for (mirrored_deaths[0..ncases], case_infos[0..ncases]) |mirrored, info| {
                const num = info.branch_deaths.count() + @intCast(u32, mirrored.items.len);
                try a.extra.ensureUnusedCapacity(gpa, num + 1);
                a.extra.appendAssumeCapacity(num);
                a.extra.appendSliceAssumeCapacity(mirrored.items);
                {
                    var it = info.branch_deaths.keyIterator();
                    while (it.next()) |key| a.extra.appendAssumeCapacity(key.*);
                }
            }
            try a.extra.ensureUnusedCapacity(gpa, else_death_count);
            a.extra.appendSliceAssumeCapacity(mirrored_deaths[ncases].items);
            {
                var it = case_infos[ncases].branch_deaths.keyIterator();
                while (it.next()) |key| a.extra.appendAssumeCapacity(key.*);
            }
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
            const extra_operands = @intCast(u32, total_operands) -| (bpi - 1);
            const max_extra_tombs = (extra_operands + 30) / 31;

            const extra_tombs: []u32 = switch (pass) {
                .loop_analysis => &.{},
                .main_analysis => try a.gpa.alloc(u32, max_extra_tombs),
            };
            errdefer a.gpa.free(extra_tombs);

            @memset(extra_tombs, 0);

            const will_die_immediately: bool = switch (pass) {
                .loop_analysis => false, // track everything, since we don't have full liveness information yet
                .main_analysis => data.branch_deaths.contains(inst) and !data.live_set.contains(inst),
            };

            return .{
                .a = a,
                .data = data,
                .inst = inst,
                .operands_remaining = @intCast(u32, total_operands),
                .extra_tombs = extra_tombs,
                .will_die_immediately = will_die_immediately,
            };
        }

        /// Must be called with operands in reverse order.
        fn feed(big: *Self, op_ref: Air.Inst.Ref) !void {
            // Note that after this, `operands_remaining` becomes the index of the current operand
            big.operands_remaining -= 1;

            if (big.operands_remaining < bpi - 1) {
                big.small[big.operands_remaining] = op_ref;
                return;
            }

            const operand = Air.refToIndex(op_ref) orelse return;

            // Don't compute any liveness for constants
            const inst_tags = big.a.air.instructions.items(.tag);
            switch (inst_tags[operand]) {
                .constant, .const_ty => return,
                else => {},
            }

            // If our result is unused and the instruction doesn't need to be lowered, backends will
            // skip the lowering of this instruction, so we don't want to record uses of operands.
            // That way, we can mark as many instructions as possible unused.
            if (big.will_die_immediately and !big.a.air.mustLower(big.inst)) return;

            const extra_byte = (big.operands_remaining - (bpi - 1)) / 31;
            const extra_bit = @intCast(u5, big.operands_remaining - (bpi - 1) - extra_byte * 31);

            const gpa = big.a.gpa;

            switch (pass) {
                .loop_analysis => {
                    _ = try big.data.live_set.put(gpa, operand, {});
                },

                .main_analysis => {
                    if ((try big.data.live_set.fetchPut(gpa, operand, {})) == null) {
                        log.debug("[{}] %{}: added %{} to live set (operand dies here)", .{ pass, big.inst, operand });
                        big.extra_tombs[extra_byte] |= @as(u32, 1) << extra_bit;
                        if (big.data.branch_deaths.remove(operand)) {
                            log.debug("[{}] %{}: resolved branch death of %{} to this usage", .{ pass, big.inst, operand });
                        }
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
                        if (@truncate(u31, big.extra_tombs[num - 1]) != 0) {
                            // Some operand dies here
                            break;
                        }
                        num -= 1;
                    }
                    // Mark final tomb
                    big.extra_tombs[num - 1] |= @as(u32, 1) << 31;

                    const extra_tombs = big.extra_tombs[0..num];

                    const extra_index = @intCast(u32, big.a.extra.items.len);
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
