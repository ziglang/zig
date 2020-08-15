const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const assert = std.debug.assert;
const zir = @import("zir.zig");
const Module = @import("Module.zig");
const ast = std.zig.ast;
const trace = @import("tracy.zig").trace;
const Scope = Module.Scope;
const InnerError = Module.InnerError;

pub const ResultLoc = union(enum) {
    /// The expression is the right-hand side of assignment to `_`.
    discard,
    /// The expression has an inferred type, and it will be evaluated as an rvalue.
    none,
    /// The expression must generate a pointer rather than a value. For example, the left hand side
    /// of an assignment uses an "LValue" result location.
    lvalue,
    /// The expression will be type coerced into this type, but it will be evaluated as an rvalue.
    ty: *zir.Inst,
    /// The expression must store its result into this typed pointer.
    ptr: *zir.Inst,
    /// The expression must store its result into this allocation, which has an inferred type.
    inferred_ptr: *zir.Inst.Tag.alloc_inferred.Type(),
    /// The expression must store its result into this pointer, which is a typed pointer that
    /// has been bitcasted to whatever the expression's type is.
    bitcasted_ptr: *zir.Inst.UnOp,
    /// There is a pointer for the expression to store its result into, however, its type
    /// is inferred based on peer type resolution for a `zir.Inst.Block`.
    block_ptr: *zir.Inst.Block,
};

pub fn typeExpr(mod: *Module, scope: *Scope, type_node: *ast.Node) InnerError!*zir.Inst {
    const type_src = scope.tree().token_locs[type_node.firstToken()].start;
    const type_type = try addZIRInstConst(mod, scope, type_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.type_type),
    });
    const type_rl: ResultLoc = .{ .ty = type_type };
    return expr(mod, scope, type_rl, type_node);
}

