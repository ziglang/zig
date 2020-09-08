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
    /// The expression is the right-hand side of assignment to `_`. Only the side-effects of the
    /// expression should be generated.
    discard,
    /// The expression has an inferred type, and it will be evaluated as an rvalue.
    none,
    /// The expression must generate a pointer rather than a value. For example, the left hand side
    /// of an assignment uses this kind of result location.
    ref,
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

fn lvalExpr(mod: *Module, scope: *Scope, node: *ast.Node) InnerError!*zir.Inst {
    switch (node.tag) {
        .Root => unreachable,
        .Use => unreachable,
        .TestDecl => unreachable,
        .DocComment => unreachable,
        .VarDecl => unreachable,
        .SwitchCase => unreachable,
        .SwitchElse => unreachable,
        .Else => unreachable,
        .Payload => unreachable,
        .PointerPayload => unreachable,
        .PointerIndexPayload => unreachable,
        .ErrorTag => unreachable,
        .FieldInitializer => unreachable,
        .ContainerField => unreachable,

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
        .Add,
        .AddWrap,
        .Sub,
        .SubWrap,
        .Mul,
        .MulWrap,
        .Div,
        .Mod,
        .BitAnd,
        .BitOr,
        .BitShiftLeft,
        .BitShiftRight,
        .BitXor,
        .BangEqual,
        .EqualEqual,
        .GreaterThan,
        .GreaterOrEqual,
        .LessThan,
        .LessOrEqual,
        .ArrayCat,
        .ArrayMult,
        .BoolAnd,
        .BoolOr,
        .Asm,
        .StringLiteral,
        .IntegerLiteral,
        .Call,
        .Unreachable,
        .Return,
        .If,
        .While,
        .BoolNot,
        .AddressOf,
        .FloatLiteral,
        .UndefinedLiteral,
        .BoolLiteral,
        .NullLiteral,
        .OptionalType,
        .Block,
        .LabeledBlock,
        .Break,
        .PtrType,
        .GroupedExpression,
        .ArrayType,
        .ArrayTypeSentinel,
        .EnumLiteral,
        .MultilineStringLiteral,
        .CharLiteral,
        .Defer,
        .Catch,
        .ErrorUnion,
        .MergeErrorSets,
        .Range,
        .OrElse,
        .Await,
        .BitNot,
        .Negation,
        .NegationWrap,
        .Resume,
        .Try,
        .SliceType,
        .Slice,
        .ArrayInitializer,
        .ArrayInitializerDot,
        .StructInitializer,
        .StructInitializerDot,
        .Switch,
        .For,
        .Suspend,
        .Continue,
        .AnyType,
        .ErrorType,
        .FnProto,
        .AnyFrameType,
        .ErrorSetDecl,
        .ContainerDecl,
        .Comptime,
        .Nosuspend,
        => return mod.failNode(scope, node, "invalid left-hand side to assignment", .{}),

        // @field can be assigned to
        .BuiltinCall => {
            const call = node.castTag(.BuiltinCall).?;
            const tree = scope.tree();
            const builtin_name = tree.tokenSlice(call.builtin_token);

            if (!mem.eql(u8, builtin_name, "@field")) {
                return mod.failNode(scope, node, "invalid left-hand side to assignment", .{});
            }
        },

        // can be assigned to
        .UnwrapOptional, .Deref, .Period, .ArrayAccess, .Identifier => {},
    }
    return expr(mod, scope, .ref, node);
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
        .ContainerField => unreachable, // Handled explicitly.

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

        .BoolAnd => return boolBinOp(mod, scope, rl, node.castTag(.BoolAnd).?),
        .BoolOr => return boolBinOp(mod, scope, rl, node.castTag(.BoolOr).?),

        .BoolNot => return rlWrap(mod, scope, rl, try boolNot(mod, scope, node.castTag(.BoolNot).?)),
        .BitNot => return rlWrap(mod, scope, rl, try bitNot(mod, scope, node.castTag(.BitNot).?)),
        .Negation => return rlWrap(mod, scope, rl, try negation(mod, scope, node.castTag(.Negation).?, .sub)),
        .NegationWrap => return rlWrap(mod, scope, rl, try negation(mod, scope, node.castTag(.NegationWrap).?, .subwrap)),

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
        .Period => return field(mod, scope, rl, node.castTag(.Period).?),
        .Deref => return rlWrap(mod, scope, rl, try deref(mod, scope, node.castTag(.Deref).?)),
        .AddressOf => return rlWrap(mod, scope, rl, try addressOf(mod, scope, node.castTag(.AddressOf).?)),
        .FloatLiteral => return rlWrap(mod, scope, rl, try floatLiteral(mod, scope, node.castTag(.FloatLiteral).?)),
        .UndefinedLiteral => return rlWrap(mod, scope, rl, try undefLiteral(mod, scope, node.castTag(.UndefinedLiteral).?)),
        .BoolLiteral => return rlWrap(mod, scope, rl, try boolLiteral(mod, scope, node.castTag(.BoolLiteral).?)),
        .NullLiteral => return rlWrap(mod, scope, rl, try nullLiteral(mod, scope, node.castTag(.NullLiteral).?)),
        .OptionalType => return rlWrap(mod, scope, rl, try optionalType(mod, scope, node.castTag(.OptionalType).?)),
        .UnwrapOptional => return unwrapOptional(mod, scope, rl, node.castTag(.UnwrapOptional).?),
        .Block => return rlWrapVoid(mod, scope, rl, node, try blockExpr(mod, scope, node.castTag(.Block).?)),
        .LabeledBlock => return labeledBlockExpr(mod, scope, rl, node.castTag(.LabeledBlock).?, .block),
        .Break => return rlWrap(mod, scope, rl, try breakExpr(mod, scope, node.castTag(.Break).?)),
        .PtrType => return rlWrap(mod, scope, rl, try ptrType(mod, scope, node.castTag(.PtrType).?)),
        .GroupedExpression => return expr(mod, scope, rl, node.castTag(.GroupedExpression).?.expr),
        .ArrayType => return rlWrap(mod, scope, rl, try arrayType(mod, scope, node.castTag(.ArrayType).?)),
        .ArrayTypeSentinel => return rlWrap(mod, scope, rl, try arrayTypeSentinel(mod, scope, node.castTag(.ArrayTypeSentinel).?)),
        .EnumLiteral => return rlWrap(mod, scope, rl, try enumLiteral(mod, scope, node.castTag(.EnumLiteral).?)),
        .MultilineStringLiteral => return rlWrap(mod, scope, rl, try multilineStrLiteral(mod, scope, node.castTag(.MultilineStringLiteral).?)),
        .CharLiteral => return rlWrap(mod, scope, rl, try charLiteral(mod, scope, node.castTag(.CharLiteral).?)),
        .SliceType => return rlWrap(mod, scope, rl, try sliceType(mod, scope, node.castTag(.SliceType).?)),
        .ErrorUnion => return rlWrap(mod, scope, rl, try typeInixOp(mod, scope, node.castTag(.ErrorUnion).?, .error_union_type)),
        .MergeErrorSets => return rlWrap(mod, scope, rl, try typeInixOp(mod, scope, node.castTag(.MergeErrorSets).?, .merge_error_sets)),
        .AnyFrameType => return rlWrap(mod, scope, rl, try anyFrameType(mod, scope, node.castTag(.AnyFrameType).?)),
        .ErrorSetDecl => return errorSetDecl(mod, scope, rl, node.castTag(.ErrorSetDecl).?),
        .ErrorType => return rlWrap(mod, scope, rl, try errorType(mod, scope, node.castTag(.ErrorType).?)),
        .For => return forExpr(mod, scope, rl, node.castTag(.For).?),
        .ArrayAccess => return arrayAccess(mod, scope, rl, node.castTag(.ArrayAccess).?),
        .Slice => return rlWrap(mod, scope, rl, try sliceExpr(mod, scope, node.castTag(.Slice).?)),
        .Catch => return catchExpr(mod, scope, rl, node.castTag(.Catch).?),
        .Comptime => return comptimeKeyword(mod, scope, rl, node.castTag(.Comptime).?),
        .OrElse => return orelseExpr(mod, scope, rl, node.castTag(.OrElse).?),

        .Defer => return mod.failNode(scope, node, "TODO implement astgen.expr for .Defer", .{}),
        .Range => return mod.failNode(scope, node, "TODO implement astgen.expr for .Range", .{}),
        .Await => return mod.failNode(scope, node, "TODO implement astgen.expr for .Await", .{}),
        .Resume => return mod.failNode(scope, node, "TODO implement astgen.expr for .Resume", .{}),
        .Try => return mod.failNode(scope, node, "TODO implement astgen.expr for .Try", .{}),
        .ArrayInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializer", .{}),
        .ArrayInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializerDot", .{}),
        .StructInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializer", .{}),
        .StructInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializerDot", .{}),
        .Switch => return mod.failNode(scope, node, "TODO implement astgen.expr for .Switch", .{}),
        .Suspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Suspend", .{}),
        .Continue => return mod.failNode(scope, node, "TODO implement astgen.expr for .Continue", .{}),
        .AnyType => return mod.failNode(scope, node, "TODO implement astgen.expr for .AnyType", .{}),
        .FnProto => return mod.failNode(scope, node, "TODO implement astgen.expr for .FnProto", .{}),
        .ContainerDecl => return mod.failNode(scope, node, "TODO implement astgen.expr for .ContainerDecl", .{}),
        .Nosuspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Nosuspend", .{}),
    }
}

