const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const ast = std.zig.ast;
const Token = std.zig.Token;

const indent_delta = 4;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering.
    OutOfMemory,
};

/// Returns whether anything changed
pub fn render(allocator: *mem.Allocator, stream: var, tree: *ast.Tree) (@TypeOf(stream.*).Error || Error)!bool {
    var change_detection_stream = std.io.changeDetectionStream(tree.source, stream);
    var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &change_detection_stream);

    try renderRoot(allocator, &auto_indenting_stream, tree);

    return change_detection_stream.changeDetected();
}

fn renderRoot(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
) (@TypeOf(stream.*).Error || Error)!void {
    var tok_it = tree.tokens.iterator(0);

    // render all the line comments at the beginning of the file
    while (tok_it.next()) |token| {
        if (token.id != .LineComment) break;
        try stream.outStream().print("{}\n", .{mem.trimRight(u8, tree.tokenSlicePtr(token), " ")});
        if (tok_it.peek()) |next_token| {
            const loc = tree.tokenLocationPtr(token.end, next_token);
            if (loc.line >= 2) {
                try stream.insertNewline();
            }
        }
    }

    var it = tree.root_node.decls.iterator(0);
    while (true) {
        var decl = (it.next() orelse return).*;

        // This loop does the following:
        //
        //  - Iterates through line/doc comment tokens that precedes the current
        //    decl.
        //  - Figures out the first token index (`copy_start_token_index`) which
        //    hasn't been copied to the output stream yet.
        //  - Detects `zig fmt: (off|on)` in the line comment tokens, and
        //    determines whether the current decl should be reformatted or not.
        //
        var token_index = decl.firstToken();
        var fmt_active = true;
        var found_fmt_directive = false;

        var copy_start_token_index = token_index;

        while (token_index != 0) {
            token_index -= 1;
            const token = tree.tokens.at(token_index);
            switch (token.id) {
                .LineComment => {},
                .DocComment => {
                    copy_start_token_index = token_index;
                    continue;
                },
                else => break,
            }

            if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(token)[2..], " "), "zig fmt: off")) {
                if (!found_fmt_directive) {
                    fmt_active = false;
                    found_fmt_directive = true;
                }
            } else if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(token)[2..], " "), "zig fmt: on")) {
                if (!found_fmt_directive) {
                    fmt_active = true;
                    found_fmt_directive = true;
                }
            }
        }

        if (!fmt_active) {
            // Reformatting is disabled for the current decl and possibly some
            // more decls that follow.
            // Find the next `decl` for which reformatting is re-enabled.
            token_index = decl.firstToken();

            while (!fmt_active) {
                decl = (it.next() orelse {
                    // If there's no next reformatted `decl`, just copy the
                    // remaining input tokens and bail out.
                    const start = tree.tokens.at(copy_start_token_index).start;
                    try copyFixingWhitespace(stream, tree.source[start..]);
                    return;
                }).*;
                var decl_first_token_index = decl.firstToken();

                while (token_index < decl_first_token_index) : (token_index += 1) {
                    const token = tree.tokens.at(token_index);
                    switch (token.id) {
                        .LineComment => {},
                        .Eof => unreachable,
                        else => continue,
                    }
                    if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(token)[2..], " "), "zig fmt: on")) {
                        fmt_active = true;
                    } else if (mem.eql(u8, mem.trim(u8, tree.tokenSlicePtr(token)[2..], " "), "zig fmt: off")) {
                        fmt_active = false;
                    }
                }
            }

            // Found the next `decl` for which reformatting is enabled. Copy
            // the input tokens before the `decl` that haven't been copied yet.
            var copy_end_token_index = decl.firstToken();
            token_index = copy_end_token_index;
            while (token_index != 0) {
                token_index -= 1;
                const token = tree.tokens.at(token_index);
                switch (token.id) {
                    .LineComment => {},
                    .DocComment => {
                        copy_end_token_index = token_index;
                        continue;
                    },
                    else => break,
                }
            }

            const start = tree.tokens.at(copy_start_token_index).start;
            const end = tree.tokens.at(copy_end_token_index).start;
            try copyFixingWhitespace(stream, tree.source[start..end]);
        }

        try renderTopLevelDecl(allocator, stream, tree, decl);
        if (it.peek()) |next_decl| {
            try renderExtraNewline(tree, stream, next_decl.*);
        }
    }
}

fn renderExtraNewline(tree: *ast.Tree, stream: var, node: *ast.Node) @TypeOf(stream.*).Error!void {
    const first_token = node.firstToken();
    var prev_token = first_token;
    if (prev_token == 0) return;
    while (tree.tokens.at(prev_token - 1).id == .DocComment) {
        prev_token -= 1;
    }
    const prev_token_end = tree.tokens.at(prev_token - 1).end;
    const loc = tree.tokenLocation(prev_token_end, first_token);
    if (loc.line >= 2) {
        try stream.insertNewline();
    }
}

fn renderTopLevelDecl(allocator: *mem.Allocator, stream: var, tree: *ast.Tree, decl: *ast.Node) (@TypeOf(stream.*).Error || Error)!void {
    try renderContainerDecl(allocator, stream, tree, decl, .Newline);
}

fn renderContainerDecl(allocator: *mem.Allocator, stream: var, tree: *ast.Tree, decl: *ast.Node, space: Space) (@TypeOf(stream.*).Error || Error)!void {
    switch (decl.id) {
        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderDocComments(tree, stream, fn_proto);

            if (fn_proto.body_node) |body_node| {
                try renderExpression(allocator, stream, tree, decl, .Space);
                try renderExpression(allocator, stream, tree, body_node, space);
            } else {
                try renderExpression(allocator, stream, tree, decl, .None);
                try renderToken(tree, stream, tree.nextToken(decl.lastToken()), space);
            }
        },

        .Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, .Space); // pub
            }
            try renderToken(tree, stream, use_decl.use_token, .Space); // usingnamespace
            try renderExpression(allocator, stream, tree, use_decl.expr, .None);
            try renderToken(tree, stream, use_decl.semicolon_token, space); // ;
        },

        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderDocComments(tree, stream, var_decl);
            try renderVarDecl(allocator, stream, tree, var_decl);
        },

        .TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderDocComments(tree, stream, test_decl);
            try renderToken(tree, stream, test_decl.test_token, .Space);
            try renderExpression(allocator, stream, tree, test_decl.name, .Space);
            try renderExpression(allocator, stream, tree, test_decl.body_node, space);
        },

        .ContainerField => {
            const field = @fieldParentPtr(ast.Node.ContainerField, "base", decl);

            try renderDocComments(tree, stream, field);
            if (field.comptime_token) |t| {
                try renderToken(tree, stream, t, .Space); // comptime
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.nextToken(field.lastToken());
                break :blk tree.tokens.at(maybe_comma).id == .Comma;
            };

            // The trailing comma is emitted at the end, but if it's not present
            // we still have to respect the specified `space` parameter
            const last_token_space: Space = if (src_has_trailing_comma) .None else space;

            if (field.type_expr == null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, last_token_space); // name
            } else if (field.type_expr != null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, .None); // align
                    try renderToken(tree, stream, lparen_token, .None); // (
                    try renderExpression(allocator, stream, tree, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, last_token_space); // )
                } else {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, last_token_space); // type
                }
            } else if (field.type_expr == null and field.value_expr != null) {
                try renderToken(tree, stream, field.name_token, .Space); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // =
                try renderExpression(allocator, stream, tree, field.value_expr.?, last_token_space); // value
            } else {
                try renderToken(tree, stream, field.name_token, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, .None); // align
                    try renderToken(tree, stream, lparen_token, .None); // (
                    try renderExpression(allocator, stream, tree, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, .Space); // )
                } else {
                    try renderExpression(allocator, stream, tree, field.type_expr.?, .Space); // type
                }
                try renderToken(tree, stream, tree.prevToken(field.value_expr.?.firstToken()), .Space); // =
                try renderExpression(allocator, stream, tree, field.value_expr.?, last_token_space); // value
            }

            if (src_has_trailing_comma) {
                const comma = tree.nextToken(field.lastToken());
                try renderToken(tree, stream, comma, space);
            }
        },

        .Comptime => {
            assert(!decl.requireSemiColon());
            try renderExpression(allocator, stream, tree, decl, space);
        },

        .DocComment => {
            const comment = @fieldParentPtr(ast.Node.DocComment, "base", decl);
            var it = comment.lines.iterator(0);
            while (it.next()) |line_token_index| {
                try renderToken(tree, stream, line_token_index.*, .Newline);
            }
        },
        else => unreachable,
    }
}

