aro_comp: *aro.Compilation,
tree: aro.Tree,
bin_file: *link.File,
arena: Allocator,
gpa: Allocator,
verbose_air: bool,

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.aro);

const Codegen = @This();
const aro = @import("lib.zig");
const link = @import("../link.zig");
const NodeIndex = aro.Tree.NodeIndex;
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const Air = @import("../Air.zig");
const Compilation = @import("../Compilation.zig");
const Module = @import("../Module.zig");
const Liveness = @import("../Liveness.zig");

pub fn generateTree(comp: *Compilation, aro_comp: *aro.Compilation, tree: aro.Tree, arena: Allocator) !void {
    var c = Codegen{
        .bin_file = comp.bin_file,
        .aro_comp = aro_comp,
        .tree = tree,
        .arena = arena,
        .gpa = comp.gpa,
        .verbose_air = comp.verbose_air,
    };

    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    for (tree.root_decls) |decl| {
        switch (node_tags[@enumToInt(decl)]) {
            // these produce no code
            .static_assert,
            .typedef,
            .struct_decl_two,
            .union_decl_two,
            .enum_decl_two,
            .struct_decl,
            .union_decl,
            .enum_decl,
            => {},

            // define symbol
            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .extern_var,
            .threadlocal_extern_var,
            => {
                const name = c.tree.tokSlice(node_datas[@enumToInt(decl)].decl.name);
                log.debug("ignoring the opportunity to define a symbol named {s}", .{name});
                //_ = try c.obj.declareSymbol(.@"undefined", name, .Strong, .external, 0, 0);
            },

            // function definition
            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            => try c.genFn(decl),

            .@"var",
            .static_var,
            .threadlocal_var,
            .threadlocal_static_var,
            => try c.genVar(decl),

            else => unreachable,
        }
    }
}

