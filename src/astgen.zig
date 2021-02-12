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
    /// expression should be generated. The result instruction from the expression must
    /// be ignored.
    discard,
    /// The expression has an inferred type, and it will be evaluated as an rvalue.
    none,
    /// The expression must generate a pointer rather than a value. For example, the left hand side
    /// of an assignment uses this kind of result location.
    ref,
    /// The expression will be coerced into this type, but it will be evaluated as an rvalue.
    ty: *zir.Inst,
    /// The expression must store its result into this typed pointer. The result instruction
    /// from the expression must be ignored.
    ptr: *zir.Inst,
    /// The expression must store its result into this allocation, which has an inferred type.
    /// The result instruction from the expression must be ignored.
    inferred_ptr: *zir.Inst.Tag.alloc_inferred.Type(),
    /// The expression must store its result into this pointer, which is a typed pointer that
    /// has been bitcasted to whatever the expression's type is.
    /// The result instruction from the expression must be ignored.
    bitcasted_ptr: *zir.Inst.UnOp,
    /// There is a pointer for the expression to store its result into, however, its type
    /// is inferred based on peer type resolution for a `zir.Inst.Block`.
    /// The result instruction from the expression must be ignored.
    block_ptr: *Module.Scope.GenZIR,

    pub const Strategy = struct {
        elide_store_to_block_ptr_instructions: bool,
        tag: Tag,

        pub const Tag = enum {
            /// Both branches will use break_void; result location is used to communicate the
            /// result instruction.
            break_void,
            /// Use break statements to pass the block result value, and call rvalue() at
            /// the end depending on rl. Also elide the store_to_block_ptr instructions
            /// depending on rl.
            break_operand,
        };
    };
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
        .UnwrapOptional,
        .Deref,
        .Period,
        .ArrayAccess,
        .Identifier,
        .GroupedExpression,
        .OrElse,
        => {},
    }
    return expr(mod, scope, .ref, node);
}

/// Turn Zig AST into untyped ZIR istructions.
/// When `rl` is discard, ptr, inferred_ptr, bitcasted_ptr, or inferred_ptr, the
/// result instruction can be used to inspect whether it is isNoReturn() but that is it,
/// it must otherwise not be used.
pub fn expr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node) InnerError!*zir.Inst {
    switch (node.tag) {
        .Root => unreachable, // Top-level declaration.
        .Use => unreachable, // Top-level declaration.
        .TestDecl => unreachable, // Top-level declaration.
        .DocComment => unreachable, // Top-level declaration.
        .VarDecl => unreachable, // Handled in `blockExpr`.
        .SwitchCase => unreachable, // Handled in `switchExpr`.
        .SwitchElse => unreachable, // Handled in `switchExpr`.
        .Range => unreachable, // Handled in `switchExpr`.
        .Else => unreachable, // Handled explicitly the control flow expression functions.
        .Payload => unreachable, // Handled explicitly.
        .PointerPayload => unreachable, // Handled explicitly.
        .PointerIndexPayload => unreachable, // Handled explicitly.
        .ErrorTag => unreachable, // Handled explicitly.
        .FieldInitializer => unreachable, // Handled explicitly.
        .ContainerField => unreachable, // Handled explicitly.

        .Assign => return rvalueVoid(mod, scope, rl, node, try assign(mod, scope, node.castTag(.Assign).?)),
        .AssignBitAnd => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitAnd).?, .bit_and)),
        .AssignBitOr => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitOr).?, .bit_or)),
        .AssignBitShiftLeft => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitShiftLeft).?, .shl)),
        .AssignBitShiftRight => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitShiftRight).?, .shr)),
        .AssignBitXor => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignBitXor).?, .xor)),
        .AssignDiv => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignDiv).?, .div)),
        .AssignSub => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignSub).?, .sub)),
        .AssignSubWrap => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignSubWrap).?, .subwrap)),
        .AssignMod => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMod).?, .mod_rem)),
        .AssignAdd => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignAdd).?, .add)),
        .AssignAddWrap => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignAddWrap).?, .addwrap)),
        .AssignMul => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMul).?, .mul)),
        .AssignMulWrap => return rvalueVoid(mod, scope, rl, node, try assignOp(mod, scope, node.castTag(.AssignMulWrap).?, .mulwrap)),

        .Add => return simpleBinOp(mod, scope, rl, node.castTag(.Add).?, .add),
        .AddWrap => return simpleBinOp(mod, scope, rl, node.castTag(.AddWrap).?, .addwrap),
        .Sub => return simpleBinOp(mod, scope, rl, node.castTag(.Sub).?, .sub),
        .SubWrap => return simpleBinOp(mod, scope, rl, node.castTag(.SubWrap).?, .subwrap),
        .Mul => return simpleBinOp(mod, scope, rl, node.castTag(.Mul).?, .mul),
        .MulWrap => return simpleBinOp(mod, scope, rl, node.castTag(.MulWrap).?, .mulwrap),
        .Div => return simpleBinOp(mod, scope, rl, node.castTag(.Div).?, .div),
        .Mod => return simpleBinOp(mod, scope, rl, node.castTag(.Mod).?, .mod_rem),
        .BitAnd => return simpleBinOp(mod, scope, rl, node.castTag(.BitAnd).?, .bit_and),
        .BitOr => return simpleBinOp(mod, scope, rl, node.castTag(.BitOr).?, .bit_or),
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

        .BoolNot => return rvalue(mod, scope, rl, try boolNot(mod, scope, node.castTag(.BoolNot).?)),
        .BitNot => return rvalue(mod, scope, rl, try bitNot(mod, scope, node.castTag(.BitNot).?)),
        .Negation => return rvalue(mod, scope, rl, try negation(mod, scope, node.castTag(.Negation).?, .sub)),
        .NegationWrap => return rvalue(mod, scope, rl, try negation(mod, scope, node.castTag(.NegationWrap).?, .subwrap)),

        .Identifier => return try identifier(mod, scope, rl, node.castTag(.Identifier).?),
        .Asm => return rvalue(mod, scope, rl, try assembly(mod, scope, node.castTag(.Asm).?)),
        .StringLiteral => return rvalue(mod, scope, rl, try stringLiteral(mod, scope, node.castTag(.StringLiteral).?)),
        .IntegerLiteral => return rvalue(mod, scope, rl, try integerLiteral(mod, scope, node.castTag(.IntegerLiteral).?)),
        .BuiltinCall => return builtinCall(mod, scope, rl, node.castTag(.BuiltinCall).?),
        .Call => return callExpr(mod, scope, rl, node.castTag(.Call).?),
        .Unreachable => return unreach(mod, scope, node.castTag(.Unreachable).?),
        .Return => return ret(mod, scope, node.castTag(.Return).?),
        .If => return ifExpr(mod, scope, rl, node.castTag(.If).?),
        .While => return whileExpr(mod, scope, rl, node.castTag(.While).?),
        .Period => return field(mod, scope, rl, node.castTag(.Period).?),
        .Deref => return rvalue(mod, scope, rl, try deref(mod, scope, node.castTag(.Deref).?)),
        .AddressOf => return rvalue(mod, scope, rl, try addressOf(mod, scope, node.castTag(.AddressOf).?)),
        .FloatLiteral => return rvalue(mod, scope, rl, try floatLiteral(mod, scope, node.castTag(.FloatLiteral).?)),
        .UndefinedLiteral => return rvalue(mod, scope, rl, try undefLiteral(mod, scope, node.castTag(.UndefinedLiteral).?)),
        .BoolLiteral => return rvalue(mod, scope, rl, try boolLiteral(mod, scope, node.castTag(.BoolLiteral).?)),
        .NullLiteral => return rvalue(mod, scope, rl, try nullLiteral(mod, scope, node.castTag(.NullLiteral).?)),
        .OptionalType => return rvalue(mod, scope, rl, try optionalType(mod, scope, node.castTag(.OptionalType).?)),
        .UnwrapOptional => return unwrapOptional(mod, scope, rl, node.castTag(.UnwrapOptional).?),
        .Block => return rvalueVoid(mod, scope, rl, node, try blockExpr(mod, scope, node.castTag(.Block).?)),
        .LabeledBlock => return labeledBlockExpr(mod, scope, rl, node.castTag(.LabeledBlock).?, .block),
        .Break => return rvalue(mod, scope, rl, try breakExpr(mod, scope, node.castTag(.Break).?)),
        .Continue => return rvalue(mod, scope, rl, try continueExpr(mod, scope, node.castTag(.Continue).?)),
        .PtrType => return rvalue(mod, scope, rl, try ptrType(mod, scope, node.castTag(.PtrType).?)),
        .GroupedExpression => return expr(mod, scope, rl, node.castTag(.GroupedExpression).?.expr),
        .ArrayType => return rvalue(mod, scope, rl, try arrayType(mod, scope, node.castTag(.ArrayType).?)),
        .ArrayTypeSentinel => return rvalue(mod, scope, rl, try arrayTypeSentinel(mod, scope, node.castTag(.ArrayTypeSentinel).?)),
        .EnumLiteral => return rvalue(mod, scope, rl, try enumLiteral(mod, scope, node.castTag(.EnumLiteral).?)),
        .MultilineStringLiteral => return rvalue(mod, scope, rl, try multilineStrLiteral(mod, scope, node.castTag(.MultilineStringLiteral).?)),
        .CharLiteral => return rvalue(mod, scope, rl, try charLiteral(mod, scope, node.castTag(.CharLiteral).?)),
        .SliceType => return rvalue(mod, scope, rl, try sliceType(mod, scope, node.castTag(.SliceType).?)),
        .ErrorUnion => return rvalue(mod, scope, rl, try typeInixOp(mod, scope, node.castTag(.ErrorUnion).?, .error_union_type)),
        .MergeErrorSets => return rvalue(mod, scope, rl, try typeInixOp(mod, scope, node.castTag(.MergeErrorSets).?, .merge_error_sets)),
        .AnyFrameType => return rvalue(mod, scope, rl, try anyFrameType(mod, scope, node.castTag(.AnyFrameType).?)),
        .ErrorSetDecl => return rvalue(mod, scope, rl, try errorSetDecl(mod, scope, node.castTag(.ErrorSetDecl).?)),
        .ErrorType => return rvalue(mod, scope, rl, try errorType(mod, scope, node.castTag(.ErrorType).?)),
        .For => return forExpr(mod, scope, rl, node.castTag(.For).?),
        .ArrayAccess => return arrayAccess(mod, scope, rl, node.castTag(.ArrayAccess).?),
        .Slice => return rvalue(mod, scope, rl, try sliceExpr(mod, scope, node.castTag(.Slice).?)),
        .Catch => return catchExpr(mod, scope, rl, node.castTag(.Catch).?),
        .Comptime => return comptimeKeyword(mod, scope, rl, node.castTag(.Comptime).?),
        .OrElse => return orelseExpr(mod, scope, rl, node.castTag(.OrElse).?),
        .Switch => return switchExpr(mod, scope, rl, node.castTag(.Switch).?),
        .ContainerDecl => return containerDecl(mod, scope, rl, node.castTag(.ContainerDecl).?),

        .Defer => return mod.failNode(scope, node, "TODO implement astgen.expr for .Defer", .{}),
        .Await => return mod.failNode(scope, node, "TODO implement astgen.expr for .Await", .{}),
        .Resume => return mod.failNode(scope, node, "TODO implement astgen.expr for .Resume", .{}),
        .Try => return mod.failNode(scope, node, "TODO implement astgen.expr for .Try", .{}),
        .ArrayInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializer", .{}),
        .ArrayInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .ArrayInitializerDot", .{}),
        .StructInitializer => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializer", .{}),
        .StructInitializerDot => return mod.failNode(scope, node, "TODO implement astgen.expr for .StructInitializerDot", .{}),
        .Suspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Suspend", .{}),
        .AnyType => return mod.failNode(scope, node, "TODO implement astgen.expr for .AnyType", .{}),
        .FnProto => return mod.failNode(scope, node, "TODO implement astgen.expr for .FnProto", .{}),
        .Nosuspend => return mod.failNode(scope, node, "TODO implement astgen.expr for .Nosuspend", .{}),
    }
}

