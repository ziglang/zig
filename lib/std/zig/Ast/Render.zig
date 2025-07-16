const std = @import("../../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const meta = std.meta;
const Ast = std.zig.Ast;
const Token = std.zig.Token;
const primitives = std.zig.primitives;
const Writer = std.io.Writer;

const Render = @This();

gpa: Allocator,
ais: *AutoIndentingStream,
tree: Ast,
fixups: Fixups,

const indent_delta = 4;
const asm_indent_delta = 2;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering.
    OutOfMemory,
    /// Transitive failure from
    WriteFailed,
};

pub const Fixups = struct {
    /// The key is the mut token (`var`/`const`) of the variable declaration
    /// that should have a `_ = foo;` inserted afterwards.
    unused_var_decls: std.AutoHashMapUnmanaged(Ast.TokenIndex, void) = .empty,
    /// The functions in this unordered set of AST fn decl nodes will render
    /// with a function body of `@trap()` instead, with all parameters
    /// discarded.
    gut_functions: std.AutoHashMapUnmanaged(Ast.Node.Index, void) = .empty,
    /// These global declarations will be omitted.
    omit_nodes: std.AutoHashMapUnmanaged(Ast.Node.Index, void) = .empty,
    /// These expressions will be replaced with the string value.
    replace_nodes_with_string: std.AutoHashMapUnmanaged(Ast.Node.Index, []const u8) = .empty,
    /// The string value will be inserted directly after the node.
    append_string_after_node: std.AutoHashMapUnmanaged(Ast.Node.Index, []const u8) = .empty,
    /// These nodes will be replaced with a different node.
    replace_nodes_with_node: std.AutoHashMapUnmanaged(Ast.Node.Index, Ast.Node.Index) = .empty,
    /// Change all identifier names matching the key to be value instead.
    rename_identifiers: std.StringArrayHashMapUnmanaged([]const u8) = .empty,

    /// All `@import` builtin calls which refer to a file path will be prefixed
    /// with this path.
    rebase_imported_paths: ?[]const u8 = null,

    pub fn count(f: Fixups) usize {
        return f.unused_var_decls.count() +
            f.gut_functions.count() +
            f.omit_nodes.count() +
            f.replace_nodes_with_string.count() +
            f.append_string_after_node.count() +
            f.replace_nodes_with_node.count() +
            f.rename_identifiers.count() +
            @intFromBool(f.rebase_imported_paths != null);
    }

    pub fn clearRetainingCapacity(f: *Fixups) void {
        f.unused_var_decls.clearRetainingCapacity();
        f.gut_functions.clearRetainingCapacity();
        f.omit_nodes.clearRetainingCapacity();
        f.replace_nodes_with_string.clearRetainingCapacity();
        f.append_string_after_node.clearRetainingCapacity();
        f.replace_nodes_with_node.clearRetainingCapacity();
        f.rename_identifiers.clearRetainingCapacity();

        f.rebase_imported_paths = null;
    }

    pub fn deinit(f: *Fixups, gpa: Allocator) void {
        f.unused_var_decls.deinit(gpa);
        f.gut_functions.deinit(gpa);
        f.omit_nodes.deinit(gpa);
        f.replace_nodes_with_string.deinit(gpa);
        f.append_string_after_node.deinit(gpa);
        f.replace_nodes_with_node.deinit(gpa);
        f.rename_identifiers.deinit(gpa);
        f.* = undefined;
    }
};

pub fn renderTree(gpa: Allocator, w: *Writer, tree: Ast, fixups: Fixups) Error!void {
    assert(tree.errors.len == 0); // Cannot render an invalid tree.
    var auto_indenting_stream: AutoIndentingStream = .init(gpa, w, indent_delta);
    defer auto_indenting_stream.deinit();
    var r: Render = .{
        .gpa = gpa,
        .ais = &auto_indenting_stream,
        .tree = tree,
        .fixups = fixups,
    };

    // Render all the line comments at the beginning of the file.
    const comment_end_loc = tree.tokenStart(0);
    _ = try renderComments(&r, 0, comment_end_loc);

    if (tree.tokenTag(0) == .container_doc_comment) {
        try renderContainerDocComments(&r, 0);
    }

    switch (tree.mode) {
        .zig => try renderMembers(&r, tree.rootDecls()),
        .zon => {
            try renderExpression(
                &r,
                tree.rootDecls()[0],
                .newline,
            );
        },
    }

    if (auto_indenting_stream.disabled_offset) |disabled_offset| {
        try writeFixingWhitespace(auto_indenting_stream.underlying_writer, tree.source[disabled_offset..]);
    }
}

/// Render all members in the given slice, keeping empty lines where appropriate
fn renderMembers(r: *Render, members: []const Ast.Node.Index) Error!void {
    const tree = r.tree;
    if (members.len == 0) return;
    const container: Container = for (members) |member| {
        if (tree.fullContainerField(member)) |field| if (!field.ast.tuple_like) break .other;
    } else .tuple;
    try renderMember(r, container, members[0], .newline);
    for (members[1..]) |member| {
        try renderExtraNewline(r, member);
        try renderMember(r, container, member, .newline);
    }
}

const Container = enum {
    @"enum",
    tuple,
    other,
};

fn renderMember(
    r: *Render,
    container: Container,
    decl: Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    if (r.fixups.omit_nodes.contains(decl)) return;
    try renderDocComments(r, tree.firstToken(decl));
    switch (tree.nodeTag(decl)) {
        .fn_decl => {
            // Some examples:
            // pub extern "foo" fn ...
            // export fn ...
            const fn_proto, const body_node = tree.nodeData(decl).node_and_node;
            const fn_token = tree.nodeMainToken(fn_proto);
            // Go back to the first token we should render here.
            var i = fn_token;
            while (i > 0) {
                i -= 1;
                switch (tree.tokenTag(i)) {
                    .keyword_extern,
                    .keyword_export,
                    .keyword_pub,
                    .string_literal,
                    .keyword_inline,
                    .keyword_noinline,
                    => continue,

                    else => {
                        i += 1;
                        break;
                    },
                }
            }

            while (i < fn_token) : (i += 1) {
                try renderToken(r, i, .space);
            }
            switch (tree.nodeTag(fn_proto)) {
                .fn_proto_one, .fn_proto => {
                    var buf: [1]Ast.Node.Index = undefined;
                    const opt_callconv_expr = if (tree.nodeTag(fn_proto) == .fn_proto_one)
                        tree.fnProtoOne(&buf, fn_proto).ast.callconv_expr
                    else
                        tree.fnProto(fn_proto).ast.callconv_expr;

                    // Keep in sync with logic in `renderFnProto`. Search this file for the marker PROMOTE_CALLCONV_INLINE
                    if (opt_callconv_expr.unwrap()) |callconv_expr| {
                        if (tree.nodeTag(callconv_expr) == .enum_literal) {
                            if (mem.eql(u8, "@\"inline\"", tree.tokenSlice(tree.nodeMainToken(callconv_expr)))) {
                                try ais.underlying_writer.writeAll("inline ");
                            }
                        }
                    }
                },
                .fn_proto_simple, .fn_proto_multi => {},
                else => unreachable,
            }
            try renderExpression(r, fn_proto, .space);
            if (r.fixups.gut_functions.contains(decl)) {
                try ais.pushIndent(.normal);
                const lbrace = tree.nodeMainToken(body_node);
                try renderToken(r, lbrace, .newline);
                try discardAllParams(r, fn_proto);
                try ais.writeAll("@trap();");
                ais.popIndent();
                try ais.insertNewline();
                try renderToken(r, tree.lastToken(body_node), space); // rbrace
            } else if (r.fixups.unused_var_decls.count() != 0) {
                try ais.pushIndent(.normal);
                const lbrace = tree.nodeMainToken(body_node);
                try renderToken(r, lbrace, .newline);

                var fn_proto_buf: [1]Ast.Node.Index = undefined;
                const full_fn_proto = tree.fullFnProto(&fn_proto_buf, fn_proto).?;
                var it = full_fn_proto.iterate(&tree);
                while (it.next()) |param| {
                    const name_ident = param.name_token.?;
                    assert(tree.tokenTag(name_ident) == .identifier);
                    if (r.fixups.unused_var_decls.contains(name_ident)) {
                        try ais.writeAll("_ = ");
                        try ais.writeAll(tokenSliceForRender(r.tree, name_ident));
                        try ais.writeAll(";\n");
                    }
                }
                var statements_buf: [2]Ast.Node.Index = undefined;
                const statements = tree.blockStatements(&statements_buf, body_node).?;
                return finishRenderBlock(r, body_node, statements, space);
            } else {
                return renderExpression(r, body_node, space);
            }
        },
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            // Extern function prototypes are parsed as these tags.
            // Go back to the first token we should render here.
            const fn_token = tree.nodeMainToken(decl);
            var i = fn_token;
            while (i > 0) {
                i -= 1;
                switch (tree.tokenTag(i)) {
                    .keyword_extern,
                    .keyword_export,
                    .keyword_pub,
                    .string_literal,
                    .keyword_inline,
                    .keyword_noinline,
                    => continue,

                    else => {
                        i += 1;
                        break;
                    },
                }
            }
            while (i < fn_token) : (i += 1) {
                try renderToken(r, i, .space);
            }
            try renderExpression(r, decl, .none);
            return renderToken(r, tree.lastToken(decl) + 1, space); // semicolon
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            try ais.pushSpace(.semicolon);
            try renderVarDecl(r, tree.fullVarDecl(decl).?, false, .semicolon);
            ais.popSpace();
        },

        .test_decl => {
            const test_token = tree.nodeMainToken(decl);
            const opt_name_token, const block_node = tree.nodeData(decl).opt_token_and_node;
            try renderToken(r, test_token, .space);
            if (opt_name_token.unwrap()) |name_token| {
                switch (tree.tokenTag(name_token)) {
                    .string_literal => try renderToken(r, name_token, .space),
                    .identifier => try renderIdentifier(r, name_token, .space, .preserve_when_shadowing),
                    else => unreachable,
                }
            }
            try renderExpression(r, block_node, space);
        },

        .container_field_init,
        .container_field_align,
        .container_field,
        => return renderContainerField(r, container, tree.fullContainerField(decl).?, space),

        .@"comptime" => return renderExpression(r, decl, space),

        .root => unreachable,
        else => unreachable,
    }
}

/// Render all expressions in the slice, keeping empty lines where appropriate
fn renderExpressions(r: *Render, expressions: []const Ast.Node.Index, space: Space) Error!void {
    if (expressions.len == 0) return;
    try renderExpression(r, expressions[0], space);
    for (expressions[1..]) |expression| {
        try renderExtraNewline(r, expression);
        try renderExpression(r, expression, space);
    }
}

