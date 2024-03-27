const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const backend = @import("../backend.zig");
const Interner = backend.Interner;
const Ir = backend.Ir;
const Builtins = @import("Builtins.zig");
const Builtin = Builtins.Builtin;
const Compilation = @import("Compilation.zig");
const Builder = Ir.Builder;
const StrInt = @import("StringInterner.zig");
const StringId = StrInt.StringId;
const Tree = @import("Tree.zig");
const NodeIndex = Tree.NodeIndex;
const Type = @import("Type.zig");
const Value = @import("Value.zig");

const WipSwitch = struct {
    cases: Cases = .{},
    default: ?Ir.Ref = null,
    size: u64,

    const Cases = std.MultiArrayList(struct {
        val: Interner.Ref,
        label: Ir.Ref,
    });
};

const Symbol = struct {
    name: StringId,
    val: Ir.Ref,
};

const Error = Compilation.Error;

const CodeGen = @This();

tree: Tree,
comp: *Compilation,
builder: Builder,
node_tag: []const Tree.Tag,
node_data: []const Tree.Node.Data,
node_ty: []const Type,
wip_switch: *WipSwitch = undefined,
symbols: std.ArrayListUnmanaged(Symbol) = .{},
ret_nodes: std.ArrayListUnmanaged(Ir.Inst.Phi.Input) = .{},
phi_nodes: std.ArrayListUnmanaged(Ir.Inst.Phi.Input) = .{},
record_elem_buf: std.ArrayListUnmanaged(Interner.Ref) = .{},
record_cache: std.AutoHashMapUnmanaged(*Type.Record, Interner.Ref) = .{},
cond_dummy_ty: ?Interner.Ref = null,
bool_invert: bool = false,
bool_end_label: Ir.Ref = .none,
cond_dummy_ref: Ir.Ref = undefined,
continue_label: Ir.Ref = undefined,
break_label: Ir.Ref = undefined,
return_label: Ir.Ref = undefined,

fn fail(c: *CodeGen, comptime fmt: []const u8, args: anytype) error{ FatalError, OutOfMemory } {
    try c.comp.diagnostics.list.append(c.comp.gpa, .{
        .tag = .cli_error,
        .kind = .@"fatal error",
        .extra = .{ .str = try std.fmt.allocPrint(c.comp.diagnostics.arena.allocator(), fmt, args) },
    });
    return error.FatalError;
}

pub fn genIr(tree: Tree) Compilation.Error!Ir {
    const gpa = tree.comp.gpa;
    var c = CodeGen{
        .builder = .{
            .gpa = tree.comp.gpa,
            .interner = &tree.comp.interner,
            .arena = std.heap.ArenaAllocator.init(gpa),
        },
        .tree = tree,
        .comp = tree.comp,
        .node_tag = tree.nodes.items(.tag),
        .node_data = tree.nodes.items(.data),
        .node_ty = tree.nodes.items(.ty),
    };
    defer c.symbols.deinit(gpa);
    defer c.ret_nodes.deinit(gpa);
    defer c.phi_nodes.deinit(gpa);
    defer c.record_elem_buf.deinit(gpa);
    defer c.record_cache.deinit(gpa);
    defer c.builder.deinit();

    const node_tags = tree.nodes.items(.tag);
    for (tree.root_decls) |decl| {
        c.builder.arena.deinit();
        c.builder.arena = std.heap.ArenaAllocator.init(gpa);

        switch (node_tags[@intFromEnum(decl)]) {
            .static_assert,
            .typedef,
            .struct_decl_two,
            .union_decl_two,
            .enum_decl_two,
            .struct_decl,
            .union_decl,
            .enum_decl,
            => {},

            .fn_proto,
            .static_fn_proto,
            .inline_fn_proto,
            .inline_static_fn_proto,
            .extern_var,
            .threadlocal_extern_var,
            => {},

            .fn_def,
            .static_fn_def,
            .inline_fn_def,
            .inline_static_fn_def,
            => c.genFn(decl) catch |err| switch (err) {
                error.FatalError => return error.FatalError,
                error.OutOfMemory => return error.OutOfMemory,
            },

            .@"var",
            .static_var,
            .threadlocal_var,
            .threadlocal_static_var,
            => c.genVar(decl) catch |err| switch (err) {
                error.FatalError => return error.FatalError,
                error.OutOfMemory => return error.OutOfMemory,
            },
            else => unreachable,
        }
    }
    return c.builder.finish();
}

fn genType(c: *CodeGen, base_ty: Type) !Interner.Ref {
    var key: Interner.Key = undefined;
    const ty = base_ty.canonicalize(.standard);
    switch (ty.specifier) {
        .void => return .void,
        .bool => return .i1,
        .@"struct" => {
            if (c.record_cache.get(ty.data.record)) |some| return some;

            const elem_buf_top = c.record_elem_buf.items.len;
            defer c.record_elem_buf.items.len = elem_buf_top;

            for (ty.data.record.fields) |field| {
                if (!field.isRegularField()) {
                    return c.fail("TODO lower struct bitfields", .{});
                }
                // TODO handle padding bits
                const field_ref = try c.genType(field.ty);
                try c.record_elem_buf.append(c.builder.gpa, field_ref);
            }

            return c.builder.interner.put(c.builder.gpa, .{
                .record_ty = c.record_elem_buf.items[elem_buf_top..],
            });
        },
        .@"union" => {
            return c.fail("TODO lower union types", .{});
        },
        else => {},
    }
    if (ty.isPtr()) return .ptr;
    if (ty.isFunc()) return .func;
    if (!ty.isReal()) return c.fail("TODO lower complex types", .{});
    if (ty.isInt()) {
        const bits = ty.bitSizeof(c.comp).?;
        key = .{ .int_ty = @intCast(bits) };
    } else if (ty.isFloat()) {
        const bits = ty.bitSizeof(c.comp).?;
        key = .{ .float_ty = @intCast(bits) };
    } else if (ty.isArray()) {
        const elem = try c.genType(ty.elemType());
        key = .{ .array_ty = .{ .child = elem, .len = ty.arrayLen().? } };
    } else if (ty.specifier == .vector) {
        const elem = try c.genType(ty.elemType());
        key = .{ .vector_ty = .{ .child = elem, .len = @intCast(ty.data.array.len) } };
    } else if (ty.is(.nullptr_t)) {
        return c.fail("TODO lower nullptr_t", .{});
    }
    return c.builder.interner.put(c.builder.gpa, key);
}