fn comptimeKeyword(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.Comptime) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    return comptimeExpr(mod, scope, rl, node.expr);
}

pub fn comptimeExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    node: *ast.Node,
) InnerError!*zir.Inst {
    // If we are already in a comptime scope, no need to make another one.
    if (parent_scope.isComptime()) {
        return expr(mod, parent_scope, rl, node);
    }

    // Optimization for labeled blocks: don't need to have 2 layers of blocks,
    // we can reuse the existing one.
    if (node.castTag(.LabeledBlock)) |block_node| {
        return labeledBlockExpr(mod, parent_scope, rl, block_node, .block_comptime);
    }

    // Make a scope to collect generated instructions in the sub-expression.
    var block_scope: Scope.GenZIR = .{
        .parent = parent_scope,
        .decl = parent_scope.ownerDecl().?,
        .arena = parent_scope.arena(),
        .force_comptime = true,
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    // No need to capture the result here because block_comptime_flat implies that the final
    // instruction is the block's result value.
    _ = try expr(mod, &block_scope.base, rl, node);

    const tree = parent_scope.tree();
    const src = tree.token_locs[node.firstToken()].start;

    const block = try addZIRInstBlock(mod, parent_scope, src, .block_comptime_flat, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    return &block.base;
}

fn breakExpr(
    mod: *Module,
    parent_scope: *Scope,
    node: *ast.Node.ControlFlowExpression,
) InnerError!*zir.Inst {
    const tree = parent_scope.tree();
    const src = tree.token_locs[node.ltoken].start;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZIR).?;

                const block_inst = blk: {
                    if (node.getLabel()) |break_label| {
                        if (gen_zir.label) |*label| {
                            if (try tokenIdentEql(mod, parent_scope, label.token, break_label)) {
                                label.used = true;
                                break :blk label.block_inst;
                            }
                        }
                    } else if (gen_zir.break_block) |inst| {
                        break :blk inst;
                    }
                    scope = gen_zir.parent;
                    continue;
                };

                const rhs = node.getRHS() orelse {
                    return addZirInstTag(mod, parent_scope, src, .break_void, .{
                        .block = block_inst,
                    });
                };
                gen_zir.break_count += 1;
                const prev_rvalue_rl_count = gen_zir.rvalue_rl_count;
                const operand = try expr(mod, parent_scope, gen_zir.break_result_loc, rhs);
                const have_store_to_block = gen_zir.rvalue_rl_count != prev_rvalue_rl_count;
                const br = try addZirInstTag(mod, parent_scope, src, .@"break", .{
                    .block = block_inst,
                    .operand = operand,
                });
                if (gen_zir.break_result_loc == .block_ptr) {
                    try gen_zir.labeled_breaks.append(mod.gpa, br.castTag(.@"break").?);

                    if (have_store_to_block) {
                        const inst_list = parent_scope.getGenZIR().instructions.items;
                        const last_inst = inst_list[inst_list.len - 2];
                        const store_inst = last_inst.castTag(.store_to_block_ptr).?;
                        assert(store_inst.positionals.lhs == gen_zir.rl_ptr.?);
                        try gen_zir.labeled_store_to_block_ptr_list.append(mod.gpa, store_inst);
                    }
                }
                return br;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => if (node.getLabel()) |break_label| {
                const label_name = try mod.identifierTokenString(parent_scope, break_label);
                return mod.failTok(parent_scope, break_label, "label not found: '{s}'", .{label_name});
            } else {
                return mod.failTok(parent_scope, src, "break expression outside loop", .{});
            },
        }
    }
}

fn continueExpr(mod: *Module, parent_scope: *Scope, node: *ast.Node.ControlFlowExpression) InnerError!*zir.Inst {
    const tree = parent_scope.tree();
    const src = tree.token_locs[node.ltoken].start;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZIR).?;
                const continue_block = gen_zir.continue_block orelse {
                    scope = gen_zir.parent;
                    continue;
                };
                if (node.getLabel()) |break_label| blk: {
                    if (gen_zir.label) |*label| {
                        if (try tokenIdentEql(mod, parent_scope, label.token, break_label)) {
                            label.used = true;
                            break :blk;
                        }
                    }
                    // found continue but either it has a different label, or no label
                    scope = gen_zir.parent;
                    continue;
                }

                return addZirInstTag(mod, parent_scope, src, .break_void, .{
                    .block = continue_block,
                });
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => if (node.getLabel()) |break_label| {
                const label_name = try mod.identifierTokenString(parent_scope, break_label);
                return mod.failTok(parent_scope, break_label, "label not found: '{s}'", .{label_name});
            } else {
                return mod.failTok(parent_scope, src, "continue expression outside loop", .{});
            },
        }
    }
}

pub fn blockExpr(mod: *Module, parent_scope: *Scope, block_node: *ast.Node.Block) InnerError!void {
    const tracy = trace(@src());
    defer tracy.end();

    try blockExprStmts(mod, parent_scope, &block_node.base, block_node.statements());
}

fn checkLabelRedefinition(mod: *Module, parent_scope: *Scope, label: ast.TokenIndex) !void {
    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZIR).?;
                if (gen_zir.label) |prev_label| {
                    if (try tokenIdentEql(mod, parent_scope, label, prev_label.token)) {
                        const tree = parent_scope.tree();
                        const label_src = tree.token_locs[label].start;
                        const prev_label_src = tree.token_locs[prev_label.token].start;

                        const label_name = try mod.identifierTokenString(parent_scope, label);
                        const msg = msg: {
                            const msg = try mod.errMsg(
                                parent_scope,
                                label_src,
                                "redefinition of label '{s}'",
                                .{label_name},
                            );
                            errdefer msg.destroy(mod.gpa);
                            try mod.errNote(
                                parent_scope,
                                prev_label_src,
                                msg,
                                "previous definition is here",
                                .{},
                            );
                            break :msg msg;
                        };
                        return mod.failWithOwnedErrorMsg(parent_scope, msg);
                    }
                }
                scope = gen_zir.parent;
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            else => return,
        }
    }
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

    try checkLabelRedefinition(mod, parent_scope, block_node.label);

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
        .decl = parent_scope.ownerDecl().?,
        .arena = gen_zir.arena,
        .force_comptime = parent_scope.isComptime(),
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?Scope.GenZIR.Label, Scope.GenZIR.Label{
            .token = block_node.label,
            .block_inst = block_inst,
        }),
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);
    defer block_scope.labeled_breaks.deinit(mod.gpa);
    defer block_scope.labeled_store_to_block_ptr_list.deinit(mod.gpa);

    try blockExprStmts(mod, &block_scope.base, &block_node.base, block_node.statements());

    if (!block_scope.label.?.used) {
        return mod.fail(parent_scope, tree.token_locs[block_node.label].start, "unused block label", .{});
    }

    try gen_zir.instructions.append(mod.gpa, &block_inst.base);

    const strat = rlStrategy(rl, &block_scope);
    switch (strat.tag) {
        .break_void => {
            // The code took advantage of the result location as a pointer.
            // Turn the break instructions into break_void instructions.
            for (block_scope.labeled_breaks.items) |br| {
                br.base.tag = .break_void;
            }
            // TODO technically not needed since we changed the tag to break_void but
            // would be better still to elide the ones that are in this list.
            try copyBodyNoEliding(&block_inst.positionals.body, block_scope);

            return &block_inst.base;
        },
        .break_operand => {
            // All break operands are values that did not use the result location pointer.
            if (strat.elide_store_to_block_ptr_instructions) {
                for (block_scope.labeled_store_to_block_ptr_list.items) |inst| {
                    inst.base.tag = .void_value;
                }
                // TODO technically not needed since we changed the tag to void_value but
                // would be better still to elide the ones that are in this list.
            }
            try copyBodyNoEliding(&block_inst.positionals.body, block_scope);
            switch (rl) {
                .ref => return &block_inst.base,
                else => return rvalue(mod, parent_scope, rl, &block_inst.base),
            }
        },
    }
}

