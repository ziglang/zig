//! Abstract Syntax Tree for Zig source code.
//! For Zig syntax, the root node is at nodes[0] and contains the list of
//! sub-nodes.
//! For Zon syntax, the root node is at nodes[0] and contains lhs as the node
//! index of the main expression.

/// Reference to externally-owned data.
source: [:0]const u8,

tokens: TokenList.Slice,
nodes: NodeList.Slice,
extra_data: []u32,
mode: Mode = .zig,

errors: []const Error,

pub const ByteOffset = u32;

pub const TokenList = std.MultiArrayList(struct {
    tag: Token.Tag,
    start: ByteOffset,
});
pub const NodeList = std.MultiArrayList(Node);

/// Index into `tokens`.
pub const TokenIndex = u32;

/// Index into `tokens`, or null.
pub const OptionalTokenIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(oti: OptionalTokenIndex) ?TokenIndex {
        return if (oti == .none) null else @intFromEnum(oti);
    }

    pub fn fromToken(ti: TokenIndex) OptionalTokenIndex {
        return @enumFromInt(ti);
    }

    pub fn fromOptional(oti: ?TokenIndex) OptionalTokenIndex {
        return if (oti) |ti| @enumFromInt(ti) else .none;
    }
};

/// A relative token index.
pub const TokenOffset = enum(i32) {
    zero = 0,
    _,

    pub fn init(base: TokenIndex, destination: TokenIndex) TokenOffset {
        const base_i64: i64 = base;
        const destination_i64: i64 = destination;
        return @enumFromInt(destination_i64 - base_i64);
    }

    pub fn toOptional(to: TokenOffset) OptionalTokenOffset {
        const result: OptionalTokenOffset = @enumFromInt(@intFromEnum(to));
        assert(result != .none);
        return result;
    }

    pub fn toAbsolute(offset: TokenOffset, base: TokenIndex) TokenIndex {
        return @intCast(@as(i64, base) + @intFromEnum(offset));
    }
};

/// A relative token index, or null.
pub const OptionalTokenOffset = enum(i32) {
    none = std.math.maxInt(i32),
    _,

    pub fn unwrap(oto: OptionalTokenOffset) ?TokenOffset {
        return if (oto == .none) null else @enumFromInt(@intFromEnum(oto));
    }
};

pub fn tokenTag(tree: *const Ast, token_index: TokenIndex) Token.Tag {
    return tree.tokens.items(.tag)[token_index];
}

pub fn tokenStart(tree: *const Ast, token_index: TokenIndex) ByteOffset {
    return tree.tokens.items(.start)[token_index];
}

pub fn nodeTag(tree: *const Ast, node: Node.Index) Node.Tag {
    return tree.nodes.items(.tag)[@intFromEnum(node)];
}

pub fn nodeMainToken(tree: *const Ast, node: Node.Index) TokenIndex {
    return tree.nodes.items(.main_token)[@intFromEnum(node)];
}

pub fn nodeData(tree: *const Ast, node: Node.Index) Node.Data {
    return tree.nodes.items(.data)[@intFromEnum(node)];
}

pub fn isTokenPrecededByTags(
    tree: *const Ast,
    ti: TokenIndex,
    expected_token_tags: []const Token.Tag,
) bool {
    return std.mem.endsWith(
        Token.Tag,
        tree.tokens.items(.tag)[0..ti],
        expected_token_tags,
    );
}

pub const Location = struct {
    line: usize,
    column: usize,
    line_start: usize,
    line_end: usize,
};

pub const Span = struct {
    start: u32,
    end: u32,
    main: u32,
};

pub fn deinit(tree: *Ast, gpa: Allocator) void {
    tree.tokens.deinit(gpa);
    tree.nodes.deinit(gpa);
    gpa.free(tree.extra_data);
    gpa.free(tree.errors);
    tree.* = undefined;
}

pub const RenderError = error{
    /// Ran out of memory allocating call stack frames to complete rendering, or
    /// ran out of memory allocating space in the output buffer.
    OutOfMemory,
};

pub const Mode = enum { zig, zon };

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(gpa: Allocator, source: [:0]const u8, mode: Mode) Allocator.Error!Ast {
    var tokens = Ast.TokenList{};
    defer tokens.deinit(gpa);

    // Empirically, the zig std lib has an 8:1 ratio of source bytes to token count.
    const estimated_token_count = source.len / 8;
    try tokens.ensureTotalCapacity(gpa, estimated_token_count);

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const token = tokenizer.next();
        try tokens.append(gpa, .{
            .tag = token.tag,
            .start = @intCast(token.loc.start),
        });
        if (token.tag == .eof) break;
    }

    var parser: Parse = .{
        .source = source,
        .gpa = gpa,
        .tokens = tokens.slice(),
        .errors = .{},
        .nodes = .{},
        .extra_data = .{},
        .scratch = .{},
        .tok_i = 0,
    };
    defer parser.errors.deinit(gpa);
    defer parser.nodes.deinit(gpa);
    defer parser.extra_data.deinit(gpa);
    defer parser.scratch.deinit(gpa);

    // Empirically, Zig source code has a 2:1 ratio of tokens to AST nodes.
    // Make sure at least 1 so we can use appendAssumeCapacity on the root node below.
    const estimated_node_count = (tokens.len + 2) / 2;
    try parser.nodes.ensureTotalCapacity(gpa, estimated_node_count);

    switch (mode) {
        .zig => try parser.parseRoot(),
        .zon => try parser.parseZon(),
    }

    const extra_data = try parser.extra_data.toOwnedSlice(gpa);
    errdefer gpa.free(extra_data);
    const errors = try parser.errors.toOwnedSlice(gpa);
    errdefer gpa.free(errors);

    // TODO experiment with compacting the MultiArrayList slices here
    return Ast{
        .source = source,
        .mode = mode,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = extra_data,
        .errors = errors,
    };
}

/// `gpa` is used for allocating the resulting formatted source code.
/// Caller owns the returned slice of bytes, allocated with `gpa`.
pub fn render(tree: Ast, gpa: Allocator) RenderError![]u8 {
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    try tree.renderToArrayList(&buffer, .{});
    return buffer.toOwnedSlice();
}

pub const Fixups = private_render.Fixups;

pub fn renderToArrayList(tree: Ast, buffer: *std.ArrayList(u8), fixups: Fixups) RenderError!void {
    return @import("./render.zig").renderTree(buffer, tree, fixups);
}

/// Returns an extra offset for column and byte offset of errors that
/// should point after the token in the error message.
pub fn errorOffset(tree: Ast, parse_error: Error) u32 {
    return if (parse_error.token_is_prev)
        @as(u32, @intCast(tree.tokenSlice(parse_error.token).len))
    else
        0;
}

pub fn tokenLocation(self: Ast, start_offset: ByteOffset, token_index: TokenIndex) Location {
    var loc = Location{
        .line = 0,
        .column = 0,
        .line_start = start_offset,
        .line_end = self.source.len,
    };
    const token_start = self.tokenStart(token_index);

    // Scan to by line until we go past the token start
    while (std.mem.indexOfScalarPos(u8, self.source, loc.line_start, '\n')) |i| {
        if (i >= token_start) {
            break; // Went past
        }
        loc.line += 1;
        loc.line_start = i + 1;
    }

    const offset = loc.line_start;
    for (self.source[offset..], 0..) |c, i| {
        if (i + offset == token_start) {
            loc.line_end = i + offset;
            while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') {
                loc.line_end += 1;
            }
            return loc;
        }
        if (c == '\n') {
            loc.line += 1;
            loc.column = 0;
            loc.line_start = i + 1;
        } else {
            loc.column += 1;
        }
    }
    return loc;
}

pub fn tokenSlice(tree: Ast, token_index: TokenIndex) []const u8 {
    const token_tag = tree.tokenTag(token_index);

    // Many tokens can be determined entirely by their tag.
    if (token_tag.lexeme()) |lexeme| {
        return lexeme;
    }

    // For some tokens, re-tokenization is needed to find the end.
    var tokenizer: std.zig.Tokenizer = .{
        .buffer = tree.source,
        .index = tree.tokenStart(token_index),
    };
    const token = tokenizer.next();
    assert(token.tag == token_tag);
    return tree.source[token.loc.start..token.loc.end];
}

pub fn extraDataSlice(tree: Ast, range: Node.SubRange, comptime T: type) []const T {
    return @ptrCast(tree.extra_data[@intFromEnum(range.start)..@intFromEnum(range.end)]);
}

pub fn extraDataSliceWithLen(tree: Ast, start: ExtraIndex, len: u32, comptime T: type) []const T {
    return @ptrCast(tree.extra_data[@intFromEnum(start)..][0..len]);
}

pub fn extraData(tree: Ast, index: ExtraIndex, comptime T: type) T {
    const fields = std.meta.fields(T);
    var result: T = undefined;
    inline for (fields, 0..) |field, i| {
        @field(result, field.name) = switch (field.type) {
            Node.Index,
            Node.OptionalIndex,
            OptionalTokenIndex,
            ExtraIndex,
            => @enumFromInt(tree.extra_data[@intFromEnum(index) + i]),
            TokenIndex => tree.extra_data[@intFromEnum(index) + i],
            else => @compileError("unexpected field type: " ++ @typeName(field.type)),
        };
    }
    return result;
}

fn loadOptionalNodesIntoBuffer(comptime size: usize, buffer: *[size]Node.Index, items: [size]Node.OptionalIndex) []Node.Index {
    for (buffer, items, 0..) |*node, opt_node, i| {
        node.* = opt_node.unwrap() orelse return buffer[0..i];
    }
    return buffer[0..];
}

pub fn rootDecls(tree: Ast) []const Node.Index {
    switch (tree.mode) {
        .zig => return tree.extraDataSlice(tree.nodeData(.root).extra_range, Node.Index),
        // Ensure that the returned slice points into the existing memory of the Ast
        .zon => return (&tree.nodes.items(.data)[@intFromEnum(Node.Index.root)].node)[0..1],
    }
}

