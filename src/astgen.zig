const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const zir = @import("zir.zig");
const Module = @import("Module.zig");
const ast = std.zig.ast;
const trace = @import("tracy.zig").trace;
const Scope = Module.Scope;
const InnerError = Module.InnerError;
const BuiltinFn = @import("BuiltinFn.zig");

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
    ty: zir.Inst.Ref,
    /// The expression must store its result into this typed pointer. The result instruction
    /// from the expression must be ignored.
    ptr: zir.Inst.Ref,
    /// The expression must store its result into this allocation, which has an inferred type.
    /// The result instruction from the expression must be ignored.
    /// Always an instruction with tag `alloc_inferred`.
    inferred_ptr: zir.Inst.Ref,
    /// The expression must store its result into this pointer, which is a typed pointer that
    /// has been bitcasted to whatever the expression's type is.
    /// The result instruction from the expression must be ignored.
    bitcasted_ptr: zir.Inst.Ref,
    /// There is a pointer for the expression to store its result into, however, its type
    /// is inferred based on peer type resolution for a `zir.Inst.Block`.
    /// The result instruction from the expression must be ignored.
    block_ptr: *Module.Scope.GenZir,

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

const void_inst: zir.Inst.Ref = @enumToInt(zir.Const.void_value);

pub fn typeExpr(mod: *Module, scope: *Scope, type_node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const type_rl: ResultLoc = .{ .ty = @enumToInt(zir.Const.type_type) };
    return expr(mod, scope, type_rl, type_node);
}

fn lvalExpr(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    switch (node_tags[node]) {
        .root => unreachable,
        .@"usingnamespace" => unreachable,
        .test_decl => unreachable,
        .global_var_decl => unreachable,
        .local_var_decl => unreachable,
        .simple_var_decl => unreachable,
        .aligned_var_decl => unreachable,
        .switch_case => unreachable,
        .switch_case_one => unreachable,
        .container_field_init => unreachable,
        .container_field_align => unreachable,
        .container_field => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,

        .assign,
        .assign_bit_and,
        .assign_bit_or,
        .assign_bit_shift_left,
        .assign_bit_shift_right,
        .assign_bit_xor,
        .assign_div,
        .assign_sub,
        .assign_sub_wrap,
        .assign_mod,
        .assign_add,
        .assign_add_wrap,
        .assign_mul,
        .assign_mul_wrap,
        .add,
        .add_wrap,
        .sub,
        .sub_wrap,
        .mul,
        .mul_wrap,
        .div,
        .mod,
        .bit_and,
        .bit_or,
        .bit_shift_left,
        .bit_shift_right,
        .bit_xor,
        .bang_equal,
        .equal_equal,
        .greater_than,
        .greater_or_equal,
        .less_than,
        .less_or_equal,
        .array_cat,
        .array_mult,
        .bool_and,
        .bool_or,
        .@"asm",
        .asm_simple,
        .string_literal,
        .integer_literal,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        .call_one,
        .call_one_comma,
        .async_call_one,
        .async_call_one_comma,
        .unreachable_literal,
        .@"return",
        .@"if",
        .if_simple,
        .@"while",
        .while_simple,
        .while_cont,
        .bool_not,
        .address_of,
        .float_literal,
        .undefined_literal,
        .true_literal,
        .false_literal,
        .null_literal,
        .optional_type,
        .block,
        .block_semicolon,
        .block_two,
        .block_two_semicolon,
        .@"break",
        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        .array_type,
        .array_type_sentinel,
        .enum_literal,
        .multiline_string_literal,
        .char_literal,
        .@"defer",
        .@"errdefer",
        .@"catch",
        .error_union,
        .merge_error_sets,
        .switch_range,
        .@"await",
        .bit_not,
        .negation,
        .negation_wrap,
        .@"resume",
        .@"try",
        .slice,
        .slice_open,
        .slice_sentinel,
        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        .@"switch",
        .switch_comma,
        .@"for",
        .for_simple,
        .@"suspend",
        .@"continue",
        .@"anytype",
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        .fn_decl,
        .anyframe_type,
        .anyframe_literal,
        .error_set_decl,
        .container_decl,
        .container_decl_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .@"comptime",
        .@"nosuspend",
        .error_value,
        => return mod.failNode(scope, node, "invalid left-hand side to assignment", .{}),

        .builtin_call,
        .builtin_call_comma,
        .builtin_call_two,
        .builtin_call_two_comma,
        => {
            const builtin_token = main_tokens[node];
            const builtin_name = tree.tokenSlice(builtin_token);
            // If the builtin is an invalid name, we don't cause an error here; instead
            // let it pass, and the error will be "invalid builtin function" later.
            if (BuiltinFn.list.get(builtin_name)) |info| {
                if (!info.allows_lvalue) {
                    return mod.failNode(scope, node, "invalid left-hand side to assignment", .{});
                }
            }
        },

        // These can be assigned to.
        .unwrap_optional,
        .deref,
        .field_access,
        .array_access,
        .identifier,
        .grouped_expression,
        .@"orelse",
        => {},
    }
    return expr(mod, scope, .ref, node);
}