fn blockExprStmts(
    mod: *Module,
    parent_scope: *Scope,
    node: *ast.Node,
    statements: []*ast.Node,
) !void {
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
            .AssignBitAnd => try assignOp(mod, scope, statement.castTag(.AssignBitAnd).?, .bit_and),
            .AssignBitOr => try assignOp(mod, scope, statement.castTag(.AssignBitOr).?, .bit_or),
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
    if (node.getComptimeToken()) |comptime_token| {
        return mod.failTok(scope, comptime_token, "TODO implement comptime locals", .{});
    }
    if (node.getAlignNode()) |align_node| {
        return mod.failNode(scope, align_node, "TODO implement alignment on locals", .{});
    }
    const tree = scope.tree();
    const name_src = tree.token_locs[node.name_token].start;
    const ident_name = try mod.identifierTokenString(scope, node.name_token);

    // Local variables shadowing detection, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (mem.eql(u8, local_val.name, ident_name)) {
                    const msg = msg: {
                        const msg = try mod.errMsg(scope, name_src, "redefinition of '{s}'", .{
                            ident_name,
                        });
                        errdefer msg.destroy(mod.gpa);
                        try mod.errNote(scope, local_val.inst.src, msg, "previous definition is here", .{});
                        break :msg msg;
                    };
                    return mod.failWithOwnedErrorMsg(scope, msg);
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (mem.eql(u8, local_ptr.name, ident_name)) {
                    const msg = msg: {
                        const msg = try mod.errMsg(scope, name_src, "redefinition of '{s}'", .{
                            ident_name,
                        });
                        errdefer msg.destroy(mod.gpa);
                        try mod.errNote(scope, local_ptr.ptr.src, msg, "previous definition is here", .{});
                        break :msg msg;
                    };
                    return mod.failWithOwnedErrorMsg(scope, msg);
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(Scope.GenZIR).?.parent,
            else => break,
        };
    }

    // Namespace vars shadowing detection
    if (mod.lookupDeclName(scope, ident_name)) |_| {
        // TODO add note for other definition
        return mod.fail(scope, name_src, "redefinition of '{s}'", .{ident_name});
    }
    const init_node = node.getInitNode() orelse
        return mod.fail(scope, name_src, "variables must be initialized", .{});

    switch (tree.token_ids[node.mut_token]) {
        .Keyword_const => {
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            if (!nodeMayNeedMemoryLocation(init_node, scope)) {
                const result_loc: ResultLoc = if (node.getTypeNode()) |type_node|
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

            // Detect whether the initialization expression actually uses the
            // result location pointer.
            var init_scope: Scope.GenZIR = .{
                .parent = scope,
                .decl = scope.ownerDecl().?,
                .arena = scope.arena(),
                .force_comptime = scope.isComptime(),
                .instructions = .{},
            };
            defer init_scope.instructions.deinit(mod.gpa);

            var resolve_inferred_alloc: ?*zir.Inst = null;
            var opt_type_inst: ?*zir.Inst = null;
            if (node.getTypeNode()) |type_node| {
                const type_inst = try typeExpr(mod, &init_scope.base, type_node);
                opt_type_inst = type_inst;
                init_scope.rl_ptr = try addZIRUnOp(mod, &init_scope.base, name_src, .alloc, type_inst);
            } else {
                const alloc = try addZIRNoOpT(mod, &init_scope.base, name_src, .alloc_inferred);
                resolve_inferred_alloc = &alloc.base;
                init_scope.rl_ptr = &alloc.base;
            }
            const init_result_loc: ResultLoc = .{ .block_ptr = &init_scope };
            const init_inst = try expr(mod, &init_scope.base, init_result_loc, init_node);
            const parent_zir = &scope.getGenZIR().instructions;
            if (init_scope.rvalue_rl_count == 1) {
                // Result location pointer not used. We don't need an alloc for this
                // const local, and type inference becomes trivial.
                // Move the init_scope instructions into the parent scope, eliding
                // the alloc instruction and the store_to_block_ptr instruction.
                const expected_len = parent_zir.items.len + init_scope.instructions.items.len - 2;
                try parent_zir.ensureCapacity(mod.gpa, expected_len);
                for (init_scope.instructions.items) |src_inst| {
                    if (src_inst == init_scope.rl_ptr.?) continue;
                    if (src_inst.castTag(.store_to_block_ptr)) |store| {
                        if (store.positionals.lhs == init_scope.rl_ptr.?) continue;
                    }
                    parent_zir.appendAssumeCapacity(src_inst);
                }
                assert(parent_zir.items.len == expected_len);
                const casted_init = if (opt_type_inst) |type_inst|
                    try addZIRBinOp(mod, scope, type_inst.src, .as, type_inst, init_inst)
                else
                    init_inst;

                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = scope.getGenZIR(),
                    .name = ident_name,
                    .inst = casted_init,
                };
                return &sub_scope.base;
            }
            // The initialization expression took advantage of the result location
            // of the const local. In this case we will create an alloc and a LocalPtr for it.
            // Move the init_scope instructions into the parent scope, swapping
            // store_to_block_ptr for store_to_inferred_ptr.
            const expected_len = parent_zir.items.len + init_scope.instructions.items.len;
            try parent_zir.ensureCapacity(mod.gpa, expected_len);
            for (init_scope.instructions.items) |src_inst| {
                if (src_inst.castTag(.store_to_block_ptr)) |store| {
                    if (store.positionals.lhs == init_scope.rl_ptr.?) {
                        src_inst.tag = .store_to_inferred_ptr;
                    }
                }
                parent_zir.appendAssumeCapacity(src_inst);
            }
            assert(parent_zir.items.len == expected_len);
            if (resolve_inferred_alloc) |inst| {
                _ = try addZIRUnOp(mod, scope, name_src, .resolve_inferred_alloc, inst);
            }
            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = scope.getGenZIR(),
                .name = ident_name,
                .ptr = init_scope.rl_ptr.?,
            };
            return &sub_scope.base;
        },
        .Keyword_var => {
            var resolve_inferred_alloc: ?*zir.Inst = null;
            const var_data: struct { result_loc: ResultLoc, alloc: *zir.Inst } = if (node.getTypeNode()) |type_node| a: {
                const type_inst = try typeExpr(mod, scope, type_node);
                const alloc = try addZIRUnOp(mod, scope, name_src, .alloc_mut, type_inst);
                break :a .{ .alloc = alloc, .result_loc = .{ .ptr = alloc } };
            } else a: {
                const alloc = try addZIRNoOpT(mod, scope, name_src, .alloc_inferred_mut);
                resolve_inferred_alloc = &alloc.base;
                break :a .{ .alloc = &alloc.base, .result_loc = .{ .inferred_ptr = alloc } };
            };
            const init_inst = try expr(mod, scope, var_data.result_loc, init_node);
            if (resolve_inferred_alloc) |inst| {
                _ = try addZIRUnOp(mod, scope, name_src, .resolve_inferred_alloc, inst);
            }
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
    return addZIRUnOp(mod, scope, src, .bool_not, operand);
}

fn bitNot(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    const operand = try expr(mod, scope, .none, node.rhs);
    return addZIRUnOp(mod, scope, src, .bit_not, operand);
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

    var kw_args: std.meta.fieldInfo(zir.Inst.PtrType, .kw_args).field_type = .{};
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
    const name = try mod.identifierTokenString(scope, node.name);

    return addZIRInst(mod, scope, src, zir.Inst.EnumLiteral, .{ .name = name }, .{});
}

fn unwrapOptional(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleSuffixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;

    const operand = try expr(mod, scope, rl, node.lhs);
    const op: zir.Inst.Tag = switch (rl) {
        .ref => .optional_payload_safe_ptr,
        else => .optional_payload_safe,
    };
    return addZIRUnOp(mod, scope, src, op, operand);
}

fn containerField(
    mod: *Module,
    scope: *Scope,
    node: *ast.Node.ContainerField,
) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.firstToken()].start;
    const name = try mod.identifierTokenString(scope, node.name_token);

    if (node.comptime_token == null and node.value_expr == null and node.align_expr == null) {
        if (node.type_expr) |some| {
            const ty = try typeExpr(mod, scope, some);
            return addZIRInst(mod, scope, src, zir.Inst.ContainerFieldTyped, .{
                .bytes = name,
                .ty = ty,
            }, .{});
        } else {
            return addZIRInst(mod, scope, src, zir.Inst.ContainerFieldNamed, .{
                .bytes = name,
            }, .{});
        }
    }

    const ty = if (node.type_expr) |some| try typeExpr(mod, scope, some) else null;
    const alignment = if (node.align_expr) |some| try expr(mod, scope, .none, some) else null;
    const init = if (node.value_expr) |some| try expr(mod, scope, .none, some) else null;

    return addZIRInst(mod, scope, src, zir.Inst.ContainerField, .{
        .bytes = name,
    }, .{
        .ty = ty,
        .init = init,
        .alignment = alignment,
        .is_comptime = node.comptime_token != null,
    });
}

fn containerDecl(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.ContainerDecl) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.kind_token].start;

    var gen_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    defer gen_scope.instructions.deinit(mod.gpa);

    var fields = std.ArrayList(*zir.Inst).init(mod.gpa);
    defer fields.deinit();

    for (node.fieldsAndDecls()) |fd| {
        if (fd.castTag(.ContainerField)) |f| {
            try fields.append(try containerField(mod, &gen_scope.base, f));
        }
    }

    var decl_arena = std.heap.ArenaAllocator.init(mod.gpa);
    errdefer decl_arena.deinit();
    const arena = &decl_arena.allocator;

    var layout: std.builtin.TypeInfo.ContainerLayout = .Auto;
    if (node.layout_token) |some| switch (tree.token_ids[some]) {
        .Keyword_extern => layout = .Extern,
        .Keyword_packed => layout = .Packed,
        else => unreachable,
    };

    const container_type = switch (tree.token_ids[node.kind_token]) {
        .Keyword_enum => blk: {
            const tag_type: ?*zir.Inst = switch (node.init_arg_expr) {
                .Type => |t| try typeExpr(mod, &gen_scope.base, t),
                .None => null,
                .Enum => unreachable,
            };
            const inst = try addZIRInst(mod, &gen_scope.base, src, zir.Inst.EnumType, .{
                .fields = try arena.dupe(*zir.Inst, fields.items),
            }, .{
                .layout = layout,
                .tag_type = tag_type,
            });
            const enum_type = try arena.create(Type.Payload.Enum);
            enum_type.* = .{
                .analysis = .{
                    .queued = .{
                        .body = .{ .instructions = try arena.dupe(*zir.Inst, gen_scope.instructions.items) },
                        .inst = inst,
                    },
                },
                .scope = .{
                    .file_scope = scope.getFileScope(),
                    .ty = Type.initPayload(&enum_type.base),
                },
            };
            break :blk Type.initPayload(&enum_type.base);
        },
        .Keyword_struct => blk: {
            assert(node.init_arg_expr == .None);
            const inst = try addZIRInst(mod, &gen_scope.base, src, zir.Inst.StructType, .{
                .fields = try arena.dupe(*zir.Inst, fields.items),
            }, .{
                .layout = layout,
            });
            const struct_type = try arena.create(Type.Payload.Struct);
            struct_type.* = .{
                .analysis = .{
                    .queued = .{
                        .body = .{ .instructions = try arena.dupe(*zir.Inst, gen_scope.instructions.items) },
                        .inst = inst,
                    },
                },
                .scope = .{
                    .file_scope = scope.getFileScope(),
                    .ty = Type.initPayload(&struct_type.base),
                },
            };
            break :blk Type.initPayload(&struct_type.base);
        },
        .Keyword_union => blk: {
            const init_inst = switch (node.init_arg_expr) {
                .Enum => |e| if (e) |t| try typeExpr(mod, &gen_scope.base, t) else null,
                .None => null,
                .Type => |t| try typeExpr(mod, &gen_scope.base, t),
            };
            const init_kind: zir.Inst.UnionType.InitKind = switch (node.init_arg_expr) {
                .Enum => .enum_type,
                .None => .none,
                .Type => .tag_type,
            };
            const inst = try addZIRInst(mod, &gen_scope.base, src, zir.Inst.UnionType, .{
                .fields = try arena.dupe(*zir.Inst, fields.items),
            }, .{
                .layout = layout,
                .init_kind = init_kind,
                .init_inst = init_inst,
            });
            const union_type = try arena.create(Type.Payload.Union);
            union_type.* = .{
                .analysis = .{
                    .queued = .{
                        .body = .{ .instructions = try arena.dupe(*zir.Inst, gen_scope.instructions.items) },
                        .inst = inst,
                    },
                },
                .scope = .{
                    .file_scope = scope.getFileScope(),
                    .ty = Type.initPayload(&union_type.base),
                },
            };
            break :blk Type.initPayload(&union_type.base);
        },
        .Keyword_opaque => blk: {
            if (fields.items.len > 0) {
                return mod.fail(scope, fields.items[0].src, "opaque types cannot have fields", .{});
            }
            const opaque_type = try arena.create(Type.Payload.Opaque);
            opaque_type.* = .{
                .scope = .{
                    .file_scope = scope.getFileScope(),
                    .ty = Type.initPayload(&opaque_type.base),
                },
            };
            break :blk Type.initPayload(&opaque_type.base);
        },
        else => unreachable,
    };
    const val = try Value.Tag.ty.create(arena, container_type);
    const decl = try mod.createContainerDecl(scope, node.kind_token, &decl_arena, .{
        .ty = Type.initTag(.type),
        .val = val,
    });
    if (rl == .ref) {
        return addZIRInst(mod, scope, src, zir.Inst.DeclRef, .{ .decl = decl }, .{});
    } else {
        return rvalue(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.DeclVal, .{
            .decl = decl,
        }, .{}));
    }
}

