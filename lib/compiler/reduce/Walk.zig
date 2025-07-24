const std = @import("std");
const Ast = std.zig.Ast;
const Walk = @This();
const assert = std.debug.assert;
const BuiltinFn = std.zig.BuiltinFn;

ast: *const Ast,
transformations: *std.ArrayList(Transformation),
unreferenced_globals: std.StringArrayHashMapUnmanaged(Ast.Node.Index),
in_scope_names: std.StringArrayHashMapUnmanaged(u32),
replace_names: std.StringArrayHashMapUnmanaged(u32),
gpa: std.mem.Allocator,
arena: std.mem.Allocator,

pub const Transformation = union(enum) {
    /// Replace the fn decl AST Node with one whose body is only `@trap()` with
    /// discarded parameters.
    gut_function: Ast.Node.Index,
    /// Omit a global declaration.
    delete_node: Ast.Node.Index,
    /// Delete a local variable declaration and replace all of its references
    /// with `undefined`.
    delete_var_decl: struct {
        var_decl_node: Ast.Node.Index,
        /// Identifier nodes that reference the variable.
        references: std.ArrayListUnmanaged(Ast.Node.Index),
    },
    /// Replace an expression with `undefined`.
    replace_with_undef: Ast.Node.Index,
    /// Replace an expression with `true`.
    replace_with_true: Ast.Node.Index,
    /// Replace an expression with `false`.
    replace_with_false: Ast.Node.Index,
    /// Replace a node with another node.
    replace_node: struct {
        to_replace: Ast.Node.Index,
        replacement: Ast.Node.Index,
    },
    /// Replace an `@import` with the imported file contents wrapped in a struct.
    inline_imported_file: InlineImportedFile,

    pub const InlineImportedFile = struct {
        builtin_call_node: Ast.Node.Index,
        imported_string: []const u8,
        /// Identifier names that must be renamed in the inlined code or else
        /// will cause ambiguous reference errors.
        in_scope_names: std.StringArrayHashMapUnmanaged(void),
    };
};

pub const Error = error{OutOfMemory};

/// The result will be priority shuffled.
pub fn findTransformations(
    arena: std.mem.Allocator,
    ast: *const Ast,
    transformations: *std.ArrayList(Transformation),
) !void {
    transformations.clearRetainingCapacity();

    var walk: Walk = .{
        .ast = ast,
        .transformations = transformations,
        .gpa = transformations.allocator,
        .arena = arena,
        .unreferenced_globals = .{},
        .in_scope_names = .{},
        .replace_names = .{},
    };
    defer {
        walk.unreferenced_globals.deinit(walk.gpa);
        walk.in_scope_names.deinit(walk.gpa);
        walk.replace_names.deinit(walk.gpa);
    }

    try walkMembers(&walk, walk.ast.rootDecls());

    const unreferenced_globals = walk.unreferenced_globals.values();
    try transformations.ensureUnusedCapacity(unreferenced_globals.len);
    for (unreferenced_globals) |node| {
        transformations.appendAssumeCapacity(.{ .delete_node = node });
    }
}

fn walkMembers(w: *Walk, members: []const Ast.Node.Index) Error!void {
    // First we scan for globals so that we can delete them while walking.
    try scanDecls(w, members, .add);

    for (members) |member| {
        try walkMember(w, member);
    }

    try scanDecls(w, members, .remove);
}

const ScanDeclsAction = enum { add, remove };

fn scanDecls(w: *Walk, members: []const Ast.Node.Index, action: ScanDeclsAction) Error!void {
    const ast = w.ast;
    const gpa = w.gpa;

    for (members) |member_node| {
        const name_token = switch (ast.nodeTag(member_node)) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => ast.nodeMainToken(member_node) + 1,

            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            => ast.nodeMainToken(member_node) + 1,

            else => continue,
        };

        assert(ast.tokenTag(name_token) == .identifier);
        const name_bytes = ast.tokenSlice(name_token);

        switch (action) {
            .add => {
                try w.unreferenced_globals.put(gpa, name_bytes, member_node);

                const gop = try w.in_scope_names.getOrPut(gpa, name_bytes);
                if (!gop.found_existing) gop.value_ptr.* = 0;
                gop.value_ptr.* += 1;
            },
            .remove => {
                const entry = w.in_scope_names.getEntry(name_bytes).?;
                if (entry.value_ptr.* <= 1) {
                    assert(w.in_scope_names.swapRemove(name_bytes));
                } else {
                    entry.value_ptr.* -= 1;
                }
            },
        }
    }
}

