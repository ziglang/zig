// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const meta = std.meta;
const ast = std.zig.ast;
const Token = std.zig.Token;

const indent_delta = 4;
const asm_indent_delta = 2;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering, or
    /// ran out of memory allocating space in the output buffer.
    OutOfMemory,
};

const Writer = std.ArrayList(u8).Writer;
const Ais = std.io.AutoIndentingStream(Writer);

/// `gpa` is used for allocating the resulting formatted source code, as well as
/// for allocating extra stack memory if needed, because this function utilizes recursion.
/// Note: that's not actually true yet, see https://github.com/ziglang/zig/issues/1006.
/// Caller owns the returned slice of bytes, allocated with `gpa`.
pub fn render(gpa: *mem.Allocator, tree: ast.Tree) Error![]u8 {
    assert(tree.errors.len == 0); // Cannot render an invalid tree.

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, buffer.writer());
    try renderRoot(&auto_indenting_stream, tree);
    return buffer.toOwnedSlice();
}

/// Assumes there are no tokens in between start and end.
fn renderComments(ais: *Ais, tree: ast.Tree, start: usize, end: usize, prefix: []const u8) Error!usize {
    var index: usize = start;
    var count: usize = 0;
    while (true) {
        const comment_start = index +
            (mem.indexOf(u8, tree.source[index..end], "//") orelse return count);
        const newline = comment_start +
            mem.indexOfScalar(u8, tree.source[comment_start..end], '\n').?;
        const untrimmed_comment = tree.source[comment_start..newline];
        const trimmed_comment = mem.trimRight(u8, untrimmed_comment, " \r\t");
        if (count == 0) {
            count += 1;
            try ais.writer().writeAll(prefix);
        } else {
            // If another newline occurs between prev comment and this one
            // we honor it, but not any additional ones.
            if (mem.indexOfScalar(u8, tree.source[index..comment_start], '\n') != null) {
                try ais.insertNewline();
            }
        }
        try ais.writer().print("{s}\n", .{trimmed_comment});
        index = newline + 1;
    }
}

fn renderRoot(ais: *Ais, tree: ast.Tree) Error!void {
    // Render all the line comments at the beginning of the file.
    const src_start: usize = if (mem.startsWith(u8, tree.source, "\xEF\xBB\xBF")) 3 else 0;
    const comment_end_loc: usize = tree.tokens.items(.start)[0];
    _ = try renderComments(ais, tree, src_start, comment_end_loc, "");

    // Root is always index 0.
    const nodes_data = tree.nodes.items(.data);
    const root_decls = tree.extra_data[nodes_data[0].lhs..nodes_data[0].rhs];

    return renderAllMembers(ais, tree, root_decls);
}

fn renderAllMembers(ais: *Ais, tree: ast.Tree, members: []const ast.Node.Index) Error!void {
    if (members.len == 0) return;

    const first_member = members[0];
    try renderMember(ais, tree, first_member, .newline);

    for (members[1..]) |member| {
        try renderExtraNewline(ais, tree, member);
        try renderMember(ais, tree, member, .newline);
    }
}

fn renderExtraNewline(ais: *Ais, tree: ast.Tree, node: ast.Node.Index) Error!void {
    return renderExtraNewlineToken(ais, tree, tree.firstToken(node));
}

fn renderExtraNewlineToken(ais: *Ais, tree: ast.Tree, first_token: ast.TokenIndex) Error!void {
    if (first_token == 0) return;
    const token_starts = tree.tokens.items(.start);
    if (tree.tokenLocation(token_starts[first_token - 1], first_token).line >= 2) {
        return ais.insertNewline();
    }
}

fn renderMember(ais: *Ais, tree: ast.Tree, decl: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    try renderDocComments(ais, tree, tree.firstToken(decl));
    switch (tree.nodes.items(.tag)[decl]) {
        .fn_decl => {
            // Some examples:
            // pub extern "foo" fn ...
            // export fn ...
            const fn_proto = datas[decl].lhs;
            const fn_token = main_tokens[fn_proto];
            // Go back to the first token we should render here.
            var i = fn_token;
            while (i > 0) {
                i -= 1;
                switch (token_tags[i]) {
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
                try renderToken(ais, tree, i, .space);
            }
            if (datas[decl].rhs != 0) {
                try renderExpression(ais, tree, fn_proto, .space);
                return renderExpression(ais, tree, datas[decl].rhs, space);
            } else {
                try renderExpression(ais, tree, fn_proto, .none);
                return renderToken(ais, tree, tree.lastToken(fn_proto) + 1, space); // semicolon
            }
        },
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            try renderExpression(ais, tree, decl, .none);
            return renderToken(ais, tree, tree.lastToken(decl) + 1, space); // semicolon
        },

        .@"usingnamespace" => {
            const main_token = main_tokens[decl];
            const expr = datas[decl].lhs;
            if (main_token > 0 and token_tags[main_token - 1] == .keyword_pub) {
                try renderToken(ais, tree, main_token - 1, .space); // pub
            }
            try renderToken(ais, tree, main_token, .space); // usingnamespace
            try renderExpression(ais, tree, expr, .none);
            return renderToken(ais, tree, tree.lastToken(expr) + 1, space); // ;
        },

        .global_var_decl => return renderVarDecl(ais, tree, tree.globalVarDecl(decl)),
        .local_var_decl => return renderVarDecl(ais, tree, tree.localVarDecl(decl)),
        .simple_var_decl => return renderVarDecl(ais, tree, tree.simpleVarDecl(decl)),
        .aligned_var_decl => return renderVarDecl(ais, tree, tree.alignedVarDecl(decl)),

        .test_decl => {
            const test_token = main_tokens[decl];
            try renderToken(ais, tree, test_token, .space);
            if (token_tags[test_token + 1] == .string_literal) {
                try renderToken(ais, tree, test_token + 1, .space);
            }
            try renderExpression(ais, tree, datas[decl].rhs, space);
        },

        .container_field_init => return renderContainerField(ais, tree, tree.containerFieldInit(decl), space),
        .container_field_align => return renderContainerField(ais, tree, tree.containerFieldAlign(decl), space),
        .container_field => return renderContainerField(ais, tree, tree.containerField(decl), space),
        .@"comptime" => return renderExpression(ais, tree, decl, space),

        .root => unreachable,
        else => unreachable,
    }
}