fn errorSetDecl(mod: *Module, scope: *Scope, node: *ast.Node.ErrorSetDecl) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.error_token].start;
    const decls = node.decls();
    const fields = try scope.arena().alloc([]const u8, decls.len);

    for (decls) |decl, i| {
        const tag = decl.castTag(.ErrorTag).?;
        fields[i] = try mod.identifierTokenString(scope, tag.name_token);
    }

    return addZIRInst(mod, scope, src, zir.Inst.ErrorSet, .{ .fields = fields }, .{});
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
    switch (rl) {
        .ref => return orelseCatchExpr(
            mod,
            scope,
            rl,
            node.lhs,
            node.op_token,
            .is_err_ptr,
            .err_union_payload_unsafe_ptr,
            .err_union_code_ptr,
            node.rhs,
            node.payload,
        ),
        else => return orelseCatchExpr(
            mod,
            scope,
            rl,
            node.lhs,
            node.op_token,
            .is_err,
            .err_union_payload_unsafe,
            .err_union_code,
            node.rhs,
            node.payload,
        ),
    }
}

fn orelseExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    switch (rl) {
        .ref => return orelseCatchExpr(
            mod,
            scope,
            rl,
            node.lhs,
            node.op_token,
            .is_null_ptr,
            .optional_payload_unsafe_ptr,
            undefined,
            node.rhs,
            null,
        ),
        else => return orelseCatchExpr(
            mod,
            scope,
            rl,
            node.lhs,
            node.op_token,
            .is_null,
            .optional_payload_unsafe,
            undefined,
            node.rhs,
            null,
        ),
    }
}

fn orelseCatchExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    lhs: *ast.Node,
    op_token: ast.TokenIndex,
    cond_op: zir.Inst.Tag,
    unwrap_op: zir.Inst.Tag,
    unwrap_code_op: zir.Inst.Tag,
    rhs: *ast.Node,
    payload_node: ?*ast.Node,
) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[op_token].start;

    var block_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);

    // This could be a pointer or value depending on the `rl` parameter.
    block_scope.break_count += 1;
    const operand = try expr(mod, &block_scope.base, block_scope.break_result_loc, lhs);
    const cond = try addZIRUnOp(mod, &block_scope.base, src, cond_op, operand);

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, src, .block, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    var then_scope: Scope.GenZIR = .{
        .parent = &block_scope.base,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    var err_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = blk: {
        const payload = payload_node orelse break :blk &then_scope.base;

        const err_name = tree.tokenSlice(payload.castTag(.Payload).?.error_symbol.firstToken());
        if (mem.eql(u8, err_name, "_"))
            break :blk &then_scope.base;

        err_val_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = err_name,
            .inst = try addZIRUnOp(mod, &then_scope.base, src, unwrap_code_op, operand),
        };
        break :blk &err_val_scope.base;
    };

    block_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, block_scope.break_result_loc, rhs);

    var else_scope: Scope.GenZIR = .{
        .parent = &block_scope.base,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    // This could be a pointer or value depending on `unwrap_op`.
    const unwrapped_payload = try addZIRUnOp(mod, &else_scope.base, src, unwrap_op, operand);

    return finishThenElseBlock(
        mod,
        scope,
        rl,
        &block_scope,
        &then_scope,
        &else_scope,
        &condbr.positionals.then_body,
        &condbr.positionals.else_body,
        src,
        src,
        then_result,
        unwrapped_payload,
        block,
        block,
    );
}

fn finishThenElseBlock(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    block_scope: *Scope.GenZIR,
    then_scope: *Scope.GenZIR,
    else_scope: *Scope.GenZIR,
    then_body: *zir.Body,
    else_body: *zir.Body,
    then_src: usize,
    else_src: usize,
    then_result: *zir.Inst,
    else_result: ?*zir.Inst,
    main_block: *zir.Inst.Block,
    then_break_block: *zir.Inst.Block,
) InnerError!*zir.Inst {
    // We now have enough information to decide whether the result instruction should
    // be communicated via result location pointer or break instructions.
    const strat = rlStrategy(rl, block_scope);
    switch (strat.tag) {
        .break_void => {
            if (!then_result.tag.isNoReturn()) {
                _ = try addZirInstTag(mod, &then_scope.base, then_src, .break_void, .{
                    .block = then_break_block,
                });
            }
            if (else_result) |inst| {
                if (!inst.tag.isNoReturn()) {
                    _ = try addZirInstTag(mod, &else_scope.base, else_src, .break_void, .{
                        .block = main_block,
                    });
                }
            } else {
                _ = try addZirInstTag(mod, &else_scope.base, else_src, .break_void, .{
                    .block = main_block,
                });
            }
            assert(!strat.elide_store_to_block_ptr_instructions);
            try copyBodyNoEliding(then_body, then_scope.*);
            try copyBodyNoEliding(else_body, else_scope.*);
            return &main_block.base;
        },
        .break_operand => {
            if (!then_result.tag.isNoReturn()) {
                _ = try addZirInstTag(mod, &then_scope.base, then_src, .@"break", .{
                    .block = then_break_block,
                    .operand = then_result,
                });
            }
            if (else_result) |inst| {
                if (!inst.tag.isNoReturn()) {
                    _ = try addZirInstTag(mod, &else_scope.base, else_src, .@"break", .{
                        .block = main_block,
                        .operand = inst,
                    });
                }
            } else {
                _ = try addZirInstTag(mod, &else_scope.base, else_src, .break_void, .{
                    .block = main_block,
                });
            }
            if (strat.elide_store_to_block_ptr_instructions) {
                try copyBodyWithElidedStoreBlockPtr(then_body, then_scope.*);
                try copyBodyWithElidedStoreBlockPtr(else_body, else_scope.*);
            } else {
                try copyBodyNoEliding(then_body, then_scope.*);
                try copyBodyNoEliding(else_body, else_scope.*);
            }
            switch (rl) {
                .ref => return &main_block.base,
                else => return rvalue(mod, parent_scope, rl, &main_block.base),
            }
        },
    }
}

/// Return whether the identifier names of two tokens are equal. Resolves @""
/// tokens without allocating.
/// OK in theory it could do it without allocating. This implementation
/// allocates when the @"" form is used.
fn tokenIdentEql(mod: *Module, scope: *Scope, token1: ast.TokenIndex, token2: ast.TokenIndex) !bool {
    const ident_name_1 = try mod.identifierTokenString(scope, token1);
    const ident_name_2 = try mod.identifierTokenString(scope, token2);
    return mem.eql(u8, ident_name_1, ident_name_2);
}

pub fn field(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    // TODO custom AST node for field access so that we don't have to go through a node cast here
    const field_name = try mod.identifierTokenString(scope, node.rhs.castTag(.Identifier).?.token);
    if (rl == .ref) {
        return addZirInstTag(mod, scope, src, .field_ptr, .{
            .object = try expr(mod, scope, .ref, node.lhs),
            .field_name = field_name,
        });
    }
    return rvalue(mod, scope, rl, try addZirInstTag(mod, scope, src, .field_val, .{
        .object = try expr(mod, scope, .none, node.lhs),
        .field_name = field_name,
    }));
}

fn namedField(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    call: *ast.Node.BuiltinCall,
) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 2);

    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();

    const string_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.const_slice_u8_type),
    });
    const string_rl: ResultLoc = .{ .ty = string_type };

    if (rl == .ref) {
        return addZirInstTag(mod, scope, src, .field_ptr_named, .{
            .object = try expr(mod, scope, .ref, params[0]),
            .field_name = try comptimeExpr(mod, scope, string_rl, params[1]),
        });
    }
    return rvalue(mod, scope, rl, try addZirInstTag(mod, scope, src, .field_val_named, .{
        .object = try expr(mod, scope, .none, params[0]),
        .field_name = try comptimeExpr(mod, scope, string_rl, params[1]),
    }));
}

