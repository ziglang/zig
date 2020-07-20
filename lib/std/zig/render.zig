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
pub fn render(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree) (@TypeOf(stream).Error || Error)!bool {
    // cannot render an invalid tree
    std.debug.assert(tree.errors.len == 0);

    // make a passthrough stream that checks whether something changed
    const MyStream = struct {
        const MyStream = @This();
        const StreamError = @TypeOf(stream).Error;

        child_stream: @TypeOf(stream),
        anything_changed: bool,
        source_index: usize,
        source: []const u8,

        fn write(self: *MyStream, bytes: []const u8) StreamError!usize {
            if (!self.anything_changed) {
                const end = self.source_index + bytes.len;
                if (end > self.source.len) {
                    self.anything_changed = true;
                } else {
                    const src_slice = self.source[self.source_index..end];
                    self.source_index += bytes.len;
                    if (!mem.eql(u8, bytes, src_slice)) {
                        self.anything_changed = true;
                    }
                }
            }

            return self.child_stream.write(bytes);
        }
    };
    var my_stream = MyStream{
        .child_stream = stream,
        .anything_changed = false,
        .source_index = 0,
        .source = tree.source,
    };
    const my_stream_stream: std.io.Writer(*MyStream, MyStream.StreamError, MyStream.write) = .{
        .context = &my_stream,
    };

    try renderRoot(allocator, my_stream_stream, tree);

    if (my_stream.source_index != my_stream.source.len) {
        my_stream.anything_changed = true;
    }

    return my_stream.anything_changed;
}

fn renderRoot(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
) (@TypeOf(stream).Error || Error)!void {
    // render all the line comments at the beginning of the file
    for (tree.token_ids) |token_id, i| {
        if (token_id != .LineComment) break;
        const token_loc = tree.token_locs[i];
        try stream.print("{}\n", .{mem.trimRight(u8, tree.tokenSliceLoc(token_loc), " ")});
        const next_token = tree.token_locs[i + 1];
        const loc = tree.tokenLocationLoc(token_loc.end, next_token);
        if (loc.line >= 2) {
            try stream.writeByte('\n');
        }
    }

    var start_col: usize = 0;
    var decl_i: ast.NodeIndex = 0;
    const root_decls = tree.root_node.decls();

    if (root_decls.len == 0) return;
    while (true) {
        var decl = root_decls[decl_i];

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
            const token_id = tree.token_ids[token_index];
            switch (token_id) {
                .LineComment => {},
                .DocComment => {
                    copy_start_token_index = token_index;
                    continue;
                },
                else => break,
            }

            const token_loc = tree.token_locs[token_index];
            if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: off")) {
                if (!found_fmt_directive) {
                    fmt_active = false;
                    found_fmt_directive = true;
                }
            } else if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: on")) {
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
                decl_i += 1;
                if (decl_i >= root_decls.len) {
                    // If there's no next reformatted `decl`, just copy the
                    // remaining input tokens and bail out.
                    const start = tree.token_locs[copy_start_token_index].start;
                    try copyFixingWhitespace(stream, tree.source[start..]);
                    return;
                }
                decl = root_decls[decl_i];
                var decl_first_token_index = decl.firstToken();

                while (token_index < decl_first_token_index) : (token_index += 1) {
                    const token_id = tree.token_ids[token_index];
                    switch (token_id) {
                        .LineComment => {},
                        .Eof => unreachable,
                        else => continue,
                    }
                    const token_loc = tree.token_locs[token_index];
                    if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: on")) {
                        fmt_active = true;
                    } else if (mem.eql(u8, mem.trim(u8, tree.tokenSliceLoc(token_loc)[2..], " "), "zig fmt: off")) {
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
                const token_id = tree.token_ids[token_index];
                switch (token_id) {
                    .LineComment => {},
                    .DocComment => {
                        copy_end_token_index = token_index;
                        continue;
                    },
                    else => break,
                }
            }

            const start = tree.token_locs[copy_start_token_index].start;
            const end = tree.token_locs[copy_end_token_index].start;
            try copyFixingWhitespace(stream, tree.source[start..end]);
        }

        try renderTopLevelDecl(allocator, stream, tree, 0, &start_col, decl);
        decl_i += 1;
        if (decl_i >= root_decls.len) return;
        try renderExtraNewline(tree, stream, &start_col, root_decls[decl_i]);
    }
}

fn renderExtraNewline(tree: *ast.Tree, stream: anytype, start_col: *usize, node: *ast.Node) @TypeOf(stream).Error!void {
    return renderExtraNewlineToken(tree, stream, start_col, node.firstToken());
}

fn renderExtraNewlineToken(
    tree: *ast.Tree,
    stream: anytype,
    start_col: *usize,
    first_token: ast.TokenIndex,
) @TypeOf(stream).Error!void {
    var prev_token = first_token;
    if (prev_token == 0) return;
    var newline_threshold: usize = 2;
    while (tree.token_ids[prev_token - 1] == .DocComment) {
        if (tree.tokenLocation(tree.token_locs[prev_token - 1].end, prev_token).line == 1) {
            newline_threshold += 1;
        }
        prev_token -= 1;
    }
    const prev_token_end = tree.token_locs[prev_token - 1].end;
    const loc = tree.tokenLocation(prev_token_end, first_token);
    if (loc.line >= newline_threshold) {
        try stream.writeByte('\n');
        start_col.* = 0;
    }
}

fn renderTopLevelDecl(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree, indent: usize, start_col: *usize, decl: *ast.Node) (@TypeOf(stream).Error || Error)!void {
    try renderContainerDecl(allocator, stream, tree, indent, start_col, decl, .Newline);
}

fn renderContainerDecl(allocator: *mem.Allocator, stream: anytype, tree: *ast.Tree, indent: usize, start_col: *usize, decl: *ast.Node, space: Space) (@TypeOf(stream).Error || Error)!void {
    switch (decl.tag) {
        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderDocComments(tree, stream, fn_proto, fn_proto.getTrailer("doc_comments"), indent, start_col);

            if (fn_proto.getTrailer("body_node")) |body_node| {
                try renderExpression(allocator, stream, tree, indent, start_col, decl, .Space);
                try renderExpression(allocator, stream, tree, indent, start_col, body_node, space);
            } else {
                try renderExpression(allocator, stream, tree, indent, start_col, decl, .None);
                try renderToken(tree, stream, tree.nextToken(decl.lastToken()), indent, start_col, space);
            }
        },

        .Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try renderToken(tree, stream, visib_token, indent, start_col, .Space); // pub
            }
            try renderToken(tree, stream, use_decl.use_token, indent, start_col, .Space); // usingnamespace
            try renderExpression(allocator, stream, tree, indent, start_col, use_decl.expr, .None);
            try renderToken(tree, stream, use_decl.semicolon_token, indent, start_col, space); // ;
        },

        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderDocComments(tree, stream, var_decl, var_decl.getTrailer("doc_comments"), indent, start_col);
            try renderVarDecl(allocator, stream, tree, indent, start_col, var_decl);
        },

        .TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderDocComments(tree, stream, test_decl, test_decl.doc_comments, indent, start_col);
            try renderToken(tree, stream, test_decl.test_token, indent, start_col, .Space);
            try renderExpression(allocator, stream, tree, indent, start_col, test_decl.name, .Space);
            try renderExpression(allocator, stream, tree, indent, start_col, test_decl.body_node, space);
        },

        .ContainerField => {
            const field = @fieldParentPtr(ast.Node.ContainerField, "base", decl);

            try renderDocComments(tree, stream, field, field.doc_comments, indent, start_col);
            if (field.comptime_token) |t| {
                try renderToken(tree, stream, t, indent, start_col, .Space); // comptime
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.nextToken(field.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            // The trailing comma is emitted at the end, but if it's not present
            // we still have to respect the specified `space` parameter
            const last_token_space: Space = if (src_has_trailing_comma) .None else space;

            if (field.type_expr == null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, indent, start_col, last_token_space); // name
            } else if (field.type_expr != null and field.value_expr == null) {
                try renderToken(tree, stream, field.name_token, indent, start_col, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), indent, start_col, .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, indent, start_col, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, indent, start_col, .None); // align
                    try renderToken(tree, stream, lparen_token, indent, start_col, .None); // (
                    try renderExpression(allocator, stream, tree, indent, start_col, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, indent, start_col, last_token_space); // )
                } else {
                    try renderExpression(allocator, stream, tree, indent, start_col, field.type_expr.?, last_token_space); // type
                }
            } else if (field.type_expr == null and field.value_expr != null) {
                try renderToken(tree, stream, field.name_token, indent, start_col, .Space); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), indent, start_col, .Space); // =
                try renderExpression(allocator, stream, tree, indent, start_col, field.value_expr.?, last_token_space); // value
            } else {
                try renderToken(tree, stream, field.name_token, indent, start_col, .None); // name
                try renderToken(tree, stream, tree.nextToken(field.name_token), indent, start_col, .Space); // :

                if (field.align_expr) |align_value_expr| {
                    try renderExpression(allocator, stream, tree, indent, start_col, field.type_expr.?, .Space); // type
                    const lparen_token = tree.prevToken(align_value_expr.firstToken());
                    const align_kw = tree.prevToken(lparen_token);
                    const rparen_token = tree.nextToken(align_value_expr.lastToken());
                    try renderToken(tree, stream, align_kw, indent, start_col, .None); // align
                    try renderToken(tree, stream, lparen_token, indent, start_col, .None); // (
                    try renderExpression(allocator, stream, tree, indent, start_col, align_value_expr, .None); // alignment
                    try renderToken(tree, stream, rparen_token, indent, start_col, .Space); // )
                } else {
                    try renderExpression(allocator, stream, tree, indent, start_col, field.type_expr.?, .Space); // type
                }
                try renderToken(tree, stream, tree.prevToken(field.value_expr.?.firstToken()), indent, start_col, .Space); // =
                try renderExpression(allocator, stream, tree, indent, start_col, field.value_expr.?, last_token_space); // value
            }

            if (src_has_trailing_comma) {
                const comma = tree.nextToken(field.lastToken());
                try renderToken(tree, stream, comma, indent, start_col, space);
            }
        },

        .Comptime => {
            assert(!decl.requireSemiColon());
            try renderExpression(allocator, stream, tree, indent, start_col, decl, space);
        },

        .DocComment => {
            const comment = @fieldParentPtr(ast.Node.DocComment, "base", decl);
            const kind = tree.token_ids[comment.first_line];
            try renderToken(tree, stream, comment.first_line, indent, start_col, .Newline);
            var tok_i = comment.first_line + 1;
            while (true) : (tok_i += 1) {
                const tok_id = tree.token_ids[tok_i];
                if (tok_id == kind) {
                    try stream.writeByteNTimes(' ', indent);
                    try renderToken(tree, stream, tok_i, indent, start_col, .Newline);
                } else if (tok_id == .LineComment) {
                    continue;
                } else {
                    break;
                }
            }
        },
        else => unreachable,
    }
}