fn comptimeKeyword(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.Comptime) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    return comptimeExpr(mod, scope, rl, node.expr);
}

pub fn comptimeExpr(mod: *Module, parent_scope: *Scope, rl: ResultLoc, node: *ast.Node) InnerError!*zir.Inst {
    const tree = parent_scope.tree();
    const src = tree.token_locs[node.firstToken()].start;

    // Optimization for labeled blocks: don't need to have 2 layers of blocks, we can reuse the existing one.
    if (node.castTag(.LabeledBlock)) |block_node| {
        return labeledBlockExpr(mod, parent_scope, rl, block_node, .block_comptime);
    }

    // Make a scope to collect generated instructions in the sub-expression.
    var block_scope: Scope.GenZIR = .{
        .parent = parent_scope,
        .decl = parent_scope.decl().?,
        .arena = parent_scope.arena(),
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    // No need to capture the result here because block_comptime_flat implies that the final
    // instruction is the block's result value.
    _ = try expr(mod, &block_scope.base, rl, node);

    const block = try addZIRInstBlock(mod, parent_scope, src, .block_comptime_flat, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    return &block.base;
}

fn breakExpr(mod: *Module, parent_scope: *Scope, node: *ast.Node.ControlFlowExpression) InnerError!*zir.Inst {
    const tree = parent_scope.tree();
    const src = tree.token_locs[node.ltoken].start;

    if (node.getLabel()) |break_label| {
        // Look for the label in the scope.
        var scope = parent_scope;
        while (true) {
            switch (scope.tag) {
                .gen_zir => {
                    const gen_zir = scope.cast(Scope.GenZIR).?;
                    if (gen_zir.label) |label| {
                        if (try tokenIdentEql(mod, parent_scope, label.token, break_label)) {
                            if (node.getRHS()) |rhs| {
                                // Most result location types can be forwarded directly; however
                                // if we need to write to a pointer which has an inferred type,
                                // proper type inference requires peer type resolution on the block's
                                // break operand expressions.
                                const branch_rl: ResultLoc = switch (label.result_loc) {
                                    .discard, .none, .ty, .ptr, .ref => label.result_loc,
                                    .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = label.block_inst },
                                };
                                const operand = try expr(mod, parent_scope, branch_rl, rhs);
                                return try addZIRInst(mod, scope, src, zir.Inst.Break, .{
                                    .block = label.block_inst,
                                    .operand = operand,
                                }, .{});
                            } else {
                                return try addZIRInst(mod, scope, src, zir.Inst.BreakVoid, .{
                                    .block = label.block_inst,
                                }, .{});
                            }
                        }
                    }
                    scope = gen_zir.parent;
                },
                .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
                .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
                else => {
                    const label_name = try identifierTokenString(mod, parent_scope, break_label);
                    return mod.failTok(parent_scope, break_label, "label not found: '{}'", .{label_name});
                },
            }
        }
    } else {
        return mod.failNode(parent_scope, &node.base, "TODO implement break from loop", .{});
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
    zir_tag: zir.Inst.Tag,
) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    assert(zir_tag == .block or zir_tag == .block_comptime);

    const tree = parent_scope.tree();
    const src = tree.token_locs[block_node.lbrace].start;

    // Create the Block ZIR instruction so that we can put it into the GenZIR struct
    // so that break statements can reference it.
    const gen_zir = parent_scope.getGenZIR();
    const block_inst = try gen_zir.arena.create(zir.Inst.Block);
    block_inst.* = .{
        .base = .{
            .tag = zir_tag,
            .src = src,
        },
        .positionals = .{
            .body = .{ .instructions = undefined },
        },
        .kw_args = .{},
    };

    var block_scope: Scope.GenZIR = .{
        .parent = parent_scope,
        .decl = parent_scope.decl().?,
        .arena = gen_zir.arena,
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?Scope.GenZIR.Label, Scope.GenZIR.Label{
            .token = block_node.label,
            .block_inst = block_inst,
            .result_loc = rl,
        }),
    };
    defer block_scope.instructions.deinit(mod.gpa);

    try blockExprStmts(mod, &block_scope.base, &block_node.base, block_node.statements());

    block_inst.positionals.body.instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items);
    try gen_zir.instructions.append(mod.gpa, &block_inst.base);

    return &block_inst.base;
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
    if (node.getComptimeToken()) |comptime_token| {
        return mod.failTok(scope, comptime_token, "TODO implement comptime locals", .{});
    }
    if (node.getAlignNode()) |align_node| {
        return mod.failNode(scope, align_node, "TODO implement alignment on locals", .{});
    }
    const tree = scope.tree();
    const name_src = tree.token_locs[node.name_token].start;
    const ident_name = try identifierTokenString(mod, scope, node.name_token);
    const init_node = node.getInitNode() orelse
        return mod.fail(scope, name_src, "variables must be initialized", .{});

    switch (tree.token_ids[node.mut_token]) {
        .Keyword_const => {
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            const result_loc = if (nodeMayNeedMemoryLocation(init_node)) r: {
                if (node.getTypeNode()) |type_node| {
                    const type_inst = try typeExpr(mod, scope, type_node);
                    const alloc = try addZIRUnOp(mod, scope, name_src, .alloc, type_inst);
                    break :r ResultLoc{ .ptr = alloc };
                } else {
                    const alloc = try addZIRNoOpT(mod, scope, name_src, .alloc_inferred);
                    break :r ResultLoc{ .inferred_ptr = alloc };
                }
            } else r: {
                if (node.getTypeNode()) |type_node|
                    break :r ResultLoc{ .ty = try typeExpr(mod, scope, type_node) }
                else
                    break :r .none;
            };
            const init_inst = try expr(mod, scope, result_loc, init_node);
            const sub_scope = try block_arena.create(Scope.LocalVal);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = scope.getGenZIR(),
                .name = ident_name,
                .inst = init_inst,
            };
            return &sub_scope.base;
        },
        .Keyword_var => {
            const var_data: struct { result_loc: ResultLoc, alloc: *zir.Inst } = if (node.getTypeNode()) |type_node| a: {
                const type_inst = try typeExpr(mod, scope, type_node);
                const alloc = try addZIRUnOp(mod, scope, name_src, .alloc, type_inst);
                break :a .{ .alloc = alloc, .result_loc = .{ .ptr = alloc } };
            } else a: {
                const alloc = try addZIRNoOp(mod, scope, name_src, .alloc_inferred);
                break :a .{ .alloc = alloc, .result_loc = .{ .inferred_ptr = alloc.castTag(.alloc_inferred).? } };
            };
            const init_inst = try expr(mod, scope, var_data.result_loc, init_node);
            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = scope.getGenZIR(),
                .name = ident_name,
                .ptr = var_data.alloc,
            };
            return &sub_scope.base;
        },
        else => unreachable,
    }
}