fn genFn(c: *CodeGen, decl: NodeIndex) Error!void {
    const name = c.tree.tokSlice(c.node_data[@intFromEnum(decl)].decl.name);
    const func_ty = c.node_ty[@intFromEnum(decl)].canonicalize(.standard);
    c.ret_nodes.items.len = 0;

    try c.builder.startFn();

    for (func_ty.data.func.params) |param| {
        // TODO handle calling convention here
        const arg = try c.builder.addArg(try c.genType(param.ty));

        const size: u32 = @intCast(param.ty.sizeof(c.comp).?); // TODO add error in parser
        const @"align" = param.ty.alignof(c.comp);
        const alloc = try c.builder.addAlloc(size, @"align");
        try c.builder.addStore(alloc, arg);
        try c.symbols.append(c.comp.gpa, .{ .name = param.name, .val = alloc });
    }

    // Generate body
    c.return_label = try c.builder.makeLabel("return");
    try c.genStmt(c.node_data[@intFromEnum(decl)].decl.node);

    // Relocate returns
    if (c.ret_nodes.items.len == 0) {
        _ = try c.builder.addInst(.ret, .{ .un = .none }, .noreturn);
    } else if (c.ret_nodes.items.len == 1) {
        c.builder.body.items.len -= 1;
        _ = try c.builder.addInst(.ret, .{ .un = c.ret_nodes.items[0].value }, .noreturn);
    } else {
        try c.builder.startBlock(c.return_label);
        const phi = try c.builder.addPhi(c.ret_nodes.items, try c.genType(func_ty.returnType()));
        _ = try c.builder.addInst(.ret, .{ .un = phi }, .noreturn);
    }

    try c.builder.finishFn(name);
}

fn addUn(c: *CodeGen, tag: Ir.Inst.Tag, operand: Ir.Ref, ty: Type) !Ir.Ref {
    return c.builder.addInst(tag, .{ .un = operand }, try c.genType(ty));
}

fn addBin(c: *CodeGen, tag: Ir.Inst.Tag, lhs: Ir.Ref, rhs: Ir.Ref, ty: Type) !Ir.Ref {
    return c.builder.addInst(tag, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, try c.genType(ty));
}

fn addBranch(c: *CodeGen, cond: Ir.Ref, true_label: Ir.Ref, false_label: Ir.Ref) !void {
    if (true_label == c.bool_end_label) {
        if (false_label == c.bool_end_label) {
            try c.phi_nodes.append(c.comp.gpa, .{ .label = c.builder.current_label, .value = cond });
            return;
        }
        try c.addBoolPhi(!c.bool_invert);
    }
    if (false_label == c.bool_end_label) {
        try c.addBoolPhi(c.bool_invert);
    }
    return c.builder.addBranch(cond, true_label, false_label);
}

fn addBoolPhi(c: *CodeGen, value: bool) !void {
    const val = try c.builder.addConstant((try Value.int(@intFromBool(value), c.comp)).ref(), .i1);
    try c.phi_nodes.append(c.comp.gpa, .{ .label = c.builder.current_label, .value = val });
}

fn genStmt(c: *CodeGen, node: NodeIndex) Error!void {
    _ = try c.genExpr(node);
}