fn renderExpression(r: *Render, node: Ast.Node.Index, space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    if (r.fixups.replace_nodes_with_string.get(node)) |replacement| {
        try ais.writeAll(replacement);
        try renderOnlySpace(r, space);
        return;
    } else if (r.fixups.replace_nodes_with_node.get(node)) |replacement| {
        return renderExpression(r, replacement, space);
    }
    switch (tree.nodeTag(node)) {
        .identifier => {
            const token_index = tree.nodeMainToken(node);
            return renderIdentifier(r, token_index, space, .preserve_when_shadowing);
        },

        .number_literal,
        .char_literal,
        .unreachable_literal,
        .anyframe_literal,
        .string_literal,
        => return renderToken(r, tree.nodeMainToken(node), space),

        .multiline_string_literal => {
            try ais.maybeInsertNewline();

            const first_tok, const last_tok = tree.nodeData(node).token_and_token;
            for (first_tok..last_tok + 1) |i| {
                try renderToken(r, @intCast(i), .newline);
            }

            const next_token = last_tok + 1;
            const next_token_tag = tree.tokenTag(next_token);

            // dedent the next thing that comes after a multiline string literal
            if (!ais.indentStackEmpty() and
                next_token_tag != .colon and
                ((next_token_tag != .semicolon and next_token_tag != .comma) or
                    ais.lastSpaceModeIndent() < ais.currentIndent()))
            {
                ais.popIndent();
                try ais.pushIndent(.normal);
            }

            switch (space) {
                .none, .space, .newline, .skip => {},
                .semicolon => if (next_token_tag == .semicolon) try renderTokenOverrideSpaceMode(r, next_token, .newline, .semicolon),
                .comma => if (next_token_tag == .comma) try renderTokenOverrideSpaceMode(r, next_token, .newline, .comma),
                .comma_space => if (next_token_tag == .comma) try renderToken(r, next_token, .space),
            }
        },

        .error_value => {
            const main_token = tree.nodeMainToken(node);
            try renderToken(r, main_token, .none);
            try renderToken(r, main_token + 1, .none);
            return renderIdentifier(r, main_token + 2, space, .eagerly_unquote);
        },

        .block_two,
        .block_two_semicolon,
        .block,
        .block_semicolon,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const statements = tree.blockStatements(&buf, node).?;
            return renderBlock(r, node, statements, space);
        },

        .@"errdefer" => {
            const defer_token = tree.nodeMainToken(node);
            const maybe_payload_token, const expr = tree.nodeData(node).opt_token_and_node;

            try renderToken(r, defer_token, .space);
            if (maybe_payload_token.unwrap()) |payload_token| {
                try renderToken(r, payload_token - 1, .none); // |
                try renderIdentifier(r, payload_token, .none, .preserve_when_shadowing); // identifier
                try renderToken(r, payload_token + 1, .space); // |
            }
            return renderExpression(r, expr, space);
        },

        .@"defer",
        .@"comptime",
        .@"nosuspend",
        .@"suspend",
        => {
            const main_token = tree.nodeMainToken(node);
            const item = tree.nodeData(node).node;
            try renderToken(r, main_token, .space);
            return renderExpression(r, item, space);
        },

        .@"catch" => {
            const main_token = tree.nodeMainToken(node);
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            const fallback_first = tree.firstToken(rhs);

            const same_line = tree.tokensOnSameLine(main_token, fallback_first);
            const after_op_space = if (same_line) Space.space else Space.newline;

            try renderExpression(r, lhs, .space); // target

            try ais.pushIndent(.normal);
            if (tree.tokenTag(fallback_first - 1) == .pipe) {
                try renderToken(r, main_token, .space); // catch keyword
                try renderToken(r, main_token + 1, .none); // pipe
                try renderIdentifier(r, main_token + 2, .none, .preserve_when_shadowing); // payload identifier
                try renderToken(r, main_token + 3, after_op_space); // pipe
            } else {
                assert(tree.tokenTag(fallback_first - 1) == .keyword_catch);
                try renderToken(r, main_token, after_op_space); // catch keyword
            }
            try renderExpression(r, rhs, space); // fallback
            ais.popIndent();
        },

        .field_access => {
            const lhs, const name_token = tree.nodeData(node).node_and_token;
            const dot_token = name_token - 1;

            try ais.pushIndent(.field_access);
            try renderExpression(r, lhs, .none);

            // Allow a line break between the lhs and the dot if the lhs and rhs
            // are on different lines.
            const lhs_last_token = tree.lastToken(lhs);
            const same_line = tree.tokensOnSameLine(lhs_last_token, name_token);
            if (!same_line and !hasComment(tree, lhs_last_token, dot_token)) try ais.insertNewline();

            try renderToken(r, dot_token, .none);

            try renderIdentifier(r, name_token, space, .eagerly_unquote); // field
            ais.popIndent();
        },

        .error_union,
        .switch_range,
        => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            try renderExpression(r, lhs, .none);
            try renderToken(r, tree.nodeMainToken(node), .none);
            return renderExpression(r, rhs, space);
        },
        .for_range => {
            const start, const opt_end = tree.nodeData(node).node_and_opt_node;
            try renderExpression(r, start, .none);
            if (opt_end.unwrap()) |end| {
                try renderToken(r, tree.nodeMainToken(node), .none);
                return renderExpression(r, end, space);
            } else {
                return renderToken(r, tree.nodeMainToken(node), space);
            }
        },

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
        => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            try renderExpression(r, lhs, .space);
            const op_token = tree.nodeMainToken(node);
            try ais.pushIndent(.after_equals);
            if (tree.tokensOnSameLine(op_token, op_token + 1)) {
                try renderToken(r, op_token, .space);
            } else {
                try renderToken(r, op_token, .newline);
            }
            try renderExpression(r, rhs, space);
            ais.popIndent();
        },

        .add,
        .add_wrap,
        .add_sat,
        .array_cat,
        .array_mult,
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
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            try renderExpression(r, lhs, .space);
            const op_token = tree.nodeMainToken(node);
            try ais.pushIndent(.binop);
            if (tree.tokensOnSameLine(op_token, op_token + 1)) {
                try renderToken(r, op_token, .space);
            } else {
                try renderToken(r, op_token, .newline);
            }
            try renderExpression(r, rhs, space);
            ais.popIndent();
        },

        .assign_destructure => {
            const full = tree.assignDestructure(node);
            if (full.comptime_token) |comptime_token| {
                try renderToken(r, comptime_token, .space);
            }

            for (full.ast.variables, 0..) |variable_node, i| {
                const variable_space: Space = if (i == full.ast.variables.len - 1) .space else .comma_space;
                switch (tree.nodeTag(variable_node)) {
                    .global_var_decl,
                    .local_var_decl,
                    .simple_var_decl,
                    .aligned_var_decl,
                    => {
                        try renderVarDecl(r, tree.fullVarDecl(variable_node).?, true, variable_space);
                    },
                    else => try renderExpression(r, variable_node, variable_space),
                }
            }
            try ais.pushIndent(.after_equals);
            if (tree.tokensOnSameLine(full.ast.equal_token, full.ast.equal_token + 1)) {
                try renderToken(r, full.ast.equal_token, .space);
            } else {
                try renderToken(r, full.ast.equal_token, .newline);
            }
            try renderExpression(r, full.ast.value_expr, space);
            ais.popIndent();
        },

        .bit_not,
        .bool_not,
        .negation,
        .negation_wrap,
        .optional_type,
        .address_of,
        => {
            try renderToken(r, tree.nodeMainToken(node), .none);
            return renderExpression(r, tree.nodeData(node).node, space);
        },

        .@"try",
        .@"resume",
        => {
            try renderToken(r, tree.nodeMainToken(node), .space);
            return renderExpression(r, tree.nodeData(node).node, space);
        },

        .array_type,
        .array_type_sentinel,
        => return renderArrayType(r, tree.fullArrayType(node).?, space),

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => return renderPtrType(r, tree.fullPtrType(node).?, space),

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
            return renderArrayInit(r, tree.fullArrayInit(&elements, node).?, space);
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
            return renderStructInit(r, node, tree.fullStructInit(&buf, node).?, space);
        },

        .call_one,
        .call_one_comma,
        .call,
        .call_comma,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return renderCall(r, tree.fullCall(&buf, node).?, space);
        },

        .array_access => {
            const lhs, const rhs = tree.nodeData(node).node_and_node;
            const lbracket = tree.firstToken(rhs) - 1;
            const rbracket = tree.lastToken(rhs) + 1;
            const one_line = tree.tokensOnSameLine(lbracket, rbracket);
            const inner_space = if (one_line) Space.none else Space.newline;
            try renderExpression(r, lhs, .none);
            try ais.pushIndent(.normal);
            try renderToken(r, lbracket, inner_space); // [
            try renderExpression(r, rhs, inner_space);
            ais.popIndent();
            return renderToken(r, rbracket, space); // ]
        },

        .slice_open,
        .slice,
        .slice_sentinel,
        => return renderSlice(r, node, tree.fullSlice(node).?, space),

        .deref => {
            try renderExpression(r, tree.nodeData(node).node, .none);
            return renderToken(r, tree.nodeMainToken(node), space);
        },

        .unwrap_optional => {
            const lhs, const question_mark = tree.nodeData(node).node_and_token;
            const dot_token = question_mark - 1;
            try renderExpression(r, lhs, .none);
            try renderToken(r, dot_token, .none);
            return renderToken(r, question_mark, space);
        },

        .@"break", .@"continue" => {
            const main_token = tree.nodeMainToken(node);
            const opt_label_token, const opt_target = tree.nodeData(node).opt_token_and_opt_node;
            if (opt_label_token == .none and opt_target == .none) {
                try renderToken(r, main_token, space); // break/continue
            } else if (opt_label_token == .none and opt_target != .none) {
                const target = opt_target.unwrap().?;
                try renderToken(r, main_token, .space); // break/continue
                try renderExpression(r, target, space);
            } else if (opt_label_token != .none and opt_target == .none) {
                const label_token = opt_label_token.unwrap().?;
                try renderToken(r, main_token, .space); // break/continue
                try renderToken(r, label_token - 1, .none); // :
                try renderIdentifier(r, label_token, space, .eagerly_unquote); // identifier
            } else if (opt_label_token != .none and opt_target != .none) {
                const label_token = opt_label_token.unwrap().?;
                const target = opt_target.unwrap().?;
                try renderToken(r, main_token, .space); // break/continue
                try renderToken(r, label_token - 1, .none); // :
                try renderIdentifier(r, label_token, .space, .eagerly_unquote); // identifier
                try renderExpression(r, target, space);
            } else unreachable;
        },

        .@"return" => {
            if (tree.nodeData(node).opt_node.unwrap()) |expr| {
                try renderToken(r, tree.nodeMainToken(node), .space);
                try renderExpression(r, expr, space);
            } else {
                try renderToken(r, tree.nodeMainToken(node), space);
            }
        },

        .grouped_expression => {
            const expr, const rparen = tree.nodeData(node).node_and_token;
            try ais.pushIndent(.normal);
            try renderToken(r, tree.nodeMainToken(node), .none); // lparen
            try renderExpression(r, expr, .none);
            ais.popIndent();
            return renderToken(r, rparen, space);
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
            return renderContainerDecl(r, node, tree.fullContainerDecl(&buf, node).?, space);
        },

        .error_set_decl => {
            const error_token = tree.nodeMainToken(node);
            const lbrace, const rbrace = tree.nodeData(node).token_and_token;

            try renderToken(r, error_token, .none);

            if (lbrace + 1 == rbrace) {
                // There is nothing between the braces so render condensed: `error{}`
                try renderToken(r, lbrace, .none);
                return renderToken(r, rbrace, space);
            } else if (lbrace + 2 == rbrace and tree.tokenTag(lbrace + 1) == .identifier) {
                // There is exactly one member and no trailing comma or
                // comments, so render without surrounding spaces: `error{Foo}`
                try renderToken(r, lbrace, .none);
                try renderIdentifier(r, lbrace + 1, .none, .eagerly_unquote); // identifier
                return renderToken(r, rbrace, space);
            } else if (tree.tokenTag(rbrace - 1) == .comma) {
                // There is a trailing comma so render each member on a new line.
                try ais.pushIndent(.normal);
                try renderToken(r, lbrace, .newline);
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    if (i > lbrace + 1) try renderExtraNewlineToken(r, i);
                    switch (tree.tokenTag(i)) {
                        .doc_comment => try renderToken(r, i, .newline),
                        .identifier => {
                            try ais.pushSpace(.comma);
                            try renderIdentifier(r, i, .comma, .eagerly_unquote);
                            ais.popSpace();
                        },
                        .comma => {},
                        else => unreachable,
                    }
                }
                ais.popIndent();
                return renderToken(r, rbrace, space);
            } else {
                // There is no trailing comma so render everything on one line.
                try renderToken(r, lbrace, .space);
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    switch (tree.tokenTag(i)) {
                        .doc_comment => unreachable, // TODO
                        .identifier => try renderIdentifier(r, i, .comma_space, .eagerly_unquote),
                        .comma => {},
                        else => unreachable,
                    }
                }
                return renderToken(r, rbrace, space);
            }
        },

        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        => {
            var buf: [2]Ast.Node.Index = undefined;
            const params = tree.builtinCallParams(&buf, node).?;
            return renderBuiltinCall(r, tree.nodeMainToken(node), params, space);
        },

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            var buf: [1]Ast.Node.Index = undefined;
            return renderFnProto(r, tree.fullFnProto(&buf, node).?, space);
        },

        .anyframe_type => {
            const main_token = tree.nodeMainToken(node);
            try renderToken(r, main_token, .none); // anyframe
            try renderToken(r, main_token + 1, .none); // ->
            return renderExpression(r, tree.nodeData(node).token_and_node[1], space);
        },

        .@"switch",
        .switch_comma,
        => {
            const full = tree.switchFull(node);

            if (full.label_token) |label_token| {
                try renderIdentifier(r, label_token, .none, .eagerly_unquote); // label
                try renderToken(r, label_token + 1, .space); // :
            }

            const rparen = tree.lastToken(full.ast.condition) + 1;

            try renderToken(r, full.ast.switch_token, .space); // switch
            try renderToken(r, full.ast.switch_token + 1, .none); // (
            try renderExpression(r, full.ast.condition, .none); // condition expression
            try renderToken(r, rparen, .space); // )

            try ais.pushIndent(.normal);
            if (full.ast.cases.len == 0) {
                try renderToken(r, rparen + 1, .none); // {
            } else {
                try renderToken(r, rparen + 1, .newline); // {
                try ais.pushSpace(.comma);
                try renderExpressions(r, full.ast.cases, .comma);
                ais.popSpace();
            }
            ais.popIndent();
            return renderToken(r, tree.lastToken(node), space); // }
        },

        .switch_case_one,
        .switch_case_inline_one,
        .switch_case,
        .switch_case_inline,
        => return renderSwitchCase(r, tree.fullSwitchCase(node).?, space),

        .while_simple,
        .while_cont,
        .@"while",
        => return renderWhile(r, tree.fullWhile(node).?, space),

        .for_simple,
        .@"for",
        => return renderFor(r, tree.fullFor(node).?, space),

        .if_simple,
        .@"if",
        => return renderIf(r, tree.fullIf(node).?, space),

        .asm_simple,
        .@"asm",
        => return renderAsm(r, tree.fullAsm(node).?, space),

        .enum_literal => {
            try renderToken(r, tree.nodeMainToken(node) - 1, .none); // .
            return renderIdentifier(r, tree.nodeMainToken(node), space, .eagerly_unquote); // name
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

/// Same as `renderExpression`, but afterwards looks for any
/// append_string_after_node fixups to apply
fn renderExpressionFixup(r: *Render, node: Ast.Node.Index, space: Space) Error!void {
    const ais = r.ais;
    try renderExpression(r, node, space);
    if (r.fixups.append_string_after_node.get(node)) |bytes| {
        try ais.writeAll(bytes);
    }
}

fn renderArrayType(
    r: *Render,
    array_type: Ast.full.ArrayType,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const rbracket = tree.firstToken(array_type.ast.elem_type) - 1;
    const one_line = tree.tokensOnSameLine(array_type.ast.lbracket, rbracket);
    const inner_space = if (one_line) Space.none else Space.newline;
    try ais.pushIndent(.normal);
    try renderToken(r, array_type.ast.lbracket, inner_space); // lbracket
    try renderExpression(r, array_type.ast.elem_count, inner_space);
    if (array_type.ast.sentinel.unwrap()) |sentinel| {
        try renderToken(r, tree.firstToken(sentinel) - 1, inner_space); // colon
        try renderExpression(r, sentinel, inner_space);
    }
    ais.popIndent();
    try renderToken(r, rbracket, .none); // rbracket
    return renderExpression(r, array_type.ast.elem_type, space);
}

fn renderPtrType(r: *Render, ptr_type: Ast.full.PtrType, space: Space) Error!void {
    const tree = r.tree;
    const main_token = ptr_type.ast.main_token;
    switch (ptr_type.size) {
        .one => {
            // Since ** tokens exist and the same token is shared by two
            // nested pointer types, we check to see if we are the parent
            // in such a relationship. If so, skip rendering anything for
            // this pointer type and rely on the child to render our asterisk
            // as well when it renders the ** token.
            if (tree.tokenTag(main_token) == .asterisk_asterisk and
                main_token == tree.nodeMainToken(ptr_type.ast.child_type))
            {
                return renderExpression(r, ptr_type.ast.child_type, space);
            }
            try renderToken(r, main_token, .none); // asterisk
        },
        .many => {
            if (ptr_type.ast.sentinel.unwrap()) |sentinel| {
                try renderToken(r, main_token, .none); // lbracket
                try renderToken(r, main_token + 1, .none); // asterisk
                try renderToken(r, main_token + 2, .none); // colon
                try renderExpression(r, sentinel, .none);
                try renderToken(r, tree.lastToken(sentinel) + 1, .none); // rbracket
            } else {
                try renderToken(r, main_token, .none); // lbracket
                try renderToken(r, main_token + 1, .none); // asterisk
                try renderToken(r, main_token + 2, .none); // rbracket
            }
        },
        .c => {
            try renderToken(r, main_token, .none); // lbracket
            try renderToken(r, main_token + 1, .none); // asterisk
            try renderToken(r, main_token + 2, .none); // c
            try renderToken(r, main_token + 3, .none); // rbracket
        },
        .slice => {
            if (ptr_type.ast.sentinel.unwrap()) |sentinel| {
                try renderToken(r, main_token, .none); // lbracket
                try renderToken(r, main_token + 1, .none); // colon
                try renderExpression(r, sentinel, .none);
                try renderToken(r, tree.lastToken(sentinel) + 1, .none); // rbracket
            } else {
                try renderToken(r, main_token, .none); // lbracket
                try renderToken(r, main_token + 1, .none); // rbracket
            }
        },
    }

    if (ptr_type.allowzero_token) |allowzero_token| {
        try renderToken(r, allowzero_token, .space);
    }

    if (ptr_type.ast.align_node.unwrap()) |align_node| {
        const align_first = tree.firstToken(align_node);
        try renderToken(r, align_first - 2, .none); // align
        try renderToken(r, align_first - 1, .none); // lparen
        try renderExpression(r, align_node, .none);
        if (ptr_type.ast.bit_range_start.unwrap()) |bit_range_start| {
            const bit_range_end = ptr_type.ast.bit_range_end.unwrap().?;
            try renderToken(r, tree.firstToken(bit_range_start) - 1, .none); // colon
            try renderExpression(r, bit_range_start, .none);
            try renderToken(r, tree.firstToken(bit_range_end) - 1, .none); // colon
            try renderExpression(r, bit_range_end, .none);
            try renderToken(r, tree.lastToken(bit_range_end) + 1, .space); // rparen
        } else {
            try renderToken(r, tree.lastToken(align_node) + 1, .space); // rparen
        }
    }

    if (ptr_type.ast.addrspace_node.unwrap()) |addrspace_node| {
        const addrspace_first = tree.firstToken(addrspace_node);
        try renderToken(r, addrspace_first - 2, .none); // addrspace
        try renderToken(r, addrspace_first - 1, .none); // lparen
        try renderExpression(r, addrspace_node, .none);
        try renderToken(r, tree.lastToken(addrspace_node) + 1, .space); // rparen
    }

    if (ptr_type.const_token) |const_token| {
        try renderToken(r, const_token, .space);
    }

    if (ptr_type.volatile_token) |volatile_token| {
        try renderToken(r, volatile_token, .space);
    }

    try renderExpression(r, ptr_type.ast.child_type, space);
}

fn renderSlice(
    r: *Render,
    slice_node: Ast.Node.Index,
    slice: Ast.full.Slice,
    space: Space,
) Error!void {
    const tree = r.tree;
    const after_start_space_bool = nodeCausesSliceOpSpace(tree.nodeTag(slice.ast.start)) or
        if (slice.ast.end.unwrap()) |end| nodeCausesSliceOpSpace(tree.nodeTag(end)) else false;
    const after_start_space = if (after_start_space_bool) Space.space else Space.none;
    const after_dots_space = if (slice.ast.end != .none)
        after_start_space
    else if (slice.ast.sentinel != .none) Space.space else Space.none;

    try renderExpression(r, slice.ast.sliced, .none);
    try renderToken(r, slice.ast.lbracket, .none); // lbracket

    const start_last = tree.lastToken(slice.ast.start);
    try renderExpression(r, slice.ast.start, after_start_space);
    try renderToken(r, start_last + 1, after_dots_space); // ellipsis2 ("..")

    if (slice.ast.end.unwrap()) |end| {
        const after_end_space = if (slice.ast.sentinel != .none) Space.space else Space.none;
        try renderExpression(r, end, after_end_space);
    }

    if (slice.ast.sentinel.unwrap()) |sentinel| {
        try renderToken(r, tree.firstToken(sentinel) - 1, .none); // colon
        try renderExpression(r, sentinel, .none);
    }

    try renderToken(r, tree.lastToken(slice_node), space); // rbracket
}

fn renderAsmOutput(
    r: *Render,
    asm_output: Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    assert(tree.nodeTag(asm_output) == .asm_output);
    const symbolic_name = tree.nodeMainToken(asm_output);

    try renderToken(r, symbolic_name - 1, .none); // lbracket
    try renderIdentifier(r, symbolic_name, .none, .eagerly_unquote); // ident
    try renderToken(r, symbolic_name + 1, .space); // rbracket
    try renderToken(r, symbolic_name + 2, .space); // "constraint"
    try renderToken(r, symbolic_name + 3, .none); // lparen

    if (tree.tokenTag(symbolic_name + 4) == .arrow) {
        const type_expr, const rparen = tree.nodeData(asm_output).opt_node_and_token;
        try renderToken(r, symbolic_name + 4, .space); // ->
        try renderExpression(r, type_expr.unwrap().?, Space.none);
        return renderToken(r, rparen, space);
    } else {
        try renderIdentifier(r, symbolic_name + 4, .none, .eagerly_unquote); // ident
        return renderToken(r, symbolic_name + 5, space); // rparen
    }
}

fn renderAsmInput(
    r: *Render,
    asm_input: Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    assert(tree.nodeTag(asm_input) == .asm_input);
    const symbolic_name = tree.nodeMainToken(asm_input);
    const expr, const rparen = tree.nodeData(asm_input).node_and_token;

    try renderToken(r, symbolic_name - 1, .none); // lbracket
    try renderIdentifier(r, symbolic_name, .none, .eagerly_unquote); // ident
    try renderToken(r, symbolic_name + 1, .space); // rbracket
    try renderToken(r, symbolic_name + 2, .space); // "constraint"
    try renderToken(r, symbolic_name + 3, .none); // lparen
    try renderExpression(r, expr, Space.none);
    return renderToken(r, rparen, space);
}

fn renderVarDecl(
    r: *Render,
    var_decl: Ast.full.VarDecl,
    /// Destructures intentionally ignore leading `comptime` tokens.
    ignore_comptime_token: bool,
    /// `comma_space` and `space` are used for destructure LHS decls.
    space: Space,
) Error!void {
    try renderVarDeclWithoutFixups(r, var_decl, ignore_comptime_token, space);
    if (r.fixups.unused_var_decls.contains(var_decl.ast.mut_token + 1)) {
        // Discard the variable like this: `_ = foo;`
        const ais = r.ais;
        try ais.writeAll("_ = ");
        try ais.writeAll(tokenSliceForRender(r.tree, var_decl.ast.mut_token + 1));
        try ais.writeAll(";\n");
    }
}

fn renderVarDeclWithoutFixups(
    r: *Render,
    var_decl: Ast.full.VarDecl,
    /// Destructures intentionally ignore leading `comptime` tokens.
    ignore_comptime_token: bool,
    /// `comma_space` and `space` are used for destructure LHS decls.
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    if (var_decl.visib_token) |visib_token| {
        try renderToken(r, visib_token, Space.space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(r, extern_export_token, Space.space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderToken(r, lib_name, Space.space); // "lib"
        }
    }

    if (var_decl.threadlocal_token) |thread_local_token| {
        try renderToken(r, thread_local_token, Space.space); // threadlocal
    }

    if (!ignore_comptime_token) {
        if (var_decl.comptime_token) |comptime_token| {
            try renderToken(r, comptime_token, Space.space); // comptime
        }
    }

    try renderToken(r, var_decl.ast.mut_token, .space); // var

    if (var_decl.ast.type_node != .none or var_decl.ast.align_node != .none or
        var_decl.ast.addrspace_node != .none or var_decl.ast.section_node != .none or
        var_decl.ast.init_node != .none)
    {
        const name_space = if (var_decl.ast.type_node == .none and
            (var_decl.ast.align_node != .none or
                var_decl.ast.addrspace_node != .none or
                var_decl.ast.section_node != .none or
                var_decl.ast.init_node != .none))
            Space.space
        else
            Space.none;

        try renderIdentifier(r, var_decl.ast.mut_token + 1, name_space, .preserve_when_shadowing); // name
    } else {
        return renderIdentifier(r, var_decl.ast.mut_token + 1, space, .preserve_when_shadowing); // name
    }

    if (var_decl.ast.type_node.unwrap()) |type_node| {
        try renderToken(r, var_decl.ast.mut_token + 2, Space.space); // :
        if (var_decl.ast.align_node != .none or var_decl.ast.addrspace_node != .none or
            var_decl.ast.section_node != .none or var_decl.ast.init_node != .none)
        {
            try renderExpression(r, type_node, .space);
        } else {
            return renderExpression(r, type_node, space);
        }
    }

    if (var_decl.ast.align_node.unwrap()) |align_node| {
        const lparen = tree.firstToken(align_node) - 1;
        const align_kw = lparen - 1;
        const rparen = tree.lastToken(align_node) + 1;
        try renderToken(r, align_kw, Space.none); // align
        try renderToken(r, lparen, Space.none); // (
        try renderExpression(r, align_node, Space.none);
        if (var_decl.ast.addrspace_node != .none or var_decl.ast.section_node != .none or
            var_decl.ast.init_node != .none)
        {
            try renderToken(r, rparen, .space); // )
        } else {
            return renderToken(r, rparen, space); // )
        }
    }

    if (var_decl.ast.addrspace_node.unwrap()) |addrspace_node| {
        const lparen = tree.firstToken(addrspace_node) - 1;
        const addrspace_kw = lparen - 1;
        const rparen = tree.lastToken(addrspace_node) + 1;
        try renderToken(r, addrspace_kw, Space.none); // addrspace
        try renderToken(r, lparen, Space.none); // (
        try renderExpression(r, addrspace_node, Space.none);
        if (var_decl.ast.section_node != .none or var_decl.ast.init_node != .none) {
            try renderToken(r, rparen, .space); // )
        } else {
            try renderToken(r, rparen, .none); // )
            return renderToken(r, rparen + 1, Space.newline); // ;
        }
    }

    if (var_decl.ast.section_node.unwrap()) |section_node| {
        const lparen = tree.firstToken(section_node) - 1;
        const section_kw = lparen - 1;
        const rparen = tree.lastToken(section_node) + 1;
        try renderToken(r, section_kw, Space.none); // linksection
        try renderToken(r, lparen, Space.none); // (
        try renderExpression(r, section_node, Space.none);
        if (var_decl.ast.init_node != .none) {
            try renderToken(r, rparen, .space); // )
        } else {
            return renderToken(r, rparen, space); // )
        }
    }

    const init_node = var_decl.ast.init_node.unwrap().?;

    const eq_token = tree.firstToken(init_node) - 1;
    const eq_space: Space = if (tree.tokensOnSameLine(eq_token, eq_token + 1)) .space else .newline;
    try ais.pushIndent(.after_equals);
    try renderToken(r, eq_token, eq_space); // =
    try renderExpression(r, init_node, space); // ;
    ais.popIndent();
}

fn renderIf(r: *Render, if_node: Ast.full.If, space: Space) Error!void {
    return renderWhile(r, .{
        .ast = .{
            .while_token = if_node.ast.if_token,
            .cond_expr = if_node.ast.cond_expr,
            .cont_expr = .none,
            .then_expr = if_node.ast.then_expr,
            .else_expr = if_node.ast.else_expr,
        },
        .inline_token = null,
        .label_token = null,
        .payload_token = if_node.payload_token,
        .else_token = if_node.else_token,
        .error_token = if_node.error_token,
    }, space);
}

/// Note that this function is additionally used to render if expressions, with
/// respective values set to null.
fn renderWhile(r: *Render, while_node: Ast.full.While, space: Space) Error!void {
    const tree = r.tree;

    if (while_node.label_token) |label| {
        try renderIdentifier(r, label, .none, .eagerly_unquote); // label
        try renderToken(r, label + 1, .space); // :
    }

    if (while_node.inline_token) |inline_token| {
        try renderToken(r, inline_token, .space); // inline
    }

    try renderToken(r, while_node.ast.while_token, .space); // if/for/while
    try renderToken(r, while_node.ast.while_token + 1, .none); // lparen
    try renderExpression(r, while_node.ast.cond_expr, .none); // condition

    var last_prefix_token = tree.lastToken(while_node.ast.cond_expr) + 1; // rparen

    if (while_node.payload_token) |payload_token| {
        try renderToken(r, last_prefix_token, .space);
        try renderToken(r, payload_token - 1, .none); // |
        const ident = blk: {
            if (tree.tokenTag(payload_token) == .asterisk) {
                try renderToken(r, payload_token, .none); // *
                break :blk payload_token + 1;
            } else {
                break :blk payload_token;
            }
        };
        try renderIdentifier(r, ident, .none, .preserve_when_shadowing); // identifier
        const pipe = blk: {
            if (tree.tokenTag(ident + 1) == .comma) {
                try renderToken(r, ident + 1, .space); // ,
                try renderIdentifier(r, ident + 2, .none, .preserve_when_shadowing); // index
                break :blk ident + 3;
            } else {
                break :blk ident + 1;
            }
        };
        last_prefix_token = pipe;
    }

    if (while_node.ast.cont_expr.unwrap()) |cont_expr| {
        try renderToken(r, last_prefix_token, .space);
        const lparen = tree.firstToken(cont_expr) - 1;
        try renderToken(r, lparen - 1, .space); // :
        try renderToken(r, lparen, .none); // lparen
        try renderExpression(r, cont_expr, .none);
        last_prefix_token = tree.lastToken(cont_expr) + 1; // rparen
    }

    try renderThenElse(
        r,
        last_prefix_token,
        while_node.ast.then_expr,
        while_node.else_token,
        while_node.error_token,
        while_node.ast.else_expr,
        space,
    );
}

fn renderThenElse(
    r: *Render,
    last_prefix_token: Ast.TokenIndex,
    then_expr: Ast.Node.Index,
    else_token: ?Ast.TokenIndex,
    maybe_error_token: ?Ast.TokenIndex,
    opt_else_expr: Ast.Node.OptionalIndex,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const then_expr_is_block = nodeIsBlock(tree.nodeTag(then_expr));
    const indent_then_expr = !then_expr_is_block and
        !tree.tokensOnSameLine(last_prefix_token, tree.firstToken(then_expr));

    if (indent_then_expr) try ais.pushIndent(.normal);

    if (then_expr_is_block and ais.isLineOverIndented()) {
        ais.disableIndentCommitting();
        try renderToken(r, last_prefix_token, .newline);
        ais.enableIndentCommitting();
    } else if (indent_then_expr) {
        try renderToken(r, last_prefix_token, .newline);
    } else {
        try renderToken(r, last_prefix_token, .space);
    }

    if (opt_else_expr.unwrap()) |else_expr| {
        if (indent_then_expr) {
            try renderExpression(r, then_expr, .newline);
        } else {
            try renderExpression(r, then_expr, .space);
        }

        if (indent_then_expr) ais.popIndent();

        var last_else_token = else_token.?;

        if (maybe_error_token) |error_token| {
            try renderToken(r, last_else_token, .space); // else
            try renderToken(r, error_token - 1, .none); // |
            try renderIdentifier(r, error_token, .none, .preserve_when_shadowing); // identifier
            last_else_token = error_token + 1; // |
        }

        const indent_else_expr = indent_then_expr and
            !nodeIsBlock(tree.nodeTag(else_expr)) and
            !nodeIsIfForWhileSwitch(tree.nodeTag(else_expr));
        if (indent_else_expr) {
            try ais.pushIndent(.normal);
            try renderToken(r, last_else_token, .newline);
            try renderExpression(r, else_expr, space);
            ais.popIndent();
        } else {
            try renderToken(r, last_else_token, .space);
            try renderExpression(r, else_expr, space);
        }
    } else {
        try renderExpression(r, then_expr, space);
        if (indent_then_expr) ais.popIndent();
    }
}

fn renderFor(r: *Render, for_node: Ast.full.For, space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const token_tags = tree.tokens.items(.tag);

    if (for_node.label_token) |label| {
        try renderIdentifier(r, label, .none, .eagerly_unquote); // label
        try renderToken(r, label + 1, .space); // :
    }

    if (for_node.inline_token) |inline_token| {
        try renderToken(r, inline_token, .space); // inline
    }

    try renderToken(r, for_node.ast.for_token, .space); // if/for/while

    const lparen = for_node.ast.for_token + 1;
    try renderParamList(r, lparen, for_node.ast.inputs, .space);

    var cur = for_node.payload_token;
    const pipe = std.mem.indexOfScalarPos(std.zig.Token.Tag, token_tags, cur, .pipe).?;
    if (tree.tokenTag(@intCast(pipe - 1)) == .comma) {
        try ais.pushIndent(.normal);
        try renderToken(r, cur - 1, .newline); // |
        while (true) {
            if (tree.tokenTag(cur) == .asterisk) {
                try renderToken(r, cur, .none); // *
                cur += 1;
            }
            try renderIdentifier(r, cur, .none, .preserve_when_shadowing); // identifier
            cur += 1;
            if (tree.tokenTag(cur) == .comma) {
                try renderToken(r, cur, .newline); // ,
                cur += 1;
            }
            if (tree.tokenTag(cur) == .pipe) {
                break;
            }
        }
        ais.popIndent();
    } else {
        try renderToken(r, cur - 1, .none); // |
        while (true) {
            if (tree.tokenTag(cur) == .asterisk) {
                try renderToken(r, cur, .none); // *
                cur += 1;
            }
            try renderIdentifier(r, cur, .none, .preserve_when_shadowing); // identifier
            cur += 1;
            if (tree.tokenTag(cur) == .comma) {
                try renderToken(r, cur, .space); // ,
                cur += 1;
            }
            if (tree.tokenTag(cur) == .pipe) {
                break;
            }
        }
    }

    try renderThenElse(
        r,
        cur,
        for_node.ast.then_expr,
        for_node.else_token,
        null,
        for_node.ast.else_expr,
        space,
    );
}

fn renderContainerField(
    r: *Render,
    container: Container,
    field_param: Ast.full.ContainerField,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    var field = field_param;
    if (container != .tuple) field.convertToNonTupleLike(&tree);
    const quote: QuoteBehavior = switch (container) {
        .@"enum" => .eagerly_unquote_except_underscore,
        .tuple, .other => .eagerly_unquote,
    };

    if (field.comptime_token) |t| {
        try renderToken(r, t, .space); // comptime
    }
    if (field.ast.type_expr == .none and field.ast.value_expr == .none) {
        if (field.ast.align_expr.unwrap()) |align_expr| {
            try renderIdentifier(r, field.ast.main_token, .space, quote); // name
            const lparen_token = tree.firstToken(align_expr) - 1;
            const align_kw = lparen_token - 1;
            const rparen_token = tree.lastToken(align_expr) + 1;
            try renderToken(r, align_kw, .none); // align
            try renderToken(r, lparen_token, .none); // (
            try renderExpression(r, align_expr, .none); // alignment
            return renderToken(r, rparen_token, .space); // )
        }
        return renderIdentifierComma(r, field.ast.main_token, space, quote); // name
    }
    if (field.ast.type_expr != .none and field.ast.value_expr == .none) {
        const type_expr = field.ast.type_expr.unwrap().?;
        if (!field.ast.tuple_like) {
            try renderIdentifier(r, field.ast.main_token, .none, quote); // name
            try renderToken(r, field.ast.main_token + 1, .space); // :
        }

        if (field.ast.align_expr.unwrap()) |align_expr| {
            try renderExpression(r, type_expr, .space); // type
            const align_token = tree.firstToken(align_expr) - 2;
            try renderToken(r, align_token, .none); // align
            try renderToken(r, align_token + 1, .none); // (
            try renderExpression(r, align_expr, .none); // alignment
            const rparen = tree.lastToken(align_expr) + 1;
            return renderTokenComma(r, rparen, space); // )
        } else {
            return renderExpressionComma(r, type_expr, space); // type
        }
    }
    if (field.ast.type_expr == .none and field.ast.value_expr != .none) {
        const value_expr = field.ast.value_expr.unwrap().?;

        try renderIdentifier(r, field.ast.main_token, .space, quote); // name
        if (field.ast.align_expr.unwrap()) |align_expr| {
            const lparen_token = tree.firstToken(align_expr) - 1;
            const align_kw = lparen_token - 1;
            const rparen_token = tree.lastToken(align_expr) + 1;
            try renderToken(r, align_kw, .none); // align
            try renderToken(r, lparen_token, .none); // (
            try renderExpression(r, align_expr, .none); // alignment
            try renderToken(r, rparen_token, .space); // )
        }
        try renderToken(r, field.ast.main_token + 1, .space); // =
        return renderExpressionComma(r, value_expr, space); // value
    }
    if (!field.ast.tuple_like) {
        try renderIdentifier(r, field.ast.main_token, .none, quote); // name
        try renderToken(r, field.ast.main_token + 1, .space); // :
    }

    const type_expr = field.ast.type_expr.unwrap().?;
    const value_expr = field.ast.value_expr.unwrap().?;

    try renderExpression(r, type_expr, .space); // type

    if (field.ast.align_expr.unwrap()) |align_expr| {
        const lparen_token = tree.firstToken(align_expr) - 1;
        const align_kw = lparen_token - 1;
        const rparen_token = tree.lastToken(align_expr) + 1;
        try renderToken(r, align_kw, .none); // align
        try renderToken(r, lparen_token, .none); // (
        try renderExpression(r, align_expr, .none); // alignment
        try renderToken(r, rparen_token, .space); // )
    }
    const eq_token = tree.firstToken(value_expr) - 1;
    const eq_space: Space = if (tree.tokensOnSameLine(eq_token, eq_token + 1)) .space else .newline;

    try ais.pushIndent(.after_equals);
    try renderToken(r, eq_token, eq_space); // =

    if (eq_space == .space) {
        ais.popIndent();
        try renderExpressionComma(r, value_expr, space); // value
        return;
    }

    const maybe_comma = tree.lastToken(value_expr) + 1;

    if (tree.tokenTag(maybe_comma) == .comma) {
        try renderExpression(r, value_expr, .none); // value
        ais.popIndent();
        try renderToken(r, maybe_comma, .newline);
    } else {
        try renderExpression(r, value_expr, space); // value
        ais.popIndent();
    }
}

fn renderBuiltinCall(
    r: *Render,
    builtin_token: Ast.TokenIndex,
    params: []const Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    try renderToken(r, builtin_token, .none); // @name

    if (params.len == 0) {
        try renderToken(r, builtin_token + 1, .none); // (
        return renderToken(r, builtin_token + 2, space); // )
    }

    if (r.fixups.rebase_imported_paths) |prefix| {
        const slice = tree.tokenSlice(builtin_token);
        if (mem.eql(u8, slice, "@import")) f: {
            const param = params[0];
            const str_lit_token = tree.nodeMainToken(param);
            assert(tree.tokenTag(str_lit_token) == .string_literal);
            const token_bytes = tree.tokenSlice(str_lit_token);
            const imported_string = std.zig.string_literal.parseAlloc(r.gpa, token_bytes) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.InvalidLiteral => break :f,
            };
            defer r.gpa.free(imported_string);
            const new_string = try std.fs.path.resolvePosix(r.gpa, &.{ prefix, imported_string });
            defer r.gpa.free(new_string);

            try renderToken(r, builtin_token + 1, .none); // (
            try ais.print("\"{f}\"", .{std.zig.fmtString(new_string)});
            return renderToken(r, str_lit_token + 1, space); // )
        }
    }

    const last_param = params[params.len - 1];
    const after_last_param_token = tree.lastToken(last_param) + 1;

    if (tree.tokenTag(after_last_param_token) != .comma) {
        // Render all on one line, no trailing comma.
        try renderToken(r, builtin_token + 1, .none); // (

        for (params, 0..) |param_node, i| {
            const first_param_token = tree.firstToken(param_node);
            if (tree.tokenTag(first_param_token) == .multiline_string_literal_line or
                hasSameLineComment(tree, first_param_token - 1))
            {
                try ais.pushIndent(.normal);
                try renderExpression(r, param_node, .none);
                ais.popIndent();
            } else {
                try renderExpression(r, param_node, .none);
            }

            if (i + 1 < params.len) {
                const comma_token = tree.lastToken(param_node) + 1;
                try renderToken(r, comma_token, .space); // ,
            }
        }
        return renderToken(r, after_last_param_token, space); // )
    } else {
        // Render one param per line.
        try ais.pushIndent(.normal);
        try renderToken(r, builtin_token + 1, Space.newline); // (

        for (params) |param_node| {
            try ais.pushSpace(.comma);
            try renderExpression(r, param_node, .comma);
            ais.popSpace();
        }
        ais.popIndent();

        return renderToken(r, after_last_param_token + 1, space); // )
    }
}

fn renderFnProto(r: *Render, fn_proto: Ast.full.FnProto, space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    const after_fn_token = fn_proto.ast.fn_token + 1;
    const lparen = if (tree.tokenTag(after_fn_token) == .identifier) blk: {
        try renderToken(r, fn_proto.ast.fn_token, .space); // fn
        try renderIdentifier(r, after_fn_token, .none, .preserve_when_shadowing); // name
        break :blk after_fn_token + 1;
    } else blk: {
        try renderToken(r, fn_proto.ast.fn_token, .space); // fn
        break :blk fn_proto.ast.fn_token + 1;
    };
    assert(tree.tokenTag(lparen) == .l_paren);

    const return_type = fn_proto.ast.return_type.unwrap().?;
    const maybe_bang = tree.firstToken(return_type) - 1;
    const rparen = blk: {
        // These may appear in any order, so we have to check the token_starts array
        // to find out which is first.
        var rparen = if (tree.tokenTag(maybe_bang) == .bang) maybe_bang - 1 else maybe_bang;
        var smallest_start = tree.tokenStart(maybe_bang);
        if (fn_proto.ast.align_expr.unwrap()) |align_expr| {
            const tok = tree.firstToken(align_expr) - 3;
            const start = tree.tokenStart(tok);
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.addrspace_expr.unwrap()) |addrspace_expr| {
            const tok = tree.firstToken(addrspace_expr) - 3;
            const start = tree.tokenStart(tok);
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.section_expr.unwrap()) |section_expr| {
            const tok = tree.firstToken(section_expr) - 3;
            const start = tree.tokenStart(tok);
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.callconv_expr.unwrap()) |callconv_expr| {
            const tok = tree.firstToken(callconv_expr) - 3;
            const start = tree.tokenStart(tok);
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        break :blk rparen;
    };
    assert(tree.tokenTag(rparen) == .r_paren);

    // The params list is a sparse set that does *not* include anytype or ... parameters.

    const trailing_comma = tree.tokenTag(rparen - 1) == .comma;
    if (!trailing_comma and !hasComment(tree, lparen, rparen)) {
        // Render all on one line, no trailing comma.
        try renderToken(r, lparen, .none); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (tree.tokenTag(last_param_token)) {
                .doc_comment => {
                    try renderToken(r, last_param_token, .newline);
                    continue;
                },
                .ellipsis3 => {
                    try renderToken(r, last_param_token, .none); // ...
                    break;
                },
                .keyword_noalias, .keyword_comptime => {
                    try renderToken(r, last_param_token, .space);
                    last_param_token += 1;
                },
                .identifier => {},
                .keyword_anytype => {
                    try renderToken(r, last_param_token, .none); // anytype
                    continue;
                },
                .r_paren => break,
                .comma => {
                    try renderToken(r, last_param_token, .space); // ,
                    continue;
                },
                else => {}, // Parameter type without a name.
            }
            if (tree.tokenTag(last_param_token) == .identifier and
                tree.tokenTag(last_param_token + 1) == .colon)
            {
                try renderIdentifier(r, last_param_token, .none, .preserve_when_shadowing); // name
                last_param_token = last_param_token + 1;
                try renderToken(r, last_param_token, .space); // :
                last_param_token += 1;
            }
            if (tree.tokenTag(last_param_token) == .keyword_anytype) {
                try renderToken(r, last_param_token, .none); // anytype
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try renderExpression(r, param, .none);
            last_param_token = tree.lastToken(param);
        }
    } else {
        // One param per line.
        try ais.pushIndent(.normal);
        try renderToken(r, lparen, .newline); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (tree.tokenTag(last_param_token)) {
                .doc_comment => {
                    try renderToken(r, last_param_token, .newline);
                    continue;
                },
                .ellipsis3 => {
                    try renderToken(r, last_param_token, .comma); // ...
                    break;
                },
                .keyword_noalias, .keyword_comptime => {
                    try renderToken(r, last_param_token, .space);
                    last_param_token += 1;
                },
                .identifier => {},
                .keyword_anytype => {
                    try renderToken(r, last_param_token, .comma); // anytype
                    if (tree.tokenTag(last_param_token + 1) == .comma)
                        last_param_token += 1;
                    continue;
                },
                .r_paren => break,
                else => {}, // Parameter type without a name.
            }
            if (tree.tokenTag(last_param_token) == .identifier and
                tree.tokenTag(last_param_token + 1) == .colon)
            {
                try renderIdentifier(r, last_param_token, .none, .preserve_when_shadowing); // name
                last_param_token += 1;
                try renderToken(r, last_param_token, .space); // :
                last_param_token += 1;
            }
            if (tree.tokenTag(last_param_token) == .keyword_anytype) {
                try renderToken(r, last_param_token, .comma); // anytype
                if (tree.tokenTag(last_param_token + 1) == .comma)
                    last_param_token += 1;
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try ais.pushSpace(.comma);
            try renderExpression(r, param, .comma);
            ais.popSpace();
            last_param_token = tree.lastToken(param);
            if (tree.tokenTag(last_param_token + 1) == .comma) last_param_token += 1;
        }
        ais.popIndent();
    }

    try renderToken(r, rparen, .space); // )

    if (fn_proto.ast.align_expr.unwrap()) |align_expr| {
        const align_lparen = tree.firstToken(align_expr) - 1;
        const align_rparen = tree.lastToken(align_expr) + 1;

        try renderToken(r, align_lparen - 1, .none); // align
        try renderToken(r, align_lparen, .none); // (
        try renderExpression(r, align_expr, .none);
        try renderToken(r, align_rparen, .space); // )
    }

    if (fn_proto.ast.addrspace_expr.unwrap()) |addrspace_expr| {
        const align_lparen = tree.firstToken(addrspace_expr) - 1;
        const align_rparen = tree.lastToken(addrspace_expr) + 1;

        try renderToken(r, align_lparen - 1, .none); // addrspace
        try renderToken(r, align_lparen, .none); // (
        try renderExpression(r, addrspace_expr, .none);
        try renderToken(r, align_rparen, .space); // )
    }

    if (fn_proto.ast.section_expr.unwrap()) |section_expr| {
        const section_lparen = tree.firstToken(section_expr) - 1;
        const section_rparen = tree.lastToken(section_expr) + 1;

        try renderToken(r, section_lparen - 1, .none); // section
        try renderToken(r, section_lparen, .none); // (
        try renderExpression(r, section_expr, .none);
        try renderToken(r, section_rparen, .space); // )
    }

    if (fn_proto.ast.callconv_expr.unwrap()) |callconv_expr| {
        // Keep in sync with logic in `renderMember`. Search this file for the marker PROMOTE_CALLCONV_INLINE
        const is_callconv_inline = mem.eql(u8, "@\"inline\"", tree.tokenSlice(tree.nodeMainToken(callconv_expr)));
        const is_declaration = fn_proto.name_token != null;
        if (!(is_declaration and is_callconv_inline)) {
            const callconv_lparen = tree.firstToken(callconv_expr) - 1;
            const callconv_rparen = tree.lastToken(callconv_expr) + 1;

            try renderToken(r, callconv_lparen - 1, .none); // callconv
            try renderToken(r, callconv_lparen, .none); // (
            try renderExpression(r, callconv_expr, .none);
            try renderToken(r, callconv_rparen, .space); // )
        }
    }

    if (tree.tokenTag(maybe_bang) == .bang) {
        try renderToken(r, maybe_bang, .none); // !
    }
    return renderExpression(r, return_type, space);
}

fn renderSwitchCase(
    r: *Render,
    switch_case: Ast.full.SwitchCase,
    space: Space,
) Error!void {
    const ais = r.ais;
    const tree = r.tree;
    const trailing_comma = tree.tokenTag(switch_case.ast.arrow_token - 1) == .comma;
    const has_comment_before_arrow = blk: {
        if (switch_case.ast.values.len == 0) break :blk false;
        break :blk hasComment(tree, tree.firstToken(switch_case.ast.values[0]), switch_case.ast.arrow_token);
    };

    // render inline keyword
    if (switch_case.inline_token) |some| {
        try renderToken(r, some, .space);
    }

    // Render everything before the arrow
    if (switch_case.ast.values.len == 0) {
        try renderToken(r, switch_case.ast.arrow_token - 1, .space); // else keyword
    } else if (trailing_comma or has_comment_before_arrow) {
        // Render each value on a new line
        try ais.pushSpace(.comma);
        try renderExpressions(r, switch_case.ast.values, .comma);
        ais.popSpace();
    } else {
        // Render on one line
        for (switch_case.ast.values) |value_expr| {
            try renderExpression(r, value_expr, .comma_space);
        }
    }

    // Render the arrow and everything after it
    const pre_target_space = if (tree.nodeTag(switch_case.ast.target_expr) == .multiline_string_literal)
        // Newline gets inserted when rendering the target expr.
        Space.none
    else
        Space.space;
    const after_arrow_space: Space = if (switch_case.payload_token == null) pre_target_space else .space;
    try renderToken(r, switch_case.ast.arrow_token, after_arrow_space); // =>

    if (switch_case.payload_token) |payload_token| {
        try renderToken(r, payload_token - 1, .none); // pipe
        const ident = payload_token + @intFromBool(tree.tokenTag(payload_token) == .asterisk);
        if (tree.tokenTag(payload_token) == .asterisk) {
            try renderToken(r, payload_token, .none); // asterisk
        }
        try renderIdentifier(r, ident, .none, .preserve_when_shadowing); // identifier
        if (tree.tokenTag(ident + 1) == .comma) {
            try renderToken(r, ident + 1, .space); // ,
            try renderIdentifier(r, ident + 2, .none, .preserve_when_shadowing); // identifier
            try renderToken(r, ident + 3, pre_target_space); // pipe
        } else {
            try renderToken(r, ident + 1, pre_target_space); // pipe
        }
    }

    try renderExpression(r, switch_case.ast.target_expr, space);
}

fn renderBlock(
    r: *Render,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const lbrace = tree.nodeMainToken(block_node);

    if (tree.isTokenPrecededByTags(lbrace, &.{ .identifier, .colon })) {
        try renderIdentifier(r, lbrace - 2, .none, .eagerly_unquote); // identifier
        try renderToken(r, lbrace - 1, .space); // :
    }
    try ais.pushIndent(.normal);
    if (statements.len == 0) {
        try renderToken(r, lbrace, .none);
        ais.popIndent();
        try renderToken(r, tree.lastToken(block_node), space); // rbrace
        return;
    }
    try renderToken(r, lbrace, .newline);
    return finishRenderBlock(r, block_node, statements, space);
}

fn finishRenderBlock(
    r: *Render,
    block_node: Ast.Node.Index,
    statements: []const Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    for (statements, 0..) |stmt, i| {
        if (i != 0) try renderExtraNewline(r, stmt);
        if (r.fixups.omit_nodes.contains(stmt)) continue;
        try ais.pushSpace(.semicolon);
        switch (tree.nodeTag(stmt)) {
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => try renderVarDecl(r, tree.fullVarDecl(stmt).?, false, .semicolon),

            else => try renderExpression(r, stmt, .semicolon),
        }
        ais.popSpace();
    }
    ais.popIndent();

    try renderToken(r, tree.lastToken(block_node), space); // rbrace
}

fn renderStructInit(
    r: *Render,
    struct_node: Ast.Node.Index,
    struct_init: Ast.full.StructInit,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    if (struct_init.ast.type_expr.unwrap()) |type_expr| {
        try renderExpression(r, type_expr, .none); // T
    } else {
        try renderToken(r, struct_init.ast.lbrace - 1, .none); // .
    }

    if (struct_init.ast.fields.len == 0) {
        try ais.pushIndent(.normal);
        try renderToken(r, struct_init.ast.lbrace, .none); // lbrace
        ais.popIndent();
        return renderToken(r, struct_init.ast.lbrace + 1, space); // rbrace
    }

    const rbrace = tree.lastToken(struct_node);
    const trailing_comma = tree.tokenTag(rbrace - 1) == .comma;
    if (trailing_comma or hasComment(tree, struct_init.ast.lbrace, rbrace)) {
        // Render one field init per line.
        try ais.pushIndent(.normal);
        try renderToken(r, struct_init.ast.lbrace, .newline);

        try renderToken(r, struct_init.ast.lbrace + 1, .none); // .
        try renderIdentifier(r, struct_init.ast.lbrace + 2, .space, .eagerly_unquote); // name
        // Don't output a space after the = if expression is a multiline string,
        // since then it will start on the next line.
        const field_node = struct_init.ast.fields[0];
        const expr = tree.nodeTag(field_node);
        var space_after_equal: Space = if (expr == .multiline_string_literal) .none else .space;
        try renderToken(r, struct_init.ast.lbrace + 3, space_after_equal); // =

        try ais.pushSpace(.comma);
        try renderExpressionFixup(r, field_node, .comma);
        ais.popSpace();

        for (struct_init.ast.fields[1..]) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderExtraNewlineToken(r, init_token - 3);
            try renderToken(r, init_token - 3, .none); // .
            try renderIdentifier(r, init_token - 2, .space, .eagerly_unquote); // name
            space_after_equal = if (tree.nodeTag(field_init) == .multiline_string_literal) .none else .space;
            try renderToken(r, init_token - 1, space_after_equal); // =

            try ais.pushSpace(.comma);
            try renderExpressionFixup(r, field_init, .comma);
            ais.popSpace();
        }

        ais.popIndent();
    } else {
        // Render all on one line, no trailing comma.
        try renderToken(r, struct_init.ast.lbrace, .space);

        for (struct_init.ast.fields) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderToken(r, init_token - 3, .none); // .
            try renderIdentifier(r, init_token - 2, .space, .eagerly_unquote); // name
            try renderToken(r, init_token - 1, .space); // =
            try renderExpressionFixup(r, field_init, .comma_space);
        }
    }

    return renderToken(r, rbrace, space);
}