fn renderExpression(ais: *Ais, tree: ast.Tree, node: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const node_tags = tree.nodes.items(.tag);
    const datas = tree.nodes.items(.data);
    switch (node_tags[node]) {
        .identifier,
        .integer_literal,
        .float_literal,
        .string_literal,
        .char_literal,
        .true_literal,
        .false_literal,
        .null_literal,
        .unreachable_literal,
        .undefined_literal,
        .anyframe_literal,
        => return renderToken(ais, tree, main_tokens[node], space),

        .error_value => {
            try renderToken(ais, tree, main_tokens[node], .none);
            try renderToken(ais, tree, main_tokens[node] + 1, .none);
            return renderToken(ais, tree, main_tokens[node] + 2, space);
        },

        .@"anytype" => return renderToken(ais, tree, main_tokens[node], space),

        .block_two,
        .block_two_semicolon,
        => {
            const statements = [2]ast.Node.Index{ datas[node].lhs, datas[node].rhs };
            if (datas[node].lhs == 0) {
                return renderBlock(ais, tree, node, statements[0..0], space);
            } else if (datas[node].rhs == 0) {
                return renderBlock(ais, tree, node, statements[0..1], space);
            } else {
                return renderBlock(ais, tree, node, statements[0..2], space);
            }
        },
        .block,
        .block_semicolon,
        => {
            const statements = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBlock(ais, tree, node, statements, space);
        },

        .@"errdefer" => {
            const defer_token = main_tokens[node];
            const payload_token = datas[node].lhs;
            const expr = datas[node].rhs;

            try renderToken(ais, tree, defer_token, .space);
            if (payload_token != 0) {
                try renderToken(ais, tree, payload_token - 1, .none); // |
                try renderToken(ais, tree, payload_token, .none); // identifier
                try renderToken(ais, tree, payload_token + 1, .space); // |
            }
            return renderExpression(ais, tree, expr, space);
        },

        .@"defer" => {
            const defer_token = main_tokens[node];
            const expr = datas[node].rhs;
            try renderToken(ais, tree, defer_token, .space);
            return renderExpression(ais, tree, expr, space);
        },
        .@"comptime", .@"nosuspend" => {
            const comptime_token = main_tokens[node];
            const block = datas[node].lhs;
            try renderToken(ais, tree, comptime_token, .space);
            return renderExpression(ais, tree, block, space);
        },

        .@"suspend" => {
            const suspend_token = main_tokens[node];
            const body = datas[node].lhs;
            if (body != 0) {
                try renderToken(ais, tree, suspend_token, .space);
                return renderExpression(ais, tree, body, space);
            } else {
                return renderToken(ais, tree, suspend_token, space);
            }
        },

        .@"catch" => {
            const main_token = main_tokens[node];
            const fallback_first = tree.firstToken(datas[node].rhs);

            const same_line = tree.tokensOnSameLine(main_token, fallback_first);
            const after_op_space = if (same_line) Space.space else Space.newline;

            try renderExpression(ais, tree, datas[node].lhs, .space); // target

            if (token_tags[fallback_first - 1] == .pipe) {
                try renderToken(ais, tree, main_token, .space); // catch keyword
                try renderToken(ais, tree, main_token + 1, .none); // pipe
                try renderToken(ais, tree, main_token + 2, .none); // payload identifier
                try renderToken(ais, tree, main_token + 3, after_op_space); // pipe
            } else {
                assert(token_tags[fallback_first - 1] == .keyword_catch);
                try renderToken(ais, tree, main_token, after_op_space); // catch keyword
            }

            ais.pushIndentOneShot();
            try renderExpression(ais, tree, datas[node].rhs, space); // fallback
        },

        .field_access => {
            const field_access = datas[node];
            try renderExpression(ais, tree, field_access.lhs, .none);
            try renderToken(ais, tree, main_tokens[node], .none);
            return renderToken(ais, tree, field_access.rhs, space);
        },

        .error_union,
        .switch_range,
        => {
            const infix = datas[node];
            try renderExpression(ais, tree, infix.lhs, .none);
            try renderToken(ais, tree, main_tokens[node], .none);
            return renderExpression(ais, tree, infix.rhs, space);
        },

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
        => {
            const infix = datas[node];
            try renderExpression(ais, tree, infix.lhs, .space);
            const op_token = main_tokens[node];
            if (tree.tokensOnSameLine(op_token, op_token + 1)) {
                try renderToken(ais, tree, op_token, .space);
            } else {
                ais.pushIndent();
                try renderToken(ais, tree, op_token, .newline);
                ais.popIndent();
                ais.pushIndentOneShot();
            }
            return renderExpression(ais, tree, infix.rhs, space);
        },

        .bit_not,
        .bool_not,
        .negation,
        .negation_wrap,
        .optional_type,
        .address_of,
        => {
            try renderToken(ais, tree, main_tokens[node], .none);
            return renderExpression(ais, tree, datas[node].lhs, space);
        },

        .@"try",
        .@"resume",
        .@"await",
        => {
            try renderToken(ais, tree, main_tokens[node], .space);
            return renderExpression(ais, tree, datas[node].lhs, space);
        },

        .array_type => return renderArrayType(ais, tree, tree.arrayType(node), space),
        .array_type_sentinel => return renderArrayType(ais, tree, tree.arrayTypeSentinel(node), space),

        .ptr_type_aligned => return renderPtrType(ais, tree, tree.ptrTypeAligned(node), space),
        .ptr_type_sentinel => return renderPtrType(ais, tree, tree.ptrTypeSentinel(node), space),
        .ptr_type => return renderPtrType(ais, tree, tree.ptrType(node), space),
        .ptr_type_bit_range => return renderPtrType(ais, tree, tree.ptrTypeBitRange(node), space),

        .array_init_one, .array_init_one_comma => {
            var elements: [1]ast.Node.Index = undefined;
            return renderArrayInit(ais, tree, tree.arrayInitOne(&elements, node), space);
        },
        .array_init_dot_two, .array_init_dot_two_comma => {
            var elements: [2]ast.Node.Index = undefined;
            return renderArrayInit(ais, tree, tree.arrayInitDotTwo(&elements, node), space);
        },
        .array_init_dot,
        .array_init_dot_comma,
        => return renderArrayInit(ais, tree, tree.arrayInitDot(node), space),
        .array_init,
        .array_init_comma,
        => return renderArrayInit(ais, tree, tree.arrayInit(node), space),

        .struct_init_one, .struct_init_one_comma => {
            var fields: [1]ast.Node.Index = undefined;
            return renderStructInit(ais, tree, tree.structInitOne(&fields, node), space);
        },
        .struct_init_dot_two, .struct_init_dot_two_comma => {
            var fields: [2]ast.Node.Index = undefined;
            return renderStructInit(ais, tree, tree.structInitDotTwo(&fields, node), space);
        },
        .struct_init_dot,
        .struct_init_dot_comma,
        => return renderStructInit(ais, tree, tree.structInitDot(node), space),
        .struct_init,
        .struct_init_comma,
        => return renderStructInit(ais, tree, tree.structInit(node), space),

        .call_one, .call_one_comma, .async_call_one, .async_call_one_comma => {
            var params: [1]ast.Node.Index = undefined;
            return renderCall(ais, tree, tree.callOne(&params, node), space);
        },

        .call,
        .call_comma,
        .async_call,
        .async_call_comma,
        => return renderCall(ais, tree, tree.callFull(node), space),

        .array_access => {
            const suffix = datas[node];
            const lbracket = tree.firstToken(suffix.rhs) - 1;
            const rbracket = tree.lastToken(suffix.rhs) + 1;
            try renderExpression(ais, tree, suffix.lhs, .none);
            try renderToken(ais, tree, lbracket, .none); // [
            try renderExpression(ais, tree, suffix.rhs, .none);
            return renderToken(ais, tree, rbracket, space); // ]
        },

        .slice_open => try renderSlice(ais, tree, tree.sliceOpen(node), space),
        .slice => try renderSlice(ais, tree, tree.slice(node), space),
        .slice_sentinel => try renderSlice(ais, tree, tree.sliceSentinel(node), space),

        .deref => {
            try renderExpression(ais, tree, datas[node].lhs, .none);
            return renderToken(ais, tree, main_tokens[node], space);
        },

        .unwrap_optional => {
            try renderExpression(ais, tree, datas[node].lhs, .none);
            try renderToken(ais, tree, main_tokens[node], .none);
            return renderToken(ais, tree, datas[node].rhs, space);
        },

        .@"break" => {
            const main_token = main_tokens[node];
            const label_token = datas[node].lhs;
            const target = datas[node].rhs;
            if (label_token == 0 and target == 0) {
                try renderToken(ais, tree, main_token, space); // break keyword
            } else if (label_token == 0 and target != 0) {
                try renderToken(ais, tree, main_token, .space); // break keyword
                try renderExpression(ais, tree, target, space);
            } else if (label_token != 0 and target == 0) {
                try renderToken(ais, tree, main_token, .space); // break keyword
                try renderToken(ais, tree, label_token - 1, .none); // colon
                try renderToken(ais, tree, label_token, space); // identifier
            } else if (label_token != 0 and target != 0) {
                try renderToken(ais, tree, main_token, .space); // break keyword
                try renderToken(ais, tree, label_token - 1, .none); // colon
                try renderToken(ais, tree, label_token, .space); // identifier
                try renderExpression(ais, tree, target, space);
            }
        },

        .@"continue" => {
            const main_token = main_tokens[node];
            const label = datas[node].lhs;
            if (label != 0) {
                try renderToken(ais, tree, main_token, .space); // continue
                try renderToken(ais, tree, label - 1, .none); // :
                return renderToken(ais, tree, label, space); // label
            } else {
                return renderToken(ais, tree, main_token, space); // continue
            }
        },

        .@"return" => {
            if (datas[node].lhs != 0) {
                try renderToken(ais, tree, main_tokens[node], .space);
                try renderExpression(ais, tree, datas[node].lhs, space);
            } else {
                try renderToken(ais, tree, main_tokens[node], space);
            }
        },

        .grouped_expression => {
            try renderToken(ais, tree, main_tokens[node], .none);
            try renderExpression(ais, tree, datas[node].lhs, .none);
            return renderToken(ais, tree, datas[node].rhs, space);
        },

        .container_decl,
        .container_decl_comma,
        => return renderContainerDecl(ais, tree, tree.containerDecl(node), space),

        .container_decl_two, .container_decl_two_comma => {
            var buffer: [2]ast.Node.Index = undefined;
            return renderContainerDecl(ais, tree, tree.containerDeclTwo(&buffer, node), space);
        },
        .container_decl_arg,
        .container_decl_arg_comma,
        => return renderContainerDecl(ais, tree, tree.containerDeclArg(node), space),

        .tagged_union,
        .tagged_union_comma,
        => return renderContainerDecl(ais, tree, tree.taggedUnion(node), space),

        .tagged_union_two, .tagged_union_two_comma => {
            var buffer: [2]ast.Node.Index = undefined;
            return renderContainerDecl(ais, tree, tree.taggedUnionTwo(&buffer, node), space);
        },
        .tagged_union_enum_tag,
        .tagged_union_enum_tag_comma,
        => return renderContainerDecl(ais, tree, tree.taggedUnionEnumTag(node), space),

        // TODO: handle comments properly
        .error_set_decl => {
            const error_token = main_tokens[node];
            const lbrace = error_token + 1;
            const rbrace = datas[node].rhs;

            try renderToken(ais, tree, error_token, .none);

            if (lbrace + 1 == rbrace) {
                // There is nothing between the braces so render condensed: `error{}`
                try renderToken(ais, tree, lbrace, .none);
                return renderToken(ais, tree, rbrace, space);
            } else if (lbrace + 2 == rbrace and token_tags[lbrace + 1] == .identifier) {
                // There is exactly one member and no trailing comma or
                // comments, so render without surrounding spaces: `error{Foo}`
                try renderToken(ais, tree, lbrace, .none);
                try renderToken(ais, tree, lbrace + 1, .none); // identifier
                return renderToken(ais, tree, rbrace, space);
            } else if (token_tags[rbrace - 1] == .comma) {
                // There is a trailing comma so render each member on a new line.
                try renderToken(ais, tree, lbrace, .newline);
                ais.pushIndent();
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    try renderExtraNewlineToken(ais, tree, i);
                    switch (token_tags[i]) {
                        .doc_comment => try renderToken(ais, tree, i, .newline),
                        .identifier => try renderToken(ais, tree, i, .comma),
                        .comma => {},
                        else => unreachable,
                    }
                }
                ais.popIndent();
                return renderToken(ais, tree, rbrace, space);
            } else {
                // There is no trailing comma so render everything on one line.
                try renderToken(ais, tree, lbrace, .space);
                var i = lbrace + 1;
                while (i < rbrace) : (i += 1) {
                    switch (token_tags[i]) {
                        .doc_comment => unreachable, // TODO
                        .identifier => try renderToken(ais, tree, i, .comma_space),
                        .comma => {},
                        else => unreachable,
                    }
                }
                return renderToken(ais, tree, rbrace, space);
            }
        },

        .builtin_call_two, .builtin_call_two_comma => {
            if (datas[node].lhs == 0) {
                const params = [_]ast.Node.Index{};
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            } else if (datas[node].rhs == 0) {
                const params = [_]ast.Node.Index{datas[node].lhs};
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            } else {
                const params = [_]ast.Node.Index{ datas[node].lhs, datas[node].rhs };
                return renderBuiltinCall(ais, tree, main_tokens[node], &params, space);
            }
        },
        .builtin_call, .builtin_call_comma => {
            const params = tree.extra_data[datas[node].lhs..datas[node].rhs];
            return renderBuiltinCall(ais, tree, main_tokens[node], params, space);
        },

        .fn_proto_simple => {
            var params: [1]ast.Node.Index = undefined;
            return renderFnProto(ais, tree, tree.fnProtoSimple(&params, node), space);
        },
        .fn_proto_multi => return renderFnProto(ais, tree, tree.fnProtoMulti(node), space),
        .fn_proto_one => {
            var params: [1]ast.Node.Index = undefined;
            return renderFnProto(ais, tree, tree.fnProtoOne(&params, node), space);
        },
        .fn_proto => return renderFnProto(ais, tree, tree.fnProto(node), space),

        .anyframe_type => {
            const main_token = main_tokens[node];
            if (datas[node].rhs != 0) {
                try renderToken(ais, tree, main_token, .none); // anyframe
                try renderToken(ais, tree, main_token + 1, .none); // ->
                return renderExpression(ais, tree, datas[node].rhs, space);
            } else {
                return renderToken(ais, tree, main_token, space); // anyframe
            }
        },

        .@"switch",
        .switch_comma,
        => {
            const switch_token = main_tokens[node];
            const condition = datas[node].lhs;
            const extra = tree.extraData(datas[node].rhs, ast.Node.SubRange);
            const cases = tree.extra_data[extra.start..extra.end];
            const rparen = tree.lastToken(condition) + 1;

            try renderToken(ais, tree, switch_token, .space); // switch keyword
            try renderToken(ais, tree, switch_token + 1, .none); // lparen
            try renderExpression(ais, tree, condition, .none); // condtion expression
            try renderToken(ais, tree, rparen, .space); // rparen

            if (cases.len == 0) {
                try renderToken(ais, tree, rparen + 1, .none); // lbrace
                return renderToken(ais, tree, rparen + 2, space); // rbrace
            }
            try renderToken(ais, tree, rparen + 1, .newline); // lbrace
            ais.pushIndent();
            try renderExpression(ais, tree, cases[0], .comma);
            for (cases[1..]) |case| {
                try renderExtraNewline(ais, tree, case);
                try renderExpression(ais, tree, case, .comma);
            }
            ais.popIndent();
            return renderToken(ais, tree, tree.lastToken(node), space); // rbrace
        },

        .switch_case_one => return renderSwitchCase(ais, tree, tree.switchCaseOne(node), space),
        .switch_case => return renderSwitchCase(ais, tree, tree.switchCase(node), space),

        .while_simple => return renderWhile(ais, tree, tree.whileSimple(node), space),
        .while_cont => return renderWhile(ais, tree, tree.whileCont(node), space),
        .@"while" => return renderWhile(ais, tree, tree.whileFull(node), space),
        .for_simple => return renderWhile(ais, tree, tree.forSimple(node), space),
        .@"for" => return renderWhile(ais, tree, tree.forFull(node), space),

        .if_simple => return renderIf(ais, tree, tree.ifSimple(node), space),
        .@"if" => return renderIf(ais, tree, tree.ifFull(node), space),

        .asm_simple => return renderAsm(ais, tree, tree.asmSimple(node), space),
        .@"asm" => return renderAsm(ais, tree, tree.asmFull(node), space),

        .enum_literal => {
            try renderToken(ais, tree, main_tokens[node] - 1, .none); // .
            return renderToken(ais, tree, main_tokens[node], space); // name
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

// TODO: handle comments inside the brackets
fn renderArrayType(
    ais: *Ais,
    tree: ast.Tree,
    array_type: ast.full.ArrayType,
    space: Space,
) Error!void {
    try renderToken(ais, tree, array_type.ast.lbracket, .none); // lbracket
    try renderExpression(ais, tree, array_type.ast.elem_count, .none);
    if (array_type.ast.sentinel) |sentinel| {
        try renderToken(ais, tree, tree.firstToken(sentinel) - 1, .none); // colon
        try renderExpression(ais, tree, sentinel, .none);
    }
    try renderToken(ais, tree, tree.firstToken(array_type.ast.elem_type) - 1, .none); // rbracket
    return renderExpression(ais, tree, array_type.ast.elem_type, space);
}

fn renderPtrType(
    ais: *Ais,
    tree: ast.Tree,
    ptr_type: ast.full.PtrType,
    space: Space,
) Error!void {
    switch (ptr_type.kind) {
        .one => {
            // Since ** tokens exist and the same token is shared by two
            // nested pointer types, we check to see if we are the parent
            // in such a relationship. If so, skip rendering anything for
            // this pointer type and rely on the child to render our asterisk
            // as well when it renders the ** token.
            if (tree.tokens.items(.tag)[ptr_type.ast.main_token] == .asterisk_asterisk and
                ptr_type.ast.main_token == tree.nodes.items(.main_token)[ptr_type.ast.child_type])
            {
                return renderExpression(ais, tree, ptr_type.ast.child_type, space);
            }
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // asterisk
        },
        .many => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .none); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .none); // rbracket
        },
        .sentinel => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .none); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .none); // colon
            try renderExpression(ais, tree, ptr_type.ast.sentinel, .none);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.sentinel) + 1, .none); // rbracket
        },
        .c => {
            try renderToken(ais, tree, ptr_type.ast.main_token - 1, .none); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // asterisk
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .none); // c
            try renderToken(ais, tree, ptr_type.ast.main_token + 2, .none); // rbracket
        },
        .slice => {
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .none); // rbracket
        },
        .slice_sentinel => {
            try renderToken(ais, tree, ptr_type.ast.main_token, .none); // lbracket
            try renderToken(ais, tree, ptr_type.ast.main_token + 1, .none); // colon
            try renderExpression(ais, tree, ptr_type.ast.sentinel, .none);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.sentinel) + 1, .none); // rbracket
        },
    }

    if (ptr_type.allowzero_token) |allowzero_token| {
        try renderToken(ais, tree, allowzero_token, .space);
    }

    if (ptr_type.ast.align_node != 0) {
        const align_first = tree.firstToken(ptr_type.ast.align_node);
        try renderToken(ais, tree, align_first - 2, .none); // align
        try renderToken(ais, tree, align_first - 1, .none); // lparen
        try renderExpression(ais, tree, ptr_type.ast.align_node, .none);
        if (ptr_type.ast.bit_range_start != 0) {
            assert(ptr_type.ast.bit_range_end != 0);
            try renderToken(ais, tree, tree.firstToken(ptr_type.ast.bit_range_start) - 1, .none); // colon
            try renderExpression(ais, tree, ptr_type.ast.bit_range_start, .none);
            try renderToken(ais, tree, tree.firstToken(ptr_type.ast.bit_range_end) - 1, .none); // colon
            try renderExpression(ais, tree, ptr_type.ast.bit_range_end, .none);
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.bit_range_end) + 1, .space); // rparen
        } else {
            try renderToken(ais, tree, tree.lastToken(ptr_type.ast.align_node) + 1, .space); // rparen
        }
    }

    if (ptr_type.const_token) |const_token| {
        try renderToken(ais, tree, const_token, .space);
    }

    if (ptr_type.volatile_token) |volatile_token| {
        try renderToken(ais, tree, volatile_token, .space);
    }

    try renderExpression(ais, tree, ptr_type.ast.child_type, space);
}