/// Turn Zig AST into untyped ZIR istructions.
pub fn expr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node) InnerError!*zir.Inst {
    switch (node.tag) {
        .Root => unreachable, // Top-level declaration.
        .Use => unreachable, // Top-level declaration.
        .TestDecl => unreachable, // Top-level declaration.
        .DocComment => unreachable, // Top-level declaration.
        .VarDecl => unreachable, // Handled in `blockExpr`.
        .SwitchCase => unreachable, // Handled in `switchExpr`.
        .SwitchElse => unreachable, // Handled in `switchExpr`.
        .Else => unreachable, // Handled explicitly the control flow expression functions.
        .Payload => unreachable, // Handled explicitly.
        .PointerPayload => unreachable, // Handled explicitly.
        .PointerIndexPayload => unreachable, // Handled explicitly.
        .ErrorTag => unreachable, // Handled explicitly.
        .FieldInitializer => unreachable, // Handled explicitly.

        .Assign => return rlWrapVoid(mod, scope, rl, node, try assign(mod, scope, node.castTag(.Assign).?)),
        .AssignBitAnd => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitAnd).?, .bitand)),
        .AssignBitOr => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitOr).?, .bitor)),
        .AssignBitShiftLeft => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitShiftLeft).?, .shl)),
        .AssignBitShiftRight => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitShiftRight).?, .shr)),
        .AssignBitXor => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitXor).?, .xor)),
        .AssignDiv => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignDiv).?, .div)),
        .AssignSub => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignSub).?, .sub)),
        .AssignSubWrap => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignSubWrap).?, .subwrap)),
        .AssignMod => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMod).?, .mod_rem)),
        .AssignAdd => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignAdd).?, .add)),
        .AssignAddWrap => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignAddWrap).?, .addwrap)),
        .AssignMul => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMul).?, .mul)),
        .AssignMulWrap => return rlWrapVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMulWrap).?, .mulwrap)),

        .Add => return simpleBinOp(mod, scope, rl, node.castTag(.Add).?, .add),
        .AddWrap => return simpleBinOp(mod, scope, rl, node.castTag(.AddWrap).?, .addwrap),
        .Sub => return simpleBinOp(mod, scope, rl, node.castTag(.Sub).?, .sub),
        .SubWrap => return simpleBinOp(mod, scope, rl, node.castTag(.SubWrap).?, .subwrap),
        .Mul => return simpleBinOp(mod, scope, rl, node.castTag(.Mul).?, .mul),
        .MulWrap => return simpleBinOp(mod, scope, rl, node.castTag(.MulWrap).?, .mulwrap),
        .Div => return simpleBinOp(mod, scope, rl, node.castTag(.Div).?, .div),
        .Mod => return simpleBinOp(mod, scope, rl, node.castTag(.Mod).?, .mod_rem),
        .BitAnd => return simpleBinOp(mod, scope, rl, node.castTag(.BitAnd).?, .bitand),
        .BitOr => return simpleBinOp(mod, scope, rl, node.castTag(.BitOr).?, .bitor),
        .BitShiftLeft => return simpleBinOp(mod, scope, rl, node.castTag(.BitShiftLeft).?, .shl),
        .BitShiftRight => return simpleBinOp(mod, scope, rl, node.castTag(.BitShiftRight).?, .shr),
        .BitXor => return simpleBinOp(mod, scope, rl, node.castTag(.BitXor).?, .xor),

        .BangEqual => return simpleBinOp(mod, scope, rl, node.castTag(.BangEqual).?, .cmp_neq),
        .EqualEqual => return simpleBinOp(mod, scope, rl, node.castTag(.EqualEqual).?, .cmp_eq),
        .GreaterThan => return simpleBinOp(mod, scope, rl, node.castTag(.GreaterThan).?, .cmp_gt),
        .GreaterOrEqual => return simpleBinOp(mod, scope, rl, node.castTag(.GreaterOrEqual).?, .cmp_gte),
        .LessThan => return simpleBinOp(mod, scope, rl, node.castTag(.LessThan).?, .cmp_lt),
        .LessOrEqual => return simpleBinOp(mod, scope, rl, node.castTag(.LessOrEqual).?, .cmp_lte),

        .ArrayCat => return simpleBinOp(mod, scope, rl, node.castTag(.ArrayCat).?, .array_cat),
        .ArrayMult => return simpleBinOp(mod, scope, rl, node.castTag(.ArrayMult).?, .array_mul),

        .Identifier => return try identifier(mod, scope, rl, node.castTag(.Identifier).?),
        .Asm => return rlWrap(mod, scope, rl, try assembly(mod, scope, node.castTag(.Asm).?)),
        .StringLiteral => return rlWrap(mod, scope, rl, try stringLiteral(mod, scope, node.castTag(.StringLiteral).?)),
        .IntegerLiteral => return rlWrap(mod, scope, rl, try integerLiteral(mod, scope, node.castTag(.IntegerLiteral).?)),
        .BuiltinCall => return builtinCall(mod, scope, rl, node.castTag(.BuiltinCall).?),
        .Call => return callExpr(mod, scope, rl, node.castTag(.Call).?),
        .Unreachable => return unreach(mod, scope, node.castTag(.Unreachable).?),
        .Return => return ret(mod, scope, node.castTag(.Return).?),
        .If => return ifExpr(mod, scope, rl, node.castTag(.If).?),
        .While => return whileExpr(mod, scope, rl, node.castTag(.While).?),
        .Period => return rlWrap(mod, scope, rl, try field(mod, scope, node.castTag(.Period).?)),
        .Deref => return rlWrap(mod, scope, rl, try deref(mod, scope, node.castTag(.Deref).?)),
        .BoolNot => return rlWrap(mod, scope, rl, try boolNot(mod, scope, node.castTag(.BoolNot).?)),
        .FloatLiteral => return rlWrap(mod, scope, rl, try floatLiteral(mod, scope, node.castTag(.FloatLiteral).?)),
        .UndefinedLiteral => return rlWrap(mod, scope, rl, try undefLiteral(mod, scope, node.castTag(.UndefinedLiteral).?)),
        .BoolLiteral => return rlWrap(mod, scope, rl, try boolLiteral(mod, scope, node.castTag(.BoolLiteral).?)),
        .NullLiteral => return rlWrap(mod, scope, rl, try nullLiteral(mod, scope, node.castTag(.NullLiteral).?)),
        .OptionalType => return rlWrap(mod, scope, rl, try optionalType(mod, scope, node.castTag(.OptionalType).?)),
        .UnwrapOptional => return unwrapOptional(mod, scope, rl, node.castTag(.UnwrapOptional).?),
        .Block => return rlWrapVoid(mod, scope, rl, node, try blockExpr(mod, scope, node.castTag(.Block).?)),
        .LabeledBlock => return labeledBlockExpr(mod, scope, rl, node.castTag(.LabeledBlock).?),
        .Defer => return mod.failNode(scope, node, "TODO implement astgen.expr for .Defer", .{}),
        .Catch => return mod.failNode(scope, node, "TODO implement astgen.expr for .Catch", .{}),
        .BoolAnd => return mod.failNode(scope, node, "TODO implement astgen.expr for .BoolAnd", .{}),
        .BoolOr => return mod.failNode(scope, node, "TODO implement astgen.expr for .BoolOr", .{}),
        .ErrorUnion => return mod.failNode(scope, node, "TODO implement astgen.expr for .ErrorUnion", .{}),
        .MergeErrorSets => return mod.failNode(scope, node, "TODO implement astgen.expr for .MergeErrorSets", .{}),
        .Range => return mod.failNode(scope, node, "TODO implement astgen.expr for .Range", .{}),
        .OrElse => return mod.failNode(scope, node, "TODO implement astgen.expr for .OrElse", .{}),
        .AddressOf => return mod.failNode(scope, node, "TODO implement astgen.expr for .AddressOf", .{}),
        .Await => return mod.failNode(scope, node, "TODO implement astgen.expr for .Await", .{}),
        .BitNot => return mod.failNode(scope, node, "TODO implement astgen.expr for .BitNot", .{}),
        .Negation => return mod.failNode(scope, node, "TODO implement astgen.expr for .Negation", .{}),
        .NegationWrap => return mod.failNode(scope, node, "TODO implement astgen.expr for .NegationWrap", .{}),
        .Resume => return mod.failNode(scope, node, "TODO implement astgen.expr for .Resume", .{}),
        .Try => return mod.failNode(scope, node, "TODO implement astgen.expr for .Try", .{}),
        .ArrayType => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayType", .{}),
        .ArrayTypeSentinel => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayTypeSentinel", .{}),
        .PtrType => return mod.failNode(scope, node, "TODO implement astgen.expr for .PtrType", .{}),
        .SliceType => return mod.failNode(scope, node, "TODO implement astgen.expr for .SliceType", .{}),
        .Slice => return mod.failNode(scope, node, "TODO implement astgen.expr for .Slice", .{}),
        .ArrayAccess => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayAccess", .{}),
        .ArrayInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializer", .{}),
        .ArrayInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializerDot", .{}),
        .StructInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializer", .{}),
        .StructInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializerDot", .{}),
        .Switch => return mod.failNode(scope, node, "TODO implement astgen.expr for .Switch", .{}),
        .For => return mod.failNode(scope, node, "TODO implement astgen.expr for .For", .{}),
        .Suspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Suspend", .{}),
        .Continue => return mod.failNode(scope, node, "TODO implement astgen.expr for .Continue", .{}),
        .Break => return mod.failNode(scope, node, "TODO implement astgen.expr for .Break", .{}),
        .AnyType => return mod.failNode(scope, node, "TODO implement astgen.expr for .AnyType", .{}),
        .ErrorType => return mod.failNode(scope, node, "TODO implement astgen.expr for .ErrorType", .{}),
        .FnProto => return mod.failNode(scope, node, "TODO implement astgen.expr for .FnProto", .{}),
        .AnyFrameType => return mod.failNode(scope, node, "TODO implement astgen.expr for .AnyFrameType", .{}),
        .EnumLiteral => return mod.failNode(scope, node, "TODO implement astgen.expr for .EnumLiteral", .{}),
        .MultilineStringLiteral => return mod.failNode(scope, node, "TODO implement astgen.expr for .MultilineStringLiteral", .{}),
        .CharLiteral => return mod.failNode(scope, node, "TODO implement astgen.expr for .CharLiteral", .{}),
        .GroupedExpression => return mod.failNode(scope, node, "TODO implement astgen.expr for .GroupedExpression", .{}),
        .ErrorSetDecl => return mod.failNode(scope, node, "TODO implement astgen.expr for .ErrorSetDecl", .{}),
        .ContainerDecl => return mod.failNode(scope, node, "TODO implement astgen.expr for .ContainerDecl", .{}),
        .Comptime => return mod.failNode(scope, node, "TODO implement astgen.expr for .Comptime", .{}),
        .Nosuspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Nosuspend", .{}),
        .ContainerField => return mod.failNode(scope, node, "TODO implement astgen.expr for .ContainerField", .{}),
    }
}

pub fn blockExpr(mod: *Module, parent_scope: *Scope, block_node: *ast.Node.Block) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    try blockExprStmts(mod, parent_scope, &block_node.base, block_node.statements());
}

fn labeledBlockExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    block_node: *ast.Node.LabeledBlock,
) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    var block_scope: Scope.GenZIR = .{
        .parent = parent_scope,
        .decl = parent_scope.decl().?,
        .arena = parent_scope.arena(),
        .instructions = .{},
        .label = block_node.label,
    };
    defer block_scope.instructions.deinit(mod.gpa);

    try blockExprStmts(mod, &block_scope.base, &block_node.base, block_node.statements());

    const tree = parent_scope.tree();
    const src = tree.token_locs[block_node.lbrace].start;
    const block = try addZIRInstBlock(mod, parent_scope, src, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    return &block.base;
}

