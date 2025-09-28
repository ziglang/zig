const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const backend = @import("../backend.zig");
const Interner = backend.Interner;
const Ir = backend.Ir;
const Builder = Ir.Builder;

const Builtins = @import("Builtins.zig");
const Builtin = Builtins.Builtin;
const Compilation = @import("Compilation.zig");
const StringId = @import("StringInterner.zig").StringId;
const Tree = @import("Tree.zig");
const Node = Tree.Node;
const QualType = @import("TypeStore.zig").QualType;
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

tree: *const Tree,
comp: *Compilation,
builder: Builder,
wip_switch: *WipSwitch = undefined,
symbols: std.ArrayList(Symbol) = .empty,
ret_nodes: std.ArrayList(Ir.Inst.Phi.Input) = .empty,
phi_nodes: std.ArrayList(Ir.Inst.Phi.Input) = .empty,
record_elem_buf: std.ArrayList(Interner.Ref) = .empty,
record_cache: std.AutoHashMapUnmanaged(QualType, Interner.Ref) = .empty,
cond_dummy_ty: ?Interner.Ref = null,
bool_invert: bool = false,
bool_end_label: Ir.Ref = .none,
cond_dummy_ref: Ir.Ref = undefined,
continue_label: Ir.Ref = undefined,
break_label: Ir.Ref = undefined,
return_label: Ir.Ref = undefined,
compound_assign_dummy: ?Ir.Ref = null,

fn fail(c: *CodeGen, comptime fmt: []const u8, args: anytype) error{ FatalError, OutOfMemory } {
    var sf = std.heap.stackFallback(1024, c.comp.gpa);
    const allocator = sf.get();
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    try buf.print(allocator, fmt, args);
    try c.comp.diagnostics.add(.{ .text = buf.items, .kind = .@"fatal error", .location = null });
    return error.FatalError;
}

pub fn genIr(tree: *const Tree) Compilation.Error!Ir {
    const gpa = tree.comp.gpa;
    var c: CodeGen = .{
        .builder = .{
            .gpa = tree.comp.gpa,
            .interner = &tree.comp.interner,
            .arena = std.heap.ArenaAllocator.init(gpa),
        },
        .tree = tree,
        .comp = tree.comp,
    };
    defer c.symbols.deinit(gpa);
    defer c.ret_nodes.deinit(gpa);
    defer c.phi_nodes.deinit(gpa);
    defer c.record_elem_buf.deinit(gpa);
    defer c.record_cache.deinit(gpa);
    defer c.builder.deinit();

    for (tree.root_decls.items) |decl| {
        c.builder.arena.deinit();
        c.builder.arena = std.heap.ArenaAllocator.init(gpa);

        switch (decl.get(c.tree)) {
            .empty_decl,
            .static_assert,
            .typedef,
            .struct_decl,
            .union_decl,
            .enum_decl,
            .struct_forward_decl,
            .union_forward_decl,
            .enum_forward_decl,
            => {},

            .function => |function| {
                if (function.body == null) continue;
                c.genFn(function) catch |err| switch (err) {
                    error.FatalError => return error.FatalError,
                    error.OutOfMemory => return error.OutOfMemory,
                };
            },

            .variable => |variable| c.genVar(variable) catch |err| switch (err) {
                error.FatalError => return error.FatalError,
                error.OutOfMemory => return error.OutOfMemory,
            },
            else => unreachable,
        }
    }
    return c.builder.finish();
}

fn genType(c: *CodeGen, qt: QualType) !Interner.Ref {
    const base = qt.base(c.comp);
    const key: Interner.Key = switch (base.type) {
        .void => return .void,
        .bool => return .i1,
        .@"struct" => |record| {
            if (c.record_cache.get(base.qt.unqualified())) |some| return some;

            const elem_buf_top = c.record_elem_buf.items.len;
            defer c.record_elem_buf.items.len = elem_buf_top;

            for (record.fields) |field| {
                if (field.bit_width != .null) {
                    return c.fail("TODO lower struct bitfields", .{});
                }
                // TODO handle padding bits
                const field_ref = try c.genType(field.qt);
                try c.record_elem_buf.append(c.builder.gpa, field_ref);
            }

            const recrd_ty = try c.builder.interner.put(c.builder.gpa, .{
                .record_ty = c.record_elem_buf.items[elem_buf_top..],
            });
            try c.record_cache.put(c.comp.gpa, base.qt.unqualified(), recrd_ty);
            return recrd_ty;
        },
        .@"union" => {
            return c.fail("TODO lower union types", .{});
        },
        .pointer => return .ptr,
        .func => return .func,
        .complex => return c.fail("TODO lower complex types", .{}),
        .atomic => return c.fail("TODO lower atomic types", .{}),
        .@"enum" => |@"enum"| return c.genType(@"enum".tag.?),
        .int => |int| .{ .int_ty = int.bits(c.comp) },
        .bit_int => |bit_int| .{ .int_ty = bit_int.bits },
        .float => |float| .{ .float_ty = float.bits(c.comp) },
        .array => |array| blk: {
            switch (array.len) {
                .fixed, .static => |len| {
                    const elem = try c.genType(array.elem);
                    break :blk .{ .array_ty = .{ .child = elem, .len = len } };
                },
                .variable, .unspecified_variable => return c.fail("TODO VLAs", .{}),
                .incomplete => unreachable,
            }
        },
        .vector => |vector| blk: {
            const elem = try c.genType(vector.elem);
            break :blk .{ .vector_ty = .{ .child = elem, .len = vector.len } };
        },
        .nullptr_t => {
            return c.fail("TODO lower nullptr_t", .{});
        },
        .attributed, .typeof, .typedef => unreachable,
    };
    return c.builder.interner.put(c.builder.gpa, key);
}

