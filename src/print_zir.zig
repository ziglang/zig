const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Ast = std.zig.Ast;
const InternPool = @import("InternPool.zig");

const Zir = std.zig.Zir;
const Zcu = @import("Zcu.zig");
const LazySrcLoc = Zcu.LazySrcLoc;

/// Write human-readable, debug formatted ZIR code.
pub fn renderAsText(gpa: Allocator, tree: ?Ast, zir: Zir, bw: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var writer: Writer = .{
        .gpa = gpa,
        .arena = arena.allocator(),
        .tree = tree,
        .code = zir,
        .indent = 0,
        .parent_decl_node = .root,
        .recurse_decls = true,
        .recurse_blocks = true,
    };

    const main_struct_inst: Zir.Inst.Index = .main_struct_inst;
    try bw.print("%{d} ", .{@intFromEnum(main_struct_inst)});
    try writer.writeInstToStream(bw, main_struct_inst);
    try bw.writeAll("\n");
    const imports_index = zir.extra[@intFromEnum(Zir.ExtraIndex.imports)];
    if (imports_index != 0) {
        try bw.writeAll("Imports:\n");

        const extra = zir.extraData(Zir.Inst.Imports, imports_index);
        var extra_index = extra.end;

        for (0..extra.data.imports_len) |_| {
            const item = zir.extraData(Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;

            const import_path = zir.nullTerminatedString(item.data.name);
            try bw.print("  @import(\"{f}\") ", .{
                std.zig.fmtString(import_path),
            });
            try writer.writeSrcTokAbs(bw, item.data.token);
            try bw.writeAll("\n");
        }
    }
}

pub fn renderInstructionContext(
    gpa: Allocator,
    block: []const Zir.Inst.Index,
    block_index: usize,
    scope_file: *Zcu.File,
    parent_decl_node: Ast.Node.Index,
    indent: u32,
    bw: *std.Io.Writer,
) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var writer: Writer = .{
        .gpa = gpa,
        .arena = arena.allocator(),
        .tree = scope_file.tree,
        .code = scope_file.zir.?,
        .indent = if (indent < 2) 2 else indent,
        .parent_decl_node = parent_decl_node,
        .recurse_decls = false,
        .recurse_blocks = true,
    };

    try writer.writeBody(bw, block[0..block_index]);
    try bw.splatByteAll(' ', writer.indent - 2);
    try bw.print("> %{d} ", .{@intFromEnum(block[block_index])});
    try writer.writeInstToStream(bw, block[block_index]);
    try bw.writeByte('\n');
    if (block_index + 1 < block.len) {
        try writer.writeBody(bw, block[block_index + 1 ..]);
    }
}

pub fn renderSingleInstruction(
    gpa: Allocator,
    inst: Zir.Inst.Index,
    scope_file: *Zcu.File,
    parent_decl_node: Ast.Node.Index,
    indent: u32,
    bw: *std.Io.Writer,
) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var writer: Writer = .{
        .gpa = gpa,
        .arena = arena.allocator(),
        .tree = scope_file.tree,
        .code = scope_file.zir.?,
        .indent = indent,
        .parent_decl_node = parent_decl_node,
        .recurse_decls = false,
        .recurse_blocks = false,
    };

    try bw.print("%{d} ", .{@intFromEnum(inst)});
    try writer.writeInstToStream(bw, inst);
}