fn blockExprStmts(mod: *Module, parent_scope: *Scope, node: *ast.Node, statements: []*ast.Node) !void {
    const tree = parent_scope.tree();

    var block_arena = std.heap.ArenaAllocator.init(mod.gpa);
    defer block_arena.deinit();

    var scope = parent_scope;
    for (statements) |statement| {
        const src = tree.token_locs[statement.firstToken()].start;
        _ = try addZIRNoOp(mod, scope, src, .dbg_stmt);
        switch (statement.tag) {
            .VarDecl => {
                const var_decl_node = statement.castTag(.VarDecl).?;
                scope = try varDecl(mod, scope, var_decl_node, &block_arena.allocator);
            },
            .Assign => try assign(mod, scope, statement.castTag(.Assign).?),
            .AssignBitAnd => try assignOp(mod, scope, statement.castTag(.AssignBitAnd).?, .bitand),
            .AssignBitOr => try assignOp(mod, scope, statement.castTag(.AssignBitOr).?, .bitor),
            .AssignBitShiftLeft => try assignOp(mod, scope, statement.castTag(.AssignBitShiftLeft).?, .shl),
            .AssignBitShiftRight => try assignOp(mod, scope, statement.castTag(.AssignBitShiftRight).?, .shr),
            .AssignBitXor => try assignOp(mod, scope, statement.castTag(.AssignBitXor).?, .xor),
            .AssignDiv => try assignOp(mod, scope, statement.castTag(.AssignDiv).?, .div),
            .AssignSub => try assignOp(mod, scope, statement.castTag(.AssignSub).?, .sub),
            .AssignSubWrap => try assignOp(mod, scope, statement.castTag(.AssignSubWrap).?, .subwrap),
            .AssignMod => try assignOp(mod, scope, statement.castTag(.AssignMod).?, .mod_rem),
            .AssignAdd => try assignOp(mod, scope, statement.castTag(.AssignAdd).?, .add),
            .AssignAddWrap => try assignOp(mod, scope, statement.castTag(.AssignAddWrap).?, .addwrap),
            .AssignMul => try assignOp(mod, scope, statement.castTag(.AssignMul).?, .mul),
            .AssignMulWrap => try assignOp(mod, scope, statement.castTag(.AssignMulWrap).?, .mulwrap),

            else => {
                const possibly_unused_result = try expr(mod, scope, .none, statement);
                if (!possibly_unused_result.tag.isNoReturn()) {
                    _ = try addZIRUnOp(mod, scope, src, .ensure_result_used, possibly_unused_result);
                }
            },
        }
    }
}

fn varDecl(
    mod: *Module,
    scope: *Scope,
    node: *ast.Node.VarDecl,
    block_arena: *Allocator,
) InnerError!*Scope {
    // TODO implement detection of shadowing
    if (node.getTrailer("comptime_token")) |comptime_token| {
        return mod.failTok(scope, comptime_token, "TODO implement comptime locals", .{});
    }
    if (node.getTrailer("align_node")) |align_node| {
        return mod.failNode(scope, align_node, "TODO implement alignment on locals", .{});
    }
    const tree = scope.tree();
    const name_src = tree.token_locs[node.name_token].start;
    const ident_name = try identifierTokenString(mod, scope, node.name_token);
    const init_node = node.getTrailer("init_node").?;
    switch (tree.token_ids[node.mut_token]) {
        .Keyword_const => {
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            if (nodeMayNeedMemoryLocation(init_node)) {
                if (node.getTrailer("type_node")) |type_node| {
                    const type_inst = try typeExpr(mod, scope, type_node);
                    const alloc = try addZIRUnOp(mod, scope, name_src, .alloc, type_inst);
                    const result_loc: ResultLoc = .{ .ptr = alloc };
                    const init_inst = try expr(mod, scope, result_loc, init_node);
                    const sub_scope = try block_arena.create(Scope.LocalVal);
                    sub_scope.* = .{
                        .parent = scope,
                        .gen_zir = scope.getGenZIR(),
                        .name = ident_name,
                        .inst = init_inst,
                    };
                    return &sub_scope.base;
                } else {
                    const alloc = try addZIRNoOpT(mod, scope, name_src, .alloc_inferred);
                    const result_loc: ResultLoc = .{ .inferred_ptr = alloc };
                    const init_inst = try expr(mod, scope, result_loc, init_node);
                    const sub_scope = try block_arena.create(Scope.LocalVal);
                    sub_scope.* = .{
                        .parent = scope,
                        .gen_zir = scope.getGenZIR(),
                        .name = ident_name,
                        .inst = init_inst,
                    };
                    return &sub_scope.base;
                }
            } else {
                const result_loc: ResultLoc = if (node.getTrailer("type_node")) |type_node|
                    .{ .ty = try typeExpr(mod, scope, type_node) }
                else
                    .none;
                const init_inst = try expr(mod, scope, result_loc, init_node);
                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = scope.getGenZIR(),
                    .name = ident_name,
                    .inst = init_inst,
                };
                return &sub_scope.base;
            }
        },
        .Keyword_var => {
            if (node.getTrailer("type_node")) |type_node| {
                const type_inst = try typeExpr(mod, scope, type_node);
                const alloc = try addZIRUnOp(mod, scope, name_src, .alloc, type_inst);
                const result_loc: ResultLoc = .{ .ptr = alloc };
                const init_inst = try expr(mod, scope, result_loc, init_node);
                const sub_scope = try block_arena.create(Scope.LocalPtr);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = scope.getGenZIR(),
                    .name = ident_name,
                    .ptr = alloc,
                };
                return &sub_scope.base;
            } else {
                const alloc = try addZIRNoOp(mod, scope, name_src, .alloc_inferred);
                const result_loc = .{ .inferred_ptr = alloc.castTag(.alloc_inferred).? };
                const init_inst = try expr(mod, scope, result_loc, init_node);
                const sub_scope = try block_arena.create(Scope.LocalPtr);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = scope.getGenZIR(),
                    .name = ident_name,
                    .ptr = alloc,
                };
                return &sub_scope.base;
            }
        },
        else => unreachable,
    }
}

fn assign(mod: *Module, scope: *Scope, infix_node: *ast.Node.SimpleInfixOp) InnerError!void {
    if (infix_node.lhs.castTag(.Identifier)) |ident| {
        // This intentionally does not support @"_" syntax.
        const ident_name = scope.tree().tokenSlice(ident.token);
        if (std.mem.eql(u8, ident_name, "_")) {
            _ = try expr(mod, scope, .discard, infix_node.rhs);
            return;
        }
    }
    const lvalue = try expr(mod, scope, .lvalue, infix_node.lhs);
    _ = try expr(mod, scope, .{ .ptr = lvalue }, infix_node.rhs);
}