fn genFn(c: *CodeGen, function: Node.Function) Error!void {
    const name = c.tree.tokSlice(function.name_tok);
    const func_ty = function.qt.base(c.comp).type.func;
    c.ret_nodes.items.len = 0;

    try c.builder.startFn();

    for (func_ty.params) |param| {
        // TODO handle calling convention here
        const arg = try c.builder.addArg(try c.genType(param.qt));

        const size: u32 = @intCast(param.qt.sizeof(c.comp)); // TODO add error in parser
        const @"align" = param.qt.alignof(c.comp);
        const alloc = try c.builder.addAlloc(size, @"align");
        try c.builder.addStore(alloc, arg);
        try c.symbols.append(c.comp.gpa, .{ .name = param.name, .val = alloc });
    }

    // Generate body
    c.return_label = try c.builder.makeLabel("return");
    try c.genStmt(function.body.?);

    // Relocate returns
    if (c.ret_nodes.items.len == 0) {
        _ = try c.builder.addInst(.ret, .{ .un = .none }, .noreturn);
    } else if (c.ret_nodes.items.len == 1) {
        c.builder.body.items.len -= 1;
        _ = try c.builder.addInst(.ret, .{ .un = c.ret_nodes.items[0].value }, .noreturn);
    } else {
        try c.builder.startBlock(c.return_label);
        const phi = try c.builder.addPhi(c.ret_nodes.items, try c.genType(func_ty.return_type));
        _ = try c.builder.addInst(.ret, .{ .un = phi }, .noreturn);
    }

    try c.builder.finishFn(name);
}

fn addUn(c: *CodeGen, tag: Ir.Inst.Tag, operand: Ir.Ref, qt: QualType) !Ir.Ref {
    return c.builder.addInst(tag, .{ .un = operand }, try c.genType(qt));
}