fn walkMember(w: *Walk, decl: Ast.Node.Index) Error!void {
    const ast = w.ast;
    switch (ast.nodeTag(decl)) {
        .fn_decl => {
            const fn_proto, const body_node = ast.nodeData(decl).node_and_node;
            try walkExpression(w, fn_proto);
            if (!isFnBodyGutted(ast, body_node)) {
                w.replace_names.clearRetainingCapacity();
                try w.transformations.append(.{ .gut_function = decl });
                try walkExpression(w, body_node);
            }
        },
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            try walkExpression(w, decl);
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => try walkGlobalVarDecl(w, decl, ast.fullVarDecl(decl).?),

        .test_decl => {
            try w.transformations.append(.{ .delete_node = decl });
            try walkExpression(w, ast.nodeData(decl).opt_token_and_node[1]);
        },

        .container_field_init,
        .container_field_align,
        .container_field,
        => {
            try w.transformations.append(.{ .delete_node = decl });
            try walkContainerField(w, ast.fullContainerField(decl).?);
        },

        .@"comptime" => {
            try w.transformations.append(.{ .delete_node = decl });
            try walkExpression(w, decl);
        },

        .root => unreachable,
        else => unreachable,
    }
}

fn walkExpression(w: *Walk, node: Ast.Node.Index) Error!void {
    const ast = w.ast;
    switch (ast.nodeTag(node)) {
        .identifier => {
            const name_ident = ast.nodeMainToken(node);
            assert(ast.tokenTag(name_ident) == .identifier);
            const name_bytes = ast.tokenSlice(name_ident);
            _ = w.unreferenced_globals.swapRemove(name_bytes);
            if (w.replace_names.get(name_bytes)) |index| {
                try w.transformations.items[index].delete_var_decl.references.append(w.arena, node);
            }
        },

        .number_literal,
        .char_literal,
        .unreachable_literal,
        .anyframe_literal,
        .string_literal,
        => {},

        .multiline_string_literal => {},

        .error_value => {},

        .block_two,
        .block_two_semicolon,
        .block,
        .block_semicolon,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const statements = ast.blockStatements(&buf, node).?;
            return walkBlock(w, node, statements);
        },

        .@"errdefer" => {
            const expr = ast.nodeData(node).opt_token_and_node[1];
            return walkExpression(w, expr);
        },

        .@"defer",
        .@"comptime",
        .@"nosuspend",
        .@"suspend",
        => {
            return walkExpression(w, ast.nodeData(node).node);
        },

        .field_access => {
            try walkExpression(w, ast.nodeData(node).node_and_token[0]);
        },

        .for_range => {
            const start, const opt_end = ast.nodeData(node).node_and_opt_node;
            try walkExpression(w, start);
            if (opt_end.unwrap()) |end| {
                return walkExpression(w, end);
            }
        },

        .add,
        .add_wrap,
        .add_sat,
        .array_cat,
        .array_mult,
        .assign,
        .assign_bit_and,
        .assign_bit_or,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_xor,
        .assign_div,
        .assign_sub,
        .assign_sub_wrap,
        .assign_sub_sat,
        .assign_mod,
        .assign_add,
        .assign_add_wrap,
        .assign_add_sat,
        .assign_mul,
        .assign_mul_wrap,
        .assign_mul_sat,
        .bang_equal,
        .bit_and,
        .bit_or,
        .shl,
        .shl_sat,
        .shr,
        .bit_xor,
        .bool_and,
        .bool_or,
        .div,
        .equal_equal,
        .greater_or_equal,
        .greater_than,
        .less_or_equal,
        .less_than,
        .merge_error_sets,
        .mod,
        .mul,
        .mul_wrap,
        .mul_sat,
        .sub,
        .sub_wrap,
        .sub_sat,
        .@"catch",
        .error_union,
        .switch_range,
        .@"orelse",
        .array_access,
        => {
            const lhs, const rhs = ast.nodeData(node).node_and_node;
            try walkExpression(w, lhs);
            try walkExpression(w, rhs);
        },

        .assign_destructure => {
            const full = ast.assignDestructure(node);
            for (full.ast.variables) |variable_node| {
                switch (ast.nodeTag(variable_node)) {
                    .global_var_decl,
                    .local_var_decl,
                    .simple_var_decl,
                    .aligned_var_decl,
                    => try walkLocalVarDecl(w, ast.fullVarDecl(variable_node).?),

                    else => try walkExpression(w, variable_node),
                }
            }
            return walkExpression(w, full.ast.value_expr);
        },

        .bit_not,
        .bool_not,
        .negation,
        .negation_wrap,
        .optional_type,
        .address_of,
        .@"try",
        .@"resume",
        .deref,
        => {
            return walkExpression(w, ast.nodeData(node).node);
        },

        .array_type,
        .array_type_sentinel,
        => {},

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => {},

        .array_init_one,
        .array_init_one_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .array_init_dot,
        .array_init_dot_comma,
        .array_init,
        .array_init_comma,
        => {
            var elements: [2]Ast.Node.Index = undefined;
            return walkArrayInit(w, ast.fullArrayInit(&elements, node).?);
        },

        .struct_init_one,
        .struct_init_one_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init,
        .struct_init_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            return walkStructInit(w, node, ast.fullStructInit(&buf, node).?);
        },

        .call_one,
        .call_one_comma,
        .call,
        .call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return walkCall(w, ast.fullCall(&buf, node).?);
        },

        .slice_open, .slice, .slice_sentinel => return walkSlice(w, node, ast.fullSlice(node).?),

        .unwrap_optional => {
            try walkExpression(w, ast.nodeData(node).node_and_token[0]);
        },

        .@"break" => {
            const label_token, const target = ast.nodeData(node).opt_token_and_opt_node;
            if (label_token == .none and target == .none) {
                // no expressions
            } else if (label_token == .none and target != .none) {
                try walkExpression(w, target.unwrap().?);
            } else if (label_token != .none and target == .none) {
                try walkIdentifier(w, label_token.unwrap().?);
            } else if (label_token != .none and target != .none) {
                try walkExpression(w, target.unwrap().?);
            }
        },

        .@"continue" => {
            const opt_label = ast.nodeData(node).opt_token_and_opt_node[0];
            if (opt_label.unwrap()) |label| {
                return walkIdentifier(w, label);
            }
        },

        .@"return" => {
            if (ast.nodeData(node).opt_node.unwrap()) |lhs| {
                try walkExpression(w, lhs);
            }
        },

        .grouped_expression => {
            try walkExpression(w, ast.nodeData(node).node_and_token[0]);
        },

        .container_decl,
        .container_decl_trailing,
        .container_decl_arg,
        .container_decl_arg_trailing,
        .container_decl_two,
        .container_decl_two_trailing,
        .tagged_union,
        .tagged_union_trailing,
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_trailing,
        .tagged_union_two,
        .tagged_union_two_trailing,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            return walkContainerDecl(w, node, ast.fullContainerDecl(&buf, node).?);
        },

        .error_set_decl => {
            const lbrace, const rbrace = ast.nodeData(node).token_and_token;

            var i = lbrace + 1;
            while (i < rbrace) : (i += 1) {
                switch (ast.tokenTag(i)) {
                    .doc_comment => unreachable, // TODO
                    .identifier => try walkIdentifier(w, i),
                    .comma => {},
                    else => unreachable,
                }
            }
        },

        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = ast.builtinCallParams(&buf, node).?;
            return walkBuiltinCall(w, node, params);
        },

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return walkFnProto(w, ast.fullFnProto(&buf, node).?);
        },

        .anyframe_type => {
            _, const child_type = ast.nodeData(node).token_and_node;
            return walkExpression(w, child_type);
        },

        .@"switch",
        .switch_comma,
        => {
            const full = ast.fullSwitch(node).?;
            try walkExpression(w, full.ast.condition); // condition expression
            try walkExpressions(w, full.ast.cases);
        },

        .switch_case_one,
        .switch_case_inline_one,
        .switch_case,
        .switch_case_inline,
        => return walkSwitchCase(w, ast.fullSwitchCase(node).?),

        .while_simple,
        .while_cont,
        .@"while",
        => return walkWhile(w, node, ast.fullWhile(node).?),

        .for_simple,
        .@"for",
        => return walkFor(w, ast.fullFor(node).?),

        .if_simple,
        .@"if",
        => return walkIf(w, node, ast.fullIf(node).?),

        .asm_simple,
        .@"asm",
        => return walkAsm(w, ast.fullAsm(node).?),

        .enum_literal => {
            return walkIdentifier(w, ast.nodeMainToken(node)); // name
        },

        .fn_decl => unreachable,
        .container_field => unreachable,
        .container_field_init => unreachable,
        .container_field_align => unreachable,
        .root => unreachable,
        .global_var_decl => unreachable,
        .local_var_decl => unreachable,
        .simple_var_decl => unreachable,
        .aligned_var_decl => unreachable,
        .test_decl => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,
    }
}