fn renderExpression(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    base: *ast.Node,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    switch (base.tag) {
        .Identifier => {
            const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
            return renderToken(tree, stream, identifier.token, indent, start_col, space);
        },
        .Block => {
            const block = @fieldParentPtr(ast.Node.Block, "base", base);

            if (block.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None);
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space);
            }

            if (block.statements_len == 0) {
                try renderToken(tree, stream, block.lbrace, indent + indent_delta, start_col, Space.None);
                return renderToken(tree, stream, block.rbrace, indent, start_col, space);
            } else {
                const block_indent = indent + indent_delta;
                try renderToken(tree, stream, block.lbrace, block_indent, start_col, Space.Newline);

                const block_statements = block.statements();
                for (block_statements) |statement, i| {
                    try stream.writeByteNTimes(' ', block_indent);
                    try renderStatement(allocator, stream, tree, block_indent, start_col, statement);

                    if (i + 1 < block_statements.len) {
                        try renderExtraNewline(tree, stream, start_col, block_statements[i + 1]);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                return renderToken(tree, stream, block.rbrace, indent, start_col, space);
            }
        },
        .Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);

            try renderToken(tree, stream, defer_node.defer_token, indent, start_col, Space.Space);
            if (defer_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }
            return renderExpression(allocator, stream, tree, indent, start_col, defer_node.expr, space);
        },
        .Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);

            try renderToken(tree, stream, comptime_node.comptime_token, indent, start_col, Space.Space);
            return renderExpression(allocator, stream, tree, indent, start_col, comptime_node.expr, space);
        },
        .Nosuspend => {
            const nosuspend_node = @fieldParentPtr(ast.Node.Nosuspend, "base", base);
            if (mem.eql(u8, tree.tokenSlice(nosuspend_node.nosuspend_token), "noasync")) {
                // TODO: remove this
                try stream.writeAll("nosuspend ");
            } else {
                try renderToken(tree, stream, nosuspend_node.nosuspend_token, indent, start_col, Space.Space);
            }
            return renderExpression(allocator, stream, tree, indent, start_col, nosuspend_node.expr, space);
        },

        .Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);

            if (suspend_node.body) |body| {
                try renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, Space.Space);
                return renderExpression(allocator, stream, tree, indent, start_col, body, space);
            } else {
                return renderToken(tree, stream, suspend_node.suspend_token, indent, start_col, space);
            }
        },

        .Catch => {
            const infix_op_node = @fieldParentPtr(ast.Node.Catch, "base", base);

            const op_space = Space.Space;
            try renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const loc = tree.tokenLocation(tree.token_locs[infix_op_node.op_token].end, tree.nextToken(infix_op_node.op_token));
                break :blk if (loc.line == 0) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, indent, start_col, after_op_space);
            if (after_op_space == Space.Newline and
                tree.token_ids[tree.nextToken(infix_op_node.op_token)] != .MultilineStringLiteralLine)
            {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                start_col.* = indent + indent_delta;
            }

            if (infix_op_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }

            return renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.rhs, space);
        },

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
        .Period,
        .Range,
        .Sub,
        .SubWrap,
        .OrElse,
        => {
            const infix_op_node = @fieldParentPtr(ast.Node.SimpleInfixOp, "base", base);

            const op_space = switch (base.tag) {
                .Period, .ErrorUnion, .Range => Space.None,
                else => Space.Space,
            };
            try renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.lhs, op_space);

            const after_op_space = blk: {
                const loc = tree.tokenLocation(tree.token_locs[infix_op_node.op_token].end, tree.nextToken(infix_op_node.op_token));
                break :blk if (loc.line == 0) op_space else Space.Newline;
            };

            try renderToken(tree, stream, infix_op_node.op_token, indent, start_col, after_op_space);
            if (after_op_space == Space.Newline and
                tree.token_ids[tree.nextToken(infix_op_node.op_token)] != .MultilineStringLiteralLine)
            {
                try stream.writeByteNTimes(' ', indent + indent_delta);
                start_col.* = indent + indent_delta;
            }

            return renderExpression(allocator, stream, tree, indent, start_col, infix_op_node.rhs, space);
        },

        .BitNot,
        .BoolNot,
        .Negation,
        .NegationWrap,
        .OptionalType,
        .AddressOf,
        => {
            const casted_node = @fieldParentPtr(ast.Node.SimplePrefixOp, "base", base);
            try renderToken(tree, stream, casted_node.op_token, indent, start_col, Space.None);
            return renderExpression(allocator, stream, tree, indent, start_col, casted_node.rhs, space);
        },

        .Try,
        .Resume,
        .Await,
        => {
            const casted_node = @fieldParentPtr(ast.Node.SimplePrefixOp, "base", base);
            try renderToken(tree, stream, casted_node.op_token, indent, start_col, Space.Space);
            return renderExpression(allocator, stream, tree, indent, start_col, casted_node.rhs, space);
        },

        .ArrayType => {
            const array_type = @fieldParentPtr(ast.Node.ArrayType, "base", base);
            return renderArrayType(
                allocator,
                stream,
                tree,
                indent,
                start_col,
                array_type.op_token,
                array_type.rhs,
                array_type.len_expr,
                null,
                space,
            );
        },
        .ArrayTypeSentinel => {
            const array_type = @fieldParentPtr(ast.Node.ArrayTypeSentinel, "base", base);
            return renderArrayType(
                allocator,
                stream,
                tree,
                indent,
                start_col,
                array_type.op_token,
                array_type.rhs,
                array_type.len_expr,
                array_type.sentinel,
                space,
            );
        },

        .PtrType => {
            const ptr_type = @fieldParentPtr(ast.Node.PtrType, "base", base);
            const op_tok_id = tree.token_ids[ptr_type.op_token];
            switch (op_tok_id) {
                .Asterisk, .AsteriskAsterisk => try stream.writeByte('*'),
                .LBracket => if (tree.token_ids[ptr_type.op_token + 2] == .Identifier)
                    try stream.writeAll("[*c")
                else
                    try stream.writeAll("[*"),
                else => unreachable,
            }
            if (ptr_type.ptr_info.sentinel) |sentinel| {
                const colon_token = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon_token, indent, start_col, Space.None); // :
                const sentinel_space = switch (op_tok_id) {
                    .LBracket => Space.None,
                    else => Space.Space,
                };
                try renderExpression(allocator, stream, tree, indent, start_col, sentinel, sentinel_space);
            }
            switch (op_tok_id) {
                .Asterisk, .AsteriskAsterisk => {},
                .LBracket => try stream.writeByte(']'),
                else => unreachable,
            }
            if (ptr_type.ptr_info.allowzero_token) |allowzero_token| {
                try renderToken(tree, stream, allowzero_token, indent, start_col, Space.Space); // allowzero
            }
            if (ptr_type.ptr_info.align_info) |align_info| {
                const lparen_token = tree.prevToken(align_info.node.firstToken());
                const align_token = tree.prevToken(lparen_token);

                try renderToken(tree, stream, align_token, indent, start_col, Space.None); // align
                try renderToken(tree, stream, lparen_token, indent, start_col, Space.None); // (

                try renderExpression(allocator, stream, tree, indent, start_col, align_info.node, Space.None);

                if (align_info.bit_range) |bit_range| {
                    const colon1 = tree.prevToken(bit_range.start.firstToken());
                    const colon2 = tree.prevToken(bit_range.end.firstToken());

                    try renderToken(tree, stream, colon1, indent, start_col, Space.None); // :
                    try renderExpression(allocator, stream, tree, indent, start_col, bit_range.start, Space.None);
                    try renderToken(tree, stream, colon2, indent, start_col, Space.None); // :
                    try renderExpression(allocator, stream, tree, indent, start_col, bit_range.end, Space.None);

                    const rparen_token = tree.nextToken(bit_range.end.lastToken());
                    try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                } else {
                    const rparen_token = tree.nextToken(align_info.node.lastToken());
                    try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                }
            }
            if (ptr_type.ptr_info.const_token) |const_token| {
                try renderToken(tree, stream, const_token, indent, start_col, Space.Space); // const
            }
            if (ptr_type.ptr_info.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space); // volatile
            }
            return renderExpression(allocator, stream, tree, indent, start_col, ptr_type.rhs, space);
        },

        .SliceType => {
            const slice_type = @fieldParentPtr(ast.Node.SliceType, "base", base);
            try renderToken(tree, stream, slice_type.op_token, indent, start_col, Space.None); // [
            if (slice_type.ptr_info.sentinel) |sentinel| {
                const colon_token = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon_token, indent, start_col, Space.None); // :
                try renderExpression(allocator, stream, tree, indent, start_col, sentinel, Space.None);
                try renderToken(tree, stream, tree.nextToken(sentinel.lastToken()), indent, start_col, Space.None); // ]
            } else {
                try renderToken(tree, stream, tree.nextToken(slice_type.op_token), indent, start_col, Space.None); // ]
            }

            if (slice_type.ptr_info.allowzero_token) |allowzero_token| {
                try renderToken(tree, stream, allowzero_token, indent, start_col, Space.Space); // allowzero
            }
            if (slice_type.ptr_info.align_info) |align_info| {
                const lparen_token = tree.prevToken(align_info.node.firstToken());
                const align_token = tree.prevToken(lparen_token);

                try renderToken(tree, stream, align_token, indent, start_col, Space.None); // align
                try renderToken(tree, stream, lparen_token, indent, start_col, Space.None); // (

                try renderExpression(allocator, stream, tree, indent, start_col, align_info.node, Space.None);

                if (align_info.bit_range) |bit_range| {
                    const colon1 = tree.prevToken(bit_range.start.firstToken());
                    const colon2 = tree.prevToken(bit_range.end.firstToken());

                    try renderToken(tree, stream, colon1, indent, start_col, Space.None); // :
                    try renderExpression(allocator, stream, tree, indent, start_col, bit_range.start, Space.None);
                    try renderToken(tree, stream, colon2, indent, start_col, Space.None); // :
                    try renderExpression(allocator, stream, tree, indent, start_col, bit_range.end, Space.None);

                    const rparen_token = tree.nextToken(bit_range.end.lastToken());
                    try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                } else {
                    const rparen_token = tree.nextToken(align_info.node.lastToken());
                    try renderToken(tree, stream, rparen_token, indent, start_col, Space.Space); // )
                }
            }
            if (slice_type.ptr_info.const_token) |const_token| {
                try renderToken(tree, stream, const_token, indent, start_col, Space.Space);
            }
            if (slice_type.ptr_info.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space);
            }
            return renderExpression(allocator, stream, tree, indent, start_col, slice_type.rhs, space);
        },

        .ArrayInitializer, .ArrayInitializerDot => {
            var rtoken: ast.TokenIndex = undefined;
            var exprs: []*ast.Node = undefined;
            const lhs: union(enum) { dot: ast.TokenIndex, node: *ast.Node } = switch (base.tag) {
                .ArrayInitializerDot => blk: {
                    const casted = @fieldParentPtr(ast.Node.ArrayInitializerDot, "base", base);
                    rtoken = casted.rtoken;
                    exprs = casted.list();
                    break :blk .{ .dot = casted.dot };
                },
                .ArrayInitializer => blk: {
                    const casted = @fieldParentPtr(ast.Node.ArrayInitializer, "base", base);
                    rtoken = casted.rtoken;
                    exprs = casted.list();
                    break :blk .{ .node = casted.lhs };
                },
                else => unreachable,
            };

            const lbrace = switch (lhs) {
                .dot => |dot| tree.nextToken(dot),
                .node => |node| tree.nextToken(node.lastToken()),
            };

            if (exprs.len == 0) {
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }

            if (exprs.len == 1 and tree.token_ids[exprs[0].lastToken() + 1] == .RBrace) {
                const expr = exprs[0];
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.None);
                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }

            switch (lhs) {
                .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
            }

            // scan to find row size
            const maybe_row_size: ?usize = blk: {
                var count: usize = 1;
                for (exprs) |expr, i| {
                    if (i + 1 < exprs.len) {
                        const expr_last_token = expr.lastToken() + 1;
                        const loc = tree.tokenLocation(tree.token_locs[expr_last_token].end, exprs[i + 1].firstToken());
                        if (loc.line != 0) break :blk count;
                        count += 1;
                    } else {
                        const expr_last_token = expr.lastToken();
                        const loc = tree.tokenLocation(tree.token_locs[expr_last_token].end, rtoken);
                        if (loc.line == 0) {
                            // all on one line
                            const src_has_trailing_comma = trailblk: {
                                const maybe_comma = tree.prevToken(rtoken);
                                break :trailblk tree.token_ids[maybe_comma] == .Comma;
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
                unreachable;
            };

            if (maybe_row_size) |row_size| {
                // A place to store the width of each expression and its column's maximum
                var widths = try allocator.alloc(usize, exprs.len + row_size);
                defer allocator.free(widths);
                mem.set(usize, widths, 0);

                var expr_widths = widths[0 .. widths.len - row_size];
                var column_widths = widths[widths.len - row_size ..];

                // Null stream for counting the printed length of each expression
                var counting_stream = std.io.countingOutStream(std.io.null_out_stream);

                for (exprs) |expr, i| {
                    counting_stream.bytes_written = 0;
                    var dummy_col: usize = 0;
                    try renderExpression(allocator, counting_stream.outStream(), tree, indent, &dummy_col, expr, Space.None);
                    const width = @intCast(usize, counting_stream.bytes_written);
                    const col = i % row_size;
                    column_widths[col] = std.math.max(column_widths[col], width);
                    expr_widths[i] = width;
                }

                var new_indent = indent + indent_delta;

                if (tree.token_ids[tree.nextToken(lbrace)] != .MultilineStringLiteralLine) {
                    try renderToken(tree, stream, lbrace, new_indent, start_col, Space.Newline);
                    try stream.writeByteNTimes(' ', new_indent);
                } else {
                    new_indent -= indent_delta;
                    try renderToken(tree, stream, lbrace, new_indent, start_col, Space.None);
                }

                var col: usize = 1;
                for (exprs) |expr, i| {
                    if (i + 1 < exprs.len) {
                        const next_expr = exprs[i + 1];
                        try renderExpression(allocator, stream, tree, new_indent, start_col, expr, Space.None);

                        const comma = tree.nextToken(expr.lastToken());

                        if (col != row_size) {
                            try renderToken(tree, stream, comma, new_indent, start_col, Space.Space); // ,

                            const padding = column_widths[i % row_size] - expr_widths[i];
                            try stream.writeByteNTimes(' ', padding);

                            col += 1;
                            continue;
                        }
                        col = 1;

                        if (tree.token_ids[tree.nextToken(comma)] != .MultilineStringLiteralLine) {
                            try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline); // ,
                        } else {
                            try renderToken(tree, stream, comma, new_indent, start_col, Space.None); // ,
                        }

                        try renderExtraNewline(tree, stream, start_col, next_expr);
                        if (next_expr.tag != .MultilineStringLiteral) {
                            try stream.writeByteNTimes(' ', new_indent);
                        }
                    } else {
                        try renderExpression(allocator, stream, tree, new_indent, start_col, expr, Space.Comma); // ,
                    }
                }
                if (exprs[exprs.len - 1].tag != .MultilineStringLiteral) {
                    try stream.writeByteNTimes(' ', indent);
                }
                return renderToken(tree, stream, rtoken, indent, start_col, space);
            } else {
                try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);
                for (exprs) |expr, i| {
                    if (i + 1 < exprs.len) {
                        try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.None);
                        const comma = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, comma, indent, start_col, Space.Space); // ,
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.Space);
                    }
                }

                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }
        },

        .StructInitializer, .StructInitializerDot => {
            var rtoken: ast.TokenIndex = undefined;
            var field_inits: []*ast.Node = undefined;
            const lhs: union(enum) { dot: ast.TokenIndex, node: *ast.Node } = switch (base.tag) {
                .StructInitializerDot => blk: {
                    const casted = @fieldParentPtr(ast.Node.StructInitializerDot, "base", base);
                    rtoken = casted.rtoken;
                    field_inits = casted.list();
                    break :blk .{ .dot = casted.dot };
                },
                .StructInitializer => blk: {
                    const casted = @fieldParentPtr(ast.Node.StructInitializer, "base", base);
                    rtoken = casted.rtoken;
                    field_inits = casted.list();
                    break :blk .{ .node = casted.lhs };
                },
                else => unreachable,
            };

            const lbrace = switch (lhs) {
                .dot => |dot| tree.nextToken(dot),
                .node => |node| tree.nextToken(node.lastToken()),
            };

            if (field_inits.len == 0) {
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, indent + indent_delta, start_col, Space.None);
                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(rtoken);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const src_same_line = blk: {
                const loc = tree.tokenLocation(tree.token_locs[lbrace].end, rtoken);
                break :blk loc.line == 0;
            };

            const expr_outputs_one_line = blk: {
                // render field expressions until a LF is found
                for (field_inits) |field_init| {
                    var find_stream = FindByteOutStream.init('\n');
                    var dummy_col: usize = 0;
                    try renderExpression(allocator, find_stream.outStream(), tree, 0, &dummy_col, field_init, Space.None);
                    if (find_stream.byte_found) break :blk false;
                }
                break :blk true;
            };

            if (field_inits.len == 1) blk: {
                const field_init = field_inits[0].cast(ast.Node.FieldInitializer).?;

                switch (field_init.expr.tag) {
                    .StructInitializer,
                    .StructInitializerDot,
                    => break :blk,

                    else => {},
                }

                // if the expression outputs to multiline, make this struct multiline
                if (!expr_outputs_one_line or src_has_trailing_comma) {
                    break :blk;
                }

                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);
                try renderExpression(allocator, stream, tree, indent, start_col, &field_init.base, Space.Space);
                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }

            if (!src_has_trailing_comma and src_same_line and expr_outputs_one_line) {
                // render all on one line, no trailing comma
                switch (lhs) {
                    .dot => |dot| try renderToken(tree, stream, dot, indent, start_col, Space.None),
                    .node => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None),
                }
                try renderToken(tree, stream, lbrace, indent, start_col, Space.Space);

                for (field_inits) |field_init, i| {
                    if (i + 1 < field_inits.len) {
                        try renderExpression(allocator, stream, tree, indent, start_col, field_init, Space.None);

                        const comma = tree.nextToken(field_init.lastToken());
                        try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, field_init, Space.Space);
                    }
                }

                return renderToken(tree, stream, rtoken, indent, start_col, space);
            }

            const new_indent = indent + indent_delta;

            switch (lhs) {
                .dot => |dot| try renderToken(tree, stream, dot, new_indent, start_col, Space.None),
                .node => |node| try renderExpression(allocator, stream, tree, new_indent, start_col, node, Space.None),
            }
            try renderToken(tree, stream, lbrace, new_indent, start_col, Space.Newline);

            for (field_inits) |field_init, i| {
                try stream.writeByteNTimes(' ', new_indent);

                if (i + 1 < field_inits.len) {
                    try renderExpression(allocator, stream, tree, new_indent, start_col, field_init, Space.None);

                    const comma = tree.nextToken(field_init.lastToken());
                    try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline);

                    try renderExtraNewline(tree, stream, start_col, field_inits[i + 1]);
                } else {
                    try renderExpression(allocator, stream, tree, new_indent, start_col, field_init, Space.Comma);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            return renderToken(tree, stream, rtoken, indent, start_col, space);
        },

        .Call => {
            const call = @fieldParentPtr(ast.Node.Call, "base", base);
            if (call.async_token) |async_token| {
                try renderToken(tree, stream, async_token, indent, start_col, Space.Space);
            }

            try renderExpression(allocator, stream, tree, indent, start_col, call.lhs, Space.None);

            const lparen = tree.nextToken(call.lhs.lastToken());

            if (call.params_len == 0) {
                try renderToken(tree, stream, lparen, indent, start_col, Space.None);
                return renderToken(tree, stream, call.rtoken, indent, start_col, space);
            }

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(call.rtoken);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (src_has_trailing_comma) {
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, lparen, new_indent, start_col, Space.Newline);

                const params = call.params();
                for (params) |param_node, i| {
                    const param_node_new_indent = if (param_node.tag == .MultilineStringLiteral) blk: {
                        break :blk indent;
                    } else blk: {
                        try stream.writeByteNTimes(' ', new_indent);
                        break :blk new_indent;
                    };

                    if (i + 1 < params.len) {
                        try renderExpression(allocator, stream, tree, param_node_new_indent, start_col, param_node, Space.None);
                        const comma = tree.nextToken(param_node.lastToken());
                        try renderToken(tree, stream, comma, new_indent, start_col, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, start_col, params[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, param_node_new_indent, start_col, param_node, Space.Comma);
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, call.rtoken, indent, start_col, space);
                    }
                }
            }

            try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

            const params = call.params();
            for (params) |param_node, i| {
                try renderExpression(allocator, stream, tree, indent, start_col, param_node, Space.None);

                if (i + 1 < params.len) {
                    const comma = tree.nextToken(param_node.lastToken());
                    try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                }
            }
            return renderToken(tree, stream, call.rtoken, indent, start_col, space);
        },

        .ArrayAccess => {
            const suffix_op = base.castTag(.ArrayAccess).?;

            const lbracket = tree.nextToken(suffix_op.lhs.lastToken());
            const rbracket = tree.nextToken(suffix_op.index_expr.lastToken());

            try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
            try renderToken(tree, stream, lbracket, indent, start_col, Space.None); // [

            const starts_with_comment = tree.token_ids[lbracket + 1] == .LineComment;
            const ends_with_comment = tree.token_ids[rbracket - 1] == .LineComment;
            const new_indent = if (ends_with_comment) indent + indent_delta else indent;
            const new_space = if (ends_with_comment) Space.Newline else Space.None;
            try renderExpression(allocator, stream, tree, new_indent, start_col, suffix_op.index_expr, new_space);
            if (starts_with_comment) {
                try stream.writeByte('\n');
            }
            if (ends_with_comment or starts_with_comment) {
                try stream.writeByteNTimes(' ', indent);
            }
            return renderToken(tree, stream, rbracket, indent, start_col, space); // ]
        },
        .Slice => {
            const suffix_op = base.castTag(.Slice).?;

            try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);

            const lbracket = tree.prevToken(suffix_op.start.firstToken());
            const dotdot = tree.nextToken(suffix_op.start.lastToken());

            const after_start_space_bool = nodeCausesSliceOpSpace(suffix_op.start) or
                (if (suffix_op.end) |end| nodeCausesSliceOpSpace(end) else false);
            const after_start_space = if (after_start_space_bool) Space.Space else Space.None;
            const after_op_space = if (suffix_op.end != null) after_start_space else Space.None;

            try renderToken(tree, stream, lbracket, indent, start_col, Space.None); // [
            try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.start, after_start_space);
            try renderToken(tree, stream, dotdot, indent, start_col, after_op_space); // ..
            if (suffix_op.end) |end| {
                const after_end_space = if (suffix_op.sentinel != null) Space.Space else Space.None;
                try renderExpression(allocator, stream, tree, indent, start_col, end, after_end_space);
            }
            if (suffix_op.sentinel) |sentinel| {
                const colon = tree.prevToken(sentinel.firstToken());
                try renderToken(tree, stream, colon, indent, start_col, Space.None); // :
                try renderExpression(allocator, stream, tree, indent, start_col, sentinel, Space.None);
            }
            return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space); // ]
        },
        .Deref => {
            const suffix_op = base.castTag(.Deref).?;

            try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
            return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space); // .*
        },
        .UnwrapOptional => {
            const suffix_op = base.castTag(.UnwrapOptional).?;

            try renderExpression(allocator, stream, tree, indent, start_col, suffix_op.lhs, Space.None);
            try renderToken(tree, stream, tree.prevToken(suffix_op.rtoken), indent, start_col, Space.None); // .
            return renderToken(tree, stream, suffix_op.rtoken, indent, start_col, space); // ?
        },

        .ControlFlowExpression => {
            const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

            switch (flow_expr.kind) {
                .Break => |maybe_label| {
                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space); // break
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space); // break
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, start_col, Space.None); // :

                        if (flow_expr.rhs == null) {
                            return renderExpression(allocator, stream, tree, indent, start_col, label, space); // label
                        }
                        try renderExpression(allocator, stream, tree, indent, start_col, label, Space.Space); // label
                    }
                },
                .Continue => |maybe_label| {
                    assert(flow_expr.rhs == null);

                    if (maybe_label == null and flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space); // continue
                    }

                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space); // continue
                    if (maybe_label) |label| {
                        const colon = tree.nextToken(flow_expr.ltoken);
                        try renderToken(tree, stream, colon, indent, start_col, Space.None); // :

                        return renderExpression(allocator, stream, tree, indent, start_col, label, space);
                    }
                },
                .Return => {
                    if (flow_expr.rhs == null) {
                        return renderToken(tree, stream, flow_expr.ltoken, indent, start_col, space);
                    }
                    try renderToken(tree, stream, flow_expr.ltoken, indent, start_col, Space.Space);
                },
            }

            return renderExpression(allocator, stream, tree, indent, start_col, flow_expr.rhs.?, space);
        },

        .Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            try renderExpression(allocator, stream, tree, indent, start_col, payload.error_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        .PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, start_col, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, start_col, payload.value_symbol, Space.None);
            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        .PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try renderToken(tree, stream, payload.lpipe, indent, start_col, Space.None);
            if (payload.ptr_token) |ptr_token| {
                try renderToken(tree, stream, ptr_token, indent, start_col, Space.None);
            }
            try renderExpression(allocator, stream, tree, indent, start_col, payload.value_symbol, Space.None);

            if (payload.index_symbol) |index_symbol| {
                const comma = tree.nextToken(payload.value_symbol.lastToken());

                try renderToken(tree, stream, comma, indent, start_col, Space.Space);
                try renderExpression(allocator, stream, tree, indent, start_col, index_symbol, Space.None);
            }

            return renderToken(tree, stream, payload.rpipe, indent, start_col, space);
        },

        .GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, indent, start_col, Space.None);
            try renderExpression(allocator, stream, tree, indent, start_col, grouped_expr.expr, Space.None);
            return renderToken(tree, stream, grouped_expr.rparen, indent, start_col, space);
        },

        .FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try renderToken(tree, stream, field_init.period_token, indent, start_col, Space.None); // .
            try renderToken(tree, stream, field_init.name_token, indent, start_col, Space.Space); // name
            try renderToken(tree, stream, tree.nextToken(field_init.name_token), indent, start_col, Space.Space); // =
            return renderExpression(allocator, stream, tree, indent, start_col, field_init.expr, space);
        },

        .IntegerLiteral => {
            const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
            return renderToken(tree, stream, integer_literal.token, indent, start_col, space);
        },
        .FloatLiteral => {
            const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
            return renderToken(tree, stream, float_literal.token, indent, start_col, space);
        },
        .StringLiteral => {
            const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
            return renderToken(tree, stream, string_literal.token, indent, start_col, space);
        },
        .CharLiteral => {
            const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, char_literal.token, indent, start_col, space);
        },
        .BoolLiteral => {
            const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            return renderToken(tree, stream, bool_literal.token, indent, start_col, space);
        },
        .NullLiteral => {
            const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
            return renderToken(tree, stream, null_literal.token, indent, start_col, space);
        },
        .Unreachable => {
            const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
            return renderToken(tree, stream, unreachable_node.token, indent, start_col, space);
        },
        .ErrorType => {
            const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
            return renderToken(tree, stream, error_type.token, indent, start_col, space);
        },
        .AnyType => {
            const any_type = @fieldParentPtr(ast.Node.AnyType, "base", base);
            if (mem.eql(u8, tree.tokenSlice(any_type.token), "var")) {
                // TODO remove in next release cycle
                try stream.writeAll("anytype");
                if (space == .Comma) try stream.writeAll(",\n");
                return;
            }
            return renderToken(tree, stream, any_type.token, indent, start_col, space);
        },
        .ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            if (container_decl.layout_token) |layout_token| {
                try renderToken(tree, stream, layout_token, indent, start_col, Space.Space);
            }

            switch (container_decl.init_arg_expr) {
                .None => {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.Space); // union
                },
                .Enum => |enum_tag_type| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const enum_token = tree.nextToken(lparen);

                    try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
                    try renderToken(tree, stream, enum_token, indent, start_col, Space.None); // enum

                    if (enum_tag_type) |expr| {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, start_col, Space.None); // (
                        try renderExpression(allocator, stream, tree, indent, start_col, expr, Space.None);

                        const rparen = tree.nextToken(expr.lastToken());
                        try renderToken(tree, stream, rparen, indent, start_col, Space.None); // )
                        try renderToken(tree, stream, tree.nextToken(rparen), indent, start_col, Space.Space); // )
                    } else {
                        try renderToken(tree, stream, tree.nextToken(enum_token), indent, start_col, Space.Space); // )
                    }
                },
                .Type => |type_expr| {
                    try renderToken(tree, stream, container_decl.kind_token, indent, start_col, Space.None); // union

                    const lparen = tree.nextToken(container_decl.kind_token);
                    const rparen = tree.nextToken(type_expr.lastToken());

                    try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
                    try renderExpression(allocator, stream, tree, indent, start_col, type_expr, Space.None);
                    try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
                },
            }

            if (container_decl.fields_and_decls_len == 0) {
                try renderToken(tree, stream, container_decl.lbrace_token, indent + indent_delta, start_col, Space.None); // {
                return renderToken(tree, stream, container_decl.rbrace_token, indent, start_col, space); // }
            }

            const src_has_trailing_comma = blk: {
                var maybe_comma = tree.prevToken(container_decl.lastToken());
                // Doc comments for a field may also appear after the comma, eg.
                // field_name: T, // comment attached to field_name
                if (tree.token_ids[maybe_comma] == .DocComment)
                    maybe_comma = tree.prevToken(maybe_comma);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const fields_and_decls = container_decl.fieldsAndDecls();

            // Check if the first declaration and the { are on the same line
            const src_has_newline = !tree.tokensOnSameLine(
                container_decl.lbrace_token,
                fields_and_decls[0].firstToken(),
            );

            // We can only print all the elements in-line if all the
            // declarations inside are fields
            const src_has_only_fields = blk: {
                for (fields_and_decls) |decl| {
                    if (decl.tag != .ContainerField) break :blk false;
                }
                break :blk true;
            };

            if (src_has_trailing_comma or !src_has_only_fields) {
                // One declaration per line
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, container_decl.lbrace_token, new_indent, start_col, .Newline); // {

                for (fields_and_decls) |decl, i| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderContainerDecl(allocator, stream, tree, new_indent, start_col, decl, .Newline);

                    if (i + 1 < fields_and_decls.len) {
                        try renderExtraNewline(tree, stream, start_col, fields_and_decls[i + 1]);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
            } else if (src_has_newline) {
                // All the declarations on the same line, but place the items on
                // their own line
                try renderToken(tree, stream, container_decl.lbrace_token, indent, start_col, .Newline); // {

                const new_indent = indent + indent_delta;
                try stream.writeByteNTimes(' ', new_indent);

                for (fields_and_decls) |decl, i| {
                    const space_after_decl: Space = if (i + 1 >= fields_and_decls.len) .Newline else .Space;
                    try renderContainerDecl(allocator, stream, tree, new_indent, start_col, decl, space_after_decl);
                }

                try stream.writeByteNTimes(' ', indent);
            } else {
                // All the declarations on the same line
                try renderToken(tree, stream, container_decl.lbrace_token, indent, start_col, .Space); // {

                for (fields_and_decls) |decl| {
                    try renderContainerDecl(allocator, stream, tree, indent, start_col, decl, .Space);
                }
            }

            return renderToken(tree, stream, container_decl.rbrace_token, indent, start_col, space); // }
        },

        .ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            const lbrace = tree.nextToken(err_set_decl.error_token);

            if (err_set_decl.decls_len == 0) {
                try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None);
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space);
            }

            if (err_set_decl.decls_len == 1) blk: {
                const node = err_set_decl.decls()[0];

                // if there are any doc comments or same line comments
                // don't try to put it all on one line
                if (node.cast(ast.Node.ErrorTag)) |tag| {
                    if (tag.doc_comments != null) break :blk;
                } else {
                    break :blk;
                }

                try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None); // error
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None); // {
                try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None);
                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space); // }
            }

            try renderToken(tree, stream, err_set_decl.error_token, indent, start_col, Space.None); // error

            const src_has_trailing_comma = blk: {
                const maybe_comma = tree.prevToken(err_set_decl.rbrace_token);
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (src_has_trailing_comma) {
                try renderToken(tree, stream, lbrace, indent, start_col, Space.Newline); // {
                const new_indent = indent + indent_delta;

                const decls = err_set_decl.decls();
                for (decls) |node, i| {
                    try stream.writeByteNTimes(' ', new_indent);

                    if (i + 1 < decls.len) {
                        try renderExpression(allocator, stream, tree, new_indent, start_col, node, Space.None);
                        try renderToken(tree, stream, tree.nextToken(node.lastToken()), new_indent, start_col, Space.Newline); // ,

                        try renderExtraNewline(tree, stream, start_col, decls[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, new_indent, start_col, node, Space.Comma);
                    }
                }

                try stream.writeByteNTimes(' ', indent);
                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space); // }
            } else {
                try renderToken(tree, stream, lbrace, indent, start_col, Space.Space); // {

                const decls = err_set_decl.decls();
                for (decls) |node, i| {
                    if (i + 1 < decls.len) {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        assert(tree.token_ids[comma_token] == .Comma);
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Space); // ,
                        try renderExtraNewline(tree, stream, start_col, decls[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.Space);
                    }
                }

                return renderToken(tree, stream, err_set_decl.rbrace_token, indent, start_col, space); // }
            }
        },

        .ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", base);

            try renderDocComments(tree, stream, tag, tag.doc_comments, indent, start_col);
            return renderToken(tree, stream, tag.name_token, indent, start_col, space); // name
        },

        .MultilineStringLiteral => {
            // TODO: Don't indent in this function, but let the caller indent.
            // If this has been implemented, a lot of hacky solutions in i.e. ArrayInit and FunctionCall can be removed
            const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);

            var skip_first_indent = true;
            if (tree.token_ids[multiline_str_literal.firstToken() - 1] != .LineComment) {
                try stream.print("\n", .{});
                skip_first_indent = false;
            }

            for (multiline_str_literal.lines()) |t| {
                if (!skip_first_indent) {
                    try stream.writeByteNTimes(' ', indent + indent_delta);
                }
                try renderToken(tree, stream, t, indent, start_col, Space.None);
                skip_first_indent = false;
            }
            try stream.writeByteNTimes(' ', indent);
        },
        .UndefinedLiteral => {
            const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
            return renderToken(tree, stream, undefined_literal.token, indent, start_col, space);
        },

        .BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);

            try renderToken(tree, stream, builtin_call.builtin_token, indent, start_col, Space.None); // @name

            const src_params_trailing_comma = blk: {
                if (builtin_call.params_len < 2) break :blk false;
                const last_node = builtin_call.params()[builtin_call.params_len - 1];
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            const lparen = tree.nextToken(builtin_call.builtin_token);

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                // render all on one line, no trailing comma
                const params = builtin_call.params();
                for (params) |param_node, i| {
                    try renderExpression(allocator, stream, tree, indent, start_col, param_node, Space.None);

                    if (i + 1 < params.len) {
                        const comma_token = tree.nextToken(param_node.lastToken());
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Space); // ,
                    }
                }
            } else {
                // one param per line
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, lparen, new_indent, start_col, Space.Newline); // (

                for (builtin_call.params()) |param_node| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderExpression(allocator, stream, tree, indent, start_col, param_node, Space.Comma);
                }
                try stream.writeByteNTimes(' ', indent);
            }

            return renderToken(tree, stream, builtin_call.rparen_token, indent, start_col, space); // )
        },

        .FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.getTrailer("visib_token")) |visib_token_index| {
                const visib_token = tree.token_ids[visib_token_index];
                assert(visib_token == .Keyword_pub or visib_token == .Keyword_export);

                try renderToken(tree, stream, visib_token_index, indent, start_col, Space.Space); // pub
            }

            if (fn_proto.getTrailer("extern_export_inline_token")) |extern_export_inline_token| {
                if (fn_proto.getTrailer("is_extern_prototype") == null)
                    try renderToken(tree, stream, extern_export_inline_token, indent, start_col, Space.Space); // extern/export/inline
            }

            if (fn_proto.getTrailer("lib_name")) |lib_name| {
                try renderExpression(allocator, stream, tree, indent, start_col, lib_name, Space.Space);
            }

            const lparen = if (fn_proto.getTrailer("name_token")) |name_token| blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, start_col, Space.Space); // fn
                try renderToken(tree, stream, name_token, indent, start_col, Space.None); // name
                break :blk tree.nextToken(name_token);
            } else blk: {
                try renderToken(tree, stream, fn_proto.fn_token, indent, start_col, Space.Space); // fn
                break :blk tree.nextToken(fn_proto.fn_token);
            };
            assert(tree.token_ids[lparen] == .LParen);

            const rparen = tree.prevToken(
            // the first token for the annotation expressions is the left
            // parenthesis, hence the need for two prevToken
            if (fn_proto.getTrailer("align_expr")) |align_expr|
                tree.prevToken(tree.prevToken(align_expr.firstToken()))
            else if (fn_proto.getTrailer("section_expr")) |section_expr|
                tree.prevToken(tree.prevToken(section_expr.firstToken()))
            else if (fn_proto.getTrailer("callconv_expr")) |callconv_expr|
                tree.prevToken(tree.prevToken(callconv_expr.firstToken()))
            else switch (fn_proto.return_type) {
                .Explicit => |node| node.firstToken(),
                .InferErrorSet => |node| tree.prevToken(node.firstToken()),
                .Invalid => unreachable,
            });
            assert(tree.token_ids[rparen] == .RParen);

            const src_params_trailing_comma = blk: {
                const maybe_comma = tree.token_ids[rparen - 1];
                break :blk maybe_comma == .Comma or maybe_comma == .LineComment;
            };

            if (!src_params_trailing_comma) {
                try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                // render all on one line, no trailing comma
                for (fn_proto.params()) |param_decl, i| {
                    try renderParamDecl(allocator, stream, tree, indent, start_col, param_decl, Space.None);

                    if (i + 1 < fn_proto.params_len or fn_proto.getTrailer("var_args_token") != null) {
                        const comma = tree.nextToken(param_decl.lastToken());
                        try renderToken(tree, stream, comma, indent, start_col, Space.Space); // ,
                    }
                }
                if (fn_proto.getTrailer("var_args_token")) |var_args_token| {
                    try renderToken(tree, stream, var_args_token, indent, start_col, Space.None);
                }
            } else {
                // one param per line
                const new_indent = indent + indent_delta;
                try renderToken(tree, stream, lparen, new_indent, start_col, Space.Newline); // (

                for (fn_proto.params()) |param_decl| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderParamDecl(allocator, stream, tree, new_indent, start_col, param_decl, Space.Comma);
                }
                if (fn_proto.getTrailer("var_args_token")) |var_args_token| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderToken(tree, stream, var_args_token, new_indent, start_col, Space.Comma);
                }
                try stream.writeByteNTimes(' ', indent);
            }

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )

            if (fn_proto.getTrailer("align_expr")) |align_expr| {
                const align_rparen = tree.nextToken(align_expr.lastToken());
                const align_lparen = tree.prevToken(align_expr.firstToken());
                const align_kw = tree.prevToken(align_lparen);

                try renderToken(tree, stream, align_kw, indent, start_col, Space.None); // align
                try renderToken(tree, stream, align_lparen, indent, start_col, Space.None); // (
                try renderExpression(allocator, stream, tree, indent, start_col, align_expr, Space.None);
                try renderToken(tree, stream, align_rparen, indent, start_col, Space.Space); // )
            }

            if (fn_proto.getTrailer("section_expr")) |section_expr| {
                const section_rparen = tree.nextToken(section_expr.lastToken());
                const section_lparen = tree.prevToken(section_expr.firstToken());
                const section_kw = tree.prevToken(section_lparen);

                try renderToken(tree, stream, section_kw, indent, start_col, Space.None); // section
                try renderToken(tree, stream, section_lparen, indent, start_col, Space.None); // (
                try renderExpression(allocator, stream, tree, indent, start_col, section_expr, Space.None);
                try renderToken(tree, stream, section_rparen, indent, start_col, Space.Space); // )
            }

            if (fn_proto.getTrailer("callconv_expr")) |callconv_expr| {
                const callconv_rparen = tree.nextToken(callconv_expr.lastToken());
                const callconv_lparen = tree.prevToken(callconv_expr.firstToken());
                const callconv_kw = tree.prevToken(callconv_lparen);

                try renderToken(tree, stream, callconv_kw, indent, start_col, Space.None); // callconv
                try renderToken(tree, stream, callconv_lparen, indent, start_col, Space.None); // (
                try renderExpression(allocator, stream, tree, indent, start_col, callconv_expr, Space.None);
                try renderToken(tree, stream, callconv_rparen, indent, start_col, Space.Space); // )
            } else if (fn_proto.getTrailer("is_extern_prototype") != null) {
                try stream.writeAll("callconv(.C) ");
            } else if (fn_proto.getTrailer("is_async") != null) {
                try stream.writeAll("callconv(.Async) ");
            }

            switch (fn_proto.return_type) {
                .Explicit => |node| {
                    return renderExpression(allocator, stream, tree, indent, start_col, node, space);
                },
                .InferErrorSet => |node| {
                    try renderToken(tree, stream, tree.prevToken(node.firstToken()), indent, start_col, Space.None); // !
                    return renderExpression(allocator, stream, tree, indent, start_col, node, space);
                },
                .Invalid => unreachable,
            }
        },

        .AnyFrameType => {
            const anyframe_type = @fieldParentPtr(ast.Node.AnyFrameType, "base", base);

            if (anyframe_type.result) |result| {
                try renderToken(tree, stream, anyframe_type.anyframe_token, indent, start_col, Space.None); // anyframe
                try renderToken(tree, stream, result.arrow_token, indent, start_col, Space.None); // ->
                return renderExpression(allocator, stream, tree, indent, start_col, result.return_type, space);
            } else {
                return renderToken(tree, stream, anyframe_type.anyframe_token, indent, start_col, space); // anyframe
            }
        },

        .DocComment => unreachable, // doc comments are attached to nodes

        .Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try renderToken(tree, stream, switch_node.switch_token, indent, start_col, Space.Space); // switch
            try renderToken(tree, stream, tree.nextToken(switch_node.switch_token), indent, start_col, Space.None); // (

            const rparen = tree.nextToken(switch_node.expr.lastToken());
            const lbrace = tree.nextToken(rparen);

            if (switch_node.cases_len == 0) {
                try renderExpression(allocator, stream, tree, indent, start_col, switch_node.expr, Space.None);
                try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
                try renderToken(tree, stream, lbrace, indent, start_col, Space.None); // {
                return renderToken(tree, stream, switch_node.rbrace, indent, start_col, space); // }
            }

            try renderExpression(allocator, stream, tree, indent, start_col, switch_node.expr, Space.None);

            const new_indent = indent + indent_delta;

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )
            try renderToken(tree, stream, lbrace, new_indent, start_col, Space.Newline); // {

            const cases = switch_node.cases();
            for (cases) |node, i| {
                try stream.writeByteNTimes(' ', new_indent);
                try renderExpression(allocator, stream, tree, new_indent, start_col, node, Space.Comma);

                if (i + 1 < cases.len) {
                    try renderExtraNewline(tree, stream, start_col, cases[i + 1]);
                }
            }

            try stream.writeByteNTimes(' ', indent);
            return renderToken(tree, stream, switch_node.rbrace, indent, start_col, space); // }
        },

        .SwitchCase => {
            const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

            assert(switch_case.items_len != 0);
            const src_has_trailing_comma = blk: {
                const last_node = switch_case.items()[switch_case.items_len - 1];
                const maybe_comma = tree.nextToken(last_node.lastToken());
                break :blk tree.token_ids[maybe_comma] == .Comma;
            };

            if (switch_case.items_len == 1 or !src_has_trailing_comma) {
                const items = switch_case.items();
                for (items) |node, i| {
                    if (i + 1 < items.len) {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Space); // ,
                        try renderExtraNewline(tree, stream, start_col, items[i + 1]);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.Space);
                    }
                }
            } else {
                const items = switch_case.items();
                for (items) |node, i| {
                    if (i + 1 < items.len) {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.None);

                        const comma_token = tree.nextToken(node.lastToken());
                        try renderToken(tree, stream, comma_token, indent, start_col, Space.Newline); // ,
                        try renderExtraNewline(tree, stream, start_col, items[i + 1]);
                        try stream.writeByteNTimes(' ', indent);
                    } else {
                        try renderExpression(allocator, stream, tree, indent, start_col, node, Space.Comma);
                        try stream.writeByteNTimes(' ', indent);
                    }
                }
            }

            try renderToken(tree, stream, switch_case.arrow_token, indent, start_col, Space.Space); // =>

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }

            return renderExpression(allocator, stream, tree, indent, start_col, switch_case.expr, space);
        },
        .SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            return renderToken(tree, stream, switch_else.token, indent, start_col, space);
        },
        .Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            const body_is_block = nodeIsBlock(else_node.body);
            const same_line = body_is_block or tree.tokensOnSameLine(else_node.else_token, else_node.body.lastToken());

            const after_else_space = if (same_line or else_node.payload != null) Space.Space else Space.Newline;
            try renderToken(tree, stream, else_node.else_token, indent, start_col, after_else_space);

            if (else_node.payload) |payload| {
                const payload_space = if (same_line) Space.Space else Space.Newline;
                try renderExpression(allocator, stream, tree, indent, start_col, payload, payload_space);
            }

            if (same_line) {
                return renderExpression(allocator, stream, tree, indent, start_col, else_node.body, space);
            }

            try stream.writeByteNTimes(' ', indent + indent_delta);
            start_col.* = indent + indent_delta;
            return renderExpression(allocator, stream, tree, indent, start_col, else_node.body, space);
        },

        .While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space); // :
            }

            if (while_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, start_col, Space.Space); // inline
            }

            try renderToken(tree, stream, while_node.while_token, indent, start_col, Space.Space); // while
            try renderToken(tree, stream, tree.nextToken(while_node.while_token), indent, start_col, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, start_col, while_node.condition, Space.None);

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
                try renderToken(tree, stream, cond_rparen, indent, start_col, rparen_space); // )
            }

            if (while_node.payload) |payload| {
                const payload_space = if (while_node.continue_expr != null) Space.Space else block_start_space;
                try renderExpression(allocator, stream, tree, indent, start_col, payload, payload_space);
            }

            if (while_node.continue_expr) |continue_expr| {
                const rparen = tree.nextToken(continue_expr.lastToken());
                const lparen = tree.prevToken(continue_expr.firstToken());
                const colon = tree.prevToken(lparen);

                try renderToken(tree, stream, colon, indent, start_col, Space.Space); // :
                try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

                try renderExpression(allocator, stream, tree, indent, start_col, continue_expr, Space.None);

                try renderToken(tree, stream, rparen, indent, start_col, block_start_space); // )
            }

            var new_indent = indent;
            if (block_start_space == Space.Newline) {
                new_indent += indent_delta;
                try stream.writeByteNTimes(' ', new_indent);
                start_col.* = new_indent;
            }

            try renderExpression(allocator, stream, tree, indent, start_col, while_node.body, after_body_space);

            if (while_node.@"else") |@"else"| {
                if (after_body_space == Space.Newline) {
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                }
                return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space);
            }
        },

        .For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);

            if (for_node.label) |label| {
                try renderToken(tree, stream, label, indent, start_col, Space.None); // label
                try renderToken(tree, stream, tree.nextToken(label), indent, start_col, Space.Space); // :
            }

            if (for_node.inline_token) |inline_token| {
                try renderToken(tree, stream, inline_token, indent, start_col, Space.Space); // inline
            }

            try renderToken(tree, stream, for_node.for_token, indent, start_col, Space.Space); // for
            try renderToken(tree, stream, tree.nextToken(for_node.for_token), indent, start_col, Space.None); // (
            try renderExpression(allocator, stream, tree, indent, start_col, for_node.array_expr, Space.None);

            const rparen = tree.nextToken(for_node.array_expr.lastToken());

            const body_is_block = for_node.body.tag == .Block;
            const src_one_line_to_body = !body_is_block and tree.tokensOnSameLine(rparen, for_node.body.firstToken());
            const body_on_same_line = body_is_block or src_one_line_to_body;

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )

            const space_after_payload = if (body_on_same_line) Space.Space else Space.Newline;
            try renderExpression(allocator, stream, tree, indent, start_col, for_node.payload, space_after_payload); // |x|

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

            const body_indent = if (body_on_same_line) indent else indent + indent_delta;
            if (!body_on_same_line) try stream.writeByteNTimes(' ', body_indent);
            try renderExpression(allocator, stream, tree, body_indent, start_col, for_node.body, space_after_body); // { body }

            if (for_node.@"else") |@"else"| {
                if (space_after_body == Space.Newline) try stream.writeByteNTimes(' ', indent);
                return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space); // else
            }
        },

        .If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);

            const lparen = tree.nextToken(if_node.if_token);
            const rparen = tree.nextToken(if_node.condition.lastToken());

            try renderToken(tree, stream, if_node.if_token, indent, start_col, Space.Space); // if
            try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (

            try renderExpression(allocator, stream, tree, indent, start_col, if_node.condition, Space.None); // condition

            const body_is_if_block = if_node.body.tag == .If;
            const body_is_block = nodeIsBlock(if_node.body);

            if (body_is_if_block) {
                try renderExtraNewline(tree, stream, start_col, if_node.body);
            } else if (body_is_block) {
                const after_rparen_space = if (if_node.payload == null) Space.BlockStart else Space.Space;
                try renderToken(tree, stream, rparen, indent, start_col, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.BlockStart); // |x|
                }

                if (if_node.@"else") |@"else"| {
                    try renderExpression(allocator, stream, tree, indent, start_col, if_node.body, Space.SpaceOrOutdent);
                    return renderExpression(allocator, stream, tree, indent, start_col, &@"else".base, space);
                } else {
                    return renderExpression(allocator, stream, tree, indent, start_col, if_node.body, space);
                }
            }

            const src_has_newline = !tree.tokensOnSameLine(rparen, if_node.body.lastToken());

            if (src_has_newline) {
                const after_rparen_space = if (if_node.payload == null) Space.Newline else Space.Space;
                try renderToken(tree, stream, rparen, indent, start_col, after_rparen_space); // )

                if (if_node.payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Newline);
                }

                const new_indent = indent + indent_delta;
                try stream.writeByteNTimes(' ', new_indent);

                if (if_node.@"else") |@"else"| {
                    const else_is_block = nodeIsBlock(@"else".body);
                    try renderExpression(allocator, stream, tree, new_indent, start_col, if_node.body, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);

                    if (else_is_block) {
                        try renderToken(tree, stream, @"else".else_token, indent, start_col, Space.Space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                        }

                        return renderExpression(allocator, stream, tree, indent, start_col, @"else".body, space);
                    } else {
                        const after_else_space = if (@"else".payload == null) Space.Newline else Space.Space;
                        try renderToken(tree, stream, @"else".else_token, indent, start_col, after_else_space); // else

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Newline);
                        }
                        try stream.writeByteNTimes(' ', new_indent);

                        return renderExpression(allocator, stream, tree, new_indent, start_col, @"else".body, space);
                    }
                } else {
                    return renderExpression(allocator, stream, tree, new_indent, start_col, if_node.body, space);
                }
            }

            try renderToken(tree, stream, rparen, indent, start_col, Space.Space); // )

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
            }

            if (if_node.@"else") |@"else"| {
                try renderExpression(allocator, stream, tree, indent, start_col, if_node.body, Space.Space);
                try renderToken(tree, stream, @"else".else_token, indent, start_col, Space.Space);

                if (@"else".payload) |payload| {
                    try renderExpression(allocator, stream, tree, indent, start_col, payload, Space.Space);
                }

                return renderExpression(allocator, stream, tree, indent, start_col, @"else".body, space);
            } else {
                return renderExpression(allocator, stream, tree, indent, start_col, if_node.body, space);
            }
        },

        .Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);

            try renderToken(tree, stream, asm_node.asm_token, indent, start_col, Space.Space); // asm

            if (asm_node.volatile_token) |volatile_token| {
                try renderToken(tree, stream, volatile_token, indent, start_col, Space.Space); // volatile
                try renderToken(tree, stream, tree.nextToken(volatile_token), indent, start_col, Space.None); // (
            } else {
                try renderToken(tree, stream, tree.nextToken(asm_node.asm_token), indent, start_col, Space.None); // (
            }

            if (asm_node.outputs.len == 0 and asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                try renderExpression(allocator, stream, tree, indent, start_col, asm_node.template, Space.None);
                return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
            }

            try renderExpression(allocator, stream, tree, indent, start_col, asm_node.template, Space.Newline);

            const indent_once = indent + indent_delta;

            if (asm_node.template.tag == .MultilineStringLiteral) {
                // After rendering a multiline string literal the cursor is
                // already offset by indent
                try stream.writeByteNTimes(' ', indent_delta);
            } else {
                try stream.writeByteNTimes(' ', indent_once);
            }

            const colon1 = tree.nextToken(asm_node.template.lastToken());
            const indent_extra = indent_once + 2;

            const colon2 = if (asm_node.outputs.len == 0) blk: {
                try renderToken(tree, stream, colon1, indent, start_col, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon1);
            } else blk: {
                try renderToken(tree, stream, colon1, indent, start_col, Space.Space); // :

                for (asm_node.outputs) |*asm_output, i| {
                    if (i + 1 < asm_node.outputs.len) {
                        const next_asm_output = asm_node.outputs[i + 1];
                        try renderAsmOutput(allocator, stream, tree, indent_extra, start_col, asm_output, Space.None);

                        const comma = tree.prevToken(next_asm_output.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, start_col, Space.Newline); // ,
                        try renderExtraNewlineToken(tree, stream, start_col, next_asm_output.firstToken());

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.inputs.len == 0 and asm_node.clobbers.len == 0) {
                        try renderAsmOutput(allocator, stream, tree, indent_extra, start_col, asm_output, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
                    } else {
                        try renderAsmOutput(allocator, stream, tree, indent_extra, start_col, asm_output, Space.Newline);
                        try stream.writeByteNTimes(' ', indent_once);
                        const comma_or_colon = tree.nextToken(asm_output.lastToken());
                        break :blk switch (tree.token_ids[comma_or_colon]) {
                            .Comma => tree.nextToken(comma_or_colon),
                            else => comma_or_colon,
                        };
                    }
                }
                unreachable;
            };

            const colon3 = if (asm_node.inputs.len == 0) blk: {
                try renderToken(tree, stream, colon2, indent, start_col, Space.Newline); // :
                try stream.writeByteNTimes(' ', indent_once);

                break :blk tree.nextToken(colon2);
            } else blk: {
                try renderToken(tree, stream, colon2, indent, start_col, Space.Space); // :

                for (asm_node.inputs) |*asm_input, i| {
                    if (i + 1 < asm_node.inputs.len) {
                        const next_asm_input = &asm_node.inputs[i + 1];
                        try renderAsmInput(allocator, stream, tree, indent_extra, start_col, asm_input, Space.None);

                        const comma = tree.prevToken(next_asm_input.firstToken());
                        try renderToken(tree, stream, comma, indent_extra, start_col, Space.Newline); // ,
                        try renderExtraNewlineToken(tree, stream, start_col, next_asm_input.firstToken());

                        try stream.writeByteNTimes(' ', indent_extra);
                    } else if (asm_node.clobbers.len == 0) {
                        try renderAsmInput(allocator, stream, tree, indent_extra, start_col, asm_input, Space.Newline);
                        try stream.writeByteNTimes(' ', indent);
                        return renderToken(tree, stream, asm_node.rparen, indent, start_col, space); // )
                    } else {
                        try renderAsmInput(allocator, stream, tree, indent_extra, start_col, asm_input, Space.Newline);
                        try stream.writeByteNTimes(' ', indent_once);
                        const comma_or_colon = tree.nextToken(asm_input.lastToken());
                        break :blk switch (tree.token_ids[comma_or_colon]) {
                            .Comma => tree.nextToken(comma_or_colon),
                            else => comma_or_colon,
                        };
                    }
                }
                unreachable;
            };

            try renderToken(tree, stream, colon3, indent, start_col, Space.Space); // :

            for (asm_node.clobbers) |clobber_node, i| {
                if (i + 1 >= asm_node.clobbers.len) {
                    try renderExpression(allocator, stream, tree, indent_extra, start_col, clobber_node, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);
                    return renderToken(tree, stream, asm_node.rparen, indent, start_col, space);
                } else {
                    try renderExpression(allocator, stream, tree, indent_extra, start_col, clobber_node, Space.None);
                    const comma = tree.nextToken(clobber_node.lastToken());
                    try renderToken(tree, stream, comma, indent_once, start_col, Space.Space); // ,
                }
            }
        },

        .EnumLiteral => {
            const enum_literal = @fieldParentPtr(ast.Node.EnumLiteral, "base", base);

            try renderToken(tree, stream, enum_literal.dot, indent, start_col, Space.None); // .
            return renderToken(tree, stream, enum_literal.name, indent, start_col, space); // name
        },

        .ContainerField,
        .Root,
        .VarDecl,
        .Use,
        .TestDecl,
        => unreachable,
    }
}