fn renderArrayInit(
    r: *Render,
    array_init: Ast.full.ArrayInit,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const gpa = r.gpa;

    if (array_init.ast.type_expr.unwrap()) |type_expr| {
        try renderExpression(r, type_expr, .none); // T
    } else {
        try renderToken(r, array_init.ast.lbrace - 1, .none); // .
    }

    if (array_init.ast.elements.len == 0) {
        try ais.pushIndent(.normal);
        try renderToken(r, array_init.ast.lbrace, .none); // lbrace
        ais.popIndent();
        return renderToken(r, array_init.ast.lbrace + 1, space); // rbrace
    }

    const last_elem = array_init.ast.elements[array_init.ast.elements.len - 1];
    const last_elem_token = tree.lastToken(last_elem);
    const trailing_comma = tree.tokenTag(last_elem_token + 1) == .comma;
    const rbrace = if (trailing_comma) last_elem_token + 2 else last_elem_token + 1;
    assert(tree.tokenTag(rbrace) == .r_brace);

    if (array_init.ast.elements.len == 1) {
        const only_elem = array_init.ast.elements[0];
        const first_token = tree.firstToken(only_elem);
        if (tree.tokenTag(first_token) != .multiline_string_literal_line and
            !anythingBetween(tree, last_elem_token, rbrace))
        {
            try renderToken(r, array_init.ast.lbrace, .none);
            try renderExpression(r, only_elem, .none);
            return renderToken(r, rbrace, space);
        }
    }

    const contains_comment = hasComment(tree, array_init.ast.lbrace, rbrace);
    const contains_multiline_string = hasMultilineString(tree, array_init.ast.lbrace, rbrace);

    if (!trailing_comma and !contains_comment and !contains_multiline_string) {
        // Render all on one line, no trailing comma.
        if (array_init.ast.elements.len == 1) {
            // If there is only one element, we don't use spaces
            try renderToken(r, array_init.ast.lbrace, .none);
            try renderExpression(r, array_init.ast.elements[0], .none);
        } else {
            try renderToken(r, array_init.ast.lbrace, .space);
            for (array_init.ast.elements) |elem| {
                try renderExpression(r, elem, .comma_space);
            }
        }
        return renderToken(r, last_elem_token + 1, space); // rbrace
    }

    try ais.pushIndent(.normal);
    try renderToken(r, array_init.ast.lbrace, .newline);

    var expr_index: usize = 0;
    while (true) {
        const row_size = rowSize(tree, array_init.ast.elements[expr_index..], rbrace);
        const row_exprs = array_init.ast.elements[expr_index..];
        // A place to store the width of each expression and its column's maximum
        const widths = try gpa.alloc(usize, row_exprs.len + row_size);
        defer gpa.free(widths);
        @memset(widths, 0);

        const expr_newlines = try gpa.alloc(bool, row_exprs.len);
        defer gpa.free(expr_newlines);
        @memset(expr_newlines, false);

        const expr_widths = widths[0..row_exprs.len];
        const column_widths = widths[row_exprs.len..];

        // Find next row with trailing comment (if any) to end the current section.
        const section_end = sec_end: {
            var this_line_first_expr: usize = 0;
            var this_line_size = rowSize(tree, row_exprs, rbrace);
            for (row_exprs, 0..) |expr, i| {
                // Ignore comment on first line of this section.
                if (i == 0) continue;
                const expr_last_token = tree.lastToken(expr);
                if (tree.tokensOnSameLine(tree.firstToken(row_exprs[0]), expr_last_token))
                    continue;
                // Track start of line containing comment.
                if (!tree.tokensOnSameLine(tree.firstToken(row_exprs[this_line_first_expr]), expr_last_token)) {
                    this_line_first_expr = i;
                    this_line_size = rowSize(tree, row_exprs[this_line_first_expr..], rbrace);
                }

                const maybe_comma = expr_last_token + 1;
                if (tree.tokenTag(maybe_comma) == .comma) {
                    if (hasSameLineComment(tree, maybe_comma))
                        break :sec_end i - this_line_size + 1;
                }
            }
            break :sec_end row_exprs.len;
        };
        expr_index += section_end;

        const section_exprs = row_exprs[0..section_end];

        var sub_expr_buffer: std.io.Writer.Allocating = .init(gpa);
        defer sub_expr_buffer.deinit();

        const sub_expr_buffer_starts = try gpa.alloc(usize, section_exprs.len + 1);
        defer gpa.free(sub_expr_buffer_starts);

        var auto_indenting_stream: AutoIndentingStream = .init(gpa, &sub_expr_buffer.writer, indent_delta);
        defer auto_indenting_stream.deinit();
        var sub_render: Render = .{
            .gpa = r.gpa,
            .ais = &auto_indenting_stream,
            .tree = r.tree,
            .fixups = r.fixups,
        };

        // Calculate size of columns in current section
        var column_counter: usize = 0;
        var single_line = true;
        var contains_newline = false;
        for (section_exprs, 0..) |expr, i| {
            const start = sub_expr_buffer.getWritten().len;
            sub_expr_buffer_starts[i] = start;

            if (i + 1 < section_exprs.len) {
                try renderExpression(&sub_render, expr, .none);
                const written = sub_expr_buffer.getWritten();
                const width = written.len - start;
                const this_contains_newline = mem.indexOfScalar(u8, written[start..], '\n') != null;
                contains_newline = contains_newline or this_contains_newline;
                expr_widths[i] = width;
                expr_newlines[i] = this_contains_newline;

                if (!this_contains_newline) {
                    const column = column_counter % row_size;
                    column_widths[column] = @max(column_widths[column], width);

                    const expr_last_token = tree.lastToken(expr) + 1;
                    const next_expr = section_exprs[i + 1];
                    column_counter += 1;
                    if (!tree.tokensOnSameLine(expr_last_token, tree.firstToken(next_expr))) single_line = false;
                } else {
                    single_line = false;
                    column_counter = 0;
                }
            } else {
                try ais.pushSpace(.comma);
                try renderExpression(&sub_render, expr, .comma);
                ais.popSpace();

                const written = sub_expr_buffer.getWritten();
                const width = written.len - start - 2;
                const this_contains_newline = mem.indexOfScalar(u8, written[start .. written.len - 1], '\n') != null;
                contains_newline = contains_newline or this_contains_newline;
                expr_widths[i] = width;
                expr_newlines[i] = contains_newline;

                if (!contains_newline) {
                    const column = column_counter % row_size;
                    column_widths[column] = @max(column_widths[column], width);
                }
            }
        }
        sub_expr_buffer_starts[section_exprs.len] = sub_expr_buffer.getWritten().len;

        // Render exprs in current section.
        column_counter = 0;
        for (section_exprs, 0..) |expr, i| {
            const start = sub_expr_buffer_starts[i];
            const end = sub_expr_buffer_starts[i + 1];
            const expr_text = sub_expr_buffer.getWritten()[start..end];
            if (!expr_newlines[i]) {
                try ais.writeAll(expr_text);
            } else {
                var by_line = std.mem.splitScalar(u8, expr_text, '\n');
                var last_line_was_empty = false;
                try ais.writeAll(by_line.first());
                while (by_line.next()) |line| {
                    if (std.mem.startsWith(u8, line, "//") and last_line_was_empty) {
                        try ais.insertNewline();
                    } else {
                        try ais.maybeInsertNewline();
                    }
                    last_line_was_empty = (line.len == 0);
                    try ais.writeAll(line);
                }
            }

            if (i + 1 < section_exprs.len) {
                const next_expr = section_exprs[i + 1];
                const comma = tree.lastToken(expr) + 1;

                if (column_counter != row_size - 1) {
                    if (!expr_newlines[i] and !expr_newlines[i + 1]) {
                        // Neither the current or next expression is multiline
                        try renderToken(r, comma, .space); // ,
                        assert(column_widths[column_counter % row_size] >= expr_widths[i]);
                        const padding = column_widths[column_counter % row_size] - expr_widths[i];
                        try ais.splatByteAll(' ', padding);

                        column_counter += 1;
                        continue;
                    }
                }

                if (single_line and row_size != 1) {
                    try renderToken(r, comma, .space); // ,
                    continue;
                }

                column_counter = 0;
                try renderToken(r, comma, .newline); // ,
                try renderExtraNewline(r, next_expr);
            }
        }

        if (expr_index == array_init.ast.elements.len)
            break;
    }

    ais.popIndent();
    return renderToken(r, rbrace, space); // rbrace
}