fn walkGlobalVarDecl(w: *Walk, decl_node: Ast.Node.Index, var_decl: Ast.full.VarDecl) Error!void {
    _ = decl_node;

    if (var_decl.ast.type_node.unwrap()) |type_node| {
        try walkExpression(w, type_node);
    }

    if (var_decl.ast.align_node.unwrap()) |align_node| {
        try walkExpression(w, align_node);
    }

    if (var_decl.ast.addrspace_node.unwrap()) |addrspace_node| {
        try walkExpression(w, addrspace_node);
    }

    if (var_decl.ast.section_node.unwrap()) |section_node| {
        try walkExpression(w, section_node);
    }

    if (var_decl.ast.init_node.unwrap()) |init_node| {
        if (!isUndefinedIdent(w.ast, init_node)) {
            try w.transformations.append(.{ .replace_with_undef = init_node });
        }
        try walkExpression(w, init_node);
    }
}

fn walkLocalVarDecl(w: *Walk, var_decl: Ast.full.VarDecl) Error!void {
    try walkIdentifierNew(w, var_decl.ast.mut_token + 1); // name

    if (var_decl.ast.type_node.unwrap()) |type_node| {
        try walkExpression(w, type_node);
    }

    if (var_decl.ast.align_node.unwrap()) |align_node| {
        try walkExpression(w, align_node);
    }

    if (var_decl.ast.addrspace_node.unwrap()) |addrspace_node| {
        try walkExpression(w, addrspace_node);
    }

    if (var_decl.ast.section_node.unwrap()) |section_node| {
        try walkExpression(w, section_node);
    }

    if (var_decl.ast.init_node.unwrap()) |init_node| {
        if (!isUndefinedIdent(w.ast, init_node)) {
            try w.transformations.append(.{ .replace_with_undef = init_node });
        }
        try walkExpression(w, init_node);
    }
}

