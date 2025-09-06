pt: Zcu.PerThread,
target: *const std.Target,
air: Air,
nav_index: InternPool.Nav.Index,

// Blocks
def_order: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, void),
blocks: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, Block),
loops: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, Loop),
active_loops: std.ArrayListUnmanaged(Loop.Index),
loop_live: struct {
    set: std.AutoArrayHashMapUnmanaged(struct { Loop.Index, Air.Inst.Index }, void),
    list: std.ArrayListUnmanaged(Air.Inst.Index),
},
dom_start: u32,
dom_len: u32,
dom: std.ArrayListUnmanaged(DomInt),

// Wip Mir
saved_registers: std.enums.EnumSet(Register.Alias),
instructions: std.ArrayListUnmanaged(codegen.aarch64.encoding.Instruction),
literals: std.ArrayListUnmanaged(u32),
nav_relocs: std.ArrayListUnmanaged(codegen.aarch64.Mir.Reloc.Nav),
uav_relocs: std.ArrayListUnmanaged(codegen.aarch64.Mir.Reloc.Uav),
lazy_relocs: std.ArrayListUnmanaged(codegen.aarch64.Mir.Reloc.Lazy),
global_relocs: std.ArrayListUnmanaged(codegen.aarch64.Mir.Reloc.Global),
literal_relocs: std.ArrayListUnmanaged(codegen.aarch64.Mir.Reloc.Literal),

// Stack Frame
returns: bool,
va_list: union(enum) {
    other: Value.Indirect,
    sysv: struct {
        __stack: Value.Indirect,
        __gr_top: Value.Indirect,
        __vr_top: Value.Indirect,
        __gr_offs: i32,
        __vr_offs: i32,
    },
},
stack_size: u24,
stack_align: InternPool.Alignment,

// Value Tracking
live_registers: LiveRegisters,
live_values: std.AutoHashMapUnmanaged(Air.Inst.Index, Value.Index),
values: std.ArrayListUnmanaged(Value),

pub const LiveRegisters = std.enums.EnumArray(Register.Alias, Value.Index);

pub const Block = struct {
    live_registers: LiveRegisters,
    target_label: u32,

    pub const main: Air.Inst.Index = @enumFromInt(
        std.math.maxInt(@typeInfo(Air.Inst.Index).@"enum".tag_type),
    );

    fn branch(target_block: *const Block, isel: *Select) !void {
        if (isel.instructions.items.len > target_block.target_label) {
            try isel.emit(.b(@intCast((isel.instructions.items.len + 1 - target_block.target_label) << 2)));
        }
        try isel.merge(&target_block.live_registers, .{});
    }
};

pub const Loop = struct {
    def_order: u32,
    dom: u32,
    depth: u32,
    live: u32,
    live_registers: LiveRegisters,
    repeat_list: u32,

    pub const invalid: Air.Inst.Index = @enumFromInt(
        std.math.maxInt(@typeInfo(Air.Inst.Index).@"enum".tag_type),
    );

    pub const Index = enum(u32) {
        _,

        fn inst(li: Loop.Index, isel: *Select) Air.Inst.Index {
            return isel.loops.keys()[@intFromEnum(li)];
        }

        fn get(li: Loop.Index, isel: *Select) *Loop {
            return &isel.loops.values()[@intFromEnum(li)];
        }
    };

    pub const empty_list: u32 = std.math.maxInt(u32);

    fn branch(target_loop: *Loop, isel: *Select) !void {
        try isel.instructions.ensureUnusedCapacity(isel.pt.zcu.gpa, 1);
        const repeat_list_tail = target_loop.repeat_list;
        target_loop.repeat_list = @intCast(isel.instructions.items.len);
        isel.instructions.appendAssumeCapacity(@bitCast(repeat_list_tail));
        try isel.merge(&target_loop.live_registers, .{});
    }
};

pub fn deinit(isel: *Select) void {
    const gpa = isel.pt.zcu.gpa;

    isel.def_order.deinit(gpa);
    isel.blocks.deinit(gpa);
    isel.loops.deinit(gpa);
    isel.active_loops.deinit(gpa);
    isel.loop_live.set.deinit(gpa);
    isel.loop_live.list.deinit(gpa);
    isel.dom.deinit(gpa);

    isel.instructions.deinit(gpa);
    isel.literals.deinit(gpa);
    isel.nav_relocs.deinit(gpa);
    isel.uav_relocs.deinit(gpa);
    isel.lazy_relocs.deinit(gpa);
    isel.global_relocs.deinit(gpa);
    isel.literal_relocs.deinit(gpa);

    isel.live_values.deinit(gpa);
    isel.values.deinit(gpa);

    isel.* = undefined;
}

pub fn analyze(isel: *Select, air_body: []const Air.Inst.Index) !void {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const air_tags = isel.air.instructions.items(.tag);
    const air_data = isel.air.instructions.items(.data);
    var air_body_index: usize = 0;
    var air_inst_index = air_body[air_body_index];
    const initial_def_order_len = isel.def_order.count();
    air_tag: switch (air_tags[@intFromEnum(air_inst_index)]) {
        .arg,
        .ret_addr,
        .frame_addr,
        .err_return_trace,
        .save_err_return_trace_index,
        .runtime_nav_ptr,
        .c_va_start,
        => {
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
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
        .max,
        .min,
        .bit_and,
        .bit_or,
        .shr,
        .shr_exact,
        .shl,
        .shl_exact,
        .shl_sat,
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
        .array_elem_val,
        .slice_elem_val,
        .ptr_elem_val,
        => {
            const bin_op = air_data[@intFromEnum(air_inst_index)].bin_op;

            try isel.analyzeUse(bin_op.lhs);
            try isel.analyzeUse(bin_op.rhs);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .ptr_add,
        .ptr_sub,
        .add_with_overflow,
        .sub_with_overflow,
        .mul_with_overflow,
        .shl_with_overflow,
        .slice,
        .slice_elem_ptr,
        .ptr_elem_ptr,
        => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;

            try isel.analyzeUse(bin_op.lhs);
            try isel.analyzeUse(bin_op.rhs);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .alloc => {
            const ty = air_data[@intFromEnum(air_inst_index)].ty;

            isel.stack_align = isel.stack_align.maxStrict(ty.ptrAlignment(zcu));
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .inferred_alloc,
        .inferred_alloc_comptime,
        .wasm_memory_size,
        .wasm_memory_grow,
        .work_item_id,
        .work_group_size,
        .work_group_id,
        => unreachable,
        .ret_ptr => {
            const ty = air_data[@intFromEnum(air_inst_index)].ty;

            if (isel.live_values.get(Block.main)) |ret_vi| switch (ret_vi.parent(isel)) {
                .unallocated, .stack_slot => isel.stack_align = isel.stack_align.maxStrict(ty.ptrAlignment(zcu)),
                .value, .constant => unreachable,
                .address => |address_vi| try isel.live_values.putNoClobber(gpa, air_inst_index, address_vi.ref(isel)),
            };
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .assembly => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.Asm, ty_pl.payload);
            const operands: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[extra.end..][0 .. extra.data.flags.outputs_len + extra.data.inputs_len]);

            for (operands) |operand| if (operand != .none) try isel.analyzeUse(operand);
            if (ty_pl.ty != .void_type) try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .not,
        .clz,
        .ctz,
        .popcount,
        .byte_swap,
        .bit_reverse,
        .abs,
        .load,
        .fptrunc,
        .fpext,
        .intcast,
        .intcast_safe,
        .trunc,
        .optional_payload,
        .optional_payload_ptr,
        .optional_payload_ptr_set,
        .wrap_optional,
        .unwrap_errunion_payload,
        .unwrap_errunion_err,
        .unwrap_errunion_payload_ptr,
        .unwrap_errunion_err_ptr,
        .errunion_payload_ptr_set,
        .wrap_errunion_payload,
        .wrap_errunion_err,
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        .get_union_tag,
        .ptr_slice_len_ptr,
        .ptr_slice_ptr_ptr,
        .array_to_slice,
        .int_from_float,
        .int_from_float_optimized,
        .int_from_float_safe,
        .int_from_float_optimized_safe,
        .float_from_int,
        .splat,
        .error_set_has_value,
        .addrspace_cast,
        .c_va_arg,
        .c_va_copy,
        => {
            const ty_op = air_data[@intFromEnum(air_inst_index)].ty_op;

            try isel.analyzeUse(ty_op.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .bitcast => {
            const ty_op = air_data[@intFromEnum(air_inst_index)].ty_op;
            maybe_noop: {
                if (ty_op.ty.toInterned().? != isel.air.typeOf(ty_op.operand, ip).toIntern()) break :maybe_noop;
                if (true) break :maybe_noop;
                if (ty_op.operand.toIndex()) |src_air_inst_index| {
                    if (isel.hints.get(src_air_inst_index)) |hint_vpsi| {
                        try isel.hints.putNoClobber(gpa, air_inst_index, hint_vpsi);
                    }
                }
            }
            try isel.analyzeUse(ty_op.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        inline .block, .dbg_inline_block => |air_tag| {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(switch (air_tag) {
                else => comptime unreachable,
                .block => Air.Block,
                .dbg_inline_block => Air.DbgInlineBlock,
            }, ty_pl.payload);
            const result_ty = ty_pl.ty.toInterned().?;

            if (result_ty == .noreturn_type) {
                try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));

                air_body_index += 1;
                break :air_tag;
            }

            assert(!(try isel.blocks.getOrPut(gpa, air_inst_index)).found_existing);
            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            const block_entry = isel.blocks.pop().?;
            assert(block_entry.key == air_inst_index);

            if (result_ty != .void_type) try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .loop => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.Block, ty_pl.payload);

            const initial_dom_start = isel.dom_start;
            const initial_dom_len = isel.dom_len;
            isel.dom_start = @intCast(isel.dom.items.len);
            isel.dom_len = @intCast(isel.blocks.count());
            try isel.active_loops.append(gpa, @enumFromInt(isel.loops.count()));
            try isel.loops.putNoClobber(gpa, air_inst_index, .{
                .def_order = @intCast(isel.def_order.count()),
                .dom = isel.dom_start,
                .depth = isel.dom_len,
                .live = 0,
                .live_registers = undefined,
                .repeat_list = undefined,
            });
            try isel.dom.appendNTimes(gpa, 0, std.math.divCeil(usize, isel.dom_len, @bitSizeOf(DomInt)) catch unreachable);
            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            for (
                isel.dom.items[initial_dom_start..].ptr,
                isel.dom.items[isel.dom_start..][0 .. std.math.divCeil(usize, initial_dom_len, @bitSizeOf(DomInt)) catch unreachable],
            ) |*initial_dom, loop_dom| initial_dom.* |= loop_dom;
            isel.dom_start = initial_dom_start;
            isel.dom_len = initial_dom_len;
            assert(isel.active_loops.pop().?.inst(isel) == air_inst_index);

            air_body_index += 1;
        },
        .repeat, .trap, .unreach => air_body_index += 1,
        .br => {
            const br = air_data[@intFromEnum(air_inst_index)].br;
            const block_index = isel.blocks.getIndex(br.block_inst).?;
            if (block_index < isel.dom_len) isel.dom.items[isel.dom_start + block_index / @bitSizeOf(DomInt)] |= @as(DomInt, 1) << @truncate(block_index);
            try isel.analyzeUse(br.operand);

            air_body_index += 1;
        },
        .breakpoint, .dbg_stmt, .dbg_empty_stmt, .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline, .c_va_end => {
            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .call,
        .call_always_tail,
        .call_never_tail,
        .call_never_inline,
        => {
            const pl_op = air_data[@intFromEnum(air_inst_index)].pl_op;
            const extra = isel.air.extraData(Air.Call, pl_op.payload);
            const args: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[extra.end..][0..extra.data.args_len]);
            isel.saved_registers.insert(.lr);
            const callee_ty = isel.air.typeOf(pl_op.operand, ip);
            const func_info = switch (ip.indexToKey(callee_ty.toIntern())) {
                else => unreachable,
                .func_type => |func_type| func_type,
                .ptr_type => |ptr_type| ip.indexToKey(ptr_type.child).func_type,
            };

            try isel.analyzeUse(pl_op.operand);
            var param_it: CallAbiIterator = .init;
            for (args, 0..) |arg, arg_index| {
                const restore_values_len = isel.values.items.len;
                defer isel.values.shrinkRetainingCapacity(restore_values_len);
                const param_vi = param_vi: {
                    const param_ty = isel.air.typeOf(arg, ip);
                    if (arg_index >= func_info.param_types.len) {
                        assert(func_info.is_var_args);
                        switch (isel.va_list) {
                            .other => break :param_vi try param_it.nonSysvVarArg(isel, param_ty),
                            .sysv => {},
                        }
                    }
                    break :param_vi try param_it.param(isel, param_ty);
                } orelse continue;
                defer param_vi.deref(isel);
                const passed_vi = switch (param_vi.parent(isel)) {
                    .unallocated, .stack_slot => param_vi,
                    .value, .constant => unreachable,
                    .address => |address_vi| address_vi,
                };
                switch (passed_vi.parent(isel)) {
                    .unallocated => {},
                    .stack_slot => |stack_slot| {
                        assert(stack_slot.base == .sp);
                        isel.stack_size = @max(
                            isel.stack_size,
                            stack_slot.offset + @as(u24, @intCast(passed_vi.size(isel))),
                        );
                    },
                    .value, .constant, .address => unreachable,
                }

                try isel.analyzeUse(arg);
            }

            var ret_it: CallAbiIterator = .init;
            if (try ret_it.ret(isel, isel.air.typeOfIndex(air_inst_index, ip))) |ret_vi| {
                tracking_log.debug("${d} <- %{d}", .{ @intFromEnum(ret_vi), @intFromEnum(air_inst_index) });
                switch (ret_vi.parent(isel)) {
                    .unallocated, .stack_slot => {},
                    .value, .constant => unreachable,
                    .address => |address_vi| {
                        defer address_vi.deref(isel);
                        const ret_value = ret_vi.get(isel);
                        ret_value.flags.parent_tag = .unallocated;
                        ret_value.parent_payload = .{ .unallocated = {} };
                    },
                }
                try isel.live_values.putNoClobber(gpa, air_inst_index, ret_vi);

                try isel.def_order.putNoClobber(gpa, air_inst_index, {});
            }

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
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
        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,
        .is_err,
        .is_non_err,
        .is_err_ptr,
        .is_non_err_ptr,
        .is_named_enum_value,
        .tag_name,
        .error_name,
        .cmp_lt_errors_len,
        => {
            const un_op = air_data[@intFromEnum(air_inst_index)].un_op;

            try isel.analyzeUse(un_op);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .cmp_vector, .cmp_vector_optimized => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.VectorCmp, ty_pl.payload).data;

            try isel.analyzeUse(extra.lhs);
            try isel.analyzeUse(extra.rhs);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .cond_br => {
            const pl_op = air_data[@intFromEnum(air_inst_index)].pl_op;
            const extra = isel.air.extraData(Air.CondBr, pl_op.payload);

            try isel.analyzeUse(pl_op.operand);

            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.then_body_len]));
            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end + extra.data.then_body_len ..][0..extra.data.else_body_len]));

            air_body_index += 1;
        },
        .switch_br => {
            const switch_br = isel.air.unwrapSwitch(air_inst_index);

            try isel.analyzeUse(switch_br.operand);

            var cases_it = switch_br.iterateCases();
            while (cases_it.next()) |case| try isel.analyze(case.body);
            if (switch_br.else_body_len > 0) try isel.analyze(cases_it.elseBody());

            air_body_index += 1;
        },
        .loop_switch_br => {
            const switch_br = isel.air.unwrapSwitch(air_inst_index);

            const initial_dom_start = isel.dom_start;
            const initial_dom_len = isel.dom_len;
            isel.dom_start = @intCast(isel.dom.items.len);
            isel.dom_len = @intCast(isel.blocks.count());
            try isel.active_loops.append(gpa, @enumFromInt(isel.loops.count()));
            try isel.loops.putNoClobber(gpa, air_inst_index, .{
                .def_order = @intCast(isel.def_order.count()),
                .dom = isel.dom_start,
                .depth = isel.dom_len,
                .live = 0,
                .live_registers = undefined,
                .repeat_list = undefined,
            });
            try isel.dom.appendNTimes(gpa, 0, std.math.divCeil(usize, isel.dom_len, @bitSizeOf(DomInt)) catch unreachable);

            var cases_it = switch_br.iterateCases();
            while (cases_it.next()) |case| try isel.analyze(case.body);
            if (switch_br.else_body_len > 0) try isel.analyze(cases_it.elseBody());

            for (
                isel.dom.items[initial_dom_start..].ptr,
                isel.dom.items[isel.dom_start..][0 .. std.math.divCeil(usize, initial_dom_len, @bitSizeOf(DomInt)) catch unreachable],
            ) |*initial_dom, loop_dom| initial_dom.* |= loop_dom;
            isel.dom_start = initial_dom_start;
            isel.dom_len = initial_dom_len;
            assert(isel.active_loops.pop().?.inst(isel) == air_inst_index);

            air_body_index += 1;
        },
        .switch_dispatch => {
            const br = air_data[@intFromEnum(air_inst_index)].br;

            try isel.analyzeUse(br.operand);

            air_body_index += 1;
        },
        .@"try", .try_cold => {
            const pl_op = air_data[@intFromEnum(air_inst_index)].pl_op;
            const extra = isel.air.extraData(Air.Try, pl_op.payload);

            try isel.analyzeUse(pl_op.operand);
            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .try_ptr, .try_ptr_cold => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.TryPtr, ty_pl.payload);

            try isel.analyzeUse(extra.data.ptr);
            try isel.analyze(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .ret, .ret_safe, .ret_load => {
            const un_op = air_data[@intFromEnum(air_inst_index)].un_op;
            isel.returns = true;

            const block_index = 0;
            assert(isel.blocks.keys()[block_index] == Block.main);
            if (isel.dom_len > 0) isel.dom.items[isel.dom_start] |= 1 << block_index;

            try isel.analyzeUse(un_op);

            air_body_index += 1;
        },
        .store,
        .store_safe,
        .set_union_tag,
        .memset,
        .memset_safe,
        .memcpy,
        .memmove,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        => {
            const bin_op = air_data[@intFromEnum(air_inst_index)].bin_op;

            try isel.analyzeUse(bin_op.lhs);
            try isel.analyzeUse(bin_op.rhs);

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .struct_field_ptr, .struct_field_val => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.StructField, ty_pl.payload).data;

            try isel.analyzeUse(extra.struct_operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .slice_len => {
            const ty_op = air_data[@intFromEnum(air_inst_index)].ty_op;

            try isel.analyzeUse(ty_op.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            const slice_vi = try isel.use(ty_op.operand);
            var len_part_it = slice_vi.field(isel.air.typeOf(ty_op.operand, ip), 8, 8);
            if (try len_part_it.only(isel)) |len_part_vi|
                try isel.live_values.putNoClobber(gpa, air_inst_index, len_part_vi.ref(isel));

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .slice_ptr => {
            const ty_op = air_data[@intFromEnum(air_inst_index)].ty_op;

            try isel.analyzeUse(ty_op.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            const slice_vi = try isel.use(ty_op.operand);
            var ptr_part_it = slice_vi.field(isel.air.typeOf(ty_op.operand, ip), 0, 8);
            if (try ptr_part_it.only(isel)) |ptr_part_vi|
                try isel.live_values.putNoClobber(gpa, air_inst_index, ptr_part_vi.ref(isel));

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .reduce, .reduce_optimized => {
            const reduce = air_data[@intFromEnum(air_inst_index)].reduce;

            try isel.analyzeUse(reduce.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .shuffle_one => {
            const extra = isel.air.unwrapShuffleOne(zcu, air_inst_index);

            try isel.analyzeUse(extra.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .shuffle_two => {
            const extra = isel.air.unwrapShuffleTwo(zcu, air_inst_index);

            try isel.analyzeUse(extra.operand_a);
            try isel.analyzeUse(extra.operand_b);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .select, .mul_add => {
            const pl_op = air_data[@intFromEnum(air_inst_index)].pl_op;
            const bin_op = isel.air.extraData(Air.Bin, pl_op.payload).data;

            try isel.analyzeUse(pl_op.operand);
            try isel.analyzeUse(bin_op.lhs);
            try isel.analyzeUse(bin_op.rhs);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .cmpxchg_weak, .cmpxchg_strong => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

            try isel.analyzeUse(extra.ptr);
            try isel.analyzeUse(extra.expected_value);
            try isel.analyzeUse(extra.new_value);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .atomic_load => {
            const atomic_load = air_data[@intFromEnum(air_inst_index)].atomic_load;

            try isel.analyzeUse(atomic_load.ptr);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .atomic_rmw => {
            const pl_op = air_data[@intFromEnum(air_inst_index)].pl_op;
            const extra = isel.air.extraData(Air.AtomicRmw, pl_op.payload).data;

            try isel.analyzeUse(extra.operand);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .aggregate_init => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const elements: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[ty_pl.payload..][0..@intCast(ty_pl.ty.toType().arrayLen(zcu))]);

            for (elements) |element| try isel.analyzeUse(element);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .union_init => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.UnionInit, ty_pl.payload).data;

            try isel.analyzeUse(extra.init);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .prefetch => {
            const prefetch = air_data[@intFromEnum(air_inst_index)].prefetch;

            try isel.analyzeUse(prefetch.ptr);

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .field_parent_ptr => {
            const ty_pl = air_data[@intFromEnum(air_inst_index)].ty_pl;
            const extra = isel.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

            try isel.analyzeUse(extra.field_ptr);
            try isel.def_order.putNoClobber(gpa, air_inst_index, {});

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .set_err_return_trace => {
            const un_op = air_data[@intFromEnum(air_inst_index)].un_op;

            try isel.analyzeUse(un_op);

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
        .vector_store_elem => {
            const vector_store_elem = air_data[@intFromEnum(air_inst_index)].vector_store_elem;
            const bin_op = isel.air.extraData(Air.Bin, vector_store_elem.payload).data;

            try isel.analyzeUse(vector_store_elem.vector_ptr);
            try isel.analyzeUse(bin_op.lhs);
            try isel.analyzeUse(bin_op.rhs);

            air_body_index += 1;
            air_inst_index = air_body[air_body_index];
            continue :air_tag air_tags[@intFromEnum(air_inst_index)];
        },
    }
    assert(air_body_index == air_body.len);
    isel.def_order.shrinkRetainingCapacity(initial_def_order_len);
}

fn analyzeUse(isel: *Select, air_ref: Air.Inst.Ref) !void {
    const air_inst_index = air_ref.toIndex() orelse return;
    const def_order_index = isel.def_order.getIndex(air_inst_index).?;

    // Loop liveness
    var active_loop_index = isel.active_loops.items.len;
    while (active_loop_index > 0) {
        const prev_active_loop_index = active_loop_index - 1;
        const active_loop = isel.active_loops.items[prev_active_loop_index];
        if (def_order_index >= active_loop.get(isel).def_order) break;
        active_loop_index = prev_active_loop_index;
    }
    if (active_loop_index < isel.active_loops.items.len) {
        const active_loop = isel.active_loops.items[active_loop_index];
        const loop_live_gop =
            try isel.loop_live.set.getOrPut(isel.pt.zcu.gpa, .{ active_loop, air_inst_index });
        if (!loop_live_gop.found_existing) active_loop.get(isel).live += 1;
    }
}

pub fn finishAnalysis(isel: *Select) !void {
    const gpa = isel.pt.zcu.gpa;

    // Loop Liveness
    if (isel.loops.count() > 0) {
        try isel.loops.ensureUnusedCapacity(gpa, 1);

        const loop_live_len: u32 = @intCast(isel.loop_live.set.count());
        if (loop_live_len > 0) {
            try isel.loop_live.list.resize(gpa, loop_live_len);

            const loops = isel.loops.values();
            for (loops[1..], loops[0 .. loops.len - 1]) |*loop, prev_loop| loop.live += prev_loop.live;
            assert(loops[loops.len - 1].live == loop_live_len);

            for (isel.loop_live.set.keys()) |entry| {
                const loop, const inst = entry;
                const loop_live = &loop.get(isel).live;
                loop_live.* -= 1;
                isel.loop_live.list.items[loop_live.*] = inst;
            }
            assert(loops[0].live == 0);
        }

        const invalid_gop = isel.loops.getOrPutAssumeCapacity(Loop.invalid);
        assert(!invalid_gop.found_existing);
        invalid_gop.value_ptr.live = loop_live_len;
    }
}

pub fn body(isel: *Select, air_body: []const Air.Inst.Index) error{ OutOfMemory, CodegenFail }!void {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;

    {
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| switch (live_reg_entry.value.*) {
            _ => {
                const ra = &live_reg_entry.value.get(isel).location_payload.small.register;
                assert(ra.* == live_reg_entry.key);
                ra.* = .zr;
                live_reg_entry.value.* = .free;
            },
            .allocating => live_reg_entry.value.* = .free,
            .free => {},
        };
    }

    var air: struct {
        isel: *Select,
        tag_items: []const Air.Inst.Tag,
        data_items: []const Air.Inst.Data,
        body: []const Air.Inst.Index,
        body_index: u32,
        inst_index: Air.Inst.Index,

        fn tag(it: *@This(), inst_index: Air.Inst.Index) Air.Inst.Tag {
            return it.tag_items[@intFromEnum(inst_index)];
        }

        fn data(it: *@This(), inst_index: Air.Inst.Index) Air.Inst.Data {
            return it.data_items[@intFromEnum(inst_index)];
        }

        fn next(it: *@This()) ?Air.Inst.Tag {
            if (it.body_index == 0) {
                @branchHint(.unlikely);
                return null;
            }
            it.body_index -= 1;
            it.inst_index = it.body[it.body_index];
            wip_mir_log.debug("{f}", .{it.fmtAir(it.inst_index)});
            return it.tag(it.inst_index);
        }

        fn fmtAir(it: @This(), inst: Air.Inst.Index) struct {
            isel: *Select,
            inst: Air.Inst.Index,
            pub fn format(fmt_air: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
                fmt_air.isel.air.writeInst(writer, fmt_air.inst, fmt_air.isel.pt, null);
            }
        } {
            return .{ .isel = it.isel, .inst = inst };
        }
    } = .{
        .isel = isel,
        .tag_items = isel.air.instructions.items(.tag),
        .data_items = isel.air.instructions.items(.data),
        .body = air_body,
        .body_index = @intCast(air_body.len),
        .inst_index = undefined,
    };
    air_tag: switch (air.next().?) {
        else => |air_tag| return isel.fail("unimplemented {s}", .{@tagName(air_tag)}),
        .arg => {
            const arg_vi = isel.live_values.fetchRemove(air.inst_index).?.value;
            defer arg_vi.deref(isel);
            switch (arg_vi.parent(isel)) {
                .unallocated, .stack_slot => if (arg_vi.hint(isel)) |arg_ra| {
                    try arg_vi.defLiveIn(isel, arg_ra, comptime &.initFill(.free));
                } else {
                    var arg_part_it = arg_vi.parts(isel);
                    while (arg_part_it.next()) |arg_part| {
                        try arg_part.defLiveIn(isel, arg_part.hint(isel).?, comptime &.initFill(.free));
                    }
                },
                .value, .constant => unreachable,
                .address => |address_vi| try address_vi.defLiveIn(isel, address_vi.hint(isel).?, comptime &.initFill(.free)),
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .add, .add_safe, .add_optimized, .add_wrap, .sub, .sub_safe, .sub_optimized, .sub_wrap => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) try res_vi.value.addOrSubtract(isel, ty, try isel.use(bin_op.lhs), switch (air_tag) {
                    else => unreachable,
                    .add, .add_safe, .add_wrap => .add,
                    .sub, .sub_safe, .sub_wrap => .sub,
                }, try isel.use(bin_op.rhs), .{
                    .overflow = switch (air_tag) {
                        else => unreachable,
                        .add, .sub => .@"unreachable",
                        .add_safe, .sub_safe => .{ .panic = .integer_overflow },
                        .add_wrap, .sub_wrap => .wrap,
                    },
                }) else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt) continue :bits 32 else switch (air_tag) {
                                else => unreachable,
                                .add, .add_optimized => .fadd(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                                .sub, .sub_optimized => .fsub(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                            },
                            32 => switch (air_tag) {
                                else => unreachable,
                                .add, .add_optimized => .fadd(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                                .sub, .sub_optimized => .fsub(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                            },
                            64 => switch (air_tag) {
                                else => unreachable,
                                .add, .add_optimized => .fadd(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                                .sub, .sub_optimized => .fsub(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                            },
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (air_tag) {
                                else => unreachable,
                                .add, .add_optimized => switch (bits) {
                                    else => unreachable,
                                    16 => "__addhf3",
                                    32 => "__addsf3",
                                    64 => "__adddf3",
                                    80 => "__addxf3",
                                    128 => "__addtf3",
                                },
                                .sub, .sub_optimized => switch (bits) {
                                    else => unreachable,
                                    16 => "__subhf3",
                                    32 => "__subsf3",
                                    64 => "__subdf3",
                                    80 => "__subxf3",
                                    128 => "__subtf3",
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .add_sat, .sub_sat => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.bits) {
                    0 => unreachable,
                    32, 64 => |bits| switch (int_info.signedness) {
                        .signed => return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                        .unsigned => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            const unsat_res_ra = try isel.allocIntReg();
                            defer isel.freeReg(unsat_res_ra);
                            switch (air_tag) {
                                else => unreachable,
                                .add_sat => switch (bits) {
                                    else => unreachable,
                                    32 => {
                                        try isel.emit(.csinv(res_ra.w(), unsat_res_ra.w(), .wzr, .invert(.cs)));
                                        try isel.emit(.adds(unsat_res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                                    },
                                    64 => {
                                        try isel.emit(.csinv(res_ra.x(), unsat_res_ra.x(), .xzr, .invert(.cs)));
                                        try isel.emit(.adds(unsat_res_ra.x(), lhs_mat.ra.x(), .{ .register = rhs_mat.ra.x() }));
                                    },
                                },
                                .sub_sat => switch (bits) {
                                    else => unreachable,
                                    32 => {
                                        try isel.emit(.csel(res_ra.w(), unsat_res_ra.w(), .wzr, .invert(.cc)));
                                        try isel.emit(.subs(unsat_res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                                    },
                                    64 => {
                                        try isel.emit(.csel(res_ra.x(), unsat_res_ra.x(), .xzr, .invert(.cc)));
                                        try isel.emit(.subs(unsat_res_ra.x(), lhs_mat.ra.x(), .{ .register = rhs_mat.ra.x() }));
                                    },
                                },
                            }
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .mul, .mul_optimized, .mul_wrap => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) {
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    const int_info = ty.intInfo(zcu);
                    switch (int_info.bits) {
                        0 => unreachable,
                        1 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            switch (int_info.signedness) {
                                .signed => switch (air_tag) {
                                    else => unreachable,
                                    .mul => break :unused try isel.emit(.orr(res_ra.w(), .wzr, .{ .register = .wzr })),
                                    .mul_wrap => {},
                                },
                                .unsigned => {},
                            }
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.@"and"(res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        2...32 => |bits| {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            switch (air_tag) {
                                else => unreachable,
                                .mul => {},
                                .mul_wrap => switch (bits) {
                                    else => unreachable,
                                    1...31 => try isel.emit(switch (int_info.signedness) {
                                        .signed => .sbfm(res_ra.w(), res_ra.w(), .{
                                            .N = .word,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                        .unsigned => .ubfm(res_ra.w(), res_ra.w(), .{
                                            .N = .word,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                    }),
                                    32 => {},
                                },
                            }
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.madd(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w(), .wzr));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        33...64 => |bits| {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            switch (air_tag) {
                                else => unreachable,
                                .mul => {},
                                .mul_wrap => switch (bits) {
                                    else => unreachable,
                                    33...63 => try isel.emit(switch (int_info.signedness) {
                                        .signed => .sbfm(res_ra.x(), res_ra.x(), .{
                                            .N = .doubleword,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                        .unsigned => .ubfm(res_ra.x(), res_ra.x(), .{
                                            .N = .doubleword,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                    }),
                                    64 => {},
                                },
                            }
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.madd(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), .xzr));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        65...128 => |bits| {
                            var res_hi64_it = res_vi.value.field(ty, 8, 8);
                            const res_hi64_vi = try res_hi64_it.only(isel);
                            const res_hi64_ra = try res_hi64_vi.?.defReg(isel);
                            var res_lo64_it = res_vi.value.field(ty, 0, 8);
                            const res_lo64_vi = try res_lo64_it.only(isel);
                            const res_lo64_ra = try res_lo64_vi.?.defReg(isel);
                            if (res_hi64_ra == null and res_lo64_ra == null) break :unused;
                            if (res_hi64_ra) |res_ra| switch (air_tag) {
                                else => unreachable,
                                .mul => {},
                                .mul_wrap => switch (bits) {
                                    else => unreachable,
                                    65...127 => try isel.emit(switch (int_info.signedness) {
                                        .signed => .sbfm(res_ra.x(), res_ra.x(), .{
                                            .N = .doubleword,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                        .unsigned => .ubfm(res_ra.x(), res_ra.x(), .{
                                            .N = .doubleword,
                                            .immr = 0,
                                            .imms = @intCast(bits - 1),
                                        }),
                                    }),
                                    128 => {},
                                },
                            };
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_lo64_mat, const rhs_lo64_mat = lo64_mat: {
                                const res_hi64_lock: RegLock = if (res_hi64_ra != null and res_lo64_ra != null)
                                    isel.lockReg(res_hi64_ra.?)
                                else
                                    .empty;
                                defer res_hi64_lock.unlock(isel);

                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                const rhs_lo64_mat = try rhs_lo64_vi.?.matReg(isel);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                const lhs_lo64_mat = try lhs_lo64_vi.?.matReg(isel);
                                break :lo64_mat .{ lhs_lo64_mat, rhs_lo64_mat };
                            };
                            if (res_lo64_ra) |res_ra| try isel.emit(.madd(res_ra.x(), lhs_lo64_mat.ra.x(), rhs_lo64_mat.ra.x(), .xzr));
                            if (res_hi64_ra) |res_ra| {
                                var rhs_hi64_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi64_vi = try rhs_hi64_it.only(isel);
                                const rhs_hi64_mat = try rhs_hi64_vi.?.matReg(isel);
                                var lhs_hi64_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi64_vi = try lhs_hi64_it.only(isel);
                                const lhs_hi64_mat = try lhs_hi64_vi.?.matReg(isel);
                                const acc_ra = try isel.allocIntReg();
                                defer isel.freeReg(acc_ra);
                                try isel.emit(.madd(res_ra.x(), lhs_hi64_mat.ra.x(), rhs_lo64_mat.ra.x(), acc_ra.x()));
                                try isel.emit(.madd(acc_ra.x(), lhs_lo64_mat.ra.x(), rhs_hi64_mat.ra.x(), acc_ra.x()));
                                try isel.emit(.umulh(acc_ra.x(), lhs_lo64_mat.ra.x(), rhs_lo64_mat.ra.x()));
                                try rhs_hi64_mat.finish(isel);
                                try lhs_hi64_mat.finish(isel);
                            }
                            try rhs_lo64_mat.finish(isel);
                            try lhs_lo64_mat.finish(isel);
                        },
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                    }
                } else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt)
                                continue :bits 32
                            else
                                .fmul(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                            32 => .fmul(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                            64 => .fmul(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (bits) {
                                else => unreachable,
                                16 => "__mulhf3",
                                32 => "__mulsf3",
                                64 => "__muldf3",
                                80 => "__mulxf3",
                                128 => "__multf3",
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .mul_safe => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.signedness) {
                    .signed => switch (int_info.bits) {
                        0 => unreachable,
                        1 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.orr(res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(.integer_overflow);
                            try isel.emit(.@"b."(
                                .invert(.ne),
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                            try isel.emit(.ands(.wzr, lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                    },
                    .unsigned => switch (int_info.bits) {
                        0 => unreachable,
                        1 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.@"and"(res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        2...16 => |bits| {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(.integer_overflow);
                            try isel.emit(.@"b."(
                                .eq,
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                            try isel.emit(.ands(.wzr, res_ra.w(), .{ .immediate = .{
                                .N = .word,
                                .immr = @intCast(32 - bits),
                                .imms = @intCast(32 - bits - 1),
                            } }));
                            try isel.emit(.madd(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w(), .wzr));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        17...32 => |bits| {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(.integer_overflow);
                            try isel.emit(.@"b."(
                                .eq,
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                            try isel.emit(.ands(.xzr, res_ra.x(), .{ .immediate = .{
                                .N = .doubleword,
                                .immr = @intCast(64 - bits),
                                .imms = @intCast(64 - bits - 1),
                            } }));
                            try isel.emit(.umaddl(res_ra.x(), lhs_mat.ra.w(), rhs_mat.ra.w(), .xzr));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        33...63 => |bits| {
                            const lo64_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            const hi64_ra = hi64_ra: {
                                const lo64_lock = isel.tryLockReg(lo64_ra);
                                defer lo64_lock.unlock(isel);
                                break :hi64_ra try isel.allocIntReg();
                            };
                            defer isel.freeReg(hi64_ra);
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(.integer_overflow);
                            try isel.emit(.cbz(
                                hi64_ra.x(),
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                            try isel.emit(.orr(hi64_ra.x(), hi64_ra.x(), .{ .shifted_register = .{
                                .register = lo64_ra.x(),
                                .shift = .{ .lsr = @intCast(bits) },
                            } }));
                            try isel.emit(.madd(lo64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), .xzr));
                            try isel.emit(.umulh(hi64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        64 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            try isel.emit(.madd(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), .xzr));
                            const hi64_ra = try isel.allocIntReg();
                            defer isel.freeReg(hi64_ra);
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(.integer_overflow);
                            try isel.emit(.cbz(
                                hi64_ra.x(),
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                            try isel.emit(.umulh(hi64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()));
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        65...128 => return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .mul_sat => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.bits) {
                    0 => unreachable,
                    1 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        switch (int_info.signedness) {
                            .signed => try isel.emit(.orr(res_ra.w(), .wzr, .{ .register = .wzr })),
                            .unsigned => {
                                const lhs_vi = try isel.use(bin_op.lhs);
                                const rhs_vi = try isel.use(bin_op.rhs);
                                const lhs_mat = try lhs_vi.matReg(isel);
                                const rhs_mat = try rhs_vi.matReg(isel);
                                try isel.emit(.@"and"(res_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                                try rhs_mat.finish(isel);
                                try lhs_mat.finish(isel);
                            },
                        }
                    },
                    2...32 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const saturated_ra = switch (int_info.signedness) {
                            .signed => try isel.allocIntReg(),
                            .unsigned => switch (bits) {
                                else => unreachable,
                                2...31 => try isel.allocIntReg(),
                                32 => .zr,
                            },
                        };
                        defer if (saturated_ra != .zr) isel.freeReg(saturated_ra);
                        const unwrapped_ra = try isel.allocIntReg();
                        defer isel.freeReg(unwrapped_ra);
                        try isel.emit(switch (saturated_ra) {
                            else => .csel(res_ra.w(), unwrapped_ra.w(), saturated_ra.w(), .eq),
                            .zr => .csinv(res_ra.w(), unwrapped_ra.w(), saturated_ra.w(), .eq),
                        });
                        switch (bits) {
                            else => unreachable,
                            2...7, 9...15, 17...31 => switch (int_info.signedness) {
                                .signed => {
                                    const wrapped_ra = try isel.allocIntReg();
                                    defer isel.freeReg(wrapped_ra);
                                    switch (bits) {
                                        else => unreachable,
                                        1...7, 9...15 => {
                                            try isel.emit(.subs(.wzr, unwrapped_ra.w(), .{ .register = wrapped_ra.w() }));
                                            try isel.emit(.sbfm(wrapped_ra.w(), unwrapped_ra.w(), .{
                                                .N = .word,
                                                .immr = 0,
                                                .imms = @intCast(bits - 1),
                                            }));
                                        },
                                        17...31 => {
                                            try isel.emit(.subs(.xzr, unwrapped_ra.x(), .{ .register = wrapped_ra.x() }));
                                            try isel.emit(.sbfm(wrapped_ra.x(), unwrapped_ra.x(), .{
                                                .N = .doubleword,
                                                .immr = 0,
                                                .imms = @intCast(bits - 1),
                                            }));
                                        },
                                    }
                                },
                                .unsigned => switch (bits) {
                                    else => unreachable,
                                    1...7, 9...15 => try isel.emit(.ands(.wzr, unwrapped_ra.w(), .{ .immediate = .{
                                        .N = .word,
                                        .immr = @intCast(32 - bits),
                                        .imms = @intCast(32 - bits - 1),
                                    } })),
                                    17...31 => try isel.emit(.ands(.xzr, unwrapped_ra.x(), .{ .immediate = .{
                                        .N = .doubleword,
                                        .immr = @intCast(64 - bits),
                                        .imms = @intCast(64 - bits - 1),
                                    } })),
                                },
                            },
                            8 => try isel.emit(.subs(.wzr, unwrapped_ra.w(), .{ .extended_register = .{
                                .register = unwrapped_ra.w(),
                                .extend = switch (int_info.signedness) {
                                    .signed => .{ .sxtb = 0 },
                                    .unsigned => .{ .uxtb = 0 },
                                },
                            } })),
                            16 => try isel.emit(.subs(.wzr, unwrapped_ra.w(), .{ .extended_register = .{
                                .register = unwrapped_ra.w(),
                                .extend = switch (int_info.signedness) {
                                    .signed => .{ .sxth = 0 },
                                    .unsigned => .{ .uxth = 0 },
                                },
                            } })),
                            32 => try isel.emit(.subs(.xzr, unwrapped_ra.x(), .{ .extended_register = .{
                                .register = unwrapped_ra.w(),
                                .extend = switch (int_info.signedness) {
                                    .signed => .{ .sxtw = 0 },
                                    .unsigned => .{ .uxtw = 0 },
                                },
                            } })),
                        }
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        switch (int_info.signedness) {
                            .signed => {
                                try isel.emit(.eor(saturated_ra.w(), saturated_ra.w(), .{ .immediate = .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1 - 1),
                                } }));
                                try isel.emit(.sbfm(saturated_ra.w(), saturated_ra.w(), .{
                                    .N = .word,
                                    .immr = @intCast(bits - 1),
                                    .imms = @intCast(bits - 1 + 1 - 1),
                                }));
                                try isel.emit(.eor(saturated_ra.w(), lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                            },
                            .unsigned => switch (bits) {
                                else => unreachable,
                                2...31 => try isel.movImmediate(saturated_ra.w(), @as(u32, std.math.maxInt(u32)) >> @intCast(32 - bits)),
                                32 => {},
                            },
                        }
                        switch (bits) {
                            else => unreachable,
                            2...16 => try isel.emit(.madd(unwrapped_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w(), .wzr)),
                            17...32 => switch (int_info.signedness) {
                                .signed => try isel.emit(.smaddl(unwrapped_ra.x(), lhs_mat.ra.w(), rhs_mat.ra.w(), .xzr)),
                                .unsigned => try isel.emit(.umaddl(unwrapped_ra.x(), lhs_mat.ra.w(), rhs_mat.ra.w(), .xzr)),
                            },
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    33...64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const saturated_ra = switch (int_info.signedness) {
                            .signed => try isel.allocIntReg(),
                            .unsigned => switch (bits) {
                                else => unreachable,
                                33...63 => try isel.allocIntReg(),
                                64 => .zr,
                            },
                        };
                        defer if (saturated_ra != .zr) isel.freeReg(saturated_ra);
                        const unwrapped_lo64_ra = try isel.allocIntReg();
                        defer isel.freeReg(unwrapped_lo64_ra);
                        const unwrapped_hi64_ra = try isel.allocIntReg();
                        defer isel.freeReg(unwrapped_hi64_ra);
                        try isel.emit(switch (saturated_ra) {
                            else => .csel(res_ra.x(), unwrapped_lo64_ra.x(), saturated_ra.x(), .eq),
                            .zr => .csinv(res_ra.x(), unwrapped_lo64_ra.x(), saturated_ra.x(), .eq),
                        });
                        switch (int_info.signedness) {
                            .signed => switch (bits) {
                                else => unreachable,
                                32...63 => {
                                    const wrapped_lo64_ra = try isel.allocIntReg();
                                    defer isel.freeReg(wrapped_lo64_ra);
                                    try isel.emit(.ccmp(
                                        unwrapped_lo64_ra.x(),
                                        .{ .register = wrapped_lo64_ra.x() },
                                        .{ .n = false, .z = false, .c = false, .v = false },
                                        .eq,
                                    ));
                                    try isel.emit(.subs(.xzr, unwrapped_hi64_ra.x(), .{ .shifted_register = .{
                                        .register = unwrapped_lo64_ra.x(),
                                        .shift = .{ .asr = 63 },
                                    } }));
                                    try isel.emit(.sbfm(wrapped_lo64_ra.x(), unwrapped_lo64_ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(bits - 1),
                                    }));
                                },
                                64 => try isel.emit(.subs(.xzr, unwrapped_hi64_ra.x(), .{ .shifted_register = .{
                                    .register = unwrapped_lo64_ra.x(),
                                    .shift = .{ .asr = @intCast(bits - 1) },
                                } })),
                            },
                            .unsigned => switch (bits) {
                                else => unreachable,
                                32...63 => {
                                    const overflow_ra = try isel.allocIntReg();
                                    defer isel.freeReg(overflow_ra);
                                    try isel.emit(.subs(.xzr, overflow_ra.x(), .{ .immediate = 0 }));
                                    try isel.emit(.orr(overflow_ra.x(), unwrapped_hi64_ra.x(), .{ .shifted_register = .{
                                        .register = unwrapped_lo64_ra.x(),
                                        .shift = .{ .lsr = @intCast(bits) },
                                    } }));
                                },
                                64 => try isel.emit(.subs(.xzr, unwrapped_hi64_ra.x(), .{ .immediate = 0 })),
                            },
                        }
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        switch (int_info.signedness) {
                            .signed => {
                                try isel.emit(.eor(saturated_ra.x(), saturated_ra.x(), .{ .immediate = .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1 - 1),
                                } }));
                                try isel.emit(.sbfm(saturated_ra.x(), saturated_ra.x(), .{
                                    .N = .doubleword,
                                    .immr = @intCast(bits - 1),
                                    .imms = @intCast(bits - 1 + 1 - 1),
                                }));
                                try isel.emit(.eor(saturated_ra.x(), lhs_mat.ra.x(), .{ .register = rhs_mat.ra.x() }));
                                try isel.emit(.madd(unwrapped_lo64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), .xzr));
                                try isel.emit(.smulh(unwrapped_hi64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()));
                            },
                            .unsigned => {
                                switch (bits) {
                                    else => unreachable,
                                    32...63 => try isel.movImmediate(saturated_ra.x(), @as(u64, std.math.maxInt(u64)) >> @intCast(64 - bits)),
                                    64 => {},
                                }
                                try isel.emit(.madd(unwrapped_lo64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), .xzr));
                                try isel.emit(.umulh(unwrapped_hi64_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()));
                            },
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .div_float, .div_float_optimized => {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt)
                                continue :bits 32
                            else
                                .fdiv(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                            32 => .fdiv(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                            64 => .fdiv(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (bits) {
                                else => unreachable,
                                16 => "__divhf3",
                                32 => "__divsf3",
                                64 => "__divdf3",
                                80 => "__divxf3",
                                128 => "__divtf3",
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .div_trunc, .div_trunc_optimized, .div_floor, .div_floor_optimized, .div_exact, .div_exact_optimized => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) {
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    const int_info = ty.intInfo(zcu);
                    switch (int_info.bits) {
                        0 => unreachable,
                        1...64 => |bits| {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            const lhs_mat = try lhs_vi.matReg(isel);
                            const rhs_mat = try rhs_vi.matReg(isel);
                            const div_ra = div_ra: switch (air_tag) {
                                else => unreachable,
                                .div_trunc, .div_exact => res_ra,
                                .div_floor => switch (int_info.signedness) {
                                    .signed => {
                                        const div_ra = try isel.allocIntReg();
                                        errdefer isel.freeReg(div_ra);
                                        const rem_ra = try isel.allocIntReg();
                                        defer isel.freeReg(rem_ra);
                                        switch (bits) {
                                            else => unreachable,
                                            1...32 => {
                                                try isel.emit(.csel(res_ra.w(), div_ra.w(), rem_ra.w(), .pl));
                                                try isel.emit(.sub(rem_ra.w(), div_ra.w(), .{ .immediate = 1 }));
                                                try isel.emit(.ccmp(
                                                    rem_ra.w(),
                                                    .{ .immediate = 0 },
                                                    .{ .n = false, .z = false, .c = false, .v = false },
                                                    .ne,
                                                ));
                                                try isel.emit(.eor(rem_ra.w(), rem_ra.w(), .{ .register = rhs_mat.ra.w() }));
                                                try isel.emit(.subs(.wzr, rem_ra.w(), .{ .immediate = 0 }));
                                                try isel.emit(.msub(rem_ra.w(), div_ra.w(), rhs_mat.ra.w(), lhs_mat.ra.w()));
                                            },
                                            33...64 => {
                                                try isel.emit(.csel(res_ra.x(), div_ra.x(), rem_ra.x(), .pl));
                                                try isel.emit(.sub(rem_ra.x(), div_ra.x(), .{ .immediate = 1 }));
                                                try isel.emit(.ccmp(
                                                    rem_ra.x(),
                                                    .{ .immediate = 0 },
                                                    .{ .n = false, .z = false, .c = false, .v = false },
                                                    .ne,
                                                ));
                                                try isel.emit(.eor(rem_ra.x(), rem_ra.x(), .{ .register = rhs_mat.ra.x() }));
                                                try isel.emit(.subs(.xzr, rem_ra.x(), .{ .immediate = 0 }));
                                                try isel.emit(.msub(rem_ra.x(), div_ra.x(), rhs_mat.ra.x(), lhs_mat.ra.x()));
                                            },
                                        }
                                        break :div_ra div_ra;
                                    },
                                    .unsigned => res_ra,
                                },
                            };
                            defer if (div_ra != res_ra) isel.freeReg(div_ra);
                            try isel.emit(switch (bits) {
                                else => unreachable,
                                1...32 => switch (int_info.signedness) {
                                    .signed => .sdiv(div_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                    .unsigned => .udiv(div_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                },
                                33...64 => switch (int_info.signedness) {
                                    .signed => .sdiv(div_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                                    .unsigned => .udiv(div_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                                },
                            });
                            try rhs_mat.finish(isel);
                            try lhs_mat.finish(isel);
                        },
                        65...128 => {
                            switch (air_tag) {
                                else => unreachable,
                                .div_trunc, .div_exact => {},
                                .div_floor => switch (int_info.signedness) {
                                    .signed => return isel.fail("unimplemented {s}", .{@tagName(air_tag)}),
                                    .unsigned => {},
                                },
                            }

                            try call.prepareReturn(isel);
                            var res_hi64_it = res_vi.value.field(ty, 8, 8);
                            const res_hi64_vi = try res_hi64_it.only(isel);
                            try call.returnLiveIn(isel, res_hi64_vi.?, .r1);
                            var res_lo64_it = res_vi.value.field(ty, 0, 8);
                            const res_lo64_vi = try res_lo64_it.only(isel);
                            try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            try call.finishReturn(isel);

                            try call.prepareCallee(isel);
                            try isel.global_relocs.append(gpa, .{
                                .name = switch (int_info.signedness) {
                                    .signed => "__divti3",
                                    .unsigned => "__udivti3",
                                },
                                .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                            });
                            try isel.emit(.bl(0));
                            try call.finishCallee(isel);

                            try call.prepareParams(isel);
                            const lhs_vi = try isel.use(bin_op.lhs);
                            const rhs_vi = try isel.use(bin_op.rhs);
                            var rhs_hi64_it = rhs_vi.field(ty, 8, 8);
                            const rhs_hi64_vi = try rhs_hi64_it.only(isel);
                            try call.paramLiveOut(isel, rhs_hi64_vi.?, .r3);
                            var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                            const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                            try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                            var lhs_hi64_it = lhs_vi.field(ty, 8, 8);
                            const lhs_hi64_vi = try lhs_hi64_it.only(isel);
                            try call.paramLiveOut(isel, lhs_hi64_vi.?, .r1);
                            var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                            const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                            try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            try call.finishParams(isel);
                        },
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                    }
                } else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt) continue :bits 32 else {
                                switch (air_tag) {
                                    else => unreachable,
                                    .div_trunc, .div_trunc_optimized => try isel.emit(.frintz(res_ra.h(), res_ra.h())),
                                    .div_floor, .div_floor_optimized => try isel.emit(.frintm(res_ra.h(), res_ra.h())),
                                    .div_exact, .div_exact_optimized => {},
                                }
                                try isel.emit(.fdiv(res_ra.h(), lhs_ra.h(), rhs_ra.h()));
                            },
                            32 => {
                                switch (air_tag) {
                                    else => unreachable,
                                    .div_trunc, .div_trunc_optimized => try isel.emit(.frintz(res_ra.s(), res_ra.s())),
                                    .div_floor, .div_floor_optimized => try isel.emit(.frintm(res_ra.s(), res_ra.s())),
                                    .div_exact, .div_exact_optimized => {},
                                }
                                try isel.emit(.fdiv(res_ra.s(), lhs_ra.s(), rhs_ra.s()));
                            },
                            64 => {
                                switch (air_tag) {
                                    else => unreachable,
                                    .div_trunc, .div_trunc_optimized => try isel.emit(.frintz(res_ra.d(), res_ra.d())),
                                    .div_floor, .div_floor_optimized => try isel.emit(.frintm(res_ra.d(), res_ra.d())),
                                    .div_exact, .div_exact_optimized => {},
                                }
                                try isel.emit(.fdiv(res_ra.d(), lhs_ra.d(), rhs_ra.d()));
                            },
                        }
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        switch (air_tag) {
                            else => unreachable,
                            .div_trunc, .div_trunc_optimized => {
                                try isel.global_relocs.append(gpa, .{
                                    .name = switch (bits) {
                                        else => unreachable,
                                        16 => "__trunch",
                                        32 => "truncf",
                                        64 => "trunc",
                                        80 => "__truncx",
                                        128 => "truncq",
                                    },
                                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                                });
                                try isel.emit(.bl(0));
                            },
                            .div_floor, .div_floor_optimized => {
                                try isel.global_relocs.append(gpa, .{
                                    .name = switch (bits) {
                                        else => unreachable,
                                        16 => "__floorh",
                                        32 => "floorf",
                                        64 => "floor",
                                        80 => "__floorx",
                                        128 => "floorq",
                                    },
                                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                                });
                                try isel.emit(.bl(0));
                            },
                            .div_exact, .div_exact_optimized => {},
                        }
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (bits) {
                                else => unreachable,
                                16 => "__divhf3",
                                32 => "__divsf3",
                                64 => "__divdf3",
                                80 => "__divxf3",
                                128 => "__divtf3",
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .rem, .rem_optimized, .mod, .mod_optimized => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) {
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    const int_info = ty.intInfo(zcu);
                    if (int_info.bits > 64) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                    const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                    const lhs_vi = try isel.use(bin_op.lhs);
                    const rhs_vi = try isel.use(bin_op.rhs);
                    const lhs_mat = try lhs_vi.matReg(isel);
                    const rhs_mat = try rhs_vi.matReg(isel);
                    const div_ra = try isel.allocIntReg();
                    defer isel.freeReg(div_ra);
                    const rem_ra = rem_ra: switch (air_tag) {
                        else => unreachable,
                        .rem => res_ra,
                        .mod => switch (int_info.signedness) {
                            .signed => {
                                const rem_ra = try isel.allocIntReg();
                                errdefer isel.freeReg(rem_ra);
                                switch (int_info.bits) {
                                    else => unreachable,
                                    1...32 => {
                                        try isel.emit(.csel(res_ra.w(), rem_ra.w(), div_ra.w(), .pl));
                                        try isel.emit(.add(div_ra.w(), rem_ra.w(), .{ .register = rhs_mat.ra.w() }));
                                        try isel.emit(.ccmp(
                                            div_ra.w(),
                                            .{ .immediate = 0 },
                                            .{ .n = false, .z = false, .c = false, .v = false },
                                            .ne,
                                        ));
                                        try isel.emit(.eor(div_ra.w(), rem_ra.w(), .{ .register = rhs_mat.ra.w() }));
                                        try isel.emit(.subs(.wzr, rem_ra.w(), .{ .immediate = 0 }));
                                    },
                                    33...64 => {
                                        try isel.emit(.csel(res_ra.x(), rem_ra.x(), div_ra.x(), .pl));
                                        try isel.emit(.add(div_ra.x(), rem_ra.x(), .{ .register = rhs_mat.ra.x() }));
                                        try isel.emit(.ccmp(
                                            div_ra.x(),
                                            .{ .immediate = 0 },
                                            .{ .n = false, .z = false, .c = false, .v = false },
                                            .ne,
                                        ));
                                        try isel.emit(.eor(div_ra.x(), rem_ra.x(), .{ .register = rhs_mat.ra.x() }));
                                        try isel.emit(.subs(.xzr, rem_ra.x(), .{ .immediate = 0 }));
                                    },
                                }
                                break :rem_ra rem_ra;
                            },
                            .unsigned => res_ra,
                        },
                    };
                    defer if (rem_ra != res_ra) isel.freeReg(rem_ra);
                    switch (int_info.bits) {
                        else => unreachable,
                        1...32 => {
                            try isel.emit(.msub(rem_ra.w(), div_ra.w(), rhs_mat.ra.w(), lhs_mat.ra.w()));
                            try isel.emit(switch (int_info.signedness) {
                                .signed => .sdiv(div_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                .unsigned => .udiv(div_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                            });
                        },
                        33...64 => {
                            try isel.emit(.msub(rem_ra.x(), div_ra.x(), rhs_mat.ra.x(), lhs_mat.ra.x()));
                            try isel.emit(switch (int_info.signedness) {
                                .signed => .sdiv(div_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                                .unsigned => .udiv(div_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                            });
                        },
                    }
                    try rhs_mat.finish(isel);
                    try lhs_mat.finish(isel);
                } else {
                    const bits = ty.floatBits(isel.target);
                    switch (air_tag) {
                        else => unreachable,
                        .rem, .rem_optimized => {
                            if (!res_vi.value.isUsed(isel)) break :unused;
                            try call.prepareReturn(isel);
                            switch (bits) {
                                else => unreachable,
                                16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                                80 => {
                                    var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                    const res_hi16_vi = try res_hi16_it.only(isel);
                                    try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                    var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                    const res_lo64_vi = try res_lo64_it.only(isel);
                                    try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                                },
                            }
                            try call.finishReturn(isel);
                        },
                        .mod, .mod_optimized => switch (bits) {
                            else => unreachable,
                            16, 32, 64 => {
                                const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                                try call.prepareReturn(isel);
                                const rem_ra: Register.Alias = .v0;
                                const temp1_ra: Register.Alias = .v1;
                                const temp2_ra: Register.Alias = switch (res_ra) {
                                    rem_ra, temp1_ra => .v2,
                                    else => res_ra,
                                };
                                const need_fcvt = switch (bits) {
                                    else => unreachable,
                                    16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                                    32, 64 => false,
                                };
                                if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                                try isel.emit(switch (res_ra) {
                                    rem_ra => .bif(res_ra.@"8b"(), temp2_ra.@"8b"(), temp1_ra.@"8b"()),
                                    temp1_ra => .bsl(res_ra.@"8b"(), rem_ra.@"8b"(), temp2_ra.@"8b"()),
                                    else => .bit(res_ra.@"8b"(), rem_ra.@"8b"(), temp1_ra.@"8b"()),
                                });
                                const rhs_vi = try isel.use(bin_op.rhs);
                                const rhs_mat = try rhs_vi.matReg(isel);
                                try isel.emit(bits: switch (bits) {
                                    else => unreachable,
                                    16 => if (need_fcvt)
                                        continue :bits 32
                                    else
                                        .fadd(temp2_ra.h(), rem_ra.h(), rhs_mat.ra.h()),
                                    32 => .fadd(temp2_ra.s(), rem_ra.s(), rhs_mat.ra.s()),
                                    64 => .fadd(temp2_ra.d(), rem_ra.d(), rhs_mat.ra.d()),
                                });
                                if (need_fcvt) {
                                    try isel.emit(.fcvt(rhs_mat.ra.s(), rhs_mat.ra.h()));
                                    try isel.emit(.fcvt(rem_ra.s(), rem_ra.h()));
                                }
                                try isel.emit(.orr(temp1_ra.@"8b"(), temp1_ra.@"8b"(), .{
                                    .register = temp2_ra.@"8b"(),
                                }));
                                try isel.emit(switch (bits) {
                                    else => unreachable,
                                    16 => .cmge(temp1_ra.@"4h"(), temp1_ra.@"4h"(), .zero),
                                    32 => .cmge(temp1_ra.@"2s"(), temp1_ra.@"2s"(), .zero),
                                    64 => .cmge(temp1_ra.d(), temp1_ra.d(), .zero),
                                });
                                try isel.emit(switch (bits) {
                                    else => unreachable,
                                    16 => .fcmeq(temp2_ra.h(), rem_ra.h(), .zero),
                                    32 => .fcmeq(temp2_ra.s(), rem_ra.s(), .zero),
                                    64 => .fcmeq(temp2_ra.d(), rem_ra.d(), .zero),
                                });
                                try isel.emit(.eor(temp1_ra.@"8b"(), rem_ra.@"8b"(), .{
                                    .register = rhs_mat.ra.@"8b"(),
                                }));
                                try rhs_mat.finish(isel);
                                try call.finishReturn(isel);
                            },
                            80, 128 => {
                                if (!res_vi.value.isUsed(isel)) break :unused;
                                try call.prepareReturn(isel);
                                switch (bits) {
                                    else => unreachable,
                                    16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                                    80 => {
                                        var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                        const res_hi16_vi = try res_hi16_it.only(isel);
                                        try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                        var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                        const res_lo64_vi = try res_lo64_it.only(isel);
                                        try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                                    },
                                }
                                const skip_label = isel.instructions.items.len;
                                try isel.global_relocs.append(gpa, .{
                                    .name = switch (bits) {
                                        else => unreachable,
                                        16 => "__addhf3",
                                        32 => "__addsf3",
                                        64 => "__adddf3",
                                        80 => "__addxf3",
                                        128 => "__addtf3",
                                    },
                                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                                });
                                try isel.emit(.bl(0));
                                const rhs_vi = try isel.use(bin_op.rhs);
                                switch (bits) {
                                    else => unreachable,
                                    80 => {
                                        const lhs_lo64_ra: Register.Alias = .r0;
                                        const lhs_hi16_ra: Register.Alias = .r1;
                                        const rhs_lo64_ra: Register.Alias = .r2;
                                        const rhs_hi16_ra: Register.Alias = .r3;
                                        const temp_ra: Register.Alias = .r4;
                                        var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                        const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                        try call.paramLiveOut(isel, rhs_hi16_vi.?, rhs_hi16_ra);
                                        var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                        const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                        try call.paramLiveOut(isel, rhs_lo64_vi.?, rhs_lo64_ra);
                                        try isel.emit(.cbz(
                                            temp_ra.x(),
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                        try isel.emit(.orr(temp_ra.x(), lhs_lo64_ra.x(), .{ .shifted_register = .{
                                            .register = lhs_hi16_ra.x(),
                                            .shift = .{ .lsl = 64 - 15 },
                                        } }));
                                        try isel.emit(.tbz(
                                            temp_ra.w(),
                                            15,
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                        try isel.emit(.eor(temp_ra.w(), lhs_hi16_ra.w(), .{
                                            .register = rhs_hi16_ra.w(),
                                        }));
                                    },
                                    128 => {
                                        const lhs_ra: Register.Alias = .v0;
                                        const rhs_ra: Register.Alias = .v1;
                                        const temp1_ra: Register.Alias = .r0;
                                        const temp2_ra: Register.Alias = .r1;
                                        try call.paramLiveOut(isel, rhs_vi, rhs_ra);
                                        try isel.emit(.@"b."(
                                            .pl,
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                        try isel.emit(.cbz(
                                            temp1_ra.x(),
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                        try isel.emit(.orr(temp1_ra.x(), temp1_ra.x(), .{ .shifted_register = .{
                                            .register = temp2_ra.x(),
                                            .shift = .{ .lsl = 1 },
                                        } }));
                                        try isel.emit(.fmov(temp1_ra.x(), .{
                                            .register = rhs_ra.d(),
                                        }));
                                        try isel.emit(.tbz(
                                            temp1_ra.x(),
                                            63,
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                        try isel.emit(.eor(temp1_ra.x(), temp1_ra.x(), .{
                                            .register = temp2_ra.x(),
                                        }));
                                        try isel.emit(.fmov(temp2_ra.x(), .{
                                            .register = rhs_ra.@"d[]"(1),
                                        }));
                                        try isel.emit(.fmov(temp1_ra.x(), .{
                                            .register = lhs_ra.@"d[]"(1),
                                        }));
                                    },
                                }
                                try call.finishReturn(isel);
                            },
                        },
                    }

                    try call.prepareCallee(isel);
                    try isel.global_relocs.append(gpa, .{
                        .name = switch (bits) {
                            else => unreachable,
                            16 => "__fmodh",
                            32 => "fmodf",
                            64 => "fmod",
                            80 => "__fmodx",
                            128 => "fmodq",
                        },
                        .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                    });
                    try isel.emit(.bl(0));
                    try call.finishCallee(isel);

                    try call.prepareParams(isel);
                    const lhs_vi = try isel.use(bin_op.lhs);
                    const rhs_vi = try isel.use(bin_op.rhs);
                    switch (bits) {
                        else => unreachable,
                        16, 32, 64, 128 => {
                            try call.paramLiveOut(isel, rhs_vi, .v1);
                            try call.paramLiveOut(isel, lhs_vi, .v0);
                        },
                        80 => {
                            var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                            const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                            try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                            var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                            const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                            try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                            var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                            const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                            try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                            var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                            const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                            try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                        },
                    }
                    try call.finishParams(isel);
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ptr_add, .ptr_sub => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);
                const res_ra = try res_vi.value.defReg(isel) orelse break :unused;

                const ty_pl = air.data(air.inst_index).ty_pl;
                const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;
                const elem_size = ty_pl.ty.toType().elemType2(zcu).abiSize(zcu);

                const base_vi = try isel.use(bin_op.lhs);
                var base_part_it = base_vi.field(ty_pl.ty.toType(), 0, 8);
                const base_part_vi = try base_part_it.only(isel);
                const base_part_mat = try base_part_vi.?.matReg(isel);
                const index_vi = try isel.use(bin_op.rhs);
                try isel.elemPtr(res_ra, base_part_mat.ra, switch (air_tag) {
                    else => unreachable,
                    .ptr_add => .add,
                    .ptr_sub => .sub,
                }, elem_size, index_vi);
                try base_part_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .max, .min => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) {
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    const int_info = ty.intInfo(zcu);
                    if (int_info.bits > 64) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                    const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                    const lhs_vi = try isel.use(bin_op.lhs);
                    const rhs_vi = try isel.use(bin_op.rhs);
                    const lhs_mat = try lhs_vi.matReg(isel);
                    const rhs_mat = try rhs_vi.matReg(isel);
                    const cond: codegen.aarch64.encoding.ConditionCode = switch (air_tag) {
                        else => unreachable,
                        .max => switch (int_info.signedness) {
                            .signed => .ge,
                            .unsigned => .hs,
                        },
                        .min => switch (int_info.signedness) {
                            .signed => .lt,
                            .unsigned => .lo,
                        },
                    };
                    switch (int_info.bits) {
                        else => unreachable,
                        1...32 => {
                            try isel.emit(.csel(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w(), cond));
                            try isel.emit(.subs(.wzr, lhs_mat.ra.w(), .{ .register = rhs_mat.ra.w() }));
                        },
                        33...64 => {
                            try isel.emit(.csel(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x(), cond));
                            try isel.emit(.subs(.xzr, lhs_mat.ra.x(), .{ .register = rhs_mat.ra.x() }));
                        },
                    }
                    try rhs_mat.finish(isel);
                    try lhs_mat.finish(isel);
                } else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt) continue :bits 32 else switch (air_tag) {
                                else => unreachable,
                                .max => .fmaxnm(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                                .min => .fminnm(res_ra.h(), lhs_ra.h(), rhs_ra.h()),
                            },
                            32 => switch (air_tag) {
                                else => unreachable,
                                .max => .fmaxnm(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                                .min => .fminnm(res_ra.s(), lhs_ra.s(), rhs_ra.s()),
                            },
                            64 => switch (air_tag) {
                                else => unreachable,
                                .max => .fmaxnm(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                                .min => .fminnm(res_ra.d(), lhs_ra.d(), rhs_ra.d()),
                            },
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (air_tag) {
                                else => unreachable,
                                .max => switch (bits) {
                                    else => unreachable,
                                    16 => "__fmaxh",
                                    32 => "fmaxf",
                                    64 => "fmax",
                                    80 => "__fmaxx",
                                    128 => "fmaxq",
                                },
                                .min => switch (bits) {
                                    else => unreachable,
                                    16 => "__fminh",
                                    32 => "fminf",
                                    64 => "fmin",
                                    80 => "__fminx",
                                    128 => "fminq",
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .add_with_overflow, .sub_with_overflow => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| {
                defer res_vi.value.deref(isel);

                const ty_pl = air.data(air.inst_index).ty_pl;
                const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                const lhs_vi = try isel.use(bin_op.lhs);
                const rhs_vi = try isel.use(bin_op.rhs);
                const ty_size = lhs_vi.size(isel);
                var overflow_it = res_vi.value.field(ty_pl.ty.toType(), ty_size, 1);
                const overflow_vi = try overflow_it.only(isel);
                var wrapped_it = res_vi.value.field(ty_pl.ty.toType(), 0, ty_size);
                const wrapped_vi = try wrapped_it.only(isel);
                try wrapped_vi.?.addOrSubtract(isel, ty, lhs_vi, switch (air_tag) {
                    else => unreachable,
                    .add_with_overflow => .add,
                    .sub_with_overflow => .sub,
                }, rhs_vi, .{
                    .overflow = if (try overflow_vi.?.defReg(isel)) |overflow_ra| .{ .ra = overflow_ra } else .wrap,
                });
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .alloc, .ret_ptr => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |ptr_vi| unused: {
                defer ptr_vi.value.deref(isel);
                switch (air_tag) {
                    else => unreachable,
                    .alloc => {},
                    .ret_ptr => if (isel.live_values.get(Block.main)) |ret_vi| switch (ret_vi.parent(isel)) {
                        .unallocated, .stack_slot => {},
                        .value, .constant => unreachable,
                        .address => break :unused,
                    },
                }
                const ptr_ra = try ptr_vi.value.defReg(isel) orelse break :unused;

                const ty = air.data(air.inst_index).ty;
                const slot_size = ty.childType(zcu).abiSize(zcu);
                const slot_align = ty.ptrAlignment(zcu);
                const slot_offset = slot_align.forward(isel.stack_size);
                isel.stack_size = @intCast(slot_offset + slot_size);
                const lo12: u12 = @truncate(slot_offset >> 0);
                const hi12: u12 = @intCast(slot_offset >> 12);
                if (hi12 > 0) try isel.emit(.add(
                    ptr_ra.x(),
                    if (lo12 > 0) ptr_ra.x() else .sp,
                    .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                ));
                if (lo12 > 0 or hi12 == 0) try isel.emit(.add(ptr_ra.x(), .sp, .{ .immediate = lo12 }));
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .inferred_alloc, .inferred_alloc_comptime => unreachable,
        .assembly => {
            const ty_pl = air.data(air.inst_index).ty_pl;
            const extra = isel.air.extraData(Air.Asm, ty_pl.payload);
            var extra_index = extra.end;
            const outputs: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[extra_index..][0..extra.data.flags.outputs_len]);
            extra_index += outputs.len;
            const inputs: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[extra_index..][0..extra.data.inputs_len]);
            extra_index += inputs.len;

            var as: codegen.aarch64.Assemble = .{
                .source = undefined,
                .operands = .empty,
            };
            defer as.operands.deinit(gpa);

            for (outputs) |output| {
                const extra_bytes = std.mem.sliceAsBytes(isel.air.extra.items[extra_index..]);
                const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(isel.air.extra.items[extra_index..]), 0);
                const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_index += (constraint.len + name.len + (2 + 3)) / 4;

                switch (output) {
                    else => return isel.fail("invalid constraint: '{s}'", .{constraint}),
                    .none => if (std.mem.startsWith(u8, constraint, "={") and std.mem.endsWith(u8, constraint, "}")) {
                        const output_reg = Register.parse(constraint["={".len .. constraint.len - "}".len]) orelse
                            return isel.fail("invalid constraint: '{s}'", .{constraint});
                        const output_ra = output_reg.alias;
                        if (isel.live_values.fetchRemove(air.inst_index)) |output_vi| {
                            defer output_vi.value.deref(isel);
                            try output_vi.value.defLiveIn(isel, output_reg.alias, comptime &.initFill(.free));
                            isel.freeReg(output_ra);
                        }
                        if (!std.mem.eql(u8, name, "_")) {
                            const operand_gop = try as.operands.getOrPut(gpa, name);
                            if (operand_gop.found_existing) return isel.fail("duplicate output name: '{s}'", .{name});
                            operand_gop.value_ptr.* = .{ .register = switch (ty_pl.ty.toType().abiSize(zcu)) {
                                0 => unreachable,
                                1...4 => output_ra.w(),
                                5...8 => output_ra.x(),
                                else => return isel.fail("too big output type: '{f}'", .{isel.fmtType(ty_pl.ty.toType())}),
                            } };
                        }
                    } else if (std.mem.eql(u8, constraint, "=r")) {
                        const output_ra = if (isel.live_values.fetchRemove(air.inst_index)) |output_vi| output_ra: {
                            defer output_vi.value.deref(isel);
                            break :output_ra try output_vi.value.defReg(isel) orelse try isel.allocIntReg();
                        } else try isel.allocIntReg();
                        if (!std.mem.eql(u8, name, "_")) {
                            const operand_gop = try as.operands.getOrPut(gpa, name);
                            if (operand_gop.found_existing) return isel.fail("duplicate output name: '{s}'", .{name});
                            operand_gop.value_ptr.* = .{ .register = switch (ty_pl.ty.toType().abiSize(zcu)) {
                                0 => unreachable,
                                1...4 => output_ra.w(),
                                5...8 => output_ra.x(),
                                else => return isel.fail("too big output type: '{f}'", .{isel.fmtType(ty_pl.ty.toType())}),
                            } };
                        }
                    } else return isel.fail("invalid constraint: '{s}'", .{constraint}),
                }
            }

            const input_mats = try gpa.alloc(Value.Materialize, inputs.len);
            defer gpa.free(input_mats);
            const inputs_extra_index = extra_index;
            for (inputs, input_mats) |input, *input_mat| {
                const extra_bytes = std.mem.sliceAsBytes(isel.air.extra.items[extra_index..]);
                const constraint = std.mem.sliceTo(extra_bytes, 0);
                const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_index += (constraint.len + name.len + (2 + 3)) / 4;

                if (std.mem.startsWith(u8, constraint, "{") and std.mem.endsWith(u8, constraint, "}")) {
                    const input_reg = Register.parse(constraint["{".len .. constraint.len - "}".len]) orelse
                        return isel.fail("invalid constraint: '{s}'", .{constraint});
                    input_mat.* = .{ .vi = try isel.use(input), .ra = input_reg.alias };
                    if (!std.mem.eql(u8, name, "_")) {
                        const operand_gop = try as.operands.getOrPut(gpa, name);
                        if (operand_gop.found_existing) return isel.fail("duplicate input name: '{s}'", .{name});
                        const input_ty = isel.air.typeOf(input, ip);
                        operand_gop.value_ptr.* = .{ .register = switch (input_ty.abiSize(zcu)) {
                            0 => unreachable,
                            1...4 => input_reg.alias.w(),
                            5...8 => input_reg.alias.x(),
                            else => return isel.fail("too big input type: '{f}'", .{
                                isel.fmtType(isel.air.typeOf(input, ip)),
                            }),
                        } };
                    }
                } else if (std.mem.eql(u8, constraint, "r")) {
                    const input_vi = try isel.use(input);
                    input_mat.* = try input_vi.matReg(isel);
                    if (!std.mem.eql(u8, name, "_")) {
                        const operand_gop = try as.operands.getOrPut(gpa, name);
                        if (operand_gop.found_existing) return isel.fail("duplicate input name: '{s}'", .{name});
                        operand_gop.value_ptr.* = .{ .register = switch (input_vi.size(isel)) {
                            0 => unreachable,
                            1...4 => input_mat.ra.w(),
                            5...8 => input_mat.ra.x(),
                            else => return isel.fail("too big input type: '{f}'", .{
                                isel.fmtType(isel.air.typeOf(input, ip)),
                            }),
                        } };
                    }
                } else if (std.mem.eql(u8, name, "_")) {
                    input_mat.vi = try isel.use(input);
                } else return isel.fail("invalid constraint: '{s}'", .{constraint});
            }

            const clobbers = ip.indexToKey(extra.data.clobbers).aggregate;
            const clobbers_ty: ZigType = .fromInterned(clobbers.ty);
            for (0..clobbers_ty.structFieldCount(zcu)) |field_index| {
                switch (switch (clobbers.storage) {
                    .bytes => unreachable,
                    .elems => |elems| elems[field_index],
                    .repeated_elem => |repeated_elem| repeated_elem,
                }) {
                    else => unreachable,
                    .bool_false => continue,
                    .bool_true => {},
                }
                const clobber_name = clobbers_ty.structFieldName(field_index, zcu).toSlice(ip).?;
                if (std.mem.eql(u8, clobber_name, "memory")) continue;
                if (std.mem.eql(u8, clobber_name, "nzcv")) continue;
                const clobber_reg = Register.parse(clobber_name) orelse
                    return isel.fail("unable to parse clobber: '{s}'", .{clobber_name});
                const live_vi = isel.live_registers.getPtr(clobber_reg.alias);
                switch (live_vi.*) {
                    _ => {},
                    .allocating => return isel.fail("clobbered twice: '{s}'", .{clobber_name}),
                    .free => live_vi.* = .allocating,
                }
            }
            for (0..clobbers_ty.structFieldCount(zcu)) |field_index| {
                switch (switch (clobbers.storage) {
                    .bytes => unreachable,
                    .elems => |elems| elems[field_index],
                    .repeated_elem => |repeated_elem| repeated_elem,
                }) {
                    else => unreachable,
                    .bool_false => continue,
                    .bool_true => {},
                }
                const clobber_name = clobbers_ty.structFieldName(field_index, zcu).toSlice(ip).?;
                if (std.mem.eql(u8, clobber_name, "memory")) continue;
                if (std.mem.eql(u8, clobber_name, "nzcv")) continue;
                const clobber_ra = Register.parse(clobber_name).?.alias;
                const live_vi = isel.live_registers.getPtr(clobber_ra);
                switch (live_vi.*) {
                    _ => {
                        if (!try isel.fill(clobber_ra))
                            return isel.fail("unable to clobber: '{s}'", .{clobber_name});
                        assert(live_vi.* == .free);
                        live_vi.* = .allocating;
                    },
                    .allocating => {},
                    .free => unreachable,
                }
            }

            as.source = std.mem.sliceAsBytes(isel.air.extra.items[extra_index..])[0..extra.data.source_len :0];
            const asm_start = isel.instructions.items.len;
            while (as.nextInstruction() catch |err| switch (err) {
                error.InvalidSyntax => {
                    const remaining_source = std.mem.span(as.source);
                    return isel.fail("unable to assemble: '{s}'", .{std.mem.trim(
                        u8,
                        as.source[0 .. std.mem.indexOfScalar(u8, remaining_source, '\n') orelse remaining_source.len],
                        &std.ascii.whitespace,
                    )});
                },
            }) |instruction| try isel.emit(instruction);
            std.mem.reverse(codegen.aarch64.encoding.Instruction, isel.instructions.items[asm_start..]);

            extra_index = inputs_extra_index;
            for (input_mats) |input_mat| {
                const extra_bytes = std.mem.sliceAsBytes(isel.air.extra.items[extra_index..]);
                const constraint = std.mem.sliceTo(extra_bytes, 0);
                const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_index += (constraint.len + name.len + (2 + 3)) / 4;

                if (std.mem.startsWith(u8, constraint, "{") and std.mem.endsWith(u8, constraint, "}")) {
                    try input_mat.vi.liveOut(isel, input_mat.ra);
                } else if (std.mem.eql(u8, constraint, "r")) {
                    try input_mat.finish(isel);
                } else if (std.mem.eql(u8, name, "_")) {
                    try input_mat.vi.mat(isel);
                } else unreachable;
            }

            for (0..clobbers_ty.structFieldCount(zcu)) |field_index| {
                switch (switch (clobbers.storage) {
                    .bytes => unreachable,
                    .elems => |elems| elems[field_index],
                    .repeated_elem => |repeated_elem| repeated_elem,
                }) {
                    else => unreachable,
                    .bool_false => continue,
                    .bool_true => {},
                }
                const clobber_name = clobbers_ty.structFieldName(field_index, zcu).toSlice(ip).?;
                if (std.mem.eql(u8, clobber_name, "memory")) continue;
                if (std.mem.eql(u8, clobber_name, "cc")) continue;
                isel.freeReg(Register.parse(clobber_name).?.alias);
            }

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .bit_and, .bit_or, .xor, .bool_and, .bool_or => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                const int_info: std.builtin.Type.Int = if (ty.toIntern() == .bool_type)
                    .{ .signedness = .unsigned, .bits = 1 }
                else if (ty.isAbiInt(zcu))
                    ty.intInfo(zcu)
                else
                    return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                if (int_info.bits > 128) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                const lhs_vi = try isel.use(bin_op.lhs);
                const rhs_vi = try isel.use(bin_op.rhs);
                var offset = res_vi.value.size(isel);
                while (offset > 0) {
                    const size = @min(offset, 8);
                    offset -= size;
                    var res_part_it = res_vi.value.field(ty, offset, size);
                    const res_part_vi = try res_part_it.only(isel);
                    const res_part_ra = try res_part_vi.?.defReg(isel) orelse continue;
                    var lhs_part_it = lhs_vi.field(ty, offset, size);
                    const lhs_part_vi = try lhs_part_it.only(isel);
                    const lhs_part_mat = try lhs_part_vi.?.matReg(isel);
                    var rhs_part_it = rhs_vi.field(ty, offset, size);
                    const rhs_part_vi = try rhs_part_it.only(isel);
                    const rhs_part_mat = try rhs_part_vi.?.matReg(isel);
                    try isel.emit(switch (air_tag) {
                        else => unreachable,
                        .bit_and, .bool_and => switch (size) {
                            else => unreachable,
                            1, 2, 4 => .@"and"(res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                            8 => .@"and"(res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                        },
                        .bit_or, .bool_or => switch (size) {
                            else => unreachable,
                            1, 2, 4 => .orr(res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                            8 => .orr(res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                        },
                        .xor => switch (size) {
                            else => unreachable,
                            1, 2, 4 => .eor(res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                            8 => .eor(res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                        },
                    });
                    try rhs_part_mat.finish(isel);
                    try lhs_part_mat.finish(isel);
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .shr, .shr_exact, .shl, .shl_exact => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.bits) {
                    0 => unreachable,
                    1...64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        switch (air_tag) {
                            else => unreachable,
                            .shr, .shr_exact, .shl_exact => {},
                            .shl => switch (bits) {
                                else => unreachable,
                                1...31 => try isel.emit(switch (int_info.signedness) {
                                    .signed => .sbfm(res_ra.w(), res_ra.w(), .{
                                        .N = .word,
                                        .immr = 0,
                                        .imms = @intCast(bits - 1),
                                    }),
                                    .unsigned => .ubfm(res_ra.w(), res_ra.w(), .{
                                        .N = .word,
                                        .immr = 0,
                                        .imms = @intCast(bits - 1),
                                    }),
                                }),
                                32 => {},
                                33...63 => try isel.emit(switch (int_info.signedness) {
                                    .signed => .sbfm(res_ra.x(), res_ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(bits - 1),
                                    }),
                                    .unsigned => .ubfm(res_ra.x(), res_ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(bits - 1),
                                    }),
                                }),
                                64 => {},
                            },
                        }

                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        try isel.emit(switch (air_tag) {
                            else => unreachable,
                            .shr, .shr_exact => switch (bits) {
                                else => unreachable,
                                1...32 => switch (int_info.signedness) {
                                    .signed => .asrv(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                    .unsigned => .lsrv(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                },
                                33...64 => switch (int_info.signedness) {
                                    .signed => .asrv(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                                    .unsigned => .lsrv(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                                },
                            },
                            .shl, .shl_exact => switch (bits) {
                                else => unreachable,
                                1...32 => .lslv(res_ra.w(), lhs_mat.ra.w(), rhs_mat.ra.w()),
                                33...64 => .lslv(res_ra.x(), lhs_mat.ra.x(), rhs_mat.ra.x()),
                            },
                        });
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    65...128 => |bits| {
                        var res_hi64_it = res_vi.value.field(ty, 8, 8);
                        const res_hi64_vi = try res_hi64_it.only(isel);
                        const res_hi64_ra = try res_hi64_vi.?.defReg(isel);
                        var res_lo64_it = res_vi.value.field(ty, 0, 8);
                        const res_lo64_vi = try res_lo64_it.only(isel);
                        const res_lo64_ra = try res_lo64_vi.?.defReg(isel);
                        if (res_hi64_ra == null and res_lo64_ra == null) break :unused;
                        if (res_hi64_ra) |res_ra| switch (air_tag) {
                            else => unreachable,
                            .shr, .shr_exact, .shl_exact => {},
                            .shl => switch (bits) {
                                else => unreachable,
                                65...127 => try isel.emit(switch (int_info.signedness) {
                                    .signed => .sbfm(res_ra.x(), res_ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(bits - 64 - 1),
                                    }),
                                    .unsigned => .ubfm(res_ra.x(), res_ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(bits - 64 - 1),
                                    }),
                                }),
                                128 => {},
                            },
                        };

                        const lhs_vi = try isel.use(bin_op.lhs);
                        const lhs_hi64_mat = lhs_hi64_mat: {
                            const res_lock: RegLock = switch (air_tag) {
                                else => unreachable,
                                .shr, .shr_exact => switch (int_info.signedness) {
                                    .signed => if (res_lo64_ra) |res_ra| isel.lockReg(res_ra) else .empty,
                                    .unsigned => .empty,
                                },
                                .shl, .shl_exact => .empty,
                            };
                            defer res_lock.unlock(isel);
                            var lhs_hi64_it = lhs_vi.field(ty, 8, 8);
                            const lhs_hi64_vi = try lhs_hi64_it.only(isel);
                            break :lhs_hi64_mat try lhs_hi64_vi.?.matReg(isel);
                        };
                        var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                        const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                        const lhs_lo64_mat = try lhs_lo64_vi.?.matReg(isel);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lo64_ra = lo64_ra: {
                            const res_lock: RegLock = switch (air_tag) {
                                else => unreachable,
                                .shr, .shr_exact => switch (int_info.signedness) {
                                    .signed => if (res_lo64_ra) |res_ra| isel.tryLockReg(res_ra) else .empty,
                                    .unsigned => .empty,
                                },
                                .shl, .shl_exact => if (res_hi64_ra) |res_ra| isel.tryLockReg(res_ra) else .empty,
                            };
                            defer res_lock.unlock(isel);
                            break :lo64_ra try isel.allocIntReg();
                        };
                        defer isel.freeReg(lo64_ra);
                        const hi64_ra = hi64_ra: {
                            const res_lock: RegLock = switch (air_tag) {
                                else => unreachable,
                                .shr, .shr_exact => if (res_lo64_ra) |res_ra| isel.tryLockReg(res_ra) else .empty,
                                .shl, .shl_exact => .empty,
                            };
                            defer res_lock.unlock(isel);
                            break :hi64_ra try isel.allocIntReg();
                        };
                        defer isel.freeReg(hi64_ra);
                        switch (air_tag) {
                            else => unreachable,
                            .shr, .shr_exact => {
                                if (res_hi64_ra) |res_ra| switch (int_info.signedness) {
                                    .signed => {
                                        try isel.emit(.csel(res_ra.x(), hi64_ra.x(), lo64_ra.x(), .eq));
                                        try isel.emit(.sbfm(lo64_ra.x(), lhs_hi64_mat.ra.x(), .{
                                            .N = .doubleword,
                                            .immr = @intCast(bits - 64 - 1),
                                            .imms = @intCast(bits - 64 - 1),
                                        }));
                                    },
                                    .unsigned => try isel.emit(.csel(res_ra.x(), hi64_ra.x(), .xzr, .eq)),
                                };
                                if (res_lo64_ra) |res_ra| try isel.emit(.csel(res_ra.x(), lo64_ra.x(), hi64_ra.x(), .eq));
                                switch (int_info.signedness) {
                                    .signed => try isel.emit(.asrv(hi64_ra.x(), lhs_hi64_mat.ra.x(), rhs_mat.ra.x())),
                                    .unsigned => try isel.emit(.lsrv(hi64_ra.x(), lhs_hi64_mat.ra.x(), rhs_mat.ra.x())),
                                }
                            },
                            .shl, .shl_exact => {
                                if (res_lo64_ra) |res_ra| try isel.emit(.csel(res_ra.x(), lo64_ra.x(), .xzr, .eq));
                                if (res_hi64_ra) |res_ra| try isel.emit(.csel(res_ra.x(), hi64_ra.x(), lo64_ra.x(), .eq));
                                try isel.emit(.lslv(lo64_ra.x(), lhs_lo64_mat.ra.x(), rhs_mat.ra.x()));
                            },
                        }
                        try isel.emit(.ands(.wzr, rhs_mat.ra.w(), .{ .immediate = .{ .N = .word, .immr = 32 - 6, .imms = 0 } }));
                        switch (air_tag) {
                            else => unreachable,
                            .shr, .shr_exact => if (res_lo64_ra) |_| {
                                try isel.emit(.orr(
                                    lo64_ra.x(),
                                    lo64_ra.x(),
                                    .{ .shifted_register = .{ .register = hi64_ra.x(), .shift = .{ .lsl = 1 } } },
                                ));
                                try isel.emit(.lslv(hi64_ra.x(), lhs_hi64_mat.ra.x(), hi64_ra.x()));
                                try isel.emit(.lsrv(lo64_ra.x(), lhs_lo64_mat.ra.x(), rhs_mat.ra.x()));
                                try isel.emit(.orn(hi64_ra.w(), .wzr, .{ .register = rhs_mat.ra.w() }));
                            },
                            .shl, .shl_exact => if (res_hi64_ra) |_| {
                                try isel.emit(.orr(
                                    hi64_ra.x(),
                                    hi64_ra.x(),
                                    .{ .shifted_register = .{ .register = lo64_ra.x(), .shift = .{ .lsr = 1 } } },
                                ));
                                try isel.emit(.lsrv(lo64_ra.x(), lhs_lo64_mat.ra.x(), lo64_ra.x()));
                                try isel.emit(.lslv(hi64_ra.x(), lhs_hi64_mat.ra.x(), rhs_mat.ra.x()));
                                try isel.emit(.orn(lo64_ra.w(), .wzr, .{ .register = rhs_mat.ra.w() }));
                            },
                        }
                        try rhs_mat.finish(isel);
                        try lhs_lo64_mat.finish(isel);
                        try lhs_hi64_mat.finish(isel);
                        break :unused;
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .not => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = ty_op.ty.toType();
                const int_info: std.builtin.Type.Int = int_info: {
                    if (ty_op.ty == .bool_type) break :int_info .{ .signedness = .unsigned, .bits = 1 };
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    break :int_info ty.intInfo(zcu);
                };
                if (int_info.bits > 128) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                const src_vi = try isel.use(ty_op.operand);
                var offset = res_vi.value.size(isel);
                while (offset > 0) {
                    const size = @min(offset, 8);
                    offset -= size;
                    var res_part_it = res_vi.value.field(ty, offset, size);
                    const res_part_vi = try res_part_it.only(isel);
                    const res_part_ra = try res_part_vi.?.defReg(isel) orelse continue;
                    var src_part_it = src_vi.field(ty, offset, size);
                    const src_part_vi = try src_part_it.only(isel);
                    const src_part_mat = try src_part_vi.?.matReg(isel);
                    try isel.emit(switch (int_info.signedness) {
                        .signed => switch (size) {
                            else => unreachable,
                            1, 2, 4 => .orn(res_part_ra.w(), .wzr, .{ .register = src_part_mat.ra.w() }),
                            8 => .orn(res_part_ra.x(), .xzr, .{ .register = src_part_mat.ra.x() }),
                        },
                        .unsigned => switch (@min(int_info.bits - 8 * offset, 64)) {
                            else => unreachable,
                            1...31 => |bits| .eor(res_part_ra.w(), src_part_mat.ra.w(), .{ .immediate = .{
                                .N = .word,
                                .immr = 0,
                                .imms = @intCast(bits - 1),
                            } }),
                            32 => .orn(res_part_ra.w(), .wzr, .{ .register = src_part_mat.ra.w() }),
                            33...63 => |bits| .eor(res_part_ra.x(), src_part_mat.ra.x(), .{ .immediate = .{
                                .N = .doubleword,
                                .immr = 0,
                                .imms = @intCast(bits - 1),
                            } }),
                            64 => .orn(res_part_ra.x(), .xzr, .{ .register = src_part_mat.ra.x() }),
                        },
                    });
                    try src_part_mat.finish(isel);
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .bitcast => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const dst_tag = dst_ty.zigTypeTag(zcu);
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                const src_tag = src_ty.zigTypeTag(zcu);
                if (dst_ty.isAbiInt(zcu) and (src_tag == .bool or src_ty.isAbiInt(zcu))) {
                    const dst_int_info = dst_ty.intInfo(zcu);
                    const src_int_info: std.builtin.Type.Int = if (src_tag == .bool) .{ .signedness = undefined, .bits = 1 } else src_ty.intInfo(zcu);
                    assert(dst_int_info.bits == src_int_info.bits);
                    if (dst_tag != .@"struct" and src_tag != .@"struct" and src_tag != .bool and dst_int_info.signedness == src_int_info.signedness) {
                        try dst_vi.value.move(isel, ty_op.operand);
                    } else switch (dst_int_info.bits) {
                        0 => unreachable,
                        1...31 => |dst_bits| {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(switch (dst_int_info.signedness) {
                                .signed => .sbfm(dst_ra.w(), src_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(dst_bits - 1),
                                }),
                                .unsigned => .ubfm(dst_ra.w(), src_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(dst_bits - 1),
                                }),
                            });
                            try src_mat.finish(isel);
                        },
                        32 => try dst_vi.value.move(isel, ty_op.operand),
                        33...63 => |dst_bits| {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(switch (dst_int_info.signedness) {
                                .signed => .sbfm(dst_ra.x(), src_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(dst_bits - 1),
                                }),
                                .unsigned => .ubfm(dst_ra.x(), src_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(dst_bits - 1),
                                }),
                            });
                            try src_mat.finish(isel);
                        },
                        64 => try dst_vi.value.move(isel, ty_op.operand),
                        65...127 => |dst_bits| {
                            const src_vi = try isel.use(ty_op.operand);
                            var dst_hi64_it = dst_vi.value.field(dst_ty, 8, 8);
                            const dst_hi64_vi = try dst_hi64_it.only(isel);
                            if (try dst_hi64_vi.?.defReg(isel)) |dst_hi64_ra| {
                                var src_hi64_it = src_vi.field(src_ty, 8, 8);
                                const src_hi64_vi = try src_hi64_it.only(isel);
                                const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                                try isel.emit(switch (dst_int_info.signedness) {
                                    .signed => .sbfm(dst_hi64_ra.x(), src_hi64_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(dst_bits - 64 - 1),
                                    }),
                                    .unsigned => .ubfm(dst_hi64_ra.x(), src_hi64_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(dst_bits - 64 - 1),
                                    }),
                                });
                                try src_hi64_mat.finish(isel);
                            }
                            var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                            const dst_lo64_vi = try dst_lo64_it.only(isel);
                            if (try dst_lo64_vi.?.defReg(isel)) |dst_lo64_ra| {
                                var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try src_lo64_vi.?.liveOut(isel, dst_lo64_ra);
                            }
                        },
                        128 => try dst_vi.value.move(isel, ty_op.operand),
                        else => return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) }),
                    }
                } else if ((dst_ty.isPtrAtRuntime(zcu) or dst_ty.isAbiInt(zcu)) and (src_ty.isPtrAtRuntime(zcu) or src_ty.isAbiInt(zcu))) {
                    try dst_vi.value.move(isel, ty_op.operand);
                } else if (dst_ty.isSliceAtRuntime(zcu) and src_ty.isSliceAtRuntime(zcu)) {
                    try dst_vi.value.move(isel, ty_op.operand);
                } else if (dst_tag == .error_union and src_tag == .error_union) {
                    assert(dst_ty.errorUnionSet(zcu).hasRuntimeBitsIgnoreComptime(zcu) ==
                        src_ty.errorUnionSet(zcu).hasRuntimeBitsIgnoreComptime(zcu));
                    if (dst_ty.errorUnionPayload(zcu).toIntern() == src_ty.errorUnionPayload(zcu).toIntern()) {
                        try dst_vi.value.move(isel, ty_op.operand);
                    } else return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                } else if (dst_tag == .float and src_tag == .float) {
                    assert(dst_ty.floatBits(isel.target) == src_ty.floatBits(isel.target));
                    try dst_vi.value.move(isel, ty_op.operand);
                } else if (dst_ty.isAbiInt(zcu) and src_tag == .float) {
                    const dst_int_info = dst_ty.intInfo(zcu);
                    assert(dst_int_info.bits == src_ty.floatBits(isel.target));
                    switch (dst_int_info.bits) {
                        else => unreachable,
                        16 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            switch (dst_int_info.signedness) {
                                .signed => try isel.emit(.smov(dst_ra.w(), src_mat.ra.@"h[]"(0))),
                                .unsigned => try isel.emit(if (isel.target.cpu.has(.aarch64, .fullfp16))
                                    .fmov(dst_ra.w(), .{ .register = src_mat.ra.h() })
                                else
                                    .umov(dst_ra.w(), src_mat.ra.@"h[]"(0))),
                            }
                            try src_mat.finish(isel);
                        },
                        32 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.fmov(dst_ra.w(), .{ .register = src_mat.ra.s() }));
                            try src_mat.finish(isel);
                        },
                        64 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.fmov(dst_ra.x(), .{ .register = src_mat.ra.d() }));
                            try src_mat.finish(isel);
                        },
                        80 => switch (dst_int_info.signedness) {
                            .signed => {
                                const src_vi = try isel.use(ty_op.operand);
                                var dst_hi16_it = dst_vi.value.field(dst_ty, 8, 8);
                                const dst_hi16_vi = try dst_hi16_it.only(isel);
                                if (try dst_hi16_vi.?.defReg(isel)) |dst_hi16_ra| {
                                    var src_hi16_it = src_vi.field(src_ty, 8, 8);
                                    const src_hi16_vi = try src_hi16_it.only(isel);
                                    const src_hi16_mat = try src_hi16_vi.?.matReg(isel);
                                    try isel.emit(.sbfm(dst_hi16_ra.x(), src_hi16_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = 16 - 1,
                                    }));
                                    try src_hi16_mat.finish(isel);
                                }
                                var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                                const dst_lo64_vi = try dst_lo64_it.only(isel);
                                if (try dst_lo64_vi.?.defReg(isel)) |dst_lo64_ra| {
                                    var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                    const src_lo64_vi = try src_lo64_it.only(isel);
                                    try src_lo64_vi.?.liveOut(isel, dst_lo64_ra);
                                }
                            },
                            else => try dst_vi.value.move(isel, ty_op.operand),
                        },
                        128 => {
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            var dst_hi64_it = dst_vi.value.field(dst_ty, 8, 8);
                            const dst_hi64_vi = try dst_hi64_it.only(isel);
                            if (try dst_hi64_vi.?.defReg(isel)) |dst_hi64_ra| try isel.emit(.fmov(dst_hi64_ra.x(), .{ .register = src_mat.ra.@"d[]"(1) }));
                            var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                            const dst_lo64_vi = try dst_lo64_it.only(isel);
                            if (try dst_lo64_vi.?.defReg(isel)) |dst_lo64_ra| try isel.emit(.fmov(dst_lo64_ra.x(), .{ .register = src_mat.ra.d() }));
                            try src_mat.finish(isel);
                        },
                    }
                } else if (dst_tag == .float and src_ty.isAbiInt(zcu)) {
                    const src_int_info = src_ty.intInfo(zcu);
                    assert(dst_ty.floatBits(isel.target) == src_int_info.bits);
                    switch (src_int_info.bits) {
                        else => unreachable,
                        16 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.fmov(
                                if (isel.target.cpu.has(.aarch64, .fullfp16)) dst_ra.h() else dst_ra.s(),
                                .{ .register = src_mat.ra.w() },
                            ));
                            try src_mat.finish(isel);
                        },
                        32 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.fmov(dst_ra.s(), .{ .register = src_mat.ra.w() }));
                            try src_mat.finish(isel);
                        },
                        64 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.fmov(dst_ra.d(), .{ .register = src_mat.ra.x() }));
                            try src_mat.finish(isel);
                        },
                        80 => switch (src_int_info.signedness) {
                            .signed => {
                                const src_vi = try isel.use(ty_op.operand);
                                var dst_hi16_it = dst_vi.value.field(dst_ty, 8, 8);
                                const dst_hi16_vi = try dst_hi16_it.only(isel);
                                if (try dst_hi16_vi.?.defReg(isel)) |dst_hi16_ra| {
                                    var src_hi16_it = src_vi.field(src_ty, 8, 8);
                                    const src_hi16_vi = try src_hi16_it.only(isel);
                                    const src_hi16_mat = try src_hi16_vi.?.matReg(isel);
                                    try isel.emit(.ubfm(dst_hi16_ra.x(), src_hi16_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = 16 - 1,
                                    }));
                                    try src_hi16_mat.finish(isel);
                                }
                                var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                                const dst_lo64_vi = try dst_lo64_it.only(isel);
                                if (try dst_lo64_vi.?.defReg(isel)) |dst_lo64_ra| {
                                    var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                    const src_lo64_vi = try src_lo64_it.only(isel);
                                    try src_lo64_vi.?.liveOut(isel, dst_lo64_ra);
                                }
                            },
                            else => try dst_vi.value.move(isel, ty_op.operand),
                        },
                        128 => {
                            const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            var src_hi64_it = src_vi.field(src_ty, 8, 8);
                            const src_hi64_vi = try src_hi64_it.only(isel);
                            const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                            try isel.emit(.fmov(dst_ra.@"d[]"(1), .{ .register = src_hi64_mat.ra.x() }));
                            try src_hi64_mat.finish(isel);
                            var src_lo64_it = src_vi.field(src_ty, 0, 8);
                            const src_lo64_vi = try src_lo64_it.only(isel);
                            const src_lo64_mat = try src_lo64_vi.?.matReg(isel);
                            try isel.emit(.fmov(dst_ra.d(), .{ .register = src_lo64_mat.ra.x() }));
                            try src_lo64_mat.finish(isel);
                        },
                    }
                } else if (dst_ty.isAbiInt(zcu) and src_tag == .array and src_ty.childType(zcu).isAbiInt(zcu)) {
                    const dst_int_info = dst_ty.intInfo(zcu);
                    const src_child_int_info = src_ty.childType(zcu).intInfo(zcu);
                    const src_len = src_ty.arrayLenIncludingSentinel(zcu);
                    assert(dst_int_info.bits == src_child_int_info.bits * src_len);
                    const src_child_size = src_ty.childType(zcu).abiSize(zcu);
                    if (8 * src_child_size == src_child_int_info.bits) {
                        try dst_vi.value.defAddr(isel, dst_ty, .{ .wrap = dst_int_info }) orelse break :unused;

                        try call.prepareReturn(isel);
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = "memcpy",
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(ty_op.operand);
                        try isel.movImmediate(.x2, src_child_size * src_len);
                        try call.paramAddress(isel, src_vi, .r1);
                        try call.paramAddress(isel, dst_vi.value, .r0);
                        try call.finishParams(isel);
                    } else return isel.fail("bad  {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                } else if (dst_tag == .array and dst_ty.childType(zcu).isAbiInt(zcu) and src_ty.isAbiInt(zcu)) {
                    const dst_child_int_info = dst_ty.childType(zcu).intInfo(zcu);
                    const src_int_info = src_ty.intInfo(zcu);
                    const dst_len = dst_ty.arrayLenIncludingSentinel(zcu);
                    assert(dst_child_int_info.bits * dst_len == src_int_info.bits);
                    const dst_child_size = dst_ty.childType(zcu).abiSize(zcu);
                    if (8 * dst_child_size == dst_child_int_info.bits) {
                        try dst_vi.value.defAddr(isel, dst_ty, .{}) orelse break :unused;

                        try call.prepareReturn(isel);
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = "memcpy",
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(ty_op.operand);
                        try isel.movImmediate(.x2, dst_child_size * dst_len);
                        try call.paramAddress(isel, src_vi, .r1);
                        try call.paramAddress(isel, dst_vi.value, .r0);
                        try call.finishParams(isel);
                    } else return isel.fail("bad  {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                } else return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .block => {
            const ty_pl = air.data(air.inst_index).ty_pl;
            const extra = isel.air.extraData(Air.Block, ty_pl.payload);
            try isel.block(air.inst_index, ty_pl.ty.toType(), @ptrCast(
                isel.air.extra.items[extra.end..][0..extra.data.body_len],
            ));
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .loop => {
            const ty_pl = air.data(air.inst_index).ty_pl;
            const extra = isel.air.extraData(Air.Block, ty_pl.payload);
            const loops = isel.loops.values();
            const loop_index = isel.loops.getIndex(air.inst_index).?;
            const loop = &loops[loop_index];

            tracking_log.debug("{f}", .{
                isel.fmtDom(air.inst_index, loop.dom, @intCast(isel.blocks.count())),
            });
            tracking_log.debug("{f}", .{isel.fmtLoopLive(air.inst_index)});
            assert(loop.depth == isel.blocks.count());

            if (false) {
                // loops are dumb...
                for (isel.loop_live.list.items[loop.live..loops[loop_index + 1].live]) |live_inst| {
                    const live_vi = try isel.use(live_inst.toRef());
                    try live_vi.mat(isel);
                }

                // IT'S DOM TIME!!!
                for (isel.blocks.values(), 0..) |*dom_block, dom_index| {
                    if (@as(u1, @truncate(isel.dom.items[
                        loop.dom + dom_index / @bitSizeOf(DomInt)
                    ] >> @truncate(dom_index))) == 0) continue;
                    var live_reg_it = dom_block.live_registers.iterator();
                    while (live_reg_it.next()) |live_reg_entry| switch (live_reg_entry.value.*) {
                        _ => |live_vi| try live_vi.mat(isel),
                        .allocating => unreachable,
                        .free => {},
                    };
                }
            }

            loop.live_registers = isel.live_registers;
            loop.repeat_list = Loop.empty_list;
            try isel.body(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            try isel.merge(&loop.live_registers, .{ .fill_extra = true });

            var repeat_label = loop.repeat_list;
            assert(repeat_label != Loop.empty_list);
            while (repeat_label != Loop.empty_list) {
                const instruction = &isel.instructions.items[repeat_label];
                const next_repeat_label = instruction.*;
                instruction.* = .b(-@as(i28, @intCast((isel.instructions.items.len - 1 - repeat_label) << 2)));
                repeat_label = @bitCast(next_repeat_label);
            }

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .repeat => {
            const repeat = air.data(air.inst_index).repeat;
            try isel.loops.getPtr(repeat.loop_inst).?.branch(isel);
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .br => {
            const br = air.data(air.inst_index).br;
            try isel.blocks.getPtr(br.block_inst).?.branch(isel);
            if (isel.live_values.get(br.block_inst)) |dst_vi| try dst_vi.move(isel, br.operand);
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .trap => {
            try isel.emit(.brk(0x1));
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .breakpoint => {
            try isel.emit(.brk(0xf000));
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ret_addr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |addr_vi| unused: {
                defer addr_vi.value.deref(isel);
                const addr_ra = try addr_vi.value.defReg(isel) orelse break :unused;
                try isel.emit(.ldr(addr_ra.x(), .{ .unsigned_offset = .{ .base = .fp, .offset = 8 } }));
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .frame_addr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |addr_vi| unused: {
                defer addr_vi.value.deref(isel);
                const addr_ra = try addr_vi.value.defReg(isel) orelse break :unused;
                try isel.emit(.orr(addr_ra.x(), .xzr, .{ .register = .fp }));
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .call => {
            const pl_op = air.data(air.inst_index).pl_op;
            const extra = isel.air.extraData(Air.Call, pl_op.payload);
            const args: []const Air.Inst.Ref = @ptrCast(isel.air.extra.items[extra.end..][0..extra.data.args_len]);
            const callee_ty = isel.air.typeOf(pl_op.operand, ip);
            const func_info = switch (ip.indexToKey(callee_ty.toIntern())) {
                else => unreachable,
                .func_type => |func_type| func_type,
                .ptr_type => |ptr_type| ip.indexToKey(ptr_type.child).func_type,
            };

            try call.prepareReturn(isel);
            const maybe_def_ret_vi = isel.live_values.fetchRemove(air.inst_index);
            var maybe_ret_addr_vi: ?Value.Index = null;
            if (maybe_def_ret_vi) |def_ret_vi| {
                defer def_ret_vi.value.deref(isel);

                var ret_it: CallAbiIterator = .init;
                const ret_vi = try ret_it.ret(isel, isel.air.typeOfIndex(air.inst_index, ip));
                defer ret_vi.?.deref(isel);
                switch (ret_vi.?.parent(isel)) {
                    .unallocated, .stack_slot => if (ret_vi.?.hint(isel)) |ret_ra| {
                        try call.returnLiveIn(isel, def_ret_vi.value, ret_ra);
                    } else {
                        var def_ret_part_it = def_ret_vi.value.parts(isel);
                        var ret_part_it = ret_vi.?.parts(isel);
                        while (def_ret_part_it.next()) |ret_part_vi| {
                            try call.returnLiveIn(isel, ret_part_vi, ret_part_it.next().?.hint(isel).?);
                        }
                    },
                    .value, .constant => unreachable,
                    .address => |address_vi| {
                        maybe_ret_addr_vi = address_vi;
                        _ = try def_ret_vi.value.defAddr(isel, isel.air.typeOfIndex(air.inst_index, ip), .{
                            .expected_live_registers = &call.caller_saved_regs,
                        });
                    },
                }
            }
            try call.finishReturn(isel);

            try call.prepareCallee(isel);
            if (pl_op.operand.toInterned()) |ct_callee| {
                try isel.nav_relocs.append(gpa, switch (ip.indexToKey(ct_callee)) {
                    else => unreachable,
                    inline .@"extern", .func => |func| .{
                        .nav = func.owner_nav,
                        .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                    },
                    .ptr => |ptr| .{
                        .nav = ptr.base_addr.nav,
                        .reloc = .{
                            .label = @intCast(isel.instructions.items.len),
                            .addend = ptr.byte_offset,
                        },
                    },
                });
                try isel.emit(.bl(0));
            } else {
                const callee_vi = try isel.use(pl_op.operand);
                const callee_mat = try callee_vi.matReg(isel);
                try isel.emit(.blr(callee_mat.ra.x()));
                try callee_mat.finish(isel);
            }
            try call.finishCallee(isel);

            try call.prepareParams(isel);
            if (maybe_ret_addr_vi) |ret_addr_vi| try call.paramAddress(
                isel,
                maybe_def_ret_vi.?.value,
                ret_addr_vi.hint(isel).?,
            );
            var param_it: CallAbiIterator = .init;
            for (args, 0..) |arg, arg_index| {
                const param_ty = isel.air.typeOf(arg, ip);
                const param_vi = param_vi: {
                    if (arg_index >= func_info.param_types.len) {
                        assert(func_info.is_var_args);
                        switch (isel.va_list) {
                            .other => break :param_vi try param_it.nonSysvVarArg(isel, param_ty),
                            .sysv => {},
                        }
                    }
                    break :param_vi try param_it.param(isel, param_ty);
                } orelse continue;
                defer param_vi.deref(isel);
                const arg_vi = try isel.use(arg);
                switch (param_vi.parent(isel)) {
                    .unallocated => if (param_vi.hint(isel)) |param_ra| {
                        try call.paramLiveOut(isel, arg_vi, param_ra);
                    } else {
                        var param_part_it = param_vi.parts(isel);
                        var arg_part_it = arg_vi.parts(isel);
                        if (arg_part_it.only()) |_| {
                            try isel.values.ensureUnusedCapacity(gpa, param_part_it.remaining);
                            arg_vi.setParts(isel, param_part_it.remaining);
                            while (param_part_it.next()) |param_part_vi| _ = arg_vi.addPart(
                                isel,
                                param_part_vi.get(isel).offset_from_parent,
                                param_part_vi.size(isel),
                            );
                            param_part_it = param_vi.parts(isel);
                            arg_part_it = arg_vi.parts(isel);
                        }
                        while (param_part_it.next()) |param_part_vi| {
                            const arg_part_vi = arg_part_it.next().?;
                            assert(arg_part_vi.get(isel).offset_from_parent ==
                                param_part_vi.get(isel).offset_from_parent);
                            assert(arg_part_vi.size(isel) == param_part_vi.size(isel));
                            try call.paramLiveOut(isel, arg_part_vi, param_part_vi.hint(isel).?);
                        }
                    },
                    .stack_slot => |stack_slot| try arg_vi.store(isel, param_ty, stack_slot.base, .{
                        .offset = @intCast(stack_slot.offset),
                    }),
                    .value, .constant => unreachable,
                    .address => |address_vi| try call.paramAddress(isel, arg_vi, address_vi.hint(isel).?),
                }
            }
            try call.finishParams(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .clz => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = isel.air.typeOf(ty_op.operand, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.bits) {
                    0 => unreachable,
                    1...64 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.clzLimb(res_ra, int_info, src_mat.ra);
                        try src_mat.finish(isel);
                    },
                    65...128 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        var src_hi64_it = src_vi.field(ty, 8, 8);
                        const src_hi64_vi = try src_hi64_it.only(isel);
                        const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                        var src_lo64_it = src_vi.field(ty, 0, 8);
                        const src_lo64_vi = try src_lo64_it.only(isel);
                        const src_lo64_mat = try src_lo64_vi.?.matReg(isel);
                        const lo64_ra = try isel.allocIntReg();
                        defer isel.freeReg(lo64_ra);
                        const hi64_ra = try isel.allocIntReg();
                        defer isel.freeReg(hi64_ra);
                        try isel.emit(.csel(res_ra.w(), lo64_ra.w(), hi64_ra.w(), .eq));
                        try isel.emit(.add(lo64_ra.w(), lo64_ra.w(), .{ .immediate = @intCast(bits - 64) }));
                        try isel.emit(.subs(.xzr, src_hi64_mat.ra.x(), .{ .immediate = 0 }));
                        try isel.clzLimb(hi64_ra, .{ .signedness = int_info.signedness, .bits = bits - 64 }, src_hi64_mat.ra);
                        try isel.clzLimb(lo64_ra, .{ .signedness = .unsigned, .bits = 64 }, src_lo64_mat.ra);
                        try src_hi64_mat.finish(isel);
                        try src_lo64_mat.finish(isel);
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ctz => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = isel.air.typeOf(ty_op.operand, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                switch (int_info.bits) {
                    0 => unreachable,
                    1...64 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.ctzLimb(res_ra, int_info, src_mat.ra);
                        try src_mat.finish(isel);
                    },
                    65...128 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        var src_hi64_it = src_vi.field(ty, 8, 8);
                        const src_hi64_vi = try src_hi64_it.only(isel);
                        const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                        var src_lo64_it = src_vi.field(ty, 0, 8);
                        const src_lo64_vi = try src_lo64_it.only(isel);
                        const src_lo64_mat = try src_lo64_vi.?.matReg(isel);
                        const lo64_ra = try isel.allocIntReg();
                        defer isel.freeReg(lo64_ra);
                        const hi64_ra = try isel.allocIntReg();
                        defer isel.freeReg(hi64_ra);
                        try isel.emit(.csel(res_ra.w(), lo64_ra.w(), hi64_ra.w(), .ne));
                        try isel.emit(.add(hi64_ra.w(), hi64_ra.w(), .{ .immediate = 64 }));
                        try isel.emit(.subs(.xzr, src_lo64_mat.ra.x(), .{ .immediate = 0 }));
                        try isel.ctzLimb(hi64_ra, .{ .signedness = .unsigned, .bits = 64 }, src_hi64_mat.ra);
                        try isel.ctzLimb(lo64_ra, .{ .signedness = int_info.signedness, .bits = bits - 64 }, src_lo64_mat.ra);
                        try src_hi64_mat.finish(isel);
                        try src_lo64_mat.finish(isel);
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .popcount => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = isel.air.typeOf(ty_op.operand, ip);
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                if (int_info.bits > 64) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                const src_vi = try isel.use(ty_op.operand);
                const src_mat = try src_vi.matReg(isel);
                const vec_ra = try isel.allocVecReg();
                defer isel.freeReg(vec_ra);
                try isel.emit(.umov(res_ra.w(), vec_ra.@"b[]"(0)));
                switch (int_info.bits) {
                    else => unreachable,
                    1...8 => {},
                    9...16 => try isel.emit(.addp(vec_ra.@"8b"(), vec_ra.@"8b"(), .{ .vector = vec_ra.@"8b"() })),
                    17...64 => try isel.emit(.addv(vec_ra.b(), vec_ra.@"8b"())),
                }
                try isel.emit(.cnt(vec_ra.@"8b"(), vec_ra.@"8b"()));
                switch (int_info.bits) {
                    else => unreachable,
                    1...31 => |bits| switch (int_info.signedness) {
                        .signed => {
                            try isel.emit(.fmov(vec_ra.s(), .{ .register = res_ra.w() }));
                            try isel.emit(.ubfm(res_ra.w(), src_mat.ra.w(), .{
                                .N = .word,
                                .immr = 0,
                                .imms = @intCast(bits - 1),
                            }));
                        },
                        .unsigned => try isel.emit(.fmov(vec_ra.s(), .{ .register = src_mat.ra.w() })),
                    },
                    32 => try isel.emit(.fmov(vec_ra.s(), .{ .register = src_mat.ra.w() })),
                    33...63 => |bits| switch (int_info.signedness) {
                        .signed => {
                            try isel.emit(.fmov(vec_ra.d(), .{ .register = res_ra.x() }));
                            try isel.emit(.ubfm(res_ra.x(), src_mat.ra.x(), .{
                                .N = .doubleword,
                                .immr = 0,
                                .imms = @intCast(bits - 1),
                            }));
                        },
                        .unsigned => try isel.emit(.fmov(vec_ra.d(), .{ .register = src_mat.ra.x() })),
                    },
                    64 => try isel.emit(.fmov(vec_ra.d(), .{ .register = src_mat.ra.x() })),
                }
                try src_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .byte_swap => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = ty_op.ty.toType();
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                if (int_info.bits > 64) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                if (int_info.bits == 8) break :unused try res_vi.value.move(isel, ty_op.operand);
                const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                const src_vi = try isel.use(ty_op.operand);
                const src_mat = try src_vi.matReg(isel);
                switch (int_info.bits) {
                    else => unreachable,
                    16 => switch (int_info.signedness) {
                        .signed => {
                            try isel.emit(.sbfm(res_ra.w(), res_ra.w(), .{
                                .N = .word,
                                .immr = 32 - 16,
                                .imms = 32 - 1,
                            }));
                            try isel.emit(.rev(res_ra.w(), src_mat.ra.w()));
                        },
                        .unsigned => try isel.emit(.rev16(res_ra.w(), src_mat.ra.w())),
                    },
                    24 => {
                        switch (int_info.signedness) {
                            .signed => try isel.emit(.sbfm(res_ra.w(), res_ra.w(), .{
                                .N = .word,
                                .immr = 32 - 24,
                                .imms = 32 - 1,
                            })),
                            .unsigned => try isel.emit(.ubfm(res_ra.w(), res_ra.w(), .{
                                .N = .word,
                                .immr = 32 - 24,
                                .imms = 32 - 1,
                            })),
                        }
                        try isel.emit(.rev(res_ra.w(), src_mat.ra.w()));
                    },
                    32 => try isel.emit(.rev(res_ra.w(), src_mat.ra.w())),
                    40, 48, 56 => |bits| {
                        switch (int_info.signedness) {
                            .signed => try isel.emit(.sbfm(res_ra.x(), res_ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(64 - bits),
                                .imms = 64 - 1,
                            })),
                            .unsigned => try isel.emit(.ubfm(res_ra.x(), res_ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(64 - bits),
                                .imms = 64 - 1,
                            })),
                        }
                        try isel.emit(.rev(res_ra.x(), src_mat.ra.x()));
                    },
                    64 => try isel.emit(.rev(res_ra.x(), src_mat.ra.x())),
                }
                try src_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .bit_reverse => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = ty_op.ty.toType();
                if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                const int_info = ty.intInfo(zcu);
                if (int_info.bits > 64) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                const src_vi = try isel.use(ty_op.operand);
                const src_mat = try src_vi.matReg(isel);
                switch (int_info.bits) {
                    else => unreachable,
                    1...31 => |bits| {
                        switch (int_info.signedness) {
                            .signed => try isel.emit(.sbfm(res_ra.w(), res_ra.w(), .{
                                .N = .word,
                                .immr = @intCast(32 - bits),
                                .imms = 32 - 1,
                            })),
                            .unsigned => try isel.emit(.ubfm(res_ra.w(), res_ra.w(), .{
                                .N = .word,
                                .immr = @intCast(32 - bits),
                                .imms = 32 - 1,
                            })),
                        }
                        try isel.emit(.rbit(res_ra.w(), src_mat.ra.w()));
                    },
                    32 => try isel.emit(.rbit(res_ra.w(), src_mat.ra.w())),
                    33...63 => |bits| {
                        switch (int_info.signedness) {
                            .signed => try isel.emit(.sbfm(res_ra.x(), res_ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(64 - bits),
                                .imms = 64 - 1,
                            })),
                            .unsigned => try isel.emit(.ubfm(res_ra.x(), res_ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(64 - bits),
                                .imms = 64 - 1,
                            })),
                        }
                        try isel.emit(.rbit(res_ra.x(), src_mat.ra.x()));
                    },
                    64 => try isel.emit(.rbit(res_ra.x(), src_mat.ra.x())),
                }
                try src_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .sqrt, .floor, .ceil, .round, .trunc_float => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const un_op = air.data(air.inst_index).un_op;
                const ty = isel.air.typeOf(un_op, ip);
                switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const src_vi = try isel.use(un_op);
                        const src_mat = try src_vi.matReg(isel);
                        const src_ra = if (need_fcvt) try isel.allocVecReg() else src_mat.ra;
                        defer if (need_fcvt) isel.freeReg(src_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt) continue :bits 32 else switch (air_tag) {
                                else => unreachable,
                                .sqrt => .fsqrt(res_ra.h(), src_ra.h()),
                                .floor => .frintm(res_ra.h(), src_ra.h()),
                                .ceil => .frintp(res_ra.h(), src_ra.h()),
                                .round => .frinta(res_ra.h(), src_ra.h()),
                                .trunc_float => .frintz(res_ra.h(), src_ra.h()),
                            },
                            32 => switch (air_tag) {
                                else => unreachable,
                                .sqrt => .fsqrt(res_ra.s(), src_ra.s()),
                                .floor => .frintm(res_ra.s(), src_ra.s()),
                                .ceil => .frintp(res_ra.s(), src_ra.s()),
                                .round => .frinta(res_ra.s(), src_ra.s()),
                                .trunc_float => .frintz(res_ra.s(), src_ra.s()),
                            },
                            64 => switch (air_tag) {
                                else => unreachable,
                                .sqrt => .fsqrt(res_ra.d(), src_ra.d()),
                                .floor => .frintm(res_ra.d(), src_ra.d()),
                                .ceil => .frintp(res_ra.d(), src_ra.d()),
                                .round => .frinta(res_ra.d(), src_ra.d()),
                                .trunc_float => .frintz(res_ra.d(), src_ra.d()),
                            },
                        });
                        if (need_fcvt) try isel.emit(.fcvt(src_ra.s(), src_mat.ra.h()));
                        try src_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (air_tag) {
                                else => unreachable,
                                .sqrt => switch (bits) {
                                    else => unreachable,
                                    16 => "__sqrth",
                                    32 => "sqrtf",
                                    64 => "sqrt",
                                    80 => "__sqrtx",
                                    128 => "sqrtq",
                                },
                                .floor => switch (bits) {
                                    else => unreachable,
                                    16 => "__floorh",
                                    32 => "floorf",
                                    64 => "floor",
                                    80 => "__floorx",
                                    128 => "floorq",
                                },
                                .ceil => switch (bits) {
                                    else => unreachable,
                                    16 => "__ceilh",
                                    32 => "ceilf",
                                    64 => "ceil",
                                    80 => "__ceilx",
                                    128 => "ceilq",
                                },
                                .round => switch (bits) {
                                    else => unreachable,
                                    16 => "__roundh",
                                    32 => "roundf",
                                    64 => "round",
                                    80 => "__roundx",
                                    128 => "roundq",
                                },
                                .trunc_float => switch (bits) {
                                    else => unreachable,
                                    16 => "__trunch",
                                    32 => "truncf",
                                    64 => "trunc",
                                    80 => "__truncx",
                                    128 => "truncq",
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(un_op);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.paramLiveOut(isel, src_vi, .v0),
                            80 => {
                                var src_hi16_it = src_vi.field(ty, 8, 8);
                                const src_hi16_vi = try src_hi16_it.only(isel);
                                try call.paramLiveOut(isel, src_hi16_vi.?, .r1);
                                var src_lo64_it = src_vi.field(ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try call.paramLiveOut(isel, src_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .sin, .cos, .tan, .exp, .exp2, .log, .log2, .log10 => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| {
                defer res_vi.value.deref(isel);

                const un_op = air.data(air.inst_index).un_op;
                const ty = isel.air.typeOf(un_op, ip);
                const bits = ty.floatBits(isel.target);
                try call.prepareReturn(isel);
                switch (bits) {
                    else => unreachable,
                    16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                    80 => {
                        var res_hi16_it = res_vi.value.field(ty, 8, 8);
                        const res_hi16_vi = try res_hi16_it.only(isel);
                        try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                        var res_lo64_it = res_vi.value.field(ty, 0, 8);
                        const res_lo64_vi = try res_lo64_it.only(isel);
                        try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                    },
                }
                try call.finishReturn(isel);

                try call.prepareCallee(isel);
                try isel.global_relocs.append(gpa, .{
                    .name = switch (air_tag) {
                        else => unreachable,
                        .sin => switch (bits) {
                            else => unreachable,
                            16 => "__sinh",
                            32 => "sinf",
                            64 => "sin",
                            80 => "__sinx",
                            128 => "sinq",
                        },
                        .cos => switch (bits) {
                            else => unreachable,
                            16 => "__cosh",
                            32 => "cosf",
                            64 => "cos",
                            80 => "__cosx",
                            128 => "cosq",
                        },
                        .tan => switch (bits) {
                            else => unreachable,
                            16 => "__tanh",
                            32 => "tanf",
                            64 => "tan",
                            80 => "__tanx",
                            128 => "tanq",
                        },
                        .exp => switch (bits) {
                            else => unreachable,
                            16 => "__exph",
                            32 => "expf",
                            64 => "exp",
                            80 => "__expx",
                            128 => "expq",
                        },
                        .exp2 => switch (bits) {
                            else => unreachable,
                            16 => "__exp2h",
                            32 => "exp2f",
                            64 => "exp2",
                            80 => "__exp2x",
                            128 => "exp2q",
                        },
                        .log => switch (bits) {
                            else => unreachable,
                            16 => "__logh",
                            32 => "logf",
                            64 => "log",
                            80 => "__logx",
                            128 => "logq",
                        },
                        .log2 => switch (bits) {
                            else => unreachable,
                            16 => "__log2h",
                            32 => "log2f",
                            64 => "log2",
                            80 => "__log2x",
                            128 => "log2q",
                        },
                        .log10 => switch (bits) {
                            else => unreachable,
                            16 => "__log10h",
                            32 => "log10f",
                            64 => "log10",
                            80 => "__log10x",
                            128 => "log10q",
                        },
                    },
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.bl(0));
                try call.finishCallee(isel);

                try call.prepareParams(isel);
                const src_vi = try isel.use(un_op);
                switch (bits) {
                    else => unreachable,
                    16, 32, 64, 128 => try call.paramLiveOut(isel, src_vi, .v0),
                    80 => {
                        var src_hi16_it = src_vi.field(ty, 8, 8);
                        const src_hi16_vi = try src_hi16_it.only(isel);
                        try call.paramLiveOut(isel, src_hi16_vi.?, .r1);
                        var src_lo64_it = src_vi.field(ty, 0, 8);
                        const src_lo64_vi = try src_lo64_it.only(isel);
                        try call.paramLiveOut(isel, src_lo64_vi.?, .r0);
                    },
                }
                try call.finishParams(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .abs => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const ty = ty_op.ty.toType();
                if (!ty.isRuntimeFloat()) {
                    if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    switch (ty.intInfo(zcu).bits) {
                        0 => unreachable,
                        1...32 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.csneg(res_ra.w(), src_mat.ra.w(), src_mat.ra.w(), .pl));
                            try isel.emit(.subs(.wzr, src_mat.ra.w(), .{ .immediate = 0 }));
                            try src_mat.finish(isel);
                        },
                        33...64 => {
                            const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                            const src_vi = try isel.use(ty_op.operand);
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.csneg(res_ra.x(), src_mat.ra.x(), src_mat.ra.x(), .pl));
                            try isel.emit(.subs(.xzr, src_mat.ra.x(), .{ .immediate = 0 }));
                            try src_mat.finish(isel);
                        },
                        65...128 => {
                            var res_hi64_it = res_vi.value.field(ty, 8, 8);
                            const res_hi64_vi = try res_hi64_it.only(isel);
                            const res_hi64_ra = try res_hi64_vi.?.defReg(isel);
                            var res_lo64_it = res_vi.value.field(ty, 0, 8);
                            const res_lo64_vi = try res_lo64_it.only(isel);
                            const res_lo64_ra = try res_lo64_vi.?.defReg(isel);
                            if (res_hi64_ra == null and res_lo64_ra == null) break :unused;
                            const src_ty = isel.air.typeOf(ty_op.operand, ip);
                            const src_vi = try isel.use(ty_op.operand);
                            var src_hi64_it = src_vi.field(src_ty, 8, 8);
                            const src_hi64_vi = try src_hi64_it.only(isel);
                            const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                            var src_lo64_it = src_vi.field(src_ty, 0, 8);
                            const src_lo64_vi = try src_lo64_it.only(isel);
                            const src_lo64_mat = try src_lo64_vi.?.matReg(isel);
                            const lo64_ra = try isel.allocIntReg();
                            defer isel.freeReg(lo64_ra);
                            const hi64_ra, const mask_ra = alloc_ras: {
                                const res_lo64_lock: RegLock = if (res_lo64_ra) |res_ra| isel.tryLockReg(res_ra) else .empty;
                                defer res_lo64_lock.unlock(isel);
                                break :alloc_ras .{ try isel.allocIntReg(), try isel.allocIntReg() };
                            };
                            defer {
                                isel.freeReg(hi64_ra);
                                isel.freeReg(mask_ra);
                            }
                            if (res_hi64_ra) |res_ra| try isel.emit(.sbc(res_ra.x(), hi64_ra.x(), mask_ra.x()));
                            try isel.emit(.subs(
                                if (res_lo64_ra) |res_ra| res_ra.x() else .xzr,
                                lo64_ra.x(),
                                .{ .register = mask_ra.x() },
                            ));
                            if (res_hi64_ra) |_| try isel.emit(.eor(hi64_ra.x(), src_hi64_mat.ra.x(), .{ .register = mask_ra.x() }));
                            try isel.emit(.eor(lo64_ra.x(), src_lo64_mat.ra.x(), .{ .register = mask_ra.x() }));
                            try isel.emit(.sbfm(mask_ra.x(), src_hi64_mat.ra.x(), .{
                                .N = .doubleword,
                                .immr = 64 - 1,
                                .imms = 64 - 1,
                            }));
                            try src_lo64_mat.finish(isel);
                            try src_hi64_mat.finish(isel);
                        },
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) }),
                    }
                } else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(if (isel.target.cpu.has(.aarch64, .fullfp16))
                            .fabs(res_ra.h(), src_mat.ra.h())
                        else
                            .bic(res_ra.@"4h"(), res_ra.@"4h"(), .{ .shifted_immediate = .{
                                .immediate = 0b10000000,
                                .lsl = 8,
                            } }));
                        try src_mat.finish(isel);
                    },
                    32 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(.fabs(res_ra.s(), src_mat.ra.s()));
                        try src_mat.finish(isel);
                    },
                    64 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(.fabs(res_ra.d(), src_mat.ra.d()));
                        try src_mat.finish(isel);
                    },
                    80 => {
                        const src_vi = try isel.use(ty_op.operand);
                        var res_hi16_it = res_vi.value.field(ty, 8, 8);
                        const res_hi16_vi = try res_hi16_it.only(isel);
                        if (try res_hi16_vi.?.defReg(isel)) |res_hi16_ra| {
                            var src_hi16_it = src_vi.field(ty, 8, 8);
                            const src_hi16_vi = try src_hi16_it.only(isel);
                            const src_hi16_mat = try src_hi16_vi.?.matReg(isel);
                            try isel.emit(.@"and"(res_hi16_ra.w(), src_hi16_mat.ra.w(), .{ .immediate = .{
                                .N = .word,
                                .immr = 0,
                                .imms = 15 - 1,
                            } }));
                            try src_hi16_mat.finish(isel);
                        }
                        var res_lo64_it = res_vi.value.field(ty, 0, 8);
                        const res_lo64_vi = try res_lo64_it.only(isel);
                        if (try res_lo64_vi.?.defReg(isel)) |res_lo64_ra| {
                            var src_lo64_it = src_vi.field(ty, 0, 8);
                            const src_lo64_vi = try src_lo64_it.only(isel);
                            try src_lo64_vi.?.liveOut(isel, res_lo64_ra);
                        }
                    },
                    128 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        const neg_zero_ra = try isel.allocVecReg();
                        defer isel.freeReg(neg_zero_ra);
                        try isel.emit(.bic(res_ra.@"16b"(), src_mat.ra.@"16b"(), .{ .register = neg_zero_ra.@"16b"() }));
                        try isel.literals.appendNTimes(gpa, 0, -%isel.literals.items.len % 4);
                        try isel.literal_relocs.append(gpa, .{
                            .label = @intCast(isel.instructions.items.len),
                        });
                        try isel.emit(.ldr(neg_zero_ra.q(), .{
                            .literal = @intCast((isel.instructions.items.len + 1 + isel.literals.items.len) << 2),
                        }));
                        try isel.emitLiteral(&(.{0} ** 15 ++ .{0x80}));
                        try src_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .neg, .neg_optimized => {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const un_op = air.data(air.inst_index).un_op;
                const ty = isel.air.typeOf(un_op, ip);
                switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(un_op);
                        const src_mat = try src_vi.matReg(isel);
                        if (isel.target.cpu.has(.aarch64, .fullfp16)) {
                            try isel.emit(.fneg(res_ra.h(), src_mat.ra.h()));
                        } else {
                            const neg_zero_ra = try isel.allocVecReg();
                            defer isel.freeReg(neg_zero_ra);
                            try isel.emit(.eor(res_ra.@"8b"(), res_ra.@"8b"(), .{ .register = neg_zero_ra.@"8b"() }));
                            try isel.emit(.movi(neg_zero_ra.@"4h"(), 0b10000000, .{ .lsl = 8 }));
                        }
                        try src_mat.finish(isel);
                    },
                    32 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(un_op);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(.fneg(res_ra.s(), src_mat.ra.s()));
                        try src_mat.finish(isel);
                    },
                    64 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(un_op);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(.fneg(res_ra.d(), src_mat.ra.d()));
                        try src_mat.finish(isel);
                    },
                    80 => {
                        const src_vi = try isel.use(un_op);
                        var res_hi16_it = res_vi.value.field(ty, 8, 8);
                        const res_hi16_vi = try res_hi16_it.only(isel);
                        if (try res_hi16_vi.?.defReg(isel)) |res_hi16_ra| {
                            var src_hi16_it = src_vi.field(ty, 8, 8);
                            const src_hi16_vi = try src_hi16_it.only(isel);
                            const src_hi16_mat = try src_hi16_vi.?.matReg(isel);
                            try isel.emit(.eor(res_hi16_ra.w(), src_hi16_mat.ra.w(), .{ .immediate = .{
                                .N = .word,
                                .immr = 32 - 15,
                                .imms = 1 - 1,
                            } }));
                            try src_hi16_mat.finish(isel);
                        }
                        var res_lo64_it = res_vi.value.field(ty, 0, 8);
                        const res_lo64_vi = try res_lo64_it.only(isel);
                        if (try res_lo64_vi.?.defReg(isel)) |res_lo64_ra| {
                            var src_lo64_it = src_vi.field(ty, 0, 8);
                            const src_lo64_vi = try src_lo64_it.only(isel);
                            try src_lo64_vi.?.liveOut(isel, res_lo64_ra);
                        }
                    },
                    128 => {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(un_op);
                        const src_mat = try src_vi.matReg(isel);
                        const neg_zero_ra = try isel.allocVecReg();
                        defer isel.freeReg(neg_zero_ra);
                        try isel.emit(.eor(res_ra.@"16b"(), src_mat.ra.@"16b"(), .{ .register = neg_zero_ra.@"16b"() }));
                        try isel.literals.appendNTimes(gpa, 0, -%isel.literals.items.len % 4);
                        try isel.literal_relocs.append(gpa, .{
                            .label = @intCast(isel.instructions.items.len),
                        });
                        try isel.emit(.ldr(neg_zero_ra.q(), .{
                            .literal = @intCast((isel.instructions.items.len + 1 + isel.literals.items.len) << 2),
                        }));
                        try isel.emitLiteral(&(.{0} ** 15 ++ .{0x80}));
                        try src_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .cmp_lt, .cmp_lte, .cmp_eq, .cmp_gte, .cmp_gt, .cmp_neq => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                var bin_op = air.data(air.inst_index).bin_op;
                const ty = isel.air.typeOf(bin_op.lhs, ip);
                if (!ty.isRuntimeFloat()) {
                    const int_info: std.builtin.Type.Int = if (ty.toIntern() == .bool_type)
                        .{ .signedness = .unsigned, .bits = 1 }
                    else if (ty.isAbiInt(zcu))
                        ty.intInfo(zcu)
                    else if (ty.isPtrAtRuntime(zcu))
                        .{ .signedness = .unsigned, .bits = 64 }
                    else
                        return isel.fail("bad {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });
                    if (int_info.bits > 256) return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(ty) });

                    const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                    try isel.emit(.csinc(res_ra.w(), .wzr, .wzr, .invert(cond: switch (air_tag) {
                        else => unreachable,
                        .cmp_lt => switch (int_info.signedness) {
                            .signed => .lt,
                            .unsigned => .lo,
                        },
                        .cmp_lte => switch (int_info.bits) {
                            else => unreachable,
                            1...64 => switch (int_info.signedness) {
                                .signed => .le,
                                .unsigned => .ls,
                            },
                            65...128 => {
                                std.mem.swap(Air.Inst.Ref, &bin_op.lhs, &bin_op.rhs);
                                continue :cond .cmp_gte;
                            },
                        },
                        .cmp_eq => .eq,
                        .cmp_gte => switch (int_info.signedness) {
                            .signed => .ge,
                            .unsigned => .hs,
                        },
                        .cmp_gt => switch (int_info.bits) {
                            else => unreachable,
                            1...64 => switch (int_info.signedness) {
                                .signed => .gt,
                                .unsigned => .hi,
                            },
                            65...128 => {
                                std.mem.swap(Air.Inst.Ref, &bin_op.lhs, &bin_op.rhs);
                                continue :cond .cmp_lt;
                            },
                        },
                        .cmp_neq => .ne,
                    })));

                    const lhs_vi = try isel.use(bin_op.lhs);
                    const rhs_vi = try isel.use(bin_op.rhs);
                    var part_offset = lhs_vi.size(isel);
                    while (part_offset > 0) {
                        const part_size = @min(part_offset, 8);
                        part_offset -= part_size;
                        var lhs_part_it = lhs_vi.field(ty, part_offset, part_size);
                        const lhs_part_vi = try lhs_part_it.only(isel);
                        const lhs_part_mat = try lhs_part_vi.?.matReg(isel);
                        var rhs_part_it = rhs_vi.field(ty, part_offset, part_size);
                        const rhs_part_vi = try rhs_part_it.only(isel);
                        const rhs_part_mat = try rhs_part_vi.?.matReg(isel);
                        try isel.emit(switch (part_size) {
                            else => unreachable,
                            1...4 => switch (part_offset) {
                                0 => .subs(.wzr, lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                                else => switch (air_tag) {
                                    else => unreachable,
                                    .cmp_lt, .cmp_lte, .cmp_gte, .cmp_gt => .sbcs(
                                        .wzr,
                                        lhs_part_mat.ra.w(),
                                        rhs_part_mat.ra.w(),
                                    ),
                                    .cmp_eq, .cmp_neq => .ccmp(
                                        lhs_part_mat.ra.w(),
                                        .{ .register = rhs_part_mat.ra.w() },
                                        .{ .n = false, .z = false, .c = false, .v = false },
                                        .eq,
                                    ),
                                },
                            },
                            5...8 => switch (part_offset) {
                                0 => .subs(.xzr, lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                                else => switch (air_tag) {
                                    else => unreachable,
                                    .cmp_lt, .cmp_lte, .cmp_gte, .cmp_gt => .sbcs(
                                        .xzr,
                                        lhs_part_mat.ra.x(),
                                        rhs_part_mat.ra.x(),
                                    ),
                                    .cmp_eq, .cmp_neq => .ccmp(
                                        lhs_part_mat.ra.x(),
                                        .{ .register = rhs_part_mat.ra.x() },
                                        .{ .n = false, .z = false, .c = false, .v = false },
                                        .eq,
                                    ),
                                },
                            },
                        });
                        try rhs_part_mat.finish(isel);
                        try lhs_part_mat.finish(isel);
                    }
                } else switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        try isel.emit(.csinc(res_ra.w(), .wzr, .wzr, .invert(switch (air_tag) {
                            else => unreachable,
                            .cmp_lt => .lo,
                            .cmp_lte => .ls,
                            .cmp_eq => .eq,
                            .cmp_gte => .ge,
                            .cmp_gt => .gt,
                            .cmp_neq => .ne,
                        })));

                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt)
                                continue :bits 32
                            else
                                .fcmp(lhs_ra.h(), .{ .register = rhs_ra.h() }),
                            32 => .fcmp(lhs_ra.s(), .{ .register = rhs_ra.s() }),
                            64 => .fcmp(lhs_ra.d(), .{ .register = rhs_ra.d() }),
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;

                        try call.prepareReturn(isel);
                        try call.returnFill(isel, .r0);
                        try isel.emit(.csinc(res_ra.w(), .wzr, .wzr, .invert(cond: switch (air_tag) {
                            else => unreachable,
                            .cmp_lt => .lt,
                            .cmp_lte => .le,
                            .cmp_eq => .eq,
                            .cmp_gte => {
                                std.mem.swap(Air.Inst.Ref, &bin_op.lhs, &bin_op.rhs);
                                continue :cond .cmp_lte;
                            },
                            .cmp_gt => {
                                std.mem.swap(Air.Inst.Ref, &bin_op.lhs, &bin_op.rhs);
                                continue :cond .cmp_lt;
                            },
                            .cmp_neq => .ne,
                        })));
                        try isel.emit(.subs(.wzr, .w0, .{ .immediate = 0 }));
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (bits) {
                                else => unreachable,
                                16 => "__cmphf2",
                                32 => "__cmpsf2",
                                64 => "__cmpdf2",
                                80 => "__cmpxf2",
                                128 => "__cmptf2",
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .cond_br => {
            const pl_op = air.data(air.inst_index).pl_op;
            const extra = isel.air.extraData(Air.CondBr, pl_op.payload);

            try isel.body(@ptrCast(isel.air.extra.items[extra.end + extra.data.then_body_len ..][0..extra.data.else_body_len]));
            const else_label = isel.instructions.items.len;
            const else_live_registers = isel.live_registers;
            try isel.body(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.then_body_len]));
            try isel.merge(&else_live_registers, .{});

            const cond_vi = try isel.use(pl_op.operand);
            const cond_mat = try cond_vi.matReg(isel);
            try isel.emit(.tbz(
                cond_mat.ra.x(),
                0,
                @intCast((isel.instructions.items.len + 1 - else_label) << 2),
            ));
            try cond_mat.finish(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .switch_br => {
            const switch_br = isel.air.unwrapSwitch(air.inst_index);
            const cond_ty = isel.air.typeOf(switch_br.operand, ip);
            const cond_int_info: std.builtin.Type.Int = if (cond_ty.toIntern() == .bool_type)
                .{ .signedness = .unsigned, .bits = 1 }
            else if (cond_ty.isAbiInt(zcu))
                cond_ty.intInfo(zcu)
            else
                return isel.fail("bad switch cond {f}", .{isel.fmtType(cond_ty)});

            var final_case = true;
            if (switch_br.else_body_len > 0) {
                var cases_it = switch_br.iterateCases();
                while (cases_it.next()) |_| {}
                try isel.body(cases_it.elseBody());
                assert(final_case);
                final_case = false;
            }
            const zero_reg: Register = switch (cond_int_info.bits) {
                else => unreachable,
                1...32 => .wzr,
                33...64 => .xzr,
            };
            var cond_mat: ?Value.Materialize = null;
            var cond_reg: Register = undefined;
            var cases_it = switch_br.iterateCases();
            while (cases_it.next()) |case| {
                const next_label = isel.instructions.items.len;
                const next_live_registers = isel.live_registers;
                try isel.body(case.body);
                if (final_case) {
                    final_case = false;
                    continue;
                }
                try isel.merge(&next_live_registers, .{});
                if (cond_mat == null) {
                    var cond_vi = try isel.use(switch_br.operand);
                    cond_mat = try cond_vi.matReg(isel);
                    cond_reg = switch (cond_int_info.bits) {
                        else => unreachable,
                        1...32 => cond_mat.?.ra.w(),
                        33...64 => cond_mat.?.ra.x(),
                    };
                }
                if (case.ranges.len == 0 and case.items.len == 1 and Constant.fromInterned(
                    case.items[0].toInterned().?,
                ).orderAgainstZero(zcu).compare(.eq)) {
                    try isel.emit(.cbnz(
                        cond_reg,
                        @intCast((isel.instructions.items.len + 1 - next_label) << 2),
                    ));
                    continue;
                }
                try isel.emit(.@"b."(
                    .invert(switch (case.ranges.len) {
                        0 => .eq,
                        else => .ls,
                    }),
                    @intCast((isel.instructions.items.len + 1 - next_label) << 2),
                ));
                var case_range_index = case.ranges.len;
                while (case_range_index > 0) {
                    case_range_index -= 1;

                    const low_val: Constant = .fromInterned(case.ranges[case_range_index][0].toInterned().?);
                    var low_bigint_space: Constant.BigIntSpace = undefined;
                    const low_bigint = low_val.toBigInt(&low_bigint_space, zcu);
                    const low_int: i64 = if (low_bigint.positive) @bitCast(
                        low_bigint.toInt(u64) catch
                            return isel.fail("too big case range start: {f}", .{isel.fmtConstant(low_val)}),
                    ) else low_bigint.toInt(i64) catch
                        return isel.fail("too big case range start: {f}", .{isel.fmtConstant(low_val)});

                    const high_val: Constant = .fromInterned(case.ranges[case_range_index][1].toInterned().?);
                    var high_bigint_space: Constant.BigIntSpace = undefined;
                    const high_bigint = high_val.toBigInt(&high_bigint_space, zcu);
                    const high_int: i64 = if (high_bigint.positive) @bitCast(
                        high_bigint.toInt(u64) catch
                            return isel.fail("too big case range end: {f}", .{isel.fmtConstant(high_val)}),
                    ) else high_bigint.toInt(i64) catch
                        return isel.fail("too big case range end: {f}", .{isel.fmtConstant(high_val)});

                    const adjusted_ra = switch (low_int) {
                        0 => cond_mat.?.ra,
                        else => try isel.allocIntReg(),
                    };
                    defer if (adjusted_ra != cond_mat.?.ra) isel.freeReg(adjusted_ra);
                    const adjusted_reg = switch (cond_int_info.bits) {
                        else => unreachable,
                        1...32 => adjusted_ra.w(),
                        33...64 => adjusted_ra.x(),
                    };
                    const delta_int = high_int -% low_int;
                    if (case_range_index | case.items.len > 0) {
                        if (std.math.cast(u5, delta_int)) |pos_imm| try isel.emit(.ccmp(
                            adjusted_reg,
                            .{ .immediate = pos_imm },
                            .{ .n = false, .z = true, .c = false, .v = false },
                            if (case_range_index > 0) .hi else .ne,
                        )) else if (std.math.cast(u5, -delta_int)) |neg_imm| try isel.emit(.ccmn(
                            adjusted_reg,
                            .{ .immediate = neg_imm },
                            .{ .n = false, .z = true, .c = false, .v = false },
                            if (case_range_index > 0) .hi else .ne,
                        )) else {
                            const imm_ra = try isel.allocIntReg();
                            defer isel.freeReg(imm_ra);
                            const imm_reg = switch (cond_int_info.bits) {
                                else => unreachable,
                                1...32 => imm_ra.w(),
                                33...64 => imm_ra.x(),
                            };
                            try isel.emit(.ccmp(
                                cond_reg,
                                .{ .register = imm_reg },
                                .{ .n = false, .z = true, .c = false, .v = false },
                                if (case_range_index > 0) .hi else .ne,
                            ));
                            try isel.movImmediate(imm_reg, @bitCast(delta_int));
                        }
                    } else {
                        if (std.math.cast(u12, delta_int)) |pos_imm| try isel.emit(.subs(
                            zero_reg,
                            adjusted_reg,
                            .{ .immediate = pos_imm },
                        )) else if (std.math.cast(u12, -delta_int)) |neg_imm| try isel.emit(.adds(
                            zero_reg,
                            adjusted_reg,
                            .{ .immediate = neg_imm },
                        )) else if (if (@as(i12, @truncate(delta_int)) == 0)
                            std.math.cast(u12, delta_int >> 12)
                        else
                            null) |pos_imm_lsr_12| try isel.emit(.subs(
                            zero_reg,
                            adjusted_reg,
                            .{ .shifted_immediate = .{ .immediate = pos_imm_lsr_12, .lsl = .@"12" } },
                        )) else if (if (@as(i12, @truncate(-delta_int)) == 0)
                            std.math.cast(u12, -delta_int >> 12)
                        else
                            null) |neg_imm_lsr_12| try isel.emit(.adds(
                            zero_reg,
                            adjusted_reg,
                            .{ .shifted_immediate = .{ .immediate = neg_imm_lsr_12, .lsl = .@"12" } },
                        )) else {
                            const imm_ra = try isel.allocIntReg();
                            defer isel.freeReg(imm_ra);
                            const imm_reg = switch (cond_int_info.bits) {
                                else => unreachable,
                                1...32 => imm_ra.w(),
                                33...64 => imm_ra.x(),
                            };
                            try isel.emit(.subs(zero_reg, adjusted_reg, .{ .register = imm_reg }));
                            try isel.movImmediate(imm_reg, @bitCast(delta_int));
                        }
                    }

                    switch (low_int) {
                        0 => {},
                        else => {
                            if (std.math.cast(u12, low_int)) |pos_imm| try isel.emit(.sub(
                                adjusted_reg,
                                cond_reg,
                                .{ .immediate = pos_imm },
                            )) else if (std.math.cast(u12, -low_int)) |neg_imm| try isel.emit(.add(
                                adjusted_reg,
                                cond_reg,
                                .{ .immediate = neg_imm },
                            )) else if (if (@as(i12, @truncate(low_int)) == 0)
                                std.math.cast(u12, low_int >> 12)
                            else
                                null) |pos_imm_lsr_12| try isel.emit(.sub(
                                adjusted_reg,
                                cond_reg,
                                .{ .shifted_immediate = .{ .immediate = pos_imm_lsr_12, .lsl = .@"12" } },
                            )) else if (if (@as(i12, @truncate(-low_int)) == 0)
                                std.math.cast(u12, -low_int >> 12)
                            else
                                null) |neg_imm_lsr_12| try isel.emit(.add(
                                adjusted_reg,
                                cond_reg,
                                .{ .shifted_immediate = .{ .immediate = neg_imm_lsr_12, .lsl = .@"12" } },
                            )) else {
                                const imm_ra = try isel.allocIntReg();
                                defer isel.freeReg(imm_ra);
                                const imm_reg = switch (cond_int_info.bits) {
                                    else => unreachable,
                                    1...32 => imm_ra.w(),
                                    33...64 => imm_ra.x(),
                                };
                                try isel.emit(.sub(adjusted_reg, cond_reg, .{ .register = imm_reg }));
                                try isel.movImmediate(imm_reg, @bitCast(low_int));
                            }
                        },
                    }
                }
                var case_item_index = case.items.len;
                while (case_item_index > 0) {
                    case_item_index -= 1;

                    const item_val: Constant = .fromInterned(case.items[case_item_index].toInterned().?);
                    var item_bigint_space: Constant.BigIntSpace = undefined;
                    const item_bigint = item_val.toBigInt(&item_bigint_space, zcu);
                    const item_int: i64 = if (item_bigint.positive) @bitCast(
                        item_bigint.toInt(u64) catch
                            return isel.fail("too big case item: {f}", .{isel.fmtConstant(item_val)}),
                    ) else item_bigint.toInt(i64) catch
                        return isel.fail("too big case item: {f}", .{isel.fmtConstant(item_val)});

                    if (case_item_index > 0) {
                        if (std.math.cast(u5, item_int)) |pos_imm| try isel.emit(.ccmp(
                            cond_reg,
                            .{ .immediate = pos_imm },
                            .{ .n = false, .z = true, .c = false, .v = false },
                            .ne,
                        )) else if (std.math.cast(u5, -item_int)) |neg_imm| try isel.emit(.ccmn(
                            cond_reg,
                            .{ .immediate = neg_imm },
                            .{ .n = false, .z = true, .c = false, .v = false },
                            .ne,
                        )) else {
                            const imm_ra = try isel.allocIntReg();
                            defer isel.freeReg(imm_ra);
                            const imm_reg = switch (cond_int_info.bits) {
                                else => unreachable,
                                1...32 => imm_ra.w(),
                                33...64 => imm_ra.x(),
                            };
                            try isel.emit(.ccmp(
                                cond_reg,
                                .{ .register = imm_reg },
                                .{ .n = false, .z = true, .c = false, .v = false },
                                .ne,
                            ));
                            try isel.movImmediate(imm_reg, @bitCast(item_int));
                        }
                    } else {
                        if (std.math.cast(u12, item_int)) |pos_imm| try isel.emit(.subs(
                            zero_reg,
                            cond_reg,
                            .{ .immediate = pos_imm },
                        )) else if (std.math.cast(u12, -item_int)) |neg_imm| try isel.emit(.adds(
                            zero_reg,
                            cond_reg,
                            .{ .immediate = neg_imm },
                        )) else if (if (@as(i12, @truncate(item_int)) == 0)
                            std.math.cast(u12, item_int >> 12)
                        else
                            null) |pos_imm_lsr_12| try isel.emit(.subs(
                            zero_reg,
                            cond_reg,
                            .{ .shifted_immediate = .{ .immediate = pos_imm_lsr_12, .lsl = .@"12" } },
                        )) else if (if (@as(i12, @truncate(-item_int)) == 0)
                            std.math.cast(u12, -item_int >> 12)
                        else
                            null) |neg_imm_lsr_12| try isel.emit(.adds(
                            zero_reg,
                            cond_reg,
                            .{ .shifted_immediate = .{ .immediate = neg_imm_lsr_12, .lsl = .@"12" } },
                        )) else {
                            const imm_ra = try isel.allocIntReg();
                            defer isel.freeReg(imm_ra);
                            const imm_reg = switch (cond_int_info.bits) {
                                else => unreachable,
                                1...32 => imm_ra.w(),
                                33...64 => imm_ra.x(),
                            };
                            try isel.emit(.subs(zero_reg, cond_reg, .{ .register = imm_reg }));
                            try isel.movImmediate(imm_reg, @bitCast(item_int));
                        }
                    }
                }
            }
            if (cond_mat) |mat| try mat.finish(isel);
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .@"try", .try_cold => {
            const pl_op = air.data(air.inst_index).pl_op;
            const extra = isel.air.extraData(Air.Try, pl_op.payload);
            const error_union_ty = isel.air.typeOf(pl_op.operand, ip);
            const error_union_info = ip.indexToKey(error_union_ty.toIntern()).error_union_type;
            const payload_ty: ZigType = .fromInterned(error_union_info.payload_type);

            const error_union_vi = try isel.use(pl_op.operand);
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_vi| {
                defer payload_vi.value.deref(isel);

                var payload_part_it = error_union_vi.field(
                    error_union_ty,
                    codegen.errUnionPayloadOffset(payload_ty, zcu),
                    payload_vi.value.size(isel),
                );
                const payload_part_vi = try payload_part_it.only(isel);
                try payload_vi.value.copy(isel, payload_ty, payload_part_vi.?);
            }

            const cont_label = isel.instructions.items.len;
            const cont_live_registers = isel.live_registers;
            try isel.body(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            try isel.merge(&cont_live_registers, .{});

            var error_set_part_it = error_union_vi.field(
                error_union_ty,
                codegen.errUnionErrorOffset(payload_ty, zcu),
                ZigType.fromInterned(error_union_info.error_set_type).abiSize(zcu),
            );
            const error_set_part_vi = try error_set_part_it.only(isel);
            const error_set_part_mat = try error_set_part_vi.?.matReg(isel);
            try isel.emit(.cbz(
                error_set_part_mat.ra.w(),
                @intCast((isel.instructions.items.len + 1 - cont_label) << 2),
            ));
            try error_set_part_mat.finish(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .try_ptr, .try_ptr_cold => {
            const ty_pl = air.data(air.inst_index).ty_pl;
            const extra = isel.air.extraData(Air.TryPtr, ty_pl.payload);
            const error_union_ty = isel.air.typeOf(extra.data.ptr, ip).childType(zcu);
            const error_union_info = ip.indexToKey(error_union_ty.toIntern()).error_union_type;
            const payload_ty: ZigType = .fromInterned(error_union_info.payload_type);

            const error_union_ptr_vi = try isel.use(extra.data.ptr);
            const error_union_ptr_mat = try error_union_ptr_vi.matReg(isel);
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_ptr_vi| unused: {
                defer payload_ptr_vi.value.deref(isel);
                switch (codegen.errUnionPayloadOffset(ty_pl.ty.toType().childType(zcu), zcu)) {
                    0 => try payload_ptr_vi.value.move(isel, extra.data.ptr),
                    else => |payload_offset| {
                        const payload_ptr_ra = try payload_ptr_vi.value.defReg(isel) orelse break :unused;
                        const lo12: u12 = @truncate(payload_offset >> 0);
                        const hi12: u12 = @intCast(payload_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            payload_ptr_ra.x(),
                            if (lo12 > 0) payload_ptr_ra.x() else error_union_ptr_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(payload_ptr_ra.x(), error_union_ptr_mat.ra.x(), .{ .immediate = lo12 }));
                    },
                }
            }

            const cont_label = isel.instructions.items.len;
            const cont_live_registers = isel.live_registers;
            try isel.body(@ptrCast(isel.air.extra.items[extra.end..][0..extra.data.body_len]));
            try isel.merge(&cont_live_registers, .{});

            const error_set_ra = try isel.allocIntReg();
            defer isel.freeReg(error_set_ra);
            try isel.loadReg(
                error_set_ra,
                ZigType.fromInterned(error_union_info.error_set_type).abiSize(zcu),
                .unsigned,
                error_union_ptr_mat.ra,
                codegen.errUnionErrorOffset(payload_ty, zcu),
            );
            try error_union_ptr_mat.finish(isel);
            try isel.emit(.cbz(
                error_set_ra.w(),
                @intCast((isel.instructions.items.len + 1 - cont_label) << 2),
            ));

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .dbg_stmt => if (air.next()) |next_air_tag| continue :air_tag next_air_tag,
        .dbg_empty_stmt => {
            try isel.emit(.nop());
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .dbg_inline_block => {
            const ty_pl = air.data(air.inst_index).ty_pl;
            const extra = isel.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
            try isel.block(air.inst_index, ty_pl.ty.toType(), @ptrCast(
                isel.air.extra.items[extra.end..][0..extra.data.body_len],
            ));
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .dbg_var_ptr, .dbg_var_val, .dbg_arg_inline => {
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .is_null, .is_non_null => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |is_vi| unused: {
                defer is_vi.value.deref(isel);
                const is_ra = try is_vi.value.defReg(isel) orelse break :unused;

                const un_op = air.data(air.inst_index).un_op;
                const opt_ty = isel.air.typeOf(un_op, ip);
                const payload_ty = opt_ty.optionalChild(zcu);
                const payload_size = payload_ty.abiSize(zcu);
                const has_value_offset, const has_value_size = if (!opt_ty.optionalReprIsPayload(zcu))
                    .{ payload_size, 1 }
                else if (payload_ty.isSlice(zcu))
                    .{ 0, 8 }
                else
                    .{ 0, payload_size };

                try isel.emit(.csinc(is_ra.w(), .wzr, .wzr, .invert(switch (air_tag) {
                    else => unreachable,
                    .is_null => .eq,
                    .is_non_null => .ne,
                })));
                const opt_vi = try isel.use(un_op);
                var has_value_part_it = opt_vi.field(opt_ty, has_value_offset, has_value_size);
                const has_value_part_vi = try has_value_part_it.only(isel);
                const has_value_part_mat = try has_value_part_vi.?.matReg(isel);
                try isel.emit(switch (has_value_size) {
                    else => unreachable,
                    1...4 => .subs(.wzr, has_value_part_mat.ra.w(), .{ .immediate = 0 }),
                    5...8 => .subs(.xzr, has_value_part_mat.ra.x(), .{ .immediate = 0 }),
                });
                try has_value_part_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .is_err, .is_non_err => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |is_vi| unused: {
                defer is_vi.value.deref(isel);
                const is_ra = try is_vi.value.defReg(isel) orelse break :unused;

                const un_op = air.data(air.inst_index).un_op;
                const error_union_ty = isel.air.typeOf(un_op, ip);
                const error_union_info = ip.indexToKey(error_union_ty.toIntern()).error_union_type;
                const error_set_ty: ZigType = .fromInterned(error_union_info.error_set_type);
                const payload_ty: ZigType = .fromInterned(error_union_info.payload_type);
                const error_set_offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                const error_set_size = error_set_ty.abiSize(zcu);

                try isel.emit(.csinc(is_ra.w(), .wzr, .wzr, .invert(switch (air_tag) {
                    else => unreachable,
                    .is_err => .ne,
                    .is_non_err => .eq,
                })));
                const error_union_vi = try isel.use(un_op);
                var error_set_part_it = error_union_vi.field(error_union_ty, error_set_offset, error_set_size);
                const error_set_part_vi = try error_set_part_it.only(isel);
                const error_set_part_mat = try error_set_part_vi.?.matReg(isel);
                try isel.emit(.ands(.wzr, error_set_part_mat.ra.w(), .{ .immediate = .{
                    .N = .word,
                    .immr = 0,
                    .imms = @intCast(8 * error_set_size - 1),
                } }));
                try error_set_part_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .load => {
            const ty_op = air.data(air.inst_index).ty_op;
            const ptr_ty = isel.air.typeOf(ty_op.operand, ip);
            const ptr_info = ptr_ty.ptrInfo(zcu);
            if (ptr_info.packed_offset.host_size > 0) return isel.fail("packed load", .{});

            if (ptr_info.flags.is_volatile) _ = try isel.use(air.inst_index.toRef());
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const size = dst_vi.value.size(isel);
                if (size <= Value.max_parts and ip.zigTypeTag(ptr_info.child) != .@"union") {
                    const ptr_vi = try isel.use(ty_op.operand);
                    const ptr_mat = try ptr_vi.matReg(isel);
                    _ = try dst_vi.value.load(isel, ty_op.ty.toType(), ptr_mat.ra, .{
                        .@"volatile" = ptr_info.flags.is_volatile,
                    });
                    try ptr_mat.finish(isel);
                } else {
                    try dst_vi.value.defAddr(isel, .fromInterned(ptr_info.child), .{}) orelse break :unused;

                    try call.prepareReturn(isel);
                    try call.finishReturn(isel);

                    try call.prepareCallee(isel);
                    try isel.global_relocs.append(gpa, .{
                        .name = "memcpy",
                        .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                    });
                    try isel.emit(.bl(0));
                    try call.finishCallee(isel);

                    try call.prepareParams(isel);
                    const ptr_vi = try isel.use(ty_op.operand);
                    try isel.movImmediate(.x2, size);
                    try call.paramLiveOut(isel, ptr_vi, .r1);
                    try call.paramAddress(isel, dst_vi.value, .r0);
                    try call.finishParams(isel);
                }
            }

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ret, .ret_safe => {
            assert(isel.blocks.keys()[0] == Block.main);
            try isel.blocks.values()[0].branch(isel);
            if (isel.live_values.get(Block.main)) |ret_vi| {
                const un_op = air.data(air.inst_index).un_op;
                const src_vi = try isel.use(un_op);
                switch (ret_vi.parent(isel)) {
                    .unallocated, .stack_slot => if (ret_vi.hint(isel)) |ret_ra| {
                        try src_vi.liveOut(isel, ret_ra);
                    } else {
                        var ret_part_it = ret_vi.parts(isel);
                        var src_part_it = src_vi.parts(isel);
                        if (src_part_it.only()) |_| {
                            try isel.values.ensureUnusedCapacity(gpa, ret_part_it.remaining);
                            src_vi.setParts(isel, ret_part_it.remaining);
                            while (ret_part_it.next()) |ret_part_vi| {
                                const src_part_vi = src_vi.addPart(
                                    isel,
                                    ret_part_vi.get(isel).offset_from_parent,
                                    ret_part_vi.size(isel),
                                );
                                switch (ret_part_vi.signedness(isel)) {
                                    .signed => src_part_vi.setSignedness(isel, .signed),
                                    .unsigned => {},
                                }
                                if (ret_part_vi.isVector(isel)) src_part_vi.setIsVector(isel);
                            }
                            ret_part_it = ret_vi.parts(isel);
                            src_part_it = src_vi.parts(isel);
                        }
                        while (ret_part_it.next()) |ret_part_vi| {
                            const src_part_vi = src_part_it.next().?;
                            assert(ret_part_vi.get(isel).offset_from_parent == src_part_vi.get(isel).offset_from_parent);
                            assert(ret_part_vi.size(isel) == src_part_vi.size(isel));
                            try src_part_vi.liveOut(isel, ret_part_vi.hint(isel).?);
                        }
                    },
                    .value, .constant => unreachable,
                    .address => |address_vi| {
                        const ptr_mat = try address_vi.matReg(isel);
                        try src_vi.store(isel, isel.air.typeOf(un_op, ip), ptr_mat.ra, .{});
                        try ptr_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ret_load => {
            const un_op = air.data(air.inst_index).un_op;
            const ptr_ty = isel.air.typeOf(un_op, ip);
            const ptr_info = ptr_ty.ptrInfo(zcu);
            if (ptr_info.packed_offset.host_size > 0) return isel.fail("packed load", .{});

            assert(isel.blocks.keys()[0] == Block.main);
            try isel.blocks.values()[0].branch(isel);
            if (isel.live_values.get(Block.main)) |ret_vi| switch (ret_vi.parent(isel)) {
                .unallocated, .stack_slot => {
                    var ret_part_it: Value.PartIterator = if (ret_vi.hint(isel)) |_| .initOne(ret_vi) else ret_vi.parts(isel);
                    while (ret_part_it.next()) |ret_part_vi| try ret_part_vi.liveOut(isel, ret_part_vi.hint(isel).?);
                    const ptr_vi = try isel.use(un_op);
                    const ptr_mat = try ptr_vi.matReg(isel);
                    _ = try ret_vi.load(isel, .fromInterned(ptr_info.child), ptr_mat.ra, .{});
                    try ptr_mat.finish(isel);
                },
                .value, .constant => unreachable,
                .address => {},
            };
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .store, .store_safe, .atomic_store_unordered => {
            const bin_op = air.data(air.inst_index).bin_op;
            const ptr_ty = isel.air.typeOf(bin_op.lhs, ip);
            const ptr_info = ptr_ty.ptrInfo(zcu);
            if (ptr_info.packed_offset.host_size > 0) return isel.fail("packed store", .{});
            if (bin_op.rhs.toInterned()) |rhs_val| if (ip.isUndef(rhs_val))
                break :air_tag if (air.next()) |next_air_tag| continue :air_tag next_air_tag;

            const src_vi = try isel.use(bin_op.rhs);
            const size = src_vi.size(isel);
            if (ZigType.fromInterned(ptr_info.child).zigTypeTag(zcu) != .@"union") switch (size) {
                0 => unreachable,
                1...Value.max_parts => {
                    const ptr_vi = try isel.use(bin_op.lhs);
                    const ptr_mat = try ptr_vi.matReg(isel);
                    try src_vi.store(isel, isel.air.typeOf(bin_op.rhs, ip), ptr_mat.ra, .{
                        .@"volatile" = ptr_info.flags.is_volatile,
                    });
                    try ptr_mat.finish(isel);

                    break :air_tag if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
                },
                else => {},
            };
            try call.prepareReturn(isel);
            try call.finishReturn(isel);

            try call.prepareCallee(isel);
            try isel.global_relocs.append(gpa, .{
                .name = "memcpy",
                .reloc = .{ .label = @intCast(isel.instructions.items.len) },
            });
            try isel.emit(.bl(0));
            try call.finishCallee(isel);

            try call.prepareParams(isel);
            const ptr_vi = try isel.use(bin_op.lhs);
            try isel.movImmediate(.x2, size);
            try call.paramAddress(isel, src_vi, .r1);
            try call.paramLiveOut(isel, ptr_vi, .r0);
            try call.finishParams(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .unreach => if (air.next()) |next_air_tag| continue :air_tag next_air_tag,
        .fptrunc, .fpext => {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const dst_bits = dst_ty.floatBits(isel.target);
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                const src_bits = src_ty.floatBits(isel.target);
                assert(dst_bits != src_bits);
                switch (@max(dst_bits, src_bits)) {
                    else => unreachable,
                    16, 32, 64 => {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(.fcvt(switch (dst_bits) {
                            else => unreachable,
                            16 => dst_ra.h(),
                            32 => dst_ra.s(),
                            64 => dst_ra.d(),
                        }, switch (src_bits) {
                            else => unreachable,
                            16 => src_mat.ra.h(),
                            32 => src_mat.ra.s(),
                            64 => src_mat.ra.d(),
                        }));
                        try src_mat.finish(isel);
                    },
                    80, 128 => {
                        try call.prepareReturn(isel);
                        switch (dst_bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, dst_vi.value, .v0),
                            80 => {
                                var dst_hi16_it = dst_vi.value.field(dst_ty, 8, 8);
                                const dst_hi16_vi = try dst_hi16_it.only(isel);
                                try call.returnLiveIn(isel, dst_hi16_vi.?, .r1);
                                var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                                const dst_lo64_vi = try dst_lo64_it.only(isel);
                                try call.returnLiveIn(isel, dst_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (dst_bits) {
                                else => unreachable,
                                16 => switch (src_bits) {
                                    else => unreachable,
                                    32 => "__truncsfhf2",
                                    64 => "__truncdfhf2",
                                    80 => "__truncxfhf2",
                                    128 => "__trunctfhf2",
                                },
                                32 => switch (src_bits) {
                                    else => unreachable,
                                    16 => "__extendhfsf2",
                                    64 => "__truncdfsf2",
                                    80 => "__truncxfsf2",
                                    128 => "__trunctfsf2",
                                },
                                64 => switch (src_bits) {
                                    else => unreachable,
                                    16 => "__extendhfdf2",
                                    32 => "__extendsfdf2",
                                    80 => "__truncxfdf2",
                                    128 => "__trunctfdf2",
                                },
                                80 => switch (src_bits) {
                                    else => unreachable,
                                    16 => "__extendhfxf2",
                                    32 => "__extendsfxf2",
                                    64 => "__extenddfxf2",
                                    128 => "__trunctfxf2",
                                },
                                128 => switch (src_bits) {
                                    else => unreachable,
                                    16 => "__extendhftf2",
                                    32 => "__extendsftf2",
                                    64 => "__extenddftf2",
                                    80 => "__extendxftf2",
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(ty_op.operand);
                        switch (src_bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.paramLiveOut(isel, src_vi, .v0),
                            80 => {
                                var src_hi16_it = src_vi.field(src_ty, 8, 8);
                                const src_hi16_vi = try src_hi16_it.only(isel);
                                try call.paramLiveOut(isel, src_hi16_vi.?, .r1);
                                var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try call.paramLiveOut(isel, src_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .intcast => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const dst_int_info = dst_ty.intInfo(zcu);
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                const src_int_info = src_ty.intInfo(zcu);
                const can_be_negative = dst_int_info.signedness == .signed and
                    src_int_info.signedness == .signed;
                if ((dst_int_info.bits <= 8 and src_int_info.bits <= 8) or
                    (dst_int_info.bits > 8 and dst_int_info.bits <= 16 and
                        src_int_info.bits > 8 and src_int_info.bits <= 16) or
                    (dst_int_info.bits > 16 and dst_int_info.bits <= 32 and
                        src_int_info.bits > 16 and src_int_info.bits <= 32) or
                    (dst_int_info.bits > 32 and dst_int_info.bits <= 64 and
                        src_int_info.bits > 32 and src_int_info.bits <= 64) or
                    (dst_int_info.bits > 64 and src_int_info.bits > 64 and
                        (dst_int_info.bits - 1) / 128 == (src_int_info.bits - 1) / 128))
                {
                    try dst_vi.value.move(isel, ty_op.operand);
                } else if (dst_int_info.bits <= 32 and src_int_info.bits <= 64) {
                    const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                    const src_vi = try isel.use(ty_op.operand);
                    const src_mat = try src_vi.matReg(isel);
                    try isel.emit(.orr(dst_ra.w(), .wzr, .{ .register = src_mat.ra.w() }));
                    try src_mat.finish(isel);
                } else if (dst_int_info.bits <= 64 and src_int_info.bits <= 32) {
                    const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                    const src_vi = try isel.use(ty_op.operand);
                    const src_mat = try src_vi.matReg(isel);
                    try isel.emit(if (can_be_negative) .sbfm(dst_ra.x(), src_mat.ra.x(), .{
                        .N = .doubleword,
                        .immr = 0,
                        .imms = @intCast(src_int_info.bits - 1),
                    }) else .orr(dst_ra.w(), .wzr, .{ .register = src_mat.ra.w() }));
                    try src_mat.finish(isel);
                } else if (dst_int_info.bits <= 32 and src_int_info.bits <= 128) {
                    assert(src_int_info.bits > 64);
                    const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                    const src_vi = try isel.use(ty_op.operand);

                    var src_lo64_it = src_vi.field(src_ty, 0, 8);
                    const src_lo64_vi = try src_lo64_it.only(isel);
                    const src_lo64_mat = try src_lo64_vi.?.matReg(isel);
                    try isel.emit(.orr(dst_ra.w(), .wzr, .{ .register = src_lo64_mat.ra.w() }));
                    try src_lo64_mat.finish(isel);
                } else if (dst_int_info.bits <= 64 and src_int_info.bits <= 128) {
                    assert(dst_int_info.bits > 32 and src_int_info.bits > 64);
                    const src_vi = try isel.use(ty_op.operand);

                    var src_lo64_it = src_vi.field(src_ty, 0, 8);
                    const src_lo64_vi = try src_lo64_it.only(isel);
                    try dst_vi.value.copy(isel, dst_ty, src_lo64_vi.?);
                } else if (dst_int_info.bits <= 128 and src_int_info.bits <= 64) {
                    assert(dst_int_info.bits > 64);
                    const src_vi = try isel.use(ty_op.operand);

                    var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                    const dst_lo64_vi = try dst_lo64_it.only(isel);
                    if (src_int_info.bits <= 32) unused_lo64: {
                        const dst_lo64_ra = try dst_lo64_vi.?.defReg(isel) orelse break :unused_lo64;
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(if (can_be_negative) .sbfm(dst_lo64_ra.x(), src_mat.ra.x(), .{
                            .N = .doubleword,
                            .immr = 0,
                            .imms = @intCast(src_int_info.bits - 1),
                        }) else .orr(dst_lo64_ra.w(), .wzr, .{ .register = src_mat.ra.w() }));
                        try src_mat.finish(isel);
                    } else try dst_lo64_vi.?.copy(isel, src_ty, src_vi);

                    var dst_hi64_it = dst_vi.value.field(dst_ty, 8, 8);
                    const dst_hi64_vi = try dst_hi64_it.only(isel);
                    const dst_hi64_ra = try dst_hi64_vi.?.defReg(isel);
                    if (dst_hi64_ra) |dst_ra| switch (can_be_negative) {
                        false => try isel.emit(.orr(dst_ra.x(), .xzr, .{ .register = .xzr })),
                        true => {
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(.sbfm(dst_ra.x(), src_mat.ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(src_int_info.bits - 1),
                                .imms = @intCast(src_int_info.bits - 1),
                            }));
                            try src_mat.finish(isel);
                        },
                    };
                } else return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .intcast_safe => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const dst_int_info = dst_ty.intInfo(zcu);
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                const src_int_info = src_ty.intInfo(zcu);
                const can_be_negative = dst_int_info.signedness == .signed and
                    src_int_info.signedness == .signed;
                const panic_id: Zcu.SimplePanicId = panic_id: switch (dst_ty.zigTypeTag(zcu)) {
                    else => unreachable,
                    .int => .integer_out_of_bounds,
                    .@"enum" => {
                        if (!dst_ty.isNonexhaustiveEnum(zcu)) {
                            return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                        }
                        break :panic_id .invalid_enum_value;
                    },
                };
                if (dst_ty.toIntern() == src_ty.toIntern()) {
                    try dst_vi.value.move(isel, ty_op.operand);
                } else if (dst_int_info.bits <= 64 and src_int_info.bits <= 64) {
                    const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                    const src_vi = try isel.use(ty_op.operand);
                    const dst_active_bits = dst_int_info.bits - @intFromBool(dst_int_info.signedness == .signed);
                    const src_active_bits = src_int_info.bits - @intFromBool(src_int_info.signedness == .signed);
                    if ((dst_int_info.signedness != .unsigned or src_int_info.signedness != .signed) and dst_active_bits >= src_active_bits) {
                        const src_mat = try src_vi.matReg(isel);
                        try isel.emit(if (can_be_negative and dst_active_bits > 32 and src_active_bits <= 32)
                            .sbfm(dst_ra.x(), src_mat.ra.x(), .{
                                .N = .doubleword,
                                .immr = 0,
                                .imms = @intCast(src_int_info.bits - 1),
                            })
                        else switch (src_int_info.bits) {
                            else => unreachable,
                            1...32 => .orr(dst_ra.w(), .wzr, .{ .register = src_mat.ra.w() }),
                            33...64 => .orr(dst_ra.x(), .xzr, .{ .register = src_mat.ra.x() }),
                        });
                        try src_mat.finish(isel);
                    } else {
                        const skip_label = isel.instructions.items.len;
                        try isel.emitPanic(panic_id);
                        try isel.emit(.@"b."(
                            .eq,
                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                        ));
                        if (can_be_negative) {
                            const src_mat = src_mat: {
                                const dst_lock = isel.lockReg(dst_ra);
                                defer dst_lock.unlock(isel);
                                break :src_mat try src_vi.matReg(isel);
                            };
                            try isel.emit(switch (src_int_info.bits) {
                                else => unreachable,
                                1...32 => .subs(.wzr, dst_ra.w(), .{ .register = src_mat.ra.w() }),
                                33...64 => .subs(.xzr, dst_ra.x(), .{ .register = src_mat.ra.x() }),
                            });
                            try isel.emit(switch (@max(dst_int_info.bits, src_int_info.bits)) {
                                else => unreachable,
                                1...32 => .sbfm(dst_ra.w(), src_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(dst_int_info.bits - 1),
                                }),
                                33...64 => .sbfm(dst_ra.x(), src_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(dst_int_info.bits - 1),
                                }),
                            });
                            try src_mat.finish(isel);
                        } else {
                            const src_mat = try src_vi.matReg(isel);
                            try isel.emit(switch (@min(dst_int_info.bits, src_int_info.bits)) {
                                else => unreachable,
                                1...32 => .orr(dst_ra.w(), .wzr, .{ .register = src_mat.ra.w() }),
                                33...64 => .orr(dst_ra.x(), .xzr, .{ .register = src_mat.ra.x() }),
                            });
                            const active_bits = @min(dst_active_bits, src_active_bits);
                            try isel.emit(switch (src_int_info.bits) {
                                else => unreachable,
                                1...32 => .ands(.wzr, src_mat.ra.w(), .{ .immediate = .{
                                    .N = .word,
                                    .immr = @intCast(32 - active_bits),
                                    .imms = @intCast(32 - active_bits - 1),
                                } }),
                                33...64 => .ands(.xzr, src_mat.ra.x(), .{ .immediate = .{
                                    .N = .doubleword,
                                    .immr = @intCast(64 - active_bits),
                                    .imms = @intCast(64 - active_bits - 1),
                                } }),
                            });
                            try src_mat.finish(isel);
                        }
                    }
                } else return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .trunc => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                if (!dst_ty.isAbiInt(zcu) or !src_ty.isAbiInt(zcu)) return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                const dst_int_info = dst_ty.intInfo(zcu);
                switch (dst_int_info.bits) {
                    0 => unreachable,
                    1...64 => |dst_bits| {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        var src_part_it = src_vi.field(src_ty, 0, @min(src_vi.size(isel), 8));
                        const src_part_vi = try src_part_it.only(isel);
                        const src_part_mat = try src_part_vi.?.matReg(isel);
                        try isel.emit(switch (dst_bits) {
                            else => unreachable,
                            1...31 => |bits| switch (dst_int_info.signedness) {
                                .signed => .sbfm(dst_ra.w(), src_part_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1),
                                }),
                                .unsigned => .ubfm(dst_ra.w(), src_part_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1),
                                }),
                            },
                            32 => .orr(dst_ra.w(), .wzr, .{ .register = src_part_mat.ra.w() }),
                            33...63 => |bits| switch (dst_int_info.signedness) {
                                .signed => .sbfm(dst_ra.x(), src_part_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1),
                                }),
                                .unsigned => .ubfm(dst_ra.x(), src_part_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = 0,
                                    .imms = @intCast(bits - 1),
                                }),
                            },
                            64 => .orr(dst_ra.x(), .xzr, .{ .register = src_part_mat.ra.x() }),
                        });
                        try src_part_mat.finish(isel);
                    },
                    65...128 => |dst_bits| switch (src_ty.intInfo(zcu).bits) {
                        0 => unreachable,
                        65...128 => {
                            const src_vi = try isel.use(ty_op.operand);
                            var dst_hi64_it = dst_vi.value.field(dst_ty, 8, 8);
                            const dst_hi64_vi = try dst_hi64_it.only(isel);
                            if (try dst_hi64_vi.?.defReg(isel)) |dst_hi64_ra| {
                                var src_hi64_it = src_vi.field(src_ty, 8, 8);
                                const src_hi64_vi = try src_hi64_it.only(isel);
                                const src_hi64_mat = try src_hi64_vi.?.matReg(isel);
                                try isel.emit(switch (dst_int_info.signedness) {
                                    .signed => .sbfm(dst_hi64_ra.x(), src_hi64_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(dst_bits - 64 - 1),
                                    }),
                                    .unsigned => .ubfm(dst_hi64_ra.x(), src_hi64_mat.ra.x(), .{
                                        .N = .doubleword,
                                        .immr = 0,
                                        .imms = @intCast(dst_bits - 64 - 1),
                                    }),
                                });
                                try src_hi64_mat.finish(isel);
                            }
                            var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                            const dst_lo64_vi = try dst_lo64_it.only(isel);
                            if (try dst_lo64_vi.?.defReg(isel)) |dst_lo64_ra| {
                                var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try src_lo64_vi.?.liveOut(isel, dst_lo64_ra);
                            }
                        },
                        else => return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) }),
                    },
                    else => return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .optional_payload => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_vi| unused: {
                defer payload_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const opt_ty = isel.air.typeOf(ty_op.operand, ip);
                if (opt_ty.optionalReprIsPayload(zcu)) {
                    try payload_vi.value.move(isel, ty_op.operand);
                    break :unused;
                }

                const opt_vi = try isel.use(ty_op.operand);
                var payload_part_it = opt_vi.field(opt_ty, 0, payload_vi.value.size(isel));
                const payload_part_vi = try payload_part_it.only(isel);
                try payload_vi.value.copy(isel, ty_op.ty.toType(), payload_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .optional_payload_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_ptr_vi| {
                defer payload_ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                try payload_ptr_vi.value.move(isel, ty_op.operand);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .optional_payload_ptr_set => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_ptr_vi| {
                defer payload_ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const opt_ty = isel.air.typeOf(ty_op.operand, ip).childType(zcu);
                if (!opt_ty.optionalReprIsPayload(zcu)) {
                    const opt_ptr_vi = try isel.use(ty_op.operand);
                    const opt_ptr_mat = try opt_ptr_vi.matReg(isel);
                    const has_value_ra = try isel.allocIntReg();
                    defer isel.freeReg(has_value_ra);
                    try isel.storeReg(
                        has_value_ra,
                        1,
                        opt_ptr_mat.ra,
                        opt_ty.optionalChild(zcu).abiSize(zcu),
                    );
                    try opt_ptr_mat.finish(isel);
                    try isel.emit(.movz(has_value_ra.w(), 1, .{ .lsl = .@"0" }));
                }
                try payload_ptr_vi.value.move(isel, ty_op.operand);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .wrap_optional => {
            if (isel.live_values.fetchRemove(air.inst_index)) |opt_vi| unused: {
                defer opt_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                if (ty_op.ty.toType().optionalReprIsPayload(zcu)) {
                    try opt_vi.value.move(isel, ty_op.operand);
                    break :unused;
                }

                const payload_size = isel.air.typeOf(ty_op.operand, ip).abiSize(zcu);
                var payload_part_it = opt_vi.value.field(ty_op.ty.toType(), 0, payload_size);
                const payload_part_vi = try payload_part_it.only(isel);
                try payload_part_vi.?.move(isel, ty_op.operand);
                var has_value_part_it = opt_vi.value.field(ty_op.ty.toType(), payload_size, 1);
                const has_value_part_vi = try has_value_part_it.only(isel);
                const has_value_part_ra = try has_value_part_vi.?.defReg(isel) orelse break :unused;
                try isel.emit(.movz(has_value_part_ra.w(), 1, .{ .lsl = .@"0" }));
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .unwrap_errunion_payload => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_vi| {
                defer payload_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const error_union_ty = isel.air.typeOf(ty_op.operand, ip);

                const error_union_vi = try isel.use(ty_op.operand);
                var payload_part_it = error_union_vi.field(
                    error_union_ty,
                    codegen.errUnionPayloadOffset(ty_op.ty.toType(), zcu),
                    payload_vi.value.size(isel),
                );
                const payload_part_vi = try payload_part_it.only(isel);
                try payload_vi.value.copy(isel, ty_op.ty.toType(), payload_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .unwrap_errunion_err => {
            if (isel.live_values.fetchRemove(air.inst_index)) |error_set_vi| {
                defer error_set_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const error_union_ty = isel.air.typeOf(ty_op.operand, ip);

                const error_union_vi = try isel.use(ty_op.operand);
                var error_set_part_it = error_union_vi.field(
                    error_union_ty,
                    codegen.errUnionErrorOffset(error_union_ty.errorUnionPayload(zcu), zcu),
                    error_set_vi.value.size(isel),
                );
                const error_set_part_vi = try error_set_part_it.only(isel);
                try error_set_vi.value.copy(isel, ty_op.ty.toType(), error_set_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .unwrap_errunion_payload_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_ptr_vi| unused: {
                defer payload_ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                switch (codegen.errUnionPayloadOffset(ty_op.ty.toType().childType(zcu), zcu)) {
                    0 => try payload_ptr_vi.value.move(isel, ty_op.operand),
                    else => |payload_offset| {
                        const payload_ptr_ra = try payload_ptr_vi.value.defReg(isel) orelse break :unused;
                        const error_union_ptr_vi = try isel.use(ty_op.operand);
                        const error_union_ptr_mat = try error_union_ptr_vi.matReg(isel);
                        const lo12: u12 = @truncate(payload_offset >> 0);
                        const hi12: u12 = @intCast(payload_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            payload_ptr_ra.x(),
                            if (lo12 > 0) payload_ptr_ra.x() else error_union_ptr_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(payload_ptr_ra.x(), error_union_ptr_mat.ra.x(), .{ .immediate = lo12 }));
                        try error_union_ptr_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .unwrap_errunion_err_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |error_ptr_vi| unused: {
                defer error_ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                switch (codegen.errUnionErrorOffset(
                    isel.air.typeOf(ty_op.operand, ip).childType(zcu).errorUnionPayload(zcu),
                    zcu,
                )) {
                    0 => try error_ptr_vi.value.move(isel, ty_op.operand),
                    else => |error_offset| {
                        const error_ptr_ra = try error_ptr_vi.value.defReg(isel) orelse break :unused;
                        const error_union_ptr_vi = try isel.use(ty_op.operand);
                        const error_union_ptr_mat = try error_union_ptr_vi.matReg(isel);
                        const lo12: u12 = @truncate(error_offset >> 0);
                        const hi12: u12 = @intCast(error_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            error_ptr_ra.x(),
                            if (lo12 > 0) error_ptr_ra.x() else error_union_ptr_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(error_ptr_ra.x(), error_union_ptr_mat.ra.x(), .{ .immediate = lo12 }));
                        try error_union_ptr_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .errunion_payload_ptr_set => {
            if (isel.live_values.fetchRemove(air.inst_index)) |payload_ptr_vi| unused: {
                defer payload_ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const payload_ty = ty_op.ty.toType().childType(zcu);
                const error_union_ty = isel.air.typeOf(ty_op.operand, ip).childType(zcu);
                const error_set_size = error_union_ty.errorUnionSet(zcu).abiSize(zcu);
                const error_union_ptr_vi = try isel.use(ty_op.operand);
                const error_union_ptr_mat = try error_union_ptr_vi.matReg(isel);
                if (error_set_size > 0) try isel.storeReg(
                    .zr,
                    error_set_size,
                    error_union_ptr_mat.ra,
                    codegen.errUnionErrorOffset(payload_ty, zcu),
                );
                switch (codegen.errUnionPayloadOffset(payload_ty, zcu)) {
                    0 => {
                        try error_union_ptr_mat.finish(isel);
                        try payload_ptr_vi.value.move(isel, ty_op.operand);
                    },
                    else => |payload_offset| {
                        const payload_ptr_ra = try payload_ptr_vi.value.defReg(isel) orelse break :unused;
                        const lo12: u12 = @truncate(payload_offset >> 0);
                        const hi12: u12 = @intCast(payload_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            payload_ptr_ra.x(),
                            if (lo12 > 0) payload_ptr_ra.x() else error_union_ptr_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(payload_ptr_ra.x(), error_union_ptr_mat.ra.x(), .{ .immediate = lo12 }));
                        try error_union_ptr_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .wrap_errunion_payload => {
            if (isel.live_values.fetchRemove(air.inst_index)) |error_union_vi| {
                defer error_union_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const error_union_ty = ty_op.ty.toType();
                const error_union_info = ip.indexToKey(error_union_ty.toIntern()).error_union_type;
                const error_set_ty: ZigType = .fromInterned(error_union_info.error_set_type);
                const payload_ty: ZigType = .fromInterned(error_union_info.payload_type);
                const error_set_offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                const payload_offset = codegen.errUnionPayloadOffset(payload_ty, zcu);
                const error_set_size = error_set_ty.abiSize(zcu);
                const payload_size = payload_ty.abiSize(zcu);

                var payload_part_it = error_union_vi.value.field(error_union_ty, payload_offset, payload_size);
                const payload_part_vi = try payload_part_it.only(isel);
                try payload_part_vi.?.move(isel, ty_op.operand);
                var error_set_part_it = error_union_vi.value.field(error_union_ty, error_set_offset, error_set_size);
                const error_set_part_vi = try error_set_part_it.only(isel);
                if (try error_set_part_vi.?.defReg(isel)) |error_set_part_ra| try isel.emit(switch (error_set_size) {
                    else => unreachable,
                    1...4 => .orr(error_set_part_ra.w(), .wzr, .{ .register = .wzr }),
                    5...8 => .orr(error_set_part_ra.x(), .xzr, .{ .register = .xzr }),
                });
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .wrap_errunion_err => {
            if (isel.live_values.fetchRemove(air.inst_index)) |error_union_vi| {
                defer error_union_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const error_union_ty = ty_op.ty.toType();
                const error_union_info = ip.indexToKey(error_union_ty.toIntern()).error_union_type;
                const error_set_ty: ZigType = .fromInterned(error_union_info.error_set_type);
                const payload_ty: ZigType = .fromInterned(error_union_info.payload_type);
                const error_set_offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                const payload_offset = codegen.errUnionPayloadOffset(payload_ty, zcu);
                const error_set_size = error_set_ty.abiSize(zcu);
                const payload_size = payload_ty.abiSize(zcu);

                var error_set_part_it = error_union_vi.value.field(error_union_ty, error_set_offset, error_set_size);
                const error_set_part_vi = try error_set_part_it.only(isel);
                try error_set_part_vi.?.move(isel, ty_op.operand);
                if (payload_size > 0) {
                    var payload_part_it = error_union_vi.value.field(error_union_ty, payload_offset, payload_size);
                    const payload_part_vi = try payload_part_it.only(isel);
                    try payload_part_vi.?.defUndef(isel, payload_ty, .{});
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .struct_field_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const ty_pl = air.data(air.inst_index).ty_pl;
                const extra = isel.air.extraData(Air.StructField, ty_pl.payload).data;
                switch (codegen.fieldOffset(
                    isel.air.typeOf(extra.struct_operand, ip),
                    ty_pl.ty.toType(),
                    extra.field_index,
                    zcu,
                )) {
                    0 => try dst_vi.value.move(isel, extra.struct_operand),
                    else => |field_offset| {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(extra.struct_operand);
                        const src_mat = try src_vi.matReg(isel);
                        const lo12: u12 = @truncate(field_offset >> 0);
                        const hi12: u12 = @intCast(field_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            dst_ra.x(),
                            if (lo12 > 0) dst_ra.x() else src_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(dst_ra.x(), src_mat.ra.x(), .{ .immediate = lo12 }));
                        try src_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                switch (codegen.fieldOffset(
                    isel.air.typeOf(ty_op.operand, ip),
                    ty_op.ty.toType(),
                    switch (air_tag) {
                        else => unreachable,
                        .struct_field_ptr_index_0 => 0,
                        .struct_field_ptr_index_1 => 1,
                        .struct_field_ptr_index_2 => 2,
                        .struct_field_ptr_index_3 => 3,
                    },
                    zcu,
                )) {
                    0 => try dst_vi.value.move(isel, ty_op.operand),
                    else => |field_offset| {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        const lo12: u12 = @truncate(field_offset >> 0);
                        const hi12: u12 = @intCast(field_offset >> 12);
                        if (hi12 > 0) try isel.emit(.add(
                            dst_ra.x(),
                            if (lo12 > 0) dst_ra.x() else src_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.add(dst_ra.x(), src_mat.ra.x(), .{ .immediate = lo12 }));
                        try src_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .struct_field_val => {
            if (isel.live_values.fetchRemove(air.inst_index)) |field_vi| unused: {
                defer field_vi.value.deref(isel);

                const ty_pl = air.data(air.inst_index).ty_pl;
                const extra = isel.air.extraData(Air.StructField, ty_pl.payload).data;
                const agg_ty = isel.air.typeOf(extra.struct_operand, ip);
                const field_ty = ty_pl.ty.toType();
                const field_bit_offset, const field_bit_size, const is_packed = switch (agg_ty.containerLayout(zcu)) {
                    .auto, .@"extern" => .{
                        8 * agg_ty.structFieldOffset(extra.field_index, zcu),
                        8 * field_ty.abiSize(zcu),
                        false,
                    },
                    .@"packed" => .{
                        if (zcu.typeToPackedStruct(agg_ty)) |loaded_struct|
                            zcu.structPackedFieldBitOffset(loaded_struct, extra.field_index)
                        else
                            0,
                        field_ty.bitSize(zcu),
                        true,
                    },
                };
                if (is_packed) return isel.fail("packed field of {f}", .{
                    isel.fmtType(agg_ty),
                });

                const agg_vi = try isel.use(extra.struct_operand);
                switch (agg_ty.zigTypeTag(zcu)) {
                    else => unreachable,
                    .@"struct" => {
                        var agg_part_it = agg_vi.field(agg_ty, @divExact(field_bit_offset, 8), @divExact(field_bit_size, 8));
                        while (try agg_part_it.next(isel)) |agg_part| {
                            var field_part_it = field_vi.value.field(ty_pl.ty.toType(), agg_part.offset, agg_part.vi.size(isel));
                            const field_part_vi = try field_part_it.only(isel);
                            if (field_part_vi.? == agg_part.vi) continue;
                            var field_subpart_it = field_part_vi.?.parts(isel);
                            const field_part_offset = if (field_subpart_it.only()) |field_subpart_vi|
                                field_subpart_vi.get(isel).offset_from_parent
                            else
                                0;
                            while (field_subpart_it.next()) |field_subpart_vi| {
                                const field_subpart_ra = try field_subpart_vi.defReg(isel) orelse continue;
                                const field_subpart_offset, const field_subpart_size = field_subpart_vi.position(isel);
                                var agg_subpart_it = agg_part.vi.field(
                                    field_ty,
                                    agg_part.offset + field_subpart_offset - field_part_offset,
                                    field_subpart_size,
                                );
                                const agg_subpart_vi = try agg_subpart_it.only(isel);
                                try agg_subpart_vi.?.liveOut(isel, field_subpart_ra);
                            }
                        }
                    },
                    .@"union" => {
                        try field_vi.value.defAddr(isel, field_ty, .{}) orelse break :unused;

                        try call.prepareReturn(isel);
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = "memcpy",
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const union_layout = agg_ty.unionGetLayout(zcu);
                        var payload_it = agg_vi.field(agg_ty, union_layout.payloadOffset(), union_layout.payload_size);
                        const payload_vi = try payload_it.only(isel);
                        try isel.movImmediate(.x2, field_vi.value.size(isel));
                        try call.paramAddress(isel, payload_vi.?, .r1);
                        try call.paramAddress(isel, field_vi.value, .r0);
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .set_union_tag => {
            const bin_op = air.data(air.inst_index).bin_op;
            const union_ty = isel.air.typeOf(bin_op.lhs, ip).childType(zcu);
            const union_layout = union_ty.unionGetLayout(zcu);
            const tag_vi = try isel.use(bin_op.rhs);
            const union_ptr_vi = try isel.use(bin_op.lhs);
            const union_ptr_mat = try union_ptr_vi.matReg(isel);
            try tag_vi.store(isel, isel.air.typeOf(bin_op.rhs, ip), union_ptr_mat.ra, .{
                .offset = union_layout.tagOffset(),
            });
            try union_ptr_mat.finish(isel);
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .get_union_tag => {
            if (isel.live_values.fetchRemove(air.inst_index)) |tag_vi| {
                defer tag_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const union_ty = isel.air.typeOf(ty_op.operand, ip);
                const union_layout = union_ty.unionGetLayout(zcu);
                const union_vi = try isel.use(ty_op.operand);
                var tag_part_it = union_vi.field(union_ty, union_layout.tagOffset(), union_layout.tag_size);
                const tag_part_vi = try tag_part_it.only(isel);
                try tag_vi.value.copy(isel, ty_op.ty.toType(), tag_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .slice => {
            if (isel.live_values.fetchRemove(air.inst_index)) |slice_vi| {
                defer slice_vi.value.deref(isel);
                const ty_pl = air.data(air.inst_index).ty_pl;
                const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;
                var ptr_part_it = slice_vi.value.field(ty_pl.ty.toType(), 0, 8);
                const ptr_part_vi = try ptr_part_it.only(isel);
                try ptr_part_vi.?.move(isel, bin_op.lhs);
                var len_part_it = slice_vi.value.field(ty_pl.ty.toType(), 8, 8);
                const len_part_vi = try len_part_it.only(isel);
                try len_part_vi.?.move(isel, bin_op.rhs);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .slice_len => {
            if (isel.live_values.fetchRemove(air.inst_index)) |len_vi| {
                defer len_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const slice_vi = try isel.use(ty_op.operand);
                var len_part_it = slice_vi.field(isel.air.typeOf(ty_op.operand, ip), 8, 8);
                const len_part_vi = try len_part_it.only(isel);
                try len_vi.value.copy(isel, ty_op.ty.toType(), len_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .slice_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |ptr_vi| {
                defer ptr_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const slice_vi = try isel.use(ty_op.operand);
                var ptr_part_it = slice_vi.field(isel.air.typeOf(ty_op.operand, ip), 0, 8);
                const ptr_part_vi = try ptr_part_it.only(isel);
                try ptr_vi.value.copy(isel, ty_op.ty.toType(), ptr_part_vi.?);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ptr_slice_len_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                const src_vi = try isel.use(ty_op.operand);
                const src_mat = try src_vi.matReg(isel);
                try isel.emit(.add(dst_ra.x(), src_mat.ra.x(), .{ .immediate = 8 }));
                try src_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ptr_slice_ptr_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| {
                defer dst_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                try dst_vi.value.move(isel, ty_op.operand);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .array_elem_val => {
            if (isel.live_values.fetchRemove(air.inst_index)) |elem_vi| unused: {
                defer elem_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const array_ty = isel.air.typeOf(bin_op.lhs, ip);
                const elem_ty = array_ty.childType(zcu);
                const elem_size = elem_ty.abiSize(zcu);
                if (elem_size <= 16 and array_ty.arrayLenIncludingSentinel(zcu) <= Value.max_parts) if (bin_op.rhs.toInterned()) |index_val| {
                    const elem_offset = elem_size * Constant.fromInterned(index_val).toUnsignedInt(zcu);
                    const array_vi = try isel.use(bin_op.lhs);
                    var elem_part_it = array_vi.field(array_ty, elem_offset, elem_size);
                    const elem_part_vi = try elem_part_it.only(isel);
                    try elem_vi.value.copy(isel, elem_ty, elem_part_vi.?);
                    break :unused;
                };
                switch (elem_size) {
                    0 => unreachable,
                    1, 2, 4, 8 => {
                        const elem_ra = try elem_vi.value.defReg(isel) orelse break :unused;
                        const array_ptr_ra = try isel.allocIntReg();
                        defer isel.freeReg(array_ptr_ra);
                        const index_vi = try isel.use(bin_op.rhs);
                        const index_mat = try index_vi.matReg(isel);
                        try isel.emit(switch (elem_size) {
                            else => unreachable,
                            1 => if (elem_vi.value.isVector(isel)) .ldr(elem_ra.b(), .{ .extended_register = .{
                                .base = array_ptr_ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 0 },
                            } }) else switch (elem_vi.value.signedness(isel)) {
                                .signed => .ldrsb(elem_ra.w(), .{ .extended_register = .{
                                    .base = array_ptr_ra.x(),
                                    .index = index_mat.ra.x(),
                                    .extend = .{ .lsl = 0 },
                                } }),
                                .unsigned => .ldrb(elem_ra.w(), .{ .extended_register = .{
                                    .base = array_ptr_ra.x(),
                                    .index = index_mat.ra.x(),
                                    .extend = .{ .lsl = 0 },
                                } }),
                            },
                            2 => if (elem_vi.value.isVector(isel)) .ldr(elem_ra.h(), .{ .extended_register = .{
                                .base = array_ptr_ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 1 },
                            } }) else switch (elem_vi.value.signedness(isel)) {
                                .signed => .ldrsh(elem_ra.w(), .{ .extended_register = .{
                                    .base = array_ptr_ra.x(),
                                    .index = index_mat.ra.x(),
                                    .extend = .{ .lsl = 1 },
                                } }),
                                .unsigned => .ldrh(elem_ra.w(), .{ .extended_register = .{
                                    .base = array_ptr_ra.x(),
                                    .index = index_mat.ra.x(),
                                    .extend = .{ .lsl = 1 },
                                } }),
                            },
                            4 => .ldr(if (elem_vi.value.isVector(isel)) elem_ra.s() else elem_ra.w(), .{ .extended_register = .{
                                .base = array_ptr_ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 2 },
                            } }),
                            8 => .ldr(if (elem_vi.value.isVector(isel)) elem_ra.d() else elem_ra.x(), .{ .extended_register = .{
                                .base = array_ptr_ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 3 },
                            } }),
                            16 => .ldr(elem_ra.q(), .{ .extended_register = .{
                                .base = array_ptr_ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 4 },
                            } }),
                        });
                        try index_mat.finish(isel);
                        const array_vi = try isel.use(bin_op.lhs);
                        try array_vi.address(isel, 0, array_ptr_ra);
                    },
                    else => {
                        const ptr_ra = try isel.allocIntReg();
                        defer isel.freeReg(ptr_ra);
                        if (!try elem_vi.value.load(isel, elem_ty, ptr_ra, .{})) break :unused;
                        const index_vi = try isel.use(bin_op.rhs);
                        try isel.elemPtr(ptr_ra, ptr_ra, .add, elem_size, index_vi);
                        const array_vi = try isel.use(bin_op.lhs);
                        try array_vi.address(isel, 0, ptr_ra);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .slice_elem_val => {
            if (isel.live_values.fetchRemove(air.inst_index)) |elem_vi| unused: {
                defer elem_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const slice_ty = isel.air.typeOf(bin_op.lhs, ip);
                const ptr_info = slice_ty.ptrInfo(zcu);
                const elem_size = elem_vi.value.size(isel);
                const elem_is_vector = elem_vi.value.isVector(isel);
                if (switch (elem_size) {
                    0 => unreachable,
                    1, 2, 4, 8 => true,
                    16 => elem_is_vector,
                    else => false,
                }) {
                    const elem_ra = try elem_vi.value.defReg(isel) orelse break :unused;
                    const slice_vi = try isel.use(bin_op.lhs);
                    const index_vi = try isel.use(bin_op.rhs);
                    var ptr_part_it = slice_vi.field(slice_ty, 0, 8);
                    const ptr_part_vi = try ptr_part_it.only(isel);
                    const base_mat = try ptr_part_vi.?.matReg(isel);
                    const index_mat = try index_vi.matReg(isel);
                    try isel.emit(switch (elem_size) {
                        else => unreachable,
                        1 => if (elem_is_vector) .ldr(elem_ra.b(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 0 },
                        } }) else switch (elem_vi.value.signedness(isel)) {
                            .signed => .ldrsb(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 0 },
                            } }),
                            .unsigned => .ldrb(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 0 },
                            } }),
                        },
                        2 => if (elem_is_vector) .ldr(elem_ra.h(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 1 },
                        } }) else switch (elem_vi.value.signedness(isel)) {
                            .signed => .ldrsh(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 1 },
                            } }),
                            .unsigned => .ldrh(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 1 },
                            } }),
                        },
                        4 => .ldr(if (elem_is_vector) elem_ra.s() else elem_ra.w(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 2 },
                        } }),
                        8 => .ldr(if (elem_is_vector) elem_ra.d() else elem_ra.x(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 3 },
                        } }),
                        16 => if (elem_is_vector) .ldr(elem_ra.q(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 4 },
                        } }) else unreachable,
                    });
                    try index_mat.finish(isel);
                    try base_mat.finish(isel);
                } else {
                    const elem_ptr_ra = try isel.allocIntReg();
                    defer isel.freeReg(elem_ptr_ra);
                    if (!try elem_vi.value.load(isel, slice_ty.elemType2(zcu), elem_ptr_ra, .{
                        .@"volatile" = ptr_info.flags.is_volatile,
                    })) break :unused;
                    const slice_vi = try isel.use(bin_op.lhs);
                    var ptr_part_it = slice_vi.field(slice_ty, 0, 8);
                    const ptr_part_vi = try ptr_part_it.only(isel);
                    const ptr_part_mat = try ptr_part_vi.?.matReg(isel);
                    const index_vi = try isel.use(bin_op.rhs);
                    try isel.elemPtr(elem_ptr_ra, ptr_part_mat.ra, .add, elem_size, index_vi);
                    try ptr_part_mat.finish(isel);
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .slice_elem_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |elem_ptr_vi| unused: {
                defer elem_ptr_vi.value.deref(isel);
                const elem_ptr_ra = try elem_ptr_vi.value.defReg(isel) orelse break :unused;

                const ty_pl = air.data(air.inst_index).ty_pl;
                const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;
                const elem_size = ty_pl.ty.toType().childType(zcu).abiSize(zcu);

                const slice_vi = try isel.use(bin_op.lhs);
                var ptr_part_it = slice_vi.field(isel.air.typeOf(bin_op.lhs, ip), 0, 8);
                const ptr_part_vi = try ptr_part_it.only(isel);
                const ptr_part_mat = try ptr_part_vi.?.matReg(isel);
                const index_vi = try isel.use(bin_op.rhs);
                try isel.elemPtr(elem_ptr_ra, ptr_part_mat.ra, .add, elem_size, index_vi);
                try ptr_part_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ptr_elem_val => {
            if (isel.live_values.fetchRemove(air.inst_index)) |elem_vi| unused: {
                defer elem_vi.value.deref(isel);

                const bin_op = air.data(air.inst_index).bin_op;
                const ptr_ty = isel.air.typeOf(bin_op.lhs, ip);
                const ptr_info = ptr_ty.ptrInfo(zcu);
                const elem_size = elem_vi.value.size(isel);
                const elem_is_vector = elem_vi.value.isVector(isel);
                if (switch (elem_size) {
                    0 => unreachable,
                    1, 2, 4, 8 => true,
                    16 => elem_is_vector,
                    else => false,
                }) {
                    const elem_ra = try elem_vi.value.defReg(isel) orelse break :unused;
                    const base_vi = try isel.use(bin_op.lhs);
                    const index_vi = try isel.use(bin_op.rhs);
                    const base_mat = try base_vi.matReg(isel);
                    const index_mat = try index_vi.matReg(isel);
                    try isel.emit(switch (elem_size) {
                        else => unreachable,
                        1 => if (elem_is_vector) .ldr(elem_ra.b(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 0 },
                        } }) else switch (elem_vi.value.signedness(isel)) {
                            .signed => .ldrsb(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 0 },
                            } }),
                            .unsigned => .ldrb(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 0 },
                            } }),
                        },
                        2 => if (elem_is_vector) .ldr(elem_ra.h(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 1 },
                        } }) else switch (elem_vi.value.signedness(isel)) {
                            .signed => .ldrsh(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 1 },
                            } }),
                            .unsigned => .ldrh(elem_ra.w(), .{ .extended_register = .{
                                .base = base_mat.ra.x(),
                                .index = index_mat.ra.x(),
                                .extend = .{ .lsl = 1 },
                            } }),
                        },
                        4 => .ldr(if (elem_is_vector) elem_ra.s() else elem_ra.w(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 2 },
                        } }),
                        8 => .ldr(if (elem_is_vector) elem_ra.d() else elem_ra.x(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 3 },
                        } }),
                        16 => if (elem_is_vector) .ldr(elem_ra.q(), .{ .extended_register = .{
                            .base = base_mat.ra.x(),
                            .index = index_mat.ra.x(),
                            .extend = .{ .lsl = 4 },
                        } }) else unreachable,
                    });
                    try index_mat.finish(isel);
                    try base_mat.finish(isel);
                } else {
                    const elem_ptr_ra = try isel.allocIntReg();
                    defer isel.freeReg(elem_ptr_ra);
                    if (!try elem_vi.value.load(isel, ptr_ty.elemType2(zcu), elem_ptr_ra, .{
                        .@"volatile" = ptr_info.flags.is_volatile,
                    })) break :unused;
                    const base_vi = try isel.use(bin_op.lhs);
                    const base_mat = try base_vi.matReg(isel);
                    const index_vi = try isel.use(bin_op.rhs);
                    try isel.elemPtr(elem_ptr_ra, base_mat.ra, .add, elem_size, index_vi);
                    try base_mat.finish(isel);
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .ptr_elem_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |elem_ptr_vi| unused: {
                defer elem_ptr_vi.value.deref(isel);
                const elem_ptr_ra = try elem_ptr_vi.value.defReg(isel) orelse break :unused;

                const ty_pl = air.data(air.inst_index).ty_pl;
                const bin_op = isel.air.extraData(Air.Bin, ty_pl.payload).data;
                const elem_size = ty_pl.ty.toType().childType(zcu).abiSize(zcu);

                const base_vi = try isel.use(bin_op.lhs);
                const base_mat = try base_vi.matReg(isel);
                const index_vi = try isel.use(bin_op.rhs);
                try isel.elemPtr(elem_ptr_ra, base_mat.ra, .add, elem_size, index_vi);
                try base_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .array_to_slice => {
            if (isel.live_values.fetchRemove(air.inst_index)) |slice_vi| {
                defer slice_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                var ptr_part_it = slice_vi.value.field(ty_op.ty.toType(), 0, 8);
                const ptr_part_vi = try ptr_part_it.only(isel);
                try ptr_part_vi.?.move(isel, ty_op.operand);
                var len_part_it = slice_vi.value.field(ty_op.ty.toType(), 8, 8);
                const len_part_vi = try len_part_it.only(isel);
                if (try len_part_vi.?.defReg(isel)) |len_ra| try isel.movImmediate(
                    len_ra.x(),
                    isel.air.typeOf(ty_op.operand, ip).childType(zcu).arrayLen(zcu),
                );
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .int_from_float, .int_from_float_optimized => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                if (!dst_ty.isAbiInt(zcu)) return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                const dst_int_info = dst_ty.intInfo(zcu);
                const src_bits = src_ty.floatBits(isel.target);
                switch (@max(dst_int_info.bits, src_bits)) {
                    0 => unreachable,
                    1...64 => {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (src_bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        const src_ra = if (need_fcvt) try isel.allocVecReg() else src_mat.ra;
                        defer if (need_fcvt) isel.freeReg(src_ra);
                        const dst_reg = switch (dst_int_info.bits) {
                            else => unreachable,
                            1...32 => dst_ra.w(),
                            33...64 => dst_ra.x(),
                        };
                        const src_reg = switch (src_bits) {
                            else => unreachable,
                            16 => if (need_fcvt) src_ra.s() else src_ra.h(),
                            32 => src_ra.s(),
                            64 => src_ra.d(),
                        };
                        try isel.emit(switch (dst_int_info.signedness) {
                            .signed => .fcvtzs(dst_reg, src_reg),
                            .unsigned => .fcvtzu(dst_reg, src_reg),
                        });
                        if (need_fcvt) try isel.emit(.fcvt(src_reg, src_mat.ra.h()));
                        try src_mat.finish(isel);
                    },
                    65...128 => {
                        try call.prepareReturn(isel);
                        switch (dst_int_info.bits) {
                            else => unreachable,
                            1...64 => try call.returnLiveIn(isel, dst_vi.value, .r0),
                            65...128 => {
                                var dst_hi64_it = dst_vi.value.field(dst_ty, 8, 8);
                                const dst_hi64_vi = try dst_hi64_it.only(isel);
                                try call.returnLiveIn(isel, dst_hi64_vi.?, .r1);
                                var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                                const dst_lo64_vi = try dst_lo64_it.only(isel);
                                try call.returnLiveIn(isel, dst_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (dst_int_info.bits) {
                                else => unreachable,
                                1...32 => switch (dst_int_info.signedness) {
                                    .signed => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixhfsi",
                                        32 => "__fixsfsi",
                                        64 => "__fixdfsi",
                                        80 => "__fixxfsi",
                                        128 => "__fixtfsi",
                                    },
                                    .unsigned => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixunshfsi",
                                        32 => "__fixunssfsi",
                                        64 => "__fixunsdfsi",
                                        80 => "__fixunsxfsi",
                                        128 => "__fixunstfsi",
                                    },
                                },
                                33...64 => switch (dst_int_info.signedness) {
                                    .signed => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixhfdi",
                                        32 => "__fixsfdi",
                                        64 => "__fixdfdi",
                                        80 => "__fixxfdi",
                                        128 => "__fixtfdi",
                                    },
                                    .unsigned => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixunshfdi",
                                        32 => "__fixunssfdi",
                                        64 => "__fixunsdfdi",
                                        80 => "__fixunsxfdi",
                                        128 => "__fixunstfdi",
                                    },
                                },
                                65...128 => switch (dst_int_info.signedness) {
                                    .signed => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixhfti",
                                        32 => "__fixsfti",
                                        64 => "__fixdfti",
                                        80 => "__fixxfti",
                                        128 => "__fixtfti",
                                    },
                                    .unsigned => switch (src_bits) {
                                        else => unreachable,
                                        16 => "__fixunshfti",
                                        32 => "__fixunssfti",
                                        64 => "__fixunsdfti",
                                        80 => "__fixunsxfti",
                                        128 => "__fixunstfti",
                                    },
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(ty_op.operand);
                        switch (src_bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.paramLiveOut(isel, src_vi, .v0),
                            80 => {
                                var src_hi16_it = src_vi.field(src_ty, 8, 8);
                                const src_hi16_vi = try src_hi16_it.only(isel);
                                try call.paramLiveOut(isel, src_hi16_vi.?, .r1);
                                var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try call.paramLiveOut(isel, src_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                    else => return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .float_from_int => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);

                const ty_op = air.data(air.inst_index).ty_op;
                const dst_ty = ty_op.ty.toType();
                const src_ty = isel.air.typeOf(ty_op.operand, ip);
                const dst_bits = dst_ty.floatBits(isel.target);
                if (!src_ty.isAbiInt(zcu)) return isel.fail("bad {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) });
                const src_int_info = src_ty.intInfo(zcu);
                switch (@max(dst_bits, src_int_info.bits)) {
                    0 => unreachable,
                    1...64 => {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (dst_bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(dst_ra.h(), dst_ra.s()));
                        const src_vi = try isel.use(ty_op.operand);
                        const src_mat = try src_vi.matReg(isel);
                        const dst_reg = switch (dst_bits) {
                            else => unreachable,
                            16 => if (need_fcvt) dst_ra.s() else dst_ra.h(),
                            32 => dst_ra.s(),
                            64 => dst_ra.d(),
                        };
                        const src_reg = switch (src_int_info.bits) {
                            else => unreachable,
                            1...32 => src_mat.ra.w(),
                            33...64 => src_mat.ra.x(),
                        };
                        try isel.emit(switch (src_int_info.signedness) {
                            .signed => .scvtf(dst_reg, src_reg),
                            .unsigned => .ucvtf(dst_reg, src_reg),
                        });
                        try src_mat.finish(isel);
                    },
                    65...128 => {
                        try call.prepareReturn(isel);
                        switch (dst_bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, dst_vi.value, .v0),
                            80 => {
                                var dst_hi16_it = dst_vi.value.field(dst_ty, 8, 8);
                                const dst_hi16_vi = try dst_hi16_it.only(isel);
                                try call.returnLiveIn(isel, dst_hi16_vi.?, .r1);
                                var dst_lo64_it = dst_vi.value.field(dst_ty, 0, 8);
                                const dst_lo64_vi = try dst_lo64_it.only(isel);
                                try call.returnLiveIn(isel, dst_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (src_int_info.bits) {
                                else => unreachable,
                                1...32 => switch (src_int_info.signedness) {
                                    .signed => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floatsihf",
                                        32 => "__floatsisf",
                                        64 => "__floatsidf",
                                        80 => "__floatsixf",
                                        128 => "__floatsitf",
                                    },
                                    .unsigned => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floatunsihf",
                                        32 => "__floatunsisf",
                                        64 => "__floatunsidf",
                                        80 => "__floatunsixf",
                                        128 => "__floatunsitf",
                                    },
                                },
                                33...64 => switch (src_int_info.signedness) {
                                    .signed => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floatdihf",
                                        32 => "__floatdisf",
                                        64 => "__floatdidf",
                                        80 => "__floatdixf",
                                        128 => "__floatditf",
                                    },
                                    .unsigned => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floatundihf",
                                        32 => "__floatundisf",
                                        64 => "__floatundidf",
                                        80 => "__floatundixf",
                                        128 => "__floatunditf",
                                    },
                                },
                                65...128 => switch (src_int_info.signedness) {
                                    .signed => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floattihf",
                                        32 => "__floattisf",
                                        64 => "__floattidf",
                                        80 => "__floattixf",
                                        128 => "__floattitf",
                                    },
                                    .unsigned => switch (dst_bits) {
                                        else => unreachable,
                                        16 => "__floatuntihf",
                                        32 => "__floatuntisf",
                                        64 => "__floatuntidf",
                                        80 => "__floatuntixf",
                                        128 => "__floatuntitf",
                                    },
                                },
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const src_vi = try isel.use(ty_op.operand);
                        switch (src_int_info.bits) {
                            else => unreachable,
                            1...64 => try call.paramLiveOut(isel, src_vi, .r0),
                            65...128 => {
                                var src_hi64_it = src_vi.field(src_ty, 8, 8);
                                const src_hi64_vi = try src_hi64_it.only(isel);
                                try call.paramLiveOut(isel, src_hi64_vi.?, .r1);
                                var src_lo64_it = src_vi.field(src_ty, 0, 8);
                                const src_lo64_vi = try src_lo64_it.only(isel);
                                try call.paramLiveOut(isel, src_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                    else => return isel.fail("too big {s} {f} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty), isel.fmtType(src_ty) }),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .memset, .memset_safe => |air_tag| {
            const bin_op = air.data(air.inst_index).bin_op;
            const dst_ty = isel.air.typeOf(bin_op.lhs, ip);
            const dst_info = dst_ty.ptrInfo(zcu);
            const fill_byte: union(enum) { constant: u8, value: Air.Inst.Ref } = fill_byte: {
                if (bin_op.rhs.toInterned()) |fill_val| {
                    if (ip.isUndef(fill_val)) switch (air_tag) {
                        else => unreachable,
                        .memset => break :air_tag if (air.next()) |next_air_tag| continue :air_tag next_air_tag,
                        .memset_safe => break :fill_byte .{ .constant = 0xaa },
                    };
                    if (try isel.hasRepeatedByteRepr(.fromInterned(fill_val))) |fill_byte|
                        break :fill_byte .{ .constant = fill_byte };
                }
                switch (dst_ty.elemType2(zcu).abiSize(zcu)) {
                    0 => unreachable,
                    1 => break :fill_byte .{ .value = bin_op.rhs },
                    2, 4, 8 => |size| {
                        const dst_vi = try isel.use(bin_op.lhs);
                        const ptr_ra = try isel.allocIntReg();
                        const fill_vi = try isel.use(bin_op.rhs);
                        const fill_mat = try fill_vi.matReg(isel);
                        const len_mat: Value.Materialize = len_mat: switch (dst_info.flags.size) {
                            .one => .{ .vi = undefined, .ra = try isel.allocIntReg() },
                            .many => unreachable,
                            .slice => {
                                var dst_len_it = dst_vi.field(dst_ty, 8, 8);
                                const dst_len_vi = try dst_len_it.only(isel);
                                break :len_mat try dst_len_vi.?.matReg(isel);
                            },
                            .c => unreachable,
                        };

                        const skip_label = isel.instructions.items.len;
                        _ = try isel.instructions.addOne(gpa);
                        try isel.emit(.sub(len_mat.ra.x(), len_mat.ra.x(), .{ .immediate = 1 }));
                        try isel.emit(switch (size) {
                            else => unreachable,
                            2 => .strh(fill_mat.ra.w(), .{ .post_index = .{ .base = ptr_ra.x(), .index = 2 } }),
                            4 => .str(fill_mat.ra.w(), .{ .post_index = .{ .base = ptr_ra.x(), .index = 4 } }),
                            8 => .str(fill_mat.ra.x(), .{ .post_index = .{ .base = ptr_ra.x(), .index = 8 } }),
                        });
                        isel.instructions.items[skip_label] = .cbnz(
                            len_mat.ra.x(),
                            -@as(i21, @intCast((isel.instructions.items.len - 1 - skip_label) << 2)),
                        );
                        switch (dst_info.flags.size) {
                            .one => {
                                const len_imm = ZigType.fromInterned(dst_info.child).arrayLen(zcu);
                                assert(len_imm > 0);
                                try isel.movImmediate(len_mat.ra.x(), len_imm);
                                isel.freeReg(len_mat.ra);
                                try fill_mat.finish(isel);
                                isel.freeReg(ptr_ra);
                                try dst_vi.liveOut(isel, ptr_ra);
                            },
                            .many => unreachable,
                            .slice => {
                                try isel.emit(.cbz(
                                    len_mat.ra.x(),
                                    @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                ));
                                try len_mat.finish(isel);
                                try fill_mat.finish(isel);
                                isel.freeReg(ptr_ra);
                                var dst_ptr_it = dst_vi.field(dst_ty, 0, 8);
                                const dst_ptr_vi = try dst_ptr_it.only(isel);
                                try dst_ptr_vi.?.liveOut(isel, ptr_ra);
                            },
                            .c => unreachable,
                        }

                        break :air_tag if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
                    },
                    else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(dst_ty) }),
                }
            };

            try call.prepareReturn(isel);
            try call.finishReturn(isel);

            try call.prepareCallee(isel);
            try isel.global_relocs.append(gpa, .{
                .name = "memset",
                .reloc = .{ .label = @intCast(isel.instructions.items.len) },
            });
            try isel.emit(.bl(0));
            try call.finishCallee(isel);

            try call.prepareParams(isel);
            const dst_vi = try isel.use(bin_op.lhs);
            switch (dst_info.flags.size) {
                .one => {
                    try isel.movImmediate(.x2, ZigType.fromInterned(dst_info.child).abiSize(zcu));
                    switch (fill_byte) {
                        .constant => |byte| try isel.movImmediate(.w1, byte),
                        .value => |byte| try call.paramLiveOut(isel, try isel.use(byte), .r1),
                    }
                    try call.paramLiveOut(isel, dst_vi, .r0);
                },
                .many => unreachable,
                .slice => {
                    var dst_ptr_it = dst_vi.field(dst_ty, 0, 8);
                    const dst_ptr_vi = try dst_ptr_it.only(isel);
                    var dst_len_it = dst_vi.field(dst_ty, 8, 8);
                    const dst_len_vi = try dst_len_it.only(isel);
                    try isel.elemPtr(.r2, .zr, .add, ZigType.fromInterned(dst_info.child).abiSize(zcu), dst_len_vi.?);
                    switch (fill_byte) {
                        .constant => |byte| try isel.movImmediate(.w1, byte),
                        .value => |byte| try call.paramLiveOut(isel, try isel.use(byte), .r1),
                    }
                    try call.paramLiveOut(isel, dst_ptr_vi.?, .r0);
                },
                .c => unreachable,
            }
            try call.finishParams(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .memcpy, .memmove => |air_tag| {
            const bin_op = air.data(air.inst_index).bin_op;
            const dst_ty = isel.air.typeOf(bin_op.lhs, ip);
            const dst_info = dst_ty.ptrInfo(zcu);

            try call.prepareReturn(isel);
            try call.finishReturn(isel);

            try call.prepareCallee(isel);
            try isel.global_relocs.append(gpa, .{
                .name = @tagName(air_tag),
                .reloc = .{ .label = @intCast(isel.instructions.items.len) },
            });
            try isel.emit(.bl(0));
            try call.finishCallee(isel);

            try call.prepareParams(isel);
            switch (dst_info.flags.size) {
                .one => {
                    const dst_vi = try isel.use(bin_op.lhs);
                    const src_vi = try isel.use(bin_op.rhs);
                    try isel.movImmediate(.x2, ZigType.fromInterned(dst_info.child).abiSize(zcu));
                    try call.paramLiveOut(isel, src_vi, .r1);
                    try call.paramLiveOut(isel, dst_vi, .r0);
                },
                .many => unreachable,
                .slice => {
                    const dst_vi = try isel.use(bin_op.lhs);
                    var dst_ptr_it = dst_vi.field(dst_ty, 0, 8);
                    const dst_ptr_vi = try dst_ptr_it.only(isel);
                    var dst_len_it = dst_vi.field(dst_ty, 8, 8);
                    const dst_len_vi = try dst_len_it.only(isel);
                    const src_vi = try isel.use(bin_op.rhs);
                    try isel.elemPtr(.r2, .zr, .add, ZigType.fromInterned(dst_info.child).abiSize(zcu), dst_len_vi.?);
                    try call.paramLiveOut(isel, src_vi, .r1);
                    try call.paramLiveOut(isel, dst_ptr_vi.?, .r0);
                },
                .c => unreachable,
            }
            try call.finishParams(isel);

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .atomic_load => {
            const atomic_load = air.data(air.inst_index).atomic_load;
            const ptr_ty = isel.air.typeOf(atomic_load.ptr, ip);
            const ptr_info = ptr_ty.ptrInfo(zcu);
            if (atomic_load.order != .unordered) return isel.fail("ordered atomic load", .{});
            if (ptr_info.packed_offset.host_size > 0) return isel.fail("packed atomic load", .{});

            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| {
                defer dst_vi.value.deref(isel);
                var ptr_mat: ?Value.Materialize = null;
                var dst_part_it = dst_vi.value.parts(isel);
                while (dst_part_it.next()) |dst_part_vi| {
                    const dst_ra = try dst_part_vi.defReg(isel) orelse continue;
                    if (ptr_mat == null) {
                        const ptr_vi = try isel.use(atomic_load.ptr);
                        ptr_mat = try ptr_vi.matReg(isel);
                    }
                    try isel.emit(switch (dst_part_vi.size(isel)) {
                        else => |size| return isel.fail("bad atomic load size of {d} from {f}", .{
                            size, isel.fmtType(ptr_ty),
                        }),
                        1 => switch (dst_part_vi.signedness(isel)) {
                            .signed => .ldrsb(dst_ra.w(), .{ .unsigned_offset = .{
                                .base = ptr_mat.?.ra.x(),
                                .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                            } }),
                            .unsigned => .ldrb(dst_ra.w(), .{ .unsigned_offset = .{
                                .base = ptr_mat.?.ra.x(),
                                .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                            } }),
                        },
                        2 => switch (dst_part_vi.signedness(isel)) {
                            .signed => .ldrsh(dst_ra.w(), .{ .unsigned_offset = .{
                                .base = ptr_mat.?.ra.x(),
                                .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                            } }),
                            .unsigned => .ldrh(dst_ra.w(), .{ .unsigned_offset = .{
                                .base = ptr_mat.?.ra.x(),
                                .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                            } }),
                        },
                        4 => .ldr(dst_ra.w(), .{ .unsigned_offset = .{
                            .base = ptr_mat.?.ra.x(),
                            .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                        } }),
                        8 => .ldr(dst_ra.x(), .{ .unsigned_offset = .{
                            .base = ptr_mat.?.ra.x(),
                            .offset = @intCast(dst_part_vi.get(isel).offset_from_parent),
                        } }),
                    });
                }
                if (ptr_mat) |mat| try mat.finish(isel);
            } else if (ptr_info.flags.is_volatile) return isel.fail("volatile atomic load", .{});

            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .error_name => {
            if (isel.live_values.fetchRemove(air.inst_index)) |name_vi| unused: {
                defer name_vi.value.deref(isel);
                var ptr_part_it = name_vi.value.field(.slice_const_u8_sentinel_0, 0, 8);
                const ptr_part_vi = try ptr_part_it.only(isel);
                const ptr_part_ra = try ptr_part_vi.?.defReg(isel);
                var len_part_it = name_vi.value.field(.slice_const_u8_sentinel_0, 8, 8);
                const len_part_vi = try len_part_it.only(isel);
                const len_part_ra = try len_part_vi.?.defReg(isel);
                if (ptr_part_ra == null and len_part_ra == null) break :unused;

                const un_op = air.data(air.inst_index).un_op;
                const error_vi = try isel.use(un_op);
                const error_mat = try error_vi.matReg(isel);
                const ptr_ra = try isel.allocIntReg();
                defer isel.freeReg(ptr_ra);
                const start_ra, const end_ra = range_ras: {
                    const name_lock: RegLock = if (len_part_ra != null) if (ptr_part_ra) |name_ptr_ra|
                        isel.tryLockReg(name_ptr_ra)
                    else
                        .empty else .empty;
                    defer name_lock.unlock(isel);
                    break :range_ras .{ try isel.allocIntReg(), try isel.allocIntReg() };
                };
                defer {
                    isel.freeReg(start_ra);
                    isel.freeReg(end_ra);
                }
                if (len_part_ra) |name_len_ra| try isel.emit(.sub(
                    name_len_ra.w(),
                    end_ra.w(),
                    .{ .register = start_ra.w() },
                ));
                if (ptr_part_ra) |name_ptr_ra| try isel.emit(.add(
                    name_ptr_ra.x(),
                    ptr_ra.x(),
                    .{ .extended_register = .{
                        .register = start_ra.w(),
                        .extend = .{ .uxtw = 0 },
                    } },
                ));
                if (len_part_ra) |_| try isel.emit(.sub(end_ra.w(), end_ra.w(), .{ .immediate = 1 }));
                try isel.emit(.ldp(start_ra.w(), end_ra.w(), .{ .base = start_ra.x() }));
                try isel.emit(.add(start_ra.x(), ptr_ra.x(), .{ .extended_register = .{
                    .register = error_mat.ra.w(),
                    .extend = switch (zcu.errorSetBits()) {
                        else => unreachable,
                        1...8 => .{ .uxtb = 2 },
                        9...16 => .{ .uxth = 2 },
                        17...32 => .{ .uxtw = 2 },
                    },
                } }));
                try isel.lazy_relocs.append(gpa, .{
                    .symbol = .{ .kind = .const_data, .ty = .anyerror_type },
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.add(ptr_ra.x(), ptr_ra.x(), .{ .immediate = 0 }));
                try isel.lazy_relocs.append(gpa, .{
                    .symbol = .{ .kind = .const_data, .ty = .anyerror_type },
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.adrp(ptr_ra.x(), 0));
                try error_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .aggregate_init => {
            if (isel.live_values.fetchRemove(air.inst_index)) |agg_vi| {
                defer agg_vi.value.deref(isel);

                const ty_pl = air.data(air.inst_index).ty_pl;
                const agg_ty = ty_pl.ty.toType();
                switch (ip.indexToKey(agg_ty.toIntern())) {
                    .array_type => |array_type| {
                        const elems: []const Air.Inst.Ref =
                            @ptrCast(isel.air.extra.items[ty_pl.payload..][0..@intCast(array_type.len)]);
                        var elem_offset: u64 = 0;
                        const elem_size = ZigType.fromInterned(array_type.child).abiSize(zcu);
                        for (elems) |elem| {
                            var agg_part_it = agg_vi.value.field(agg_ty, elem_offset, elem_size);
                            const agg_part_vi = try agg_part_it.only(isel);
                            try agg_part_vi.?.move(isel, elem);
                            elem_offset += elem_size;
                        }
                        switch (array_type.sentinel) {
                            .none => {},
                            else => |sentinel| {
                                var agg_part_it = agg_vi.value.field(agg_ty, elem_offset, elem_size);
                                const agg_part_vi = try agg_part_it.only(isel);
                                try agg_part_vi.?.move(isel, .fromIntern(sentinel));
                            },
                        }
                    },
                    .struct_type => {
                        const loaded_struct = ip.loadStructType(agg_ty.toIntern());
                        const elems: []const Air.Inst.Ref =
                            @ptrCast(isel.air.extra.items[ty_pl.payload..][0..loaded_struct.field_types.len]);
                        var field_offset: u64 = 0;
                        var field_it = loaded_struct.iterateRuntimeOrder(ip);
                        while (field_it.next()) |field_index| {
                            const field_ty: ZigType = .fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                            field_offset = field_ty.structFieldAlignment(
                                loaded_struct.fieldAlign(ip, field_index),
                                loaded_struct.layout,
                                zcu,
                            ).forward(field_offset);
                            const field_size = field_ty.abiSize(zcu);
                            if (field_size == 0) continue;
                            var agg_part_it = agg_vi.value.field(agg_ty, field_offset, field_size);
                            const agg_part_vi = try agg_part_it.only(isel);
                            try agg_part_vi.?.move(isel, elems[field_index]);
                            field_offset += field_size;
                        }
                        assert(loaded_struct.flagsUnordered(ip).alignment.forward(field_offset) == agg_vi.value.size(isel));
                    },
                    .tuple_type => |tuple_type| {
                        const elems: []const Air.Inst.Ref =
                            @ptrCast(isel.air.extra.items[ty_pl.payload..][0..tuple_type.types.len]);
                        var tuple_align: InternPool.Alignment = .@"1";
                        var field_offset: u64 = 0;
                        for (
                            tuple_type.types.get(ip),
                            tuple_type.values.get(ip),
                            elems,
                        ) |field_ty_index, field_val, elem| {
                            if (field_val != .none) continue;
                            const field_ty: ZigType = .fromInterned(field_ty_index);
                            const field_align = field_ty.abiAlignment(zcu);
                            tuple_align = tuple_align.maxStrict(field_align);
                            field_offset = field_align.forward(field_offset);
                            const field_size = field_ty.abiSize(zcu);
                            if (field_size == 0) continue;
                            var agg_part_it = agg_vi.value.field(agg_ty, field_offset, field_size);
                            const agg_part_vi = try agg_part_it.only(isel);
                            try agg_part_vi.?.move(isel, elem);
                            field_offset += field_size;
                        }
                        assert(tuple_align.forward(field_offset) == agg_vi.value.size(isel));
                    },
                    else => return isel.fail("aggregate init {f}", .{isel.fmtType(agg_ty)}),
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .union_init => |air_tag| {
            if (isel.live_values.fetchRemove(air.inst_index)) |union_vi| unused: {
                defer union_vi.value.deref(isel);

                const ty_pl = air.data(air.inst_index).ty_pl;
                const extra = isel.air.extraData(Air.UnionInit, ty_pl.payload).data;
                const union_ty = ty_pl.ty.toType();
                const loaded_union = ip.loadUnionType(union_ty.toIntern());
                const union_layout = ZigType.getUnionLayout(loaded_union, zcu);

                if (union_layout.tag_size > 0) unused_tag: {
                    const loaded_tag = loaded_union.loadTagType(ip);
                    var tag_it = union_vi.value.field(union_ty, union_layout.tagOffset(), union_layout.tag_size);
                    const tag_vi = try tag_it.only(isel);
                    const tag_ra = try tag_vi.?.defReg(isel) orelse break :unused_tag;
                    switch (union_layout.tag_size) {
                        0 => unreachable,
                        1...4 => try isel.movImmediate(tag_ra.w(), @as(u32, switch (loaded_tag.values.len) {
                            0 => extra.field_index,
                            else => switch (ip.indexToKey(loaded_tag.values.get(ip)[extra.field_index]).int.storage) {
                                .u64 => |imm| @intCast(imm),
                                .i64 => |imm| @bitCast(@as(i32, @intCast(imm))),
                                else => unreachable,
                            },
                        })),
                        5...8 => try isel.movImmediate(tag_ra.x(), switch (loaded_tag.values.len) {
                            0 => extra.field_index,
                            else => switch (ip.indexToKey(loaded_tag.values.get(ip)[extra.field_index]).int.storage) {
                                .u64 => |imm| imm,
                                .i64 => |imm| @bitCast(imm),
                                else => unreachable,
                            },
                        }),
                        else => return isel.fail("too big {s} {f}", .{ @tagName(air_tag), isel.fmtType(union_ty) }),
                    }
                }
                var payload_it = union_vi.value.field(union_ty, union_layout.payloadOffset(), union_layout.payload_size);
                const payload_vi = try payload_it.only(isel);
                try payload_vi.?.defAddr(isel, union_ty, .{ .root_vi = union_vi.value }) orelse break :unused;

                try call.prepareReturn(isel);
                try call.finishReturn(isel);

                try call.prepareCallee(isel);
                try isel.global_relocs.append(gpa, .{
                    .name = "memcpy",
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.bl(0));
                try call.finishCallee(isel);

                try call.prepareParams(isel);
                const init_vi = try isel.use(extra.init);
                try isel.movImmediate(.x2, init_vi.size(isel));
                try call.paramAddress(isel, init_vi, .r1);
                try call.paramAddress(isel, payload_vi.?, .r0);
                try call.finishParams(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .prefetch => {
            const prefetch = air.data(air.inst_index).prefetch;
            if (!(prefetch.rw == .write and prefetch.cache == .instruction)) {
                const maybe_slice_ty = isel.air.typeOf(prefetch.ptr, ip);
                const maybe_slice_vi = try isel.use(prefetch.ptr);
                const ptr_vi = if (maybe_slice_ty.isSlice(zcu)) ptr_vi: {
                    var ptr_part_it = maybe_slice_vi.field(maybe_slice_ty, 0, 8);
                    const ptr_part_vi = try ptr_part_it.only(isel);
                    break :ptr_vi ptr_part_vi.?;
                } else maybe_slice_vi;
                const ptr_mat = try ptr_vi.matReg(isel);
                try isel.emit(.prfm(.{
                    .policy = switch (prefetch.locality) {
                        1, 2, 3 => .keep,
                        0 => .strm,
                    },
                    .target = switch (prefetch.locality) {
                        0, 3 => .l1,
                        2 => .l2,
                        1 => .l3,
                    },
                    .type = switch (prefetch.rw) {
                        .read => switch (prefetch.cache) {
                            .data => .pld,
                            .instruction => .pli,
                        },
                        .write => switch (prefetch.cache) {
                            .data => .pst,
                            .instruction => unreachable,
                        },
                    },
                }, .{ .base = ptr_mat.ra.x() }));
                try ptr_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .mul_add => {
            if (isel.live_values.fetchRemove(air.inst_index)) |res_vi| unused: {
                defer res_vi.value.deref(isel);

                const pl_op = air.data(air.inst_index).pl_op;
                const bin_op = isel.air.extraData(Air.Bin, pl_op.payload).data;
                const ty = isel.air.typeOf(pl_op.operand, ip);
                switch (ty.floatBits(isel.target)) {
                    else => unreachable,
                    16, 32, 64 => |bits| {
                        const res_ra = try res_vi.value.defReg(isel) orelse break :unused;
                        const need_fcvt = switch (bits) {
                            else => unreachable,
                            16 => !isel.target.cpu.has(.aarch64, .fullfp16),
                            32, 64 => false,
                        };
                        if (need_fcvt) try isel.emit(.fcvt(res_ra.h(), res_ra.s()));
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const addend_vi = try isel.use(pl_op.operand);
                        const lhs_mat = try lhs_vi.matReg(isel);
                        const rhs_mat = try rhs_vi.matReg(isel);
                        const addend_mat = try addend_vi.matReg(isel);
                        const lhs_ra = if (need_fcvt) try isel.allocVecReg() else lhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(lhs_ra);
                        const rhs_ra = if (need_fcvt) try isel.allocVecReg() else rhs_mat.ra;
                        defer if (need_fcvt) isel.freeReg(rhs_ra);
                        const addend_ra = if (need_fcvt) try isel.allocVecReg() else addend_mat.ra;
                        defer if (need_fcvt) isel.freeReg(addend_ra);
                        try isel.emit(bits: switch (bits) {
                            else => unreachable,
                            16 => if (need_fcvt)
                                continue :bits 32
                            else
                                .fmadd(res_ra.h(), lhs_ra.h(), rhs_ra.h(), addend_ra.h()),
                            32 => .fmadd(res_ra.s(), lhs_ra.s(), rhs_ra.s(), addend_ra.s()),
                            64 => .fmadd(res_ra.d(), lhs_ra.d(), rhs_ra.d(), addend_ra.d()),
                        });
                        if (need_fcvt) {
                            try isel.emit(.fcvt(addend_ra.s(), addend_mat.ra.h()));
                            try isel.emit(.fcvt(rhs_ra.s(), rhs_mat.ra.h()));
                            try isel.emit(.fcvt(lhs_ra.s(), lhs_mat.ra.h()));
                        }
                        try addend_mat.finish(isel);
                        try rhs_mat.finish(isel);
                        try lhs_mat.finish(isel);
                    },
                    80, 128 => |bits| {
                        try call.prepareReturn(isel);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => try call.returnLiveIn(isel, res_vi.value, .v0),
                            80 => {
                                var res_hi16_it = res_vi.value.field(ty, 8, 8);
                                const res_hi16_vi = try res_hi16_it.only(isel);
                                try call.returnLiveIn(isel, res_hi16_vi.?, .r1);
                                var res_lo64_it = res_vi.value.field(ty, 0, 8);
                                const res_lo64_vi = try res_lo64_it.only(isel);
                                try call.returnLiveIn(isel, res_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishReturn(isel);

                        try call.prepareCallee(isel);
                        try isel.global_relocs.append(gpa, .{
                            .name = switch (bits) {
                                else => unreachable,
                                16 => "__fmah",
                                32 => "fmaf",
                                64 => "fma",
                                80 => "__fmax",
                                128 => "fmaq",
                            },
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.bl(0));
                        try call.finishCallee(isel);

                        try call.prepareParams(isel);
                        const lhs_vi = try isel.use(bin_op.lhs);
                        const rhs_vi = try isel.use(bin_op.rhs);
                        const addend_vi = try isel.use(pl_op.operand);
                        switch (bits) {
                            else => unreachable,
                            16, 32, 64, 128 => {
                                try call.paramLiveOut(isel, addend_vi, .v2);
                                try call.paramLiveOut(isel, rhs_vi, .v1);
                                try call.paramLiveOut(isel, lhs_vi, .v0);
                            },
                            80 => {
                                var addend_hi16_it = addend_vi.field(ty, 8, 8);
                                const addend_hi16_vi = try addend_hi16_it.only(isel);
                                try call.paramLiveOut(isel, addend_hi16_vi.?, .r5);
                                var addend_lo64_it = addend_vi.field(ty, 0, 8);
                                const addend_lo64_vi = try addend_lo64_it.only(isel);
                                try call.paramLiveOut(isel, addend_lo64_vi.?, .r4);
                                var rhs_hi16_it = rhs_vi.field(ty, 8, 8);
                                const rhs_hi16_vi = try rhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, rhs_hi16_vi.?, .r3);
                                var rhs_lo64_it = rhs_vi.field(ty, 0, 8);
                                const rhs_lo64_vi = try rhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, rhs_lo64_vi.?, .r2);
                                var lhs_hi16_it = lhs_vi.field(ty, 8, 8);
                                const lhs_hi16_vi = try lhs_hi16_it.only(isel);
                                try call.paramLiveOut(isel, lhs_hi16_vi.?, .r1);
                                var lhs_lo64_it = lhs_vi.field(ty, 0, 8);
                                const lhs_lo64_vi = try lhs_lo64_it.only(isel);
                                try call.paramLiveOut(isel, lhs_lo64_vi.?, .r0);
                            },
                        }
                        try call.finishParams(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .field_parent_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |dst_vi| unused: {
                defer dst_vi.value.deref(isel);
                const ty_pl = air.data(air.inst_index).ty_pl;
                const extra = isel.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;
                switch (codegen.fieldOffset(
                    ty_pl.ty.toType(),
                    isel.air.typeOf(extra.field_ptr, ip),
                    extra.field_index,
                    zcu,
                )) {
                    0 => try dst_vi.value.move(isel, extra.field_ptr),
                    else => |field_offset| {
                        const dst_ra = try dst_vi.value.defReg(isel) orelse break :unused;
                        const src_vi = try isel.use(extra.field_ptr);
                        const src_mat = try src_vi.matReg(isel);
                        const lo12: u12 = @truncate(field_offset >> 0);
                        const hi12: u12 = @intCast(field_offset >> 12);
                        if (hi12 > 0) try isel.emit(.sub(
                            dst_ra.x(),
                            if (lo12 > 0) dst_ra.x() else src_mat.ra.x(),
                            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                        ));
                        if (lo12 > 0) try isel.emit(.sub(dst_ra.x(), src_mat.ra.x(), .{ .immediate = lo12 }));
                        try src_mat.finish(isel);
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .wasm_memory_size, .wasm_memory_grow => unreachable,
        .cmp_lt_errors_len => {
            if (isel.live_values.fetchRemove(air.inst_index)) |is_vi| unused: {
                defer is_vi.value.deref(isel);
                const is_ra = try is_vi.value.defReg(isel) orelse break :unused;
                try isel.emit(.csinc(is_ra.w(), .wzr, .wzr, .invert(.ls)));

                const un_op = air.data(air.inst_index).un_op;
                const error_vi = try isel.use(un_op);
                const error_mat = try error_vi.matReg(isel);
                const ptr_ra = try isel.allocIntReg();
                defer isel.freeReg(ptr_ra);
                try isel.emit(.subs(.wzr, error_mat.ra.w(), .{ .register = ptr_ra.w() }));
                try isel.lazy_relocs.append(gpa, .{
                    .symbol = .{ .kind = .const_data, .ty = .anyerror_type },
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.ldr(ptr_ra.w(), .{ .base = ptr_ra.x() }));
                try isel.lazy_relocs.append(gpa, .{
                    .symbol = .{ .kind = .const_data, .ty = .anyerror_type },
                    .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                });
                try isel.emit(.adrp(ptr_ra.x(), 0));
                try error_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .runtime_nav_ptr => {
            if (isel.live_values.fetchRemove(air.inst_index)) |ptr_vi| unused: {
                defer ptr_vi.value.deref(isel);
                const ptr_ra = try ptr_vi.value.defReg(isel) orelse break :unused;

                const ty_nav = air.data(air.inst_index).ty_nav;
                if (ZigType.fromInterned(ip.getNav(ty_nav.nav).typeOf(ip)).isFnOrHasRuntimeBits(zcu)) switch (true) {
                    false => {
                        try isel.nav_relocs.append(gpa, .{
                            .nav = ty_nav.nav,
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.adr(ptr_ra.x(), 0));
                    },
                    true => {
                        try isel.nav_relocs.append(gpa, .{
                            .nav = ty_nav.nav,
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.add(ptr_ra.x(), ptr_ra.x(), .{ .immediate = 0 }));
                        try isel.nav_relocs.append(gpa, .{
                            .nav = ty_nav.nav,
                            .reloc = .{ .label = @intCast(isel.instructions.items.len) },
                        });
                        try isel.emit(.adrp(ptr_ra.x(), 0));
                    },
                } else try isel.movImmediate(ptr_ra.x(), isel.pt.navAlignment(ty_nav.nav).forward(0xaaaaaaaaaaaaaaaa));
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .c_va_arg => {
            const maybe_arg_vi = isel.live_values.fetchRemove(air.inst_index);
            defer if (maybe_arg_vi) |arg_vi| arg_vi.value.deref(isel);
            const ty_op = air.data(air.inst_index).ty_op;
            const ty = ty_op.ty.toType();
            var param_it: CallAbiIterator = .init;
            const param_vi = try param_it.param(isel, ty);
            defer param_vi.?.deref(isel);
            const passed_vi = switch (param_vi.?.parent(isel)) {
                .unallocated => param_vi.?,
                .stack_slot, .value, .constant => unreachable,
                .address => |address_vi| address_vi,
            };
            const passed_size: u5 = @intCast(passed_vi.alignment(isel).forward(passed_vi.size(isel)));
            const passed_is_vector = passed_vi.isVector(isel);

            const va_list_ptr_vi = try isel.use(ty_op.operand);
            const va_list_ptr_mat = try va_list_ptr_vi.matReg(isel);
            const offs_ra = try isel.allocIntReg();
            defer isel.freeReg(offs_ra);
            const stack_ra = try isel.allocIntReg();
            defer isel.freeReg(stack_ra);

            var part_vis: [2]Value.Index = undefined;
            var arg_part_ras: [2]?Register.Alias = @splat(null);
            const parts_len = parts_len: {
                var parts_len: u2 = 0;
                var part_it = passed_vi.parts(isel);
                while (part_it.next()) |part_vi| : (parts_len += 1) {
                    part_vis[parts_len] = part_vi;
                    const arg_vi = maybe_arg_vi orelse continue;
                    const part_offset, const part_size = part_vi.position(isel);
                    var arg_part_it = arg_vi.value.field(ty, part_offset, part_size);
                    const arg_part_vi = try arg_part_it.only(isel);
                    arg_part_ras[parts_len] = try arg_part_vi.?.defReg(isel);
                }
                break :parts_len parts_len;
            };

            const done_label = isel.instructions.items.len;
            try isel.emit(.str(stack_ra.x(), .{ .unsigned_offset = .{
                .base = va_list_ptr_mat.ra.x(),
                .offset = 0,
            } }));
            try isel.emit(switch (parts_len) {
                else => unreachable,
                1 => if (arg_part_ras[0]) |arg_part_ra| switch (part_vis[0].size(isel)) {
                    else => unreachable,
                    1 => if (arg_part_ra.isVector()) .ldr(arg_part_ra.b(), .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } }) else switch (part_vis[0].signedness(isel)) {
                        .signed => .ldrsb(arg_part_ra.w(), .{ .post_index = .{
                            .base = stack_ra.x(),
                            .index = passed_size,
                        } }),
                        .unsigned => .ldrb(arg_part_ra.w(), .{ .post_index = .{
                            .base = stack_ra.x(),
                            .index = passed_size,
                        } }),
                    },
                    2 => if (arg_part_ra.isVector()) .ldr(arg_part_ra.h(), .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } }) else switch (part_vis[0].signedness(isel)) {
                        .signed => .ldrsh(arg_part_ra.w(), .{ .post_index = .{
                            .base = stack_ra.x(),
                            .index = passed_size,
                        } }),
                        .unsigned => .ldrh(arg_part_ra.w(), .{ .post_index = .{
                            .base = stack_ra.x(),
                            .index = passed_size,
                        } }),
                    },
                    4 => .ldr(if (arg_part_ra.isVector()) arg_part_ra.s() else arg_part_ra.w(), .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } }),
                    8 => .ldr(if (arg_part_ra.isVector()) arg_part_ra.d() else arg_part_ra.x(), .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } }),
                    16 => .ldr(arg_part_ra.q(), .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } }),
                } else .add(stack_ra.x(), stack_ra.x(), .{ .immediate = passed_size }),
                2 => if (arg_part_ras[0] != null or arg_part_ras[1] != null) .ldp(
                    @as(Register.Alias, arg_part_ras[0] orelse .zr).x(),
                    @as(Register.Alias, arg_part_ras[1] orelse .zr).x(),
                    .{ .post_index = .{
                        .base = stack_ra.x(),
                        .index = passed_size,
                    } },
                ) else .add(stack_ra.x(), stack_ra.x(), .{ .immediate = passed_size }),
            });
            try isel.emit(.ldr(stack_ra.x(), .{ .unsigned_offset = .{
                .base = va_list_ptr_mat.ra.x(),
                .offset = 0,
            } }));
            switch (isel.va_list) {
                .other => {},
                .sysv => {
                    const stack_label = isel.instructions.items.len;
                    try isel.emit(.b(
                        @intCast((isel.instructions.items.len + 1 - done_label) << 2),
                    ));
                    switch (parts_len) {
                        else => unreachable,
                        1 => if (arg_part_ras[0]) |arg_part_ra| try isel.emit(switch (part_vis[0].size(isel)) {
                            else => unreachable,
                            1 => if (arg_part_ra.isVector()) .ldr(arg_part_ra.b(), .{ .extended_register = .{
                                .base = stack_ra.x(),
                                .index = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }) else switch (part_vis[0].signedness(isel)) {
                                .signed => .ldrsb(arg_part_ra.w(), .{ .extended_register = .{
                                    .base = stack_ra.x(),
                                    .index = offs_ra.w(),
                                    .extend = .{ .sxtw = 0 },
                                } }),
                                .unsigned => .ldrb(arg_part_ra.w(), .{ .extended_register = .{
                                    .base = stack_ra.x(),
                                    .index = offs_ra.w(),
                                    .extend = .{ .sxtw = 0 },
                                } }),
                            },
                            2 => if (arg_part_ra.isVector()) .ldr(arg_part_ra.h(), .{ .extended_register = .{
                                .base = stack_ra.x(),
                                .index = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }) else switch (part_vis[0].signedness(isel)) {
                                .signed => .ldrsh(arg_part_ra.w(), .{ .extended_register = .{
                                    .base = stack_ra.x(),
                                    .index = offs_ra.w(),
                                    .extend = .{ .sxtw = 0 },
                                } }),
                                .unsigned => .ldrh(arg_part_ra.w(), .{ .extended_register = .{
                                    .base = stack_ra.x(),
                                    .index = offs_ra.w(),
                                    .extend = .{ .sxtw = 0 },
                                } }),
                            },
                            4 => .ldr(if (arg_part_ra.isVector()) arg_part_ra.s() else arg_part_ra.w(), .{ .extended_register = .{
                                .base = stack_ra.x(),
                                .index = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }),
                            8 => .ldr(if (arg_part_ra.isVector()) arg_part_ra.d() else arg_part_ra.x(), .{ .extended_register = .{
                                .base = stack_ra.x(),
                                .index = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }),
                            16 => .ldr(arg_part_ra.q(), .{ .extended_register = .{
                                .base = stack_ra.x(),
                                .index = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }),
                        }),
                        2 => if (arg_part_ras[0] != null or arg_part_ras[1] != null) {
                            try isel.emit(.ldp(
                                @as(Register.Alias, arg_part_ras[0] orelse .zr).x(),
                                @as(Register.Alias, arg_part_ras[1] orelse .zr).x(),
                                .{ .base = stack_ra.x() },
                            ));
                            try isel.emit(.add(stack_ra.x(), stack_ra.x(), .{ .extended_register = .{
                                .register = offs_ra.w(),
                                .extend = .{ .sxtw = 0 },
                            } }));
                        },
                    }
                    try isel.emit(.ldr(stack_ra.x(), .{ .unsigned_offset = .{
                        .base = va_list_ptr_mat.ra.x(),
                        .offset = if (passed_is_vector) 16 else 8,
                    } }));
                    try isel.emit(.@"b."(
                        .gt,
                        @intCast((isel.instructions.items.len + 1 - stack_label) << 2),
                    ));
                    try isel.emit(.str(stack_ra.w(), .{ .unsigned_offset = .{
                        .base = va_list_ptr_mat.ra.x(),
                        .offset = if (passed_is_vector) 28 else 24,
                    } }));
                    try isel.emit(.adds(stack_ra.w(), offs_ra.w(), .{ .immediate = passed_size }));
                    try isel.emit(.tbz(
                        offs_ra.w(),
                        31,
                        @intCast((isel.instructions.items.len + 1 - stack_label) << 2),
                    ));
                    try isel.emit(.ldr(offs_ra.w(), .{ .unsigned_offset = .{
                        .base = va_list_ptr_mat.ra.x(),
                        .offset = if (passed_is_vector) 28 else 24,
                    } }));
                },
            }
            try va_list_ptr_mat.finish(isel);
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .c_va_copy => {
            if (isel.live_values.fetchRemove(air.inst_index)) |va_list_vi| {
                defer va_list_vi.value.deref(isel);
                const ty_op = air.data(air.inst_index).ty_op;
                const va_list_ptr_vi = try isel.use(ty_op.operand);
                const va_list_ptr_mat = try va_list_ptr_vi.matReg(isel);
                _ = try va_list_vi.value.load(isel, ty_op.ty.toType(), va_list_ptr_mat.ra, .{});
                try va_list_ptr_mat.finish(isel);
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .c_va_end => if (air.next()) |next_air_tag| continue :air_tag next_air_tag,
        .c_va_start => {
            if (isel.live_values.fetchRemove(air.inst_index)) |va_list_vi| {
                defer va_list_vi.value.deref(isel);
                const ty = air.data(air.inst_index).ty;
                switch (isel.va_list) {
                    .other => |va_list| if (try va_list_vi.value.defReg(isel)) |va_list_ra| try isel.emit(.add(
                        va_list_ra.x(),
                        va_list.base.x(),
                        .{ .immediate = @intCast(va_list.offset) },
                    )),
                    .sysv => |va_list| {
                        var vr_offs_it = va_list_vi.value.field(ty, 28, 4);
                        const vr_offs_vi = try vr_offs_it.only(isel);
                        if (try vr_offs_vi.?.defReg(isel)) |vr_offs_ra| try isel.movImmediate(
                            vr_offs_ra.w(),
                            @as(u32, @bitCast(va_list.__vr_offs)),
                        );
                        var gr_offs_it = va_list_vi.value.field(ty, 24, 4);
                        const gr_offs_vi = try gr_offs_it.only(isel);
                        if (try gr_offs_vi.?.defReg(isel)) |gr_offs_ra| try isel.movImmediate(
                            gr_offs_ra.w(),
                            @as(u32, @bitCast(va_list.__gr_offs)),
                        );
                        var vr_top_it = va_list_vi.value.field(ty, 16, 8);
                        const vr_top_vi = try vr_top_it.only(isel);
                        if (try vr_top_vi.?.defReg(isel)) |vr_top_ra| try isel.emit(.add(
                            vr_top_ra.x(),
                            va_list.__vr_top.base.x(),
                            .{ .immediate = @intCast(va_list.__vr_top.offset) },
                        ));
                        var gr_top_it = va_list_vi.value.field(ty, 8, 8);
                        const gr_top_vi = try gr_top_it.only(isel);
                        if (try gr_top_vi.?.defReg(isel)) |gr_top_ra| try isel.emit(.add(
                            gr_top_ra.x(),
                            va_list.__gr_top.base.x(),
                            .{ .immediate = @intCast(va_list.__gr_top.offset) },
                        ));
                        var stack_it = va_list_vi.value.field(ty, 0, 8);
                        const stack_vi = try stack_it.only(isel);
                        if (try stack_vi.?.defReg(isel)) |stack_ra| try isel.emit(.add(
                            stack_ra.x(),
                            va_list.__stack.base.x(),
                            .{ .immediate = @intCast(va_list.__stack.offset) },
                        ));
                    },
                }
            }
            if (air.next()) |next_air_tag| continue :air_tag next_air_tag;
        },
        .work_item_id, .work_group_size, .work_group_id => unreachable,
    }
    assert(air.body_index == 0);
}

pub fn verify(isel: *Select, check_values: bool) void {
    if (!std.debug.runtime_safety) return;
    assert(isel.blocks.count() == 1 and isel.blocks.keys()[0] == Select.Block.main);
    assert(isel.active_loops.items.len == 0);
    assert(isel.dom_start == 0 and isel.dom_len == 0);
    var live_reg_it = isel.live_registers.iterator();
    while (live_reg_it.next()) |live_reg_entry| switch (live_reg_entry.value.*) {
        _ => {
            isel.dumpValues(.all);
            unreachable;
        },
        .allocating, .free => {},
    };
    if (check_values) for (isel.values.items) |value| if (value.refs != 0) {
        isel.dumpValues(.only_referenced);
        unreachable;
    };
}

///           Stack Frame Layout
/// +-+-----------------------------------+
/// |R| allocated stack                   |
/// +-+-----------------------------------+
/// |S| caller frame record               |   +---------------+
/// +-+-----------------------------------+ <-| entry/exit FP |
/// |R| caller frame                      |   +---------------+
/// +-+-----------------------------------+
/// |R| variable incoming stack arguments |   +---------------+
/// +-+-----------------------------------+ <-| __stack       |
/// |S| named incoming stack arguments    |   +---------------+
/// +-+-----------------------------------+ <-| entry/exit SP |
/// |S| incoming gr arguments             |   | __gr_top      |
/// +-+-----------------------------------+   +---------------+
/// |S| alignment gap                     |
/// +-+-----------------------------------+
/// |S| frame record                      |   +----------+
/// +-+-----------------------------------+ <-| FP       |
/// |S| incoming vr arguments             |   | __vr_top |
/// +-+-----------------------------------+   +----------+
/// |L| alignment gap                     |
/// +-+-----------------------------------+
/// |L| callee saved vr area              |
/// +-+-----------------------------------+
/// |L| callee saved gr area              |   +----------------------+
/// +-+-----------------------------------+ <-| prologue/epilogue SP |
/// |R| realignment gap                   |   +----------------------+
/// +-+-----------------------------------+
/// |L| locals                            |
/// +-+-----------------------------------+
/// |S| outgoing stack arguments          |   +----+
/// +-+-----------------------------------+ <-| SP |
/// |R| unallocated stack                 |   +----+
/// +-+-----------------------------------+
/// [S] Size computed by `analyze`, can be used by the body.
/// [L] Size computed by `layout`, can be used by the prologue/epilogue.
/// [R] Size unknown until runtime, can vary from one call to the next.
///
/// Constraints that led to this layout:
///  * FP to __stack/__gr_top/__vr_top must only pass through [S]
///  * SP to outgoing stack arguments/locals must only pass through [S]
///  * entry/exit SP to prologue/epilogue SP must only pass through [S/L]
///  * all save areas must be at a positive offset from prologue/epilogue SP
///  * the entry/exit SP to prologue/epilogue SP distance must
///   - be a multiple of 16 due to hardware restrictions on the value of SP
///   - conform to the limit from the first matching condition in the
///     following list due to instruction encoding limitations
///    1. callee saved gr count >= 2: multiple of 8 of at most 504 bytes
///    2. callee saved vr count >= 2: multiple of 8 of at most 504 bytes
///    3. callee saved gr count >= 1: at most 255 bytes
///    4. callee saved vr count >= 1: at most 255 bytes
///    5. variable incoming vr argument count >= 2: multiple of 16 of at most 1008 bytes
///    6. variable incoming vr argument count >= 1: at most 255 bytes
///    7. have frame record: multiple of 8 of at most 504 bytes
pub fn layout(
    isel: *Select,
    incoming: CallAbiIterator,
    is_sysv_var_args: bool,
    saved_gra_len: u7,
    saved_vra_len: u7,
    mod: *const Package.Module,
) !usize {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(isel.nav_index);
    wip_mir_log.debug("{f}<body>:\n", .{nav.fqn.fmt(ip)});

    const stack_size: u24 = @intCast(InternPool.Alignment.@"16".forward(isel.stack_size));

    var saves_buf: [10 + 8 + 8 + 2 + 8]struct {
        class: enum { integer, vector },
        needs_restore: bool,
        register: Register,
        offset: u10,
        size: u5,
    } = undefined;
    const saves, const saves_size, const frame_record_offset = saves: {
        var saves_len: usize = 0;
        var saves_size: u10 = 0;
        var save_ra: Register.Alias = undefined;

        // callee saved gr area
        save_ra = .r19;
        while (save_ra != .r29) : (save_ra = @enumFromInt(@intFromEnum(save_ra) + 1)) {
            if (!isel.saved_registers.contains(save_ra)) continue;
            saves_size = std.mem.alignForward(u10, saves_size, 8);
            saves_buf[saves_len] = .{
                .class = .integer,
                .needs_restore = true,
                .register = save_ra.x(),
                .offset = saves_size,
                .size = 8,
            };
            saves_len += 1;
            saves_size += 8;
        }
        var deferred_gr = if (saves_size == 8 or (saves_size % 16 != 0 and saved_gra_len % 2 != 0)) gr: {
            saves_len -= 1;
            saves_size -= 8;
            break :gr saves_buf[saves_len].register;
        } else null;
        defer assert(deferred_gr == null);

        // callee saved vr area
        save_ra = .v8;
        while (save_ra != .v16) : (save_ra = @enumFromInt(@intFromEnum(save_ra) + 1)) {
            if (!isel.saved_registers.contains(save_ra)) continue;
            saves_size = std.mem.alignForward(u10, saves_size, 8);
            saves_buf[saves_len] = .{
                .class = .vector,
                .needs_restore = true,
                .register = save_ra.d(),
                .offset = saves_size,
                .size = 8,
            };
            saves_len += 1;
            saves_size += 8;
        }
        if (deferred_gr != null and saved_gra_len % 2 == 0) {
            saves_size = std.mem.alignForward(u10, saves_size, 8);
            saves_buf[saves_len] = .{
                .class = .integer,
                .needs_restore = true,
                .register = deferred_gr.?,
                .offset = saves_size,
                .size = 8,
            };
            saves_len += 1;
            saves_size += 8;
            deferred_gr = null;
        }
        if (saves_size % 16 != 0 and saved_vra_len % 2 != 0) {
            const prev_save = &saves_buf[saves_len - 1];
            switch (prev_save.class) {
                .integer => {},
                .vector => {
                    prev_save.register = prev_save.register.alias.q();
                    prev_save.size = 16;
                    saves_size += 8;
                },
            }
        }

        // incoming vr arguments
        save_ra = if (mod.strip) incoming.nsrn else CallAbiIterator.nsrn_start;
        while (save_ra != if (is_sysv_var_args) CallAbiIterator.nsrn_end else incoming.nsrn) : (save_ra = @enumFromInt(@intFromEnum(save_ra) + 1)) {
            saves_size = std.mem.alignForward(u10, saves_size, 16);
            saves_buf[saves_len] = .{
                .class = .vector,
                .needs_restore = false,
                .register = save_ra.q(),
                .offset = saves_size,
                .size = 16,
            };
            saves_len += 1;
            saves_size += 16;
        }

        // frame record
        saves_size = std.mem.alignForward(u10, saves_size, 16);
        const frame_record_offset = saves_size;
        saves_buf[saves_len] = .{
            .class = .integer,
            .needs_restore = true,
            .register = .fp,
            .offset = saves_size,
            .size = 8,
        };
        saves_len += 1;
        saves_size += 8;

        saves_size = std.mem.alignForward(u10, saves_size, 8);
        saves_buf[saves_len] = .{
            .class = .integer,
            .needs_restore = true,
            .register = .lr,
            .offset = saves_size,
            .size = 8,
        };
        saves_len += 1;
        saves_size += 8;

        // incoming gr arguments
        if (deferred_gr) |gr| {
            saves_size = std.mem.alignForward(u10, saves_size, 8);
            saves_buf[saves_len] = .{
                .class = .integer,
                .needs_restore = true,
                .register = gr,
                .offset = saves_size,
                .size = 8,
            };
            saves_len += 1;
            saves_size += 8;
            deferred_gr = null;
        } else switch (@as(u1, @truncate(saved_gra_len))) {
            0 => {},
            1 => saves_size += 8,
        }
        save_ra = if (mod.strip) incoming.ngrn else CallAbiIterator.ngrn_start;
        while (save_ra != if (is_sysv_var_args) CallAbiIterator.ngrn_end else incoming.ngrn) : (save_ra = @enumFromInt(@intFromEnum(save_ra) + 1)) {
            saves_size = std.mem.alignForward(u10, saves_size, 8);
            saves_buf[saves_len] = .{
                .class = .integer,
                .needs_restore = false,
                .register = save_ra.x(),
                .offset = saves_size,
                .size = 8,
            };
            saves_len += 1;
            saves_size += 8;
        }

        assert(InternPool.Alignment.@"16".check(saves_size));
        break :saves .{ saves_buf[0..saves_len], saves_size, frame_record_offset };
    };

    {
        wip_mir_log.debug("{f}<prologue>:", .{nav.fqn.fmt(ip)});
        var save_index: usize = 0;
        while (save_index < saves.len) if (save_index + 2 <= saves.len and
            saves[save_index + 0].class == saves[save_index + 1].class and
            saves[save_index + 0].size == saves[save_index + 1].size and
            saves[save_index + 0].offset + saves[save_index + 0].size == saves[save_index + 1].offset)
        {
            try isel.emit(.stp(
                saves[save_index + 0].register,
                saves[save_index + 1].register,
                switch (saves[save_index + 0].offset) {
                    0 => .{ .pre_index = .{
                        .base = .sp,
                        .index = @intCast(-@as(i11, saves_size)),
                    } },
                    else => |offset| .{ .signed_offset = .{
                        .base = .sp,
                        .offset = @intCast(offset),
                    } },
                },
            ));
            save_index += 2;
        } else {
            try isel.emit(.str(
                saves[save_index].register,
                switch (saves[save_index].offset) {
                    0 => .{ .pre_index = .{
                        .base = .sp,
                        .index = @intCast(-@as(i11, saves_size)),
                    } },
                    else => |offset| .{ .unsigned_offset = .{
                        .base = .sp,
                        .offset = @intCast(offset),
                    } },
                },
            ));
            save_index += 1;
        };

        try isel.emit(.add(.fp, .sp, .{ .immediate = frame_record_offset }));
        const scratch_reg: Register = if (isel.stack_align == .@"16")
            .sp
        else if (stack_size == 0 and frame_record_offset == 0)
            .fp
        else
            .ip0;
        const stack_size_lo: u12 = @truncate(stack_size >> 0);
        const stack_size_hi: u12 = @truncate(stack_size >> 12);
        if (mod.stack_check) {
            if (stack_size_hi > 2) {
                try isel.movImmediate(.ip1, stack_size_hi);
                const loop_label = isel.instructions.items.len;
                try isel.emit(.sub(.sp, .sp, .{
                    .shifted_immediate = .{ .immediate = 1, .lsl = .@"12" },
                }));
                try isel.emit(.sub(.ip1, .ip1, .{ .immediate = 1 }));
                try isel.emit(.ldr(.xzr, .{ .base = .sp }));
                try isel.emit(.cbnz(.ip1, -@as(i21, @intCast(
                    (isel.instructions.items.len - loop_label) << 2,
                ))));
            } else for (0..stack_size_hi) |_| {
                try isel.emit(.sub(.sp, .sp, .{
                    .shifted_immediate = .{ .immediate = 1, .lsl = .@"12" },
                }));
                try isel.emit(.ldr(.xzr, .{ .base = .sp }));
            }
            if (stack_size_lo > 0) try isel.emit(.sub(
                scratch_reg,
                .sp,
                .{ .immediate = stack_size_lo },
            )) else if (scratch_reg.alias == Register.Alias.ip0)
                try isel.emit(.add(scratch_reg, .sp, .{ .immediate = 0 }));
        } else {
            if (stack_size_hi > 0) try isel.emit(.sub(scratch_reg, .sp, .{
                .shifted_immediate = .{ .immediate = stack_size_hi, .lsl = .@"12" },
            }));
            if (stack_size_lo > 0) try isel.emit(.sub(
                scratch_reg,
                if (stack_size_hi > 0) scratch_reg else .sp,
                .{ .immediate = stack_size_lo },
            )) else if (scratch_reg.alias == Register.Alias.ip0 and stack_size_hi == 0)
                try isel.emit(.add(scratch_reg, .sp, .{ .immediate = 0 }));
        }
        if (isel.stack_align != .@"16") try isel.emit(.@"and"(.sp, scratch_reg, .{ .immediate = .{
            .N = .doubleword,
            .immr = -%isel.stack_align.toLog2Units(),
            .imms = ~isel.stack_align.toLog2Units(),
        } }));
        wip_mir_log.debug("", .{});
    }

    const epilogue = isel.instructions.items.len;
    if (isel.returns) {
        try isel.emit(.ret(.lr));
        var save_index: usize = 0;
        var first_offset: ?u10 = null;
        while (save_index < saves.len) {
            if (save_index + 2 <= saves.len and saves[save_index + 1].needs_restore and
                saves[save_index + 0].class == saves[save_index + 1].class and
                saves[save_index + 0].offset + saves[save_index + 0].size == saves[save_index + 1].offset)
            {
                try isel.emit(.ldp(
                    saves[save_index + 0].register,
                    saves[save_index + 1].register,
                    if (first_offset) |offset| .{ .signed_offset = .{
                        .base = .sp,
                        .offset = @intCast(saves[save_index + 0].offset - offset),
                    } } else form: {
                        first_offset = @intCast(saves[save_index + 0].offset);
                        break :form .{ .post_index = .{
                            .base = .sp,
                            .index = @intCast(saves_size - first_offset.?),
                        } };
                    },
                ));
                save_index += 2;
            } else if (saves[save_index].needs_restore) {
                try isel.emit(.ldr(
                    saves[save_index].register,
                    if (first_offset) |offset| .{ .unsigned_offset = .{
                        .base = .sp,
                        .offset = saves[save_index + 0].offset - offset,
                    } } else form: {
                        const offset = saves[save_index + 0].offset;
                        first_offset = offset;
                        break :form .{ .post_index = .{
                            .base = .sp,
                            .index = @intCast(saves_size - offset),
                        } };
                    },
                ));
                save_index += 1;
            } else save_index += 1;
        }
        const offset = stack_size + first_offset.?;
        const offset_lo: u12 = @truncate(offset >> 0);
        const offset_hi: u12 = @truncate(offset >> 12);
        if (isel.stack_align != .@"16" or (offset_lo > 0 and offset_hi > 0)) {
            const fp_offset = @as(i11, first_offset.?) - frame_record_offset;
            try isel.emit(if (fp_offset >= 0)
                .add(.sp, .fp, .{ .immediate = @intCast(fp_offset) })
            else
                .sub(.sp, .fp, .{ .immediate = @intCast(-fp_offset) }));
        } else {
            if (offset_hi > 0) try isel.emit(.add(.sp, .sp, .{
                .shifted_immediate = .{ .immediate = offset_hi, .lsl = .@"12" },
            }));
            if (offset_lo > 0) try isel.emit(.add(.sp, .sp, .{
                .immediate = offset_lo,
            }));
        }
        wip_mir_log.debug("{f}<epilogue>:\n", .{nav.fqn.fmt(ip)});
    }
    return epilogue;
}

fn fmtDom(isel: *Select, inst: Air.Inst.Index, start: u32, len: u32) struct {
    isel: *Select,
    inst: Air.Inst.Index,
    start: u32,
    len: u32,
    pub fn format(data: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("%{d} -> {{", .{@intFromEnum(data.inst)});
        var first = true;
        for (data.isel.blocks.keys()[0..data.len], 0..) |block_inst_index, dom_index| {
            if (@as(u1, @truncate(data.isel.dom.items[
                data.start + dom_index / @bitSizeOf(DomInt)
            ] >> @truncate(dom_index))) == 0) continue;
            if (first) {
                first = false;
            } else {
                try writer.writeByte(',');
            }
            switch (block_inst_index) {
                Block.main => try writer.writeAll(" %main"),
                else => try writer.print(" %{d}", .{@intFromEnum(block_inst_index)}),
            }
        }
        if (!first) try writer.writeByte(' ');
        try writer.writeByte('}');
    }
} {
    return .{ .isel = isel, .inst = inst, .start = start, .len = len };
}

fn fmtLoopLive(isel: *Select, loop_inst: Air.Inst.Index) struct {
    isel: *Select,
    inst: Air.Inst.Index,
    pub fn format(data: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const loops = data.isel.loops.values();
        const loop_index = data.isel.loops.getIndex(data.inst).?;
        const live_insts =
            data.isel.loop_live.list.items[loops[loop_index].live..loops[loop_index + 1].live];

        try writer.print("%{d} <- {{", .{@intFromEnum(data.inst)});
        var first = true;
        for (live_insts) |live_inst| {
            if (first) {
                first = false;
            } else {
                try writer.writeByte(',');
            }
            try writer.print(" %{d}", .{@intFromEnum(live_inst)});
        }
        if (!first) try writer.writeByte(' ');
        try writer.writeByte('}');
    }
} {
    return .{ .isel = isel, .inst = loop_inst };
}

fn fmtType(isel: *Select, ty: ZigType) ZigType.Formatter {
    return ty.fmt(isel.pt);
}

fn fmtConstant(isel: *Select, constant: Constant) @typeInfo(@TypeOf(Constant.fmtValue)).@"fn".return_type.? {
    return constant.fmtValue(isel.pt);
}

fn block(
    isel: *Select,
    air_inst_index: Air.Inst.Index,
    res_ty: ZigType,
    air_body: []const Air.Inst.Index,
) !void {
    if (res_ty.toIntern() != .noreturn_type) {
        isel.blocks.putAssumeCapacityNoClobber(air_inst_index, .{
            .live_registers = isel.live_registers,
            .target_label = @intCast(isel.instructions.items.len),
        });
    }
    try isel.body(air_body);
    if (res_ty.toIntern() != .noreturn_type) {
        const block_entry = isel.blocks.pop().?;
        assert(block_entry.key == air_inst_index);
        if (isel.live_values.fetchRemove(air_inst_index)) |result_vi| result_vi.value.deref(isel);
    }
}

fn emit(isel: *Select, instruction: codegen.aarch64.encoding.Instruction) !void {
    wip_mir_log.debug("  | {f}", .{instruction});
    try isel.instructions.append(isel.pt.zcu.gpa, instruction);
}

fn emitPanic(isel: *Select, panic_id: Zcu.SimplePanicId) !void {
    const zcu = isel.pt.zcu;
    try isel.nav_relocs.append(zcu.gpa, .{
        .nav = switch (zcu.intern_pool.indexToKey(zcu.builtin_decl_values.get(panic_id.toBuiltin()))) {
            else => unreachable,
            inline .@"extern", .func => |func| func.owner_nav,
        },
        .reloc = .{ .label = @intCast(isel.instructions.items.len) },
    });
    try isel.emit(.bl(0));
}

fn emitLiteral(isel: *Select, bytes: []const u8) !void {
    const words: []align(1) const u32 = @ptrCast(bytes);
    const literals = try isel.literals.addManyAsSlice(isel.pt.zcu.gpa, words.len);
    switch (isel.target.cpu.arch.endian()) {
        .little => @memcpy(literals, words),
        .big => for (words, 0..) |word, word_index| {
            literals[literals.len - 1 - word_index] = @byteSwap(word);
        },
    }
}

fn fail(isel: *Select, comptime format: []const u8, args: anytype) error{ OutOfMemory, CodegenFail } {
    @branchHint(.cold);
    return isel.pt.zcu.codegenFail(isel.nav_index, format, args);
}

/// dst = src
fn movImmediate(isel: *Select, dst_reg: Register, src_imm: u64) !void {
    const sf = dst_reg.format.general;
    if (src_imm == 0) {
        const zr: Register = switch (sf) {
            .word => .wzr,
            .doubleword => .xzr,
        };
        return isel.emit(.orr(dst_reg, zr, .{ .register = zr }));
    }

    const Part = u16;
    const min_part: Part = std.math.minInt(Part);
    const max_part: Part = std.math.maxInt(Part);

    const parts: [4]Part = @bitCast(switch (sf) {
        .word => @as(u32, @intCast(src_imm)),
        .doubleword => @as(u64, @intCast(src_imm)),
    });
    const width: u7 = switch (sf) {
        .word => 32,
        .doubleword => 64,
    };
    const parts_len: u3 = @intCast(@divExact(width, @bitSizeOf(Part)));
    var equal_min_count: u3 = 0;
    var equal_max_count: u3 = 0;
    for (parts[0..parts_len]) |part| {
        equal_min_count += @intFromBool(part == min_part);
        equal_max_count += @intFromBool(part == max_part);
    }

    const equal_fill_count, const fill_part: Part = if (equal_min_count >= equal_max_count)
        .{ equal_min_count, min_part }
    else
        .{ equal_max_count, max_part };
    var remaining_parts = @max(parts_len - equal_fill_count, 1);

    if (remaining_parts > 1) {
        var elem_width: u8 = 2;
        while (elem_width <= width) : (elem_width <<= 1) {
            const emask = @as(u64, std.math.maxInt(u64)) >> @intCast(64 - elem_width);
            const rmask = @divExact(@as(u64, switch (sf) {
                .word => std.math.maxInt(u32),
                .doubleword => std.math.maxInt(u64),
            }), emask);
            const elem = src_imm & emask;
            if (src_imm != elem * rmask) continue;
            const imask: u64 = @bitCast(@as(i64, @bitCast(elem << 63)) >> 63);
            const lsb0 = elem ^ (imask & emask);
            const lsb1 = (lsb0 - 1) | lsb0;
            if ((lsb1 +% 1) & lsb1 == 0) {
                const lo: u6 = @intCast(@ctz(lsb0));
                const hi: u6 = @intCast(@clz(lsb0) - (64 - elem_width));
                const mid: u6 = @intCast(elem_width - lo - hi);
                const smask: u6 = @truncate(imask);
                const mid_masked = mid & ~smask;
                return isel.emit(.orr(
                    dst_reg,
                    switch (sf) {
                        .word => .wzr,
                        .doubleword => .xzr,
                    },
                    .{ .immediate = .{
                        .N = @enumFromInt(elem_width >> 6),
                        .immr = hi + mid_masked,
                        .imms = ((((lo + hi) & smask) | mid_masked) - 1) | -%@as(u6, @truncate(elem_width)) << 1,
                    } },
                ));
            }
        }
    }

    var part_index = parts_len;
    while (part_index > 0) {
        part_index -= 1;
        if (part_index >= remaining_parts and parts[part_index] == fill_part) continue;
        remaining_parts -= 1;
        try isel.emit(if (remaining_parts > 0) .movk(
            dst_reg,
            parts[part_index],
            .{ .lsl = @enumFromInt(part_index) },
        ) else switch (fill_part) {
            else => unreachable,
            min_part => .movz(
                dst_reg,
                parts[part_index],
                .{ .lsl = @enumFromInt(part_index) },
            ),
            max_part => .movn(
                dst_reg,
                ~parts[part_index],
                .{ .lsl = @enumFromInt(part_index) },
            ),
        });
    }
    assert(remaining_parts == 0);
}

/// elem_ptr = base +- elem_size * index
/// elem_ptr, base, and index may alias
fn elemPtr(
    isel: *Select,
    elem_ptr_ra: Register.Alias,
    base_ra: Register.Alias,
    op: codegen.aarch64.encoding.Instruction.AddSubtractOp,
    elem_size: u64,
    index_vi: Value.Index,
) !void {
    const index_mat = try index_vi.matReg(isel);
    switch (@popCount(elem_size)) {
        0 => unreachable,
        1 => try isel.emit(switch (op) {
            .add => switch (base_ra) {
                else => .add(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                    .register = index_mat.ra.x(),
                    .shift = .{ .lsl = @intCast(@ctz(elem_size)) },
                } }),
                .zr => switch (@ctz(elem_size)) {
                    0 => .orr(elem_ptr_ra.x(), .xzr, .{ .register = index_mat.ra.x() }),
                    else => |shift| .ubfm(elem_ptr_ra.x(), index_mat.ra.x(), .{
                        .N = .doubleword,
                        .immr = @intCast(64 - shift),
                        .imms = @intCast(63 - shift),
                    }),
                },
            },
            .sub => .sub(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                .register = index_mat.ra.x(),
                .shift = .{ .lsl = @intCast(@ctz(elem_size)) },
            } }),
        }),
        2 => {
            const shift: u6 = @intCast(@ctz(elem_size));
            const temp_ra = temp_ra: switch (op) {
                .add => switch (base_ra) {
                    else => {
                        const temp_ra = try isel.allocIntReg();
                        errdefer isel.freeReg(temp_ra);
                        try isel.emit(.add(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                            .register = temp_ra.x(),
                            .shift = .{ .lsl = shift },
                        } }));
                        break :temp_ra temp_ra;
                    },
                    .zr => {
                        if (shift > 0) try isel.emit(.ubfm(elem_ptr_ra.x(), elem_ptr_ra.x(), .{
                            .N = .doubleword,
                            .immr = -%shift,
                            .imms = ~shift,
                        }));
                        break :temp_ra elem_ptr_ra;
                    },
                },
                .sub => {
                    const temp_ra = try isel.allocIntReg();
                    errdefer isel.freeReg(temp_ra);
                    try isel.emit(.sub(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                        .register = temp_ra.x(),
                        .shift = .{ .lsl = shift },
                    } }));
                    break :temp_ra temp_ra;
                },
            };
            defer if (temp_ra != elem_ptr_ra) isel.freeReg(temp_ra);
            try isel.emit(.add(temp_ra.x(), index_mat.ra.x(), .{ .shifted_register = .{
                .register = index_mat.ra.x(),
                .shift = .{ .lsl = @intCast(63 - @clz(elem_size) - shift) },
            } }));
        },
        else => {
            const elem_size_lsb1 = (elem_size - 1) | elem_size;
            if ((elem_size_lsb1 +% 1) & elem_size_lsb1 == 0) {
                const shift: u6 = @intCast(@ctz(elem_size));
                const temp_ra = temp_ra: switch (op) {
                    .add => {
                        const temp_ra = try isel.allocIntReg();
                        errdefer isel.freeReg(temp_ra);
                        try isel.emit(.sub(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                            .register = temp_ra.x(),
                            .shift = .{ .lsl = shift },
                        } }));
                        break :temp_ra temp_ra;
                    },
                    .sub => switch (base_ra) {
                        else => {
                            const temp_ra = try isel.allocIntReg();
                            errdefer isel.freeReg(temp_ra);
                            try isel.emit(.add(elem_ptr_ra.x(), base_ra.x(), .{ .shifted_register = .{
                                .register = temp_ra.x(),
                                .shift = .{ .lsl = shift },
                            } }));
                            break :temp_ra temp_ra;
                        },
                        .zr => {
                            if (shift > 0) try isel.emit(.ubfm(elem_ptr_ra.x(), elem_ptr_ra.x(), .{
                                .N = .doubleword,
                                .immr = -%shift,
                                .imms = ~shift,
                            }));
                            break :temp_ra elem_ptr_ra;
                        },
                    },
                };
                defer if (temp_ra != elem_ptr_ra) isel.freeReg(temp_ra);
                try isel.emit(.sub(temp_ra.x(), index_mat.ra.x(), .{ .shifted_register = .{
                    .register = index_mat.ra.x(),
                    .shift = .{ .lsl = @intCast(64 - @clz(elem_size) - shift) },
                } }));
            } else {
                try isel.emit(switch (op) {
                    .add => .madd(elem_ptr_ra.x(), index_mat.ra.x(), elem_ptr_ra.x(), base_ra.x()),
                    .sub => .msub(elem_ptr_ra.x(), index_mat.ra.x(), elem_ptr_ra.x(), base_ra.x()),
                });
                try isel.movImmediate(elem_ptr_ra.x(), elem_size);
            }
        },
    }
    try index_mat.finish(isel);
}

fn clzLimb(
    isel: *Select,
    res_ra: Register.Alias,
    src_int_info: std.builtin.Type.Int,
    src_ra: Register.Alias,
) !void {
    switch (src_int_info.bits) {
        else => unreachable,
        1...31 => |bits| {
            try isel.emit(.sub(res_ra.w(), res_ra.w(), .{
                .immediate = @intCast(32 - bits),
            }));
            switch (src_int_info.signedness) {
                .signed => {
                    try isel.emit(.clz(res_ra.w(), res_ra.w()));
                    try isel.emit(.ubfm(res_ra.w(), src_ra.w(), .{
                        .N = .word,
                        .immr = 0,
                        .imms = @intCast(bits - 1),
                    }));
                },
                .unsigned => try isel.emit(.clz(res_ra.w(), src_ra.w())),
            }
        },
        32 => try isel.emit(.clz(res_ra.w(), src_ra.w())),
        33...63 => |bits| {
            try isel.emit(.sub(res_ra.w(), res_ra.w(), .{
                .immediate = @intCast(64 - bits),
            }));
            switch (src_int_info.signedness) {
                .signed => {
                    try isel.emit(.clz(res_ra.x(), res_ra.x()));
                    try isel.emit(.ubfm(res_ra.x(), src_ra.x(), .{
                        .N = .doubleword,
                        .immr = 0,
                        .imms = @intCast(bits - 1),
                    }));
                },
                .unsigned => try isel.emit(.clz(res_ra.x(), src_ra.x())),
            }
        },
        64 => try isel.emit(.clz(res_ra.x(), src_ra.x())),
    }
}

fn ctzLimb(
    isel: *Select,
    res_ra: Register.Alias,
    src_int_info: std.builtin.Type.Int,
    src_ra: Register.Alias,
) !void {
    switch (src_int_info.bits) {
        else => unreachable,
        1...31 => |bits| {
            try isel.emit(.clz(res_ra.w(), res_ra.w()));
            try isel.emit(.rbit(res_ra.w(), res_ra.w()));
            try isel.emit(.orr(res_ra.w(), src_ra.w(), .{ .immediate = .{
                .N = .word,
                .immr = @intCast(32 - bits),
                .imms = @intCast(32 - bits - 1),
            } }));
        },
        32 => {
            try isel.emit(.clz(res_ra.w(), res_ra.w()));
            try isel.emit(.rbit(res_ra.w(), src_ra.w()));
        },
        33...63 => |bits| {
            try isel.emit(.clz(res_ra.x(), res_ra.x()));
            try isel.emit(.rbit(res_ra.x(), res_ra.x()));
            try isel.emit(.orr(res_ra.x(), src_ra.x(), .{ .immediate = .{
                .N = .doubleword,
                .immr = @intCast(64 - bits),
                .imms = @intCast(64 - bits - 1),
            } }));
        },
        64 => {
            try isel.emit(.clz(res_ra.x(), res_ra.x()));
            try isel.emit(.rbit(res_ra.x(), src_ra.x()));
        },
    }
}

fn loadReg(
    isel: *Select,
    ra: Register.Alias,
    size: u64,
    signedness: std.builtin.Signedness,
    base_ra: Register.Alias,
    offset: i65,
) !void {
    switch (size) {
        0 => unreachable,
        1 => {
            if (std.math.cast(u12, offset)) |unsigned_offset| return isel.emit(if (ra.isVector()) .ldr(
                ra.b(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ) else switch (signedness) {
                .signed => .ldrsb(ra.w(), .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } }),
                .unsigned => .ldrb(ra.w(), .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } }),
            });
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(if (ra.isVector())
                .ldur(ra.b(), base_ra.x(), signed_offset)
            else switch (signedness) {
                .signed => .ldursb(ra.w(), base_ra.x(), signed_offset),
                .unsigned => .ldurb(ra.w(), base_ra.x(), signed_offset),
            });
        },
        2 => {
            if (std.math.cast(u13, offset)) |unsigned_offset| if (unsigned_offset % 2 == 0)
                return isel.emit(if (ra.isVector()) .ldr(
                    ra.h(),
                    .{ .unsigned_offset = .{
                        .base = base_ra.x(),
                        .offset = unsigned_offset,
                    } },
                ) else switch (signedness) {
                    .signed => .ldrsh(
                        ra.w(),
                        .{ .unsigned_offset = .{
                            .base = base_ra.x(),
                            .offset = unsigned_offset,
                        } },
                    ),
                    .unsigned => .ldrh(
                        ra.w(),
                        .{ .unsigned_offset = .{
                            .base = base_ra.x(),
                            .offset = unsigned_offset,
                        } },
                    ),
                });
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(if (ra.isVector())
                .ldur(ra.h(), base_ra.x(), signed_offset)
            else switch (signedness) {
                .signed => .ldursh(ra.w(), base_ra.x(), signed_offset),
                .unsigned => .ldurh(ra.w(), base_ra.x(), signed_offset),
            });
        },
        3 => {
            const lo16_ra = try isel.allocIntReg();
            defer isel.freeReg(lo16_ra);
            try isel.emit(.orr(ra.w(), lo16_ra.w(), .{ .shifted_register = .{
                .register = ra.w(),
                .shift = .{ .lsl = 16 },
            } }));
            try isel.loadReg(ra, 1, signedness, base_ra, offset + 2);
            return isel.loadReg(lo16_ra, 2, .unsigned, base_ra, offset);
        },
        4 => {
            if (std.math.cast(u14, offset)) |unsigned_offset| if (unsigned_offset % 4 == 0) return isel.emit(.ldr(
                if (ra.isVector()) ra.s() else ra.w(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.ldur(
                if (ra.isVector()) ra.s() else ra.w(),
                base_ra.x(),
                signed_offset,
            ));
        },
        5, 6 => {
            const lo32_ra = try isel.allocIntReg();
            defer isel.freeReg(lo32_ra);
            try isel.emit(.orr(ra.x(), lo32_ra.x(), .{ .shifted_register = .{
                .register = ra.x(),
                .shift = .{ .lsl = 32 },
            } }));
            try isel.loadReg(ra, size - 4, signedness, base_ra, offset + 4);
            return isel.loadReg(lo32_ra, 4, .unsigned, base_ra, offset);
        },
        7 => {
            const lo32_ra = try isel.allocIntReg();
            defer isel.freeReg(lo32_ra);
            const lo48_ra = try isel.allocIntReg();
            defer isel.freeReg(lo48_ra);
            try isel.emit(.orr(ra.x(), lo48_ra.x(), .{ .shifted_register = .{
                .register = ra.x(),
                .shift = .{ .lsl = 32 + 16 },
            } }));
            try isel.loadReg(ra, 1, signedness, base_ra, offset + 4 + 2);
            try isel.emit(.orr(lo48_ra.x(), lo32_ra.x(), .{ .shifted_register = .{
                .register = lo48_ra.x(),
                .shift = .{ .lsl = 32 },
            } }));
            try isel.loadReg(lo48_ra, 2, .unsigned, base_ra, offset + 4);
            return isel.loadReg(lo32_ra, 4, .unsigned, base_ra, offset);
        },
        8 => {
            if (std.math.cast(u15, offset)) |unsigned_offset| if (unsigned_offset % 8 == 0) return isel.emit(.ldr(
                if (ra.isVector()) ra.d() else ra.x(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.ldur(
                if (ra.isVector()) ra.d() else ra.x(),
                base_ra.x(),
                signed_offset,
            ));
        },
        16 => {
            if (std.math.cast(u16, offset)) |unsigned_offset| if (unsigned_offset % 16 == 0) return isel.emit(.ldr(
                ra.q(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.ldur(ra.q(), base_ra.x(), signed_offset));
        },
        else => return isel.fail("bad load size: {d}", .{size}),
    }
    const ptr_ra = try isel.allocIntReg();
    defer isel.freeReg(ptr_ra);
    try isel.loadReg(ra, size, signedness, ptr_ra, 0);
    if (std.math.cast(u24, offset)) |pos_offset| {
        const lo12: u12 = @truncate(pos_offset >> 0);
        const hi12: u12 = @intCast(pos_offset >> 12);
        if (hi12 > 0) try isel.emit(.add(
            ptr_ra.x(),
            if (lo12 > 0) ptr_ra.x() else base_ra.x(),
            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
        ));
        if (lo12 > 0 or hi12 == 0) try isel.emit(.add(ptr_ra.x(), base_ra.x(), .{ .immediate = lo12 }));
    } else if (std.math.cast(u24, -offset)) |neg_offset| {
        const lo12: u12 = @truncate(neg_offset >> 0);
        const hi12: u12 = @intCast(neg_offset >> 12);
        if (hi12 > 0) try isel.emit(.sub(
            ptr_ra.x(),
            if (lo12 > 0) ptr_ra.x() else base_ra.x(),
            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
        ));
        if (lo12 > 0 or hi12 == 0) try isel.emit(.sub(ptr_ra.x(), base_ra.x(), .{ .immediate = lo12 }));
    } else {
        try isel.emit(.add(ptr_ra.x(), base_ra.x(), .{ .register = ptr_ra.x() }));
        try isel.movImmediate(ptr_ra.x(), @truncate(@as(u65, @bitCast(offset))));
    }
}

fn storeReg(
    isel: *Select,
    ra: Register.Alias,
    size: u64,
    base_ra: Register.Alias,
    offset: i65,
) !void {
    switch (size) {
        0 => unreachable,
        1 => {
            if (std.math.cast(u12, offset)) |unsigned_offset| return isel.emit(if (ra.isVector()) .str(
                ra.b(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ) else .strb(
                ra.w(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(if (ra.isVector())
                .stur(ra.b(), base_ra.x(), signed_offset)
            else
                .sturb(ra.w(), base_ra.x(), signed_offset));
        },
        2 => {
            if (std.math.cast(u13, offset)) |unsigned_offset| if (unsigned_offset % 2 == 0)
                return isel.emit(if (ra.isVector()) .str(
                    ra.h(),
                    .{ .unsigned_offset = .{
                        .base = base_ra.x(),
                        .offset = unsigned_offset,
                    } },
                ) else .strh(
                    ra.w(),
                    .{ .unsigned_offset = .{
                        .base = base_ra.x(),
                        .offset = unsigned_offset,
                    } },
                ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(if (ra.isVector())
                .stur(ra.h(), base_ra.x(), signed_offset)
            else
                .sturh(ra.w(), base_ra.x(), signed_offset));
        },
        3 => {
            const hi8_ra = try isel.allocIntReg();
            defer isel.freeReg(hi8_ra);
            try isel.storeReg(hi8_ra, 1, base_ra, offset + 2);
            try isel.storeReg(ra, 2, base_ra, offset);
            return isel.emit(.ubfm(hi8_ra.w(), ra.w(), .{
                .N = .word,
                .immr = 16,
                .imms = 16 + 8 - 1,
            }));
        },
        4 => {
            if (std.math.cast(u14, offset)) |unsigned_offset| if (unsigned_offset % 4 == 0) return isel.emit(.str(
                if (ra.isVector()) ra.s() else ra.w(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.stur(
                if (ra.isVector()) ra.s() else ra.w(),
                base_ra.x(),
                signed_offset,
            ));
        },
        5 => {
            const hi8_ra = try isel.allocIntReg();
            defer isel.freeReg(hi8_ra);
            try isel.storeReg(hi8_ra, 1, base_ra, offset + 4);
            try isel.storeReg(ra, 4, base_ra, offset);
            return isel.emit(.ubfm(hi8_ra.x(), ra.x(), .{
                .N = .doubleword,
                .immr = 32,
                .imms = 32 + 8 - 1,
            }));
        },
        6 => {
            const hi16_ra = try isel.allocIntReg();
            defer isel.freeReg(hi16_ra);
            try isel.storeReg(hi16_ra, 2, base_ra, offset + 4);
            try isel.storeReg(ra, 4, base_ra, offset);
            return isel.emit(.ubfm(hi16_ra.x(), ra.x(), .{
                .N = .doubleword,
                .immr = 32,
                .imms = 32 + 16 - 1,
            }));
        },
        7 => {
            const hi16_ra = try isel.allocIntReg();
            defer isel.freeReg(hi16_ra);
            const hi8_ra = try isel.allocIntReg();
            defer isel.freeReg(hi8_ra);
            try isel.storeReg(hi8_ra, 1, base_ra, offset + 6);
            try isel.storeReg(hi16_ra, 2, base_ra, offset + 4);
            try isel.storeReg(ra, 4, base_ra, offset);
            try isel.emit(.ubfm(hi8_ra.x(), ra.x(), .{
                .N = .doubleword,
                .immr = 32 + 16,
                .imms = 32 + 16 + 8 - 1,
            }));
            return isel.emit(.ubfm(hi16_ra.x(), ra.x(), .{
                .N = .doubleword,
                .immr = 32,
                .imms = 32 + 16 - 1,
            }));
        },
        8 => {
            if (std.math.cast(u15, offset)) |unsigned_offset| if (unsigned_offset % 8 == 0) return isel.emit(.str(
                if (ra.isVector()) ra.d() else ra.x(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.stur(
                if (ra.isVector()) ra.d() else ra.x(),
                base_ra.x(),
                signed_offset,
            ));
        },
        16 => {
            if (std.math.cast(u16, offset)) |unsigned_offset| if (unsigned_offset % 16 == 0) return isel.emit(.str(
                ra.q(),
                .{ .unsigned_offset = .{
                    .base = base_ra.x(),
                    .offset = unsigned_offset,
                } },
            ));
            if (std.math.cast(i9, offset)) |signed_offset| return isel.emit(.stur(ra.q(), base_ra.x(), signed_offset));
        },
        else => return isel.fail("bad store size: {d}", .{size}),
    }
    const ptr_ra = try isel.allocIntReg();
    defer isel.freeReg(ptr_ra);
    try isel.storeReg(ra, size, ptr_ra, 0);
    if (std.math.cast(u24, offset)) |pos_offset| {
        const lo12: u12 = @truncate(pos_offset >> 0);
        const hi12: u12 = @intCast(pos_offset >> 12);
        if (hi12 > 0) try isel.emit(.add(
            ptr_ra.x(),
            if (lo12 > 0) ptr_ra.x() else base_ra.x(),
            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
        ));
        if (lo12 > 0 or hi12 == 0) try isel.emit(.add(ptr_ra.x(), base_ra.x(), .{ .immediate = lo12 }));
    } else if (std.math.cast(u24, -offset)) |neg_offset| {
        const lo12: u12 = @truncate(neg_offset >> 0);
        const hi12: u12 = @intCast(neg_offset >> 12);
        if (hi12 > 0) try isel.emit(.sub(
            ptr_ra.x(),
            if (lo12 > 0) ptr_ra.x() else base_ra.x(),
            .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
        ));
        if (lo12 > 0 or hi12 == 0) try isel.emit(.sub(ptr_ra.x(), base_ra.x(), .{ .immediate = lo12 }));
    } else {
        try isel.emit(.add(ptr_ra.x(), base_ra.x(), .{ .register = ptr_ra.x() }));
        try isel.movImmediate(ptr_ra.x(), @truncate(@as(u65, @bitCast(offset))));
    }
}

const DomInt = u8;

pub const Value = struct {
    refs: u32,
    flags: Flags,
    offset_from_parent: u64,
    parent_payload: Parent.Payload,
    location_payload: Location.Payload,
    parts: Value.Index,

    /// Must be at least 16 to compute call abi.
    /// Must be at least 16, the largest hardware alignment.
    pub const max_parts = 16;
    pub const PartsLen = std.math.IntFittingRange(0, Value.max_parts);

    comptime {
        if (!std.debug.runtime_safety) assert(@sizeOf(Value) == 32);
    }

    pub const Flags = packed struct(u32) {
        alignment: InternPool.Alignment,
        parent_tag: Parent.Tag,
        location_tag: Location.Tag,
        parts_len_minus_one: std.math.IntFittingRange(0, Value.max_parts - 1),
        unused: u18 = 0,
    };

    pub const Parent = union(enum(u3)) {
        unallocated: void,
        stack_slot: Indirect,
        address: Value.Index,
        value: Value.Index,
        constant: Constant,

        pub const Tag = @typeInfo(Parent).@"union".tag_type.?;
        pub const Payload = @Type(.{ .@"union" = .{
            .layout = .auto,
            .tag_type = null,
            .fields = @typeInfo(Parent).@"union".fields,
            .decls = &.{},
        } });
    };

    pub const Location = union(enum(u1)) {
        large: struct {
            size: u64,
        },
        small: struct {
            size: u5,
            signedness: std.builtin.Signedness,
            is_vector: bool,
            hint: Register.Alias,
            register: Register.Alias,
        },

        pub const Tag = @typeInfo(Location).@"union".tag_type.?;
        pub const Payload = @Type(.{ .@"union" = .{
            .layout = .auto,
            .tag_type = null,
            .fields = @typeInfo(Location).@"union".fields,
            .decls = &.{},
        } });
    };

    pub const Indirect = packed struct(u32) {
        base: Register.Alias,
        offset: i25,

        pub fn withOffset(ind: Indirect, offset: i25) Indirect {
            return .{
                .base = ind.base,
                .offset = ind.offset + offset,
            };
        }
    };

    pub const Index = enum(u32) {
        allocating = std.math.maxInt(u32) - 1,
        free = std.math.maxInt(u32) - 0,
        _,

        fn get(vi: Value.Index, isel: *Select) *Value {
            return &isel.values.items[@intFromEnum(vi)];
        }

        fn setAlignment(vi: Value.Index, isel: *Select, new_alignment: InternPool.Alignment) void {
            vi.get(isel).flags.alignment = new_alignment;
        }

        pub fn alignment(vi: Value.Index, isel: *Select) InternPool.Alignment {
            return vi.get(isel).flags.alignment;
        }

        pub fn setParent(vi: Value.Index, isel: *Select, new_parent: Parent) void {
            const value = vi.get(isel);
            assert(value.flags.parent_tag == .unallocated);
            value.flags.parent_tag = new_parent;
            value.parent_payload = switch (new_parent) {
                .unallocated => unreachable,
                inline else => |payload, tag| @unionInit(Parent.Payload, @tagName(tag), payload),
            };
            if (value.refs > 0) switch (new_parent) {
                .unallocated => unreachable,
                .stack_slot, .constant => {},
                .address, .value => |parent_vi| _ = parent_vi.ref(isel),
            };
        }

        pub fn changeStackSlot(vi: Value.Index, isel: *Select, new_stack_slot: Indirect) void {
            const value = vi.get(isel);
            assert(value.flags.parent_tag == .stack_slot);
            value.flags.parent_tag = .unallocated;
            vi.setParent(isel, .{ .stack_slot = new_stack_slot });
        }

        pub fn parent(vi: Value.Index, isel: *Select) Parent {
            const value = vi.get(isel);
            return switch (value.flags.parent_tag) {
                inline else => |tag| @unionInit(
                    Parent,
                    @tagName(tag),
                    @field(value.parent_payload, @tagName(tag)),
                ),
            };
        }

        pub fn valueParent(initial_vi: Value.Index, isel: *Select) struct { u64, Value.Index } {
            var offset: u64 = 0;
            var vi = initial_vi;
            parent: switch (vi.parent(isel)) {
                else => return .{ offset, vi },
                .value => |parent_vi| {
                    offset += vi.position(isel)[0];
                    vi = parent_vi;
                    continue :parent parent_vi.parent(isel);
                },
            }
        }

        pub fn location(vi: Value.Index, isel: *Select) Location {
            const value = vi.get(isel);
            return switch (value.flags.location_tag) {
                inline else => |tag| @unionInit(
                    Location,
                    @tagName(tag),
                    @field(value.location_payload, @tagName(tag)),
                ),
            };
        }

        pub fn position(vi: Value.Index, isel: *Select) struct { u64, u64 } {
            return .{ vi.get(isel).offset_from_parent, vi.size(isel) };
        }

        pub fn size(vi: Value.Index, isel: *Select) u64 {
            return switch (vi.location(isel)) {
                inline else => |loc| loc.size,
            };
        }

        fn setHint(vi: Value.Index, isel: *Select, new_hint: Register.Alias) void {
            vi.get(isel).location_payload.small.hint = new_hint;
        }

        pub fn hint(vi: Value.Index, isel: *Select) ?Register.Alias {
            return switch (vi.location(isel)) {
                .large => null,
                .small => |loc| switch (loc.hint) {
                    .zr => null,
                    else => |hint_reg| hint_reg,
                },
            };
        }

        fn setSignedness(vi: Value.Index, isel: *Select, new_signedness: std.builtin.Signedness) void {
            const value = vi.get(isel);
            assert(value.location_payload.small.size <= 2);
            value.location_payload.small.signedness = new_signedness;
        }

        pub fn signedness(vi: Value.Index, isel: *Select) std.builtin.Signedness {
            const value = vi.get(isel);
            return switch (value.flags.location_tag) {
                .large => .unsigned,
                .small => value.location_payload.small.signedness,
            };
        }

        fn setIsVector(vi: Value.Index, isel: *Select) void {
            const is_vector = &vi.get(isel).location_payload.small.is_vector;
            assert(!is_vector.*);
            is_vector.* = true;
        }

        pub fn isVector(vi: Value.Index, isel: *Select) bool {
            const value = vi.get(isel);
            return switch (value.flags.location_tag) {
                .large => false,
                .small => value.location_payload.small.is_vector,
            };
        }

        pub fn register(vi: Value.Index, isel: *Select) ?Register.Alias {
            return switch (vi.location(isel)) {
                .large => null,
                .small => |loc| switch (loc.register) {
                    .zr => null,
                    else => |reg| reg,
                },
            };
        }

        pub fn isUsed(vi: Value.Index, isel: *Select) bool {
            return vi.valueParent(isel)[1].parent(isel) != .unallocated or vi.hasRegisterRecursive(isel);
        }

        fn hasRegisterRecursive(vi: Value.Index, isel: *Select) bool {
            if (vi.register(isel)) |_| return true;
            var part_it = vi.parts(isel);
            if (part_it.only() == null) while (part_it.next()) |part_vi| if (part_vi.hasRegisterRecursive(isel)) return true;
            return false;
        }

        fn setParts(vi: Value.Index, isel: *Select, parts_len: Value.PartsLen) void {
            assert(parts_len > 1);
            const value = vi.get(isel);
            assert(value.flags.parts_len_minus_one == 0);
            value.parts = @enumFromInt(isel.values.items.len);
            value.flags.parts_len_minus_one = @intCast(parts_len - 1);
        }

        fn addPart(vi: Value.Index, isel: *Select, part_offset: u64, part_size: u64) Value.Index {
            const part_vi = isel.initValueAdvanced(vi.alignment(isel), part_offset, part_size);
            tracking_log.debug("${d} <- ${d}[{d}]", .{
                @intFromEnum(part_vi),
                @intFromEnum(vi),
                part_offset,
            });
            part_vi.setParent(isel, .{ .value = vi });
            return part_vi;
        }

        pub fn parts(vi: Value.Index, isel: *Select) Value.PartIterator {
            const value = vi.get(isel);
            return switch (value.flags.parts_len_minus_one) {
                0 => .initOne(vi),
                else => |parts_len_minus_one| .{
                    .vi = value.parts,
                    .remaining = @as(Value.PartsLen, parts_len_minus_one) + 1,
                },
            };
        }

        fn containingParts(vi: Value.Index, isel: *Select, part_offset: u64, part_size: u64) Value.PartIterator {
            const start_vi = vi.partAtOffset(isel, part_offset);
            const start_offset, const start_size = start_vi.position(isel);
            if (part_offset >= start_offset and part_size <= start_size) return .initOne(start_vi);
            const end_vi = vi.partAtOffset(isel, part_size - 1 + part_offset);
            return .{
                .vi = start_vi,
                .remaining = @intCast(@intFromEnum(end_vi) - @intFromEnum(start_vi) + 1),
            };
        }
        comptime {
            _ = containingParts;
        }

        fn partAtOffset(vi: Value.Index, isel: *Select, offset: u64) Value.Index {
            const SearchPartIndex = std.math.IntFittingRange(0, Value.max_parts * 2 - 1);
            const value = vi.get(isel);
            var last: SearchPartIndex = value.flags.parts_len_minus_one;
            if (last == 0) return vi;
            var first: SearchPartIndex = 0;
            last += 1;
            while (true) {
                const mid = (first + last) / 2;
                const mid_vi: Value.Index = @enumFromInt(@intFromEnum(value.parts) + mid);
                if (mid == first) return mid_vi;
                if (offset < mid_vi.get(isel).offset_from_parent) last = mid else first = mid;
            }
        }

        fn field(
            vi: Value.Index,
            ty: ZigType,
            field_offset: u64,
            field_size: u64,
        ) Value.FieldPartIterator {
            assert(field_size > 0);
            return .{
                .vi = vi,
                .ty = ty,
                .field_offset = field_offset,
                .field_size = field_size,
                .next_offset = 0,
            };
        }

        fn ref(initial_vi: Value.Index, isel: *Select) Value.Index {
            var vi = initial_vi;
            while (true) {
                const refs = &vi.get(isel).refs;
                refs.* += 1;
                if (refs.* > 1) return initial_vi;
                switch (vi.parent(isel)) {
                    .unallocated, .stack_slot, .constant => {},
                    .address, .value => |parent_vi| {
                        vi = parent_vi;
                        continue;
                    },
                }
                return initial_vi;
            }
        }

        pub fn deref(initial_vi: Value.Index, isel: *Select) void {
            var vi = initial_vi;
            while (true) {
                const refs = &vi.get(isel).refs;
                refs.* -= 1;
                if (refs.* > 0) return;
                switch (vi.parent(isel)) {
                    .unallocated, .constant => {},
                    .stack_slot => {
                        // reuse stack slot
                    },
                    .address, .value => |parent_vi| {
                        vi = parent_vi;
                        continue;
                    },
                }
                return;
            }
        }

        fn move(dst_vi: Value.Index, isel: *Select, src_ref: Air.Inst.Ref) !void {
            try dst_vi.copy(
                isel,
                isel.air.typeOf(src_ref, &isel.pt.zcu.intern_pool),
                try isel.use(src_ref),
            );
        }

        fn copy(dst_vi: Value.Index, isel: *Select, ty: ZigType, src_vi: Value.Index) !void {
            try dst_vi.copyAdvanced(isel, src_vi, .{
                .ty = ty,
                .dst_vi = dst_vi,
                .dst_offset = 0,
                .src_vi = src_vi,
                .src_offset = 0,
            });
        }

        fn copyAdvanced(dst_vi: Value.Index, isel: *Select, src_vi: Value.Index, root: struct {
            ty: ZigType,
            dst_vi: Value.Index,
            dst_offset: u64,
            src_vi: Value.Index,
            src_offset: u64,
        }) !void {
            if (dst_vi == src_vi) return;
            var dst_part_it = dst_vi.parts(isel);
            if (dst_part_it.only()) |dst_part_vi| {
                var src_part_it = src_vi.parts(isel);
                if (src_part_it.only()) |src_part_vi| only: {
                    const src_part_size = src_part_vi.size(isel);
                    if (src_part_size > @as(@TypeOf(src_part_size), if (src_part_vi.isVector(isel)) 16 else 8)) {
                        var subpart_it = root.src_vi.field(root.ty, root.src_offset, src_part_size - 1);
                        _ = try subpart_it.next(isel);
                        src_part_it = src_vi.parts(isel);
                        assert(src_part_it.only() == null);
                        break :only;
                    }
                    return src_part_vi.liveOut(isel, try dst_part_vi.defReg(isel) orelse return);
                }
                while (src_part_it.next()) |src_part_vi| {
                    const src_part_offset, const src_part_size = src_part_vi.position(isel);
                    var dst_field_it = root.dst_vi.field(root.ty, root.dst_offset + src_part_offset, src_part_size);
                    const dst_field_vi = try dst_field_it.only(isel);
                    try dst_field_vi.?.copyAdvanced(isel, src_part_vi, .{
                        .ty = root.ty,
                        .dst_vi = root.dst_vi,
                        .dst_offset = root.dst_offset + src_part_offset,
                        .src_vi = root.src_vi,
                        .src_offset = root.src_offset + src_part_offset,
                    });
                }
            } else while (dst_part_it.next()) |dst_part_vi| {
                const dst_part_offset, const dst_part_size = dst_part_vi.position(isel);
                var src_field_it = root.src_vi.field(root.ty, root.src_offset + dst_part_offset, dst_part_size);
                const src_part_vi = try src_field_it.only(isel);
                try dst_part_vi.copyAdvanced(isel, src_part_vi.?, .{
                    .ty = root.ty,
                    .dst_vi = root.dst_vi,
                    .dst_offset = root.dst_offset + dst_part_offset,
                    .src_vi = root.src_vi,
                    .src_offset = root.src_offset + dst_part_offset,
                });
            }
        }

        const AddOrSubtractOptions = struct {
            overflow: Overflow,

            const Overflow = union(enum) {
                @"unreachable",
                panic: Zcu.SimplePanicId,
                wrap,
                ra: Register.Alias,

                fn defCond(overflow: Overflow, isel: *Select, cond: codegen.aarch64.encoding.ConditionCode) !void {
                    switch (overflow) {
                        .@"unreachable" => unreachable,
                        .panic => |panic_id| {
                            const skip_label = isel.instructions.items.len;
                            try isel.emitPanic(panic_id);
                            try isel.emit(.@"b."(
                                cond.invert(),
                                @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                            ));
                        },
                        .wrap => {},
                        .ra => |overflow_ra| try isel.emit(.csinc(overflow_ra.w(), .wzr, .wzr, cond.invert())),
                    }
                }
            };
        };
        fn addOrSubtract(
            res_vi: Value.Index,
            isel: *Select,
            ty: ZigType,
            lhs_vi: Value.Index,
            op: codegen.aarch64.encoding.Instruction.AddSubtractOp,
            rhs_vi: Value.Index,
            opts: AddOrSubtractOptions,
        ) !void {
            const zcu = isel.pt.zcu;
            if (!ty.isAbiInt(zcu)) return isel.fail("bad {s} {f}", .{ @tagName(op), isel.fmtType(ty) });
            const int_info = ty.intInfo(zcu);
            if (int_info.bits > 128) return isel.fail("too big {s} {f}", .{ @tagName(op), isel.fmtType(ty) });
            var part_offset = res_vi.size(isel);
            var need_wrap = switch (opts.overflow) {
                .@"unreachable" => false,
                .panic, .wrap, .ra => true,
            };
            var need_carry = switch (opts.overflow) {
                .@"unreachable", .wrap => false,
                .panic, .ra => true,
            };
            while (part_offset > 0) : (need_wrap = false) {
                const part_size = @min(part_offset, 8);
                part_offset -= part_size;
                var wrapped_res_part_it = res_vi.field(ty, part_offset, part_size);
                const wrapped_res_part_vi = try wrapped_res_part_it.only(isel);
                const wrapped_res_part_ra = try wrapped_res_part_vi.?.defReg(isel) orelse if (need_carry) .zr else continue;
                const unwrapped_res_part_ra = unwrapped_res_part_ra: {
                    if (!need_wrap) break :unwrapped_res_part_ra wrapped_res_part_ra;
                    if (int_info.bits % 32 == 0) {
                        try opts.overflow.defCond(isel, switch (int_info.signedness) {
                            .signed => .vs,
                            .unsigned => switch (op) {
                                .add => .cs,
                                .sub => .cc,
                            },
                        });
                        break :unwrapped_res_part_ra wrapped_res_part_ra;
                    }
                    need_carry = false;
                    const wrapped_part_ra, const unwrapped_part_ra = part_ra: switch (opts.overflow) {
                        .@"unreachable" => unreachable,
                        .panic, .ra => switch (int_info.signedness) {
                            .signed => {
                                try opts.overflow.defCond(isel, .ne);
                                const wrapped_part_ra = switch (wrapped_res_part_ra) {
                                    else => |res_part_ra| res_part_ra,
                                    .zr => try isel.allocIntReg(),
                                };
                                errdefer if (wrapped_part_ra != wrapped_res_part_ra) isel.freeReg(wrapped_part_ra);
                                const unwrapped_part_ra = unwrapped_part_ra: {
                                    const wrapped_res_part_lock: RegLock = switch (wrapped_res_part_ra) {
                                        else => |res_part_ra| isel.lockReg(res_part_ra),
                                        .zr => .empty,
                                    };
                                    defer wrapped_res_part_lock.unlock(isel);
                                    break :unwrapped_part_ra try isel.allocIntReg();
                                };
                                errdefer isel.freeReg(unwrapped_part_ra);
                                switch (part_size) {
                                    else => unreachable,
                                    1...4 => try isel.emit(.subs(.wzr, wrapped_part_ra.w(), .{ .register = unwrapped_part_ra.w() })),
                                    5...8 => try isel.emit(.subs(.xzr, wrapped_part_ra.x(), .{ .register = unwrapped_part_ra.x() })),
                                }
                                break :part_ra .{ wrapped_part_ra, unwrapped_part_ra };
                            },
                            .unsigned => {
                                const unwrapped_part_ra = unwrapped_part_ra: {
                                    const wrapped_res_part_lock: RegLock = switch (wrapped_res_part_ra) {
                                        else => |res_part_ra| isel.lockReg(res_part_ra),
                                        .zr => .empty,
                                    };
                                    defer wrapped_res_part_lock.unlock(isel);
                                    break :unwrapped_part_ra try isel.allocIntReg();
                                };
                                errdefer isel.freeReg(unwrapped_part_ra);
                                const bit: u6 = @truncate(int_info.bits);
                                switch (opts.overflow) {
                                    .@"unreachable", .wrap => unreachable,
                                    .panic => |panic_id| {
                                        const skip_label = isel.instructions.items.len;
                                        try isel.emitPanic(panic_id);
                                        try isel.emit(.tbz(
                                            switch (bit) {
                                                0, 32 => unreachable,
                                                1...31 => unwrapped_part_ra.w(),
                                                33...63 => unwrapped_part_ra.x(),
                                            },
                                            bit,
                                            @intCast((isel.instructions.items.len + 1 - skip_label) << 2),
                                        ));
                                    },
                                    .ra => |overflow_ra| try isel.emit(switch (bit) {
                                        0, 32 => unreachable,
                                        1...31 => .ubfm(overflow_ra.w(), unwrapped_part_ra.w(), .{
                                            .N = .word,
                                            .immr = bit,
                                            .imms = bit,
                                        }),
                                        33...63 => .ubfm(overflow_ra.x(), unwrapped_part_ra.x(), .{
                                            .N = .doubleword,
                                            .immr = bit,
                                            .imms = bit,
                                        }),
                                    }),
                                }
                                break :part_ra .{ wrapped_res_part_ra, unwrapped_part_ra };
                            },
                        },
                        .wrap => .{ wrapped_res_part_ra, wrapped_res_part_ra },
                    };
                    defer if (wrapped_part_ra != wrapped_res_part_ra) isel.freeReg(wrapped_part_ra);
                    errdefer if (unwrapped_part_ra != wrapped_res_part_ra) isel.freeReg(unwrapped_part_ra);
                    if (wrapped_part_ra != .zr) try isel.emit(switch (part_size) {
                        else => unreachable,
                        1...4 => switch (int_info.signedness) {
                            .signed => .sbfm(wrapped_part_ra.w(), unwrapped_part_ra.w(), .{
                                .N = .word,
                                .immr = 0,
                                .imms = @truncate(int_info.bits - 1),
                            }),
                            .unsigned => .ubfm(wrapped_part_ra.w(), unwrapped_part_ra.w(), .{
                                .N = .word,
                                .immr = 0,
                                .imms = @truncate(int_info.bits - 1),
                            }),
                        },
                        5...8 => switch (int_info.signedness) {
                            .signed => .sbfm(wrapped_part_ra.x(), unwrapped_part_ra.x(), .{
                                .N = .doubleword,
                                .immr = 0,
                                .imms = @truncate(int_info.bits - 1),
                            }),
                            .unsigned => .ubfm(wrapped_part_ra.x(), unwrapped_part_ra.x(), .{
                                .N = .doubleword,
                                .immr = 0,
                                .imms = @truncate(int_info.bits - 1),
                            }),
                        },
                    });
                    break :unwrapped_res_part_ra unwrapped_part_ra;
                };
                defer if (unwrapped_res_part_ra != wrapped_res_part_ra) isel.freeReg(unwrapped_res_part_ra);
                var lhs_part_it = lhs_vi.field(ty, part_offset, part_size);
                const lhs_part_vi = try lhs_part_it.only(isel);
                const lhs_part_mat = try lhs_part_vi.?.matReg(isel);
                var rhs_part_it = rhs_vi.field(ty, part_offset, part_size);
                const rhs_part_vi = try rhs_part_it.only(isel);
                const rhs_part_mat = try rhs_part_vi.?.matReg(isel);
                try isel.emit(switch (part_size) {
                    else => unreachable,
                    1...4 => switch (op) {
                        .add => switch (part_offset) {
                            0 => switch (need_carry) {
                                false => .add(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                                true => .adds(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                            },
                            else => switch (need_carry) {
                                false => .adc(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), rhs_part_mat.ra.w()),
                                true => .adcs(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), rhs_part_mat.ra.w()),
                            },
                        },
                        .sub => switch (part_offset) {
                            0 => switch (need_carry) {
                                false => .sub(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                                true => .subs(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), .{ .register = rhs_part_mat.ra.w() }),
                            },
                            else => switch (need_carry) {
                                false => .sbc(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), rhs_part_mat.ra.w()),
                                true => .sbcs(unwrapped_res_part_ra.w(), lhs_part_mat.ra.w(), rhs_part_mat.ra.w()),
                            },
                        },
                    },
                    5...8 => switch (op) {
                        .add => switch (part_offset) {
                            0 => switch (need_carry) {
                                false => .add(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                                true => .adds(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                            },
                            else => switch (need_carry) {
                                false => .adc(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), rhs_part_mat.ra.x()),
                                true => .adcs(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), rhs_part_mat.ra.x()),
                            },
                        },
                        .sub => switch (part_offset) {
                            0 => switch (need_carry) {
                                false => .sub(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                                true => .subs(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), .{ .register = rhs_part_mat.ra.x() }),
                            },
                            else => switch (need_carry) {
                                false => .sbc(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), rhs_part_mat.ra.x()),
                                true => .sbcs(unwrapped_res_part_ra.x(), lhs_part_mat.ra.x(), rhs_part_mat.ra.x()),
                            },
                        },
                    },
                });
                try rhs_part_mat.finish(isel);
                try lhs_part_mat.finish(isel);
                need_carry = true;
            }
        }

        const MemoryAccessOptions = struct {
            root_vi: Value.Index = .free,
            offset: u64 = 0,
            @"volatile": bool = false,
            split: bool = true,
            wrap: ?std.builtin.Type.Int = null,
            expected_live_registers: *const LiveRegisters = &.initFill(.free),
        };

        fn load(
            vi: Value.Index,
            isel: *Select,
            root_ty: ZigType,
            base_ra: Register.Alias,
            opts: MemoryAccessOptions,
        ) !bool {
            const root_vi = switch (opts.root_vi) {
                _ => |root_vi| root_vi,
                .allocating => unreachable,
                .free => vi,
            };
            var part_it = vi.parts(isel);
            if (part_it.only()) |part_vi| only: {
                const part_size = part_vi.size(isel);
                const part_is_vector = part_vi.isVector(isel);
                if (part_size > @as(@TypeOf(part_size), if (part_is_vector) 16 else 8)) {
                    if (!opts.split) return false;
                    var subpart_it = root_vi.field(root_ty, opts.offset, part_size - 1);
                    _ = try subpart_it.next(isel);
                    part_it = vi.parts(isel);
                    assert(part_it.only() == null);
                    break :only;
                }
                const part_ra = if (try part_vi.defReg(isel)) |part_ra|
                    part_ra
                else if (opts.@"volatile")
                    .zr
                else
                    return false;
                if (part_ra != .zr) {
                    const live_vi = isel.live_registers.getPtr(part_ra);
                    assert(live_vi.* == .free);
                    live_vi.* = .allocating;
                }
                if (opts.wrap) |int_info| switch (int_info.bits) {
                    else => unreachable,
                    1...7, 9...15, 17...31 => |bits| try isel.emit(switch (int_info.signedness) {
                        .signed => .sbfm(part_ra.w(), part_ra.w(), .{
                            .N = .word,
                            .immr = 0,
                            .imms = @intCast(bits - 1),
                        }),
                        .unsigned => .ubfm(part_ra.w(), part_ra.w(), .{
                            .N = .word,
                            .immr = 0,
                            .imms = @intCast(bits - 1),
                        }),
                    }),
                    8, 16, 32 => {},
                    33...63 => |bits| try isel.emit(switch (int_info.signedness) {
                        .signed => .sbfm(part_ra.x(), part_ra.x(), .{
                            .N = .doubleword,
                            .immr = 0,
                            .imms = @intCast(bits - 1),
                        }),
                        .unsigned => .ubfm(part_ra.x(), part_ra.x(), .{
                            .N = .doubleword,
                            .immr = 0,
                            .imms = @intCast(bits - 1),
                        }),
                    }),
                    64 => {},
                };
                try isel.loadReg(part_ra, part_size, part_vi.signedness(isel), base_ra, opts.offset);
                if (part_ra != .zr) {
                    const live_vi = isel.live_registers.getPtr(part_ra);
                    assert(live_vi.* == .allocating);
                    switch (opts.expected_live_registers.get(part_ra)) {
                        _ => {},
                        .allocating => unreachable,
                        .free => live_vi.* = .free,
                    }
                }
                return true;
            }
            var used = false;
            while (part_it.next()) |part_vi| used |= try part_vi.load(isel, root_ty, base_ra, .{
                .root_vi = root_vi,
                .offset = opts.offset + part_vi.get(isel).offset_from_parent,
                .@"volatile" = opts.@"volatile",
                .split = opts.split,
                .wrap = switch (part_it.remaining) {
                    else => null,
                    0 => if (opts.wrap) |wrap| .{
                        .signedness = wrap.signedness,
                        .bits = @intCast(wrap.bits - 8 * part_vi.position(isel)[0]),
                    } else null,
                },
                .expected_live_registers = opts.expected_live_registers,
            });
            return used;
        }

        fn store(
            vi: Value.Index,
            isel: *Select,
            root_ty: ZigType,
            base_ra: Register.Alias,
            opts: MemoryAccessOptions,
        ) !void {
            const root_vi = switch (opts.root_vi) {
                _ => |root_vi| root_vi,
                .allocating => unreachable,
                .free => vi,
            };
            var part_it = vi.parts(isel);
            if (part_it.only()) |part_vi| only: {
                const part_size = part_vi.size(isel);
                const part_is_vector = part_vi.isVector(isel);
                if (part_size > @as(@TypeOf(part_size), if (part_is_vector) 16 else 8)) {
                    if (!opts.split) return;
                    var subpart_it = root_vi.field(root_ty, opts.offset, part_size - 1);
                    _ = try subpart_it.next(isel);
                    part_it = vi.parts(isel);
                    assert(part_it.only() == null);
                    break :only;
                }
                const part_mat = try part_vi.matReg(isel);
                try isel.storeReg(part_mat.ra, part_size, base_ra, opts.offset);
                return part_mat.finish(isel);
            }
            while (part_it.next()) |part_vi| try part_vi.store(isel, root_ty, base_ra, .{
                .root_vi = root_vi,
                .offset = opts.offset + part_vi.get(isel).offset_from_parent,
                .@"volatile" = opts.@"volatile",
                .split = opts.split,
                .wrap = switch (part_it.remaining) {
                    else => null,
                    0 => if (opts.wrap) |wrap| .{
                        .signedness = wrap.signedness,
                        .bits = @intCast(wrap.bits - 8 * part_vi.position(isel)[0]),
                    } else null,
                },
                .expected_live_registers = opts.expected_live_registers,
            });
        }

        fn mat(vi: Value.Index, isel: *Select) !void {
            if (false) {
                var part_it: Value.PartIterator = if (vi.size(isel) > 8) vi.parts(isel) else .initOne(vi);
                if (part_it.only()) |part_vi| only: {
                    const mat_ra = mat_ra: {
                        if (part_vi.register(isel)) |mat_ra| {
                            part_vi.get(isel).location_payload.small.register = .zr;
                            const live_vi = isel.live_registers.getPtr(mat_ra);
                            assert(live_vi.* == part_vi);
                            live_vi.* = .allocating;
                            break :mat_ra mat_ra;
                        }
                        if (part_vi.hint(isel)) |hint_ra| {
                            const live_vi = isel.live_registers.getPtr(hint_ra);
                            if (live_vi.* == .free) {
                                live_vi.* = .allocating;
                                isel.saved_registers.insert(hint_ra);
                                break :mat_ra hint_ra;
                            }
                        }
                        const part_size = part_vi.size(isel);
                        const part_is_vector = part_vi.isVector(isel);
                        if (part_size <= @as(@TypeOf(part_size), if (part_is_vector) 16 else 8))
                            switch (if (part_is_vector) isel.tryAllocVecReg() else isel.tryAllocIntReg()) {
                                .allocated => |ra| break :mat_ra ra,
                                .fill_candidate, .out_of_registers => {},
                            };
                        _, const parent_vi = vi.valueParent(isel);
                        switch (parent_vi.parent(isel)) {
                            .unallocated => parent_vi.setParent(isel, .{ .stack_slot = parent_vi.allocStackSlot(isel) }),
                            else => {},
                        }
                        break :only;
                    };
                    assert(isel.live_registers.get(mat_ra) == .allocating);
                    try Value.Materialize.finish(.{ .vi = part_vi, .ra = mat_ra }, isel);
                } else while (part_it.next()) |part_vi| try part_vi.mat(isel);
            } else {
                _, const parent_vi = vi.valueParent(isel);
                switch (parent_vi.parent(isel)) {
                    .unallocated => parent_vi.setParent(isel, .{ .stack_slot = parent_vi.allocStackSlot(isel) }),
                    else => {},
                }
            }
        }

        fn matReg(vi: Value.Index, isel: *Select) !Value.Materialize {
            const mat_ra = mat_ra: {
                if (vi.register(isel)) |mat_ra| {
                    vi.get(isel).location_payload.small.register = .zr;
                    const live_vi = isel.live_registers.getPtr(mat_ra);
                    assert(live_vi.* == vi);
                    live_vi.* = .allocating;
                    break :mat_ra mat_ra;
                }
                if (vi.hint(isel)) |hint_ra| {
                    const live_vi = isel.live_registers.getPtr(hint_ra);
                    if (live_vi.* == .free) {
                        live_vi.* = .allocating;
                        isel.saved_registers.insert(hint_ra);
                        break :mat_ra hint_ra;
                    }
                }
                break :mat_ra if (vi.isVector(isel)) try isel.allocVecReg() else try isel.allocIntReg();
            };
            assert(isel.live_registers.get(mat_ra) == .allocating);
            return .{ .vi = vi, .ra = mat_ra };
        }

        fn defAddr(
            def_vi: Value.Index,
            isel: *Select,
            root_ty: ZigType,
            opts: struct {
                root_vi: Value.Index = .free,
                wrap: ?std.builtin.Type.Int = null,
                expected_live_registers: *const LiveRegisters = &.initFill(.free),
            },
        ) !?void {
            if (!def_vi.isUsed(isel)) return null;
            const offset_from_parent: i65, const parent_vi = def_vi.valueParent(isel);
            const stack_slot, const allocated = switch (parent_vi.parent(isel)) {
                .unallocated => .{ parent_vi.allocStackSlot(isel), true },
                .stack_slot => |stack_slot| .{ stack_slot, false },
                else => unreachable,
            };
            _ = try def_vi.load(isel, root_ty, stack_slot.base, .{
                .root_vi = opts.root_vi,
                .offset = @intCast(stack_slot.offset + offset_from_parent),
                .split = false,
                .wrap = opts.wrap,
                .expected_live_registers = opts.expected_live_registers,
            });
            if (allocated) parent_vi.setParent(isel, .{ .stack_slot = stack_slot });
        }

        fn defReg(def_vi: Value.Index, isel: *Select) !?Register.Alias {
            var vi = def_vi;
            var offset: i65 = 0;
            var def_ra: ?Register.Alias = null;
            while (true) {
                if (vi.register(isel)) |ra| {
                    vi.get(isel).location_payload.small.register = .zr;
                    const live_vi = isel.live_registers.getPtr(ra);
                    assert(live_vi.* == vi);
                    if (def_ra == null and vi != def_vi) {
                        var part_it = vi.parts(isel);
                        assert(part_it.only() == null);

                        const first_part_vi = part_it.next().?;
                        const first_part_value = first_part_vi.get(isel);
                        assert(first_part_value.offset_from_parent == 0);
                        first_part_value.location_payload.small.register = ra;
                        live_vi.* = first_part_vi;

                        const vi_size = vi.size(isel);
                        while (part_it.next()) |part_vi| {
                            const part_offset, const part_size = part_vi.position(isel);
                            const part_mat = try part_vi.matReg(isel);
                            try isel.emit(if (part_vi.isVector(isel)) emit: {
                                assert(part_offset == 0 and part_size == vi_size);
                                break :emit switch (vi_size) {
                                    else => unreachable,
                                    2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                                        .fmov(ra.h(), .{ .register = part_mat.ra.h() })
                                    else
                                        .dup(ra.h(), part_mat.ra.@"h[]"(0)),
                                    4 => .fmov(ra.s(), .{ .register = part_mat.ra.s() }),
                                    8 => .fmov(ra.d(), .{ .register = part_mat.ra.d() }),
                                    16 => .orr(ra.@"16b"(), part_mat.ra.@"16b"(), .{ .register = part_mat.ra.@"16b"() }),
                                };
                            } else switch (vi_size) {
                                else => unreachable,
                                1...4 => .bfm(ra.w(), part_mat.ra.w(), .{
                                    .N = .word,
                                    .immr = @as(u5, @truncate(32 - 8 * part_offset)),
                                    .imms = @intCast(8 * part_size - 1),
                                }),
                                5...8 => .bfm(ra.x(), part_mat.ra.x(), .{
                                    .N = .doubleword,
                                    .immr = @as(u6, @truncate(64 - 8 * part_offset)),
                                    .imms = @intCast(8 * part_size - 1),
                                }),
                            });
                            try part_mat.finish(isel);
                        }
                        vi = def_vi;
                        offset = 0;
                        continue;
                    }
                    live_vi.* = .free;
                    def_ra = ra;
                }
                offset += vi.get(isel).offset_from_parent;
                switch (vi.parent(isel)) {
                    else => unreachable,
                    .unallocated => return def_ra,
                    .stack_slot => |stack_slot| {
                        offset += stack_slot.offset;
                        const def_is_vector = def_vi.isVector(isel);
                        const ra = def_ra orelse if (def_is_vector) try isel.allocVecReg() else try isel.allocIntReg();
                        defer if (def_ra == null) isel.freeReg(ra);
                        try isel.storeReg(ra, def_vi.size(isel), stack_slot.base, offset);
                        return ra;
                    },
                    .value => |parent_vi| vi = parent_vi,
                }
            }
        }

        pub fn defUndef(def_vi: Value.Index, isel: *Select, root_ty: ZigType, opts: struct {
            root_vi: Value.Index = .free,
            offset: u64 = 0,
            split: bool = true,
        }) !void {
            const root_vi = switch (opts.root_vi) {
                _ => |root_vi| root_vi,
                .allocating => unreachable,
                .free => def_vi,
            };
            var part_it = def_vi.parts(isel);
            if (part_it.only()) |part_vi| only: {
                const part_size = part_vi.size(isel);
                const part_is_vector = part_vi.isVector(isel);
                if (part_size > @as(@TypeOf(part_size), if (part_is_vector) 16 else 8)) {
                    if (!opts.split) return;
                    var subpart_it = root_vi.field(root_ty, opts.offset, part_size - 1);
                    _ = try subpart_it.next(isel);
                    part_it = def_vi.parts(isel);
                    assert(part_it.only() == null);
                    break :only;
                }
                return if (try part_vi.defReg(isel)) |part_ra| try isel.emit(if (part_is_vector)
                    .movi(switch (part_size) {
                        else => unreachable,
                        1...8 => part_ra.@"8b"(),
                        9...16 => part_ra.@"16b"(),
                    }, 0xaa, .{ .lsl = 0 })
                else switch (part_size) {
                    else => unreachable,
                    1...4 => .orr(part_ra.w(), .wzr, .{ .immediate = .{
                        .N = .word,
                        .immr = 0b000001,
                        .imms = 0b111100,
                    } }),
                    5...8 => .orr(part_ra.x(), .xzr, .{ .immediate = .{
                        .N = .word,
                        .immr = 0b000001,
                        .imms = 0b111100,
                    } }),
                });
            }
            while (part_it.next()) |part_vi| try part_vi.defUndef(isel, root_ty, .{
                .root_vi = root_vi,
            });
        }

        pub fn liveIn(
            vi: Value.Index,
            isel: *Select,
            src_ra: Register.Alias,
            expected_live_registers: *const LiveRegisters,
        ) !void {
            const src_live_vi = isel.live_registers.getPtr(src_ra);
            if (vi.register(isel)) |dst_ra| {
                const dst_live_vi = isel.live_registers.getPtr(dst_ra);
                assert(dst_live_vi.* == vi);
                if (dst_ra == src_ra) {
                    src_live_vi.* = .allocating;
                    return;
                }
                dst_live_vi.* = .allocating;
                if (try isel.fill(src_ra)) {
                    assert(src_live_vi.* == .free);
                    src_live_vi.* = .allocating;
                }
                assert(src_live_vi.* == .allocating);
                try isel.emit(switch (dst_ra.isVector()) {
                    false => switch (src_ra.isVector()) {
                        false => switch (vi.size(isel)) {
                            else => unreachable,
                            1...4 => .orr(dst_ra.w(), .wzr, .{ .register = src_ra.w() }),
                            5...8 => .orr(dst_ra.x(), .xzr, .{ .register = src_ra.x() }),
                        },
                        true => switch (vi.size(isel)) {
                            else => unreachable,
                            2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                                .fmov(dst_ra.w(), .{ .register = src_ra.h() })
                            else
                                .umov(dst_ra.w(), src_ra.@"h[]"(0)),
                            4 => .fmov(dst_ra.w(), .{ .register = src_ra.s() }),
                            8 => .fmov(dst_ra.x(), .{ .register = src_ra.d() }),
                        },
                    },
                    true => switch (src_ra.isVector()) {
                        false => size: switch (vi.size(isel)) {
                            else => unreachable,
                            2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                                .fmov(dst_ra.h(), .{ .register = src_ra.w() })
                            else
                                continue :size 4,
                            4 => .fmov(dst_ra.s(), .{ .register = src_ra.w() }),
                            8 => .fmov(dst_ra.d(), .{ .register = src_ra.x() }),
                        },
                        true => switch (vi.size(isel)) {
                            else => unreachable,
                            2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                                .fmov(dst_ra.h(), .{ .register = src_ra.h() })
                            else
                                .dup(dst_ra.h(), src_ra.@"h[]"(0)),
                            4 => .fmov(dst_ra.s(), .{ .register = src_ra.s() }),
                            8 => .fmov(dst_ra.d(), .{ .register = src_ra.d() }),
                            16 => .orr(dst_ra.@"16b"(), src_ra.@"16b"(), .{ .register = src_ra.@"16b"() }),
                        },
                    },
                });
                assert(dst_live_vi.* == .allocating);
                dst_live_vi.* = switch (expected_live_registers.get(dst_ra)) {
                    _ => .allocating,
                    .allocating => .allocating,
                    .free => .free,
                };
            } else if (try isel.fill(src_ra)) {
                assert(src_live_vi.* == .free);
                src_live_vi.* = .allocating;
            }
            assert(src_live_vi.* == .allocating);
            vi.get(isel).location_payload.small.register = src_ra;
        }

        pub fn defLiveIn(
            vi: Value.Index,
            isel: *Select,
            src_ra: Register.Alias,
            expected_live_registers: *const LiveRegisters,
        ) !void {
            try vi.liveIn(isel, src_ra, expected_live_registers);
            const offset_from_parent, const parent_vi = vi.valueParent(isel);
            switch (parent_vi.parent(isel)) {
                .unallocated => {},
                .stack_slot => |stack_slot| if (stack_slot.base != Register.Alias.fp) try isel.storeReg(
                    src_ra,
                    vi.size(isel),
                    stack_slot.base,
                    @as(i65, stack_slot.offset) + offset_from_parent,
                ),
                else => unreachable,
            }
            try vi.spillReg(isel, src_ra, 0, expected_live_registers);
        }

        fn spillReg(
            vi: Value.Index,
            isel: *Select,
            src_ra: Register.Alias,
            start_offset: u64,
            expected_live_registers: *const LiveRegisters,
        ) !void {
            assert(isel.live_registers.get(src_ra) == .allocating);
            var part_it = vi.parts(isel);
            if (part_it.only()) |part_vi| {
                const dst_ra = part_vi.register(isel) orelse return;
                if (dst_ra == src_ra) return;
                const part_size = part_vi.size(isel);
                const part_ra = if (part_vi.isVector(isel)) try isel.allocIntReg() else dst_ra;
                defer if (part_ra != dst_ra) isel.freeReg(part_ra);
                if (part_ra != dst_ra) try isel.emit(part_size: switch (part_size) {
                    else => unreachable,
                    2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                        .fmov(dst_ra.h(), .{ .register = part_ra.w() })
                    else
                        continue :part_size 4,
                    4 => .fmov(dst_ra.s(), .{ .register = part_ra.w() }),
                    8 => .fmov(dst_ra.d(), .{ .register = part_ra.x() }),
                });
                try isel.emit(switch (start_offset + part_size) {
                    else => unreachable,
                    1...4 => |end_offset| switch (part_vi.signedness(isel)) {
                        .signed => .sbfm(part_ra.w(), src_ra.w(), .{
                            .N = .word,
                            .immr = @intCast(8 * start_offset),
                            .imms = @intCast(8 * end_offset - 1),
                        }),
                        .unsigned => .ubfm(part_ra.w(), src_ra.w(), .{
                            .N = .word,
                            .immr = @intCast(8 * start_offset),
                            .imms = @intCast(8 * end_offset - 1),
                        }),
                    },
                    5...8 => |end_offset| switch (part_vi.signedness(isel)) {
                        .signed => .sbfm(part_ra.x(), src_ra.x(), .{
                            .N = .doubleword,
                            .immr = @intCast(8 * start_offset),
                            .imms = @intCast(8 * end_offset - 1),
                        }),
                        .unsigned => .ubfm(part_ra.x(), src_ra.x(), .{
                            .N = .doubleword,
                            .immr = @intCast(8 * start_offset),
                            .imms = @intCast(8 * end_offset - 1),
                        }),
                    },
                });
                const value_ra = &part_vi.get(isel).location_payload.small.register;
                assert(value_ra.* == dst_ra);
                value_ra.* = .zr;
                const dst_live_vi = isel.live_registers.getPtr(dst_ra);
                assert(dst_live_vi.* == part_vi);
                dst_live_vi.* = switch (expected_live_registers.get(dst_ra)) {
                    _ => .allocating,
                    .allocating => unreachable,
                    .free => .free,
                };
            } else while (part_it.next()) |part_vi| try part_vi.spillReg(
                isel,
                src_ra,
                start_offset + part_vi.get(isel).offset_from_parent,
                expected_live_registers,
            );
        }

        fn liveOut(vi: Value.Index, isel: *Select, ra: Register.Alias) !void {
            assert(try isel.fill(ra));
            const live_vi = isel.live_registers.getPtr(ra);
            assert(live_vi.* == .free);
            live_vi.* = .allocating;
            try Value.Materialize.finish(.{ .vi = vi, .ra = ra }, isel);
        }

        fn allocStackSlot(vi: Value.Index, isel: *Select) Value.Indirect {
            const offset = vi.alignment(isel).forward(isel.stack_size);
            isel.stack_size = @intCast(offset + vi.size(isel));
            tracking_log.debug("${d} -> [sp, #0x{x}]", .{ @intFromEnum(vi), @abs(offset) });
            return .{
                .base = .sp,
                .offset = @intCast(offset),
            };
        }

        fn address(initial_vi: Value.Index, isel: *Select, initial_offset: u64, ptr_ra: Register.Alias) !void {
            var vi = initial_vi;
            var offset: i65 = vi.get(isel).offset_from_parent + initial_offset;
            parent: switch (vi.parent(isel)) {
                .unallocated => {
                    const stack_slot = vi.allocStackSlot(isel);
                    vi.setParent(isel, .{ .stack_slot = stack_slot });
                    continue :parent .{ .stack_slot = stack_slot };
                },
                .stack_slot => |stack_slot| {
                    offset += stack_slot.offset;
                    const lo12: u12 = @truncate(@abs(offset) >> 0);
                    const hi12: u12 = @intCast(@abs(offset) >> 12);
                    if (hi12 > 0) try isel.emit(if (offset >= 0) .add(
                        ptr_ra.x(),
                        if (lo12 > 0) ptr_ra.x() else stack_slot.base.x(),
                        .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                    ) else .sub(
                        ptr_ra.x(),
                        if (lo12 > 0) ptr_ra.x() else stack_slot.base.x(),
                        .{ .shifted_immediate = .{ .immediate = hi12, .lsl = .@"12" } },
                    ));
                    if (lo12 > 0 or hi12 == 0) try isel.emit(if (offset >= 0) .add(
                        ptr_ra.x(),
                        stack_slot.base.x(),
                        .{ .immediate = lo12 },
                    ) else .sub(
                        ptr_ra.x(),
                        stack_slot.base.x(),
                        .{ .immediate = lo12 },
                    ));
                },
                .address => |address_vi| try address_vi.liveOut(isel, ptr_ra),
                .value => |parent_vi| {
                    vi = parent_vi;
                    offset += vi.get(isel).offset_from_parent;
                    continue :parent vi.parent(isel);
                },
                .constant => |constant| {
                    const pt = isel.pt;
                    const zcu = pt.zcu;
                    switch (true) {
                        false => {
                            try isel.uav_relocs.append(zcu.gpa, .{
                                .uav = .{
                                    .val = constant.toIntern(),
                                    .orig_ty = (try pt.singleConstPtrType(constant.typeOf(zcu))).toIntern(),
                                },
                                .reloc = .{
                                    .label = @intCast(isel.instructions.items.len),
                                    .addend = @intCast(offset),
                                },
                            });
                            try isel.emit(.adr(ptr_ra.x(), 0));
                        },
                        true => {
                            try isel.uav_relocs.append(zcu.gpa, .{
                                .uav = .{
                                    .val = constant.toIntern(),
                                    .orig_ty = (try pt.singleConstPtrType(constant.typeOf(zcu))).toIntern(),
                                },
                                .reloc = .{
                                    .label = @intCast(isel.instructions.items.len),
                                    .addend = @intCast(offset),
                                },
                            });
                            try isel.emit(.add(ptr_ra.x(), ptr_ra.x(), .{ .immediate = 0 }));
                            try isel.uav_relocs.append(zcu.gpa, .{
                                .uav = .{
                                    .val = constant.toIntern(),
                                    .orig_ty = (try pt.singleConstPtrType(constant.typeOf(zcu))).toIntern(),
                                },
                                .reloc = .{
                                    .label = @intCast(isel.instructions.items.len),
                                    .addend = @intCast(offset),
                                },
                            });
                            try isel.emit(.adrp(ptr_ra.x(), 0));
                        },
                    }
                },
            }
        }
    };

    pub const PartIterator = struct {
        vi: Value.Index,
        remaining: Value.PartsLen,

        fn initOne(vi: Value.Index) PartIterator {
            return .{ .vi = vi, .remaining = 1 };
        }

        pub fn next(it: *PartIterator) ?Value.Index {
            if (it.remaining == 0) return null;
            it.remaining -= 1;
            defer it.vi = @enumFromInt(@intFromEnum(it.vi) + 1);
            return it.vi;
        }

        pub fn peek(it: PartIterator) ?Value.Index {
            var it_mut = it;
            return it_mut.next();
        }

        pub fn only(it: PartIterator) ?Value.Index {
            return if (it.remaining == 1) it.vi else null;
        }
    };

    const FieldPartIterator = struct {
        vi: Value.Index,
        ty: ZigType,
        field_offset: u64,
        field_size: u64,
        next_offset: u64,

        fn next(it: *FieldPartIterator, isel: *Select) !?struct { offset: u64, vi: Value.Index } {
            const next_offset = it.next_offset;
            const next_part_size = it.field_size - next_offset;
            if (next_part_size == 0) return null;
            var next_part_offset = it.field_offset + next_offset;

            const zcu = isel.pt.zcu;
            const ip = &zcu.intern_pool;
            var vi = it.vi;
            var ty = it.ty;
            var ty_size = vi.size(isel);
            assert(ty_size == ty.abiSize(zcu));
            var offset: u64 = 0;
            var size = ty_size;
            assert(next_part_offset + next_part_size <= size);
            while (next_part_offset > 0 or next_part_size < size) {
                const part_vi = vi.partAtOffset(isel, next_part_offset);
                if (part_vi != vi) {
                    vi = part_vi;
                    const part_offset, size = part_vi.position(isel);
                    assert(part_offset <= next_part_offset and part_offset + size > next_part_offset);
                    offset += part_offset;
                    next_part_offset -= part_offset;
                    continue;
                }
                try isel.values.ensureUnusedCapacity(zcu.gpa, Value.max_parts);
                type_key: switch (ip.indexToKey(ty.toIntern())) {
                    else => return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)}),
                    .int_type => |int_type| switch (int_type.bits) {
                        0 => unreachable,
                        1...64 => unreachable,
                        65...256 => |bits| if (offset == 0 and size == ty_size) {
                            const parts_len = std.math.divCeil(u16, bits, 64) catch unreachable;
                            vi.setParts(isel, @intCast(parts_len));
                            for (0..parts_len) |part_index| _ = vi.addPart(isel, 8 * part_index, 8);
                        },
                        else => return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)}),
                    },
                    .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                        .one, .many, .c => unreachable,
                        .slice => if (offset == 0 and size == ty_size) {
                            vi.setParts(isel, 2);
                            _ = vi.addPart(isel, 0, 8);
                            _ = vi.addPart(isel, 8, 8);
                        } else unreachable,
                    },
                    .opt_type => |child_type| if (ty.optionalReprIsPayload(zcu)) continue :type_key ip.indexToKey(child_type) else {
                        const child_ty: ZigType = .fromInterned(child_type);
                        const child_size = child_ty.abiSize(zcu);
                        if (offset == 0 and size == child_size) {
                            ty = child_ty;
                            ty_size = child_size;
                            continue :type_key ip.indexToKey(child_type);
                        }
                        switch (child_size) {
                            0...8, 16 => if (offset == 0 and size == ty_size) {
                                vi.setParts(isel, 2);
                                _ = vi.addPart(isel, 0, child_size);
                                _ = vi.addPart(isel, child_size, 1);
                            } else unreachable,
                            9...15 => if (offset == 0 and size == ty_size) {
                                vi.setParts(isel, 2);
                                _ = vi.addPart(isel, 0, 8);
                                _ = vi.addPart(isel, 8, ty_size - 8);
                            } else if (offset == 8 and size == ty_size - 8) {
                                vi.setParts(isel, 2);
                                _ = vi.addPart(isel, 0, child_size - 8);
                                _ = vi.addPart(isel, child_size - 8, 1);
                            } else unreachable,
                            else => return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)}),
                        }
                    },
                    .array_type => |array_type| {
                        const min_part_log2_stride: u5 = if (size > 16) 4 else if (size > 8) 3 else 0;
                        const array_len = array_type.lenIncludingSentinel();
                        if (array_len > Value.max_parts and
                            (std.math.divCeil(u64, size, @as(u64, 1) << min_part_log2_stride) catch unreachable) > Value.max_parts)
                            return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)});
                        const alignment = vi.alignment(isel);
                        const Part = struct { offset: u64, size: u64 };
                        var parts: [Value.max_parts]Part = undefined;
                        var parts_len: Value.PartsLen = 0;
                        const elem_ty: ZigType = .fromInterned(array_type.child);
                        const elem_size = elem_ty.abiSize(zcu);
                        const elem_signedness = if (ty.isAbiInt(zcu)) elem_signedness: {
                            const elem_int_info = elem_ty.intInfo(zcu);
                            break :elem_signedness if (elem_int_info.bits <= 16) elem_int_info.signedness else null;
                        } else null;
                        const elem_is_vector = elem_size <= 16 and
                            CallAbiIterator.homogeneousAggregateBaseType(zcu, elem_ty.toIntern()) != null;
                        var elem_end: u64 = 0;
                        for (0..@intCast(array_len)) |_| {
                            const elem_begin = elem_end;
                            if (elem_begin >= offset + size) break;
                            elem_end = elem_begin + elem_size;
                            if (elem_end <= offset) continue;
                            if (offset >= elem_begin and offset + size <= elem_begin + elem_size) {
                                ty = elem_ty;
                                ty_size = elem_size;
                                offset -= elem_begin;
                                continue :type_key ip.indexToKey(elem_ty.toIntern());
                            }
                            if (parts_len > 0) combine: {
                                const prev_part = &parts[parts_len - 1];
                                const combined_size = elem_end - prev_part.offset;
                                if (combined_size > @as(u64, 1) << @min(
                                    min_part_log2_stride,
                                    alignment.toLog2Units(),
                                    @ctz(prev_part.offset),
                                )) break :combine;
                                prev_part.size = combined_size;
                                continue;
                            }
                            parts[parts_len] = .{ .offset = elem_begin, .size = elem_size };
                            parts_len += 1;
                        }
                        vi.setParts(isel, parts_len);
                        for (parts[0..parts_len]) |part| {
                            const subpart_vi = vi.addPart(isel, part.offset - offset, part.size);
                            if (elem_signedness) |signedness| subpart_vi.setSignedness(isel, signedness);
                            if (elem_is_vector) subpart_vi.setIsVector(isel);
                        }
                    },
                    .anyframe_type => unreachable,
                    .error_union_type => |error_union_type| {
                        const min_part_log2_stride: u5 = if (size > 16) 4 else if (size > 8) 3 else 0;
                        if ((std.math.divCeil(u64, size, @as(u64, 1) << min_part_log2_stride) catch unreachable) > Value.max_parts)
                            return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)});
                        const alignment = vi.alignment(isel);
                        const payload_ty: ZigType = .fromInterned(error_union_type.payload_type);
                        const error_set_offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                        const payload_offset = codegen.errUnionPayloadOffset(payload_ty, zcu);
                        const Part = struct { offset: u64, size: u64, signedness: ?std.builtin.Signedness, is_vector: bool };
                        var parts: [2]Part = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var field_end: u64 = 0;
                        for (0..2) |field_index| {
                            const field_ty: ZigType, const field_begin = switch (@as(enum { error_set, payload }, switch (field_index) {
                                0 => if (error_set_offset < payload_offset) .error_set else .payload,
                                1 => if (error_set_offset < payload_offset) .payload else .error_set,
                                else => unreachable,
                            })) {
                                .error_set => .{ .fromInterned(error_union_type.error_set_type), error_set_offset },
                                .payload => .{ payload_ty, payload_offset },
                            };
                            if (field_begin >= offset + size) break;
                            const field_size = field_ty.abiSize(zcu);
                            if (field_size == 0) continue;
                            field_end = field_begin + field_size;
                            if (field_end <= offset) continue;
                            if (offset >= field_begin and offset + size <= field_begin + field_size) {
                                ty = field_ty;
                                ty_size = field_size;
                                offset -= field_begin;
                                continue :type_key ip.indexToKey(field_ty.toIntern());
                            }
                            const field_signedness = if (field_ty.isAbiInt(zcu)) field_signedness: {
                                const field_int_info = field_ty.intInfo(zcu);
                                break :field_signedness if (field_int_info.bits <= 16) field_int_info.signedness else null;
                            } else null;
                            const field_is_vector = field_size <= 16 and
                                CallAbiIterator.homogeneousAggregateBaseType(zcu, field_ty.toIntern()) != null;
                            if (parts_len > 0) combine: {
                                const prev_part = &parts[parts_len - 1];
                                const combined_size = field_end - prev_part.offset;
                                if (combined_size > @as(u64, 1) << @min(
                                    min_part_log2_stride,
                                    alignment.toLog2Units(),
                                    @ctz(prev_part.offset),
                                )) break :combine;
                                prev_part.size = combined_size;
                                prev_part.signedness = null;
                                prev_part.is_vector &= field_is_vector;
                                continue;
                            }
                            parts[parts_len] = .{
                                .offset = field_begin,
                                .size = field_size,
                                .signedness = field_signedness,
                                .is_vector = field_is_vector,
                            };
                            parts_len += 1;
                        }
                        vi.setParts(isel, parts_len);
                        for (parts[0..parts_len]) |part| {
                            const subpart_vi = vi.addPart(isel, part.offset - offset, part.size);
                            if (part.signedness) |signedness| subpart_vi.setSignedness(isel, signedness);
                            if (part.is_vector) subpart_vi.setIsVector(isel);
                        }
                    },
                    .simple_type => |simple_type| switch (simple_type) {
                        .f16, .f32, .f64, .f128, .c_longdouble => return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)}),
                        .f80 => continue :type_key .{ .int_type = .{ .signedness = .unsigned, .bits = 80 } },
                        .usize,
                        .isize,
                        .c_char,
                        .c_short,
                        .c_ushort,
                        .c_int,
                        .c_uint,
                        .c_long,
                        .c_ulong,
                        .c_longlong,
                        .c_ulonglong,
                        => continue :type_key .{ .int_type = ty.intInfo(zcu) },
                        .anyopaque,
                        .void,
                        .type,
                        .comptime_int,
                        .comptime_float,
                        .noreturn,
                        .null,
                        .undefined,
                        .enum_literal,
                        .adhoc_inferred_error_set,
                        .generic_poison,
                        => unreachable,
                        .bool => continue :type_key .{ .int_type = .{ .signedness = .unsigned, .bits = 1 } },
                        .anyerror => continue :type_key .{ .int_type = .{
                            .signedness = .unsigned,
                            .bits = zcu.errorSetBits(),
                        } },
                    },
                    .struct_type => {
                        const loaded_struct = ip.loadStructType(ty.toIntern());
                        switch (loaded_struct.layout) {
                            .auto, .@"extern" => {},
                            .@"packed" => continue :type_key .{
                                .int_type = ip.indexToKey(loaded_struct.backingIntTypeUnordered(ip)).int_type,
                            },
                        }
                        const min_part_log2_stride: u5 = if (size > 16) 4 else if (size > 8) 3 else 0;
                        if (loaded_struct.field_types.len > Value.max_parts and
                            (std.math.divCeil(u64, size, @as(u64, 1) << min_part_log2_stride) catch unreachable) > Value.max_parts)
                            return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)});
                        const alignment = vi.alignment(isel);
                        const Part = struct { offset: u64, size: u64, signedness: ?std.builtin.Signedness, is_vector: bool };
                        var parts: [Value.max_parts]Part = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var field_end: u64 = 0;
                        var field_it = loaded_struct.iterateRuntimeOrder(ip);
                        while (field_it.next()) |field_index| {
                            const field_ty: ZigType = .fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                            const field_begin = switch (loaded_struct.fieldAlign(ip, field_index)) {
                                .none => field_ty.abiAlignment(zcu),
                                else => |field_align| field_align,
                            }.forward(field_end);
                            if (field_begin >= offset + size) break;
                            const field_size = field_ty.abiSize(zcu);
                            field_end = field_begin + field_size;
                            if (field_end <= offset) continue;
                            if (offset >= field_begin and offset + size <= field_begin + field_size) {
                                ty = field_ty;
                                ty_size = field_size;
                                offset -= field_begin;
                                continue :type_key ip.indexToKey(field_ty.toIntern());
                            }
                            const field_signedness = if (field_ty.isAbiInt(zcu)) field_signedness: {
                                const field_int_info = field_ty.intInfo(zcu);
                                break :field_signedness if (field_int_info.bits <= 16) field_int_info.signedness else null;
                            } else null;
                            const field_is_vector = field_size <= 16 and
                                CallAbiIterator.homogeneousAggregateBaseType(zcu, field_ty.toIntern()) != null;
                            if (parts_len > 0) combine: {
                                const prev_part = &parts[parts_len - 1];
                                const combined_size = field_end - prev_part.offset;
                                if (combined_size > @as(u64, 1) << @min(
                                    min_part_log2_stride,
                                    alignment.toLog2Units(),
                                    @ctz(prev_part.offset),
                                )) break :combine;
                                prev_part.size = combined_size;
                                prev_part.signedness = null;
                                prev_part.is_vector &= field_is_vector;
                                continue;
                            }
                            parts[parts_len] = .{
                                .offset = field_begin,
                                .size = field_size,
                                .signedness = field_signedness,
                                .is_vector = field_is_vector,
                            };
                            parts_len += 1;
                        }
                        vi.setParts(isel, parts_len);
                        for (parts[0..parts_len]) |part| {
                            const subpart_vi = vi.addPart(isel, part.offset - offset, part.size);
                            if (part.signedness) |signedness| subpart_vi.setSignedness(isel, signedness);
                            if (part.is_vector) subpart_vi.setIsVector(isel);
                        }
                    },
                    .tuple_type => |tuple_type| {
                        const min_part_log2_stride: u5 = if (size > 16) 4 else if (size > 8) 3 else 0;
                        if (tuple_type.types.len > Value.max_parts and
                            (std.math.divCeil(u64, size, @as(u64, 1) << min_part_log2_stride) catch unreachable) > Value.max_parts)
                            return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)});
                        const alignment = vi.alignment(isel);
                        const Part = struct { offset: u64, size: u64, is_vector: bool };
                        var parts: [Value.max_parts]Part = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var field_end: u64 = 0;
                        for (tuple_type.types.get(ip), tuple_type.values.get(ip)) |field_type, field_value| {
                            if (field_value != .none) continue;
                            const field_ty: ZigType = .fromInterned(field_type);
                            const field_begin = field_ty.abiAlignment(zcu).forward(field_end);
                            if (field_begin >= offset + size) break;
                            const field_size = field_ty.abiSize(zcu);
                            if (field_size == 0) continue;
                            field_end = field_begin + field_size;
                            if (field_end <= offset) continue;
                            if (offset >= field_begin and offset + size <= field_begin + field_size) {
                                ty = field_ty;
                                ty_size = field_size;
                                offset -= field_begin;
                                continue :type_key ip.indexToKey(field_ty.toIntern());
                            }
                            const field_is_vector = field_size <= 16 and
                                CallAbiIterator.homogeneousAggregateBaseType(zcu, field_ty.toIntern()) != null;
                            if (parts_len > 0) combine: {
                                const prev_part = &parts[parts_len - 1];
                                const combined_size = field_end - prev_part.offset;
                                if (combined_size > @as(u64, 1) << @min(
                                    min_part_log2_stride,
                                    alignment.toLog2Units(),
                                    @ctz(prev_part.offset),
                                )) break :combine;
                                prev_part.size = combined_size;
                                prev_part.is_vector &= field_is_vector;
                                continue;
                            }
                            parts[parts_len] = .{ .offset = field_begin, .size = field_size, .is_vector = field_is_vector };
                            parts_len += 1;
                        }
                        vi.setParts(isel, parts_len);
                        for (parts[0..parts_len]) |part| {
                            const subpart_vi = vi.addPart(isel, part.offset - offset, part.size);
                            if (part.is_vector) subpart_vi.setIsVector(isel);
                        }
                    },
                    .union_type => {
                        const loaded_union = ip.loadUnionType(ty.toIntern());
                        switch (loaded_union.flagsUnordered(ip).layout) {
                            .auto, .@"extern" => {},
                            .@"packed" => continue :type_key .{ .int_type = .{
                                .signedness = .unsigned,
                                .bits = @intCast(ty.bitSize(zcu)),
                            } },
                        }
                        const min_part_log2_stride: u5 = if (size > 16) 4 else if (size > 8) 3 else 0;
                        if ((std.math.divCeil(u64, size, @as(u64, 1) << min_part_log2_stride) catch unreachable) > Value.max_parts)
                            return isel.fail("Value.FieldPartIterator.next({f})", .{isel.fmtType(ty)});
                        const union_layout = ZigType.getUnionLayout(loaded_union, zcu);
                        const alignment = vi.alignment(isel);
                        const tag_offset = union_layout.tagOffset();
                        const payload_offset = union_layout.payloadOffset();
                        const Part = struct { offset: u64, size: u64, signedness: ?std.builtin.Signedness };
                        var parts: [2]Part = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var field_end: u64 = 0;
                        for (0..2) |field_index| {
                            const field: enum { tag, payload } = switch (field_index) {
                                0 => if (tag_offset < payload_offset) .tag else .payload,
                                1 => if (tag_offset < payload_offset) .payload else .tag,
                                else => unreachable,
                            };
                            const field_size, const field_begin = switch (field) {
                                .tag => .{ union_layout.tag_size, tag_offset },
                                .payload => .{ union_layout.payload_size, payload_offset },
                            };
                            if (field_begin >= offset + size) break;
                            if (field_size == 0) continue;
                            field_end = field_begin + field_size;
                            if (field_end <= offset) continue;
                            const field_signedness = field_signedness: switch (field) {
                                .tag => {
                                    if (offset >= field_begin and offset + size <= field_begin + field_size) {
                                        ty = .fromInterned(loaded_union.enum_tag_ty);
                                        ty_size = field_size;
                                        offset -= field_begin;
                                        continue :type_key ip.indexToKey(loaded_union.enum_tag_ty);
                                    }
                                    break :field_signedness ip.indexToKey(loaded_union.loadTagType(ip).tag_ty).int_type.signedness;
                                },
                                .payload => null,
                            };
                            if (parts_len > 0) combine: {
                                const prev_part = &parts[parts_len - 1];
                                const combined_size = field_end - prev_part.offset;
                                if (combined_size > @as(u64, 1) << @min(
                                    min_part_log2_stride,
                                    alignment.toLog2Units(),
                                    @ctz(prev_part.offset),
                                )) break :combine;
                                prev_part.size = combined_size;
                                prev_part.signedness = null;
                                continue;
                            }
                            parts[parts_len] = .{
                                .offset = field_begin,
                                .size = field_size,
                                .signedness = field_signedness,
                            };
                            parts_len += 1;
                        }
                        vi.setParts(isel, parts_len);
                        for (parts[0..parts_len]) |part| {
                            const subpart_vi = vi.addPart(isel, part.offset - offset, part.size);
                            if (part.signedness) |signedness| subpart_vi.setSignedness(isel, signedness);
                        }
                    },
                    .opaque_type, .func_type => continue :type_key .{ .simple_type = .anyopaque },
                    .enum_type => continue :type_key ip.indexToKey(ip.loadEnumType(ty.toIntern()).tag_ty),
                    .error_set_type,
                    .inferred_error_set_type,
                    => continue :type_key .{ .simple_type = .anyerror },
                    .undef,
                    .simple_value,
                    .variable,
                    .@"extern",
                    .func,
                    .int,
                    .err,
                    .error_union,
                    .enum_literal,
                    .enum_tag,
                    .empty_enum_value,
                    .float,
                    .ptr,
                    .slice,
                    .opt,
                    .aggregate,
                    .un,
                    .memoized_call,
                    => unreachable, // values, not types
                }
            }
            it.next_offset = next_offset + size;
            return .{ .offset = next_part_offset - next_offset, .vi = vi };
        }

        fn only(it: *FieldPartIterator, isel: *Select) !?Value.Index {
            const part = try it.next(isel);
            assert(part.?.offset == 0);
            return if (try it.next(isel)) |_| null else part.?.vi;
        }
    };

    const Materialize = struct {
        vi: Value.Index,
        ra: Register.Alias,

        fn finish(mat: Value.Materialize, isel: *Select) error{ OutOfMemory, CodegenFail }!void {
            const live_vi = isel.live_registers.getPtr(mat.ra);
            assert(live_vi.* == .allocating);
            var vi = mat.vi;
            var offset: u64 = 0;
            const size = mat.vi.size(isel);
            free: while (true) {
                if (vi.register(isel)) |ra| {
                    if (ra != mat.ra) break :free try isel.emit(if (vi == mat.vi) if (mat.ra.isVector()) switch (size) {
                        else => unreachable,
                        2 => if (isel.target.cpu.has(.aarch64, .fullfp16))
                            .fmov(mat.ra.h(), .{ .register = ra.h() })
                        else
                            .dup(mat.ra.h(), ra.@"h[]"(0)),
                        4 => .fmov(mat.ra.s(), .{ .register = ra.s() }),
                        8 => .fmov(mat.ra.d(), .{ .register = ra.d() }),
                        16 => .orr(mat.ra.@"16b"(), ra.@"16b"(), .{ .register = ra.@"16b"() }),
                    } else switch (size) {
                        else => unreachable,
                        1...4 => .orr(mat.ra.w(), .wzr, .{ .register = ra.w() }),
                        5...8 => .orr(mat.ra.x(), .xzr, .{ .register = ra.x() }),
                    } else switch (offset + size) {
                        else => unreachable,
                        1...4 => |end_offset| switch (mat.vi.signedness(isel)) {
                            .signed => .sbfm(mat.ra.w(), ra.w(), .{
                                .N = .word,
                                .immr = @intCast(8 * offset),
                                .imms = @intCast(8 * end_offset - 1),
                            }),
                            .unsigned => .ubfm(mat.ra.w(), ra.w(), .{
                                .N = .word,
                                .immr = @intCast(8 * offset),
                                .imms = @intCast(8 * end_offset - 1),
                            }),
                        },
                        5...8 => |end_offset| switch (mat.vi.signedness(isel)) {
                            .signed => .sbfm(mat.ra.x(), ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(8 * offset),
                                .imms = @intCast(8 * end_offset - 1),
                            }),
                            .unsigned => .ubfm(mat.ra.x(), ra.x(), .{
                                .N = .doubleword,
                                .immr = @intCast(8 * offset),
                                .imms = @intCast(8 * end_offset - 1),
                            }),
                        },
                    });
                    mat.vi.get(isel).location_payload.small.register = mat.ra;
                    live_vi.* = mat.vi;
                    return;
                }
                offset += vi.get(isel).offset_from_parent;
                switch (vi.parent(isel)) {
                    .unallocated => {
                        mat.vi.get(isel).location_payload.small.register = mat.ra;
                        live_vi.* = mat.vi;
                        return;
                    },
                    .stack_slot => |stack_slot| break :free try isel.loadReg(
                        mat.ra,
                        size,
                        mat.vi.signedness(isel),
                        stack_slot.base,
                        @as(i65, stack_slot.offset) + offset,
                    ),
                    .address => |base_vi| {
                        const base_mat = try base_vi.matReg(isel);
                        try isel.loadReg(mat.ra, size, mat.vi.signedness(isel), base_mat.ra, offset);
                        break :free try base_mat.finish(isel);
                    },
                    .value => |parent_vi| vi = parent_vi,
                    .constant => |initial_constant| {
                        const zcu = isel.pt.zcu;
                        const ip = &zcu.intern_pool;
                        var constant = initial_constant.toIntern();
                        var constant_key = ip.indexToKey(constant);
                        while (true) {
                            constant_key: switch (constant_key) {
                                .int_type,
                                .ptr_type,
                                .array_type,
                                .vector_type,
                                .opt_type,
                                .anyframe_type,
                                .error_union_type,
                                .simple_type,
                                .struct_type,
                                .tuple_type,
                                .union_type,
                                .opaque_type,
                                .enum_type,
                                .func_type,
                                .error_set_type,
                                .inferred_error_set_type,

                                .enum_literal,
                                .empty_enum_value,
                                .memoized_call,
                                => unreachable, // not a runtime value
                                .undef => break :free try isel.emit(if (mat.ra.isVector()) .movi(switch (size) {
                                    else => unreachable,
                                    1...8 => mat.ra.@"8b"(),
                                    9...16 => mat.ra.@"16b"(),
                                }, 0xaa, .{ .lsl = 0 }) else switch (size) {
                                    else => unreachable,
                                    1...4 => .orr(mat.ra.w(), .wzr, .{ .immediate = .{
                                        .N = .word,
                                        .immr = 0b000001,
                                        .imms = 0b111100,
                                    } }),
                                    5...8 => .orr(mat.ra.x(), .xzr, .{ .immediate = .{
                                        .N = .word,
                                        .immr = 0b000001,
                                        .imms = 0b111100,
                                    } }),
                                }),
                                .simple_value => |simple_value| switch (simple_value) {
                                    .undefined, .void, .null, .empty_tuple, .@"unreachable" => unreachable,
                                    .true => continue :constant_key .{ .int = .{
                                        .ty = .bool_type,
                                        .storage = .{ .u64 = 1 },
                                    } },
                                    .false => continue :constant_key .{ .int = .{
                                        .ty = .bool_type,
                                        .storage = .{ .u64 = 0 },
                                    } },
                                },
                                .int => |int| break :free storage: switch (int.storage) {
                                    .u64 => |imm| try isel.movImmediate(switch (size) {
                                        else => unreachable,
                                        1...4 => mat.ra.w(),
                                        5...8 => mat.ra.x(),
                                    }, @bitCast(std.math.shr(u64, imm, 8 * offset))),
                                    .i64 => |imm| switch (size) {
                                        else => unreachable,
                                        1...4 => try isel.movImmediate(mat.ra.w(), @as(u32, @bitCast(@as(i32, @truncate(std.math.shr(i64, imm, 8 * offset)))))),
                                        5...8 => try isel.movImmediate(mat.ra.x(), @bitCast(std.math.shr(i64, imm, 8 * offset))),
                                    },
                                    .big_int => |big_int| {
                                        assert(size == 8);
                                        var imm: u64 = 0;
                                        const limb_bits = @bitSizeOf(std.math.big.Limb);
                                        const limbs = @divExact(64, limb_bits);
                                        var limb_index: usize = @intCast(@divExact(offset, @divExact(limb_bits, 8)) + limbs);
                                        for (0..limbs) |_| {
                                            limb_index -= 1;
                                            if (limb_index >= big_int.limbs.len) continue;
                                            if (limb_bits < 64) imm <<= limb_bits;
                                            imm |= big_int.limbs[limb_index];
                                        }
                                        if (!big_int.positive) {
                                            limb_index = @min(limb_index, big_int.limbs.len);
                                            imm = while (limb_index > 0) {
                                                limb_index -= 1;
                                                if (big_int.limbs[limb_index] != 0) break ~imm;
                                            } else -%imm;
                                        }
                                        try isel.movImmediate(mat.ra.x(), imm);
                                    },
                                    .lazy_align => |ty| continue :storage .{
                                        .u64 = ZigType.fromInterned(ty).abiAlignment(zcu).toByteUnits().?,
                                    },
                                    .lazy_size => |ty| continue :storage .{
                                        .u64 = ZigType.fromInterned(ty).abiSize(zcu),
                                    },
                                },
                                .err => |err| continue :constant_key .{ .int = .{
                                    .ty = err.ty,
                                    .storage = .{ .u64 = ip.getErrorValueIfExists(err.name).? },
                                } },
                                .error_union => |error_union| {
                                    const error_union_type = ip.indexToKey(error_union.ty).error_union_type;
                                    const error_set_ty: ZigType = .fromInterned(error_union_type.error_set_type);
                                    const payload_ty: ZigType = .fromInterned(error_union_type.payload_type);
                                    const error_set_offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                                    const error_set_size = error_set_ty.abiSize(zcu);
                                    if (offset >= error_set_offset and offset + size <= error_set_offset + error_set_size) {
                                        offset -= error_set_offset;
                                        continue :constant_key switch (error_union.val) {
                                            .err_name => |err_name| .{ .err = .{
                                                .ty = error_union_type.error_set_type,
                                                .name = err_name,
                                            } },
                                            .payload => .{ .int = .{
                                                .ty = error_union_type.error_set_type,
                                                .storage = .{ .u64 = 0 },
                                            } },
                                        };
                                    }
                                    const payload_offset = codegen.errUnionPayloadOffset(payload_ty, zcu);
                                    const payload_size = payload_ty.abiSize(zcu);
                                    if (offset >= payload_offset and offset + size <= payload_offset + payload_size) {
                                        offset -= payload_offset;
                                        switch (error_union.val) {
                                            .err_name => continue :constant_key .{ .undef = error_union_type.payload_type },
                                            .payload => |payload| {
                                                constant = payload;
                                                constant_key = ip.indexToKey(payload);
                                                continue :constant_key constant_key;
                                            },
                                        }
                                    }
                                },
                                .enum_tag => |enum_tag| continue :constant_key .{ .int = ip.indexToKey(enum_tag.int).int },
                                .float => |float| storage: switch (float.storage) {
                                    .f16 => |imm| {
                                        if (!mat.ra.isVector()) continue :constant_key .{ .int = .{
                                            .ty = .u16_type,
                                            .storage = .{ .u64 = @as(u16, @bitCast(imm)) },
                                        } };
                                        const feat_fp16 = isel.target.cpu.has(.aarch64, .fullfp16);
                                        if (feat_fp16) {
                                            const Repr = std.math.FloatRepr(f16);
                                            const repr: Repr = @bitCast(imm);
                                            if (repr.mantissa & std.math.maxInt(Repr.Mantissa) >> 5 == 0 and switch (repr.exponent) {
                                                .denormal, .infinite => false,
                                                else => std.math.cast(i3, repr.exponent.unbias() - 1) != null,
                                            }) break :free try isel.emit(.fmov(mat.ra.h(), .{ .immediate = imm }));
                                        }
                                        const bits: u16 = @bitCast(imm);
                                        if (bits == 0) break :free try isel.emit(.movi(mat.ra.d(), 0b00000000, .replicate));
                                        if (bits & std.math.maxInt(u8) == 0) break :free try isel.emit(.movi(
                                            mat.ra.@"4h"(),
                                            @intCast(@shrExact(bits, 8)),
                                            .{ .lsl = 8 },
                                        ));
                                        const temp_ra = try isel.allocIntReg();
                                        defer isel.freeReg(temp_ra);
                                        try isel.emit(.fmov(if (feat_fp16) mat.ra.h() else mat.ra.s(), .{ .register = temp_ra.w() }));
                                        break :free try isel.movImmediate(temp_ra.w(), bits);
                                    },
                                    .f32 => |imm| {
                                        if (!mat.ra.isVector()) continue :constant_key .{ .int = .{
                                            .ty = .u32_type,
                                            .storage = .{ .u64 = @as(u32, @bitCast(imm)) },
                                        } };
                                        const Repr = std.math.FloatRepr(f32);
                                        const repr: Repr = @bitCast(imm);
                                        if (repr.mantissa & std.math.maxInt(Repr.Mantissa) >> 5 == 0 and switch (repr.exponent) {
                                            .denormal, .infinite => false,
                                            else => std.math.cast(i3, repr.exponent.unbias() - 1) != null,
                                        }) break :free try isel.emit(.fmov(mat.ra.s(), .{ .immediate = @floatCast(imm) }));
                                        const bits: u32 = @bitCast(imm);
                                        if (bits == 0) break :free try isel.emit(.movi(mat.ra.d(), 0b00000000, .replicate));
                                        if (bits & std.math.maxInt(u24) == 0) break :free try isel.emit(.movi(
                                            mat.ra.@"2s"(),
                                            @intCast(@shrExact(bits, 24)),
                                            .{ .lsl = 24 },
                                        ));
                                        const temp_ra = try isel.allocIntReg();
                                        defer isel.freeReg(temp_ra);
                                        try isel.emit(.fmov(mat.ra.s(), .{ .register = temp_ra.w() }));
                                        break :free try isel.movImmediate(temp_ra.w(), bits);
                                    },
                                    .f64 => |imm| {
                                        if (!mat.ra.isVector()) continue :constant_key .{ .int = .{
                                            .ty = .u64_type,
                                            .storage = .{ .u64 = @as(u64, @bitCast(imm)) },
                                        } };
                                        const Repr = std.math.FloatRepr(f64);
                                        const repr: Repr = @bitCast(imm);
                                        if (repr.mantissa & std.math.maxInt(Repr.Mantissa) >> 5 == 0 and switch (repr.exponent) {
                                            .denormal, .infinite => false,
                                            else => std.math.cast(i3, repr.exponent.unbias() - 1) != null,
                                        }) break :free try isel.emit(.fmov(mat.ra.d(), .{ .immediate = @floatCast(imm) }));
                                        const bits: u64 = @bitCast(imm);
                                        if (bits == 0) break :free try isel.emit(.movi(mat.ra.d(), 0b00000000, .replicate));
                                        const temp_ra = try isel.allocIntReg();
                                        defer isel.freeReg(temp_ra);
                                        try isel.emit(.fmov(mat.ra.d(), .{ .register = temp_ra.x() }));
                                        break :free try isel.movImmediate(temp_ra.x(), bits);
                                    },
                                    .f80 => |imm| break :free try isel.movImmediate(
                                        mat.ra.x(),
                                        @truncate(std.math.shr(u80, @bitCast(imm), 8 * offset)),
                                    ),
                                    .f128 => |imm| switch (ZigType.fromInterned(float.ty).floatBits(isel.target)) {
                                        else => unreachable,
                                        16 => continue :storage .{ .f16 = @floatCast(imm) },
                                        32 => continue :storage .{ .f32 = @floatCast(imm) },
                                        64 => continue :storage .{ .f64 = @floatCast(imm) },
                                        128 => {
                                            const bits: u128 = @bitCast(imm);
                                            const hi64: u64 = @intCast(bits >> 64);
                                            const lo64: u64 = @truncate(bits >> 0);
                                            const temp_ra = try isel.allocIntReg();
                                            defer isel.freeReg(temp_ra);
                                            switch (hi64) {
                                                0 => {},
                                                else => {
                                                    try isel.emit(.fmov(mat.ra.@"d[]"(1), .{ .register = temp_ra.x() }));
                                                    try isel.movImmediate(temp_ra.x(), hi64);
                                                },
                                            }
                                            break :free switch (lo64) {
                                                0 => try isel.emit(.movi(switch (hi64) {
                                                    else => mat.ra.d(),
                                                    0 => mat.ra.@"2d"(),
                                                }, 0b00000000, .replicate)),
                                                else => {
                                                    try isel.emit(.fmov(mat.ra.d(), .{ .register = temp_ra.x() }));
                                                    try isel.movImmediate(temp_ra.x(), lo64);
                                                },
                                            };
                                        },
                                    },
                                },
                                .ptr => |ptr| {
                                    assert(offset == 0 and size == 8);
                                    break :free switch (ptr.base_addr) {
                                        .nav => |nav| if (ZigType.fromInterned(ip.getNav(nav).typeOf(ip)).isFnOrHasRuntimeBits(zcu)) switch (true) {
                                            false => {
                                                try isel.nav_relocs.append(zcu.gpa, .{
                                                    .nav = nav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.adr(mat.ra.x(), 0));
                                            },
                                            true => {
                                                try isel.nav_relocs.append(zcu.gpa, .{
                                                    .nav = nav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.add(mat.ra.x(), mat.ra.x(), .{ .immediate = 0 }));
                                                try isel.nav_relocs.append(zcu.gpa, .{
                                                    .nav = nav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.adrp(mat.ra.x(), 0));
                                            },
                                        } else continue :constant_key .{ .int = .{
                                            .ty = .usize_type,
                                            .storage = .{ .u64 = isel.pt.navAlignment(nav).forward(0xaaaaaaaaaaaaaaaa) },
                                        } },
                                        .uav => |uav| if (ZigType.fromInterned(ip.typeOf(uav.val)).isFnOrHasRuntimeBits(zcu)) switch (true) {
                                            false => {
                                                try isel.uav_relocs.append(zcu.gpa, .{
                                                    .uav = uav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.adr(mat.ra.x(), 0));
                                            },
                                            true => {
                                                try isel.uav_relocs.append(zcu.gpa, .{
                                                    .uav = uav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.add(mat.ra.x(), mat.ra.x(), .{ .immediate = 0 }));
                                                try isel.uav_relocs.append(zcu.gpa, .{
                                                    .uav = uav,
                                                    .reloc = .{
                                                        .label = @intCast(isel.instructions.items.len),
                                                        .addend = ptr.byte_offset,
                                                    },
                                                });
                                                try isel.emit(.adrp(mat.ra.x(), 0));
                                            },
                                        } else continue :constant_key .{ .int = .{
                                            .ty = .usize_type,
                                            .storage = .{ .u64 = ZigType.fromInterned(uav.orig_ty).ptrAlignment(zcu).forward(0xaaaaaaaaaaaaaaaa) },
                                        } },
                                        .int => continue :constant_key .{ .int = .{
                                            .ty = .usize_type,
                                            .storage = .{ .u64 = ptr.byte_offset },
                                        } },
                                        .eu_payload => |base| {
                                            var base_ptr = ip.indexToKey(base).ptr;
                                            const eu_ty = ip.indexToKey(base_ptr.ty).ptr_type.child;
                                            const payload_ty = ip.indexToKey(eu_ty).error_union_type.payload_type;
                                            base_ptr.byte_offset += codegen.errUnionPayloadOffset(.fromInterned(payload_ty), zcu) + ptr.byte_offset;
                                            continue :constant_key .{ .ptr = base_ptr };
                                        },
                                        .opt_payload => |base| {
                                            var base_ptr = ip.indexToKey(base).ptr;
                                            base_ptr.byte_offset += ptr.byte_offset;
                                            continue :constant_key .{ .ptr = base_ptr };
                                        },
                                        .field => |field| {
                                            var base_ptr = ip.indexToKey(field.base).ptr;
                                            const agg_ty: ZigType = .fromInterned(ip.indexToKey(base_ptr.ty).ptr_type.child);
                                            base_ptr.byte_offset += agg_ty.structFieldOffset(@intCast(field.index), zcu) + ptr.byte_offset;
                                            continue :constant_key .{ .ptr = base_ptr };
                                        },
                                        .comptime_alloc, .comptime_field, .arr_elem => unreachable,
                                    };
                                },
                                .slice => |slice| switch (offset) {
                                    0 => continue :constant_key switch (ip.indexToKey(slice.ptr)) {
                                        else => unreachable,
                                        .undef => |undef| .{ .undef = undef },
                                        .ptr => |ptr| .{ .ptr = ptr },
                                    },
                                    else => {
                                        assert(offset == @divExact(isel.target.ptrBitWidth(), 8));
                                        offset = 0;
                                        continue :constant_key .{ .int = ip.indexToKey(slice.len).int };
                                    },
                                },
                                .opt => |opt| {
                                    const child_ty = ip.indexToKey(opt.ty).opt_type;
                                    const child_size = ZigType.fromInterned(child_ty).abiSize(zcu);
                                    if (offset == child_size and size == 1) {
                                        offset = 0;
                                        continue :constant_key .{ .simple_value = switch (opt.val) {
                                            .none => .false,
                                            else => .true,
                                        } };
                                    }
                                    const opt_ty: ZigType = .fromInterned(opt.ty);
                                    if (offset + size <= child_size) continue :constant_key switch (opt.val) {
                                        .none => if (opt_ty.optionalReprIsPayload(zcu)) .{ .int = .{
                                            .ty = opt.ty,
                                            .storage = .{ .u64 = 0 },
                                        } } else .{ .undef = child_ty },
                                        else => |child| {
                                            constant = child;
                                            constant_key = ip.indexToKey(child);
                                            continue :constant_key constant_key;
                                        },
                                    };
                                },
                                .aggregate => |aggregate| switch (ip.indexToKey(aggregate.ty)) {
                                    else => unreachable,
                                    .array_type => |array_type| {
                                        const elem_size = ZigType.fromInterned(array_type.child).abiSize(zcu);
                                        const elem_offset = @mod(offset, elem_size);
                                        if (size <= elem_size - elem_offset) {
                                            defer offset = elem_offset;
                                            continue :constant_key switch (aggregate.storage) {
                                                .bytes => |bytes| .{ .int = .{ .ty = .u8_type, .storage = .{
                                                    .u64 = bytes.toSlice(array_type.lenIncludingSentinel(), ip)[@intCast(@divFloor(offset, elem_size))],
                                                } } },
                                                .elems => |elems| {
                                                    constant = elems[@intCast(@divFloor(offset, elem_size))];
                                                    constant_key = ip.indexToKey(constant);
                                                    continue :constant_key constant_key;
                                                },
                                                .repeated_elem => |repeated_elem| {
                                                    constant = repeated_elem;
                                                    constant_key = ip.indexToKey(repeated_elem);
                                                    continue :constant_key constant_key;
                                                },
                                            };
                                        }
                                    },
                                    .vector_type => {},
                                    .struct_type => {
                                        const loaded_struct = ip.loadStructType(aggregate.ty);
                                        switch (loaded_struct.layout) {
                                            .auto => {
                                                var field_offset: u64 = 0;
                                                var field_it = loaded_struct.iterateRuntimeOrder(ip);
                                                while (field_it.next()) |field_index| {
                                                    if (loaded_struct.fieldIsComptime(ip, field_index)) continue;
                                                    const field_ty: ZigType = .fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                                    field_offset = field_ty.structFieldAlignment(
                                                        loaded_struct.fieldAlign(ip, field_index),
                                                        loaded_struct.layout,
                                                        zcu,
                                                    ).forward(field_offset);
                                                    const field_size = field_ty.abiSize(zcu);
                                                    if (offset >= field_offset and offset + size <= field_offset + field_size) {
                                                        offset -= field_offset;
                                                        constant = switch (aggregate.storage) {
                                                            .bytes => unreachable,
                                                            .elems => |elems| elems[field_index],
                                                            .repeated_elem => |repeated_elem| repeated_elem,
                                                        };
                                                        constant_key = ip.indexToKey(constant);
                                                        continue :constant_key constant_key;
                                                    }
                                                    field_offset += field_size;
                                                }
                                            },
                                            .@"extern", .@"packed" => {},
                                        }
                                    },
                                    .tuple_type => |tuple_type| {
                                        var field_offset: u64 = 0;
                                        for (tuple_type.types.get(ip), tuple_type.values.get(ip), 0..) |field_type, field_value, field_index| {
                                            if (field_value != .none) continue;
                                            const field_ty: ZigType = .fromInterned(field_type);
                                            field_offset = field_ty.abiAlignment(zcu).forward(field_offset);
                                            const field_size = field_ty.abiSize(zcu);
                                            if (offset >= field_offset and offset + size <= field_offset + field_size) {
                                                offset -= field_offset;
                                                constant = switch (aggregate.storage) {
                                                    .bytes => unreachable,
                                                    .elems => |elems| elems[field_index],
                                                    .repeated_elem => |repeated_elem| repeated_elem,
                                                };
                                                constant_key = ip.indexToKey(constant);
                                                continue :constant_key constant_key;
                                            }
                                            field_offset += field_size;
                                        }
                                    },
                                },
                                else => {},
                            }
                            var buffer: [16]u8 = @splat(0);
                            if (ZigType.fromInterned(constant_key.typeOf()).abiSize(zcu) <= buffer.len and
                                try isel.writeToMemory(.fromInterned(constant), &buffer))
                            {
                                constant_key = if (mat.ra.isVector()) .{ .float = switch (size) {
                                    else => unreachable,
                                    2 => .{ .ty = .f16_type, .storage = .{ .f16 = @bitCast(std.mem.readInt(
                                        u16,
                                        buffer[@intCast(offset)..][0..2],
                                        isel.target.cpu.arch.endian(),
                                    )) } },
                                    4 => .{ .ty = .f32_type, .storage = .{ .f32 = @bitCast(std.mem.readInt(
                                        u32,
                                        buffer[@intCast(offset)..][0..4],
                                        isel.target.cpu.arch.endian(),
                                    )) } },
                                    8 => .{ .ty = .f64_type, .storage = .{ .f64 = @bitCast(std.mem.readInt(
                                        u64,
                                        buffer[@intCast(offset)..][0..8],
                                        isel.target.cpu.arch.endian(),
                                    )) } },
                                    16 => .{ .ty = .f128_type, .storage = .{ .f128 = @bitCast(std.mem.readInt(
                                        u128,
                                        buffer[@intCast(offset)..][0..16],
                                        isel.target.cpu.arch.endian(),
                                    )) } },
                                } } else .{ .int = .{
                                    .ty = .u64_type,
                                    .storage = .{ .u64 = switch (size) {
                                        else => unreachable,
                                        inline 1...8 => |ct_size| std.mem.readInt(
                                            @Type(.{ .int = .{ .signedness = .unsigned, .bits = 8 * ct_size } }),
                                            buffer[@intCast(offset)..][0..ct_size],
                                            isel.target.cpu.arch.endian(),
                                        ),
                                    } },
                                } };
                                offset = 0;
                                continue;
                            }
                            return isel.fail("unsupported value <{f}, {f}>", .{
                                isel.fmtType(.fromInterned(constant_key.typeOf())),
                                isel.fmtConstant(.fromInterned(constant)),
                            });
                        }
                    },
                }
            }
            live_vi.* = .free;
        }
    };
};
fn initValue(isel: *Select, ty: ZigType) Value.Index {
    const zcu = isel.pt.zcu;
    return isel.initValueAdvanced(ty.abiAlignment(zcu), 0, ty.abiSize(zcu));
}
fn initValueAdvanced(
    isel: *Select,
    parent_alignment: InternPool.Alignment,
    offset_from_parent: u64,
    size: u64,
) Value.Index {
    defer isel.values.addOneAssumeCapacity().* = .{
        .refs = 0,
        .flags = .{
            .alignment = .fromLog2Units(@min(parent_alignment.toLog2Units(), @ctz(offset_from_parent))),
            .parent_tag = .unallocated,
            .location_tag = if (size > 16) .large else .small,
            .parts_len_minus_one = 0,
        },
        .offset_from_parent = offset_from_parent,
        .parent_payload = .{ .unallocated = {} },
        .location_payload = if (size > 16) .{ .large = .{
            .size = size,
        } } else .{ .small = .{
            .size = @intCast(size),
            .signedness = .unsigned,
            .is_vector = false,
            .hint = .zr,
            .register = .zr,
        } },
        .parts = undefined,
    };
    return @enumFromInt(isel.values.items.len);
}
pub fn dumpValues(isel: *Select, which: enum { only_referenced, all }) void {
    errdefer |err| @panic(@errorName(err));
    const stderr = std.debug.lockStderrWriter(&.{});
    defer std.debug.unlockStderrWriter();

    const zcu = isel.pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(isel.nav_index);

    var reverse_live_values: std.AutoArrayHashMapUnmanaged(Value.Index, std.ArrayListUnmanaged(Air.Inst.Index)) = .empty;
    defer {
        for (reverse_live_values.values()) |*list| list.deinit(gpa);
        reverse_live_values.deinit(gpa);
    }
    {
        try reverse_live_values.ensureTotalCapacity(gpa, isel.live_values.count());
        var live_val_it = isel.live_values.iterator();
        while (live_val_it.next()) |live_val_entry| switch (live_val_entry.value_ptr.*) {
            _ => {
                const gop = reverse_live_values.getOrPutAssumeCapacity(live_val_entry.value_ptr.*);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                try gop.value_ptr.append(gpa, live_val_entry.key_ptr.*);
            },
            .allocating, .free => unreachable,
        };
    }

    var reverse_live_registers: std.AutoHashMapUnmanaged(Value.Index, Register.Alias) = .empty;
    defer reverse_live_registers.deinit(gpa);
    {
        try reverse_live_registers.ensureTotalCapacity(gpa, @typeInfo(Register.Alias).@"enum".fields.len);
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| switch (live_reg_entry.value.*) {
            _ => reverse_live_registers.putAssumeCapacityNoClobber(live_reg_entry.value.*, live_reg_entry.key),
            .allocating, .free => {},
        };
    }

    var roots: std.AutoArrayHashMapUnmanaged(Value.Index, u32) = .empty;
    defer roots.deinit(gpa);
    {
        try roots.ensureTotalCapacity(gpa, isel.values.items.len);
        var vi: Value.Index = @enumFromInt(isel.values.items.len);
        while (@intFromEnum(vi) > 0) {
            vi = @enumFromInt(@intFromEnum(vi) - 1);
            if (which == .only_referenced and vi.get(isel).refs == 0) continue;
            while (true) switch (vi.parent(isel)) {
                .unallocated, .stack_slot, .constant => break,
                .value => |parent_vi| vi = parent_vi,
                .address => |address_vi| break roots.putAssumeCapacity(address_vi, 0),
            };
            roots.putAssumeCapacity(vi, 0);
        }
    }

    try stderr.print("# Begin {s} Value Dump: {f}:\n", .{ @typeName(Select), nav.fqn.fmt(ip) });
    while (roots.pop()) |root_entry| {
        const vi = root_entry.key;
        const value = vi.get(isel);
        try stderr.splatByteAll(' ', 2 * (@as(usize, 1) + root_entry.value));
        try stderr.print("${d}", .{@intFromEnum(vi)});
        {
            var first = true;
            if (reverse_live_values.get(vi)) |aiis| for (aiis.items) |aii| {
                if (aii == Block.main) {
                    try stderr.print("{s}%main", .{if (first) " <- " else ", "});
                } else {
                    try stderr.print("{s}%{d}", .{ if (first) " <- " else ", ", @intFromEnum(aii) });
                }
                first = false;
            };
            if (reverse_live_registers.get(vi)) |ra| {
                try stderr.print("{s}{s}", .{ if (first) " <- " else ", ", @tagName(ra) });
                first = false;
            }
        }
        try stderr.writeByte(':');
        switch (value.flags.parent_tag) {
            .unallocated => if (value.offset_from_parent != 0) try stderr.print(" +0x{x}", .{value.offset_from_parent}),
            .stack_slot => {
                try stderr.print(" [{s}, #{s}0x{x}", .{
                    @tagName(value.parent_payload.stack_slot.base),
                    if (value.parent_payload.stack_slot.offset < 0) "-" else "",
                    @abs(value.parent_payload.stack_slot.offset),
                });
                if (value.offset_from_parent != 0) try stderr.print("+0x{x}", .{value.offset_from_parent});
                try stderr.writeByte(']');
            },
            .value => try stderr.print(" ${d}+0x{x}", .{ @intFromEnum(value.parent_payload.value), value.offset_from_parent }),
            .address => try stderr.print(" ${d}[0x{x}]", .{ @intFromEnum(value.parent_payload.address), value.offset_from_parent }),
            .constant => try stderr.print(" <{f}, {f}>", .{
                isel.fmtType(value.parent_payload.constant.typeOf(zcu)),
                isel.fmtConstant(value.parent_payload.constant),
            }),
        }
        try stderr.print(" align({s})", .{@tagName(value.flags.alignment)});
        switch (value.flags.location_tag) {
            .large => try stderr.print(" size=0x{x} large", .{value.location_payload.large.size}),
            .small => {
                const loc = value.location_payload.small;
                try stderr.print(" size=0x{x}", .{loc.size});
                switch (loc.signedness) {
                    .unsigned => {},
                    .signed => try stderr.writeAll(" signed"),
                }
                if (loc.hint != .zr) try stderr.print(" hint={s}", .{@tagName(loc.hint)});
                if (loc.register != .zr) try stderr.print(" loc={s}", .{@tagName(loc.register)});
            },
        }
        try stderr.print(" refs={d}\n", .{value.refs});

        var part_index = value.flags.parts_len_minus_one;
        if (part_index > 0) while (true) : (part_index -= 1) {
            roots.putAssumeCapacityNoClobber(
                @enumFromInt(@intFromEnum(value.parts) + part_index),
                root_entry.value + 1,
            );
            if (part_index == 0) break;
        };
    }
    try stderr.print("# End {s} Value Dump: {f}\n\n", .{ @typeName(Select), nav.fqn.fmt(ip) });
}

fn hasRepeatedByteRepr(isel: *Select, constant: Constant) error{OutOfMemory}!?u8 {
    const zcu = isel.pt.zcu;
    const ty = constant.typeOf(zcu);
    const abi_size = std.math.cast(usize, ty.abiSize(zcu)) orelse return null;
    const byte_buffer = try zcu.gpa.alloc(u8, abi_size);
    defer zcu.gpa.free(byte_buffer);
    return if (try isel.writeToMemory(constant, byte_buffer) and
        std.mem.allEqual(u8, byte_buffer[1..], byte_buffer[0])) byte_buffer[0] else null;
}

fn writeToMemory(isel: *Select, constant: Constant, buffer: []u8) error{OutOfMemory}!bool {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    if (try isel.writeKeyToMemory(ip.indexToKey(constant.toIntern()), buffer)) return true;
    constant.writeToMemory(isel.pt, buffer) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.ReinterpretDeclRef, error.Unimplemented, error.IllDefinedMemoryLayout => return false,
    };
    return true;
}
fn writeKeyToMemory(isel: *Select, constant_key: InternPool.Key, buffer: []u8) error{OutOfMemory}!bool {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    switch (constant_key) {
        .int_type,
        .ptr_type,
        .array_type,
        .vector_type,
        .opt_type,
        .anyframe_type,
        .error_union_type,
        .simple_type,
        .struct_type,
        .tuple_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,

        .enum_literal,
        .empty_enum_value,
        .memoized_call,
        => unreachable, // not a runtime value
        .err => |err| {
            const error_int = ip.getErrorValueIfExists(err.name).?;
            switch (buffer.len) {
                else => unreachable,
                inline 1...4 => |size| std.mem.writeInt(
                    @Type(.{ .int = .{ .signedness = .unsigned, .bits = 8 * size } }),
                    buffer[0..size],
                    @intCast(error_int),
                    isel.target.cpu.arch.endian(),
                ),
            }
        },
        .error_union => |error_union| {
            const error_union_type = ip.indexToKey(error_union.ty).error_union_type;
            const error_set_ty: ZigType = .fromInterned(error_union_type.error_set_type);
            const payload_ty: ZigType = .fromInterned(error_union_type.payload_type);
            const error_set = buffer[@intCast(codegen.errUnionErrorOffset(payload_ty, zcu))..][0..@intCast(error_set_ty.abiSize(zcu))];
            switch (error_union.val) {
                .err_name => |err_name| if (!try isel.writeKeyToMemory(.{ .err = .{
                    .ty = error_set_ty.toIntern(),
                    .name = err_name,
                } }, error_set)) return false,
                .payload => |payload| {
                    if (!try isel.writeToMemory(
                        .fromInterned(payload),
                        buffer[@intCast(codegen.errUnionPayloadOffset(payload_ty, zcu))..][0..@intCast(payload_ty.abiSize(zcu))],
                    )) return false;
                    @memset(error_set, 0);
                },
            }
        },
        .opt => |opt| {
            const child_size: usize = @intCast(ZigType.fromInterned(ip.indexToKey(opt.ty).opt_type).abiSize(zcu));
            switch (opt.val) {
                .none => if (!ZigType.fromInterned(opt.ty).optionalReprIsPayload(zcu)) {
                    buffer[child_size] = @intFromBool(false);
                } else @memset(buffer[0..child_size], 0x00),
                else => |child_constant| {
                    if (!try isel.writeToMemory(.fromInterned(child_constant), buffer[0..child_size])) return false;
                    if (!ZigType.fromInterned(opt.ty).optionalReprIsPayload(zcu)) buffer[child_size] = @intFromBool(true);
                },
            }
        },
        .aggregate => |aggregate| switch (ip.indexToKey(aggregate.ty)) {
            else => unreachable,
            .array_type => |array_type| {
                var elem_offset: usize = 0;
                const elem_size: usize = @intCast(ZigType.fromInterned(array_type.child).abiSize(zcu));
                const len_including_sentinel: usize = @intCast(array_type.lenIncludingSentinel());
                switch (aggregate.storage) {
                    .bytes => |bytes| @memcpy(buffer[0..len_including_sentinel], bytes.toSlice(len_including_sentinel, ip)),
                    .elems => |elems| for (elems) |elem| {
                        if (!try isel.writeToMemory(.fromInterned(elem), buffer[elem_offset..][0..elem_size])) return false;
                        elem_offset += elem_size;
                    },
                    .repeated_elem => |repeated_elem| for (0..len_including_sentinel) |_| {
                        if (!try isel.writeToMemory(.fromInterned(repeated_elem), buffer[elem_offset..][0..elem_size])) return false;
                        elem_offset += elem_size;
                    },
                }
            },
            .vector_type => return false,
            .struct_type => {
                const loaded_struct = ip.loadStructType(aggregate.ty);
                switch (loaded_struct.layout) {
                    .auto => {
                        var field_offset: u64 = 0;
                        var field_it = loaded_struct.iterateRuntimeOrder(ip);
                        while (field_it.next()) |field_index| {
                            if (loaded_struct.fieldIsComptime(ip, field_index)) continue;
                            const field_ty: ZigType = .fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                            field_offset = field_ty.structFieldAlignment(
                                loaded_struct.fieldAlign(ip, field_index),
                                loaded_struct.layout,
                                zcu,
                            ).forward(field_offset);
                            const field_size = field_ty.abiSize(zcu);
                            if (!try isel.writeToMemory(.fromInterned(switch (aggregate.storage) {
                                .bytes => unreachable,
                                .elems => |elems| elems[field_index],
                                .repeated_elem => |repeated_elem| repeated_elem,
                            }), buffer[@intCast(field_offset)..][0..@intCast(field_size)])) return false;
                            field_offset += field_size;
                        }
                    },
                    .@"extern", .@"packed" => return false,
                }
            },
            .tuple_type => |tuple_type| {
                var field_offset: u64 = 0;
                for (tuple_type.types.get(ip), tuple_type.values.get(ip), 0..) |field_type, field_value, field_index| {
                    if (field_value != .none) continue;
                    const field_ty: ZigType = .fromInterned(field_type);
                    field_offset = field_ty.abiAlignment(zcu).forward(field_offset);
                    const field_size = field_ty.abiSize(zcu);
                    if (!try isel.writeToMemory(.fromInterned(switch (aggregate.storage) {
                        .bytes => unreachable,
                        .elems => |elems| elems[field_index],
                        .repeated_elem => |repeated_elem| repeated_elem,
                    }), buffer[@intCast(field_offset)..][0..@intCast(field_size)])) return false;
                    field_offset += field_size;
                }
            },
        },
        else => return false,
    }
    return true;
}

const TryAllocRegResult = union(enum) {
    allocated: Register.Alias,
    fill_candidate: Register.Alias,
    out_of_registers,
};

fn tryAllocIntReg(isel: *Select) TryAllocRegResult {
    var failed_result: TryAllocRegResult = .out_of_registers;
    var ra: Register.Alias = .r0;
    while (true) : (ra = @enumFromInt(@intFromEnum(ra) + 1)) {
        if (ra == .r18) continue; // The Platform Register
        if (ra == Register.Alias.fp) continue;
        const live_vi = isel.live_registers.getPtr(ra);
        switch (live_vi.*) {
            _ => switch (failed_result) {
                .allocated => unreachable,
                .fill_candidate => {},
                .out_of_registers => failed_result = .{ .fill_candidate = ra },
            },
            .allocating => {},
            .free => {
                live_vi.* = .allocating;
                isel.saved_registers.insert(ra);
                return .{ .allocated = ra };
            },
        }
        if (ra == Register.Alias.lr) return failed_result;
    }
}

fn allocIntReg(isel: *Select) !Register.Alias {
    switch (isel.tryAllocIntReg()) {
        .allocated => |ra| return ra,
        .fill_candidate => |ra| {
            assert(try isel.fillMemory(ra));
            const live_vi = isel.live_registers.getPtr(ra);
            assert(live_vi.* == .free);
            live_vi.* = .allocating;
            return ra;
        },
        .out_of_registers => return isel.fail("ran out of registers", .{}),
    }
}

fn tryAllocVecReg(isel: *Select) TryAllocRegResult {
    var failed_result: TryAllocRegResult = .out_of_registers;
    var ra: Register.Alias = .v0;
    while (true) : (ra = @enumFromInt(@intFromEnum(ra) + 1)) {
        const live_vi = isel.live_registers.getPtr(ra);
        switch (live_vi.*) {
            _ => switch (failed_result) {
                .allocated => unreachable,
                .fill_candidate => {},
                .out_of_registers => failed_result = .{ .fill_candidate = ra },
            },
            .allocating => {},
            .free => {
                live_vi.* = .allocating;
                isel.saved_registers.insert(ra);
                return .{ .allocated = ra };
            },
        }
        if (ra == Register.Alias.v31) return failed_result;
    }
}

fn allocVecReg(isel: *Select) !Register.Alias {
    switch (isel.tryAllocVecReg()) {
        .allocated => |ra| return ra,
        .fill_candidate => |ra| {
            assert(try isel.fillMemory(ra));
            return ra;
        },
        .out_of_registers => return isel.fail("ran out of registers", .{}),
    }
}

const RegLock = struct {
    ra: Register.Alias,
    const empty: RegLock = .{ .ra = .zr };
    fn unlock(lock: RegLock, isel: *Select) void {
        switch (lock.ra) {
            else => |ra| isel.freeReg(ra),
            .zr => {},
        }
    }
};
fn lockReg(isel: *Select, ra: Register.Alias) RegLock {
    assert(ra != .zr);
    const live_vi = isel.live_registers.getPtr(ra);
    assert(live_vi.* == .free);
    live_vi.* = .allocating;
    return .{ .ra = ra };
}
fn tryLockReg(isel: *Select, ra: Register.Alias) RegLock {
    assert(ra != .zr);
    const live_vi = isel.live_registers.getPtr(ra);
    switch (live_vi.*) {
        _ => unreachable,
        .allocating => return .{ .ra = .zr },
        .free => {
            live_vi.* = .allocating;
            return .{ .ra = ra };
        },
    }
}

fn freeReg(isel: *Select, ra: Register.Alias) void {
    assert(ra != .zr);
    const live_vi = isel.live_registers.getPtr(ra);
    assert(live_vi.* == .allocating);
    live_vi.* = .free;
}

fn use(isel: *Select, air_ref: Air.Inst.Ref) !Value.Index {
    const zcu = isel.pt.zcu;
    const ip = &zcu.intern_pool;
    try isel.values.ensureUnusedCapacity(zcu.gpa, 1);
    const vi, const ty = if (air_ref.toIndex()) |air_inst_index| vi_ty: {
        const live_gop = try isel.live_values.getOrPut(zcu.gpa, air_inst_index);
        if (live_gop.found_existing) return live_gop.value_ptr.*;
        const ty = isel.air.typeOf(air_ref, ip);
        const vi = isel.initValue(ty);
        tracking_log.debug("${d} <- %{d}", .{
            @intFromEnum(vi),
            @intFromEnum(air_inst_index),
        });
        live_gop.value_ptr.* = vi.ref(isel);
        break :vi_ty .{ vi, ty };
    } else vi_ty: {
        const constant: Constant = .fromInterned(air_ref.toInterned().?);
        const ty = constant.typeOf(zcu);
        const vi = isel.initValue(ty);
        tracking_log.debug("${d} <- <{f}, {f}>", .{
            @intFromEnum(vi),
            isel.fmtType(ty),
            isel.fmtConstant(constant),
        });
        vi.setParent(isel, .{ .constant = constant });
        break :vi_ty .{ vi, ty };
    };
    if (ty.isAbiInt(zcu)) {
        const int_info = ty.intInfo(zcu);
        if (int_info.bits <= 16) vi.setSignedness(isel, int_info.signedness);
    } else if (vi.size(isel) <= 16 and
        CallAbiIterator.homogeneousAggregateBaseType(zcu, ty.toIntern()) != null) vi.setIsVector(isel);
    return vi;
}

fn fill(isel: *Select, dst_ra: Register.Alias) error{ OutOfMemory, CodegenFail }!bool {
    switch (dst_ra) {
        else => {},
        Register.Alias.fp, .zr, .sp, .pc, .fpcr, .fpsr, .ffr => return false,
    }
    const dst_live_vi = isel.live_registers.getPtr(dst_ra);
    const dst_vi = switch (dst_live_vi.*) {
        _ => |dst_vi| dst_vi,
        .allocating => return false,
        .free => return true,
    };
    const src_ra = src_ra: {
        if (dst_vi.hint(isel)) |hint_ra| {
            assert(dst_live_vi.* == dst_vi);
            dst_live_vi.* = .allocating;
            defer dst_live_vi.* = dst_vi;
            if (try isel.fill(hint_ra)) {
                isel.saved_registers.insert(hint_ra);
                break :src_ra hint_ra;
            }
        }
        switch (if (dst_vi.isVector(isel)) isel.tryAllocVecReg() else isel.tryAllocIntReg()) {
            .allocated => |ra| break :src_ra ra,
            .fill_candidate, .out_of_registers => return isel.fillMemory(dst_ra),
        }
    };
    try dst_vi.liveIn(isel, src_ra, comptime &.initFill(.free));
    const src_live_vi = isel.live_registers.getPtr(src_ra);
    assert(src_live_vi.* == .allocating);
    src_live_vi.* = dst_vi;
    return true;
}

fn fillMemory(isel: *Select, dst_ra: Register.Alias) error{ OutOfMemory, CodegenFail }!bool {
    const dst_live_vi = isel.live_registers.getPtr(dst_ra);
    const dst_vi = switch (dst_live_vi.*) {
        _ => |dst_vi| dst_vi,
        .allocating => return false,
        .free => return true,
    };
    const dst_vi_ra = &dst_vi.get(isel).location_payload.small.register;
    assert(dst_vi_ra.* == dst_ra);
    const base_ra = if (dst_ra.isVector()) try isel.allocIntReg() else dst_ra;
    defer if (base_ra != dst_ra) isel.freeReg(base_ra);
    try isel.emit(switch (dst_vi.size(isel)) {
        else => unreachable,
        1 => if (dst_ra.isVector())
            .ldr(dst_ra.b(), .{ .base = base_ra.x() })
        else switch (dst_vi.signedness(isel)) {
            .signed => .ldrsb(dst_ra.w(), .{ .base = base_ra.x() }),
            .unsigned => .ldrb(dst_ra.w(), .{ .base = base_ra.x() }),
        },
        2 => if (dst_ra.isVector())
            .ldr(dst_ra.h(), .{ .base = base_ra.x() })
        else switch (dst_vi.signedness(isel)) {
            .signed => .ldrsh(dst_ra.w(), .{ .base = base_ra.x() }),
            .unsigned => .ldrh(dst_ra.w(), .{ .base = base_ra.x() }),
        },
        4 => .ldr(if (dst_ra.isVector()) dst_ra.s() else dst_ra.w(), .{ .base = base_ra.x() }),
        8 => .ldr(if (dst_ra.isVector()) dst_ra.d() else dst_ra.x(), .{ .base = base_ra.x() }),
        16 => .ldr(dst_ra.q(), .{ .base = base_ra.x() }),
    });
    dst_vi_ra.* = .zr;
    try dst_vi.address(isel, 0, base_ra);
    dst_live_vi.* = .free;
    return true;
}

/// Merges possibly differing value tracking into a consistent state.
///
/// At a conditional branch, if a value is expected in the same register on both
/// paths, or only expected in a register on only one path, tracking is updated:
///
///     $0 -> r0 // final state is now consistent with both paths
///      b.cond else
///     then:
///     $0 -> r0 // updated if not already consistent with else
///      ...
///      b end
///     else:
///     $0 -> r0
///      ...
///     end:
///
/// At a conditional branch, if a value is expected in different registers on
/// each path, mov instructions are emitted:
///
///     $0 -> r0 // final state is now consistent with both paths
///      b.cond else
///     then:
///     $0 -> r0 // updated to be consistent with else
///      mov x1, x0 // emitted to merge the inconsistent states
///     $0 -> r1
///      ...
///      b end
///     else:
///     $0 -> r0
///      ...
///     end:
///
/// At a loop, a value that is expected in a register at the repeats is updated:
///
///     $0 -> r0 // final state is now consistent with all paths
///     loop:
///     $0 -> r0 // updated to be consistent with the repeats
///      ...
///     $0 -> r0
///      b.cond loop
///      ...
///     $0 -> r0
///      b loop
///
/// At a loop, a value that is expected in a register at the top is filled:
///
///     $0 -> [sp, #A] // final state is now consistent with all paths
///     loop:
///     $0 -> [sp, #A] // updated to be consistent with the repeats
///      ldr x0, [sp, #A] // emitted to merge the inconsistent states
///     $0 -> r0
///      ...
///     $0 -> [sp, #A]
///      b.cond loop
///      ...
///     $0 -> [sp, #A]
///      b loop
///
/// At a loop, if a value that is expected in different registers on each path,
/// mov instructions are emitted:
///
///     $0 -> r0 // final state is now consistent with all paths
///     loop:
///     $0 -> r0 // updated to be consistent with the repeats
///      mov x1, x0 // emitted to merge the inconsistent states
///     $0 -> r1
///      ...
///     $0 -> r0
///      b.cond loop
///      ...
///     $0 -> r0
///      b loop
fn merge(
    isel: *Select,
    expected_live_registers: *const LiveRegisters,
    comptime opts: struct { fill_extra: bool = false },
) !void {
    var live_reg_it = isel.live_registers.iterator();
    while (live_reg_it.next()) |live_reg_entry| {
        const ra = live_reg_entry.key;
        const actual_vi = live_reg_entry.value;
        const expected_vi = expected_live_registers.get(ra);
        switch (expected_vi) {
            else => switch (actual_vi.*) {
                _ => {},
                .allocating => unreachable,
                .free => actual_vi.* = .allocating,
            },
            .free => {},
        }
    }
    live_reg_it = isel.live_registers.iterator();
    while (live_reg_it.next()) |live_reg_entry| {
        const ra = live_reg_entry.key;
        const actual_vi = live_reg_entry.value;
        const expected_vi = expected_live_registers.get(ra);
        switch (expected_vi) {
            _ => {
                switch (actual_vi.*) {
                    _ => _ = if (opts.fill_extra) {
                        assert(try isel.fillMemory(ra));
                        assert(actual_vi.* == .free);
                    },
                    .allocating => actual_vi.* = .free,
                    .free => unreachable,
                }
                try expected_vi.liveIn(isel, ra, expected_live_registers);
            },
            .allocating => if (if (opts.fill_extra) try isel.fillMemory(ra) else try isel.fill(ra)) {
                assert(actual_vi.* == .free);
                actual_vi.* = .allocating;
            },
            .free => if (opts.fill_extra) assert(try isel.fillMemory(ra) and actual_vi.* == .free),
        }
    }
    live_reg_it = isel.live_registers.iterator();
    while (live_reg_it.next()) |live_reg_entry| {
        const ra = live_reg_entry.key;
        const actual_vi = live_reg_entry.value;
        const expected_vi = expected_live_registers.get(ra);
        switch (expected_vi) {
            _ => {
                assert(actual_vi.* == .allocating and expected_vi.register(isel) == ra);
                actual_vi.* = expected_vi;
            },
            .allocating => assert(actual_vi.* == .allocating),
            .free => if (opts.fill_extra) assert(actual_vi.* == .free),
        }
    }
}

const call = struct {
    const param_reg: Value.Index = @enumFromInt(@intFromEnum(Value.Index.allocating) - 2);
    const callee_clobbered_reg: Value.Index = @enumFromInt(@intFromEnum(Value.Index.allocating) - 1);
    const caller_saved_regs: LiveRegisters = .init(.{
        .r0 = param_reg,
        .r1 = param_reg,
        .r2 = param_reg,
        .r3 = param_reg,
        .r4 = param_reg,
        .r5 = param_reg,
        .r6 = param_reg,
        .r7 = param_reg,
        .r8 = param_reg,
        .r9 = callee_clobbered_reg,
        .r10 = callee_clobbered_reg,
        .r11 = callee_clobbered_reg,
        .r12 = callee_clobbered_reg,
        .r13 = callee_clobbered_reg,
        .r14 = callee_clobbered_reg,
        .r15 = callee_clobbered_reg,
        .r16 = callee_clobbered_reg,
        .r17 = callee_clobbered_reg,
        .r18 = callee_clobbered_reg,
        .r19 = .free,
        .r20 = .free,
        .r21 = .free,
        .r22 = .free,
        .r23 = .free,
        .r24 = .free,
        .r25 = .free,
        .r26 = .free,
        .r27 = .free,
        .r28 = .free,
        .r29 = .free,
        .r30 = callee_clobbered_reg,
        .zr = .free,
        .sp = .free,

        .pc = .free,

        .v0 = param_reg,
        .v1 = param_reg,
        .v2 = param_reg,
        .v3 = param_reg,
        .v4 = param_reg,
        .v5 = param_reg,
        .v6 = param_reg,
        .v7 = param_reg,
        .v8 = .free,
        .v9 = .free,
        .v10 = .free,
        .v11 = .free,
        .v12 = .free,
        .v13 = .free,
        .v14 = .free,
        .v15 = .free,
        .v16 = callee_clobbered_reg,
        .v17 = callee_clobbered_reg,
        .v18 = callee_clobbered_reg,
        .v19 = callee_clobbered_reg,
        .v20 = callee_clobbered_reg,
        .v21 = callee_clobbered_reg,
        .v22 = callee_clobbered_reg,
        .v23 = callee_clobbered_reg,
        .v24 = callee_clobbered_reg,
        .v25 = callee_clobbered_reg,
        .v26 = callee_clobbered_reg,
        .v27 = callee_clobbered_reg,
        .v28 = callee_clobbered_reg,
        .v29 = callee_clobbered_reg,
        .v30 = callee_clobbered_reg,
        .v31 = callee_clobbered_reg,

        .fpcr = .free,
        .fpsr = .free,

        .p0 = callee_clobbered_reg,
        .p1 = callee_clobbered_reg,
        .p2 = callee_clobbered_reg,
        .p3 = callee_clobbered_reg,
        .p4 = callee_clobbered_reg,
        .p5 = callee_clobbered_reg,
        .p6 = callee_clobbered_reg,
        .p7 = callee_clobbered_reg,
        .p8 = callee_clobbered_reg,
        .p9 = callee_clobbered_reg,
        .p10 = callee_clobbered_reg,
        .p11 = callee_clobbered_reg,
        .p12 = callee_clobbered_reg,
        .p13 = callee_clobbered_reg,
        .p14 = callee_clobbered_reg,
        .p15 = callee_clobbered_reg,

        .ffr = .free,
    });
    fn prepareReturn(isel: *Select) !void {
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| switch (caller_saved_regs.get(live_reg_entry.key)) {
            else => unreachable,
            param_reg, callee_clobbered_reg => switch (live_reg_entry.value.*) {
                _ => {},
                .allocating => unreachable,
                .free => live_reg_entry.value.* = .allocating,
            },
            .free => {},
        };
    }
    fn returnFill(isel: *Select, ra: Register.Alias) !void {
        const live_vi = isel.live_registers.getPtr(ra);
        if (try isel.fill(ra)) {
            assert(live_vi.* == .free);
            live_vi.* = .allocating;
        }
        assert(live_vi.* == .allocating);
    }
    fn returnLiveIn(isel: *Select, vi: Value.Index, ra: Register.Alias) !void {
        try vi.defLiveIn(isel, ra, &caller_saved_regs);
    }
    fn finishReturn(isel: *Select) !void {
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| {
            switch (live_reg_entry.value.*) {
                _ => |live_vi| switch (live_vi.size(isel)) {
                    else => unreachable,
                    1, 2, 4, 8 => {},
                    16 => {
                        assert(try isel.fillMemory(live_reg_entry.key));
                        assert(live_reg_entry.value.* == .free);
                        switch (caller_saved_regs.get(live_reg_entry.key)) {
                            else => unreachable,
                            param_reg, callee_clobbered_reg => live_reg_entry.value.* = .allocating,
                            .free => {},
                        }
                        continue;
                    },
                },
                .allocating, .free => {},
            }
            switch (caller_saved_regs.get(live_reg_entry.key)) {
                else => unreachable,
                param_reg, callee_clobbered_reg => switch (live_reg_entry.value.*) {
                    _ => {
                        assert(try isel.fill(live_reg_entry.key));
                        assert(live_reg_entry.value.* == .free);
                        live_reg_entry.value.* = .allocating;
                    },
                    .allocating => {},
                    .free => unreachable,
                },
                .free => {},
            }
        }
    }
    fn prepareCallee(isel: *Select) !void {
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| switch (caller_saved_regs.get(live_reg_entry.key)) {
            else => unreachable,
            param_reg => assert(live_reg_entry.value.* == .allocating),
            callee_clobbered_reg => isel.freeReg(live_reg_entry.key),
            .free => {},
        };
    }
    fn finishCallee(_: *Select) !void {}
    fn prepareParams(_: *Select) !void {}
    fn paramLiveOut(isel: *Select, vi: Value.Index, ra: Register.Alias) !void {
        isel.freeReg(ra);
        try vi.liveOut(isel, ra);
        const live_vi = isel.live_registers.getPtr(ra);
        if (live_vi.* == .free) live_vi.* = .allocating;
    }
    fn paramAddress(isel: *Select, vi: Value.Index, ra: Register.Alias) !void {
        isel.freeReg(ra);
        try vi.address(isel, 0, ra);
        const live_vi = isel.live_registers.getPtr(ra);
        if (live_vi.* == .free) live_vi.* = .allocating;
    }
    fn finishParams(isel: *Select) !void {
        var live_reg_it = isel.live_registers.iterator();
        while (live_reg_it.next()) |live_reg_entry| switch (caller_saved_regs.get(live_reg_entry.key)) {
            else => unreachable,
            param_reg => switch (live_reg_entry.value.*) {
                _ => {},
                .allocating => live_reg_entry.value.* = .free,
                .free => unreachable,
            },
            callee_clobbered_reg, .free => {},
        };
    }
};

pub const CallAbiIterator = struct {
    /// Next General-purpose Register Number
    ngrn: Register.Alias,
    /// Next SIMD and Floating-point Register Number
    nsrn: Register.Alias,
    /// next stacked argument address
    nsaa: u24,

    pub const ngrn_start: Register.Alias = .r0;
    pub const ngrn_end: Register.Alias = .r8;
    pub const nsrn_start: Register.Alias = .v0;
    pub const nsrn_end: Register.Alias = .v8;
    pub const nsaa_start: u42 = 0;

    pub const init: CallAbiIterator = .{
        // A.1
        .ngrn = ngrn_start,
        // A.2
        .nsrn = nsrn_start,
        // A.3
        .nsaa = nsaa_start,
    };

    pub fn param(it: *CallAbiIterator, isel: *Select, ty: ZigType) !?Value.Index {
        const zcu = isel.pt.zcu;
        const ip = &zcu.intern_pool;

        if (ty.isNoReturn(zcu) or !ty.hasRuntimeBitsIgnoreComptime(zcu)) return null;
        try isel.values.ensureUnusedCapacity(zcu.gpa, Value.max_parts);
        const wip_vi = isel.initValue(ty);
        type_key: switch (ip.indexToKey(ty.toIntern())) {
            else => return isel.fail("CallAbiIterator.param({f})", .{isel.fmtType(ty)}),
            .int_type => |int_type| switch (int_type.bits) {
                0 => unreachable,
                1...16 => {
                    wip_vi.setSignedness(isel, int_type.signedness);
                    // C.7
                    it.integer(isel, wip_vi);
                },
                // C.7
                17...64 => it.integer(isel, wip_vi),
                // C.9
                65...128 => it.integers(isel, wip_vi, @splat(@divExact(wip_vi.size(isel), 2))),
                else => it.indirect(isel, wip_vi),
            },
            .array_type => switch (wip_vi.size(isel)) {
                0 => unreachable,
                1...8 => it.integer(isel, wip_vi),
                9...16 => |size| it.integers(isel, wip_vi, .{ 8, size - 8 }),
                else => it.indirect(isel, wip_vi),
            },
            .ptr_type => |ptr_type| switch (ptr_type.flags.size) {
                .one, .many, .c => continue :type_key .{ .int_type = .{
                    .signedness = .unsigned,
                    .bits = 64,
                } },
                .slice => it.integers(isel, wip_vi, @splat(8)),
            },
            .opt_type => |child_type| if (ty.optionalReprIsPayload(zcu))
                continue :type_key ip.indexToKey(child_type)
            else switch (ZigType.fromInterned(child_type).abiSize(zcu)) {
                0 => continue :type_key .{ .simple_type = .bool },
                1...7 => it.integer(isel, wip_vi),
                8...15 => |child_size| it.integers(isel, wip_vi, .{ 8, child_size - 7 }),
                else => return isel.fail("CallAbiIterator.param({f})", .{isel.fmtType(ty)}),
            },
            .anyframe_type => unreachable,
            .error_union_type => |error_union_type| switch (wip_vi.size(isel)) {
                0 => unreachable,
                1...8 => it.integer(isel, wip_vi),
                9...16 => {
                    var sizes: [2]u64 = @splat(0);
                    const payload_ty: ZigType = .fromInterned(error_union_type.payload_type);
                    {
                        const error_set_ty: ZigType = .fromInterned(error_union_type.error_set_type);
                        const offset = codegen.errUnionErrorOffset(payload_ty, zcu);
                        const end = offset % 8 + error_set_ty.abiSize(zcu);
                        const part_index: usize = @intCast(offset / 8);
                        sizes[part_index] = @max(sizes[part_index], @min(end, 8));
                        if (end > 8) sizes[part_index + 1] = @max(sizes[part_index + 1], end - 8);
                    }
                    {
                        const offset = codegen.errUnionPayloadOffset(payload_ty, zcu);
                        const end = offset % 8 + payload_ty.abiSize(zcu);
                        const part_index: usize = @intCast(offset / 8);
                        sizes[part_index] = @max(sizes[part_index], @min(end, 8));
                        if (end > 8) sizes[part_index + 1] = @max(sizes[part_index + 1], end - 8);
                    }
                    it.integers(isel, wip_vi, sizes);
                },
                else => it.indirect(isel, wip_vi),
            },
            .simple_type => |simple_type| switch (simple_type) {
                .f16, .f32, .f64, .f128, .c_longdouble => it.vector(isel, wip_vi),
                .f80 => continue :type_key .{ .int_type = .{ .signedness = .unsigned, .bits = 80 } },
                .usize,
                .isize,
                .c_char,
                .c_short,
                .c_ushort,
                .c_int,
                .c_uint,
                .c_long,
                .c_ulong,
                .c_longlong,
                .c_ulonglong,
                => continue :type_key .{ .int_type = ty.intInfo(zcu) },
                // B.1
                .anyopaque => it.indirect(isel, wip_vi),
                .bool => continue :type_key .{ .int_type = .{ .signedness = .unsigned, .bits = 1 } },
                .anyerror => continue :type_key .{ .int_type = .{
                    .signedness = .unsigned,
                    .bits = zcu.errorSetBits(),
                } },
                .void,
                .type,
                .comptime_int,
                .comptime_float,
                .noreturn,
                .null,
                .undefined,
                .enum_literal,
                .adhoc_inferred_error_set,
                .generic_poison,
                => unreachable,
            },
            .struct_type => {
                const loaded_struct = ip.loadStructType(ty.toIntern());
                switch (loaded_struct.layout) {
                    .auto, .@"extern" => {},
                    .@"packed" => continue :type_key .{
                        .int_type = ip.indexToKey(loaded_struct.backingIntTypeUnordered(ip)).int_type,
                    },
                }
                const size = wip_vi.size(isel);
                if (size <= 16 * 4) homogeneous_aggregate: {
                    const fdt = homogeneousStructBaseType(zcu, &loaded_struct) orelse break :homogeneous_aggregate;
                    const parts_len = @shrExact(size, fdt.log2Size());
                    if (parts_len > 4) break :homogeneous_aggregate;
                    it.vectors(isel, wip_vi, fdt, @intCast(parts_len));
                    break :type_key;
                }
                switch (size) {
                    0 => unreachable,
                    1...8 => it.integer(isel, wip_vi),
                    9...16 => {
                        var part_offset: u64 = 0;
                        var part_sizes: [2]u64 = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var next_field_end: u64 = 0;
                        var field_it = loaded_struct.iterateRuntimeOrder(ip);
                        while (part_offset < size) {
                            const field_end = next_field_end;
                            const next_field_begin = if (field_it.next()) |field_index| next_field_begin: {
                                const field_ty: ZigType = .fromInterned(loaded_struct.field_types.get(ip)[field_index]);
                                const next_field_begin = switch (loaded_struct.fieldAlign(ip, field_index)) {
                                    .none => field_ty.abiAlignment(zcu),
                                    else => |field_align| field_align,
                                }.forward(field_end);
                                next_field_end = next_field_begin + field_ty.abiSize(zcu);
                                break :next_field_begin next_field_begin;
                            } else std.mem.alignForward(u64, size, 8);
                            while (next_field_begin - part_offset >= 8) {
                                const part_size = field_end - part_offset;
                                part_sizes[parts_len] = part_size;
                                assert(part_offset + part_size <= size);
                                parts_len += 1;
                                part_offset = next_field_begin;
                            }
                        }
                        assert(parts_len == part_sizes.len);
                        it.integers(isel, wip_vi, part_sizes);
                    },
                    else => it.indirect(isel, wip_vi),
                }
            },
            .tuple_type => |tuple_type| {
                const size = wip_vi.size(isel);
                if (size <= 16 * 4) homogeneous_aggregate: {
                    const fdt = homogeneousTupleBaseType(zcu, tuple_type) orelse break :homogeneous_aggregate;
                    const parts_len = @shrExact(size, fdt.log2Size());
                    if (parts_len > 4) break :homogeneous_aggregate;
                    it.vectors(isel, wip_vi, fdt, @intCast(parts_len));
                    break :type_key;
                }
                switch (size) {
                    0 => unreachable,
                    1...8 => it.integer(isel, wip_vi),
                    9...16 => {
                        var part_offset: u64 = 0;
                        var part_sizes: [2]u64 = undefined;
                        var parts_len: Value.PartsLen = 0;
                        var next_field_end: u64 = 0;
                        var field_index: usize = 0;
                        while (part_offset < size) {
                            const field_end = next_field_end;
                            const next_field_begin = while (field_index < tuple_type.types.len) {
                                defer field_index += 1;
                                if (tuple_type.values.get(ip)[field_index] != .none) continue;
                                const field_ty: ZigType = .fromInterned(tuple_type.types.get(ip)[field_index]);
                                const next_field_begin = field_ty.abiAlignment(zcu).forward(field_end);
                                next_field_end = next_field_begin + field_ty.abiSize(zcu);
                                break next_field_begin;
                            } else std.mem.alignForward(u64, size, 8);
                            while (next_field_begin - part_offset >= 8) {
                                const part_size = @min(field_end - part_offset, 8);
                                part_sizes[parts_len] = part_size;
                                assert(part_offset + part_size <= size);
                                parts_len += 1;
                                part_offset += part_size;
                                if (part_offset >= field_end) part_offset = next_field_begin;
                            }
                        }
                        assert(parts_len == part_sizes.len);
                        it.integers(isel, wip_vi, part_sizes);
                    },
                    else => it.indirect(isel, wip_vi),
                }
            },
            .union_type => {
                const loaded_union = ip.loadUnionType(ty.toIntern());
                switch (loaded_union.flagsUnordered(ip).layout) {
                    .auto, .@"extern" => {},
                    .@"packed" => continue :type_key .{ .int_type = .{
                        .signedness = .unsigned,
                        .bits = @intCast(ty.bitSize(zcu)),
                    } },
                }
                switch (wip_vi.size(isel)) {
                    0 => unreachable,
                    1...8 => it.integer(isel, wip_vi),
                    9...16 => {
                        const union_layout = ZigType.getUnionLayout(loaded_union, zcu);
                        var sizes: [2]u64 = @splat(0);
                        {
                            const offset = union_layout.tagOffset();
                            const end = offset % 8 + union_layout.tag_size;
                            const part_index: usize = @intCast(offset / 8);
                            sizes[part_index] = @max(sizes[part_index], @min(end, 8));
                            if (end > 8) sizes[part_index + 1] = @max(sizes[part_index + 1], end - 8);
                        }
                        {
                            const offset = union_layout.payloadOffset();
                            const end = offset % 8 + union_layout.payload_size;
                            const part_index: usize = @intCast(offset / 8);
                            sizes[part_index] = @max(sizes[part_index], @min(end, 8));
                            if (end > 8) sizes[part_index + 1] = @max(sizes[part_index + 1], end - 8);
                        }
                        it.integers(isel, wip_vi, sizes);
                    },
                    else => it.indirect(isel, wip_vi),
                }
            },
            .opaque_type, .func_type => continue :type_key .{ .simple_type = .anyopaque },
            .enum_type => continue :type_key ip.indexToKey(ip.loadEnumType(ty.toIntern()).tag_ty),
            .error_set_type,
            .inferred_error_set_type,
            => continue :type_key .{ .simple_type = .anyerror },
            .undef,
            .simple_value,
            .variable,
            .@"extern",
            .func,
            .int,
            .err,
            .error_union,
            .enum_literal,
            .enum_tag,
            .empty_enum_value,
            .float,
            .ptr,
            .slice,
            .opt,
            .aggregate,
            .un,
            .memoized_call,
            => unreachable, // values, not types
        }
        return wip_vi.ref(isel);
    }

    pub fn nonSysvVarArg(it: *CallAbiIterator, isel: *Select, ty: ZigType) !?Value.Index {
        const ngrn = it.ngrn;
        defer it.ngrn = ngrn;
        it.ngrn = ngrn_end;
        const nsrn = it.nsrn;
        defer it.nsrn = nsrn;
        it.nsrn = nsrn_end;
        return it.param(isel, ty);
    }

    pub fn ret(it: *CallAbiIterator, isel: *Select, ty: ZigType) !?Value.Index {
        const wip_vi = try it.param(isel, ty) orelse return null;
        switch (wip_vi.parent(isel)) {
            .unallocated, .stack_slot => {},
            .value, .constant => unreachable,
            .address => |address_vi| {
                assert(address_vi.hint(isel) == ngrn_start);
                address_vi.setHint(isel, ngrn_end);
            },
        }
        return wip_vi;
    }

    pub const FundamentalDataType = enum {
        half,
        single,
        double,
        quad,
        vector64,
        vector128,
        fn log2Size(fdt: FundamentalDataType) u3 {
            return switch (fdt) {
                .half => 1,
                .single => 2,
                .double, .vector64 => 3,
                .quad, .vector128 => 4,
            };
        }
        fn size(fdt: FundamentalDataType) u64 {
            return @as(u64, 1) << fdt.log2Size();
        }
    };
    fn homogeneousAggregateBaseType(zcu: *Zcu, initial_ty: InternPool.Index) ?FundamentalDataType {
        const ip = &zcu.intern_pool;
        var ty = initial_ty;
        return type_key: switch (ip.indexToKey(ty)) {
            else => null,
            .array_type => |array_type| {
                ty = array_type.child;
                continue :type_key ip.indexToKey(ty);
            },
            .vector_type => switch (ZigType.fromInterned(ty).abiSize(zcu)) {
                else => null,
                8 => .vector64,
                16 => .vector128,
            },
            .simple_type => |simple_type| switch (simple_type) {
                .f16 => .half,
                .f32 => .single,
                .f64 => .double,
                .f128 => .quad,
                .c_longdouble => switch (zcu.getTarget().cTypeBitSize(.longdouble)) {
                    else => unreachable,
                    16 => .half,
                    32 => .single,
                    64 => .double,
                    80 => null,
                    128 => .quad,
                },
                else => null,
            },
            .struct_type => homogeneousStructBaseType(zcu, &ip.loadStructType(ty)),
            .tuple_type => |tuple_type| homogeneousTupleBaseType(zcu, tuple_type),
        };
    }
    fn homogeneousStructBaseType(zcu: *Zcu, loaded_struct: *const InternPool.LoadedStructType) ?FundamentalDataType {
        const ip = &zcu.intern_pool;
        var common_fdt: ?FundamentalDataType = null;
        for (0.., loaded_struct.field_types.get(ip)) |field_index, field_ty| {
            if (loaded_struct.fieldIsComptime(ip, field_index)) continue;
            if (loaded_struct.fieldAlign(ip, field_index) != .none) return null;
            if (!ZigType.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;
            const fdt = homogeneousAggregateBaseType(zcu, field_ty);
            if (common_fdt == null) common_fdt = fdt else if (fdt != common_fdt) return null;
        }
        return common_fdt;
    }
    fn homogeneousTupleBaseType(zcu: *Zcu, tuple_type: InternPool.Key.TupleType) ?FundamentalDataType {
        const ip = &zcu.intern_pool;
        var common_fdt: ?FundamentalDataType = null;
        for (tuple_type.values.get(ip), tuple_type.types.get(ip)) |field_val, field_ty| {
            if (field_val != .none) continue;
            const fdt = homogeneousAggregateBaseType(zcu, field_ty);
            if (common_fdt == null) common_fdt = fdt else if (fdt != common_fdt) return null;
        }
        return common_fdt;
    }

    const Spec = struct {
        offset: u64,
        size: u64,
    };

    fn stack(it: *CallAbiIterator, isel: *Select, wip_vi: Value.Index) void {
        // C.12
        it.nsaa = @intCast(wip_vi.alignment(isel).forward(it.nsaa));
        const parent_vi = switch (wip_vi.parent(isel)) {
            .unallocated, .stack_slot => wip_vi,
            .address, .constant => unreachable,
            .value => |parent_vi| parent_vi,
        };
        switch (parent_vi.parent(isel)) {
            .unallocated => parent_vi.setParent(isel, .{ .stack_slot = .{
                .base = .sp,
                .offset = it.nsaa,
            } }),
            .stack_slot => {},
            .address, .value, .constant => unreachable,
        }
        it.nsaa += @intCast(wip_vi.size(isel));
    }

    fn integer(it: *CallAbiIterator, isel: *Select, wip_vi: Value.Index) void {
        assert(wip_vi.size(isel) <= 8);
        const natural_alignment = wip_vi.alignment(isel);
        assert(natural_alignment.order(.@"16").compare(.lte));
        wip_vi.setAlignment(isel, natural_alignment.maxStrict(.@"8"));
        if (it.ngrn == ngrn_end) return it.stack(isel, wip_vi);
        wip_vi.setHint(isel, it.ngrn);
        it.ngrn = @enumFromInt(@intFromEnum(it.ngrn) + 1);
    }

    fn integers(it: *CallAbiIterator, isel: *Select, wip_vi: Value.Index, part_sizes: [2]u64) void {
        assert(wip_vi.size(isel) <= 16);
        const natural_alignment = wip_vi.alignment(isel);
        assert(natural_alignment.order(.@"16").compare(.lte));
        wip_vi.setAlignment(isel, natural_alignment.maxStrict(.@"8"));
        // C.8
        if (natural_alignment == .@"16") it.ngrn = @enumFromInt(std.mem.alignForward(
            @typeInfo(Register.Alias).@"enum".tag_type,
            @intFromEnum(it.ngrn),
            2,
        ));
        if (it.ngrn == ngrn_end) return it.stack(isel, wip_vi);
        wip_vi.setParts(isel, part_sizes.len);
        for (0.., part_sizes) |part_index, part_size|
            it.integer(isel, wip_vi.addPart(isel, 8 * part_index, part_size));
    }

    fn vector(it: *CallAbiIterator, isel: *Select, wip_vi: Value.Index) void {
        assert(wip_vi.size(isel) <= 16);
        const natural_alignment = wip_vi.alignment(isel);
        assert(natural_alignment.order(.@"16").compare(.lte));
        wip_vi.setAlignment(isel, natural_alignment.maxStrict(.@"8"));
        wip_vi.setIsVector(isel);
        if (it.nsrn == nsrn_end) return it.stack(isel, wip_vi);
        wip_vi.setHint(isel, it.nsrn);
        it.nsrn = @enumFromInt(@intFromEnum(it.nsrn) + 1);
    }

    fn vectors(
        it: *CallAbiIterator,
        isel: *Select,
        wip_vi: Value.Index,
        fdt: FundamentalDataType,
        parts_len: Value.PartsLen,
    ) void {
        const fdt_log2_size = fdt.log2Size();
        assert(wip_vi.size(isel) == @shlExact(@as(u9, parts_len), fdt_log2_size));
        const natural_alignment = wip_vi.alignment(isel);
        assert(natural_alignment.order(.@"16").compare(.lte));
        wip_vi.setAlignment(isel, natural_alignment.maxStrict(.@"8"));
        if (@intFromEnum(it.nsrn) > @intFromEnum(nsrn_end) - parts_len) return it.stack(isel, wip_vi);
        if (parts_len == 1) return it.vector(isel, wip_vi);
        wip_vi.setParts(isel, parts_len);
        const fdt_size = @as(u64, 1) << fdt_log2_size;
        for (0..parts_len) |part_index|
            it.vector(isel, wip_vi.addPart(isel, part_index << fdt_log2_size, fdt_size));
    }

    fn indirect(it: *CallAbiIterator, isel: *Select, wip_vi: Value.Index) void {
        const wip_address_vi = isel.initValue(.usize);
        wip_vi.setParent(isel, .{ .address = wip_address_vi });
        it.integer(isel, wip_address_vi);
    }
};

const Air = @import("../../Air.zig");
const assert = std.debug.assert;
const codegen = @import("../../codegen.zig");
const Constant = @import("../../Value.zig");
const InternPool = @import("../../InternPool.zig");
const Package = @import("../../Package.zig");
const Register = codegen.aarch64.encoding.Register;
const Select = @This();
const std = @import("std");
const tracking_log = std.log.scoped(.tracking);
const wip_mir_log = std.log.scoped(.@"wip-mir");
const Zcu = @import("../../Zcu.zig");
const ZigType = @import("../../Type.zig");
