const std = @import("std");
const Allocator = std.mem.Allocator;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

const Module = @import("Module.zig");
const Value = @import("value.zig").Value;
const Zir = @import("Zir.zig");
const Air = @import("Air.zig");
const Liveness = @import("Liveness.zig");

pub fn dump(gpa: *Allocator, air: Air, zir: Zir, liveness: Liveness) void {
    const instruction_bytes = air.instructions.len *
        // Here we don't use @sizeOf(Air.Inst.Data) because it would include
        // the debug safety tag but we want to measure release size.
        (@sizeOf(Air.Inst.Tag) + 8);
    const extra_bytes = air.extra.len * @sizeOf(u32);
    const values_bytes = air.values.len * @sizeOf(Value);
    const tomb_bytes = liveness.tomb_bits.len * @sizeOf(usize);
    const liveness_extra_bytes = liveness.extra.len * @sizeOf(u32);
    const liveness_special_bytes = liveness.special.count() * 8;
    const total_bytes = @sizeOf(Air) + instruction_bytes + extra_bytes +
        values_bytes + @sizeOf(Liveness) + liveness_extra_bytes +
        liveness_special_bytes + tomb_bytes;

    // zig fmt: off
    std.debug.print(
        \\# Total AIR+Liveness bytes: {}
        \\# AIR Instructions:         {d} ({})
        \\# AIR Extra Data:           {d} ({})
        \\# AIR Values Bytes:         {d} ({})
        \\# Liveness tomb_bits:       {}
        \\# Liveness Extra Data:      {d} ({})
        \\# Liveness special table:   {d} ({})
        \\
    , .{
        fmtIntSizeBin(total_bytes),
        air.instructions.len, fmtIntSizeBin(instruction_bytes),
        air.extra.len, fmtIntSizeBin(extra_bytes),
        air.values.len, fmtIntSizeBin(values_bytes),
        fmtIntSizeBin(tomb_bytes),
        liveness.extra.len, fmtIntSizeBin(liveness_extra_bytes),
        liveness.special.count(), fmtIntSizeBin(liveness_special_bytes),
    });
    // zig fmt: on
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var writer: Writer = .{
        .gpa = gpa,
        .arena = &arena.allocator,
        .air = air,
        .zir = zir,
        .liveness = liveness,
        .indent = 2,
    };
    const stream = std.io.getStdErr().writer();
    writer.writeAllConstants(stream) catch return;
    stream.writeByte('\n') catch return;
    writer.writeBody(stream, air.getMainBody()) catch return;
}