fn arrayAccess(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node.ArrayAccess) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });
    const index_rl: ResultLoc = .{ .ty = usize_type };

    if (rl == .ref) {
        return addZirInstTag(mod, scope, src, .elem_ptr, .{
            .array = try expr(mod, scope, .ref, node.lhs),
            .index = try expr(mod, scope, index_rl, node.index_expr),
        });
    }
    return rvalue(mod, scope, rl, try addZirInstTag(mod, scope, src, .elem_val, .{
        .array = try expr(mod, scope, .none, node.lhs),
        .index = try expr(mod, scope, index_rl, node.index_expr),
    }));
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
    return rvalue(mod, scope, rl, result);
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
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
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
        .force_comptime = block_scope.force_comptime,
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
        .force_comptime = block_scope.force_comptime,
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

    return rvalue(mod, scope, rl, &block.base);
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
                return try addZIRUnOp(mod, &block_scope.base, src, .is_non_null, result);
            },
            .err_union => {
                const err_ptr = try expr(mod, &block_scope.base, .ref, cond_node);
                self.* = .{ .err_union = err_ptr };
                const result = try addZIRUnOp(mod, &block_scope.base, src, .deref, err_ptr);
                return try addZIRUnOp(mod, &block_scope.base, src, .is_err, result);
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

        const payload_ptr = try addZIRUnOp(mod, &else_scope.base, src, .err_union_payload_unsafe_ptr, self.err_union.?);

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
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
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
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // declare payload to the then_scope
    const then_sub_scope = try cond_kind.thenSubScope(mod, &then_scope, then_src, if_node.payload);

    block_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, block_scope.break_result_loc, if_node.body);
    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    var else_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    var else_src: usize = undefined;
    var else_sub_scope: *Module.Scope = undefined;
    const else_result: ?*zir.Inst = if (if_node.@"else") |else_node| blk: {
        else_src = tree.token_locs[else_node.body.lastToken()].start;
        // declare payload to the then_scope
        else_sub_scope = try cond_kind.elseSubScope(mod, &else_scope, else_src, else_node.payload);

        block_scope.break_count += 1;
        break :blk try expr(mod, else_sub_scope, block_scope.break_result_loc, else_node.body);
    } else blk: {
        else_src = tree.token_locs[if_node.lastToken()].start;
        else_sub_scope = &else_scope.base;
        break :blk null;
    };

    return finishThenElseBlock(
        mod,
        scope,
        rl,
        &block_scope,
        &then_scope,
        &else_scope,
        &condbr.positionals.then_body,
        &condbr.positionals.else_body,
        then_src,
        else_src,
        then_result,
        else_result,
        block,
        block,
    );
}

/// Expects to find exactly 1 .store_to_block_ptr instruction.
fn copyBodyWithElidedStoreBlockPtr(body: *zir.Body, scope: Module.Scope.GenZIR) !void {
    body.* = .{
        .instructions = try scope.arena.alloc(*zir.Inst, scope.instructions.items.len - 1),
    };
    var dst_index: usize = 0;
    for (scope.instructions.items) |src_inst| {
        if (src_inst.tag != .store_to_block_ptr) {
            body.instructions[dst_index] = src_inst;
            dst_index += 1;
        }
    }
    assert(dst_index == body.instructions.len);
}

fn copyBodyNoEliding(body: *zir.Body, scope: Module.Scope.GenZIR) !void {
    body.* = .{
        .instructions = try scope.arena.dupe(*zir.Inst, scope.instructions.items),
    };
}

fn whileExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    while_node: *ast.Node.While,
) InnerError!*zir.Inst {
    var cond_kind: CondKind = .bool;
    if (while_node.payload) |_| cond_kind = .{ .optional = null };
    if (while_node.@"else") |else_node| {
        if (else_node.payload) |payload| {
            cond_kind = .{ .err_union = null };
        }
    }

    if (while_node.label) |label| {
        try checkLabelRedefinition(mod, scope, label);
    }

    if (while_node.inline_token) |tok|
        return mod.failTok(scope, tok, "TODO inline while", .{});

    var loop_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&loop_scope, rl);
    defer loop_scope.instructions.deinit(mod.gpa);

    var continue_scope: Scope.GenZIR = .{
        .parent = &loop_scope.base,
        .decl = loop_scope.decl,
        .arena = loop_scope.arena,
        .force_comptime = loop_scope.force_comptime,
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
    const loop = try scope.arena().create(zir.Inst.Loop);
    loop.* = .{
        .base = .{
            .tag = .loop,
            .src = while_src,
        },
        .positionals = .{
            .body = .{
                .instructions = try scope.arena().dupe(*zir.Inst, loop_scope.instructions.items),
            },
        },
        .kw_args = .{},
    };
    const while_block = try addZIRInstBlock(mod, scope, while_src, .block, .{
        .instructions = try scope.arena().dupe(*zir.Inst, &[1]*zir.Inst{&loop.base}),
    });
    loop_scope.break_block = while_block;
    loop_scope.continue_block = cond_block;
    if (while_node.label) |some| {
        loop_scope.label = @as(?Scope.GenZIR.Label, Scope.GenZIR.Label{
            .token = some,
            .block_inst = while_block,
        });
    }

    const then_src = tree.token_locs[while_node.body.lastToken()].start;
    var then_scope: Scope.GenZIR = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // declare payload to the then_scope
    const then_sub_scope = try cond_kind.thenSubScope(mod, &then_scope, then_src, while_node.payload);

    loop_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, loop_scope.break_result_loc, while_node.body);

    var else_scope: Scope.GenZIR = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    var else_src: usize = undefined;
    const else_result: ?*zir.Inst = if (while_node.@"else") |else_node| blk: {
        else_src = tree.token_locs[else_node.body.lastToken()].start;
        // declare payload to the then_scope
        const else_sub_scope = try cond_kind.elseSubScope(mod, &else_scope, else_src, else_node.payload);

        loop_scope.break_count += 1;
        break :blk try expr(mod, else_sub_scope, loop_scope.break_result_loc, else_node.body);
    } else blk: {
        else_src = tree.token_locs[while_node.lastToken()].start;
        break :blk null;
    };
    if (loop_scope.label) |some| {
        if (!some.used) {
            return mod.fail(scope, tree.token_locs[some.token].start, "unused while label", .{});
        }
    }
    return finishThenElseBlock(
        mod,
        scope,
        rl,
        &loop_scope,
        &then_scope,
        &else_scope,
        &condbr.positionals.then_body,
        &condbr.positionals.else_body,
        then_src,
        else_src,
        then_result,
        else_result,
        while_block,
        cond_block,
    );
}

fn forExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    for_node: *ast.Node.For,
) InnerError!*zir.Inst {
    if (for_node.label) |label| {
        try checkLabelRedefinition(mod, scope, label);
    }

    if (for_node.inline_token) |tok|
        return mod.failTok(scope, tok, "TODO inline for", .{});

    // setup variables and constants
    const tree = scope.tree();
    const for_src = tree.token_locs[for_node.for_token].start;
    const index_ptr = blk: {
        const usize_type = try addZIRInstConst(mod, scope, for_src, .{
            .ty = Type.initTag(.type),
            .val = Value.initTag(.usize_type),
        });
        const index_ptr = try addZIRUnOp(mod, scope, for_src, .alloc, usize_type);
        // initialize to zero
        const zero = try addZIRInstConst(mod, scope, for_src, .{
            .ty = Type.initTag(.usize),
            .val = Value.initTag(.zero),
        });
        _ = try addZIRBinOp(mod, scope, for_src, .store, index_ptr, zero);
        break :blk index_ptr;
    };
    const array_ptr = try expr(mod, scope, .ref, for_node.array_expr);
    const cond_src = tree.token_locs[for_node.array_expr.firstToken()].start;
    const len = try addZIRUnOp(mod, scope, cond_src, .indexable_ptr_len, array_ptr);

    var loop_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&loop_scope, rl);
    defer loop_scope.instructions.deinit(mod.gpa);

    var cond_scope: Scope.GenZIR = .{
        .parent = &loop_scope.base,
        .decl = loop_scope.decl,
        .arena = loop_scope.arena,
        .force_comptime = loop_scope.force_comptime,
        .instructions = .{},
    };
    defer cond_scope.instructions.deinit(mod.gpa);

    // check condition i < array_expr.len
    const index = try addZIRUnOp(mod, &cond_scope.base, cond_src, .deref, index_ptr);
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

    const loop = try scope.arena().create(zir.Inst.Loop);
    loop.* = .{
        .base = .{
            .tag = .loop,
            .src = for_src,
        },
        .positionals = .{
            .body = .{
                .instructions = try scope.arena().dupe(*zir.Inst, loop_scope.instructions.items),
            },
        },
        .kw_args = .{},
    };
    const for_block = try addZIRInstBlock(mod, scope, for_src, .block, .{
        .instructions = try scope.arena().dupe(*zir.Inst, &[1]*zir.Inst{&loop.base}),
    });
    loop_scope.break_block = for_block;
    loop_scope.continue_block = cond_block;
    if (for_node.label) |some| {
        loop_scope.label = @as(?Scope.GenZIR.Label, Scope.GenZIR.Label{
            .token = some,
            .block_inst = for_block,
        });
    }

    // while body
    const then_src = tree.token_locs[for_node.body.lastToken()].start;
    var then_scope: Scope.GenZIR = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

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

    loop_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, loop_scope.break_result_loc, for_node.body);

    // else branch
    var else_scope: Scope.GenZIR = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    var else_src: usize = undefined;
    const else_result: ?*zir.Inst = if (for_node.@"else") |else_node| blk: {
        else_src = tree.token_locs[else_node.body.lastToken()].start;
        loop_scope.break_count += 1;
        break :blk try expr(mod, &else_scope.base, loop_scope.break_result_loc, else_node.body);
    } else blk: {
        else_src = tree.token_locs[for_node.lastToken()].start;
        break :blk null;
    };
    if (loop_scope.label) |some| {
        if (!some.used) {
            return mod.fail(scope, tree.token_locs[some.token].start, "unused for label", .{});
        }
    }
    return finishThenElseBlock(
        mod,
        scope,
        rl,
        &loop_scope,
        &then_scope,
        &else_scope,
        &condbr.positionals.then_body,
        &condbr.positionals.else_body,
        then_src,
        else_src,
        then_result,
        else_result,
        for_block,
        cond_block,
    );
}

fn switchCaseUsesRef(node: *ast.Node.Switch) bool {
    for (node.cases()) |uncasted_case| {
        const case = uncasted_case.castTag(.SwitchCase).?;
        const uncasted_payload = case.payload orelse continue;
        const payload = uncasted_payload.castTag(.PointerPayload).?;
        if (payload.ptr_token) |_| return true;
    }
    return false;
}

fn getRangeNode(node: *ast.Node) ?*ast.Node.SimpleInfixOp {
    var cur = node;
    while (true) {
        switch (cur.tag) {
            .Range => return @fieldParentPtr(ast.Node.SimpleInfixOp, "base", cur),
            .GroupedExpression => cur = @fieldParentPtr(ast.Node.GroupedExpression, "base", cur).expr,
            else => return null,
        }
    }
}