pub fn renderError(tree: Ast, parse_error: Error, stream: anytype) !void {
    switch (parse_error.tag) {
        .asterisk_after_ptr_deref => {
            // Note that the token will point at the `.*` but ideally the source
            // location would point to the `*` after the `.*`.
            return stream.writeAll("'.*' cannot be followed by '*'; are you missing a space?");
        },
        .chained_comparison_operators => {
            return stream.writeAll("comparison operators cannot be chained");
        },
        .decl_between_fields => {
            return stream.writeAll("declarations are not allowed between container fields");
        },
        .expected_block => {
            return stream.print("expected block, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_block_or_assignment => {
            return stream.print("expected block or assignment, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_block_or_expr => {
            return stream.print("expected block or expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_block_or_field => {
            return stream.print("expected block or field, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_container_members => {
            return stream.print("expected test, comptime, var decl, or container field, found '{s}'", .{
                tree.tokenTag(parse_error.token).symbol(),
            });
        },
        .expected_expr => {
            return stream.print("expected expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_expr_or_assignment => {
            return stream.print("expected expression or assignment, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_expr_or_var_decl => {
            return stream.print("expected expression or var decl, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_fn => {
            return stream.print("expected function, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_inlinable => {
            return stream.print("expected 'while' or 'for', found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_labelable => {
            return stream.print("expected 'while', 'for', 'inline', or '{{', found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_param_list => {
            return stream.print("expected parameter list, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_prefix_expr => {
            return stream.print("expected prefix expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_primary_type_expr => {
            return stream.print("expected primary type expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_pub_item => {
            return stream.writeAll("expected function or variable declaration after pub");
        },
        .expected_return_type => {
            return stream.print("expected return type expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_semi_or_else => {
            return stream.writeAll("expected ';' or 'else' after statement");
        },
        .expected_semi_or_lbrace => {
            return stream.writeAll("expected ';' or block after function prototype");
        },
        .expected_statement => {
            return stream.print("expected statement, found '{s}'", .{
                tree.tokenTag(parse_error.token).symbol(),
            });
        },
        .expected_suffix_op => {
            return stream.print("expected pointer dereference, optional unwrap, or field access, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_type_expr => {
            return stream.print("expected type expression, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_var_decl => {
            return stream.print("expected variable declaration, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_var_decl_or_fn => {
            return stream.print("expected variable declaration or function, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_loop_payload => {
            return stream.print("expected loop payload, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .expected_container => {
            return stream.print("expected a struct, enum or union, found '{s}'", .{
                tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev)).symbol(),
            });
        },
        .extern_fn_body => {
            return stream.writeAll("extern functions have no body");
        },
        .extra_addrspace_qualifier => {
            return stream.writeAll("extra addrspace qualifier");
        },
        .extra_align_qualifier => {
            return stream.writeAll("extra align qualifier");
        },
        .extra_allowzero_qualifier => {
            return stream.writeAll("extra allowzero qualifier");
        },
        .extra_const_qualifier => {
            return stream.writeAll("extra const qualifier");
        },
        .extra_volatile_qualifier => {
            return stream.writeAll("extra volatile qualifier");
        },
        .ptr_mod_on_array_child_type => {
            return stream.print("pointer modifier '{s}' not allowed on array child type", .{
                tree.tokenTag(parse_error.token).symbol(),
            });
        },
        .invalid_bit_range => {
            return stream.writeAll("bit range not allowed on slices and arrays");
        },
        .same_line_doc_comment => {
            return stream.writeAll("same line documentation comment");
        },
        .unattached_doc_comment => {
            return stream.writeAll("unattached documentation comment");
        },
        .test_doc_comment => {
            return stream.writeAll("documentation comments cannot be attached to tests");
        },
        .comptime_doc_comment => {
            return stream.writeAll("documentation comments cannot be attached to comptime blocks");
        },
        .varargs_nonfinal => {
            return stream.writeAll("function prototype has parameter after varargs");
        },
        .expected_continue_expr => {
            return stream.writeAll("expected ':' before while continue expression");
        },

        .expected_semi_after_decl => {
            return stream.writeAll("expected ';' after declaration");
        },
        .expected_semi_after_stmt => {
            return stream.writeAll("expected ';' after statement");
        },
        .expected_comma_after_field => {
            return stream.writeAll("expected ',' after field");
        },
        .expected_comma_after_arg => {
            return stream.writeAll("expected ',' after argument");
        },
        .expected_comma_after_param => {
            return stream.writeAll("expected ',' after parameter");
        },
        .expected_comma_after_initializer => {
            return stream.writeAll("expected ',' after initializer");
        },
        .expected_comma_after_switch_prong => {
            return stream.writeAll("expected ',' after switch prong");
        },
        .expected_comma_after_for_operand => {
            return stream.writeAll("expected ',' after for operand");
        },
        .expected_comma_after_capture => {
            return stream.writeAll("expected ',' after for capture");
        },
        .expected_initializer => {
            return stream.writeAll("expected field initializer");
        },
        .mismatched_binary_op_whitespace => {
            return stream.print("binary operator '{s}' has whitespace on one side, but not the other", .{tree.tokenTag(parse_error.token).lexeme().?});
        },
        .invalid_ampersand_ampersand => {
            return stream.writeAll("ambiguous use of '&&'; use 'and' for logical AND, or change whitespace to ' & &' for bitwise AND");
        },
        .c_style_container => {
            return stream.print("'{s} {s}' is invalid", .{
                parse_error.extra.expected_tag.symbol(), tree.tokenSlice(parse_error.token),
            });
        },
        .zig_style_container => {
            return stream.print("to declare a container do 'const {s} = {s}'", .{
                tree.tokenSlice(parse_error.token), parse_error.extra.expected_tag.symbol(),
            });
        },
        .previous_field => {
            return stream.writeAll("field before declarations here");
        },
        .next_field => {
            return stream.writeAll("field after declarations here");
        },
        .expected_var_const => {
            return stream.writeAll("expected 'var' or 'const' before variable declaration");
        },
        .wrong_equal_var_decl => {
            return stream.writeAll("variable initialized with '==' instead of '='");
        },
        .var_const_decl => {
            return stream.writeAll("use 'var' or 'const' to declare variable");
        },
        .extra_for_capture => {
            return stream.writeAll("extra capture in for loop");
        },
        .for_input_not_captured => {
            return stream.writeAll("for input is not captured");
        },

        .invalid_byte => {
            const tok_slice = tree.source[tree.tokens.items(.start)[parse_error.token]..];
            return stream.print("{s} contains invalid byte: '{'}'", .{
                switch (tok_slice[0]) {
                    '\'' => "character literal",
                    '"', '\\' => "string literal",
                    '/' => "comment",
                    else => unreachable,
                },
                std.zig.fmtEscapes(tok_slice[parse_error.extra.offset..][0..1]),
            });
        },

        .expected_token => {
            const found_tag = tree.tokenTag(parse_error.token + @intFromBool(parse_error.token_is_prev));
            const expected_symbol = parse_error.extra.expected_tag.symbol();
            switch (found_tag) {
                .invalid => return stream.print("expected '{s}', found invalid bytes", .{
                    expected_symbol,
                }),
                else => return stream.print("expected '{s}', found '{s}'", .{
                    expected_symbol, found_tag.symbol(),
                }),
            }
        },
    }
}

pub fn firstToken(tree: Ast, node: Node.Index) TokenIndex {
    var end_offset: u32 = 0;
    var n = node;
    while (true) switch (tree.nodeTag(n)) {
        .root => return 0,

        .test_decl,
        .@"errdefer",
        .@"defer",
        .bool_not,
        .negation,
        .bit_not,
        .negation_wrap,
        .address_of,
        .@"try",
        .@"await",
        .optional_type,
        .@"switch",
        .switch_comma,
        .if_simple,
        .@"if",
        .@"suspend",
        .@"resume",
        .@"continue",
        .@"break",
        .@"return",
        .anyframe_type,
        .identifier,
        .anyframe_literal,
        .char_literal,
        .number_literal,
        .unreachable_literal,
        .string_literal,
        .multiline_string_literal,
        .grouped_expression,
        .builtin_call_two,
        .builtin_call_two_comma,
        .builtin_call,
        .builtin_call_comma,
        .error_set_decl,
        .@"comptime",
        .@"nosuspend",
        .asm_simple,
        .@"asm",
        .array_type,
        .array_type_sentinel,
        .error_value,
        => return tree.nodeMainToken(n) - end_offset,

        .array_init_dot,
        .array_init_dot_comma,
        .array_init_dot_two,
        .array_init_dot_two_comma,
        .struct_init_dot,
        .struct_init_dot_comma,
        .struct_init_dot_two,
        .struct_init_dot_two_comma,
        .enum_literal,
        => return tree.nodeMainToken(n) - 1 - end_offset,

        .@"catch",
        .equal_equal,
        .bang_equal,
        .less_than,
        .greater_than,
        .less_or_equal,
        .greater_or_equal,
        .assign_mul,
        .assign_div,
        .assign_mod,
        .assign_add,
        .assign_sub,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_and,
        .assign_bit_xor,
        .assign_bit_or,
        .assign_mul_wrap,
        .assign_add_wrap,
        .assign_sub_wrap,
        .assign_mul_sat,
        .assign_add_sat,
        .assign_sub_sat,
        .assign,
        .merge_error_sets,
        .mul,
        .div,
        .mod,
        .array_mult,
        .mul_wrap,
        .mul_sat,
        .add,
        .sub,
        .array_cat,
        .add_wrap,
        .sub_wrap,
        .add_sat,
        .sub_sat,
        .shl,
        .shl_sat,
        .shr,
        .bit_and,
        .bit_xor,
        .bit_or,
        .@"orelse",
        .bool_and,
        .bool_or,
        .slice_open,
        .array_access,
        .array_init_one,
        .array_init_one_comma,
        .switch_range,
        .error_union,
        => n = tree.nodeData(n).node_and_node[0],

        .for_range,
        .call_one,
        .call_one_comma,
        .struct_init_one,
        .struct_init_one_comma,
        => n = tree.nodeData(n).node_and_opt_node[0],

        .field_access,
        .unwrap_optional,
        => n = tree.nodeData(n).node_and_token[0],

        .slice,
        .slice_sentinel,
        .array_init,
        .array_init_comma,
        .struct_init,
        .struct_init_comma,
        .call,
        .call_comma,
        => n = tree.nodeData(n).node_and_extra[0],

        .deref => n = tree.nodeData(n).node,

        .assign_destructure => n = tree.assignDestructure(n).ast.variables[0],

        .fn_decl,
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => {
            var i = tree.nodeMainToken(n); // fn token
            while (i > 0) {
                i -= 1;
                switch (tree.tokenTag(i)) {
                    .keyword_extern,
                    .keyword_export,
                    .keyword_pub,
                    .keyword_inline,
                    .keyword_noinline,
                    .string_literal,
                    => continue,

                    else => return i + 1 - end_offset,
                }
            }
            return i - end_offset;
        },

        .@"usingnamespace" => {
            const main_token: TokenIndex = tree.nodeMainToken(n);
            const has_visib_token = tree.isTokenPrecededByTags(main_token, &.{.keyword_pub});
            end_offset += @intFromBool(has_visib_token);
            return main_token - end_offset;
        },

        .async_call_one,
        .async_call_one_comma,
        => {
            end_offset += 1; // async token
            n = tree.nodeData(n).node_and_opt_node[0];
        },

        .async_call,
        .async_call_comma,
        => {
            end_offset += 1; // async token
            n = tree.nodeData(n).node_and_extra[0];
        },

        .container_field_init,
        .container_field_align,
        .container_field,
        => {
            const name_token = tree.nodeMainToken(n);
            const has_comptime_token = tree.isTokenPrecededByTags(name_token, &.{.keyword_comptime});
            end_offset += @intFromBool(has_comptime_token);
            return name_token - end_offset;
        },

        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            var i = tree.nodeMainToken(n); // mut token
            while (i > 0) {
                i -= 1;
                switch (tree.tokenTag(i)) {
                    .keyword_extern,
                    .keyword_export,
                    .keyword_comptime,
                    .keyword_pub,
                    .keyword_threadlocal,
                    .string_literal,
                    => continue,

                    else => return i + 1 - end_offset,
                }
            }
            return i - end_offset;
        },

        .block,
        .block_semicolon,
        .block_two,
        .block_two_semicolon,
        => {
            // Look for a label.
            const lbrace = tree.nodeMainToken(n);
            if (tree.isTokenPrecededByTags(lbrace, &.{ .identifier, .colon })) {
                end_offset += 2;
            }
            return lbrace - end_offset;
        },

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
        => {
            const main_token = tree.nodeMainToken(n);
            switch (tree.tokenTag(main_token -| 1)) {
                .keyword_packed, .keyword_extern => end_offset += 1,
                else => {},
            }
            return main_token - end_offset;
        },

        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        => return tree.nodeMainToken(n) - end_offset,

        .switch_case_one,
        .switch_case_inline_one,
        .switch_case,
        .switch_case_inline,
        => {
            const full_switch = tree.fullSwitchCase(n).?;
            if (full_switch.inline_token) |inline_token| {
                return inline_token;
            } else if (full_switch.ast.values.len == 0) {
                return full_switch.ast.arrow_token - 1 - end_offset; // else token
            } else {
                n = full_switch.ast.values[0];
            }
        },

        .asm_output, .asm_input => {
            assert(tree.tokenTag(tree.nodeMainToken(n) - 1) == .l_bracket);
            return tree.nodeMainToken(n) - 1 - end_offset;
        },

        .while_simple,
        .while_cont,
        .@"while",
        .for_simple,
        .@"for",
        => {
            // Look for a label and inline.
            const main_token = tree.nodeMainToken(n);
            var result = main_token;
            if (tree.isTokenPrecededByTags(result, &.{.keyword_inline})) {
                result = result - 1;
            }
            if (tree.isTokenPrecededByTags(result, &.{ .identifier, .colon })) {
                result = result - 2;
            }
            return result - end_offset;
        },
    };
}

pub fn lastToken(tree: Ast, node: Node.Index) TokenIndex {
    var n = node;
    var end_offset: u32 = 0;
    while (true) switch (tree.nodeTag(n)) {
        .root => return @intCast(tree.tokens.len - 1),

        .@"usingnamespace",
        .bool_not,
        .negation,
        .bit_not,
        .negation_wrap,
        .address_of,
        .@"try",
        .@"await",
        .optional_type,
        .@"suspend",
        .@"resume",
        .@"nosuspend",
        .@"comptime",
        => n = tree.nodeData(n).node,

        .@"catch",
        .equal_equal,
        .bang_equal,
        .less_than,
        .greater_than,
        .less_or_equal,
        .greater_or_equal,
        .assign_mul,
        .assign_div,
        .assign_mod,
        .assign_add,
        .assign_sub,
        .assign_shl,
        .assign_shl_sat,
        .assign_shr,
        .assign_bit_and,
        .assign_bit_xor,
        .assign_bit_or,
        .assign_mul_wrap,
        .assign_add_wrap,
        .assign_sub_wrap,
        .assign_mul_sat,
        .assign_add_sat,
        .assign_sub_sat,
        .assign,
        .merge_error_sets,
        .mul,
        .div,
        .mod,
        .array_mult,
        .mul_wrap,
        .mul_sat,
        .add,
        .sub,
        .array_cat,
        .add_wrap,
        .sub_wrap,
        .add_sat,
        .sub_sat,
        .shl,
        .shl_sat,
        .shr,
        .bit_and,
        .bit_xor,
        .bit_or,
        .@"orelse",
        .bool_and,
        .bool_or,
        .error_union,
        .if_simple,
        .while_simple,
        .for_simple,
        .fn_decl,
        .array_type,
        .switch_range,
        => n = tree.nodeData(n).node_and_node[1],

        .test_decl, .@"errdefer" => n = tree.nodeData(n).opt_token_and_node[1],
        .@"defer" => n = tree.nodeData(n).node,
        .anyframe_type => n = tree.nodeData(n).token_and_node[1],

        .switch_case_one,
        .switch_case_inline_one,
        .ptr_type_aligned,
        .ptr_type_sentinel,
        => n = tree.nodeData(n).opt_node_and_node[1],

        .assign_destructure,
        .ptr_type,
        .ptr_type_bit_range,
        .switch_case,
        .switch_case_inline,
        => n = tree.nodeData(n).extra_and_node[1],

        .fn_proto_simple => n = tree.nodeData(n).opt_node_and_opt_node[1].unwrap().?,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => n = tree.nodeData(n).extra_and_opt_node[1].unwrap().?,

        .for_range => {
            n = tree.nodeData(n).node_and_opt_node[1].unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },

        .field_access,
        .unwrap_optional,
        .asm_simple,
        => return tree.nodeData(n).node_and_token[1] + end_offset,
        .grouped_expression, .asm_input => return tree.nodeData(n).node_and_token[1] + end_offset,
        .multiline_string_literal, .error_set_decl => return tree.nodeData(n).token_and_token[1] + end_offset,
        .asm_output => return tree.nodeData(n).opt_node_and_token[1] + end_offset,
        .error_value => return tree.nodeMainToken(n) + 2 + end_offset,

        .anyframe_literal,
        .char_literal,
        .number_literal,
        .unreachable_literal,
        .identifier,
        .deref,
        .enum_literal,
        .string_literal,
        => return tree.nodeMainToken(n) + end_offset,

        .@"return" => {
            n = tree.nodeData(n).opt_node.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },

        .call, .async_call => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const params = tree.extraData(extra_index, Node.SubRange);
            assert(params.start != params.end);
            end_offset += 1; // for the rparen
            n = @enumFromInt(tree.extra_data[@intFromEnum(params.end) - 1]); // last parameter
        },
        .tagged_union_enum_tag => {
            const arg, const extra_index = tree.nodeData(n).node_and_extra;
            const members = tree.extraData(extra_index, Node.SubRange);
            if (members.start == members.end) {
                end_offset += 4; // for the rparen + rparen + lbrace + rbrace
                n = arg;
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(members.end) - 1]); // last parameter
            }
        },
        .call_comma,
        .async_call_comma,
        .tagged_union_enum_tag_trailing,
        => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const params = tree.extraData(extra_index, Node.SubRange);
            assert(params.start != params.end);
            end_offset += 2; // for the comma/semicolon + rparen/rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(params.end) - 1]); // last parameter
        },
        .@"switch" => {
            const condition, const extra_index = tree.nodeData(n).node_and_extra;
            const cases = tree.extraData(extra_index, Node.SubRange);
            if (cases.start == cases.end) {
                end_offset += 3; // rparen, lbrace, rbrace
                n = condition;
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(cases.end) - 1]); // last case
            }
        },
        .container_decl_arg => {
            const arg, const extra_index = tree.nodeData(n).node_and_extra;
            const members = tree.extraData(extra_index, Node.SubRange);
            if (members.end == members.start) {
                end_offset += 3; // for the rparen + lbrace + rbrace
                n = arg;
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(members.end) - 1]); // last parameter
            }
        },
        .@"asm" => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.Asm);
            return extra.rparen + end_offset;
        },
        .array_init,
        .struct_init,
        => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const elements = tree.extraData(extra_index, Node.SubRange);
            assert(elements.start != elements.end);
            end_offset += 1; // for the rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(elements.end) - 1]); // last element
        },
        .array_init_comma,
        .struct_init_comma,
        .container_decl_arg_trailing,
        .switch_comma,
        => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const members = tree.extraData(extra_index, Node.SubRange);
            assert(members.start != members.end);
            end_offset += 2; // for the comma + rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(members.end) - 1]); // last parameter
        },
        .array_init_dot,
        .struct_init_dot,
        .block,
        .container_decl,
        .tagged_union,
        .builtin_call,
        => {
            const range = tree.nodeData(n).extra_range;
            assert(range.start != range.end);
            end_offset += 1; // for the rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(range.end) - 1]); // last statement
        },
        .array_init_dot_comma,
        .struct_init_dot_comma,
        .block_semicolon,
        .container_decl_trailing,
        .tagged_union_trailing,
        .builtin_call_comma,
        => {
            const range = tree.nodeData(n).extra_range;
            assert(range.start != range.end);
            end_offset += 2; // for the comma/semicolon + rbrace/rparen
            n = @enumFromInt(tree.extra_data[@intFromEnum(range.end) - 1]); // last member
        },
        .call_one,
        .async_call_one,
        => {
            _, const first_param = tree.nodeData(n).node_and_opt_node;
            end_offset += 1; // for the rparen
            n = first_param.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },

        .array_init_dot_two,
        .block_two,
        .builtin_call_two,
        .struct_init_dot_two,
        .container_decl_two,
        .tagged_union_two,
        => {
            const opt_lhs, const opt_rhs = tree.nodeData(n).opt_node_and_opt_node;
            if (opt_rhs.unwrap()) |rhs| {
                end_offset += 1; // for the rparen/rbrace
                n = rhs;
            } else if (opt_lhs.unwrap()) |lhs| {
                end_offset += 1; // for the rparen/rbrace
                n = lhs;
            } else {
                switch (tree.nodeTag(n)) {
                    .array_init_dot_two,
                    .block_two,
                    .struct_init_dot_two,
                    => end_offset += 1, // rbrace
                    .builtin_call_two => end_offset += 2, // lparen/lbrace + rparen/rbrace
                    .container_decl_two => {
                        var i: u32 = 2; // lbrace + rbrace
                        while (tree.tokenTag(tree.nodeMainToken(n) + i) == .container_doc_comment) i += 1;
                        end_offset += i;
                    },
                    .tagged_union_two => {
                        var i: u32 = 5; // (enum) {}
                        while (tree.tokenTag(tree.nodeMainToken(n) + i) == .container_doc_comment) i += 1;
                        end_offset += i;
                    },
                    else => unreachable,
                }
                return tree.nodeMainToken(n) + end_offset;
            }
        },
        .array_init_dot_two_comma,
        .builtin_call_two_comma,
        .block_two_semicolon,
        .struct_init_dot_two_comma,
        .container_decl_two_trailing,
        .tagged_union_two_trailing,
        => {
            const opt_lhs, const opt_rhs = tree.nodeData(n).opt_node_and_opt_node;
            end_offset += 2; // for the comma/semicolon + rbrace/rparen
            if (opt_rhs.unwrap()) |rhs| {
                n = rhs;
            } else if (opt_lhs.unwrap()) |lhs| {
                n = lhs;
            } else {
                unreachable;
            }
        },
        .simple_var_decl => {
            const type_node, const init_node = tree.nodeData(n).opt_node_and_opt_node;
            if (init_node.unwrap()) |rhs| {
                n = rhs;
            } else if (type_node.unwrap()) |lhs| {
                n = lhs;
            } else {
                end_offset += 1; // from mut token to name
                return tree.nodeMainToken(n) + end_offset;
            }
        },
        .aligned_var_decl => {
            const align_node, const init_node = tree.nodeData(n).node_and_opt_node;
            if (init_node.unwrap()) |rhs| {
                n = rhs;
            } else {
                end_offset += 1; // for the rparen
                n = align_node;
            }
        },
        .global_var_decl => {
            const extra_index, const init_node = tree.nodeData(n).extra_and_opt_node;
            if (init_node.unwrap()) |rhs| {
                n = rhs;
            } else {
                const extra = tree.extraData(extra_index, Node.GlobalVarDecl);
                if (extra.section_node.unwrap()) |section_node| {
                    end_offset += 1; // for the rparen
                    n = section_node;
                } else if (extra.align_node.unwrap()) |align_node| {
                    end_offset += 1; // for the rparen
                    n = align_node;
                } else if (extra.type_node.unwrap()) |type_node| {
                    n = type_node;
                } else {
                    end_offset += 1; // from mut token to name
                    return tree.nodeMainToken(n) + end_offset;
                }
            }
        },
        .local_var_decl => {
            const extra_index, const init_node = tree.nodeData(n).extra_and_opt_node;
            if (init_node.unwrap()) |rhs| {
                n = rhs;
            } else {
                const extra = tree.extraData(extra_index, Node.LocalVarDecl);
                end_offset += 1; // for the rparen
                n = extra.align_node;
            }
        },
        .container_field_init => {
            const type_expr, const value_expr = tree.nodeData(n).node_and_opt_node;
            n = value_expr.unwrap() orelse type_expr;
        },

        .array_access,
        .array_init_one,
        .container_field_align,
        => {
            _, const rhs = tree.nodeData(n).node_and_node;
            end_offset += 1; // for the rbracket/rbrace/rparen
            n = rhs;
        },
        .container_field => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.ContainerField);
            n = extra.value_expr;
        },

        .struct_init_one => {
            _, const first_field = tree.nodeData(n).node_and_opt_node;
            end_offset += 1; // rbrace
            n = first_field.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },
        .slice_open => {
            _, const start_node = tree.nodeData(n).node_and_node;
            end_offset += 2; // ellipsis2 + rbracket, or comma + rparen
            n = start_node;
        },
        .array_init_one_comma => {
            _, const first_element = tree.nodeData(n).node_and_node;
            end_offset += 2; // comma + rbrace
            n = first_element;
        },
        .call_one_comma,
        .async_call_one_comma,
        .struct_init_one_comma,
        => {
            _, const first_field = tree.nodeData(n).node_and_opt_node;
            end_offset += 2; // ellipsis2 + rbracket, or comma + rparen
            n = first_field.unwrap().?;
        },
        .slice => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.Slice);
            end_offset += 1; // rbracket
            n = extra.end;
        },
        .slice_sentinel => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.SliceSentinel);
            end_offset += 1; // rbracket
            n = extra.sentinel;
        },

        .@"continue", .@"break" => {
            const opt_label, const opt_rhs = tree.nodeData(n).opt_token_and_opt_node;
            if (opt_rhs.unwrap()) |rhs| {
                n = rhs;
            } else if (opt_label.unwrap()) |lhs| {
                return lhs + end_offset;
            } else {
                return tree.nodeMainToken(n) + end_offset;
            }
        },
        .while_cont => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.WhileCont);
            n = extra.then_expr;
        },
        .@"while" => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.While);
            n = extra.else_expr;
        },
        .@"if" => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.If);
            n = extra.else_expr;
        },
        .@"for" => {
            const extra_index, const extra = tree.nodeData(n).@"for";
            const index = @intFromEnum(extra_index) + extra.inputs + @intFromBool(extra.has_else);
            n = @enumFromInt(tree.extra_data[index]);
        },
        .array_type_sentinel => {
            _, const extra_index = tree.nodeData(n).node_and_extra;
            const extra = tree.extraData(extra_index, Node.ArrayTypeSentinel);
            n = extra.elem_type;
        },
    };
}

