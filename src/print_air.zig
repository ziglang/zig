const std = @import("std");
const Allocator = std.mem.Allocator;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

const Zcu = @import("Zcu.zig");
const Value = @import("Value.zig");
const Type = @import("Type.zig");
const Air = @import("Air.zig");
const Liveness = @import("Liveness.zig");
const InternPool = @import("InternPool.zig");

pub fn write(stream: anytype, pt: Zcu.PerThread, air: Air, liveness: ?Liveness) void {
    const instruction_bytes = air.instructions.len *
        // Here we don't use @sizeOf(Air.Inst.Data) because it would include
        // the debug safety tag but we want to measure release size.
        (@sizeOf(Air.Inst.Tag) + 8);
    const extra_bytes = air.extra.len * @sizeOf(u32);
    const tomb_bytes = if (liveness) |l| l.tomb_bits.len * @sizeOf(usize) else 0;
    const liveness_extra_bytes = if (liveness) |l| l.extra.len * @sizeOf(u32) else 0;
    const liveness_special_bytes = if (liveness) |l| l.special.count() * 8 else 0;
    const total_bytes = @sizeOf(Air) + instruction_bytes + extra_bytes +
        @sizeOf(Liveness) + liveness_extra_bytes +
        liveness_special_bytes + tomb_bytes;

    // zig fmt: off
    stream.print(
        \\# Total AIR+Liveness bytes: {}
        \\# AIR Instructions:         {d} ({})
        \\# AIR Extra Data:           {d} ({})
        \\# Liveness tomb_bits:       {}
        \\# Liveness Extra Data:      {d} ({})
        \\# Liveness special table:   {d} ({})
        \\
    , .{
        fmtIntSizeBin(total_bytes),
        air.instructions.len, fmtIntSizeBin(instruction_bytes),
        air.extra.len, fmtIntSizeBin(extra_bytes),
        fmtIntSizeBin(tomb_bytes),
        if (liveness) |l| l.extra.len else 0, fmtIntSizeBin(liveness_extra_bytes),
        if (liveness) |l| l.special.count() else 0, fmtIntSizeBin(liveness_special_bytes),
    }) catch return;
    // zig fmt: on

    var writer: Writer = .{
        .pt = pt,
        .gpa = pt.zcu.gpa,
        .air = air,
        .liveness = liveness,
        .indent = 2,
        .skip_body = false,
    };
    writer.writeBody(stream, air.getMainBody()) catch return;
}

pub fn writeInst(
    stream: anytype,
    inst: Air.Inst.Index,
    pt: Zcu.PerThread,
    air: Air,
    liveness: ?Liveness,
) void {
    var writer: Writer = .{
        .pt = pt,
        .gpa = pt.zcu.gpa,
        .air = air,
        .liveness = liveness,
        .indent = 2,
        .skip_body = true,
    };
    writer.writeInst(stream, inst) catch return;
}

pub fn dump(pt: Zcu.PerThread, air: Air, liveness: ?Liveness) void {
    write(std.io.getStdErr().writer(), pt, air, liveness);
}

pub fn dumpInst(inst: Air.Inst.Index, pt: Zcu.PerThread, air: Air, liveness: ?Liveness) void {
    writeInst(std.io.getStdErr().writer(), inst, pt, air, liveness);
}