fn renderArrayType(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    lbracket: ast.TokenIndex,
    rhs: *ast.Node,
    len_expr: *ast.Node,
    opt_sentinel: ?*ast.Node,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    const rbracket = tree.nextToken(if (opt_sentinel) |sentinel|
        sentinel.lastToken()
    else
        len_expr.lastToken());

    try renderToken(tree, stream, lbracket, indent, start_col, Space.None); // [

    const starts_with_comment = tree.token_ids[lbracket + 1] == .LineComment;
    const ends_with_comment = tree.token_ids[rbracket - 1] == .LineComment;
    const new_indent = if (ends_with_comment) indent + indent_delta else indent;
    const new_space = if (ends_with_comment) Space.Newline else Space.None;
    try renderExpression(allocator, stream, tree, new_indent, start_col, len_expr, new_space);
    if (starts_with_comment) {
        try stream.writeByte('\n');
    }
    if (ends_with_comment or starts_with_comment) {
        try stream.writeByteNTimes(' ', indent);
    }
    if (opt_sentinel) |sentinel| {
        const colon_token = tree.prevToken(sentinel.firstToken());
        try renderToken(tree, stream, colon_token, indent, start_col, Space.None); // :
        try renderExpression(allocator, stream, tree, indent, start_col, sentinel, Space.None);
    }
    try renderToken(tree, stream, rbracket, indent, start_col, Space.None); // ]

    return renderExpression(allocator, stream, tree, indent, start_col, rhs, space);
}

