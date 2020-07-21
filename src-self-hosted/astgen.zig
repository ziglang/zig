const std = @import("std");
const mem = std.mem;
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

/// Turn Zig AST into untyped ZIR istructions.
pub fn expr(mod: *Module, scope: *Scope, node: *ast.Node) InnerError!*zir.Inst {
    switch (node.tag) {
        .VarDecl => unreachable, // Handled in `blockExpr`.

        .Add => return simpleInfixOp(mod, scope, node.castTag(.Add).?, .add),
        .Sub => return simpleInfixOp(mod, scope, node.castTag(.Sub).?, .sub),
        .BangEqual => return simpleInfixOp(mod, scope, node.castTag(.BangEqual).?, .cmp_neq),
        .EqualEqual => return simpleInfixOp(mod, scope, node.castTag(.EqualEqual).?, .cmp_eq),
        .GreaterThan => return simpleInfixOp(mod, scope, node.castTag(.GreaterThan).?, .cmp_gt),
        .GreaterOrEqual => return simpleInfixOp(mod, scope, node.castTag(.GreaterOrEqual).?, .cmp_gte),
        .LessThan => return simpleInfixOp(mod, scope, node.castTag(.LessThan).?, .cmp_lt),
        .LessOrEqual => return simpleInfixOp(mod, scope, node.castTag(.LessOrEqual).?, .cmp_lte),

        .Identifier => return identifier(mod, scope, node.castTag(.Identifier).?),
        .Asm => return assembly(mod, scope, node.castTag(.Asm).?),
        .StringLiteral => return stringLiteral(mod, scope, node.castTag(.StringLiteral).?),
        .IntegerLiteral => return integerLiteral(mod, scope, node.castTag(.IntegerLiteral).?),
        .BuiltinCall => return builtinCall(mod, scope, node.castTag(.BuiltinCall).?),
        .Call => return callExpr(mod, scope, node.castTag(.Call).?),
        .Unreachable => return unreach(mod, scope, node.castTag(.Unreachable).?),
        .ControlFlowExpression => return controlFlowExpr(mod, scope, node.castTag(.ControlFlowExpression).?),
        .If => return ifExpr(mod, scope, node.castTag(.If).?),
        .Assign => return assign(mod, scope, node.castTag(.Assign).?),
        .Period => return field(mod, scope, node.castTag(.Period).?),
        .Deref => return deref(mod, scope, node.castTag(.Deref).?),
        .BoolNot => return boolNot(mod, scope, node.castTag(.BoolNot).?),
        .FloatLiteral => return floatLiteral(mod, scope, node.castTag(.FloatLiteral).?),
        .UndefinedLiteral, .BoolLiteral, .NullLiteral => return primitiveLiteral(mod, scope, node),
        else => return mod.failNode(scope, node, "TODO implement astgen.Expr for {}", .{@tagName(node.tag)}),
    }
}

pub fn blockExpr(mod: *Module, parent_scope: *Scope, block_node: *ast.Node.Block) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (block_node.label) |label| {
        return mod.failTok(parent_scope, label, "TODO implement labeled blocks", .{});
    }

    var block_arena = std.heap.ArenaAllocator.init(mod.gpa);
    defer block_arena.deinit();

    var scope = parent_scope;
    for (block_node.statements()) |statement| {
        switch (statement.tag) {
            .VarDecl => {
                const sub_scope = try block_arena.allocator.create(Scope.LocalVar);
                const var_decl_node = @fieldParentPtr(ast.Node.VarDecl, "base", statement);
                sub_scope.* = try varDecl(mod, scope, var_decl_node);
                scope = &sub_scope.base;
            },
            else => _ = try expr(mod, scope, statement),
        }
    }
}

fn varDecl(mod: *Module, scope: *Scope, node: *ast.Node.VarDecl) InnerError!Scope.LocalVar {
    // TODO implement detection of shadowing
    if (node.getTrailer("comptime_token")) |comptime_token| {
        return mod.failTok(scope, comptime_token, "TODO implement comptime locals", .{});
    }
    if (node.getTrailer("align_node")) |align_node| {
        return mod.failNode(scope, align_node, "TODO implement alignment on locals", .{});
    }
    const tree = scope.tree();
    switch (tree.token_ids[node.mut_token]) {
        .Keyword_const => {
            if (node.getTrailer("type_node")) |type_node| {
                return mod.failNode(scope, type_node, "TODO implement typed const locals", .{});
            }
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            const init_node = node.getTrailer("init_node").?;
            if (nodeMayNeedMemoryLocation(init_node)) {
                return mod.failNode(scope, init_node, "TODO implement result locations", .{});
            }
            const init_inst = try expr(mod, scope, init_node);
            const ident_name = try identifierTokenString(mod, scope, node.name_token);
            return Scope.LocalVar{
                .parent = scope,
                .gen_zir = scope.getGenZIR(),
                .name = ident_name,
                .inst = init_inst,
            };
        },
        .Keyword_var => {
            return mod.failNode(scope, &node.base, "TODO implement local vars", .{});
        },
        else => unreachable,
    }
}