fn walkContainerField(w: *Walk, field: Ast.full.ContainerField) Error!void {
    if (field.ast.type_expr.unwrap()) |type_expr| {
        try walkExpression(w, type_expr); // type
    }
    if (field.ast.align_expr.unwrap()) |align_expr| {
        try walkExpression(w, align_expr); // alignment
    }
    if (field.ast.value_expr.unwrap()) |value_expr| {
        try walkExpression(w, value_expr); // value
    }
}

fn walkBlock(
    w: *Walk,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
) Error!void {
    _ = block_node;
    const ast = w.ast;

    for (statements) |stmt| {
        switch (ast.nodeTag(stmt)) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                const var_decl = ast.fullVarDecl(stmt).?;
                if (var_decl.ast.init_node != .none and
                    isUndefinedIdent(w.ast, var_decl.ast.init_node.unwrap().?))
                {
                    try w.transformations.append(.{ .delete_var_decl = .{
                        .var_decl_node = stmt,
                        .references = .{},
                    } });
                    const name_tok = var_decl.ast.mut_token + 1;
                    const name_bytes = ast.tokenSlice(name_tok);
                    try w.replace_names.put(w.gpa, name_bytes, @intCast(w.transformations.items.len - 1));
                } else {
                    try walkLocalVarDecl(w, var_decl);
                }
            },

            else => {
                switch (categorizeStmt(ast, stmt)) {
                    // Don't try to remove `_ = foo;` discards; those are handled separately.
                    .discard_identifier => {},
                    // definitely try to remove `_ = undefined;` though.
                    .discard_undefined, .trap_call, .other => {
                        try w.transformations.append(.{ .delete_node = stmt });
                    },
                }
                try walkExpression(w, stmt);
            },
        }
    }
}

