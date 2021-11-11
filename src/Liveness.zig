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
const Zir = @import("Zir.zig");
const Log2Int = std.math.Log2Int;

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
///  * `switch_br` - points to a `SwitchBr` in `extra` at this index.
///  * `asm`, `call` - the value is a set of bits which are the extra tomb bits of operands.
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

pub fn analyze(gpa: *Allocator, air: Air, zir: Zir) Allocator.Error!Liveness {
    const tracy = trace(@src());
    defer tracy.end();

    var a: Analysis = .{
        .gpa = gpa,
        .air = air,
        .table = .{},
        .tomb_bits = try gpa.alloc(
            usize,
            (air.instructions.len * bpi + @bitSizeOf(usize) - 1) / @bitSizeOf(usize),
        ),
        .extra = .{},
        .special = .{},
        .zir = &zir,
    };
    errdefer gpa.free(a.tomb_bits);
    errdefer a.special.deinit(gpa);
    defer a.extra.deinit(gpa);
    defer a.table.deinit(gpa);

    std.mem.set(usize, a.tomb_bits, 0);

    const main_body = air.getMainBody();
    try a.table.ensureTotalCapacity(gpa, @intCast(u32, main_body.len));
    try analyzeWithContext(&a, null, main_body);
    return Liveness{
        .tomb_bits = a.tomb_bits,
        .special = a.special,
        .extra = a.extra.toOwnedSlice(gpa),
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

pub fn deinit(l: *Liveness, gpa: *Allocator) void {
    gpa.free(l.tomb_bits);
    gpa.free(l.extra);
    l.special.deinit(gpa);
    l.* = undefined;
}

/// How many tomb bits per AIR instruction.
pub const bpi = 4;
pub const Bpi = std.meta.Int(.unsigned, bpi);
pub const OperandInt = std.math.Log2Int(Bpi);

/// In-progress data; on successful analysis converted into `Liveness`.
const Analysis = struct {
    gpa: *Allocator,
    air: Air,
    table: std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    tomb_bits: []usize,
    special: std.AutoHashMapUnmanaged(Air.Inst.Index, u32),
    extra: std.ArrayListUnmanaged(u32),
    zir: *const Zir,

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
            a.extra.appendAssumeCapacity(switch (field.field_type) {
                u32 => @field(extra, field.name),
                else => @compileError("bad field type"),
            });
        }
        return result;
    }
};

fn analyzeWithContext(
    a: *Analysis,
    new_set: ?*std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    body: []const Air.Inst.Index,
) Allocator.Error!void {
    var i: usize = body.len;

    if (new_set) |ns| {
        // We are only interested in doing this for instructions which are born
        // before a conditional branch, so after obtaining the new set for
        // each branch we prune the instructions which were born within.
        while (i != 0) {
            i -= 1;
            const inst = body[i];
            _ = ns.remove(inst);
            try analyzeInst(a, new_set, inst);
        }
    } else {
        while (i != 0) {
            i -= 1;
            const inst = body[i];
            try analyzeInst(a, new_set, inst);
        }
    }
}

