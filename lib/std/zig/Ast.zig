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

    // TODO experiment with compacting the MultiArrayList slices here
    return Ast{
        .source = source,
        .mode = mode,
        .tokens = tokens.toOwnedSlice(),
        .nodes = parser.nodes.toOwnedSlice(),
        .extra_data = try parser.extra_data.toOwnedSlice(gpa),
        .errors = try parser.errors.toOwnedSlice(gpa),
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

pub fn extraDataSlice(tree: Ast, start: ExtraIndex, end: ExtraIndex, comptime T: type) []const T {
    return @ptrCast(tree.extra_data[@intFromEnum(start)..@intFromEnum(end)]);
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
        .zig => {
            const data = tree.nodeData(.root);
            return tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index);
        },
        .zon => {
            // Ensure that the returned slice points into the existing memory of the Ast
            return (&tree.nodes.items(.data)[@intFromEnum(Node.Index.root)].lhs.node)[0..1];
        },
    }
}

pub fn renderError(tree: Ast, parse_error: Error, stream: anytype) !void {
    switch (parse_error.tag) {
        .asterisk_after_ptr_deref => {
            // Note that the token will point at the `.*` but ideally the source
            // location would point to the `*` after the `.*`.
            return stream.writeAll("'.*' cannot be followed by '*'. Are you missing a space?");
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
            return stream.print("binary operator `{s}` has whitespace on one side, but not the other.", .{tree.tokenTag(parse_error.token).lexeme().?});
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
        .field_access,
        .unwrap_optional,
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
        .slice,
        .slice_sentinel,
        .deref,
        .array_access,
        .array_init_one,
        .array_init_one_comma,
        .array_init,
        .array_init_comma,
        .struct_init_one,
        .struct_init_one_comma,
        .struct_init,
        .struct_init_comma,
        .call_one,
        .call_one_comma,
        .call,
        .call_comma,
        .switch_range,
        .for_range,
        .error_union,
        => n = tree.nodeData(n).lhs.node,

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
        .async_call,
        .async_call_comma,
        => {
            end_offset += 1; // async token
            n = tree.nodeData(n).lhs.node;
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
        => n = tree.nodeData(n).lhs.node,

        .test_decl,
        .@"errdefer",
        .@"defer",
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
        .assign_destructure,
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
        .anyframe_type,
        .error_union,
        .if_simple,
        .while_simple,
        .for_simple,
        .fn_decl,
        .ptr_type_aligned,
        .ptr_type_sentinel,
        .ptr_type,
        .ptr_type_bit_range,
        .array_type,
        .switch_case_one,
        .switch_case_inline_one,
        .switch_case,
        .switch_case_inline,
        .switch_range,
        => n = tree.nodeData(n).rhs.node,

        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => n = tree.nodeData(n).rhs.opt_node.unwrap().?,

        .for_range => {
            n = tree.nodeData(n).rhs.opt_node.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },

        .field_access,
        .unwrap_optional,
        .grouped_expression,
        .multiline_string_literal,
        .error_set_decl,
        .asm_simple,
        .asm_output,
        .asm_input,
        => return tree.nodeData(n).rhs.token + end_offset,

        .error_value => return tree.nodeData(n).rhs.opt_token.unwrap().? + end_offset,

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
            n = tree.nodeData(n).lhs.opt_node.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },

        .call, .async_call => {
            const params = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            assert(params.start != params.end);
            end_offset += 1; // for the rparen
            n = @enumFromInt(tree.extra_data[@intFromEnum(params.end) - 1]); // last parameter
        },
        .tagged_union_enum_tag => {
            const members = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            if (members.start == members.end) {
                end_offset += 4; // for the rparen + rparen + lbrace + rbrace
                n = tree.nodeData(n).lhs.node;
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(members.end) - 1]); // last parameter
            }
        },
        .call_comma,
        .async_call_comma,
        .tagged_union_enum_tag_trailing,
        => {
            const params = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            assert(params.start != params.end);
            end_offset += 2; // for the comma/semicolon + rparen/rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(params.end) - 1]); // last parameter
        },
        .@"switch" => {
            const cases = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            if (cases.start == cases.end) {
                end_offset += 3; // rparen, lbrace, rbrace
                n = tree.nodeData(n).lhs.node; // condition expression
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(cases.end) - 1]); // last case
            }
        },
        .container_decl_arg => {
            const members = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            if (members.end == members.start) {
                end_offset += 3; // for the rparen + lbrace + rbrace
                n = tree.nodeData(n).lhs.node;
            } else {
                end_offset += 1; // for the rbrace
                n = @enumFromInt(tree.extra_data[@intFromEnum(members.end) - 1]); // last parameter
            }
        },
        .@"asm" => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.Asm);
            return extra.rparen + end_offset;
        },
        .array_init,
        .struct_init,
        => {
            const elements = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
            assert(elements.start != elements.end);
            end_offset += 1; // for the rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(elements.end) - 1]); // last element
        },
        .array_init_comma,
        .struct_init_comma,
        .container_decl_arg_trailing,
        .switch_comma,
        => {
            const members = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SubRange);
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
            const data = tree.nodeData(n);
            assert(data.lhs.extra_index != data.rhs.extra_index);
            end_offset += 1; // for the rbrace
            n = @enumFromInt(tree.extra_data[@intFromEnum(data.rhs.extra_index) - 1]); // last statement
        },
        .array_init_dot_comma,
        .struct_init_dot_comma,
        .block_semicolon,
        .container_decl_trailing,
        .tagged_union_trailing,
        .builtin_call_comma,
        => {
            const data = tree.nodeData(n);
            assert(data.lhs.extra_index != data.rhs.extra_index);
            end_offset += 2; // for the comma/semicolon + rbrace/rparen
            n = @enumFromInt(tree.extra_data[@intFromEnum(data.rhs.extra_index) - 1]); // last member
        },
        .call_one,
        .async_call_one,
        => {
            end_offset += 1; // for the rparen
            n = tree.nodeData(n).rhs.opt_node.unwrap() orelse {
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
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                end_offset += 1; // for the rparen/rbrace
                n = rhs;
            } else if (data.lhs.opt_node.unwrap()) |lhs| {
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
            end_offset += 2; // for the comma/semicolon + rbrace/rparen
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else if (data.lhs.opt_node.unwrap()) |lhs| {
                n = lhs;
            } else {
                unreachable;
            }
        },
        .simple_var_decl => {
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else if (data.lhs.opt_node.unwrap()) |lhs| {
                n = lhs;
            } else {
                end_offset += 1; // from mut token to name
                return tree.nodeMainToken(n) + end_offset;
            }
        },
        .aligned_var_decl => {
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else if (data.lhs.opt_node.unwrap()) |lhs| {
                end_offset += 1; // for the rparen
                n = lhs;
            } else {
                unreachable;
            }
        },
        .global_var_decl => {
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else {
                const extra = tree.extraData(data.lhs.extra_index, Node.GlobalVarDecl);
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
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else {
                const extra = tree.extraData(data.lhs.extra_index, Node.LocalVarDecl);
                end_offset += 1; // for the rparen
                n = extra.align_node;
            }
        },
        .container_field_init => {
            const data = tree.nodeData(n);
            n = data.rhs.opt_node.unwrap() orelse data.lhs.node;
        },

        .array_access,
        .array_init_one,
        .container_field_align,
        => {
            end_offset += 1; // for the rbracket/rbrace/rparen
            n = tree.nodeData(n).rhs.node;
        },
        .container_field => {
            const data = tree.nodeData(n);
            const extra = tree.extraData(data.rhs.extra_index, Node.ContainerField);
            n = extra.value_expr;
        },

        .struct_init_one => {
            end_offset += 1; // rbrace
            n = tree.nodeData(n).rhs.opt_node.unwrap() orelse {
                return tree.nodeMainToken(n) + end_offset;
            };
        },
        .slice_open => {
            end_offset += 2; // ellipsis2 + rbracket, or comma + rparen
            n = tree.nodeData(n).rhs.node;
        },
        .array_init_one_comma => {
            end_offset += 2; // comma + rbrace
            n = tree.nodeData(n).rhs.node;
        },
        .call_one_comma,
        .async_call_one_comma,
        .struct_init_one_comma,
        => {
            end_offset += 2; // ellipsis2 + rbracket, or comma + rparen
            n = tree.nodeData(n).rhs.opt_node.unwrap().?;
        },
        .slice => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.Slice);
            end_offset += 1; // rbracket
            n = extra.end;
        },
        .slice_sentinel => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.SliceSentinel);
            end_offset += 1; // rbracket
            n = extra.sentinel;
        },

        .@"continue", .@"break" => {
            const data = tree.nodeData(n);
            if (data.rhs.opt_node.unwrap()) |rhs| {
                n = rhs;
            } else if (data.lhs.opt_token.unwrap()) |lhs| {
                return lhs + end_offset;
            } else {
                return tree.nodeMainToken(n) + end_offset;
            }
        },
        .while_cont => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.WhileCont);
            n = extra.then_expr;
        },
        .@"while" => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.While);
            n = extra.else_expr;
        },
        .@"if" => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.If);
            n = extra.else_expr;
        },
        .@"for" => {
            const extra = tree.nodeData(n).rhs.@"for";
            const index = @intFromEnum(tree.nodeData(n).lhs.extra_index) + extra.inputs + @intFromBool(extra.has_else);
            n = @enumFromInt(tree.extra_data[index]);
        },
        .array_type_sentinel => {
            const extra = tree.extraData(tree.nodeData(n).rhs.extra_index, Node.ArrayTypeSentinel);
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
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.GlobalVarDecl);
    return tree.fullVarDeclComponents(.{
        .type_node = extra.type_node,
        .align_node = extra.align_node,
        .addrspace_node = extra.addrspace_node,
        .section_node = extra.section_node,
        .init_node = data.rhs.opt_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn localVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .local_var_decl);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.LocalVarDecl);
    return tree.fullVarDeclComponents(.{
        .type_node = extra.type_node.toOptional(),
        .align_node = extra.align_node.toOptional(),
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = data.rhs.opt_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn simpleVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .simple_var_decl);
    const data = tree.nodeData(node);
    return tree.fullVarDeclComponents(.{
        .type_node = data.lhs.opt_node,
        .align_node = .none,
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = data.rhs.opt_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn alignedVarDecl(tree: Ast, node: Node.Index) full.VarDecl {
    assert(tree.nodeTag(node) == .aligned_var_decl);
    const data = tree.nodeData(node);
    return tree.fullVarDeclComponents(.{
        .type_node = .none,
        .align_node = data.lhs.node.toOptional(),
        .addrspace_node = .none,
        .section_node = .none,
        .init_node = data.rhs.opt_node,
        .mut_token = tree.nodeMainToken(node),
    });
}

pub fn assignDestructure(tree: Ast, node: Node.Index) full.AssignDestructure {
    const data = tree.nodeData(node);
    const extra_index = @intFromEnum(data.lhs.extra_index);
    const variable_count = tree.extra_data[extra_index];
    return tree.fullAssignDestructureComponents(.{
        .variables = tree.extraDataSliceWithLen(@enumFromInt(extra_index + 1), variable_count, Node.Index),
        .equal_token = tree.nodeMainToken(node),
        .value_expr = data.rhs.node,
    });
}

pub fn ifSimple(tree: Ast, node: Node.Index) full.If {
    assert(tree.nodeTag(node) == .if_simple);
    const data = tree.nodeData(node);
    return tree.fullIfComponents(.{
        .cond_expr = data.lhs.node,
        .then_expr = data.rhs.node,
        .else_expr = .none,
        .if_token = tree.nodeMainToken(node),
    });
}

pub fn ifFull(tree: Ast, node: Node.Index) full.If {
    assert(tree.nodeTag(node) == .@"if");
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.If);
    return tree.fullIfComponents(.{
        .cond_expr = data.lhs.node,
        .then_expr = extra.then_expr,
        .else_expr = extra.else_expr.toOptional(),
        .if_token = tree.nodeMainToken(node),
    });
}

pub fn containerField(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.ContainerField);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = data.lhs.node.toOptional(),
        .align_expr = extra.align_expr.toOptional(),
        .value_expr = extra.value_expr.toOptional(),
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn containerFieldInit(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field_init);
    const data = tree.nodeData(node);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = data.lhs.node.toOptional(),
        .align_expr = .none,
        .value_expr = data.rhs.opt_node,
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn containerFieldAlign(tree: Ast, node: Node.Index) full.ContainerField {
    assert(tree.nodeTag(node) == .container_field_align);
    const data = tree.nodeData(node);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerFieldComponents(.{
        .main_token = main_token,
        .type_expr = data.lhs.node.toOptional(),
        .align_expr = data.rhs.node.toOptional(),
        .value_expr = .none,
        .tuple_like = tree.tokenTag(main_token) != .identifier or
            tree.tokenTag(main_token + 1) != .colon,
    });
}

pub fn fnProtoSimple(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_simple);
    const data = tree.nodeData(node);
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{data.lhs.opt_node});
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = data.rhs.opt_node,
        .params = params,
        .align_expr = .none,
        .addrspace_expr = .none,
        .section_expr = .none,
        .callconv_expr = .none,
    });
}