const Writer = struct {
    pt: Zcu.PerThread,
    gpa: Allocator,
    air: Air,
    liveness: ?Liveness,
    indent: usize,
    skip_body: bool,

    fn writeBody(w: *Writer, s: anytype, body: []const Air.Inst.Index) @TypeOf(s).Error!void {
        for (body) |inst| {
            try w.writeInst(s, inst);
            try s.writeByte('\n');
        }
    }

    fn writeInst(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const tag = w.air.instructions.items(.tag)[@intFromEnum(inst)];
        try s.writeByteNTimes(' ', w.indent);
        try s.print("%{d}{c}= {s}(", .{
            @intFromEnum(inst),
            @as(u8, if (if (w.liveness) |liveness| liveness.isUnused(inst) else false) '!' else ' '),
            @tagName(tag),
        });
        switch (tag) {
            .add,
            .add_optimized,
            .add_safe,
            .add_wrap,
            .add_sat,
            .sub,
            .sub_optimized,
            .sub_safe,
            .sub_wrap,
            .sub_sat,
            .mul,
            .mul_optimized,
            .mul_safe,
            .mul_wrap,
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
            .set_union_tag,
            .min,
            .max,
            .div_float_optimized,
            .div_trunc_optimized,
            .div_floor_optimized,
            .div_exact_optimized,
            .rem_optimized,
            .mod_optimized,
            .cmp_lt_optimized,
            .cmp_lte_optimized,
            .cmp_eq_optimized,
            .cmp_gte_optimized,
            .cmp_gt_optimized,
            .cmp_neq_optimized,
            .memcpy,
            .memset,
            .memset_safe,
            => try w.writeBinOp(s, inst),

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
            .ret,
            .ret_safe,
            .ret_load,
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
            => try w.writeUnOp(s, inst),

            .trap,
            .breakpoint,
            .unreach,
            .ret_addr,
            .frame_addr,
            .save_err_return_trace_index,
            => try w.writeNoOp(s, inst),

            .alloc,
            .ret_ptr,
            .err_return_trace,
            .c_va_start,
            => try w.writeTy(s, inst),

            .arg => try w.writeArg(s, inst),

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
            .float_from_int,
            .splat,
            .int_from_float,
            .int_from_float_optimized,
            .get_union_tag,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .abs,
            .error_set_has_value,
            .addrspace_cast,
            .c_va_arg,
            .c_va_copy,
            => try w.writeTyOp(s, inst),

            .block, .dbg_inline_block => try w.writeBlock(s, tag, inst),

            .loop => try w.writeLoop(s, inst),

            .slice,
            .slice_elem_ptr,
            .ptr_elem_ptr,
            .ptr_add,
            .ptr_sub,
            .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            => try w.writeTyPlBin(s, inst),

            .call,
            .call_always_tail,
            .call_never_tail,
            .call_never_inline,
            => try w.writeCall(s, inst),

            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            => try w.writeDbgVar(s, inst),

            .struct_field_ptr => try w.writeStructField(s, inst),
            .struct_field_val => try w.writeStructField(s, inst),
            .inferred_alloc => @panic("TODO"),
            .inferred_alloc_comptime => @panic("TODO"),
            .assembly => try w.writeAssembly(s, inst),
            .dbg_stmt => try w.writeDbgStmt(s, inst),

            .aggregate_init => try w.writeAggregateInit(s, inst),
            .union_init => try w.writeUnionInit(s, inst),
            .br => try w.writeBr(s, inst),
            .switch_dispatch => try w.writeBr(s, inst),
            .repeat => try w.writeRepeat(s, inst),
            .cond_br => try w.writeCondBr(s, inst),
            .@"try", .try_cold => try w.writeTry(s, inst),
            .try_ptr, .try_ptr_cold => try w.writeTryPtr(s, inst),
            .loop_switch_br, .switch_br => try w.writeSwitchBr(s, inst),
            .cmpxchg_weak, .cmpxchg_strong => try w.writeCmpxchg(s, inst),
            .atomic_load => try w.writeAtomicLoad(s, inst),
            .prefetch => try w.writePrefetch(s, inst),
            .atomic_store_unordered => try w.writeAtomicStore(s, inst, .unordered),
            .atomic_store_monotonic => try w.writeAtomicStore(s, inst, .monotonic),
            .atomic_store_release => try w.writeAtomicStore(s, inst, .release),
            .atomic_store_seq_cst => try w.writeAtomicStore(s, inst, .seq_cst),
            .atomic_rmw => try w.writeAtomicRmw(s, inst),
            .field_parent_ptr => try w.writeFieldParentPtr(s, inst),
            .wasm_memory_size => try w.writeWasmMemorySize(s, inst),
            .wasm_memory_grow => try w.writeWasmMemoryGrow(s, inst),
            .mul_add => try w.writeMulAdd(s, inst),
            .select => try w.writeSelect(s, inst),
            .shuffle => try w.writeShuffle(s, inst),
            .reduce, .reduce_optimized => try w.writeReduce(s, inst),
            .cmp_vector, .cmp_vector_optimized => try w.writeCmpVector(s, inst),
            .vector_store_elem => try w.writeVectorStoreElem(s, inst),

            .work_item_id,
            .work_group_size,
            .work_group_id,
            => try w.writeWorkDimension(s, inst),
        }
        try s.writeByte(')');
    }

    fn writeBinOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const bin_op = w.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        try w.writeOperand(s, inst, 0, bin_op.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, bin_op.rhs);
    }

    fn writeUnOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const un_op = w.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        try w.writeOperand(s, inst, 0, un_op);
    }

    fn writeNoOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        _ = w;
        _ = inst;
        // no-op, no argument to write
    }

    fn writeType(w: *Writer, s: anytype, ty: Type) !void {
        return ty.print(s, w.pt);
    }

    fn writeTy(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty = w.air.instructions.items(.data)[@intFromEnum(inst)].ty;
        try w.writeType(s, ty);
    }

    fn writeArg(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const arg = w.air.instructions.items(.data)[@intFromEnum(inst)].arg;
        try w.writeType(s, arg.ty.toType());
        switch (arg.name) {
            .none => {},
            _ => try s.print(", \"{}\"", .{std.zig.fmtEscapes(arg.name.toSlice(w.air))}),
        }
    }

    fn writeTyOp(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_op = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        try w.writeType(s, ty_op.ty.toType());
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 0, ty_op.operand);
    }

    fn writeBlock(w: *Writer, s: anytype, tag: Air.Inst.Tag, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        try w.writeType(s, ty_pl.ty.toType());
        const body: []const Air.Inst.Index = @ptrCast(switch (tag) {
            inline .block, .dbg_inline_block => |comptime_tag| body: {
                const extra = w.air.extraData(switch (comptime_tag) {
                    .block => Air.Block,
                    .dbg_inline_block => Air.DbgInlineBlock,
                    else => unreachable,
                }, ty_pl.payload);
                switch (comptime_tag) {
                    .block => {},
                    .dbg_inline_block => {
                        try s.writeAll(", ");
                        try w.writeInstRef(s, Air.internedToRef(extra.data.func), false);
                    },
                    else => unreachable,
                }
                break :body w.air.extra[extra.end..][0..extra.data.body_len];
            },
            else => unreachable,
        });
        if (w.skip_body) return s.writeAll(", ...");
        const liveness_block = if (w.liveness) |liveness|
            liveness.getBlock(inst)
        else
            Liveness.BlockSlices{ .deaths = &.{} };

        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;
        try w.writeBody(s, body);
        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");

        for (liveness_block.deaths) |operand| {
            try s.print(" %{d}!", .{@intFromEnum(operand)});
        }
    }

    fn writeLoop(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.Block, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(w.air.extra[extra.end..][0..extra.data.body_len]);

        try w.writeType(s, ty_pl.ty.toType());
        if (w.skip_body) return s.writeAll(", ...");
        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;
        try w.writeBody(s, body);
        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");
    }

    fn writeAggregateInit(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const zcu = w.pt.zcu;
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const vector_ty = ty_pl.ty.toType();
        const len = @as(usize, @intCast(vector_ty.arrayLen(zcu)));
        const elements = @as([]const Air.Inst.Ref, @ptrCast(w.air.extra[ty_pl.payload..][0..len]));

        try w.writeType(s, vector_ty);
        try s.writeAll(", [");
        for (elements, 0..) |elem, i| {
            if (i != 0) try s.writeAll(", ");
            try w.writeOperand(s, inst, i, elem);
        }
        try s.writeAll("]");
    }

    fn writeUnionInit(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.UnionInit, ty_pl.payload).data;

        try s.print("{d}, ", .{extra.field_index});
        try w.writeOperand(s, inst, 0, extra.init);
    }

    fn writeStructField(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.StructField, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.struct_operand);
        try s.print(", {d}", .{extra.field_index});
    }

    fn writeTyPlBin(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const data = w.air.instructions.items(.data);
        const ty_pl = data[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.Bin, ty_pl.payload).data;

        const inst_ty = data[@intFromEnum(inst)].ty_pl.ty.toType();
        try w.writeType(s, inst_ty);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 0, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.rhs);
    }

    fn writeCmpxchg(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
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

    fn writeMulAdd(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.Bin, pl_op.payload).data;

        try w.writeOperand(s, inst, 0, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.rhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, pl_op.operand);
    }

    fn writeShuffle(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.Shuffle, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.a);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.b);
        try s.print(", mask {d}, len {d}", .{ extra.mask, extra.mask_len });
    }

    fn writeSelect(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const zcu = w.pt.zcu;
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.Bin, pl_op.payload).data;

        const elem_ty = w.typeOfIndex(inst).childType(zcu);
        try w.writeType(s, elem_ty);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, extra.rhs);
    }

    fn writeReduce(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const reduce = w.air.instructions.items(.data)[@intFromEnum(inst)].reduce;

        try w.writeOperand(s, inst, 0, reduce.operand);
        try s.print(", {s}", .{@tagName(reduce.operation)});
    }

    fn writeCmpVector(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.VectorCmp, ty_pl.payload).data;

        try s.print("{s}, ", .{@tagName(extra.compareOperator())});
        try w.writeOperand(s, inst, 0, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.rhs);
    }

    fn writeVectorStoreElem(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const data = w.air.instructions.items(.data)[@intFromEnum(inst)].vector_store_elem;
        const extra = w.air.extraData(Air.VectorCmp, data.payload).data;

        try w.writeOperand(s, inst, 0, data.vector_ptr);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 2, extra.rhs);
    }

    fn writeAtomicLoad(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const atomic_load = w.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;

        try w.writeOperand(s, inst, 0, atomic_load.ptr);
        try s.print(", {s}", .{@tagName(atomic_load.order)});
    }

    fn writePrefetch(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const prefetch = w.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;

        try w.writeOperand(s, inst, 0, prefetch.ptr);
        try s.print(", {s}, {d}, {s}", .{
            @tagName(prefetch.rw), prefetch.locality, @tagName(prefetch.cache),
        });
    }

    fn writeAtomicStore(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        order: std.builtin.AtomicOrder,
    ) @TypeOf(s).Error!void {
        const bin_op = w.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        try w.writeOperand(s, inst, 0, bin_op.lhs);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, bin_op.rhs);
        try s.print(", {s}", .{@tagName(order)});
    }

    fn writeAtomicRmw(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.AtomicRmw, pl_op.payload).data;

        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 1, extra.operand);
        try s.print(", {s}, {s}", .{ @tagName(extra.op()), @tagName(extra.ordering()) });
    }

    fn writeFieldParentPtr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        try w.writeOperand(s, inst, 0, extra.field_ptr);
        try s.print(", {d}", .{extra.field_index});
    }

    fn writeAssembly(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.Asm, ty_pl.payload);
        const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
        const clobbers_len = @as(u31, @truncate(extra.data.flags));
        var extra_i: usize = extra.end;
        var op_index: usize = 0;

        const ret_ty = w.typeOfIndex(inst);
        try w.writeType(s, ret_ty);

        if (is_volatile) {
            try s.writeAll(", volatile");
        }

        const outputs = @as([]const Air.Inst.Ref, @ptrCast(w.air.extra[extra_i..][0..extra.data.outputs_len]));
        extra_i += outputs.len;
        const inputs = @as([]const Air.Inst.Ref, @ptrCast(w.air.extra[extra_i..][0..extra.data.inputs_len]));
        extra_i += inputs.len;

        for (outputs) |output| {
            const extra_bytes = std.mem.sliceAsBytes(w.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);

            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the strings and their null terminators, we still use the next u32
            // for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (output == .none) {
                try s.print(", [{s}] -> {s}", .{ name, constraint });
            } else {
                try s.print(", [{s}] out {s} = (", .{ name, constraint });
                try w.writeOperand(s, inst, op_index, output);
                op_index += 1;
                try s.writeByte(')');
            }
        }

        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(w.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the strings and their null terminators, we still use the next u32
            // for the null terminator.
            extra_i += (constraint.len + name.len + 1) / 4 + 1;

            try s.print(", [{s}] in {s} = (", .{ name, constraint });
            try w.writeOperand(s, inst, op_index, input);
            op_index += 1;
            try s.writeByte(')');
        }

        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const extra_bytes = std.mem.sliceAsBytes(w.air.extra[extra_i..]);
                const clobber = std.mem.sliceTo(extra_bytes, 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;

                try s.writeAll(", ~{");
                try s.writeAll(clobber);
                try s.writeAll("}");
            }
        }
        const asm_source = std.mem.sliceAsBytes(w.air.extra[extra_i..])[0..extra.data.source_len];
        try s.print(", \"{}\"", .{std.zig.fmtEscapes(asm_source)});
    }

    fn writeDbgStmt(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const dbg_stmt = w.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
        try s.print("{d}:{d}", .{ dbg_stmt.line + 1, dbg_stmt.column + 1 });
    }

    fn writeDbgVar(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        try w.writeOperand(s, inst, 0, pl_op.operand);
        const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);
        try s.print(", \"{}\"", .{std.zig.fmtEscapes(name.toSlice(w.air))});
    }

    fn writeCall(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.Call, pl_op.payload);
        const args = @as([]const Air.Inst.Ref, @ptrCast(w.air.extra[extra.end..][0..extra.data.args_len]));
        try w.writeOperand(s, inst, 0, pl_op.operand);
        try s.writeAll(", [");
        for (args, 0..) |arg, i| {
            if (i != 0) try s.writeAll(", ");
            try w.writeOperand(s, inst, 1 + i, arg);
        }
        try s.writeAll("]");
    }

    fn writeBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const br = w.air.instructions.items(.data)[@intFromEnum(inst)].br;
        try w.writeInstIndex(s, br.block_inst, false);
        try s.writeAll(", ");
        try w.writeOperand(s, inst, 0, br.operand);
    }

    fn writeRepeat(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const repeat = w.air.instructions.items(.data)[@intFromEnum(inst)].repeat;
        try w.writeInstIndex(s, repeat.loop_inst, false);
    }

    fn writeTry(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.Try, pl_op.payload);
        const body: []const Air.Inst.Index = @ptrCast(w.air.extra[extra.end..][0..extra.data.body_len]);
        const liveness_condbr = if (w.liveness) |liveness|
            liveness.getCondBr(inst)
        else
            Liveness.CondBrSlices{ .then_deaths = &.{}, .else_deaths = &.{} };

        try w.writeOperand(s, inst, 0, pl_op.operand);
        if (w.skip_body) return s.writeAll(", ...");
        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;

        if (liveness_condbr.else_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.else_deaths, 0..) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{@intFromEnum(operand)});
            }
            try s.writeAll("\n");
        }
        try w.writeBody(s, body);

        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");

        for (liveness_condbr.then_deaths) |operand| {
            try s.print(" %{d}!", .{@intFromEnum(operand)});
        }
    }

    fn writeTryPtr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const ty_pl = w.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = w.air.extraData(Air.TryPtr, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(w.air.extra[extra.end..][0..extra.data.body_len]);
        const liveness_condbr = if (w.liveness) |liveness|
            liveness.getCondBr(inst)
        else
            Liveness.CondBrSlices{ .then_deaths = &.{}, .else_deaths = &.{} };

        try w.writeOperand(s, inst, 0, extra.data.ptr);

        try s.writeAll(", ");
        try w.writeType(s, ty_pl.ty.toType());
        if (w.skip_body) return s.writeAll(", ...");
        try s.writeAll(", {\n");
        const old_indent = w.indent;
        w.indent += 2;

        if (liveness_condbr.else_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.else_deaths, 0..) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{@intFromEnum(operand)});
            }
            try s.writeAll("\n");
        }
        try w.writeBody(s, body);

        w.indent = old_indent;
        try s.writeByteNTimes(' ', w.indent);
        try s.writeAll("}");

        for (liveness_condbr.then_deaths) |operand| {
            try s.print(" %{d}!", .{@intFromEnum(operand)});
        }
    }

    fn writeCondBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = w.air.extraData(Air.CondBr, pl_op.payload);
        const then_body: []const Air.Inst.Index = @ptrCast(w.air.extra[extra.end..][0..extra.data.then_body_len]);
        const else_body: []const Air.Inst.Index = @ptrCast(w.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
        const liveness_condbr = if (w.liveness) |liveness|
            liveness.getCondBr(inst)
        else
            Liveness.CondBrSlices{ .then_deaths = &.{}, .else_deaths = &.{} };

        try w.writeOperand(s, inst, 0, pl_op.operand);
        if (w.skip_body) return s.writeAll(", ...");
        try s.writeAll(",");
        if (extra.data.branch_hints.true != .none) {
            try s.print(" {s}", .{@tagName(extra.data.branch_hints.true)});
        }
        if (extra.data.branch_hints.then_cov != .none) {
            try s.print(" {s}", .{@tagName(extra.data.branch_hints.then_cov)});
        }
        try s.writeAll(" {\n");
        const old_indent = w.indent;
        w.indent += 2;

        if (liveness_condbr.then_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.then_deaths, 0..) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{@intFromEnum(operand)});
            }
            try s.writeAll("\n");
        }

        try w.writeBody(s, then_body);
        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("},");
        if (extra.data.branch_hints.false != .none) {
            try s.print(" {s}", .{@tagName(extra.data.branch_hints.false)});
        }
        if (extra.data.branch_hints.else_cov != .none) {
            try s.print(" {s}", .{@tagName(extra.data.branch_hints.else_cov)});
        }
        try s.writeAll(" {\n");

        if (liveness_condbr.else_deaths.len != 0) {
            try s.writeByteNTimes(' ', w.indent);
            for (liveness_condbr.else_deaths, 0..) |operand, i| {
                if (i != 0) try s.writeAll(" ");
                try s.print("%{d}!", .{@intFromEnum(operand)});
            }
            try s.writeAll("\n");
        }

        try w.writeBody(s, else_body);
        w.indent = old_indent;

        try s.writeByteNTimes(' ', old_indent);
        try s.writeAll("}");
    }

    fn writeSwitchBr(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const switch_br = w.air.unwrapSwitch(inst);

        const liveness = if (w.liveness) |liveness|
            liveness.getSwitchBr(w.gpa, inst, switch_br.cases_len + 1) catch
                @panic("out of memory")
        else blk: {
            const slice = w.gpa.alloc([]const Air.Inst.Index, switch_br.cases_len + 1) catch
                @panic("out of memory");
            @memset(slice, &.{});
            break :blk Liveness.SwitchBrTable{ .deaths = slice };
        };
        defer w.gpa.free(liveness.deaths);

        try w.writeOperand(s, inst, 0, switch_br.operand);
        if (w.skip_body) return s.writeAll(", ...");
        const old_indent = w.indent;
        w.indent += 2;

        var it = switch_br.iterateCases();
        while (it.next()) |case| {
            try s.writeAll(", [");
            for (case.items, 0..) |item, item_i| {
                if (item_i != 0) try s.writeAll(", ");
                try w.writeInstRef(s, item, false);
            }
            for (case.ranges, 0..) |range, range_i| {
                if (range_i != 0 or case.items.len != 0) try s.writeAll(", ");
                try w.writeInstRef(s, range[0], false);
                try s.writeAll("...");
                try w.writeInstRef(s, range[1], false);
            }
            try s.writeAll("] ");
            const hint = switch_br.getHint(case.idx);
            if (hint != .none) {
                try s.print(".{s} ", .{@tagName(hint)});
            }
            try s.writeAll("=> {\n");
            w.indent += 2;

            const deaths = liveness.deaths[case.idx];
            if (deaths.len != 0) {
                try s.writeByteNTimes(' ', w.indent);
                for (deaths, 0..) |operand, i| {
                    if (i != 0) try s.writeAll(" ");
                    try s.print("%{d}!", .{@intFromEnum(operand)});
                }
                try s.writeAll("\n");
            }

            try w.writeBody(s, case.body);
            w.indent -= 2;
            try s.writeByteNTimes(' ', w.indent);
            try s.writeAll("}");
        }

        const else_body = it.elseBody();
        if (else_body.len != 0) {
            try s.writeAll(", else ");
            const hint = switch_br.getElseHint();
            if (hint != .none) {
                try s.print(".{s} ", .{@tagName(hint)});
            }
            try s.writeAll("=> {\n");
            w.indent += 2;

            const deaths = liveness.deaths[liveness.deaths.len - 1];
            if (deaths.len != 0) {
                try s.writeByteNTimes(' ', w.indent);
                for (deaths, 0..) |operand, i| {
                    if (i != 0) try s.writeAll(" ");
                    try s.print("%{d}!", .{@intFromEnum(operand)});
                }
                try s.writeAll("\n");
            }

            try w.writeBody(s, else_body);
            w.indent -= 2;
            try s.writeByteNTimes(' ', w.indent);
            try s.writeAll("}");
        }

        try s.writeAll("\n");
        try s.writeByteNTimes(' ', old_indent);
    }

    fn writeWasmMemorySize(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        try s.print("{d}", .{pl_op.payload});
    }

    fn writeWasmMemoryGrow(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        try s.print("{d}, ", .{pl_op.payload});
        try w.writeOperand(s, inst, 0, pl_op.operand);
    }

    fn writeWorkDimension(w: *Writer, s: anytype, inst: Air.Inst.Index) @TypeOf(s).Error!void {
        const pl_op = w.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        try s.print("{d}", .{pl_op.payload});
    }

    fn writeOperand(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        op_index: usize,
        operand: Air.Inst.Ref,
    ) @TypeOf(s).Error!void {
        const small_tomb_bits = Liveness.bpi - 1;
        const dies = if (w.liveness) |liveness| blk: {
            if (op_index < small_tomb_bits)
                break :blk liveness.operandDies(inst, @as(Liveness.OperandInt, @intCast(op_index)));
            var extra_index = liveness.special.get(inst).?;
            var tomb_op_index: usize = small_tomb_bits;
            while (true) {
                const bits = liveness.extra[extra_index];
                if (op_index < tomb_op_index + 31) {
                    break :blk @as(u1, @truncate(bits >> @as(u5, @intCast(op_index - tomb_op_index)))) != 0;
                }
                if ((bits >> 31) != 0) break :blk false;
                extra_index += 1;
                tomb_op_index += 31;
            }
        } else false;
        return w.writeInstRef(s, operand, dies);
    }

    fn writeInstRef(
        w: *Writer,
        s: anytype,
        operand: Air.Inst.Ref,
        dies: bool,
    ) @TypeOf(s).Error!void {
        if (@intFromEnum(operand) < InternPool.static_len) {
            return s.print("@{}", .{operand});
        } else if (operand.toInterned()) |ip_index| {
            const pt = w.pt;
            const ty = Type.fromInterned(pt.zcu.intern_pool.indexToKey(ip_index).typeOf());
            try s.print("<{}, {}>", .{
                ty.fmt(pt),
                Value.fromInterned(ip_index).fmtValue(pt),
            });
        } else {
            return w.writeInstIndex(s, operand.toIndex().?, dies);
        }
    }

    fn writeInstIndex(
        w: *Writer,
        s: anytype,
        inst: Air.Inst.Index,
        dies: bool,
    ) @TypeOf(s).Error!void {
        _ = w;
        try s.print("%{d}", .{@intFromEnum(inst)});
        if (dies) try s.writeByte('!');
    }

    fn typeOfIndex(w: *Writer, inst: Air.Inst.Index) Type {
        const zcu = w.pt.zcu;
        return w.air.typeOfIndex(inst, &zcu.intern_pool);
    }
};