fn assignOp(
    mod: *Module,
    scope: *Scope,
    infix_node: *ast.Node.SimpleInfixOp,
    op_inst_tag: zir.Inst.Tag,
) InnerError!void {
    const lhs_ptr = try expr(mod, scope, .lvalue, infix_node.lhs);
    const lhs = try addZIRUnOp(mod, scope, lhs_ptr.src, .deref, lhs_ptr);
    const lhs_type = try addZIRUnOp(mod, scope, lhs_ptr.src, .typeof, lhs);
    const rhs = try expr(mod, scope, .{ .ty = lhs_type }, infix_node.rhs);

    const tree = scope.tree();
    const src = tree.token_locs[infix_node.op_token].start;

    const result = try addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
    _ = try addZIRBinOp(mod, scope, src, .store, lhs_ptr, result);
}

fn boolNot(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const bool_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });
    const operand = try expr(mod, scope, .{ .ty = bool_type }, node.rhs);
    return addZIRUnOp(mod, scope, src, .boolnot, operand);
}

fn optionalType(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const meta_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.type_type),
    });
    const operand = try expr(mod, scope, .{ .ty = meta_type }, node.rhs);
    return addZIRUnOp(mod, scope, src, .optional_type, operand);
}

fn unwrapOptional(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleSuffixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;

    const operand = try expr(mod, scope, .lvalue, node.lhs);
    const unwrapped_ptr = try addZIRUnOp(mod, scope, src, .unwrap_optional_safe, operand);
    if (rl == .lvalue) return unwrapped_ptr;

    return rlWrap(mod, scope, rl, try addZIRUnOp(mod, scope, src, .deref, unwrapped_ptr));
}

/// Identifier token -> String (allocated in scope.arena())
pub fn identifierTokenString(mod: *Module, scope: *Scope, token: ast.TokenIndex) InnerError![]const u8 {
    const tree = scope.tree();

    const ident_name = tree.tokenSlice(token);
    if (std.mem.startsWith(u8, ident_name, "@")) {
        const raw_string = ident_name[1..];
        var bad_index: usize = undefined;
        return std.zig.parseStringLiteral(scope.arena(), raw_string, &bad_index) catch |err| switch (err) {
            error.InvalidCharacter => {
                const bad_byte = raw_string[bad_index];
                const src = tree.token_locs[token].start;
                return mod.fail(scope, src + 1 + bad_index, "invalid string literal character: '{c}'\n", .{bad_byte});
            },
            else => |e| return e,
        };
    }
    return ident_name;
}

pub fn identifierStringInst(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;

    const ident_name = try identifierTokenString(mod, scope, node.token);

    return addZIRInst(mod, scope, src, zir.Inst.Str, .{ .bytes = ident_name }, .{});
}

fn field(mod: *Module, scope: *Scope, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    // TODO introduce lvalues
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;

    const lhs = try expr(mod, scope, .none, node.lhs);
    const field_name = try identifierStringInst(mod, scope, node.rhs.castTag(.Identifier).?);

    const pointer = try addZIRInst(mod, scope, src, zir.Inst.FieldPtr, .{ .object_ptr = lhs, .field_name = field_name }, .{});
    return addZIRUnOp(mod, scope, src, .deref, pointer);
}

fn deref(mod: *Module, scope: *Scope, node: *ast.Node.SimpleSuffixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;
    const lhs = try expr(mod, scope, .none, node.lhs);
    return addZIRUnOp(mod, scope, src, .deref, lhs);
}

fn simpleBinOp(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    infix_node: *ast.Node.SimpleInfixOp,
    op_inst_tag: zir.Inst.Tag,
) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[infix_node.op_token].start;

    const lhs = try expr(mod, scope, .none, infix_node.lhs);
    const rhs = try expr(mod, scope, .none, infix_node.rhs);

    const result = try addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
    return rlWrap(mod, scope, rl, result);
}

fn ifExpr(mod: *Module, scope: *Scope, rl: ResultLoc, if_node: *ast.Node.If) InnerError!*zir.Inst {
    if (if_node.payload) |payload| {
        return mod.failNode(scope, payload, "TODO implement astgen.IfExpr for optionals", .{});
    }
    if (if_node.@"else") |else_node| {
        if (else_node.payload) |payload| {
            return mod.failNode(scope, payload, "TODO implement astgen.IfExpr for error unions", .{});
        }
    }
    var block_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.decl().?,
        .arena = scope.arena(),
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    const tree = scope.tree();
    const if_src = tree.token_locs[if_node.if_token].start;
    const bool_type = try addZIRInstConst(mod, scope, if_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });
    const cond = try expr(mod, &block_scope.base, .{ .ty = bool_type }, if_node.condition);

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, if_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, if_src, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });
    var then_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the if's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .lvalue => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = block },
    };

    const then_result = try expr(mod, &then_scope.base, branch_rl, if_node.body);
    if (!then_result.tag.isNoReturn()) {
        const then_src = tree.token_locs[if_node.body.lastToken()].start;
        _ = try addZIRInst(mod, &then_scope.base, then_src, zir.Inst.Break, .{
            .block = block,
            .operand = then_result,
        }, .{});
    }
    condbr.positionals.then_body = .{
        .instructions = try then_scope.arena.dupe(*zir.Inst, then_scope.instructions.items),
    };

    var else_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    if (if_node.@"else") |else_node| {
        const else_result = try expr(mod, &else_scope.base, branch_rl, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            const else_src = tree.token_locs[else_node.body.lastToken()].start;
            _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.Break, .{
                .block = block,
                .operand = else_result,
            }, .{});
        }
    } else {
        // TODO Optimization opportunity: we can avoid an allocation and a memcpy here
        // by directly allocating the body for this one instruction.
        const else_src = tree.token_locs[if_node.lastToken()].start;
        _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.BreakVoid, .{
            .block = block,
        }, .{});
    }
    condbr.positionals.else_body = .{
        .instructions = try else_scope.arena.dupe(*zir.Inst, else_scope.instructions.items),
    };

    return &block.base;
}