/// Turn Zig AST into untyped ZIR istructions.
/// When `rl` is discard, ptr, inferred_ptr, bitcasted_ptr, or inferred_ptr, the
/// result instruction can be used to inspect whether it is isNoReturn() but that is it,
/// it must otherwise not be used.
pub fn expr(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const node_tags = tree.nodes.items(.tag);
    const token_starts = tree.tokens.items(.start);

    switch (node_tags[node]) {
        .root => unreachable, // Top-level declaration.
        .@"usingnamespace" => unreachable, // Top-level declaration.
        .test_decl => unreachable, // Top-level declaration.
        .container_field_init => unreachable, // Top-level declaration.
        .container_field_align => unreachable, // Top-level declaration.
        .container_field => unreachable, // Top-level declaration.
        .fn_decl => unreachable, // Top-level declaration.

        .global_var_decl => unreachable, // Handled in `blockExpr`.
        .local_var_decl => unreachable, // Handled in `blockExpr`.
        .simple_var_decl => unreachable, // Handled in `blockExpr`.
        .aligned_var_decl => unreachable, // Handled in `blockExpr`.

        .switch_case => unreachable, // Handled in `switchExpr`.
        .switch_case_one => unreachable, // Handled in `switchExpr`.
        .switch_range => unreachable, // Handled in `switchExpr`.

        .asm_output => unreachable, // Handled in `asmExpr`.
        .asm_input => unreachable, // Handled in `asmExpr`.

        .assign => {
            try assign(mod, scope, node);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_bit_and => {
            try assignOp(mod, scope, node, .bit_and);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_bit_or => {
            try assignOp(mod, scope, node, .bit_or);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_bit_shift_left => {
            try assignOp(mod, scope, node, .shl);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_bit_shift_right => {
            try assignOp(mod, scope, node, .shr);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_bit_xor => {
            try assignOp(mod, scope, node, .xor);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_div => {
            try assignOp(mod, scope, node, .div);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_sub => {
            try assignOp(mod, scope, node, .sub);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_sub_wrap => {
            try assignOp(mod, scope, node, .subwrap);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_mod => {
            try assignOp(mod, scope, node, .mod_rem);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_add => {
            try assignOp(mod, scope, node, .add);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_add_wrap => {
            try assignOp(mod, scope, node, .addwrap);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_mul => {
            try assignOp(mod, scope, node, .mul);
            return rvalue(mod, scope, rl, void_inst, node);
        },
        .assign_mul_wrap => {
            try assignOp(mod, scope, node, .mulwrap);
            return rvalue(mod, scope, rl, void_inst, node);
        },

        .add => return simpleBinOp(mod, scope, rl, node, .add),
        .add_wrap => return simpleBinOp(mod, scope, rl, node, .addwrap),
        .sub => return simpleBinOp(mod, scope, rl, node, .sub),
        .sub_wrap => return simpleBinOp(mod, scope, rl, node, .subwrap),
        .mul => return simpleBinOp(mod, scope, rl, node, .mul),
        .mul_wrap => return simpleBinOp(mod, scope, rl, node, .mulwrap),
        .div => return simpleBinOp(mod, scope, rl, node, .div),
        .mod => return simpleBinOp(mod, scope, rl, node, .mod_rem),
        .bit_and => return simpleBinOp(mod, scope, rl, node, .bit_and),
        .bit_or => return simpleBinOp(mod, scope, rl, node, .bit_or),
        .bit_shift_left => return simpleBinOp(mod, scope, rl, node, .shl),
        .bit_shift_right => return simpleBinOp(mod, scope, rl, node, .shr),
        .bit_xor => return simpleBinOp(mod, scope, rl, node, .xor),

        .bang_equal => return simpleBinOp(mod, scope, rl, node, .cmp_neq),
        .equal_equal => return simpleBinOp(mod, scope, rl, node, .cmp_eq),
        .greater_than => return simpleBinOp(mod, scope, rl, node, .cmp_gt),
        .greater_or_equal => return simpleBinOp(mod, scope, rl, node, .cmp_gte),
        .less_than => return simpleBinOp(mod, scope, rl, node, .cmp_lt),
        .less_or_equal => return simpleBinOp(mod, scope, rl, node, .cmp_lte),

        .array_cat => return simpleBinOp(mod, scope, rl, node, .array_cat),
        .array_mult => return simpleBinOp(mod, scope, rl, node, .array_mul),

        .bool_and => return boolBinOp(mod, scope, rl, node, true),
        .bool_or => return boolBinOp(mod, scope, rl, node, false),

        .bool_not => @panic("TODO"),
        .bit_not => @panic("TODO"),
        .negation => @panic("TODO"),
        .negation_wrap => @panic("TODO"),
        //.bool_not => return rvalue(mod, scope, rl, try boolNot(mod, scope, node)),
        //.bit_not => return rvalue(mod, scope, rl, try bitNot(mod, scope, node)),
        //.negation => return rvalue(mod, scope, rl, try negation(mod, scope, node, .sub)),
        //.negation_wrap => return rvalue(mod, scope, rl, try negation(mod, scope, node, .subwrap)),

        .identifier => return identifier(mod, scope, rl, node),

        .asm_simple => return asmExpr(mod, scope, rl, tree.asmSimple(node)),
        .@"asm" => return asmExpr(mod, scope, rl, tree.asmFull(node)),

        .string_literal => return stringLiteral(mod, scope, rl, node),
        .multiline_string_literal => return multilineStringLiteral(mod, scope, rl, node),

        .integer_literal => return integerLiteral(mod, scope, rl, node),

        .builtin_call_two, .builtin_call_two_comma => {
            if (node_datas[node].lhs == 0) {
                const params = [_]ast.Node.Index{};
                return builtinCall(mod, scope, rl, node, &params);
            } else if (node_datas[node].rhs == 0) {
                const params = [_]ast.Node.Index{node_datas[node].lhs};
                return builtinCall(mod, scope, rl, node, &params);
            } else {
                const params = [_]ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
                return builtinCall(mod, scope, rl, node, &params);
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return builtinCall(mod, scope, rl, node, params);
        },

        .call_one, .call_one_comma, .async_call_one, .async_call_one_comma => {
            var params: [1]ast.Node.Index = undefined;
            return callExpr(mod, scope, rl, node, tree.callOne(&params, node));
        },
        .call, .call_comma, .async_call, .async_call_comma => {
            return callExpr(mod, scope, rl, node, tree.callFull(node));
        },

        .unreachable_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            return addZIRNoOp(mod, scope, src, .unreachable_safe);
        },
        .@"return" => return ret(mod, scope, node),
        .field_access => return fieldAccess(mod, scope, rl, node),
        .float_literal => return floatLiteral(mod, scope, rl, node),

        .if_simple => return ifExpr(mod, scope, rl, tree.ifSimple(node)),
        .@"if" => return ifExpr(mod, scope, rl, tree.ifFull(node)),

        .while_simple => return whileExpr(mod, scope, rl, tree.whileSimple(node)),
        .while_cont => return whileExpr(mod, scope, rl, tree.whileCont(node)),
        .@"while" => return whileExpr(mod, scope, rl, tree.whileFull(node)),

        .for_simple => return forExpr(mod, scope, rl, tree.forSimple(node)),
        .@"for" => return forExpr(mod, scope, rl, tree.forFull(node)),

        // TODO handling these separately would actually be simpler & have fewer branches
        // once we have a ZIR instruction for each of these 3 cases.
        .slice_open => return sliceExpr(mod, scope, rl, tree.sliceOpen(node)),
        .slice => return sliceExpr(mod, scope, rl, tree.slice(node)),
        .slice_sentinel => return sliceExpr(mod, scope, rl, tree.sliceSentinel(node)),

        .deref => {
            if (true) @panic("TODO update for zir-memory-layout");
            const lhs = try expr(mod, scope, .none, node_datas[node].lhs);
            const src = token_starts[main_tokens[node]];
            const result = try addZIRUnOp(mod, scope, src, .deref, lhs);
            return rvalue(mod, scope, rl, result);
        },
        .address_of => {
            if (true) @panic("TODO update for zir-memory-layout");
            const result = try expr(mod, scope, .ref, node_datas[node].lhs);
            return rvalue(mod, scope, rl, result);
        },
        .undefined_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.@"undefined"),
                .val = Value.initTag(.undef),
            });
            return rvalue(mod, scope, rl, result);
        },
        .true_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.bool),
                .val = Value.initTag(.bool_true),
            });
            return rvalue(mod, scope, rl, result);
        },
        .false_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.bool),
                .val = Value.initTag(.bool_false),
            });
            return rvalue(mod, scope, rl, result);
        },
        .null_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.@"null"),
                .val = Value.initTag(.null_value),
            });
            return rvalue(mod, scope, rl, result);
        },
        .optional_type => {
            if (true) @panic("TODO update for zir-memory-layout");
            const src = token_starts[main_tokens[node]];
            const operand = try typeExpr(mod, scope, node_datas[node].lhs);
            const result = try addZIRUnOp(mod, scope, src, .optional_type, operand);
            return rvalue(mod, scope, rl, result);
        },
        .unwrap_optional => {
            if (true) @panic("TODO update for zir-memory-layout");
            const src = token_starts[main_tokens[node]];
            switch (rl) {
                .ref => return addZIRUnOp(
                    mod,
                    scope,
                    src,
                    .optional_payload_safe_ptr,
                    try expr(mod, scope, .ref, node_datas[node].lhs),
                ),
                else => return rvalue(mod, scope, rl, try addZIRUnOp(
                    mod,
                    scope,
                    src,
                    .optional_payload_safe,
                    try expr(mod, scope, .none, node_datas[node].lhs),
                )),
            }
        },
        .block_two, .block_two_semicolon => {
            if (true) @panic("TODO update for zir-memory-layout");
            const statements = [2]ast.Node.Index{ node_datas[node].lhs, node_datas[node].rhs };
            if (node_datas[node].lhs == 0) {
                return blockExpr(mod, scope, rl, node, statements[0..0]);
            } else if (node_datas[node].rhs == 0) {
                return blockExpr(mod, scope, rl, node, statements[0..1]);
            } else {
                return blockExpr(mod, scope, rl, node, statements[0..2]);
            }
        },
        .block, .block_semicolon => {
            if (true) @panic("TODO update for zir-memory-layout");
            const statements = tree.extra_data[node_datas[node].lhs..node_datas[node].rhs];
            return blockExpr(mod, scope, rl, node, statements);
        },
        .enum_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const ident_token = main_tokens[node];
            const gen_zir = scope.getGenZir();
            const string_bytes = &gen_zir.zir_exec.string_bytes;
            const str_index = string_bytes.items.len;
            try mod.appendIdentStr(scope, ident_token, string_bytes);
            const str_len = string_bytes.items.len - str_index;
            const result = try gen_zir.addStr(.enum_literal, str_index, str_len);
            return rvalue(mod, scope, rl, result);
        },
        .error_value => {
            if (true) @panic("TODO update for zir-memory-layout");
            const ident_token = node_datas[node].rhs;
            const name = try mod.identifierTokenString(scope, ident_token);
            const src = token_starts[ident_token];
            const result = try addZirInstTag(mod, scope, src, .error_value, .{ .name = name });
            return rvalue(mod, scope, rl, result);
        },
        .error_union => {
            if (true) @panic("TODO update for zir-memory-layout");
            const error_set = try typeExpr(mod, scope, node_datas[node].lhs);
            const payload = try typeExpr(mod, scope, node_datas[node].rhs);
            const src = token_starts[main_tokens[node]];
            const result = try addZIRBinOp(mod, scope, src, .error_union_type, error_set, payload);
            return rvalue(mod, scope, rl, result);
        },
        .merge_error_sets => {
            if (true) @panic("TODO update for zir-memory-layout");
            const lhs = try typeExpr(mod, scope, node_datas[node].lhs);
            const rhs = try typeExpr(mod, scope, node_datas[node].rhs);
            const src = token_starts[main_tokens[node]];
            const result = try addZIRBinOp(mod, scope, src, .merge_error_sets, lhs, rhs);
            return rvalue(mod, scope, rl, result);
        },
        .anyframe_literal => {
            if (true) @panic("TODO update for zir-memory-layout");
            const main_token = main_tokens[node];
            const src = token_starts[main_token];
            const result = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.anyframe_type),
            });
            return rvalue(mod, scope, rl, result);
        },
        .anyframe_type => {
            if (true) @panic("TODO update for zir-memory-layout");
            const src = token_starts[node_datas[node].lhs];
            const return_type = try typeExpr(mod, scope, node_datas[node].rhs);
            const result = try addZIRUnOp(mod, scope, src, .anyframe_type, return_type);
            return rvalue(mod, scope, rl, result);
        },
        .@"catch" => {
            if (true) @panic("TODO update for zir-memory-layout");
            const catch_token = main_tokens[node];
            const payload_token: ?ast.TokenIndex = if (token_tags[catch_token + 1] == .pipe)
                catch_token + 2
            else
                null;
            switch (rl) {
                .ref => return orelseCatchExpr(
                    mod,
                    scope,
                    rl,
                    node_datas[node].lhs,
                    main_tokens[node],
                    .is_err_ptr,
                    .err_union_payload_unsafe_ptr,
                    .err_union_code_ptr,
                    node_datas[node].rhs,
                    payload_token,
                ),
                else => return orelseCatchExpr(
                    mod,
                    scope,
                    rl,
                    node_datas[node].lhs,
                    main_tokens[node],
                    .is_err,
                    .err_union_payload_unsafe,
                    .err_union_code,
                    node_datas[node].rhs,
                    payload_token,
                ),
            }
        },
        .@"orelse" => switch (rl) {
            .ref => return orelseCatchExpr(
                mod,
                scope,
                rl,
                node_datas[node].lhs,
                main_tokens[node],
                .is_null_ptr,
                .optional_payload_unsafe_ptr,
                undefined,
                node_datas[node].rhs,
                null,
            ),
            else => return orelseCatchExpr(
                mod,
                scope,
                rl,
                node_datas[node].lhs,
                main_tokens[node],
                .is_null,
                .optional_payload_unsafe,
                undefined,
                node_datas[node].rhs,
                null,
            ),
        },

        .ptr_type_aligned => return ptrType(mod, scope, rl, tree.ptrTypeAligned(node)),
        .ptr_type_sentinel => return ptrType(mod, scope, rl, tree.ptrTypeSentinel(node)),
        .ptr_type => return ptrType(mod, scope, rl, tree.ptrType(node)),
        .ptr_type_bit_range => return ptrType(mod, scope, rl, tree.ptrTypeBitRange(node)),

        .container_decl,
        .container_decl_trailing,
        => return containerDecl(mod, scope, rl, tree.containerDecl(node)),
        .container_decl_two, .container_decl_two_trailing => {
            var buffer: [2]ast.Node.Index = undefined;
            return containerDecl(mod, scope, rl, tree.containerDeclTwo(&buffer, node));
        },
        .container_decl_arg,
        .container_decl_arg_trailing,
        => return containerDecl(mod, scope, rl, tree.containerDeclArg(node)),

        .tagged_union,
        .tagged_union_trailing,
        => return containerDecl(mod, scope, rl, tree.taggedUnion(node)),
        .tagged_union_two, .tagged_union_two_trailing => {
            var buffer: [2]ast.Node.Index = undefined;
            return containerDecl(mod, scope, rl, tree.taggedUnionTwo(&buffer, node));
        },
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        => return containerDecl(mod, scope, rl, tree.taggedUnionEnumTag(node)),

        .@"break" => return breakExpr(mod, scope, rl, node),
        .@"continue" => return continueExpr(mod, scope, rl, node),
        .grouped_expression => return expr(mod, scope, rl, node_datas[node].lhs),
        .array_type => return arrayType(mod, scope, rl, node),
        .array_type_sentinel => return arrayTypeSentinel(mod, scope, rl, node),
        .char_literal => return charLiteral(mod, scope, rl, node),
        .error_set_decl => return errorSetDecl(mod, scope, rl, node),
        .array_access => return arrayAccess(mod, scope, rl, node),
        .@"comptime" => return comptimeExpr(mod, scope, rl, node_datas[node].lhs),
        .@"switch", .switch_comma => return switchExpr(mod, scope, rl, node),

        .@"nosuspend" => return nosuspendExpr(mod, scope, rl, node),
        .@"suspend" => @panic("TODO"),
        //.@"suspend" => return rvalue(mod, scope, rl, try suspendExpr(mod, scope, node)),
        .@"await" => return awaitExpr(mod, scope, rl, node),
        .@"resume" => @panic("TODO"),
        //.@"resume" => return rvalue(mod, scope, rl, try resumeExpr(mod, scope, node)),

        .@"defer" => return mod.failNode(scope, node, "TODO implement astgen.expr for .defer", .{}),
        .@"errdefer" => return mod.failNode(scope, node, "TODO implement astgen.expr for .errdefer", .{}),
        .@"try" => return mod.failNode(scope, node, "TODO implement astgen.expr for .Try", .{}),

        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => return mod.failNode(scope, node, "TODO implement astgen.expr for array literals", .{}),

        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        => return mod.failNode(scope, node, "TODO implement astgen.expr for struct literals", .{}),

        .@"anytype" => return mod.failNode(scope, node, "TODO implement astgen.expr for .anytype", .{}),
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => return mod.failNode(scope, node, "TODO implement astgen.expr for function prototypes", .{}),
    }
}

pub fn comptimeExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout branch");

    // If we are already in a comptime scope, no need to make another one.
    if (parent_scope.isComptime()) {
        return expr(mod, parent_scope, rl, node);
    }

    const gz = parent_scope.getGenZir();
    const tree = parent_scope.tree();
    const token_starts = tree.tokens.items(.start);

    // Make a scope to collect generated instructions in the sub-expression.
    var block_scope: Scope.GenZir = .{
        .parent = parent_scope,
        .zir_code = gz.zir_code,
        .force_comptime = true,
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    // No need to capture the result here because block_comptime_flat implies that the final
    // instruction is the block's result value.
    _ = try expr(mod, &block_scope.base, rl, node);

    const src = token_starts[tree.firstToken(node)];
    const block = try addZIRInstBlock(mod, parent_scope, src, .block_comptime_flat, .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, block_scope.instructions.items),
    });

    return &block.base;
}

fn breakExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = parent_scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const break_label = node_datas[node].lhs;
    const rhs = node_datas[node].rhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZir).?;

                const block_inst = blk: {
                    if (break_label != 0) {
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

                if (rhs == 0) {
                    const result = try addZirInstTag(mod, parent_scope, src, .break_void, .{
                        .block = block_inst,
                    });
                    return rvalue(mod, parent_scope, rl, result);
                }
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
                        const inst_list = parent_scope.getGenZir().instructions.items;
                        const last_inst = inst_list[inst_list.len - 2];
                        const store_inst = last_inst.castTag(.store_to_block_ptr).?;
                        assert(store_inst.positionals.lhs == gen_zir.rl_ptr.?);
                        try gen_zir.labeled_store_to_block_ptr_list.append(mod.gpa, store_inst);
                    }
                }
                return rvalue(mod, parent_scope, rl, br);
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .gen_suspend => scope = scope.cast(Scope.GenZIR).?.parent,
            .gen_nosuspend => scope = scope.cast(Scope.Nosuspend).?.parent,
            else => if (break_label != 0) {
                const label_name = try mod.identifierTokenString(parent_scope, break_label);
                return mod.failTok(parent_scope, break_label, "label not found: '{s}'", .{label_name});
            } else {
                return mod.failTok(parent_scope, src, "break expression outside loop", .{});
            },
        }
    }
}