fn addBin(c: *CodeGen, tag: Ir.Inst.Tag, lhs: Ir.Ref, rhs: Ir.Ref, qt: QualType) !Ir.Ref {
    return c.builder.addInst(tag, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, try c.genType(qt));
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

fn genStmt(c: *CodeGen, node: Node.Index) Error!void {
    _ = try c.genExpr(node);
}

fn genExpr(c: *CodeGen, node_index: Node.Index) Error!Ir.Ref {
    if (c.tree.value_map.get(node_index)) |val| {
        return c.builder.addConstant(val.ref(), try c.genType(node_index.qt(c.tree)));
    }
    const node = node_index.get(c.tree);
    switch (node) {
        .enumeration_ref,
        .bool_literal,
        .int_literal,
        .char_literal,
        .float_literal,
        .imaginary_literal,
        .string_literal_expr,
        .alignof_expr,
        => unreachable, // These should have an entry in value_map.
        .static_assert,
        .function,
        .typedef,
        .struct_decl,
        .union_decl,
        .enum_decl,
        .enum_field,
        .record_field,
        .struct_forward_decl,
        .union_forward_decl,
        .enum_forward_decl,
        .null_stmt,
        => {},
        .variable => |variable| {
            if (variable.storage_class == .@"extern" or variable.storage_class == .static) {
                try c.genVar(variable);
                return .none;
            }
            const size: u32 = @intCast(variable.qt.sizeof(c.comp)); // TODO add error in parser
            const @"align" = variable.qt.alignof(c.comp);
            const alloc = try c.builder.addAlloc(size, @"align");
            const name = try c.comp.internString(c.tree.tokSlice(variable.name_tok));
            try c.symbols.append(c.comp.gpa, .{ .name = name, .val = alloc });
            if (variable.initializer) |init| {
                try c.genInitializer(alloc, variable.qt, init);
            }
        },
        .labeled_stmt => |labeled| {
            const label = try c.builder.makeLabel("label");
            try c.builder.startBlock(label);
            try c.genStmt(labeled.body);
        },
        .compound_stmt => |compound| {
            const old_sym_len = c.symbols.items.len;
            c.symbols.items.len = old_sym_len;

            for (compound.body) |stmt| try c.genStmt(stmt);
        },
        .if_stmt => |@"if"| {
            const then_label = try c.builder.makeLabel("if.then");

            const else_body = @"if".else_body orelse {
                const end_label = try c.builder.makeLabel("if.end");
                try c.genBoolExpr(@"if".cond, then_label, end_label);

                try c.builder.startBlock(then_label);
                try c.genStmt(@"if".then_body);
                try c.builder.startBlock(end_label);
                return .none;
            };

            const else_label = try c.builder.makeLabel("if.else");
            const end_label = try c.builder.makeLabel("if.end");

            try c.genBoolExpr(@"if".cond, then_label, else_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(@"if".then_body);
            try c.builder.addJump(end_label);

            try c.builder.startBlock(else_label);
            try c.genStmt(else_body);

            try c.builder.startBlock(end_label);
        },
        .switch_stmt => |@"switch"| {
            var wip_switch = WipSwitch{
                .size = @"switch".cond.qt(c.tree).sizeof(c.comp),
            };
            defer wip_switch.cases.deinit(c.builder.gpa);

            const old_wip_switch = c.wip_switch;
            defer c.wip_switch = old_wip_switch;
            c.wip_switch = &wip_switch;

            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;
            const end_ref = try c.builder.makeLabel("switch.end");
            c.break_label = end_ref;

            const cond = try c.genExpr(@"switch".cond);
            const switch_index = c.builder.instructions.len;
            _ = try c.builder.addInst(.@"switch", undefined, .noreturn);

            try c.genStmt(@"switch".body);

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
        .case_stmt => |case| {
            if (case.end != null) return c.fail("TODO CodeGen.genStmt case range\n", .{});
            const val = c.tree.value_map.get(case.start).?;
            const label = try c.builder.makeLabel("case");
            try c.builder.startBlock(label);
            try c.wip_switch.cases.append(c.builder.gpa, .{
                .val = val.ref(),
                .label = label,
            });
            try c.genStmt(case.body);
        },
        .default_stmt => |default| {
            const default_label = try c.builder.makeLabel("default");
            try c.builder.startBlock(default_label);
            c.wip_switch.default = default_label;
            try c.genStmt(default.body);
        },
        .while_stmt => |@"while"| {
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
            try c.genBoolExpr(@"while".cond, then_label, end_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(@"while".body);
            try c.builder.addJump(cond_label);
            try c.builder.startBlock(end_label);
        },
        .do_while_stmt => |do_while| {
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
            try c.genStmt(do_while.body);

            try c.builder.startBlock(cond_label);
            try c.genBoolExpr(do_while.cond, then_label, end_label);

            try c.builder.startBlock(end_label);
        },
        .for_stmt => |@"for"| {
            const old_break_label = c.break_label;
            defer c.break_label = old_break_label;

            const old_continue_label = c.continue_label;
            defer c.continue_label = old_continue_label;

            switch (@"for".init) {
                .decls => |decls| {
                    for (decls) |decl| try c.genStmt(decl);
                },
                .expr => |maybe_init| {
                    if (maybe_init) |init| _ = try c.genExpr(init);
                },
            }

            const cond = @"for".cond orelse {
                const then_label = try c.builder.makeLabel("for.then");
                const end_label = try c.builder.makeLabel("for.end");

                c.continue_label = then_label;
                c.break_label = end_label;

                try c.builder.startBlock(then_label);
                try c.genStmt(@"for".body);
                if (@"for".incr) |incr| {
                    _ = try c.genExpr(incr);
                }
                try c.builder.addJump(then_label);
                try c.builder.startBlock(end_label);
                return .none;
            };

            const then_label = try c.builder.makeLabel("for.then");
            var cond_label = then_label;
            const cont_label = try c.builder.makeLabel("for.cont");
            const end_label = try c.builder.makeLabel("for.end");

            c.continue_label = cont_label;
            c.break_label = end_label;

            cond_label = try c.builder.makeLabel("for.cond");

            try c.builder.startBlock(cond_label);
            try c.genBoolExpr(cond, then_label, end_label);

            try c.builder.startBlock(then_label);
            try c.genStmt(@"for".body);
            if (@"for".incr) |incr| {
                _ = try c.genExpr(incr);
            }
            try c.builder.addJump(cond_label);
            try c.builder.startBlock(end_label);
        },
        .continue_stmt => try c.builder.addJump(c.continue_label),
        .break_stmt => try c.builder.addJump(c.break_label),
        .return_stmt => |@"return"| {
            switch (@"return".operand) {
                .expr => |expr| {
                    const operand = try c.genExpr(expr);
                    try c.ret_nodes.append(c.comp.gpa, .{ .value = operand, .label = c.builder.current_label });
                },
                .none => {},
                .implicit => |zeroes| {
                    if (zeroes) {
                        const operand = try c.builder.addConstant(.zero, try c.genType(@"return".return_qt));
                        try c.ret_nodes.append(c.comp.gpa, .{ .value = operand, .label = c.builder.current_label });
                    }
                    // No need to emit a jump since an implicit return_stmt is always the last statement.
                    return .none;
                },
            }
            try c.builder.addJump(c.return_label);
        },
        .goto_stmt,
        .computed_goto_stmt,
        .nullptr_literal,
        => return c.fail("TODO CodeGen.genStmt {s}\n", .{@tagName(node)}),
        .comma_expr => |bin| {
            _ = try c.genExpr(bin.lhs);
            return c.genExpr(bin.rhs);
        },
        .assign_expr => |bin| {
            const rhs = try c.genExpr(bin.rhs);
            const lhs = try c.genLval(bin.lhs);
            try c.builder.addStore(lhs, rhs);
            return rhs;
        },
        .mul_assign_expr => |bin| return c.genCompoundAssign(bin),
        .div_assign_expr => |bin| return c.genCompoundAssign(bin),
        .mod_assign_expr => |bin| return c.genCompoundAssign(bin),
        .add_assign_expr => |bin| return c.genCompoundAssign(bin),
        .sub_assign_expr => |bin| return c.genCompoundAssign(bin),
        .shl_assign_expr => |bin| return c.genCompoundAssign(bin),
        .shr_assign_expr => |bin| return c.genCompoundAssign(bin),
        .bit_and_assign_expr => |bin| return c.genCompoundAssign(bin),
        .bit_xor_assign_expr => |bin| return c.genCompoundAssign(bin),
        .bit_or_assign_expr => |bin| return c.genCompoundAssign(bin),
        .bit_or_expr => |bin| return c.genBinOp(bin, .bit_or),
        .bit_xor_expr => |bin| return c.genBinOp(bin, .bit_xor),
        .bit_and_expr => |bin| return c.genBinOp(bin, .bit_and),
        .equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_eq);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .not_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_ne);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .less_than_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_lt);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .less_than_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_lte);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .greater_than_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_gt);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .greater_than_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_gte);
            return c.addUn(.zext, cmp, bin.qt);
        },
        .shl_expr => |bin| return c.genBinOp(bin, .bit_shl),
        .shr_expr => |bin| return c.genBinOp(bin, .bit_shr),
        .add_expr => |bin| {
            if (bin.qt.is(c.comp, .pointer)) {
                const lhs_qt = bin.lhs.qt(c.tree);
                if (lhs_qt.is(c.comp, .pointer)) {
                    const ptr = try c.genExpr(bin.lhs);
                    const offset = try c.genExpr(bin.rhs);
                    return c.genPtrArithmetic(ptr, offset, bin.rhs.qt(c.tree), bin.qt);
                } else {
                    const offset = try c.genExpr(bin.lhs);
                    const ptr = try c.genExpr(bin.rhs);
                    const offset_ty = lhs_qt;
                    return c.genPtrArithmetic(ptr, offset, offset_ty, bin.qt);
                }
            }
            return c.genBinOp(bin, .add);
        },
        .sub_expr => |bin| {
            if (bin.qt.is(c.comp, .pointer)) {
                const ptr = try c.genExpr(bin.lhs);
                const offset = try c.genExpr(bin.rhs);
                return c.genPtrArithmetic(ptr, offset, bin.rhs.qt(c.tree), bin.qt);
            }
            return c.genBinOp(bin, .sub);
        },
        .mul_expr => |bin| return c.genBinOp(bin, .mul),
        .div_expr => |bin| return c.genBinOp(bin, .div),
        .mod_expr => |bin| return c.genBinOp(bin, .mod),
        .addr_of_expr => |un| return try c.genLval(un.operand),
        .deref_expr => |un| {
            const operand_node = un.operand.get(c.tree);
            if (operand_node == .cast and operand_node.cast.kind == .function_to_pointer) {
                return c.genExpr(un.operand);
            }
            const operand = try c.genLval(un.operand);
            return c.addUn(.load, operand, un.qt);
        },
        .plus_expr => |un| return c.genExpr(un.operand),
        .negate_expr => |un| {
            const zero = try c.builder.addConstant(.zero, try c.genType(un.qt));
            const operand = try c.genExpr(un.operand);
            return c.addBin(.sub, zero, operand, un.qt);
        },
        .bit_not_expr => |un| {
            const operand = try c.genExpr(un.operand);
            return c.addUn(.bit_not, operand, un.qt);
        },
        .bool_not_expr => |un| {
            const zero = try c.builder.addConstant(.zero, try c.genType(un.qt));
            const operand = try c.genExpr(un.operand);
            return c.addBin(.cmp_ne, zero, operand, un.qt);
        },
        .pre_inc_expr => |un| {
            const operand = try c.genLval(un.operand);
            const val = try c.addUn(.load, operand, un.qt);
            const one = try c.builder.addConstant(.one, try c.genType(un.qt));
            const plus_one = try c.addBin(.add, val, one, un.qt);
            try c.builder.addStore(operand, plus_one);
            return plus_one;
        },
        .pre_dec_expr => |un| {
            const operand = try c.genLval(un.operand);
            const val = try c.addUn(.load, operand, un.qt);
            const one = try c.builder.addConstant(.one, try c.genType(un.qt));
            const plus_one = try c.addBin(.sub, val, one, un.qt);
            try c.builder.addStore(operand, plus_one);
            return plus_one;
        },
        .post_inc_expr => |un| {
            const operand = try c.genLval(un.operand);
            const val = try c.addUn(.load, operand, un.qt);
            const one = try c.builder.addConstant(.one, try c.genType(un.qt));
            const plus_one = try c.addBin(.add, val, one, un.qt);
            try c.builder.addStore(operand, plus_one);
            return val;
        },
        .post_dec_expr => |un| {
            const operand = try c.genLval(un.operand);
            const val = try c.addUn(.load, operand, un.qt);
            const one = try c.builder.addConstant(.one, try c.genType(un.qt));
            const plus_one = try c.addBin(.sub, val, one, un.qt);
            try c.builder.addStore(operand, plus_one);
            return val;
        },
        .paren_expr => |un| return c.genExpr(un.operand),
        .decl_ref_expr => unreachable, // Lval expression.
        .cast => |cast| switch (cast.kind) {
            .no_op => return c.genExpr(cast.operand),
            .to_void => {
                _ = try c.genExpr(cast.operand);
                return .none;
            },
            .lval_to_rval => {
                const operand = try c.genLval(cast.operand);
                return c.addUn(.load, operand, cast.qt);
            },
            .function_to_pointer, .array_to_pointer => {
                return c.genLval(cast.operand);
            },
            .int_cast => {
                const operand = try c.genExpr(cast.operand);
                const src_qt = cast.operand.qt(c.tree);
                const src_bits = src_qt.bitSizeof(c.comp);
                const dest_bits = cast.qt.bitSizeof(c.comp);
                if (src_bits == dest_bits) {
                    return operand;
                } else if (src_bits < dest_bits) {
                    if (src_qt.signedness(c.comp) == .unsigned)
                        return c.addUn(.zext, operand, cast.qt)
                    else
                        return c.addUn(.sext, operand, cast.qt);
                } else {
                    return c.addUn(.trunc, operand, cast.qt);
                }
            },
            .bool_to_int => {
                const operand = try c.genExpr(cast.operand);
                return c.addUn(.zext, operand, cast.qt);
            },
            .pointer_to_bool, .int_to_bool, .float_to_bool => {
                const lhs = try c.genExpr(cast.operand);
                const rhs = try c.builder.addConstant(.zero, try c.genType(cast.qt));
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
            .atomic_to_non_atomic,
            .non_atomic_to_atomic,
            => return c.fail("TODO CodeGen gen CastKind {}\n", .{cast.kind}),
        },
        .binary_cond_expr => |conditional| {
            if (c.tree.value_map.get(conditional.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    c.cond_dummy_ref = try c.genExpr(conditional.cond);
                    return c.genExpr(conditional.then_expr);
                } else {
                    return c.genExpr(conditional.else_expr);
                }
            }

            const then_label = try c.builder.makeLabel("ternary.then");
            const else_label = try c.builder.makeLabel("ternary.else");
            const end_label = try c.builder.makeLabel("ternary.end");
            const cond_qt = conditional.cond.qt(c.tree);
            {
                const old_cond_dummy_ty = c.cond_dummy_ty;
                defer c.cond_dummy_ty = old_cond_dummy_ty;
                c.cond_dummy_ty = try c.genType(cond_qt);

                try c.genBoolExpr(conditional.cond, then_label, else_label);
            }

            try c.builder.startBlock(then_label);
            if (c.builder.instructions.items(.ty)[@intFromEnum(c.cond_dummy_ref)] == .i1) {
                c.cond_dummy_ref = try c.addUn(.zext, c.cond_dummy_ref, cond_qt);
            }
            const then_val = try c.genExpr(conditional.then_expr);
            try c.builder.addJump(end_label);
            const then_exit = c.builder.current_label;

            try c.builder.startBlock(else_label);
            const else_val = try c.genExpr(conditional.else_expr);
            const else_exit = c.builder.current_label;

            try c.builder.startBlock(end_label);

            var phi_buf: [2]Ir.Inst.Phi.Input = .{
                .{ .value = then_val, .label = then_exit },
                .{ .value = else_val, .label = else_exit },
            };
            return c.builder.addPhi(&phi_buf, try c.genType(conditional.qt));
        },
        .cond_dummy_expr => return c.cond_dummy_ref,
        .cond_expr => |conditional| {
            if (c.tree.value_map.get(conditional.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genExpr(conditional.then_expr);
                } else {
                    return c.genExpr(conditional.else_expr);
                }
            }

            const then_label = try c.builder.makeLabel("ternary.then");
            const else_label = try c.builder.makeLabel("ternary.else");
            const end_label = try c.builder.makeLabel("ternary.end");

            try c.genBoolExpr(conditional.cond, then_label, else_label);

            try c.builder.startBlock(then_label);
            const then_val = try c.genExpr(conditional.then_expr);
            try c.builder.addJump(end_label);
            const then_exit = c.builder.current_label;

            try c.builder.startBlock(else_label);
            const else_val = try c.genExpr(conditional.else_expr);
            const else_exit = c.builder.current_label;

            try c.builder.startBlock(end_label);

            var phi_buf: [2]Ir.Inst.Phi.Input = .{
                .{ .value = then_val, .label = then_exit },
                .{ .value = else_val, .label = else_exit },
            };
            return c.builder.addPhi(&phi_buf, try c.genType(conditional.qt));
        },
        .call_expr => |call| return c.genCall(call),
        .bool_or_expr => |bin| {
            if (c.tree.value_map.get(bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    return c.builder.addConstant(.one, try c.genType(bin.qt));
                }
                return c.genExpr(bin.rhs);
            }

            const false_label = try c.builder.makeLabel("bool_false");
            const exit_label = try c.builder.makeLabel("bool_exit");

            const old_bool_end_label = c.bool_end_label;
            defer c.bool_end_label = old_bool_end_label;
            c.bool_end_label = exit_label;

            const phi_nodes_top = c.phi_nodes.items.len;
            defer c.phi_nodes.items.len = phi_nodes_top;

            try c.genBoolExpr(bin.lhs, exit_label, false_label);

            try c.builder.startBlock(false_label);
            try c.genBoolExpr(bin.rhs, exit_label, exit_label);

            try c.builder.startBlock(exit_label);

            const phi = try c.builder.addPhi(c.phi_nodes.items[phi_nodes_top..], .i1);
            return c.addUn(.zext, phi, bin.qt);
        },
        .bool_and_expr => |bin| {
            if (c.tree.value_map.get(bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    return c.builder.addConstant(.zero, try c.genType(bin.qt));
                }
                return c.genExpr(bin.rhs);
            }

            const true_label = try c.builder.makeLabel("bool_true");
            const exit_label = try c.builder.makeLabel("bool_exit");

            const old_bool_end_label = c.bool_end_label;
            defer c.bool_end_label = old_bool_end_label;
            c.bool_end_label = exit_label;

            const phi_nodes_top = c.phi_nodes.items.len;
            defer c.phi_nodes.items.len = phi_nodes_top;

            try c.genBoolExpr(bin.lhs, true_label, exit_label);

            try c.builder.startBlock(true_label);
            try c.genBoolExpr(bin.rhs, exit_label, exit_label);

            try c.builder.startBlock(exit_label);

            const phi = try c.builder.addPhi(c.phi_nodes.items[phi_nodes_top..], .i1);
            return c.addUn(.zext, phi, bin.qt);
        },
        .builtin_choose_expr => |conditional| {
            const cond = c.tree.value_map.get(conditional.cond).?;
            if (cond.toBool(c.comp)) {
                return c.genExpr(conditional.then_expr);
            } else {
                return c.genExpr(conditional.else_expr);
            }
        },
        .generic_expr => |generic| {
            const chosen = generic.chosen.get(c.tree);
            switch (chosen) {
                .generic_association_expr => |assoc| {
                    return c.genExpr(assoc.expr);
                },
                .generic_default_expr => |default| {
                    return c.genExpr(default.expr);
                },
                else => unreachable,
            }
        },
        .generic_association_expr, .generic_default_expr => unreachable,
        .stmt_expr => |un| {
            const compound_stmt = un.operand.get(c.tree).compound_stmt;

            const old_sym_len = c.symbols.items.len;
            c.symbols.items.len = old_sym_len;

            for (compound_stmt.body[0..compound_stmt.body.len -| 1]) |stmt| try c.genStmt(stmt);
            return c.genExpr(compound_stmt.body[compound_stmt.body.len - 1]);
        },
        .builtin_call_expr => |call| {
            const name = c.tree.tokSlice(call.builtin_tok);
            const builtin = c.comp.builtins.lookup(name).builtin;
            return c.genBuiltinCall(builtin, call.args, call.qt);
        },
        .addr_of_label,
        .imag_expr,
        .real_expr,
        .sizeof_expr,
        => return c.fail("TODO CodeGen.genExpr {s}\n", .{@tagName(node)}),
        else => unreachable, // Not an expression.
    }
    return .none;
}