fn genExpr(c: *CodeGen, node: NodeIndex) Error!Ir.Ref {
    std.debug.assert(node != .none);
    const ty = c.node_ty[@intFromEnum(node)];
    if (c.tree.value_map.get(node)) |val| {
        return c.builder.addConstant(val.ref(), try c.genType(ty));
    }
    const data = c.node_data[@intFromEnum(node)];
    switch (c.node_tag[@intFromEnum(node)]) {
        .enumeration_ref,
        .bool_literal,
        .int_literal,
        .char_literal,
        .float_literal,
        .imaginary_literal,
        .string_literal_expr,
        .alignof_expr,
        => unreachable, // These should have an entry in value_map.
        .fn_def,
        .static_fn_def,
        .inline_fn_def,
        .inline_static_fn_def,
        .invalid,
        .threadlocal_var,
        => unreachable,
        .static_assert,
        .fn_proto,
        .static_fn_proto,
        .inline_fn_proto,
        .inline_static_fn_proto,
        .extern_var,
        .threadlocal_extern_var,
        .typedef,
        .struct_decl_two,
        .union_decl_two,
        .enum_decl_two,
        .struct_decl,
        .union_decl,
        .enum_decl,
        .enum_field_decl,
        .record_field_decl,
        .indirect_record_field_decl,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        .null_stmt,
        => {},
        .static_var,
        .implicit_static_var,
        .threadlocal_static_var,
        => try c.genVar(node), // TODO
        .@"var" => {
            const size: u32 = @intCast(ty.sizeof(c.comp).?); // TODO add error in parser
            const @"align" = ty.alignof(c.comp);
            const alloc = try c.builder.addAlloc(size, @"align");
            const name = try StrInt.intern(c.comp, c.tree.tokSlice(data.decl.name));
            try c.symbols.append(c.comp.gpa, .{ .name = name, .val = alloc });
            if (data.decl.node != .none) {
                try c.genInitializer(alloc, ty, data.decl.node);
            }
        },
        .labeled_stmt => {
            const label = try c.builder.makeLabel("label");
            try c.builder.startBlock(label);
            try c.genStmt(data.decl.node);
        },
        .compound_stmt_two => {
            const old_sym_len = c.symbols.items.len;
            c.symbols.items.len = old_sym_len;

            if (data.bin.lhs != .none) try c.genStmt(data.bin.lhs);
            if (data.bin.rhs != .none) try c.genStmt(data.bin.rhs);
        },
        .compound_stmt => {
            const old_sym_len = c.symbols.items.len;
            c.symbols.items.len = old_sym_len;

            for (c.tree.data[data.range.start..data.range.end]) |stmt| try c.genStmt(stmt);
        },
        .if_then_else_stmt => {
            const then_label = try c.builder.makeLabel("if.then");
            const else_label = try c.builder.makeLabel("if.else");
            const end_label = try c.builder.makeLabel("if.end");

            try c.genBoolExpr(data.if3.cond, then_label, else_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(c.tree.data[data.if3.body]); // then
            try c.builder.addJump(end_label);

            try c.builder.startBlock(else_label);
            try c.genStmt(c.tree.data[data.if3.body + 1]); // else

            try c.builder.startBlock(end_label);
        },
        .if_then_stmt => {
            const then_label = try c.builder.makeLabel("if.then");
            const end_label = try c.builder.makeLabel("if.end");

            try c.genBoolExpr(data.bin.lhs, then_label, end_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(data.bin.rhs); // then
            try c.builder.startBlock(end_label);
        },
        .switch_stmt => {
            var wip_switch = WipSwitch{
                .size = c.node_ty[@intFromEnum(data.bin.lhs)].sizeof(c.comp).?,
            };
            defer wip_switch.cases.deinit(c.builder.gpa);

            const old_wip_switch = c.wip_switch;
            defer c.wip_switch = old_wip_switch;
            c.wip_switch = &wip_switch;

            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;
            const end_ref = try c.builder.makeLabel("switch.end");
            c.break_label = end_ref;

            const cond = try c.genExpr(data.bin.lhs);
            const switch_index = c.builder.instructions.len;
            _ = try c.builder.addInst(.@"switch", undefined, .noreturn);

            try c.genStmt(data.bin.rhs); // body

            const default_ref = wip_switch.default orelse end_ref;
            try c.builder.startBlock(end_ref);

            const a = c.builder.arena.allocator();
            const switch_data = try a.create(Ir.Inst.Switch);
            switch_data.* = .{
                .target = cond,
                .cases_len = @intCast(wip_switch.cases.len),
                .case_vals = (try a.dupe(Interner.Ref, wip_switch.cases.items(.val))).ptr,
                .case_labels = (try a.dupe(Ir.Ref, wip_switch.cases.items(.label))).ptr,
                .default = default_ref,
            };
            c.builder.instructions.items(.data)[switch_index] = .{ .@"switch" = switch_data };
        },
        .case_stmt => {
            const val = c.tree.value_map.get(data.bin.lhs).?;
            const label = try c.builder.makeLabel("case");
            try c.builder.startBlock(label);
            try c.wip_switch.cases.append(c.builder.gpa, .{
                .val = val.ref(),
                .label = label,
            });
            try c.genStmt(data.bin.rhs);
        },
        .default_stmt => {
            const default = try c.builder.makeLabel("default");
            try c.builder.startBlock(default);
            c.wip_switch.default = default;
            try c.genStmt(data.un);
        },
        .while_stmt => {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            const cond_label = try c.builder.makeLabel("while.cond");
            const then_label = try c.builder.makeLabel("while.then");
            const end_label = try c.builder.makeLabel("while.end");

            c.continue_label = cond_label;
            c.break_label = end_label;

            try c.builder.startBlock(cond_label);
            try c.genBoolExpr(data.bin.lhs, then_label, end_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(data.bin.rhs);
            try c.builder.addJump(cond_label);
            try c.builder.startBlock(end_label);
        },
        .do_while_stmt => {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            const then_label = try c.builder.makeLabel("do.then");
            const cond_label = try c.builder.makeLabel("do.cond");
            const end_label = try c.builder.makeLabel("do.end");

            c.continue_label = cond_label;
            c.break_label = end_label;

            try c.builder.startBlock(then_label);
            try c.genStmt(data.bin.rhs);

            try c.builder.startBlock(cond_label);
            try c.genBoolExpr(data.bin.lhs, then_label, end_label);

            try c.builder.startBlock(end_label);
        },
        .for_decl_stmt => {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            const for_decl = data.forDecl(&c.tree);
            for (for_decl.decls) |decl| try c.genStmt(decl);

            const then_label = try c.builder.makeLabel("for.then");
            var cond_label = then_label;
            const cont_label = try c.builder.makeLabel("for.cont");
            const end_label = try c.builder.makeLabel("for.end");

            c.continue_label = cont_label;
            c.break_label = end_label;

            if (for_decl.cond != .none) {
                cond_label = try c.builder.makeLabel("for.cond");
                try c.builder.startBlock(cond_label);
                try c.genBoolExpr(for_decl.cond, then_label, end_label);
            }
            try c.builder.startBlock(then_label);
            try c.genStmt(for_decl.body);
            if (for_decl.incr != .none) {
                _ = try c.genExpr(for_decl.incr);
            }
            try c.builder.addJump(cond_label);
            try c.builder.startBlock(end_label);
        },
        .forever_stmt => {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            const then_label = try c.builder.makeLabel("for.then");
            const end_label = try c.builder.makeLabel("for.end");

            c.continue_label = then_label;
            c.break_label = end_label;

            try c.builder.startBlock(then_label);
            try c.genStmt(data.un);
            try c.builder.startBlock(end_label);
        },
        .for_stmt => {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            const for_stmt = data.forStmt(&c.tree);
            if (for_stmt.init != .none) _ = try c.genExpr(for_stmt.init);

            const then_label = try c.builder.makeLabel("for.then");
            var cond_label = then_label;
            const cont_label = try c.builder.makeLabel("for.cont");
            const end_label = try c.builder.makeLabel("for.end");

            c.continue_label = cont_label;
            c.break_label = end_label;

            if (for_stmt.cond != .none) {
                cond_label = try c.builder.makeLabel("for.cond");
                try c.builder.startBlock(cond_label);
                try c.genBoolExpr(for_stmt.cond, then_label, end_label);
            }
            try c.builder.startBlock(then_label);
            try c.genStmt(for_stmt.body);
            if (for_stmt.incr != .none) {
                _ = try c.genExpr(for_stmt.incr);
            }
            try c.builder.addJump(cond_label);
            try c.builder.startBlock(end_label);
        },
        .continue_stmt => try c.builder.addJump(c.continue_label),
        .break_stmt => try c.builder.addJump(c.break_label),
        .return_stmt => {
            if (data.un != .none) {
                const operand = try c.genExpr(data.un);
                try c.ret_nodes.append(c.comp.gpa, .{ .value = operand, .label = c.builder.current_label });
            }
            try c.builder.addJump(c.return_label);
        },
        .implicit_return => {
            if (data.return_zero) {
                const operand = try c.builder.addConstant(.zero, try c.genType(ty));
                try c.ret_nodes.append(c.comp.gpa, .{ .value = operand, .label = c.builder.current_label });
            }
            // No need to emit a jump since implicit_return is always the last instruction.
        },
        .case_range_stmt,
        .goto_stmt,
        .computed_goto_stmt,
        .nullptr_literal,
        => return c.fail("TODO CodeGen.genStmt {}\n", .{c.node_tag[@intFromEnum(node)]}),
        .comma_expr => {
            _ = try c.genExpr(data.bin.lhs);
            return c.genExpr(data.bin.rhs);
        },
        .assign_expr => {
            const rhs = try c.genExpr(data.bin.rhs);
            const lhs = try c.genLval(data.bin.lhs);
            try c.builder.addStore(lhs, rhs);
            return rhs;
        },
        .mul_assign_expr => return c.genCompoundAssign(node, .mul),
        .div_assign_expr => return c.genCompoundAssign(node, .div),
        .mod_assign_expr => return c.genCompoundAssign(node, .mod),
        .add_assign_expr => return c.genCompoundAssign(node, .add),
        .sub_assign_expr => return c.genCompoundAssign(node, .sub),
        .shl_assign_expr => return c.genCompoundAssign(node, .bit_shl),
        .shr_assign_expr => return c.genCompoundAssign(node, .bit_shr),
        .bit_and_assign_expr => return c.genCompoundAssign(node, .bit_and),
        .bit_xor_assign_expr => return c.genCompoundAssign(node, .bit_xor),
        .bit_or_assign_expr => return c.genCompoundAssign(node, .bit_or),
        .bit_or_expr => return c.genBinOp(node, .bit_or),
        .bit_xor_expr => return c.genBinOp(node, .bit_xor),
        .bit_and_expr => return c.genBinOp(node, .bit_and),
        .equal_expr => {
            const cmp = try c.genComparison(node, .cmp_eq);
            return c.addUn(.zext, cmp, ty);
        },
        .not_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_ne);
            return c.addUn(.zext, cmp, ty);
        },
        .less_than_expr => {
            const cmp = try c.genComparison(node, .cmp_lt);
            return c.addUn(.zext, cmp, ty);
        },
        .less_than_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_lte);
            return c.addUn(.zext, cmp, ty);
        },
        .greater_than_expr => {
            const cmp = try c.genComparison(node, .cmp_gt);
            return c.addUn(.zext, cmp, ty);
        },
        .greater_than_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_gte);
            return c.addUn(.zext, cmp, ty);
        },
        .shl_expr => return c.genBinOp(node, .bit_shl),
        .shr_expr => return c.genBinOp(node, .bit_shr),
        .add_expr => {
            if (ty.isPtr()) {
                const lhs_ty = c.node_ty[@intFromEnum(data.bin.lhs)];
                if (lhs_ty.isPtr()) {
                    const ptr = try c.genExpr(data.bin.lhs);
                    const offset = try c.genExpr(data.bin.rhs);
                    const offset_ty = c.node_ty[@intFromEnum(data.bin.rhs)];
                    return c.genPtrArithmetic(ptr, offset, offset_ty, ty);
                } else {
                    const offset = try c.genExpr(data.bin.lhs);
                    const ptr = try c.genExpr(data.bin.rhs);
                    const offset_ty = lhs_ty;
                    return c.genPtrArithmetic(ptr, offset, offset_ty, ty);
                }
            }
            return c.genBinOp(node, .add);
        },
        .sub_expr => {
            if (ty.isPtr()) {
                const ptr = try c.genExpr(data.bin.lhs);
                const offset = try c.genExpr(data.bin.rhs);
                const offset_ty = c.node_ty[@intFromEnum(data.bin.rhs)];
                return c.genPtrArithmetic(ptr, offset, offset_ty, ty);
            }
            return c.genBinOp(node, .sub);
        },
        .mul_expr => return c.genBinOp(node, .mul),
        .div_expr => return c.genBinOp(node, .div),
        .mod_expr => return c.genBinOp(node, .mod),
        .addr_of_expr => return try c.genLval(data.un),
        .deref_expr => {
            const un_data = c.node_data[@intFromEnum(data.un)];
            if (c.node_tag[@intFromEnum(data.un)] == .implicit_cast and un_data.cast.kind == .function_to_pointer) {
                return c.genExpr(data.un);
            }
            const operand = try c.genLval(data.un);
            return c.addUn(.load, operand, ty);
        },
        .plus_expr => return c.genExpr(data.un),
        .negate_expr => {
            const zero = try c.builder.addConstant(.zero, try c.genType(ty));
            const operand = try c.genExpr(data.un);
            return c.addBin(.sub, zero, operand, ty);
        },
        .bit_not_expr => {
            const operand = try c.genExpr(data.un);
            return c.addUn(.bit_not, operand, ty);
        },
        .bool_not_expr => {
            const zero = try c.builder.addConstant(.zero, try c.genType(ty));
            const operand = try c.genExpr(data.un);
            return c.addBin(.cmp_ne, zero, operand, ty);
        },
        .pre_inc_expr => {
            const operand = try c.genLval(data.un);
            const val = try c.addUn(.load, operand, ty);
            const one = try c.builder.addConstant(.one, try c.genType(ty));
            const plus_one = try c.addBin(.add, val, one, ty);
            try c.builder.addStore(operand, plus_one);
            return plus_one;
        },
        .pre_dec_expr => {
            const operand = try c.genLval(data.un);
            const val = try c.addUn(.load, operand, ty);
            const one = try c.builder.addConstant(.one, try c.genType(ty));
            const plus_one = try c.addBin(.sub, val, one, ty);
            try c.builder.addStore(operand, plus_one);
            return plus_one;
        },
        .post_inc_expr => {
            const operand = try c.genLval(data.un);
            const val = try c.addUn(.load, operand, ty);
            const one = try c.builder.addConstant(.one, try c.genType(ty));
            const plus_one = try c.addBin(.add, val, one, ty);
            try c.builder.addStore(operand, plus_one);
            return val;
        },
        .post_dec_expr => {
            const operand = try c.genLval(data.un);
            const val = try c.addUn(.load, operand, ty);
            const one = try c.builder.addConstant(.one, try c.genType(ty));
            const plus_one = try c.addBin(.sub, val, one, ty);
            try c.builder.addStore(operand, plus_one);
            return val;
        },
        .paren_expr => return c.genExpr(data.un),
        .decl_ref_expr => unreachable, // Lval expression.
        .explicit_cast, .implicit_cast => switch (data.cast.kind) {
            .no_op => return c.genExpr(data.cast.operand),
            .to_void => {
                _ = try c.genExpr(data.cast.operand);
                return .none;
            },
            .lval_to_rval => {
                const operand = try c.genLval(data.cast.operand);
                return c.addUn(.load, operand, ty);
            },
            .function_to_pointer, .array_to_pointer => {
                return c.genLval(data.cast.operand);
            },
            .int_cast => {
                const operand = try c.genExpr(data.cast.operand);
                const src_ty = c.node_ty[@intFromEnum(data.cast.operand)];
                const src_bits = src_ty.bitSizeof(c.comp).?;
                const dest_bits = ty.bitSizeof(c.comp).?;
                if (src_bits == dest_bits) {
                    return operand;
                } else if (src_bits < dest_bits) {
                    if (src_ty.isUnsignedInt(c.comp))
                        return c.addUn(.zext, operand, ty)
                    else
                        return c.addUn(.sext, operand, ty);
                } else {
                    return c.addUn(.trunc, operand, ty);
                }
            },
            .bool_to_int => {
                const operand = try c.genExpr(data.cast.operand);
                return c.addUn(.zext, operand, ty);
            },
            .pointer_to_bool, .int_to_bool, .float_to_bool => {
                const lhs = try c.genExpr(data.cast.operand);
                const rhs = try c.builder.addConstant(.zero, try c.genType(c.node_ty[@intFromEnum(node)]));
                return c.builder.addInst(.cmp_ne, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, .i1);
            },
            .bitcast,
            .pointer_to_int,
            .bool_to_float,
            .bool_to_pointer,
            .int_to_float,
            .complex_int_to_complex_float,
            .int_to_pointer,
            .float_to_int,
            .complex_float_to_complex_int,
            .complex_int_cast,
            .complex_int_to_real,
            .real_to_complex_int,
            .float_cast,
            .complex_float_cast,
            .complex_float_to_real,
            .real_to_complex_float,
            .null_to_pointer,
            .union_cast,
            .vector_splat,
            => return c.fail("TODO CodeGen gen CastKind {}\n", .{data.cast.kind}),
        },
        .binary_cond_expr => {
            if (c.tree.value_map.get(data.if3.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    c.cond_dummy_ref = try c.genExpr(data.if3.cond);
                    return c.genExpr(c.tree.data[data.if3.body]); // then
                } else {
                    return c.genExpr(c.tree.data[data.if3.body + 1]); // else
                }
            }

            const then_label = try c.builder.makeLabel("ternary.then");
            const else_label = try c.builder.makeLabel("ternary.else");
            const end_label = try c.builder.makeLabel("ternary.end");
            const cond_ty = c.node_ty[@intFromEnum(data.if3.cond)];
            {
                const old_cond_dummy_ty = c.cond_dummy_ty;
                defer c.cond_dummy_ty = old_cond_dummy_ty;
                c.cond_dummy_ty = try c.genType(cond_ty);

                try c.genBoolExpr(data.if3.cond, then_label, else_label);
            }

            try c.builder.startBlock(then_label);
            if (c.builder.instructions.items(.ty)[@intFromEnum(c.cond_dummy_ref)] == .i1) {
                c.cond_dummy_ref = try c.addUn(.zext, c.cond_dummy_ref, cond_ty);
            }
            const then_val = try c.genExpr(c.tree.data[data.if3.body]); // then
            try c.builder.addJump(end_label);
            const then_exit = c.builder.current_label;

            try c.builder.startBlock(else_label);
            const else_val = try c.genExpr(c.tree.data[data.if3.body + 1]); // else
            const else_exit = c.builder.current_label;

            try c.builder.startBlock(end_label);

            var phi_buf: [2]Ir.Inst.Phi.Input = .{
                .{ .value = then_val, .label = then_exit },
                .{ .value = else_val, .label = else_exit },
            };
            return c.builder.addPhi(&phi_buf, try c.genType(ty));
        },
        .cond_dummy_expr => return c.cond_dummy_ref,
        .cond_expr => {
            if (c.tree.value_map.get(data.if3.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genExpr(c.tree.data[data.if3.body]); // then
                } else {
                    return c.genExpr(c.tree.data[data.if3.body + 1]); // else
                }
            }

            const then_label = try c.builder.makeLabel("ternary.then");
            const else_label = try c.builder.makeLabel("ternary.else");
            const end_label = try c.builder.makeLabel("ternary.end");

            try c.genBoolExpr(data.if3.cond, then_label, else_label);

            try c.builder.startBlock(then_label);
            const then_val = try c.genExpr(c.tree.data[data.if3.body]); // then
            try c.builder.addJump(end_label);
            const then_exit = c.builder.current_label;

            try c.builder.startBlock(else_label);
            const else_val = try c.genExpr(c.tree.data[data.if3.body + 1]); // else
            const else_exit = c.builder.current_label;

            try c.builder.startBlock(end_label);

            var phi_buf: [2]Ir.Inst.Phi.Input = .{
                .{ .value = then_val, .label = then_exit },
                .{ .value = else_val, .label = else_exit },
            };
            return c.builder.addPhi(&phi_buf, try c.genType(ty));
        },
        .call_expr_one => if (data.bin.rhs == .none) {
            return c.genCall(data.bin.lhs, &.{}, ty);
        } else {
            return c.genCall(data.bin.lhs, &.{data.bin.rhs}, ty);
        },
        .call_expr => {
            return c.genCall(c.tree.data[data.range.start], c.tree.data[data.range.start + 1 .. data.range.end], ty);
        },
        .bool_or_expr => {
            if (c.tree.value_map.get(data.bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    return c.builder.addConstant(.one, try c.genType(ty));
                }
                return c.genExpr(data.bin.rhs);
            }

            const false_label = try c.builder.makeLabel("bool_false");
            const exit_label = try c.builder.makeLabel("bool_exit");

            const old_bool_end_label = c.bool_end_label;
            defer c.bool_end_label = old_bool_end_label;
            c.bool_end_label = exit_label;

            const phi_nodes_top = c.phi_nodes.items.len;
            defer c.phi_nodes.items.len = phi_nodes_top;

            try c.genBoolExpr(data.bin.lhs, exit_label, false_label);

            try c.builder.startBlock(false_label);
            try c.genBoolExpr(data.bin.rhs, exit_label, exit_label);

            try c.builder.startBlock(exit_label);

            const phi = try c.builder.addPhi(c.phi_nodes.items[phi_nodes_top..], .i1);
            return c.addUn(.zext, phi, ty);
        },
        .bool_and_expr => {
            if (c.tree.value_map.get(data.bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    return c.builder.addConstant(.zero, try c.genType(ty));
                }
                return c.genExpr(data.bin.rhs);
            }

            const true_label = try c.builder.makeLabel("bool_true");
            const exit_label = try c.builder.makeLabel("bool_exit");

            const old_bool_end_label = c.bool_end_label;
            defer c.bool_end_label = old_bool_end_label;
            c.bool_end_label = exit_label;

            const phi_nodes_top = c.phi_nodes.items.len;
            defer c.phi_nodes.items.len = phi_nodes_top;

            try c.genBoolExpr(data.bin.lhs, true_label, exit_label);

            try c.builder.startBlock(true_label);
            try c.genBoolExpr(data.bin.rhs, exit_label, exit_label);

            try c.builder.startBlock(exit_label);

            const phi = try c.builder.addPhi(c.phi_nodes.items[phi_nodes_top..], .i1);
            return c.addUn(.zext, phi, ty);
        },
        .builtin_choose_expr => {
            const cond = c.tree.value_map.get(data.if3.cond).?;
            if (cond.toBool(c.comp)) {
                return c.genExpr(c.tree.data[data.if3.body]);
            } else {
                return c.genExpr(c.tree.data[data.if3.body + 1]);
            }
        },
        .generic_expr_one => {
            const index = @intFromEnum(data.bin.rhs);
            switch (c.node_tag[index]) {
                .generic_association_expr, .generic_default_expr => {
                    return c.genExpr(c.node_data[index].un);
                },
                else => unreachable,
            }
        },
        .generic_expr => {
            const index = @intFromEnum(c.tree.data[data.range.start + 1]);
            switch (c.node_tag[index]) {
                .generic_association_expr, .generic_default_expr => {
                    return c.genExpr(c.node_data[index].un);
                },
                else => unreachable,
            }
        },
        .generic_association_expr, .generic_default_expr => unreachable,
        .stmt_expr => switch (c.node_tag[@intFromEnum(data.un)]) {
            .compound_stmt_two => {
                const old_sym_len = c.symbols.items.len;
                c.symbols.items.len = old_sym_len;

                const stmt_data = c.node_data[@intFromEnum(data.un)];
                if (stmt_data.bin.rhs == .none) return c.genExpr(stmt_data.bin.lhs);
                try c.genStmt(stmt_data.bin.lhs);
                return c.genExpr(stmt_data.bin.rhs);
            },
            .compound_stmt => {
                const old_sym_len = c.symbols.items.len;
                c.symbols.items.len = old_sym_len;

                const stmt_data = c.node_data[@intFromEnum(data.un)];
                for (c.tree.data[stmt_data.range.start .. stmt_data.range.end - 1]) |stmt| try c.genStmt(stmt);
                return c.genExpr(c.tree.data[stmt_data.range.end]);
            },
            else => unreachable,
        },
        .builtin_call_expr_one => {
            const name = c.tree.tokSlice(data.decl.name);
            const builtin = c.comp.builtins.lookup(name).builtin;
            if (data.decl.node == .none) {
                return c.genBuiltinCall(builtin, &.{}, ty);
            } else {
                return c.genBuiltinCall(builtin, &.{data.decl.node}, ty);
            }
        },
        .builtin_call_expr => {
            const name_node_idx = c.tree.data[data.range.start];
            const name = c.tree.tokSlice(@intFromEnum(name_node_idx));
            const builtin = c.comp.builtins.lookup(name).builtin;
            return c.genBuiltinCall(builtin, c.tree.data[data.range.start + 1 .. data.range.end], ty);
        },
        .addr_of_label,
        .imag_expr,
        .real_expr,
        .sizeof_expr,
        .special_builtin_call_one,
        => return c.fail("TODO CodeGen.genExpr {}\n", .{c.node_tag[@intFromEnum(node)]}),
        else => unreachable, // Not an expression.
    }
    return .none;
}

