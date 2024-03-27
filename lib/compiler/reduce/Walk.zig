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
    const node_tags = ast.nodes.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);
    const token_tags = ast.tokens.items(.tag);

    for (members) |member_node| {
        const name_token = switch (node_tags[member_node]) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => main_tokens[member_node] + 1,

            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            .fn_decl,
            => main_tokens[member_node] + 1,

            else => continue,
        };

        assert(token_tags[name_token] == .identifier);
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
    const datas = ast.nodes.items(.data);
    switch (ast.nodes.items(.tag)[decl]) {
        .fn_decl => {
            const fn_proto = datas[decl].lhs;
            try walkExpression(w, fn_proto);
            const body_node = datas[decl].rhs;
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

        .@"usingnamespace" => {
            try w.transformations.append(.{ .delete_node = decl });
            const expr = datas[decl].lhs;
            try walkExpression(w, expr);
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => try walkGlobalVarDecl(w, decl, ast.fullVarDecl(decl).?),

        .test_decl => {
            try w.transformations.append(.{ .delete_node = decl });
            try walkExpression(w, datas[decl].rhs);
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
    const token_tags = ast.tokens.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);
    const node_tags = ast.nodes.items(.tag);
    const datas = ast.nodes.items(.data);
    switch (node_tags[node]) {
        .identifier => {
            const name_ident = main_tokens[node];
            assert(token_tags[name_ident] == .identifier);
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
        => {
            const statements = [2]Ast.Node.Index{ datas[node].lhs, datas[node].rhs };
            if (datas[node].lhs == 0) {
                return walkBlock(w, node, statements[0..0]);
            } else if (datas[node].rhs == 0) {
                return walkBlock(w, node, statements[0..1]);
            } else {
                return walkBlock(w, node, statements[0..2]);
            }
        },
        .block,
        .block_semicolon,
        => {
            const statements = ast.extra_data[datas[node].lhs..datas[node].rhs];
            return walkBlock(w, node, statements);
        },

        .@"errdefer" => {
            const expr = datas[node].rhs;
            return walkExpression(w, expr);
        },

        .@"defer" => {
            const expr = datas[node].rhs;
            return walkExpression(w, expr);
        },
        .@"comptime", .@"nosuspend" => {
            const block = datas[node].lhs;
            return walkExpression(w, block);
        },

        .@"suspend" => {
            const body = datas[node].lhs;
            return walkExpression(w, body);
        },

        .@"catch" => {
            try walkExpression(w, datas[node].lhs); // target
            try walkExpression(w, datas[node].rhs); // fallback
        },

        .field_access => {
            const field_access = datas[node];
            try walkExpression(w, field_access.lhs);
        },

        .error_union,
        .switch_range,
        => {
            const infix = datas[node];
            try walkExpression(w, infix.lhs);
            return walkExpression(w, infix.rhs);
        },
        .for_range => {
            const infix = datas[node];
            try walkExpression(w, infix.lhs);
            if (infix.rhs != 0) {
                return walkExpression(w, infix.rhs);
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
        .@"orelse",
        => {
            const infix = datas[node];
            try walkExpression(w, infix.lhs);
            try walkExpression(w, infix.rhs);
        },

        .assign_destructure => {
            const full = ast.assignDestructure(node);
            for (full.ast.variables) |variable_node| {
                switch (node_tags[variable_node]) {
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
        => {
            return walkExpression(w, datas[node].lhs);
        },

        .@"try",
        .@"resume",
        .@"await",
        => {
            return walkExpression(w, datas[node].lhs);
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
        .async_call_one,
        .async_call_one_comma,
        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return walkCall(w, ast.fullCall(&buf, node).?);
        },

        .array_access => {
            const suffix = datas[node];
            try walkExpression(w, suffix.lhs);
            try walkExpression(w, suffix.rhs);
        },

        .slice_open, .slice, .slice_sentinel => return walkSlice(w, node, ast.fullSlice(node).?),

        .deref => {
            try walkExpression(w, datas[node].lhs);
        },

        .unwrap_optional => {
            try walkExpression(w, datas[node].lhs);
        },

        .@"break" => {
            const label_token = datas[node].lhs;
            const target = datas[node].rhs;
            if (label_token == 0 and target == 0) {
                // no expressions
            } else if (label_token == 0 and target != 0) {
                try walkExpression(w, target);
            } else if (label_token != 0 and target == 0) {
                try walkIdentifier(w, label_token);
            } else if (label_token != 0 and target != 0) {
                try walkExpression(w, target);
            }
        },

        .@"continue" => {
            const label = datas[node].lhs;
            if (label != 0) {
                return walkIdentifier(w, label); // label
            }
        },

        .@"return" => {
            if (datas[node].lhs != 0) {
                try walkExpression(w, datas[node].lhs);
            }
        },

        .grouped_expression => {
            try walkExpression(w, datas[node].lhs);
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
            const error_token = main_tokens[node];
            const lbrace = error_token + 1;
            const rbrace = datas[node].rhs;

            var i = lbrace + 1;
            while (i < rbrace) : (i += 1) {
                switch (token_tags[i]) {
                    .doc_comment => unreachable, // TODO
                    .identifier => try walkIdentifier(w, i),
                    .comma => {},
                    else => unreachable,
                }
            }
        },

        .builtin_call_two, .builtin_call_two_comma => {
            if (datas[node].lhs == 0) {
                return walkBuiltinCall(w, node, &.{});
            } else if (datas[node].rhs == 0) {
                return walkBuiltinCall(w, node, &.{datas[node].lhs});
            } else {
                return walkBuiltinCall(w, node, &.{ datas[node].lhs, datas[node].rhs });
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = ast.extra_data[datas[node].lhs..datas[node].rhs];
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
            if (datas[node].rhs != 0) {
                return walkExpression(w, datas[node].rhs);
            }
        },

        .@"switch",
        .switch_comma,
        => {
            const condition = datas[node].lhs;
            const extra = ast.extraData(datas[node].rhs, Ast.Node.SubRange);
            const cases = ast.extra_data[extra.start..extra.end];

            try walkExpression(w, condition); // condition expression
            try walkExpressions(w, cases);
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
            return walkIdentifier(w, main_tokens[node]); // name
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
        .@"usingnamespace" => unreachable,
        .test_decl => unreachable,
        .asm_output => unreachable,
        .asm_input => unreachable,
    }
}

fn walkGlobalVarDecl(w: *Walk, decl_node: Ast.Node.Index, var_decl: Ast.full.VarDecl) Error!void {
    _ = decl_node;

    if (var_decl.ast.type_node != 0) {
        try walkExpression(w, var_decl.ast.type_node);
    }

    if (var_decl.ast.align_node != 0) {
        try walkExpression(w, var_decl.ast.align_node);
    }

    if (var_decl.ast.addrspace_node != 0) {
        try walkExpression(w, var_decl.ast.addrspace_node);
    }

    if (var_decl.ast.section_node != 0) {
        try walkExpression(w, var_decl.ast.section_node);
    }

    if (var_decl.ast.init_node != 0) {
        if (!isUndefinedIdent(w.ast, var_decl.ast.init_node)) {
            try w.transformations.append(.{ .replace_with_undef = var_decl.ast.init_node });
        }
        try walkExpression(w, var_decl.ast.init_node);
    }
}

fn walkLocalVarDecl(w: *Walk, var_decl: Ast.full.VarDecl) Error!void {
    try walkIdentifierNew(w, var_decl.ast.mut_token + 1); // name

    if (var_decl.ast.type_node != 0) {
        try walkExpression(w, var_decl.ast.type_node);
    }

    if (var_decl.ast.align_node != 0) {
        try walkExpression(w, var_decl.ast.align_node);
    }

    if (var_decl.ast.addrspace_node != 0) {
        try walkExpression(w, var_decl.ast.addrspace_node);
    }

    if (var_decl.ast.section_node != 0) {
        try walkExpression(w, var_decl.ast.section_node);
    }

    if (var_decl.ast.init_node != 0) {
        if (!isUndefinedIdent(w.ast, var_decl.ast.init_node)) {
            try w.transformations.append(.{ .replace_with_undef = var_decl.ast.init_node });
        }
        try walkExpression(w, var_decl.ast.init_node);
    }
}

fn walkContainerField(w: *Walk, field: Ast.full.ContainerField) Error!void {
    if (field.ast.type_expr != 0) {
        try walkExpression(w, field.ast.type_expr); // type
    }
    if (field.ast.align_expr != 0) {
        try walkExpression(w, field.ast.align_expr); // alignment
    }
    if (field.ast.value_expr != 0) {
        try walkExpression(w, field.ast.value_expr); // value
    }
}

fn walkBlock(
    w: *Walk,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
) Error!void {
    _ = block_node;
    const ast = w.ast;
    const node_tags = ast.nodes.items(.tag);

    for (statements) |stmt| {
        switch (node_tags[stmt]) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                const var_decl = ast.fullVarDecl(stmt).?;
                if (var_decl.ast.init_node != 0 and
                    isUndefinedIdent(w.ast, var_decl.ast.init_node))
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
    if (array_type.ast.sentinel != 0) {
        try walkExpression(w, array_type.ast.sentinel);
    }
    return walkExpression(w, array_type.ast.elem_type);
}

fn walkArrayInit(w: *Walk, array_init: Ast.full.ArrayInit) Error!void {
    if (array_init.ast.type_expr != 0) {
        try walkExpression(w, array_init.ast.type_expr); // T
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
    if (struct_init.ast.type_expr != 0) {
        try walkExpression(w, struct_init.ast.type_expr); // T
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
    if (slice.ast.end != 0) {
        try walkExpression(w, slice.ast.end);
    }
    if (slice.ast.sentinel != 0) {
        try walkExpression(w, slice.ast.sentinel);
    }
}

fn walkIdentifier(w: *Walk, name_ident: Ast.TokenIndex) Error!void {
    const ast = w.ast;
    const token_tags = ast.tokens.items(.tag);
    assert(token_tags[name_ident] == .identifier);
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
    if (container_decl.ast.arg != 0) {
        try walkExpression(w, container_decl.ast.arg);
    }
    try walkMembers(w, container_decl.ast.members);
}

fn walkBuiltinCall(
    w: *Walk,
    call_node: Ast.Node.Index,
    params: []const Ast.Node.Index,
) Error!void {
    const ast = w.ast;
    const main_tokens = ast.nodes.items(.main_token);
    const builtin_token = main_tokens[call_node];
    const builtin_name = ast.tokenSlice(builtin_token);
    const info = BuiltinFn.list.get(builtin_name).?;
    switch (info.tag) {
        .import => {
            const operand_node = params[0];
            const str_lit_token = main_tokens[operand_node];
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
            if (param.type_expr != 0) {
                try walkExpression(w, param.type_expr);
            }
        }
    }

    if (fn_proto.ast.align_expr != 0) {
        try walkExpression(w, fn_proto.ast.align_expr);
    }

    if (fn_proto.ast.addrspace_expr != 0) {
        try walkExpression(w, fn_proto.ast.addrspace_expr);
    }

    if (fn_proto.ast.section_expr != 0) {
        try walkExpression(w, fn_proto.ast.section_expr);
    }

    if (fn_proto.ast.callconv_expr != 0) {
        try walkExpression(w, fn_proto.ast.callconv_expr);
    }

    try walkExpression(w, fn_proto.ast.return_type);
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
    assert(while_node.ast.cond_expr != 0);
    assert(while_node.ast.then_expr != 0);

    // Perform these transformations in this priority order:
    // 1. If the `else` expression is missing or an empty block, replace the condition with `if (true)` if it is not already.
    // 2. If the `then` block is empty, replace the condition with `if (false)` if it is not already.
    // 3. If the condition is `if (true)`, replace the `if` expression with the contents of the `then` expression.
    // 4. If the condition is `if (false)`, replace the `if` expression with the contents of the `else` expression.
    if (!isTrueIdent(w.ast, while_node.ast.cond_expr) and
        (while_node.ast.else_expr == 0 or isEmptyBlock(w.ast, while_node.ast.else_expr)))
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
            .replacement = while_node.ast.else_expr,
        } });
    }

    try walkExpression(w, while_node.ast.cond_expr); // condition

    if (while_node.ast.cont_expr != 0) {
        try walkExpression(w, while_node.ast.cont_expr);
    }

    if (while_node.ast.then_expr != 0) {
        try walkExpression(w, while_node.ast.then_expr);
    }
    if (while_node.ast.else_expr != 0) {
        try walkExpression(w, while_node.ast.else_expr);
    }
}

fn walkFor(w: *Walk, for_node: Ast.full.For) Error!void {
    try walkParamList(w, for_node.ast.inputs);
    if (for_node.ast.then_expr != 0) {
        try walkExpression(w, for_node.ast.then_expr);
    }
    if (for_node.ast.else_expr != 0) {
        try walkExpression(w, for_node.ast.else_expr);
    }
}

fn walkIf(w: *Walk, node_index: Ast.Node.Index, if_node: Ast.full.If) Error!void {
    assert(if_node.ast.cond_expr != 0);
    assert(if_node.ast.then_expr != 0);

    // Perform these transformations in this priority order:
    // 1. If the `else` expression is missing or an empty block, replace the condition with `if (true)` if it is not already.
    // 2. If the `then` block is empty, replace the condition with `if (false)` if it is not already.
    // 3. If the condition is `if (true)`, replace the `if` expression with the contents of the `then` expression.
    // 4. If the condition is `if (false)`, replace the `if` expression with the contents of the `else` expression.
    if (!isTrueIdent(w.ast, if_node.ast.cond_expr) and
        (if_node.ast.else_expr == 0 or isEmptyBlock(w.ast, if_node.ast.else_expr)))
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
            .replacement = if_node.ast.else_expr,
        } });
    }

    try walkExpression(w, if_node.ast.cond_expr); // condition

    if (if_node.ast.then_expr != 0) {
        try walkExpression(w, if_node.ast.then_expr);
    }
    if (if_node.ast.else_expr != 0) {
        try walkExpression(w, if_node.ast.else_expr);
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
    const node_tags = ast.nodes.items(.tag);
    const datas = ast.nodes.items(.data);
    var statements_buf: [2]Ast.Node.Index = undefined;
    const statements = switch (node_tags[body_node]) {
        .block_two,
        .block_two_semicolon,
        => blk: {
            statements_buf[0..2].* = .{ datas[body_node].lhs, datas[body_node].rhs };
            break :blk if (datas[body_node].lhs == 0)
                statements_buf[0..0]
            else if (datas[body_node].rhs == 0)
                statements_buf[0..1]
            else
                statements_buf[0..2];
        },

        .block,
        .block_semicolon,
        => ast.extra_data[datas[body_node].lhs..datas[body_node].rhs],

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
    const node_tags = ast.nodes.items(.tag);
    const datas = ast.nodes.items(.data);
    const main_tokens = ast.nodes.items(.main_token);
    switch (node_tags[stmt]) {
        .builtin_call_two, .builtin_call_two_comma => {
            if (datas[stmt].lhs == 0) {
                return categorizeBuiltinCall(ast, main_tokens[stmt], &.{});
            } else if (datas[stmt].rhs == 0) {
                return categorizeBuiltinCall(ast, main_tokens[stmt], &.{datas[stmt].lhs});
            } else {
                return categorizeBuiltinCall(ast, main_tokens[stmt], &.{ datas[stmt].lhs, datas[stmt].rhs });
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = ast.extra_data[datas[stmt].lhs..datas[stmt].rhs];
            return categorizeBuiltinCall(ast, main_tokens[stmt], params);
        },
        .assign => {
            const infix = datas[stmt];
            if (isDiscardIdent(ast, infix.lhs) and node_tags[infix.rhs] == .identifier) {
                const name_bytes = ast.tokenSlice(main_tokens[infix.rhs]);
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
    const node_tags = ast.nodes.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);
    switch (node_tags[node]) {
        .identifier => {
            const token_index = main_tokens[node];
            const name_bytes = ast.tokenSlice(token_index);
            return std.mem.eql(u8, name_bytes, string);
        },
        else => return false,
    }
}

fn isEmptyBlock(ast: *const Ast, node: Ast.Node.Index) bool {
    const node_tags = ast.nodes.items(.tag);
    const node_data = ast.nodes.items(.data);
    switch (node_tags[node]) {
        .block_two => {
            return node_data[node].lhs == 0 and node_data[node].rhs == 0;
        },
        else => return false,
    }
}