pub fn tokensOnSameLine(tree: Ast, token1: TokenIndex, token2: TokenIndex) bool {
    const source = tree.source[tree.tokenStart(token1)..tree.tokenStart(token2)];
    return mem.indexOfScalar(u8, source, '\n') == null;
}

pub fn getNodeSource(tree: Ast, node: Node.Index) []const u8 {
    const first_token = tree.firstToken(node);
    const last_token = tree.lastToken(node);
    const start = tree.tokenStart(first_token);
    const end = tree.tokenStart(last_token) + tree.tokenSlice(last_token).len;
    return tree.source[start..end];
}

pub fn globalVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .global_var_decl);
    const extra_index, const init_node = tree.nodeData(node).extra_and_opt_node;
    const extra = tree.extraData(extra_index, Node.GlobalVarDecl);
    return tree.fullVarDeclComponents(.{
        .type_node = extra.type_node,
        .align_node = extra.align_node,
        .addrspace_node = extra.addrspace_node,
        .section_node = extra.section_node,
        .init_node = init_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn localVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .local_var_decl);
    const extra_index, const init_node = tree.nodeData(node).extra_and_opt_node;
    const extra = tree.extraData(extra_index, Node.LocalVarDecl);
    return tree.fullVarDeclComponents(.{
        .type_node = extra.type_node.toOptional(),
        .align_node = extra.align_node.toOptional(),
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = init_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn simpleVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .simple_var_decl);
    const type_node, const init_node = tree.nodeData(node).opt_node_and_opt_node;
    return tree.fullVarDeclComponents(.{
        .type_node = type_node,
        .align_node = .none,
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = init_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn alignedVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .aligned_var_decl);
    const align_node, const init_node = tree.nodeData(node).node_and_opt_node;
    return tree.fullVarDeclComponents(.{
        .type_node = .none,
        .align_node = align_node.toOptional(),
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = init_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn assignDestructure(tree: Ast, node: Node.Index) full.AssignDestructure {
    const extra_index, const value_expr = tree.nodeData(node).extra_and_node;
    const variable_count = tree.extra_data[@intFromEnum(extra_index)];
    return tree.fullAssignDestructureComponents(.{
        .variables = tree.extraDataSliceWithLen(@enumFromInt(@intFromEnum(extra_index) + 1), variable_count, Node.Index),
        .equal_token = tree.nodeMainToken(node),
        .value_expr = value_expr,
    });
}

pub fn ifSimple(tree: Ast, node: Node.Index) full.If {
    assert(tree.nodeTag(node) == .if_simple);
    const cond_expr, const then_expr = tree.nodeData(node).node_and_node;
    return tree.fullIfComponents(.{
        .cond_expr = cond_expr,
        .then_expr = then_expr,
        .else_expr = .none,
        .if_token = tree.nodeMainToken(node),
    });
}

pub fn ifFull(tree: Ast, node: Node.Index) full.If {
    assert(tree.nodeTag(node) == .@"if");
    const cond_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.If);
    return tree.fullIfComponents(.{
        .cond_expr = cond_expr,
        .then_expr = extra.then_expr,
        .else_expr = extra.else_expr.toOptional(),
        .if_token = tree.nodeMainToken(node),
    });
}

pub fn containerField(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field);
    const type_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.ContainerField);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = type_expr.toOptional(),
        .align_expr = extra.align_expr.toOptional(),
        .value_expr = extra.value_expr.toOptional(),
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn containerFieldInit(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field_init);
    const type_expr, const value_expr = tree.nodeData(node).node_and_opt_node;
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = type_expr.toOptional(),
        .align_expr = .none,
        .value_expr = value_expr,
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn containerFieldAlign(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field_align);
    const type_expr, const align_expr = tree.nodeData(node).node_and_node;
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = type_expr.toOptional(),
        .align_expr = align_expr.toOptional(),
        .value_expr = .none,
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn fnProtoSimple(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_simple);
    const first_param, const return_type = tree.nodeData(node).opt_node_and_opt_node;
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{first_param});
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = return_type,
        .params = params,
        .align_expr = .none,
        .addrspace_expr = .none,
        .section_expr = .none,
        .callconv_expr = .none,
    });
}

pub fn fnProtoMulti(tree: Ast, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_multi);
    const extra_index, const return_type = tree.nodeData(node).extra_and_opt_node;
    const params = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = return_type,
        .params = params,
        .align_expr = .none,
        .addrspace_expr = .none,
        .section_expr = .none,
        .callconv_expr = .none,
    });
}

pub fn fnProtoOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_one);
    const extra_index, const return_type = tree.nodeData(node).extra_and_opt_node;
    const extra = tree.extraData(extra_index, Node.FnProtoOne);
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{extra.param});
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = return_type,
        .params = params,
        .align_expr = extra.align_expr,
        .addrspace_expr = extra.addrspace_expr,
        .section_expr = extra.section_expr,
        .callconv_expr = extra.callconv_expr,
    });
}

pub fn fnProto(tree: Ast, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto);
    const extra_index, const return_type = tree.nodeData(node).extra_and_opt_node;
    const extra = tree.extraData(extra_index, Node.FnProto);
    const params = tree.extraDataSlice(.{ .start = extra.params_start, .end = extra.params_end }, Node.Index);
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = return_type,
        .params = params,
        .align_expr = extra.align_expr,
        .addrspace_expr = extra.addrspace_expr,
        .section_expr = extra.section_expr,
        .callconv_expr = extra.callconv_expr,
    });
}

pub fn structInitOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.StructInit {
    assert(tree.nodeTag(node) == .struct_init_one or
        tree.nodeTag(node) == .struct_init_one_comma);
    const type_expr, const first_field = tree.nodeData(node).node_and_opt_node;
    const fields = loadOptionalNodesIntoBuffer(1, buffer, .{first_field});
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = type_expr.toOptional(),
        },
    };
}

pub fn structInitDotTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.StructInit {
    assert(tree.nodeTag(node) == .struct_init_dot_two or
        tree.nodeTag(node) == .struct_init_dot_two_comma);
    const fields = loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = .none,
        },
    };
}

pub fn structInitDot(tree: Ast, node: Node.Index) full.StructInit {
    assert(tree.nodeTag(node) == .struct_init_dot or
        tree.nodeTag(node) == .struct_init_dot_comma);
    const fields = tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = .none,
        },
    };
}

pub fn structInit(tree: Ast, node: Node.Index) full.StructInit {
    assert(tree.nodeTag(node) == .struct_init or
        tree.nodeTag(node) == .struct_init_comma);
    const type_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const fields = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = type_expr.toOptional(),
        },
    };
}

pub fn arrayInitOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init_one or
        tree.nodeTag(node) == .array_init_one_comma);
    const type_expr, buffer[0] = tree.nodeData(node).node_and_node;
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = buffer[0..1],
            .type_expr = type_expr.toOptional(),
        },
    };
}

pub fn arrayInitDotTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init_dot_two or
        tree.nodeTag(node) == .array_init_dot_two_comma);
    const elements = loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = elements,
            .type_expr = .none,
        },
    };
}

pub fn arrayInitDot(tree: Ast, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init_dot or
        tree.nodeTag(node) == .array_init_dot_comma);
    const elements = tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = elements,
            .type_expr = .none,
        },
    };
}

pub fn arrayInit(tree: Ast, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init or
        tree.nodeTag(node) == .array_init_comma);
    const type_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const elements = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = elements,
            .type_expr = type_expr.toOptional(),
        },
    };
}

pub fn arrayType(tree: Ast, node: Node.Index) full.ArrayType {
    assert(tree.nodeTag(node) == .array_type);
    const elem_count, const elem_type = tree.nodeData(node).node_and_node;
    return .{
        .ast = .{
            .lbracket = tree.nodeMainToken(node),
            .elem_count = elem_count,
            .sentinel = .none,
            .elem_type = elem_type,
        },
    };
}

pub fn arrayTypeSentinel(tree: Ast, node: Node.Index) full.ArrayType {
    assert(tree.nodeTag(node) == .array_type_sentinel);
    const elem_count, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.ArrayTypeSentinel);
    return .{
        .ast = .{
            .lbracket = tree.nodeMainToken(node),
            .elem_count = elem_count,
            .sentinel = extra.sentinel.toOptional(),
            .elem_type = extra.elem_type,
        },
    };
}

pub fn ptrTypeAligned(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_aligned);
    const align_node, const child_type = tree.nodeData(node).opt_node_and_node;
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = align_node,
        .addrspace_node = .none,
        .sentinel = .none,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = child_type,
    });
}

pub fn ptrTypeSentinel(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_sentinel);
    const sentinel, const child_type = tree.nodeData(node).opt_node_and_node;
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = .none,
        .addrspace_node = .none,
        .sentinel = sentinel,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = child_type,
    });
}

pub fn ptrType(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type);
    const extra_index, const child_type = tree.nodeData(node).extra_and_node;
    const extra = tree.extraData(extra_index, Node.PtrType);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = extra.align_node,
        .addrspace_node = extra.addrspace_node,
        .sentinel = extra.sentinel,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = child_type,
    });
}

pub fn ptrTypeBitRange(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_bit_range);
    const extra_index, const child_type = tree.nodeData(node).extra_and_node;
    const extra = tree.extraData(extra_index, Node.PtrTypeBitRange);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = extra.align_node.toOptional(),
        .addrspace_node = extra.addrspace_node,
        .sentinel = extra.sentinel,
        .bit_range_start = extra.bit_range_start.toOptional(),
        .bit_range_end = extra.bit_range_end.toOptional(),
        .child_type = child_type,
    });
}