pub fn fnProtoMulti(tree: Ast, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_multi);
    const data = tree.nodeData(node);
    const params_range = tree.extraData(data.lhs.extra_index, Node.SubRange);
    const params = tree.extraDataSlice(params_range.start, params_range.end, Node.Index);
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = data.rhs.opt_node,
        .params = params,
        .align_expr = .none,
        .addrspace_expr = .none,
        .section_expr = .none,
        .callconv_expr = .none,
    });
}

pub fn fnProtoOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto_one);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.FnProtoOne);
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{extra.param});
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = data.rhs.opt_node,
        .params = params,
        .align_expr = extra.align_expr,
        .addrspace_expr = extra.addrspace_expr,
        .section_expr = extra.section_expr,
        .callconv_expr = extra.callconv_expr,
    });
}

pub fn fnProto(tree: Ast, node: Node.Index) full.FnProto {
    assert(tree.nodeTag(node) == .fn_proto);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.FnProto);
    const params = tree.extraDataSlice(extra.params_start, extra.params_end, Node.Index);
    return tree.fullFnProtoComponents(.{
        .proto_node = node,
        .fn_token = tree.nodeMainToken(node),
        .return_type = data.rhs.opt_node,
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
    const data = tree.nodeData(node);
    const fields = loadOptionalNodesIntoBuffer(1, buffer, .{data.rhs.opt_node});
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = data.lhs.node.toOptional(),
        },
    };
}