fn renderContainerDecl(
    r: *Render,
    container_decl_node: Ast.Node.Index,
    container_decl: Ast.full.ContainerDecl,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    if (container_decl.layout_token) |layout_token| {
        try renderToken(r, layout_token, .space);
    }

    const container: Container = switch (tree.tokenTag(container_decl.ast.main_token)) {
        .keyword_enum => .@"enum",
        .keyword_struct => for (container_decl.ast.members) |member| {
            if (tree.fullContainerField(member)) |field| if (!field.ast.tuple_like) break .other;
        } else .tuple,
        else => .other,
    };

    var lbrace: Ast.TokenIndex = undefined;
    if (container_decl.ast.enum_token) |enum_token| {
        try renderToken(r, container_decl.ast.main_token, .none); // union
        try renderToken(r, enum_token - 1, .none); // lparen
        try renderToken(r, enum_token, .none); // enum
        if (container_decl.ast.arg.unwrap()) |arg| {
            try renderToken(r, enum_token + 1, .none); // lparen
            try renderExpression(r, arg, .none);
            const rparen = tree.lastToken(arg) + 1;
            try renderToken(r, rparen, .none); // rparen
            try renderToken(r, rparen + 1, .space); // rparen
            lbrace = rparen + 2;
        } else {
            try renderToken(r, enum_token + 1, .space); // rparen
            lbrace = enum_token + 2;
        }
    } else if (container_decl.ast.arg.unwrap()) |arg| {
        try renderToken(r, container_decl.ast.main_token, .none); // union
        try renderToken(r, container_decl.ast.main_token + 1, .none); // lparen
        try renderExpression(r, arg, .none);
        const rparen = tree.lastToken(arg) + 1;
        try renderToken(r, rparen, .space); // rparen
        lbrace = rparen + 1;
    } else {
        try renderToken(r, container_decl.ast.main_token, .space); // union
        lbrace = container_decl.ast.main_token + 1;
    }

    const rbrace = tree.lastToken(container_decl_node);

    if (container_decl.ast.members.len == 0) {
        try ais.pushIndent(.normal);
        if (tree.tokenTag(lbrace + 1) == .container_doc_comment) {
            try renderToken(r, lbrace, .newline); // lbrace
            try renderContainerDocComments(r, lbrace + 1);
        } else {
            try renderToken(r, lbrace, .none); // lbrace
        }
        ais.popIndent();
        return renderToken(r, rbrace, space); // rbrace
    }

    const src_has_trailing_comma = tree.tokenTag(rbrace - 1) == .comma;
    if (!src_has_trailing_comma) one_line: {
        // We print all the members in-line unless one of the following conditions are true:

        // 1. The container has comments or multiline strings.
        if (hasComment(tree, lbrace, rbrace) or hasMultilineString(tree, lbrace, rbrace)) {
            break :one_line;
        }

        // 2. The container has a container comment.
        if (tree.tokenTag(lbrace + 1) == .container_doc_comment) break :one_line;

        // 3. A member of the container has a doc comment.
        for (tree.tokens.items(.tag)[lbrace + 1 .. rbrace - 1]) |tag| {
            if (tag == .doc_comment) break :one_line;
        }

        // 4. The container has non-field members.
        for (container_decl.ast.members) |member| {
            if (tree.fullContainerField(member) == null) break :one_line;
        }

        // Print all the declarations on the same line.
        try renderToken(r, lbrace, .space); // lbrace
        for (container_decl.ast.members) |member| {
            try renderMember(r, container, member, .space);
        }
        return renderToken(r, rbrace, space); // rbrace
    }

    // One member per line.
    try ais.pushIndent(.normal);
    try renderToken(r, lbrace, .newline); // lbrace
    if (tree.tokenTag(lbrace + 1) == .container_doc_comment) {
        try renderContainerDocComments(r, lbrace + 1);
    }
    for (container_decl.ast.members, 0..) |member, i| {
        if (i != 0) try renderExtraNewline(r, member);
        switch (tree.nodeTag(member)) {
            // For container fields, ensure a trailing comma is added if necessary.
            .container_field_init,
            .container_field_align,
            .container_field,
            => {
                try ais.pushSpace(.comma);
                try renderMember(r, container, member, .comma);
                ais.popSpace();
            },

            else => try renderMember(r, container, member, .newline),
        }
    }
    ais.popIndent();

    return renderToken(r, rbrace, space); // rbrace
}