pub fn sliceOpen(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice_open);
    const sliced, const start = tree.nodeData(node).node_and_node;
    return .{
        .ast = .{
            .sliced = sliced,
            .lbracket = tree.nodeMainToken(node),
            .start = start,
            .end = .none,
            .sentinel = .none,
        },
    };
}

pub fn slice(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice);
    const sliced, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.Slice);
    return .{
        .ast = .{
            .sliced = sliced,
            .lbracket = tree.nodeMainToken(node),
            .start = extra.start,
            .end = extra.end.toOptional(),
            .sentinel = .none,
        },
    };
}

pub fn sliceSentinel(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice_sentinel);
    const sliced, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.SliceSentinel);
    return .{
        .ast = .{
            .sliced = sliced,
            .lbracket = tree.nodeMainToken(node),
            .start = extra.start,
            .end = extra.end,
            .sentinel = extra.sentinel.toOptional(),
        },
    };
}

pub fn containerDeclTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .container_decl_two or
        tree.nodeTag(node) == .container_decl_two_trailing);
    const members = loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node);
    return tree.fullContainerDeclComponents(.{
        .main_token = tree.nodeMainToken(node),
        .enum_token = null,
        .members = members,
        .arg = .none,
    });
}

pub fn containerDecl(tree: Ast, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .container_decl or
        tree.nodeTag(node) == .container_decl_trailing);
    const members = tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index);
    return tree.fullContainerDeclComponents(.{
        .main_token = tree.nodeMainToken(node),
        .enum_token = null,
        .members = members,
        .arg = .none,
    });
}

pub fn containerDeclArg(tree: Ast, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .container_decl_arg or
        tree.nodeTag(node) == .container_decl_arg_trailing);
    const arg, const extra_index = tree.nodeData(node).node_and_extra;
    const members = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return tree.fullContainerDeclComponents(.{
        .main_token = tree.nodeMainToken(node),
        .enum_token = null,
        .members = members,
        .arg = arg.toOptional(),
    });
}

pub fn containerDeclRoot(tree: Ast) full.ContainerDecl {
    return .{
        .layout_token = null,
        .ast = .{
            .main_token = 0,
            .enum_token = null,
            .members = tree.rootDecls(),
            .arg = .none,
        },
    };
}

pub fn taggedUnionTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .tagged_union_two or
        tree.nodeTag(node) == .tagged_union_two_trailing);
    const members = loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerDeclComponents(.{
        .main_token = main_token,
        .enum_token = main_token + 2, // union lparen enum
        .members = members,
        .arg = .none,
    });
}

pub fn taggedUnion(tree: Ast, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .tagged_union or
        tree.nodeTag(node) == .tagged_union_trailing);
    const members = tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerDeclComponents(.{
        .main_token = main_token,
        .enum_token = main_token + 2, // union lparen enum
        .members = members,
        .arg = .none,
    });
}

pub fn taggedUnionEnumTag(tree: Ast, node: Node.Index) full.ContainerDecl {
    assert(tree.nodeTag(node) == .tagged_union_enum_tag or
        tree.nodeTag(node) == .tagged_union_enum_tag_trailing);
    const arg, const extra_index = tree.nodeData(node).node_and_extra;
    const members = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerDeclComponents(.{
        .main_token = main_token,
        .enum_token = main_token + 2, // union lparen enum
        .members = members,
        .arg = arg.toOptional(),
    });
}

pub fn switchFull(tree: Ast, node: Node.Index) full.Switch {
    const main_token = tree.nodeMainToken(node);
    const switch_token: TokenIndex, const label_token: ?TokenIndex = switch (tree.tokenTag(main_token)) {
        .identifier => .{ main_token + 2, main_token },
        .keyword_switch => .{ main_token, null },
        else => unreachable,
    };
    const condition, const extra_index = tree.nodeData(node).node_and_extra;
    const cases = tree.extraDataSlice(tree.extraData(extra_index, Ast.Node.SubRange), Node.Index);
    return .{
        .ast = .{
            .switch_token = switch_token,
            .condition = condition,
            .cases = cases,
        },
        .label_token = label_token,
    };
}

pub fn switchCaseOne(tree: Ast, node: Node.Index) full.SwitchCase {
    const first_value, const target_expr = tree.nodeData(node).opt_node_and_node;
    return tree.fullSwitchCaseComponents(.{
        .values = if (first_value == .none)
            &.{}
        else
            // Ensure that the returned slice points into the existing memory of the Ast
            (@as(*const Node.Index, @ptrCast(&tree.nodes.items(.data)[@intFromEnum(node)].opt_node_and_node[0])))[0..1],
        .arrow_token = tree.nodeMainToken(node),
        .target_expr = target_expr,
    }, node);
}

pub fn switchCase(tree: Ast, node: Node.Index) full.SwitchCase {
    const extra_index, const target_expr = tree.nodeData(node).extra_and_node;
    const values = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return tree.fullSwitchCaseComponents(.{
        .values = values,
        .arrow_token = tree.nodeMainToken(node),
        .target_expr = target_expr,
    }, node);
}

pub fn asmSimple(tree: Ast, node: Node.Index) full.Asm {
    const template, const rparen = tree.nodeData(node).node_and_token;
    return tree.fullAsmComponents(.{
        .asm_token = tree.nodeMainToken(node),
        .template = template,
        .items = &.{},
        .rparen = rparen,
    });
}

pub fn asmFull(tree: Ast, node: Node.Index) full.Asm {
    const template, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.Asm);
    const items = tree.extraDataSlice(.{ .start = extra.items_start, .end = extra.items_end }, Node.Index);
    return tree.fullAsmComponents(.{
        .asm_token = tree.nodeMainToken(node),
        .template = template,
        .items = items,
        .rparen = extra.rparen,
    });
}

pub fn whileSimple(tree: Ast, node: Node.Index) full.While {
    const cond_expr, const then_expr = tree.nodeData(node).node_and_node;
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = cond_expr,
        .cont_expr = .none,
        .then_expr = then_expr,
        .else_expr = .none,
    });
}

pub fn whileCont(tree: Ast, node: Node.Index) full.While {
    const cond_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.WhileCont);
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = cond_expr,
        .cont_expr = extra.cont_expr.toOptional(),
        .then_expr = extra.then_expr,
        .else_expr = .none,
    });
}

pub fn whileFull(tree: Ast, node: Node.Index) full.While {
    const cond_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const extra = tree.extraData(extra_index, Node.While);
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = cond_expr,
        .cont_expr = extra.cont_expr,
        .then_expr = extra.then_expr,
        .else_expr = extra.else_expr.toOptional(),
    });
}

pub fn forSimple(tree: Ast, node: Node.Index) full.For {
    const data = &tree.nodes.items(.data)[@intFromEnum(node)].node_and_node;
    return tree.fullForComponents(.{
        .for_token = tree.nodeMainToken(node),
        .inputs = (&data[0])[0..1],
        .then_expr = data[1],
        .else_expr = .none,
    });
}

pub fn forFull(tree: Ast, node: Node.Index) full.For {
    const extra_index, const extra = tree.nodeData(node).@"for";
    const inputs = tree.extraDataSliceWithLen(extra_index, extra.inputs, Node.Index);
    const then_expr: Node.Index = @enumFromInt(tree.extra_data[@intFromEnum(extra_index) + extra.inputs]);
    const else_expr: Node.OptionalIndex = if (extra.has_else) @enumFromInt(tree.extra_data[@intFromEnum(extra_index) + extra.inputs + 1]) else .none;
    return tree.fullForComponents(.{
        .for_token = tree.nodeMainToken(node),
        .inputs = inputs,
        .then_expr = then_expr,
        .else_expr = else_expr,
    });
}

pub fn callOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.Call {
    const fn_expr, const first_param = tree.nodeData(node).node_and_opt_node;
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{first_param});
    return tree.fullCallComponents(.{
        .lparen = tree.nodeMainToken(node),
        .fn_expr = fn_expr,
        .params = params,
    });
}

pub fn callFull(tree: Ast, node: Node.Index) full.Call {
    const fn_expr, const extra_index = tree.nodeData(node).node_and_extra;
    const params = tree.extraDataSlice(tree.extraData(extra_index, Node.SubRange), Node.Index);
    return tree.fullCallComponents(.{
        .lparen = tree.nodeMainToken(node),
        .fn_expr = fn_expr,
        .params = params,
    });
}

fn fullVarDeclComponents(tree: Ast, info: full.VarDecl.Components) full.VarDecl {
    var result: full.VarDecl = .{
        .ast = info,
        .visib_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .threadlocal_token = null,
        .comptime_token = null,
    };
    var i = info.mut_token;
    while (i > 0) {
        i -= 1;
        switch (tree.tokenTag(i)) {
            .keyword_extern, .keyword_export => result.extern_export_token = i,
            .keyword_comptime => result.comptime_token = i,
            .keyword_pub => result.visib_token = i,
            .keyword_threadlocal => result.threadlocal_token = i,
            .string_literal => result.lib_name = i,
            else => break,
        }
    }
    return result;
}

fn fullAssignDestructureComponents(tree: Ast, info: full.AssignDestructure.Components) full.AssignDestructure {
    var result: full.AssignDestructure = .{
        .comptime_token = null,
        .ast = info,
    };
    const first_variable_token = tree.firstToken(info.variables[0]);
    const maybe_comptime_token = switch (tree.nodeTag(info.variables[0])) {
        .global_var_decl,
        .local_var_decl,
        .aligned_var_decl,
        .simple_var_decl,
        => first_variable_token,
        else => first_variable_token - 1,
    };
    if (tree.tokenTag(maybe_comptime_token) == .keyword_comptime) {
        result.comptime_token = maybe_comptime_token;
    }
    return result;
}

fn fullIfComponents(tree: Ast, info: full.If.Components) full.If {
    var result: full.If = .{
        .ast = info,
        .payload_token = null,
        .error_token = null,
        .else_token = undefined,
    };
    // if (cond_expr) |x|
    //              ^ ^
    const payload_pipe = tree.lastToken(info.cond_expr) + 2;
    if (tree.tokenTag(payload_pipe) == .pipe) {
        result.payload_token = payload_pipe + 1;
    }
    if (info.else_expr != .none) {
        // then_expr else |x|
        //           ^    ^
        result.else_token = tree.lastToken(info.then_expr) + 1;
        if (tree.tokenTag(result.else_token + 1) == .pipe) {
            result.error_token = result.else_token + 2;
        }
    }
    return result;
}

fn fullContainerFieldComponents(tree: Ast, info: full.ContainerField.Components) full.ContainerField {
    var result: full.ContainerField = .{
        .ast = info,
        .comptime_token = null,
    };
    if (tree.isTokenPrecededByTags(info.main_token, &.{.keyword_comptime})) {
        // comptime type = init,
        // ^        ^
        // comptime name: type = init,
        // ^        ^
        result.comptime_token = info.main_token - 1;
    }
    return result;
}

fn fullFnProtoComponents(tree: Ast, info: full.FnProto.Components) full.FnProto {
    var result: full.FnProto = .{
        .ast = info,
        .visib_token = null,
        .extern_export_inline_token = null,
        .lib_name = null,
        .name_token = null,
        .lparen = undefined,
    };
    var i = info.fn_token;
    while (i > 0) {
        i -= 1;
        switch (tree.tokenTag(i)) {
            .keyword_extern,
            .keyword_export,
            .keyword_inline,
            .keyword_noinline,
            => result.extern_export_inline_token = i,
            .keyword_pub => result.visib_token = i,
            .string_literal => result.lib_name = i,
            else => break,
        }
    }
    const after_fn_token = info.fn_token + 1;
    if (tree.tokenTag(after_fn_token) == .identifier) {
        result.name_token = after_fn_token;
        result.lparen = after_fn_token + 1;
    } else {
        result.lparen = after_fn_token;
    }
    assert(tree.tokenTag(result.lparen) == .l_paren);

    return result;
}

fn fullPtrTypeComponents(tree: Ast, info: full.PtrType.Components) full.PtrType {
    const size: std.builtin.Type.Pointer.Size = switch (tree.tokenTag(info.main_token)) {
        .asterisk,
        .asterisk_asterisk,
        => .one,
        .l_bracket => switch (tree.tokenTag(info.main_token + 1)) {
            .asterisk => if (tree.tokenTag(info.main_token + 2) == .identifier) .c else .many,
            else => .slice,
        },
        else => unreachable,
    };
    var result: full.PtrType = .{
        .size = size,
        .allowzero_token = null,
        .const_token = null,
        .volatile_token = null,
        .ast = info,
    };
    // We need to be careful that we don't iterate over any sub-expressions
    // here while looking for modifiers as that could result in false
    // positives. Therefore, start after a sentinel if there is one and
    // skip over any align node and bit range nodes.
    var i = if (info.sentinel.unwrap()) |sentinel| tree.lastToken(sentinel) + 1 else switch (size) {
        .many, .c => info.main_token + 1,
        else => info.main_token,
    };
    const end = tree.firstToken(info.child_type);
    while (i < end) : (i += 1) {
        switch (tree.tokenTag(i)) {
            .keyword_allowzero => result.allowzero_token = i,
            .keyword_const => result.const_token = i,
            .keyword_volatile => result.volatile_token = i,
            .keyword_align => {
                const align_node = info.align_node.unwrap().?;
                if (info.bit_range_end.unwrap()) |bit_range_end| {
                    assert(info.bit_range_start != .none);
                    i = tree.lastToken(bit_range_end) + 1;
                } else {
                    i = tree.lastToken(align_node) + 1;
                }
            },
            else => {},
        }
    }
    return result;
}

fn fullContainerDeclComponents(tree: Ast, info: full.ContainerDecl.Components) full.ContainerDecl {
    var result: full.ContainerDecl = .{
        .ast = info,
        .layout_token = null,
    };

    if (info.main_token == 0) return result; // .root
    const previous_token = info.main_token - 1;

    switch (tree.tokenTag(previous_token)) {
        .keyword_extern, .keyword_packed => result.layout_token = previous_token,
        else => {},
    }
    return result;
}

fn fullSwitchComponents(tree: Ast, info: full.Switch.Components) full.Switch {
    const tok_i = info.switch_token -| 1;
    var result: full.Switch = .{
        .ast = info,
        .label_token = null,
    };
    if (tree.tokenTag(tok_i) == .colon and
        tree.tokenTag(tok_i -| 1) == .identifier)
    {
        result.label_token = tok_i - 1;
    }
    return result;
}

fn fullSwitchCaseComponents(tree: Ast, info: full.SwitchCase.Components, node: Node.Index) full.SwitchCase {
    var result: full.SwitchCase = .{
        .ast = info,
        .payload_token = null,
        .inline_token = null,
    };
    if (tree.tokenTag(info.arrow_token + 1) == .pipe) {
        result.payload_token = info.arrow_token + 2;
    }
    result.inline_token = switch (tree.nodeTag(node)) {
        .switch_case_inline, .switch_case_inline_one => if (result.ast.values.len == 0)
            info.arrow_token - 2
        else
            tree.firstToken(result.ast.values[0]) - 1,
        else => null,
    };
    return result;
}