pub fn structInitDotTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.StructInit {
    assert(tree.nodeTag(node) == .struct_init_dot_two or
        tree.nodeTag(node) == .struct_init_dot_two_comma);
    const data = tree.nodeData(node);
    const fields = loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node });
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
    const data = tree.nodeData(node);
    const fields = tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index);
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
    const data = tree.nodeData(node);
    const fields_range = tree.extraData(data.rhs.extra_index, Node.SubRange);
    const fields = tree.extraDataSlice(fields_range.start, fields_range.end, Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .fields = fields,
            .type_expr = data.lhs.node.toOptional(),
        },
    };
}

pub fn arrayInitOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init_one or
        tree.nodeTag(node) == .array_init_one_comma);
    const data = tree.nodeData(node);
    buffer[0] = data.rhs.node;
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = buffer[0..1],
            .type_expr = data.lhs.node.toOptional(),
        },
    };
}

pub fn arrayInitDotTwo(tree: Ast, buffer: *[2]Node.Index, node: Node.Index) full.ArrayInit {
    assert(tree.nodeTag(node) == .array_init_dot_two or
        tree.nodeTag(node) == .array_init_dot_two_comma);
    const data = tree.nodeData(node);
    const elements = loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node });
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
    const data = tree.nodeData(node);
    const elements = tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index);
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
    const data = tree.nodeData(node);
    const elem_range = tree.extraData(data.rhs.extra_index, Node.SubRange);
    const elements = tree.extraDataSlice(elem_range.start, elem_range.end, Node.Index);
    return .{
        .ast = .{
            .lbrace = tree.nodeMainToken(node),
            .elements = elements,
            .type_expr = data.lhs.node.toOptional(),
        },
    };
}

pub fn arrayType(tree: Ast, node: Node.Index) full.ArrayType {
    assert(tree.nodeTag(node) == .array_type);
    const data = tree.nodeData(node);
    return .{
        .ast = .{
            .lbracket = tree.nodeMainToken(node),
            .elem_count = data.lhs.node,
            .sentinel = .none,
            .elem_type = data.rhs.node,
        },
    };
}

pub fn arrayTypeSentinel(tree: Ast, node: Node.Index) full.ArrayType {
    assert(tree.nodeTag(node) == .array_type_sentinel);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.ArrayTypeSentinel);
    return .{
        .ast = .{
            .lbracket = tree.nodeMainToken(node),
            .elem_count = data.lhs.node,
            .sentinel = extra.sentinel.toOptional(),
            .elem_type = extra.elem_type,
        },
    };
}

pub fn ptrTypeAligned(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_aligned);
    const data = tree.nodeData(node);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = data.lhs.opt_node,
        .addrspace_node = .none,
        .sentinel = .none,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = data.rhs.node,
    });
}

pub fn ptrTypeSentinel(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_sentinel);
    const data = tree.nodeData(node);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = .none,
        .addrspace_node = .none,
        .sentinel = data.lhs.opt_node,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = data.rhs.node,
    });
}

pub fn ptrType(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.PtrType);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = extra.align_node,
        .addrspace_node = extra.addrspace_node,
        .sentinel = extra.sentinel,
        .bit_range_start = .none,
        .bit_range_end = .none,
        .child_type = data.rhs.node,
    });
}

pub fn ptrTypeBitRange(tree: Ast, node: Node.Index) full.PtrType {
    assert(tree.nodeTag(node) == .ptr_type_bit_range);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.PtrTypeBitRange);
    return tree.fullPtrTypeComponents(.{
        .main_token = tree.nodeMainToken(node),
        .align_node = extra.align_node.toOptional(),
        .addrspace_node = extra.addrspace_node,
        .sentinel = extra.sentinel,
        .bit_range_start = extra.bit_range_start.toOptional(),
        .bit_range_end = extra.bit_range_end.toOptional(),
        .child_type = data.rhs.node,
    });
}

pub fn sliceOpen(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice_open);
    const data = tree.nodeData(node);
    return .{
        .ast = .{
            .sliced = data.lhs.node,
            .lbracket = tree.nodeMainToken(node),
            .start = data.rhs.node,
            .end = .none,
            .sentinel = .none,
        },
    };
}

pub fn slice(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.Slice);
    return .{
        .ast = .{
            .sliced = data.lhs.node,
            .lbracket = tree.nodeMainToken(node),
            .start = extra.start,
            .end = extra.end.toOptional(),
            .sentinel = .none,
        },
    };
}

pub fn sliceSentinel(tree: Ast, node: Node.Index) full.Slice {
    assert(tree.nodeTag(node) == .slice_sentinel);
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.SliceSentinel);
    return .{
        .ast = .{
            .sliced = data.lhs.node,
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
    const data = tree.nodeData(node);
    const members = loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node });
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
    const data = tree.nodeData(node);
    const members = tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index);
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
    const data = tree.nodeData(node);
    const members_range = tree.extraData(data.rhs.extra_index, Node.SubRange);
    const members = tree.extraDataSlice(members_range.start, members_range.end, Node.Index);
    return tree.fullContainerDeclComponents(.{
        .main_token = tree.nodeMainToken(node),
        .enum_token = null,
        .members = members,
        .arg = data.lhs.node.toOptional(),
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
    const data = tree.nodeData(node);
    const members = loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node });
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
    const data = tree.nodeData(node);
    const members = tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index);
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
    const data = tree.nodeData(node);
    const members_range = tree.extraData(data.rhs.extra_index, Node.SubRange);
    const members = tree.extraDataSlice(members_range.start, members_range.end, Node.Index);
    const main_token = tree.nodeMainToken(node);
    return tree.fullContainerDeclComponents(.{
        .main_token = main_token,
        .enum_token = main_token + 2, // union lparen enum
        .members = members,
        .arg = data.lhs.node.toOptional(),
    });
}