fn whileExpr(mod: *Module, scope: *Scope, rl: ResultLoc, while_node: *ast.Node.While) InnerError!*zir.Inst {
    if (while_node.payload) |payload| {
        return mod.failNode(scope, payload, "TODO implement astgen.whileExpr for optionals", .{});
    }
    if (while_node.@"else") |else_node| {
        if (else_node.payload) |payload| {
            return mod.failNode(scope, payload, "TODO implement astgen.whileExpr for error unions", .{});
        }
    }

    var expr_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.decl().?,
        .arena = scope.arena(),
        .instructions = .{},
    };
    defer expr_scope.instructions.deinit(mod.gpa);

    var loop_scope: Scope.GenZIR = .{
        .parent = &expr_scope.base,
        .decl = expr_scope.decl,
        .arena = expr_scope.arena,
        .instructions = .{},
    };
    defer loop_scope.instructions.deinit(mod.gpa);

    var continue_scope: Scope.GenZIR = .{
        .parent = &loop_scope.base,
        .decl = loop_scope.decl,
        .arena = loop_scope.arena,
        .instructions = .{},
    };
    defer continue_scope.instructions.deinit(mod.gpa);

    const tree = scope.tree();
    const while_src = tree.token_locs[while_node.while_token].start;
    const bool_type = try addZIRInstConst(mod, scope, while_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });
    const void_type = try addZIRInstConst(mod, scope, while_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const cond = try expr(mod, &continue_scope.base, .{ .ty = bool_type }, while_node.condition);

    const condbr = try addZIRInstSpecial(mod, &continue_scope.base, while_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});
    const cond_block = try addZIRInstBlock(mod, &loop_scope.base, while_src, .{
        .instructions = try loop_scope.arena.dupe(*zir.Inst, continue_scope.instructions.items),
    });
    // TODO avoid emitting the continue expr when there
    // are no jumps to it. This happens when the last statement of a while body is noreturn
    // and there are no `continue` statements.
    // The "repeat" at the end of a loop body is implied.
    if (while_node.continue_expr) |cont_expr| {
        _ = try expr(mod, &loop_scope.base, .{ .ty = void_type }, cont_expr);
    }
    const loop = try addZIRInstLoop(mod, &expr_scope.base, while_src, .{
        .instructions = try expr_scope.arena.dupe(*zir.Inst, loop_scope.instructions.items),
    });
    const while_block = try addZIRInstBlock(mod, scope, while_src, .{
        .instructions = try expr_scope.arena.dupe(*zir.Inst, expr_scope.instructions.items),
    });
    var then_scope: Scope.GenZIR = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the while's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .lvalue => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = while_block },
    };

    const then_result = try expr(mod, &then_scope.base, branch_rl, while_node.body);
    if (!then_result.tag.isNoReturn()) {
        const then_src = tree.token_locs[while_node.body.lastToken()].start;
        _ = try addZIRInst(mod, &then_scope.base, then_src, zir.Inst.Break, .{
            .block = cond_block,
            .operand = then_result,
        }, .{});
    }
    condbr.positionals.then_body = .{
        .instructions = try then_scope.arena.dupe(*zir.Inst, then_scope.instructions.items),
    };

    var else_scope: Scope.GenZIR = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    if (while_node.@"else") |else_node| {
        const else_result = try expr(mod, &else_scope.base, branch_rl, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            const else_src = tree.token_locs[else_node.body.lastToken()].start;
            _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.Break, .{
                .block = while_block,
                .operand = else_result,
            }, .{});
        }
    } else {
        const else_src = tree.token_locs[while_node.lastToken()].start;
        _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.BreakVoid, .{
            .block = while_block,
        }, .{});
    }
    condbr.positionals.else_body = .{
        .instructions = try else_scope.arena.dupe(*zir.Inst, else_scope.instructions.items),
    };
    return &while_block.base;
}

fn ret(mod: *Module, scope: *Scope, cfe: *ast.Node.ControlFlowExpression) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[cfe.ltoken].start;
    if (cfe.getRHS()) |rhs_node| {
        if (nodeMayNeedMemoryLocation(rhs_node)) {
            const ret_ptr = try addZIRNoOp(mod, scope, src, .ret_ptr);
            const operand = try expr(mod, scope, .{ .ptr = ret_ptr }, rhs_node);
            return addZIRUnOp(mod, scope, src, .@"return", operand);
        } else {
            const fn_ret_ty = try addZIRNoOp(mod, scope, src, .ret_type);
            const operand = try expr(mod, scope, .{ .ty = fn_ret_ty }, rhs_node);
            return addZIRUnOp(mod, scope, src, .@"return", operand);
        }
    } else {
        return addZIRNoOp(mod, scope, src, .returnvoid);
    }
}

fn identifier(mod: *Module, scope: *Scope, rl: ResultLoc, ident: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const tree = scope.tree();
    const ident_name = try identifierTokenString(mod, scope, ident.token);
    const src = tree.token_locs[ident.token].start;
    if (mem.eql(u8, ident_name, "_")) {
        return mod.failNode(scope, &ident.base, "TODO implement '_' identifier", .{});
    }

    if (getSimplePrimitiveValue(ident_name)) |typed_value| {
        const result = try addZIRInstConst(mod, scope, src, typed_value);
        return rlWrap(mod, scope, rl, result);
    }

    if (ident_name.len >= 2) integer: {
        const first_c = ident_name[0];
        if (first_c == 'i' or first_c == 'u') {
            const is_signed = first_c == 'i';
            const bit_count = std.fmt.parseInt(u16, ident_name[1..], 10) catch |err| switch (err) {
                error.Overflow => return mod.failNode(
                    scope,
                    &ident.base,
                    "primitive integer type '{}' exceeds maximum bit width of 65535",
                    .{ident_name},
                ),
                error.InvalidCharacter => break :integer,
            };
            const val = switch (bit_count) {
                8 => if (is_signed) Value.initTag(.i8_type) else Value.initTag(.u8_type),
                16 => if (is_signed) Value.initTag(.i16_type) else Value.initTag(.u16_type),
                32 => if (is_signed) Value.initTag(.i32_type) else Value.initTag(.u32_type),
                64 => if (is_signed) Value.initTag(.i64_type) else Value.initTag(.u64_type),
                else => {
                    const int_type_payload = try scope.arena().create(Value.Payload.IntType);
                    int_type_payload.* = .{ .signed = is_signed, .bits = bit_count };
                    const result = try addZIRInstConst(mod, scope, src, .{
                        .ty = Type.initTag(.comptime_int),
                        .val = Value.initPayload(&int_type_payload.base),
                    });
                    return rlWrap(mod, scope, rl, result);
                },
            };
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.type),
                .val = val,
            });
            return rlWrap(mod, scope, rl, result);
        }
    }

    // Local variables, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (mem.eql(u8, local_val.name, ident_name)) {
                    return rlWrap(mod, scope, rl, local_val.inst);
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (mem.eql(u8, local_ptr.name, ident_name)) {
                    if (rl == .lvalue) {
                        return local_ptr.ptr;
                    } else {
                        const result = try addZIRUnOp(mod, scope, src, .deref, local_ptr.ptr);
                        return rlWrap(mod, scope, rl, result);
                    }
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(Scope.GenZIR).?.parent,
            else => break,
        };
    }

    if (mod.lookupDeclName(scope, ident_name)) |decl| {
        // TODO handle lvalues
        const result = try addZIRInst(mod, scope, src, zir.Inst.DeclValInModule, .{ .decl = decl }, .{});
        return rlWrap(mod, scope, rl, result);
    }

    return mod.failNode(scope, &ident.base, "use of undeclared identifier '{}'", .{ident_name});
}