fn genLval(c: *CodeGen, node_index: Node.Index) Error!Ir.Ref {
    assert(c.tree.isLval(node_index));
    const node = node_index.get(c.tree);
    switch (node) {
        .string_literal_expr => {
            const val = c.tree.value_map.get(node_index).?;
            return c.builder.addConstant(val.ref(), .ptr);
        },
        .paren_expr => |un| return c.genLval(un.operand),
        .decl_ref_expr => |decl_ref| {
            const slice = c.tree.tokSlice(decl_ref.name_tok);
            const name = try c.comp.internString(slice);
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
        .deref_expr => |un| return c.genExpr(un.operand),
        .compound_literal_expr => |literal| {
            if (literal.storage_class == .static or literal.thread_local) {
                return c.fail("TODO CodeGen.compound_literal_expr static or thread_local\n", .{});
            }
            const size: u32 = @intCast(literal.qt.sizeof(c.comp)); // TODO add error in parser
            const @"align" = literal.qt.alignof(c.comp);
            const alloc = try c.builder.addAlloc(size, @"align");
            try c.genInitializer(alloc, literal.qt, literal.initializer);
            return alloc;
        },
        .builtin_choose_expr => |conditional| {
            const cond = c.tree.value_map.get(conditional.cond).?;
            if (cond.toBool(c.comp)) {
                return c.genLval(conditional.then_expr);
            } else {
                return c.genLval(conditional.else_expr);
            }
        },
        .compound_assign_dummy_expr => {
            return c.compound_assign_dummy.?;
        },
        .member_access_expr,
        .member_access_ptr_expr,
        .array_access_expr,
        => return c.fail("TODO CodeGen.genLval {s}\n", .{@tagName(node)}),
        else => unreachable, // Not an lval expression.
    }
}

fn genBoolExpr(c: *CodeGen, base: Node.Index, true_label: Ir.Ref, false_label: Ir.Ref) Error!void {
    var node = base;
    while (true) switch (node.get(c.tree)) {
        .paren_expr => |un| node = un.operand,
        else => break,
    };

    switch (node.get(c.tree)) {
        .bool_or_expr => |bin| {
            if (c.tree.value_map.get(bin.lhs)) |lhs| {
                if (lhs.toBool(c.comp)) {
                    if (true_label == c.bool_end_label) {
                        return c.addBoolPhi(!c.bool_invert);
                    }
                    return c.builder.addJump(true_label);
                }
                return c.genBoolExpr(bin.rhs, true_label, false_label);
            }

            const new_false_label = try c.builder.makeLabel("bool_false");
            try c.genBoolExpr(bin.lhs, true_label, new_false_label);
            try c.builder.startBlock(new_false_label);

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(bin.rhs, true_label, false_label);
        },
        .bool_and_expr => |bin| {
            if (c.tree.value_map.get(bin.lhs)) |lhs| {
                if (!lhs.toBool(c.comp)) {
                    if (false_label == c.bool_end_label) {
                        return c.addBoolPhi(c.bool_invert);
                    }
                    return c.builder.addJump(false_label);
                }
                return c.genBoolExpr(bin.rhs, true_label, false_label);
            }

            const new_true_label = try c.builder.makeLabel("bool_true");
            try c.genBoolExpr(bin.lhs, new_true_label, false_label);
            try c.builder.startBlock(new_true_label);

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(bin.rhs, true_label, false_label);
        },
        .bool_not_expr => |un| {
            c.bool_invert = !c.bool_invert;
            defer c.bool_invert = !c.bool_invert;

            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.zero, ty);
            return c.genBoolExpr(un.operand, false_label, true_label);
        },
        .equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_eq);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .not_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_ne);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .less_than_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_lt);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .less_than_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_lte);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .greater_than_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_gt);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .greater_than_equal_expr => |bin| {
            const cmp = try c.genComparison(bin, .cmp_gte);
            if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
            return c.addBranch(cmp, true_label, false_label);
        },
        .cast => |cast| switch (cast.kind) {
            .bool_to_int => {
                const operand = try c.genExpr(cast.operand);
                if (c.cond_dummy_ty != null) c.cond_dummy_ref = operand;
                return c.addBranch(operand, true_label, false_label);
            },
            else => {},
        },
        .binary_cond_expr => |conditional| {
            if (c.tree.value_map.get(conditional.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genBoolExpr(conditional.then_expr, true_label, false_label);
                } else {
                    return c.genBoolExpr(conditional.else_expr, true_label, false_label);
                }
            }

            const new_false_label = try c.builder.makeLabel("ternary.else");
            try c.genBoolExpr(conditional.cond, true_label, new_false_label);

            try c.builder.startBlock(new_false_label);
            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(conditional.else_expr, true_label, false_label);
        },
        .cond_expr => |conditional| {
            if (c.tree.value_map.get(conditional.cond)) |cond| {
                if (cond.toBool(c.comp)) {
                    return c.genBoolExpr(conditional.then_expr, true_label, false_label);
                } else {
                    return c.genBoolExpr(conditional.else_expr, true_label, false_label);
                }
            }

            const new_true_label = try c.builder.makeLabel("ternary.then");
            const new_false_label = try c.builder.makeLabel("ternary.else");
            try c.genBoolExpr(conditional.cond, new_true_label, new_false_label);

            try c.builder.startBlock(new_true_label);
            try c.genBoolExpr(conditional.then_expr, true_label, false_label);
            try c.builder.startBlock(new_false_label);
            if (c.cond_dummy_ty) |ty| c.cond_dummy_ref = try c.builder.addConstant(.one, ty);
            return c.genBoolExpr(conditional.else_expr, true_label, false_label);
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
    const rhs = try c.builder.addConstant(.zero, try c.genType(node.qt(c.tree)));
    const cmp = try c.builder.addInst(.cmp_ne, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, .i1);
    if (c.cond_dummy_ty != null) c.cond_dummy_ref = cmp;
    try c.addBranch(cmp, true_label, false_label);
}