pub fn switchFull(tree: Ast, node: Node.Index) full.Switch {
    const data = tree.nodeData(node);
    const main_token = tree.nodeMainToken(node);
    const switch_token: TokenIndex, const label_token: ?TokenIndex = switch (tree.tokenTag(main_token)) {
        .identifier => .{ main_token + 2, main_token },
        .keyword_switch => .{ main_token, null },
        else => unreachable,
    };
    const extra = tree.extraData(data.rhs.extra_index, Ast.Node.SubRange);
    const cases = tree.extraDataSlice(extra.start, extra.end, Node.Index);
    return .{
        .ast = .{
            .switch_token = switch_token,
            .condition = data.lhs.node,
            .cases = cases,
        },
        .label_token = label_token,
    };
}

pub fn switchCaseOne(tree: Ast, node: Node.Index) full.SwitchCase {
    const data = tree.nodeData(node);
    return tree.fullSwitchCaseComponents(.{
        .values = if (data.lhs.opt_node == .none)
            &.{}
        else
            // Ensure that the returned slice points into the existing memory of the Ast
            (@as(*const Node.Index, @ptrCast(&tree.nodes.items(.data)[@intFromEnum(node)].lhs.opt_node)))[0..1],
        .arrow_token = tree.nodeMainToken(node),
        .target_expr = data.rhs.node,
    }, node);
}

pub fn switchCase(tree: Ast, node: Node.Index) full.SwitchCase {
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.lhs.extra_index, Node.SubRange);
    const values = tree.extraDataSlice(extra.start, extra.end, Node.Index);
    return tree.fullSwitchCaseComponents(.{
        .values = values,
        .arrow_token = tree.nodeMainToken(node),
        .target_expr = data.rhs.node,
    }, node);
}

pub fn asmSimple(tree: Ast, node: Node.Index) full.Asm {
    const data = tree.nodeData(node);
    return tree.fullAsmComponents(.{
        .asm_token = tree.nodeMainToken(node),
        .template = data.lhs.node,
        .items = &.{},
        .rparen = data.rhs.token,
    });
}

pub fn asmFull(tree: Ast, node: Node.Index) full.Asm {
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.Asm);
    const items = tree.extraDataSlice(extra.items_start, extra.items_end, Node.Index);
    return tree.fullAsmComponents(.{
        .asm_token = tree.nodeMainToken(node),
        .template = data.lhs.node,
        .items = items,
        .rparen = extra.rparen,
    });
}

pub fn whileSimple(tree: Ast, node: Node.Index) full.While {
    const data = tree.nodeData(node);
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = data.lhs.node,
        .cont_expr = .none,
        .then_expr = data.rhs.node,
        .else_expr = .none,
    });
}

pub fn whileCont(tree: Ast, node: Node.Index) full.While {
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.WhileCont);
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = data.lhs.node,
        .cont_expr = extra.cont_expr.toOptional(),
        .then_expr = extra.then_expr,
        .else_expr = .none,
    });
}

pub fn whileFull(tree: Ast, node: Node.Index) full.While {
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.While);
    return tree.fullWhileComponents(.{
        .while_token = tree.nodeMainToken(node),
        .cond_expr = data.lhs.node,
        .cont_expr = extra.cont_expr,
        .then_expr = extra.then_expr,
        .else_expr = extra.else_expr.toOptional(),
    });
}

pub fn forSimple(tree: Ast, node: Node.Index) full.For {
    const data = tree.nodeData(node);
    const inputs: *[1]Node.Index = &tree.nodes.items(.data)[@intFromEnum(node)].lhs.node;
    return tree.fullForComponents(.{
        .for_token = tree.nodeMainToken(node),
        .inputs = inputs[0..1],
        .then_expr = data.rhs.node,
        .else_expr = .none,
    });
}

pub fn forFull(tree: Ast, node: Node.Index) full.For {
    const data = tree.nodeData(node);
    const extra = data.rhs.@"for";
    const inputs = tree.extraDataSliceWithLen(data.lhs.extra_index, extra.inputs, Node.Index);
    const then_expr: Node.Index = @enumFromInt(tree.extra_data[@intFromEnum(data.lhs.extra_index) + extra.inputs]);
    const else_expr: Node.OptionalIndex = if (extra.has_else) @enumFromInt(tree.extra_data[@intFromEnum(data.lhs.extra_index) + extra.inputs + 1]) else .none;
    return tree.fullForComponents(.{
        .for_token = tree.nodeMainToken(node),
        .inputs = inputs,
        .then_expr = then_expr,
        .else_expr = else_expr,
    });
}

pub fn callOne(tree: Ast, buffer: *[1]Node.Index, node: Node.Index) full.Call {
    const data = tree.nodeData(node);
    const params = loadOptionalNodesIntoBuffer(1, buffer, .{data.rhs.opt_node});
    return tree.fullCallComponents(.{
        .lparen = tree.nodeMainToken(node),
        .fn_expr = data.lhs.node,
        .params = params,
    });
}

pub fn callFull(tree: Ast, node: Node.Index) full.Call {
    const data = tree.nodeData(node);
    const extra = tree.extraData(data.rhs.extra_index, Node.SubRange);
    const params = tree.extraDataSlice(extra.start, extra.end, Node.Index);
    return tree.fullCallComponents(.{
        .lparen = tree.nodeMainToken(node),
        .fn_expr = data.lhs.node,
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
        .fn_decl => tree.fullFnProto(buffer, tree.nodeData(node).lhs.node),
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
    const data = tree.nodeData(node);
    return switch (tree.nodeTag(node)) {
        .builtin_call_two, .builtin_call_two_comma => loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node }),
        .builtin_call, .builtin_call_comma => tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index),
        else => null,
    };
}