fn renderSlice(
    ais: *Ais,
    tree: ast.Tree,
    slice: ast.full.Slice,
    space: Space,
) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const after_start_space_bool = nodeCausesSliceOpSpace(node_tags[slice.ast.start]) or
        if (slice.ast.end != 0) nodeCausesSliceOpSpace(node_tags[slice.ast.end]) else false;
    const after_start_space = if (after_start_space_bool) Space.space else Space.none;
    const after_dots_space = if (slice.ast.end != 0) after_start_space else Space.none;

    try renderExpression(ais, tree, slice.ast.sliced, .none);
    try renderToken(ais, tree, slice.ast.lbracket, .none); // lbracket

    const start_last = tree.lastToken(slice.ast.start);
    try renderExpression(ais, tree, slice.ast.start, after_start_space);
    try renderToken(ais, tree, start_last + 1, after_dots_space); // ellipsis2 ("..")
    if (slice.ast.end == 0) {
        return renderToken(ais, tree, start_last + 2, space); // rbracket
    }

    const end_last = tree.lastToken(slice.ast.end);
    const after_end_space = if (slice.ast.sentinel != 0) Space.space else Space.none;
    try renderExpression(ais, tree, slice.ast.end, after_end_space);
    if (slice.ast.sentinel == 0) {
        return renderToken(ais, tree, end_last + 1, space); // rbracket
    }

    try renderToken(ais, tree, end_last + 1, .none); // colon
    try renderExpression(ais, tree, slice.ast.sentinel, .none);
    try renderToken(ais, tree, tree.lastToken(slice.ast.sentinel) + 1, space); // rbracket
}