fn analyzeInst(
    a: *Analysis,
    new_set: ?*std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    inst: Air.Inst.Index,
) Allocator.Error!void {
    const gpa = a.gpa;
    const table = &a.table;
    const inst_tags = a.air.instructions.items(.tag);
    const inst_datas = a.air.instructions.items(.data);

    // No tombstone for this instruction means it is never referenced,
    // and its birth marks its own death. Very metal 🤘
    const main_tomb = !table.contains(inst);

    switch (inst_tags[inst]) {
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
        .ptr_add,
        .ptr_sub,
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
        .store,
        .array_elem_val,
        .slice_elem_val,
        .ptr_elem_val,
        .shl,
        .shl_exact,
        .shl_sat,
        .shr,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .set_union_tag,
        .min,
        .max,
        => {
            const o = inst_datas[inst].bin_op;
            return trackOperands(a, new_set, inst, main_tomb, .{ o.lhs, o.rhs, .none });
        },

        .arg,
        .alloc,
        .ret_ptr,
        .constant,
        .const_ty,
        .breakpoint,
        .dbg_stmt,
        .unreach,
        .fence,
        => return trackOperands(a, new_set, inst, main_tomb, .{ .none, .none, .none }),

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
        .int_to_float,
        .get_union_tag,
        .clz,
        .ctz,
        .popcount,
        => {
            const o = inst_datas[inst].ty_op;
            return trackOperands(a, new_set, inst, main_tomb, .{ o.operand, .none, .none });
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
        .ret,
        .ret_load,
        => {
            const operand = inst_datas[inst].un_op;
            return trackOperands(a, new_set, inst, main_tomb, .{ operand, .none, .none });
        },

        .call => {
            const inst_data = inst_datas[inst].pl_op;
            const callee = inst_data.operand;
            const extra = a.air.extraData(Air.Call, inst_data.payload);
            const args = @bitCast([]const Air.Inst.Ref, a.air.extra[extra.end..][0..extra.data.args_len]);
            if (args.len <= bpi - 2) {
                var buf = [1]Air.Inst.Ref{.none} ** (bpi - 1);
                buf[0] = callee;
                std.mem.copy(Air.Inst.Ref, buf[1..], args);
                return trackOperands(a, new_set, inst, main_tomb, buf);
            }
            var extra_tombs: ExtraTombs = .{
                .analysis = a,
                .new_set = new_set,
                .inst = inst,
                .main_tomb = main_tomb,
            };
            try extra_tombs.feed(callee);
            for (args) |arg| {
                try extra_tombs.feed(arg);
            }
            return extra_tombs.finish();
        },
        .struct_field_ptr, .struct_field_val => {
            const extra = a.air.extraData(Air.StructField, inst_datas[inst].ty_pl.payload).data;
            return trackOperands(a, new_set, inst, main_tomb, .{ extra.struct_operand, .none, .none });
        },
        .ptr_elem_ptr, .slice_elem_ptr, .slice => {
            const extra = a.air.extraData(Air.Bin, inst_datas[inst].ty_pl.payload).data;
            return trackOperands(a, new_set, inst, main_tomb, .{ extra.lhs, extra.rhs, .none });
        },
        .cmpxchg_strong, .cmpxchg_weak => {
            const extra = a.air.extraData(Air.Cmpxchg, inst_datas[inst].ty_pl.payload).data;
            return trackOperands(a, new_set, inst, main_tomb, .{ extra.ptr, extra.expected_value, extra.new_value });
        },
        .atomic_load => {
            const ptr = inst_datas[inst].atomic_load.ptr;
            return trackOperands(a, new_set, inst, main_tomb, .{ ptr, .none, .none });
        },
        .atomic_rmw => {
            const pl_op = inst_datas[inst].pl_op;
            const extra = a.air.extraData(Air.AtomicRmw, pl_op.payload).data;
            return trackOperands(a, new_set, inst, main_tomb, .{ pl_op.operand, extra.operand, .none });
        },
        .memset, .memcpy => {
            const pl_op = inst_datas[inst].pl_op;
            const extra = a.air.extraData(Air.Bin, pl_op.payload).data;
            return trackOperands(a, new_set, inst, main_tomb, .{ pl_op.operand, extra.lhs, extra.rhs });
        },
        .br => {
            const br = inst_datas[inst].br;
            return trackOperands(a, new_set, inst, main_tomb, .{ br.operand, .none, .none });
        },
        .assembly => {
            const extra = a.air.extraData(Air.Asm, inst_datas[inst].ty_pl.payload);
            const extended = a.zir.instructions.items(.data)[extra.data.zir_index].extended;
            const outputs_len = @truncate(u5, extended.small);
            const inputs_len = @truncate(u5, extended.small >> 5);
            const outputs = @bitCast([]const Air.Inst.Ref, a.air.extra[extra.end..][0..outputs_len]);
            const args = @bitCast([]const Air.Inst.Ref, a.air.extra[extra.end + outputs.len ..][0..inputs_len]);
            if (outputs.len + args.len <= bpi - 1) {
                var buf = [1]Air.Inst.Ref{.none} ** (bpi - 1);
                std.mem.copy(Air.Inst.Ref, &buf, outputs);
                std.mem.copy(Air.Inst.Ref, buf[outputs.len..], args);
                return trackOperands(a, new_set, inst, main_tomb, buf);
            }
            var extra_tombs: ExtraTombs = .{
                .analysis = a,
                .new_set = new_set,
                .inst = inst,
                .main_tomb = main_tomb,
            };
            for (outputs) |output| {
                try extra_tombs.feed(output);
            }
            for (args) |arg| {
                try extra_tombs.feed(arg);
            }
            return extra_tombs.finish();
        },
        .block => {
            const extra = a.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
            const body = a.air.extra[extra.end..][0..extra.data.body_len];
            try analyzeWithContext(a, new_set, body);
            return trackOperands(a, new_set, inst, main_tomb, .{ .none, .none, .none });
        },
        .loop => {
            const extra = a.air.extraData(Air.Block, inst_datas[inst].ty_pl.payload);
            const body = a.air.extra[extra.end..][0..extra.data.body_len];
            try analyzeWithContext(a, new_set, body);
            return; // Loop has no operands and it is always unreferenced.
        },
        .cond_br => {
            // Each death that occurs inside one branch, but not the other, needs
            // to be added as a death immediately upon entering the other branch.
            const inst_data = inst_datas[inst].pl_op;
            const condition = inst_data.operand;
            const extra = a.air.extraData(Air.CondBr, inst_data.payload);
            const then_body = a.air.extra[extra.end..][0..extra.data.then_body_len];
            const else_body = a.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];

            var then_table: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{};
            defer then_table.deinit(gpa);
            try analyzeWithContext(a, &then_table, then_body);

            // Reset the table back to its state from before the branch.
            {
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }

            var else_table: std.AutoHashMapUnmanaged(Air.Inst.Index, void) = .{};
            defer else_table.deinit(gpa);
            try analyzeWithContext(a, &else_table, else_body);

            var then_entry_deaths = std.ArrayList(Air.Inst.Index).init(gpa);
            defer then_entry_deaths.deinit();
            var else_entry_deaths = std.ArrayList(Air.Inst.Index).init(gpa);
            defer else_entry_deaths.deinit();

            {
                var it = else_table.keyIterator();
                while (it.next()) |key| {
                    const else_death = key.*;
                    if (!then_table.contains(else_death)) {
                        try then_entry_deaths.append(else_death);
                    }
                }
            }
            // This loop is the same, except it's for the then branch, and it additionally
            // has to put its items back into the table to undo the reset.
            {
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    const then_death = key.*;
                    if (!else_table.contains(then_death)) {
                        try else_entry_deaths.append(then_death);
                    }
                    try table.put(gpa, then_death, {});
                }
            }
            // Now we have to correctly populate new_set.
            if (new_set) |ns| {
                try ns.ensureUnusedCapacity(gpa, @intCast(u32, then_table.count() + else_table.count()));
                var it = then_table.keyIterator();
                while (it.next()) |key| {
                    _ = ns.putAssumeCapacity(key.*, {});
                }
                it = else_table.keyIterator();
                while (it.next()) |key| {
                    _ = ns.putAssumeCapacity(key.*, {});
                }
            }
            const then_death_count = @intCast(u32, then_entry_deaths.items.len);
            const else_death_count = @intCast(u32, else_entry_deaths.items.len);

            try a.extra.ensureUnusedCapacity(gpa, std.meta.fields(Air.CondBr).len +
                then_death_count + else_death_count);
            const extra_index = a.addExtraAssumeCapacity(CondBr{
                .then_death_count = then_death_count,
                .else_death_count = else_death_count,
            });
            a.extra.appendSliceAssumeCapacity(then_entry_deaths.items);
            a.extra.appendSliceAssumeCapacity(else_entry_deaths.items);
            try a.special.put(gpa, inst, extra_index);

            // Continue on with the instruction analysis. The following code will find the condition
            // instruction, and the deaths flag for the CondBr instruction will indicate whether the
            // condition's lifetime ends immediately before entering any branch.
            return trackOperands(a, new_set, inst, main_tomb, .{ condition, .none, .none });
        },
        .switch_br => {
            const pl_op = inst_datas[inst].pl_op;
            const condition = pl_op.operand;
            const switch_br = a.air.extraData(Air.SwitchBr, pl_op.payload);

            const Table = std.AutoHashMapUnmanaged(Air.Inst.Index, void);
            const case_tables = try gpa.alloc(Table, switch_br.data.cases_len + 1); // +1 for else
            defer gpa.free(case_tables);

            std.mem.set(Table, case_tables, .{});
            defer for (case_tables) |*ct| ct.deinit(gpa);

            var air_extra_index: usize = switch_br.end;
            for (case_tables[0..switch_br.data.cases_len]) |*case_table| {
                const case = a.air.extraData(Air.SwitchBr.Case, air_extra_index);
                const case_body = a.air.extra[case.end + case.data.items_len ..][0..case.data.body_len];
                air_extra_index = case.end + case.data.items_len + case_body.len;
                try analyzeWithContext(a, case_table, case_body);

                // Reset the table back to its state from before the case.
                var it = case_table.keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }
            { // else
                const else_table = &case_tables[case_tables.len - 1];
                const else_body = a.air.extra[air_extra_index..][0..switch_br.data.else_body_len];
                try analyzeWithContext(a, else_table, else_body);

                // Reset the table back to its state from before the case.
                var it = else_table.keyIterator();
                while (it.next()) |key| {
                    assert(table.remove(key.*));
                }
            }

            const List = std.ArrayListUnmanaged(Air.Inst.Index);
            const case_deaths = try gpa.alloc(List, case_tables.len); // includes else
            defer gpa.free(case_deaths);

            std.mem.set(List, case_deaths, .{});
            defer for (case_deaths) |*cd| cd.deinit(gpa);

            var total_deaths: u32 = 0;
            for (case_tables) |*ct, i| {
                total_deaths += ct.count();
                var it = ct.keyIterator();
                while (it.next()) |key| {
                    const case_death = key.*;
                    for (case_tables) |*ct_inner, j| {
                        if (i == j) continue;
                        if (!ct_inner.contains(case_death)) {
                            // instruction is not referenced in this case
                            try case_deaths[j].append(gpa, case_death);
                        }
                    }
                    // undo resetting the table
                    try table.put(gpa, case_death, {});
                }
            }

            // Now we have to correctly populate new_set.
            if (new_set) |ns| {
                try ns.ensureUnusedCapacity(gpa, total_deaths);
                for (case_tables) |*ct| {
                    var it = ct.keyIterator();
                    while (it.next()) |key| {
                        _ = ns.putAssumeCapacity(key.*, {});
                    }
                }
            }

            const else_death_count = @intCast(u32, case_deaths[case_deaths.len - 1].items.len);
            const extra_index = try a.addExtra(SwitchBr{
                .else_death_count = else_death_count,
            });
            for (case_deaths[0 .. case_deaths.len - 1]) |*cd| {
                const case_death_count = @intCast(u32, cd.items.len);
                try a.extra.ensureUnusedCapacity(gpa, 1 + case_death_count + else_death_count);
                a.extra.appendAssumeCapacity(case_death_count);
                a.extra.appendSliceAssumeCapacity(cd.items);
            }
            a.extra.appendSliceAssumeCapacity(case_deaths[case_deaths.len - 1].items);
            try a.special.put(gpa, inst, extra_index);

            return trackOperands(a, new_set, inst, main_tomb, .{ condition, .none, .none });
        },
    }
}