fn continueExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = parent_scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const break_label = node_datas[node].lhs;

    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZir).?;
                const continue_block = gen_zir.continue_block orelse {
                    scope = gen_zir.parent;
                    continue;
                };
                if (break_label != 0) blk: {
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

                const result = try addZirInstTag(mod, parent_scope, src, .break_void, .{
                    .block = continue_block,
                });
                return rvalue(mod, parent_scope, rl, result);
            },
            .local_val => scope = scope.cast(Scope.LocalVal).?.parent,
            .local_ptr => scope = scope.cast(Scope.LocalPtr).?.parent,
            .gen_suspend => scope = scope.cast(Scope.GenZIR).?.parent,
            .gen_nosuspend => scope = scope.cast(Scope.Nosuspend).?.parent,
            else => if (break_label != 0) {
                const label_name = try mod.identifierTokenString(parent_scope, break_label);
                return mod.failTok(parent_scope, break_label, "label not found: '{s}'", .{label_name});
            } else {
                return mod.failTok(parent_scope, src, "continue expression outside loop", .{});
            },
        }
    }
}

pub fn blockExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
) InnerError!zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    if (token_tags[lbrace - 1] == .colon and
        token_tags[lbrace - 2] == .identifier)
    {
        return labeledBlockExpr(mod, scope, rl, block_node, statements, .block);
    }

    try blockExprStmts(mod, scope, block_node, statements);
    return rvalue(mod, scope, rl, void_inst, block_node);
}

fn checkLabelRedefinition(mod: *Module, parent_scope: *Scope, label: ast.TokenIndex) !void {
    // Look for the label in the scope.
    var scope = parent_scope;
    while (true) {
        switch (scope.tag) {
            .gen_zir => {
                const gen_zir = scope.cast(Scope.GenZir).?;
                if (gen_zir.label) |prev_label| {
                    if (try tokenIdentEql(mod, parent_scope, label, prev_label.token)) {
                        const tree = parent_scope.tree();
                        const main_tokens = tree.nodes.items(.main_token);
                        const token_starts = tree.tokens.items(.start);

                        const label_name = try mod.identifierTokenString(parent_scope, label);
                        const msg = msg: {
                            const msg = try mod.errMsg(
                                parent_scope,
                                gen_zir.tokSrcLoc(label),
                                "redefinition of label '{s}'",
                                .{label_name},
                            );
                            errdefer msg.destroy(mod.gpa);
                            try mod.errNote(
                                parent_scope,
                                gen_zir.tokSrcLoc(prev_label.token),
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
            .gen_suspend => scope = scope.cast(Scope.GenZIR).?.parent,
            .gen_nosuspend => scope = scope.cast(Scope.Nosuspend).?.parent,
            else => return,
        }
    }
}

fn labeledBlockExpr(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
    zir_tag: zir.Inst.Tag,
) InnerError!zir.Inst.Ref {
    const tracy = trace(@src());
    defer tracy.end();

    assert(zir_tag == .block or zir_tag == .block_comptime);

    const tree = parent_scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);

    const lbrace = main_tokens[block_node];
    const label_token = lbrace - 2;
    assert(token_tags[label_token] == .identifier);
    const src = token_starts[lbrace];

    try checkLabelRedefinition(mod, parent_scope, label_token);

    // Create the Block ZIR instruction so that we can put it into the GenZir struct
    // so that break statements can reference it.
    const gen_zir = parent_scope.getGenZir();
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

    var block_scope: Scope.GenZir = .{
        .parent = parent_scope,
        .decl = parent_scope.ownerDecl().?,
        .arena = gen_zir.arena,
        .force_comptime = parent_scope.isComptime(),
        .instructions = .{},
        // TODO @as here is working around a stage1 miscompilation bug :(
        .label = @as(?Scope.GenZir.Label, Scope.GenZir.Label{
            .token = label_token,
            .block_inst = block_inst,
        }),
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);
    defer block_scope.labeled_breaks.deinit(mod.gpa);
    defer block_scope.labeled_store_to_block_ptr_list.deinit(mod.gpa);

    try blockExprStmts(mod, &block_scope.base, block_node, statements);

    if (!block_scope.label.?.used) {
        return mod.failTok(parent_scope, label_token, "unused block label", .{});
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
    node: ast.Node.Index,
    statements: []const ast.Node.Index,
) !void {
    const tree = parent_scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const node_tags = tree.nodes.items(.tag);

    var block_arena = std.heap.ArenaAllocator.init(mod.gpa);
    defer block_arena.deinit();

    var scope = parent_scope;
    for (statements) |statement| {
        const src = token_starts[tree.firstToken(statement)];
        _ = try addZIRNoOp(mod, scope, src, .dbg_stmt);
        switch (node_tags[statement]) {
            .global_var_decl => scope = try varDecl(mod, scope, &block_arena.allocator, tree.globalVarDecl(statement)),
            .local_var_decl => scope = try varDecl(mod, scope, &block_arena.allocator, tree.localVarDecl(statement)),
            .simple_var_decl => scope = try varDecl(mod, scope, &block_arena.allocator, tree.simpleVarDecl(statement)),
            .aligned_var_decl => scope = try varDecl(mod, scope, &block_arena.allocator, tree.alignedVarDecl(statement)),

            .assign => try assign(mod, scope, statement),
            .assign_bit_and => try assignOp(mod, scope, statement, .bit_and),
            .assign_bit_or => try assignOp(mod, scope, statement, .bit_or),
            .assign_bit_shift_left => try assignOp(mod, scope, statement, .shl),
            .assign_bit_shift_right => try assignOp(mod, scope, statement, .shr),
            .assign_bit_xor => try assignOp(mod, scope, statement, .xor),
            .assign_div => try assignOp(mod, scope, statement, .div),
            .assign_sub => try assignOp(mod, scope, statement, .sub),
            .assign_sub_wrap => try assignOp(mod, scope, statement, .subwrap),
            .assign_mod => try assignOp(mod, scope, statement, .mod_rem),
            .assign_add => try assignOp(mod, scope, statement, .add),
            .assign_add_wrap => try assignOp(mod, scope, statement, .addwrap),
            .assign_mul => try assignOp(mod, scope, statement, .mul),
            .assign_mul_wrap => try assignOp(mod, scope, statement, .mulwrap),

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
    block_arena: *Allocator,
    var_decl: ast.full.VarDecl,
) InnerError!*Scope {
    if (var_decl.comptime_token) |comptime_token| {
        return mod.failTok(scope, comptime_token, "TODO implement comptime locals", .{});
    }
    if (var_decl.ast.align_node != 0) {
        return mod.failNode(scope, var_decl.ast.align_node, "TODO implement alignment on locals", .{});
    }
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);

    const name_token = var_decl.ast.mut_token + 1;
    const name_src = token_starts[name_token];
    const ident_name = try mod.identifierTokenString(scope, name_token);

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
            .gen_zir => s = s.cast(Scope.GenZir).?.parent,
            .gen_suspend => s = s.cast(Scope.GenZir).?.parent,
            .gen_nosuspend => s = s.cast(Scope.Nosuspend).?.parent,
            else => break,
        };
    }

    // Namespace vars shadowing detection
    if (mod.lookupDeclName(scope, ident_name)) |_| {
        // TODO add note for other definition
        return mod.fail(scope, name_src, "redefinition of '{s}'", .{ident_name});
    }
    if (var_decl.ast.init_node == 0) {
        return mod.fail(scope, name_src, "variables must be initialized", .{});
    }

    switch (token_tags[var_decl.ast.mut_token]) {
        .keyword_const => {
            // Depending on the type of AST the initialization expression is, we may need an lvalue
            // or an rvalue as a result location. If it is an rvalue, we can use the instruction as
            // the variable, no memory location needed.
            if (!nodeMayNeedMemoryLocation(scope, var_decl.ast.init_node)) {
                const result_loc: ResultLoc = if (var_decl.ast.type_node != 0) .{
                    .ty = try typeExpr(mod, scope, var_decl.ast.type_node),
                } else .none;
                const init_inst = try expr(mod, scope, result_loc, var_decl.ast.init_node);
                const sub_scope = try block_arena.create(Scope.LocalVal);
                sub_scope.* = .{
                    .parent = scope,
                    .gen_zir = scope.getGenZir(),
                    .name = ident_name,
                    .inst = init_inst,
                };
                return &sub_scope.base;
            }

            // Detect whether the initialization expression actually uses the
            // result location pointer.
            var init_scope: Scope.GenZir = .{
                .parent = scope,
                .decl = scope.ownerDecl().?,
                .arena = scope.arena(),
                .force_comptime = scope.isComptime(),
                .instructions = .{},
            };
            defer init_scope.instructions.deinit(mod.gpa);

            var resolve_inferred_alloc: ?*zir.Inst = null;
            var opt_type_inst: ?*zir.Inst = null;
            if (var_decl.ast.type_node != 0) {
                const type_inst = try typeExpr(mod, &init_scope.base, var_decl.ast.type_node);
                opt_type_inst = type_inst;
                init_scope.rl_ptr = try addZIRUnOp(mod, &init_scope.base, name_src, .alloc, type_inst);
            } else {
                const alloc = try addZIRNoOpT(mod, &init_scope.base, name_src, .alloc_inferred);
                resolve_inferred_alloc = &alloc.base;
                init_scope.rl_ptr = &alloc.base;
            }
            const init_result_loc: ResultLoc = .{ .block_ptr = &init_scope };
            const init_inst = try expr(mod, &init_scope.base, init_result_loc, var_decl.ast.init_node);
            const parent_zir = &scope.getGenZir().instructions;
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
                    .gen_zir = scope.getGenZir(),
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
                .gen_zir = scope.getGenZir(),
                .name = ident_name,
                .ptr = init_scope.rl_ptr.?,
            };
            return &sub_scope.base;
        },
        .keyword_var => {
            var resolve_inferred_alloc: ?*zir.Inst = null;
            const var_data: struct {
                result_loc: ResultLoc,
                alloc: *zir.Inst,
            } = if (var_decl.ast.type_node != 0) a: {
                const type_inst = try typeExpr(mod, scope, var_decl.ast.type_node);
                const alloc = try addZIRUnOp(mod, scope, name_src, .alloc_mut, type_inst);
                break :a .{ .alloc = alloc, .result_loc = .{ .ptr = alloc } };
            } else a: {
                const alloc = try addZIRNoOpT(mod, scope, name_src, .alloc_inferred_mut);
                resolve_inferred_alloc = &alloc.base;
                break :a .{ .alloc = &alloc.base, .result_loc = .{ .inferred_ptr = alloc } };
            };
            const init_inst = try expr(mod, scope, var_data.result_loc, var_decl.ast.init_node);
            if (resolve_inferred_alloc) |inst| {
                _ = try addZIRUnOp(mod, scope, name_src, .resolve_inferred_alloc, inst);
            }
            const sub_scope = try block_arena.create(Scope.LocalPtr);
            sub_scope.* = .{
                .parent = scope,
                .gen_zir = scope.getGenZir(),
                .name = ident_name,
                .ptr = var_data.alloc,
            };
            return &sub_scope.base;
        },
        else => unreachable,
    }
}

fn assign(mod: *Module, scope: *Scope, infix_node: ast.Node.Index) InnerError!void {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);

    const lhs = node_datas[infix_node].lhs;
    const rhs = node_datas[infix_node].rhs;
    if (node_tags[lhs] == .identifier) {
        // This intentionally does not support `@"_"` syntax.
        const ident_name = tree.tokenSlice(main_tokens[lhs]);
        if (mem.eql(u8, ident_name, "_")) {
            _ = try expr(mod, scope, .discard, rhs);
            return;
        }
    }
    const lvalue = try lvalExpr(mod, scope, lhs);
    _ = try expr(mod, scope, .{ .ptr = lvalue }, rhs);
}

fn assignOp(
    mod: *Module,
    scope: *Scope,
    infix_node: ast.Node.Index,
    op_inst_tag: zir.Inst.Tag,
) InnerError!void {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const lhs_ptr = try lvalExpr(mod, scope, node_datas[infix_node].lhs);
    const lhs = try addZIRUnOp(mod, scope, lhs_ptr.src, .deref, lhs_ptr);
    const lhs_type = try addZIRUnOp(mod, scope, lhs_ptr.src, .typeof, lhs);
    const rhs = try expr(mod, scope, .{ .ty = lhs_type }, node_datas[infix_node].rhs);
    const src = token_starts[main_tokens[infix_node]];
    const result = try addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
    _ = try addZIRBinOp(mod, scope, src, .store, lhs_ptr, result);
}

fn boolNot(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const bool_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });
    const operand = try expr(mod, scope, .{ .ty = bool_type }, node_datas[node].lhs);
    return addZIRUnOp(mod, scope, src, .bool_not, operand);
}

fn bitNot(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const operand = try expr(mod, scope, .none, node_datas[node].lhs);
    return addZIRUnOp(mod, scope, src, .bit_not, operand);
}