fn renderAsmOutput(
    ais: *Ais,
    tree: ast.Tree,
    asm_output: ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    assert(node_tags[asm_output] == .asm_output);
    const symbolic_name = main_tokens[asm_output];

    try renderToken(ais, tree, symbolic_name - 1, .none); // lbracket
    try renderToken(ais, tree, symbolic_name, .none); // ident
    try renderToken(ais, tree, symbolic_name + 1, .space); // rbracket
    try renderToken(ais, tree, symbolic_name + 2, .space); // "constraint"
    try renderToken(ais, tree, symbolic_name + 3, .none); // lparen

    if (token_tags[symbolic_name + 4] == .arrow) {
        try renderToken(ais, tree, symbolic_name + 4, .space); // ->
        try renderExpression(ais, tree, datas[asm_output].lhs, Space.none);
        return renderToken(ais, tree, datas[asm_output].rhs, space); // rparen
    } else {
        try renderToken(ais, tree, symbolic_name + 4, .none); // ident
        return renderToken(ais, tree, symbolic_name + 5, space); // rparen
    }
}

fn renderAsmInput(
    ais: *Ais,
    tree: ast.Tree,
    asm_input: ast.Node.Index,
    space: Space,
) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);
    const datas = tree.nodes.items(.data);
    assert(node_tags[asm_input] == .asm_input);
    const symbolic_name = main_tokens[asm_input];

    try renderToken(ais, tree, symbolic_name - 1, .none); // lbracket
    try renderToken(ais, tree, symbolic_name, .none); // ident
    try renderToken(ais, tree, symbolic_name + 1, .space); // rbracket
    try renderToken(ais, tree, symbolic_name + 2, .space); // "constraint"
    try renderToken(ais, tree, symbolic_name + 3, .none); // lparen
    try renderExpression(ais, tree, datas[asm_input].lhs, Space.none);
    return renderToken(ais, tree, datas[asm_input].rhs, space); // rparen
}