fn renderAsmOutput(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    asm_output: *const ast.Node.Asm.Output,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    try stream.writeAll("[");
    try renderExpression(allocator, stream, tree, indent, start_col, asm_output.symbolic_name, Space.None);
    try stream.writeAll("] ");
    try renderExpression(allocator, stream, tree, indent, start_col, asm_output.constraint, Space.None);
    try stream.writeAll(" (");

    switch (asm_output.kind) {
        ast.Node.Asm.Output.Kind.Variable => |variable_name| {
            try renderExpression(allocator, stream, tree, indent, start_col, &variable_name.base, Space.None);
        },
        ast.Node.Asm.Output.Kind.Return => |return_type| {
            try stream.writeAll("-> ");
            try renderExpression(allocator, stream, tree, indent, start_col, return_type, Space.None);
        },
    }

    return renderToken(tree, stream, asm_output.lastToken(), indent, start_col, space); // )
}

fn renderAsmInput(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    asm_input: *const ast.Node.Asm.Input,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    try stream.writeAll("[");
    try renderExpression(allocator, stream, tree, indent, start_col, asm_input.symbolic_name, Space.None);
    try stream.writeAll("] ");
    try renderExpression(allocator, stream, tree, indent, start_col, asm_input.constraint, Space.None);
    try stream.writeAll(" (");
    try renderExpression(allocator, stream, tree, indent, start_col, asm_input.expr, Space.None);
    return renderToken(tree, stream, asm_input.lastToken(), indent, start_col, space); // )
}