fn stringLiteral(mod: *Module, scope: *Scope, str_lit: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tree = scope.tree();
    const unparsed_bytes = tree.tokenSlice(str_lit.token);
    const arena = scope.arena();

    var bad_index: usize = undefined;
    const bytes = std.zig.parseStringLiteral(arena, unparsed_bytes, &bad_index) catch |err| switch (err) {
        error.InvalidCharacter => {
            const bad_byte = unparsed_bytes[bad_index];
            const src = tree.token_locs[str_lit.token].start;
            return mod.fail(scope, src + bad_index, "invalid string literal character: '{c}'\n", .{bad_byte});
        },
        else => |e| return e,
    };

    const src = tree.token_locs[str_lit.token].start;
    return addZIRInst(mod, scope, src, zir.Inst.Str, .{ .bytes = bytes }, .{});
}

fn integerLiteral(mod: *Module, scope: *Scope, int_lit: *ast.Node.OneToken) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const prefixed_bytes = tree.tokenSlice(int_lit.token);
    const base = if (mem.startsWith(u8, prefixed_bytes, "0x"))
        16
    else if (mem.startsWith(u8, prefixed_bytes, "0o"))
        8
    else if (mem.startsWith(u8, prefixed_bytes, "0b"))
        2
    else
        @as(u8, 10);

    const bytes = if (base == 10)
        prefixed_bytes
    else
        prefixed_bytes[2..];

    if (std.fmt.parseInt(u64, bytes, base)) |small_int| {
        const int_payload = try arena.create(Value.Payload.Int_u64);
        int_payload.* = .{ .int = small_int };
        const src = tree.token_locs[int_lit.token].start;
        return addZIRInstConst(mod, scope, src, .{
            .ty = Type.initTag(.comptime_int),
            .val = Value.initPayload(&int_payload.base),
        });
    } else |err| {
        return mod.failTok(scope, int_lit.token, "TODO implement int literals that don't fit in a u64", .{});
    }
}

fn floatLiteral(mod: *Module, scope: *Scope, float_lit: *ast.Node.OneToken) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const bytes = tree.tokenSlice(float_lit.token);
    if (bytes.len > 2 and bytes[1] == 'x') {
        return mod.failTok(scope, float_lit.token, "TODO hex floats", .{});
    }

    const val = std.fmt.parseFloat(f128, bytes) catch |e| switch (e) {
        error.InvalidCharacter => unreachable, // validated by tokenizer
    };
    const float_payload = try arena.create(Value.Payload.Float_128);
    float_payload.* = .{ .val = val };
    const src = tree.token_locs[float_lit.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = Value.initPayload(&float_payload.base),
    });
}

fn undefLiteral(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.@"undefined"),
        .val = Value.initTag(.undef),
    });
}

fn boolLiteral(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.bool),
        .val = switch (tree.token_ids[node.token]) {
            .Keyword_true => Value.initTag(.bool_true),
            .Keyword_false => Value.initTag(.bool_false),
            else => unreachable,
        },
    });
}

fn nullLiteral(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.@"null"),
        .val = Value.initTag(.null_value),
    });
}

fn assembly(mod: *Module, scope: *Scope, asm_node: *ast.Node.Asm) InnerError!*zir.Inst {
    if (asm_node.outputs.len != 0) {
        return mod.failNode(scope, &asm_node.base, "TODO implement asm with an output", .{});
    }
    const arena = scope.arena();
    const tree = scope.tree();

    const inputs = try arena.alloc(*zir.Inst, asm_node.inputs.len);
    const args = try arena.alloc(*zir.Inst, asm_node.inputs.len);

    const src = tree.token_locs[asm_node.asm_token].start;

    const str_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.const_slice_u8_type),
    });
    const str_type_rl: ResultLoc = .{ .ty = str_type };

    for (asm_node.inputs) |input, i| {
        // TODO semantically analyze constraints
        inputs[i] = try expr(mod, scope, str_type_rl, input.constraint);
        args[i] = try expr(mod, scope, .none, input.expr);
    }

    const return_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const asm_inst = try addZIRInst(mod, scope, src, zir.Inst.Asm, .{
        .asm_source = try expr(mod, scope, str_type_rl, asm_node.template),
        .return_type = return_type,
    }, .{
        .@"volatile" = asm_node.volatile_token != null,
        //.clobbers =  TODO handle clobbers
        .inputs = inputs,
        .args = args,
    });
    return asm_inst;
}

fn ensureBuiltinParamCount(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall, count: u32) !void {
    if (call.params_len == count)
        return;

    const s = if (count == 1) "" else "s";
    return mod.failTok(scope, call.builtin_token, "expected {} parameter{}, found {}", .{ count, s, call.params_len });
}

fn simpleCast(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    call: *ast.Node.BuiltinCall,
    inst_tag: zir.Inst.Tag,
) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 2);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const type_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.type_type),
    });
    const params = call.params();
    const dest_type = try expr(mod, scope, .{ .ty = type_type }, params[0]);
    const rhs = try expr(mod, scope, .none, params[1]);
    const result = try addZIRBinOp(mod, scope, src, inst_tag, dest_type, rhs);
    return rlWrap(mod, scope, rl, result);
}

fn ptrToInt(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 1);
    const operand = try expr(mod, scope, .none, call.params()[0]);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    return addZIRUnOp(mod, scope, src, .ptrtoint, operand);
}

fn as(mod: *Module, scope: *Scope, rl: ResultLoc, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 2);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    const dest_type = try typeExpr(mod, scope, params[0]);
    switch (rl) {
        .none => return try expr(mod, scope, .{ .ty = dest_type }, params[1]),
        .discard => {
            const result = try expr(mod, scope, .{ .ty = dest_type }, params[1]);
            _ = try addZIRUnOp(mod, scope, result.src, .ensure_result_non_error, result);
            return result;
        },
        .lvalue => {
            const result = try expr(mod, scope, .{ .ty = dest_type }, params[1]);
            return addZIRUnOp(mod, scope, result.src, .ref, result);
        },
        .ty => |result_ty| {
            const result = try expr(mod, scope, .{ .ty = dest_type }, params[1]);
            return addZIRBinOp(mod, scope, src, .as, result_ty, result);
        },
        .ptr => |result_ptr| {
            const casted_result_ptr = try addZIRBinOp(mod, scope, src, .coerce_result_ptr, dest_type, result_ptr);
            return expr(mod, scope, .{ .ptr = casted_result_ptr }, params[1]);
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, call.builtin_token, "TODO implement @as with result location @bitCast", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, call.builtin_token, "TODO implement @as with inferred-type result location pointer", .{});
        },
        .block_ptr => |block_ptr| {
            const casted_block_ptr = try addZIRInst(mod, scope, src, zir.Inst.CoerceResultBlockPtr, .{
                .dest_type = dest_type,
                .block = block_ptr,
            }, .{});
            return expr(mod, scope, .{ .ptr = casted_block_ptr }, params[1]);
        },
    }
}