const Func = struct {
    codegen: *Codegen,
    name: []const u8,

    air_instructions: std.MultiArrayList(Air.Inst) = .{},
    air_extra: std.ArrayListUnmanaged(u32) = .{},
    air_values: std.ArrayListUnmanaged(Value) = .{},

    fn deinit(func: *Func) void {
        const gpa = func.codegen.gpa;
        func.air_instructions.deinit(gpa);
        func.air_extra.deinit(gpa);
        func.air_values.deinit(gpa);
        func.* = undefined;
    }

    /// Reminder to refactor this out with the equivalent Sema function.
    fn addConstant(func: *Func, ty: Type, val: Value) !Air.Inst.Ref {
        const gpa = func.codegen.gpa;
        const ty_inst = try func.addType(ty);
        try func.air_values.append(gpa, val);
        try func.air_instructions.append(gpa, .{
            .tag = .constant,
            .data = .{ .ty_pl = .{
                .ty = ty_inst,
                .payload = @intCast(u32, func.air_values.items.len - 1),
            } },
        });
        return Air.indexToRef(@intCast(u32, func.air_instructions.len - 1));
    }

    /// Reminder to refactor this out with the equivalent Sema function.
    fn addType(func: *Func, ty: Type) !Air.Inst.Ref {
        switch (ty.tag()) {
            .u1 => return .u1_type,
            .u8 => return .u8_type,
            .i8 => return .i8_type,
            .u16 => return .u16_type,
            .i16 => return .i16_type,
            .u32 => return .u32_type,
            .i32 => return .i32_type,
            .u64 => return .u64_type,
            .i64 => return .i64_type,
            .u128 => return .u128_type,
            .i128 => return .i128_type,
            .usize => return .usize_type,
            .isize => return .isize_type,
            .c_short => return .c_short_type,
            .c_ushort => return .c_ushort_type,
            .c_int => return .c_int_type,
            .c_uint => return .c_uint_type,
            .c_long => return .c_long_type,
            .c_ulong => return .c_ulong_type,
            .c_longlong => return .c_longlong_type,
            .c_ulonglong => return .c_ulonglong_type,
            .c_longdouble => return .c_longdouble_type,
            .f16 => return .f16_type,
            .f32 => return .f32_type,
            .f64 => return .f64_type,
            .f80 => return .f80_type,
            .f128 => return .f128_type,
            .anyopaque => return .anyopaque_type,
            .bool => return .bool_type,
            .void => return .void_type,
            .type => return .type_type,
            .anyerror => return .anyerror_type,
            .comptime_int => return .comptime_int_type,
            .comptime_float => return .comptime_float_type,
            .noreturn => return .noreturn_type,
            .@"anyframe" => return .anyframe_type,
            .@"null" => return .null_type,
            .@"undefined" => return .undefined_type,
            .enum_literal => return .enum_literal_type,
            .atomic_order => return .atomic_order_type,
            .atomic_rmw_op => return .atomic_rmw_op_type,
            .calling_convention => return .calling_convention_type,
            .address_space => return .address_space_type,
            .float_mode => return .float_mode_type,
            .reduce_op => return .reduce_op_type,
            .call_options => return .call_options_type,
            .prefetch_options => return .prefetch_options_type,
            .export_options => return .export_options_type,
            .extern_options => return .extern_options_type,
            .type_info => return .type_info_type,
            .manyptr_u8 => return .manyptr_u8_type,
            .manyptr_const_u8 => return .manyptr_const_u8_type,
            .fn_noreturn_no_args => return .fn_noreturn_no_args_type,
            .fn_void_no_args => return .fn_void_no_args_type,
            .fn_naked_noreturn_no_args => return .fn_naked_noreturn_no_args_type,
            .fn_ccc_void_no_args => return .fn_ccc_void_no_args_type,
            .single_const_pointer_to_comptime_int => return .single_const_pointer_to_comptime_int_type,
            .const_slice_u8 => return .const_slice_u8_type,
            .anyerror_void_error_union => return .anyerror_void_error_union_type,
            .generic_poison => return .generic_poison_type,
            else => {},
        }
        try func.air_instructions.append(func.codegen.gpa, .{
            .tag = .const_ty,
            .data = .{ .ty = ty },
        });
        return Air.indexToRef(@intCast(u32, func.air_instructions.len - 1));
    }

    fn getTmpAir(func: Func) Air {
        return .{
            .instructions = func.air_instructions.slice(),
            .extra = func.air_extra.items,
            .values = func.air_values.items,
        };
    }

    fn addExtra(func: *Func, extra: anytype) Allocator.Error!u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        try func.air_extra.ensureUnusedCapacity(func.gpa, fields.len);
        return addExtraAssumeCapacity(func, extra);
    }

    fn addExtraAssumeCapacity(func: *Func, extra: anytype) u32 {
        const fields = std.meta.fields(@TypeOf(extra));
        const result = @intCast(u32, func.air_extra.items.len);
        inline for (fields) |field| {
            func.air_extra.appendAssumeCapacity(switch (field.field_type) {
                u32 => @field(extra, field.name),
                Air.Inst.Ref => @enumToInt(@field(extra, field.name)),
                i32 => @bitCast(u32, @field(extra, field.name)),
                else => @compileError("bad field type"),
            });
        }
        return result;
    }

    fn appendRefsAssumeCapacity(func: *Func, refs: []const Air.Inst.Ref) void {
        const coerced = @bitCast([]const u32, refs);
        func.air_extra.appendSliceAssumeCapacity(coerced);
    }
};

