const std = @import("std");
const Allocator = std.mem.Allocator;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

const Module = @import("Module.zig");
const Value = @import("value.zig").Value;
const Air = @import("Air.zig");
const Liveness = @import("Liveness.zig");

pub fn dump(gpa: *Allocator, air: Air, liveness: Liveness) void {
    const instruction_bytes = air.instructions.len *
        // Here we don't use @sizeOf(Air.Inst.Data) because it would include
        // the debug safety tag but we want to measure release size.
        (@sizeOf(Air.Inst.Tag) + 8);
    const extra_bytes = air.extra.len * @sizeOf(u32);
    const values_bytes = air.values.len * @sizeOf(Value);
    const variables_bytes = air.variables.len * @sizeOf(*Module.Var);
    const tomb_bytes = liveness.tomb_bits.len * @sizeOf(usize);
    const liveness_extra_bytes = liveness.extra.len * @sizeOf(u32);
    const liveness_special_bytes = liveness.special.count() * 8;
    const total_bytes = @sizeOf(Air) + instruction_bytes + extra_bytes +
        values_bytes * variables_bytes + @sizeOf(Liveness) + liveness_extra_bytes +
        liveness_special_bytes + tomb_bytes;

    // zig fmt: off
    std.debug.print(
        \\# Total AIR+Liveness bytes: {}
        \\# AIR Instructions:         {d} ({})
        \\# AIR Extra Data:           {d} ({})
        \\# AIR Values Bytes:         {d} ({})
        \\# AIR Variables Bytes:      {d} ({})
        \\# Liveness tomb_bits:       {}
        \\# Liveness Extra Data:      {d} ({})
        \\# Liveness special table:   {d} ({})
        \\
    , .{
        fmtIntSizeBin(total_bytes),
        air.instructions.len, fmtIntSizeBin(instruction_bytes),
        air.extra.len, fmtIntSizeBin(extra_bytes),
        air.values.len, fmtIntSizeBin(values_bytes),
        air.variables.len, fmtIntSizeBin(variables_bytes),
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
        .liveness = liveness,
        .indent = 0,
    };
    const stream = std.io.getStdErr().writer();
    writer.writeAllConstants(stream) catch return;
    writer.writeBody(stream, air.getMainBody()) catch return;
}

const Writer = struct {
    gpa: *Allocator,
    arena: *Allocator,
    air: Air,
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
            try s.print("%{d} ", .{inst});
            try w.writeInst(s, inst);
            if (w.liveness.isUnused(inst)) {
                try s.writeAll(") unused\n");
            } else {
                try s.writeAll(")\n");
            }
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
            .sub,
            .subwrap,
            .mul,
            .mulwrap,
            .div,
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
            .ret,
            => try w.writeUnOp(s, inst),

            .breakpoint,
            .unreach,
            => try w.writeNoOp(s, inst),

            .const_ty,
            .alloc,
            => try w.writeTy(s, inst),

            .not,
            .bitcast,
            .load,
            .ref,
            .floatcast,
            .intcast,
            .optional_payload,
            .optional_payload_ptr,
            .wrap_optional,
            .unwrap_errunion_payload,
            .unwrap_errunion_err,
            .unwrap_errunion_payload_ptr,
            .unwrap_errunion_err_ptr,
            .wrap_errunion_payload,
            .wrap_errunion_err,
            => try w.writeTyOp(s, inst),

            .block,
            .loop,
            => try w.writeBlock(s, inst),

            .struct_field_ptr => try w.writeStructFieldPtr(s, inst),
            .varptr => try w.writeVarPtr(s, inst),
            .constant => try w.writeConstant(s, inst),
            .assembly => try w.writeAssembly(s, inst),
            .dbg_stmt => try w.writeDbgStmt(s, inst),
            .call => try w.writeCall(s, inst),
            .br => try w.writeBr(s, inst),
            .cond_br => try w.writeCondBr(s, inst),
            .switch_br => try w.writeSwitchBr(s, inst),
        }
    }

    fn writeTyStr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        _ = inst;
        try s.writeAll("TODO");
    }

    fn writeBinOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const bin_op = w.air.instructions.items(.data)[inst].bin_op;
        try w.writeInstRef(s, bin_op.lhs);
        try s.writeAll(", ");
        try w.writeInstRef(s, bin_op.rhs);
    }

    fn writeUnOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const un_op = w.air.instructions.items(.data)[inst].un_op;
        try w.writeInstRef(s, un_op);
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
        try w.writeInstRef(s, ty_op.operand);
    }

    fn writeBlock(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.Block, ty_pl.payload);
        const body = w.air.extra[extra.end..][0..extra.data.body_len];

        try s.writeAll("{\n");
        const old_indent = w.indent;
        w.indent += 2;
        try w.writeBody(s, body);
        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");
    }

    fn writeStructFieldPtr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const extra = w.air.extraData(Air.StructField, ty_pl.payload);

        try w.writeInstRef(s, extra.data.struct_ptr);
        try s.print(", {d}", .{extra.data.field_index});
    }

    fn writeVarPtr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        _ = inst;
        try s.writeAll("TODO");
    }

    fn writeConstant(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[inst].ty_pl;
        const val = w.air.values[ty_pl.payload];
        try s.print("{}, {}", .{ w.air.getRefType(ty_pl.ty), val });
    }

    fn writeAssembly(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        _ = inst;
        try s.writeAll("TODO");
    }

    fn writeDbgStmt(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const dbg_stmt = w.air.instructions.items(.data)[inst].dbg_stmt;
        try s.print("{d}:{d}", .{ dbg_stmt.line + 1, dbg_stmt.column + 1 });
    }

    fn writeCall(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.Call, pl_op.payload);
        const args = w.air.extra[extra.end..][0..extra.data.args_len];
        try w.writeInstRef(s, pl_op.operand);
        try s.writeAll(", [");
        for (args) |arg, i| {
            if (i != 0) try s.writeAll(", ");
            try w.writeInstRef(s, @intToEnum(Air.Inst.Ref, arg));
        }
        try s.writeAll("]");
    }

    fn writeBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const br = w.air.instructions.items(.data)[inst].br;
        try w.writeInstIndex(s, br.block_inst);
        try s.writeAll(", ");
        try w.writeInstRef(s, br.operand);
    }

    fn writeCondBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[inst].pl_op;
        const extra = w.air.extraData(Air.CondBr, pl_op.payload);
        const then_body = w.air.extra[extra.end..][0..extra.data.then_body_len];
        const else_body = w.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];

        try w.writeInstRef(s, pl_op.operand);
        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;

        try w.writeBody(s, then_body);
        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("}, {\n");

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

        try w.writeInstRef(s, pl_op.operand);
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
                try w.writeInstRef(s, item);
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

    fn writeInstRef(w: *Writer, s: anytype, inst: Air.Inst.Ref) @TypeOf(s).Error!void {
        var i: usize = @enumToInt(inst);

        if (i < Air.Inst.Ref.typed_value_map.len) {
            return s.print("@{}", .{inst});
        }
        i -= Air.Inst.Ref.typed_value_map.len;

        return w.writeInstIndex(s, @intCast(Air.Inst.Index, i));
    }

    fn writeInstIndex(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        return s.print("%{d}", .{inst});
    }
};