fn renderVarDecl(ais: *Ais, tree: ast.Tree, var_decl: ast.full.VarDecl) Error!void {
    if (var_decl.visib_token) |visib_token| {
        try renderToken(ais, tree, visib_token, Space.space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(ais, tree, extern_export_token, Space.space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(ais, tree, lib_name, Space.space); // "lib"
        }
    }

    if (var_decl.threadlocal_token) |thread_local_token| {
        try renderToken(ais, tree, thread_local_token, Space.space); // threadlocal
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(ais, tree, comptime_token, Space.space); // comptime
    }

    try renderToken(ais, tree, var_decl.ast.mut_token, .space); // var

    const name_space = if (var_decl.ast.type_node == 0 and
        (var_decl.ast.align_node != 0 or
        var_decl.ast.section_node != 0 or
        var_decl.ast.init_node != 0))
        Space.space
    else
        Space.none;
    try renderToken(ais, tree, var_decl.ast.mut_token + 1, name_space); // name

    if (var_decl.ast.type_node != 0) {
        try renderToken(ais, tree, var_decl.ast.mut_token + 2, Space.space); // :
        if (var_decl.ast.align_node != 0 or var_decl.ast.section_node != 0 or
            var_decl.ast.init_node != 0)
        {
            try renderExpression(ais, tree, var_decl.ast.type_node, .space);
        } else {
            try renderExpression(ais, tree, var_decl.ast.type_node, .none);
            const semicolon = tree.lastToken(var_decl.ast.type_node) + 1;
            return renderToken(ais, tree, semicolon, Space.newline); // ;
        }
    }

    if (var_decl.ast.align_node != 0) {
        const lparen = tree.firstToken(var_decl.ast.align_node) - 1;
        const align_kw = lparen - 1;
        const rparen = tree.lastToken(var_decl.ast.align_node) + 1;
        try renderToken(ais, tree, align_kw, Space.none); // align
        try renderToken(ais, tree, lparen, Space.none); // (
        try renderExpression(ais, tree, var_decl.ast.align_node, Space.none);
        if (var_decl.ast.section_node != 0 or var_decl.ast.init_node != 0) {
            try renderToken(ais, tree, rparen, .space); // )
        } else {
            try renderToken(ais, tree, rparen, .none); // )
            return renderToken(ais, tree, rparen + 1, Space.newline); // ;
        }
    }

    if (var_decl.ast.section_node != 0) {
        const lparen = tree.firstToken(var_decl.ast.section_node) - 1;
        const section_kw = lparen - 1;
        const rparen = tree.lastToken(var_decl.ast.section_node) + 1;
        try renderToken(ais, tree, section_kw, Space.none); // linksection
        try renderToken(ais, tree, lparen, Space.none); // (
        try renderExpression(ais, tree, var_decl.ast.section_node, Space.none);
        if (var_decl.ast.init_node != 0) {
            try renderToken(ais, tree, rparen, .space); // )
        } else {
            try renderToken(ais, tree, rparen, .none); // )
            return renderToken(ais, tree, rparen + 1, Space.newline); // ;
        }
    }

    assert(var_decl.ast.init_node != 0);
    const eq_token = tree.firstToken(var_decl.ast.init_node) - 1;
    const eq_space: Space = if (tree.tokensOnSameLine(eq_token, eq_token + 1)) .space else .newline;
    {
        ais.pushIndent();
        try renderToken(ais, tree, eq_token, eq_space); // =
        ais.popIndent();
    }
    ais.pushIndentOneShot();
    try renderExpression(ais, tree, var_decl.ast.init_node, .semicolon);
}

fn renderIf(ais: *Ais, tree: ast.Tree, if_node: ast.full.If, space: Space) Error!void {
    return renderWhile(ais, tree, .{
        .ast = .{
            .while_token = if_node.ast.if_token,
            .cond_expr = if_node.ast.cond_expr,
            .cont_expr = 0,
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

/// Note that this function is additionally used to render if and for expressions, with
/// respective values set to null.
fn renderWhile(ais: *Ais, tree: ast.Tree, while_node: ast.full.While, space: Space) Error!void {
    const node_tags = tree.nodes.items(.tag);
    const token_tags = tree.tokens.items(.tag);

    if (while_node.label_token) |label| {
        try renderToken(ais, tree, label, .none); // label
        try renderToken(ais, tree, label + 1, .space); // :
    }

    if (while_node.inline_token) |inline_token| {
        try renderToken(ais, tree, inline_token, .space); // inline
    }

    try renderToken(ais, tree, while_node.ast.while_token, .space); // if
    try renderToken(ais, tree, while_node.ast.while_token + 1, .none); // (
    try renderExpression(ais, tree, while_node.ast.cond_expr, .none); // condition

    if (nodeIsBlock(node_tags[while_node.ast.then_expr])) {
        if (while_node.payload_token) |payload_token| {
            try renderToken(ais, tree, payload_token - 2, .space); // )
            try renderToken(ais, tree, payload_token - 1, .none); // |
            const ident = blk: {
                if (token_tags[payload_token] == .asterisk) {
                    try renderToken(ais, tree, payload_token, .none); // *
                    break :blk payload_token + 1;
                } else {
                    break :blk payload_token;
                }
            };
            try renderToken(ais, tree, ident, .none); // identifier
            const pipe = blk: {
                if (token_tags[ident + 1] == .comma) {
                    try renderToken(ais, tree, ident + 1, .space); // ,
                    try renderToken(ais, tree, ident + 2, .none); // index
                    break :blk payload_token + 3;
                } else {
                    break :blk ident + 1;
                }
            };
            try renderToken(ais, tree, pipe, .space); // |
        } else {
            const rparen = tree.lastToken(while_node.ast.cond_expr) + 1;
            try renderToken(ais, tree, rparen, .space); // )
        }
        if (while_node.ast.cont_expr != 0) {
            const rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
            const lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
            try renderToken(ais, tree, lparen - 1, .space); // :
            try renderToken(ais, tree, lparen, .none); // lparen
            try renderExpression(ais, tree, while_node.ast.cont_expr, .none);
            try renderToken(ais, tree, rparen, .space); // rparen
        }
        if (while_node.ast.else_expr != 0) {
            try renderExpression(ais, tree, while_node.ast.then_expr, Space.space);
            try renderToken(ais, tree, while_node.else_token, .space); // else
            if (while_node.error_token) |error_token| {
                try renderToken(ais, tree, error_token - 1, .none); // |
                try renderToken(ais, tree, error_token, .none); // identifier
                try renderToken(ais, tree, error_token + 1, .space); // |
            }
            return renderExpression(ais, tree, while_node.ast.else_expr, space);
        } else {
            return renderExpression(ais, tree, while_node.ast.then_expr, space);
        }
    }

    const rparen = tree.lastToken(while_node.ast.cond_expr) + 1;
    const last_then_token = tree.lastToken(while_node.ast.then_expr);
    const src_has_newline = !tree.tokensOnSameLine(rparen, last_then_token);

    if (src_has_newline) {
        if (while_node.payload_token) |payload_token| {
            try renderToken(ais, tree, payload_token - 2, .space); // )
            try renderToken(ais, tree, payload_token - 1, .none); // |
            const ident = blk: {
                if (token_tags[payload_token] == .asterisk) {
                    try renderToken(ais, tree, payload_token, .none); // *
                    break :blk payload_token + 1;
                } else {
                    break :blk payload_token;
                }
            };
            try renderToken(ais, tree, ident, .none); // identifier
            const pipe = blk: {
                if (token_tags[ident + 1] == .comma) {
                    try renderToken(ais, tree, ident + 1, .space); // ,
                    try renderToken(ais, tree, ident + 2, .none); // index
                    break :blk payload_token + 3;
                } else {
                    break :blk ident + 1;
                }
            };
            try renderToken(ais, tree, pipe, .newline); // |
        } else {
            ais.pushIndent();
            try renderToken(ais, tree, rparen, .newline); // )
            ais.popIndent();
        }
        if (while_node.ast.cont_expr != 0) {
            const cont_rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
            const cont_lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
            try renderToken(ais, tree, cont_lparen - 1, .space); // :
            try renderToken(ais, tree, cont_lparen, .none); // lparen
            try renderExpression(ais, tree, while_node.ast.cont_expr, .none);
            try renderToken(ais, tree, cont_rparen, .newline); // rparen
        }
        if (while_node.ast.else_expr != 0) {
            ais.pushIndent();
            try renderExpression(ais, tree, while_node.ast.then_expr, Space.newline);
            ais.popIndent();
            const else_is_block = nodeIsBlock(node_tags[while_node.ast.else_expr]);
            if (else_is_block) {
                try renderToken(ais, tree, while_node.else_token, .space); // else
                if (while_node.error_token) |error_token| {
                    try renderToken(ais, tree, error_token - 1, .none); // |
                    try renderToken(ais, tree, error_token, .none); // identifier
                    try renderToken(ais, tree, error_token + 1, .space); // |
                }
                return renderExpression(ais, tree, while_node.ast.else_expr, space);
            } else {
                if (while_node.error_token) |error_token| {
                    try renderToken(ais, tree, while_node.else_token, .space); // else
                    try renderToken(ais, tree, error_token - 1, .none); // |
                    try renderToken(ais, tree, error_token, .none); // identifier
                    try renderToken(ais, tree, error_token + 1, .space); // |
                } else {
                    try renderToken(ais, tree, while_node.else_token, .newline); // else
                }
                ais.pushIndent();
                try renderExpression(ais, tree, while_node.ast.else_expr, space);
                ais.popIndent();
                return;
            }
        } else {
            ais.pushIndent();
            try renderExpression(ais, tree, while_node.ast.then_expr, space);
            ais.popIndent();
            return;
        }
    }

    // Render everything on a single line.

    if (while_node.payload_token) |payload_token| {
        assert(payload_token - 2 == rparen);
        try renderToken(ais, tree, payload_token - 2, .space); // )
        try renderToken(ais, tree, payload_token - 1, .none); // |
        const ident = blk: {
            if (token_tags[payload_token] == .asterisk) {
                try renderToken(ais, tree, payload_token, .none); // *
                break :blk payload_token + 1;
            } else {
                break :blk payload_token;
            }
        };
        try renderToken(ais, tree, ident, .none); // identifier
        const pipe = blk: {
            if (token_tags[ident + 1] == .comma) {
                try renderToken(ais, tree, ident + 1, .space); // ,
                try renderToken(ais, tree, ident + 2, .none); // index
                break :blk payload_token + 3;
            } else {
                break :blk ident + 1;
            }
        };
        try renderToken(ais, tree, pipe, .space); // |
    } else {
        try renderToken(ais, tree, rparen, .space); // )
    }

    if (while_node.ast.cont_expr != 0) {
        const cont_rparen = tree.lastToken(while_node.ast.cont_expr) + 1;
        const cont_lparen = tree.firstToken(while_node.ast.cont_expr) - 1;
        try renderToken(ais, tree, cont_lparen - 1, .space); // :
        try renderToken(ais, tree, cont_lparen, .none); // lparen
        try renderExpression(ais, tree, while_node.ast.cont_expr, .none);
        try renderToken(ais, tree, cont_rparen, .space); // rparen
    }

    if (while_node.ast.else_expr != 0) {
        try renderExpression(ais, tree, while_node.ast.then_expr, .space);
        try renderToken(ais, tree, while_node.else_token, .space); // else

        if (while_node.error_token) |error_token| {
            try renderToken(ais, tree, error_token - 1, .none); // |
            try renderToken(ais, tree, error_token, .none); // identifier
            try renderToken(ais, tree, error_token + 1, .space); // |
        }

        return renderExpression(ais, tree, while_node.ast.else_expr, space);
    } else {
        return renderExpression(ais, tree, while_node.ast.then_expr, space);
    }
}

fn renderContainerField(
    ais: *Ais,
    tree: ast.Tree,
    field: ast.full.ContainerField,
    space: Space,
) Error!void {
    const main_tokens = tree.nodes.items(.main_token);
    if (field.comptime_token) |t| {
        try renderToken(ais, tree, t, .space); // comptime
    }
    if (field.ast.type_expr == 0 and field.ast.value_expr == 0) {
        return renderTokenComma(ais, tree, field.ast.name_token, space); // name
    }
    if (field.ast.type_expr != 0 and field.ast.value_expr == 0) {
        try renderToken(ais, tree, field.ast.name_token, .none); // name
        try renderToken(ais, tree, field.ast.name_token + 1, .space); // :

        if (field.ast.align_expr != 0) {
            try renderExpression(ais, tree, field.ast.type_expr, .space); // type
            const align_token = tree.firstToken(field.ast.align_expr) - 2;
            try renderToken(ais, tree, align_token, .none); // align
            try renderToken(ais, tree, align_token + 1, .none); // (
            try renderExpression(ais, tree, field.ast.align_expr, .none); // alignment
            const rparen = tree.lastToken(field.ast.align_expr) + 1;
            return renderTokenComma(ais, tree, rparen, space); // )
        } else {
            return renderExpressionComma(ais, tree, field.ast.type_expr, space); // type
        }
    }
    if (field.ast.type_expr == 0 and field.ast.value_expr != 0) {
        try renderToken(ais, tree, field.ast.name_token, .space); // name
        try renderToken(ais, tree, field.ast.name_token + 1, .space); // =
        return renderExpressionComma(ais, tree, field.ast.value_expr, space); // value
    }

    try renderToken(ais, tree, field.ast.name_token, .none); // name
    try renderToken(ais, tree, field.ast.name_token + 1, .space); // :
    try renderExpression(ais, tree, field.ast.type_expr, .space); // type

    if (field.ast.align_expr != 0) {
        const lparen_token = tree.firstToken(field.ast.align_expr) - 1;
        const align_kw = lparen_token - 1;
        const rparen_token = tree.lastToken(field.ast.align_expr) + 1;
        try renderToken(ais, tree, align_kw, .none); // align
        try renderToken(ais, tree, lparen_token, .none); // (
        try renderExpression(ais, tree, field.ast.align_expr, .none); // alignment
        try renderToken(ais, tree, rparen_token, .space); // )
    }
    const eq_token = tree.firstToken(field.ast.value_expr) - 1;
    try renderToken(ais, tree, eq_token, .space); // =
    return renderExpressionComma(ais, tree, field.ast.value_expr, space); // value
}

fn renderBuiltinCall(
    ais: *Ais,
    tree: ast.Tree,
    builtin_token: ast.TokenIndex,
    params: []const ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);

    try renderToken(ais, tree, builtin_token, .none); // @name

    if (params.len == 0) {
        try renderToken(ais, tree, builtin_token + 1, .none); // (
        return renderToken(ais, tree, builtin_token + 2, space); // )
    }

    const last_param = params[params.len - 1];
    const after_last_param_token = tree.lastToken(last_param) + 1;

    if (token_tags[after_last_param_token] != .comma) {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, builtin_token + 1, .none); // (

        for (params) |param_node, i| {
            try renderExpression(ais, tree, param_node, .none);

            if (i + 1 < params.len) {
                const comma_token = tree.lastToken(param_node) + 1;
                try renderToken(ais, tree, comma_token, .space); // ,
            }
        }
        return renderToken(ais, tree, after_last_param_token, space); // )
    } else {
        // Render one param per line.
        ais.pushIndent();
        try renderToken(ais, tree, builtin_token + 1, Space.newline); // (

        for (params) |param_node| {
            try renderExpression(ais, tree, param_node, .comma);
        }
        ais.popIndent();

        return renderToken(ais, tree, after_last_param_token + 1, space); // )
    }
}

fn renderFnProto(ais: *Ais, tree: ast.Tree, fn_proto: ast.full.FnProto, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);

    const after_fn_token = fn_proto.ast.fn_token + 1;
    const lparen = if (token_tags[after_fn_token] == .identifier) blk: {
        try renderToken(ais, tree, fn_proto.ast.fn_token, .space); // fn
        try renderToken(ais, tree, after_fn_token, .none); // name
        break :blk after_fn_token + 1;
    } else blk: {
        try renderToken(ais, tree, fn_proto.ast.fn_token, .space); // fn
        break :blk fn_proto.ast.fn_token + 1;
    };
    assert(token_tags[lparen] == .l_paren);

    const maybe_bang = tree.firstToken(fn_proto.ast.return_type) - 1;
    const rparen = blk: {
        // These may appear in any order, so we have to check the token_starts array
        // to find out which is first.
        var rparen: ast.TokenIndex = maybe_bang;
        var smallest_start = token_starts[maybe_bang];
        if (fn_proto.ast.align_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.align_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.section_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.section_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        if (fn_proto.ast.callconv_expr != 0) {
            const tok = tree.firstToken(fn_proto.ast.callconv_expr) - 3;
            const start = token_starts[tok];
            if (start < smallest_start) {
                rparen = tok;
                smallest_start = start;
            }
        }
        break :blk rparen;
    };
    assert(token_tags[rparen] == .r_paren);

    // The params list is a sparse set that does *not* include anytype or ... parameters.

    if (token_tags[rparen - 1] != .comma) {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, lparen, .none); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (token_tags[last_param_token]) {
                .doc_comment => {
                    try renderToken(ais, tree, last_param_token, .newline);
                    continue;
                },
                .ellipsis3 => {
                    try renderToken(ais, tree, last_param_token, .none); // ...
                    break;
                },
                .keyword_noalias, .keyword_comptime => {
                    try renderToken(ais, tree, last_param_token, .space);
                    last_param_token += 1;
                },
                .identifier => {},
                .keyword_anytype => {
                    try renderToken(ais, tree, last_param_token, .none); // anytype
                    continue;
                },
                .r_paren => break,
                .comma => {
                    try renderToken(ais, tree, last_param_token, .space); // ,
                    last_param_token += 1;
                },
                else => {}, // Parameter type without a name.
            }
            if (token_tags[last_param_token] == .identifier and
                token_tags[last_param_token + 1] == .colon)
            {
                try renderToken(ais, tree, last_param_token, .none); // name
                last_param_token += 1;
                try renderToken(ais, tree, last_param_token, .space); // :
                last_param_token += 1;
            }
            if (token_tags[last_param_token] == .keyword_anytype) {
                try renderToken(ais, tree, last_param_token, .none); // anytype
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try renderExpression(ais, tree, param, .none);
            last_param_token = tree.lastToken(param);
        }
    } else {
        // One param per line.
        ais.pushIndent();
        try renderToken(ais, tree, lparen, .newline); // (

        var param_i: usize = 0;
        var last_param_token = lparen;
        while (true) {
            last_param_token += 1;
            switch (token_tags[last_param_token]) {
                .doc_comment => {
                    try renderToken(ais, tree, last_param_token, .newline);
                    continue;
                },
                .ellipsis3 => {
                    try renderToken(ais, tree, last_param_token, .comma); // ...
                    break;
                },
                .keyword_noalias, .keyword_comptime => {
                    try renderToken(ais, tree, last_param_token, .space);
                    last_param_token += 1;
                },
                .identifier => {},
                .keyword_anytype => {
                    try renderToken(ais, tree, last_param_token, .comma); // anytype
                    continue;
                },
                .r_paren => break,
                else => unreachable,
            }
            if (token_tags[last_param_token] == .identifier) {
                try renderToken(ais, tree, last_param_token, .none); // name
                last_param_token += 1;
                try renderToken(ais, tree, last_param_token, .space); // :
                last_param_token += 1;
            }
            if (token_tags[last_param_token] == .keyword_anytype) {
                try renderToken(ais, tree, last_param_token, .comma); // anytype
                continue;
            }
            const param = fn_proto.ast.params[param_i];
            param_i += 1;
            try renderExpression(ais, tree, param, .comma);
            last_param_token = tree.lastToken(param) + 1;
        }
        ais.popIndent();
    }

    try renderToken(ais, tree, rparen, .space); // )

    if (fn_proto.ast.align_expr != 0) {
        const align_lparen = tree.firstToken(fn_proto.ast.align_expr) - 1;
        const align_rparen = tree.lastToken(fn_proto.ast.align_expr) + 1;

        try renderToken(ais, tree, align_lparen - 1, .none); // align
        try renderToken(ais, tree, align_lparen, .none); // (
        try renderExpression(ais, tree, fn_proto.ast.align_expr, .none);
        try renderToken(ais, tree, align_rparen, .space); // )
    }

    if (fn_proto.ast.section_expr != 0) {
        const section_lparen = tree.firstToken(fn_proto.ast.section_expr) - 1;
        const section_rparen = tree.lastToken(fn_proto.ast.section_expr) + 1;

        try renderToken(ais, tree, section_lparen - 1, .none); // section
        try renderToken(ais, tree, section_lparen, .none); // (
        try renderExpression(ais, tree, fn_proto.ast.section_expr, .none);
        try renderToken(ais, tree, section_rparen, .space); // )
    }

    if (fn_proto.ast.callconv_expr != 0) {
        const callconv_lparen = tree.firstToken(fn_proto.ast.callconv_expr) - 1;
        const callconv_rparen = tree.lastToken(fn_proto.ast.callconv_expr) + 1;

        try renderToken(ais, tree, callconv_lparen - 1, .none); // callconv
        try renderToken(ais, tree, callconv_lparen, .none); // (
        try renderExpression(ais, tree, fn_proto.ast.callconv_expr, .none);
        try renderToken(ais, tree, callconv_rparen, .space); // )
    }

    if (token_tags[maybe_bang] == .bang) {
        try renderToken(ais, tree, maybe_bang, .none); // !
    }
    return renderExpression(ais, tree, fn_proto.ast.return_type, space);
}

fn renderSwitchCase(
    ais: *Ais,
    tree: ast.Tree,
    switch_case: ast.full.SwitchCase,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const trailing_comma = token_tags[switch_case.ast.arrow_token - 1] == .comma;

    // Render everything before the arrow
    if (switch_case.ast.values.len == 0) {
        try renderToken(ais, tree, switch_case.ast.arrow_token - 1, .space); // else keyword
    } else if (switch_case.ast.values.len == 1) {
        // render on one line and drop the trailing comma if any
        try renderExpression(ais, tree, switch_case.ast.values[0], .space);
    } else if (trailing_comma) {
        // Render each value on a new line
        try renderExpression(ais, tree, switch_case.ast.values[0], .comma);
        for (switch_case.ast.values[1..]) |value_expr| {
            try renderExtraNewline(ais, tree, value_expr);
            try renderExpression(ais, tree, value_expr, .comma);
        }
    } else {
        // Render on one line
        for (switch_case.ast.values) |value_expr| {
            try renderExpression(ais, tree, value_expr, .comma_space);
        }
    }

    // Render the arrow and everything after it
    try renderToken(ais, tree, switch_case.ast.arrow_token, .space);

    if (switch_case.payload_token) |payload_token| {
        try renderToken(ais, tree, payload_token - 1, .none); // pipe
        if (token_tags[payload_token] == .asterisk) {
            try renderToken(ais, tree, payload_token, .none); // asterisk
            try renderToken(ais, tree, payload_token + 1, .none); // identifier
            try renderToken(ais, tree, payload_token + 2, .space); // pipe
        } else {
            try renderToken(ais, tree, payload_token, .none); // identifier
            try renderToken(ais, tree, payload_token + 1, .space); // pipe
        }
    }

    try renderExpression(ais, tree, switch_case.ast.target_expr, space);
}

fn renderBlock(
    ais: *Ais,
    tree: ast.Tree,
    block_node: ast.Node.Index,
    statements: []const ast.Node.Index,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const nodes_data = tree.nodes.items(.data);
    const lbrace = tree.nodes.items(.main_token)[block_node];

    if (token_tags[lbrace - 1] == .colon and
        token_tags[lbrace - 2] == .identifier)
    {
        try renderToken(ais, tree, lbrace - 2, .none);
        try renderToken(ais, tree, lbrace - 1, .space);
    }

    if (statements.len == 0) {
        try renderToken(ais, tree, lbrace, .none);
        return renderToken(ais, tree, lbrace + 1, space); // rbrace
    }

    try renderToken(ais, tree, lbrace, .newline);
    ais.pushIndent();
    for (statements) |stmt, i| {
        switch (node_tags[stmt]) {
            .global_var_decl => try renderVarDecl(ais, tree, tree.globalVarDecl(stmt)),
            .local_var_decl => try renderVarDecl(ais, tree, tree.localVarDecl(stmt)),
            .simple_var_decl => try renderVarDecl(ais, tree, tree.simpleVarDecl(stmt)),
            .aligned_var_decl => try renderVarDecl(ais, tree, tree.alignedVarDecl(stmt)),
            else => try renderExpression(ais, tree, stmt, .semicolon),
        }
        if (i + 1 < statements.len) {
            try renderExtraNewline(ais, tree, statements[i + 1]);
        }
    }
    ais.popIndent();

    try renderToken(ais, tree, tree.lastToken(block_node), space); // rbrace
}

// TODO: handle comments between fields
fn renderStructInit(
    ais: *Ais,
    tree: ast.Tree,
    struct_init: ast.full.StructInit,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    if (struct_init.ast.type_expr == 0) {
        try renderToken(ais, tree, struct_init.ast.lbrace - 1, .none); // .
    } else {
        try renderExpression(ais, tree, struct_init.ast.type_expr, .none); // T
    }
    if (struct_init.ast.fields.len == 0) {
        try renderToken(ais, tree, struct_init.ast.lbrace, .none); // lbrace
        return renderToken(ais, tree, struct_init.ast.lbrace + 1, space); // rbrace
    }
    const last_field = struct_init.ast.fields[struct_init.ast.fields.len - 1];
    const last_field_token = tree.lastToken(last_field);
    if (token_tags[last_field_token + 1] == .comma) {
        // Render one field init per line.
        ais.pushIndent();
        try renderToken(ais, tree, struct_init.ast.lbrace, .newline);

        try renderToken(ais, tree, struct_init.ast.lbrace + 1, .none); // .
        try renderToken(ais, tree, struct_init.ast.lbrace + 2, .space); // name
        try renderToken(ais, tree, struct_init.ast.lbrace + 3, .space); // =
        try renderExpression(ais, tree, struct_init.ast.fields[0], .comma);

        for (struct_init.ast.fields[1..]) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderToken(ais, tree, init_token - 3, .none); // .
            try renderToken(ais, tree, init_token - 2, .space); // name
            try renderToken(ais, tree, init_token - 1, .space); // =
            try renderExpressionNewlined(ais, tree, field_init, .comma);
        }
        ais.popIndent();
        return renderToken(ais, tree, last_field_token + 2, space); // rbrace
    } else {
        // Render all on one line, no trailing comma.
        try renderToken(ais, tree, struct_init.ast.lbrace, .space);

        for (struct_init.ast.fields) |field_init| {
            const init_token = tree.firstToken(field_init);
            try renderToken(ais, tree, init_token - 3, .none); // .
            try renderToken(ais, tree, init_token - 2, .space); // name
            try renderToken(ais, tree, init_token - 1, .space); // =
            try renderExpression(ais, tree, field_init, .comma_space);
        }

        return renderToken(ais, tree, last_field_token + 1, space); // rbrace
    }
}

// TODO: handle comments between elements
fn renderArrayInit(
    ais: *Ais,
    tree: ast.Tree,
    array_init: ast.full.ArrayInit,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    if (array_init.ast.type_expr == 0) {
        try renderToken(ais, tree, array_init.ast.lbrace - 1, .none); // .
    } else {
        try renderExpression(ais, tree, array_init.ast.type_expr, .none); // T
    }
    if (array_init.ast.elements.len == 0) {
        try renderToken(ais, tree, array_init.ast.lbrace, .none); // lbrace
        return renderToken(ais, tree, array_init.ast.lbrace + 1, space); // rbrace
    }
    const last_elem = array_init.ast.elements[array_init.ast.elements.len - 1];
    const last_elem_token = tree.lastToken(last_elem);
    if (token_tags[last_elem_token + 1] == .comma) {
        // Render one element per line.
        ais.pushIndent();
        try renderToken(ais, tree, array_init.ast.lbrace, .newline);

        try renderExpression(ais, tree, array_init.ast.elements[0], .comma);
        for (array_init.ast.elements[1..]) |elem| {
            try renderExpressionNewlined(ais, tree, elem, .comma);
        }

        ais.popIndent();
        return renderToken(ais, tree, last_elem_token + 2, space); // rbrace
    } else {
        // Render all on one line, no trailing comma.
        if (array_init.ast.elements.len == 1) {
            // If there is only one element, we don't use spaces
            try renderToken(ais, tree, array_init.ast.lbrace, .none);
            try renderExpression(ais, tree, array_init.ast.elements[0], .none);
        } else {
            try renderToken(ais, tree, array_init.ast.lbrace, .space);
            for (array_init.ast.elements) |elem| {
                try renderExpression(ais, tree, elem, .comma_space);
            }
        }
        return renderToken(ais, tree, last_elem_token + 1, space); // rbrace
    }
}

fn renderContainerDecl(
    ais: *Ais,
    tree: ast.Tree,
    container_decl: ast.full.ContainerDecl,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);

    if (container_decl.layout_token) |layout_token| {
        try renderToken(ais, tree, layout_token, .space);
    }

    var lbrace: ast.TokenIndex = undefined;
    if (container_decl.ast.enum_token) |enum_token| {
        try renderToken(ais, tree, container_decl.ast.main_token, .none); // union
        try renderToken(ais, tree, enum_token - 1, .none); // lparen
        try renderToken(ais, tree, enum_token, .none); // enum
        if (container_decl.ast.arg != 0) {
            try renderToken(ais, tree, enum_token + 1, .none); // lparen
            try renderExpression(ais, tree, container_decl.ast.arg, .none);
            const rparen = tree.lastToken(container_decl.ast.arg) + 1;
            try renderToken(ais, tree, rparen, .none); // rparen
            try renderToken(ais, tree, rparen + 1, .space); // rparen
            lbrace = rparen + 2;
        } else {
            try renderToken(ais, tree, enum_token + 1, .space); // rparen
            lbrace = enum_token + 2;
        }
    } else if (container_decl.ast.arg != 0) {
        try renderToken(ais, tree, container_decl.ast.main_token, .none); // union
        try renderToken(ais, tree, container_decl.ast.main_token + 1, .none); // lparen
        try renderExpression(ais, tree, container_decl.ast.arg, .none);
        const rparen = tree.lastToken(container_decl.ast.arg) + 1;
        try renderToken(ais, tree, rparen, .space); // rparen
        lbrace = rparen + 1;
    } else {
        try renderToken(ais, tree, container_decl.ast.main_token, .space); // union
        lbrace = container_decl.ast.main_token + 1;
    }

    if (container_decl.ast.members.len == 0) {
        try renderToken(ais, tree, lbrace, Space.none); // lbrace
        return renderToken(ais, tree, lbrace + 1, space); // rbrace
    }

    const last_member = container_decl.ast.members[container_decl.ast.members.len - 1];
    const last_member_token = tree.lastToken(last_member);
    const rbrace = switch (token_tags[last_member_token + 1]) {
        .doc_comment => last_member_token + 2,
        .comma => switch (token_tags[last_member_token + 2]) {
            .doc_comment => last_member_token + 3,
            .r_brace => last_member_token + 2,
            else => unreachable,
        },
        .r_brace => last_member_token + 1,
        else => unreachable,
    };
    const src_has_trailing_comma = token_tags[last_member_token + 1] == .comma;

    if (!src_has_trailing_comma) one_line: {
        // We can only print all the members in-line if all the members are fields.
        for (container_decl.ast.members) |member| {
            if (!node_tags[member].isContainerField()) break :one_line;
        }
        // All the declarations on the same line.
        try renderToken(ais, tree, lbrace, .space); // lbrace
        for (container_decl.ast.members) |member| {
            try renderMember(ais, tree, member, .space);
        }
        return renderToken(ais, tree, rbrace, space); // rbrace
    }

    // One member per line.
    ais.pushIndent();
    try renderToken(ais, tree, lbrace, .newline); // lbrace
    try renderAllMembers(ais, tree, container_decl.ast.members);
    ais.popIndent();

    return renderToken(ais, tree, rbrace, space); // rbrace
}