fn trackOperands(
    a: *Analysis,
    new_set: ?*std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    inst: Air.Inst.Index,
    main_tomb: bool,
    operands: [bpi - 1]Air.Inst.Ref,
) Allocator.Error!void {
    const table = &a.table;
    const gpa = a.gpa;

    var tomb_bits: Bpi = @boolToInt(main_tomb);
    var i = operands.len;

    while (i > 0) {
        i -= 1;
        tomb_bits <<= 1;
        const op_int = @enumToInt(operands[i]);
        if (op_int < Air.Inst.Ref.typed_value_map.len) continue;
        const operand: Air.Inst.Index = op_int - @intCast(u32, Air.Inst.Ref.typed_value_map.len);
        const prev = try table.fetchPut(gpa, operand, {});
        if (prev == null) {
            // Death.
            tomb_bits |= 1;
            if (new_set) |ns| try ns.putNoClobber(gpa, operand, {});
        }
    }
    a.storeTombBits(inst, tomb_bits);
}

const ExtraTombs = struct {
    analysis: *Analysis,
    new_set: ?*std.AutoHashMapUnmanaged(Air.Inst.Index, void),
    inst: Air.Inst.Index,
    main_tomb: bool,
    bit_index: usize = 0,
    tomb_bits: Bpi = 0,
    big_tomb_bits: u32 = 0,

    fn feed(et: *ExtraTombs, op_ref: Air.Inst.Ref) !void {
        const this_bit_index = et.bit_index;
        assert(this_bit_index < 32); // TODO mechanism for when there are greater than 32 operands
        et.bit_index += 1;
        const gpa = et.analysis.gpa;
        const op_int = @enumToInt(op_ref);
        if (op_int < Air.Inst.Ref.typed_value_map.len) return;
        const op_index: Air.Inst.Index = op_int - @intCast(u32, Air.Inst.Ref.typed_value_map.len);
        const prev = try et.analysis.table.fetchPut(gpa, op_index, {});
        if (prev == null) {
            // Death.
            if (et.new_set) |ns| try ns.putNoClobber(gpa, op_index, {});
            if (this_bit_index < bpi - 1) {
                et.tomb_bits |= @as(Bpi, 1) << @intCast(OperandInt, this_bit_index);
            } else {
                const big_bit_index = this_bit_index - (bpi - 1);
                et.big_tomb_bits |= @as(u32, 1) << @intCast(u5, big_bit_index);
            }
        }
    }

    fn finish(et: *ExtraTombs) !void {
        et.tomb_bits |= @as(Bpi, @boolToInt(et.main_tomb)) << (bpi - 1);
        et.analysis.storeTombBits(et.inst, et.tomb_bits);
        try et.analysis.special.put(et.analysis.gpa, et.inst, et.big_tomb_bits);
    }
};