fn genBuiltinCall(c: *CodeGen, builtin: Builtin, arg_nodes: []const Node.Index, qt: QualType) Error!Ir.Ref {
    _ = arg_nodes;
    _ = qt;
    return c.fail("TODO CodeGen.genBuiltinCall {s}\n", .{Builtin.nameFromTag(builtin.tag).span()});
}

fn genCall(c: *CodeGen, call: Node.Call) Error!Ir.Ref {
    // Detect direct calls.
    const fn_ref = blk: {
        const callee = call.callee.get(c.tree);
        if (callee != .cast or callee.cast.kind != .function_to_pointer) {
            break :blk try c.genExpr(call.callee);
        }

        var cur = callee.cast.operand;
        while (true) switch (cur.get(c.tree)) {
            .paren_expr, .addr_of_expr, .deref_expr => |un| cur = un.operand,
            .cast => |cast| {
                if (cast.kind != .function_to_pointer) {
                    break :blk try c.genExpr(call.callee);
                }
                cur = cast.operand;
            },
            .decl_ref_expr => |decl_ref| {
                const slice = c.tree.tokSlice(decl_ref.name_tok);
                const name = try c.comp.internString(slice);
                var i = c.symbols.items.len;
                while (i > 0) {
                    i -= 1;
                    if (c.symbols.items[i].name == name) {
                        break :blk try c.genExpr(call.callee);
                    }
                }

                const duped_name = try c.builder.arena.allocator().dupeZ(u8, slice);
                const ref: Ir.Ref = @enumFromInt(c.builder.instructions.len);
                try c.builder.instructions.append(c.builder.gpa, .{ .tag = .symbol, .data = .{ .label = duped_name }, .ty = .ptr });
                break :blk ref;
            },
            else => break :blk try c.genExpr(call.callee),
        };
    };

    const args = try c.builder.arena.allocator().alloc(Ir.Ref, call.args.len);
    for (call.args, args) |node, *arg| {
        // TODO handle calling convention here
        arg.* = try c.genExpr(node);
    }
    // TODO handle variadic call
    const call_inst = try c.builder.arena.allocator().create(Ir.Inst.Call);
    call_inst.* = .{
        .func = fn_ref,
        .args_len = @intCast(args.len),
        .args_ptr = args.ptr,
    };
    return c.builder.addInst(.call, .{ .call = call_inst }, try c.genType(call.qt));
}