fn genLval(c: *CodeGen, node: NodeIndex) Error!Ir.Ref {
    std.debug.assert(node != .none);
    assert(c.tree.isLval(node));
    const data = c.node_data[@intFromEnum(node)];
    switch (c.node_tag[@intFromEnum(node)]) {
        .string_literal_expr => {
            const val = c.tree.value_map.get(node).?;
            return c.builder.addConstant(val.ref(), .ptr);
        },
        .paren_expr => return c.genLval(data.un),
        .decl_ref_expr => {
            const slice = c.tree.tokSlice(data.decl_ref);
            const name = try StrInt.intern(c.comp, slice);
            var i = c.symbols.items.len;
            while (i > 0) {
                i -= 1;
                if (c.symbols.items[i].name == name) {
                    return c.symbols.items[i].val;
                }
            }

            const duped_name = try c.builder.arena.allocator().dupeZ(u8, slice);
            const ref: Ir.Ref = @enumFromInt(c.builder.instructions.len);
            try c.builder.instructions.append(c.builder.gpa, .{ .tag = .symbol, .data = .{ .label = duped_name }, .ty = .ptr });
            return ref;
        },
        .deref_expr => return c.genExpr(data.un),
        .compound_literal_expr => {
            const ty = c.node_ty[@intFromEnum(node)];
            const size: u32 = @intCast(ty.sizeof(c.comp).?); // TODO add error in parser
            const @"align" = ty.alignof(c.comp);
            const alloc = try c.builder.addAlloc(size, @"align");
            try c.genInitializer(alloc, ty, data.un);
            return alloc;
        },
        .builtin_choose_expr => {
            const cond = c.tree.value_map.get(data.if3.cond).?;
            if (cond.toBool(c.comp)) {
                return c.genLval(c.tree.data[data.if3.body]);
            } else {
                return c.genLval(c.tree.data[data.if3.body + 1]);
            }
        },
        .member_access_expr,
        .member_access_ptr_expr,
        .array_access_expr,
        .static_compound_literal_expr,
        .thread_local_compound_literal_expr,
        .static_thread_local_compound_literal_expr,
        => return c.fail("TODO CodeGen.genLval {}\n", .{c.node_tag[@intFromEnum(node)]}),
        else => unreachable, // Not an lval expression.
    }
}