fn negation(
    mod: *Module,
    scope: *Scope,
    node: ast.Node.Index,
    op_inst_tag: zir.Inst.Tag,
) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const lhs = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_int),
        .val = Value.initTag(.zero),
    });
    const rhs = try expr(mod, scope, .none, node_datas[node].lhs);
    return addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
}

fn ptrType(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    ptr_info: ast.full.PtrType,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[ptr_info.ast.main_token];

    const simple = ptr_info.allowzero_token == null and
        ptr_info.ast.align_node == 0 and
        ptr_info.volatile_token == null and
        ptr_info.ast.sentinel == 0;

    if (simple) {
        const child_type = try typeExpr(mod, scope, ptr_info.ast.child_type);
        const mutable = ptr_info.const_token == null;
        const T = zir.Inst.Tag;
        const result = try addZIRUnOp(mod, scope, src, switch (ptr_info.size) {
            .One => if (mutable) T.single_mut_ptr_type else T.single_const_ptr_type,
            .Many => if (mutable) T.many_mut_ptr_type else T.many_const_ptr_type,
            .C => if (mutable) T.c_mut_ptr_type else T.c_const_ptr_type,
            .Slice => if (mutable) T.mut_slice_type else T.const_slice_type,
        }, child_type);
        return rvalue(mod, scope, rl, result);
    }

    var kw_args: std.meta.fieldInfo(zir.Inst.PtrType, .kw_args).field_type = .{};
    kw_args.size = ptr_info.size;
    kw_args.@"allowzero" = ptr_info.allowzero_token != null;
    if (ptr_info.ast.align_node != 0) {
        kw_args.@"align" = try expr(mod, scope, .none, ptr_info.ast.align_node);
        if (ptr_info.ast.bit_range_start != 0) {
            kw_args.align_bit_start = try expr(mod, scope, .none, ptr_info.ast.bit_range_start);
            kw_args.align_bit_end = try expr(mod, scope, .none, ptr_info.ast.bit_range_end);
        }
    }
    kw_args.mutable = ptr_info.const_token == null;
    kw_args.@"volatile" = ptr_info.volatile_token != null;
    const child_type = try typeExpr(mod, scope, ptr_info.ast.child_type);
    if (ptr_info.ast.sentinel != 0) {
        kw_args.sentinel = try expr(mod, scope, .{ .ty = child_type }, ptr_info.ast.sentinel);
    }
    const result = try addZIRInst(mod, scope, src, zir.Inst.PtrType, .{ .child_type = child_type }, kw_args);
    return rvalue(mod, scope, rl, result);
}

fn arrayType(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[node]];
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });
    const len_node = node_datas[node].lhs;
    const elem_node = node_datas[node].rhs;
    if (len_node == 0) {
        const elem_type = try typeExpr(mod, scope, elem_node);
        const result = try addZIRUnOp(mod, scope, src, .mut_slice_type, elem_type);
        return rvalue(mod, scope, rl, result);
    } else {
        // TODO check for [_]T
        const len = try expr(mod, scope, .{ .ty = usize_type }, len_node);
        const elem_type = try typeExpr(mod, scope, elem_node);

        const result = try addZIRBinOp(mod, scope, src, .array_type, len, elem_type);
        return rvalue(mod, scope, rl, result);
    }
}

fn arrayTypeSentinel(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const node_datas = tree.nodes.items(.data);

    const len_node = node_datas[node].lhs;
    const extra = tree.extraData(node_datas[node].rhs, ast.Node.ArrayTypeSentinel);
    const src = token_starts[main_tokens[node]];
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });

    // TODO check for [_]T
    const len = try expr(mod, scope, .{ .ty = usize_type }, len_node);
    const sentinel_uncasted = try expr(mod, scope, .none, extra.sentinel);
    const elem_type = try typeExpr(mod, scope, extra.elem_type);
    const sentinel = try addZIRBinOp(mod, scope, src, .as, elem_type, sentinel_uncasted);

    const result = try addZIRInst(mod, scope, src, zir.Inst.ArrayTypeSentinel, .{
        .len = len,
        .sentinel = sentinel,
        .elem_type = elem_type,
    }, .{});
    return rvalue(mod, scope, rl, result);
}

fn containerDecl(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    container_decl: ast.full.ContainerDecl,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    return mod.failTok(scope, container_decl.ast.main_token, "TODO implement container decls", .{});
}

fn errorSetDecl(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);

    // Count how many fields there are.
    const error_token = main_tokens[node];
    const count: usize = count: {
        var tok_i = error_token + 2;
        var count: usize = 0;
        while (true) : (tok_i += 1) {
            switch (token_tags[tok_i]) {
                .doc_comment, .comma => {},
                .identifier => count += 1,
                .r_brace => break :count count,
                else => unreachable,
            }
        } else unreachable; // TODO should not need else unreachable here
    };

    const fields = try scope.arena().alloc([]const u8, count);
    {
        var tok_i = error_token + 2;
        var field_i: usize = 0;
        while (true) : (tok_i += 1) {
            switch (token_tags[tok_i]) {
                .doc_comment, .comma => {},
                .identifier => {
                    fields[field_i] = try mod.identifierTokenString(scope, tok_i);
                    field_i += 1;
                },
                .r_brace => break,
                else => unreachable,
            }
        }
    }
    const src = token_starts[error_token];
    const result = try addZIRInst(mod, scope, src, zir.Inst.ErrorSet, .{ .fields = fields }, .{});
    return rvalue(mod, scope, rl, result);
}

fn orelseCatchExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    lhs: ast.Node.Index,
    op_token: ast.TokenIndex,
    cond_op: zir.Inst.Tag,
    unwrap_op: zir.Inst.Tag,
    unwrap_code_op: zir.Inst.Tag,
    rhs: ast.Node.Index,
    payload_token: ?ast.TokenIndex,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");

    const tree = scope.tree();
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[op_token];

    var block_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);

    // This could be a pointer or value depending on the `operand_rl` parameter.
    // We cannot use `block_scope.break_result_loc` because that has the bare
    // type, whereas this expression has the optional type. Later we make
    // up for this fact by calling rvalue on the else branch.
    block_scope.break_count += 1;
    const operand_rl = try makeOptionalTypeResultLoc(mod, &block_scope.base, src, block_scope.break_result_loc);
    const operand = try expr(mod, &block_scope.base, operand_rl, lhs);
    const cond = try addZIRUnOp(mod, &block_scope.base, src, cond_op, operand);

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, src, .block, .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, block_scope.instructions.items),
    });

    var then_scope: Scope.GenZir = .{
        .parent = &block_scope.base,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    var err_val_scope: Scope.LocalVal = undefined;
    const then_sub_scope = blk: {
        const payload = payload_token orelse break :blk &then_scope.base;
        if (mem.eql(u8, tree.tokenSlice(payload), "_")) {
            return mod.failTok(&then_scope.base, payload, "discard of error capture; omit it instead", .{});
        }
        const err_name = try mod.identifierTokenString(scope, payload);
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

    var else_scope: Scope.GenZir = .{
        .parent = &block_scope.base,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    // This could be a pointer or value depending on `unwrap_op`.
    const unwrapped_payload = try addZIRUnOp(mod, &else_scope.base, src, unwrap_op, operand);
    const else_result = switch (rl) {
        .ref => unwrapped_payload,
        else => try rvalue(mod, &else_scope.base, block_scope.break_result_loc, unwrapped_payload),
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
        src,
        src,
        then_result,
        else_result,
        block,
        block,
    );
}

fn finishThenElseBlock(
    mod: *Module,
    parent_scope: *Scope,
    rl: ResultLoc,
    block_scope: *Scope.GenZir,
    then_scope: *Scope.GenZir,
    else_scope: *Scope.GenZir,
    then_body: *zir.Body,
    else_body: *zir.Body,
    then_src: usize,
    else_src: usize,
    then_result: zir.Inst.Ref,
    else_result: ?*zir.Inst,
    main_block: zir.Inst.Ref.Block,
    then_break_block: zir.Inst.Ref.Block,
) InnerError!zir.Inst.Ref {
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

pub fn fieldAccess(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const token_starts = tree.tokens.items(.start);
    const main_tokens = tree.nodes.items(.main_token);
    const node_datas = tree.nodes.items(.data);

    const dot_token = main_tokens[node];
    const src = token_starts[dot_token];
    const field_ident = dot_token + 1;
    const field_name = try mod.identifierTokenString(scope, field_ident);
    if (rl == .ref) {
        return addZirInstTag(mod, scope, src, .field_ptr, .{
            .object = try expr(mod, scope, .ref, node_datas[node].lhs),
            .field_name = field_name,
        });
    } else {
        return rvalue(mod, scope, rl, try addZirInstTag(mod, scope, src, .field_val, .{
            .object = try expr(mod, scope, .none, node_datas[node].lhs),
            .field_name = field_name,
        }));
    }
}

fn arrayAccess(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const node_datas = tree.nodes.items(.data);

    const src = token_starts[main_tokens[node]];
    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });
    const index_rl: ResultLoc = .{ .ty = usize_type };
    switch (rl) {
        .ref => return addZirInstTag(mod, scope, src, .elem_ptr, .{
            .array = try expr(mod, scope, .ref, node_datas[node].lhs),
            .index = try expr(mod, scope, index_rl, node_datas[node].rhs),
        }),
        else => return rvalue(mod, scope, rl, try addZirInstTag(mod, scope, src, .elem_val, .{
            .array = try expr(mod, scope, .none, node_datas[node].lhs),
            .index = try expr(mod, scope, index_rl, node_datas[node].rhs),
        })),
    }
}

fn sliceExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    slice: ast.full.Slice,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[slice.ast.lbracket];

    const usize_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    });

    const array_ptr = try expr(mod, scope, .ref, slice.ast.sliced);
    const start = try expr(mod, scope, .{ .ty = usize_type }, slice.ast.start);

    if (slice.ast.sentinel == 0) {
        if (slice.ast.end == 0) {
            const result = try addZIRBinOp(mod, scope, src, .slice_start, array_ptr, start);
            return rvalue(mod, scope, rl, result);
        } else {
            const end = try expr(mod, scope, .{ .ty = usize_type }, slice.ast.end);
            // TODO a ZIR slice_open instruction
            const result = try addZIRInst(mod, scope, src, zir.Inst.Slice, .{
                .array_ptr = array_ptr,
                .start = start,
            }, .{ .end = end });
            return rvalue(mod, scope, rl, result);
        }
    }

    const end = try expr(mod, scope, .{ .ty = usize_type }, slice.ast.end);
    // TODO pass the proper result loc to this expression using a ZIR instruction
    // "get the child element type for a slice target".
    const sentinel = try expr(mod, scope, .none, slice.ast.sentinel);
    const result = try addZIRInst(mod, scope, src, zir.Inst.Slice, .{
        .array_ptr = array_ptr,
        .start = start,
    }, .{
        .end = end,
        .sentinel = sentinel,
    });
    return rvalue(mod, scope, rl, result);
}

fn simpleBinOp(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    infix_node: ast.Node.Index,
    op_inst_tag: zir.Inst.Tag,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const lhs = try expr(mod, scope, .none, node_datas[infix_node].lhs);
    const rhs = try expr(mod, scope, .none, node_datas[infix_node].rhs);
    const src = token_starts[main_tokens[infix_node]];
    const result = try addZIRBinOp(mod, scope, src, op_inst_tag, lhs, rhs);
    return rvalue(mod, scope, rl, result);
}

fn boolBinOp(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    infix_node: ast.Node.Index,
    is_bool_and: bool,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_tokens[infix_node]];
    const bool_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    });

    var block_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    defer block_scope.instructions.deinit(mod.gpa);

    const lhs = try expr(mod, scope, .{ .ty = bool_type }, node_datas[infix_node].lhs);
    const condbr = try addZIRInstSpecial(mod, &block_scope.base, src, zir.Inst.CondBr, .{
        .condition = lhs,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, src, .block, .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, block_scope.instructions.items),
    });

    var rhs_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer rhs_scope.instructions.deinit(mod.gpa);

    const rhs = try expr(mod, &rhs_scope.base, .{ .ty = bool_type }, node_datas[infix_node].rhs);
    _ = try addZIRInst(mod, &rhs_scope.base, src, zir.Inst.Break, .{
        .block = block,
        .operand = rhs,
    }, .{});

    var const_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer const_scope.instructions.deinit(mod.gpa);

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
        condbr.positionals.then_body = .{ .instructions = try rhs_scope.arena.dupe(zir.Inst.Ref, rhs_scope.instructions.items) };
        condbr.positionals.else_body = .{ .instructions = try const_scope.arena.dupe(zir.Inst.Ref, const_scope.instructions.items) };
    } else {
        // if lhs // OR
        //     break true
        // else
        //     break rhs
        condbr.positionals.then_body = .{ .instructions = try const_scope.arena.dupe(zir.Inst.Ref, const_scope.instructions.items) };
        condbr.positionals.else_body = .{ .instructions = try rhs_scope.arena.dupe(zir.Inst.Ref, rhs_scope.instructions.items) };
    }

    return rvalue(mod, scope, rl, &block.base);
}