fn fullAsmComponents(tree: Ast, info: full.Asm.Components) full.Asm {
    var result: full.Asm = .{
        .ast = info,
        .volatile_token = null,
        .inputs = &.{},
        .outputs = &.{},
        .first_clobber = null,
    };
    if (tree.tokenTag(info.asm_token + 1) == .keyword_volatile) {
        result.volatile_token = info.asm_token + 1;
    }
    const outputs_end: usize = for (info.items, 0..) |item, i| {
        switch (tree.nodeTag(item)) {
            .asm_output => continue,
            else => break i,
        }
    } else info.items.len;

    result.outputs = info.items[0..outputs_end];
    result.inputs = info.items[outputs_end..];

    if (info.items.len == 0) {
        // asm ("foo" ::: "a", "b");
        const template_token = tree.lastToken(info.template);
        if (tree.tokenTag(template_token + 1) == .colon and
            tree.tokenTag(template_token + 2) == .colon and
            tree.tokenTag(template_token + 3) == .colon and
            tree.tokenTag(template_token + 4) == .string_literal)
        {
            result.first_clobber = template_token + 4;
        }
    } else if (result.inputs.len != 0) {
        // asm ("foo" :: [_] "" (y) : "a", "b");
        const last_input = result.inputs[result.inputs.len - 1];
        const rparen = tree.lastToken(last_input);
        var i = rparen + 1;
        // Allow a (useless) comma right after the closing parenthesis.
        if (tree.tokenTag(i) == .comma) i = i + 1;
        if (tree.tokenTag(i) == .colon and
            tree.tokenTag(i + 1) == .string_literal)
        {
            result.first_clobber = i + 1;
        }
    } else {
        // asm ("foo" : [_] "" (x) :: "a", "b");
        const last_output = result.outputs[result.outputs.len - 1];
        const rparen = tree.lastToken(last_output);
        var i = rparen + 1;
        // Allow a (useless) comma right after the closing parenthesis.
        if (tree.tokenTag(i) == .comma) i = i + 1;
        if (tree.tokenTag(i) == .colon and
            tree.tokenTag(i + 1) == .colon and
            tree.tokenTag(i + 2) == .string_literal)
        {
            result.first_clobber = i + 2;
        }
    }

    return result;
}

fn fullWhileComponents(tree: Ast, info: full.While.Components) full.While {
    var result: full.While = .{
        .ast = info,
        .inline_token = null,
        .label_token = null,
        .payload_token = null,
        .else_token = undefined,
        .error_token = null,
    };
    var tok_i = info.while_token;
    if (tree.isTokenPrecededByTags(tok_i, &.{.keyword_inline})) {
        result.inline_token = tok_i - 1;
        tok_i = tok_i - 1;
    }
    if (tree.isTokenPrecededByTags(tok_i, &.{ .identifier, .colon })) {
        result.label_token = tok_i - 2;
    }
    const last_cond_token = tree.lastToken(info.cond_expr);
    if (tree.tokenTag(last_cond_token + 2) == .pipe) {
        result.payload_token = last_cond_token + 3;
    }
    if (info.else_expr != .none) {
        // then_expr else |x|
        //           ^    ^
        result.else_token = tree.lastToken(info.then_expr) + 1;
        if (tree.tokenTag(result.else_token + 1) == .pipe) {
            result.error_token = result.else_token + 2;
        }
    }
    return result;
}

fn fullForComponents(tree: Ast, info: full.For.Components) full.For {
    var result: full.For = .{
        .ast = info,
        .inline_token = null,
        .label_token = null,
        .payload_token = undefined,
        .else_token = undefined,
    };
    var tok_i = info.for_token;
    if (tree.isTokenPrecededByTags(tok_i, &.{.keyword_inline})) {
        result.inline_token = tok_i - 1;
        tok_i = tok_i - 1;
    }
    if (tree.isTokenPrecededByTags(tok_i, &.{ .identifier, .colon })) {
        result.label_token = tok_i - 2;
    }
    const last_cond_token = tree.lastToken(info.inputs[info.inputs.len - 1]);
    result.payload_token = last_cond_token + @as(u32, 3) + @intFromBool(tree.tokenTag(last_cond_token + 1) == .comma);
    if (info.else_expr != .none) {
        result.else_token = tree.lastToken(info.then_expr) + 1;
    }
    return result;
}

fn fullCallComponents(tree: Ast, info: full.Call.Components) full.Call {
    var result: full.Call = .{
        .ast = info,
        .async_token = null,
    };
    const first_token = tree.firstToken(info.fn_expr);
    if (tree.isTokenPrecededByTags(first_token, &.{.keyword_async})) {
        result.async_token = first_token - 1;
    }
    return result;
}

pub fn fullVarDecl(tree: Ast, node: Node.Index) ?full.VarDecl {
    return switch (tree.nodeTag(node)) {
        .global_var_decl => tree.globalVarDecl(node),
        .local_var_decl => tree.localVarDecl(node),
        .aligned_var_decl => tree.alignedVarDecl(node),
        .simple_var_decl => tree.simpleVarDecl(node),
        else => null,
    };
}

pub fn fullIf(tree: Ast, node: Node.Index) ?full.If {
    return switch (tree.nodeTag(node)) {
        .if_simple => tree.ifSimple(node),
        .@"if" => tree.ifFull(node),
        else => null,
    };
}

pub fn fullWhile(tree: Ast, node: Node.Index) ?full.While {
    return switch (tree.nodeTag(node)) {
        .while_simple => tree.whileSimple(node),
        .while_cont => tree.whileCont(node),
        .@"while" => tree.whileFull(node),
        else => null,
    };
}

pub fn fullFor(tree: Ast, node: Node.Index) ?full.For {
    return switch (tree.nodeTag(node)) {
        .for_simple => tree.forSimple(node),
        .@"for" => tree.forFull(node),
        else => null,
    };
}

pub fn fullContainerField(tree: Ast, node: Node.Index) ?full.ContainerField {
    return switch (tree.nodeTag(node)) {
        .container_field_init => tree.containerFieldInit(node),
        .container_field_align => tree.containerFieldAlign(node),
        .container_field => tree.containerField(node),
        else => null,
    };
}

pub fn fullFnProto(tree: Ast, buffer: *[1]Ast.Node.Index, node: Node.Index) ?full.FnProto {
    return switch (tree.nodeTag(node)) {
        .fn_proto => tree.fnProto(node),
        .fn_proto_multi => tree.fnProtoMulti(node),
        .fn_proto_one => tree.fnProtoOne(buffer, node),
        .fn_proto_simple => tree.fnProtoSimple(buffer, node),
        .fn_decl => tree.fullFnProto(buffer, tree.nodeData(node).node_and_node[0]),
        else => null,
    };
}

pub fn fullStructInit(tree: Ast, buffer: *[2]Ast.Node.Index, node: Node.Index) ?full.StructInit {
    return switch (tree.nodeTag(node)) {
        .struct_init_one, .struct_init_one_comma => tree.structInitOne(buffer[0..1], node),
        .struct_init_dot_two, .struct_init_dot_two_comma => tree.structInitDotTwo(buffer, node),
        .struct_init_dot, .struct_init_dot_comma => tree.structInitDot(node),
        .struct_init, .struct_init_comma => tree.structInit(node),
        else => null,
    };
}

pub fn fullArrayInit(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) ?full.ArrayInit {
    return switch (tree.nodeTag(node)) {
        .array_init_one, .array_init_one_comma => tree.arrayInitOne(buffer[0..1], node),
        .array_init_dot_two, .array_init_dot_two_comma => tree.arrayInitDotTwo(buffer, node),
        .array_init_dot, .array_init_dot_comma => tree.arrayInitDot(node),
        .array_init, .array_init_comma => tree.arrayInit(node),
        else => null,
    };
}

pub fn fullArrayType(tree: Ast, node: Node.Index) ?full.ArrayType {
    return switch (tree.nodeTag(node)) {
        .array_type => tree.arrayType(node),
        .array_type_sentinel => tree.arrayTypeSentinel(node),
        else => null,
    };
}

pub fn fullPtrType(tree: Ast, node: Node.Index) ?full.PtrType {
    return switch (tree.nodeTag(node)) {
        .ptr_type_aligned => tree.ptrTypeAligned(node),
        .ptr_type_sentinel => tree.ptrTypeSentinel(node),
        .ptr_type => tree.ptrType(node),
        .ptr_type_bit_range => tree.ptrTypeBitRange(node),
        else => null,
    };
}

pub fn fullSlice(tree: Ast, node: Node.Index) ?full.Slice {
    return switch (tree.nodeTag(node)) {
        .slice_open => tree.sliceOpen(node),
        .slice => tree.slice(node),
        .slice_sentinel => tree.sliceSentinel(node),
        else => null,
    };
}

pub fn fullContainerDecl(tree: Ast, buffer: *[2]Ast.Node.Index, node: Node.Index) ?full.ContainerDecl {
    return switch (tree.nodeTag(node)) {
        .root => tree.containerDeclRoot(),
        .container_decl, .container_decl_trailing => tree.containerDecl(node),
        .container_decl_arg, .container_decl_arg_trailing => tree.containerDeclArg(node),
        .container_decl_two, .container_decl_two_trailing => tree.containerDeclTwo(buffer, node),
        .tagged_union, .tagged_union_trailing => tree.taggedUnion(node),
        .tagged_union_enum_tag, .tagged_union_enum_tag_trailing => tree.taggedUnionEnumTag(node),
        .tagged_union_two, .tagged_union_two_trailing => tree.taggedUnionTwo(buffer, node),
        else => null,
    };
}

pub fn fullSwitch(tree: Ast, node: Node.Index) ?full.Switch {
    return switch (tree.nodeTag(node)) {
        .@"switch", .switch_comma => tree.switchFull(node),
        else => null,
    };
}

pub fn fullSwitchCase(tree: Ast, node: Node.Index) ?full.SwitchCase {
    return switch (tree.nodeTag(node)) {
        .switch_case_one, .switch_case_inline_one => tree.switchCaseOne(node),
        .switch_case, .switch_case_inline => tree.switchCase(node),
        else => null,
    };
}

pub fn fullAsm(tree: Ast, node: Node.Index) ?full.Asm {
    return switch (tree.nodeTag(node)) {
        .asm_simple => tree.asmSimple(node),
        .@"asm" => tree.asmFull(node),
        else => null,
    };
}

pub fn fullCall(tree: Ast, buffer: *[1]Ast.Node.Index, node: Node.Index) ?full.Call {
    return switch (tree.nodeTag(node)) {
        .call, .call_comma, .async_call, .async_call_comma => tree.callFull(node),
        .call_one, .call_one_comma, .async_call_one, .async_call_one_comma => tree.callOne(buffer, node),
        else => null,
    };
}

pub fn builtinCallParams(tree: Ast, buffer: *[2]Ast.Node.Index, node: Ast.Node.Index) ?[]const Node.Index {
    return switch (tree.nodeTag(node)) {
        .builtin_call_two, .builtin_call_two_comma => loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node),
        .builtin_call, .builtin_call_comma => tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index),
        else => null,
    };
}

pub fn blockStatements(tree: Ast, buffer: *[2]Ast.Node.Index, node: Ast.Node.Index) ?[]const Node.Index {
    return switch (tree.nodeTag(node)) {
        .block_two, .block_two_semicolon => loadOptionalNodesIntoBuffer(2, buffer, tree.nodeData(node).opt_node_and_opt_node),
        .block, .block_semicolon => tree.extraDataSlice(tree.nodeData(node).extra_range, Node.Index),
        else => null,
    };
}