fn bitCast(mod: *Module, scope: *Scope, rl: ResultLoc, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 2);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const type_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.type_type),
    });
    const params = call.params();
    const dest_type = try expr(mod, scope, .{ .ty = type_type }, params[0]);
    switch (rl) {
        .none => {
            const operand = try expr(mod, scope, .none, params[1]);
            return addZIRBinOp(mod, scope, src, .bitcast, dest_type, operand);
        },
        .discard => {
            const operand = try expr(mod, scope, .none, params[1]);
            const result = try addZIRBinOp(mod, scope, src, .bitcast, dest_type, operand);
            _ = try addZIRUnOp(mod, scope, result.src, .ensure_result_non_error, result);
            return result;
        },
        .lvalue => {
            const operand = try expr(mod, scope, .lvalue, params[1]);
            const result = try addZIRBinOp(mod, scope, src, .bitcast_lvalue, dest_type, operand);
            return result;
        },
        .ty => |result_ty| {
            const result = try expr(mod, scope, .none, params[1]);
            const bitcasted = try addZIRBinOp(mod, scope, src, .bitcast, dest_type, result);
            return addZIRBinOp(mod, scope, src, .as, result_ty, bitcasted);
        },
        .ptr => |result_ptr| {
            const casted_result_ptr = try addZIRUnOp(mod, scope, src, .bitcast_result_ptr, result_ptr);
            return expr(mod, scope, .{ .bitcasted_ptr = casted_result_ptr.castTag(.bitcast_result_ptr).? }, params[1]);
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            return mod.failTok(scope, call.builtin_token, "TODO implement @bitCast with result location another @bitCast", .{});
        },
        .block_ptr => |block_ptr| {
            return mod.failTok(scope, call.builtin_token, "TODO implement @bitCast with result location inferred peer types", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, call.builtin_token, "TODO implement @bitCast with inferred-type result location pointer", .{});
        },
    }
}

fn builtinCall(mod: *Module, scope: *Scope, rl: ResultLoc, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    const tree = scope.tree();
    const builtin_name = tree.tokenSlice(call.builtin_token);

    // We handle the different builtins manually because they have different semantics depending
    // on the function. For example, `@as` and others participate in result location semantics,
    // and `@cImport` creates a special scope that collects a .c source code text buffer.
    // Also, some builtins have a variable number of parameters.

    if (mem.eql(u8, builtin_name, "@ptrToInt")) {
        return rlWrap(mod, scope, rl, try ptrToInt(mod, scope, call));
    } else if (mem.eql(u8, builtin_name, "@as")) {
        return as(mod, scope, rl, call);
    } else if (mem.eql(u8, builtin_name, "@floatCast")) {
        return simpleCast(mod, scope, rl, call, .floatcast);
    } else if (mem.eql(u8, builtin_name, "@intCast")) {
        return simpleCast(mod, scope, rl, call, .intcast);
    } else if (mem.eql(u8, builtin_name, "@bitCast")) {
        return bitCast(mod, scope, rl, call);
    } else {
        return mod.failTok(scope, call.builtin_token, "invalid builtin function: '{}'", .{builtin_name});
    }
}

fn callExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.Call) InnerError!*zir.Inst {
    const tree = scope.tree();
    const lhs = try expr(mod, scope, .none, node.lhs);

    const param_nodes = node.params();
    const args = try scope.getGenZIR().arena.alloc(*zir.Inst, param_nodes.len);
    for (param_nodes) |param_node, i| {
        const param_src = tree.token_locs[param_node.firstToken()].start;
        const param_type = try addZIRInst(mod, scope, param_src, zir.Inst.ParamType, .{
            .func = lhs,
            .arg_index = i,
        }, .{});
        args[i] = try expr(mod, scope, .{ .ty = param_type }, param_node);
    }

    const src = tree.token_locs[node.lhs.firstToken()].start;
    const result = try addZIRInst(mod, scope, src, zir.Inst.Call, .{
        .func = lhs,
        .args = args,
    }, .{});
    // TODO function call with result location
    return rlWrap(mod, scope, rl, result);
}

fn unreach(mod: *Module, scope: *Scope, unreach_node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[unreach_node.token].start;
    return addZIRNoOp(mod, scope, src, .@"unreachable");
}

fn getSimplePrimitiveValue(name: []const u8) ?TypedValue {
    const simple_types = std.ComptimeStringMap(Value.Tag, .{
        .{ "u8", .u8_type },
        .{ "i8", .i8_type },
        .{ "isize", .isize_type },
        .{ "usize", .usize_type },
        .{ "c_short", .c_short_type },
        .{ "c_ushort", .c_ushort_type },
        .{ "c_int", .c_int_type },
        .{ "c_uint", .c_uint_type },
        .{ "c_long", .c_long_type },
        .{ "c_ulong", .c_ulong_type },
        .{ "c_longlong", .c_longlong_type },
        .{ "c_ulonglong", .c_ulonglong_type },
        .{ "c_longdouble", .c_longdouble_type },
        .{ "f16", .f16_type },
        .{ "f32", .f32_type },
        .{ "f64", .f64_type },
        .{ "f128", .f128_type },
        .{ "c_void", .c_void_type },
        .{ "bool", .bool_type },
        .{ "void", .void_type },
        .{ "type", .type_type },
        .{ "anyerror", .anyerror_type },
        .{ "comptime_int", .comptime_int_type },
        .{ "comptime_float", .comptime_float_type },
        .{ "noreturn", .noreturn_type },
    });
    if (simple_types.get(name)) |tag| {
        return TypedValue{
            .ty = Type.initTag(.type),
            .val = Value.initTag(tag),
        };
    }
    return null;
}