fn ifExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    if_full: ast.full.If,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    var block_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);

    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const if_src = token_starts[if_full.ast.if_token];

    const cond = c: {
        // TODO https://github.com/ziglang/zig/issues/7929
        if (if_full.error_token) |error_token| {
            return mod.failTok(scope, error_token, "TODO implement if error union", .{});
        } else if (if_full.payload_token) |payload_token| {
            return mod.failTok(scope, payload_token, "TODO implement if optional", .{});
        } else {
            const bool_type = try addZIRInstConst(mod, &block_scope.base, if_src, .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.bool_type),
            });
            break :c try expr(mod, &block_scope.base, .{ .ty = bool_type }, if_full.ast.cond_expr);
        }
    };

    const condbr = try addZIRInstSpecial(mod, &block_scope.base, if_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});

    const block = try addZIRInstBlock(mod, scope, if_src, .block, .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, block_scope.instructions.items),
    });

    const then_src = token_starts[tree.lastToken(if_full.ast.then_expr)];
    var then_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    // declare payload to the then_scope
    const then_sub_scope = &then_scope.base;

    block_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, block_scope.break_result_loc, if_full.ast.then_expr);
    // We hold off on the break instructions as well as copying the then/else
    // instructions into place until we know whether to keep store_to_block_ptr
    // instructions or not.

    var else_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    const else_node = if_full.ast.else_expr;
    const else_info: struct { src: usize, result: ?*zir.Inst } = if (else_node != 0) blk: {
        block_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = token_starts[tree.lastToken(else_node)],
            .result = try expr(mod, sub_scope, block_scope.break_result_loc, else_node),
        };
    } else .{
        .src = token_starts[tree.lastToken(if_full.ast.then_expr)],
        .result = null,
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
        else_info.src,
        then_result,
        else_info.result,
        block,
        block,
    );
}

/// Expects to find exactly 1 .store_to_block_ptr instruction.
fn copyBodyWithElidedStoreBlockPtr(body: *zir.Body, scope: Module.Scope.GenZir) !void {
    body.* = .{
        .instructions = try scope.arena.alloc(zir.Inst.Ref, scope.instructions.items.len - 1),
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

fn copyBodyNoEliding(body: *zir.Body, scope: Module.Scope.GenZir) !void {
    body.* = .{
        .instructions = try scope.arena.dupe(zir.Inst.Ref, scope.instructions.items),
    };
}

fn whileExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    while_full: ast.full.While,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    if (while_full.label_token) |label_token| {
        try checkLabelRedefinition(mod, scope, label_token);
    }
    if (while_full.inline_token) |inline_token| {
        return mod.failTok(scope, inline_token, "TODO inline while", .{});
    }

    var loop_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&loop_scope, rl);
    defer loop_scope.instructions.deinit(mod.gpa);

    var continue_scope: Scope.GenZir = .{
        .parent = &loop_scope.base,
        .decl = loop_scope.decl,
        .arena = loop_scope.arena,
        .force_comptime = loop_scope.force_comptime,
        .instructions = .{},
    };
    defer continue_scope.instructions.deinit(mod.gpa);

    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const while_src = token_starts[while_full.ast.while_token];
    const void_type = try addZIRInstConst(mod, scope, while_src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const cond = c: {
        // TODO https://github.com/ziglang/zig/issues/7929
        if (while_full.error_token) |error_token| {
            return mod.failTok(scope, error_token, "TODO implement while error union", .{});
        } else if (while_full.payload_token) |payload_token| {
            return mod.failTok(scope, payload_token, "TODO implement while optional", .{});
        } else {
            const bool_type = try addZIRInstConst(mod, &continue_scope.base, while_src, .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.bool_type),
            });
            break :c try expr(mod, &continue_scope.base, .{ .ty = bool_type }, while_full.ast.cond_expr);
        }
    };

    const condbr = try addZIRInstSpecial(mod, &continue_scope.base, while_src, zir.Inst.CondBr, .{
        .condition = cond,
        .then_body = undefined, // populated below
        .else_body = undefined, // populated below
    }, .{});
    const cond_block = try addZIRInstBlock(mod, &loop_scope.base, while_src, .block, .{
        .instructions = try loop_scope.arena.dupe(zir.Inst.Ref, continue_scope.instructions.items),
    });
    // TODO avoid emitting the continue expr when there
    // are no jumps to it. This happens when the last statement of a while body is noreturn
    // and there are no `continue` statements.
    // The "repeat" at the end of a loop body is implied.
    if (while_full.ast.cont_expr != 0) {
        _ = try expr(mod, &loop_scope.base, .{ .ty = void_type }, while_full.ast.cont_expr);
    }
    const loop = try scope.arena().create(zir.Inst.Loop);
    loop.* = .{
        .base = .{
            .tag = .loop,
            .src = while_src,
        },
        .positionals = .{
            .body = .{
                .instructions = try scope.arena().dupe(zir.Inst.Ref, loop_scope.instructions.items),
            },
        },
        .kw_args = .{},
    };
    const while_block = try addZIRInstBlock(mod, scope, while_src, .block, .{
        .instructions = try scope.arena().dupe(zir.Inst.Ref, &[1]zir.Inst.Ref{&loop.base}),
    });
    loop_scope.break_block = while_block;
    loop_scope.continue_block = cond_block;
    if (while_full.label_token) |label_token| {
        loop_scope.label = @as(?Scope.GenZir.Label, Scope.GenZir.Label{
            .token = label_token,
            .block_inst = while_block,
        });
    }

    const then_src = token_starts[tree.lastToken(while_full.ast.then_expr)];
    var then_scope: Scope.GenZir = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    const then_sub_scope = &then_scope.base;

    loop_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, loop_scope.break_result_loc, while_full.ast.then_expr);

    var else_scope: Scope.GenZir = .{
        .parent = &continue_scope.base,
        .decl = continue_scope.decl,
        .arena = continue_scope.arena,
        .force_comptime = continue_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    const else_node = while_full.ast.else_expr;
    const else_info: struct { src: usize, result: ?*zir.Inst } = if (else_node != 0) blk: {
        loop_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = token_starts[tree.lastToken(else_node)],
            .result = try expr(mod, sub_scope, loop_scope.break_result_loc, else_node),
        };
    } else .{
        .src = token_starts[tree.lastToken(while_full.ast.then_expr)],
        .result = null,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            return mod.fail(scope, token_starts[some.token], "unused while loop label", .{});
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
        else_info.src,
        then_result,
        else_info.result,
        while_block,
        cond_block,
    );
}

fn forExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    for_full: ast.full.While,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    if (for_full.label_token) |label_token| {
        try checkLabelRedefinition(mod, scope, label_token);
    }

    if (for_full.inline_token) |inline_token| {
        return mod.failTok(scope, inline_token, "TODO inline for", .{});
    }

    // Set up variables and constants.
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);

    const for_src = token_starts[for_full.ast.while_token];
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
    const array_ptr = try expr(mod, scope, .ref, for_full.ast.cond_expr);
    const cond_src = token_starts[tree.firstToken(for_full.ast.cond_expr)];
    const len = try addZIRUnOp(mod, scope, cond_src, .indexable_ptr_len, array_ptr);

    var loop_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&loop_scope, rl);
    defer loop_scope.instructions.deinit(mod.gpa);

    var cond_scope: Scope.GenZir = .{
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
        .instructions = try loop_scope.arena.dupe(zir.Inst.Ref, cond_scope.instructions.items),
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
                .instructions = try scope.arena().dupe(zir.Inst.Ref, loop_scope.instructions.items),
            },
        },
        .kw_args = .{},
    };
    const for_block = try addZIRInstBlock(mod, scope, for_src, .block, .{
        .instructions = try scope.arena().dupe(zir.Inst.Ref, &[1]zir.Inst.Ref{&loop.base}),
    });
    loop_scope.break_block = for_block;
    loop_scope.continue_block = cond_block;
    if (for_full.label_token) |label_token| {
        loop_scope.label = @as(?Scope.GenZir.Label, Scope.GenZir.Label{
            .token = label_token,
            .block_inst = for_block,
        });
    }

    // while body
    const then_src = token_starts[tree.lastToken(for_full.ast.then_expr)];
    var then_scope: Scope.GenZir = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer then_scope.instructions.deinit(mod.gpa);

    var index_scope: Scope.LocalPtr = undefined;
    const then_sub_scope = blk: {
        const payload_token = for_full.payload_token.?;
        const ident = if (token_tags[payload_token] == .asterisk)
            payload_token + 1
        else
            payload_token;
        const is_ptr = ident != payload_token;
        const value_name = tree.tokenSlice(ident);
        if (!mem.eql(u8, value_name, "_")) {
            return mod.failNode(&then_scope.base, ident, "TODO implement for loop value payload", .{});
        } else if (is_ptr) {
            return mod.failTok(&then_scope.base, payload_token, "pointer modifier invalid on discard", .{});
        }

        const index_token = if (token_tags[ident + 1] == .comma)
            ident + 2
        else
            break :blk &then_scope.base;
        if (mem.eql(u8, tree.tokenSlice(index_token), "_")) {
            return mod.failTok(&then_scope.base, index_token, "discard of index capture; omit it instead", .{});
        }
        const index_name = try mod.identifierTokenString(&then_scope.base, index_token);
        index_scope = .{
            .parent = &then_scope.base,
            .gen_zir = &then_scope,
            .name = index_name,
            .ptr = index_ptr,
        };
        break :blk &index_scope.base;
    };

    loop_scope.break_count += 1;
    const then_result = try expr(mod, then_sub_scope, loop_scope.break_result_loc, for_full.ast.then_expr);

    // else branch
    var else_scope: Scope.GenZir = .{
        .parent = &cond_scope.base,
        .decl = cond_scope.decl,
        .arena = cond_scope.arena,
        .force_comptime = cond_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    const else_node = for_full.ast.else_expr;
    const else_info: struct { src: usize, result: ?*zir.Inst } = if (else_node != 0) blk: {
        loop_scope.break_count += 1;
        const sub_scope = &else_scope.base;
        break :blk .{
            .src = token_starts[tree.lastToken(else_node)],
            .result = try expr(mod, sub_scope, loop_scope.break_result_loc, else_node),
        };
    } else .{
        .src = token_starts[tree.lastToken(for_full.ast.then_expr)],
        .result = null,
    };

    if (loop_scope.label) |some| {
        if (!some.used) {
            return mod.fail(scope, token_starts[some.token], "unused for loop label", .{});
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
        else_info.src,
        then_result,
        else_info.result,
        for_block,
        cond_block,
    );
}

fn getRangeNode(
    node_tags: []const ast.Node.Tag,
    node_datas: []const ast.Node.Data,
    start_node: ast.Node.Index,
) ?ast.Node.Index {
    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            .switch_range => return node,
            .grouped_expression => node = node_datas[node].lhs,
            else => return null,
        }
    }
}