fn renderAsm(
    ais: *Ais,
    tree: ast.Tree,
    asm_node: ast.full.Asm,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);

    try renderToken(ais, tree, asm_node.ast.asm_token, .space); // asm

    if (asm_node.volatile_token) |volatile_token| {
        try renderToken(ais, tree, volatile_token, .space); // volatile
        try renderToken(ais, tree, volatile_token + 1, .none); // lparen
    } else {
        try renderToken(ais, tree, asm_node.ast.asm_token + 1, .none); // lparen
    }

    if (asm_node.ast.items.len == 0) {
        try renderExpression(ais, tree, asm_node.ast.template, .none);
        if (asm_node.first_clobber) |first_clobber| {
            // asm ("foo" ::: "a", "b")
            var tok_i = first_clobber;
            while (true) : (tok_i += 1) {
                try renderToken(ais, tree, tok_i, .none);
                tok_i += 1;
                switch (token_tags[tok_i]) {
                    .r_paren => return renderToken(ais, tree, tok_i, space),
                    .comma => try renderToken(ais, tree, tok_i, .space),
                    else => unreachable,
                }
            }
        } else {
            // asm ("foo")
            return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
        }
    }

    ais.pushIndent();
    try renderExpression(ais, tree, asm_node.ast.template, .newline);
    ais.setIndentDelta(asm_indent_delta);
    const colon1 = tree.lastToken(asm_node.ast.template) + 1;

    const colon2 = if (asm_node.outputs.len == 0) colon2: {
        try renderToken(ais, tree, colon1, .newline); // :
        break :colon2 colon1 + 1;
    } else colon2: {
        try renderToken(ais, tree, colon1, .space); // :

        ais.pushIndent();
        for (asm_node.outputs) |asm_output, i| {
            if (i + 1 < asm_node.outputs.len) {
                const next_asm_output = asm_node.outputs[i + 1];
                try renderAsmOutput(ais, tree, asm_output, .none);

                const comma = tree.firstToken(next_asm_output) - 1;
                try renderToken(ais, tree, comma, .newline); // ,
                try renderExtraNewlineToken(ais, tree, tree.firstToken(next_asm_output));
            } else if (asm_node.inputs.len == 0 and asm_node.first_clobber == null) {
                try renderAsmOutput(ais, tree, asm_output, .newline);
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
            } else {
                try renderAsmOutput(ais, tree, asm_output, .newline);
                const comma_or_colon = tree.lastToken(asm_output) + 1;
                ais.popIndent();
                break :colon2 switch (token_tags[comma_or_colon]) {
                    .comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        } else unreachable;
    };

    const colon3 = if (asm_node.inputs.len == 0) colon3: {
        try renderToken(ais, tree, colon2, .newline); // :
        break :colon3 colon2 + 1;
    } else colon3: {
        try renderToken(ais, tree, colon2, .space); // :
        ais.pushIndent();
        for (asm_node.inputs) |asm_input, i| {
            if (i + 1 < asm_node.inputs.len) {
                const next_asm_input = asm_node.inputs[i + 1];
                try renderAsmInput(ais, tree, asm_input, .none);

                const first_token = tree.firstToken(next_asm_input);
                try renderToken(ais, tree, first_token - 1, .newline); // ,
                try renderExtraNewlineToken(ais, tree, first_token);
            } else if (asm_node.first_clobber == null) {
                try renderAsmInput(ais, tree, asm_input, .newline);
                ais.popIndent();
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                return renderToken(ais, tree, asm_node.ast.rparen, space); // rparen
            } else {
                try renderAsmInput(ais, tree, asm_input, .newline);
                const comma_or_colon = tree.lastToken(asm_input) + 1;
                ais.popIndent();
                break :colon3 switch (token_tags[comma_or_colon]) {
                    .comma => comma_or_colon + 1,
                    else => comma_or_colon,
                };
            }
        }
        unreachable;
    };

    try renderToken(ais, tree, colon3, .space); // :
    const first_clobber = asm_node.first_clobber.?;
    var tok_i = first_clobber;
    while (true) {
        switch (token_tags[tok_i + 1]) {
            .r_paren => {
                ais.setIndentDelta(indent_delta);
                ais.popIndent();
                try renderToken(ais, tree, tok_i, .newline);
                return renderToken(ais, tree, tok_i + 1, space);
            },
            .comma => {
                try renderToken(ais, tree, tok_i, .none);
                try renderToken(ais, tree, tok_i + 1, .space);
                tok_i += 2;
            },
            else => unreachable,
        }
    } else unreachable; // TODO shouldn't need this on while(true)
}

fn renderCall(
    ais: *Ais,
    tree: ast.Tree,
    call: ast.full.Call,
    space: Space,
) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const node_tags = tree.nodes.items(.tag);
    const main_tokens = tree.nodes.items(.main_token);

    if (call.async_token) |async_token| {
        try renderToken(ais, tree, async_token, .space);
    }
    try renderExpression(ais, tree, call.ast.fn_expr, .none);

    const lparen = call.ast.lparen;
    const params = call.ast.params;
    if (params.len == 0) {
        try renderToken(ais, tree, lparen, .none);
        return renderToken(ais, tree, lparen + 1, space); // )
    }

    const last_param = params[params.len - 1];
    const after_last_param_tok = tree.lastToken(last_param) + 1;
    if (token_tags[after_last_param_tok] == .comma) {
        ais.pushIndent();
        try renderToken(ais, tree, lparen, Space.newline); // (
        for (params) |param_node, i| {
            if (i + 1 < params.len) {
                try renderExpression(ais, tree, param_node, Space.none);

                // Unindent the comma for multiline string literals
                const is_multiline_string = node_tags[param_node] == .string_literal and
                    token_tags[main_tokens[param_node]] == .multiline_string_literal_line;
                if (is_multiline_string) ais.popIndent();

                const comma = tree.lastToken(param_node) + 1;
                try renderToken(ais, tree, comma, Space.newline); // ,

                if (is_multiline_string) ais.pushIndent();

                try renderExtraNewline(ais, tree, params[i + 1]);
            } else {
                try renderExpression(ais, tree, param_node, Space.comma);
            }
        }
        ais.popIndent();
        return renderToken(ais, tree, after_last_param_tok + 1, space); // )
    }

    try renderToken(ais, tree, lparen, Space.none); // (

    for (params) |param_node, i| {
        try renderExpression(ais, tree, param_node, Space.none);

        if (i + 1 < params.len) {
            const comma = tree.lastToken(param_node) + 1;
            try renderToken(ais, tree, comma, Space.space);
        }
    }
    return renderToken(ais, tree, after_last_param_tok, space); // )
}