fn renderExpression(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    base: *ast.Node,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    switch (base.id) {
        .Identifier => {
            const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
            return renderToken(tree, stream, identifier.token, space);
        },
        .Block => {
            const block = @fieldParentPtr(ast.Node.Block, "base", base);

            if (block.label) |label| {
                try renderToken(tree, stream, label, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), Space.Space);
            }

            if (block.statements.len == 0) {
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, block.lbrace, Space.None);
            } else {
                stream.pushIndentNextLine();
                defer stream.popIndent();

                try renderToken(tree, stream, block.lbrace, Space.Newline);

                var it = block.statements.iterator(0);
                while (it.next()) |statement| {
                    try renderStatement(allocator, stream, tree, statement.*);

                    if (it.peek()) |next_statement| {
                        try renderExtraNewline(tree, stream, next_statement.*);
                    }
                }
            }
            return renderToken(tree, stream, block.rbrace, space);
        },
        .Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

            try renderToken(tree, stream, defer_node.defer_token, Space.Space);
            return renderExpression(allocator, stream, tree, defer_node.expr, space);
        },
        .Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);

            try renderToken(tree, stream, comptime_node.comptime_token, Space.Space);
            return renderExpression(allocator, stream, tree, comptime_node.expr, space);
        },
        .Noasync => {
            const noasync_node = @fieldParentPtr(ast.Node.Noasync, "base", base);

            try renderToken(tree, stream, noasync_node.noasync_token, Space.Space);
            return renderExpression(allocator, stream, tree, noasync_node.expr, space);
        },

        .Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

            if (suspend_node.body) |body| {
                try renderToken(tree, stream, suspend_node.suspend_token, Space.Space);
                return renderExpression(allocator, stream, tree, body, space);
            } else {
                return renderToken(tree, stream, suspend_node.suspend_token, space);
            }
        },

        .InfixOp => {
            const infix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);

            const op_space = switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Period, ast.Node.InfixOp.Op.ErrorUnion, ast.Node.InfixOp.Op.Range => Space.None,
                else => Space.Space,
            };
            try renderExpression(allocator, stream, tree, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const same_line = tree.tokensOnSameLine(infix_op_node.op_token, tree.nextToken(infix_op_node.op_token));
                break :blk if (same_line) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, after_op_space);

            switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Catch => |maybe_payload| if (maybe_payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.Space);
                },
                else => {},
            }

            stream.pushIndentOneShot();
            return renderExpression(allocator, stream, tree, infix_op_node.rhs, space);
        },

        .PrefixOp => {
            const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);

            switch (prefix_op_node.op) {
                .PtrType => |ptr_info| {
                    const op_tok_id = tree.tokens.at(prefix_op_node.op_token).id;
                    switch (op_tok_id) {
                        .Asterisk, .AsteriskAsterisk => try stream.outStream().writeByte('*'),
                        .LBracket => if (tree.tokens.at(prefix_op_node.op_token + 2).id == .Identifier)
                            try stream.outStream().writeAll("[*c")
                        else
                            try stream.outStream().writeAll("[*"),
                        else => unreachable,
                    }
                    if (ptr_info.sentinel) |sentinel| {
                        const colon_token = tree.prevToken(sentinel.firstToken());
                        try renderToken(tree, stream, colon_token, Space.None); // :
                        const sentinel_space = switch (op_tok_id) {
                            .LBracket => Space.None,
                            else => Space.Space,
                        };
                        try renderExpression(allocator, stream, tree, sentinel, sentinel_space);
                    }
                    switch (op_tok_id) {
                        .Asterisk, .AsteriskAsterisk => {},
                        .LBracket => try stream.outStream().writeByte(']'),
                        else => unreachable,
                    }
                    if (ptr_info.allowzero_token) |allowzero_token| {
                        try renderToken(tree, stream, allowzero_token, Space.Space); // allowzero
                    }
                    if (ptr_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, Space.None); // align
                        try renderToken(tree, stream, lparen_token, Space.None); // (

                        try renderExpression(allocator, stream, tree, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, Space.None); // :
                            try renderExpression(allocator, stream, tree, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, Space.None); // :
                            try renderExpression(allocator, stream, tree, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, Space.Space); // )
                        }
                    }
                    if (ptr_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, Space.Space); // const
                    }
                    if (ptr_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, Space.Space); // volatile
                    }
                },

                .SliceType => |ptr_info| {
                    try renderToken(tree, stream, prefix_op_node.op_token, Space.None); // [
                    if (ptr_info.sentinel) |sentinel| {
                        const colon_token = tree.prevToken(sentinel.firstToken());
                        try renderToken(tree, stream, colon_token, Space.None); // :
                        try renderExpression(allocator, stream, tree, sentinel, Space.None);
                        try renderToken(tree, stream, tree.nextToken(sentinel.lastToken()), Space.None); // ]
                    } else {
                        try renderToken(tree, stream, tree.nextToken(prefix_op_node.op_token), Space.None); // ]
                    }

                    if (ptr_info.allowzero_token) |allowzero_token| {
                        try renderToken(tree, stream, allowzero_token, Space.Space); // allowzero
                    }
                    if (ptr_info.align_info) |align_info| {
                        const lparen_token = tree.prevToken(align_info.node.firstToken());
                        const align_token = tree.prevToken(lparen_token);

                        try renderToken(tree, stream, align_token, Space.None); // align
                        try renderToken(tree, stream, lparen_token, Space.None); // (

                        try renderExpression(allocator, stream, tree, align_info.node, Space.None);

                        if (align_info.bit_range) |bit_range| {
                            const colon1 = tree.prevToken(bit_range.start.firstToken());
                            const colon2 = tree.prevToken(bit_range.end.firstToken());

                            try renderToken(tree, stream, colon1, Space.None); // :
                            try renderExpression(allocator, stream, tree, bit_range.start, Space.None);
                            try renderToken(tree, stream, colon2, Space.None); // :
                            try renderExpression(allocator, stream, tree, bit_range.end, Space.None);

                            const rparen_token = tree.nextToken(bit_range.end.lastToken());
                            try renderToken(tree, stream, rparen_token, Space.Space); // )
                        } else {
                            const rparen_token = tree.nextToken(align_info.node.lastToken());
                            try renderToken(tree, stream, rparen_token, Space.Space); // )
                        }
                    }
                    if (ptr_info.const_token) |const_token| {
                        try renderToken(tree, stream, const_token, Space.Space);
                    }
                    if (ptr_info.volatile_token) |volatile_token| {
                        try renderToken(tree, stream, volatile_token, Space.Space);
                    }
                },

                .ArrayType => |array_info| {
                    const lbracket = prefix_op_node.op_token;
                    const rbracket = tree.nextToken(if (array_info.sentinel) |sentinel|
                        sentinel.lastToken()
                    else
                        array_info.len_expr.lastToken());

                    const starts_with_comment = tree.tokens.at(lbracket + 1).id == .LineComment;
                    const ends_with_comment = tree.tokens.at(rbracket - 1).id == .LineComment;
                    const new_space = if (ends_with_comment) Space.Newline else Space.None;
                    {
                        const do_indent = (starts_with_comment or ends_with_comment);
                        if (do_indent) stream.pushIndent();
                        defer if (do_indent) stream.popIndent();

                        try renderToken(tree, stream, lbracket, Space.None); // [
                        try renderExpression(allocator, stream, tree, array_info.len_expr, new_space);

                        if (starts_with_comment) {
                            try stream.maybeInsertNewline();
                        }
                        if (array_info.sentinel) |sentinel| {
                            const colon_token = tree.prevToken(sentinel.firstToken());
                            try renderToken(tree, stream, colon_token, Space.None); // :
                            try renderExpression(allocator, stream, tree, sentinel, Space.None);
                        }
                        if (starts_with_comment) {
                            try stream.maybeInsertNewline();
                        }
                    }
                    try renderToken(tree, stream, rbracket, Space.None); // ]
                },
                .BitNot,
                .BoolNot,
                .Negation,
                .NegationWrap,
                .OptionalType,
                .AddressOf,
                => {
                    try renderToken(tree, stream, prefix_op_node.op_token, Space.None);
                },

                .Try,
                .Cancel,
                .Resume,
                => {
                    try renderToken(tree, stream, prefix_op_node.op_token, Space.Space);
                },

                .Await => {
                    try renderToken(tree, stream, prefix_op_node.op_token, Space.Space);
                },
            }

            return renderExpression(allocator, stream, tree, prefix_op_node.rhs, space);
        },

        .SuffixOp => {
            const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

            switch (suffix_op.op) {
                .Call => |*call_info| {
                    if (call_info.async_token) |async_token| {
                        try renderToken(tree, stream, async_token, Space.Space);
                    }

                    try renderExpression(allocator, stream, tree, suffix_op.lhs.node, Space.None);

                    const lparen = tree.nextToken(suffix_op.lhs.node.lastToken());

                    if (call_info.params.len == 0) {
                        try renderToken(tree, stream, lparen, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    const src_has_trailing_comma = blk: {
                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                        break :blk tree.tokens.at(maybe_comma).id == .Comma;
                    };

                    if (src_has_trailing_comma) {
                        try renderToken(tree, stream, lparen, Space.Newline);

                        var it = call_info.params.iterator(0);
                        while (it.next()) |param_node| {
                            stream.pushIndent();
                            defer stream.popIndent();

                            if (it.peek()) |next_node| {
                                try renderExpression(allocator, stream, tree, param_node.*, Space.None);
                                const comma = tree.nextToken(param_node.*.lastToken());
                                try renderToken(tree, stream, comma, Space.Newline); // ,
                                try renderExtraNewline(tree, stream, next_node.*);
                            } else {
                                try renderExpression(allocator, stream, tree, param_node.*, Space.Comma);
                            }
                        }
                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    try renderToken(tree, stream, lparen, Space.None); // (

                    var it = call_info.params.iterator(0);
                    while (it.next()) |param_node| {
                        if (param_node.*.id == .MultilineStringLiteral) stream.pushIndentOneShot();

                        try renderExpression(allocator, stream, tree, param_node.*, Space.None);

                        if (it.peek()) |next_param| {
                            const comma = tree.nextToken(param_node.*.lastToken());
                            try renderToken(tree, stream, comma, Space.Space);
                        }
                    }
                    return renderToken(tree, stream, suffix_op.rtoken, space);
                },

                .ArrayAccess => |index_expr| {
                    const lbracket = tree.nextToken(suffix_op.lhs.node.lastToken());
                    const rbracket = tree.nextToken(index_expr.lastToken());

                    try renderExpression(allocator, stream, tree, suffix_op.lhs.node, Space.None);
                    try renderToken(tree, stream, lbracket, Space.None); // [

                    const starts_with_comment = tree.tokens.at(lbracket + 1).id == .LineComment;
                    const ends_with_comment = tree.tokens.at(rbracket - 1).id == .LineComment;
                    {
                        const new_space = if (ends_with_comment) Space.Newline else Space.None;

                        stream.pushIndent();
                        defer stream.popIndent();
                        try renderExpression(allocator, stream, tree, index_expr, new_space);
                    }
                    if (starts_with_comment) try stream.maybeInsertNewline();
                    return renderToken(tree, stream, rbracket, space); // ]
                },

                .Deref => {
                    try renderExpression(allocator, stream, tree, suffix_op.lhs.node, Space.None);
                    return renderToken(tree, stream, suffix_op.rtoken, space); // .*
                },

                .UnwrapOptional => {
                    try renderExpression(allocator, stream, tree, suffix_op.lhs.node, Space.None);
                    try renderToken(tree, stream, tree.prevToken(suffix_op.rtoken), Space.None); // .
                    return renderToken(tree, stream, suffix_op.rtoken, space); // ?
                },

                .Slice => |range| {
                    try renderExpression(allocator, stream, tree, suffix_op.lhs.node, Space.None);

                    const lbracket = tree.prevToken(range.start.firstToken());
                    const dotdot = tree.nextToken(range.start.lastToken());

                    const after_start_space_bool = nodeCausesSliceOpSpace(range.start) or
                        (if (range.end) |end| nodeCausesSliceOpSpace(end) else false);
                    const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
                    const after_op_space = if (range.end != null) after_start_space else Space.None;

                    try renderToken(tree, stream, lbracket, Space.None); // [
                    try renderExpression(allocator, stream, tree, range.start, after_start_space);
                    try renderToken(tree, stream, dotdot, after_op_space); // ..
                    if (range.end) |end| {
                        const after_end_space = if (range.sentinel != null) Space.Space else Space.None;
                        try renderExpression(allocator, stream, tree, end, after_end_space);
                    }
                    if (range.sentinel) |sentinel| {
                        const colon = tree.prevToken(sentinel.firstToken());
                        try renderToken(tree, stream, colon, Space.None); // :
                        try renderExpression(allocator, stream, tree, sentinel, Space.None);
                    }
                    return renderToken(tree, stream, suffix_op.rtoken, space); // ]
                },

                .StructInitializer => |*field_inits| {
                    const lbrace = switch (suffix_op.lhs) {
                        .dot => |dot| tree.nextToken(dot),
                        .node => |node| tree.nextToken(node.lastToken()),
                    };

                    if (field_inits.len == 0) {
                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }

                        {
                            stream.pushIndentNextLine();
                            defer stream.popIndent();
                            try renderToken(tree, stream, lbrace, Space.None);
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    const src_has_trailing_comma = blk: {
                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                        break :blk tree.tokens.at(maybe_comma).id == .Comma;
                    };

                    const src_same_line = blk: {
                        const loc = tree.tokenLocation(tree.tokens.at(lbrace).end, suffix_op.rtoken);
                        break :blk loc.line == 0;
                    };

                    const expr_outputs_one_line = blk: {
                        // render field expressions until a LF is found
                        var it = field_inits.iterator(0);
                        while (it.next()) |field_init| {
                            var find_stream = std.io.findByteOutStream('\n', &std.io.null_out_stream);
                            var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &find_stream);

                            try renderExpression(allocator, &auto_indenting_stream, tree, field_init.*, Space.None);
                            if (find_stream.byte_found) break :blk false;
                        }
                        break :blk true;
                    };

                    if (field_inits.len == 1) blk: {
                        const field_init = field_inits.at(0).*.cast(ast.Node.FieldInitializer).?;

                        if (field_init.expr.cast(ast.Node.SuffixOp)) |nested_suffix_op| {
                            if (nested_suffix_op.op == .StructInitializer) {
                                break :blk;
                            }
                        }

                        // if the expression outputs to multiline, make this struct multiline
                        if (!expr_outputs_one_line or src_has_trailing_comma) {
                            break :blk;
                        }

                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }
                        try renderToken(tree, stream, lbrace, Space.Space);
                        try renderExpression(allocator, stream, tree, &field_init.base, Space.Space);
                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    if (!src_has_trailing_comma and src_same_line and expr_outputs_one_line) {
                        // render all on one line, no trailing comma
                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }
                        try renderToken(tree, stream, lbrace, Space.Space);

                        var it = field_inits.iterator(0);
                        while (it.next()) |field_init| {
                            if (it.peek() != null) {
                                try renderExpression(allocator, stream, tree, field_init.*, Space.None);

                                const comma = tree.nextToken(field_init.*.lastToken());
                                try renderToken(tree, stream, comma, Space.Space);
                            } else {
                                try renderExpression(allocator, stream, tree, field_init.*, Space.Space);
                            }
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    {
                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }

                        stream.pushIndentNextLine();
                        defer stream.popIndent();

                        try renderToken(tree, stream, lbrace, Space.Newline);

                        var it = field_inits.iterator(0);
                        while (it.next()) |field_init| {
                            if (it.peek()) |next_field_init| {
                                try renderExpression(allocator, stream, tree, field_init.*, Space.None);

                                const comma = tree.nextToken(field_init.*.lastToken());
                                try renderToken(tree, stream, comma, Space.Newline);

                                try renderExtraNewline(tree, stream, next_field_init.*);
                            } else {
                                try renderExpression(allocator, stream, tree, field_init.*, Space.Comma);
                            }
                        }
                    }

                    return renderToken(tree, stream, suffix_op.rtoken, space);
                },

                .ArrayInitializer => |*exprs| {
                    const lbrace = switch (suffix_op.lhs) {
                        .dot => |dot| tree.nextToken(dot),
                        .node => |node| tree.nextToken(node.lastToken()),
                    };

                    if (exprs.len == 0) {
                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }

                        {
                            stream.pushIndent();
                            defer stream.popIndent();
                            try renderToken(tree, stream, lbrace, Space.None);
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }
                    if (exprs.len == 1 and tree.tokens.at(exprs.at(0).*.lastToken() + 1).id == .RBrace) {
                        const expr = exprs.at(0).*;

                        switch (suffix_op.lhs) {
                            .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                            .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                        }
                        try renderToken(tree, stream, lbrace, Space.None);
                        try renderExpression(allocator, stream, tree, expr, Space.None);
                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }

                    switch (suffix_op.lhs) {
                        .dot => |dot| try renderToken(tree, stream, dot, Space.None),
                        .node => |node| try renderExpression(allocator, stream, tree, node, Space.None),
                    }

                    // scan to find row size
                    const maybe_row_size: ?usize = blk: {
                        var count: usize = 1;
                        var it = exprs.iterator(0);
                        while (true) {
                            const expr = it.next().?.*;
                            if (it.peek()) |next_expr| {
                                const expr_last_token = expr.*.lastToken() + 1;
                                const loc = tree.tokenLocation(tree.tokens.at(expr_last_token).end, next_expr.*.firstToken());
                                if (loc.line != 0) break :blk count;
                                count += 1;
                            } else {
                                const expr_last_token = expr.*.lastToken();
                                const loc = tree.tokenLocation(tree.tokens.at(expr_last_token).end, suffix_op.rtoken);
                                if (loc.line == 0) {
                                    // all on one line
                                    const src_has_trailing_comma = trailblk: {
                                        const maybe_comma = tree.prevToken(suffix_op.rtoken);
                                        break :trailblk tree.tokens.at(maybe_comma).id == .Comma;
                                    };
                                    if (src_has_trailing_comma) {
                                        break :blk 1; // force row size 1
                                    } else {
                                        break :blk null; // no newlines
                                    }
                                }
                                break :blk count;
                            }
                        }
                    };

                    if (maybe_row_size) |row_size| {
                        // A place to store the width of each expression and its column's maximum
                        var widths = try allocator.alloc(usize, exprs.len + row_size);
                        defer allocator.free(widths);
                        mem.set(usize, widths, 0);

                        var expr_widths = widths[0 .. widths.len - row_size];
                        var column_widths = widths[widths.len - row_size ..];

                        // Null stream for counting the printed length of each expression
                        var counting_stream = std.io.countingOutStream(&std.io.null_out_stream);
                        var auto_indenting_stream = std.io.autoIndentingStream(indent_delta, &counting_stream);

                        var it = exprs.iterator(0);
                        var i: usize = 0;

                        while (it.next()) |expr| : (i += 1) {
                            counting_stream.bytes_written = 0;
                            try renderExpression(allocator, &auto_indenting_stream, tree, expr.*, Space.None);
                            const width = @intCast(usize, counting_stream.bytes_written);
                            const col = i % row_size;
                            column_widths[col] = std.math.max(column_widths[col], width);
                            expr_widths[i] = width;
                        }

                        {
                            stream.pushIndentNextLine();
                            defer stream.popIndent();
                            try renderToken(tree, stream, lbrace, Space.Newline);

                            it.set(0);
                            i = 0;
                            var col: usize = 1;
                            while (it.next()) |expr| : (i += 1) {
                                if (it.peek()) |next_expr| {
                                    try renderExpression(allocator, stream, tree, expr.*, Space.None);

                                    const comma = tree.nextToken(expr.*.lastToken());

                                    if (col != row_size) {
                                        try renderToken(tree, stream, comma, Space.Space); // ,

                                        const padding = column_widths[i % row_size] - expr_widths[i];
                                        try stream.outStream().writeByteNTimes(' ', padding);

                                        col += 1;
                                        continue;
                                    }
                                    col = 1;

                                    if (tree.tokens.at(tree.nextToken(comma)).id != .MultilineStringLiteralLine) {
                                        try renderToken(tree, stream, comma, Space.Newline); // ,
                                    } else {
                                        try renderToken(tree, stream, comma, Space.None); // ,
                                    }

                                    try renderExtraNewline(tree, stream, next_expr.*);
                                } else {
                                    try renderExpression(allocator, stream, tree, expr.*, Space.Comma); // ,
                                }
                            }
                        }
                        const last_node = it.prev().?;
                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    } else {
                        try renderToken(tree, stream, lbrace, Space.Space);
                        var it = exprs.iterator(0);
                        while (it.next()) |expr| {
                            if (it.peek()) |next_expr| {
                                try renderExpression(allocator, stream, tree, expr.*, Space.None);
                                const comma = tree.nextToken(expr.*.lastToken());
                                try renderToken(tree, stream, comma, Space.Space); // ,
                            } else {
                                try renderExpression(allocator, stream, tree, expr.*, Space.Space);
                            }
                        }

                        return renderToken(tree, stream, suffix_op.rtoken, space);
                    }
                },
            }
        },

        .ControlFlowExpression => {
            const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

            switch (flow_expr.kind) {
                .Break => |maybe_label| {
                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, space); // break
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, Space.Space); // break
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, Space.None); // :

                        if (flow_expr.rhs == null) {
                            return renderExpression(allocator, stream, tree, label, space); // label
                        }
                        try renderExpression(allocator, stream, tree, label, Space.Space); // label
                    }
                },
                .Continue => |maybe_label| {
                    assert(flow_expr.rhs == null);

                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, space); // continue
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, Space.Space); // continue
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, Space.None); // :

                        return renderExpression(allocator, stream, tree, label, space);
                    }
                },
                .Return => {
                    if (flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, space);
                    }
                    try renderToken(tree, stream, flow_expr.ltoken, Space.Space);
                },
            }

            return renderExpression(allocator, stream, tree, flow_expr.rhs.?, space);
        },

        .Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            try renderExpression(allocator, stream, tree, payload.error_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, space);
        },

        .PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, Space.None);
            }
            try renderExpression(allocator, stream, tree, payload.value_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, space);
        },

        .PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, Space.None);
            }
            try renderExpression(allocator, stream, tree, payload.value_symbol, Space.None);

            if (payload.index_symbol) |index_symbol| {
                const comma = tree.nextToken(payload.value_symbol.lastToken());

                try renderToken(tree, stream, comma, Space.Space);
                try renderExpression(allocator, stream, tree, index_symbol, Space.None);
            }

            return renderToken(tree, stream, payload.rpipe, space);
        },

        .GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, Space.None);
            {
                stream.pushIndentOneShot();
                try renderExpression(allocator, stream, tree, grouped_expr.expr, Space.None);
            }
            return renderToken(tree, stream, grouped_expr.rparen, space);
        },

        .FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try renderToken(tree, stream, field_init.period_token, Space.None); // .
            try renderToken(tree, stream, field_init.name_token, Space.Space); // name
            try renderToken(tree, stream, tree.nextToken(field_init.name_token), Space.Space); // =
            return renderExpression(allocator, stream, tree, field_init.expr, space);
        },

        .IntegerLiteral => {
            const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
            return renderToken(tree, stream, integer_literal.token, space);
        },
        .FloatLiteral => {
            const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
            return renderToken(tree, stream, float_literal.token, space);
        },
        .StringLiteral => {
            const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
            return renderToken(tree, stream, string_literal.token, space);
        },
        .CharLiteral => {
            const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, char_literal.token, space);
        },
        .BoolLiteral => {
            const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, bool_literal.token, space);
        },
        .NullLiteral => {
            const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
            return renderToken(tree, stream, null_literal.token, space);
        },
        .Unreachable => {
            const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
            return renderToken(tree, stream, unreachable_node.token, space);
        },
        .ErrorType => {
            const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
            return renderToken(tree, stream, error_type.token, space);
        },
        .VarType => {
            const var_type = @fieldParentPtr(ast.Node.VarType, "base", base);
            return renderToken(tree, stream, var_type.token, space);
        },
        .ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            if (container_decl.layout_token) |layout_token| {
                try renderToken(tree, stream, layout_token, Space.Space);
            }

            switch (container_decl.init_arg_expr) {
                .None => {
                    try renderToken(tree, stream, container_decl.kind_token, Space.Space); // union
                },
                .Enum => |enum_tag_type| {
                    try renderToken(tree, stream, container_decl.kind_token, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const enum_token = tree.nextToken(lparen);

                    try renderToken(tree, stream, lparen, Space.None); // (
                    try renderToken(tree, stream, enum_token, Space.None); // enum

                    if (enum_tag_type) |expr| {
                        try renderToken(tree, stream, tree.nextToken(enum_token), Space.None); // (
                        try renderExpression(allocator, stream, tree, expr, Space.None);

                        const rparen = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, rparen, Space.None); // )
                        try renderToken(tree, stream, tree.nextToken(rparen), Space.Space); // )
                    } else {
                        try renderToken(tree, stream, tree.nextToken(enum_token), Space.Space); // )
                    }
                },
                .Type => |type_expr| {
                    try renderToken(tree, stream, container_decl.kind_token, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const rparen = tree.nextToken(type_expr.lastToken());

                    try renderToken(tree, stream, lparen, Space.None); // (
                    try renderExpression(allocator, stream, tree, type_expr, Space.None);
                    try renderToken(tree, stream, rparen, Space.Space); // )
                },
            }

            if (container_decl.fields_and_decls.len == 0) {
                {
                    stream.pushIndentNextLine();
                    defer stream.popIndent();
                    try renderToken(tree, stream, container_decl.lbrace_token, Space.None); // {
                }
                return renderToken(tree, stream, container_decl.rbrace_token, space); // }
            }

            const src_has_trailing_comma = blk: {
                var maybe_comma = tree.prevToken(container_decl.lastToken());
                // Doc comments for a field may also appear after the comma, eg.
                // field_name: T, // comment attached to field_name
                if (tree.tokens.at(maybe_comma).id == .DocComment)
                    maybe_comma = tree.prevToken(maybe_comma);
                break :blk tree.tokens.at(maybe_comma).id == .Comma;
            };

            // Check if the first declaration and the { are on the same line
            const src_has_newline = !tree.tokensOnSameLine(
                container_decl.lbrace_token,
                container_decl.fields_and_decls.at(0).*.firstToken(),
            );

            // We can only print all the elements in-line if all the
            // declarations inside are fields
            const src_has_only_fields = blk: {
                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    if (decl.*.id != .ContainerField) break :blk false;
                }
                break :blk true;
            };

            if (src_has_trailing_comma or !src_has_only_fields) {
                // One declaration per line
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, container_decl.lbrace_token, .Newline); // {

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    try renderContainerDecl(allocator, stream, tree, decl.*, .Newline);

                    if (it.peek()) |next_decl| {
                        try renderExtraNewline(tree, stream, next_decl.*);
                    }
                }
            } else if (src_has_newline) {
                // All the declarations on the same line, but place the items on
                // their own line
                try renderToken(tree, stream, container_decl.lbrace_token, .Newline); // {

                stream.pushIndent();
                defer stream.popIndent();

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    const space_after_decl: Space = if (it.peek() == null) .Newline else .Space;
                    try renderContainerDecl(allocator, stream, tree, decl.*, space_after_decl);
                }
            } else {
                // All the declarations on the same line
                try renderToken(tree, stream, container_decl.lbrace_token, .Space); // {

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    try renderContainerDecl(allocator, stream, tree, decl.*, .Space);
                }
            }

            return renderToken(tree, stream, container_decl.rbrace_token, space); // }
        },

        .ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            const lbrace = tree.nextToken(err_set_decl.error_token);

            if (err_set_decl.decls.len == 0) {
                try renderToken(tree, stream, err_set_decl.error_token, Space.None);
                try renderToken(tree, stream, lbrace, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, space);
            }

            if (err_set_decl.decls.len == 1) blk: {
                const node = err_set_decl.decls.at(0).*;

                // if there are any doc comments or same line comments
                // don't try to put it all on one line
                if (node.cast(ast.Node.ErrorTag)) |tag| {
                    if (tag.doc_comments != null) break :blk;
                } else {
                    break :blk;
                }

                try renderToken(tree, stream, err_set_decl.error_token, Space.None); // error
                try renderToken(tree, stream, lbrace, Space.None); // {
                try renderExpression(allocator, stream, tree, node, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, space); // }
            }

            try renderToken(tree, stream, err_set_decl.error_token, Space.None); // error
            {
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, lbrace, Space.Newline); // {

                var it = err_set_decl.decls.iterator(0);
                while (it.next()) |node| {
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, node.*, Space.None);
                        try renderToken(tree, stream, tree.nextToken(node.*.lastToken()), Space.Newline); // ,

                        try renderExtraNewline(tree, stream, next_node.*);
                    } else {
                        try renderExpression(allocator, stream, tree, node.*, Space.Comma);
                    }
                }
            }

            return renderToken(tree, stream, err_set_decl.rbrace_token, space); // }
        },

        .ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", base);

            try renderDocComments(tree, stream, tag);
            return renderToken(tree, stream, tag.name_token, space); // name
        },

        .MultilineStringLiteral => {
            const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);

            var line_it = multiline_str_literal.lines.iterator(0);
            {
                const locked_indents = stream.lockOneShotIndent();
                defer {
                    var i: u8 = 0;
                    while (i < locked_indents) : (i += 1) stream.popIndent();
                }
                try stream.maybeInsertNewline();

                while (line_it.next()) |line| try renderToken(tree, stream, line.*, Space.None);
            }
        },
        .UndefinedLiteral => {
            const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
            return renderToken(tree, stream, undefined_literal.token, space);
        },

        .BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);

            // TODO: Remove condition after deprecating 'typeOf'. See https://github.com/ziglang/zig/issues/1348
            if (mem.eql(u8, tree.tokenSlicePtr(tree.tokens.at(builtin_call.builtin_token)), "@typeOf")) {
                try stream.outStream().writeAll("@TypeOf");
            } else {
                try renderToken(tree, stream, builtin_call.builtin_token, Space.None); // @name
            }

            const src_params_trailing_comma = blk: {
                if (builtin_call.params.len < 2) break :blk false;
                const last_node = builtin_call.params.at(builtin_call.params.len - 1).*;
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.tokens.at(maybe_comma).id == .Comma;
            };

            const lparen = tree.nextToken(builtin_call.builtin_token);

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, Space.None); // (

                // render all on one line, no trailing comma
                var it = builtin_call.params.iterator(0);
                while (it.next()) |param_node| {
                    try renderExpression(allocator, stream, tree, param_node.*, Space.None);

                    if (it.peek() != null) {
                        const comma_token = tree.nextToken(param_node.*.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Space); // ,
                    }
                }
            } else {
                // one param per line
                stream.pushIndent();
                defer stream.popIndent();
                try renderToken(tree, stream, lparen, Space.Newline); // (

                var it = builtin_call.params.iterator(0);
                while (it.next()) |param_node| {
                    try renderExpression(allocator, stream, tree, param_node.*, Space.Comma);
                }
            }

            return renderToken(tree, stream, builtin_call.rparen_token, space); // )
        },

        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.visib_token) |visib_token_index| {
                const visib_token = tree.tokens.at(visib_token_index);
                assert(visib_token.id == .Keyword_pub or visib_token.id == .Keyword_export);

                try renderToken(tree, stream, visib_token_index, Space.Space); // pub
            }

            // Some extra machinery is needed to rewrite the old-style cc
            // notation to the new callconv one
            var cc_rewrite_str: ?[*:0]const u8 = null;
            if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                const tok = tree.tokens.at(extern_export_inline_token);
                if (tok.id != .Keyword_extern or fn_proto.body_node == null) {
                    try renderToken(tree, stream, extern_export_inline_token, Space.Space); // extern/export
                } else {
                    cc_rewrite_str = ".C";
                    fn_proto.lib_name = null;
                }
            }

            if (fn_proto.lib_name) |lib_name| {
                try renderExpression(allocator, stream, tree, lib_name, Space.Space);
            }

            if (fn_proto.cc_token) |cc_token| {
                var str = tree.tokenSlicePtr(tree.tokens.at(cc_token));
                if (mem.eql(u8, str, "stdcallcc")) {
                    cc_rewrite_str = ".Stdcall";
                } else if (mem.eql(u8, str, "nakedcc")) {
                    cc_rewrite_str = ".Naked";
                } else try renderToken(tree, stream, cc_token, Space.Space); // stdcallcc
            }

            const lparen = if (fn_proto.name_token) |name_token| blk: {
                try renderToken(tree, stream, fn_proto.fn_token, Space.Space); // fn
                try renderToken(tree, stream, name_token, Space.None); // name
                break :blk tree.nextToken(name_token);
            } else blk: {
                try renderToken(tree, stream, fn_proto.fn_token, Space.Space); // fn
                break :blk tree.nextToken(fn_proto.fn_token);
            };
            assert(tree.tokens.at(lparen).id == .LParen);

            const rparen = tree.prevToken(
            // the first token for the annotation expressions is the left
            // parenthesis, hence the need for two prevToken
            if (fn_proto.align_expr) |align_expr|
                tree.prevToken(tree.prevToken(align_expr.firstToken()))
            else if (fn_proto.section_expr) |section_expr|
                tree.prevToken(tree.prevToken(section_expr.firstToken()))
            else if (fn_proto.callconv_expr) |callconv_expr|
                tree.prevToken(tree.prevToken(callconv_expr.firstToken()))
            else switch (fn_proto.return_type) {
                .Explicit => |node| node.firstToken(),
                .InferErrorSet => |node| tree.prevToken(node.firstToken()),
            });
            assert(tree.tokens.at(rparen).id == .RParen);

            const src_params_trailing_comma = blk: {
                const maybe_comma = tree.tokens.at(rparen - 1).id;
                break :blk maybe_comma == .Comma or maybe_comma == .LineComment;
            };

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, Space.None); // (

                // render all on one line, no trailing comma
                var it = fn_proto.params.iterator(0);
                while (it.next()) |param_decl_node| {
                    try renderParamDecl(allocator, stream, tree, param_decl_node.*, Space.None);

                    if (it.peek() != null) {
                        const comma = tree.nextToken(param_decl_node.*.lastToken());
                        try renderToken(tree, stream, comma, Space.Space); // ,
                    }
                }
            } else {
                // one param per line
                stream.pushIndent();
                defer stream.popIndent();
                try renderToken(tree, stream, lparen, Space.Newline); // (

                var it = fn_proto.params.iterator(0);
                while (it.next()) |param_decl_node| {
                    try renderParamDecl(allocator, stream, tree, param_decl_node.*, Space.Comma);
                }
            }

            try renderToken(tree, stream, rparen, Space.Space); // )

            if (fn_proto.align_expr) |align_expr| {
                const align_rparen = tree.nextToken(align_expr.lastToken());
                const align_lparen = tree.prevToken(align_expr.firstToken());
                const align_kw = tree.prevToken(align_lparen);

                try renderToken(tree, stream, align_kw, Space.None); // align
                try renderToken(tree, stream, align_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, align_expr, Space.None);
                try renderToken(tree, stream, align_rparen, Space.Space); // )
            }

            if (fn_proto.section_expr) |section_expr| {
                const section_rparen = tree.nextToken(section_expr.lastToken());
                const section_lparen = tree.prevToken(section_expr.firstToken());
                const section_kw = tree.prevToken(section_lparen);

                try renderToken(tree, stream, section_kw, Space.None); // section
                try renderToken(tree, stream, section_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, section_expr, Space.None);
                try renderToken(tree, stream, section_rparen, Space.Space); // )
            }

            if (fn_proto.callconv_expr) |callconv_expr| {
                const callconv_rparen = tree.nextToken(callconv_expr.lastToken());
                const callconv_lparen = tree.prevToken(callconv_expr.firstToken());
                const callconv_kw = tree.prevToken(callconv_lparen);

                try renderToken(tree, stream, callconv_kw, Space.None); // callconv
                try renderToken(tree, stream, callconv_lparen, Space.None); // (
                try renderExpression(allocator, stream, tree, callconv_expr, Space.None);
                try renderToken(tree, stream, callconv_rparen, Space.Space); // )
            } else if (cc_rewrite_str) |str| {
                try stream.outStream().writeAll("callconv(");
                try stream.outStream().writeAll(mem.toSliceConst(u8, str));
                try stream.outStream().writeAll(") ");
            }

            switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| {
                    return renderExpression(allocator, stream, tree, node, space);
                },
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
                    try renderToken(tree, stream, tree.prevToken(node.firstToken()), Space.None); // !
                    return renderExpression(allocator, stream, tree, node, space);
                },
            }
        },

        .AnyFrameType => {
            const anyframe_type = @fieldParentPtr(ast.Node.AnyFrameType, "base", base);

            if (anyframe_type.result) |result| {
                try renderToken(tree, stream, anyframe_type.anyframe_token, Space.None); // anyframe
                try renderToken(tree, stream, result.arrow_token, Space.None); // ->
                return renderExpression(allocator, stream, tree, result.return_type, space);
            } else {
                return renderToken(tree, stream, anyframe_type.anyframe_token, space); // anyframe
            }
        },

        .DocComment => unreachable, // doc comments are attached to nodes

        .Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try renderToken(tree, stream, switch_node.switch_token, Space.Space); // switch
            try renderToken(tree, stream, tree.nextToken(switch_node.switch_token), Space.None); // (

            const rparen = tree.nextToken(switch_node.expr.lastToken());
            const lbrace = tree.nextToken(rparen);

            if (switch_node.cases.len == 0) {
                try renderExpression(allocator, stream, tree, switch_node.expr, Space.None);
                try renderToken(tree, stream, rparen, Space.Space); // )
                try renderToken(tree, stream, lbrace, Space.None); // {
                return renderToken(tree, stream, switch_node.rbrace, space); // }
            }

            try renderExpression(allocator, stream, tree, switch_node.expr, Space.None);
            try renderToken(tree, stream, rparen, Space.Space); // )

            {
                stream.pushIndentNextLine();
                defer stream.popIndent();
                try renderToken(tree, stream, lbrace, Space.Newline); // {

                var it = switch_node.cases.iterator(0);
                while (it.next()) |node| {
                    try renderExpression(allocator, stream, tree, node.*, Space.Comma);

                    if (it.peek()) |next_node| {
                        try renderExtraNewline(tree, stream, next_node.*);
                    }
                }
            }

            return renderToken(tree, stream, switch_node.rbrace, space); // }
        },

        .SwitchCase => {
            const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

            assert(switch_case.items.len != 0);
            const src_has_trailing_comma = blk: {
                const last_node = switch_case.items.at(switch_case.items.len - 1).*;
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.tokens.at(maybe_comma).id == .Comma;
            };

            if (switch_case.items.len == 1 or !src_has_trailing_comma) {
                var it = switch_case.items.iterator(0);
                while (it.next()) |node| {
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Space); // ,
                        try renderExtraNewline(tree, stream, next_node.*);
                    } else {
                        try renderExpression(allocator, stream, tree, node.*, Space.Space);
                    }
                }
            } else {
                var it = switch_case.items.iterator(0);
                while (true) {
                    const node = it.next().?;
                    if (it.peek()) |next_node| {
                        try renderExpression(allocator, stream, tree, node.*, Space.None);

                        const comma_token = tree.nextToken(node.*.lastToken());
                        try renderToken(tree, stream, comma_token, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, next_node.*);
                    } else {
                        try renderExpression(allocator, stream, tree, node.*, Space.Comma);
                        break;
                    }
                }
            }

            try renderToken(tree, stream, switch_case.arrow_token, Space.Space); // =>

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }

            return renderExpression(allocator, stream, tree, switch_case.expr, space);
        },
        .SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            return renderToken(tree, stream, switch_else.token, space);
        },
        .Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            const body_is_block = nodeIsBlock(else_node.body);
            const same_line = body_is_block or tree.tokensOnSameLine(else_node.else_token, else_node.body.lastToken());

            const after_else_space = if (same_line or else_node.payload != null) Space.Space else Space.Newline;
            try renderToken(tree, stream, else_node.else_token, after_else_space);

            if (else_node.payload) |payload| {
                const payload_space = if (same_line) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, payload, payload_space);
            }

            if (same_line) {
                return renderExpression(allocator, stream, tree, else_node.body, space);
            } else {
                stream.pushIndent();
                defer stream.popIndent();
                return renderExpression(allocator, stream, tree, else_node.body, space);
            }
        },

        .While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try renderToken(tree, stream, label, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), Space.Space); // :
            }

            if (while_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, Space.Space); // inline
            }

            try renderToken(tree, stream, while_node.while_token, Space.Space); // while
            try renderToken(tree, stream, tree.nextToken(while_node.while_token), Space.None); // (
            try renderExpression(allocator, stream, tree, while_node.condition, Space.None);

            const cond_rparen = tree.nextToken(while_node.condition.lastToken());

            const body_is_block = nodeIsBlock(while_node.body);

            var block_start_space: Space = undefined;
            var after_body_space: Space = undefined;

            if (body_is_block) {
                block_start_space = Space.BlockStart;
                after_body_space = if (while_node.@"else" == null) space else Space.SpaceOrOutdent;
            } else if (tree.tokensOnSameLine(cond_rparen, while_node.body.lastToken())) {
                block_start_space = Space.Space;
                after_body_space = if (while_node.@"else" == null) space else Space.Space;
            } else {
                block_start_space = Space.Newline;
                after_body_space = if (while_node.@"else" == null) space else Space.Newline;
            }

            {
                const rparen_space = if (while_node.payload != null or while_node.continue_expr != null) Space.Space else block_start_space;
                try renderToken(tree, stream, cond_rparen, rparen_space); // )
            }

            if (while_node.payload) |payload| {
                const payload_space = Space.Space; //if (while_node.continue_expr != null) Space.Space else block_start_space;
                try renderExpression(allocator, stream, tree, payload, payload_space);
            }

            if (while_node.continue_expr) |continue_expr| {
                const rparen = tree.nextToken(continue_expr.lastToken());
                const lparen = tree.prevToken(continue_expr.firstToken());
                const colon = tree.prevToken(lparen);

                try renderToken(tree, stream, colon, Space.Space); // :
                try renderToken(tree, stream, lparen, Space.None); // (

                try renderExpression(allocator, stream, tree, continue_expr, Space.None);

                try renderToken(tree, stream, rparen, block_start_space); // )
            }

            {
                if (!body_is_block) stream.pushIndent();
                defer if (!body_is_block) stream.popIndent();
                try renderExpression(allocator, stream, tree, while_node.body, after_body_space);
            }

            if (while_node.@"else") |@"else"| {
                return renderExpression(allocator, stream, tree, &@"else".base, space);
            }
        },

        .For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);

            if (for_node.label) |label| {
                try renderToken(tree, stream, label, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), Space.Space); // :
            }

            if (for_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, Space.Space); // inline
            }

            try renderToken(tree, stream, for_node.for_token, Space.Space); // for
            try renderToken(tree, stream, tree.nextToken(for_node.for_token), Space.None); // (
            try renderExpression(allocator, stream, tree, for_node.array_expr, Space.None);

            const rparen = tree.nextToken(for_node.array_expr.lastToken());

            const body_is_block = for_node.body.id == .Block;
            const src_one_line_to_body = !body_is_block and tree.tokensOnSameLine(rparen, for_node.body.firstToken());
            const body_on_same_line = body_is_block or src_one_line_to_body;

            try renderToken(tree, stream, rparen, Space.Space); // )

            const space_after_payload = if (body_on_same_line) Space.Space else Space.Newline;
            try renderExpression(allocator, stream, tree, for_node.payload, space_after_payload); // |x|

            const space_after_body = blk: {
                if (for_node.@"else") |@"else"| {
                    const src_one_line_to_else = tree.tokensOnSameLine(rparen, @"else".firstToken());
                    if (body_is_block or src_one_line_to_else) {
                        break :blk Space.Space;
                    } else {
                        break :blk Space.Newline;
                    }
                } else {
                    break :blk space;
                }
            };

            {
                if (!body_on_same_line) stream.pushIndent();
                defer if (!body_on_same_line) stream.popIndent();
                try renderExpression(allocator, stream, tree, for_node.body, space_after_body); // { body }
            }

            if (for_node.@"else") |@"else"| {
                return renderExpression(allocator, stream, tree, &@"else".base, space); // else
            }
        },

        .If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);

            const lparen = tree.nextToken(if_node.if_token);
            const rparen = tree.nextToken(if_node.condition.lastToken());

            try renderToken(tree, stream, if_node.if_token, Space.Space); // if
            try renderToken(tree, stream, lparen, Space.None); // (

            try renderExpression(allocator, stream, tree, if_node.condition, Space.None); // condition

            const body_is_if_block = if_node.body.id == .If;
            const body_is_block = nodeIsBlock(if_node.body);

            if (body_is_if_block) {
                try renderExtraNewline(tree, stream, if_node.body);
            } else if (body_is_block) {
                const after_rparen_space = if (if_node.payload == null) Space.BlockStart else Space.Space;
                try renderToken(tree, stream, rparen, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.BlockStart); // |x|
                }

                if (if_node.@"else") |@"else"| {
                    try renderExpression(allocator, stream, tree, if_node.body, Space.SpaceOrOutdent);
                    return renderExpression(allocator, stream, tree, &@"else".base, space);
                } else {
                    return renderExpression(allocator, stream, tree, if_node.body, space);
                }
            }

            const src_has_newline = !tree.tokensOnSameLine(rparen, if_node.body.lastToken());

            if (src_has_newline) {
                const after_rparen_space = if (if_node.payload == null) Space.Newline else Space.Space;
                try renderToken(tree, stream, rparen, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.Newline);
                }

                if (if_node.@"else") |@"else"| {
                    const else_is_block = nodeIsBlock(@"else".body);

                    {
                        stream.pushIndent();
                        defer stream.popIndent();
                        try renderExpression(allocator, stream, tree, if_node.body, Space.Newline);
                    }

                    if (else_is_block) {
                        try renderToken(tree, stream, @"else".else_token, Space.Space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, payload, Space.Space);
                        }

                        return renderExpression(allocator, stream, tree, @"else".body, space);
                    } else {
                        const after_else_space = if (@"else".payload == null) Space.Newline else Space.Space;
                        try renderToken(tree, stream, @"else".else_token, after_else_space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, payload, Space.Newline);
                        }

                        stream.pushIndent();
                        defer stream.popIndent();
                        return renderExpression(allocator, stream, tree, @"else".body, space);
                    }
                } else {
                    stream.pushIndent();
                    defer stream.popIndent();
                    return renderExpression(allocator, stream, tree, if_node.body, space);
                }
            }

            // Single line if statement

            try renderToken(tree, stream, rparen, Space.Space); // )

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, payload, Space.Space);
            }

            if (if_node.@"else") |@"else"| {
                try renderExpression(allocator, stream, tree, if_node.body, Space.Space);
                try renderToken(tree, stream, @"else".else_token, Space.Space);

                if (@"else".payload) |payload| {
                    try renderExpression(allocator, stream, tree, payload, Space.Space);
                }

                return renderExpression(allocator, stream, tree, @"else".body, space);
            } else {
                return renderExpression(allocator, stream, tree, if_node.body, space);
            }
        },

        .Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

            try renderToken(tree, stream, asm_node.asm_token, Space.Space); // asm

            if (asm_node.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, Space.Space); // volatile
                try renderToken(tree, stream, tree.nextToken(volatile_token), Space.None); // (
            } else {
                try renderToken(tree, stream, tree.nextToken(asm_node.asm_token), Space.None); // (
            }

            if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                {
                    stream.pushIndent();
                    defer stream.popIndent();
                    try renderExpression(allocator, stream, tree, asm_node.template, Space.None);
                }
                return renderToken(tree, stream, asm_node.rparen, space);
            }

            contents: {
                stream.pushIndent();
                defer stream.popIndent();
                const indent_extra = 2;

                try renderExpression(allocator, stream, tree, asm_node.template, Space.Newline);

                const colon1 = tree.nextToken(asm_node.template.lastToken());
                const colon2 = if (asm_node.outputs.len == 0) blk: {
                    try renderToken(tree, stream, colon1, Space.Newline); // :
                    break :blk tree.nextToken(colon1);
                } else blk: {
                    try renderToken(tree, stream, colon1, Space.Space); // :

                    stream.pushIndentN(indent_extra);
                    defer stream.popIndent();
                    var it = asm_node.outputs.iterator(0);
                    while (true) {
                        const asm_output = it.next().?;
                        const node = &(asm_output.*).base;

                        if (it.peek()) |next_asm_output| {
                            try renderExpression(allocator, stream, tree, node, Space.None);
                            const next_node = &(next_asm_output.*).base;

                            const comma = tree.prevToken(next_asm_output.*.firstToken());
                            try renderToken(tree, stream, comma, Space.Newline); // ,
                            try renderExtraNewline(tree, stream, next_node);
                        } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                            try renderExpression(allocator, stream, tree, node, Space.Newline);
                            break :contents;
                        } else {
                            try renderExpression(allocator, stream, tree, node, Space.Newline);
                            const comma_or_colon = tree.nextToken(node.lastToken());
                            break :blk switch (tree.tokens.at(comma_or_colon).id) {
                                .Comma => tree.nextToken(comma_or_colon),
                                else => comma_or_colon,
                            };
                        }
                    }
                };

                const colon3 = if (asm_node.inputs.len == 0) blk: {
                    try renderToken(tree, stream, colon2, Space.Newline); // :
                    break :blk tree.nextToken(colon2);
                } else blk: {
                    try renderToken(tree, stream, colon2, Space.Space); // :

                    stream.pushIndentN(indent_extra);
                    defer stream.popIndent();

                    var it = asm_node.inputs.iterator(0);
                    while (true) {
                        const asm_input = it.next().?;
                        const node = &(asm_input.*).base;

                        if (it.peek()) |next_asm_input| {
                            try renderExpression(allocator, stream, tree, node, Space.None);
                            const next_node = &(next_asm_input.*).base;

                            const comma = tree.prevToken(next_asm_input.*.firstToken());
                            try renderToken(tree, stream, comma, Space.Newline); // ,
                            try renderExtraNewline(tree, stream, next_node);
                        } else if (asm_node.clobbers.len == 0) {
                            try renderExpression(allocator, stream, tree, node, Space.Newline);
                            break :contents;
                        } else {
                            try renderExpression(allocator, stream, tree, node, Space.Newline);
                            const comma_or_colon = tree.nextToken(node.lastToken());
                            break :blk switch (tree.tokens.at(comma_or_colon).id) {
                                .Comma => tree.nextToken(comma_or_colon),
                                else => comma_or_colon,
                            };
                        }
                    }
                };

                try renderToken(tree, stream, colon3, Space.Space); // :

                var it = asm_node.clobbers.iterator(0);
                while (true) {
                    const clobber_node = it.next().?.*;

                    if (it.peek() == null) {
                        try renderExpression(allocator, stream, tree, clobber_node, Space.Newline);
                        break :contents;
                    } else {
                        try renderExpression(allocator, stream, tree, clobber_node, Space.None);
                        const comma = tree.nextToken(clobber_node.lastToken());
                        try renderToken(tree, stream, comma, Space.Space); // ,
                    }
                }
            }
            return renderToken(tree, stream, asm_node.rparen, space);
        },

        .AsmInput => {
            const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

            try stream.outStream().writeAll("[");
            try renderExpression(allocator, stream, tree, asm_input.symbolic_name, Space.None);
            try stream.outStream().writeAll("] ");
            try renderExpression(allocator, stream, tree, asm_input.constraint, Space.None);
            try stream.outStream().writeAll(" (");
            try renderExpression(allocator, stream, tree, asm_input.expr, Space.None);
            return renderToken(tree, stream, asm_input.lastToken(), space); // )
        },

        .AsmOutput => {
            const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

            try stream.outStream().writeAll("[");
            try renderExpression(allocator, stream, tree, asm_output.symbolic_name, Space.None);
            try stream.outStream().writeAll("] ");
            try renderExpression(allocator, stream, tree, asm_output.constraint, Space.None);
            try stream.outStream().writeAll(" (");

            switch (asm_output.kind) {
                ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                    try renderExpression(allocator, stream, tree, &variable_name.base, Space.None);
                },
                ast.Node.AsmOutput.Kind.Return => |return_type| {
                    try stream.outStream().writeAll("-> ");
                    try renderExpression(allocator, stream, tree, return_type, Space.None);
                },
            }

            return renderToken(tree, stream, asm_output.lastToken(), space); // )
        },

        .EnumLiteral => {
            const enum_literal = @fieldParentPtr(ast.Node.EnumLiteral, "base", base);

            try renderToken(tree, stream, enum_literal.dot, Space.None); // .
            return renderToken(tree, stream, enum_literal.name, space); // name
        },

        .ContainerField,
        .Root,
        .VarDecl,
        .Use,
        .TestDecl,
        .ParamDecl,
        => unreachable,
    }
}