fn walkArrayType(w: *Walk, array_type: Ast.full.ArrayType) Error!void {
    try walkExpression(w, array_type.ast.elem_count);
    if (array_type.ast.sentinel.unwrap()) |sentinel| {
        try walkExpression(w, sentinel);
    }
    return walkExpression(w, array_type.ast.elem_type);
}

fn walkArrayInit(w: *Walk, array_init: Ast.full.ArrayInit) Error!void {
    if (array_init.ast.type_expr.unwrap()) |type_expr| {
        try walkExpression(w, type_expr); // T
    }
    for (array_init.ast.elements) |elem_init| {
        try walkExpression(w, elem_init);
    }
}

fn walkStructInit(
    w: *Walk,
    struct_node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
) Error!void {
    _ = struct_node;
    if (struct_init.ast.type_expr.unwrap()) |type_expr| {
        try walkExpression(w, type_expr); // T
    }
    for (struct_init.ast.fields) |field_init| {
        try walkExpression(w, field_init);
    }
}

fn walkCall(w: *Walk, call: Ast.full.Call) Error!void {
    try walkExpression(w, call.ast.fn_expr);
    try walkParamList(w, call.ast.params);
}

fn walkSlice(
    w: *Walk,
    slice_node: Ast.Node.Index,
    slice: Ast.full.Slice,
) Error!void {
    _ = slice_node;
    try walkExpression(w, slice.ast.sliced);
    try walkExpression(w, slice.ast.start);
    if (slice.ast.end.unwrap()) |end| {
        try walkExpression(w, end);
    }
    if (slice.ast.sentinel.unwrap()) |sentinel| {
        try walkExpression(w, sentinel);
    }
}

fn walkIdentifier(w: *Walk, name_ident: Ast.TokenIndex) Error!void {
    const ast = w.ast;
    assert(ast.tokenTag(name_ident) == .identifier);
    const name_bytes = ast.tokenSlice(name_ident);
    _ = w.unreferenced_globals.swapRemove(name_bytes);
}

fn walkIdentifierNew(w: *Walk, name_ident: Ast.TokenIndex) Error!void {
    _ = w;
    _ = name_ident;
}

fn walkContainerDecl(
    w: *Walk,
    container_decl_node: Ast.Node.Index,
    container_decl: Ast.full.ContainerDecl,
) Error!void {
    _ = container_decl_node;
    if (container_decl.ast.arg.unwrap()) |arg| {
        try walkExpression(w, arg);
    }
    try walkMembers(w, container_decl.ast.members);
}

fn walkBuiltinCall(
    w: *Walk,
    call_node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) Error!void {
    const ast = w.ast;
    const builtin_token = ast.nodeMainToken(call_node);
    const builtin_name = ast.tokenSlice(builtin_token);
    const info = BuiltinFn.list.get(builtin_name).?;
    switch (info.tag) {
        .import => {
            const operand_node = params[0];
            const str_lit_token = ast.nodeMainToken(operand_node);
            const token_bytes = ast.tokenSlice(str_lit_token);
            if (std.mem.endsWith(u8, token_bytes, ".zig\"")) {
                const imported_string = std.zig.string_literal.parseAlloc(w.arena, token_bytes) catch
                    unreachable;
                try w.transformations.append(.{ .inline_imported_file = .{
                    .builtin_call_node = call_node,
                    .imported_string = imported_string,
                    .in_scope_names = try std.StringArrayHashMapUnmanaged(void).init(
                        w.arena,
                        w.in_scope_names.keys(),
                        &.{},
                    ),
                } });
            }
        },
        else => {},
    }
    for (params) |param_node| {
        try walkExpression(w, param_node);
    }
}