fn assign(mod: *Module, scope: *Scope, infix_node: *ast.Node.SimpleInfixOp) InnerError!void {
    if (infix_node.lhs.castTag(.Identifier)) |ident| {
        // This intentionally does not support @"_" syntax.
        const ident_name = scope.tree().tokenSlice(ident.token);
        if (mem.eql(u8, ident_name, "_")) {
            _ = try expr(mod, scope, .discard, infix_node.rhs);
            return;
        }
    }
    const lvalue = try lvalExpr(mod, scope, infix_node.lhs);
    _ = try expr(mod, scope, .{ .ptr = lvalue }, infix_node.rhs);
}

fn assignOp(
    mod: *Module,
    scope: *Scope,
    infix_node: *ast.Node.SimpleInfixOp,
    op_inst_tag: zir.Inst.Tag,
) InnerError!void {
    const lhs_ptr = try lvalExpr(mod, scope, infix_node.lhs);
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

fn bitNot(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const operand = try expr(mod, scope, .none, node.rhs);
    return addZIRUnOp(mod, scope, src, .bitnot, operand);
}

fn negation(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp, op_inst_tag: zir.Inst.Tag) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;

    const lhs = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_int),
        .val = Value.initTag(.zero),
    });
    const rhs = try expr(mod, scope, .none, node.rhs);

    return addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
}

fn addressOf(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    return expr(mod, scope, .ref, node.rhs);
}

fn optionalType(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const operand = try typeExpr(mod, scope, node.rhs);
    return addZIRUnOp(mod, scope, src, .optional_type, operand);
}