fn boolNot(mod: *Module, scope: *Scope, node: *ast.Node.SimplePrefixOp) InnerError!*zir.Inst {
    const operand = try expr(mod, scope, node.rhs);
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;
    return mod.addZIRUnOp(scope, src, .boolnot, operand);
}

fn assign(mod: *Module, scope: *Scope, infix_node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    if (infix_node.lhs.tag == .Identifier) {
        const ident = @fieldParentPtr(ast.Node.Identifier, "base", infix_node.lhs);
        const tree = scope.tree();
        const ident_name = try identifierTokenString(mod, scope, ident.token);
        if (std.mem.eql(u8, ident_name, "_")) {
            return expr(mod, scope, infix_node.rhs);
        } else {
            return mod.failNode(scope, &infix_node.base, "TODO implement infix operator assign", .{});
        }
    } else {
        return mod.failNode(scope, &infix_node.base, "TODO implement infix operator assign", .{});
    }
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

pub fn identifierStringInst(mod: *Module, scope: *Scope, node: *ast.Node.Identifier) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.token].start;

    const ident_name = try identifierTokenString(mod, scope, node.token);

    return mod.addZIRInst(scope, src, zir.Inst.Str, .{ .bytes = ident_name }, .{});
}

fn field(mod: *Module, scope: *Scope, node: *ast.Node.SimpleInfixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.op_token].start;

    const lhs = try expr(mod, scope, node.lhs);
    const field_name = try identifierStringInst(mod, scope, node.rhs.castTag(.Identifier).?);

    const pointer = try mod.addZIRInst(scope, src, zir.Inst.FieldPtr, .{ .object_ptr = lhs, .field_name = field_name }, .{});
    return mod.addZIRUnOp(scope, src, .deref, pointer);
}

fn deref(mod: *Module, scope: *Scope, node: *ast.Node.SimpleSuffixOp) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[node.rtoken].start;
    const lhs = try expr(mod, scope, node.lhs);
    return mod.addZIRUnOp(scope, src, .deref, lhs);
}

fn simpleInfixOp(
    mod: *Module,
    scope: *Scope,
    infix_node: *ast.Node.SimpleInfixOp,
    op_inst_tag: zir.Inst.Tag,
) InnerError!*zir.Inst {
    const lhs = try expr(mod, scope, infix_node.lhs);
    const rhs = try expr(mod, scope, infix_node.rhs);

    const tree = scope.tree();
    const src = tree.token_locs[infix_node.op_token].start;

    return mod.addZIRBinOp(scope, src, op_inst_tag, lhs, rhs);
}