fn switchExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    switch_node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);
    const node_tags = tree.nodes.items(.tag);

    const switch_token = main_tokens[switch_node];
    const target_node = node_datas[switch_node].lhs;
    const extra = tree.extraData(node_datas[switch_node].rhs, ast.Node.SubRange);
    const case_nodes = tree.extra_data[extra.start..extra.end];

    const switch_src = token_starts[switch_token];

    var block_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    setBlockResultLoc(&block_scope, rl);
    defer block_scope.instructions.deinit(mod.gpa);

    var items = std.ArrayList(zir.Inst.Ref).init(mod.gpa);
    defer items.deinit();

    // First we gather all the switch items and check else/'_' prongs.
    var else_src: ?usize = null;
    var underscore_src: ?usize = null;
    var first_range: ?*zir.Inst = null;
    var simple_case_count: usize = 0;
    var any_payload_is_ref = false;
    for (case_nodes) |case_node| {
        const case = switch (node_tags[case_node]) {
            .switch_case_one => tree.switchCaseOne(case_node),
            .switch_case => tree.switchCase(case_node),
            else => unreachable,
        };
        if (case.payload_token) |payload_token| {
            if (token_tags[payload_token] == .asterisk) {
                any_payload_is_ref = true;
            }
        }
        // Check for else/_ prong, those are handled last.
        if (case.ast.values.len == 0) {
            const case_src = token_starts[case.ast.arrow_token - 1];
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
        } else if (case.ast.values.len == 1 and
            node_tags[case.ast.values[0]] == .identifier and
            mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
        {
            const case_src = token_starts[case.ast.arrow_token - 1];
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

        if (case.ast.values.len == 1 and
            getRangeNode(node_tags, node_datas, case.ast.values[0]) == null)
        {
            simple_case_count += 1;
        }

        // Generate all the switch items as comptime expressions.
        for (case.ast.values) |item| {
            if (getRangeNode(node_tags, node_datas, item)) |range| {
                const start = try comptimeExpr(mod, &block_scope.base, .none, node_datas[range].lhs);
                const end = try comptimeExpr(mod, &block_scope.base, .none, node_datas[range].rhs);
                const range_src = token_starts[main_tokens[range]];
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

    const rl_and_tag: struct { rl: ResultLoc, tag: zir.Inst.Tag } = if (any_payload_is_ref) .{
        .rl = .ref,
        .tag = .switchbr_ref,
    } else .{
        .rl = .none,
        .tag = .switchbr,
    };
    const target = try expr(mod, &block_scope.base, rl_and_tag.rl, target_node);
    const switch_inst = try addZirInstT(mod, &block_scope.base, switch_src, zir.Inst.SwitchBr, rl_and_tag.tag, .{
        .target = target,
        .cases = cases,
        .items = try block_scope.arena.dupe(zir.Inst.Ref, items.items),
        .else_body = undefined, // populated below
        .range = first_range,
        .special_prong = special_prong,
    });
    const block = try addZIRInstBlock(mod, scope, switch_src, .block, .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, block_scope.instructions.items),
    });

    var case_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = block_scope.decl,
        .arena = block_scope.arena,
        .force_comptime = block_scope.force_comptime,
        .instructions = .{},
    };
    defer case_scope.instructions.deinit(mod.gpa);

    var else_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = case_scope.decl,
        .arena = case_scope.arena,
        .force_comptime = case_scope.force_comptime,
        .instructions = .{},
    };
    defer else_scope.instructions.deinit(mod.gpa);

    // Now generate all but the special cases.
    var special_case: ?ast.full.SwitchCase = null;
    var items_index: usize = 0;
    var case_index: usize = 0;
    for (case_nodes) |case_node| {
        const case = switch (node_tags[case_node]) {
            .switch_case_one => tree.switchCaseOne(case_node),
            .switch_case => tree.switchCase(case_node),
            else => unreachable,
        };
        const case_src = token_starts[main_tokens[case_node]];
        case_scope.instructions.shrinkRetainingCapacity(0);

        // Check for else/_ prong, those are handled last.
        if (case.ast.values.len == 0) {
            special_case = case;
            continue;
        } else if (case.ast.values.len == 1 and
            node_tags[case.ast.values[0]] == .identifier and
            mem.eql(u8, tree.tokenSlice(main_tokens[case.ast.values[0]]), "_"))
        {
            special_case = case;
            continue;
        }

        // If this is a simple one item prong then it is handled by the switchbr.
        if (case.ast.values.len == 1 and
            getRangeNode(node_tags, node_datas, case.ast.values[0]) == null)
        {
            const item = items.items[items_index];
            items_index += 1;
            try switchCaseExpr(mod, &case_scope.base, block_scope.break_result_loc, block, case, target);

            cases[case_index] = .{
                .item = item,
                .body = .{ .instructions = try scope.arena().dupe(zir.Inst.Ref, case_scope.instructions.items) },
            };
            case_index += 1;
            continue;
        }

        // Check if the target matches any of the items.
        // 1, 2, 3..6 will result in
        // target == 1 or target == 2 or (target >= 3 and target <= 6)
        // TODO handle multiple items as switch prongs rather than along with ranges.
        var any_ok: ?*zir.Inst = null;
        for (case.ast.values) |item| {
            if (getRangeNode(node_tags, node_datas, item)) |range| {
                const range_src = token_starts[main_tokens[range]];
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
            .instructions = try scope.arena().dupe(zir.Inst.Ref, case_scope.instructions.items),
        });

        // reset cond_scope for then_body
        case_scope.instructions.items.len = 0;
        try switchCaseExpr(mod, &case_scope.base, block_scope.break_result_loc, block, case, target);
        condbr.positionals.then_body = .{
            .instructions = try scope.arena().dupe(zir.Inst.Ref, case_scope.instructions.items),
        };

        // reset cond_scope for else_body
        case_scope.instructions.items.len = 0;
        _ = try addZIRInst(mod, &case_scope.base, case_src, zir.Inst.BreakVoid, .{
            .block = cond_block,
        }, .{});
        condbr.positionals.else_body = .{
            .instructions = try scope.arena().dupe(zir.Inst.Ref, case_scope.instructions.items),
        };
    }

    // Finally generate else block or a break.
    if (special_case) |case| {
        try switchCaseExpr(mod, &else_scope.base, block_scope.break_result_loc, block, case, target);
    } else {
        // Not handling all possible cases is a compile error.
        _ = try addZIRNoOp(mod, &else_scope.base, switch_src, .unreachable_unsafe);
    }
    switch_inst.positionals.else_body = .{
        .instructions = try block_scope.arena.dupe(zir.Inst.Ref, else_scope.instructions.items),
    };

    return &block.base;
}

fn switchCaseExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    block: *zir.Inst.Block,
    case: ast.full.SwitchCase,
    target: zir.Inst.Ref,
) !void {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const token_tags = tree.tokens.items(.tag);

    const case_src = token_starts[case.ast.arrow_token];
    const sub_scope = blk: {
        const payload_token = case.payload_token orelse break :blk scope;
        const ident = if (token_tags[payload_token] == .asterisk)
            payload_token + 1
        else
            payload_token;
        const is_ptr = ident != payload_token;
        const value_name = tree.tokenSlice(ident);
        if (mem.eql(u8, value_name, "_")) {
            if (is_ptr) {
                return mod.failTok(scope, payload_token, "pointer modifier invalid on discard", .{});
            }
            break :blk scope;
        }
        return mod.failTok(scope, ident, "TODO implement switch value payload", .{});
    };

    const case_body = try expr(mod, sub_scope, rl, case.ast.target_expr);
    if (!case_body.tag.isNoReturn()) {
        _ = try addZIRInst(mod, sub_scope, case_src, zir.Inst.Break, .{
            .block = block,
            .operand = case_body,
        }, .{});
    }
}

fn ret(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);

    const operand_node = node_datas[node].lhs;
    const gz = scope.getGenZir();
    const operand: zir.Inst.Ref = if (operand_node != 0) operand: {
        const rl: ResultLoc = if (nodeMayNeedMemoryLocation(scope, operand_node)) .{
            .ptr = try gz.addNode(.ret_ptr, node),
        } else .{
            .ty = try gz.addNode(.ret_type, node),
        };
        break :operand try expr(mod, scope, rl, operand_node);
    } else void_inst;
    return gz.addUnNode(.ret_node, operand, node);
}

fn identifier(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    ident: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tracy = trace(@src());
    defer tracy.end();

    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const ident_token = main_tokens[ident];
    const ident_name = try mod.identifierTokenString(scope, ident_token);
    const src = token_starts[ident_token];
    if (mem.eql(u8, ident_name, "_")) {
        return mod.failNode(scope, ident, "TODO implement '_' identifier", .{});
    }

    if (simple_types.get(ident_name)) |zir_const_tag| {
        return rvalue(mod, scope, rl, @enumToInt(zir_const_tag));
    }

    if (ident_name.len >= 2) integer: {
        const first_c = ident_name[0];
        if (first_c == 'i' or first_c == 'u') {
            const is_signed = first_c == 'i';
            const bit_count = std.fmt.parseInt(u16, ident_name[1..], 10) catch |err| switch (err) {
                error.Overflow => return mod.failNode(
                    scope,
                    ident,
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
            .gen_zir => s = s.cast(Scope.GenZir).?.parent,
            .gen_suspend => s = s.cast(Scope.GenZir).?.parent,
            .gen_nosuspend => s = s.cast(Scope.Nosuspend).?.parent,
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

    return mod.failNode(scope, ident, "use of undeclared identifier '{s}'", .{ident_name});
}

fn parseStringLiteral(mod: *Module, scope: *Scope, token: ast.TokenIndex) ![]u8 {
    const tree = scope.tree();
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);
    assert(token_tags[token] == .string_literal);
    const unparsed = tree.tokenSlice(token);
    const arena = scope.arena();
    var bad_index: usize = undefined;
    const bytes = std.zig.parseStringLiteral(arena, unparsed, &bad_index) catch |err| switch (err) {
        error.InvalidCharacter => {
            const bad_byte = unparsed[bad_index];
            const src = token_starts[token];
            return mod.fail(scope, src + bad_index, "invalid string literal character: '{c}'", .{
                bad_byte,
            });
        },
        else => |e| return e,
    };
    return bytes;
}

fn stringLiteral(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    str_lit: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const str_lit_token = main_tokens[str_lit];
    const bytes = try parseStringLiteral(mod, scope, str_lit_token);
    const src = token_starts[str_lit_token];
    const str_inst = try addZIRInst(mod, scope, src, zir.Inst.Str, .{ .bytes = bytes }, .{});
    return rvalue(mod, scope, rl, str_inst);
}

fn multilineStringLiteral(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    str_lit: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const start = node_datas[str_lit].lhs;
    const end = node_datas[str_lit].rhs;

    // Count the number of bytes to allocate.
    const len: usize = len: {
        var tok_i = start;
        var len: usize = end - start + 1;
        while (tok_i <= end) : (tok_i += 1) {
            // 2 for the '//' + 1 for '\n'
            len += tree.tokenSlice(tok_i).len - 3;
        }
        break :len len;
    };
    const bytes = try scope.arena().alloc(u8, len);
    // First line: do not append a newline.
    var byte_i: usize = 0;
    var tok_i = start;
    {
        const slice = tree.tokenSlice(tok_i);
        const line_bytes = slice[2 .. slice.len - 1];
        mem.copy(u8, bytes[byte_i..], line_bytes);
        byte_i += line_bytes.len;
        tok_i += 1;
    }
    // Following lines: each line prepends a newline.
    while (tok_i <= end) : (tok_i += 1) {
        bytes[byte_i] = '\n';
        byte_i += 1;
        const slice = tree.tokenSlice(tok_i);
        const line_bytes = slice[2 .. slice.len - 1];
        mem.copy(u8, bytes[byte_i..], line_bytes);
        byte_i += line_bytes.len;
    }
    const src = token_starts[start];
    const str_inst = try addZIRInst(mod, scope, src, zir.Inst.Str, .{ .bytes = bytes }, .{});
    return rvalue(mod, scope, rl, str_inst);
}

fn charLiteral(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) !zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const main_token = main_tokens[node];
    const token_starts = tree.tokens.items(.start);

    const src = token_starts[main_token];
    const slice = tree.tokenSlice(main_token);

    var bad_index: usize = undefined;
    const value = std.zig.parseCharLiteral(slice, &bad_index) catch |err| switch (err) {
        error.InvalidCharacter => {
            const bad_byte = slice[bad_index];
            return mod.fail(scope, src + bad_index, "invalid character: '{c}'\n", .{bad_byte});
        },
    };
    const result = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_int),
        .val = try Value.Tag.int_u64.create(scope.arena(), value),
    });
    return rvalue(mod, scope, rl, result);
}

fn integerLiteral(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const int_token = main_tokens[node];
    const prefixed_bytes = tree.tokenSlice(int_token);
    const gz = scope.getGenZir();
    if (std.fmt.parseInt(u64, prefixed_bytes, 0)) |small_int| {
        const result: zir.Inst.Index = switch (small_int) {
            0 => @enumToInt(zir.Const.zero),
            1 => @enumToInt(zir.Const.one),
            else => try gz.addInt(small_int),
        };
        return rvalue(mod, scope, rl, result, node);
    } else |err| {
        return mod.failNode(scope, node, "TODO implement int literals that don't fit in a u64", .{});
    }
}

fn floatLiteral(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    float_lit: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const arena = scope.arena();
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const main_token = main_tokens[float_lit];
    const bytes = tree.tokenSlice(main_token);
    if (bytes.len > 2 and bytes[1] == 'x') {
        return mod.failTok(scope, main_token, "TODO implement hex floats", .{});
    }
    const float_number = std.fmt.parseFloat(f128, bytes) catch |e| switch (e) {
        error.InvalidCharacter => unreachable, // validated by tokenizer
    };
    const src = token_starts[main_token];
    const result = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.comptime_float),
        .val = try Value.Tag.float_128.create(arena, float_number),
    });
    return rvalue(mod, scope, rl, result);
}