fn sliceType(mod: *Module, scope: *Scope, node: *ast.Node.SliceType) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    return ptrSliceType(mod, scope, src, &node.ptr_info, node.rhs, .Slice);
}

fn ptrType(mod: *Module, scope: *Scope, node: *ast.Node.PtrType) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    return ptrSliceType(mod, scope, src, &node.ptr_info, node.rhs, switch (tree.token_ids[node.op_token]) {
        .Asterisk, .AsteriskAsterisk => .One,
        // TODO stage1 type inference bug
        .LBracket => @as(std.builtin.TypeInfo.Pointer.Size, switch (tree.token_ids[node.op_token + 2]) {
            .Identifier => .C,
            else => .Many,
        }),
        else => unreachable,
    });
}

fn ptrSliceType(mod: *Module, scope: *Scope, src: usize, ptr_info: *ast.PtrInfo, rhs: *ast.Node, size: std.builtin.TypeInfo.Pointer.Size) InnerError!*zir.Inst {
    const simple = ptr_info.allowzero_token == null and
        ptr_info.align_info == null and
        ptr_info.volatile_token == null and
        ptr_info.sentinel == null;

    if (simple) {
        const child_type = try typeExpr(mod, scope, rhs);
        const mutable = ptr_info.const_token == null;
        // TODO stage1 type inference bug
        const T = zir.Inst.Tag;
        return addZIRUnOp(mod, scope, src, switch (size) {
            .One => if (mutable) T.single_mut_ptr_type else T.single_const_ptr_type,
            .Many => if (mutable) T.many_mut_ptr_type else T.many_const_ptr_type,
            .C => if (mutable) T.c_mut_ptr_type else T.c_const_ptr_type,
            .Slice => if (mutable) T.mut_slice_type else T.const_slice_type,
        }, child_type);
    }

    var kw_args: std.meta.fieldInfo(zir.Inst.PtrType, "kw_args").field_type = .{};
    kw_args.size = size;
    kw_args.@"allowzero" = ptr_info.allowzero_token != null;
    if (ptr_info.align_info) |some| {
        kw_args.@"align" = try expr(mod, scope, .none, some.node);
        if (some.bit_range) |bit_range| {
            kw_args.align_bit_start = try expr(mod, scope, .none, bit_range.start);
            kw_args.align_bit_end = try expr(mod, scope, .none, bit_range.end);
        }
    }
    kw_args.mutable = ptr_info.const_token == null;
    kw_args.@"volatile" = ptr_info.volatile_token != null;
    if (ptr_info.sentinel) |some| {
        kw_args.sentinel = try expr(mod, scope, .none, some);
    }

    const child_type = try typeExpr(mod, scope, rhs);
    if (kw_args.sentinel) |some| {
        kw_args.sentinel = try addZIRBinOp(mod, scope, some.src, .as, child_type, some);
    }

    return addZIRInst(mod, scope, src, zir.Inst.PtrType, .{ .child_type = child_type }, kw_args);
}

fn arrayType(mod: *Module, scope: *Scope, node: *ast.Node.ArrayType) !*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });

    // TODO check for [_]T
    const len = try expr(mod, scope, .{ .ty = usize_type }, node.len_expr);
    const elem_type = try typeExpr(mod, scope, node.rhs);

    return addZIRBinOp(mod, scope, src, .array_type, len, elem_type);
}

fn arrayTypeSentinel(mod: *Module, scope: *Scope, node: *ast.Node.ArrayTypeSentinel) !*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });

    // TODO check for [_]T
    const len = try expr(mod, scope, .{ .ty = usize_type }, node.len_expr);
    const sentinel_uncasted = try expr(mod, scope, .none, node.sentinel);
    const elem_type = try typeExpr(mod, scope, node.rhs);
    const sentinel = try addZIRBinOp(mod, scope, src, .as, elem_type, sentinel_uncasted);

    return addZIRInst(mod, scope, src, zir.Inst.ArrayTypeSentinel, .{
        .len = len,
        .sentinel = sentinel,
        .elem_type = elem_type,
    }, .{});
}

fn anyFrameType(mod: *Module, scope: *Scope, node: *ast.Node.AnyFrameType) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.anyframe_token].start;
    if (node.result) |some| {
        const return_type = try typeExpr(mod, scope, some.return_type);
        return addZIRUnOp(mod, scope, src, .anyframe_type, return_type);
    } else {
        return addZIRInstConst(mod, scope, src, .{
            .ty = Type.initTag(.type),
            .val = Value.initTag(.anyframe_type),
        });
    }
}

fn typeInixOp(mod: *Module, scope: *Scope, node: *ast.Node.SimpleInfixOp, op_inst_tag: zir.Inst.Tag) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const error_set = try typeExpr(mod, scope, node.lhs);
    const payload = try typeExpr(mod, scope, node.rhs);
    return addZIRBinOp(mod, scope, src, op_inst_tag, error_set, payload);
}

fn enumLiteral(mod: *Module, scope: *Scope, node: *ast.Node.EnumLiteral) !*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.name].start;
    const name = try identifierTokenString(mod, scope, node.name);

    return addZIRInst(mod, scope, src, zir.Inst.EnumLiteral, .{ .name = name }, .{});
}

fn unwrapOptional(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleSuffixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;

    const operand = try expr(mod, scope, .ref, node.lhs);
    return rlWrapPtr(mod, scope, rl, try addZIRUnOp(mod, scope, src, .unwrap_optional_safe, operand));
}

fn errorSetDecl(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.ErrorSetDecl) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.error_token].start;
    const decls = node.decls();
    const fields = try scope.arena().alloc([]const u8, decls.len);

    for (decls) |decl, i| {
        const tag = decl.castTag(.ErrorTag).?;
        fields[i] = try identifierTokenString(mod, scope, tag.name_token);
    }

    // analyzing the error set results in a decl ref, so we might need to dereference it
    return rlWrapPtr(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.ErrorSet, .{ .fields = fields }, .{}));
}

fn errorType(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.anyerror_type),
    });
}