fn genFn(c: *Codegen, decl_node: NodeIndex) !void {
    const node_datas = c.tree.nodes.items(.data);
    const node_data = node_datas[@enumToInt(decl_node)].decl;
    const name = c.tree.tokSlice(node_data.name);
    log.debug("genFn {s}", .{name});
    const body_node = node_data.node;

    var func: Func = .{
        .codegen = c,
        .name = name,
    };
    defer func.deinit();

    // First few indexes of extra are reserved and set at the end.
    const reserved_count = @typeInfo(Air.ExtraIndex).Enum.fields.len;
    try func.air_extra.ensureTotalCapacity(c.gpa, reserved_count);
    func.air_extra.items.len += reserved_count;

    var block: Block = .{
        .func = &func,
        .instructions = .{},
    };
    defer block.instructions.deinit(c.gpa);

    _ = try genNode(&func, &block, body_node);

    try func.air_extra.ensureUnusedCapacity(c.gpa, @typeInfo(Air.Block).Struct.fields.len +
        block.instructions.items.len);
    const main_block_index = func.addExtraAssumeCapacity(Air.Block{
        .body_len = @intCast(u32, block.instructions.items.len),
    });
    func.air_extra.appendSliceAssumeCapacity(block.instructions.items);
    func.air_extra.items[@enumToInt(Air.ExtraIndex.main_block)] = main_block_index;

    var air = func.getTmpAir();

    var liveness = try Liveness.analyze(c.gpa, air, undefined);
    defer liveness.deinit(c.gpa);

    if (builtin.mode == .Debug and c.verbose_air) {
        std.debug.print("# Begin Function AIR: {s}:\n", .{name});
        @import("../print_air.zig").dump(c.gpa, air, undefined, liveness);
        std.debug.print("# End Function AIR: {s}\n\n", .{name});
    }

    @panic("TODO make a Decl and Fn");
    //c.bin_file.updateFunc(module, module_fn, air, liveness) catch |err| switch (err) {
    //    error.OutOfMemory => return error.OutOfMemory,
    //    error.AnalysisFail => {
    //        decl.analysis = .codegen_failure;
    //        return;
    //    },
    //    else => {
    //        try module.failed_decls.ensureUnusedCapacity(gpa, 1);
    //        module.failed_decls.putAssumeCapacityNoClobber(decl, try Module.ErrorMsg.create(
    //            gpa,
    //            decl.srcLoc(),
    //            "unable to codegen: {s}",
    //            .{@errorName(err)},
    //        ));
    //        decl.analysis = .codegen_failure_retryable;
    //        return;
    //    },
    //};
}

fn lowerType(c: *Codegen, aro_ty: aro.Type) Allocator.Error!Type {
    _ = c;
    switch (aro_ty.specifier) {
        .void => return Type.void,
        .bool => return Type.bool,
        .char, .schar => return Type.initTag(.i8),
        .uchar => return Type.initTag(.u8),
        .short => return Type.initTag(.c_short),
        .ushort => return Type.initTag(.c_ushort),
        .int => return Type.initTag(.c_int),
        .uint => return Type.initTag(.c_uint),
        .long => return Type.initTag(.c_long),
        .ulong => return Type.initTag(.c_ulong),
        .long_long => return Type.initTag(.c_longlong),
        .ulong_long => return Type.initTag(.c_ulonglong),

        .float => return Type.initTag(.f32),
        .double => return Type.initTag(.f64),
        .long_double => return Type.initTag(.c_longdouble),

        .complex_float,
        .complex_double,
        .complex_long_double,

        // data.sub_type
        .pointer,
        .unspecified_variable_len_array,
        .decayed_unspecified_variable_len_array,
        // data.func
        // int foo(int bar, char baz) and int (void)
        .func,
        // int foo(int bar, char baz, ...)
        .var_args_func,
        // int foo(bar, baz) and int foo()
        // is also var args, but we can give warnings about incorrect amounts of parameters
        .old_style_func,

        // data.array
        .array,
        .decayed_array,
        .static_array,
        .decayed_static_array,
        .incomplete_array,
        .decayed_incomplete_array,
        // data.expr
        .variable_len_array,
        .decayed_variable_len_array,

        // data.record
        .@"struct",
        .@"union",

        // data.enum
        .@"enum",

        // typeof(type-name)
        .typeof_type,
        // decayed array created with typeof(type-name)
        .decayed_typeof_type,

        // typeof(expression)
        .typeof_expr,
        // decayed array created with typeof(expression)
        .decayed_typeof_expr,

        // data.attributed
        .attributed,

        // special type used to implement __builtin_va_start
        .special_va_start,
        => std.debug.panic("TODO handle {s}", .{@tagName(aro_ty.specifier)}),
    }
}

fn lowerValue(c: *Codegen, aro_ty: aro.Type, aro_val: aro.Value) Allocator.Error!TypedValue {
    const zig_ty = try c.lowerType(aro_ty);
    switch (aro_val.tag) {
        .unavailable => unreachable,
        .int => {
            const is_signed = zig_ty.isSignedInt();
            if (is_signed) @panic("TODO");
            return TypedValue{
                .ty = zig_ty,
                .val = try Value.Tag.int_u64.create(c.arena, aro_val.data.int),
            };
        },
        .float => @panic("TODO"),
        .array => @panic("TODO"),
        .bytes => @panic("TODO"),
    }
}

