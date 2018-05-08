const std = @import("../index.zig");
const assert = std.debug.assert;
const SegmentedList = std.SegmentedList;
const mem = std.mem;
const ast = std.zig.ast;
const Token = std.zig.Token;

const RenderState = union(enum) {
    TopLevelDecl: &ast.Node,
    ParamDecl: &ast.Node,
    Text: []const u8,
    Expression: &ast.Node,
    VarDecl: &ast.Node.VarDecl,
    Statement: &ast.Node,
    PrintIndent,
    Indent: usize,
};

pub fn render(allocator: &mem.Allocator, stream: var, tree: &ast.Tree) !void {
    var stack = SegmentedList(RenderState, 32).init(allocator);
    defer stack.deinit();

    {
        try stack.push(RenderState { .Text = "\n"});

        var i = tree.root_node.decls.len;
        while (i != 0) {
            i -= 1;
            const decl = *tree.root_node.decls.at(i);
            try stack.push(RenderState {.TopLevelDecl = decl});
            if (i != 0) {
                try stack.push(RenderState {
                    .Text = blk: {
                        const prev_node = *tree.root_node.decls.at(i - 1);
                        const prev_node_last_token = tree.tokens.at(prev_node.lastToken());
                        const loc = tree.tokenLocation(prev_node_last_token.end, decl.firstToken());
                        if (loc.line >= 2) {
                            break :blk "\n\n";
                        }
                        break :blk "\n";
                    },
                });
            }
        }
    }

    const indent_delta = 4;
    var indent: usize = 0;
    while (stack.pop()) |state| {
        switch (state) {
            RenderState.TopLevelDecl => |decl| {
                switch (decl.id) {
                    ast.Node.Id.FnProto => {
                        const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);
                        try renderComments(tree, stream, fn_proto, indent);

                        if (fn_proto.body_node) |body_node| {
                            stack.push(RenderState { .Expression = body_node}) catch unreachable;
                            try stack.push(RenderState { .Text = " "});
                        } else {
                            stack.push(RenderState { .Text = ";" }) catch unreachable;
                        }

                        try stack.push(RenderState { .Expression = decl });
                    },
                    ast.Node.Id.Use => {
                        const use_decl = @fieldParentPtr(ast.Node.Use, "base", decl);
                        if (use_decl.visib_token) |visib_token| {
                            try stream.print("{} ", tree.tokenSlice(visib_token));
                        }
                        try stream.print("use ");
                        try stack.push(RenderState { .Text = ";" });
                        try stack.push(RenderState { .Expression = use_decl.expr });
                    },
                    ast.Node.Id.VarDecl => {
                        const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", decl);
                        try renderComments(tree, stream, var_decl, indent);
                        try stack.push(RenderState { .VarDecl = var_decl});
                    },
                    ast.Node.Id.TestDecl => {
                        const test_decl = @fieldParentPtr(ast.Node.TestDecl, "base", decl);
                        try renderComments(tree, stream, test_decl, indent);
                        try stream.print("test ");
                        try stack.push(RenderState { .Expression = test_decl.body_node });
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = test_decl.name });
                    },
                    ast.Node.Id.StructField => {
                        const field = @fieldParentPtr(ast.Node.StructField, "base", decl);
                        try renderComments(tree, stream, field, indent);
                        if (field.visib_token) |visib_token| {
                            try stream.print("{} ", tree.tokenSlice(visib_token));
                        }
                        try stream.print("{}: ", tree.tokenSlice(field.name_token));
                        try stack.push(RenderState { .Text = "," });
                        try stack.push(RenderState { .Expression = field.type_expr});
                    },
                    ast.Node.Id.UnionTag => {
                        const tag = @fieldParentPtr(ast.Node.UnionTag, "base", decl);
                        try renderComments(tree, stream, tag, indent);
                        try stream.print("{}", tree.tokenSlice(tag.name_token));

                        try stack.push(RenderState { .Text = "," });

                        if (tag.value_expr) |value_expr| {
                            try stack.push(RenderState { .Expression = value_expr });
                            try stack.push(RenderState { .Text = " = " });
                        }

                        if (tag.type_expr) |type_expr| {
                            try stream.print(": ");
                            try stack.push(RenderState { .Expression = type_expr});
                        }
                    },
                    ast.Node.Id.EnumTag => {
                        const tag = @fieldParentPtr(ast.Node.EnumTag, "base", decl);
                        try renderComments(tree, stream, tag, indent);
                        try stream.print("{}", tree.tokenSlice(tag.name_token));

                        try stack.push(RenderState { .Text = "," });
                        if (tag.value) |value| {
                            try stream.print(" = ");
                            try stack.push(RenderState { .Expression = value});
                        }
                    },
                    ast.Node.Id.ErrorTag => {
                        const tag = @fieldParentPtr(ast.Node.ErrorTag, "base", decl);
                        try renderComments(tree, stream, tag, indent);
                        try stream.print("{}", tree.tokenSlice(tag.name_token));
                    },
                    ast.Node.Id.Comptime => {
                        if (decl.requireSemiColon()) {
                            try stack.push(RenderState { .Text = ";" });
                        }
                        try stack.push(RenderState { .Expression = decl });
                    },
                    ast.Node.Id.LineComment => {
                        const line_comment_node = @fieldParentPtr(ast.Node.LineComment, "base", decl);
                        try stream.write(tree.tokenSlice(line_comment_node.token));
                    },
                    else => unreachable,
                }
            },

            RenderState.VarDecl => |var_decl| {
                try stack.push(RenderState { .Text = ";" });
                if (var_decl.init_node) |init_node| {
                    try stack.push(RenderState { .Expression = init_node });
                    const text = if (init_node.id == ast.Node.Id.MultilineStringLiteral) " =" else " = ";
                    try stack.push(RenderState { .Text = text });
                }
                if (var_decl.align_node) |align_node| {
                    try stack.push(RenderState { .Text = ")" });
                    try stack.push(RenderState { .Expression = align_node });
                    try stack.push(RenderState { .Text = " align(" });
                }
                if (var_decl.type_node) |type_node| {
                    try stack.push(RenderState { .Expression = type_node });
                    try stack.push(RenderState { .Text = ": " });
                }
                try stack.push(RenderState { .Text = tree.tokenSlice(var_decl.name_token) });
                try stack.push(RenderState { .Text = " " });
                try stack.push(RenderState { .Text = tree.tokenSlice(var_decl.mut_token) });

                if (var_decl.comptime_token) |comptime_token| {
                    try stack.push(RenderState { .Text = " " });
                    try stack.push(RenderState { .Text = tree.tokenSlice(comptime_token) });
                }

                if (var_decl.extern_export_token) |extern_export_token| {
                    if (var_decl.lib_name != null) {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = ??var_decl.lib_name });
                    }
                    try stack.push(RenderState { .Text = " " });
                    try stack.push(RenderState { .Text = tree.tokenSlice(extern_export_token) });
                }

                if (var_decl.visib_token) |visib_token| {
                    try stack.push(RenderState { .Text = " " });
                    try stack.push(RenderState { .Text = tree.tokenSlice(visib_token) });
                }
            },

            RenderState.ParamDecl => |base| {
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
                    try stack.push(RenderState { .Expression = param_decl.type_node});
                }
            },
            RenderState.Text => |bytes| {
                try stream.write(bytes);
            },
            RenderState.Expression => |base| switch (base.id) {
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
                        try stream.write("{");
                        try stack.push(RenderState { .Text = "}"});
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState { .Indent = indent});
                        try stack.push(RenderState { .Text = "\n"});
                        var i = block.statements.len;
                        while (i != 0) {
                            i -= 1;
                            const statement_node = *block.statements.at(i);
                            try stack.push(RenderState { .Statement = statement_node});
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Indent = indent + indent_delta});
                            try stack.push(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = *block.statements.at(i - 1);
                                        const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                        const loc = tree.tokenLocation(prev_node_last_token_end, statement_node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });
                        }
                    }
                },
                ast.Node.Id.Defer => {
                    const defer_node = @fieldParentPtr(ast.Node.Defer, "base", base);
                    try stream.print("{} ", tree.tokenSlice(defer_node.defer_token));
                    try stack.push(RenderState { .Expression = defer_node.expr });
                },
                ast.Node.Id.Comptime => {
                    const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", base);
                    try stream.print("{} ", tree.tokenSlice(comptime_node.comptime_token));
                    try stack.push(RenderState { .Expression = comptime_node.expr });
                },
                ast.Node.Id.AsyncAttribute => {
                    const async_attr = @fieldParentPtr(ast.Node.AsyncAttribute, "base", base);
                    try stream.print("{}", tree.tokenSlice(async_attr.async_token));

                    if (async_attr.allocator_type) |allocator_type| {
                        try stack.push(RenderState { .Text = ">" });
                        try stack.push(RenderState { .Expression = allocator_type });
                        try stack.push(RenderState { .Text = "<" });
                    }
                },
                ast.Node.Id.Suspend => {
                    const suspend_node = @fieldParentPtr(ast.Node.Suspend, "base", base);
                    if (suspend_node.label) |label| {
                        try stream.print("{}: ", tree.tokenSlice(label));
                    }
                    try stream.print("{}", tree.tokenSlice(suspend_node.suspend_token));

                    if (suspend_node.body) |body| {
                        try stack.push(RenderState { .Expression = body });
                        try stack.push(RenderState { .Text = " " });
                    }

                    if (suspend_node.payload) |payload| {
                        try stack.push(RenderState { .Expression = payload });
                        try stack.push(RenderState { .Text = " " });
                    }
                },
                ast.Node.Id.InfixOp => {
                    const prefix_op_node = @fieldParentPtr(ast.Node.InfixOp, "base", base);
                    try stack.push(RenderState { .Expression = prefix_op_node.rhs });

                    if (prefix_op_node.op == ast.Node.InfixOp.Op.Catch) {
                        if (prefix_op_node.op.Catch) |payload| {
                        try stack.push(RenderState { .Text = " " });
                            try stack.push(RenderState { .Expression = payload });
                        }
                        try stack.push(RenderState { .Text = " catch " });
                    } else {
                        const text = switch (prefix_op_node.op) {
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
                            ast.Node.InfixOp.Op.Catch => unreachable,
                        };

                        try stack.push(RenderState { .Text = text });
                    }
                    try stack.push(RenderState { .Expression = prefix_op_node.lhs });
                },
                ast.Node.Id.PrefixOp => {
                    const prefix_op_node = @fieldParentPtr(ast.Node.PrefixOp, "base", base);
                    try stack.push(RenderState { .Expression = prefix_op_node.rhs });
                    switch (prefix_op_node.op) {
                        ast.Node.PrefixOp.Op.AddrOf => |addr_of_info| {
                            try stream.write("&");
                            if (addr_of_info.volatile_token != null) {
                                try stack.push(RenderState { .Text = "volatile "});
                            }
                            if (addr_of_info.const_token != null) {
                                try stack.push(RenderState { .Text = "const "});
                            }
                            if (addr_of_info.align_expr) |align_expr| {
                                try stream.print("align(");
                                try stack.push(RenderState { .Text = ") "});
                                try stack.push(RenderState { .Expression = align_expr});
                            }
                        },
                        ast.Node.PrefixOp.Op.SliceType => |addr_of_info| {
                            try stream.write("[]");
                            if (addr_of_info.volatile_token != null) {
                                try stack.push(RenderState { .Text = "volatile "});
                            }
                            if (addr_of_info.const_token != null) {
                                try stack.push(RenderState { .Text = "const "});
                            }
                            if (addr_of_info.align_expr) |align_expr| {
                                try stream.print("align(");
                                try stack.push(RenderState { .Text = ") "});
                                try stack.push(RenderState { .Expression = align_expr});
                            }
                        },
                        ast.Node.PrefixOp.Op.ArrayType => |array_index| {
                            try stack.push(RenderState { .Text = "]"});
                            try stack.push(RenderState { .Expression = array_index});
                            try stack.push(RenderState { .Text = "["});
                        },
                        ast.Node.PrefixOp.Op.BitNot => try stream.write("~"),
                        ast.Node.PrefixOp.Op.BoolNot => try stream.write("!"),
                        ast.Node.PrefixOp.Op.Deref => try stream.write("*"),
                        ast.Node.PrefixOp.Op.Negation => try stream.write("-"),
                        ast.Node.PrefixOp.Op.NegationWrap => try stream.write("-%"),
                        ast.Node.PrefixOp.Op.Try => try stream.write("try "),
                        ast.Node.PrefixOp.Op.UnwrapMaybe => try stream.write("??"),
                        ast.Node.PrefixOp.Op.MaybeType => try stream.write("?"),
                        ast.Node.PrefixOp.Op.Await => try stream.write("await "),
                        ast.Node.PrefixOp.Op.Cancel => try stream.write("cancel "),
                        ast.Node.PrefixOp.Op.Resume => try stream.write("resume "),
                    }
                },
                ast.Node.Id.SuffixOp => {
                    const suffix_op = @fieldParentPtr(ast.Node.SuffixOp, "base", base);

                    switch (suffix_op.op) {
                        @TagType(ast.Node.SuffixOp.Op).Call => |*call_info| {
                            try stack.push(RenderState { .Text = ")"});
                            var i = call_info.params.len;
                            while (i != 0) {
                                i -= 1;
                                const param_node = *call_info.params.at(i);
                                try stack.push(RenderState { .Expression = param_node});
                                if (i != 0) {
                                    try stack.push(RenderState { .Text = ", " });
                                }
                            }
                            try stack.push(RenderState { .Text = "("});
                            try stack.push(RenderState { .Expression = suffix_op.lhs });

                            if (call_info.async_attr) |async_attr| {
                                try stack.push(RenderState { .Text = " "});
                                try stack.push(RenderState { .Expression = &async_attr.base });
                            }
                        },
                        ast.Node.SuffixOp.Op.ArrayAccess => |index_expr| {
                            try stack.push(RenderState { .Text = "]"});
                            try stack.push(RenderState { .Expression = index_expr});
                            try stack.push(RenderState { .Text = "["});
                            try stack.push(RenderState { .Expression = suffix_op.lhs });
                        },
                        @TagType(ast.Node.SuffixOp.Op).Slice => |range| {
                            try stack.push(RenderState { .Text = "]"});
                            if (range.end) |end| {
                                try stack.push(RenderState { .Expression = end});
                            }
                            try stack.push(RenderState { .Text = ".."});
                            try stack.push(RenderState { .Expression = range.start});
                            try stack.push(RenderState { .Text = "["});
                            try stack.push(RenderState { .Expression = suffix_op.lhs });
                        },
                        ast.Node.SuffixOp.Op.StructInitializer => |*field_inits| {
                            if (field_inits.len == 0) {
                                try stack.push(RenderState { .Text = "{}" });
                                try stack.push(RenderState { .Expression = suffix_op.lhs });
                                continue;
                            }
                            if (field_inits.len == 1) {
                                const field_init = *field_inits.at(0);

                                try stack.push(RenderState { .Text = " }" });
                                try stack.push(RenderState { .Expression = field_init });
                                try stack.push(RenderState { .Text = "{ " });
                                try stack.push(RenderState { .Expression = suffix_op.lhs });
                                continue;
                            }
                            try stack.push(RenderState { .Text = "}"});
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Indent = indent });
                            try stack.push(RenderState { .Text = "\n" });
                            var i = field_inits.len;
                            while (i != 0) {
                                i -= 1;
                                const field_init = *field_inits.at(i);
                                if (field_init.id != ast.Node.Id.LineComment) {
                                    try stack.push(RenderState { .Text = "," });
                                }
                                try stack.push(RenderState { .Expression = field_init });
                                try stack.push(RenderState.PrintIndent);
                                if (i != 0) {
                                    try stack.push(RenderState { .Text = blk: {
                                        const prev_node = *field_inits.at(i - 1);
                                        const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                        const loc = tree.tokenLocation(prev_node_last_token_end, field_init.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                        break :blk "\n";
                                    }});
                                }
                            }
                            try stack.push(RenderState { .Indent = indent + indent_delta });
                            try stack.push(RenderState { .Text = "{\n"});
                            try stack.push(RenderState { .Expression = suffix_op.lhs });
                        },
                        ast.Node.SuffixOp.Op.ArrayInitializer => |*exprs| {
                            if (exprs.len == 0) {
                                try stack.push(RenderState { .Text = "{}" });
                                try stack.push(RenderState { .Expression = suffix_op.lhs });
                                continue;
                            }
                            if (exprs.len == 1) {
                                const expr = *exprs.at(0);

                                try stack.push(RenderState { .Text = "}" });
                                try stack.push(RenderState { .Expression = expr });
                                try stack.push(RenderState { .Text = "{" });
                                try stack.push(RenderState { .Expression = suffix_op.lhs });
                                continue;
                            }

                            try stack.push(RenderState { .Text = "}"});
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Indent = indent });
                            var i = exprs.len;
                            while (i != 0) {
                                i -= 1;
                                const expr = *exprs.at(i);
                                try stack.push(RenderState { .Text = ",\n" });
                                try stack.push(RenderState { .Expression = expr });
                                try stack.push(RenderState.PrintIndent);
                            }
                            try stack.push(RenderState { .Indent = indent + indent_delta });
                            try stack.push(RenderState { .Text = "{\n"});
                            try stack.push(RenderState { .Expression = suffix_op.lhs });
                        },
                    }
                },
                ast.Node.Id.ControlFlowExpression => {
                    const flow_expr = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", base);

                    if (flow_expr.rhs) |rhs| {
                        try stack.push(RenderState { .Expression = rhs });
                        try stack.push(RenderState { .Text = " " });
                    }

                    switch (flow_expr.kind) {
                        ast.Node.ControlFlowExpression.Kind.Break => |maybe_label| {
                            try stream.print("break");
                            if (maybe_label) |label| {
                                try stream.print(" :");
                                try stack.push(RenderState { .Expression = label });
                            }
                        },
                        ast.Node.ControlFlowExpression.Kind.Continue => |maybe_label| {
                            try stream.print("continue");
                            if (maybe_label) |label| {
                                try stream.print(" :");
                                try stack.push(RenderState { .Expression = label });
                            }
                        },
                        ast.Node.ControlFlowExpression.Kind.Return => {
                            try stream.print("return");
                        },

                    }
                },
                ast.Node.Id.Payload => {
                    const payload = @fieldParentPtr(ast.Node.Payload, "base", base);
                    try stack.push(RenderState { .Text = "|"});
                    try stack.push(RenderState { .Expression = payload.error_symbol });
                    try stack.push(RenderState { .Text = "|"});
                },
                ast.Node.Id.PointerPayload => {
                    const payload = @fieldParentPtr(ast.Node.PointerPayload, "base", base);
                    try stack.push(RenderState { .Text = "|"});
                    try stack.push(RenderState { .Expression = payload.value_symbol });

                    if (payload.ptr_token) |ptr_token| {
                        try stack.push(RenderState { .Text = tree.tokenSlice(ptr_token) });
                    }

                    try stack.push(RenderState { .Text = "|"});
                },
                ast.Node.Id.PointerIndexPayload => {
                    const payload = @fieldParentPtr(ast.Node.PointerIndexPayload, "base", base);
                    try stack.push(RenderState { .Text = "|"});

                    if (payload.index_symbol) |index_symbol| {
                        try stack.push(RenderState { .Expression = index_symbol });
                        try stack.push(RenderState { .Text = ", "});
                    }

                    try stack.push(RenderState { .Expression = payload.value_symbol });

                    if (payload.ptr_token) |ptr_token| {
                        try stack.push(RenderState { .Text = tree.tokenSlice(ptr_token) });
                    }

                    try stack.push(RenderState { .Text = "|"});
                },
                ast.Node.Id.GroupedExpression => {
                    const grouped_expr = @fieldParentPtr(ast.Node.GroupedExpression, "base", base);
                    try stack.push(RenderState { .Text = ")"});
                    try stack.push(RenderState { .Expression = grouped_expr.expr });
                    try stack.push(RenderState { .Text = "("});
                },
                ast.Node.Id.FieldInitializer => {
                    const field_init = @fieldParentPtr(ast.Node.FieldInitializer, "base", base);
                    try stream.print(".{} = ", tree.tokenSlice(field_init.name_token));
                    try stack.push(RenderState { .Expression = field_init.expr });
                },
                ast.Node.Id.IntegerLiteral => {
                    const integer_literal = @fieldParentPtr(ast.Node.IntegerLiteral, "base", base);
                    try stream.print("{}", tree.tokenSlice(integer_literal.token));
                },
                ast.Node.Id.FloatLiteral => {
                    const float_literal = @fieldParentPtr(ast.Node.FloatLiteral, "base", base);
                    try stream.print("{}", tree.tokenSlice(float_literal.token));
                },
                ast.Node.Id.StringLiteral => {
                    const string_literal = @fieldParentPtr(ast.Node.StringLiteral, "base", base);
                    try stream.print("{}", tree.tokenSlice(string_literal.token));
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
                        ast.Node.ContainerDecl.Layout.Auto => { },
                    }

                    switch (container_decl.kind) {
                        ast.Node.ContainerDecl.Kind.Struct => try stream.print("struct"),
                        ast.Node.ContainerDecl.Kind.Enum => try stream.print("enum"),
                        ast.Node.ContainerDecl.Kind.Union => try stream.print("union"),
                    }

                    if (container_decl.fields_and_decls.len == 0) {
                        try stack.push(RenderState { .Text = "{}"});
                    } else {
                        try stack.push(RenderState { .Text = "}"});
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState { .Indent = indent });
                        try stack.push(RenderState { .Text = "\n"});

                        var i = container_decl.fields_and_decls.len;
                        while (i != 0) {
                            i -= 1;
                            const node = *container_decl.fields_and_decls.at(i);
                            try stack.push(RenderState { .TopLevelDecl = node});
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState {
                                .Text = blk: {
                                    if (i != 0) {
                                        const prev_node = *container_decl.fields_and_decls.at(i - 1);
                                        const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                        const loc = tree.tokenLocation(prev_node_last_token_end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                    }
                                    break :blk "\n";
                                },
                            });
                        }
                        try stack.push(RenderState { .Indent = indent + indent_delta});
                        try stack.push(RenderState { .Text = "{"});
                    }

                    switch (container_decl.init_arg_expr) {
                        ast.Node.ContainerDecl.InitArg.None => try stack.push(RenderState { .Text = " "}),
                        ast.Node.ContainerDecl.InitArg.Enum => |enum_tag_type| {
                            if (enum_tag_type) |expr| {
                                try stack.push(RenderState { .Text = ")) "});
                                try stack.push(RenderState { .Expression = expr});
                                try stack.push(RenderState { .Text = "(enum("});
                            } else {
                                try stack.push(RenderState { .Text = "(enum) "});
                            }
                        },
                        ast.Node.ContainerDecl.InitArg.Type => |type_expr| {
                            try stack.push(RenderState { .Text = ") "});
                            try stack.push(RenderState { .Expression = type_expr});
                            try stack.push(RenderState { .Text = "("});
                        },
                    }
                },
                ast.Node.Id.ErrorSetDecl => {
                    const err_set_decl = @fieldParentPtr(ast.Node.ErrorSetDecl, "base", base);

                    if (err_set_decl.decls.len == 0) {
                        try stream.write("error{}");
                        continue;
                    }

                    if (err_set_decl.decls.len == 1) blk: {
                        const node = *err_set_decl.decls.at(0);

                        // if there are any doc comments or same line comments
                        // don't try to put it all on one line
                        if (node.cast(ast.Node.ErrorTag)) |tag| {
                            if (tag.doc_comments != null) break :blk;
                        } else {
                            break :blk;
                        }


                        try stream.write("error{");
                        try stack.push(RenderState { .Text = "}" });
                        try stack.push(RenderState { .TopLevelDecl = node });
                        continue;
                    }

                    try stream.write("error{");

                    try stack.push(RenderState { .Text = "}"});
                    try stack.push(RenderState.PrintIndent);
                    try stack.push(RenderState { .Indent = indent });
                    try stack.push(RenderState { .Text = "\n"});

                    var i = err_set_decl.decls.len;
                    while (i != 0) {
                        i -= 1;
                        const node = *err_set_decl.decls.at(i);
                        if (node.id != ast.Node.Id.LineComment) {
                            try stack.push(RenderState { .Text = "," });
                        }
                        try stack.push(RenderState { .TopLevelDecl = node });
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState {
                            .Text = blk: {
                                if (i != 0) {
                                    const prev_node = *err_set_decl.decls.at(i - 1);
                                    const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                    const loc = tree.tokenLocation(prev_node_last_token_end, node.firstToken());
                                    if (loc.line >= 2) {
                                        break :blk "\n\n";
                                    }
                                }
                                break :blk "\n";
                            },
                        });
                    }
                    try stack.push(RenderState { .Indent = indent + indent_delta});
                },
                ast.Node.Id.MultilineStringLiteral => {
                    const multiline_str_literal = @fieldParentPtr(ast.Node.MultilineStringLiteral, "base", base);
                    try stream.print("\n");

                    var i : usize = 0;
                    while (i < multiline_str_literal.lines.len) : (i += 1) {
                        const t = *multiline_str_literal.lines.at(i);
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
                    try stack.push(RenderState { .Text = ")"});
                    var i = builtin_call.params.len;
                    while (i != 0) {
                        i -= 1;
                        const param_node = *builtin_call.params.at(i);
                        try stack.push(RenderState { .Expression = param_node});
                        if (i != 0) {
                            try stack.push(RenderState { .Text = ", " });
                        }
                    }
                },
                ast.Node.Id.FnProto => {
                    const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", base);

                    switch (fn_proto.return_type) {
                        ast.Node.FnProto.ReturnType.Explicit => |node| {
                            try stack.push(RenderState { .Expression = node});
                        },
                        ast.Node.FnProto.ReturnType.InferErrorSet => |node| {
                            try stack.push(RenderState { .Expression = node});
                            try stack.push(RenderState { .Text = "!"});
                        },
                    }

                    if (fn_proto.align_expr) |align_expr| {
                        try stack.push(RenderState { .Text = ") " });
                        try stack.push(RenderState { .Expression = align_expr});
                        try stack.push(RenderState { .Text = "align(" });
                    }

                    try stack.push(RenderState { .Text = ") " });
                    var i = fn_proto.params.len;
                    while (i != 0) {
                        i -= 1;
                        const param_decl_node = *fn_proto.params.at(i);
                        try stack.push(RenderState { .ParamDecl = param_decl_node});
                        if (i != 0) {
                            try stack.push(RenderState { .Text = ", " });
                        }
                    }

                    try stack.push(RenderState { .Text = "(" });
                    if (fn_proto.name_token) |name_token| {
                        try stack.push(RenderState { .Text = tree.tokenSlice(name_token) });
                        try stack.push(RenderState { .Text = " " });
                    }

                    try stack.push(RenderState { .Text = "fn" });

                    if (fn_proto.async_attr) |async_attr| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = &async_attr.base });
                    }

                    if (fn_proto.cc_token) |cc_token| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Text = tree.tokenSlice(cc_token) });
                    }

                    if (fn_proto.lib_name) |lib_name| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = lib_name });
                    }
                    if (fn_proto.extern_export_inline_token) |extern_export_inline_token| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Text = tree.tokenSlice(extern_export_inline_token) });
                    }

                    if (fn_proto.visib_token) |visib_token_index| {
                        const visib_token = tree.tokens.at(visib_token_index);
                        assert(visib_token.id == Token.Id.Keyword_pub or visib_token.id == Token.Id.Keyword_export);
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Text = tree.tokenSlice(visib_token_index) });
                    }
                },
                ast.Node.Id.PromiseType => {
                    const promise_type = @fieldParentPtr(ast.Node.PromiseType, "base", base);
                    try stream.write(tree.tokenSlice(promise_type.promise_token));
                    if (promise_type.result) |result| {
                        try stream.write(tree.tokenSlice(result.arrow_token));
                        try stack.push(RenderState { .Expression = result.return_type});
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
                        try stack.push(RenderState { .Text = ") {}"});
                        try stack.push(RenderState { .Expression = switch_node.expr });
                        continue;
                    }

                    try stack.push(RenderState { .Text = "}"});
                    try stack.push(RenderState.PrintIndent);
                    try stack.push(RenderState { .Indent = indent });
                    try stack.push(RenderState { .Text = "\n"});

                    var i = switch_node.cases.len;
                    while (i != 0) {
                        i -= 1;
                        const node = *switch_node.cases.at(i);
                        try stack.push(RenderState { .Expression = node});
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState {
                            .Text = blk: {
                                if (i != 0) {
                                    const prev_node = *switch_node.cases.at(i - 1);
                                    const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                    const loc = tree.tokenLocation(prev_node_last_token_end, node.firstToken());
                                    if (loc.line >= 2) {
                                        break :blk "\n\n";
                                    }
                                }
                                break :blk "\n";
                            },
                        });
                    }
                    try stack.push(RenderState { .Indent = indent + indent_delta});
                    try stack.push(RenderState { .Text = ") {"});
                    try stack.push(RenderState { .Expression = switch_node.expr });
                },
                ast.Node.Id.SwitchCase => {
                    const switch_case = @fieldParentPtr(ast.Node.SwitchCase, "base", base);

                    try stack.push(RenderState { .Text = "," });
                    try stack.push(RenderState { .Expression = switch_case.expr });
                    if (switch_case.payload) |payload| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = payload });
                    }
                    try stack.push(RenderState { .Text = " => "});

                    var i = switch_case.items.len;
                    while (i != 0) {
                        i -= 1;
                        try stack.push(RenderState { .Expression = *switch_case.items.at(i) });

                        if (i != 0) {
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Text = ",\n" });
                        }
                    }
                },
                ast.Node.Id.SwitchElse => {
                    const switch_else = @fieldParentPtr(ast.Node.SwitchElse, "base", base);
                    try stream.print("{}", tree.tokenSlice(switch_else.token));
                },
                ast.Node.Id.Else => {
                    const else_node = @fieldParentPtr(ast.Node.Else, "base", base);
                    try stream.print("{}", tree.tokenSlice(else_node.else_token));

                    switch (else_node.body.id) {
                        ast.Node.Id.Block, ast.Node.Id.If,
                        ast.Node.Id.For, ast.Node.Id.While,
                        ast.Node.Id.Switch => {
                            try stream.print(" ");
                            try stack.push(RenderState { .Expression = else_node.body });
                        },
                        else => {
                            try stack.push(RenderState { .Indent = indent });
                            try stack.push(RenderState { .Expression = else_node.body });
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Indent = indent + indent_delta });
                            try stack.push(RenderState { .Text = "\n" });
                        }
                    }

                    if (else_node.payload) |payload| {
                        try stack.push(RenderState { .Text = " " });
                        try stack.push(RenderState { .Expression = payload });
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

                    try stream.print("{} ", tree.tokenSlice(while_node.while_token));

                    if (while_node.@"else") |@"else"| {
                        try stack.push(RenderState { .Expression = &@"else".base });

                        if (while_node.body.id == ast.Node.Id.Block) {
                            try stack.push(RenderState { .Text = " " });
                        } else {
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Text = "\n" });
                        }
                    }

                    if (while_node.body.id == ast.Node.Id.Block) {
                        try stack.push(RenderState { .Expression = while_node.body });
                        try stack.push(RenderState { .Text = " " });
                    } else {
                        try stack.push(RenderState { .Indent = indent });
                        try stack.push(RenderState { .Expression = while_node.body });
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState { .Indent = indent + indent_delta });
                        try stack.push(RenderState { .Text = "\n" });
                    }

                    if (while_node.continue_expr) |continue_expr| {
                        try stack.push(RenderState { .Text = ")" });
                        try stack.push(RenderState { .Expression = continue_expr });
                        try stack.push(RenderState { .Text = ": (" });
                        try stack.push(RenderState { .Text = " " });
                    }

                    if (while_node.payload) |payload| {
                        try stack.push(RenderState { .Expression = payload });
                        try stack.push(RenderState { .Text = " " });
                    }

                    try stack.push(RenderState { .Text = ")" });
                    try stack.push(RenderState { .Expression = while_node.condition });
                    try stack.push(RenderState { .Text = "(" });
                },
                ast.Node.Id.For => {
                    const for_node = @fieldParentPtr(ast.Node.For, "base", base);
                    if (for_node.label) |label| {
                        try stream.print("{}: ", tree.tokenSlice(label));
                    }

                    if (for_node.inline_token) |inline_token| {
                        try stream.print("{} ", tree.tokenSlice(inline_token));
                    }

                    try stream.print("{} ", tree.tokenSlice(for_node.for_token));

                    if (for_node.@"else") |@"else"| {
                        try stack.push(RenderState { .Expression = &@"else".base });

                        if (for_node.body.id == ast.Node.Id.Block) {
                            try stack.push(RenderState { .Text = " " });
                        } else {
                            try stack.push(RenderState.PrintIndent);
                            try stack.push(RenderState { .Text = "\n" });
                        }
                    }

                    if (for_node.body.id == ast.Node.Id.Block) {
                        try stack.push(RenderState { .Expression = for_node.body });
                        try stack.push(RenderState { .Text = " " });
                    } else {
                        try stack.push(RenderState { .Indent = indent });
                        try stack.push(RenderState { .Expression = for_node.body });
                        try stack.push(RenderState.PrintIndent);
                        try stack.push(RenderState { .Indent = indent + indent_delta });
                        try stack.push(RenderState { .Text = "\n" });
                    }

                    if (for_node.payload) |payload| {
                        try stack.push(RenderState { .Expression = payload });
                        try stack.push(RenderState { .Text = " " });
                    }

                    try stack.push(RenderState { .Text = ")" });
                    try stack.push(RenderState { .Expression = for_node.array_expr });
                    try stack.push(RenderState { .Text = "(" });
                },
                ast.Node.Id.If => {
                    const if_node = @fieldParentPtr(ast.Node.If, "base", base);
                    try stream.print("{} ", tree.tokenSlice(if_node.if_token));

                    switch (if_node.body.id) {
                        ast.Node.Id.Block, ast.Node.Id.If,
                        ast.Node.Id.For, ast.Node.Id.While,
                        ast.Node.Id.Switch => {
                            if (if_node.@"else") |@"else"| {
                                try stack.push(RenderState { .Expression = &@"else".base });

                                if (if_node.body.id == ast.Node.Id.Block) {
                                    try stack.push(RenderState { .Text = " " });
                                } else {
                                    try stack.push(RenderState.PrintIndent);
                                    try stack.push(RenderState { .Text = "\n" });
                                }
                            }
                        },
                        else => {
                            if (if_node.@"else") |@"else"| {
                                try stack.push(RenderState { .Expression = @"else".body });

                                if (@"else".payload) |payload| {
                                    try stack.push(RenderState { .Text = " " });
                                    try stack.push(RenderState { .Expression = payload });
                                }

                                try stack.push(RenderState { .Text = " " });
                                try stack.push(RenderState { .Text = tree.tokenSlice(@"else".else_token) });
                                try stack.push(RenderState { .Text = " " });
                            }
                        }
                    }

                    try stack.push(RenderState { .Expression = if_node.body });
                    try stack.push(RenderState { .Text = " " });

                    if (if_node.payload) |payload| {
                        try stack.push(RenderState { .Expression = payload });
                        try stack.push(RenderState { .Text = " " });
                    }

                    try stack.push(RenderState { .Text = ")" });
                    try stack.push(RenderState { .Expression = if_node.condition });
                    try stack.push(RenderState { .Text = "(" });
                },
                ast.Node.Id.Asm => {
                    const asm_node = @fieldParentPtr(ast.Node.Asm, "base", base);
                    try stream.print("{} ", tree.tokenSlice(asm_node.asm_token));

                    if (asm_node.volatile_token) |volatile_token| {
                        try stream.print("{} ", tree.tokenSlice(volatile_token));
                    }

                    try stack.push(RenderState { .Indent = indent });
                    try stack.push(RenderState { .Text = ")" });
                    {
                        var i = asm_node.clobbers.len;
                        while (i != 0) {
                            i -= 1;
                            try stack.push(RenderState { .Expression = *asm_node.clobbers.at(i) });

                            if (i != 0) {
                                try stack.push(RenderState { .Text = ", " });
                            }
                        }
                    }
                    try stack.push(RenderState { .Text = ": " });
                    try stack.push(RenderState.PrintIndent);
                    try stack.push(RenderState { .Indent = indent + indent_delta });
                    try stack.push(RenderState { .Text = "\n" });
                    {
                        var i = asm_node.inputs.len;
                        while (i != 0) {
                            i -= 1;
                            const node = *asm_node.inputs.at(i);
                            try stack.push(RenderState { .Expression = &node.base});

                            if (i != 0) {
                                try stack.push(RenderState.PrintIndent);
                                try stack.push(RenderState {
                                    .Text = blk: {
                                        const prev_node = *asm_node.inputs.at(i - 1);
                                        const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                        const loc = tree.tokenLocation(prev_node_last_token_end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                        break :blk "\n";
                                    },
                                });
                                try stack.push(RenderState { .Text = "," });
                            }
                        }
                    }
                    try stack.push(RenderState { .Indent = indent + indent_delta + 2});
                    try stack.push(RenderState { .Text = ": "});
                    try stack.push(RenderState.PrintIndent);
                    try stack.push(RenderState { .Indent = indent + indent_delta});
                    try stack.push(RenderState { .Text = "\n" });
                    {
                        var i = asm_node.outputs.len;
                        while (i != 0) {
                            i -= 1;
                            const node = *asm_node.outputs.at(i);
                            try stack.push(RenderState { .Expression = &node.base});

                            if (i != 0) {
                                try stack.push(RenderState.PrintIndent);
                                try stack.push(RenderState {
                                    .Text = blk: {
                                        const prev_node = *asm_node.outputs.at(i - 1);
                                        const prev_node_last_token_end = tree.tokens.at(prev_node.lastToken()).end;
                                        const loc = tree.tokenLocation(prev_node_last_token_end, node.firstToken());
                                        if (loc.line >= 2) {
                                            break :blk "\n\n";
                                        }
                                        break :blk "\n";
                                    },
                                });
                                try stack.push(RenderState { .Text = "," });
                            }
                        }
                    }
                    try stack.push(RenderState { .Indent = indent + indent_delta + 2});
                    try stack.push(RenderState { .Text = ": "});
                    try stack.push(RenderState.PrintIndent);
                    try stack.push(RenderState { .Indent = indent + indent_delta});
                    try stack.push(RenderState { .Text = "\n" });
                    try stack.push(RenderState { .Expression = asm_node.template });
                    try stack.push(RenderState { .Text = "(" });
                },
                ast.Node.Id.AsmInput => {
                    const asm_input = @fieldParentPtr(ast.Node.AsmInput, "base", base);

                    try stack.push(RenderState { .Text = ")"});
                    try stack.push(RenderState { .Expression = asm_input.expr});
                    try stack.push(RenderState { .Text = " ("});
                    try stack.push(RenderState { .Expression = asm_input.constraint });
                    try stack.push(RenderState { .Text = "] "});
                    try stack.push(RenderState { .Expression = asm_input.symbolic_name });
                    try stack.push(RenderState { .Text = "["});
                },
                ast.Node.Id.AsmOutput => {
                    const asm_output = @fieldParentPtr(ast.Node.AsmOutput, "base", base);

                    try stack.push(RenderState { .Text = ")"});
                    switch (asm_output.kind) {
                        ast.Node.AsmOutput.Kind.Variable => |variable_name| {
                            try stack.push(RenderState { .Expression = &variable_name.base});
                        },
                        ast.Node.AsmOutput.Kind.Return => |return_type| {
                            try stack.push(RenderState { .Expression = return_type});
                            try stack.push(RenderState { .Text = "-> "});
                        },
                    }
                    try stack.push(RenderState { .Text = " ("});
                    try stack.push(RenderState { .Expression = asm_output.constraint });
                    try stack.push(RenderState { .Text = "] "});
                    try stack.push(RenderState { .Expression = asm_output.symbolic_name });
                    try stack.push(RenderState { .Text = "["});
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
            },
            RenderState.Statement => |base| {
                switch (base.id) {
                    ast.Node.Id.VarDecl => {
                        const var_decl = @fieldParentPtr(ast.Node.VarDecl, "base", base);
                        try stack.push(RenderState { .VarDecl = var_decl});
                    },
                    else => {
                        if (base.requireSemiColon()) {
                            try stack.push(RenderState { .Text = ";" });
                        }
                        try stack.push(RenderState { .Expression = base });
                    },
                }
            },
            RenderState.Indent => |new_indent| indent = new_indent,
            RenderState.PrintIndent => try stream.writeByteNTimes(' ', indent),
        }
    }
}

fn renderComments(tree: &ast.Tree, stream: var, node: var, indent: usize) !void {
    const comment = node.doc_comments ?? return;
    var it = comment.lines.iterator(0);
    while (it.next()) |line_token_index| {
        try stream.print("{}\n", tree.tokenSlice(*line_token_index));
        try stream.writeByteNTimes(' ', indent);
    }
}

