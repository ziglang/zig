const std = @import("../index.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const ast = std.zig.ast;
const Token = std.zig.Token;

const indent_delta = 4;

pub const Error = error{
    /// Ran out of memory allocating call stack frames to complete rendering.
    OutOfMemory,
};

pub fn render(allocator: &mem.Allocator, stream: var, tree: &ast.Tree) (@typeOf(stream).Child.Error || Error)!void {
    comptime assert(@typeId(@typeOf(stream)) == builtin.TypeId.Pointer);

    var it = tree.root_node.decls.iterator(0);
    while (it.next()) |decl| {
        try renderTopLevelDecl(allocator, stream, tree, 0, decl.*);
        if (it.peek()) |next_decl| {
            const n = if (nodeLineOffset(tree, decl.*, next_decl.*) >= 2) u8(2) else u8(1);
            try stream.writeByteNTimes('\n', n);
        }
    }
    try stream.write("\n");
}

fn nodeLineOffset(tree: &ast.Tree, a: &ast.Node, b: &ast.Node) usize {
    const a_last_token = tree.tokens.at(a.lastToken());
    const loc = tree.tokenLocation(a_last_token.end, b.firstToken());
    return loc.line;
}

fn renderTopLevelDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, decl: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (decl.id) {
        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

            try renderComments(tree, stream, fn_proto, indent);
            try renderExpression(allocator, stream, tree, indent, decl);

            if (fn_proto.body_node) |body_node| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, body_node);
            } else {
                try stream.write(";");
            }
        },
        ast.Node.Id.Use => {
            const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);

            if (use_decl.visib_token) |visib_token| {
                try stream.print("{} ", tree.tokenSlice(visib_token));
            }
            try stream.write("use ");
            try renderExpression(allocator, stream, tree, indent, use_decl.expr);
            try stream.write(";");
        },
        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);

            try renderComments(tree, stream, var_decl, indent);
            try renderVarDecl(allocator, stream, tree, indent, var_decl);
        },
        ast.Node.Id.TestDecl => {
            const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);

            try renderComments(tree, stream, test_decl, indent);
            try stream.write("test ");
            try renderExpression(allocator, stream, tree, indent, test_decl.name);
            try stream.write(" ");
            try renderExpression(allocator, stream, tree, indent, test_decl.body_node);
        },
        ast.Node.Id.StructField => {
            const field = @fieldParentPtr(ast.Node.StructField, "base", decl);

            try renderComments(tree, stream, field, indent);
            if (field.visib_token) |visib_token| {
                try stream.print("{} ", tree.tokenSlice(visib_token));
            }
            try stream.print("{}: ", tree.tokenSlice(field.name_token));
            try renderExpression(allocator, stream, tree, indent, field.type_expr);
            try renderToken(tree, stream, field.lastToken() + 1, indent, true, true);
        },
        ast.Node.Id.UnionTag => {
            const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);

            try renderComments(tree, stream, tag, indent);
            try stream.print("{}", tree.tokenSlice(tag.name_token));

            if (tag.type_expr) |type_expr| {
                try stream.print(": ");
                try renderExpression(allocator, stream, tree, indent, type_expr);
            }

            if (tag.value_expr) |value_expr| {
                try stream.print(" = ");
                try renderExpression(allocator, stream, tree, indent, value_expr);
            }

            try stream.write(",");
        },
        ast.Node.Id.EnumTag => {
            const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);

            try renderComments(tree, stream, tag, indent);
            try stream.print("{}", tree.tokenSlice(tag.name_token));

            if (tag.value) |value| {
                try stream.print(" = ");
                try renderExpression(allocator, stream, tree, indent, value);
            }

            try stream.write(",");
        },
        ast.Node.Id.ErrorTag => {
            const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", decl);

            try renderComments(tree, stream, tag, indent);
            try stream.print("{}", tree.tokenSlice(tag.name_token));
        },
        ast.Node.Id.Comptime => {
            try renderExpression(allocator, stream, tree, indent, decl);
            try maybeRenderSemicolon(stream, tree, indent, decl);
        },
        ast.Node.Id.LineComment => {
            const line_comment_node = @fieldParentPtr(ast.Node.LineComment, "base", decl);

            try stream.write(tree.tokenSlice(line_comment_node.token));
        },
        else => unreachable,
    }
}