/// Render an expression, and the comma that follows it, if it is present in the source.
fn renderExpressionComma(ais: *Ais, tree: ast.Tree, node: ast.Node.Index, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const maybe_comma = tree.lastToken(node) + 1;
    if (token_tags[maybe_comma] == .comma) {
        try renderExpression(ais, tree, node, .none);
        return renderToken(ais, tree, maybe_comma, space);
    } else {
        return renderExpression(ais, tree, node, space);
    }
}

/// Render an expression, but first insert an extra newline if the previous token is 2 or
/// more lines away.
fn renderExpressionNewlined(
    ais: *Ais,
    tree: ast.Tree,
    node: ast.Node.Index,
    space: Space,
) Error!void {
    const token_starts = tree.tokens.items(.start);
    const first_token = tree.firstToken(node);
    if (tree.tokenLocation(token_starts[first_token - 1], first_token).line >= 2) {
        try ais.insertNewline();
    }
    return renderExpression(ais, tree, node, space);
}

fn renderTokenComma(ais: *Ais, tree: ast.Tree, token: ast.TokenIndex, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const maybe_comma = token + 1;
    if (token_tags[maybe_comma] == .comma) {
        try renderToken(ais, tree, token, .none);
        return renderToken(ais, tree, maybe_comma, space);
    } else {
        return renderToken(ais, tree, token, space);
    }
}