const Error = error{OutOfMemory};

fn genNode(func: *Func, block: *Block, node: NodeIndex) Error!Air.Inst.Ref {
    const tree = func.codegen.tree;
    const node_tys = tree.nodes.items(.ty);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);

    if (tree.value_map.get(node)) |some| {
        if (some.tag == .int) {
            const zig_tv = try func.codegen.lowerValue(node_tys[@enumToInt(node)], some);
            return func.addConstant(zig_tv.ty, zig_tv.val);
        }
    }

    const data = node_datas[@enumToInt(node)];
    switch (node_tags[@enumToInt(node)]) {
        .static_assert => return Air.Inst.Ref.void_value,
        .compound_stmt_two => {
            if (data.bin.lhs != .none) _ = try genNode(func, block, data.bin.lhs);
            if (data.bin.rhs != .none) _ = try genNode(func, block, data.bin.rhs);
            return Air.Inst.Ref.void_value;
        },
        .compound_stmt => {
            const body = tree.data[data.range.start..data.range.end];
            for (body) |stmt| {
                _ = try genNode(func, block, stmt);
            }
            return Air.Inst.Ref.void_value;
        },
        .call_expr_one => if (data.bin.rhs != .none)
            return genCall(func, block, data.bin.lhs, &.{data.bin.rhs})
        else
            return genCall(func, block, data.bin.lhs, &.{}),
        .call_expr => return genCall(func, block, tree.data[data.range.start], tree.data[data.range.start + 1 .. data.range.end]),
        .function_to_pointer => return genNode(func, block, data.un), // no-op
        .array_to_pointer => {
            const operand = try genNode(func, block, data.un);
            const array_val = func.getTmpAir().value(operand).?;
            const tmp_bytes = array_val.castTag(.bytes).?.data;

            var anon_decl = try block.startAnonDecl();
            defer anon_decl.deinit();

            const bytes = try anon_decl.arena().dupeZ(u8, tmp_bytes);

            const new_decl = try anon_decl.finish(
                try Type.Tag.array_u8_sentinel_0.create(anon_decl.arena(), bytes.len),
                try Value.Tag.bytes.create(anon_decl.arena(), bytes[0 .. bytes.len + 1]),
            );

            return func.addConstant(
                try Type.ptr(func.codegen.arena, .{
                    .pointee_type = new_decl.ty,
                    .mutable = false,
                    .@"addrspace" = new_decl.@"addrspace",
                }),
                try Value.Tag.decl_ref.create(func.codegen.arena, new_decl),
            );
        },
        .decl_ref_expr => {
            // TODO locals and arguments
            const name = tree.tokSlice(data.decl_ref);
            std.debug.panic("TODO decl_ref_expr {s}", .{name});
        },
        .return_stmt => {
            const operand = try genNode(func, block, data.un);
            _ = try block.addUnOp(.ret, operand);
            return Air.Inst.Ref.unreachable_value;
        },
        .implicit_return => {
            _ = try block.addUnOp(.ret, .void_value);
            return Air.Inst.Ref.void_value;
        },
        .int_literal => {
            const zig_ty = try func.codegen.lowerType(node_tys[@enumToInt(node)]);
            if (zig_ty.isSignedInt()) {
                @panic("TODO");
            }
            const zig_val = try Value.Tag.int_u64.create(func.codegen.arena, data.int);
            return func.addConstant(zig_ty, zig_val);
        },
        .string_literal_expr => {
            const ast_bytes = tree.value_map.get(node).?.data.bytes;
            const array_val = try Value.Tag.bytes.create(func.codegen.arena, ast_bytes);
            const array_ty = try Type.Tag.array_u8.create(func.codegen.arena, ast_bytes.len);
            return func.addConstant(array_ty, array_val);
        },
        else => return std.debug.panic("TODO lower Aro AST tag {}\n", .{node_tags[@enumToInt(node)]}),
    }
}