fn renderExpression(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.Identifier => {
            const identifier = @fieldParentPtr(ast.Node.Identifier, "base", base);
            try stream.print("{}", tree.tokenSlice(identifier.token));
        },
        ast.Node.Id.Block => {
            const block = @fieldParentPtr(ast.Node.Block, "base", base);
            if (block.label) |label| {
                try stream.print("{}: ", tree.tokenSlice(label));
            }

            if (block.statements.len == 0) {
                try stream.write("{}");
            } else {
                try stream.write("{\n");
                const block_indent = indent + indent_delta;

                var it = block.statements.iterator(0);
                while (it.next()) |statement| {
                    try stream.writeByteNTimes(' ', block_indent);
                    try renderStatement(allocator, stream, tree, block_indent, statement.*);

                    if (it.peek()) |next_statement| {
                        const n = if (nodeLineOffset(tree, statement.*, next_statement.*) >= 2) u8(2) else u8(1);
                        try stream.writeByteNTimes('\n', n);
                    }
                }

                try stream.write("\n");
                try stream.writeByteNTimes(' ', indent);
                try stream.write("}");
            }
        },
        ast.Node.Id.Defer => {
            const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);
            try stream.print("{} ", tree.tokenSlice(defer_node.defer_token));
            try renderExpression(allocator, stream, tree, indent, defer_node.expr);
        },
        ast.Node.Id.Comptime => {
            const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);
            try stream.print("{} ", tree.tokenSlice(comptime_node.comptime_token));
            try renderExpression(allocator, stream, tree, indent, comptime_node.expr);
        },
        ast.Node.Id.AsyncAttribute => {
            const async_attr = @fieldParentPtr(ast.Node.AsyncAttribute, "base", base);
            try stream.print("{}", tree.tokenSlice(async_attr.async_token));

            if (async_attr.allocator_type) |allocator_type| {
                try stream.write("<");
                try renderExpression(allocator, stream, tree, indent, allocator_type);
                try stream.write(">");
            }
        },
        ast.Node.Id.Suspend => {
            const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);
            if (suspend_node.label) |label| {
                try stream.print("{}: ", tree.tokenSlice(label));
            }
            try stream.print("{}", tree.tokenSlice(suspend_node.suspend_token));

            if (suspend_node.payload) |payload| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, payload);
            }

            if (suspend_node.body) |body| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, body);
            }
        },

        ast.Node.Id.InfixOp => {
            const infix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);

            try renderExpression(allocator, stream, tree, indent, infix_op_node.lhs);

            const text = switch (infix_op_node.op) {
                ast.Node.InfixOp.Op.Add => " + ",
                ast.Node.InfixOp.Op.AddWrap => " +% ",
                ast.Node.InfixOp.Op.ArrayCat => " ++ ",
                ast.Node.InfixOp.Op.ArrayMult => " ** ",
                ast.Node.InfixOp.Op.Assign => " = ",
                ast.Node.InfixOp.Op.AssignBitAnd => " &= ",
                ast.Node.InfixOp.Op.AssignBitOr => " |= ",
                ast.Node.InfixOp.Op.AssignBitShiftLeft => " <<= ",
                ast.Node.InfixOp.Op.AssignBitShiftRight => " >>= ",
                ast.Node.InfixOp.Op.AssignBitXor => " ^= ",
                ast.Node.InfixOp.Op.AssignDiv => " /= ",
                ast.Node.InfixOp.Op.AssignMinus => " -= ",
                ast.Node.InfixOp.Op.AssignMinusWrap => " -%= ",
                ast.Node.InfixOp.Op.AssignMod => " %= ",
                ast.Node.InfixOp.Op.AssignPlus => " += ",
                ast.Node.InfixOp.Op.AssignPlusWrap => " +%= ",
                ast.Node.InfixOp.Op.AssignTimes => " *= ",
                ast.Node.InfixOp.Op.AssignTimesWarp => " *%= ",
                ast.Node.InfixOp.Op.BangEqual => " != ",
                ast.Node.InfixOp.Op.BitAnd => " & ",
                ast.Node.InfixOp.Op.BitOr => " | ",
                ast.Node.InfixOp.Op.BitShiftLeft => " << ",
                ast.Node.InfixOp.Op.BitShiftRight => " >> ",
                ast.Node.InfixOp.Op.BitXor => " ^ ",
                ast.Node.InfixOp.Op.BoolAnd => " and ",
                ast.Node.InfixOp.Op.BoolOr => " or ",
                ast.Node.InfixOp.Op.Div => " / ",
                ast.Node.InfixOp.Op.EqualEqual => " == ",
                ast.Node.InfixOp.Op.ErrorUnion => "!",
                ast.Node.InfixOp.Op.GreaterOrEqual => " >= ",
                ast.Node.InfixOp.Op.GreaterThan => " > ",
                ast.Node.InfixOp.Op.LessOrEqual => " <= ",
                ast.Node.InfixOp.Op.LessThan => " < ",
                ast.Node.InfixOp.Op.MergeErrorSets => " || ",
                ast.Node.InfixOp.Op.Mod => " % ",
                ast.Node.InfixOp.Op.Mult => " * ",
                ast.Node.InfixOp.Op.MultWrap => " *% ",
                ast.Node.InfixOp.Op.Period => ".",
                ast.Node.InfixOp.Op.Sub => " - ",
                ast.Node.InfixOp.Op.SubWrap => " -% ",
                ast.Node.InfixOp.Op.UnwrapMaybe => " ?? ",
                ast.Node.InfixOp.Op.Range => " ... ",
                ast.Node.InfixOp.Op.Catch => |maybe_payload| blk: {
                    try stream.write(" catch ");
                    if (maybe_payload) |payload| {
                        try renderExpression(allocator, stream, tree, indent, payload);
                        try stream.write(" ");
                    }
                    break :blk "";
                },
            };

            try stream.write(text);
            try renderExpression(allocator, stream, tree, indent, infix_op_node.rhs);
        },

        ast.Node.Id.PrefixOp => {
            const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);

            switch (prefix_op_node.op) {
                ast.Node.PrefixOp.Op.AddrOf => |addr_of_info| {
                    try stream.write("&");
                    if (addr_of_info.align_expr) |align_expr| {
                        try stream.write("align(");
                        try renderExpression(allocator, stream, tree, indent, align_expr);
                        try stream.write(") ");
                    }
                    if (addr_of_info.const_token != null) {
                        try stream.write("const ");
                    }
                    if (addr_of_info.volatile_token != null) {
                        try stream.write("volatile ");
                    }
                },
                ast.Node.PrefixOp.Op.SliceType => |addr_of_info| {
                    try stream.write("[]");
                    if (addr_of_info.align_expr) |align_expr| {
                        try stream.print("align(");
                        try renderExpression(allocator, stream, tree, indent, align_expr);
                        try stream.print(") ");
                    }
                    if (addr_of_info.const_token != null) {
                        try stream.print("const ");
                    }
                    if (addr_of_info.volatile_token != null) {
                        try stream.print("volatile ");
                    }
                },
                ast.Node.PrefixOp.Op.ArrayType => |array_index| {
                    try stream.print("[");
                    try renderExpression(allocator, stream, tree, indent, array_index);
                    try stream.print("]");
                },
                ast.Node.PrefixOp.Op.BitNot => try stream.write("~"),
                ast.Node.PrefixOp.Op.BoolNot => try stream.write("!"),
                ast.Node.PrefixOp.Op.Negation => try stream.write("-"),
                ast.Node.PrefixOp.Op.NegationWrap => try stream.write("-%"),
                ast.Node.PrefixOp.Op.Try => try stream.write("try "),
                ast.Node.PrefixOp.Op.UnwrapMaybe => try stream.write("??"),
                ast.Node.PrefixOp.Op.MaybeType => try stream.write("?"),
                ast.Node.PrefixOp.Op.Await => try stream.write("await "),
                ast.Node.PrefixOp.Op.Cancel => try stream.write("cancel "),
                ast.Node.PrefixOp.Op.Resume => try stream.write("resume "),
            }

            try renderExpression(allocator, stream, tree, indent, prefix_op_node.rhs);
        },

        ast.Node.Id.SuffixOp => {
            const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

            switch (suffix_op.op) {
                @TagType(ast.Node.SuffixOp.Op).Call => |*call_info| {
                    if (call_info.async_attr) |async_attr| {
                        try renderExpression(allocator, stream, tree, indent, &async_attr.base);
                        try stream.write(" ");
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                    try stream.write("(");

                    var it = call_info.params.iterator(0);
                    while (it.next()) |param_node| {
                        try renderExpression(allocator, stream, tree, indent, param_node.*);
                        if (it.peek() != null) {
                            try stream.write(", ");
                        }
                    }

                    try stream.write(")");
                },

                ast.Node.SuffixOp.Op.ArrayAccess => |index_expr| {
                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                    try stream.write("[");
                    try renderExpression(allocator, stream, tree, indent, index_expr);
                    try stream.write("]");
                },

                ast.Node.SuffixOp.Op.SuffixOp => {
                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                    try stream.write(".*");
                },

                @TagType(ast.Node.SuffixOp.Op).Slice => |range| {
                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                    try stream.write("[");
                    try renderExpression(allocator, stream, tree, indent, range.start);
                    try stream.write("..");
                    if (range.end) |end| {
                        try renderExpression(allocator, stream, tree, indent, end);
                    }
                    try stream.write("]");
                },

                ast.Node.SuffixOp.Op.StructInitializer => |*field_inits| {
                    if (field_inits.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                        try stream.write("{}");
                        return;
                    }

                    if (field_inits.len == 1) {
                        const field_init = field_inits.at(0).*;

                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                        try stream.write("{ ");
                        try renderExpression(allocator, stream, tree, indent, field_init);
                        try stream.write(" }");
                        return;
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                    try stream.write("{\n");

                    const new_indent = indent + indent_delta;

                    var it = field_inits.iterator(0);
                    while (it.next()) |field_init| {
                        try stream.writeByteNTimes(' ', new_indent);
                        try renderExpression(allocator, stream, tree, new_indent, field_init.*);
                        if ((field_init.*).id != ast.Node.Id.LineComment) {
                            try stream.write(",");
                        }
                        if (it.peek()) |next_field_init| {
                            const n = if (nodeLineOffset(tree, field_init.*, next_field_init.*) >= 2) u8(2) else u8(1);
                            try stream.writeByteNTimes('\n', n);
                        }
                    }

                    try stream.write("\n");
                    try stream.writeByteNTimes(' ', indent);
                    try stream.write("}");
                },

                ast.Node.SuffixOp.Op.ArrayInitializer => |*exprs| {
                    if (exprs.len == 0) {
                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                        try stream.write("{}");
                        return;
                    }
                    if (exprs.len == 1) {
                        const expr = exprs.at(0).*;

                        try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);
                        try stream.write("{");
                        try renderExpression(allocator, stream, tree, indent, expr);
                        try stream.write("}");
                        return;
                    }

                    try renderExpression(allocator, stream, tree, indent, suffix_op.lhs);

                    const new_indent = indent + indent_delta;
                    try stream.write("{\n");

                    var it = exprs.iterator(0);
                    while (it.next()) |expr| {
                        try stream.writeByteNTimes(' ', new_indent);
                        try renderExpression(allocator, stream, tree, new_indent, expr.*);
                        try stream.write(",");

                        if (it.peek()) |next_expr| {
                            const n = if (nodeLineOffset(tree, expr.*, next_expr.*) >= 2) u8(2) else u8(1);
                            try stream.writeByteNTimes('\n', n);
                        }
                    }

                    try stream.write("\n");
                    try stream.writeByteNTimes(' ', indent);
                    try stream.write("}");
                },
            }
        },

        ast.Node.Id.ControlFlowExpression => {
            const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

            switch (flow_expr.kind) {
                ast.Node.ControlFlowExpression.Kind.Break => |maybe_label| {
                    try stream.print("break");
                    if (maybe_label) |label| {
                        try stream.print(" :");
                        try renderExpression(allocator, stream, tree, indent, label);
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Continue => |maybe_label| {
                    try stream.print("continue");
                    if (maybe_label) |label| {
                        try stream.print(" :");
                        try renderExpression(allocator, stream, tree, indent, label);
                    }
                },
                ast.Node.ControlFlowExpression.Kind.Return => {
                    try stream.print("return");
                },
            }

            if (flow_expr.rhs) |rhs| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, rhs);
            }
        },

        ast.Node.Id.Payload => {
            const payload = @fieldParentPtr(ast.Node.Payload, "base", base);

            try stream.write("|");
            try renderExpression(allocator, stream, tree, indent, payload.error_symbol);
            try stream.write("|");
        },

        ast.Node.Id.PointerPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);

            try stream.write("|");
            if (payload.ptr_token) |ptr_token| {
                try stream.write(tree.tokenSlice(ptr_token));
            }
            try renderExpression(allocator, stream, tree, indent, payload.value_symbol);
            try stream.write("|");
        },

        ast.Node.Id.PointerIndexPayload => {
            const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);

            try stream.write("|");
            if (payload.ptr_token) |ptr_token| {
                try stream.write(tree.tokenSlice(ptr_token));
            }
            try renderExpression(allocator, stream, tree, indent, payload.value_symbol);

            if (payload.index_symbol) |index_symbol| {
                try stream.write(", ");
                try renderExpression(allocator, stream, tree, indent, index_symbol);
            }

            try stream.write("|");
        },

        ast.Node.Id.GroupedExpression => {
            const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);

            try renderToken(tree, stream, grouped_expr.lparen, indent, false, false);
            try renderExpression(allocator, stream, tree, indent, grouped_expr.expr);
            try renderToken(tree, stream, grouped_expr.rparen, indent, false, false);
        },

        ast.Node.Id.FieldInitializer => {
            const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);

            try stream.print(".{} = ", tree.tokenSlice(field_init.name_token));
            try renderExpression(allocator, stream, tree, indent, field_init.expr);
        },

        ast.Node.Id.IntegerLiteral => {
            const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
            try renderToken(tree, stream, integer_literal.token, indent, false, false);
        },
        ast.Node.Id.FloatLiteral => {
            const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(float_literal.token));
        },
        ast.Node.Id.StringLiteral => {
            const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
            try renderToken(tree, stream, string_literal.token, indent, false, false);
        },
        ast.Node.Id.CharLiteral => {
            const char_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(char_literal.token));
        },
        ast.Node.Id.BoolLiteral => {
            const bool_literal = @fieldParentPtr(ast.Node.CharLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(bool_literal.token));
        },
        ast.Node.Id.NullLiteral => {
            const null_literal = @fieldParentPtr(ast.Node.NullLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(null_literal.token));
        },
        ast.Node.Id.ThisLiteral => {
            const this_literal = @fieldParentPtr(ast.Node.ThisLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(this_literal.token));
        },
        ast.Node.Id.Unreachable => {
            const unreachable_node = @fieldParentPtr(ast.Node.Unreachable, "base", base);
            try stream.print("{}", tree.tokenSlice(unreachable_node.token));
        },
        ast.Node.Id.ErrorType => {
            const error_type = @fieldParentPtr(ast.Node.ErrorType, "base", base);
            try stream.print("{}", tree.tokenSlice(error_type.token));
        },
        ast.Node.Id.VarType => {
            const var_type = @fieldParentPtr(ast.Node.VarType, "base", base);
            try stream.print("{}", tree.tokenSlice(var_type.token));
        },
        ast.Node.Id.ContainerDecl => {
            const container_decl = @fieldParentPtr(ast.Node.ContainerDecl, "base", base);

            switch (container_decl.layout) {
                ast.Node.ContainerDecl.Layout.Packed => try stream.print("packed "),
                ast.Node.ContainerDecl.Layout.Extern => try stream.print("extern "),
                ast.Node.ContainerDecl.Layout.Auto => {},
            }

            switch (container_decl.kind) {
                ast.Node.ContainerDecl.Kind.Struct => try stream.print("struct"),
                ast.Node.ContainerDecl.Kind.Enum => try stream.print("enum"),
                ast.Node.ContainerDecl.Kind.Union => try stream.print("union"),
            }

            switch (container_decl.init_arg_expr) {
                ast.Node.ContainerDecl.InitArg.None => try stream.write(" "),
                ast.Node.ContainerDecl.InitArg.Enum => |enum_tag_type| {
                    if (enum_tag_type) |expr| {
                        try stream.write("(enum(");
                        try renderExpression(allocator, stream, tree, indent, expr);
                        try stream.write(")) ");
                    } else {
                        try stream.write("(enum) ");
                    }
                },
                ast.Node.ContainerDecl.InitArg.Type => |type_expr| {
                    try stream.write("(");
                    try renderExpression(allocator, stream, tree, indent, type_expr);
                    try stream.write(") ");
                },
            }

            if (container_decl.fields_and_decls.len == 0) {
                try stream.write("{}");
            } else {
                try stream.write("{\n");
                const new_indent = indent + indent_delta;

                var it = container_decl.fields_and_decls.iterator(0);
                while (it.next()) |decl| {
                    try stream.writeByteNTimes(' ', new_indent);
                    try renderTopLevelDecl(allocator, stream, tree, new_indent, decl.*);

                    if (it.peek()) |next_decl| {
                        const n = if (nodeLineOffset(tree, decl.*, next_decl.*) >= 2) u8(2) else u8(1);
                        try stream.writeByteNTimes('\n', n);
                    }
                }

                try stream.write("\n");
                try stream.writeByteNTimes(' ', indent);
                try stream.write("}");
            }
        },

        ast.Node.Id.ErrorSetDecl => {
            const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

            if (err_set_decl.decls.len == 0) {
                try stream.write("error{}");
                return;
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

                try stream.write("error{");
                try renderTopLevelDecl(allocator, stream, tree, indent, node);
                try stream.write("}");
                return;
            }

            try stream.write("error{\n");
            const new_indent = indent + indent_delta;

            var it = err_set_decl.decls.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);
                try renderTopLevelDecl(allocator, stream, tree, new_indent, node.*);
                if ((node.*).id != ast.Node.Id.LineComment) {
                    try stream.write(",");
                }
                if (it.peek()) |next_node| {
                    const n = if (nodeLineOffset(tree, node.*, next_node.*) >= 2) u8(2) else u8(1);
                    try stream.writeByteNTimes('\n', n);
                }
            }

            try stream.write("\n");
            try stream.writeByteNTimes(' ', indent);
            try stream.write("}");
        },

        ast.Node.Id.MultilineStringLiteral => {
            const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);
            try stream.print("\n");

            var i: usize = 0;
            while (i < multiline_str_literal.lines.len) : (i += 1) {
                const t = multiline_str_literal.lines.at(i).*;
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try stream.print("{}", tree.tokenSlice(t));
            }
            try stream.writeByteNTimes(' ', indent);
        },
        ast.Node.Id.UndefinedLiteral => {
            const undefined_literal = @fieldParentPtr(ast.Node.UndefinedLiteral, "base", base);
            try stream.print("{}", tree.tokenSlice(undefined_literal.token));
        },

        ast.Node.Id.BuiltinCall => {
            const builtin_call = @fieldParentPtr(ast.Node.BuiltinCall, "base", base);
            try stream.print("{}(", tree.tokenSlice(builtin_call.builtin_token));

            var it = builtin_call.params.iterator(0);
            while (it.next()) |param_node| {
                try renderExpression(allocator, stream, tree, indent, param_node.*);
                if (it.peek() != null) {
                    try stream.write(", ");
                }
            }
            try stream.write(")");
        },

        ast.Node.Id.FnProto => {
            const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

            if (fn_proto.visib_token) |visib_token_index| {
                const visib_token = tree.tokens.at(visib_token_index);
                assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);
                try stream.print("{} ", tree.tokenSlice(visib_token_index));
            }

            if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                try stream.print("{} ", tree.tokenSlice(extern_export_inline_token));
            }

            if (fn_proto.lib_name) |lib_name| {
                try renderExpression(allocator, stream, tree, indent, lib_name);
                try stream.write(" ");
            }

            if (fn_proto.cc_token) |cc_token| {
                try stream.print("{} ", tree.tokenSlice(cc_token));
            }

            if (fn_proto.async_attr) |async_attr| {
                try renderExpression(allocator, stream, tree, indent, &async_attr.base);
                try stream.write(" ");
            }

            try stream.write("fn");

            if (fn_proto.name_token) |name_token| {
                try stream.print(" {}", tree.tokenSlice(name_token));
            }

            try stream.write("(");

            var it = fn_proto.params.iterator(0);
            while (it.next()) |param_decl_node| {
                try renderParamDecl(allocator, stream, tree, indent, param_decl_node.*);

                if (it.peek() != null) {
                    try stream.write(", ");
                }
            }

            try stream.write(") ");

            if (fn_proto.align_expr) |align_expr| {
                try stream.write("align(");
                try renderExpression(allocator, stream, tree, indent, align_expr);
                try stream.write(") ");
            }

            switch (fn_proto.return_type) {
                ast.Node.FnProto.ReturnType.Explicit => |node| {
                    try renderExpression(allocator, stream, tree, indent, node);
                },
                ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
                    try stream.write("!");
                    try renderExpression(allocator, stream, tree, indent, node);
                },
            }
        },

        ast.Node.Id.PromiseType => {
            const promise_type = @fieldParentPtr(ast.Node.PromiseType, "base", base);
            try stream.write(tree.tokenSlice(promise_type.promise_token));
            if (promise_type.result) |result| {
                try stream.write(tree.tokenSlice(result.arrow_token));
                try renderExpression(allocator, stream, tree, indent, result.return_type);
            }
        },

        ast.Node.Id.LineComment => {
            const line_comment_node = @fieldParentPtr(ast.Node.LineComment, "base", base);
            try stream.write(tree.tokenSlice(line_comment_node.token));
        },

        ast.Node.Id.DocComment => unreachable, // doc comments are attached to nodes

        ast.Node.Id.Switch => {
            const switch_node = @fieldParentPtr(ast.Node.Switch, "base", base);

            try stream.print("{} (", tree.tokenSlice(switch_node.switch_token));
            if (switch_node.cases.len == 0) {
                try renderExpression(allocator, stream, tree, indent, switch_node.expr);
                try stream.write(") {}");
                return;
            }

            try renderExpression(allocator, stream, tree, indent, switch_node.expr);
            try stream.write(") {\n");

            const new_indent = indent + indent_delta;

            var it = switch_node.cases.iterator(0);
            while (it.next()) |node| {
                try stream.writeByteNTimes(' ', new_indent);
                try renderExpression(allocator, stream, tree, new_indent, node.*);

                if (it.peek()) |next_node| {
                    const n = if (nodeLineOffset(tree, node.*, next_node.*) >= 2) u8(2) else u8(1);
                    try stream.writeByteNTimes('\n', n);
                }
            }

            try stream.write("\n");
            try stream.writeByteNTimes(' ', indent);
            try stream.write("}");
        },

        ast.Node.Id.SwitchCase => {
            const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

            var it = switch_case.items.iterator(0);
            while (it.next()) |node| {
                try renderExpression(allocator, stream, tree, indent, node.*);

                if (it.peek() != null) {
                    try stream.write(",\n");
                    try stream.writeByteNTimes(' ', indent);
                }
            }

            try stream.write(" => ");

            if (switch_case.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload);
                try stream.write(" ");
            }

            try renderExpression(allocator, stream, tree, indent, switch_case.expr);
            {
                // Handle missing comma after last switch case
                var index = switch_case.lastToken() + 1;
                switch (tree.tokens.at(index).id) {
                    Token.Id.RBrace => {
                        try stream.write(",");
                    },
                    Token.Id.LineComment => {
                        try stream.write(", ");
                        try renderToken(tree, stream, index, indent, true, true);
                    },
                    else => try renderToken(tree, stream, index, indent, true, true),
                }
            }
        },
        ast.Node.Id.SwitchElse => {
            const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
            try stream.print("{}", tree.tokenSlice(switch_else.token));
        },
        ast.Node.Id.Else => {
            const else_node = @fieldParentPtr(ast.Node.Else, "base", base);

            var prev_tok_index = else_node.else_token - 1;
            while (tree.tokens.at(prev_tok_index).id == Token.Id.LineComment) : (prev_tok_index -= 1) { }
            prev_tok_index += 1;
            while (prev_tok_index < else_node.else_token) : (prev_tok_index += 1) {
                try stream.print("{}\n", tree.tokenSlice(prev_tok_index));
                try stream.writeByteNTimes(' ', indent);
            }

            try stream.print("{}", tree.tokenSlice(else_node.else_token));

            const block_body = switch (else_node.body.id) {
                ast.Node.Id.Block,
                ast.Node.Id.If,
                ast.Node.Id.For,
                ast.Node.Id.While,
                ast.Node.Id.Switch => true,
                else => false,
            };

            if (block_body) {
                try stream.write(" ");
            }

            if (else_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload);
                try stream.write(" ");
            }

            if (block_body) {
                try renderExpression(allocator, stream, tree, indent, else_node.body);
            } else {
                try stream.write("\n");
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, else_node.body);
            }
        },

        ast.Node.Id.While => {
            const while_node = @fieldParentPtr(ast.Node.While, "base", base);

            if (while_node.label) |label| {
                try stream.print("{}: ", tree.tokenSlice(label));
            }

            if (while_node.inline_token) |inline_token| {
                try stream.print("{} ", tree.tokenSlice(inline_token));
            }

            try stream.print("{} (", tree.tokenSlice(while_node.while_token));
            try renderExpression(allocator, stream, tree, indent, while_node.condition);
            try stream.write(")");

            if (while_node.payload) |payload| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, payload);
            }

            if (while_node.continue_expr) |continue_expr| {
                try stream.write(" : (");
                try renderExpression(allocator, stream, tree, indent, continue_expr);
                try stream.write(")");
            }

            if (while_node.body.id == ast.Node.Id.Block) {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, while_node.body);
            } else {
                try stream.write("\n");
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, while_node.body);
            }

            if (while_node.@"else") |@"else"| {
                if (while_node.body.id == ast.Node.Id.Block) {
                    try stream.write(" ");
                } else {
                    try stream.write("\n");
                    try stream.writeByteNTimes(' ', indent);
                }

                try renderExpression(allocator, stream, tree, indent, &@"else".base);
            }
        },

        ast.Node.Id.For => {
            const for_node = @fieldParentPtr(ast.Node.For, "base", base);
            if (for_node.label) |label| {
                try stream.print("{}: ", tree.tokenSlice(label));
            }

            if (for_node.inline_token) |inline_token| {
                try stream.print("{} ", tree.tokenSlice(inline_token));
            }

            try stream.print("{} (", tree.tokenSlice(for_node.for_token));
            try renderExpression(allocator, stream, tree, indent, for_node.array_expr);
            try stream.write(")");

            if (for_node.payload) |payload| {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, payload);
            }

            if (for_node.body.id == ast.Node.Id.Block) {
                try stream.write(" ");
                try renderExpression(allocator, stream, tree, indent, for_node.body);
            } else {
                try stream.write("\n");
                try stream.writeByteNTimes(' ', indent + indent_delta);
                try renderExpression(allocator, stream, tree, indent, for_node.body);
            }

            if (for_node.@"else") |@"else"| {
                if (for_node.body.id == ast.Node.Id.Block) {
                    try stream.write(" ");
                } else {
                    try stream.write("\n");
                    try stream.writeByteNTimes(' ', indent);
                }

                try renderExpression(allocator, stream, tree, indent, &@"else".base);
            }
        },

        ast.Node.Id.If => {
            const if_node = @fieldParentPtr(ast.Node.If, "base", base);
            try stream.print("{} (", tree.tokenSlice(if_node.if_token));

            try renderExpression(allocator, stream, tree, indent, if_node.condition);
            try renderToken(tree, stream, if_node.condition.lastToken() + 1, indent, false, true);

            if (if_node.payload) |payload| {
                try renderExpression(allocator, stream, tree, indent, payload);
                try stream.write(" ");
            }

            try renderExpression(allocator, stream, tree, indent, if_node.body);

            switch (if_node.body.id) {
                ast.Node.Id.Block,
                ast.Node.Id.If,
                ast.Node.Id.For,
                ast.Node.Id.While,
                ast.Node.Id.Switch => {
                    if (if_node.@"else") |@"else"| {
                        if (if_node.body.id == ast.Node.Id.Block) {
                            try stream.write(" ");
                        } else {
                            try stream.write("\n");
                            try stream.writeByteNTimes(' ', indent);
                        }

                        try renderExpression(allocator, stream, tree, indent, &@"else".base);
                    }
                },
                else => {
                    if (if_node.@"else") |@"else"| {
                        try stream.print(" {} ", tree.tokenSlice(@"else".else_token));

                        if (@"else".payload) |payload| {
                            try renderExpression(allocator, stream, tree, indent, payload);
                            try stream.write(" ");
                        }

                        try renderExpression(allocator, stream, tree, indent, @"else".body);
                    }
                },
            }
        },

        ast.Node.Id.Asm => {
            const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);
            try stream.print("{} ", tree.tokenSlice(asm_node.asm_token));

            if (asm_node.volatile_token) |volatile_token| {
                try stream.print("{} ", tree.tokenSlice(volatile_token));
            }

            try stream.print("(");
            try renderExpression(allocator, stream, tree, indent, asm_node.template);
            try stream.print("\n");
            const indent_once = indent + indent_delta;
            try stream.writeByteNTimes(' ', indent_once);
            try stream.print(": ");
            const indent_extra = indent_once + 2;

            {
                var it = asm_node.outputs.iterator(0);
                while (it.next()) |asm_output| {
                    const node = &(asm_output.*).base;
                    try renderExpression(allocator, stream, tree, indent_extra, node);

                    if (it.peek()) |next_asm_output| {
                        const next_node = &(next_asm_output.*).base;
                        const n = if (nodeLineOffset(tree, node, next_node) >= 2) u8(2) else u8(1);
                        try stream.writeByte(',');
                        try stream.writeByteNTimes('\n', n);
                        try stream.writeByteNTimes(' ', indent_extra);
                    }
                }
            }

            try stream.write("\n");
            try stream.writeByteNTimes(' ', indent_once);
            try stream.write(": ");

            {
                var it = asm_node.inputs.iterator(0);
                while (it.next()) |asm_input| {
                    const node = &(asm_input.*).base;
                    try renderExpression(allocator, stream, tree, indent_extra, node);

                    if (it.peek()) |next_asm_input| {
                        const next_node = &(next_asm_input.*).base;
                        const n = if (nodeLineOffset(tree, node, next_node) >= 2) u8(2) else u8(1);
                        try stream.writeByte(',');
                        try stream.writeByteNTimes('\n', n);
                        try stream.writeByteNTimes(' ', indent_extra);
                    }
                }
            }

            try stream.write("\n");
            try stream.writeByteNTimes(' ', indent_once);
            try stream.write(": ");

            {
                var it = asm_node.clobbers.iterator(0);
                while (it.next()) |node| {
                    try renderExpression(allocator, stream, tree, indent_once, node.*);

                    if (it.peek() != null) {
                        try stream.write(", ");
                    }
                }
            }

            try stream.write(")");
        },

        ast.Node.Id.AsmInput => {
            const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, asm_input.symbolic_name);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, asm_input.constraint);
            try stream.write(" (");
            try renderExpression(allocator, stream, tree, indent, asm_input.expr);
            try stream.write(")");
        },

        ast.Node.Id.AsmOutput => {
            const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

            try stream.write("[");
            try renderExpression(allocator, stream, tree, indent, asm_output.symbolic_name);
            try stream.write("] ");
            try renderExpression(allocator, stream, tree, indent, asm_output.constraint);
            try stream.write(" (");

            switch (asm_output.kind) {
                ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                    try renderExpression(allocator, stream, tree, indent, &variable_name.base);
                },
                ast.Node.AsmOutput.Kind.Return => |return_type| {
                    try stream.write("-> ");
                    try renderExpression(allocator, stream, tree, indent, return_type);
                },
            }

            try stream.write(")");
        },

        ast.Node.Id.StructField,
        ast.Node.Id.UnionTag,
        ast.Node.Id.EnumTag,
        ast.Node.Id.ErrorTag,
        ast.Node.Id.Root,
        ast.Node.Id.VarDecl,
        ast.Node.Id.Use,
        ast.Node.Id.TestDecl,
        ast.Node.Id.ParamDecl => unreachable,
    }
}