/// Fully assembled AST node information.
pub const full = struct {
    pub const VarDecl = struct {
        visib_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?TokenIndex,
        threadlocal_token: ?TokenIndex,
        comptime_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            mut_token: TokenIndex,
            type_node: Node.OptionalIndex,
            align_node: Node.OptionalIndex,
            addrspace_node: Node.OptionalIndex,
            section_node: Node.OptionalIndex,
            init_node: Node.OptionalIndex,
        };

        pub fn firstToken(var_decl: VarDecl) TokenIndex {
            return var_decl.visib_token orelse
                var_decl.extern_export_token orelse
                var_decl.threadlocal_token orelse
                var_decl.comptime_token orelse
                var_decl.ast.mut_token;
        }
    };

    pub const AssignDestructure = struct {
        comptime_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            variables: []const Node.Index,
            equal_token: TokenIndex,
            value_expr: Node.Index,
        };
    };

    pub const If = struct {
        /// Points to the first token after the `|`. Will either be an identifier or
        /// a `*` (with an identifier immediately after it).
        payload_token: ?TokenIndex,
        /// Points to the identifier after the `|`.
        error_token: ?TokenIndex,
        /// Populated only if else_expr != .none.
        else_token: TokenIndex,
        ast: Components,

        pub const Components = struct {
            if_token: TokenIndex,
            cond_expr: Node.Index,
            then_expr: Node.Index,
            else_expr: Node.OptionalIndex,
        };
    };

    pub const While = struct {
        ast: Components,
        inline_token: ?TokenIndex,
        label_token: ?TokenIndex,
        payload_token: ?TokenIndex,
        error_token: ?TokenIndex,
        /// Populated only if else_expr != none.
        else_token: TokenIndex,

        pub const Components = struct {
            while_token: TokenIndex,
            cond_expr: Node.Index,
            cont_expr: Node.OptionalIndex,
            then_expr: Node.Index,
            else_expr: Node.OptionalIndex,
        };
    };

    pub const For = struct {
        ast: Components,
        inline_token: ?TokenIndex,
        label_token: ?TokenIndex,
        payload_token: TokenIndex,
        /// Populated only if else_expr != .none.
        else_token: ?TokenIndex,

        pub const Components = struct {
            for_token: TokenIndex,
            inputs: []const Node.Index,
            then_expr: Node.Index,
            else_expr: Node.OptionalIndex,
        };
    };

    pub const ContainerField = struct {
        comptime_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            main_token: TokenIndex,
            /// Can only be `.none` after calling `convertToNonTupleLike`.
            type_expr: Node.OptionalIndex,
            align_expr: Node.OptionalIndex,
            value_expr: Node.OptionalIndex,
            tuple_like: bool,
        };

        pub fn firstToken(cf: ContainerField) TokenIndex {
            return cf.comptime_token orelse cf.ast.main_token;
        }

        pub fn convertToNonTupleLike(cf: *ContainerField, tree: *const Ast) void {
            if (!cf.ast.tuple_like) return;
            if (tree.nodeTag(cf.ast.type_expr.unwrap().?) != .identifier) return;

            cf.ast.type_expr = .none;
            cf.ast.tuple_like = false;
        }
    };

    pub const FnProto = struct {
        visib_token: ?TokenIndex,
        extern_export_inline_token: ?TokenIndex,
        lib_name: ?TokenIndex,
        name_token: ?TokenIndex,
        lparen: TokenIndex,
        ast: Components,

        pub const Components = struct {
            proto_node: Node.Index,
            fn_token: TokenIndex,
            return_type: Node.OptionalIndex,
            params: []const Node.Index,
            align_expr: Node.OptionalIndex,
            addrspace_expr: Node.OptionalIndex,
            section_expr: Node.OptionalIndex,
            callconv_expr: Node.OptionalIndex,
        };

        pub const Param = struct {
            first_doc_comment: ?TokenIndex,
            name_token: ?TokenIndex,
            comptime_noalias: ?TokenIndex,
            anytype_ellipsis3: ?TokenIndex,
            type_expr: ?Node.Index,
        };

        pub fn firstToken(fn_proto: FnProto) TokenIndex {
            return fn_proto.visib_token orelse
                fn_proto.extern_export_inline_token orelse
                fn_proto.ast.fn_token;
        }

        /// Abstracts over the fact that anytype and ... are not included
        /// in the params slice, since they are simple identifiers and
        /// not sub-expressions.
        pub const Iterator = struct {
            tree: *const Ast,
            fn_proto: *const FnProto,
            param_i: usize,
            tok_i: TokenIndex,
            tok_flag: bool,

            pub fn next(it: *Iterator) ?Param {
                const tree = it.tree;
                while (true) {
                    var first_doc_comment: ?TokenIndex = null;
                    var comptime_noalias: ?TokenIndex = null;
                    var name_token: ?TokenIndex = null;
                    if (!it.tok_flag) {
                        if (it.param_i >= it.fn_proto.ast.params.len) {
                            return null;
                        }
                        const param_type = it.fn_proto.ast.params[it.param_i];
                        var tok_i = tree.firstToken(param_type) - 1;
                        while (true) : (tok_i -= 1) switch (tree.tokenTag(tok_i)) {
                            .colon => continue,
                            .identifier => name_token = tok_i,
                            .doc_comment => first_doc_comment = tok_i,
                            .keyword_comptime, .keyword_noalias => comptime_noalias = tok_i,
                            else => break,
                        };
                        it.param_i += 1;
                        it.tok_i = tree.lastToken(param_type) + 1;
                        // Look for anytype and ... params afterwards.
                        if (tree.tokenTag(it.tok_i) == .comma) {
                            it.tok_i += 1;
                        }
                        it.tok_flag = true;
                        return Param{
                            .first_doc_comment = first_doc_comment,
                            .comptime_noalias = comptime_noalias,
                            .name_token = name_token,
                            .anytype_ellipsis3 = null,
                            .type_expr = param_type,
                        };
                    }
                    if (tree.tokenTag(it.tok_i) == .comma) {
                        it.tok_i += 1;
                    }
                    if (tree.tokenTag(it.tok_i) == .r_paren) {
                        return null;
                    }
                    if (tree.tokenTag(it.tok_i) == .doc_comment) {
                        first_doc_comment = it.tok_i;
                        while (tree.tokenTag(it.tok_i) == .doc_comment) {
                            it.tok_i += 1;
                        }
                    }
                    switch (tree.tokenTag(it.tok_i)) {
                        .ellipsis3 => {
                            it.tok_flag = false; // Next iteration should return null.
                            return Param{
                                .first_doc_comment = first_doc_comment,
                                .comptime_noalias = null,
                                .name_token = null,
                                .anytype_ellipsis3 = it.tok_i,
                                .type_expr = null,
                            };
                        },
                        .keyword_noalias, .keyword_comptime => {
                            comptime_noalias = it.tok_i;
                            it.tok_i += 1;
                        },
                        else => {},
                    }
                    if (tree.tokenTag(it.tok_i) == .identifier and
                        tree.tokenTag(it.tok_i + 1) == .colon)
                    {
                        name_token = it.tok_i;
                        it.tok_i += 2;
                    }
                    if (tree.tokenTag(it.tok_i) == .keyword_anytype) {
                        it.tok_i += 1;
                        return Param{
                            .first_doc_comment = first_doc_comment,
                            .comptime_noalias = comptime_noalias,
                            .name_token = name_token,
                            .anytype_ellipsis3 = it.tok_i - 1,
                            .type_expr = null,
                        };
                    }
                    it.tok_flag = false;
                }
            }
        };

        pub fn iterate(fn_proto: *const FnProto, tree: *const Ast) Iterator {
            return .{
                .tree = tree,
                .fn_proto = fn_proto,
                .param_i = 0,
                .tok_i = fn_proto.lparen + 1,
                .tok_flag = true,
            };
        }
    };

    pub const StructInit = struct {
        ast: Components,

        pub const Components = struct {
            lbrace: TokenIndex,
            fields: []const Node.Index,
            type_expr: Node.OptionalIndex,
        };
    };

    pub const ArrayInit = struct {
        ast: Components,

        pub const Components = struct {
            lbrace: TokenIndex,
            elements: []const Node.Index,
            type_expr: Node.OptionalIndex,
        };
    };

    pub const ArrayType = struct {
        ast: Components,

        pub const Components = struct {
            lbracket: TokenIndex,
            elem_count: Node.Index,
            sentinel: Node.OptionalIndex,
            elem_type: Node.Index,
        };
    };

    pub const PtrType = struct {
        size: std.builtin.Type.Pointer.Size,
        allowzero_token: ?TokenIndex,
        const_token: ?TokenIndex,
        volatile_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            main_token: TokenIndex,
            align_node: Node.OptionalIndex,
            addrspace_node: Node.OptionalIndex,
            sentinel: Node.OptionalIndex,
            bit_range_start: Node.OptionalIndex,
            bit_range_end: Node.OptionalIndex,
            child_type: Node.Index,
        };
    };

    pub const Slice = struct {
        ast: Components,

        pub const Components = struct {
            sliced: Node.Index,
            lbracket: TokenIndex,
            start: Node.Index,
            end: Node.OptionalIndex,
            sentinel: Node.OptionalIndex,
        };
    };

    pub const ContainerDecl = struct {
        layout_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            main_token: TokenIndex,
            /// Populated when main_token is Keyword_union.
            enum_token: ?TokenIndex,
            members: []const Node.Index,
            arg: Node.OptionalIndex,
        };
    };

    pub const Switch = struct {
        ast: Components,
        label_token: ?TokenIndex,

        pub const Components = struct {
            switch_token: TokenIndex,
            condition: Node.Index,
            cases: []const Node.Index,
        };
    };

    pub const SwitchCase = struct {
        inline_token: ?TokenIndex,
        /// Points to the first token after the `|`. Will either be an identifier or
        /// a `*` (with an identifier immediately after it).
        payload_token: ?TokenIndex,
        ast: Components,

        pub const Components = struct {
            /// If empty, this is an else case
            values: []const Node.Index,
            arrow_token: TokenIndex,
            target_expr: Node.Index,
        };
    };

    pub const Asm = struct {
        ast: Components,
        volatile_token: ?TokenIndex,
        first_clobber: ?TokenIndex,
        outputs: []const Node.Index,
        inputs: []const Node.Index,

        pub const Components = struct {
            asm_token: TokenIndex,
            template: Node.Index,
            items: []const Node.Index,
            rparen: TokenIndex,
        };
    };

    pub const Call = struct {
        ast: Components,
        async_token: ?TokenIndex,

        pub const Components = struct {
            lparen: TokenIndex,
            fn_expr: Node.Index,
            params: []const Node.Index,
        };
    };
};

pub const Error = struct {
    tag: Tag,
    is_note: bool = false,
    /// True if `token` points to the token before the token causing an issue.
    token_is_prev: bool = false,
    token: TokenIndex,
    extra: union {
        none: void,
        expected_tag: Token.Tag,
        offset: usize,
    } = .{ .none = {} },

    pub const Tag = enum {
        asterisk_after_ptr_deref,
        chained_comparison_operators,
        decl_between_fields,
        expected_block,
        expected_block_or_assignment,
        expected_block_or_expr,
        expected_block_or_field,
        expected_container_members,
        expected_expr,
        expected_expr_or_assignment,
        expected_expr_or_var_decl,
        expected_fn,
        expected_inlinable,
        expected_labelable,
        expected_param_list,
        expected_prefix_expr,
        expected_primary_type_expr,
        expected_pub_item,
        expected_return_type,
        expected_semi_or_else,
        expected_semi_or_lbrace,
        expected_statement,
        expected_suffix_op,
        expected_type_expr,
        expected_var_decl,
        expected_var_decl_or_fn,
        expected_loop_payload,
        expected_container,
        extern_fn_body,
        extra_addrspace_qualifier,
        extra_align_qualifier,
        extra_allowzero_qualifier,
        extra_const_qualifier,
        extra_volatile_qualifier,
        ptr_mod_on_array_child_type,
        invalid_bit_range,
        same_line_doc_comment,
        unattached_doc_comment,
        test_doc_comment,
        comptime_doc_comment,
        varargs_nonfinal,
        expected_continue_expr,
        expected_semi_after_decl,
        expected_semi_after_stmt,
        expected_comma_after_field,
        expected_comma_after_arg,
        expected_comma_after_param,
        expected_comma_after_initializer,
        expected_comma_after_switch_prong,
        expected_comma_after_for_operand,
        expected_comma_after_capture,
        expected_initializer,
        mismatched_binary_op_whitespace,
        invalid_ampersand_ampersand,
        c_style_container,
        expected_var_const,
        wrong_equal_var_decl,
        var_const_decl,
        extra_for_capture,
        for_input_not_captured,

        zig_style_container,
        previous_field,
        next_field,

        /// `expected_tag` is populated.
        expected_token,

        /// `offset` is populated
        invalid_byte,
    };
};

/// Index into `extra_data`.
pub const ExtraIndex = enum(u32) {
    _,
};