pub fn blockStatements(tree: Ast, buffer: *[2]Ast.Node.Index, node: Ast.Node.Index) ?[]const Node.Index {
    const data = tree.nodeData(node);
    return switch (tree.nodeTag(node)) {
        .block_two, .block_two_semicolon => loadOptionalNodesIntoBuffer(2, buffer, .{ data.lhs.opt_node, data.rhs.opt_node }),
        .block, .block_semicolon => tree.extraDataSlice(data.lhs.extra_index, data.rhs.extra_index, Node.Index),
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
    }

    /// The FooComma/FooSemicolon variants exist to ease the implementation of
    /// `Ast.lastToken()`
    pub const Tag = enum {
        /// The root node which is guaranteed to be at `Node.Index.root`.
        /// The meaning of lhs and rhs depends on whether it is
        /// a `.zig` or `.zon` file.
        ///
        /// main_token is the first token for the source file.
        root,
        /// `usingnamespace lhs;`.
        ///
        /// lhs is a `Node.Index`.
        /// rhs is unused.
        /// main_token is the `usingnamespace`.
        @"usingnamespace",
        /// `test {}`,
        /// `test "name" {}`,
        /// `test identifier {}`.
        ///
        /// lhs is a `OptionalTokenIndex` to test name token (must be string literal or identifier), if any.
        /// rhs is a `Node.Index` to the block.
        /// main_token is the `test`.
        test_decl,
        /// lhs is a `ExtraIndex` to `GlobalVarDecl`.
        /// rhs is a `Node.OptionalIndex` to the initialization expression.
        /// main_token is the `var` or `const`.
        ///
        /// The rhs can't be `.none` unless it is part of a `assign_destructure`
        /// node or a parsing error occured.
        global_var_decl,
        /// `var a: b align(c) = rhs`.
        /// `const main_token: type_node align(align_node) = rhs`
        ///
        /// lhs is a `ExtraIndex` to `LocalVarDecl`.
        /// rhs is a `Node.OptionalIndex` to the initialization expression.
        /// main_token is the `var` or `const`.
        ///
        /// The rhs can't be `.none` unless it is part of a `assign_destructure`
        /// node or a parsing error occured.
        local_var_decl,
        /// `var a: lhs = rhs`.
        /// Can be local or global.
        ///
        /// lhs is a `Node.OptionalIndex` to the type expression, if any.
        /// rhs is a `Node.OptionalIndex` to the initialization expression.
        /// main_token is the `var` or `const`.
        ///
        /// The rhs can't be `.none` unless it is part of a `assign_destructure`
        /// node or a parsing error occured.
        simple_var_decl,
        /// `var a align(lhs) = rhs`.
        /// Can be local or global.
        ///
        /// lhs is a `Node.Index` to the alignment expression.
        /// rhs is a `Node.OptionalIndex` to the initialization expression.
        /// main_token is the `var` or `const`.
        ///
        /// The rhs can't be `.none` unless it is part of a `assign_destructure`
        /// node or a parsing error occured.
        aligned_var_decl,
        /// `errdefer rhs`,
        /// `errdefer |lhs| rhs`.
        ///
        /// lhs is a `OptionalTokenIndex` to the payload identifier, if any.
        /// rhs is a `Node.Index` to the deferred expression.
        /// main_token is the `errdefer`.
        @"errdefer",
        /// `defer rhs`.
        ///
        /// lhs is unused.
        /// rhs is a `Node.Index` to the deferred expression.
        /// main_token is the `defer`.
        @"defer",
        /// `lhs catch rhs`,
        /// `lhs catch |err| rhs`.
        ///
        /// main_token is the `catch` keyword.
        /// The payload is determined by looking at the next token after the `catch` keyword.
        @"catch",
        /// `lhs.a`.
        ///
        /// rhs is a `TokenIndex` to the field name identifier.
        /// main_token is the `.`.
        field_access,
        /// `lhs.?`.
        ///
        /// rhs is a `TokenIndex` to the `?`.
        /// main_token is the `.`.
        unwrap_optional,
        /// `lhs == rhs`. main_token is op.
        equal_equal,
        /// `lhs != rhs`. main_token is op.
        bang_equal,
        /// `lhs < rhs`. main_token is op.
        less_than,
        /// `lhs > rhs`. main_token is op.
        greater_than,
        /// `lhs <= rhs`. main_token is op.
        less_or_equal,
        /// `lhs >= rhs`. main_token is op.
        greater_or_equal,
        /// `lhs *= rhs`. main_token is op.
        assign_mul,
        /// `lhs /= rhs`. main_token is op.
        assign_div,
        /// `lhs %= rhs`. main_token is op.
        assign_mod,
        /// `lhs += rhs`. main_token is op.
        assign_add,
        /// `lhs -= rhs`. main_token is op.
        assign_sub,
        /// `lhs <<= rhs`. main_token is op.
        assign_shl,
        /// `lhs <<|= rhs`. main_token is op.
        assign_shl_sat,
        /// `lhs >>= rhs`. main_token is op.
        assign_shr,
        /// `lhs &= rhs`. main_token is op.
        assign_bit_and,
        /// `lhs ^= rhs`. main_token is op.
        assign_bit_xor,
        /// `lhs |= rhs`. main_token is op.
        assign_bit_or,
        /// `lhs *%= rhs`. main_token is op.
        assign_mul_wrap,
        /// `lhs +%= rhs`. main_token is op.
        assign_add_wrap,
        /// `lhs -%= rhs`. main_token is op.
        assign_sub_wrap,
        /// `lhs *|= rhs`. main_token is op.
        assign_mul_sat,
        /// `lhs +|= rhs`. main_token is op.
        assign_add_sat,
        /// `lhs -|= rhs`. main_token is op.
        assign_sub_sat,
        /// `lhs = rhs`. main_token is op.
        assign,
        /// `a, b, ... = rhs`.
        ///
        /// lhs is a `ExtraIndex`.
        /// rhs is a `Node.OptionalIndex` to the initialization expression.
        /// main_token is op.
        ///
        /// The lhs stores the following data:
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
        /// that their `rhs` is always `.none`). An expression node corresponds
        /// to a standard assignment LHS (which must be evaluated as an lvalue).
        /// There may be a preceding `comptime` token, which does not create a
        /// corresponding `comptime` node so must be manually detected.
        assign_destructure,
        /// `lhs || rhs`. main_token is the `||`.
        merge_error_sets,
        /// `lhs * rhs`. main_token is the `*`.
        mul,
        /// `lhs / rhs`. main_token is the `/`.
        div,
        /// `lhs % rhs`. main_token is the `%`.
        mod,
        /// `lhs ** rhs`. main_token is the `**`.
        array_mult,
        /// `lhs *% rhs`. main_token is the `*%`.
        mul_wrap,
        /// `lhs *| rhs`. main_token is the `*|`.
        mul_sat,
        /// `lhs + rhs`. main_token is the `+`.
        add,
        /// `lhs - rhs`. main_token is the `-`.
        sub,
        /// `lhs ++ rhs`. main_token is the `++`.
        array_cat,
        /// `lhs +% rhs`. main_token is the `+%`.
        add_wrap,
        /// `lhs -% rhs`. main_token is the `-%`.
        sub_wrap,
        /// `lhs +| rhs`. main_token is the `+|`.
        add_sat,
        /// `lhs -| rhs`. main_token is the `-|`.
        sub_sat,
        /// `lhs << rhs`. main_token is the `<<`.
        shl,
        /// `lhs <<| rhs`. main_token is the `<<|`.
        shl_sat,
        /// `lhs >> rhs`. main_token is the `>>`.
        shr,
        /// `lhs & rhs`. main_token is the `&`.
        bit_and,
        /// `lhs ^ rhs`. main_token is the `^`.
        bit_xor,
        /// `lhs | rhs`. main_token is the `|`.
        bit_or,
        /// `lhs orelse rhs`. main_token is the `orelse`.
        @"orelse",
        /// `lhs and rhs`. main_token is the `and`.
        bool_and,
        /// `lhs or rhs`. main_token is the `or`.
        bool_or,
        /// `!lhs`. rhs unused. main_token is the `!`.
        bool_not,
        /// `-lhs`. rhs unused. main_token is the `-`.
        negation,
        /// `~lhs`. rhs unused. main_token is the `~`.
        bit_not,
        /// `-%lhs`. rhs unused. main_token is the `-%`.
        negation_wrap,
        /// `&lhs`. rhs unused. main_token is the `&`.
        address_of,
        /// `try lhs`. rhs unused. main_token is the `try`.
        @"try",
        /// `await lhs`. rhs unused. main_token is the `await`.
        @"await",
        /// `?lhs`. rhs unused. main_token is the `?`.
        optional_type,
        /// `[lhs]rhs`. main_token is the `[`.
        array_type,
        /// `[lhs:a]b`.
        ///
        /// rhs is a `ExtraIndex` to `ArrayTypeSentinel`.
        /// main_token is the `[`.
        array_type_sentinel,
        /// `[*]align(lhs) rhs`,
        /// `*align(lhs) rhs`,
        /// `[]rhs`.
        ///
        /// lhs is a `Node.OptionalIndex` to the alignment expression, if any.
        /// rhs is a `Node.Index` to the element type expression.
        /// main_token is the asterisk if a single item pointer or the lbracket
        /// if a slice, many-item pointer, or C-pointer.
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_aligned,
        /// `[*:lhs]rhs`,
        /// `*rhs`,
        /// `[:lhs]rhs`.
        ///
        /// lhs is a `Node.OptionalIndex` to the sentinel expression, if any.
        /// rhs is a `Node.Index` to the element type expression.
        /// main_token is the asterisk if a single item pointer or the lbracket
        /// if a slice, many-item pointer, or C-pointer.
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_sentinel,
        /// lhs is a `ExtraIndex` to `PtrType`.
        /// rhs is the element type expression.
        /// main_token is the asterisk if a single item pointer or the lbracket
        /// if a slice, many-item pointer, or C-pointer.
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type,
        /// lhs is a `ExtraIndex` to `PtrTypeBitRange`.
        /// rhs is the element type expression.
        /// main_token is the asterisk if a single item pointer or the lbracket
        /// if a slice, many-item pointer, or C-pointer.
        /// main_token might be a ** token, which is shared with a parent/child
        /// pointer type and may require special handling.
        ptr_type_bit_range,
        /// `lhs[rhs..]`
        /// main_token is the `[`.
        slice_open,
        /// `lhs[start..end]`.
        ///
        /// rhs is a `ExtraIndex` to `Slice`.
        /// main_token is the `[`.
        slice,
        /// `lhs[start..end :sentinel]`,
        /// `lhs[start.. :sentinel]`.
        ///
        /// rhs is a `ExtraIndex` to `SliceSentinel`.
        /// main_token is the `[`.
        slice_sentinel,
        /// `lhs.*`.
        ///
        /// rhs is unused.
        /// main_token is the `*`.
        deref,
        /// `lhs[rhs]`. main_token is the `[`.
        array_access,
        /// `lhs{rhs}`. main_token is the `{`.
        array_init_one,
        /// `lhs{rhs,}`. main_token is the `{`.
        array_init_one_comma,
        /// `.{}`,
        /// `.{lhs}`,
        /// `.{lhs, rhs}`.
        ///
        /// lhs is a `Node.OptionalIndex` but never `.none`.
        /// rhs is a `Node.OptionalIndex`.
        /// main_token is the `{`.
        array_init_dot_two,
        /// Same as `array_init_dot_two` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_dot_two_comma,
        /// `.{a, b}`. `extra_data[lhs..rhs]`.
        /// main_token is the `{`.
        array_init_dot,
        /// Same as `array_init_dot` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_dot_comma,
        /// `lhs{a, b}`. `sub_range_list[rhs]`.
        /// main_token is the `{`.
        array_init,
        /// Same as `array_init` except there is known to be a trailing comma
        /// before the final rbrace.
        array_init_comma,
        /// `lhs{.a = rhs}`, `lhs{}`.
        ///
        /// rhs is a `Node.OptionalIndex`.
        /// main_token is the `{`.
        ///
        /// The field name is determined by looking at the tokens before the initialization expression.
        struct_init_one,
        /// Same as `struct_init_one` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_one_comma,
        /// `.{.a = lhs, .b = rhs}`.
        ///
        /// lhs is a `Node.OptionalIndex` but never `.none`.
        /// rhs is a `Node.OptionalIndex`.
        /// main_token is the '{'.
        ///
        /// The field name is determined by looking at the tokens before the initialization expression.
        struct_init_dot_two,
        /// Same as `struct_init_dot_two` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_dot_two_comma,
        /// `.{.a = b, .c = d}`. `extra_data[lhs..rhs]`.
        ///
        /// main_token is the `{`.
        ///
        /// The field name is determined by looking at the tokens before the initialization expression.
        struct_init_dot,
        /// Same as `struct_init_dot` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_dot_comma,
        /// `lhs{.a = b, .c = d}`.
        ///
        /// rhs is a `Node.ExtraIndex` to a `SubRange` that stores the initialization expression nodes.
        /// main_token is the `{`.
        ///
        /// The field name is determined by looking at the tokens before the initialization expression.
        struct_init,
        /// Same as `struct_init` except there is known to be a trailing comma
        /// before the final rbrace.
        struct_init_comma,
        /// `lhs(rhs)`, `lhs()`.
        ///
        /// rhs is a `Node.OptionalIndex` to the first argument, if any.
        /// main_token is the `(`.
        call_one,
        /// Same as `call_one` except there is known to be a trailing comma
        /// before the final rparen.
        call_one_comma,
        /// `async lhs(rhs)`, `async lhs()`.
        ///
        /// rhs is a `Node.OptionalIndex` to the first argument, if any.
        /// main_token is the `(`.
        async_call_one,
        /// Same as `async_call_one` except there is known to be a trailing comma
        /// before the final rparen.
        async_call_one_comma,
        /// `lhs(a, b, c)`.
        ///
        /// rhs is a `Node.ExtraIndex` to a `SubRange` that stores the argument nodes.
        /// main_token is the `(`.
        call,
        /// Same as `call` except there is known to be a trailing comma
        /// before the final rparen.
        call_comma,
        /// `async lhs(a, b, c)`.
        ///
        /// rhs is a `Node.ExtraIndex` to a `SubRange` that stores the argument nodes.
        /// main_token is the `(`.
        async_call,
        /// Same as `async_call` except there is known to be a trailing comma
        /// before the final rparen.
        async_call_comma,
        /// `switch(lhs) {}`.
        ///
        /// rhs is a `Node.ExtraIndex` to a `SubRange` that stores the case nodes.
        /// `main_token` is the identifier of a preceding label, if any; otherwise `switch`.
        @"switch",
        /// Same as switch except there is known to be a trailing comma
        /// before the final rbrace
        switch_comma,
        /// `lhs => rhs`,
        /// `else => rhs`.
        ///
        /// lhs is a `Node.OptionalIndex` where `.none` means `else`.
        /// main_token is the `=>`.
        switch_case_one,
        /// Same as `switch_case_one` but the case is inline.
        switch_case_inline_one,
        /// `a, b, c => rhs`.
        ///
        /// lhs is a `Node.ExtraIndex` to a `SubRange` that stores the switch item nodes.
        /// main_token is the `=>`.
        switch_case,
        /// Same as `switch_case` but the case is inline.
        switch_case_inline,
        /// `lhs...rhs`. main_token is the `...`.
        switch_range,
        /// `while (lhs) rhs`.
        /// `while (lhs) |x| rhs`.
        while_simple,
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        /// `while (lhs) : (a) b`. `WhileCont[rhs]`.
        while_cont,
        /// `while (lhs) : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else c`. `While[rhs]`.
        /// `while (lhs) |x| : (a) b else |y| c`. `While[rhs]`.
        /// The cont expression part `: (a)` may be omitted.
        @"while",
        /// `for (lhs) rhs`.
        for_simple,
        /// `for (lhs[0..inputs]) lhs[inputs + 1] else lhs[inputs + 2]`. `For[rhs]`.
        @"for",
        /// `lhs..rhs`. rhs can be omitted.
        for_range,
        /// `if (lhs) rhs`.
        /// `if (lhs) |a| rhs`.
        if_simple,
        /// `if (lhs) a else b`. `If[rhs]`.
        /// `if (lhs) |x| a else b`. `If[rhs]`.
        /// `if (lhs) |x| a else |y| b`. `If[rhs]`.
        @"if",
        /// `suspend lhs`.
        ///
        /// rhs is unused.
        /// main_token is the `suspend`.
        @"suspend",
        /// `resume lhs`.
        ///
        /// rhs is unused.
        /// main_token is the `resume`.
        @"resume",
        /// `continue :lhs rhs`,
        /// `continue rhs`,
        /// `continue :lhs`,
        /// `continue`.
        ///
        /// lhs is a `OptionalTokenIndex` to the label identifier, if any.
        /// rhs is a `Node.OptionalIndex`.
        /// main_token is the `continue`.
        @"continue",
        /// `break :lhs rhs`,
        /// `break rhs`,
        /// `break :lhs`,
        /// `break`.
        ///
        /// lhs is a `OptionalTokenIndex` to the label identifier, if any.
        /// rhs is a `Node.OptionalIndex`.
        /// main_token is the `break`.
        @"break",
        /// `return lhs`, `return`.
        ///
        /// lhs is a `Node.OptionalIndex`.
        /// rhs is unused.
        /// main_token is the `return`.
        @"return",
        /// `fn (a: lhs) rhs`.
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// extern function declarations use this tag.
        ///
        /// lhs is a `Node.OptionalIndex` to the first parameter type expression, if any.
        /// rhs is a `Node.OptionalIndex` to the return type expression. Can't be `.none` unless a parsing error occured.
        /// main_token is the `fn` keyword.
        fn_proto_simple,
        /// `fn (a: b, c: d) rhs`.
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// extern function declarations use this tag.
        ///
        /// lhs is a `Node.ExtraIndex` to a `SubRange` that stores the parameter type expression nodes.
        /// rhs is a `Node.OptionalIndex` to the return type expression. Can't be `.none` unless a parsing error occured.
        /// main_token is the `fn` keyword.
        fn_proto_multi,
        /// `fn (a: b) addrspace(e) linksection(f) callconv(g) rhs`. `FnProtoOne[lhs]`.
        /// zero or one parameters.
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// extern function declarations use this tag.
        ///
        /// lhs is a `Node.ExtraIndex` to `FnProtoOne`.
        /// rhs is a `Node.OptionalIndex` to the return type expression. Can't be `.none` unless a parsing error occured.
        /// main_token is the `fn` keyword.
        fn_proto_one,
        /// `fn (a: b, c: d) addrspace(e) linksection(f) callconv(g) rhs`. `FnProto[lhs]`.
        /// `anytype` and `...` parameters are omitted from the AST tree.
        /// extern function declarations use this tag.
        ///
        /// lhs is a `Node.ExtraIndex` to `FnProto`.
        /// rhs is a `Node.OptionalIndex` to the return type expression. Can't be `.none` unless a parsing error occured.
        /// main_token is the `fn` keyword.
        fn_proto,
        /// Extern function declarations use the fn_proto tags rather than this one.
        ///
        /// lhs is a `Node.Index` to `fn_proto_*`.
        /// rhs is a `Node.Index` to function body block.
        /// main_token is the `fn` keyword.
        fn_decl,
        /// `anyframe->rhs`.
        ///
        /// lhs is a `TokenIndex` to the `->`.
        /// rhs is a `Node.Index`.
        /// main_token is the `anyframe`.
        anyframe_type,
        /// Both lhs and rhs unused.
        anyframe_literal,
        /// Both lhs and rhs unused.
        char_literal,
        /// Both lhs and rhs unused.
        number_literal,
        /// Both lhs and rhs unused.
        unreachable_literal,
        /// Both lhs and rhs unused.
        /// Most identifiers will not have explicit AST nodes, however for expressions
        /// which could be one of many different kinds of AST nodes, there will be an
        /// identifier AST node for it.
        identifier,
        /// `.foo`.
        ///
        /// lhs is a `TokenIndex` to the `.`,
        /// rhs unused,
        /// main_token is the identifier.
        enum_literal,
        /// Both lhs and rhs unused.
        /// main_token is the string literal token.
        string_literal,
        /// main_token is the first token index (redundant with lhs).
        /// lhs is the first token index; rhs is the last token index.
        /// Could be a series of multiline_string_literal_line tokens, or a single
        /// string_literal token.
        multiline_string_literal,
        /// `(lhs)`.
        ///
        /// lhs is a `Node.Index`.
        /// rhs is a `TokenIndex` to the `)`.
        /// main_token is the `(`.
        grouped_expression,
        /// `@a(lhs, rhs)`.
        ///
        /// lhs is a `Node.OptionalIndex` to the first argument, if any.
        /// rhs is a `Node.OptionalIndex` to the second argument, if any.
        /// main_token is the builtin token.
        builtin_call_two,
        /// Same as `builtin_call_two` except there is known to be a trailing comma
        /// before the final rparen.
        builtin_call_two_comma,
        /// `@a(b, c)`. `extra_data[lhs..rhs]`.
        /// main_token is the builtin token.
        builtin_call,
        /// Same as `builtin_call` except there is known to be a trailing comma
        /// before the final rparen.
        builtin_call_comma,
        /// `error{a, b}`.
        ///
        /// lhs is unused.
        /// rhs is the rbrace,
        /// main_token is the `error`.
        error_set_decl,
        /// `struct {}`, `union {}`, `opaque {}`, `enum {}`. `extra_data[lhs..rhs]`.
        ///
        /// main_token is the `struct`, `union`, `opaque` or `enum`.
        container_decl,
        /// Same as `container_decl` except there is known to be a trailing comma
        /// before the final rbrace.
        container_decl_trailing,
        /// `struct {lhs, rhs}`, `union {lhs, rhs}`, `opaque {lhs, rhs}`, `enum {lhs, rhs}`.
        ///
        /// lhs is a `Node.OptionalIndex` to the first container member, if any.
        /// rhs is a `Node.OptionalIndex` to the second container member, if any.
        /// main_token is the `struct`, `union`, `opaque` or `enum`.
        container_decl_two,
        /// Same as `container_decl_two` except there is known to be a trailing comma
        /// before the final rbrace.
        container_decl_two_trailing,
        /// `struct(lhs)`, `union(lhs)`, `enum(lhs)`.
        ///
        /// lhs is a `Node.Index`.
        /// rhs is a `ExtraIndex` to a `SubRange` that stores the container member nodes.
        /// main_token is the `struct`, `union` or `enum`.
        container_decl_arg,
        /// Same as `container_decl_arg` except there is known to be a trailing comma
        /// before the final rbrace.
        container_decl_arg_trailing,
        /// `union(enum) {}`. `extra_data[lhs..rhs]`.
        ///
        /// main_token is the `union`.
        ///
        /// A tagged union with explicitly provided enums will instead be
        /// represented by `container_decl_arg`.
        tagged_union,
        /// Same as `tagged_union` except there is known to be a trailing comma
        /// before the final rbrace.
        tagged_union_trailing,
        /// `union(enum) {lhs, rhs}`. lhs or rhs may be omitted.
        ///
        /// lhs is a `Node.OptionalIndex` to the first container member, if any.
        /// rhs is a `Node.OptionalIndex` to the second container member, if any.
        /// main_token is the `union`.
        ///
        /// A tagged union with explicitly provided enums will instead be
        /// represented by `container_decl_arg`.
        tagged_union_two,
        /// Same as `tagged_union_two` except there is known to be a trailing comma
        /// before the final rbrace.
        tagged_union_two_trailing,
        /// `union(enum(lhs)) {}`.
        ///
        /// lhs is a `Node.Index`.
        /// rhs is a `ExtraIndex` to a `SubRange` that stores the container member nodes.
        /// main_token is the `union`.
        tagged_union_enum_tag,
        /// Same as `tagged_union_enum_tag` except there is known to be a trailing comma
        /// before the final rbrace.
        tagged_union_enum_tag_trailing,
        /// `a: lhs = rhs,`,
        /// `a: lhs,`.
        ///
        /// lhs is a `Node.Index` to the field type expression.
        /// rhs is a `Node.OptionalIndex` to the default value expression, if any.
        /// main_token is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field_init,
        /// `a: lhs align(rhs),`.
        ///
        /// lhs is a `Node.Index` to the field type expression.
        /// rhs is a `Node.Index` to the alignment expression.
        /// main_token is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field_align,
        /// `a: lhs align(c) = d,`.
        ///
        /// lhs is a `Node.Index` to the field type expression.
        /// rhs is a `ExtraIndex` to `ContainerField`.
        /// main_token is the field name identifier.
        ///
        /// `lastToken()` does not include the possible trailing comma.
        container_field,
        /// `comptime lhs`.
        ///
        /// rhs is unused.
        /// main_token is the `comptime`.
        @"comptime",
        /// `nosuspend lhs`.
        ///
        /// rhs is unused.
        /// main_token is the `nosuspend`.
        @"nosuspend",
        /// `{lhs rhs}`.
        ///
        /// lhs is a `Node.OptionalIndex` to the first statement, if any.
        /// rhs is a `Node.OptionalIndex` to the second statement, if any.
        /// main_token is the `{`.
        block_two,
        /// Same as `block_two_semicolon` except there is known to be a trailing comma
        /// before the final rbrace.
        block_two_semicolon,
        /// `{a b}`. `extra_data[lhs..rhs]`.
        ///
        /// main_token is the `{`.
        block,
        /// Same as `block` except there is known to be a trailing comma
        /// before the final rbrace.
        block_semicolon,
        /// `asm(lhs)`.
        ///
        /// rhs is a `Token.Index` to the `)`.
        /// main_token is the `asm`.
        asm_simple,
        /// `asm(lhs, a)`.
        ///
        /// rhs is a `ExtraIndex` to `Asm`.
        /// main_token is the `asm`.
        @"asm",
        /// `[a] "b" (c)`. lhs is 0, rhs is token index of the rparen.
        /// `[a] "b" (-> lhs)`. rhs is token index of the rparen.
        /// main_token is `a`.
        asm_output,
        /// `[a] "b" (lhs)`. rhs is token index of the rparen.
        /// main_token is `a`.
        asm_input,
        /// `error.a`.
        ///
        /// lhs is the `OptionalTokenIndex` of `.`. Can't be `.none` unless a parsing error occured.
        /// rhs is the `OptionalTokenIndex` of `a`. Can't be `.none` unless a parsing error occured.
        /// main_token is `error`.
        error_value,
        /// `lhs!rhs`.
        ///
        /// main_token is the `!`.
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

    pub const Data = struct {
        lhs: Item,
        rhs: Item,

        /// The active field is determined by looking at the node tag.
        pub const Item = union {
            node: Index,
            opt_node: OptionalIndex,
            token: TokenIndex,
            opt_token: OptionalTokenIndex,
            extra_index: ExtraIndex,
            @"for": For,
        };
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