fn renderVarDecl(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    var_decl: *ast.Node.VarDecl,
) (@TypeOf(stream.*).Error || Error)!void {
    if (var_decl.visib_token) |visib_token| {
        try renderToken(tree, stream, visib_token, Space.Space); // pub
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, Space.Space); // extern

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(allocator, stream, tree, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, Space.Space); // comptime
    }

    if (var_decl.thread_local_token) |thread_local_token| {
        try renderToken(tree, stream, thread_local_token, Space.Space); // threadlocal
    }
    try renderToken(tree, stream, var_decl.mut_token, Space.Space); // var

    const name_space = if (var_decl.type_node == null and (var_decl.align_node != null or
        var_decl.section_node != null or var_decl.init_node != null)) Space.Space else Space.None;
    try renderToken(tree, stream, var_decl.name_token, name_space);

    if (var_decl.type_node) |type_node| {
        try renderToken(tree, stream, tree.nextToken(var_decl.name_token), Space.Space);
        const s = if (var_decl.align_node != null or
            var_decl.section_node != null or
            var_decl.init_node != null) Space.Space else Space.None;
        try renderExpression(allocator, stream, tree, type_node, s);
    }

    if (var_decl.align_node) |align_node| {
        const lparen = tree.prevToken(align_node.firstToken());
        const align_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(align_node.lastToken());
        try renderToken(tree, stream, align_kw, Space.None); // align
        try renderToken(tree, stream, lparen, Space.None); // (
        try renderExpression(allocator, stream, tree, align_node, Space.None);
        const s = if (var_decl.section_node != null or var_decl.init_node != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, s); // )
    }

    if (var_decl.section_node) |section_node| {
        const lparen = tree.prevToken(section_node.firstToken());
        const section_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(section_node.lastToken());
        try renderToken(tree, stream, section_kw, Space.None); // linksection
        try renderToken(tree, stream, lparen, Space.None); // (
        try renderExpression(allocator, stream, tree, section_node, Space.None);
        const s = if (var_decl.init_node != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, s); // )
    }

    if (var_decl.init_node) |init_node| {
        const s = if (init_node.id == .MultilineStringLiteral) Space.None else Space.Space;
        try renderToken(tree, stream, var_decl.eq_token.?, s); // =
        stream.pushIndentOneShot();
        try renderExpression(allocator, stream, tree, init_node, Space.None);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, Space.Newline);
}