pub const Node = struct {
    tag: Tag,
    main_token: TokenIndex,
    data: Data,

    /// Index into `nodes`.
    pub const Index = enum(u32) {
        root = 0,
        _,

        pub fn toOptional(i: Index) OptionalIndex {
            const result: OptionalIndex = @enumFromInt(@intFromEnum(i));
            assert(result != .none);
            return result;
        }

        pub fn toOffset(base: Index, destination: Index) Offset {
            const base_i64: i64 = @intFromEnum(base);
            const destination_i64: i64 = @intFromEnum(destination);
            return @enumFromInt(destination_i64 - base_i64);
        }
    };

    /// Index into `nodes`, or null.
    pub const OptionalIndex = enum(u32) {
        root = 0,
        none = std.math.maxInt(u32),
        _,

        pub fn unwrap(oi: OptionalIndex) ?Index {
            return if (oi == .none) null else @enumFromInt(@intFromEnum(oi));
        }

        pub fn fromOptional(oi: ?Index) OptionalIndex {
            return if (oi) |i| i.toOptional() else .none;
        }
    };

    /// A relative node index.
    pub const Offset = enum(i32) {
        zero = 0,
        _,

        pub fn toOptional(o: Offset) OptionalOffset {
            const result: OptionalOffset = @enumFromInt(@intFromEnum(o));
            assert(result != .none);
            return result;
        }

        pub fn toAbsolute(offset: Offset, base: Index) Index {
            return @enumFromInt(@as(i64, @intFromEnum(base)) + @intFromEnum(offset));
        }
    };

    /// A relative node index, or null.
    pub const OptionalOffset = enum(i32) {
        none = std.math.maxInt(i32),
        _,

        pub fn unwrap(oo: OptionalOffset) ?Offset {
            return if (oo == .none) null else @enumFromInt(@intFromEnum(oo));
        }
    };

    comptime {
        // Goal is to keep this under one byte for efficiency.
        assert(@sizeOf(Tag) == 1);

        if (!std.debug.runtime_safety) {
            assert(@sizeOf(Data) == 8);
        }
    }

    /// The FooComma/FooSemicolon variants exist to ease the implementation of
    /// `Ast.lastToken()`
    pub const Tag = enum {
        /// The root node which is guaranteed to be at `Node.Index.root`.
        /// The meaning of the `data` field depends on whether it is a `.zig` or
        /// `.zon` file.
        ///
        /// The `main_token` field is the first token for the source file.
        root,
        /// `usingnamespace expr;`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `usingnamespace` token.
        @"usingnamespace",
        /// `test {}`,
        /// `test "name" {}`,
        /// `test identifier {}`.
        ///
        /// The `data` field is a `.opt_token_and_node`:
        ///   1. a `OptionalTokenIndex` to the test name token (must be string literal or identifier), if any.
        ///   2. a `Node.Index` to the block.
        ///
        /// The `main_token` field is the `test` token.
        test_decl,
        /// The `data` field is a `.extra_and_opt_node`:
        ///   1. a `ExtraIndex` to `GlobalVarDecl`.
        ///   2. a `Node.OptionalIndex` to the initialization expression.
        ///
        /// The `main_token` field is the `var` or `const` token.
        ///
        /// The initialization expression can't be `.none` unless it is part of
        /// a `assign_destructure` node or a parsing error occured.
        global_var_decl,
        /// `var a: b align(c) = d`.
        /// `const main_token: type_node align(align_node) = init_expr`.
        ///
        /// The `data` field is a `.extra_and_opt_node`:
        ///   1. a `ExtraIndex` to `LocalVarDecl`.
        ///   2. a `Node.OptionalIndex` to the initialization expression-
        ///
        /// The `main_token` field is the `var` or `const` token.
        ///
        /// The initialization expression can't be `.none` unless it is part of
        /// a `assign_destructure` node or a parsing error occured.
        local_var_decl,
        /// `var a: b = c`.
        /// `const name_token: type_expr = init_expr`.
        /// Can be local or global.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the type expression, if any.
        ///   2. a `Node.OptionalIndex` to the initialization expression.
        ///
        /// The `main_token` field is the `var` or `const` token.
        ///
        /// The initialization expression can't be `.none` unless it is part of
        /// a `assign_destructure` node or a parsing error occured.
        simple_var_decl,
        /// `var a align(b) = c`.
        /// `const name_token align(align_expr) = init_expr`.
        /// Can be local or global.
        ///
        /// The `data` field is a `.node_and_opt_node`:
        ///   1. a `Node.Index` to the alignment expression.
        ///   2. a `Node.OptionalIndex` to the initialization expression.
        ///
        /// The `main_token` field is the `var` or `const` token.
        ///
        /// The initialization expression can't be `.none` unless it is part of
        /// a `assign_destructure` node or a parsing error occured.
        aligned_var_decl,
        /// `errdefer expr`,
        /// `errdefer |payload| expr`.
        ///
        /// The `data` field is a `.opt_token_and_node`:
        ///   1. a `OptionalTokenIndex` to the payload identifier, if any.
        ///   2. a `Node.Index` to the deferred expression.
        ///
        /// The `main_token` field is the `errdefer` token.
        @"errdefer",
        /// `defer expr`.
        ///
        /// The `data` field is a `.node` to the deferred expression.
        ///
        /// The `main_token` field is the `defer`.
        @"defer",
        /// `lhs catch rhs`,
        /// `lhs catch |err| rhs`.
        ///
        /// The `main_token` field is the `catch` token.
        ///
        /// The error payload is determined by looking at the next token after
        /// the `catch` token.
        @"catch",
        /// `lhs.a`.
        ///
        /// The `data` field is a `.node_and_token`:
        ///   1. a `Node.Index` to the left side of the field access.
        ///   2. a `TokenIndex` to the field name identifier.
        ///
        /// The `main_token` field is the `.` token.
        field_access,
        /// `lhs.?`.
        ///
        /// The `data` field is a `.node_and_token`:
        ///   1. a `Node.Index` to the left side of the optional unwrap.
        ///   2. a `TokenIndex` to the `?` token.
        ///
        /// The `main_token` field is the `.` token.
        unwrap_optional,
        /// `lhs == rhs`. The `main_token` field is the `==` token.
        equal_equal,
        /// `lhs != rhs`. The `main_token` field is the `!=` token.
        bang_equal,
        /// `lhs < rhs`. The `main_token` field is the `<` token.
        less_than,
        /// `lhs > rhs`. The `main_token` field is the `>` token.
        greater_than,
        /// `lhs <= rhs`. The `main_token` field is the `<=` token.
        less_or_equal,
        /// `lhs >= rhs`. The `main_token` field is the `>=` token.
        greater_or_equal,
        /// `lhs *= rhs`. The `main_token` field is the `*=` token.
        assign_mul,
        /// `lhs /= rhs`. The `main_token` field is the `/=` token.
        assign_div,
        /// `lhs %= rhs`. The `main_token` field is the `%=` token.
        assign_mod,
        /// `lhs += rhs`. The `main_token` field is the `+=` token.
        assign_add,
        /// `lhs -= rhs`. The `main_token` field is the `-=` token.
        assign_sub,
        /// `lhs <<= rhs`. The `main_token` field is the `<<=` token.
        assign_shl,
        /// `lhs <<|= rhs`. The `main_token` field is the `<<|=` token.
        assign_shl_sat,
        /// `lhs >>= rhs`. The `main_token` field is the `>>=` token.
        assign_shr,
        /// `lhs &= rhs`. The `main_token` field is the `&=` token.
        assign_bit_and,
        /// `lhs ^= rhs`. The `main_token` field is the `^=` token.
        assign_bit_xor,
        /// `lhs |= rhs`. The `main_token` field is the `|=` token.
        assign_bit_or,
        /// `lhs *%= rhs`. The `main_token` field is the `*%=` token.
        assign_mul_wrap,
        /// `lhs +%= rhs`. The `main_token` field is the `+%=` token.
        assign_add_wrap,
        /// `lhs -%= rhs`. The `main_token` field is the `-%=` token.
        assign_sub_wrap,
        /// `lhs *|= rhs`. The `main_token` field is the `*%=` token.
        assign_mul_sat,
        /// `lhs +|= rhs`. The `main_token` field is the `+|=` token.
        assign_add_sat,
        /// `lhs -|= rhs`. The `main_token` field is the `-|=` token.
        assign_sub_sat,
        /// `lhs = rhs`. The `main_token` field is the `=` token.
        assign,
        /// `a, b, ... = rhs`.
        ///
        /// The `data` field is a `.extra_and_node`:
        ///   1. a `ExtraIndex`. Further explained below.
        ///   2. a `Node.Index` to the initialization expression.
        ///
        /// The `main_token` field is the `=` token.
        ///
        /// The `ExtraIndex` stores the following data:
        /// ```
        /// elem_count: u32,
        /// variables: [elem_count]Node.Index,
        /// ```
        ///
        /// Each node in `variables` has one of the following tags:
        ///   - `global_var_decl`
        ///   - `local_var_decl`
        ///   - `simple_var_decl`
        ///   - `aligned_var_decl`
        ///   - Any expression node
        ///
        /// The first 4 tags correspond to a `var` or `const` lhs node (note
        /// that their initialization expression is always `.none`).
        /// An expression node corresponds to a standard assignment LHS (which
        /// must be evaluated as an lvalue). There may be a preceding
        /// `comptime` token, which does not create a corresponding `comptime`
        /// node so must be manually detected.
        assign_destructure,
        /// `lhs || rhs`. The `main_token` field is the `||` token.
        merge_error_sets,
        /// `lhs * rhs`. The `main_token` field is the `*` token.
        mul,
        /// `lhs / rhs`. The `main_token` field is the `/` token.
        div,
        /// `lhs % rhs`. The `main_token` field is the `%` token.
        mod,
        /// `lhs ** rhs`. The `main_token` field is the `**` token.
        array_mult,
        /// `lhs *% rhs`. The `main_token` field is the `*%` token.
        mul_wrap,
        /// `lhs *| rhs`. The `main_token` field is the `*|` token.
        mul_sat,
        /// `lhs + rhs`. The `main_token` field is the `+` token.
        add,
        /// `lhs - rhs`. The `main_token` field is the `-` token.
        sub,
        /// `lhs ++ rhs`. The `main_token` field is the `++` token.
        array_cat,
        /// `lhs +% rhs`. The `main_token` field is the `+%` token.
        add_wrap,
        /// `lhs -% rhs`. The `main_token` field is the `-%` token.
        sub_wrap,
        /// `lhs +| rhs`. The `main_token` field is the `+|` token.
        add_sat,
        /// `lhs -| rhs`. The `main_token` field is the `-|` token.
        sub_sat,
        /// `lhs << rhs`. The `main_token` field is the `<<` token.
        shl,
        /// `lhs <<| rhs`. The `main_token` field is the `<<|` token.
        shl_sat,
        /// `lhs >> rhs`. The `main_token` field is the `>>` token.
        shr,
        /// `lhs & rhs`. The `main_token` field is the `&` token.
        bit_and,
        /// `lhs ^ rhs`. The `main_token` field is the `^` token.
        bit_xor,
        /// `lhs | rhs`. The `main_token` field is the `|` token.
        bit_or,
        /// `lhs orelse rhs`. The `main_token` field is the `orelse` token.
        @"orelse",
        /// `lhs and rhs`. The `main_token` field is the `and` token.
        bool_and,
        /// `lhs or rhs`. The `main_token` field is the `or` token.
        bool_or,
        /// `!expr`. The `main_token` field is the `!` token.
        bool_not,
        /// `-expr`. The `main_token` field is the `-` token.
        negation,
        /// `~expr`. The `main_token` field is the `~` token.
        bit_not,
        /// `-%expr`. The `main_token` field is the `-%` token.
        negation_wrap,
        /// `&expr`. The `main_token` field is the `&` token.
        address_of,
        /// `try expr`. The `main_token` field is the `try` token.
        @"try",
        /// `await expr`. The `main_token` field is the `await` token.
        @"await",
        /// `?expr`. The `main_token` field is the `?` token.
        optional_type,
        /// `[lhs]rhs`. The `main_token` field is the `[` token.
        array_type,
        /// `[lhs:a]b`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the length expression.
        ///   2. a `ExtraIndex` to `ArrayTypeSentinel`.
        ///
        /// The `main_token` field is the `[` token.
        array_type_sentinel,
        /// `[*]align(lhs) rhs`,
        /// `*align(lhs) rhs`,
        /// `[]rhs`.
        ///
        /// The `data` field is a `.opt_node_and_node`:
        ///   1. a `Node.OptionalIndex` to the alignment expression, if any.
        ///   2. a `Node.Index` to the element type expression.
        ///
        /// The `main_token` is the asterisk if a single item pointer or the
        /// lbracket if a slice, many-item pointer, or C-pointer.
        /// The `main_token` might be a ** token, which is shared with a
        /// parent/child pointer type and may require special handling.
        ptr_type_aligned,
        /// `[*:lhs]rhs`,
        /// `*rhs`,
        /// `[:lhs]rhs`.
        ///
        /// The `data` field is a `.opt_node_and_node`:
        ///   1. a `Node.OptionalIndex` to the sentinel expression, if any.
        ///   2. a `Node.Index` to the element type expression.
        ///
        /// The `main_token` is the asterisk if a single item pointer or the
        /// lbracket if a slice, many-item pointer, or C-pointer.
        /// The `main_token` might be a ** token, which is shared with a
        /// parent/child pointer type and may require special handling.
        ptr_type_sentinel,
        /// The `data` field is a `.extra_and_node`:
        ///   1. a `ExtraIndex` to `PtrType`.
        ///   2. a `Node.Index` to the element type expression.
        ///
        /// The `main_token` is the asterisk if a single item pointer or the
        /// lbracket if a slice, many-item pointer, or C-pointer.
        /// The `main_token` might be a ** token, which is shared with a
        /// parent/child pointer type and may require special handling.
        ptr_type,
        /// The `data` field is a `.extra_and_node`:
        ///   1. a `ExtraIndex` to `PtrTypeBitRange`.
        ///   2. a `Node.Index` to the element type expression.
        ///
        /// The `main_token` is the asterisk if a single item pointer or the
        /// lbracket if a slice, many-item pointer, or C-pointer.
        /// The `main_token` might be a ** token, which is shared with a
        /// parent/child pointer type and may require special handling.
        ptr_type_bit_range,
        /// `lhs[rhs..]`
        ///
        /// The `main_token` field is the `[` token.
        slice_open,
        /// `sliced[start..end]`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the sliced expression.
        ///   2. a `ExtraIndex` to `Slice`.
        ///
        /// The `main_token` field is the `[` token.
        slice,
        /// `sliced[start..end :sentinel]`,
        /// `sliced[start.. :sentinel]`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the sliced expression.
        ///   2. a `ExtraIndex` to `SliceSentinel`.
        ///
        /// The `main_token` field is the `[` token.
        slice_sentinel,
        /// `expr.*`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `*` token.
        deref,
        /// `lhs[rhs]`.
        ///
        /// The `main_token` field is the `[` token.
        array_access,
        /// `lhs{rhs}`.
        ///
        /// The `main_token` field is the `{` token.
        array_init_one,
        /// Same as `array_init_one` except there is known to be a trailing
        /// comma before the final rbrace.
        array_init_one_comma,
        /// `.{a}`,
        /// `.{a, b}`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first element. Never `.none`
        ///   2. a `Node.OptionalIndex` to the second element, if any.
        ///
        /// The `main_token` field is the `{` token.
        array_init_dot_two,
        /// Same as `array_init_dot_two` except there is known to be a trailing
        /// comma before the final rbrace.
        array_init_dot_two_comma,
        /// `.{a, b, c}`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each element.
        ///
        /// The `main_token` field is the `{` token.
        array_init_dot,
        /// Same as `array_init_dot` except there is known to be a trailing
        /// comma before the final rbrace.
        array_init_dot_comma,
        /// `a{b, c}`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the type expression.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each element.
        ///
        /// The `main_token` field is the `{` token.
        array_init,
        /// Same as `array_init` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_comma,
        /// `a{.x = b}`, `a{}`.
        ///
        /// The `data` field is a `.node_and_opt_node`:
        ///   1. a `Node.Index` to the type expression.
        ///   2. a `Node.OptionalIndex` to the first field initialization, if any.
        ///
        /// The `main_token` field is the `{` token.
        ///
        /// The field name is determined by looking at the tokens preceding the
        /// field initialization.
        struct_init_one,
        /// Same as `struct_init_one` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_one_comma,
        /// `.{.x = a, .y = b}`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first field initialization. Never `.none`
        ///   2. a `Node.OptionalIndex` to the second field initialization, if any.
        ///
        /// The `main_token` field is the '{' token.
        ///
        /// The field name is determined by looking at the tokens preceding the
        /// field initialization.
        struct_init_dot_two,
        /// Same as `struct_init_dot_two` except there is known to be a trailing
        /// comma before the final rbrace.
        struct_init_dot_two_comma,
        /// `.{.x = a, .y = b, .z = c}`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each field initialization.
        ///
        /// The `main_token` field is the `{` token.
        ///
        /// The field name is determined by looking at the tokens preceding the
        /// field initialization.
        struct_init_dot,
        /// Same as `struct_init_dot` except there is known to be a trailing
        /// comma before the final rbrace.
        struct_init_dot_comma,
        /// `a{.x = b, .y = c}`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the type expression.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each field initialization.
        ///
        /// The `main_token` field is the `{` token.
        ///
        /// The field name is determined by looking at the tokens preceding the
        /// field initialization.
        struct_init,
        /// Same as `struct_init` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_comma,
        /// `a(b)`, `a()`.
        ///
        /// The `data` field is a `.node_and_opt_node`:
        ///   1. a `Node.Index` to the function expression.
        ///   2. a `Node.OptionalIndex` to the first argument, if any.
        ///
        /// The `main_token` field is the `(` token.
        call_one,
        /// Same as `call_one` except there is known to be a trailing comma
        /// before the final rparen.
        call_one_comma,
        /// `async a(b)`, `async a()`.
        ///
        /// The `data` field is a `.node_and_opt_node`:
        ///   1. a `Node.Index` to the function expression.
        ///   2. a `Node.OptionalIndex` to the first argument, if any.
        ///
        /// The `main_token` field is the `(` token.
        async_call_one,
        /// Same as `async_call_one` except there is known to be a trailing
        /// comma before the final rparen.
        async_call_one_comma,
        /// `a(b, c, d)`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the function expression.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each argument.
        ///
        /// The `main_token` field is the `(` token.
        call,
        /// Same as `call` except there is known to be a trailing comma before
        /// the final rparen.
        call_comma,
        /// `async a(b, c, d)`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the function expression.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each argument.
        ///
        /// The `main_token` field is the `(` token.
        async_call,
        /// Same as `async_call` except there is known to be a trailing comma
        /// before the final rparen.
        async_call_comma,
        /// `switch(a) {}`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the switch operand.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each switch case.
        ///
        /// `The `main_token` field` is the identifier of a preceding label, if any; otherwise `switch`.
        @"switch",
        /// Same as `switch` except there is known to be a trailing comma before
        /// the final rbrace.
        switch_comma,
        /// `a => b`,
        /// `else => b`.
        ///
        /// The `data` field is a `.opt_node_and_node`:
        ///   1. a `Node.OptionalIndex` where `.none` means `else`.
        ///   2. a `Node.Index` to the target expression.
        ///
        /// The `main_token` field is the `=>` token.
        switch_case_one,
        /// Same as `switch_case_one` but the case is inline.
        switch_case_inline_one,
        /// `a, b, c => d`.
        ///
        /// The `data` field is a `.extra_and_node`:
        ///   1. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each switch item.
        ///   2. a `Node.Index` to the target expression.
        ///
        /// The `main_token` field is the `=>` token.
        switch_case,
        /// Same as `switch_case` but the case is inline.
        switch_case_inline,
        /// `lhs...rhs`.
        ///
        /// The `main_token` field is the `...` token.
        switch_range,
        /// `while (a) b`,
        /// `while (a) |x| b`.
        while_simple,
        /// `while (a) : (b) c`,
        /// `while (a) |x| : (b) c`.
        while_cont,
        /// `while (a) : (b) c else d`,
        /// `while (a) |x| : (b) c else d`,
        /// `while (a) |x| : (b) c else |y| d`.
        /// The continue expression part `: (b)` may be omitted.
        @"while",
        /// `for (a) b`.
        for_simple,
        /// `for (lhs[0..inputs]) lhs[inputs + 1] else lhs[inputs + 2]`. `For[rhs]`.
        @"for",
        /// `lhs..rhs`, `lhs..`.
        for_range,
        /// `if (a) b`.
        /// `if (b) |x| b`.
        if_simple,
        /// `if (a) b else c`.
        /// `if (a) |x| b else c`.
        /// `if (a) |x| b else |y| d`.
        @"if",
        /// `suspend expr`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `suspend` token.
        @"suspend",
        /// `resume expr`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `resume` token.
        @"resume",
        /// `continue :label expr`,
        /// `continue expr`,
        /// `continue :label`,
        /// `continue`.
        ///
        /// The `data` field is a `.opt_token_and_opt_node`:
        ///   1. a `OptionalTokenIndex` to the label identifier, if any.
        ///   2. a `Node.OptionalIndex` to the target expression, if any.
        ///
        /// The `main_token` field is the `continue` token.
        @"continue",
        /// `break :label expr`,
        /// `break expr`,
        /// `break :label`,
        /// `break`.
        ///
        /// The `data` field is a `.opt_token_and_opt_node`:
        ///   1. a `OptionalTokenIndex` to the label identifier, if any.
        ///   2. a `Node.OptionalIndex` to the target expression, if any.
        ///
        /// The `main_token` field is the `break` token.
        @"break",
        /// `return expr`, `return`.
        ///
        /// The `data` field is a `.opt_node` to the return value, if any.
        ///
        /// The `main_token` field is the `return` token.
        @"return",
        /// `fn (a: type_expr) return_type`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first parameter type expression, if any.
        ///   2. a `Node.OptionalIndex` to the return type expression. Can't be
        ///      `.none` unless a parsing error occured.
        ///
        /// The `main_token` field is the `fn` token.
        ///
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// Extern function declarations use this tag.
        fn_proto_simple,
        /// `fn (a: b, c: d) return_type`.
        ///
        /// The `data` field is a `.extra_and_opt_node`:
        ///   1. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each parameter type expression.
        ///   2. a `Node.OptionalIndex` to the return type expression. Can't be
        ///      `.none` unless a parsing error occured.
        ///
        /// The `main_token` field is the `fn` token.
        ///
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// Extern function declarations use this tag.
        fn_proto_multi,
        /// `fn (a: b) addrspace(e) linksection(f) callconv(g) return_type`.
        /// zero or one parameters.
        ///
        /// The `data` field is a `.extra_and_opt_node`:
        ///   1. a `Node.ExtraIndex` to `FnProtoOne`.
        ///   2. a `Node.OptionalIndex` to the return type expression. Can't be
        ///      `.none` unless a parsing error occured.
        ///
        /// The `main_token` field is the `fn` token.
        ///
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// Extern function declarations use this tag.
        fn_proto_one,
        /// `fn (a: b, c: d) addrspace(e) linksection(f) callconv(g) return_type`.
        ///
        /// The `data` field is a `.extra_and_opt_node`:
        ///   1. a `Node.ExtraIndex` to `FnProto`.
        ///   2. a `Node.OptionalIndex` to the return type expression. Can't be
        ///      `.none` unless a parsing error occured.
        ///
        /// The `main_token` field is the `fn` token.
        ///
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// Extern function declarations use this tag.
        fn_proto,
        /// Extern function declarations use the fn_proto tags rather than this one.
        ///
        /// The `data` field is a `.node_and_node`:
        ///   1. a `Node.Index` to `fn_proto_*`.
        ///   2. a `Node.Index` to function body block.
        ///
        /// The `main_token` field is the `fn` token.
        fn_decl,
        /// `anyframe->return_type`.
        ///
        /// The `data` field is a `.token_and_node`:
        ///   1. a `TokenIndex` to the `->` token.
        ///   2. a `Node.Index` to the function frame return type expression.
        ///
        /// The `main_token` field is the `anyframe` token.
        anyframe_type,
        /// The `data` field is unused.
        anyframe_literal,
        /// The `data` field is unused.
        char_literal,
        /// The `data` field is unused.
        number_literal,
        /// The `data` field is unused.
        unreachable_literal,
        /// The `data` field is unused.
        ///
        /// Most identifiers will not have explicit AST nodes, however for
        /// expressions which could be one of many different kinds of AST nodes,
        /// there will be an identifier AST node for it.
        identifier,
        /// `.foo`.
        ///
        /// The `data` field is unused.
        ///
        /// The `main_token` field is the identifier.
        enum_literal,
        /// The `data` field is unused.
        ///
        /// The `main_token` field is the string literal token.
        string_literal,
        /// The `data` field is a `.token_and_token`:
        ///   1. a `TokenIndex` to the first `.multiline_string_literal_line` token.
        ///   2. a `TokenIndex` to the last `.multiline_string_literal_line` token.
        ///
        /// The `main_token` field is the first token index (redundant with `data`).
        multiline_string_literal,
        /// `(expr)`.
        ///
        /// The `data` field is a `.node_and_token`:
        ///   1. a `Node.Index` to the sub-expression
        ///   2. a `TokenIndex` to the `)` token.
        ///
        /// The `main_token` field is the `(` token.
        grouped_expression,
        /// `@a(b, c)`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first argument, if any.
        ///   2. a `Node.OptionalIndex` to the second argument, if any.
        ///
        /// The `main_token` field is the builtin token.
        builtin_call_two,
        /// Same as `builtin_call_two` except there is known to be a trailing comma
        /// before the final rparen.
        builtin_call_two_comma,
        /// `@a(b, c, d)`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each argument.
        ///
        /// The `main_token` field is the builtin token.
        builtin_call,
        /// Same as `builtin_call` except there is known to be a trailing comma
        /// before the final rparen.
        builtin_call_comma,
        /// `error{a, b}`.
        ///
        /// The `data` field is a `.token_and_token`:
        ///   1. a `TokenIndex` to the `{` token.
        ///   2. a `TokenIndex` to the `}` token.
        ///
        /// The `main_token` field is the `error`.
        error_set_decl,
        /// `struct {}`, `union {}`, `opaque {}`, `enum {}`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each container member.
        ///
        /// The `main_token` field is the `struct`, `union`, `opaque` or `enum` token.
        container_decl,
        /// Same as `container_decl` except there is known to be a trailing
        /// comma before the final rbrace.
        container_decl_trailing,
        /// `struct {lhs, rhs}`, `union {lhs, rhs}`, `opaque {lhs, rhs}`, `enum {lhs, rhs}`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first container member, if any.
        ///   2. a `Node.OptionalIndex` to the second container member, if any.
        ///
        /// The `main_token` field is the `struct`, `union`, `opaque` or `enum` token.
        container_decl_two,
        /// Same as `container_decl_two` except there is known to be a trailing
        /// comma before the final rbrace.
        container_decl_two_trailing,
        /// `struct(arg)`, `union(arg)`, `enum(arg)`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to arg.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each container member.
        ///
        /// The `main_token` field is the `struct`, `union` or `enum` token.
        container_decl_arg,
        /// Same as `container_decl_arg` except there is known to be a trailing
        /// comma before the final rbrace.
        container_decl_arg_trailing,
        /// `union(enum) {}`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each container member.
        ///
        /// The `main_token` field is the `union` token.
        ///
        /// A tagged union with explicitly provided enums will instead be
        /// represented by `container_decl_arg`.
        tagged_union,
        /// Same as `tagged_union` except there is known to be a trailing comma
        /// before the final rbrace.
        tagged_union_trailing,
        /// `union(enum) {lhs, rhs}`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first container member, if any.
        ///   2. a `Node.OptionalIndex` to the second container member, if any.
        ///
        /// The `main_token` field is the `union` token.
        ///
        /// A tagged union with explicitly provided enums will instead be
        /// represented by `container_decl_arg`.
        tagged_union_two,
        /// Same as `tagged_union_two` except there is known to be a trailing
        /// comma before the final rbrace.
        tagged_union_two_trailing,
        /// `union(enum(arg)) {}`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to arg.
        ///   2. a `ExtraIndex` to a `SubRange` that stores a `Node.Index` for
        ///      each container member.
        ///
        /// The `main_token` field is the `union` token.
        tagged_union_enum_tag,
        /// Same as `tagged_union_enum_tag` except there is known to be a
        /// trailing comma before the final rbrace.
        tagged_union_enum_tag_trailing,
        /// `a: lhs = rhs,`,
        /// `a: lhs,`.
        ///
        /// The `data` field is a `.node_and_opt_node`:
        ///   1. a `Node.Index` to the field type expression.
        ///   2. a `Node.OptionalIndex` to the default value expression, if any.
        ///
        /// The `main_token` field is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field_init,
        /// `a: lhs align(rhs),`.
        ///
        /// The `data` field is a `.node_and_node`:
        ///   1. a `Node.Index` to the field type expression.
        ///   2. a `Node.Index` to the alignment expression.
        ///
        /// The `main_token` field is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field_align,
        /// `a: lhs align(c) = d,`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to the field type expression.
        ///   2. a `ExtraIndex` to `ContainerField`.
        ///
        /// The `main_token` field is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field,
        /// `comptime expr`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `comptime` token.
        @"comptime",
        /// `nosuspend expr`.
        ///
        /// The `data` field is a `.node` to expr.
        ///
        /// The `main_token` field is the `nosuspend` token.
        @"nosuspend",
        /// `{lhs rhs}`.
        ///
        /// The `data` field is a `.opt_node_and_opt_node`:
        ///   1. a `Node.OptionalIndex` to the first statement, if any.
        ///   2. a `Node.OptionalIndex` to the second statement, if any.
        ///
        /// The `main_token` field is the `{` token.
        block_two,
        /// Same as `block_two` except there is known to be a trailing
        /// comma before the final rbrace.
        block_two_semicolon,
        /// `{a b}`.
        ///
        /// The `data` field is a `.extra_range` that stores a `Node.Index` for
        /// each statement.
        ///
        /// The `main_token` field is the `{` token.
        block,
        /// Same as `block` except there is known to be a trailing comma before
        /// the final rbrace.
        block_semicolon,
        /// `asm(lhs)`.
        ///
        /// rhs is a `Token.Index` to the `)` token.
        /// The `main_token` field is the `asm` token.
        asm_simple,
        /// `asm(lhs, a)`.
        ///
        /// The `data` field is a `.node_and_extra`:
        ///   1. a `Node.Index` to lhs.
        ///   2. a `ExtraIndex` to `Asm`.
        ///
        /// The `main_token` field is the `asm` token.
        @"asm",
        /// `[a] "b" (c)`.
        /// `[a] "b" (-> lhs)`.
        ///
        /// The `data` field is a `.opt_node_and_token`:
        ///   1. a `Node.OptionalIndex` to lhs, if any.
        ///   2. a `TokenIndex` to the `)` token.
        ///
        /// The `main_token` field is `a`.
        asm_output,
        /// `[a] "b" (lhs)`.
        ///
        /// The `data` field is a `.node_and_token`:
        ///   1. a `Node.Index` to lhs.
        ///   2. a `TokenIndex` to the `)` token.
        ///
        /// The `main_token` field is `a`.
        asm_input,
        /// `error.a`.
        ///
        /// The `data` field is unused.
        ///
        /// The `main_token` field is `error` token.
        error_value,
        /// `lhs!rhs`.
        ///
        /// The `main_token` field is the `!` token.
        error_union,

        pub fn isContainerField(tag: Tag) bool {
            return switch (tag) {
                .container_field_init,
                .container_field_align,
                .container_field,
                => true,

                else => false,
            };
        }
    };

    pub const Data = union {
        node: Index,
        opt_node: OptionalIndex,
        token: TokenIndex,
        node_and_node: struct { Index, Index },
        opt_node_and_opt_node: struct { OptionalIndex, OptionalIndex },
        node_and_opt_node: struct { Index, OptionalIndex },
        opt_node_and_node: struct { OptionalIndex, Index },
        node_and_extra: struct { Index, ExtraIndex },
        extra_and_node: struct { ExtraIndex, Index },
        extra_and_opt_node: struct { ExtraIndex, OptionalIndex },
        node_and_token: struct { Index, TokenIndex },
        token_and_node: struct { TokenIndex, Index },
        token_and_token: struct { TokenIndex, TokenIndex },
        opt_node_and_token: struct { OptionalIndex, TokenIndex },
        opt_token_and_node: struct { OptionalTokenIndex, Index },
        opt_token_and_opt_node: struct { OptionalTokenIndex, OptionalIndex },
        opt_token_and_opt_token: struct { OptionalTokenIndex, OptionalTokenIndex },
        @"for": struct { ExtraIndex, For },
        extra_range: SubRange,
    };

    pub const LocalVarDecl = struct {
        type_node: Index,
        align_node: Index,
    };

    pub const ArrayTypeSentinel = struct {
        sentinel: Index,
        elem_type: Index,
    };

    pub const PtrType = struct {
        sentinel: OptionalIndex,
        align_node: OptionalIndex,
        addrspace_node: OptionalIndex,
    };

    pub const PtrTypeBitRange = struct {
        sentinel: OptionalIndex,
        align_node: Index,
        addrspace_node: OptionalIndex,
        bit_range_start: Index,
        bit_range_end: Index,
    };

    pub const SubRange = struct {
        /// Index into extra_data.
        start: ExtraIndex,
        /// Index into extra_data.
        end: ExtraIndex,
    };

    pub const If = struct {
        then_expr: Index,
        else_expr: Index,
    };

    pub const ContainerField = struct {
        align_expr: Index,
        value_expr: Index,
    };

    pub const GlobalVarDecl = struct {
        /// Populated if there is an explicit type ascription.
        type_node: OptionalIndex,
        /// Populated if align(A) is present.
        align_node: OptionalIndex,
        /// Populated if addrspace(A) is present.
        addrspace_node: OptionalIndex,
        /// Populated if linksection(A) is present.
        section_node: OptionalIndex,
    };

    pub const Slice = struct {
        start: Index,
        end: Index,
    };

    pub const SliceSentinel = struct {
        start: Index,
        /// May be .none if the slice is "open"
        end: OptionalIndex,
        sentinel: Index,
    };

    pub const While = struct {
        cont_expr: OptionalIndex,
        then_expr: Index,
        else_expr: Index,
    };

    pub const WhileCont = struct {
        cont_expr: Index,
        then_expr: Index,
    };

    pub const For = packed struct(u32) {
        inputs: u31,
        has_else: bool,
    };

    pub const FnProtoOne = struct {
        /// Populated if there is exactly 1 parameter. Otherwise there are 0 parameters.
        param: OptionalIndex,
        /// Populated if align(A) is present.
        align_expr: OptionalIndex,
        /// Populated if addrspace(A) is present.
        addrspace_expr: OptionalIndex,
        /// Populated if linksection(A) is present.
        section_expr: OptionalIndex,
        /// Populated if callconv(A) is present.
        callconv_expr: OptionalIndex,
    };

    pub const FnProto = struct {
        params_start: ExtraIndex,
        params_end: ExtraIndex,
        /// Populated if align(A) is present.
        align_expr: OptionalIndex,
        /// Populated if addrspace(A) is present.
        addrspace_expr: OptionalIndex,
        /// Populated if linksection(A) is present.
        section_expr: OptionalIndex,
        /// Populated if callconv(A) is present.
        callconv_expr: OptionalIndex,
    };

    pub const Asm = struct {
        items_start: ExtraIndex,
        items_end: ExtraIndex,
        /// Needed to make lastToken() work.
        rparen: TokenIndex,
    };
};