fn genBoolExpr(c: *CodeGen, base: NodeIndex, true_label: Ir.Ref, false_label: Ir.Ref) Error!void {
    var node = base;
    while (true) switch (c.node_tag[@intFromEnum(node)]) {
        .paren_expr => {
            node = c.node_data[@intFromEnum(node)].un;
        },
        else => break,
    };

    const data = c.node_data[@intFromEnum(node)];
    switch (c.node_tag[@intFromEnum(node)]) {
        .bool_or_expr => {
            if (c.tree.value_map.get(data.bin.lhs)) |lhs| {
                if (lhs.toBool(c.comp)) {
                    if (true_label == c.bool_end_label) {
                        return c.addBoolPhi(!c.bool_invert);
                    }
                    return c.builder.addJump(true_label);
                }
                return c.genBoolExpr(data.bin.rhs, true_label, false_label);
            }

            const new_false_label = try c.builder.makeLabel("bool_false");
            try c.genBoolExpr(data.bin.lhs, true_label, new_false_label);
            try c.builder.startBlock(new_false_label);

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(data.bin.rhs, true_label, false_label);
        },
        .bool_and_expr => {
            if (c.tree.value_map.get(data.bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    if (false_label == c.bool_end_label) {
                        return c.addBoolPhi(c.bool_invert);
                    }
                    return c.builder.addJump(false_label);
                }
                return c.genBoolExpr(data.bin.rhs, true_label, false_label);
            }

            const new_true_label = try c.builder.makeLabel("bool_true");
            try c.genBoolExpr(data.bin.lhs, new_true_label, false_label);
            try c.builder.startBlock(new_true_label);

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(data.bin.rhs, true_label, false_label);
        },
        .bool_not_expr => {
            c.bool_invert = !c.bool_invert;
            defer c.bool_invert = !c.bool_invert;

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.zero, ty);
            return c.genBoolExpr(data.un, false_label, true_label);
        },
        .equal_expr => {
            const cmp = try c.genComparison(node, .cmp_eq);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .not_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_ne);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .less_than_expr => {
            const cmp = try c.genComparison(node, .cmp_lt);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .less_than_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_lte);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .greater_than_expr => {
            const cmp = try c.genComparison(node, .cmp_gt);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .greater_than_equal_expr => {
            const cmp = try c.genComparison(node, .cmp_gte);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .explicit_cast, .implicit_cast => switch (data.cast.kind) {
            .bool_to_int => {
                const operand = try c.genExpr(data.cast.operand);
                if (c.cond_dummy_ty != null) c.cond_dummy_ref = operand;
                return c.addBranch(operand, true_label, false_label);
            },
            else => {},
        },
        .binary_cond_expr => {
            if (c.tree.value_map.get(data.if3.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genBoolExpr(c.tree.data[data.if3.body], true_label, false_label); // then
                } else {
                    return c.genBoolExpr(c.tree.data[data.if3.body + 1], true_label, false_label); // else
                }
            }

            const new_false_label = try c.builder.makeLabel("ternary.else");
            try c.genBoolExpr(data.if3.cond, true_label, new_false_label);

            try c.builder.startBlock(new_false_label);
            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(c.tree.data[data.if3.body + 1], true_label, false_label); // else
        },
        .cond_expr => {
            if (c.tree.value_map.get(data.if3.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genBoolExpr(c.tree.data[data.if3.body], true_label, false_label); // then
                } else {
                    return c.genBoolExpr(c.tree.data[data.if3.body + 1], true_label, false_label); // else
                }
            }

            const new_true_label = try c.builder.makeLabel("ternary.then");
            const new_false_label = try c.builder.makeLabel("ternary.else");
            try c.genBoolExpr(data.if3.cond, new_true_label, new_false_label);

            try c.builder.startBlock(new_true_label);
            try c.genBoolExpr(c.tree.data[data.if3.body], true_label, false_label); // then
            try c.builder.startBlock(new_false_label);
            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(c.tree.data[data.if3.body + 1], true_label, false_label); // else
        },
        else => {},
    }

    if (c.tree.value_map.get(node)) |value| {
        if (value.toBool(c.comp)) {
            if (true_label == c.bool_end_label) {
                return c.addBoolPhi(!c.bool_invert);
            }
            return c.builder.addJump(true_label);
        } else {
            if (false_label == c.bool_end_label) {
                return c.addBoolPhi(c.bool_invert);
            }
            return c.builder.addJump(false_label);
        }
    }

    // Assume int operand.
    const lhs = try c.genExpr(node);
    const rhs = try c.builder.addConstant(.zero, try c.genType(c.node_ty[@intFromEnum(node)]));
    const cmp = try c.builder.addInst(.cmp_ne, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, .i1);
    if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
    try c.addBranch(cmp, true_label, false_label);
}

fn genBuiltinCall(c: *CodeGen, builtin: Builtin, arg_nodes: []const NodeIndex, ty: Type) Error!Ir.Ref {
    _ = arg_nodes;
    _ = ty;
    return c.fail("TODO CodeGen.genBuiltinCall {s}\n", .{Builtin.nameFromTag(builtin.tag).span()});
}

fn genCall(c: *CodeGen, fn_node: NodeIndex, arg_nodes: []const NodeIndex, ty: Type) Error!Ir.Ref {
    // Detect direct calls.
    const fn_ref = blk: {
        const data = c.node_data[@intFromEnum(fn_node)];
        if (c.node_tag[@intFromEnum(fn_node)] != .implicit_cast or data.cast.kind != .function_to_pointer) {
            break :blk try c.genExpr(fn_node);
        }

        var cur = @intFromEnum(data.cast.operand);
        while (true) switch (c.node_tag[cur]) {
            .paren_expr, .addr_of_expr, .deref_expr => {
                cur = @intFromEnum(c.node_data[cur].un);
            },
            .implicit_cast => {
                const cast = c.node_data[cur].cast;
                if (cast.kind != .function_to_pointer) {
                    break :blk try c.genExpr(fn_node);
                }
                cur = @intFromEnum(cast.operand);
            },
            .decl_ref_expr => {
                const slice = c.tree.tokSlice(c.node_data[cur].decl_ref);
                const name = try StrInt.intern(c.comp, slice);
                var i = c.symbols.items.len;
                while (i > 0) {
                    i -= 1;
                    if (c.symbols.items[i].name == name) {
                        break :blk try c.genExpr(fn_node);
                    }
                }

                const duped_name = try c.builder.arena.allocator().dupeZ(u8, slice);
                const ref: Ir.Ref = @enumFromInt(c.builder.instructions.len);
                try c.builder.instructions.append(c.builder.gpa, .{ .tag = .symbol, .data = .{ .label = duped_name }, .ty = .ptr });
                break :blk ref;
            },
            else => break :blk try c.genExpr(fn_node),
        };
    };

    const args = try c.builder.arena.allocator().alloc(Ir.Ref, arg_nodes.len);
    for (arg_nodes, args) |node, *arg| {
        // TODO handle calling convention here
        arg.* = try c.genExpr(node);
    }
    // TODO handle variadic call
    const call = try c.builder.arena.allocator().create(Ir.Inst.Call);
    call.* = .{
        .func = fn_ref,
        .args_len = @intCast(args.len),
        .args_ptr = args.ptr,
    };
    return c.builder.addInst(.call, .{ .call = call }, try c.genType(ty));
}

fn genCompoundAssign(c: *CodeGen, node: NodeIndex, tag: Ir.Inst.Tag) Error!Ir.Ref {
    const bin = c.node_data[@intFromEnum(node)].bin;
    const ty = c.node_ty[@intFromEnum(node)];
    const rhs = try c.genExpr(bin.rhs);
    const lhs = try c.genLval(bin.lhs);
    const res = try c.addBin(tag, lhs, rhs, ty);
    try c.builder.addStore(lhs, res);
    return res;
}

fn genBinOp(c: *CodeGen, node: NodeIndex, tag: Ir.Inst.Tag) Error!Ir.Ref {
    const bin = c.node_data[@intFromEnum(node)].bin;
    const ty = c.node_ty[@intFromEnum(node)];
    const lhs = try c.genExpr(bin.lhs);
    const rhs = try c.genExpr(bin.rhs);
    return c.addBin(tag, lhs, rhs, ty);
}

fn genComparison(c: *CodeGen, node: NodeIndex, tag: Ir.Inst.Tag) Error!Ir.Ref {
    const bin = c.node_data[@intFromEnum(node)].bin;
    const lhs = try c.genExpr(bin.lhs);
    const rhs = try c.genExpr(bin.rhs);

    return c.builder.addInst(tag, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, .i1);
}

fn genPtrArithmetic(c: *CodeGen, ptr: Ir.Ref, offset: Ir.Ref, offset_ty: Type, ty: Type) Error!Ir.Ref {
    // TODO consider adding a getelemptr instruction
    const size = ty.elemType().sizeof(c.comp).?;
    if (size == 1) {
        return c.builder.addInst(.add, .{ .bin = .{ .lhs = ptr, .rhs = offset } }, try c.genType(ty));
    }

    const size_inst = try c.builder.addConstant((try Value.int(size, c.comp)).ref(), try c.genType(offset_ty));
    const offset_inst = try c.addBin(.mul, offset, size_inst, offset_ty);
    return c.addBin(.add, ptr, offset_inst, offset_ty);
}

fn genInitializer(c: *CodeGen, ptr: Ir.Ref, dest_ty: Type, initializer: NodeIndex) Error!void {
    std.debug.assert(initializer != .none);
    switch (c.node_tag[@intFromEnum(initializer)]) {
        .array_init_expr_two,
        .array_init_expr,
        .struct_init_expr_two,
        .struct_init_expr,
        .union_init_expr,
        .array_filler_expr,
        .default_init_expr,
        => return c.fail("TODO CodeGen.genInitializer {}\n", .{c.node_tag[@intFromEnum(initializer)]}),
        .string_literal_expr => {
            const val = c.tree.value_map.get(initializer).?;
            const str_ptr = try c.builder.addConstant(val.ref(), .ptr);
            if (dest_ty.isArray()) {
                return c.fail("TODO memcpy\n", .{});
            } else {
                try c.builder.addStore(ptr, str_ptr);
            }
        },
        else => {
            const res = try c.genExpr(initializer);
            try c.builder.addStore(ptr, res);
        },
    }
}

fn genVar(c: *CodeGen, decl: NodeIndex) Error!void {
    _ = decl;
    return c.fail("TODO CodeGen.genVar\n", .{});
}