fn switchExpr(mod: *Module, scope: *Scope, rl: ResultLoc, switch_node: *ast.Node.Switch) InnerError!*zir.Inst {
    const tree = scope.tree();
    const switch_src = tree.token_locs[switch_node.switch_token].start;
    const use_ref = switchCaseUsesRef(switch_node);

    var block_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);

    var items = std.ArrayList(*zir.Inst).init(mod.gpa);
    defer items.deinit();

    // first we gather all the switch items and check else/'_' prongs
    var else_src: ?usize = null;
    var underscore_src: ?usize = null;
    var first_range: ?*zir.Inst = null;
    var simple_case_count: usize = 0;
    for (switch_node.cases()) |uncasted_case| {
        const case = uncasted_case.castTag(.SwitchCase).?;
        const case_src = tree.token_locs[case.firstToken()].start;
        assert(case.items_len != 0);

        // Check for else/_ prong, those are handled last.
        if (case.items_len == 1 and case.items()[0].tag == .SwitchElse) {
            if (else_src) |src| {
                const msg = msg: {
                    const msg = try mod.errMsg(
                        scope,
                        case_src,
                        "multiple else prongs in switch expression",
                        .{},
                    );
                    errdefer msg.destroy(mod.gpa);
                    try mod.errNote(scope, src, msg, "previous else prong is here", .{});
                    break :msg msg;
                };
                return mod.failWithOwnedErrorMsg(scope, msg);
            }
            else_src = case_src;
            continue;
        } else if (case.items_len == 1 and case.items()[0].tag == .Identifier and
            mem.eql(u8, tree.tokenSlice(case.items()[0].firstToken()), "_"))
        {
            if (underscore_src) |src| {
                const msg = msg: {
                    const msg = try mod.errMsg(
                        scope,
                        case_src,
                        "multiple '_' prongs in switch expression",
                        .{},
                    );
                    errdefer msg.destroy(mod.gpa);
                    try mod.errNote(scope, src, msg, "previous '_' prong is here", .{});
                    break :msg msg;
                };
                return mod.failWithOwnedErrorMsg(scope, msg);
            }
            underscore_src = case_src;
            continue;
        }

        if (else_src) |some_else| {
            if (underscore_src) |some_underscore| {
                const msg = msg: {
                    const msg = try mod.errMsg(
                        scope,
                        switch_src,
                        "else and '_' prong in switch expression",
                        .{},
                    );
                    errdefer msg.destroy(mod.gpa);
                    try mod.errNote(scope, some_else, msg, "else prong is here", .{});
                    try mod.errNote(scope, some_underscore, msg, "'_' prong is here", .{});
                    break :msg msg;
                };
                return mod.failWithOwnedErrorMsg(scope, msg);
            }
        }

        if (case.items_len == 1 and getRangeNode(case.items()[0]) == null) simple_case_count += 1;

        // generate all the switch items as comptime expressions
        for (case.items()) |item| {
            if (getRangeNode(item)) |range| {
                const start = try comptimeExpr(mod, &block_scope.base, .none, range.lhs);
                const end = try comptimeExpr(mod, &block_scope.base, .none, range.rhs);
                const range_src = tree.token_locs[range.op_token].start;
                const range_inst = try addZIRBinOp(mod, &block_scope.base, range_src, .switch_range, start, end);
                try items.append(range_inst);
            } else {
                const item_inst = try comptimeExpr(mod, &block_scope.base, .none, item);
                try items.append(item_inst);
            }
        }
    }

    var special_prong: zir.Inst.SwitchBr.SpecialProng = .none;
    if (else_src != null) special_prong = .@"else";
    if (underscore_src != null) special_prong = .underscore;
    var cases = try block_scope.arena.alloc(zir.Inst.SwitchBr.Case, simple_case_count);

    const target_ptr = if (use_ref) try expr(mod, &block_scope.base, .ref, switch_node.expr) else null;
    const target = if (target_ptr) |some|
        try addZIRUnOp(mod, &block_scope.base, some.src, .deref, some)
    else
        try expr(mod, &block_scope.base, .none, switch_node.expr);
    const switch_inst = try addZIRInst(mod, &block_scope.base, switch_src, zir.Inst.SwitchBr, .{
        .target = target,
        .cases = cases,
        .items = try block_scope.arena.dupe(*zir.Inst, items.items),
        .else_body = undefined, // populated below
    }, .{
        .range = first_range,
        .special_prong = special_prong,
    });

    const block = try addZIRInstBlock(mod, scope, switch_src, .block, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });

    var case_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer case_scope.instructions.deinit(mod.gpa);

    var else_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = case_scope.decl,
        .arena = case_scope.arena,
        .force_comptime = case_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    // Now generate all but the special cases
    var special_case: ?*ast.Node.SwitchCase = null;
    var items_index: usize = 0;
    var case_index: usize = 0;
    for (switch_node.cases()) |uncasted_case| {
        const case = uncasted_case.castTag(.SwitchCase).?;
        const case_src = tree.token_locs[case.firstToken()].start;
        // reset without freeing to reduce allocations.
        case_scope.instructions.items.len = 0;

        // Check for else/_ prong, those are handled last.
        if (case.items_len == 1 and case.items()[0].tag == .SwitchElse) {
            special_case = case;
            continue;
        } else if (case.items_len == 1 and case.items()[0].tag == .Identifier and
            mem.eql(u8, tree.tokenSlice(case.items()[0].firstToken()), "_"))
        {
            special_case = case;
            continue;
        }

        // If this is a simple one item prong then it is handled by the switchbr.
        if (case.items_len == 1 and getRangeNode(case.items()[0]) == null) {
            const item = items.items[items_index];
            items_index += 1;
            try switchCaseExpr(mod, &case_scope.base, block_scope.break_result_loc, block, case, target, target_ptr);

            cases[case_index] = .{
                .item = item,
                .body = .{ .instructions = try scope.arena().dupe(*zir.Inst, case_scope.instructions.items) },
            };
            case_index += 1;
            continue;
        }

        // TODO if the case has few items and no ranges it might be better
        // to just handle them as switch prongs.

        // Check if the target matches any of the items.
        // 1, 2, 3..6 will result in
        // target == 1 or target == 2 or (target >= 3 and target <= 6)
        var any_ok: ?*zir.Inst = null;
        for (case.items()) |item| {
            if (getRangeNode(item)) |range| {
                const range_src = tree.token_locs[range.op_token].start;
                const range_inst = items.items[items_index].castTag(.switch_range).?;
                items_index += 1;

                // target >= start and target <= end
                const range_start_ok = try addZIRBinOp(mod, &else_scope.base, range_src, .cmp_gte, target, range_inst.positionals.lhs);
                const range_end_ok = try addZIRBinOp(mod, &else_scope.base, range_src, .cmp_lte, target, range_inst.positionals.rhs);
                const range_ok = try addZIRBinOp(mod, &else_scope.base, range_src, .bool_and, range_start_ok, range_end_ok);

                if (any_ok) |some| {
                    any_ok = try addZIRBinOp(mod, &else_scope.base, range_src, .bool_or, some, range_ok);
                } else {
                    any_ok = range_ok;
                }
                continue;
            }

            const item_inst = items.items[items_index];
            items_index += 1;
            const cpm_ok = try addZIRBinOp(mod, &else_scope.base, item_inst.src, .cmp_eq, target, item_inst);

            if (any_ok) |some| {
                any_ok = try addZIRBinOp(mod, &else_scope.base, item_inst.src, .bool_or, some, cpm_ok);
            } else {
                any_ok = cpm_ok;
            }
        }

        const condbr = try addZIRInstSpecial(mod, &case_scope.base, case_src, zir.Inst.CondBr, .{
            .condition = any_ok.?,
            .then_body = undefined, // populated below
            .else_body = undefined, // populated below
        }, .{});
        const cond_block = try addZIRInstBlock(mod, &else_scope.base, case_src, .block, .{
            .instructions = try scope.arena().dupe(*zir.Inst, case_scope.instructions.items),
        });

        // reset cond_scope for then_body
        case_scope.instructions.items.len = 0;
        try switchCaseExpr(mod, &case_scope.base, block_scope.break_result_loc, block, case, target, target_ptr);
        condbr.positionals.then_body = .{
            .instructions = try scope.arena().dupe(*zir.Inst, case_scope.instructions.items),
        };

        // reset cond_scope for else_body
        case_scope.instructions.items.len = 0;
        _ = try addZIRInst(mod, &case_scope.base, case_src, zir.Inst.BreakVoid, .{
            .block = cond_block,
        }, .{});
        condbr.positionals.else_body = .{
            .instructions = try scope.arena().dupe(*zir.Inst, case_scope.instructions.items),
        };
    }

    // Finally generate else block or a break.
    if (special_case) |case| {
        try switchCaseExpr(mod, &else_scope.base, block_scope.break_result_loc, block, case, target, target_ptr);
    } else {
        // Not handling all possible cases is a compile error.
        _ = try addZIRNoOp(mod, &else_scope.base, switch_src, .unreachable_unsafe);
    }
    switch_inst.castTag(.switchbr).?.positionals.else_body = .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, else_scope.instructions.items),
    };

    return &block.base;
}

fn switchCaseExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    block: *zir.Inst.Block,
    case: *ast.Node.SwitchCase,
    target: *zir.Inst,
    target_ptr: ?*zir.Inst,
) !void {
    const tree = scope.tree();
    const case_src = tree.token_locs[case.firstToken()].start;
    const sub_scope = blk: {
        const uncasted_payload = case.payload orelse break :blk scope;
        const payload = uncasted_payload.castTag(.PointerPayload).?;
        const is_ptr = payload.ptr_token != null;
        const value_name = tree.tokenSlice(payload.value_symbol.firstToken());
        if (mem.eql(u8, value_name, "_")) {
            if (is_ptr) {
                return mod.failTok(scope, payload.ptr_token.?, "pointer modifier invalid on discard", .{});
            }
            break :blk scope;
        }
        return mod.failNode(scope, payload.value_symbol, "TODO implement switch value payload", .{});
    };

    const case_body = try expr(mod, sub_scope, rl, case.expr);
    if (!case_body.tag.isNoReturn()) {
        _ = try addZIRInst(mod, sub_scope, case_src, zir.Inst.Break, .{
            .block = block,
            .operand = case_body,
        }, .{});
    }
}