fn nodeMayNeedMemoryLocation(start_node: *ast.Node) bool {
    var node = start_node;
    while (true) {
        switch (node.tag) {
            .Root,
            .Use,
            .TestDecl,
            .DocComment,
            .SwitchCase,
            .SwitchElse,
            .Else,
            .Payload,
            .PointerPayload,
            .PointerIndexPayload,
            .ContainerField,
            .ErrorTag,
            .FieldInitializer,
            => unreachable,

            .Return,
            .Break,
            .Continue,
            .BitNot,
            .BoolNot,
            .VarDecl,
            .Defer,
            .AddressOf,
            .OptionalType,
            .Negation,
            .NegationWrap,
            .Resume,
            .ArrayType,
            .ArrayTypeSentinel,
            .PtrType,
            .SliceType,
            .Suspend,
            .AnyType,
            .ErrorType,
            .FnProto,
            .AnyFrameType,
            .IntegerLiteral,
            .FloatLiteral,
            .EnumLiteral,
            .StringLiteral,
            .MultilineStringLiteral,
            .CharLiteral,
            .BoolLiteral,
            .NullLiteral,
            .UndefinedLiteral,
            .Unreachable,
            .Identifier,
            .ErrorSetDecl,
            .ContainerDecl,
            .Asm,
            .Add,
            .AddWrap,
            .ArrayCat,
            .ArrayMult,
            .Assign,
            .AssignBitAnd,
            .AssignBitOr,
            .AssignBitShiftLeft,
            .AssignBitShiftRight,
            .AssignBitXor,
            .AssignDiv,
            .AssignSub,
            .AssignSubWrap,
            .AssignMod,
            .AssignAdd,
            .AssignAddWrap,
            .AssignMul,
            .AssignMulWrap,
            .BangEqual,
            .BitAnd,
            .BitOr,
            .BitShiftLeft,
            .BitShiftRight,
            .BitXor,
            .BoolAnd,
            .BoolOr,
            .Div,
            .EqualEqual,
            .ErrorUnion,
            .GreaterOrEqual,
            .GreaterThan,
            .LessOrEqual,
            .LessThan,
            .MergeErrorSets,
            .Mod,
            .Mul,
            .MulWrap,
            .Range,
            .Period,
            .Sub,
            .SubWrap,
            .Slice,
            .Deref,
            .ArrayAccess,
            .Block,
            => return false,

            // Forward the question to a sub-expression.
            .GroupedExpression => node = node.castTag(.GroupedExpression).?.expr,
            .Try => node = node.castTag(.Try).?.rhs,
            .Await => node = node.castTag(.Await).?.rhs,
            .Catch => node = node.castTag(.Catch).?.rhs,
            .OrElse => node = node.castTag(.OrElse).?.rhs,
            .Comptime => node = node.castTag(.Comptime).?.expr,
            .Nosuspend => node = node.castTag(.Nosuspend).?.expr,
            .UnwrapOptional => node = node.castTag(.UnwrapOptional).?.lhs,

            // True because these are exactly the expressions we need memory locations for.
            .ArrayInitializer,
            .ArrayInitializerDot,
            .StructInitializer,
            .StructInitializerDot,
            => return true,

            // True because depending on comptime conditions, sub-expressions
            // may be the kind that need memory locations.
            .While,
            .For,
            .Switch,
            .Call,
            .BuiltinCall, // TODO some of these can return false
            .LabeledBlock,
            => return true,

            // Depending on AST properties, they may need memory locations.
            .If => return node.castTag(.If).?.@"else" != null,
        }
    }
}

/// Applies `rl` semantics to `inst`. Expressions which do not do their own handling of
/// result locations must call this function on their result.
/// As an example, if the `ResultLoc` is `ptr`, it will write the result to the pointer.
/// If the `ResultLoc` is `ty`, it will coerce the result to the type.
fn rlWrap(mod: *Module, scope: *Scope, rl: ResultLoc, result: *zir.Inst) InnerError!*zir.Inst {
    switch (rl) {
        .none => return result,
        .discard => {
            // Emit a compile error for discarding error values.
            _ = try addZIRUnOp(mod, scope, result.src, .ensure_result_non_error, result);
            return result;
        },
        .lvalue => {
            // We need a pointer but we have a value.
            return addZIRUnOp(mod, scope, result.src, .ref, result);
        },
        .ty => |ty_inst| return addZIRBinOp(mod, scope, result.src, .as, ty_inst, result),
        .ptr => |ptr_inst| {
            const casted_result = try addZIRInst(mod, scope, result.src, zir.Inst.CoerceToPtrElem, .{
                .ptr = ptr_inst,
                .value = result,
            }, .{});
            _ = try addZIRBinOp(mod, scope, result.src, .store, ptr_inst, casted_result);
            return casted_result;
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            return mod.fail(scope, result.src, "TODO implement rlWrap .bitcasted_ptr", .{});
        },
        .inferred_ptr => |alloc| {
            return mod.fail(scope, result.src, "TODO implement rlWrap .inferred_ptr", .{});
        },
        .block_ptr => |block_ptr| {
            return mod.fail(scope, result.src, "TODO implement rlWrap .block_ptr", .{});
        },
    }
}

fn rlWrapVoid(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node, result: void) InnerError!*zir.Inst {
    const src = scope.tree().token_locs[node.firstToken()].start;
    const void_inst = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    });
    return rlWrap(mod, scope, rl, void_inst);
}

pub fn addZIRInstSpecial(
    mod: *Module,
    scope: *Scope,
    src: usize,
    comptime T: type,
    positionals: std.meta.fieldInfo(T, "positionals").field_type,
    kw_args: std.meta.fieldInfo(T, "kw_args").field_type,
) !*T {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(T);
    inst.* = .{
        .base = .{
            .tag = T.base_tag,
            .src = src,
        },
        .positionals = positionals,
        .kw_args = kw_args,
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return inst;
}

pub fn addZIRNoOpT(mod: *Module, scope: *Scope, src: usize, tag: zir.Inst.Tag) !*zir.Inst.NoOp {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.NoOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{},
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return inst;
}

pub fn addZIRNoOp(mod: *Module, scope: *Scope, src: usize, tag: zir.Inst.Tag) !*zir.Inst {
    const inst = try addZIRNoOpT(mod, scope, src, tag);
    return &inst.base;
}

pub fn addZIRUnOp(
    mod: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
    operand: *zir.Inst,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.UnOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{
            .operand = operand,
        },
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRBinOp(
    mod: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
    lhs: *zir.Inst,
    rhs: *zir.Inst,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.BinOp);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{
            .lhs = lhs,
            .rhs = rhs,
        },
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRInst(
    mod: *Module,
    scope: *Scope,
    src: usize,
    comptime T: type,
    positionals: std.meta.fieldInfo(T, "positionals").field_type,
    kw_args: std.meta.fieldInfo(T, "kw_args").field_type,
) !*zir.Inst {
    const inst_special = try addZIRInstSpecial(mod, scope, src, T, positionals, kw_args);
    return &inst_special.base;
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstConst(mod: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*zir.Inst {
    const P = std.meta.fieldInfo(zir.Inst.Const, "positionals").field_type;
    return addZIRInst(mod, scope, src, zir.Inst.Const, P{ .typed_value = typed_value }, .{});
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstBlock(mod: *Module, scope: *Scope, src: usize, body: zir.Module.Body) !*zir.Inst.Block {
    const P = std.meta.fieldInfo(zir.Inst.Block, "positionals").field_type;
    return addZIRInstSpecial(mod, scope, src, zir.Inst.Block, P{ .body = body }, .{});
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstLoop(mod: *Module, scope: *Scope, src: usize, body: zir.Module.Body) !*zir.Inst.Loop {
    const P = std.meta.fieldInfo(zir.Inst.Loop, "positionals").field_type;
    return addZIRInstSpecial(mod, scope, src, zir.Inst.Loop, P{ .body = body }, .{});
}