fn walkFnProto(w: *Walk, fn_proto: Ast.full.FnProto) Error!void {
    const ast = w.ast;

    {
        var it = fn_proto.iterate(ast);
        while (it.next()) |param| {
            if (param.type_expr) |type_expr| {
                try walkExpression(w, type_expr);
            }
        }
    }

    if (fn_proto.ast.align_expr.unwrap()) |align_expr| {
        try walkExpression(w, align_expr);
    }

    if (fn_proto.ast.addrspace_expr.unwrap()) |addrspace_expr| {
        try walkExpression(w, addrspace_expr);
    }

    if (fn_proto.ast.section_expr.unwrap()) |section_expr| {
        try walkExpression(w, section_expr);
    }

    if (fn_proto.ast.callconv_expr.unwrap()) |callconv_expr| {
        try walkExpression(w, callconv_expr);
    }

    const return_type = fn_proto.ast.return_type.unwrap().?;
    try walkExpression(w, return_type);
}

fn walkExpressions(w: *Walk, expressions: []const Ast.Node.Index) Error!void {
    for (expressions) |expression| {
        try walkExpression(w, expression);
    }
}

fn walkSwitchCase(w: *Walk, switch_case: Ast.full.SwitchCase) Error!void {
    for (switch_case.ast.values) |value_expr| {
        try walkExpression(w, value_expr);
    }
    try walkExpression(w, switch_case.ast.target_expr);
}

fn walkWhile(w: *Walk, node_index: Ast.Node.Index, while_node: Ast.full.While) Error!void {
    // Perform these transformations in this priority order:
    // 1. If the `else` expression is missing or an empty block, replace the condition with `if (true)` if it is not already.
    // 2. If the `then` block is empty, replace the condition with `if (false)` if it is not already.
    // 3. If the condition is `if (true)`, replace the `if` expression with the contents of the `then` expression.
    // 4. If the condition is `if (false)`, replace the `if` expression with the contents of the `else` expression.
    if (!isTrueIdent(w.ast, while_node.ast.cond_expr) and
        (while_node.ast.else_expr == .none or isEmptyBlock(w.ast, while_node.ast.else_expr.unwrap().?)))
    {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_with_true = while_node.ast.cond_expr });
    } else if (!isFalseIdent(w.ast, while_node.ast.cond_expr) and isEmptyBlock(w.ast, while_node.ast.then_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_with_false = while_node.ast.cond_expr });
    } else if (isTrueIdent(w.ast, while_node.ast.cond_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_node = .{
            .to_replace = node_index,
            .replacement = while_node.ast.then_expr,
        } });
    } else if (isFalseIdent(w.ast, while_node.ast.cond_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_node = .{
            .to_replace = node_index,
            .replacement = while_node.ast.else_expr.unwrap().?,
        } });
    }

    try walkExpression(w, while_node.ast.cond_expr); // condition

    if (while_node.ast.cont_expr.unwrap()) |cont_expr| {
        try walkExpression(w, cont_expr);
    }

    try walkExpression(w, while_node.ast.then_expr);

    if (while_node.ast.else_expr.unwrap()) |else_expr| {
        try walkExpression(w, else_expr);
    }
}

fn walkFor(w: *Walk, for_node: Ast.full.For) Error!void {
    try walkParamList(w, for_node.ast.inputs);
    try walkExpression(w, for_node.ast.then_expr);
    if (for_node.ast.else_expr.unwrap()) |else_expr| {
        try walkExpression(w, else_expr);
    }
}

fn walkIf(w: *Walk, node_index: Ast.Node.Index, if_node: Ast.full.If) Error!void {
    // Perform these transformations in this priority order:
    // 1. If the `else` expression is missing or an empty block, replace the condition with `if (true)` if it is not already.
    // 2. If the `then` block is empty, replace the condition with `if (false)` if it is not already.
    // 3. If the condition is `if (true)`, replace the `if` expression with the contents of the `then` expression.
    // 4. If the condition is `if (false)`, replace the `if` expression with the contents of the `else` expression.
    if (!isTrueIdent(w.ast, if_node.ast.cond_expr) and
        (if_node.ast.else_expr == .none or isEmptyBlock(w.ast, if_node.ast.else_expr.unwrap().?)))
    {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_with_true = if_node.ast.cond_expr });
    } else if (!isFalseIdent(w.ast, if_node.ast.cond_expr) and isEmptyBlock(w.ast, if_node.ast.then_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_with_false = if_node.ast.cond_expr });
    } else if (isTrueIdent(w.ast, if_node.ast.cond_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_node = .{
            .to_replace = node_index,
            .replacement = if_node.ast.then_expr,
        } });
    } else if (isFalseIdent(w.ast, if_node.ast.cond_expr)) {
        try w.transformations.ensureUnusedCapacity(1);
        w.transformations.appendAssumeCapacity(.{ .replace_node = .{
            .to_replace = node_index,
            .replacement = if_node.ast.else_expr.unwrap().?,
        } });
    }

    try walkExpression(w, if_node.ast.cond_expr); // condition
    try walkExpression(w, if_node.ast.then_expr);
    if (if_node.ast.else_expr.unwrap()) |else_expr| {
        try walkExpression(w, else_expr);
    }
}