fn asmExpr(mod: *Module, scope: *Scope, rl: ResultLoc, full: ast.full.Asm) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const arena = scope.arena();
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    const node_datas = tree.nodes.items(.data);

    if (full.outputs.len != 0) {
        return mod.failTok(scope, full.ast.asm_token, "TODO implement asm with an output", .{});
    }

    const inputs = try arena.alloc([]const u8, full.inputs.len);
    const args = try arena.alloc(zir.Inst.Ref, full.inputs.len);

    const src = token_starts[full.ast.asm_token];
    const str_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.const_slice_u8_type),
    });
    const str_type_rl: ResultLoc = .{ .ty = str_type };

    for (full.inputs) |input, i| {
        // TODO semantically analyze constraints
        const constraint_token = main_tokens[input] + 2;
        inputs[i] = try parseStringLiteral(mod, scope, constraint_token);
        args[i] = try expr(mod, scope, .none, node_datas[input].lhs);
    }

    const return_type = try addZIRInstConst(mod, scope, src, .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    });
    const asm_inst = try addZIRInst(mod, scope, src, zir.Inst.Asm, .{
        .asm_source = try expr(mod, scope, str_type_rl, full.ast.template),
        .return_type = return_type,
    }, .{
        .@"volatile" = full.volatile_token != null,
        //.clobbers =  TODO handle clobbers
        .inputs = inputs,
        .args = args,
    });
    return rvalue(mod, scope, rl, asm_inst);
}

fn as(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    builtin_token: ast.TokenIndex,
    src: usize,
    lhs: ast.Node.Index,
    rhs: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    const dest_type = try typeExpr(mod, scope, lhs);
    switch (rl) {
        .none, .discard, .ref, .ty => {
            const result = try expr(mod, scope, .{ .ty = dest_type }, rhs);
            return rvalue(mod, scope, rl, result);
        },

        .ptr => |result_ptr| {
            return asRlPtr(mod, scope, rl, src, result_ptr, rhs, dest_type);
        },
        .block_ptr => |block_scope| {
            return asRlPtr(mod, scope, rl, src, block_scope.rl_ptr.?, rhs, dest_type);
        },

        .bitcasted_ptr => |bitcasted_ptr| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, builtin_token, "TODO implement @as with result location @bitCast", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, builtin_token, "TODO implement @as with inferred-type result location pointer", .{});
        },
    }
}

fn asRlPtr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    src: usize,
    result_ptr: zir.Inst.Ref,
    operand_node: ast.Node.Index,
    dest_type: zir.Inst.Ref,
) InnerError!zir.Inst.Ref {
    // Detect whether this expr() call goes into rvalue() to store the result into the
    // result location. If it does, elide the coerce_result_ptr instruction
    // as well as the store instruction, instead passing the result as an rvalue.
    var as_scope: Scope.GenZir = .{
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    defer as_scope.instructions.deinit(mod.gpa);

    as_scope.rl_ptr = try addZIRBinOp(mod, &as_scope.base, src, .coerce_result_ptr, dest_type, result_ptr);
    const result = try expr(mod, &as_scope.base, .{ .block_ptr = &as_scope }, operand_node);
    const parent_zir = &scope.getGenZir().instructions;
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

fn bitCast(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    builtin_token: ast.TokenIndex,
    src: usize,
    lhs: ast.Node.Index,
    rhs: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    const dest_type = try typeExpr(mod, scope, lhs);
    switch (rl) {
        .none => {
            const operand = try expr(mod, scope, .none, rhs);
            return addZIRBinOp(mod, scope, src, .bitcast, dest_type, operand);
        },
        .discard => {
            const operand = try expr(mod, scope, .none, rhs);
            const result = try addZIRBinOp(mod, scope, src, .bitcast, dest_type, operand);
            _ = try addZIRUnOp(mod, scope, result.src, .ensure_result_non_error, result);
            return result;
        },
        .ref => {
            const operand = try expr(mod, scope, .ref, rhs);
            const result = try addZIRBinOp(mod, scope, src, .bitcast_ref, dest_type, operand);
            return result;
        },
        .ty => |result_ty| {
            const result = try expr(mod, scope, .none, rhs);
            const bitcasted = try addZIRBinOp(mod, scope, src, .bitcast, dest_type, result);
            return addZIRBinOp(mod, scope, src, .as, result_ty, bitcasted);
        },
        .ptr => |result_ptr| {
            const casted_result_ptr = try addZIRUnOp(mod, scope, src, .bitcast_result_ptr, result_ptr);
            return expr(mod, scope, .{ .bitcasted_ptr = casted_result_ptr.castTag(.bitcast_result_ptr).? }, rhs);
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            return mod.failTok(scope, builtin_token, "TODO implement @bitCast with result location another @bitCast", .{});
        },
        .block_ptr => |block_ptr| {
            return mod.failTok(scope, builtin_token, "TODO implement @bitCast with result location inferred peer types", .{});
        },
        .inferred_ptr => |result_alloc| {
            // TODO here we should be able to resolve the inference; we now have a type for the result.
            return mod.failTok(scope, builtin_token, "TODO implement @bitCast with inferred-type result location pointer", .{});
        },
    }
}

fn typeOf(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    builtin_token: ast.TokenIndex,
    src: usize,
    params: []const ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (params.len < 1) {
        return mod.failTok(scope, builtin_token, "expected at least 1 argument, found 0", .{});
    }
    if (params.len == 1) {
        return rvalue(mod, scope, rl, try addZIRUnOp(mod, scope, src, .typeof, try expr(mod, scope, .none, params[0])));
    }
    const arena = scope.arena();
    var items = try arena.alloc(zir.Inst.Ref, params.len);
    for (params) |param, param_i|
        items[param_i] = try expr(mod, scope, .none, param);
    return rvalue(mod, scope, rl, try addZIRInst(mod, scope, src, zir.Inst.TypeOfPeer, .{ .items = items }, .{}));
}

fn builtinCall(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    call: ast.Node.Index,
    params: []const ast.Node.Index,
) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);

    const builtin_token = main_tokens[call];
    const builtin_name = tree.tokenSlice(builtin_token);

    // We handle the different builtins manually because they have different semantics depending
    // on the function. For example, `@as` and others participate in result location semantics,
    // and `@cImport` creates a special scope that collects a .c source code text buffer.
    // Also, some builtins have a variable number of parameters.

    const info = BuiltinFn.list.get(builtin_name) orelse {
        return mod.failTok(scope, builtin_token, "invalid builtin function: '{s}'", .{
            builtin_name,
        });
    };
    if (info.param_count) |expected| {
        if (expected != params.len) {
            const s = if (expected == 1) "" else "s";
            return mod.failTok(scope, builtin_token, "expected {d} parameter{s}, found {d}", .{
                expected, s, params.len,
            });
        }
    }
    const src = token_starts[builtin_token];

    switch (info.tag) {
        .ptr_to_int => {
            const operand = try expr(mod, scope, .none, params[0]);
            const result = try addZIRUnOp(mod, scope, src, .ptrtoint, operand);
            return rvalue(mod, scope, rl, result);
        },
        .float_cast => {
            const dest_type = try typeExpr(mod, scope, params[0]);
            const rhs = try expr(mod, scope, .none, params[1]);
            const result = try addZIRBinOp(mod, scope, src, .floatcast, dest_type, rhs);
            return rvalue(mod, scope, rl, result);
        },
        .int_cast => {
            const dest_type = try typeExpr(mod, scope, params[0]);
            const rhs = try expr(mod, scope, .none, params[1]);
            const result = try addZIRBinOp(mod, scope, src, .intcast, dest_type, rhs);
            return rvalue(mod, scope, rl, result);
        },
        .breakpoint => {
            const result = try addZIRNoOp(mod, scope, src, .breakpoint);
            return rvalue(mod, scope, rl, result);
        },
        .import => {
            const target = try expr(mod, scope, .none, params[0]);
            const result = try addZIRUnOp(mod, scope, src, .import, target);
            return rvalue(mod, scope, rl, result);
        },
        .compile_error => {
            const target = try expr(mod, scope, .none, params[0]);
            const result = try addZIRUnOp(mod, scope, src, .compile_error, target);
            return rvalue(mod, scope, rl, result);
        },
        .set_eval_branch_quota => {
            const u32_type = try addZIRInstConst(mod, scope, src, .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.u32_type),
            });
            const quota = try expr(mod, scope, .{ .ty = u32_type }, params[0]);
            const result = try addZIRUnOp(mod, scope, src, .set_eval_branch_quota, quota);
            return rvalue(mod, scope, rl, result);
        },
        .compile_log => {
            const arena = scope.arena();
            var targets = try arena.alloc(zir.Inst.Ref, params.len);
            for (params) |param, param_i|
                targets[param_i] = try expr(mod, scope, .none, param);
            const result = try addZIRInst(mod, scope, src, zir.Inst.CompileLog, .{ .to_log = targets }, .{});
            return rvalue(mod, scope, rl, result);
        },
        .field => {
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
        },
        .as => return as(mod, scope, rl, builtin_token, src, params[0], params[1]),
        .bit_cast => return bitCast(mod, scope, rl, builtin_token, src, params[0], params[1]),
        .TypeOf => return typeOf(mod, scope, rl, builtin_token, src, params),

        .add_with_overflow,
        .align_cast,
        .align_of,
        .async_call,
        .atomic_load,
        .atomic_rmw,
        .atomic_store,
        .bit_offset_of,
        .bool_to_int,
        .bit_size_of,
        .mul_add,
        .byte_swap,
        .bit_reverse,
        .byte_offset_of,
        .call,
        .c_define,
        .c_import,
        .c_include,
        .clz,
        .cmpxchg_strong,
        .cmpxchg_weak,
        .ctz,
        .c_undef,
        .div_exact,
        .div_floor,
        .div_trunc,
        .embed_file,
        .enum_to_int,
        .error_name,
        .error_return_trace,
        .error_to_int,
        .err_set_cast,
        .@"export",
        .fence,
        .field_parent_ptr,
        .float_to_int,
        .frame,
        .Frame,
        .frame_address,
        .frame_size,
        .has_decl,
        .has_field,
        .int_to_enum,
        .int_to_error,
        .int_to_float,
        .int_to_ptr,
        .memcpy,
        .memset,
        .wasm_memory_size,
        .wasm_memory_grow,
        .mod,
        .mul_with_overflow,
        .panic,
        .pop_count,
        .ptr_cast,
        .rem,
        .return_address,
        .set_align_stack,
        .set_cold,
        .set_float_mode,
        .set_runtime_safety,
        .shl_exact,
        .shl_with_overflow,
        .shr_exact,
        .shuffle,
        .size_of,
        .splat,
        .reduce,
        .src,
        .sqrt,
        .sin,
        .cos,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .fabs,
        .floor,
        .ceil,
        .trunc,
        .round,
        .sub_with_overflow,
        .tag_name,
        .This,
        .truncate,
        .Type,
        .type_info,
        .type_name,
        .union_init,
        => return mod.failTok(scope, builtin_token, "TODO: implement builtin function {s}", .{
            builtin_name,
        }),
    }
}

fn callExpr(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    node: ast.Node.Index,
    call: ast.full.Call,
) InnerError!zir.Inst.Ref {
    if (true) {
        @panic("TODO update for zir-memory-layout branch");
    }

    if (call.async_token) |async_token| {
        return mod.failTok(scope, async_token, "TODO implement async fn call", .{});
    }
    const lhs = try expr(mod, scope, .none, call.ast.fn_expr);

    const args = try mod.gpa.alloc(zir.Inst.Index, call.ast.params.len);
    defer mod.gpa.free(args);

    const gen_zir = scope.getGenZir();
    for (call.ast.params) |param_node, i| {
        const param_type = try gen_zir.addParamType(.{
            .callee = lhs,
            .param_index = i,
        });
        args[i] = try expr(mod, scope, .{ .ty = param_type }, param_node);
    }

    const modifier: std.builtin.CallOptions.Modifier = switch (call.async_token != null) {
        true => .async_kw,
        false => .auto,
    };
    const result: zir.Inst.Index = res: {
        const tag: zir.Inst.Tag = switch (modifier) {
            .auto => switch (args.len == 0) {
                true => break :res try gen_zir.addCallNone(lhs, node),
                false => .call,
            },
            .async_kw => .call_async_kw,
            .never_tail => unreachable,
            .never_inline => unreachable,
            .no_async => .call_no_async,
            .always_tail => unreachable,
            .always_inline => unreachable,
            .compile_time => .call_compile_time,
        };
        break :res try gen_zir.addCall(tag, lhs, args, node);
    };
    return rvalue(mod, scope, rl, result); // TODO function call with result location
}