pub fn nodeToSpan(tree: *const Ast, node: Ast.Node.Index) Span {
    return tokensToSpan(
        tree,
        tree.firstToken(node),
        tree.lastToken(node),
        tree.nodeMainToken(node),
    );
}

pub fn tokenToSpan(tree: *const Ast, token: Ast.TokenIndex) Span {
    return tokensToSpan(tree, token, token, token);
}

pub fn tokensToSpan(tree: *const Ast, start: Ast.TokenIndex, end: Ast.TokenIndex, main: Ast.TokenIndex) Span {
    var start_tok = start;
    var end_tok = end;

    if (tree.tokensOnSameLine(start, end)) {
        // do nothing
    } else if (tree.tokensOnSameLine(start, main)) {
        end_tok = main;
    } else if (tree.tokensOnSameLine(main, end)) {
        start_tok = main;
    } else {
        start_tok = main;
        end_tok = main;
    }
    const start_off = tree.tokenStart(start_tok);
    const end_off = tree.tokenStart(end_tok) + @as(u32, @intCast(tree.tokenSlice(end_tok).len));
    return Span{ .start = start_off, .end = end_off, .main = tree.tokenStart(main) };
}

const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Token = std.zig.Token;
const Ast = @This();
const Allocator = std.mem.Allocator;
const Parse = @import("Parse.zig");
const private_render = @import("./render.zig");

test {
    _ = Parse;
    _ = private_render;
}