fn genCompoundAssign(c: *CodeGen, bin: Node.Binary) Error!Ir.Ref {
    const lhs = try c.genLval(bin.lhs);

    const old_dummy = c.compound_assign_dummy;
    defer c.compound_assign_dummy = old_dummy;
    c.compound_assign_dummy = lhs;

    const rhs = try c.genExpr(bin.rhs);
    try c.builder.addStore(lhs, rhs);
    return rhs;
}

fn genBinOp(c: *CodeGen, bin: Node.Binary, tag: Ir.Inst.Tag) Error!Ir.Ref {
    const lhs = try c.genExpr(bin.lhs);
    const rhs = try c.genExpr(bin.rhs);
    return c.addBin(tag, lhs, rhs, bin.qt);
}

fn genComparison(c: *CodeGen, bin: Node.Binary, tag: Ir.Inst.Tag) Error!Ir.Ref {
    const lhs = try c.genExpr(bin.lhs);
    const rhs = try c.genExpr(bin.rhs);

    return c.builder.addInst(tag, .{ .bin = .{ .lhs = lhs, .rhs = rhs } }, .i1);
}

fn genPtrArithmetic(c: *CodeGen, ptr: Ir.Ref, offset: Ir.Ref, offset_ty: QualType, qt: QualType) Error!Ir.Ref {
    // TODO consider adding a getelemptr instruction
    const size = qt.childType(c.comp).sizeof(c.comp);
    if (size == 1) {
        return c.builder.addInst(.add, .{ .bin = .{ .lhs = ptr, .rhs = offset } }, try c.genType(qt));
    }

    const size_inst = try c.builder.addConstant((try Value.int(size, c.comp)).ref(), try c.genType(offset_ty));
    const offset_inst = try c.addBin(.mul, offset, size_inst, offset_ty);
    return c.addBin(.add, ptr, offset_inst, offset_ty);
}

fn genInitializer(c: *CodeGen, ptr: Ir.Ref, dest_ty: QualType, initializer: Node.Index) Error!void {
    const node = initializer.get(c.tree);
    switch (node) {
        .array_init_expr,
        .struct_init_expr,
        .union_init_expr,
        .array_filler_expr,
        .default_init_expr,
        => return c.fail("TODO CodeGen.genInitializer {s}\n", .{@tagName(node)}),
        .string_literal_expr => {
            const val = c.tree.value_map.get(initializer).?;
            const str_ptr = try c.builder.addConstant(val.ref(), .ptr);
            if (dest_ty.is(c.comp, .array)) {
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

fn genVar(c: *CodeGen, decl: Node.Variable) Error!void {
    _ = decl;
    return c.fail("TODO CodeGen.genVar\n", .{});
}