fn renderVarDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, var_decl: &ast.Node.VarDecl) (@typeOf(stream).Child.Error || Error)!void {
    if (var_decl.visib_token) |visib_token| {
        try renderToken(tree, stream, visib_token, indent, false, true);
    }

    if (var_decl.extern_export_token) |extern_export_token| {
        try renderToken(tree, stream, extern_export_token, indent, false, true);

        if (var_decl.lib_name) |lib_name| {
            try renderExpression(allocator, stream, tree, indent, lib_name);
            try stream.write(" ");
        }
    }

    if (var_decl.comptime_token) |comptime_token| {
        try renderToken(tree, stream, comptime_token, indent, false, true);
    }

    try renderToken(tree, stream, var_decl.mut_token, indent, false, true);
    try renderToken(tree, stream, var_decl.name_token, indent, false, false);

    if (var_decl.type_node) |type_node| {
        try stream.write(": ");
        try renderExpression(allocator, stream, tree, indent, type_node);
    }

    if (var_decl.align_node) |align_node| {
        try stream.write(" align(");
        try renderExpression(allocator, stream, tree, indent, align_node);
        try stream.write(")");
    }

    if (var_decl.init_node) |init_node| {
        const text = if (init_node.id == ast.Node.Id.MultilineStringLiteral) " =" else " = ";
        try stream.write(text);
        try renderExpression(allocator, stream, tree, indent, init_node);
    }

    try renderToken(tree, stream, var_decl.semicolon_token, indent, true, false);
}