const Writer = struct {
    gpa: *Allocator,
    arena: *Allocator,
    air: Air,
    zir: Zir,
    liveness: Liveness,
    indent: usize,

    fn writeAllConstants(w: *Writer, s: anytype) @TypeOf(s).Error!void {
        for (w.air.instructions.items(.tag)) |tag, i| {
            const inst = @intCast(u32, i);
            switch (tag) {
                .constant, .const_ty => {
                    try s.writeByteNTimes(' ', w.indent);
                    try s.print("%{d} ", .{inst});
                    try w.writeInst(s, inst);
                    try s.writeAll(")\n");
                },
                else => continue,
            }
        }
    }

    fn writeBody(w: *Writer, s: anytype, body: []const Air.Inst.Index) @TypeOf(s).Error!void {
        for (body) |inst| {
            try s.writeByteNTimes(' ', w.indent);
            if (w.liveness.isUnused(inst)) {
                try s.print("%{d}!", .{inst});
            } else {
                try s.print("%{d} ", .{inst});
            }
            try w.writeInst(s, inst);
            try s.writeAll(")\n");
        }
    }

    fn writeInst(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const tags = w.air.instructions.items(.tag);
        const tag = tags[inst];
        try s.print("= {s}(", .{@tagName(tags[inst])});
        switch (tag) {
            .arg => try w.writeTyStr(s, inst),

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
            .set_union_tag,
            .min,
            .max,
            => try w.writeBinOp(s, inst),

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
            => try w.writeUnOp(s, inst),

            .breakpoint,
            .unreach,
            => try w.writeNoOp(s, inst),

            .const_ty,
            .alloc,
            .ret_ptr,
            => try w.writeTy(s, inst),

            .not,
            .bitcast,
            .load,
            .fptrunc,
            .fpext,
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
            .int_to_float,
            .float_to_int,
            .get_union_tag,
            .clz,
            .ctz,
            .popcount,
            => try w.writeTyOp(s, inst),

            .block,
            .loop,
            => try w.writeBlock(s, inst),

            .slice,
            .slice_elem_ptr,
            .ptr_elem_ptr,
            => try w.writeTyPlBin(s, inst),

            .struct_field_ptr => try w.writeStructField(s, inst),
            .struct_field_val => try w.writeStructField(s, inst),
            .constant => try w.writeConstant(s, inst),
            .assembly => try w.writeAssembly(s, inst),
            .dbg_stmt => try w.writeDbgStmt(s, inst),
            .call => try w.writeCall(s, inst),
            .br => try w.writeBr(s, inst),
            .cond_br => try w.writeCondBr(s, inst),
            .switch_br => try w.writeSwitchBr(s, inst),
            .cmpxchg_weak, .cmpxchg_strong => try w.writeCmpxchg(s, inst),
            .fence => try w.writeFence(s, inst),
            .atomic_load => try w.writeAtomicLoad(s, inst),
            .atomic_store_unordered => try w.writeAtomicStore(s, inst, .Unordered),
            .atomic_store_monotonic => try w.writeAtomicStore(s, inst, .Monotonic),
            .atomic_store_release => try w.writeAtomicStore(s, inst, .Release),
            .atomic_store_seq_cst => try w.writeAtomicStore(s, inst, .SeqCst),
            .atomic_rmw => try w.writeAtomicRmw(s, inst),
            .memcpy => try w.writeMemcpy(s, inst),
            .memset => try w.writeMemset(s, inst),
        }
    }

    fn writeTyStr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_str = w.air.instructions.items(.data)[inst].ty_str;
        const name = w.zir.nullTerminatedString(ty_str.str);
        try s.print("\"{}\", {}", .{ std.zig.fmtEscapes(name), ty_str.ty });
    }

    fn writeBinOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const bin_op = w.air.instructions.items(.data)[inst].bin_op;
        try w.writeOperand(s, inst, 0, bin_op.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, bin_op.rhs);
    }

    fn writeUnOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const un_op = w.air.instructions.items(.data)[inst].un_op;
        try w.writeOperand(s, inst, 0, un_op);
    }

    fn writeNoOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        _ = inst;
        _ = s;
        // no-op, no argument to write
    }

    fn writeTy(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty = w.air.instructions.items(.data)[inst].ty;
        try s.print("{}", .{ty});
    }

    fn writeTyOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_op = w.air.instructions.items(.data)[inst].ty_op;
        try s.print("{}, ", .{w.air.getRefType(ty_op.ty)});
        try w.writeOperand(s, inst, 0, ty_op.operand);
    }

    fn writeBlock(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.Block, ty_pl.payload);
        const body = w.air.extra[extra.end..][0..extra.data.body_len];

        try s.print("{}, {{\n", .{w.air.getRefType(ty_pl.ty)});
        const old_indent = w.indent;
        w.indent += 2;
        try w.writeBody(s, body);
        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");
    }

    fn writeStructField(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.StructField, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.struct_operand);
        try s.print(", {d}", .{extra.field_index});
    }

    fn writeTyPlBin(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.Bin, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.rhs);
    }

    fn writeCmpxchg(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.ptr);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.expected_value);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, extra.new_value);
        try s.print(", {s}, {s}", .{
            @tagName(extra.successOrder()), @tagName(extra.failureOrder()),
        });
    }

    fn writeFence(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const atomic_order = w.air.instructions.items(.data)[inst].fence;

        try s.print("{s}", .{@tagName(atomic_order)});
    }

    fn writeAtomicLoad(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const atomic_load = w.air.instructions.items(.data)[inst].atomic_load;

        try w.writeOperand(s, inst, 0, atomic_load.ptr);
        try s.print(", {s}", .{@tagName(atomic_load.order)});
    }

    fn writeAtomicStore(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        order: std.builtin.AtomicOrder,
    ) @TypeOf(s).Error!void {
        const bin_op = w.air.instructions.items(.data)[inst].bin_op;
        try w.writeOperand(s, inst, 0, bin_op.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, bin_op.rhs);
        try s.print(", {s}", .{@tagName(order)});
    }

    fn writeAtomicRmw(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.AtomicRmw, pl_op.payload).data;

        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.operand);
        try s.print(", {s}, {s}", .{ @tagName(extra.op()), @tagName(extra.ordering()) });
    }

    fn writeMemset(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.Bin, pl_op.payload).data;

        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, extra.rhs);
    }

    fn writeMemcpy(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.Bin, pl_op.payload).data;

        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, extra.rhs);
    }

    fn writeConstant(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const val = w.air.values[ty_pl.payload];
        try s.print("{}, {}", .{ w.air.getRefType(ty_pl.ty), val });
    }

    fn writeAssembly(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const air_asm = w.air.extraData(Air.Asm, ty_pl.payload);
        const zir = w.zir;
        const extended = zir.instructions.items(.data)[air_asm.data.zir_index].extended;
        const zir_extra = zir.extraData(Zir.Inst.Asm, extended.operand);
        const asm_source = zir.nullTerminatedString(zir_extra.data.asm_source);
        const outputs_len = @truncate(u5, extended.small);
        const args_len = @truncate(u5, extended.small >> 5);
        const clobbers_len = @truncate(u5, extended.small >> 10);
        const args = @bitCast([]const Air.Inst.Ref, w.air.extra[air_asm.end..][0..args_len]);

        var extra_i: usize = zir_extra.end;
        const output_constraint: ?[]const u8 = out: {
            var i: usize = 0;
            while (i < outputs_len) : (i += 1) {
                const output = zir.extraData(Zir.Inst.Asm.Output, extra_i);
                extra_i = output.end;
                break :out zir.nullTerminatedString(output.data.constraint);
            }
            break :out null;
        };

        try s.print("\"{s}\"", .{asm_source});

        if (output_constraint) |constraint| {
            const ret_ty = w.air.typeOfIndex(inst);
            try s.print(", {s} -> {}", .{ constraint, ret_ty });
        }

        for (args) |arg| {
            const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
            extra_i = input.end;
            const constraint = zir.nullTerminatedString(input.data.constraint);

            try s.print(", {s} = (", .{constraint});
            try w.writeOperand(s, inst, 0, arg);
            try s.writeByte(')');
        }

        const clobbers = zir.extra[extra_i..][0..clobbers_len];
        for (clobbers) |clobber_index| {
            const clobber = zir.nullTerminatedString(clobber_index);
            try s.writeAll(", ~{");
            try s.writeAll(clobber);
            try s.writeAll("}");
        }
    }

    fn writeDbgStmt(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const dbg_stmt = w.air.instructions.items(.data)[inst].dbg_stmt;
        try s.print("{d}:{d}", .{ dbg_stmt.line + 1, dbg_stmt.column + 1 });
    }

    fn writeCall(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.Call, pl_op.payload);
        const args = @bitCast([]const Air.Inst.Ref, w.air.extra[extra.end..][0..extra.data.args_len]);
        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", [");
        for (args) |arg, i| {
            if (i != 0) try s.writeAll(", ");
            try w.writeOperand(s, inst, 1 + i, arg);
        }
        try s.writeAll("]");
    }

    fn writeBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const br = w.air.instructions.items(.data)[inst].br;
        try w.writeInstIndex(s, br.block_inst, false);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 0, br.operand);
    }

    fn writeCondBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.CondBr, pl_op.payload);
        const then_body = w.air.extra[extra.end..][0..extra.data.then_body_len];
        const else_body = w.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
        const liveness_condbr = w.liveness.getCondBr(inst);

        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;

        if (liveness_condbr.then_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.then_deaths) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{operand});
            }
            try s.writeAll("\n");
        }

        try w.writeBody(s, then_body);
        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("}, {\n");

        if (liveness_condbr.else_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.else_deaths) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{operand});
            }
            try s.writeAll("\n");
        }

        try w.writeBody(s, else_body);
        w.indent = old_indent;

        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("}");
    }

    fn writeSwitchBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const switch_br = w.air.extraData(Air.SwitchBr, pl_op.payload);
        var extra_index: usize = switch_br.end;
        var case_i: u32 = 0;

        try w.writeOperand(s, inst, 0, pl_op.operand);
        const old_indent = w.indent;
        w.indent += 2;

        while (case_i < switch_br.data.cases_len) : (case_i += 1) {
            const case = w.air.extraData(Air.SwitchBr.Case, extra_index);
            const items = @bitCast([]const Air.Inst.Ref, w.air.extra[case.end..][0..case.data.items_len]);
            const case_body = w.air.extra[case.end + items.len ..][0..case.data.body_len];
            extra_index = case.end + case.data.items_len + case_body.len;

            try s.writeAll(", [");
            for (items) |item, item_i| {
                if (item_i != 0) try s.writeAll(", ");
                try w.writeInstRef(s, item, false);
            }
            try s.writeAll("] => {\n");
            w.indent += 2;
            try w.writeBody(s, case_body);
            w.indent -= 2;
            try s.writeByteNTimes(' ', w.indent);
            try s.writeAll("}");
        }

        const else_body = w.air.extra[extra_index..][0..switch_br.data.else_body_len];
        if (else_body.len != 0) {
            try s.writeAll(", else => {\n");
            w.indent += 2;
            try w.writeBody(s, else_body);
            w.indent -= 2;
            try s.writeByteNTimes(' ', w.indent);
            try s.writeAll("}");
        }

        try s.writeAll("\n");
        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("}");
    }

    fn writeOperand(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        op_index: usize,
        operand: Air.Inst.Ref,
    ) @TypeOf(s).Error!void {
        const dies = if (op_index < Liveness.bpi - 1)
            w.liveness.operandDies(inst, @intCast(Liveness.OperandInt, op_index))
        else blk: {
            // TODO
            break :blk false;
        };
        return w.writeInstRef(s, operand, dies);
    }

    fn writeInstRef(
        w: *Writer,
        s: anytype,
        operand: Air.Inst.Ref,
        dies: bool,
    ) @TypeOf(s).Error!void {
        var i: usize = @enumToInt(operand);

        if (i < Air.Inst.Ref.typed_value_map.len) {
            return s.print("@{}", .{operand});
        }
        i -= Air.Inst.Ref.typed_value_map.len;

        return w.writeInstIndex(s, @intCast(Air.Inst.Index, i), dies);
    }

    fn writeInstIndex(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        dies: bool,
    ) @TypeOf(s).Error!void {
        _ = w;
        if (dies) {
            try s.print("%{d}!", .{inst});
        } else {
            try s.print("%{d}", .{inst});
        }
    }
};