fn renderParamDecl(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    base: *ast.Node,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", base);

    try renderDocComments(tree, stream, param_decl);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(tree, stream, noalias_token, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(tree, stream, name_token, Space.None);
        try renderToken(tree, stream, tree.nextToken(name_token), Space.Space); // :
    }
    if (param_decl.var_args_token) |var_args_token| {
        try renderToken(tree, stream, var_args_token, space);
    } else {
        try renderExpression(allocator, stream, tree, param_decl.type_node, space);
    }
}

fn renderStatement(
    allocator: *mem.Allocator,
    stream: var,
    tree: *ast.Tree,
    base: *ast.Node,
) (@TypeOf(stream.*).Error || Error)!void {
    switch (base.id) {
        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, var_decl);
        },
        else => {
            if (base.requireSemiColon()) {
                try renderExpression(allocator, stream, tree, base, Space.None);

                const semicolon_index = tree.nextToken(base.lastToken());
                assert(tree.tokens.at(semicolon_index).id == .Semicolon);
                try renderToken(tree, stream, semicolon_index, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, base, Space.Newline);
            }
        },
    }
}

const Space = enum {
    None,
    Newline,
    Comma,
    Space,
    SpaceOrOutdent,
    NoNewline,
    NoComment,
    BlockStart,
};