fn maybeRenderSemicolon(stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    if (base.requireSemiColon()) {
        const semicolon_index = base.lastToken() + 1;
        assert(tree.tokens.at(semicolon_index).id == Token.Id.Semicolon);
        try renderToken(tree, stream, semicolon_index, indent, true, true);
    }
}

fn renderParamDecl(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", base);
    if (param_decl.comptime_token) |comptime_token| {
        try stream.print("{} ", tree.tokenSlice(comptime_token));
    }
    if (param_decl.noalias_token) |noalias_token| {
        try stream.print("{} ", tree.tokenSlice(noalias_token));
    }
    if (param_decl.name_token) |name_token| {
        try stream.print("{}: ", tree.tokenSlice(name_token));
    }
    if (param_decl.var_args_token) |var_args_token| {
        try stream.print("{}", tree.tokenSlice(var_args_token));
    } else {
        try renderExpression(allocator, stream, tree, indent, param_decl.type_node);
    }
}

fn renderStatement(allocator: &mem.Allocator, stream: var, tree: &ast.Tree, indent: usize, base: &ast.Node) (@typeOf(stream).Child.Error || Error)!void {
    switch (base.id) {
        ast.Node.Id.VarDecl => {
            const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
            try renderVarDecl(allocator, stream, tree, indent, var_decl);
        },
        else => {
            try renderExpression(allocator, stream, tree, indent, base);
            try maybeRenderSemicolon(stream, tree, indent, base);
        },
    }
}