fn renderAsm(
    r: *Render,
    asm_node: Ast.full.Asm,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    try renderToken(r, asm_node.ast.asm_token, .space); // asm

    if (asm_node.volatile_token) |volatile_token| {
        try renderToken(r, volatile_token, .space); // volatile
        try renderToken(r, volatile_token + 1, .none); // lparen
    } else {
        try renderToken(r, asm_node.ast.asm_token + 1, .none); // lparen
    }

    if (asm_node.ast.items.len == 0) {
        try ais.forcePushIndent(.normal);
        if (asm_node.first_clobber) |first_clobber| {
            // asm ("foo" ::: "a", "b")
            // asm ("foo" ::: "a", "b",)
            try renderExpression(r, asm_node.ast.template, .space);
            // Render the three colons.
            try renderToken(r, first_clobber - 3, .none);
            try renderToken(r, first_clobber - 2, .none);
            try renderToken(r, first_clobber - 1, .space);

            var tok_i = first_clobber;
            while (true) : (tok_i += 1) {
                try renderToken(r, tok_i, .none);
                tok_i += 1;
                switch (tree.tokenTag(tok_i)) {
                    .r_paren => {
                        ais.popIndent();
                        return renderToken(r, tok_i, space);
                    },
                    .comma => {
                        if (tree.tokenTag(tok_i + 1) == .r_paren) {
                            ais.popIndent();
                            return renderToken(r, tok_i + 1, space);
                        } else {
                            try renderToken(r, tok_i, .space);
                        }
                    },
                    else => unreachable,
                }
            }
        } else {
            // asm ("foo")
            try renderExpression(r, asm_node.ast.template, .none);
            ais.popIndent();
            return renderToken(r, asm_node.ast.rparen, space); // rparen
        }
    }

    try ais.forcePushIndent(.normal);
    try renderExpression(r, asm_node.ast.template, .newline);
    ais.setIndentDelta(asm_indent_delta);
    const colon1 = tree.lastToken(asm_node.ast.template) + 1;

    const colon2 = if (asm_node.outputs.len == 0) colon2: {
        try renderToken(r, colon1, .newline); // :
        break :colon2 colon1 + 1;
    } else colon2: {
        try renderToken(r, colon1, .space); // :

        try ais.forcePushIndent(.normal);
        for (asm_node.outputs, 0..) |asm_output, i| {
            if (i + 1 < asm_node.outputs.len) {
                const next_asm_output = asm_node.outputs[i + 1];
                try renderAsmOutput(r, asm_output, .none);

                const comma = tree.firstToken(next_asm_output) - 1;
                try renderToken(r, comma, .newline); // ,
                try renderExtraNewlineToken(r, tree.firstToken(next_asm_output));
            } else if (asm_node.inputs.len == 0 and asm_node.first_clobber == null) {
                try ais.pushSpace(.comma);
                try renderAsmOutput(r, asm_output, .comma);
                ais.popSpace();
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(r, asm_node.ast.rparen, space); // rparen
            } else {
                try ais.pushSpace(.comma);
                try renderAsmOutput(r, asm_output, .comma);
                ais.popSpace();
                const comma_or_colon = tree.lastToken(asm_output) + 1;
                ais.popIndent();
                break :colon2 switch (tree.tokenTag(comma_or_colon)) {
                    .comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        } else unreachable;
    };

    const colon3 = if (asm_node.inputs.len == 0) colon3: {
        try renderToken(r, colon2, .newline); // :
        break :colon3 colon2 + 1;
    } else colon3: {
        try renderToken(r, colon2, .space); // :
        try ais.forcePushIndent(.normal);
        for (asm_node.inputs, 0..) |asm_input, i| {
            if (i + 1 < asm_node.inputs.len) {
                const next_asm_input = asm_node.inputs[i + 1];
                try renderAsmInput(r, asm_input, .none);

                const first_token = tree.firstToken(next_asm_input);
                try renderToken(r, first_token - 1, .newline); // ,
                try renderExtraNewlineToken(r, first_token);
            } else if (asm_node.first_clobber == null) {
                try ais.pushSpace(.comma);
                try renderAsmInput(r, asm_input, .comma);
                ais.popSpace();
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(r, asm_node.ast.rparen, space); // rparen
            } else {
                try ais.pushSpace(.comma);
                try renderAsmInput(r, asm_input, .comma);
                ais.popSpace();
                const comma_or_colon = tree.lastToken(asm_input) + 1;
                ais.popIndent();
                break :colon3 switch (tree.tokenTag(comma_or_colon)) {
                    .comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        }
        unreachable;
    };

    try renderToken(r, colon3, .space); // :
    const first_clobber = asm_node.first_clobber.?;
    var tok_i = first_clobber;
    while (true) {
        switch (tree.tokenTag(tok_i + 1)) {
            .r_paren => {
                ais.setIndentDelta(indent_delta);
                try renderToken(r, tok_i, .newline);
                ais.popIndent();
                return renderToken(r, tok_i + 1, space);
            },
            .comma => {
                switch (tree.tokenTag(tok_i + 2)) {
                    .r_paren => {
                        ais.setIndentDelta(indent_delta);
                        try renderToken(r, tok_i, .newline);
                        ais.popIndent();
                        return renderToken(r, tok_i + 2, space);
                    },
                    else => {
                        try renderToken(r, tok_i, .none);
                        try renderToken(r, tok_i + 1, .space);
                        tok_i += 2;
                    },
                }
            },
            else => unreachable,
        }
    }
}

fn renderCall(
    r: *Render,
    call: Ast.full.Call,
    space: Space,
) Error!void {
    try renderExpression(r, call.ast.fn_expr, .none);
    try renderParamList(r, call.ast.lparen, call.ast.params, space);
}

fn renderParamList(
    r: *Render,
    lparen: Ast.TokenIndex,
    params: []const Ast.Node.Index,
    space: Space,
) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    if (params.len == 0) {
        try ais.pushIndent(.normal);
        try renderToken(r, lparen, .none);
        ais.popIndent();
        return renderToken(r, lparen + 1, space); // )
    }

    const last_param = params[params.len - 1];
    const after_last_param_tok = tree.lastToken(last_param) + 1;
    if (tree.tokenTag(after_last_param_tok) == .comma) {
        try ais.pushIndent(.normal);
        try renderToken(r, lparen, .newline); // (
        for (params, 0..) |param_node, i| {
            if (i + 1 < params.len) {
                try renderExpression(r, param_node, .none);

                const comma = tree.lastToken(param_node) + 1;
                try renderToken(r, comma, .newline); // ,

                try renderExtraNewline(r, params[i + 1]);
            } else {
                try ais.pushSpace(.comma);
                try renderExpression(r, param_node, .comma);
                ais.popSpace();
            }
        }
        ais.popIndent();
        return renderToken(r, after_last_param_tok + 1, space); // )
    }

    try ais.pushIndent(.normal);
    try renderToken(r, lparen, .none); // (
    for (params, 0..) |param_node, i| {
        try renderExpression(r, param_node, .none);

        if (i + 1 < params.len) {
            const comma = tree.lastToken(param_node) + 1;
            const next_multiline_string =
                tree.tokenTag(tree.firstToken(params[i + 1])) == .multiline_string_literal_line;
            const comma_space: Space = if (next_multiline_string) .none else .space;
            try renderToken(r, comma, comma_space);
        }
    }
    ais.popIndent();
    return renderToken(r, after_last_param_tok, space); // )
}

/// Render an expression, and the comma that follows it, if it is present in the source.
/// If a comma is present, and `space` is `Space.comma`, render only a single comma.
fn renderExpressionComma(r: *Render, node: Ast.Node.Index, space: Space) Error!void {
    const tree = r.tree;
    const maybe_comma = tree.lastToken(node) + 1;
    if (tree.tokenTag(maybe_comma) == .comma and space != .comma) {
        try renderExpression(r, node, .none);
        return renderToken(r, maybe_comma, space);
    } else {
        return renderExpression(r, node, space);
    }
}

/// Render a token, and the comma that follows it, if it is present in the source.
/// If a comma is present, and `space` is `Space.comma`, render only a single comma.
fn renderTokenComma(r: *Render, token: Ast.TokenIndex, space: Space) Error!void {
    const tree = r.tree;
    const maybe_comma = token + 1;
    if (tree.tokenTag(maybe_comma) == .comma and space != .comma) {
        try renderToken(r, token, .none);
        return renderToken(r, maybe_comma, space);
    } else {
        return renderToken(r, token, space);
    }
}

/// Render an identifier, and the comma that follows it, if it is present in the source.
/// If a comma is present, and `space` is `Space.comma`, render only a single comma.
fn renderIdentifierComma(r: *Render, token: Ast.TokenIndex, space: Space, quote: QuoteBehavior) Error!void {
    const tree = r.tree;
    const maybe_comma = token + 1;
    if (tree.tokenTag(maybe_comma) == .comma and space != .comma) {
        try renderIdentifier(r, token, .none, quote);
        return renderToken(r, maybe_comma, space);
    } else {
        return renderIdentifier(r, token, space, quote);
    }
}

const Space = enum {
    /// Output the token lexeme only.
    none,
    /// Output the token lexeme followed by a single space.
    space,
    /// Output the token lexeme followed by a newline.
    newline,
    /// If the next token is a comma, render it as well. If not, insert one.
    /// In either case, a newline will be inserted afterwards.
    comma,
    /// Additionally consume the next token if it is a comma.
    /// In either case, a space will be inserted afterwards.
    comma_space,
    /// Additionally consume the next token if it is a semicolon.
    /// In either case, a newline will be inserted afterwards.
    semicolon,
    /// Skip rendering whitespace and comments. If this is used, the caller
    /// *must* handle whitespace and comments manually.
    skip,
};

fn renderToken(r: *Render, token_index: Ast.TokenIndex, space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const lexeme = tokenSliceForRender(tree, token_index);
    try ais.writeAll(lexeme);
    try renderSpace(r, token_index, lexeme.len, space);
}

fn renderTokenOverrideSpaceMode(r: *Render, token_index: Ast.TokenIndex, space: Space, override_space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const lexeme = tokenSliceForRender(tree, token_index);
    try ais.writeAll(lexeme);
    ais.enableSpaceMode(override_space);
    defer ais.disableSpaceMode();
    try renderSpace(r, token_index, lexeme.len, space);
}

fn renderSpace(r: *Render, token_index: Ast.TokenIndex, lexeme_len: usize, space: Space) Error!void {
    const tree = r.tree;
    const ais = r.ais;

    const next_token_tag = tree.tokenTag(token_index + 1);

    if (space == .skip) return;

    if (space == .comma and next_token_tag != .comma) {
        try ais.underlying_writer.writeByte(',');
    }
    if (space == .semicolon or space == .comma) ais.enableSpaceMode(space);
    defer ais.disableSpaceMode();
    const comment = try renderComments(
        r,
        tree.tokenStart(token_index) + lexeme_len,
        tree.tokenStart(token_index + 1),
    );
    switch (space) {
        .none => {},
        .space => if (!comment) try ais.writeByte(' '),
        .newline => if (!comment) try ais.insertNewline(),

        .comma => if (next_token_tag == .comma) {
            try renderToken(r, token_index + 1, .newline);
        } else if (!comment) {
            try ais.insertNewline();
        },

        .comma_space => if (next_token_tag == .comma) {
            try renderToken(r, token_index + 1, .space);
        } else if (!comment) {
            try ais.writeByte(' ');
        },

        .semicolon => if (next_token_tag == .semicolon) {
            try renderToken(r, token_index + 1, .newline);
        } else if (!comment) {
            try ais.insertNewline();
        },

        .skip => unreachable,
    }
}

fn renderOnlySpace(r: *Render, space: Space) Error!void {
    const ais = r.ais;
    switch (space) {
        .none => {},
        .space => try ais.writeByte(' '),
        .newline => try ais.insertNewline(),
        .comma => try ais.writeAll(",\n"),
        .comma_space => try ais.writeAll(", "),
        .semicolon => try ais.writeAll(";\n"),
        .skip => unreachable,
    }
}

const QuoteBehavior = enum {
    preserve_when_shadowing,
    eagerly_unquote,
    eagerly_unquote_except_underscore,
};

fn renderIdentifier(r: *Render, token_index: Ast.TokenIndex, space: Space, quote: QuoteBehavior) Error!void {
    const tree = r.tree;
    assert(tree.tokenTag(token_index) == .identifier);
    const lexeme = tokenSliceForRender(tree, token_index);

    if (r.fixups.rename_identifiers.get(lexeme)) |mangled| {
        try r.ais.writeAll(mangled);
        try renderSpace(r, token_index, lexeme.len, space);
        return;
    }

    if (lexeme[0] != '@') {
        return renderToken(r, token_index, space);
    }

    assert(lexeme.len >= 3);
    assert(lexeme[0] == '@');
    assert(lexeme[1] == '\"');
    assert(lexeme[lexeme.len - 1] == '\"');
    const contents = lexeme[2 .. lexeme.len - 1]; // inside the @"" quotation

    // Empty name can't be unquoted.
    if (contents.len == 0) {
        return renderQuotedIdentifier(r, token_index, space, false);
    }

    // Special case for _.
    if (std.zig.isUnderscore(contents)) switch (quote) {
        .eagerly_unquote => return renderQuotedIdentifier(r, token_index, space, true),
        .eagerly_unquote_except_underscore,
        .preserve_when_shadowing,
        => return renderQuotedIdentifier(r, token_index, space, false),
    };

    // Scan the entire name for characters that would (after un-escaping) be illegal in a symbol,
    // i.e. contents don't match: [A-Za-z_][A-Za-z0-9_]*
    var contents_i: usize = 0;
    while (contents_i < contents.len) {
        switch (contents[contents_i]) {
            '0'...'9' => if (contents_i == 0) return renderQuotedIdentifier(r, token_index, space, false),
            'A'...'Z', 'a'...'z', '_' => {},
            '\\' => {
                var esc_offset = contents_i;
                const res = std.zig.string_literal.parseEscapeSequence(contents, &esc_offset);
                switch (res) {
                    .success => |char| switch (char) {
                        '0'...'9' => if (contents_i == 0) return renderQuotedIdentifier(r, token_index, space, false),
                        'A'...'Z', 'a'...'z', '_' => {},
                        else => return renderQuotedIdentifier(r, token_index, space, false),
                    },
                    .failure => return renderQuotedIdentifier(r, token_index, space, false),
                }
                contents_i += esc_offset;
                continue;
            },
            else => return renderQuotedIdentifier(r, token_index, space, false),
        }
        contents_i += 1;
    }

    // Read enough of the name (while un-escaping) to determine if it's a keyword or primitive.
    // If it's too long to fit in this buffer, we know it's neither and quoting is unnecessary.
    // If we read the whole thing, we have to do further checks.
    const longest_keyword_or_primitive_len = comptime blk: {
        var longest = 0;
        for (primitives.names.keys()) |key| {
            if (key.len > longest) longest = key.len;
        }
        for (std.zig.Token.keywords.keys()) |key| {
            if (key.len > longest) longest = key.len;
        }
        break :blk longest;
    };
    var buf: [longest_keyword_or_primitive_len]u8 = undefined;

    contents_i = 0;
    var buf_i: usize = 0;
    while (contents_i < contents.len and buf_i < longest_keyword_or_primitive_len) {
        if (contents[contents_i] == '\\') {
            const res = std.zig.string_literal.parseEscapeSequence(contents, &contents_i).success;
            buf[buf_i] = @as(u8, @intCast(res));
            buf_i += 1;
        } else {
            buf[buf_i] = contents[contents_i];
            contents_i += 1;
            buf_i += 1;
        }
    }

    // We read the whole thing, so it could be a keyword or primitive.
    if (contents_i == contents.len) {
        if (!std.zig.isValidId(buf[0..buf_i])) {
            return renderQuotedIdentifier(r, token_index, space, false);
        }
        if (primitives.isPrimitive(buf[0..buf_i])) switch (quote) {
            .eagerly_unquote,
            .eagerly_unquote_except_underscore,
            => return renderQuotedIdentifier(r, token_index, space, true),
            .preserve_when_shadowing => return renderQuotedIdentifier(r, token_index, space, false),
        };
    }

    try renderQuotedIdentifier(r, token_index, space, true);
}

// Renders a @"" quoted identifier, normalizing escapes.
// Unnecessary escapes are un-escaped, and \u escapes are normalized to \x when they fit.
// If unquote is true, the @"" is removed and the result is a bare symbol whose validity is asserted.
fn renderQuotedIdentifier(r: *Render, token_index: Ast.TokenIndex, space: Space, comptime unquote: bool) !void {
    const tree = r.tree;
    const ais = r.ais;
    assert(tree.tokenTag(token_index) == .identifier);
    const lexeme = tokenSliceForRender(tree, token_index);
    assert(lexeme.len >= 3 and lexeme[0] == '@');

    if (!unquote) try ais.writeAll("@\"");
    const contents = lexeme[2 .. lexeme.len - 1];
    try renderIdentifierContents(ais, contents);
    if (!unquote) try ais.writeByte('\"');

    try renderSpace(r, token_index, lexeme.len, space);
}

fn renderIdentifierContents(ais: *AutoIndentingStream, bytes: []const u8) !void {
    var pos: usize = 0;
    while (pos < bytes.len) {
        const byte = bytes[pos];
        switch (byte) {
            '\\' => {
                const old_pos = pos;
                const res = std.zig.string_literal.parseEscapeSequence(bytes, &pos);
                const escape_sequence = bytes[old_pos..pos];
                switch (res) {
                    .success => |codepoint| {
                        if (codepoint <= 0x7f) {
                            const buf = [1]u8{@as(u8, @intCast(codepoint))};
                            try ais.print("{f}", .{std.zig.fmtString(&buf)});
                        } else {
                            try ais.writeAll(escape_sequence);
                        }
                    },
                    .failure => {
                        try ais.writeAll(escape_sequence);
                    },
                }
            },
            0x00...('\\' - 1), ('\\' + 1)...0x7f => {
                const buf = [1]u8{byte};
                try ais.print("{f}", .{std.zig.fmtString(&buf)});
                pos += 1;
            },
            0x80...0xff => {
                try ais.writeByte(byte);
                pos += 1;
            },
        }
    }
}

/// Returns true if there exists a line comment between any of the tokens from
/// `start_token` to `end_token`. This is used to determine if e.g. a
/// fn_proto should be wrapped and have a trailing comma inserted even if
/// there is none in the source.
fn hasComment(tree: Ast, start_token: Ast.TokenIndex, end_token: Ast.TokenIndex) bool {
    for (start_token..end_token) |i| {
        const token: Ast.TokenIndex = @intCast(i);
        const start = tree.tokenStart(token) + tree.tokenSlice(token).len;
        const end = tree.tokenStart(token + 1);
        if (mem.indexOf(u8, tree.source[start..end], "//") != null) return true;
    }

    return false;
}

/// Returns true if there exists a multiline string literal between the start
/// of token `start_token` and the start of token `end_token`.
fn hasMultilineString(tree: Ast, start_token: Ast.TokenIndex, end_token: Ast.TokenIndex) bool {
    return std.mem.indexOfScalar(
        Token.Tag,
        tree.tokens.items(.tag)[start_token..end_token],
        .multiline_string_literal_line,
    ) != null;
}

/// Assumes that start is the first byte past the previous token and
/// that end is the last byte before the next token.
fn renderComments(r: *Render, start: usize, end: usize) Error!bool {
    const tree = r.tree;
    const ais = r.ais;

    var index: usize = start;
    while (mem.indexOf(u8, tree.source[index..end], "//")) |offset| {
        const comment_start = index + offset;

        // If there is no newline, the comment ends with EOF
        const newline_index = mem.indexOfScalar(u8, tree.source[comment_start..end], '\n');
        const newline = if (newline_index) |i| comment_start + i else null;

        const untrimmed_comment = tree.source[comment_start .. newline orelse tree.source.len];
        const trimmed_comment = mem.trimEnd(u8, untrimmed_comment, &std.ascii.whitespace);

        // Don't leave any whitespace at the start of the file
        if (index != 0) {
            if (index == start and mem.containsAtLeast(u8, tree.source[index..comment_start], 2, "\n")) {
                // Leave up to one empty line before the first comment
                try ais.insertNewline();
                try ais.insertNewline();
            } else if (mem.indexOfScalar(u8, tree.source[index..comment_start], '\n') != null) {
                // Respect the newline directly before the comment.
                // Note: This allows an empty line between comments
                try ais.insertNewline();
            } else if (index == start) {
                // Otherwise if the first comment is on the same line as
                // the token before it, prefix it with a single space.
                try ais.writeByte(' ');
            }
        }

        index = 1 + (newline orelse end - 1);

        const comment_content = mem.trimStart(u8, trimmed_comment["//".len..], &std.ascii.whitespace);
        if (ais.disabled_offset != null and mem.eql(u8, comment_content, "zig fmt: on")) {
            // Write the source for which formatting was disabled directly
            // to the underlying writer, fixing up invalid whitespace.
            const disabled_source = tree.source[ais.disabled_offset.?..comment_start];
            try writeFixingWhitespace(ais.underlying_writer, disabled_source);
            // Write with the canonical single space.
            try ais.underlying_writer.writeAll("// zig fmt: on\n");
            ais.disabled_offset = null;
        } else if (ais.disabled_offset == null and mem.eql(u8, comment_content, "zig fmt: off")) {
            // Write with the canonical single space.
            try ais.writeAll("// zig fmt: off\n");
            ais.disabled_offset = index;
        } else {
            // Write the comment minus trailing whitespace.
            try ais.print("{s}\n", .{trimmed_comment});
        }
    }

    if (index != start and mem.containsAtLeast(u8, tree.source[index - 1 .. end], 2, "\n")) {
        // Don't leave any whitespace at the end of the file
        if (end != tree.source.len) {
            try ais.insertNewline();
        }
    }

    return index != start;
}

fn renderExtraNewline(r: *Render, node: Ast.Node.Index) Error!void {
    return renderExtraNewlineToken(r, r.tree.firstToken(node));
}

/// Check if there is an empty line immediately before the given token. If so, render it.
fn renderExtraNewlineToken(r: *Render, token_index: Ast.TokenIndex) Error!void {
    const tree = r.tree;
    const ais = r.ais;
    const token_start = tree.tokenStart(token_index);
    if (token_start == 0) return;
    const prev_token_end = if (token_index == 0)
        0
    else
        tree.tokenStart(token_index - 1) + tokenSliceForRender(tree, token_index - 1).len;

    // If there is a immediately preceding comment or doc_comment,
    // skip it because required extra newline has already been rendered.
    if (mem.indexOf(u8, tree.source[prev_token_end..token_start], "//") != null) return;
    if (tree.isTokenPrecededByTags(token_index, &.{.doc_comment})) return;

    // Iterate backwards to the end of the previous token, stopping if a
    // non-whitespace character is encountered or two newlines have been found.
    var i = token_start - 1;
    var newlines: u2 = 0;
    while (std.ascii.isWhitespace(tree.source[i])) : (i -= 1) {
        if (tree.source[i] == '\n') newlines += 1;
        if (newlines == 2) return ais.insertNewline();
        if (i == prev_token_end) break;
    }
}

/// end_token is the token one past the last doc comment token. This function
/// searches backwards from there.
fn renderDocComments(r: *Render, end_token: Ast.TokenIndex) Error!void {
    const tree = r.tree;
    // Search backwards for the first doc comment.
    if (end_token == 0) return;
    var tok = end_token - 1;
    while (tree.tokenTag(tok) == .doc_comment) {
        if (tok == 0) break;
        tok -= 1;
    } else {
        tok += 1;
    }
    const first_tok = tok;
    if (first_tok == end_token) return;

    if (first_tok != 0) {
        const prev_token_tag = tree.tokenTag(first_tok - 1);

        // Prevent accidental use of `renderDocComments` for a function argument doc comment
        assert(prev_token_tag != .l_paren);

        if (prev_token_tag != .l_brace) {
            try renderExtraNewlineToken(r, first_tok);
        }
    }

    while (tree.tokenTag(tok) == .doc_comment) : (tok += 1) {
        try renderToken(r, tok, .newline);
    }
}

/// start_token is first container doc comment token.
fn renderContainerDocComments(r: *Render, start_token: Ast.TokenIndex) Error!void {
    const tree = r.tree;
    var tok = start_token;
    while (tree.tokenTag(tok) == .container_doc_comment) : (tok += 1) {
        try renderToken(r, tok, .newline);
    }
    // Render extra newline if there is one between final container doc comment and
    // the next token. If the next token is a doc comment, that code path
    // will have its own logic to insert a newline.
    if (tree.tokenTag(tok) != .doc_comment) {
        try renderExtraNewlineToken(r, tok);
    }
}

fn discardAllParams(r: *Render, fn_proto_node: Ast.Node.Index) Error!void {
    const tree = &r.tree;
    const ais = r.ais;
    var buf: [1]Ast.Node.Index = undefined;
    const fn_proto = tree.fullFnProto(&buf, fn_proto_node).?;
    var it = fn_proto.iterate(tree);
    while (it.next()) |param| {
        const name_ident = param.name_token.?;
        assert(tree.tokenTag(name_ident) == .identifier);
        try ais.writeAll("_ = ");
        try ais.writeAll(tokenSliceForRender(r.tree, name_ident));
        try ais.writeAll(";\n");
    }
}

fn tokenSliceForRender(tree: Ast, token_index: Ast.TokenIndex) []const u8 {
    var ret = tree.tokenSlice(token_index);
    switch (tree.tokenTag(token_index)) {
        .container_doc_comment, .doc_comment => {
            ret = mem.trimEnd(u8, ret, &std.ascii.whitespace);
        },
        else => {},
    }
    return ret;
}

fn hasSameLineComment(tree: Ast, token_index: Ast.TokenIndex) bool {
    const between_source = tree.source[tree.tokenStart(token_index)..tree.tokenStart(token_index + 1)];
    for (between_source) |byte| switch (byte) {
        '\n' => return false,
        '/' => return true,
        else => continue,
    };
    return false;
}

/// Returns `true` if and only if there are any tokens or line comments between
/// start_token and end_token.
fn anythingBetween(tree: Ast, start_token: Ast.TokenIndex, end_token: Ast.TokenIndex) bool {
    if (start_token + 1 != end_token) return true;
    const between_source = tree.source[tree.tokenStart(start_token)..tree.tokenStart(start_token + 1)];
    for (between_source) |byte| switch (byte) {
        '/' => return true,
        else => continue,
    };
    return false;
}

fn writeFixingWhitespace(w: *Writer, slice: []const u8) Error!void {
    for (slice) |byte| switch (byte) {
        '\t' => try w.splatByteAll(' ', indent_delta),
        '\r' => {},
        else => try w.writeByte(byte),
    };
}

fn nodeIsBlock(tag: Ast.Node.Tag) bool {
    return switch (tag) {
        .block,
        .block_semicolon,
        .block_two,
        .block_two_semicolon,
        => true,
        else => false,
    };
}

fn nodeIsIfForWhileSwitch(tag: Ast.Node.Tag) bool {
    return switch (tag) {
        .@"if",
        .if_simple,
        .@"for",
        .for_simple,
        .@"while",
        .while_simple,
        .while_cont,
        .@"switch",
        .switch_comma,
        => true,
        else => false,
    };
}

fn nodeCausesSliceOpSpace(tag: Ast.Node.Tag) bool {
    return switch (tag) {
        .@"catch",
        .add,
        .add_wrap,
        .array_cat,
        .array_mult,
        .assign,
        .assign_bit_and,
        .assign_bit_or,
        .assign_shl,
        .assign_shr,
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
        .shl,
        .shr,
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
        .sub,
        .sub_wrap,
        .@"orelse",
        => true,

        else => false,
    };
}

// Returns the number of nodes in `exprs` that are on the same line as `rtoken`.
fn rowSize(tree: Ast, exprs: []const Ast.Node.Index, rtoken: Ast.TokenIndex) usize {
    const first_token = tree.firstToken(exprs[0]);
    if (tree.tokensOnSameLine(first_token, rtoken)) {
        const maybe_comma = rtoken - 1;
        if (tree.tokenTag(maybe_comma) == .comma)
            return 1;
        return exprs.len; // no newlines
    }

    var count: usize = 1;
    for (exprs, 0..) |expr, i| {
        if (i + 1 < exprs.len) {
            const expr_last_token = tree.lastToken(expr) + 1;
            if (!tree.tokensOnSameLine(expr_last_token, tree.firstToken(exprs[i + 1]))) return count;
            count += 1;
        } else {
            return count;
        }
    }
    unreachable;
}

/// Automatically inserts indentation of written data by keeping
/// track of the current indentation level
///
/// We introduce a new indentation scope with pushIndent/popIndent whenever
/// we potentially want to introduce an indent after the next newline.
///
/// Indentation should only ever increment by one from one line to the next,
/// no matter how many new indentation scopes are introduced. This is done by
/// only realizing the indentation from the most recent scope. As an example:
///
///         while (foo) if (bar)
///             f(x);
///
/// The body of `while` introduces a new indentation scope and the body of
/// `if` also introduces a new indentation scope. When the newline is seen,
/// only the indentation scope of the `if` is realized, and the `while` is
/// not.
///
/// As comments are rendered during space rendering, we need to keep track
/// of the appropriate indentation level for them with pushSpace/popSpace.
/// This should be done whenever a scope that ends in a .semicolon or a
/// .comma is introduced.
const AutoIndentingStream = struct {
    underlying_writer: *Writer,

    /// Offset into the source at which formatting has been disabled with
    /// a `zig fmt: off` comment.
    ///
    /// If non-null, the AutoIndentingStream will not write any bytes
    /// to the underlying writer. It will however continue to track the
    /// indentation level.
    disabled_offset: ?usize = null,

    indent_count: usize = 0,
    indent_delta: usize,
    indent_stack: std.ArrayList(StackElem),
    space_stack: std.ArrayList(SpaceElem),
    space_mode: ?usize = null,
    disable_indent_committing: usize = 0,
    current_line_empty: bool = true,
    /// the most recently applied indent
    applied_indent: usize = 0,

    pub const IndentType = enum {
        normal,
        after_equals,
        binop,
        field_access,
    };
    const StackElem = struct {
        indent_type: IndentType,
        realized: bool,
    };
    const SpaceElem = struct {
        space: Space,
        indent_count: usize,
    };

    pub fn init(gpa: Allocator, w: *Writer, starting_indent_delta: usize) AutoIndentingStream {
        return .{
            .underlying_writer = w,
            .indent_delta = starting_indent_delta,
            .indent_stack = .init(gpa),
            .space_stack = .init(gpa),
        };
    }

    pub fn deinit(self: *AutoIndentingStream) void {
        self.indent_stack.deinit();
        self.space_stack.deinit();
    }

    pub fn writeAll(ais: *AutoIndentingStream, bytes: []const u8) Error!void {
        if (bytes.len == 0) return;
        try ais.applyIndent();
        if (ais.disabled_offset == null) try ais.underlying_writer.writeAll(bytes);
        if (bytes[bytes.len - 1] == '\n') ais.resetLine();
    }

    /// Assumes that if the printed data ends with a newline, it is directly
    /// contained in the format string.
    pub fn print(ais: *AutoIndentingStream, comptime format: []const u8, args: anytype) Error!void {
        try ais.applyIndent();
        if (ais.disabled_offset == null) try ais.underlying_writer.print(format, args);
        if (format[format.len - 1] == '\n') ais.resetLine();
    }

    pub fn writeByte(ais: *AutoIndentingStream, byte: u8) Error!void {
        try ais.applyIndent();
        if (ais.disabled_offset == null) try ais.underlying_writer.writeByte(byte);
        assert(byte != '\n');
    }

    pub fn splatByteAll(ais: *AutoIndentingStream, byte: u8, n: usize) Error!void {
        assert(byte != '\n');
        try ais.applyIndent();
        if (ais.disabled_offset == null) try ais.underlying_writer.splatByteAll(byte, n);
    }

    // Change the indent delta without changing the final indentation level
    pub fn setIndentDelta(ais: *AutoIndentingStream, new_indent_delta: usize) void {
        if (ais.indent_delta == new_indent_delta) {
            return;
        } else if (ais.indent_delta > new_indent_delta) {
            assert(ais.indent_delta % new_indent_delta == 0);
            ais.indent_count = ais.indent_count * (ais.indent_delta / new_indent_delta);
        } else {
            // assert that the current indentation (in spaces) in a multiple of the new delta
            assert((ais.indent_count * ais.indent_delta) % new_indent_delta == 0);
            ais.indent_count = ais.indent_count / (new_indent_delta / ais.indent_delta);
        }
        ais.indent_delta = new_indent_delta;
    }

    pub fn insertNewline(ais: *AutoIndentingStream) Error!void {
        if (ais.disabled_offset == null) try ais.underlying_writer.writeByte('\n');
        ais.resetLine();
    }

    /// Insert a newline unless the current line is blank
    pub fn maybeInsertNewline(ais: *AutoIndentingStream) Error!void {
        if (!ais.current_line_empty)
            try ais.insertNewline();
    }

    /// Push an indent that is automatically popped after being applied
    pub fn pushIndentOneShot(ais: *AutoIndentingStream) void {
        ais.indent_one_shot_count += 1;
        ais.pushIndent();
    }

    /// Turns all one-shot indents into regular indents
    /// Returns number of indents that must now be manually popped
    pub fn lockOneShotIndent(ais: *AutoIndentingStream) usize {
        const locked_count = ais.indent_one_shot_count;
        ais.indent_one_shot_count = 0;
        return locked_count;
    }

    /// Push an indent that should not take effect until the next line
    pub fn pushIndentNextLine(ais: *AutoIndentingStream) void {
        ais.indent_next_line += 1;
        ais.pushIndent();
    }

    /// Checks to see if the most recent indentation exceeds the currently pushed indents
    pub fn isLineOverIndented(ais: *AutoIndentingStream) bool {
        if (ais.current_line_empty) return false;
        return ais.applied_indent > ais.currentIndent();
    }

    fn resetLine(ais: *AutoIndentingStream) void {
        ais.current_line_empty = true;

        if (ais.disable_indent_committing > 0) return;

        if (ais.indent_stack.items.len > 0) {
            // By default, we realize the most recent indentation scope.
            var to_realize = ais.indent_stack.items.len - 1;

            if (ais.indent_stack.items.len >= 2 and
                ais.indent_stack.items[to_realize - 1].indent_type == .after_equals and
                ais.indent_stack.items[to_realize - 1].realized and
                ais.indent_stack.items[to_realize].indent_type == .binop)
            {
                // If we are in a .binop scope and our direct parent is .after_equals, don't indent.
                // This ensures correct indentation in the below example:
                //
                //        const foo =
                //            (x >= 'a' and x <= 'z') or         //<-- we are here
                //            (x >= 'A' and x <= 'Z');
                //
                return;
            }

            if (ais.indent_stack.items[to_realize].indent_type == .field_access) {
                // Only realize the top-most field_access in a chain.
                while (to_realize > 0 and ais.indent_stack.items[to_realize - 1].indent_type == .field_access)
                    to_realize -= 1;
            }

            if (ais.indent_stack.items[to_realize].realized) return;
            ais.indent_stack.items[to_realize].realized = true;
            ais.indent_count += 1;
        }
    }

    /// Disables indentation level changes during the next newlines until re-enabled.
    pub fn disableIndentCommitting(ais: *AutoIndentingStream) void {
        ais.disable_indent_committing += 1;
    }

    pub fn enableIndentCommitting(ais: *AutoIndentingStream) void {
        assert(ais.disable_indent_committing > 0);
        ais.disable_indent_committing -= 1;
    }

    pub fn pushSpace(ais: *AutoIndentingStream, space: Space) !void {
        try ais.space_stack.append(.{ .space = space, .indent_count = ais.indent_count });
    }

    pub fn popSpace(ais: *AutoIndentingStream) void {
        _ = ais.space_stack.pop();
    }

    /// Sets current indentation level to be the same as that of the last pushSpace.
    pub fn enableSpaceMode(ais: *AutoIndentingStream, space: Space) void {
        if (ais.space_stack.items.len == 0) return;
        const curr = ais.space_stack.getLast();
        if (curr.space != space) return;
        ais.space_mode = curr.indent_count;
    }

    pub fn disableSpaceMode(ais: *AutoIndentingStream) void {
        ais.space_mode = null;
    }

    pub fn lastSpaceModeIndent(ais: *AutoIndentingStream) usize {
        if (ais.space_stack.items.len == 0) return 0;
        return ais.space_stack.getLast().indent_count * ais.indent_delta;
    }

    /// Push default indentation
    /// Doesn't actually write any indentation.
    /// Just primes the stream to be able to write the correct indentation if it needs to.
    pub fn pushIndent(ais: *AutoIndentingStream, indent_type: IndentType) !void {
        try ais.indent_stack.append(.{ .indent_type = indent_type, .realized = false });
    }

    /// Forces an indentation level to be realized.
    pub fn forcePushIndent(ais: *AutoIndentingStream, indent_type: IndentType) !void {
        try ais.indent_stack.append(.{ .indent_type = indent_type, .realized = true });
        ais.indent_count += 1;
    }

    pub fn popIndent(ais: *AutoIndentingStream) void {
        if (ais.indent_stack.pop().?.realized) {
            assert(ais.indent_count > 0);
            ais.indent_count -= 1;
        }
    }

    pub fn indentStackEmpty(ais: *AutoIndentingStream) bool {
        return ais.indent_stack.items.len == 0;
    }

    /// Writes ' ' bytes if the current line is empty
    fn applyIndent(ais: *AutoIndentingStream) Error!void {
        const current_indent = ais.currentIndent();
        if (ais.current_line_empty and current_indent > 0) {
            if (ais.disabled_offset == null) {
                try ais.underlying_writer.splatByteAll(' ', current_indent);
            }
            ais.applied_indent = current_indent;
        }
        ais.current_line_empty = false;
    }

    fn currentIndent(ais: *AutoIndentingStream) usize {
        const indent_count = ais.space_mode orelse ais.indent_count;
        return indent_count * ais.indent_delta;
    }
};