fn renderTokenOffset(
    tree: *ast.Tree,
    stream: var,
    token_index: ast.TokenIndex,
    space: Space,
    token_skip_bytes: usize,
) (@TypeOf(stream.*).Error || Error)!void {
    if (space == Space.BlockStart) {
        // If placing the lbrace on the current line would cause an uggly gap then put the lbrace on the next line
        const new_space = if (stream.isLineOverIndented()) Space.Newline else Space.Space;
        return renderToken(tree, stream, token_index, new_space);
    }

    var token = tree.tokens.at(token_index);
    try stream.outStream().writeAll(mem.trimRight(u8, tree.tokenSlicePtr(token)[token_skip_bytes..], " "));

    if (space == Space.NoComment)
        return;

    var next_token = tree.tokens.at(token_index + 1);

    if (space == Space.Comma) switch (next_token.id) {
        .Comma => return renderToken(tree, stream, token_index + 1, Space.Newline),
        .LineComment => {
            try stream.outStream().writeAll(", ");
            return renderToken(tree, stream, token_index + 1, Space.Newline);
        },
        else => {
            if (token_index + 2 < tree.tokens.len and tree.tokens.at(token_index + 2).id == .MultilineStringLiteralLine) {
                try stream.outStream().writeAll(",");
                return;
            } else {
                try stream.outStream().writeAll(",");
                try stream.insertNewline();
                return;
            }
        },
    };

    // Skip over same line doc comments
    var offset: usize = 1;
    if (next_token.id == .DocComment) {
        const loc = tree.tokenLocationPtr(token.end, next_token);
        if (loc.line == 0) {
            offset += 1;
            next_token = tree.tokens.at(token_index + offset);
        }
    }

    if (next_token.id != .LineComment) blk: {
        switch (space) {
            Space.None, Space.NoNewline => return,
            Space.Newline => {
                if (next_token.id == .MultilineStringLiteralLine) {
                    return;
                } else {
                    try stream.insertNewline();
                    return;
                }
            },
            Space.Space, Space.SpaceOrOutdent => {
                if (next_token.id == .MultilineStringLiteralLine)
                    return;
                try stream.outStream().writeByte(' ');
                return;
            },
            Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
        }
    }

    while (true) {
        const comment_is_empty = mem.trimRight(u8, tree.tokenSlicePtr(next_token), " ").len == 2;
        if (comment_is_empty) {
            switch (space) {
                Space.Newline => {
                    offset += 1;
                    token = next_token;
                    next_token = tree.tokens.at(token_index + offset);
                    if (next_token.id != .LineComment) {
                        try stream.insertNewline();
                        return;
                    }
                },
                else => break,
            }
        } else {
            break;
        }
    }

    var loc = tree.tokenLocationPtr(token.end, next_token);
    if (loc.line == 0) {
        try stream.outStream().print(" {}", .{mem.trimRight(u8, tree.tokenSlicePtr(next_token), " ")});
        offset = 2;
        token = next_token;
        next_token = tree.tokens.at(token_index + offset);
        if (next_token.id != .LineComment) {
            switch (space) {
                Space.None, Space.Space => {
                    try stream.insertNewline();
                },
                Space.SpaceOrOutdent => {
                    try stream.insertNewline();
                },
                Space.Newline => {
                    if (next_token.id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.insertNewline();
                        return;
                    }
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationPtr(token.end, next_token);
    }

    while (true) {
        assert(loc.line != 0);
        try stream.insertNewline();
        if (loc.line != 1) try stream.insertNewline();
        try stream.outStream().writeAll(mem.trimRight(u8, tree.tokenSlicePtr(next_token), " "));

        offset += 1;
        token = next_token;
        next_token = tree.tokens.at(token_index + offset);
        if (next_token.id != .LineComment) {
            switch (space) {
                Space.Newline => {
                    if (next_token.id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.insertNewline();
                        return;
                    }
                },
                Space.None, Space.Space => {
                    try stream.insertNewline();

                    const after_comment_token = tree.tokens.at(token_index + offset);
                },
                Space.SpaceOrOutdent => {
                    try stream.insertNewline();
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationPtr(token.end, next_token);
    }
}

fn renderToken(
    tree: *ast.Tree,
    stream: var,
    token_index: ast.TokenIndex,
    space: Space,
) (@TypeOf(stream.*).Error || Error)!void {
    return renderTokenOffset(tree, stream, token_index, space, 0);
}

fn renderDocComments(
    tree: *ast.Tree,
    stream: var,
    node: var,
) (@TypeOf(stream.*).Error || Error)!void {
    const comment = node.doc_comments orelse return;
    var it = comment.lines.iterator(0);
    const first_token = node.firstToken();
    while (it.next()) |line_token_index| {
        if (line_token_index.* < first_token) {
            try renderToken(tree, stream, line_token_index.*, Space.Newline);
        } else {
            try renderToken(tree, stream, line_token_index.*, Space.NoComment);
            try stream.insertNewline();
        }
    }
}

fn nodeIsBlock(base: *const ast.Node) bool {
    return switch (base.id) {
        .Block,
        .If,
        .For,
        .While,
        .Switch,
        => true,
        else => false,
    };
}

fn nodeCausesSliceOpSpace(base: *ast.Node) bool {
    const infix_op = base.cast(ast.Node.InfixOp) orelse return false;
    return switch (infix_op.op) {
        ast.Node.InfixOp.Op.Period => false,
        else => true,
    };
}

fn copyFixingWhitespace(stream: var, slice: []const u8) @TypeOf(stream.*).Error!void {
    for (slice) |byte| switch (byte) {
        '\t' => try stream.outStream().writeAll("    "),
        '\r' => {},
        else => try stream.outStream().writeByte(byte),
    };
}