fn renderToken(tree: &ast.Tree, stream: var, token_index: ast.TokenIndex, indent: usize, line_break: bool, space: bool) (@typeOf(stream).Child.Error || Error)!void {
    const token = tree.tokens.at(token_index);
    try stream.write(tree.tokenSlicePtr(token));

    const next_token = tree.tokens.at(token_index + 1);
    if (next_token.id == Token.Id.LineComment) {
        const loc = tree.tokenLocationPtr(token.end, next_token);
        if (loc.line == 0) {
            try stream.print(" {}", tree.tokenSlicePtr(next_token));
            if (!line_break) {
                try stream.write("\n");

                const after_comment_token = tree.tokens.at(token_index + 2);
                const next_line_indent = switch (after_comment_token.id) {
                    Token.Id.RParen, Token.Id.RBrace, Token.Id.RBracket => indent,
                    else => indent + indent_delta,
                };
                try stream.writeByteNTimes(' ', next_line_indent);
                return;
            }
        }
    }

    if (!line_break and space) {
        try stream.writeByte(' ');
    }
}

fn renderComments(tree: &ast.Tree, stream: var, node: var, indent: usize) (@typeOf(stream).Child.Error || Error)!void {
    const comment = node.doc_comments ?? return;
    var it = comment.lines.iterator(0);
    while (it.next()) |line_token_index| {
        try stream.print("{}\n", tree.tokenSlice(line_token_index.*));
        try stream.writeByteNTimes(' ', indent);
    }
}