fn renderVarDecl(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    var_decl: *ast.Node.VarDecl,
) (@TypeOf(stream).Error || Error)!void {
    if (var_decl.getTrailer("visib_token")) |visib_token| {
        try renderToken(tree, stream, visib_token, indent, start_col, Space.Space); // pub
    }

    if (var_decl.getTrailer("extern_export_token")) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, indent, start_col, Space.Space); // extern

        if (var_decl.getTrailer("lib_name")) |lib_name| {
            try renderExpression(allocator, stream, tree, indent, start_col, lib_name, Space.Space); // "lib"
        }
    }

    if (var_decl.getTrailer("comptime_token")) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, start_col, Space.Space); // comptime
    }

    if (var_decl.getTrailer("thread_local_token")) |thread_local_token| {
        try renderToken(tree, stream, thread_local_token, indent, start_col, Space.Space); // threadlocal
    }
    try renderToken(tree, stream, var_decl.mut_token, indent, start_col, Space.Space); // var

    const name_space = if (var_decl.getTrailer("type_node") == null and
        (var_decl.getTrailer("align_node") != null or
        var_decl.getTrailer("section_node") != null or
        var_decl.getTrailer("init_node") != null))
        Space.Space
    else
        Space.None;
    try renderToken(tree, stream, var_decl.name_token, indent, start_col, name_space);

    if (var_decl.getTrailer("type_node")) |type_node| {
        try renderToken(tree, stream, tree.nextToken(var_decl.name_token), indent, start_col, Space.Space);
        const s = if (var_decl.getTrailer("align_node") != null or
            var_decl.getTrailer("section_node") != null or
            var_decl.getTrailer("init_node") != null) Space.Space else Space.None;
        try renderExpression(allocator, stream, tree, indent, start_col, type_node, s);
    }

    if (var_decl.getTrailer("align_node")) |align_node| {
        const lparen = tree.prevToken(align_node.firstToken());
        const align_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(align_node.lastToken());
        try renderToken(tree, stream, align_kw, indent, start_col, Space.None); // align
        try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
        try renderExpression(allocator, stream, tree, indent, start_col, align_node, Space.None);
        const s = if (var_decl.getTrailer("section_node") != null or var_decl.getTrailer("init_node") != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, indent, start_col, s); // )
    }

    if (var_decl.getTrailer("section_node")) |section_node| {
        const lparen = tree.prevToken(section_node.firstToken());
        const section_kw = tree.prevToken(lparen);
        const rparen = tree.nextToken(section_node.lastToken());
        try renderToken(tree, stream, section_kw, indent, start_col, Space.None); // linksection
        try renderToken(tree, stream, lparen, indent, start_col, Space.None); // (
        try renderExpression(allocator, stream, tree, indent, start_col, section_node, Space.None);
        const s = if (var_decl.getTrailer("init_node") != null) Space.Space else Space.None;
        try renderToken(tree, stream, rparen, indent, start_col, s); // )
    }

    if (var_decl.getTrailer("init_node")) |init_node| {
        const s = if (init_node.tag == .MultilineStringLiteral) Space.None else Space.Space;
        try renderToken(tree, stream, var_decl.getTrailer("eq_token").?, indent, start_col, s); // =
        try renderExpression(allocator, stream, tree, indent, start_col, init_node, Space.None);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, indent, start_col, Space.Newline);
}