fn ret(mod: *Module, scope: *Scope, cfe: *ast.Node.ControlFlowExpression) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[cfe.ltoken].start;
    if (cfe.getRHS()) |rhs_node| {
        if (nodeMayNeedMemoryLocation(rhs_node, scope)) {
            const ret_ptr = try addZIRNoOp(mod, scope, src, .ret_ptr);
            const operand = try expr(mod, scope, .{ .ptr = ret_ptr }, rhs_node);
            return addZIRUnOp(mod, scope, src, .@"return", operand);
        } else {
            const fn_ret_ty = try addZIRNoOp(mod, scope, src, .ret_type);
            const operand = try expr(mod, scope, .{ .ty = fn_ret_ty }, rhs_node);
            return addZIRUnOp(mod, scope, src, .@"return", operand);
        }
    } else {
        return addZIRNoOp(mod, scope, src, .return_void);
    }
}

fn identifier(mod: *Module, scope: *Scope, rl: ResultLoc, ident: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const tree = scope.tree();
    const ident_name = try mod.identifierTokenString(scope, ident.token);
    const src = tree.token_locs[ident.token].start;
    if (mem.eql(u8, ident_name, "_")) {
        return mod.failNode(scope, &ident.base, "TODO implement '_' identifier", .{});
    }

    if (getSimplePrimitiveValue(ident_name)) |typed_value| {
        const result = try addZIRInstConst(mod, scope, src, typed_value);
        return rvalue(mod, scope, rl, result);
    }

    if (ident_name.len >= 2) integer: {
        const first_c = ident_name[0];
        if (first_c == 'i' or first_c == 'u') {
            const is_signed = first_c == 'i';
            const bit_count = std.fmt.parseInt(u16, ident_name[1..], 10) catch |err| switch (err) {
                error.Overflow => return mod.failNode(
                    scope,
                    &ident.base,
                    "primitive integer type '{s}' exceeds maximum bit width of 65535",
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
                    return rvalue(mod, scope, rl, try addZIRInstConst(mod, scope, src, .{
                        .ty = Type.initTag(.type),
                        .val = try Value.Tag.int_type.create(scope.arena(), .{
                            .signed = is_signed,
                            .bits = bit_count,
                        }),
                    }));
                },
            };
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.type),
                .val = val,
            });
            return rvalue(mod, scope, rl, result);
        }
    }

    // Local variables, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_val => {
                const local_val = s.cast(Scope.LocalVal).?;
                if (mem.eql(u8, local_val.name, ident_name)) {
                    return rvalue(mod, scope, rl, local_val.inst);
                }
                s = local_val.parent;
            },
            .local_ptr => {
                const local_ptr = s.cast(Scope.LocalPtr).?;
                if (mem.eql(u8, local_ptr.name, ident_name)) {
                    if (rl == .ref) return local_ptr.ptr;
                    const loaded = try addZIRUnOp(mod, scope, src, .deref, local_ptr.ptr);
                    return rvalue(mod, scope, rl, loaded);
                }
                s = local_ptr.parent;
            },
            .gen_zir => s = s.cast(Scope.GenZIR).?.parent,
            else => break,
        };
    }

    if (mod.lookupDeclName(scope, ident_name)) |decl| {
        if (rl == .ref) {
            return addZIRInst(mod, scope, src, zir.Inst.DeclRef, .{ .decl = decl }, .{});
        } else {
            return rvalue(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.DeclVal, .{
                .decl = decl,
            }, .{}));
        }
    }

    return mod.failNode(scope, &ident.base, "use of undeclared identifier '{s}'", .{ident_name});
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

    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_int),
        .val = try Value.Tag.int_u64.create(scope.arena(), value),
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
        const src = tree.token_locs[int_lit.token].start;
        return addZIRInstConst(mod, scope, src, .{
            .ty = Type.initTag(.comptime_int),
            .val = try Value.Tag.int_u64.create(arena, small_int),
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

    const float_number = std.fmt.parseFloat(f128, bytes) catch |e| switch (e) {
        error.InvalidCharacter => unreachable, // validated by tokenizer
    };
    const src = tree.token_locs[float_lit.token].start;
    return addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = try Value.Tag.float_128.create(arena, float_number),
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
    return mod.failTok(scope, call.builtin_token, "expected {d} parameter{s}, found {d}", .{ count, s, call.params_len });
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
    return rvalue(mod, scope, rl, result);
}

fn ptrToInt(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 1);
    const operand = try expr(mod, scope, .none, call.params()[0]);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    return addZIRUnOp(mod, scope, src, .ptrtoint, operand);
}

fn as(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    call: *ast.Node.BuiltinCall,
) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 2);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    const dest_type = try typeExpr(mod, scope, params[0]);
    switch (rl) {
        .none, .discard, .ref, .ty => {
            const result = try expr(mod, scope, .{ .ty = dest_type }, params[1]);
            return rvalue(mod, scope, rl, result);
        },

        .ptr => |result_ptr| {
            return asRlPtr(mod, scope, rl, src, result_ptr, params[1], dest_type);
        },
        .block_ptr => |block_scope| {
            return asRlPtr(mod, scope, rl, src, block_scope.rl_ptr.?, params[1], dest_type);
        },

        .bitcasted_ptr => |bitcasted_ptr| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, call.builtin_token, "TODO implement @as with result location @bitCast", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, call.builtin_token, "TODO implement @as with inferred-type result location pointer", .{});
        },
    }
}

fn asRlPtr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    src: usize,
    result_ptr: *zir.Inst,
    operand_node: *ast.Node,
    dest_type: *zir.Inst,
) InnerError!*zir.Inst {
    // Detect whether this expr() call goes into rvalue() to store the result into the
    // result location. If it does, elide the coerce_result_ptr instruction
    // as well as the store instruction, instead passing the result as an rvalue.
    var as_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    defer as_scope.instructions.deinit(mod.gpa);

    as_scope.rl_ptr = try addZIRBinOp(mod, &as_scope.base, src, .coerce_result_ptr, dest_type, result_ptr);
    const result = try expr(mod, &as_scope.base, .{ .block_ptr = &as_scope }, operand_node);
    const parent_zir = &scope.getGenZIR().instructions;
    if (as_scope.rvalue_rl_count == 1) {
        // Busted! This expression didn't actually need a pointer.
        const expected_len = parent_zir.items.len + as_scope.instructions.items.len - 2;
        try parent_zir.ensureCapacity(mod.gpa, expected_len);
        for (as_scope.instructions.items) |src_inst| {
            if (src_inst == as_scope.rl_ptr.?) continue;
            if (src_inst.castTag(.store_to_block_ptr)) |store| {
                if (store.positionals.lhs == as_scope.rl_ptr.?) continue;
            }
            parent_zir.appendAssumeCapacity(src_inst);
        }
        assert(parent_zir.items.len == expected_len);
        const casted_result = try addZIRBinOp(mod, scope, dest_type.src, .as, dest_type, result);
        return rvalue(mod, scope, rl, casted_result);
    } else {
        try parent_zir.appendSlice(mod.gpa, as_scope.instructions.items);
        return result;
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

fn import(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 1);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    const target = try expr(mod, scope, .none, params[0]);
    return addZIRUnOp(mod, scope, src, .import, target);
}

fn compileError(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 1);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    const target = try expr(mod, scope, .none, params[0]);
    return addZIRUnOp(mod, scope, src, .compile_error, target);
}

fn setEvalBranchQuota(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    try ensureBuiltinParamCount(mod, scope, call, 1);
    const tree = scope.tree();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    const u32_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u32_type),
    });
    const quota = try expr(mod, scope, .{ .ty = u32_type }, params[0]);
    return addZIRUnOp(mod, scope, src, .set_eval_branch_quota, quota);
}

fn typeOf(mod: *Module, scope: *Scope, rl: ResultLoc, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    const tree = scope.tree();
    const arena = scope.arena();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    if (params.len < 1) {
        return mod.failTok(scope, call.builtin_token, "expected at least 1 argument, found 0", .{});
    }
    if (params.len == 1) {
        return rvalue(mod, scope, rl, try addZIRUnOp(mod, scope, src, .typeof, try expr(mod, scope, .none, params[0])));
    }
    var items = try arena.alloc(*zir.Inst, params.len);
    for (params) |param, param_i|
        items[param_i] = try expr(mod, scope, .none, param);
    return rvalue(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.TypeOfPeer, .{ .items = items }, .{}));
}
fn compileLog(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    const tree = scope.tree();
    const arena = scope.arena();
    const src = tree.token_locs[call.builtin_token].start;
    const params = call.params();
    var targets = try arena.alloc(*zir.Inst, params.len);
    for (params) |param, param_i|
        targets[param_i] = try expr(mod, scope, .none, param);
    return addZIRInst(mod, scope, src, zir.Inst.CompileLog, .{ .to_log = targets }, .{});
}