fn ifExpr(mod: *Module, scope: *Scope, if_node: *ast.Node.If) InnerError!*zir.Inst {
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

    const cond = try expr(mod, &block_scope.base, if_node.condition);

    const tree = scope.tree();
    const if_src = tree.token_locs[if_node.if_token].start;
    const condbr = try mod.addZIRInstSpecial(&block_scope.base, if_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try mod.addZIRInstBlock(scope, if_src, .{
        .instructions = try block_scope.arena.dupe(*zir.Inst, block_scope.instructions.items),
    });
    var then_scope: Scope.GenZIR = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    const then_result = try expr(mod, &then_scope.base, if_node.body);
    if (!then_result.tag.isNoReturn()) {
        const then_src = tree.token_locs[if_node.body.lastToken()].start;
        _ = try mod.addZIRInst(&then_scope.base, then_src, zir.Inst.Break, .{
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
        const else_result = try expr(mod, &else_scope.base, else_node.body);
        if (!else_result.tag.isNoReturn()) {
            const else_src = tree.token_locs[else_node.body.lastToken()].start;
            _ = try mod.addZIRInst(&else_scope.base, else_src, zir.Inst.Break, .{
                .block = block,
                .operand = else_result,
            }, .{});
        }
    } else {
        // TODO Optimization opportunity: we can avoid an allocation and a memcpy here
        // by directly allocating the body for this one instruction.
        const else_src = tree.token_locs[if_node.lastToken()].start;
        _ = try mod.addZIRInst(&else_scope.base, else_src, zir.Inst.BreakVoid, .{
            .block = block,
        }, .{});
    }
    condbr.positionals.else_body = .{
        .instructions = try else_scope.arena.dupe(*zir.Inst, else_scope.instructions.items),
    };

    return &block.base;
}

fn controlFlowExpr(
    mod: *Module,
    scope: *Scope,
    cfe: *ast.Node.ControlFlowExpression,
) InnerError!*zir.Inst {
    switch (cfe.kind) {
        .Break => return mod.failNode(scope, &cfe.base, "TODO implement astgen.Expr for Break", .{}),
        .Continue => return mod.failNode(scope, &cfe.base, "TODO implement astgen.Expr for Continue", .{}),
        .Return => {},
    }
    const tree = scope.tree();
    const src = tree.token_locs[cfe.ltoken].start;
    if (cfe.rhs) |rhs_node| {
        const operand = try expr(mod, scope, rhs_node);
        return mod.addZIRUnOp(scope, src, .@"return", operand);
    } else {
        return mod.addZIRNoOp(scope, src, .returnvoid);
    }
}

fn identifier(mod: *Module, scope: *Scope, ident: *ast.Node.Identifier) InnerError!*zir.Inst {
    const tracy = trace(@src());
    defer tracy.end();

    const tree = scope.tree();
    const ident_name = try identifierTokenString(mod, scope, ident.token);
    const src = tree.token_locs[ident.token].start;
    if (mem.eql(u8, ident_name, "_")) {
        return mod.failNode(scope, &ident.base, "TODO implement '_' identifier", .{});
    }

    if (getSimplePrimitiveValue(ident_name)) |typed_value| {
        return mod.addZIRInstConst(scope, src, typed_value);
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
                    return mod.addZIRInstConst(scope, src, .{
                        .ty = Type.initTag(.comptime_int),
                        .val = Value.initPayload(&int_type_payload.base),
                    });
                },
            };
            return mod.addZIRInstConst(scope, src, .{
                .ty = Type.initTag(.type),
                .val = val,
            });
        }
    }

    // Local variables, including function parameters.
    {
        var s = scope;
        while (true) switch (s.tag) {
            .local_var => {
                const local_var = s.cast(Scope.LocalVar).?;
                if (mem.eql(u8, local_var.name, ident_name)) {
                    return local_var.inst;
                }
                s = local_var.parent;
            },
            .gen_zir => s = s.cast(Scope.GenZIR).?.parent,
            else => break,
        };
    }

    if (mod.lookupDeclName(scope, ident_name)) |decl| {
        return try mod.addZIRInst(scope, src, zir.Inst.DeclValInModule, .{ .decl = decl }, .{});
    }

    return mod.failNode(scope, &ident.base, "use of undeclared identifier '{}'", .{ident_name});
}

fn stringLiteral(mod: *Module, scope: *Scope, str_lit: *ast.Node.StringLiteral) InnerError!*zir.Inst {
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
    return mod.addZIRInst(scope, src, zir.Inst.Str, .{ .bytes = bytes }, .{});
}

fn integerLiteral(mod: *Module, scope: *Scope, int_lit: *ast.Node.IntegerLiteral) InnerError!*zir.Inst {
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
        return mod.addZIRInstConst(scope, src, .{
            .ty = Type.initTag(.comptime_int),
            .val = Value.initPayload(&int_payload.base),
        });
    } else |err| {
        return mod.failTok(scope, int_lit.token, "TODO implement int literals that don't fit in a u64", .{});
    }
}

fn floatLiteral(mod: *Module, scope: *Scope, float_lit: *ast.Node.FloatLiteral) InnerError!*zir.Inst {
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
    return mod.addZIRInstConst(scope, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = Value.initPayload(&float_payload.base),
    });
}

fn primitiveLiteral(mod: *Module, scope: *Scope, node: *ast.Node) InnerError!*zir.Inst {
    const arena = scope.arena();
    const tree = scope.tree();
    const src = tree.token_locs[node.firstToken()].start;

    if (node.cast(ast.Node.BoolLiteral)) |bool_node| {
        return mod.addZIRInstConst(scope, src, .{
            .ty = Type.initTag(.bool),
            .val = if (tree.token_ids[bool_node.token] == .Keyword_true)
                Value.initTag(.bool_true)
            else
                Value.initTag(.bool_false),
        });
    } else if (node.tag == .UndefinedLiteral) {
        return mod.addZIRInstConst(scope, src, .{
            .ty = Type.initTag(.@"undefined"),
            .val = Value.initTag(.undef),
        });
    } else if (node.tag == .NullLiteral) {
        return mod.addZIRInstConst(scope, src, .{
            .ty = Type.initTag(.@"null"),
            .val = Value.initTag(.null_value),
        });
    } else unreachable;
}