fn catchExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.Catch) InnerError!*zir.Inst {
    return orelseCatchExpr(mod, scope, rl, node.lhs, node.op_token, .iserr, .unwrap_err_unsafe, node.rhs, node.payload);
}

fn orelseExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    return orelseCatchExpr(mod, scope, rl, node.lhs, node.op_token, .isnull, .unwrap_optional_unsafe, node.rhs, null);
}

fn orelseCatchExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    lhs: *ast.Node,
    op_token: ast.TokenIndex,
    cond_op: zir.Inst.Tag,
    unwrap_op: zir.Inst.Tag,
    rhs: *ast.Node,
    payload_node: ?*ast.Node,
) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[op_token].start;

    const operand_ptr = try expr(mod, scope, .ref, lhs);
    // TODO we could avoid an unnecessary copy if .iserr, .isnull took a pointer
    const err_union = try addZIRUnOp(mod, scope, src, .deref, operand_ptr);
    const cond = try addZIRUnOp(mod, scope, src, cond_op, err_union);

    var block_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.decl().?,
        .arena = scope.arena(),
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, src, .block, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the if's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .ref => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = block },
    };

    var then_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    var err_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = blk: {
        const payload = payload_node orelse
            break :blk &then_scope.base;

        const err_name = tree.tokenSlice(payload.castTag(.Payload).?.error_symbol.firstToken());
        if (mem.eql(u8, err_name, "_"))
            break :blk &then_scope.base;

        const unwrapped_err_ptr = try addZIRUnOp(mod, &then_scope.base, src, .unwrap_err_code, operand_ptr);
        err_val_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = err_name,
            .inst = try addZIRUnOp(mod, &then_scope.base, src, .deref, unwrapped_err_ptr),
        };
        break :blk &err_val_scope.base;
    };

    _ = try addZIRInst(mod, &then_scope.base, src, zir.Inst.Break, .{
        .block = block,
        .operand = try expr(mod, then_sub_scope, branch_rl, rhs),
    }, .{});

    var else_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    const unwrapped_payload = try addZIRUnOp(mod, &else_scope.base, src, unwrap_op, operand_ptr);
    _ = try addZIRInst(mod, &else_scope.base, src, zir.Inst.Break, .{
        .block = block,
        .operand = unwrapped_payload,
    }, .{});

    condbr.positionals.then_body = .{ .instructions = try then_scope.arena.dupe(*zir.Inst, then_scope.instructions.items) };
    condbr.positionals.else_body = .{ .instructions = try else_scope.arena.dupe(*zir.Inst, else_scope.instructions.items) };
    return rlWrapPtr(mod, scope, rl, &block.base);
}

/// Return whether the identifier names of two tokens are equal. Resolves @"" tokens without allocating.
/// OK in theory it could do it without allocating. This implementation allocates when the @"" form is used.
fn tokenIdentEql(mod: *Module, scope: *Scope, token1: ast.TokenIndex, token2: ast.TokenIndex) !bool {
    const ident_name_1 = try identifierTokenString(mod, scope, token1);
    const ident_name_2 = try identifierTokenString(mod, scope, token2);
    return mem.eql(u8, ident_name_1, ident_name_2);
}

/// Identifier token -> String (allocated in scope.arena())
fn identifierTokenString(mod: *Module, scope: *Scope, token: ast.TokenIndex) InnerError![]const u8 {
    const tree = scope.tree();

    const ident_name = tree.tokenSlice(token);
    if (mem.startsWith(u8, ident_name, "@")) {
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

fn field(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;

    const lhs = try expr(mod, scope, .ref, node.lhs);
    const field_name = try identifierStringInst(mod, scope, node.rhs.castTag(.Identifier).?);

    return rlWrapPtr(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.FieldPtr, .{ .object_ptr = lhs, .field_name = field_name }, .{}));
}

fn arrayAccess(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.ArrayAccess) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;

    const array_ptr = try expr(mod, scope, .ref, node.lhs);
    const index = try expr(mod, scope, .none, node.index_expr);

    return rlWrapPtr(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.ElemPtr, .{ .array_ptr = array_ptr, .index = index }, .{}));
}

fn sliceExpr(mod: *Module, scope: *Scope, node: *ast.Node.Slice) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;

    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });

    const array_ptr = try expr(mod, scope, .ref, node.lhs);
    const start = try expr(mod, scope, .{ .ty = usize_type }, node.start);

    if (node.end == null and node.sentinel == null) {
        return try addZIRBinOp(mod, scope, src, .slice_start, array_ptr, start);
    }

    const end = if (node.end) |end| try expr(mod, scope, .{ .ty = usize_type }, end) else null;
    // we could get the child type here, but it is easier to just do it in semantic analysis.
    const sentinel = if (node.sentinel) |sentinel| try expr(mod, scope, .none, sentinel) else null;

    return try addZIRInst(
        mod,
        scope,
        src,
        zir.Inst.Slice,
        .{ .array_ptr = array_ptr, .start = start },
        .{ .end = end, .sentinel = sentinel },
    );
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