const Writer = struct {
    gpa: Allocator,
    arena: Allocator,
    tree: ?Ast,
    code: Zir,
    indent: u32,
    parent_decl_node: Ast.Node.Index,
    recurse_decls: bool,
    recurse_blocks: bool,

    /// Using `std.zig.findLineColumn` whenever we need to resolve a source location makes ZIR
    /// printing O(N^2), which can have drastic effects - taking a ZIR dump from a few seconds to
    /// many minutes. Since we're usually resolving source locations close to one another,
    /// preserving state across source location resolutions speeds things up a lot.
    line_col_cursor: struct {
        line: usize = 0,
        column: usize = 0,
        line_start: usize = 0,
        off: usize = 0,

        fn find(cur: *@This(), source: []const u8, want_offset: usize) std.zig.Loc {
            if (want_offset < cur.off) {
                // Go back to the start of this line
                cur.off = cur.line_start;
                cur.column = 0;

                while (want_offset < cur.off) {
                    // Go back to the newline
                    cur.off -= 1;

                    // Seek to the start of the previous line
                    while (cur.off > 0 and source[cur.off - 1] != '\n') {
                        cur.off -= 1;
                    }
                    cur.line_start = cur.off;
                    cur.line -= 1;
                }
            }

            // The cursor is now positioned before `want_offset`.
            // Seek forward as in `std.zig.findLineColumn`.

            while (cur.off < want_offset) : (cur.off += 1) {
                switch (source[cur.off]) {
                    '\n' => {
                        cur.line += 1;
                        cur.column = 0;
                        cur.line_start = cur.off + 1;
                    },
                    else => {
                        cur.column += 1;
                    },
                }
            }

            while (cur.off < source.len and source[cur.off] != '\n') {
                cur.off += 1;
            }

            return .{
                .line = cur.line,
                .column = cur.column,
                .source_line = source[cur.line_start..cur.off],
            };
        }
    } = .{},

    const Error = std.Io.Writer.Error || Allocator.Error;

    fn writeInstToStream(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const tags = self.code.instructions.items(.tag);
        const tag = tags[@intFromEnum(inst)];
        try stream.print("= {s}(", .{@tagName(tags[@intFromEnum(inst)])});
        switch (tag) {
            .alloc,
            .alloc_mut,
            .alloc_comptime_mut,
            .elem_type,
            .indexable_ptr_elem_type,
            .splat_op_result_ty,
            .indexable_ptr_len,
            .anyframe_type,
            .bit_not,
            .bool_not,
            .slice_sentinel_ty,
            .negate,
            .negate_wrap,
            .load,
            .ensure_result_used,
            .ensure_result_non_error,
            .ensure_err_union_payload_void,
            .ret_node,
            .ret_load,
            .resolve_inferred_alloc,
            .optional_type,
            .optional_payload_safe,
            .optional_payload_unsafe,
            .optional_payload_safe_ptr,
            .optional_payload_unsafe_ptr,
            .err_union_payload_unsafe,
            .err_union_payload_unsafe_ptr,
            .err_union_code,
            .err_union_code_ptr,
            .is_non_null,
            .is_non_null_ptr,
            .is_non_err,
            .is_non_err_ptr,
            .ret_is_non_err,
            .typeof,
            .type_info,
            .size_of,
            .bit_size_of,
            .typeof_log2_int_type,
            .int_from_ptr,
            .compile_error,
            .set_eval_branch_quota,
            .int_from_enum,
            .align_of,
            .int_from_bool,
            .embed_file,
            .error_name,
            .panic,
            .set_runtime_safety,
            .sqrt,
            .sin,
            .cos,
            .tan,
            .exp,
            .exp2,
            .log,
            .log2,
            .log10,
            .abs,
            .floor,
            .ceil,
            .trunc,
            .round,
            .tag_name,
            .type_name,
            .frame_type,
            .clz,
            .ctz,
            .pop_count,
            .byte_swap,
            .bit_reverse,
            .@"resume",
            .make_ptr_const,
            .validate_deref,
            .validate_const,
            .check_comptime_control_flow,
            .opt_eu_base_ptr_init,
            .restore_err_ret_index_unconditional,
            .restore_err_ret_index_fn_entry,
            => try self.writeUnNode(stream, inst),

            .ref,
            .ret_implicit,
            .validate_ref_ty,
            => try self.writeUnTok(stream, inst),

            .bool_br_and,
            .bool_br_or,
            => try self.writeBoolBr(stream, inst),

            .validate_destructure => try self.writeValidateDestructure(stream, inst),
            .array_type_sentinel => try self.writeArrayTypeSentinel(stream, inst),
            .ptr_type => try self.writePtrType(stream, inst),
            .int => try self.writeInt(stream, inst),
            .int_big => try self.writeIntBig(stream, inst),
            .float => try self.writeFloat(stream, inst),
            .float128 => try self.writeFloat128(stream, inst),
            .str => try self.writeStr(stream, inst),
            .int_type => try self.writeIntType(stream, inst),

            .save_err_ret_index => try self.writeSaveErrRetIndex(stream, inst),

            .@"break",
            .break_inline,
            .switch_continue,
            => try self.writeBreak(stream, inst),

            .slice_start => try self.writeSliceStart(stream, inst),
            .slice_end => try self.writeSliceEnd(stream, inst),
            .slice_sentinel => try self.writeSliceSentinel(stream, inst),
            .slice_length => try self.writeSliceLength(stream, inst),

            .union_init => try self.writeUnionInit(stream, inst),

            // Struct inits

            .struct_init_empty,
            .struct_init_empty_result,
            .struct_init_empty_ref_result,
            => try self.writeUnNode(stream, inst),

            .struct_init_anon => try self.writeStructInitAnon(stream, inst),

            .struct_init,
            .struct_init_ref,
            => try self.writeStructInit(stream, inst),

            .validate_struct_init_ty,
            .validate_struct_init_result_ty,
            => try self.writeUnNode(stream, inst),

            .validate_ptr_struct_init => try self.writeBlock(stream, inst),
            .struct_init_field_type => try self.writeStructInitFieldType(stream, inst),
            .struct_init_field_ptr => try self.writePlNodeField(stream, inst),

            // Array inits

            .array_init_anon => try self.writeArrayInitAnon(stream, inst),

            .array_init,
            .array_init_ref,
            => try self.writeArrayInit(stream, inst),

            .validate_array_init_ty,
            .validate_array_init_result_ty,
            => try self.writeValidateArrayInitTy(stream, inst),

            .validate_array_init_ref_ty => try self.writeValidateArrayInitRefTy(stream, inst),
            .validate_ptr_array_init => try self.writeBlock(stream, inst),
            .array_init_elem_type => try self.writeArrayInitElemType(stream, inst),
            .array_init_elem_ptr => try self.writeArrayInitElemPtr(stream, inst),

            .atomic_load => try self.writeAtomicLoad(stream, inst),
            .atomic_store => try self.writeAtomicStore(stream, inst),
            .atomic_rmw => try self.writeAtomicRmw(stream, inst),
            .shuffle => try self.writeShuffle(stream, inst),
            .mul_add => try self.writeMulAdd(stream, inst),
            .builtin_call => try self.writeBuiltinCall(stream, inst),

            .field_type_ref => try self.writeFieldTypeRef(stream, inst),

            .add,
            .addwrap,
            .add_sat,
            .add_unsafe,
            .array_cat,
            .mul,
            .mulwrap,
            .mul_sat,
            .sub,
            .subwrap,
            .sub_sat,
            .cmp_lt,
            .cmp_lte,
            .cmp_eq,
            .cmp_gte,
            .cmp_gt,
            .cmp_neq,
            .div,
            .has_decl,
            .has_field,
            .mod_rem,
            .shl,
            .shl_exact,
            .shl_sat,
            .shr,
            .shr_exact,
            .xor,
            .store_node,
            .store_to_inferred_ptr,
            .error_union_type,
            .merge_error_sets,
            .bit_and,
            .bit_or,
            .int_from_float,
            .float_from_int,
            .ptr_from_int,
            .enum_from_int,
            .float_cast,
            .int_cast,
            .ptr_cast,
            .truncate,
            .div_exact,
            .div_floor,
            .div_trunc,
            .mod,
            .rem,
            .bit_offset_of,
            .offset_of,
            .splat,
            .reduce,
            .bitcast,
            .vector_type,
            .max,
            .min,
            .memcpy,
            .memset,
            .memmove,
            .elem_ptr_node,
            .elem_val_node,
            .elem_ptr,
            .elem_val,
            .array_type,
            .coerce_ptr_elem_ty,
            => try self.writePlNodeBin(stream, inst),

            .for_len => try self.writePlNodeMultiOp(stream, inst),

            .array_mul => try self.writeArrayMul(stream, inst),

            .elem_val_imm => try self.writeElemValImm(stream, inst),

            .@"export" => try self.writePlNodeExport(stream, inst),

            .call => try self.writeCall(stream, inst, .direct),
            .field_call => try self.writeCall(stream, inst, .field),

            .block,
            .block_inline,
            .suspend_block,
            .loop,
            .c_import,
            .typeof_builtin,
            => try self.writeBlock(stream, inst),

            .block_comptime => try self.writeBlockComptime(stream, inst),

            .condbr,
            .condbr_inline,
            => try self.writeCondBr(stream, inst),

            .@"try",
            .try_ptr,
            => try self.writeTry(stream, inst),

            .error_set_decl => try self.writeErrorSetDecl(stream, inst),

            .switch_block,
            .switch_block_ref,
            => try self.writeSwitchBlock(stream, inst),

            .switch_block_err_union => try self.writeSwitchBlockErrUnion(stream, inst),

            .field_ptr_load,
            .field_ptr,
            .decl_literal,
            .decl_literal_no_coerce,
            => try self.writePlNodeField(stream, inst),

            .field_ptr_named,
            .field_ptr_named_load,
            => try self.writePlNodeFieldNamed(stream, inst),

            .as_node, .as_shift_operand => try self.writeAs(stream, inst),

            .repeat,
            .repeat_inline,
            .alloc_inferred,
            .alloc_inferred_mut,
            .alloc_inferred_comptime,
            .alloc_inferred_comptime_mut,
            .ret_ptr,
            .ret_type,
            .trap,
            => try self.writeNode(stream, inst),

            .error_value,
            .enum_literal,
            .decl_ref,
            .decl_val,
            .ret_err_value,
            .ret_err_value_code,
            .param_anytype,
            .param_anytype_comptime,
            => try self.writeStrTok(stream, inst),

            .dbg_var_ptr,
            .dbg_var_val,
            => try self.writeStrOp(stream, inst),

            .param, .param_comptime => try self.writeParam(stream, inst),

            .func => try self.writeFunc(stream, inst, false),
            .func_inferred => try self.writeFunc(stream, inst, true),
            .func_fancy => try self.writeFuncFancy(stream, inst),

            .@"unreachable" => try self.writeUnreachable(stream, inst),

            .dbg_stmt => try self.writeDbgStmt(stream, inst),

            .@"defer" => try self.writeDefer(stream, inst),
            .defer_err_code => try self.writeDeferErrCode(stream, inst),

            .declaration => try self.writeDeclaration(stream, inst),

            .extended => try self.writeExtended(stream, inst),

            .import => try self.writeImport(stream, inst),
        }
    }

    fn writeExtended(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const extended = self.code.instructions.items(.data)[@intFromEnum(inst)].extended;
        try stream.print("{s}(", .{@tagName(extended.opcode)});
        switch (extended.opcode) {
            .this,
            .ret_addr,
            .error_return_trace,
            .frame,
            .frame_address,
            .breakpoint,
            .disable_instrumentation,
            .disable_intrinsics,
            .c_va_start,
            .in_comptime,
            .value_placeholder,
            => try self.writeExtNode(stream, extended),

            .builtin_src => {
                try stream.writeAll("))");
                const inst_data = self.code.extraData(Zir.Inst.LineColumn, extended.operand).data;
                try stream.print(":{d}:{d}", .{ inst_data.line + 1, inst_data.column + 1 });
            },

            .@"asm" => try self.writeAsm(stream, extended, false),
            .asm_expr => try self.writeAsm(stream, extended, true),
            .alloc => try self.writeAllocExtended(stream, extended),

            .compile_log => try self.writeNodeMultiOp(stream, extended),
            .typeof_peer => try self.writeTypeofPeer(stream, extended),
            .min_multi => try self.writeNodeMultiOp(stream, extended),
            .max_multi => try self.writeNodeMultiOp(stream, extended),

            .select => try self.writeSelect(stream, extended),

            .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            => try self.writeOverflowArithmetic(stream, extended),

            .struct_decl => try self.writeStructDecl(stream, extended),
            .union_decl => try self.writeUnionDecl(stream, extended),
            .enum_decl => try self.writeEnumDecl(stream, extended),
            .opaque_decl => try self.writeOpaqueDecl(stream, extended),

            .tuple_decl => try self.writeTupleDecl(stream, extended),

            .c_undef,
            .c_include,
            .set_float_mode,
            .wasm_memory_size,
            .int_from_error,
            .error_from_int,
            .c_va_copy,
            .c_va_end,
            .work_item_id,
            .work_group_size,
            .work_group_id,
            .branch_hint,
            .float_op_result_ty,
            => {
                const inst_data = self.code.extraData(Zir.Inst.UnNode, extended.operand).data;
                try self.writeInstRef(stream, inst_data.operand);
                try stream.writeAll(")) ");
                try self.writeSrcNode(stream, inst_data.node);
            },

            .reify => {
                const inst_data = self.code.extraData(Zir.Inst.Reify, extended.operand).data;
                try stream.print("line({d}), ", .{inst_data.src_line});
                try self.writeInstRef(stream, inst_data.operand);
                try stream.writeAll(")) ");
                const prev_parent_decl_node = self.parent_decl_node;
                self.parent_decl_node = inst_data.node;
                defer self.parent_decl_node = prev_parent_decl_node;
                try self.writeSrcNode(stream, .zero);
            },

            .builtin_extern,
            .c_define,
            .error_cast,
            .wasm_memory_grow,
            .prefetch,
            .c_va_arg,
            => {
                const inst_data = self.code.extraData(Zir.Inst.BinNode, extended.operand).data;
                try self.writeInstRef(stream, inst_data.lhs);
                try stream.writeAll(", ");
                try self.writeInstRef(stream, inst_data.rhs);
                try stream.writeAll(")) ");
                try self.writeSrcNode(stream, inst_data.node);
            },

            .cmpxchg => try self.writeCmpxchg(stream, extended),
            .ptr_cast_full => try self.writePtrCastFull(stream, extended),
            .ptr_cast_no_dest => try self.writePtrCastNoDest(stream, extended),

            .restore_err_ret_index => try self.writeRestoreErrRetIndex(stream, extended),
            .closure_get => try self.writeClosureGet(stream, extended),
            .field_parent_ptr => try self.writeFieldParentPtr(stream, extended),
            .builtin_value => try self.writeBuiltinValue(stream, extended),
            .inplace_arith_result_ty => try self.writeInplaceArithResultTy(stream, extended),

            .dbg_empty_stmt => try stream.writeAll("))"),
            .astgen_error => try stream.writeAll("))"),
        }
    }

    fn writeExtNode(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        try stream.writeAll(")) ");
        const src_node: Ast.Node.Offset = @enumFromInt(@as(i32, @bitCast(extended.operand)));
        try self.writeSrcNode(stream, src_node);
    }

    fn writeArrayInitElemType(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].bin;
        try self.writeInstRef(stream, inst_data.lhs);
        try stream.print(", {d})", .{@intFromEnum(inst_data.rhs)});
    }

    fn writeUnNode(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].un_node;
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeUnTok(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].un_tok;
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(") ");
        try self.writeSrcTok(stream, inst_data.src_tok);
    }

    fn writeValidateDestructure(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ValidateDestructure, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.operand);
        try stream.print(", {d}) (destructure=", .{extra.expect_len});
        try self.writeSrcNode(stream, extra.destructure_node);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeValidateArrayInitTy(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ArrayInit, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.ty);
        try stream.print(", {d}) ", .{extra.init_count});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeArrayTypeSentinel(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ArrayTypeSentinel, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.len);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.sentinel);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.elem_type);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writePtrType(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].ptr_type;
        const str_allowzero = if (inst_data.flags.is_allowzero) "allowzero, " else "";
        const str_const = if (!inst_data.flags.is_mutable) "const, " else "";
        const str_volatile = if (inst_data.flags.is_volatile) "volatile, " else "";
        const extra = self.code.extraData(Zir.Inst.PtrType, inst_data.payload_index);
        try self.writeInstRef(stream, extra.data.elem_type);
        try stream.print(", {s}{s}{s}{s}", .{
            str_allowzero,
            str_const,
            str_volatile,
            @tagName(inst_data.size),
        });
        var extra_index = extra.end;
        if (inst_data.flags.has_sentinel) {
            try stream.writeAll(", ");
            try self.writeInstRef(stream, @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index])));
            extra_index += 1;
        }
        if (inst_data.flags.has_align) {
            try stream.writeAll(", align(");
            try self.writeInstRef(stream, @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index])));
            extra_index += 1;
            if (inst_data.flags.has_bit_range) {
                const bit_start = extra_index + @intFromBool(inst_data.flags.has_addrspace);
                try stream.writeAll(":");
                try self.writeInstRef(stream, @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[bit_start])));
                try stream.writeAll(":");
                try self.writeInstRef(stream, @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[bit_start + 1])));
            }
            try stream.writeAll(")");
        }
        if (inst_data.flags.has_addrspace) {
            try stream.writeAll(", addrspace(");
            try self.writeInstRef(stream, @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index])));
            try stream.writeAll(")");
        }
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, extra.data.src_node);
    }

    fn writeInt(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].int;
        try stream.print("{d})", .{inst_data});
    }

    fn writeIntBig(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].str;
        const byte_count = inst_data.len * @sizeOf(std.math.big.Limb);
        const limb_bytes = self.code.string_bytes[@intFromEnum(inst_data.start)..][0..byte_count];
        // limb_bytes is not aligned properly; we must allocate and copy the bytes
        // in order to accomplish this.
        const limbs = try self.gpa.alloc(std.math.big.Limb, inst_data.len);
        defer self.gpa.free(limbs);

        @memcpy(mem.sliceAsBytes(limbs), limb_bytes);
        const big_int: std.math.big.int.Const = .{
            .limbs = limbs,
            .positive = true,
        };
        const as_string = try big_int.toStringAlloc(self.gpa, 10, .lower);
        defer self.gpa.free(as_string);
        try stream.print("{s})", .{as_string});
    }

    fn writeFloat(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const number = self.code.instructions.items(.data)[@intFromEnum(inst)].float;
        try stream.print("{d})", .{number});
    }

    fn writeFloat128(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Float128, inst_data.payload_index).data;
        const number = extra.get();
        // TODO improve std.format to be able to print f128 values
        try stream.print("{d}) ", .{@as(f64, @floatCast(number))});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeStr(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].str;
        const str = inst_data.get(self.code);
        try stream.print("\"{f}\")", .{std.zig.fmtString(str)});
    }

    fn writeSliceStart(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SliceStart, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.start);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSliceEnd(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SliceEnd, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.start);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.end);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSliceSentinel(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SliceSentinel, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.start);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.end);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.sentinel);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSliceLength(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SliceLength, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.start);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.len);
        if (extra.sentinel != .none) {
            try stream.writeAll(", ");
            try self.writeInstRef(stream, extra.sentinel);
        }
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeUnionInit(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.UnionInit, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.union_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.field_name);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.init);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeShuffle(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Shuffle, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.elem_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.a);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.b);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.mask);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSelect(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.Select, extended.operand).data;
        try self.writeInstRef(stream, extra.elem_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.pred);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.a);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.b);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, extra.node);
    }

    fn writeMulAdd(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.MulAdd, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.mulend1);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.mulend2);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.addend);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeBuiltinCall(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.BuiltinCall, inst_data.payload_index).data;

        try self.writeFlag(stream, "nodiscard ", extra.flags.ensure_result_used);
        try self.writeFlag(stream, "nosuspend ", extra.flags.is_nosuspend);

        try self.writeInstRef(stream, extra.modifier);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.callee);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.args);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeFieldParentPtr(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.FieldParentPtr, extended.operand).data;
        const FlagsInt = @typeInfo(Zir.Inst.FullPtrCastFlags).@"struct".backing_integer.?;
        const flags: Zir.Inst.FullPtrCastFlags = @bitCast(@as(FlagsInt, @truncate(extended.small)));
        if (flags.align_cast) try stream.writeAll("align_cast, ");
        if (flags.addrspace_cast) try stream.writeAll("addrspace_cast, ");
        if (flags.const_cast) try stream.writeAll("const_cast, ");
        if (flags.volatile_cast) try stream.writeAll("volatile_cast, ");
        try self.writeInstRef(stream, extra.parent_ptr_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.field_name);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.field_ptr);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, extra.src_node);
    }

    fn writeParam(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_tok;
        const extra = self.code.extraData(Zir.Inst.Param, inst_data.payload_index);
        const body = self.code.bodySlice(extra.end, extra.data.type.body_len);
        try stream.print("\"{f}\", ", .{
            std.zig.fmtString(self.code.nullTerminatedString(extra.data.name)),
        });

        if (extra.data.type.is_generic) try stream.writeAll("[generic] ");

        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        try self.writeSrcTok(stream, inst_data.src_tok);
    }

    fn writePlNodeBin(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Bin, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.rhs);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writePlNodeMultiOp(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.MultiOp, inst_data.payload_index);
        const args = self.code.refSlice(extra.end, extra.data.operands_len);
        try stream.writeAll("{");
        for (args, 0..) |arg, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, arg);
        }
        try stream.writeAll("}) ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeArrayMul(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ArrayMul, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.res_ty);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.rhs);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeElemValImm(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].elem_val_imm;
        try self.writeInstRef(stream, inst_data.operand);
        try stream.print(", {d})", .{inst_data.idx});
    }

    fn writeArrayInitElemPtr(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ElemPtrImm, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.ptr);
        try stream.print(", {d}) ", .{extra.index});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writePlNodeExport(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Export, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.exported);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.options);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeValidateArrayInitRefTy(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ArrayInitRefTy, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.ptr_ty);
        try stream.writeAll(", ");
        try stream.print(", {}) ", .{extra.elem_count});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeStructInit(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.StructInit, inst_data.payload_index);
        var field_i: u32 = 0;
        var extra_index = extra.end;

        while (field_i < extra.data.fields_len) : (field_i += 1) {
            const item = self.code.extraData(Zir.Inst.StructInit.Item, extra_index);
            extra_index = item.end;

            if (field_i != 0) {
                try stream.writeAll(", [");
            } else {
                try stream.writeAll("[");
            }
            try self.writeInstIndex(stream, item.data.field_type);
            try stream.writeAll(", ");
            try self.writeInstRef(stream, item.data.init);
            try stream.writeAll("]");
        }
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeCmpxchg(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.Cmpxchg, extended.operand).data;

        try self.writeInstRef(stream, extra.ptr);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.expected_value);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.new_value);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.success_order);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.failure_order);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, extra.node);
    }

    fn writePtrCastFull(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const FlagsInt = @typeInfo(Zir.Inst.FullPtrCastFlags).@"struct".backing_integer.?;
        const flags: Zir.Inst.FullPtrCastFlags = @bitCast(@as(FlagsInt, @truncate(extended.small)));
        const extra = self.code.extraData(Zir.Inst.BinNode, extended.operand).data;
        if (flags.ptr_cast) try stream.writeAll("ptr_cast, ");
        if (flags.align_cast) try stream.writeAll("align_cast, ");
        if (flags.addrspace_cast) try stream.writeAll("addrspace_cast, ");
        if (flags.const_cast) try stream.writeAll("const_cast, ");
        if (flags.volatile_cast) try stream.writeAll("volatile_cast, ");
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.rhs);
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.node);
    }

    fn writePtrCastNoDest(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const FlagsInt = @typeInfo(Zir.Inst.FullPtrCastFlags).@"struct".backing_integer.?;
        const flags: Zir.Inst.FullPtrCastFlags = @bitCast(@as(FlagsInt, @truncate(extended.small)));
        const extra = self.code.extraData(Zir.Inst.UnNode, extended.operand).data;
        if (flags.const_cast) try stream.writeAll("const_cast, ");
        if (flags.volatile_cast) try stream.writeAll("volatile_cast, ");
        try self.writeInstRef(stream, extra.operand);
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.node);
    }

    fn writeAtomicLoad(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.AtomicLoad, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.elem_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.ptr);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.ordering);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeAtomicStore(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.AtomicStore, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.ptr);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.operand);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.ordering);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeAtomicRmw(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.AtomicRmw, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.ptr);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.operation);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.operand);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.ordering);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeStructInitAnon(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.StructInitAnon, inst_data.payload_index);
        var field_i: u32 = 0;
        var extra_index = extra.end;

        while (field_i < extra.data.fields_len) : (field_i += 1) {
            const item = self.code.extraData(Zir.Inst.StructInitAnon.Item, extra_index);
            extra_index = item.end;

            const field_name = self.code.nullTerminatedString(item.data.field_name);

            const prefix = if (field_i != 0) ", [" else "[";
            try stream.print("{s}{s}=", .{ prefix, field_name });
            try self.writeInstRef(stream, item.data.init);
            try stream.writeAll("]");
        }
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeStructInitFieldType(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.FieldType, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.container_type);
        const field_name = self.code.nullTerminatedString(extra.name_start);
        try stream.print(", {s}) ", .{field_name});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeFieldTypeRef(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.FieldTypeRef, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.container_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.field_name);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeNodeMultiOp(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.NodeMultiOp, extended.operand);
        const operands = self.code.refSlice(extra.end, extended.small);

        for (operands, 0..) |operand, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, operand);
        }
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.data.src_node);
    }

    fn writeInstNode(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].inst_node;
        try self.writeInstIndex(stream, inst_data.inst);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeAsm(
        self: *Writer,
        stream: *std.Io.Writer,
        extended: Zir.Inst.Extended.InstData,
        tmpl_is_expr: bool,
    ) !void {
        const extra = self.code.extraData(Zir.Inst.Asm, extended.operand);
        const outputs_len = @as(u5, @truncate(extended.small));
        const inputs_len = @as(u5, @truncate(extended.small >> 5));
        const clobbers_len = @as(u5, @truncate(extended.small >> 10));
        const is_volatile = @as(u1, @truncate(extended.small >> 15)) != 0;

        try self.writeFlag(stream, "volatile, ", is_volatile);
        if (tmpl_is_expr) {
            try self.writeInstRef(stream, @enumFromInt(@intFromEnum(extra.data.asm_source)));
            try stream.writeAll(", ");
        } else {
            const asm_source = self.code.nullTerminatedString(extra.data.asm_source);
            try stream.print("\"{f}\", ", .{std.zig.fmtString(asm_source)});
        }
        try stream.writeAll(", ");

        var extra_i: usize = extra.end;
        var output_type_bits = extra.data.output_type_bits;
        {
            var i: usize = 0;
            while (i < outputs_len) : (i += 1) {
                const output = self.code.extraData(Zir.Inst.Asm.Output, extra_i);
                extra_i = output.end;

                const is_type = @as(u1, @truncate(output_type_bits)) != 0;
                output_type_bits >>= 1;

                const name = self.code.nullTerminatedString(output.data.name);
                const constraint = self.code.nullTerminatedString(output.data.constraint);
                try stream.print("output({f}, \"{f}\", ", .{
                    std.zig.fmtIdP(name), std.zig.fmtString(constraint),
                });
                try self.writeFlag(stream, "->", is_type);
                try self.writeInstRef(stream, output.data.operand);
                try stream.writeAll(")");
                if (i + 1 < outputs_len) {
                    try stream.writeAll("), ");
                }
            }
        }
        {
            var i: usize = 0;
            while (i < inputs_len) : (i += 1) {
                const input = self.code.extraData(Zir.Inst.Asm.Input, extra_i);
                extra_i = input.end;

                const name = self.code.nullTerminatedString(input.data.name);
                const constraint = self.code.nullTerminatedString(input.data.constraint);
                try stream.print("input({f}, \"{f}\", ", .{
                    std.zig.fmtIdP(name), std.zig.fmtString(constraint),
                });
                try self.writeInstRef(stream, input.data.operand);
                try stream.writeAll(")");
                if (i + 1 < inputs_len) {
                    try stream.writeAll(", ");
                }
            }
        }
        {
            var i: usize = 0;
            while (i < clobbers_len) : (i += 1) {
                const str_index = self.code.extra[extra_i];
                extra_i += 1;
                const clobber = self.code.nullTerminatedString(@enumFromInt(str_index));
                try stream.print("{f}", .{std.zig.fmtIdP(clobber)});
                if (i + 1 < clobbers_len) {
                    try stream.writeAll(", ");
                }
            }
        }
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.data.src_node);
    }

    fn writeOverflowArithmetic(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.BinNode, extended.operand).data;

        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.rhs);
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.node);
    }

    fn writeCall(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
        comptime kind: enum { direct, field },
    ) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const ExtraType = switch (kind) {
            .direct => Zir.Inst.Call,
            .field => Zir.Inst.FieldCall,
        };
        const extra = self.code.extraData(ExtraType, inst_data.payload_index);
        const args_len = extra.data.flags.args_len;
        const body = self.code.extra[extra.end..];

        if (extra.data.flags.ensure_result_used) {
            try stream.writeAll("nodiscard ");
        }
        try stream.print(".{s}, ", .{@tagName(@as(std.builtin.CallModifier, @enumFromInt(extra.data.flags.packed_modifier)))});
        switch (kind) {
            .direct => try self.writeInstRef(stream, extra.data.callee),
            .field => {
                const field_name = self.code.nullTerminatedString(extra.data.field_name_start);
                try self.writeInstRef(stream, extra.data.obj_ptr);
                try stream.print(", \"{f}\"", .{std.zig.fmtString(field_name)});
            },
        }
        try stream.writeAll(", [");

        self.indent += 2;
        if (args_len != 0) {
            try stream.writeAll("\n");
        }
        var i: usize = 0;
        var arg_start: u32 = args_len;
        while (i < args_len) : (i += 1) {
            try stream.splatByteAll(' ', self.indent);
            const arg_end = self.code.extra[extra.end + i];
            defer arg_start = arg_end;
            const arg_body = body[arg_start..arg_end];
            try self.writeBracedBody(stream, @ptrCast(arg_body));

            try stream.writeAll(",\n");
        }
        self.indent -= 2;
        if (args_len != 0) {
            try stream.splatByteAll(' ', self.indent);
        }

        try stream.writeAll("]) ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeBlock(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Block, inst_data.payload_index);
        const body = self.code.bodySlice(extra.end, extra.data.body_len);
        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeBlockComptime(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.BlockComptime, inst_data.payload_index);
        const body = self.code.bodySlice(extra.end, extra.data.body_len);
        try stream.print("reason={s}, ", .{@tagName(extra.data.reason)});
        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeCondBr(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.CondBr, inst_data.payload_index);
        const then_body = self.code.bodySlice(extra.end, extra.data.then_body_len);
        const else_body = self.code.bodySlice(extra.end + then_body.len, extra.data.else_body_len);
        try self.writeInstRef(stream, extra.data.condition);
        try stream.writeAll(", ");
        try self.writeBracedBody(stream, then_body);
        try stream.writeAll(", ");
        try self.writeBracedBody(stream, else_body);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeTry(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Try, inst_data.payload_index);
        const body = self.code.bodySlice(extra.end, extra.data.body_len);
        try self.writeInstRef(stream, extra.data.operand);
        try stream.writeAll(", ");
        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeStructDecl(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const small: Zir.Inst.StructDecl.Small = @bitCast(extended.small);

        const extra = self.code.extraData(Zir.Inst.StructDecl, extended.operand);

        const prev_parent_decl_node = self.parent_decl_node;
        self.parent_decl_node = extra.data.src_node;
        defer self.parent_decl_node = prev_parent_decl_node;

        const fields_hash: std.zig.SrcHash = @bitCast([4]u32{
            extra.data.fields_hash_0,
            extra.data.fields_hash_1,
            extra.data.fields_hash_2,
            extra.data.fields_hash_3,
        });

        try stream.print("hash({x}) ", .{&fields_hash});

        var extra_index: usize = extra.end;

        const captures_len = if (small.has_captures_len) blk: {
            const captures_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk captures_len;
        } else 0;

        const fields_len = if (small.has_fields_len) blk: {
            const fields_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk fields_len;
        } else 0;

        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;

        try self.writeFlag(stream, "known_non_opv, ", small.known_non_opv);
        try self.writeFlag(stream, "known_comptime_only, ", small.known_comptime_only);

        try stream.print("{s}, ", .{@tagName(small.name_strategy)});

        extra_index = try self.writeCaptures(stream, extra_index, captures_len);
        try stream.writeAll(", ");

        if (small.has_backing_int) {
            const backing_int_body_len = self.code.extra[extra_index];
            extra_index += 1;
            try stream.writeAll("packed(");
            if (backing_int_body_len == 0) {
                const backing_int_ref: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                extra_index += 1;
                try self.writeInstRef(stream, backing_int_ref);
            } else {
                const body = self.code.bodySlice(extra_index, backing_int_body_len);
                extra_index += backing_int_body_len;
                self.indent += 2;
                try self.writeBracedDecl(stream, body);
                self.indent -= 2;
            }
            try stream.writeAll("), ");
        } else {
            try stream.print("{s}, ", .{@tagName(small.layout)});
        }

        if (decls_len == 0) {
            try stream.writeAll("{}, ");
        } else {
            try stream.writeAll("{\n");
            self.indent += 2;
            try self.writeBody(stream, self.code.bodySlice(extra_index, decls_len));
            self.indent -= 2;
            extra_index += decls_len;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}, ");
        }

        if (fields_len == 0) {
            try stream.writeAll("{}, {}) ");
        } else {
            const bits_per_field = 4;
            const fields_per_u32 = 32 / bits_per_field;
            const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
            const Field = struct {
                type_len: u32 = 0,
                align_len: u32 = 0,
                init_len: u32 = 0,
                type: Zir.Inst.Ref = .none,
                name: Zir.NullTerminatedString,
                is_comptime: bool,
            };
            const fields = try self.arena.alloc(Field, fields_len);
            {
                var bit_bag_index: usize = extra_index;
                extra_index += bit_bags_count;
                var cur_bit_bag: u32 = undefined;
                var field_i: u32 = 0;
                while (field_i < fields_len) : (field_i += 1) {
                    if (field_i % fields_per_u32 == 0) {
                        cur_bit_bag = self.code.extra[bit_bag_index];
                        bit_bag_index += 1;
                    }
                    const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
                    cur_bit_bag >>= 1;
                    const has_default = @as(u1, @truncate(cur_bit_bag)) != 0;
                    cur_bit_bag >>= 1;
                    const is_comptime = @as(u1, @truncate(cur_bit_bag)) != 0;
                    cur_bit_bag >>= 1;
                    const has_type_body = @as(u1, @truncate(cur_bit_bag)) != 0;
                    cur_bit_bag >>= 1;

                    const field_name_index: Zir.NullTerminatedString = @enumFromInt(self.code.extra[extra_index]);
                    extra_index += 1;

                    fields[field_i] = .{
                        .is_comptime = is_comptime,
                        .name = field_name_index,
                    };

                    if (has_type_body) {
                        fields[field_i].type_len = self.code.extra[extra_index];
                    } else {
                        fields[field_i].type = @enumFromInt(self.code.extra[extra_index]);
                    }
                    extra_index += 1;

                    if (has_align) {
                        fields[field_i].align_len = self.code.extra[extra_index];
                        extra_index += 1;
                    }

                    if (has_default) {
                        fields[field_i].init_len = self.code.extra[extra_index];
                        extra_index += 1;
                    }
                }
            }

            try stream.writeAll("{\n");
            self.indent += 2;

            for (fields, 0..) |field, i| {
                try stream.splatByteAll(' ', self.indent);
                try self.writeFlag(stream, "comptime ", field.is_comptime);
                if (field.name != .empty) {
                    const field_name = self.code.nullTerminatedString(field.name);
                    try stream.print("{f}: ", .{std.zig.fmtIdP(field_name)});
                } else {
                    try stream.print("@\"{d}\": ", .{i});
                }
                if (field.type != .none) {
                    try self.writeInstRef(stream, field.type);
                }

                if (field.type_len > 0) {
                    const body = self.code.bodySlice(extra_index, field.type_len);
                    extra_index += body.len;
                    self.indent += 2;
                    try self.writeBracedDecl(stream, body);
                    self.indent -= 2;
                }

                if (field.align_len > 0) {
                    const body = self.code.bodySlice(extra_index, field.align_len);
                    extra_index += body.len;
                    self.indent += 2;
                    try stream.writeAll(" align(");
                    try self.writeBracedDecl(stream, body);
                    try stream.writeAll(")");
                    self.indent -= 2;
                }

                if (field.init_len > 0) {
                    const body = self.code.bodySlice(extra_index, field.init_len);
                    extra_index += body.len;
                    self.indent += 2;
                    try stream.writeAll(" = ");
                    try self.writeBracedDecl(stream, body);
                    self.indent -= 2;
                }

                try stream.writeAll(",\n");
            }

            self.indent -= 2;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}) ");
        }
        try self.writeSrcNode(stream, .zero);
    }

    fn writeUnionDecl(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const small = @as(Zir.Inst.UnionDecl.Small, @bitCast(extended.small));

        const extra = self.code.extraData(Zir.Inst.UnionDecl, extended.operand);

        const prev_parent_decl_node = self.parent_decl_node;
        self.parent_decl_node = extra.data.src_node;
        defer self.parent_decl_node = prev_parent_decl_node;

        const fields_hash: std.zig.SrcHash = @bitCast([4]u32{
            extra.data.fields_hash_0,
            extra.data.fields_hash_1,
            extra.data.fields_hash_2,
            extra.data.fields_hash_3,
        });

        try stream.print("hash({x}) ", .{&fields_hash});

        var extra_index: usize = extra.end;

        const tag_type_ref = if (small.has_tag_type) blk: {
            const tag_type_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
            break :blk tag_type_ref;
        } else .none;

        const captures_len = if (small.has_captures_len) blk: {
            const captures_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk captures_len;
        } else 0;

        const body_len = if (small.has_body_len) blk: {
            const body_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk body_len;
        } else 0;

        const fields_len = if (small.has_fields_len) blk: {
            const fields_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk fields_len;
        } else 0;

        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;

        try stream.print("{s}, {s}, ", .{
            @tagName(small.name_strategy), @tagName(small.layout),
        });
        try self.writeFlag(stream, "autoenum, ", small.auto_enum_tag);

        extra_index = try self.writeCaptures(stream, extra_index, captures_len);
        try stream.writeAll(", ");

        if (decls_len == 0) {
            try stream.writeAll("{}");
        } else {
            try stream.writeAll("{\n");
            self.indent += 2;
            try self.writeBody(stream, self.code.bodySlice(extra_index, decls_len));
            self.indent -= 2;
            extra_index += decls_len;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}");
        }

        if (tag_type_ref != .none) {
            try stream.writeAll(", ");
            try self.writeInstRef(stream, tag_type_ref);
        }

        if (fields_len == 0) {
            try stream.writeAll("}) ");
            try self.writeSrcNode(stream, .zero);
            return;
        }
        try stream.writeAll(", ");

        const body = self.code.bodySlice(extra_index, body_len);
        extra_index += body.len;

        try self.writeBracedDecl(stream, body);
        try stream.writeAll(", {\n");

        self.indent += 2;
        const bits_per_field = 4;
        const fields_per_u32 = 32 / bits_per_field;
        const bit_bags_count = std.math.divCeil(usize, fields_len, fields_per_u32) catch unreachable;
        const body_end = extra_index;
        extra_index += bit_bags_count;
        var bit_bag_index: usize = body_end;
        var cur_bit_bag: u32 = undefined;
        var field_i: u32 = 0;
        while (field_i < fields_len) : (field_i += 1) {
            if (field_i % fields_per_u32 == 0) {
                cur_bit_bag = self.code.extra[bit_bag_index];
                bit_bag_index += 1;
            }
            const has_type = @as(u1, @truncate(cur_bit_bag)) != 0;
            cur_bit_bag >>= 1;
            const has_align = @as(u1, @truncate(cur_bit_bag)) != 0;
            cur_bit_bag >>= 1;
            const has_value = @as(u1, @truncate(cur_bit_bag)) != 0;
            cur_bit_bag >>= 1;
            const unused = @as(u1, @truncate(cur_bit_bag)) != 0;
            cur_bit_bag >>= 1;

            _ = unused;

            const field_name_index: Zir.NullTerminatedString = @enumFromInt(self.code.extra[extra_index]);
            const field_name = self.code.nullTerminatedString(field_name_index);
            extra_index += 1;

            try stream.splatByteAll(' ', self.indent);
            try stream.print("{f}", .{std.zig.fmtIdP(field_name)});

            if (has_type) {
                const field_type = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;

                try stream.writeAll(": ");
                try self.writeInstRef(stream, field_type);
            }
            if (has_align) {
                const align_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;

                try stream.writeAll(" align(");
                try self.writeInstRef(stream, align_ref);
                try stream.writeAll(")");
            }
            if (has_value) {
                const default_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;

                try stream.writeAll(" = ");
                try self.writeInstRef(stream, default_ref);
            }
            try stream.writeAll(",\n");
        }

        self.indent -= 2;
        try stream.splatByteAll(' ', self.indent);
        try stream.writeAll("}) ");
        try self.writeSrcNode(stream, .zero);
    }

    fn writeEnumDecl(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const small = @as(Zir.Inst.EnumDecl.Small, @bitCast(extended.small));

        const extra = self.code.extraData(Zir.Inst.EnumDecl, extended.operand);

        const prev_parent_decl_node = self.parent_decl_node;
        self.parent_decl_node = extra.data.src_node;
        defer self.parent_decl_node = prev_parent_decl_node;

        const fields_hash: std.zig.SrcHash = @bitCast([4]u32{
            extra.data.fields_hash_0,
            extra.data.fields_hash_1,
            extra.data.fields_hash_2,
            extra.data.fields_hash_3,
        });

        try stream.print("hash({x}) ", .{&fields_hash});

        var extra_index: usize = extra.end;

        const tag_type_ref = if (small.has_tag_type) blk: {
            const tag_type_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
            break :blk tag_type_ref;
        } else .none;

        const captures_len = if (small.has_captures_len) blk: {
            const captures_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk captures_len;
        } else 0;

        const body_len = if (small.has_body_len) blk: {
            const body_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk body_len;
        } else 0;

        const fields_len = if (small.has_fields_len) blk: {
            const fields_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk fields_len;
        } else 0;

        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;

        try stream.print("{s}, ", .{@tagName(small.name_strategy)});
        try self.writeFlag(stream, "nonexhaustive, ", small.nonexhaustive);

        extra_index = try self.writeCaptures(stream, extra_index, captures_len);
        try stream.writeAll(", ");

        if (decls_len == 0) {
            try stream.writeAll("{}, ");
        } else {
            try stream.writeAll("{\n");
            self.indent += 2;
            try self.writeBody(stream, self.code.bodySlice(extra_index, decls_len));
            self.indent -= 2;
            extra_index += decls_len;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}, ");
        }

        if (tag_type_ref != .none) {
            try self.writeInstRef(stream, tag_type_ref);
            try stream.writeAll(", ");
        }

        const body = self.code.bodySlice(extra_index, body_len);
        extra_index += body.len;

        try self.writeBracedDecl(stream, body);
        if (fields_len == 0) {
            try stream.writeAll(", {}) ");
        } else {
            try stream.writeAll(", {\n");

            self.indent += 2;
            const bit_bags_count = std.math.divCeil(usize, fields_len, 32) catch unreachable;
            const body_end = extra_index;
            extra_index += bit_bags_count;
            var bit_bag_index: usize = body_end;
            var cur_bit_bag: u32 = undefined;
            var field_i: u32 = 0;
            while (field_i < fields_len) : (field_i += 1) {
                if (field_i % 32 == 0) {
                    cur_bit_bag = self.code.extra[bit_bag_index];
                    bit_bag_index += 1;
                }
                const has_tag_value = @as(u1, @truncate(cur_bit_bag)) != 0;
                cur_bit_bag >>= 1;

                const field_name = self.code.nullTerminatedString(@enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;

                try stream.splatByteAll(' ', self.indent);
                try stream.print("{f}", .{std.zig.fmtIdP(field_name)});

                if (has_tag_value) {
                    const tag_value_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                    extra_index += 1;

                    try stream.writeAll(" = ");
                    try self.writeInstRef(stream, tag_value_ref);
                }
                try stream.writeAll(",\n");
            }
            self.indent -= 2;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}) ");
        }
        try self.writeSrcNode(stream, .zero);
    }

    fn writeOpaqueDecl(
        self: *Writer,
        stream: *std.Io.Writer,
        extended: Zir.Inst.Extended.InstData,
    ) !void {
        const small = @as(Zir.Inst.OpaqueDecl.Small, @bitCast(extended.small));
        const extra = self.code.extraData(Zir.Inst.OpaqueDecl, extended.operand);

        const prev_parent_decl_node = self.parent_decl_node;
        self.parent_decl_node = extra.data.src_node;
        defer self.parent_decl_node = prev_parent_decl_node;

        var extra_index: usize = extra.end;

        const captures_len = if (small.has_captures_len) blk: {
            const captures_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk captures_len;
        } else 0;

        const decls_len = if (small.has_decls_len) blk: {
            const decls_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk decls_len;
        } else 0;

        try stream.print("{s}, ", .{@tagName(small.name_strategy)});

        extra_index = try self.writeCaptures(stream, extra_index, captures_len);
        try stream.writeAll(", ");

        if (decls_len == 0) {
            try stream.writeAll("{}) ");
        } else {
            try stream.writeAll("{\n");
            self.indent += 2;
            try self.writeBody(stream, self.code.bodySlice(extra_index, decls_len));
            self.indent -= 2;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}) ");
        }
        try self.writeSrcNode(stream, .zero);
    }

    fn writeTupleDecl(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const fields_len = extended.small;
        assert(fields_len != 0);
        const extra = self.code.extraData(Zir.Inst.TupleDecl, extended.operand);

        var extra_index = extra.end;

        try stream.writeAll("{ ");

        for (0..fields_len) |field_idx| {
            if (field_idx != 0) try stream.writeAll(", ");

            const field_ty, const field_init = self.code.extra[extra_index..][0..2].*;
            extra_index += 2;

            try stream.print("@\"{d}\": ", .{field_idx});
            try self.writeInstRef(stream, @enumFromInt(field_ty));
            try stream.writeAll(" = ");
            try self.writeInstRef(stream, @enumFromInt(field_init));
        }

        try stream.writeAll(" }) ");

        try self.writeSrcNode(stream, extra.data.src_node);
    }

    fn writeErrorSetDecl(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.ErrorSetDecl, inst_data.payload_index);

        try stream.writeAll("{\n");
        self.indent += 2;

        var extra_index = @as(u32, @intCast(extra.end));
        const extra_index_end = extra_index + extra.data.fields_len;
        while (extra_index < extra_index_end) : (extra_index += 1) {
            const name_index: Zir.NullTerminatedString = @enumFromInt(self.code.extra[extra_index]);
            const name = self.code.nullTerminatedString(name_index);
            try stream.splatByteAll(' ', self.indent);
            try stream.print("{f},\n", .{std.zig.fmtIdP(name)});
        }

        self.indent -= 2;
        try stream.splatByteAll(' ', self.indent);
        try stream.writeAll("}) ");

        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSwitchBlockErrUnion(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SwitchBlockErrUnion, inst_data.payload_index);

        var extra_index: usize = extra.end;

        const multi_cases_len = if (extra.data.bits.has_multi_cases) blk: {
            const multi_cases_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk multi_cases_len;
        } else 0;

        const err_capture_inst: Zir.Inst.Index = if (extra.data.bits.any_uses_err_capture) blk: {
            const tag_capture_inst = self.code.extra[extra_index];
            extra_index += 1;
            break :blk @enumFromInt(tag_capture_inst);
        } else undefined;

        try self.writeInstRef(stream, extra.data.operand);

        if (extra.data.bits.any_uses_err_capture) {
            try stream.writeAll(", err_capture=");
            try self.writeInstIndex(stream, err_capture_inst);
        }

        self.indent += 2;

        {
            const info = @as(Zir.Inst.SwitchBlock.ProngInfo, @bitCast(self.code.extra[extra_index]));
            extra_index += 1;

            assert(!info.is_inline);
            const body = self.code.bodySlice(extra_index, info.body_len);
            extra_index += body.len;

            try stream.writeAll(",\n");
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("non_err => ");
            try self.writeBracedBody(stream, body);
        }

        if (extra.data.bits.has_else) {
            const info = @as(Zir.Inst.SwitchBlock.ProngInfo, @bitCast(self.code.extra[extra_index]));
            extra_index += 1;
            const capture_text = switch (info.capture) {
                .none => "",
                .by_val => "by_val ",
                .by_ref => "by_ref ",
            };
            const inline_text = if (info.is_inline) "inline " else "";
            const body = self.code.bodySlice(extra_index, info.body_len);
            extra_index += body.len;

            try stream.writeAll(",\n");
            try stream.splatByteAll(' ', self.indent);
            try stream.print("{s}{s}else => ", .{ capture_text, inline_text });
            try self.writeBracedBody(stream, body);
        }

        {
            const scalar_cases_len = extra.data.bits.scalar_cases_len;
            var scalar_i: usize = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                const item_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;
                const info = @as(Zir.Inst.SwitchBlock.ProngInfo, @bitCast(self.code.extra[extra_index]));
                extra_index += 1;
                const body = self.code.bodySlice(extra_index, info.body_len);
                extra_index += info.body_len;

                try stream.writeAll(",\n");
                try stream.splatByteAll(' ', self.indent);
                switch (info.capture) {
                    .none => {},
                    .by_val => try stream.writeAll("by_val "),
                    .by_ref => try stream.writeAll("by_ref "),
                }
                if (info.is_inline) try stream.writeAll("inline ");
                try self.writeInstRef(stream, item_ref);
                try stream.writeAll(" => ");
                try self.writeBracedBody(stream, body);
            }
        }
        {
            var multi_i: usize = 0;
            while (multi_i < multi_cases_len) : (multi_i += 1) {
                const items_len = self.code.extra[extra_index];
                extra_index += 1;
                const ranges_len = self.code.extra[extra_index];
                extra_index += 1;
                const info = @as(Zir.Inst.SwitchBlock.ProngInfo, @bitCast(self.code.extra[extra_index]));
                extra_index += 1;
                const items = self.code.refSlice(extra_index, items_len);
                extra_index += items_len;

                try stream.writeAll(",\n");
                try stream.splatByteAll(' ', self.indent);
                switch (info.capture) {
                    .none => {},
                    .by_val => try stream.writeAll("by_val "),
                    .by_ref => try stream.writeAll("by_ref "),
                }
                if (info.is_inline) try stream.writeAll("inline ");

                for (items, 0..) |item_ref, item_i| {
                    if (item_i != 0) try stream.writeAll(", ");
                    try self.writeInstRef(stream, item_ref);
                }

                var range_i: usize = 0;
                while (range_i < ranges_len) : (range_i += 1) {
                    const item_first = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                    extra_index += 1;
                    const item_last = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                    extra_index += 1;

                    if (range_i != 0 or items.len != 0) {
                        try stream.writeAll(", ");
                    }
                    try self.writeInstRef(stream, item_first);
                    try stream.writeAll("...");
                    try self.writeInstRef(stream, item_last);
                }

                const body = self.code.bodySlice(extra_index, info.body_len);
                extra_index += info.body_len;
                try stream.writeAll(" => ");
                try self.writeBracedBody(stream, body);
            }
        }

        self.indent -= 2;

        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeSwitchBlock(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.SwitchBlock, inst_data.payload_index);

        var extra_index: usize = extra.end;

        const multi_cases_len = if (extra.data.bits.has_multi_cases) blk: {
            const multi_cases_len = self.code.extra[extra_index];
            extra_index += 1;
            break :blk multi_cases_len;
        } else 0;

        const tag_capture_inst: Zir.Inst.Index = if (extra.data.bits.any_has_tag_capture) blk: {
            const tag_capture_inst = self.code.extra[extra_index];
            extra_index += 1;
            break :blk @enumFromInt(tag_capture_inst);
        } else undefined;

        try self.writeInstRef(stream, extra.data.operand);

        if (extra.data.bits.any_has_tag_capture) {
            try stream.writeAll(", tag_capture=");
            try self.writeInstIndex(stream, tag_capture_inst);
        }

        self.indent += 2;

        const special_prongs = extra.data.bits.special_prongs;

        if (special_prongs.hasElse()) {
            const info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(self.code.extra[extra_index]);
            const capture_text = switch (info.capture) {
                .none => "",
                .by_val => "by_val ",
                .by_ref => "by_ref ",
            };
            const inline_text = if (info.is_inline) "inline " else "";
            extra_index += 1;
            const body = self.code.bodySlice(extra_index, info.body_len);
            extra_index += body.len;

            try stream.writeAll(",\n");
            try stream.splatByteAll(' ', self.indent);
            try stream.print("{s}{s}else => ", .{ capture_text, inline_text });
            try self.writeBracedBody(stream, body);
        }

        if (special_prongs.hasUnder()) {
            var single_item_ref: Zir.Inst.Ref = .none;
            var items_len: u32 = 0;
            var ranges_len: u32 = 0;
            if (special_prongs.hasOneAdditionalItem()) {
                single_item_ref = @enumFromInt(self.code.extra[extra_index]);
                extra_index += 1;
            } else if (special_prongs.hasManyAdditionalItems()) {
                items_len = self.code.extra[extra_index];
                extra_index += 1;
                ranges_len = self.code.extra[extra_index];
                extra_index += 1;
            }
            const info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(self.code.extra[extra_index]);
            extra_index += 1;
            const items = self.code.refSlice(extra_index, items_len);
            extra_index += items_len;

            try stream.writeAll(",\n");
            try stream.splatByteAll(' ', self.indent);
            switch (info.capture) {
                .none => {},
                .by_val => try stream.writeAll("by_val "),
                .by_ref => try stream.writeAll("by_ref "),
            }
            if (info.is_inline) try stream.writeAll("inline ");

            try stream.writeAll("_");
            if (single_item_ref != .none) {
                try stream.writeAll(", ");
                try self.writeInstRef(stream, single_item_ref);
            }
            for (items) |item_ref| {
                try stream.writeAll(", ");
                try self.writeInstRef(stream, item_ref);
            }

            var range_i: usize = 0;
            while (range_i < ranges_len) : (range_i += 1) {
                const item_first: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                extra_index += 1;
                const item_last: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                extra_index += 1;

                try stream.writeAll(", ");
                try self.writeInstRef(stream, item_first);
                try stream.writeAll("...");
                try self.writeInstRef(stream, item_last);
            }

            const body = self.code.bodySlice(extra_index, info.body_len);
            extra_index += info.body_len;
            try stream.writeAll(" => ");
            try self.writeBracedBody(stream, body);
        }

        {
            const scalar_cases_len = extra.data.bits.scalar_cases_len;
            var scalar_i: usize = 0;
            while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
                const item_ref: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                extra_index += 1;
                const info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(self.code.extra[extra_index]);
                extra_index += 1;
                const body = self.code.bodySlice(extra_index, info.body_len);
                extra_index += info.body_len;

                try stream.writeAll(",\n");
                try stream.splatByteAll(' ', self.indent);
                switch (info.capture) {
                    .none => {},
                    .by_val => try stream.writeAll("by_val "),
                    .by_ref => try stream.writeAll("by_ref "),
                }
                if (info.is_inline) try stream.writeAll("inline ");
                try self.writeInstRef(stream, item_ref);
                try stream.writeAll(" => ");
                try self.writeBracedBody(stream, body);
            }
        }
        {
            var multi_i: usize = 0;
            while (multi_i < multi_cases_len) : (multi_i += 1) {
                const items_len = self.code.extra[extra_index];
                extra_index += 1;
                const ranges_len = self.code.extra[extra_index];
                extra_index += 1;
                const info: Zir.Inst.SwitchBlock.ProngInfo = @bitCast(self.code.extra[extra_index]);
                extra_index += 1;
                const items = self.code.refSlice(extra_index, items_len);
                extra_index += items_len;

                try stream.writeAll(",\n");
                try stream.splatByteAll(' ', self.indent);
                switch (info.capture) {
                    .none => {},
                    .by_val => try stream.writeAll("by_val "),
                    .by_ref => try stream.writeAll("by_ref "),
                }
                if (info.is_inline) try stream.writeAll("inline ");

                for (items, 0..) |item_ref, item_i| {
                    if (item_i != 0) try stream.writeAll(", ");
                    try self.writeInstRef(stream, item_ref);
                }

                var range_i: usize = 0;
                while (range_i < ranges_len) : (range_i += 1) {
                    const item_first: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                    extra_index += 1;
                    const item_last: Zir.Inst.Ref = @enumFromInt(self.code.extra[extra_index]);
                    extra_index += 1;

                    if (range_i != 0 or items.len != 0) {
                        try stream.writeAll(", ");
                    }
                    try self.writeInstRef(stream, item_first);
                    try stream.writeAll("...");
                    try self.writeInstRef(stream, item_last);
                }

                const body = self.code.bodySlice(extra_index, info.body_len);
                extra_index += info.body_len;
                try stream.writeAll(" => ");
                try self.writeBracedBody(stream, body);
            }
        }

        self.indent -= 2;

        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writePlNodeField(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Field, inst_data.payload_index).data;
        const name = self.code.nullTerminatedString(extra.field_name_start);
        try self.writeInstRef(stream, extra.lhs);
        try stream.print(", \"{f}\") ", .{std.zig.fmtString(name)});
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writePlNodeFieldNamed(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.FieldNamed, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.field_name);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeAs(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.As, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.dest_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.operand);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeNode(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const src_node = self.code.instructions.items(.data)[@intFromEnum(inst)].node;
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, src_node);
    }

    fn writeStrTok(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
    ) Error!void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].str_tok;
        const str = inst_data.get(self.code);
        try stream.print("\"{f}\") ", .{std.zig.fmtString(str)});
        try self.writeSrcTok(stream, inst_data.src_tok);
    }

    fn writeStrOp(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].str_op;
        const str = inst_data.getStr(self.code);
        try self.writeInstRef(stream, inst_data.operand);
        try stream.print(", \"{f}\")", .{std.zig.fmtString(str)});
    }

    fn writeFunc(
        self: *Writer,
        stream: *std.Io.Writer,
        inst: Zir.Inst.Index,
        inferred_error_set: bool,
    ) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.Func, inst_data.payload_index);

        var extra_index = extra.end;
        var ret_ty_ref: Zir.Inst.Ref = .none;
        var ret_ty_body: []const Zir.Inst.Index = &.{};

        switch (extra.data.ret_ty.body_len) {
            0 => {
                ret_ty_ref = .void_type;
            },
            1 => {
                ret_ty_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
                extra_index += 1;
            },
            else => {
                ret_ty_body = self.code.bodySlice(extra_index, extra.data.ret_ty.body_len);
                extra_index += ret_ty_body.len;
            },
        }

        const body = self.code.bodySlice(extra_index, extra.data.body_len);
        extra_index += body.len;

        var src_locs: Zir.Inst.Func.SrcLocs = undefined;
        if (body.len != 0) {
            src_locs = self.code.extraData(Zir.Inst.Func.SrcLocs, extra_index).data;
        }
        return self.writeFuncCommon(
            stream,
            inferred_error_set,
            false,
            false,

            .none,
            &.{},
            ret_ty_ref,
            ret_ty_body,
            extra.data.ret_ty.is_generic,

            body,
            inst_data.src_node,
            src_locs,
            0,
        );
    }

    fn writeFuncFancy(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.FuncFancy, inst_data.payload_index);

        var extra_index: usize = extra.end;
        var cc_ref: Zir.Inst.Ref = .none;
        var cc_body: []const Zir.Inst.Index = &.{};
        var ret_ty_ref: Zir.Inst.Ref = .none;
        var ret_ty_body: []const Zir.Inst.Index = &.{};

        if (extra.data.bits.has_cc_body) {
            const body_len = self.code.extra[extra_index];
            extra_index += 1;
            cc_body = self.code.bodySlice(extra_index, body_len);
            extra_index += cc_body.len;
        } else if (extra.data.bits.has_cc_ref) {
            cc_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
        }
        if (extra.data.bits.has_ret_ty_body) {
            const body_len = self.code.extra[extra_index];
            extra_index += 1;
            ret_ty_body = self.code.bodySlice(extra_index, body_len);
            extra_index += ret_ty_body.len;
        } else if (extra.data.bits.has_ret_ty_ref) {
            ret_ty_ref = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
        }

        const noalias_bits: u32 = if (extra.data.bits.has_any_noalias) blk: {
            const x = self.code.extra[extra_index];
            extra_index += 1;
            break :blk x;
        } else 0;

        const body = self.code.bodySlice(extra_index, extra.data.body_len);
        extra_index += body.len;

        var src_locs: Zir.Inst.Func.SrcLocs = undefined;
        if (body.len != 0) {
            src_locs = self.code.extraData(Zir.Inst.Func.SrcLocs, extra_index).data;
        }
        return self.writeFuncCommon(
            stream,
            extra.data.bits.is_inferred_error,
            extra.data.bits.is_var_args,
            extra.data.bits.is_noinline,
            cc_ref,
            cc_body,
            ret_ty_ref,
            ret_ty_body,
            extra.data.bits.ret_ty_is_generic,
            body,
            inst_data.src_node,
            src_locs,
            noalias_bits,
        );
    }

    fn writeAllocExtended(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.AllocExtended, extended.operand);
        const small = @as(Zir.Inst.AllocExtended.Small, @bitCast(extended.small));

        var extra_index: usize = extra.end;
        const type_inst: Zir.Inst.Ref = if (!small.has_type) .none else blk: {
            const type_inst = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
            break :blk type_inst;
        };
        const align_inst: Zir.Inst.Ref = if (!small.has_align) .none else blk: {
            const align_inst = @as(Zir.Inst.Ref, @enumFromInt(self.code.extra[extra_index]));
            extra_index += 1;
            break :blk align_inst;
        };
        try self.writeFlag(stream, ",is_const", small.is_const);
        try self.writeFlag(stream, ",is_comptime", small.is_comptime);
        try self.writeOptionalInstRef(stream, ",ty=", type_inst);
        try self.writeOptionalInstRef(stream, ",align=", align_inst);
        try stream.writeAll(")) ");
        try self.writeSrcNode(stream, extra.data.src_node);
    }

    fn writeTypeofPeer(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.TypeOfPeer, extended.operand);
        const body = self.code.bodySlice(extra.data.body_index, extra.data.body_len);
        try self.writeBracedBody(stream, body);
        try stream.writeAll(",[");
        const args = self.code.refSlice(extra.end, extended.small);
        for (args, 0..) |arg, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, arg);
        }
        try stream.writeAll("])");
    }

    fn writeBoolBr(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;
        const extra = self.code.extraData(Zir.Inst.BoolBr, inst_data.payload_index);
        const body = self.code.bodySlice(extra.end, extra.data.body_len);
        try self.writeInstRef(stream, extra.data.lhs);
        try stream.writeAll(", ");
        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeIntType(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const int_type = self.code.instructions.items(.data)[@intFromEnum(inst)].int_type;
        const prefix: u8 = switch (int_type.signedness) {
            .signed => 'i',
            .unsigned => 'u',
        };
        try stream.print("{c}{d}) ", .{ prefix, int_type.bit_count });
        try self.writeSrcNode(stream, int_type.src_node);
    }

    fn writeSaveErrRetIndex(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].save_err_ret_index;

        try self.writeInstRef(stream, inst_data.operand);

        try stream.writeAll(")");
    }

    fn writeRestoreErrRetIndex(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const extra = self.code.extraData(Zir.Inst.RestoreErrRetIndex, extended.operand).data;

        try self.writeInstRef(stream, extra.block);
        try self.writeInstRef(stream, extra.operand);

        try stream.writeAll(") ");
        try self.writeSrcNode(stream, extra.src_node);
    }

    fn writeBreak(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].@"break";
        const extra = self.code.extraData(Zir.Inst.Break, inst_data.payload_index).data;

        try self.writeInstIndex(stream, extra.block_inst);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(")");
    }

    fn writeArrayInit(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;

        const extra = self.code.extraData(Zir.Inst.MultiOp, inst_data.payload_index);
        const args = self.code.refSlice(extra.end, extra.data.operands_len);

        try self.writeInstRef(stream, args[0]);
        try stream.writeAll("{");
        for (args[1..], 0..) |arg, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, arg);
        }
        try stream.writeAll("}) ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeArrayInitAnon(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;

        const extra = self.code.extraData(Zir.Inst.MultiOp, inst_data.payload_index);
        const args = self.code.refSlice(extra.end, extra.data.operands_len);

        try stream.writeAll("{");
        for (args, 0..) |arg, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, arg);
        }
        try stream.writeAll("}) ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeArrayInitSent(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_node;

        const extra = self.code.extraData(Zir.Inst.MultiOp, inst_data.payload_index);
        const args = self.code.refSlice(extra.end, extra.data.operands_len);
        const sent = args[args.len - 1];
        const elems = args[0 .. args.len - 1];

        try self.writeInstRef(stream, sent);
        try stream.writeAll(", ");

        try stream.writeAll(".{");
        for (elems, 0..) |elem, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, elem);
        }
        try stream.writeAll("}) ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeUnreachable(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].@"unreachable";
        try stream.writeAll(") ");
        try self.writeSrcNode(stream, inst_data.src_node);
    }

    fn writeFuncCommon(
        self: *Writer,
        stream: *std.Io.Writer,
        inferred_error_set: bool,
        var_args: bool,
        is_noinline: bool,
        cc_ref: Zir.Inst.Ref,
        cc_body: []const Zir.Inst.Index,
        ret_ty_ref: Zir.Inst.Ref,
        ret_ty_body: []const Zir.Inst.Index,
        ret_ty_is_generic: bool,
        body: []const Zir.Inst.Index,
        src_node: Ast.Node.Offset,
        src_locs: Zir.Inst.Func.SrcLocs,
        noalias_bits: u32,
    ) !void {
        try self.writeOptionalInstRefOrBody(stream, "cc=", cc_ref, cc_body);
        if (ret_ty_is_generic) try stream.writeAll("[generic] ");
        try self.writeOptionalInstRefOrBody(stream, "ret_ty=", ret_ty_ref, ret_ty_body);
        try self.writeFlag(stream, "vargs, ", var_args);
        try self.writeFlag(stream, "inferror, ", inferred_error_set);
        try self.writeFlag(stream, "noinline, ", is_noinline);

        if (noalias_bits != 0) {
            try stream.print("noalias=0b{b}, ", .{noalias_bits});
        }

        try stream.writeAll("body=");
        try self.writeBracedBody(stream, body);
        try stream.writeAll(") ");
        if (body.len != 0) {
            try stream.print("(lbrace={d}:{d},rbrace={d}:{d}) ", .{
                src_locs.lbrace_line + 1, @as(u16, @truncate(src_locs.columns)) + 1,
                src_locs.rbrace_line + 1, @as(u16, @truncate(src_locs.columns >> 16)) + 1,
            });
        }
        try self.writeSrcNode(stream, src_node);
    }

    fn writeDbgStmt(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
        try stream.print("{d}, {d})", .{ inst_data.line + 1, inst_data.column + 1 });
    }

    fn writeDefer(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].@"defer";
        const body = self.code.bodySlice(inst_data.index, inst_data.len);
        try self.writeBracedBody(stream, body);
        try stream.writeByte(')');
    }

    fn writeDeferErrCode(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].defer_err_code;
        const extra = self.code.extraData(Zir.Inst.DeferErrCode, inst_data.payload_index).data;

        try self.writeInstRef(stream, extra.remapped_err_code.toRef());
        try stream.writeAll(" = ");
        try self.writeInstRef(stream, inst_data.err_code);
        try stream.writeAll(", ");
        const body = self.code.bodySlice(extra.index, extra.len);
        try self.writeBracedBody(stream, body);
        try stream.writeByte(')');
    }

    fn writeDeclaration(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const decl = self.code.getDeclaration(inst);

        const prev_parent_decl_node = self.parent_decl_node;
        defer self.parent_decl_node = prev_parent_decl_node;
        self.parent_decl_node = decl.src_node;

        if (decl.is_pub) try stream.writeAll("pub ");
        switch (decl.linkage) {
            .normal => {},
            .@"export" => try stream.writeAll("export "),
            .@"extern" => try stream.writeAll("extern "),
        }
        switch (decl.kind) {
            .@"comptime" => try stream.writeAll("comptime"),
            .unnamed_test => try stream.writeAll("test"),
            .@"test", .decltest, .@"const", .@"var" => {
                try stream.print("{s} '{s}'", .{ @tagName(decl.kind), self.code.nullTerminatedString(decl.name) });
            },
        }
        const src_hash = self.code.getAssociatedSrcHash(inst).?;
        try stream.print(" line({d}) column({d}) hash({x})", .{
            decl.src_line, decl.src_column, &src_hash,
        });

        {
            if (decl.type_body) |b| {
                try stream.writeAll(" type=");
                try self.writeBracedDecl(stream, b);
            }

            if (decl.align_body) |b| {
                try stream.writeAll(" align=");
                try self.writeBracedDecl(stream, b);
            }

            if (decl.linksection_body) |b| {
                try stream.writeAll(" linksection=");
                try self.writeBracedDecl(stream, b);
            }

            if (decl.addrspace_body) |b| {
                try stream.writeAll(" addrspace=");
                try self.writeBracedDecl(stream, b);
            }

            if (decl.value_body) |b| {
                try stream.writeAll(" value=");
                try self.writeBracedDecl(stream, b);
            }
        }

        try stream.writeAll(") ");
        try self.writeSrcNode(stream, .zero);
    }

    fn writeClosureGet(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        try stream.print("{d})) ", .{extended.small});
        const src_node: Ast.Node.Offset = @enumFromInt(@as(i32, @bitCast(extended.operand)));
        try self.writeSrcNode(stream, src_node);
    }

    fn writeBuiltinValue(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const val: Zir.Inst.BuiltinValue = @enumFromInt(extended.small);
        try stream.print("{s})) ", .{@tagName(val)});
        const src_node: Ast.Node.Offset = @enumFromInt(@as(i32, @bitCast(extended.operand)));
        try self.writeSrcNode(stream, src_node);
    }

    fn writeInplaceArithResultTy(self: *Writer, stream: *std.Io.Writer, extended: Zir.Inst.Extended.InstData) !void {
        const op: Zir.Inst.InplaceOp = @enumFromInt(extended.small);
        try self.writeInstRef(stream, @enumFromInt(extended.operand));
        try stream.print(", {s}))", .{@tagName(op)});
    }

    fn writeInstRef(self: *Writer, stream: *std.Io.Writer, ref: Zir.Inst.Ref) !void {
        if (ref == .none) {
            return stream.writeAll(".none");
        } else if (ref.toIndex()) |i| {
            return self.writeInstIndex(stream, i);
        } else {
            const val: InternPool.Index = @enumFromInt(@intFromEnum(ref));
            return stream.print("@{s}", .{@tagName(val)});
        }
    }

    fn writeInstIndex(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        _ = self;
        return stream.print("%{d}", .{@intFromEnum(inst)});
    }

    fn writeCaptures(self: *Writer, stream: *std.Io.Writer, extra_index: usize, captures_len: u32) !usize {
        if (captures_len == 0) {
            try stream.writeAll("{}");
            return extra_index;
        }

        const captures: []const Zir.Inst.Capture = @ptrCast(self.code.extra[extra_index..][0..captures_len]);
        const capture_names: []const Zir.NullTerminatedString = @ptrCast(self.code.extra[extra_index + captures_len ..][0..captures_len]);
        for (captures, capture_names) |capture, name| {
            try stream.writeAll("{ ");
            if (name != .empty) {
                const name_slice = self.code.nullTerminatedString(name);
                try stream.print("{s} = ", .{name_slice});
            }
            try self.writeCapture(stream, capture);
        }

        return extra_index + 2 * captures_len;
    }

    fn writeCapture(self: *Writer, stream: *std.Io.Writer, capture: Zir.Inst.Capture) !void {
        switch (capture.unwrap()) {
            .nested => |i| return stream.print("[{d}]", .{i}),
            .instruction => |inst| return self.writeInstIndex(stream, inst),
            .instruction_load => |ptr_inst| {
                try stream.writeAll("load ");
                try self.writeInstIndex(stream, ptr_inst);
            },
            .decl_val => |str| try stream.print("decl_val \"{f}\"", .{
                std.zig.fmtString(self.code.nullTerminatedString(str)),
            }),
            .decl_ref => |str| try stream.print("decl_ref \"{f}\"", .{
                std.zig.fmtString(self.code.nullTerminatedString(str)),
            }),
        }
    }

    fn writeOptionalInstRef(
        self: *Writer,
        stream: *std.Io.Writer,
        prefix: []const u8,
        inst: Zir.Inst.Ref,
    ) !void {
        if (inst == .none) return;
        try stream.writeAll(prefix);
        try self.writeInstRef(stream, inst);
    }

    fn writeOptionalInstRefOrBody(
        self: *Writer,
        stream: *std.Io.Writer,
        prefix: []const u8,
        ref: Zir.Inst.Ref,
        body: []const Zir.Inst.Index,
    ) !void {
        if (body.len != 0) {
            try stream.writeAll(prefix);
            try self.writeBracedBody(stream, body);
            try stream.writeAll(", ");
        } else if (ref != .none) {
            try stream.writeAll(prefix);
            try self.writeInstRef(stream, ref);
            try stream.writeAll(", ");
        }
    }

    fn writeFlag(
        self: *Writer,
        stream: *std.Io.Writer,
        name: []const u8,
        flag: bool,
    ) !void {
        _ = self;
        if (!flag) return;
        try stream.writeAll(name);
    }

    fn writeSrcNode(self: *Writer, stream: *std.Io.Writer, src_node: Ast.Node.Offset) !void {
        const tree = self.tree orelse return;
        const abs_node = src_node.toAbsolute(self.parent_decl_node);
        const src_span = tree.nodeToSpan(abs_node);
        const start = self.line_col_cursor.find(tree.source, src_span.start);
        const end = self.line_col_cursor.find(tree.source, src_span.end);
        try stream.print("node_offset:{d}:{d} to :{d}:{d}", .{
            start.line + 1, start.column + 1,
            end.line + 1,   end.column + 1,
        });
    }

    fn writeSrcTok(self: *Writer, stream: *std.Io.Writer, src_tok: Ast.TokenOffset) !void {
        const tree = self.tree orelse return;
        const abs_tok = src_tok.toAbsolute(tree.firstToken(self.parent_decl_node));
        const span_start = tree.tokenStart(abs_tok);
        const span_end = span_start + @as(u32, @intCast(tree.tokenSlice(abs_tok).len));
        const start = self.line_col_cursor.find(tree.source, span_start);
        const end = self.line_col_cursor.find(tree.source, span_end);
        try stream.print("token_offset:{d}:{d} to :{d}:{d}", .{
            start.line + 1, start.column + 1,
            end.line + 1,   end.column + 1,
        });
    }

    fn writeSrcTokAbs(self: *Writer, stream: *std.Io.Writer, src_tok: Ast.TokenIndex) !void {
        const tree = self.tree orelse return;
        const span_start = tree.tokenStart(src_tok);
        const span_end = span_start + @as(u32, @intCast(tree.tokenSlice(src_tok).len));
        const start = self.line_col_cursor.find(tree.source, span_start);
        const end = self.line_col_cursor.find(tree.source, span_end);
        try stream.print("token_abs:{d}:{d} to :{d}:{d}", .{
            start.line + 1, start.column + 1,
            end.line + 1,   end.column + 1,
        });
    }

    fn writeBracedDecl(self: *Writer, stream: *std.Io.Writer, body: []const Zir.Inst.Index) !void {
        try self.writeBracedBodyConditional(stream, body, self.recurse_decls);
    }

    fn writeBracedBody(self: *Writer, stream: *std.Io.Writer, body: []const Zir.Inst.Index) !void {
        try self.writeBracedBodyConditional(stream, body, self.recurse_blocks);
    }

    fn writeBracedBodyConditional(self: *Writer, stream: *std.Io.Writer, body: []const Zir.Inst.Index, enabled: bool) !void {
        if (body.len == 0) {
            try stream.writeAll("{}");
        } else if (enabled) {
            try stream.writeAll("{\n");
            self.indent += 2;
            try self.writeBody(stream, body);
            self.indent -= 2;
            try stream.splatByteAll(' ', self.indent);
            try stream.writeAll("}");
        } else if (body.len == 1) {
            try stream.writeByte('{');
            try self.writeInstIndex(stream, body[0]);
            try stream.writeByte('}');
        } else if (body.len == 2) {
            try stream.writeByte('{');
            try self.writeInstIndex(stream, body[0]);
            try stream.writeAll(", ");
            try self.writeInstIndex(stream, body[1]);
            try stream.writeByte('}');
        } else {
            try stream.writeByte('{');
            try self.writeInstIndex(stream, body[0]);
            try stream.writeAll("..");
            try self.writeInstIndex(stream, body[body.len - 1]);
            try stream.writeByte('}');
        }
    }

    fn writeBody(self: *Writer, stream: *std.Io.Writer, body: []const Zir.Inst.Index) !void {
        for (body) |inst| {
            try stream.splatByteAll(' ', self.indent);
            try stream.print("%{d} ", .{@intFromEnum(inst)});
            try self.writeInstToStream(stream, inst);
            try stream.writeByte('\n');
        }
    }

    fn writeImport(self: *Writer, stream: *std.Io.Writer, inst: Zir.Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[@intFromEnum(inst)].pl_tok;
        const extra = self.code.extraData(Zir.Inst.Import, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.res_ty);
        const import_path = self.code.nullTerminatedString(extra.path);
        try stream.print(", \"{f}\") ", .{std.zig.fmtString(import_path)});
        try self.writeSrcTok(stream, inst_data.src_tok);
    }
};