fn suspendExpr(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const src = tree.tokens.items(.start)[tree.nodes.items(.main_token)[node]];

    if (scope.getNosuspend()) |some| {
        const msg = msg: {
            const msg = try mod.errMsg(scope, src, "suspend in nosuspend block", .{});
            errdefer msg.destroy(mod.gpa);
            try mod.errNote(scope, some.src, msg, "nosuspend block here", .{});
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(scope, msg);
    }

    if (scope.getSuspend()) |some| {
        const msg = msg: {
            const msg = try mod.errMsg(scope, src, "cannot suspend inside suspend block", .{});
            errdefer msg.destroy(mod.gpa);
            try mod.errNote(scope, some.src, msg, "other suspend block here", .{});
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(scope, msg);
    }

    var suspend_scope: Scope.GenZIR = .{
        .base = .{ .tag = .gen_suspend },
        .parent = scope,
        .decl = scope.ownerDecl().?,
        .arena = scope.arena(),
        .force_comptime = scope.isComptime(),
        .instructions = .{},
    };
    defer suspend_scope.instructions.deinit(mod.gpa);

    const operand = tree.nodes.items(.data)[node].lhs;
    if (operand != 0) {
        const possibly_unused_result = try expr(mod, &suspend_scope.base, .none, operand);
        if (!possibly_unused_result.tag.isNoReturn()) {
            _ = try addZIRUnOp(mod, &suspend_scope.base, src, .ensure_result_used, possibly_unused_result);
        }
    } else {
        return addZIRNoOp(mod, scope, src, .@"suspend");
    }

    const block = try addZIRInstBlock(mod, scope, src, .suspend_block, .{
        .instructions = try scope.arena().dupe(zir.Inst.Ref, suspend_scope.instructions.items),
    });
    return &block.base;
}

fn nosuspendExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    var child_scope = Scope.Nosuspend{
        .parent = scope,
        .gen_zir = scope.getGenZir(),
        .src = tree.tokens.items(.start)[tree.nodes.items(.main_token)[node]],
    };

    return expr(mod, &child_scope.base, rl, tree.nodes.items(.data)[node].lhs);
}

fn awaitExpr(mod: *Module, scope: *Scope, rl: ResultLoc, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    if (true) @panic("TODO update for zir-memory-layout");
    const tree = scope.tree();
    const src = tree.tokens.items(.start)[tree.nodes.items(.main_token)[node]];
    const is_nosuspend = scope.getNosuspend() != null;

    // TODO some @asyncCall stuff

    if (scope.getSuspend()) |some| {
        const msg = msg: {
            const msg = try mod.errMsg(scope, src, "cannot await inside suspend block", .{});
            errdefer msg.destroy(mod.gpa);
            try mod.errNote(scope, some.src, msg, "suspend block here", .{});
            break :msg msg;
        };
        return mod.failWithOwnedErrorMsg(scope, msg);
    }

    const operand = try expr(mod, scope, .ref, tree.nodes.items(.data)[node].lhs);
    // TODO pass result location
    return addZIRUnOp(mod, scope, src, if (is_nosuspend) .nosuspend_await else .@"await", operand);
}

fn resumeExpr(mod: *Module, scope: *Scope, node: ast.Node.Index) InnerError!zir.Inst.Ref {
    const tree = scope.tree();
    const src = tree.tokens.items(.start)[tree.nodes.items(.main_token)[node]];

    const operand = try expr(mod, scope, .ref, tree.nodes.items(.data)[node].lhs);
    return addZIRUnOp(mod, scope, src, .@"resume", operand);
}

pub const simple_types = std.ComptimeStringMap(zir.Const, .{
    .{ "u8", .u8_type },
    .{ "i8", .i8_type },
    .{ "u16", .u16_type },
    .{ "i16", .i16_type },
    .{ "u32", .u32_type },
    .{ "i32", .i32_type },
    .{ "u64", .u64_type },
    .{ "i64", .i64_type },
    .{ "usize", .usize_type },
    .{ "isize", .isize_type },
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
    .{ "null", .null_type },
    .{ "undefined", .undefined_type },
    .{ "anyframe", .anyframe_type },
    .{ "undefined", .undef },
    .{ "null", .null_value },
    .{ "true", .bool_true },
    .{ "false", .bool_false },
});

fn nodeMayNeedMemoryLocation(scope: *Scope, start_node: ast.Node.Index) bool {
    const tree = scope.tree();
    const node_tags = tree.nodes.items(.tag);
    const node_datas = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    const token_tags = tree.tokens.items(.tag);

    var node = start_node;
    while (true) {
        switch (node_tags[node]) {
            .root,
            .@"usingnamespace",
            .test_decl,
            .switch_case,
            .switch_case_one,
            .container_field_init,
            .container_field_align,
            .container_field,
            .asm_output,
            .asm_input,
            => unreachable,

            .@"return",
            .@"break",
            .@"continue",
            .bit_not,
            .bool_not,
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            .@"defer",
            .@"errdefer",
            .address_of,
            .optional_type,
            .negation,
            .negation_wrap,
            .@"resume",
            .array_type,
            .array_type_sentinel,
            .ptr_type_aligned,
            .ptr_type_sentinel,
            .ptr_type,
            .ptr_type_bit_range,
            .@"suspend",
            .@"anytype",
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            .anyframe_type,
            .anyframe_literal,
            .integer_literal,
            .float_literal,
            .enum_literal,
            .string_literal,
            .multiline_string_literal,
            .char_literal,
            .true_literal,
            .false_literal,
            .null_literal,
            .undefined_literal,
            .unreachable_literal,
            .identifier,
            .error_set_decl,
            .container_decl,
            .container_decl_trailing,
            .container_decl_two,
            .container_decl_two_trailing,
            .container_decl_arg,
            .container_decl_arg_trailing,
            .tagged_union,
            .tagged_union_trailing,
            .tagged_union_two,
            .tagged_union_two_trailing,
            .tagged_union_enum_tag,
            .tagged_union_enum_tag_trailing,
            .@"asm",
            .asm_simple,
            .add,
            .add_wrap,
            .array_cat,
            .array_mult,
            .assign,
            .assign_bit_and,
            .assign_bit_or,
            .assign_bit_shift_left,
            .assign_bit_shift_right,
            .assign_bit_xor,
            .assign_div,
            .assign_sub,
            .assign_sub_wrap,
            .assign_mod,
            .assign_add,
            .assign_add_wrap,
            .assign_mul,
            .assign_mul_wrap,
            .bang_equal,
            .bit_and,
            .bit_or,
            .bit_shift_left,
            .bit_shift_right,
            .bit_xor,
            .bool_and,
            .bool_or,
            .div,
            .equal_equal,
            .error_union,
            .greater_or_equal,
            .greater_than,
            .less_or_equal,
            .less_than,
            .merge_error_sets,
            .mod,
            .mul,
            .mul_wrap,
            .switch_range,
            .field_access,
            .sub,
            .sub_wrap,
            .slice,
            .slice_open,
            .slice_sentinel,
            .deref,
            .array_access,
            .error_value,
            .while_simple, // This variant cannot have an else expression.
            .while_cont, // This variant cannot have an else expression.
            .for_simple, // This variant cannot have an else expression.
            .if_simple, // This variant cannot have an else expression.
            => return false,

            // Forward the question to the LHS sub-expression.
            .grouped_expression,
            .@"try",
            .@"await",
            .@"comptime",
            .@"nosuspend",
            .unwrap_optional,
            => node = node_datas[node].lhs,

            // Forward the question to the RHS sub-expression.
            .@"catch",
            .@"orelse",
            => node = node_datas[node].rhs,

            // True because these are exactly the expressions we need memory locations for.
            .array_init_one,
            .array_init_one_comma,
            .array_init_dot_two,
            .array_init_dot_two_comma,
            .array_init_dot,
            .array_init_dot_comma,
            .array_init,
            .array_init_comma,
            .struct_init_one,
            .struct_init_one_comma,
            .struct_init_dot_two,
            .struct_init_dot_two_comma,
            .struct_init_dot,
            .struct_init_dot_comma,
            .struct_init,
            .struct_init_comma,
            => return true,

            // True because depending on comptime conditions, sub-expressions
            // may be the kind that need memory locations.
            .@"while", // This variant always has an else expression.
            .@"if", // This variant always has an else expression.
            .@"for", // This variant always has an else expression.
            .@"switch",
            .switch_comma,
            .call_one,
            .call_one_comma,
            .async_call_one,
            .async_call_one_comma,
            .call,
            .call_comma,
            .async_call,
            .async_call_comma,
            => return true,

            .block_two,
            .block_two_semicolon,
            .block,
            .block_semicolon,
            => {
                const lbrace = main_tokens[node];
                if (token_tags[lbrace - 1] == .colon) {
                    // Labeled blocks may need a memory location to forward
                    // to their break statements.
                    return true;
                } else {
                    return false;
                }
            },

            .builtin_call,
            .builtin_call_comma,
            .builtin_call_two,
            .builtin_call_two_comma,
            => {
                const builtin_token = main_tokens[node];
                const builtin_name = tree.tokenSlice(builtin_token);
                // If the builtin is an invalid name, we don't cause an error here; instead
                // let it pass, and the error will be "invalid builtin function" later.
                const builtin_info = BuiltinFn.list.get(builtin_name) orelse return false;
                return builtin_info.needs_mem_loc;
            },
        }
    }
}

/// Applies `rl` semantics to `inst`. Expressions which do not do their own handling of
/// result locations must call this function on their result.
/// As an example, if the `ResultLoc` is `ptr`, it will write the result to the pointer.
/// If the `ResultLoc` is `ty`, it will coerce the result to the type.
fn rvalue(
    mod: *Module,
    scope: *Scope,
    rl: ResultLoc,
    result: zir.Inst.Ref,
    src_node: ast.Node.Index,
) InnerError!zir.Inst.Ref {
    const gz = scope.getGenZir();
    switch (rl) {
        .none => return result,
        .discard => {
            // Emit a compile error for discarding error values.
            _ = try gz.addUnNode(.ensure_result_non_error, result, src_node);
            return result;
        },
        .ref => {
            // We need a pointer but we have a value.
            const tree = scope.tree();
            const src_token = tree.firstToken(src_node);
            return gz.addUnTok(.ref, result, src_token);
        },
        .ty => |ty_inst| return gz.addBin(.as, ty_inst, result),
        .ptr => |ptr_inst| {
            _ = try gz.addBin(.store, ptr_inst, result);
            return result;
        },
        .bitcasted_ptr => |bitcasted_ptr| {
            return mod.failNode(scope, src_node, "TODO implement rvalue .bitcasted_ptr", .{});
        },
        .inferred_ptr => |alloc| {
            _ = try gz.addBin(.store_to_inferred_ptr, alloc, result);
            return result;
        },
        .block_ptr => |block_scope| {
            block_scope.rvalue_rl_count += 1;
            _ = try gz.addBin(.store_to_block_ptr, block_scope.rl_ptr, result);
            return result;
        },
    }
}

fn rlStrategy(rl: ResultLoc, block_scope: *Scope.GenZir) ResultLoc.Strategy {
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

/// If the input ResultLoc is ref, returns ResultLoc.ref. Otherwise:
/// Returns ResultLoc.ty, where the type is determined by the input
/// ResultLoc type, wrapped in an optional type. If the input ResultLoc
/// has no type, .none is returned.
fn makeOptionalTypeResultLoc(mod: *Module, scope: *Scope, src: usize, rl: ResultLoc) !ResultLoc {
    switch (rl) {
        .ref => return ResultLoc.ref,
        .discard, .none, .block_ptr, .inferred_ptr, .bitcasted_ptr => return ResultLoc.none,
        .ty => |elem_ty| {
            const wrapped_ty = try addZIRUnOp(mod, scope, src, .optional_type, elem_ty);
            return ResultLoc{ .ty = wrapped_ty };
        },
        .ptr => |ptr_ty| {
            const wrapped_ty = try addZIRUnOp(mod, scope, src, .optional_type_from_ptr_elem, ptr_ty);
            return ResultLoc{ .ty = wrapped_ty };
        },
    }
}

fn setBlockResultLoc(block_scope: *Scope.GenZir, parent_rl: ResultLoc) void {
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