const Space = enum {
    /// Output the token lexeme only.
    none,
    /// Output the token lexeme followed by a single space.
    space,
    /// Output the token lexeme followed by a newline.
    newline,
    /// Additionally consume the next token if it is a comma.
    /// In either case, a newline will be inserted afterwards.
    comma,
    /// Additionally consume the next token if it is a comma.
    /// In either case, a space will be inserted afterwards.
    comma_space,
    /// Additionally consume the next token if it is a semicolon.
    /// In either case, a newline will be inserted afterwards.
    semicolon,
    /// Skips writing the possible line comment after the token.
    no_comment,
};

fn renderToken(ais: *Ais, tree: ast.Tree, token_index: ast.TokenIndex, space: Space) Error!void {
    const token_tags = tree.tokens.items(.tag);
    const token_starts = tree.tokens.items(.start);

    const token_start = token_starts[token_index];
    const token_tag = token_tags[token_index];
    const lexeme = token_tag.lexeme() orelse lexeme: {
        var tokenizer: std.zig.Tokenizer = .{
            .buffer = tree.source,
            .index = token_start,
            .pending_invalid_token = null,
        };
        const token = tokenizer.next();
        assert(token.tag == token_tag);
        break :lexeme tree.source[token.loc.start..token.loc.end];
    };
    try ais.writer().writeAll(lexeme);

    switch (space) {
        .no_comment => {},
        .none => {},
        .comma => {
            const count = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], ", ");
            if (count == 0 and token_tags[token_index + 1] == .comma) {
                return renderToken(ais, tree, token_index + 1, Space.newline);
            }
            try ais.writer().writeAll(",");

            if (token_tags[token_index + 2] != .multiline_string_literal_line) {
                try ais.insertNewline();
            }
        },
        .comma_space => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            if (token_tags[token_index + 1] == .comma) {
                return renderToken(ais, tree, token_index + 1, .space);
            } else {
                return ais.writer().writeByte(' ');
            }
        },
        .semicolon => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            if (token_tags[token_index + 1] == .semicolon) {
                return renderToken(ais, tree, token_index + 1, .newline);
            } else {
                return ais.insertNewline();
            }
        },
        .space => {
            _ = try renderComments(ais, tree, token_start + lexeme.len, token_starts[token_index + 1], "");
            return ais.writer().writeByte(' ');
        },
        .newline => {
            if (token_tags[token_index + 1] != .multiline_string_literal_line) {
                try ais.insertNewline();
            }
        },
    }
}

/// end_token is the token one past the last doc comment token. This function
/// searches backwards from there.
fn renderDocComments(ais: *Ais, tree: ast.Tree, end_token: ast.TokenIndex) Error!void {
    // Search backwards for the first doc comment.
    const token_tags = tree.tokens.items(.tag);
    if (end_token == 0) return;
    var tok = end_token - 1;
    while (token_tags[tok] == .doc_comment) {
        if (tok == 0) break;
        tok -= 1;
    } else {
        tok += 1;
    }
    const first_tok = tok;
    if (tok == end_token) return;

    while (true) : (tok += 1) {
        switch (token_tags[tok]) {
            .doc_comment => {
                if (first_tok < end_token) {
                    try renderToken(ais, tree, tok, .newline);
                } else {
                    try renderToken(ais, tree, tok, .no_comment);
                    try ais.insertNewline();
                }
            },
            else => break,
        }
    }
}

fn nodeIsBlock(tag: ast.Node.Tag) bool {
    return switch (tag) {
        .block,
        .block_semicolon,
        .block_two,
        .block_two_semicolon,
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

fn nodeCausesSliceOpSpace(tag: ast.Node.Tag) bool {
    return switch (tag) {
        .@"catch",
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
        .sub,
        .sub_wrap,
        .@"orelse",
        => true,

        else => false,
    };
}