fn boolBinOp(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    infix_node: *ast.Node.SimpleInfixOp,
) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[infix_node.op_token].start;
    const bool_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });

    var block_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.decl().?,
        .arena = scope.arena(),
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    const lhs = try expr(mod, scope, .{ .ty = bool_type }, infix_node.lhs);
    const condbr = try addZIRInstSpecial(mod, &block_scope.base, src, zir.Inst.CondBr, .{
        .condition = lhs,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, src, .block, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    var rhs_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer rhs_scope.instructions.deinit(mod.gpa);

    const rhs = try expr(mod, &rhs_scope.base, .{ .ty = bool_type }, infix_node.rhs);
    _ = try addZIRInst(mod, &rhs_scope.base, src, zir.Inst.Break, .{
        .block = block,
        .operand = rhs,
    }, .{});

    var const_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer const_scope.instructions.deinit(mod.gpa);

    const is_bool_and = infix_node.base.tag == .BoolAnd;
    _ = try addZIRInst(mod, &const_scope.base, src, zir.Inst.Break, .{
        .block = block,
        .operand = try addZIRInstConst(mod, &const_scope.base, src, .{
            .ty = Type.initTag(.bool),
            .val = if (is_bool_and) Value.initTag(.bool_false) else Value.initTag(.bool_true),
        }),
    }, .{});

    if (is_bool_and) {
        // if lhs // AND
        //     break rhs
        // else
        //     break false
        condbr.positionals.then_body = .{ .instructions = try rhs_scope.arena.dupe(*zir.Inst, rhs_scope.instructions.items) };
        condbr.positionals.else_body = .{ .instructions = try const_scope.arena.dupe(*zir.Inst, const_scope.instructions.items) };
    } else {
        // if lhs // OR
        //     break true
        // else
        //     break rhs
        condbr.positionals.then_body = .{ .instructions = try const_scope.arena.dupe(*zir.Inst, const_scope.instructions.items) };
        condbr.positionals.else_body = .{ .instructions = try rhs_scope.arena.dupe(*zir.Inst, rhs_scope.instructions.items) };
    }

    return rlWrap(mod, scope, rl, &block.base);
}

const CondKind = union(enum) {
    bool,
    optional: ?*zir.Inst,
    err_union: ?*zir.Inst,

    fn cond(self: *CondKind, mod: *Module, block_scope: *Scope.GenZIR, src: usize, cond_node: *ast.Node) !*zir.Inst {
        switch (self.*) {
            .bool => {
                const bool_type = try addZIRInstConst(mod, &block_scope.base, src, .{
                    .ty = Type.initTag(.type),
                    .val = Value.initTag(.bool_type),
                });
                return try expr(mod, &block_scope.base, .{ .ty = bool_type }, cond_node);
            },
            .optional => {
                const cond_ptr = try expr(mod, &block_scope.base, .ref, cond_node);
                self.* = .{ .optional = cond_ptr };
                const result = try addZIRUnOp(mod, &block_scope.base, src, .deref, cond_ptr);
                return try addZIRUnOp(mod, &block_scope.base, src, .isnonnull, result);
            },
            .err_union => {
                const err_ptr = try expr(mod, &block_scope.base, .ref, cond_node);
                self.* = .{ .err_union = err_ptr };
                const result = try addZIRUnOp(mod, &block_scope.base, src, .deref, err_ptr);
                return try addZIRUnOp(mod, &block_scope.base, src, .iserr, result);
            },
        }
    }

    fn thenSubScope(self: CondKind, mod: *Module, then_scope: *Scope.GenZIR, src: usize, payload_node: ?*ast.Node) !*Scope {
        if (self == .bool) return &then_scope.base;

        const payload = payload_node.?.castTag(.PointerPayload) orelse {
            // condition is error union and payload is not explicitly ignored
            _ = try addZIRUnOp(mod, &then_scope.base, src, .ensure_err_payload_void, self.err_union.?);
            return &then_scope.base;
        };
        const is_ptr = payload.ptr_token != null;
        const ident_node = payload.value_symbol.castTag(.Identifier).?;

        // This intentionally does not support @"_" syntax.
        const ident_name = then_scope.base.tree().tokenSlice(ident_node.token);
        if (mem.eql(u8, ident_name, "_")) {
            if (is_ptr)
                return mod.failTok(&then_scope.base, payload.ptr_token.?, "pointer modifier invalid on discard", .{});
            return &then_scope.base;
        }

        return mod.failNode(&then_scope.base, payload.value_symbol, "TODO implement payload symbols", .{});
    }

    fn elseSubScope(self: CondKind, mod: *Module, else_scope: *Scope.GenZIR, src: usize, payload_node: ?*ast.Node) !*Scope {
        if (self != .err_union) return &else_scope.base;

        const payload_ptr = try addZIRUnOp(mod, &else_scope.base, src, .unwrap_err_unsafe, self.err_union.?);

        const payload = payload_node.?.castTag(.Payload).?;
        const ident_node = payload.error_symbol.castTag(.Identifier).?;

        // This intentionally does not support @"_" syntax.
        const ident_name = else_scope.base.tree().tokenSlice(ident_node.token);
        if (mem.eql(u8, ident_name, "_")) {
            return &else_scope.base;
        }

        return mod.failNode(&else_scope.base, payload.error_symbol, "TODO implement payload symbols", .{});
    }
};

fn ifExpr(mod: *Module, scope: *Scope, rl: ResultLoc, if_node: *ast.Node.If) InnerError!*zir.Inst {
    var cond_kind: CondKind = .bool;
    if (if_node.payload) |_| cond_kind = .{ .optional = null };
    if (if_node.@"else") |else_node| {
        if (else_node.payload) |payload| {
            cond_kind = .{ .err_union = null };
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
    const cond = try cond_kind.cond(mod, &block_scope, if_src, if_node.condition);

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, if_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, if_src, .block, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    const then_src = tree.token_locs[if_node.body.lastToken()].start;
    var then_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // declare payload to the then_scope
    const then_sub_scope = try cond_kind.thenSubScope(mod, &then_scope, then_src, if_node.payload);

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the if's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .ref => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = block },
    };

    const then_result = try expr(mod, then_sub_scope, branch_rl, if_node.body);
    if (!then_result.tag.isNoReturn()) {
        _ = try addZIRInst(mod, then_sub_scope, then_src, zir.Inst.Break, .{
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
        const else_src = tree.token_locs[else_node.body.lastToken()].start;
        // declare payload to the then_scope
        const else_sub_scope = try cond_kind.elseSubScope(mod, &else_scope, else_src, else_node.payload);

        const else_result = try expr(mod, else_sub_scope, branch_rl, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            _ = try addZIRInst(mod, else_sub_scope, else_src, zir.Inst.Break, .{
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
    var cond_kind: CondKind = .bool;
    if (while_node.payload) |_| cond_kind = .{ .optional = null };
    if (while_node.@"else") |else_node| {
        if (else_node.payload) |payload| {
            cond_kind = .{ .err_union = null };
        }
    }

    if (while_node.label) |tok|
        return mod.failTok(scope, tok, "TODO labeled while", .{});

    if (while_node.inline_token) |tok|
        return mod.failTok(scope, tok, "TODO inline while", .{});

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
    const void_type = try addZIRInstConst(mod, scope, while_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const cond = try cond_kind.cond(mod, &continue_scope, while_src, while_node.condition);

    const condbr = try addZIRInstSpecial(mod, &continue_scope.base, while_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});
    const cond_block = try addZIRInstBlock(mod, &loop_scope.base, while_src, .block, .{
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
    const while_block = try addZIRInstBlock(mod, scope, while_src, .block, .{
        .instructions = try expr_scope.arena.dupe(*zir.Inst, expr_scope.instructions.items),
    });

    const then_src = tree.token_locs[while_node.body.lastToken()].start;
    var then_scope: Scope.GenZIR = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // declare payload to the then_scope
    const then_sub_scope = try cond_kind.thenSubScope(mod, &then_scope, then_src, while_node.payload);

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the while's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .ref => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = while_block },
    };

    const then_result = try expr(mod, then_sub_scope, branch_rl, while_node.body);
    if (!then_result.tag.isNoReturn()) {
        _ = try addZIRInst(mod, then_sub_scope, then_src, zir.Inst.Break, .{
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
        const else_src = tree.token_locs[else_node.body.lastToken()].start;
        // declare payload to the then_scope
        const else_sub_scope = try cond_kind.elseSubScope(mod, &else_scope, else_src, else_node.payload);

        const else_result = try expr(mod, else_sub_scope, branch_rl, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            _ = try addZIRInst(mod, else_sub_scope, else_src, zir.Inst.Break, .{
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

fn forExpr(mod: *Module, scope: *Scope, rl: ResultLoc, for_node: *ast.Node.For) InnerError!*zir.Inst {
    if (for_node.label) |tok|
        return mod.failTok(scope, tok, "TODO labeled for", .{});

    if (for_node.inline_token) |tok|
        return mod.failTok(scope, tok, "TODO inline for", .{});

    var for_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.decl().?,
        .arena = scope.arena(),
        .instructions = .{},
    };
    defer for_scope.instructions.deinit(mod.gpa);

    // setup variables and constants
    const tree = scope.tree();
    const for_src = tree.token_locs[for_node.for_token].start;
    const index_ptr = blk: {
        const usize_type = try addZIRInstConst(mod, &for_scope.base, for_src, .{
            .ty = Type.initTag(.type),
            .val = Value.initTag(.usize_type),
        });
        const index_ptr = try addZIRUnOp(mod, &for_scope.base, for_src, .alloc, usize_type);
        // initialize to zero
        const zero = try addZIRInstConst(mod, &for_scope.base, for_src, .{
            .ty = Type.initTag(.usize),
            .val = Value.initTag(.zero),
        });
        _ = try addZIRBinOp(mod, &for_scope.base, for_src, .store, index_ptr, zero);
        break :blk index_ptr;
    };
    const array_ptr = try expr(mod, &for_scope.base, .ref, for_node.array_expr);
    _ = try addZIRUnOp(mod, &for_scope.base, for_node.array_expr.firstToken(), .ensure_indexable, array_ptr);
    const cond_src = tree.token_locs[for_node.array_expr.firstToken()].start;
    const len_ptr = try addZIRInst(mod, &for_scope.base, cond_src, zir.Inst.FieldPtr, .{
        .object_ptr = array_ptr,
        .field_name = try addZIRInst(mod, &for_scope.base, cond_src, zir.Inst.Str, .{ .bytes = "len" }, .{}),
    }, .{});

    var loop_scope: Scope.GenZIR = .{
        .parent = &for_scope.base,
        .decl = for_scope.decl,
        .arena = for_scope.arena,
        .instructions = .{},
    };
    defer loop_scope.instructions.deinit(mod.gpa);

    var cond_scope: Scope.GenZIR = .{
        .parent = &loop_scope.base,
        .decl = loop_scope.decl,
        .arena = loop_scope.arena,
        .instructions = .{},
    };
    defer cond_scope.instructions.deinit(mod.gpa);

    // check condition i < array_expr.len
    const index = try addZIRUnOp(mod, &cond_scope.base, cond_src, .deref, index_ptr);
    const len = try addZIRUnOp(mod, &cond_scope.base, cond_src, .deref, len_ptr);
    const cond = try addZIRBinOp(mod, &cond_scope.base, cond_src, .cmp_lt, index, len);

    const condbr = try addZIRInstSpecial(mod, &cond_scope.base, for_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});
    const cond_block = try addZIRInstBlock(mod, &loop_scope.base, for_src, .block, .{
        .instructions = try loop_scope.arena.dupe(*zir.Inst, cond_scope.instructions.items),
    });

    // increment index variable
    const one = try addZIRInstConst(mod, &loop_scope.base, for_src, .{
        .ty = Type.initTag(.usize),
        .val = Value.initTag(.one),
    });
    const index_2 = try addZIRUnOp(mod, &loop_scope.base, cond_src, .deref, index_ptr);
    const index_plus_one = try addZIRBinOp(mod, &loop_scope.base, for_src, .add, index_2, one);
    _ = try addZIRBinOp(mod, &loop_scope.base, for_src, .store, index_ptr, index_plus_one);

    // looping stuff
    const loop = try addZIRInstLoop(mod, &for_scope.base, for_src, .{
        .instructions = try for_scope.arena.dupe(*zir.Inst, loop_scope.instructions.items),
    });
    const for_block = try addZIRInstBlock(mod, scope, for_src, .block, .{
        .instructions = try for_scope.arena.dupe(*zir.Inst, for_scope.instructions.items),
    });

    // while body
    const then_src = tree.token_locs[for_node.body.lastToken()].start;
    var then_scope: Scope.GenZIR = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // Most result location types can be forwarded directly; however
    // if we need to write to a pointer which has an inferred type,
    // proper type inference requires peer type resolution on the while's
    // branches.
    const branch_rl: ResultLoc = switch (rl) {
        .discard, .none, .ty, .ptr, .ref => rl,
        .inferred_ptr, .bitcasted_ptr, .block_ptr => .{ .block_ptr = for_block },
    };

    var index_scope: Scope.LocalPtr = undefined;
    const then_sub_scope = blk: {
        const payload = for_node.payload.castTag(.PointerIndexPayload).?;
        const is_ptr = payload.ptr_token != null;
        const value_name = tree.tokenSlice(payload.value_symbol.firstToken());
        if (!mem.eql(u8, value_name, "_")) {
            return mod.failNode(&then_scope.base, payload.value_symbol, "TODO implement for value payload", .{});
        } else if (is_ptr) {
            return mod.failTok(&then_scope.base, payload.ptr_token.?, "pointer modifier invalid on discard", .{});
        }

        const index_symbol_node = payload.index_symbol orelse
            break :blk &then_scope.base;

        const index_name = tree.tokenSlice(index_symbol_node.firstToken());
        if (mem.eql(u8, index_name, "_")) {
            break :blk &then_scope.base;
        }
        // TODO make this const without an extra copy?
        index_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = index_name,
            .ptr = index_ptr,
        };
        break :blk &index_scope.base;
    };

    const then_result = try expr(mod, then_sub_scope, branch_rl, for_node.body);
    if (!then_result.tag.isNoReturn()) {
        _ = try addZIRInst(mod, then_sub_scope, then_src, zir.Inst.Break, .{
            .block = cond_block,
            .operand = then_result,
        }, .{});
    }
    condbr.positionals.then_body = .{
        .instructions = try then_scope.arena.dupe(*zir.Inst, then_scope.instructions.items),
    };

    // else branch
    var else_scope: Scope.GenZIR = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    if (for_node.@"else") |else_node| {
        const else_src = tree.token_locs[else_node.body.lastToken()].start;
        const else_result = try expr(mod, &else_scope.base, branch_rl, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.Break, .{
                .block = for_block,
                .operand = else_result,
            }, .{});
        }
    } else {
        const else_src = tree.token_locs[for_node.lastToken()].start;
        _ = try addZIRInst(mod, &else_scope.base, else_src, zir.Inst.BreakVoid, .{
            .block = for_block,
        }, .{});
    }
    condbr.positionals.else_body = .{
        .instructions = try else_scope.arena.dupe(*zir.Inst, else_scope.instructions.items),
    };
    return &for_block.base;
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
                        .ty = Type.initTag(.type),
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
                    return rlWrapPtr(mod, scope, rl, local_ptr.ptr);
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(Scope.GenZIR).?.parent,
            else => break,
        };
    }

    if (mod.lookupDeclName(scope, ident_name)) |decl| {
        return rlWrapPtr(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.DeclValInModule, .{ .decl = decl }, .{}));
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

fn multilineStrLiteral(mod: *Module, scope: *Scope, node: *ast.Node.MultilineStringLiteral) !*zir.Inst {
    const tree = scope.tree();
    const lines = node.linesConst();
    const src = tree.token_locs[lines[0]].start;

    // line lengths and new lines
    var len = lines.len - 1;
    for (lines) |line| {
        // 2 for the '//' + 1 for '\n'
        len += tree.tokenSlice(line).len - 3;
    }

    const bytes = try scope.arena().alloc(u8, len);
    var i: usize = 0;
    for (lines) |line, line_i| {
        if (line_i != 0) {
            bytes[i] = '\n';
            i += 1;
        }
        const slice = tree.tokenSlice(line);
        mem.copy(u8, bytes[i..], slice[2 .. slice.len - 1]);
        i += slice.len - 3;
    }

    return addZIRInst(mod, scope, src, zir.Inst.Str, .{ .bytes = bytes }, .{});
}

fn charLiteral(mod: *Module, scope: *Scope, node: *ast.Node.OneToken) !*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;
    const slice = tree.tokenSlice(node.token);

    var bad_index: usize = undefined;
    const value = std.zig.parseCharLiteral(slice, &bad_index) catch |err| switch (err) {
        error.InvalidCharacter => {
            const bad_byte = slice[bad_index];
            return mod.fail(scope, src + bad_index, "invalid character: '{c}'\n", .{bad_byte});
        },
    };

    const int_payload = try scope.arena().create(Value.Payload.Int_u64);
    int_payload.* = .{ .int = value };
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_int),
        .val = Value.initPayload(&int_payload.base),
    });
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
    const params = call.params();
    const dest_type = try typeExpr(mod, scope, params[0]);
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
        .ref => {
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
    const params = call.params();
    const dest_type = try typeExpr(mod, scope, params[0]);
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
        .ref => {
            const operand = try expr(mod, scope, .ref, params[1]);
            const result = try addZIRBinOp(mod, scope, src, .bitcast_ref, dest_type, operand);
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
    } else if (mem.eql(u8, builtin_name, "@breakpoint")) {
        const src = tree.token_locs[call.builtin_token].start;
        return rlWrap(mod, scope, rl, try addZIRNoOp(mod, scope, src, .breakpoint));
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
        .ref => {
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

fn rlWrapPtr(mod: *Module, scope: *Scope, rl: ResultLoc, ptr: *zir.Inst) InnerError!*zir.Inst {
    if (rl == .ref) return ptr;

    return rlWrap(mod, scope, rl, try addZIRUnOp(mod, scope, ptr.src, .deref, ptr));
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

pub fn addZIRInstBlock(
    mod: *Module,
    scope: *Scope,
    src: usize,
    tag: zir.Inst.Tag,
    body: zir.Module.Body,
) !*zir.Inst.Block {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(zir.Inst.Block);
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = .{
            .body = body,
        },
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return inst;
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
pub fn addZIRInstLoop(mod: *Module, scope: *Scope, src: usize, body: zir.Module.Body) !*zir.Inst.Loop {
    const P = std.meta.fieldInfo(zir.Inst.Loop, "positionals").field_type;
    return addZIRInstSpecial(mod, scope, src, zir.Inst.Loop, P{ .body = body }, .{});
}