fn renderParamDecl(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    param_decl: ast.Node.FnProto.ParamDecl,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    try renderDocComments(tree, stream, param_decl, param_decl.doc_comments, indent, start_col);

    if (param_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, start_col, Space.Space);
    }
    if (param_decl.noalias_token) |noalias_token| {
        try renderToken(tree, stream, noalias_token, indent, start_col, Space.Space);
    }
    if (param_decl.name_token) |name_token| {
        try renderToken(tree, stream, name_token, indent, start_col, Space.None);
        try renderToken(tree, stream, tree.nextToken(name_token), indent, start_col, Space.Space); // :
    }
    switch (param_decl.param_type) {
        .any_type, .type_expr => |node| try renderExpression(allocator, stream, tree, indent, start_col, node, space),
    }
}

fn renderStatement(
    allocator: *mem.Allocator,
    stream: anytype,
    tree: *ast.Tree,
    indent: usize,
    start_col: *usize,
    base: *ast.Node,
) (@TypeOf(stream).Error || Error)!void {
    switch (base.tag) {
        .VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, indent, start_col, var_decl);
        },
        else => {
            if (base.requireSemiColon()) {
                try renderExpression(allocator, stream, tree, indent, start_col, base, Space.None);

                const semicolon_index = tree.nextToken(base.lastToken());
                assert(tree.token_ids[semicolon_index] == .Semicolon);
                try renderToken(tree, stream, semicolon_index, indent, start_col, Space.Newline);
            } else {
                try renderExpression(allocator, stream, tree, indent, start_col, base, Space.Newline);
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
    stream: anytype,
    token_index: ast.TokenIndex,
    indent: usize,
    start_col: *usize,
    space: Space,
    token_skip_bytes: usize,
) (@TypeOf(stream).Error || Error)!void {
    if (space == Space.BlockStart) {
        if (start_col.* < indent + indent_delta)
            return renderToken(tree, stream, token_index, indent, start_col, Space.Space);
        try renderToken(tree, stream, token_index, indent, start_col, Space.Newline);
        try stream.writeByteNTimes(' ', indent);
        start_col.* = indent;
        return;
    }

    var token_loc = tree.token_locs[token_index];
    try stream.writeAll(mem.trimRight(u8, tree.tokenSliceLoc(token_loc)[token_skip_bytes..], " "));

    if (space == Space.NoComment)
        return;

    var next_token_id = tree.token_ids[token_index + 1];
    var next_token_loc = tree.token_locs[token_index + 1];

    if (space == Space.Comma) switch (next_token_id) {
        .Comma => return renderToken(tree, stream, token_index + 1, indent, start_col, Space.Newline),
        .LineComment => {
            try stream.writeAll(", ");
            return renderToken(tree, stream, token_index + 1, indent, start_col, Space.Newline);
        },
        else => {
            if (token_index + 2 < tree.token_ids.len and
                tree.token_ids[token_index + 2] == .MultilineStringLiteralLine)
            {
                try stream.writeAll(",");
                return;
            } else {
                try stream.writeAll(",\n");
                start_col.* = 0;
                return;
            }
        },
    };

    // Skip over same line doc comments
    var offset: usize = 1;
    if (next_token_id == .DocComment) {
        const loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
        if (loc.line == 0) {
            offset += 1;
            next_token_id = tree.token_ids[token_index + offset];
            next_token_loc = tree.token_locs[token_index + offset];
        }
    }

    if (next_token_id != .LineComment) blk: {
        switch (space) {
            Space.None, Space.NoNewline => return,
            Space.Newline => {
                if (next_token_id == .MultilineStringLiteralLine) {
                    return;
                } else {
                    try stream.writeAll("\n");
                    start_col.* = 0;
                    return;
                }
            },
            Space.Space, Space.SpaceOrOutdent => {
                if (next_token_id == .MultilineStringLiteralLine)
                    return;
                try stream.writeByte(' ');
                return;
            },
            Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
        }
    }

    while (true) {
        const comment_is_empty = mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " ").len == 2;
        if (comment_is_empty) {
            switch (space) {
                Space.Newline => {
                    offset += 1;
                    token_loc = next_token_loc;
                    next_token_id = tree.token_ids[token_index + offset];
                    next_token_loc = tree.token_locs[token_index + offset];
                    if (next_token_id != .LineComment) {
                        try stream.writeByte('\n');
                        start_col.* = 0;
                        return;
                    }
                },
                else => break,
            }
        } else {
            break;
        }
    }

    var loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    if (loc.line == 0) {
        try stream.print(" {}", .{mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " ")});
        offset = 2;
        token_loc = next_token_loc;
        next_token_loc = tree.token_locs[token_index + offset];
        next_token_id = tree.token_ids[token_index + offset];
        if (next_token_id != .LineComment) {
            switch (space) {
                Space.None, Space.Space => {
                    try stream.writeByte('\n');
                    const after_comment_token = tree.token_ids[token_index + offset];
                    const next_line_indent = switch (after_comment_token) {
                        .RParen, .RBrace, .RBracket => indent,
                        else => indent + indent_delta,
                    };
                    try stream.writeByteNTimes(' ', next_line_indent);
                    start_col.* = next_line_indent;
                },
                Space.SpaceOrOutdent => {
                    try stream.writeByte('\n');
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                },
                Space.Newline => {
                    if (next_token_id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.writeAll("\n");
                        start_col.* = 0;
                        return;
                    }
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    }

    while (true) {
        // translate-c doesn't generate correct newlines
        // in generated code (loc.line == 0) so treat that case
        // as though there was meant to be a newline between the tokens
        const newline_count = if (loc.line <= 1) @as(u8, 1) else @as(u8, 2);
        try stream.writeByteNTimes('\n', newline_count);
        try stream.writeByteNTimes(' ', indent);
        try stream.writeAll(mem.trimRight(u8, tree.tokenSliceLoc(next_token_loc), " "));

        offset += 1;
        token_loc = next_token_loc;
        next_token_loc = tree.token_locs[token_index + offset];
        next_token_id = tree.token_ids[token_index + offset];
        if (next_token_id != .LineComment) {
            switch (space) {
                Space.Newline => {
                    if (next_token_id == .MultilineStringLiteralLine) {
                        return;
                    } else {
                        try stream.writeAll("\n");
                        start_col.* = 0;
                        return;
                    }
                },
                Space.None, Space.Space => {
                    try stream.writeByte('\n');

                    const after_comment_token = tree.token_ids[token_index + offset];
                    const next_line_indent = switch (after_comment_token) {
                        .RParen, .RBrace, .RBracket => blk: {
                            if (indent > indent_delta) {
                                break :blk indent - indent_delta;
                            } else {
                                break :blk 0;
                            }
                        },
                        else => indent,
                    };
                    try stream.writeByteNTimes(' ', next_line_indent);
                    start_col.* = next_line_indent;
                },
                Space.SpaceOrOutdent => {
                    try stream.writeByte('\n');
                    try stream.writeByteNTimes(' ', indent);
                    start_col.* = indent;
                },
                Space.NoNewline => {},
                Space.NoComment, Space.Comma, Space.BlockStart => unreachable,
            }
            return;
        }
        loc = tree.tokenLocationLoc(token_loc.end, next_token_loc);
    }
}

fn renderToken(
    tree: *ast.Tree,
    stream: anytype,
    token_index: ast.TokenIndex,
    indent: usize,
    start_col: *usize,
    space: Space,
) (@TypeOf(stream).Error || Error)!void {
    return renderTokenOffset(tree, stream, token_index, indent, start_col, space, 0);
}

fn renderDocComments(
    tree: *ast.Tree,
    stream: anytype,
    node: anytype,
    doc_comments: ?*ast.Node.DocComment,
    indent: usize,
    start_col: *usize,
) (@TypeOf(stream).Error || Error)!void {
    const comment = doc_comments orelse return;
    return renderDocCommentsToken(tree, stream, comment, node.firstToken(), indent, start_col);
}

fn renderDocCommentsToken(
    tree: *ast.Tree,
    stream: anytype,
    comment: *ast.Node.DocComment,
    first_token: ast.TokenIndex,
    indent: usize,
    start_col: *usize,
) (@TypeOf(stream).Error || Error)!void {
    var tok_i = comment.first_line;
    while (true) : (tok_i += 1) {
        switch (tree.token_ids[tok_i]) {
            .DocComment, .ContainerDocComment => {
                if (comment.first_line < first_token) {
                    try renderToken(tree, stream, tok_i, indent, start_col, Space.Newline);
                    try stream.writeByteNTimes(' ', indent);
                } else {
                    try renderToken(tree, stream, tok_i, indent, start_col, Space.NoComment);
                    try stream.writeAll("\n");
                    try stream.writeByteNTimes(' ', indent);
                }
            },
            .LineComment => continue,
            else => break,
        }
    }
}

fn nodeIsBlock(base: *const ast.Node) bool {
    return switch (base.tag) {
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
    return switch (base.tag) {
        .Catch,
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
        .Sub,
        .SubWrap,
        .OrElse,
        => true,

        else => false,
    };
}

/// A `std.io.OutStream` that returns whether the given character has been written to it.
/// The contents are not written to anything.
const FindByteOutStream = struct {
    byte_found: bool,
    byte: u8,

    pub const Error = error{};
    pub const OutStream = std.io.OutStream(*FindByteOutStream, Error, write);

    pub fn init(byte: u8) FindByteOutStream {
        return FindByteOutStream{
            .byte = byte,
            .byte_found = false,
        };
    }

    pub fn write(self: *FindByteOutStream, bytes: []const u8) Error!usize {
        if (self.byte_found) return bytes.len;
        self.byte_found = blk: {
            for (bytes) |b|
                if (b == self.byte) break :blk true;
            break :blk false;
        };
        return bytes.len;
    }

    pub fn outStream(self: *FindByteOutStream) OutStream {
        return .{ .context = self };
    }
};

fn copyFixingWhitespace(stream: anytype, slice: []const u8) @TypeOf(stream).Error!void {
    for (slice) |byte| switch (byte) {
        '\t' => try stream.writeAll("    "),
        '\r' => {},
        else => try stream.writeByte(byte),
    };
}