fn builtinCall(mod: *Module, scope: *Scope, rl: ResultLoc, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    const tree = scope.tree();
    const builtin_name = tree.tokenSlice(call.builtin_token);

    // We handle the different builtins manually because they have different semantics depending
    // on the function. For example, `@as` and others participate in result location semantics,
    // and `@cImport` creates a special scope that collects a .c source code text buffer.
    // Also, some builtins have a variable number of parameters.

    if (mem.eql(u8, builtin_name, "@ptrToInt")) {
        return rvalue(mod, scope, rl, try ptrToInt(mod, scope, call));
    } else if (mem.eql(u8, builtin_name, "@as")) {
        return as(mod, scope, rl, call);
    } else if (mem.eql(u8, builtin_name, "@floatCast")) {
        return simpleCast(mod, scope, rl, call, .floatcast);
    } else if (mem.eql(u8, builtin_name, "@intCast")) {
        return simpleCast(mod, scope, rl, call, .intcast);
    } else if (mem.eql(u8, builtin_name, "@bitCast")) {
        return bitCast(mod, scope, rl, call);
    } else if (mem.eql(u8, builtin_name, "@TypeOf")) {
        return typeOf(mod, scope, rl, call);
    } else if (mem.eql(u8, builtin_name, "@breakpoint")) {
        const src = tree.token_locs[call.builtin_token].start;
        return rvalue(mod, scope, rl, try addZIRNoOp(mod, scope, src, .breakpoint));
    } else if (mem.eql(u8, builtin_name, "@import")) {
        return rvalue(mod, scope, rl, try import(mod, scope, call));
    } else if (mem.eql(u8, builtin_name, "@compileError")) {
        return compileError(mod, scope, call);
    } else if (mem.eql(u8, builtin_name, "@setEvalBranchQuota")) {
        return setEvalBranchQuota(mod, scope, call);
    } else if (mem.eql(u8, builtin_name, "@compileLog")) {
        return compileLog(mod, scope, call);
    } else if (mem.eql(u8, builtin_name, "@field")) {
        return namedField(mod, scope, rl, call);
    } else {
        return mod.failTok(scope, call.builtin_token, "invalid builtin function: '{s}'", .{builtin_name});
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
    return rvalue(mod, scope, rl, result);
}

fn unreach(mod: *Module, scope: *Scope, unreach_node: *ast.Node.OneToken) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[unreach_node.token].start;
    return addZIRNoOp(mod, scope, src, .unreachable_safe);
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

fn nodeMayNeedMemoryLocation(start_node: *ast.Node, scope: *Scope) bool {
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
            .LabeledBlock,
            => return true,

            .BuiltinCall => {
                @setEvalBranchQuota(5000);
                const builtin_needs_mem_loc = std.ComptimeStringMap(bool, .{
                    .{ "@addWithOverflow", false },
                    .{ "@alignCast", false },
                    .{ "@alignOf", false },
                    .{ "@as", true },
                    .{ "@asyncCall", false },
                    .{ "@atomicLoad", false },
                    .{ "@atomicRmw", false },
                    .{ "@atomicStore", false },
                    .{ "@bitCast", true },
                    .{ "@bitOffsetOf", false },
                    .{ "@boolToInt", false },
                    .{ "@bitSizeOf", false },
                    .{ "@breakpoint", false },
                    .{ "@mulAdd", false },
                    .{ "@byteSwap", false },
                    .{ "@bitReverse", false },
                    .{ "@byteOffsetOf", false },
                    .{ "@call", true },
                    .{ "@cDefine", false },
                    .{ "@cImport", false },
                    .{ "@cInclude", false },
                    .{ "@clz", false },
                    .{ "@cmpxchgStrong", false },
                    .{ "@cmpxchgWeak", false },
                    .{ "@compileError", false },
                    .{ "@compileLog", false },
                    .{ "@ctz", false },
                    .{ "@cUndef", false },
                    .{ "@divExact", false },
                    .{ "@divFloor", false },
                    .{ "@divTrunc", false },
                    .{ "@embedFile", false },
                    .{ "@enumToInt", false },
                    .{ "@errorName", false },
                    .{ "@errorReturnTrace", false },
                    .{ "@errorToInt", false },
                    .{ "@errSetCast", false },
                    .{ "@export", false },
                    .{ "@fence", false },
                    .{ "@field", true },
                    .{ "@fieldParentPtr", false },
                    .{ "@floatCast", false },
                    .{ "@floatToInt", false },
                    .{ "@frame", false },
                    .{ "@Frame", false },
                    .{ "@frameAddress", false },
                    .{ "@frameSize", false },
                    .{ "@hasDecl", false },
                    .{ "@hasField", false },
                    .{ "@import", false },
                    .{ "@intCast", false },
                    .{ "@intToEnum", false },
                    .{ "@intToError", false },
                    .{ "@intToFloat", false },
                    .{ "@intToPtr", false },
                    .{ "@memcpy", false },
                    .{ "@memset", false },
                    .{ "@wasmMemorySize", false },
                    .{ "@wasmMemoryGrow", false },
                    .{ "@mod", false },
                    .{ "@mulWithOverflow", false },
                    .{ "@panic", false },
                    .{ "@popCount", false },
                    .{ "@ptrCast", false },
                    .{ "@ptrToInt", false },
                    .{ "@rem", false },
                    .{ "@returnAddress", false },
                    .{ "@setAlignStack", false },
                    .{ "@setCold", false },
                    .{ "@setEvalBranchQuota", false },
                    .{ "@setFloatMode", false },
                    .{ "@setRuntimeSafety", false },
                    .{ "@shlExact", false },
                    .{ "@shlWithOverflow", false },
                    .{ "@shrExact", false },
                    .{ "@shuffle", false },
                    .{ "@sizeOf", false },
                    .{ "@splat", true },
                    .{ "@reduce", false },
                    .{ "@src", true },
                    .{ "@sqrt", false },
                    .{ "@sin", false },
                    .{ "@cos", false },
                    .{ "@exp", false },
                    .{ "@exp2", false },
                    .{ "@log", false },
                    .{ "@log2", false },
                    .{ "@log10", false },
                    .{ "@fabs", false },
                    .{ "@floor", false },
                    .{ "@ceil", false },
                    .{ "@trunc", false },
                    .{ "@round", false },
                    .{ "@subWithOverflow", false },
                    .{ "@tagName", false },
                    .{ "@This", false },
                    .{ "@truncate", false },
                    .{ "@Type", false },
                    .{ "@typeInfo", false },
                    .{ "@typeName", false },
                    .{ "@TypeOf", false },
                    .{ "@unionInit", true },
                });
                const name = scope.tree().tokenSlice(node.castTag(.BuiltinCall).?.builtin_token);
                return builtin_needs_mem_loc.get(name).?;
            },

            // Depending on AST properties, they may need memory locations.
            .If => return node.castTag(.If).?.@"else" != null,
        }
    }
}

/// Applies `rl` semantics to `inst`. Expressions which do not do their own handling of
/// result locations must call this function on their result.
/// As an example, if the `ResultLoc` is `ptr`, it will write the result to the pointer.
/// If the `ResultLoc` is `ty`, it will coerce the result to the type.
fn rvalue(mod: *Module, scope: *Scope, rl: ResultLoc, result: *zir.Inst) InnerError!*zir.Inst {
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
            _ = try addZIRBinOp(mod, scope, result.src, .store, ptr_inst, result);
            return result;
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            return mod.fail(scope, result.src, "TODO implement rvalue .bitcasted_ptr", .{});
        },
        .inferred_ptr => |alloc| {
            _ = try addZIRBinOp(mod, scope, result.src, .store_to_inferred_ptr, &alloc.base, result);
            return result;
        },
        .block_ptr => |block_scope| {
            block_scope.rvalue_rl_count += 1;
            _ = try addZIRBinOp(mod, scope, result.src, .store_to_block_ptr, block_scope.rl_ptr.?, result);
            return result;
        },
    }
}

fn rvalueVoid(mod: *Module, scope: *Scope, rl: ResultLoc, node: *ast.Node, result: void) InnerError!*zir.Inst {
    const src = scope.tree().token_locs[node.firstToken()].start;
    const void_inst = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    });
    return rvalue(mod, scope, rl, void_inst);
}

fn rlStrategy(rl: ResultLoc, block_scope: *Scope.GenZIR) ResultLoc.Strategy {
    var elide_store_to_block_ptr_instructions = false;
    switch (rl) {
        // In this branch there will not be any store_to_block_ptr instructions.
        .discard, .none, .ty, .ref => return .{
            .tag = .break_operand,
            .elide_store_to_block_ptr_instructions = false,
        },
        // The pointer got passed through to the sub-expressions, so we will use
        // break_void here.
        // In this branch there will not be any store_to_block_ptr instructions.
        .ptr => return .{
            .tag = .break_void,
            .elide_store_to_block_ptr_instructions = false,
        },
        .inferred_ptr, .bitcasted_ptr, .block_ptr => {
            if (block_scope.rvalue_rl_count == block_scope.break_count) {
                // Neither prong of the if consumed the result location, so we can
                // use break instructions to create an rvalue.
                return .{
                    .tag = .break_operand,
                    .elide_store_to_block_ptr_instructions = true,
                };
            } else {
                // Allow the store_to_block_ptr instructions to remain so that
                // semantic analysis can turn them into bitcasts.
                return .{
                    .tag = .break_void,
                    .elide_store_to_block_ptr_instructions = false,
                };
            }
        },
    }
}

fn setBlockResultLoc(block_scope: *Scope.GenZIR, parent_rl: ResultLoc) void {
    // Depending on whether the result location is a pointer or value, different
    // ZIR needs to be generated. In the former case we rely on storing to the
    // pointer to communicate the result, and use breakvoid; in the latter case
    // the block break instructions will have the result values.
    // One more complication: when the result location is a pointer, we detect
    // the scenario where the result location is not consumed. In this case
    // we emit ZIR for the block break instructions to have the result values,
    // and then rvalue() on that to pass the value to the result location.
    switch (parent_rl) {
        .discard, .none, .ty, .ptr, .ref => {
            block_scope.break_result_loc = parent_rl;
        },

        .inferred_ptr => |ptr| {
            block_scope.rl_ptr = &ptr.base;
            block_scope.break_result_loc = .{ .block_ptr = block_scope };
        },

        .bitcasted_ptr => |ptr| {
            block_scope.rl_ptr = &ptr.base;
            block_scope.break_result_loc = .{ .block_ptr = block_scope };
        },

        .block_ptr => |parent_block_scope| {
            block_scope.rl_ptr = parent_block_scope.rl_ptr.?;
            block_scope.break_result_loc = .{ .block_ptr = block_scope };
        },
    }
}

pub fn addZirInstTag(
    mod: *Module,
    scope: *Scope,
    src: usize,
    comptime tag: zir.Inst.Tag,
    positionals: std.meta.fieldInfo(tag.Type(), .positionals).field_type,
) !*zir.Inst {
    const gen_zir = scope.getGenZIR();
    try gen_zir.instructions.ensureCapacity(mod.gpa, gen_zir.instructions.items.len + 1);
    const inst = try gen_zir.arena.create(tag.Type());
    inst.* = .{
        .base = .{
            .tag = tag,
            .src = src,
        },
        .positionals = positionals,
        .kw_args = .{},
    };
    gen_zir.instructions.appendAssumeCapacity(&inst.base);
    return &inst.base;
}

pub fn addZIRInstSpecial(
    mod: *Module,
    scope: *Scope,
    src: usize,
    comptime T: type,
    positionals: std.meta.fieldInfo(T, .positionals).field_type,
    kw_args: std.meta.fieldInfo(T, .kw_args).field_type,
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
    body: zir.Body,
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
    positionals: std.meta.fieldInfo(T, .positionals).field_type,
    kw_args: std.meta.fieldInfo(T, .kw_args).field_type,
) !*zir.Inst {
    const inst_special = try addZIRInstSpecial(mod, scope, src, T, positionals, kw_args);
    return &inst_special.base;
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstConst(mod: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*zir.Inst {
    const P = std.meta.fieldInfo(zir.Inst.Const, .positionals).field_type;
    return addZIRInst(mod, scope, src, zir.Inst.Const, P{ .typed_value = typed_value }, .{});
}

/// TODO The existence of this function is a workaround for a bug in stage1.
pub fn addZIRInstLoop(mod: *Module, scope: *Scope, src: usize, body: zir.Body) !*zir.Inst.Loop {
    const P = std.meta.fieldInfo(zir.Inst.Loop, .positionals).field_type;
    return addZIRInstSpecial(mod, scope, src, zir.Inst.Loop, P{ .body = body }, .{});
}