fn walkAsm(w: *Walk, asm_node: Ast.full.Asm) Error!void {
    try walkExpression(w, asm_node.ast.template);
    for (asm_node.ast.items) |item| {
        try walkExpression(w, item);
    }
}

fn walkParamList(w: *Walk, params: []const Ast.Node.Index) Error!void {
    for (params) |param_node| {
        try walkExpression(w, param_node);
    }
}

/// Check if it is already gutted (i.e. its body replaced with `@trap()`).
fn isFnBodyGutted(ast: *const Ast, body_node: Ast.Node.Index) bool {
    // skip over discards
    var statements_buf: [2]Ast.Node.Index = undefined;
    const statements = switch (ast.nodeTag(body_node)) {
        .block_two,
        .block_two_semicolon,
        .block,
        .block_semicolon,
        => ast.blockStatements(&statements_buf, body_node).?,

        else => return false,
    };
    var i: usize = 0;
    while (i < statements.len) : (i += 1) {
        switch (categorizeStmt(ast, statements[i])) {
            .discard_identifier => continue,
            .trap_call => return i + 1 == statements.len,
            else => return false,
        }
    }
    return false;
}

const StmtCategory = enum {
    discard_undefined,
    discard_identifier,
    trap_call,
    other,
};

fn categorizeStmt(ast: *const Ast, stmt: Ast.Node.Index) StmtCategory {
    switch (ast.nodeTag(stmt)) {
        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = ast.builtinCallParams(&buf, stmt).?;
            return categorizeBuiltinCall(ast, ast.nodeMainToken(stmt), params);
        },
        .assign => {
            const lhs, const rhs = ast.nodeData(stmt).node_and_node;
            if (isDiscardIdent(ast, lhs) and ast.nodeTag(rhs) == .identifier) {
                const name_bytes = ast.tokenSlice(ast.nodeMainToken(rhs));
                if (std.mem.eql(u8, name_bytes, "undefined")) {
                    return .discard_undefined;
                } else {
                    return .discard_identifier;
                }
            }
            return .other;
        },
        else => return .other,
    }
}

fn categorizeBuiltinCall(
    ast: *const Ast,
    builtin_token: Ast.TokenIndex,
    params: []const Ast.Node.Index,
) StmtCategory {
    if (params.len != 0) return .other;
    const name_bytes = ast.tokenSlice(builtin_token);
    if (std.mem.eql(u8, name_bytes, "@trap"))
        return .trap_call;
    return .other;
}

fn isDiscardIdent(ast: *const Ast, node: Ast.Node.Index) bool {
    return isMatchingIdent(ast, node, "_");
}

fn isUndefinedIdent(ast: *const Ast, node: Ast.Node.Index) bool {
    return isMatchingIdent(ast, node, "undefined");
}

fn isTrueIdent(ast: *const Ast, node: Ast.Node.Index) bool {
    return isMatchingIdent(ast, node, "true");
}

fn isFalseIdent(ast: *const Ast, node: Ast.Node.Index) bool {
    return isMatchingIdent(ast, node, "false");
}

fn isMatchingIdent(ast: *const Ast, node: Ast.Node.Index, string: []const u8) bool {
    switch (ast.nodeTag(node)) {
        .identifier => {
            const token_index = ast.nodeMainToken(node);
            const name_bytes = ast.tokenSlice(token_index);
            return std.mem.eql(u8, name_bytes, string);
        },
        else => return false,
    }
}

fn isEmptyBlock(ast: *const Ast, node: Ast.Node.Index) bool {
    switch (ast.nodeTag(node)) {
        .block_two => {
            const opt_lhs, const opt_rhs = ast.nodeData(node).opt_node_and_opt_node;
            return opt_lhs == .none and opt_rhs == .none;
        },
        else => return false,
    }
}