fn assembly(mod: *Module, scope: *Scope, asm_node: *ast.Node.Asm) InnerError!*zir.Inst {
    if (asm_node.outputs.len != 0) {
        return mod.failNode(scope, &asm_node.base, "TODO implement asm with an output", .{});
    }
    const arena = scope.arena();
    const tree = scope.tree();

    const inputs = try arena.alloc(*zir.Inst, asm_node.inputs.len);
    const args = try arena.alloc(*zir.Inst, asm_node.inputs.len);

    for (asm_node.inputs) |input, i| {
        // TODO semantically analyze constraints
        inputs[i] = try expr(mod, scope, input.constraint);
        args[i] = try expr(mod, scope, input.expr);
    }

    const src = tree.token_locs[asm_node.asm_token].start;
    const return_type = try mod.addZIRInstConst(scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const asm_inst = try mod.addZIRInst(scope, src, zir.Inst.Asm, .{
        .asm_source = try expr(mod, scope, asm_node.template),
        .return_type = return_type,
    }, .{
        .@"volatile" = asm_node.volatile_token != null,
        //.clobbers =  TODO handle clobbers
        .inputs = inputs,
        .args = args,
    });
    return asm_inst;
}

fn builtinCall(mod: *Module, scope: *Scope, call: *ast.Node.BuiltinCall) InnerError!*zir.Inst {
    const tree = scope.tree();
    const builtin_name = tree.tokenSlice(call.builtin_token);
    const src = tree.token_locs[call.builtin_token].start;

    inline for (std.meta.declarations(zir.Inst)) |inst| {
        if (inst.data != .Type) continue;
        const T = inst.data.Type;
        if (!@hasDecl(T, "builtin_name")) continue;
        if (std.mem.eql(u8, builtin_name, T.builtin_name)) {
            var value: T = undefined;
            const positionals = @typeInfo(std.meta.fieldInfo(T, "positionals").field_type).Struct;
            if (positionals.fields.len == 0) {
                return mod.addZIRInst(scope, src, T, value.positionals, value.kw_args);
            }
            const arg_count: ?usize = if (positionals.fields[0].field_type == []*zir.Inst) null else positionals.fields.len;
            if (arg_count) |some| {
                if (call.params_len != some) {
                    return mod.failTok(
                        scope,
                        call.builtin_token,
                        "expected {} parameter{}, found {}",
                        .{ some, if (some == 1) "" else "s", call.params_len },
                    );
                }
                const params = call.params();
                inline for (positionals.fields) |p, i| {
                    @field(value.positionals, p.name) = try expr(mod, scope, params[i]);
                }
            } else {
                return mod.failTok(scope, call.builtin_token, "TODO var args builtin '{}'", .{builtin_name});
            }

            return mod.addZIRInst(scope, src, T, value.positionals, .{});
        }
    }
    return mod.failTok(scope, call.builtin_token, "TODO implement builtin call for '{}'", .{builtin_name});
}

fn callExpr(mod: *Module, scope: *Scope, node: *ast.Node.Call) InnerError!*zir.Inst {
    const tree = scope.tree();
    const lhs = try expr(mod, scope, node.lhs);

    const param_nodes = node.params();
    const args = try scope.getGenZIR().arena.alloc(*zir.Inst, param_nodes.len);
    for (param_nodes) |param_node, i| {
        args[i] = try expr(mod, scope, param_node);
    }

    const src = tree.token_locs[node.lhs.firstToken()].start;
    return mod.addZIRInst(scope, src, zir.Inst.Call, .{
        .func = lhs,
        .args = args,
    }, .{});
}

fn unreach(mod: *Module, scope: *Scope, unreach_node: *ast.Node.Unreachable) InnerError!*zir.Inst {
    const tree = scope.tree();
    const src = tree.token_locs[unreach_node.token].start;
    return mod.addZIRNoOp(scope, src, .@"unreachable");
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

            .ControlFlowExpression,
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
            => return true,

            // Depending on AST properties, they may need memory locations.
            .If => return node.castTag(.If).?.@"else" != null,
            .Block => return node.castTag(.Block).?.label != null,
        }
    }
}