fn genCall(func: *Func, block: *Block, lhs: NodeIndex, args: []const NodeIndex) Error!Air.Inst.Ref {
    const callee = try genNode(func, block, lhs);

    const air_args = try func.codegen.arena.alloc(Air.Inst.Ref, args.len);
    for (args) |arg_node, i| {
        air_args[i] = try genNode(func, block, arg_node);
    }

    try func.air_extra.ensureUnusedCapacity(func.codegen.gpa, @typeInfo(Air.Call).Struct.fields.len + args.len);

    const func_inst = try block.addInst(.{
        .tag = .call,
        .data = .{ .pl_op = .{
            .operand = callee,
            .payload = func.addExtraAssumeCapacity(Air.Call{
                .args_len = @intCast(u32, args.len),
            }),
        } },
    });
    func.appendRefsAssumeCapacity(air_args);

    return func_inst;
}

fn genVar(c: *Codegen, decl: NodeIndex) !void {
    const node_datas = c.tree.nodes.items(.data);
    const name = c.tree.tokSlice(node_datas[@enumToInt(decl)].decl.name);
    log.debug("genVar {s}", .{name});
}

pub const Block = struct {
    func: *Func,
    /// The AIR instructions generated for this block.
    instructions: std.ArrayListUnmanaged(Air.Inst.Index),

    pub fn addTy(
        block: *Block,
        tag: Air.Inst.Tag,
        ty: Type,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty = ty },
        });
    }

    pub fn addTyOp(
        block: *Block,
        tag: Air.Inst.Tag,
        ty: Type,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty_op = .{
                .ty = try block.func.addType(ty),
                .operand = operand,
            } },
        });
    }

    pub fn addBitCast(block: *Block, ty: Type, operand: Air.Inst.Ref) Allocator.Error!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .bitcast,
            .data = .{ .ty_op = .{
                .ty = try block.func.addType(ty),
                .operand = operand,
            } },
        });
    }

    pub fn addNoOp(block: *Block, tag: Air.Inst.Tag) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .no_op = {} },
        });
    }

    pub fn addUnOp(
        block: *Block,
        tag: Air.Inst.Tag,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .un_op = operand },
        });
    }

    pub fn addBr(
        block: *Block,
        target_block: Air.Inst.Index,
        operand: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = target_block,
                .operand = operand,
            } },
        });
    }

    fn addBinOp(
        block: *Block,
        tag: Air.Inst.Tag,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
    ) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = tag,
            .data = .{ .bin_op = .{
                .lhs = lhs,
                .rhs = rhs,
            } },
        });
    }

    fn addArg(block: *Block, ty: Type, name: u32) error{OutOfMemory}!Air.Inst.Ref {
        return block.addInst(.{
            .tag = .arg,
            .data = .{ .ty_str = .{
                .ty = try block.func.addType(ty),
                .str = name,
            } },
        });
    }

    fn addStructFieldPtr(
        block: *Block,
        struct_ptr: Air.Inst.Ref,
        field_index: u32,
        ptr_field_ty: Type,
    ) !Air.Inst.Ref {
        const ty = try block.func.addType(ptr_field_ty);
        const tag: Air.Inst.Tag = switch (field_index) {
            0 => .struct_field_ptr_index_0,
            1 => .struct_field_ptr_index_1,
            2 => .struct_field_ptr_index_2,
            3 => .struct_field_ptr_index_3,
            else => {
                return block.addInst(.{
                    .tag = .struct_field_ptr,
                    .data = .{ .ty_pl = .{
                        .ty = ty,
                        .payload = try block.func.addExtra(Air.StructField{
                            .struct_operand = struct_ptr,
                            .field_index = field_index,
                        }),
                    } },
                });
            },
        };
        return block.addInst(.{
            .tag = tag,
            .data = .{ .ty_op = .{
                .ty = ty,
                .operand = struct_ptr,
            } },
        });
    }

    pub fn addStructFieldVal(
        block: *Block,
        struct_val: Air.Inst.Ref,
        field_index: u32,
        field_ty: Type,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .struct_field_val,
            .data = .{ .ty_pl = .{
                .ty = try block.func.addType(field_ty),
                .payload = try block.func.addExtra(Air.StructField{
                    .struct_operand = struct_val,
                    .field_index = field_index,
                }),
            } },
        });
    }

    pub fn addSliceElemPtr(
        block: *Block,
        slice: Air.Inst.Ref,
        elem_index: Air.Inst.Ref,
        elem_ptr_ty: Type,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .slice_elem_ptr,
            .data = .{ .ty_pl = .{
                .ty = try block.func.addType(elem_ptr_ty),
                .payload = try block.func.addExtra(Air.Bin{
                    .lhs = slice,
                    .rhs = elem_index,
                }),
            } },
        });
    }

    pub fn addPtrElemPtr(
        block: *Block,
        array_ptr: Air.Inst.Ref,
        elem_index: Air.Inst.Ref,
        elem_ptr_ty: Type,
    ) !Air.Inst.Ref {
        const ty_ref = try block.func.addType(elem_ptr_ty);
        return block.addPtrElemPtrTypeRef(array_ptr, elem_index, ty_ref);
    }

    pub fn addPtrElemPtrTypeRef(
        block: *Block,
        array_ptr: Air.Inst.Ref,
        elem_index: Air.Inst.Ref,
        elem_ptr_ty: Air.Inst.Ref,
    ) !Air.Inst.Ref {
        return block.addInst(.{
            .tag = .ptr_elem_ptr,
            .data = .{ .ty_pl = .{
                .ty = elem_ptr_ty,
                .payload = try block.func.addExtra(Air.Bin{
                    .lhs = array_ptr,
                    .rhs = elem_index,
                }),
            } },
        });
    }

    pub fn addVectorInit(
        block: *Block,
        vector_ty: Type,
        elements: []const Air.Inst.Ref,
    ) !Air.Inst.Ref {
        const func = block.func;
        const ty_ref = try func.addType(vector_ty);
        try func.air_extra.ensureUnusedCapacity(func.gpa, elements.len);
        const extra_index = @intCast(u32, func.air_extra.items.len);
        func.appendRefsAssumeCapacity(elements);

        return block.addInst(.{
            .tag = .vector_init,
            .data = .{ .ty_pl = .{
                .ty = ty_ref,
                .payload = extra_index,
            } },
        });
    }

    pub fn addInst(block: *Block, inst: Air.Inst) error{OutOfMemory}!Air.Inst.Ref {
        return Air.indexToRef(try block.addInstAsIndex(inst));
    }

    pub fn addInstAsIndex(block: *Block, inst: Air.Inst) error{OutOfMemory}!Air.Inst.Index {
        const func = block.func;
        const gpa = func.codegen.gpa;

        try func.air_instructions.ensureUnusedCapacity(gpa, 1);
        try block.instructions.ensureUnusedCapacity(gpa, 1);

        const result_index = @intCast(Air.Inst.Index, func.air_instructions.len);
        func.air_instructions.appendAssumeCapacity(inst);
        block.instructions.appendAssumeCapacity(result_index);
        return result_index;
    }

    pub fn startAnonDecl(block: *Block) !WipAnonDecl {
        return WipAnonDecl{
            .block = block,
            .new_decl_arena = std.heap.ArenaAllocator.init(block.func.codegen.gpa),
            .finished = false,
        };
    }

    pub const WipAnonDecl = struct {
        block: *Block,
        new_decl_arena: std.heap.ArenaAllocator,
        finished: bool,

        pub fn arena(wad: *WipAnonDecl) Allocator {
            return wad.new_decl_arena.allocator();
        }

        pub fn deinit(wad: *WipAnonDecl) void {
            if (!wad.finished) {
                wad.new_decl_arena.deinit();
            }
            wad.* = undefined;
        }

        pub fn finish(wad: *WipAnonDecl, ty: Type, val: Value) !*Module.Decl {
            const func = wad.block.func;
            const mod = func.codegen.bin_file.options.module.?;
            const new_decl = try mod.createAnonymousDecl2(.{
                .ty = ty,
                .val = val,
            }, func.name);
            errdefer mod.abortAnonDecl(new_decl);
            try new_decl.finalizeNewArena(&wad.new_decl_arena);
            wad.finished = true;
            return new_decl;
        }
    };
};
