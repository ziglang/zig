const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Token = std.zig.Token;

pub const TokenIndex = usize;
pub const NodeIndex = usize;

pub const Tree = struct {
    /// Reference to externally-owned data.
    source: []const u8,
    token_ids: []const Token.Id,
    token_locs: []const Token.Loc,
    errors: []const Error,
    root_node: *Node.Root,

    arena: std.heap.ArenaAllocator.State,
    gpa: *mem.Allocator,

    /// translate-c uses this to avoid having to emit correct newlines
    /// TODO get rid of this hack
    generated: bool = false,

    pub fn deinit(self: *Tree) void {
        self.gpa.free(self.token_ids);
        self.gpa.free(self.token_locs);
        self.gpa.free(self.errors);
        self.arena.promote(self.gpa).deinit();
    }

    pub fn renderError(self: *Tree, parse_error: *const Error, stream: var) !void {
        return parse_error.render(self.token_ids, stream);
    }

    pub fn tokenSlice(self: *Tree, token_index: TokenIndex) []const u8 {
        return self.tokenSliceLoc(self.token_locs[token_index]);
    }

    pub fn tokenSliceLoc(self: *Tree, token: Token.Loc) []const u8 {
        return self.source[token.start..token.end];
    }

    pub fn getNodeSource(self: *const Tree, node: *const Node) []const u8 {
        const first_token = self.token_locs[node.firstToken()];
        const last_token = self.token_locs[node.lastToken()];
        return self.source[first_token.start..last_token.end];
    }

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    /// Return the Location of the token relative to the offset specified by `start_index`.
    pub fn tokenLocationLoc(self: *Tree, start_index: usize, token: Token.Loc) Location {
        var loc = Location{
            .line = 0,
            .column = 0,
            .line_start = start_index,
            .line_end = self.source.len,
        };
        if (self.generated)
            return loc;
        const token_start = token.start;
        for (self.source[start_index..]) |c, i| {
            if (i + start_index == token_start) {
                loc.line_end = i + start_index;
                while (loc.line_end < self.source.len and self.source[loc.line_end] != '\n') : (loc.line_end += 1) {}
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

    pub fn tokenLocation(self: *Tree, start_index: usize, token_index: TokenIndex) Location {
        return self.tokenLocationLoc(start_index, self.token_locs[token_index]);
    }

    pub fn tokensOnSameLine(self: *Tree, token1_index: TokenIndex, token2_index: TokenIndex) bool {
        return self.tokensOnSameLineLoc(self.token_locs[token1_index], self.token_locs[token2_index]);
    }

    pub fn tokensOnSameLineLoc(self: *Tree, token1: Token.Loc, token2: Token.Loc) bool {
        return mem.indexOfScalar(u8, self.source[token1.end..token2.start], '\n') == null;
    }

    pub fn dump(self: *Tree) void {
        self.root_node.base.dump(0);
    }

    /// Skips over comments
    pub fn prevToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index - 1;
        while (self.token_ids[index] == .line_comment) {
            index -= 1;
        }
        return index;
    }

    /// Skips over comments
    pub fn nextToken(self: *Tree, token_index: TokenIndex) TokenIndex {
        var index = token_index + 1;
        while (self.token_ids[index] == .line_comment) {
            index += 1;
        }
        return index;
    }
};

pub const Error = union(enum) {
    pub fn render(self: *const Error, tokens: []const Token.Id, stream: var) !void {
        switch (self.*) {
            .invalid_token => |*x| return x.render(tokens, stream),
            .expected_container_members => |*x| return x.render(tokens, stream),
            .expected_string_literal => |*x| return x.render(tokens, stream),
            .expected_integer_literal => |*x| return x.render(tokens, stream),
            .expected_pub_item => |*x| return x.render(tokens, stream),
            .expected_identifier => |*x| return x.render(tokens, stream),
            .expected_statement => |*x| return x.render(tokens, stream),
            .expected_var_decl_or_fn => |*x| return x.render(tokens, stream),
            .expected_var_decl => |*x| return x.render(tokens, stream),
            .expected_fn => |*x| return x.render(tokens, stream),
            .expected_return_type => |*x| return x.render(tokens, stream),
            .expected_aggregate_kw => |*x| return x.render(tokens, stream),
            .unattached_doc_comment => |*x| return x.render(tokens, stream),
            .expected_eq_or_semi => |*x| return x.render(tokens, stream),
            .expected_semi_or_l_brace => |*x| return x.render(tokens, stream),
            .expected_semi_or_else => |*x| return x.render(tokens, stream),
            .expected_label_or_l_brace => |*x| return x.render(tokens, stream),
            .expected_l_brace => |*x| return x.render(tokens, stream),
            .expected_colon_or_r_paren => |*x| return x.render(tokens, stream),
            .expected_labelable => |*x| return x.render(tokens, stream),
            .expected_inlinable => |*x| return x.render(tokens, stream),
            .expected_asm_output_return_or_type => |*x| return x.render(tokens, stream),
            .expected_call => |*x| return x.render(tokens, stream),
            .expected_call_or_fn_proto => |*x| return x.render(tokens, stream),
            .expected_slice_or_r_bracket => |*x| return x.render(tokens, stream),
            .extra_align_qualifier => |*x| return x.render(tokens, stream),
            .extra_const_qualifier => |*x| return x.render(tokens, stream),
            .extra_volatile_qualifier => |*x| return x.render(tokens, stream),
            .extra_allow_zero_qualifier => |*x| return x.render(tokens, stream),
            .expected_type_expr => |*x| return x.render(tokens, stream),
            .expected_primary_type_expr => |*x| return x.render(tokens, stream),
            .expected_param_type => |*x| return x.render(tokens, stream),
            .expected_expr => |*x| return x.render(tokens, stream),
            .expected_primary_expr => |*x| return x.render(tokens, stream),
            .expected_token => |*x| return x.render(tokens, stream),
            .expected_comma_or_end => |*x| return x.render(tokens, stream),
            .expected_param_list => |*x| return x.render(tokens, stream),
            .expected_payload => |*x| return x.render(tokens, stream),
            .expected_block_or_assignment => |*x| return x.render(tokens, stream),
            .expected_block_or_expression => |*x| return x.render(tokens, stream),
            .expected_expr_or_assignment => |*x| return x.render(tokens, stream),
            .expected_prefix_expr => |*x| return x.render(tokens, stream),
            .expected_loop_expr => |*x| return x.render(tokens, stream),
            .expected_deref_or_unwrap => |*x| return x.render(tokens, stream),
            .expected_suffix_op => |*x| return x.render(tokens, stream),
            .expected_block_or_field => |*x| return x.render(tokens, stream),
            .decl_between_fields => |*x| return x.render(tokens, stream),
            .invalid_and => |*x| return x.render(tokens, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .invalid_token => |x| return x.token,
            .expected_container_members => |x| return x.token,
            .expected_string_literal => |x| return x.token,
            .expected_integer_literal => |x| return x.token,
            .expected_pub_item => |x| return x.token,
            .expected_identifier => |x| return x.token,
            .expected_statement => |x| return x.token,
            .expected_var_decl_or_fn => |x| return x.token,
            .expected_var_decl => |x| return x.token,
            .expected_fn => |x| return x.token,
            .expected_return_type => |x| return x.token,
            .expected_aggregate_kw => |x| return x.token,
            .unattached_doc_comment => |x| return x.token,
            .expected_eq_or_semi => |x| return x.token,
            .expected_semi_or_l_brace => |x| return x.token,
            .expected_semi_or_else => |x| return x.token,
            .expected_label_or_l_brace => |x| return x.token,
            .expected_l_brace => |x| return x.token,
            .expected_colon_or_r_paren => |x| return x.token,
            .expected_labelable => |x| return x.token,
            .expected_inlinable => |x| return x.token,
            .expected_asm_output_return_or_type => |x| return x.token,
            .expected_call => |x| return x.node.firstToken(),
            .expected_call_or_fn_proto => |x| return x.node.firstToken(),
            .expected_slice_or_r_bracket => |x| return x.token,
            .extra_align_qualifier => |x| return x.token,
            .extra_const_qualifier => |x| return x.token,
            .extra_volatile_qualifier => |x| return x.token,
            .extra_allow_zero_qualifier => |x| return x.token,
            .expected_type_expr => |x| return x.token,
            .expected_primary_type_expr => |x| return x.token,
            .expected_param_type => |x| return x.token,
            .expected_expr => |x| return x.token,
            .expected_primary_expr => |x| return x.token,
            .expected_token => |x| return x.token,
            .expected_comma_or_end => |x| return x.token,
            .expected_param_list => |x| return x.token,
            .expected_payload => |x| return x.token,
            .expected_block_or_assignment => |x| return x.token,
            .expected_block_or_expression => |x| return x.token,
            .expected_expr_or_assignment => |x| return x.token,
            .expected_prefix_expr => |x| return x.token,
            .expected_loop_expr => |x| return x.token,
            .expected_deref_or_unwrap => |x| return x.token,
            .expected_suffix_op => |x| return x.token,
            .expected_block_or_field => |x| return x.token,
            .decl_between_fields => |x| return x.token,
            .invalid_and => |x| return x.token,
        }
    }

    invalid_token: SingleTokenError("Invalid token '{}'"),
    expected_container_members: SingleTokenError("Expected test, comptime, var decl, or container field, found '{}'"),
    expected_string_literal: SingleTokenError("Expected string literal, found '{}'"),
    expected_integer_literal: SingleTokenError("Expected integer literal, found '{}'"),
    expected_identifier: SingleTokenError("Expected identifier, found '{}'"),
    expected_statement: SingleTokenError("Expected statement, found '{}'"),
    expected_var_decl_or_fn: SingleTokenError("Expected variable declaration or function, found '{}'"),
    expected_var_decl: SingleTokenError("Expected variable declaration, found '{}'"),
    expected_fn: SingleTokenError("Expected function, found '{}'"),
    expected_return_type: SingleTokenError("Expected 'var' or return type expression, found '{}'"),
    expected_aggregate_kw: SingleTokenError("Expected '" ++ Token.Id.keyword_struct.symbol() ++ "', '" ++ Token.Id.keyword_union.symbol() ++ "', or '" ++ Token.Id.keyword_enum.symbol() ++ "', found '{}'"),
    expected_eq_or_semi: SingleTokenError("Expected '=' or ';', found '{}'"),
    expected_semi_or_l_brace: SingleTokenError("Expected ';' or '{{', found '{}'"),
    expected_semi_or_else: SingleTokenError("Expected ';' or 'else', found '{}'"),
    expected_l_brace: SingleTokenError("Expected '{{', found '{}'"),
    expected_label_or_l_brace: SingleTokenError("Expected label or '{{', found '{}'"),
    expected_colon_or_r_paren: SingleTokenError("Expected ':' or ')', found '{}'"),
    expected_labelable: SingleTokenError("Expected 'while', 'for', 'inline', 'suspend', or '{{', found '{}'"),
    expected_inlinable: SingleTokenError("Expected 'while' or 'for', found '{}'"),
    expected_asm_output_return_or_type: SingleTokenError("Expected '->' or '" ++ Token.Id.identifier.symbol() ++ "', found '{}'"),
    expected_slice_or_r_bracket: SingleTokenError("Expected ']' or '..', found '{}'"),
    expected_type_expr: SingleTokenError("Expected type expression, found '{}'"),
    expected_primary_type_expr: SingleTokenError("Expected primary type expression, found '{}'"),
    expected_expr: SingleTokenError("Expected expression, found '{}'"),
    expected_primary_expr: SingleTokenError("Expected primary expression, found '{}'"),
    expected_param_list: SingleTokenError("Expected parameter list, found '{}'"),
    expected_payload: SingleTokenError("Expected loop payload, found '{}'"),
    expected_block_or_assignment: SingleTokenError("Expected block or assignment, found '{}'"),
    expected_block_or_expression: SingleTokenError("Expected block or expression, found '{}'"),
    expected_expr_or_assignment: SingleTokenError("Expected expression or assignment, found '{}'"),
    expected_prefix_expr: SingleTokenError("Expected prefix expression, found '{}'"),
    expected_loop_expr: SingleTokenError("Expected loop expression, found '{}'"),
    expected_deref_or_unwrap: SingleTokenError("Expected pointer dereference or optional unwrap, found '{}'"),
    expected_suffix_op: SingleTokenError("Expected pointer dereference, optional unwrap, or field access, found '{}'"),
    expected_block_or_field: SingleTokenError("Expected block or field, found '{}'"),

    expected_param_type: SimpleError("Expected parameter type"),
    expected_pub_item: SimpleError("Expected function or variable declaration after pub"),
    unattached_doc_comment: SimpleError("Unattached documentation comment"),
    extra_align_qualifier: SimpleError("Extra align qualifier"),
    extra_const_qualifier: SimpleError("Extra const qualifier"),
    extra_volatile_qualifier: SimpleError("Extra volatile qualifier"),
    extra_allow_zero_qualifier: SimpleError("Extra allowzero qualifier"),
    decl_between_fields: SimpleError("Declarations are not allowed between container fields"),
    invalid_and: SimpleError("`&&` is invalid. Note that `and` is boolean AND."),

    expected_call: struct {
        node: *Node,

        const ThisError = @This();

        pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
            return stream.print("expected call, found {}", .{
                @tagName(self.node.id),
            });
        }
    },

    expected_call_or_fn_proto: struct {
        node: *Node,

        const ThisError = @This();

        pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
            return stream.print("expected call or function, found {}", .{@tagName(self.node.id)});
        }
    },

    expected_token: struct {
        token: TokenIndex,
        expected_id: Token.Id,

        const ThisError = @This();

        pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
            const found_token = tokens[self.token];
            switch (found_token) {
                .invalid => {
                    return stream.print("expected '{}', found invalid bytes", .{self.expected_id.symbol()});
                },
                else => {
                    const token_name = found_token.symbol();
                    return stream.print("expected '{}', found '{}'", .{ self.expected_id.symbol(), token_name });
                },
            }
        }
    },

    expected_comma_or_end: struct {
        token: TokenIndex,
        end_id: Token.Id,

        const ThisError = @This();

        pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
            const actual_token = tokens[self.token];
            return stream.print("expected ',' or '{}', found '{}'", .{
                self.end_id.symbol(),
                actual_token.symbol(),
            });
        }
    },

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
                const actual_token = tokens[self.token];
                return stream.print(msg, .{actual_token.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: []const Token.Id, stream: var) !void {
                return stream.writeAll(msg);
            }
        };
    }
};

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        // Top level
        root,
        use,
        test_decl,

        // Statements
        var_decl,
        Defer,

        // Operators
        infix_op,
        prefix_op,
        /// Not all suffix operations are under this tag. To save memory, some
        /// suffix operations have dedicated Node tags.
        suffix_op,
        /// `T{a, b}`
        array_initializer,
        /// ArrayInitializer but with `.` instead of a left-hand-side operand.
        array_initializer_dot,
        /// `T{.a = b}`
        struct_initializer,
        /// StructInitializer but with `.` instead of a left-hand-side operand.
        struct_initializer_dot,
        /// `foo()`
        call,

        // Control flow
        Switch,
        While,
        For,
        If,
        control_flow_expression,
        Suspend,

        // Type expressions
        var_type,
        error_type,
        fn_proto,
        any_frame_type,

        // Primary expressions
        integer_literal,
        float_literal,
        enum_literal,
        string_literal,
        multiline_string_literal,
        char_literal,
        bool_literal,
        null_literal,
        undefined_literal,
        Unreachable,
        identifier,
        grouped_expression,
        builtin_call,
        error_set_decl,
        container_decl,
        Asm,
        Comptime,
        Nosuspend,
        block,

        // Misc
        doc_comment,
        switch_case,
        switch_else,
        Else,
        payload,
        pointer_payload,
        pointer_index_payload,
        container_field,
        error_tag,
        field_initializer,
    };

    pub fn cast(base: *Node, comptime T: type) ?*T {
        if (base.id == comptime typeToId(T)) {
            return @fieldParentPtr(T, "base", base);
        }
        return null;
    }

    pub fn iterate(base: *Node, index: usize) ?*Node {
        inline for (@typeInfo(Node).Struct.decls) |d| {
            const T = @field(Node, d.name);
            if (@TypeOf(T) == type and @typeInfo(T) == .Struct) {
                if (@typeInfo(T).Struct.fields[0].default_value.?.id == base.id) {
                    return @fieldParentPtr(T, "base", base).iterate(index);
                }
            }
        }
        unreachable;
    }

    pub fn firstToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Node).Struct.decls) |d| {
            const T = @field(Node, d.name);
            if (@TypeOf(T) == type and @typeInfo(T) == .Struct) {
                if (@typeInfo(T).Struct.fields[0].default_value.?.id == base.id) {
                    return @fieldParentPtr(T, "base", base).firstToken();
                }
            }
        }
        unreachable;
    }

    pub fn lastToken(base: *const Node) TokenIndex {
        inline for (@typeInfo(Node).Struct.decls) |d| {
            const T = @field(Node, d.name);
            if (@TypeOf(T) == type and @typeInfo(T) == .Struct) {
                if (@typeInfo(T).Struct.fields[0].default_value.?.id == base.id) {
                    return @fieldParentPtr(T, "base", base).lastToken();
                }
            }
        }
        unreachable;
    }

    pub fn typeToId(comptime T: type) Id {
        return @typeInfo(T).Struct.fields[0].default_value.?.id;
    }

    pub fn requireSemiColon(base: *const Node) bool {
        var n = base;
        while (true) {
            switch (n.id) {
                .root,
                .container_field,
                .block,
                .payload,
                .pointer_payload,
                .pointer_index_payload,
                .Switch,
                .switch_case,
                .switch_else,
                .field_initializer,
                .doc_comment,
                .test_decl,
                => return false,
                .While => {
                    const while_node = @fieldParentPtr(While, "base", n);
                    if (while_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return while_node.body.id != .block;
                },
                .For => {
                    const for_node = @fieldParentPtr(For, "base", n);
                    if (for_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return for_node.body.id != .block;
                },
                .If => {
                    const if_node = @fieldParentPtr(If, "base", n);
                    if (if_node.@"else") |@"else"| {
                        n = &@"else".base;
                        continue;
                    }

                    return if_node.body.id != .block;
                },
                .Else => {
                    const else_node = @fieldParentPtr(Else, "base", n);
                    n = else_node.body;
                    continue;
                },
                .Defer => {
                    const defer_node = @fieldParentPtr(Defer, "base", n);
                    return defer_node.expr.id != .block;
                },
                .Comptime => {
                    const comptime_node = @fieldParentPtr(Comptime, "base", n);
                    return comptime_node.expr.id != .block;
                },
                .Suspend => {
                    const suspend_node = @fieldParentPtr(Suspend, "base", n);
                    if (suspend_node.body) |body| {
                        return body.id != .block;
                    }

                    return true;
                },
                .Nosuspend => {
                    const nosuspend_node = @fieldParentPtr(Nosuspend, "base", n);
                    return nosuspend_node.expr.id != .block;
                },
                else => return true,
            }
        }
    }

    pub fn dump(self: *Node, indent: usize) void {
        {
            var i: usize = 0;
            while (i < indent) : (i += 1) {
                std.debug.warn(" ", .{});
            }
        }
        std.debug.warn("{}\n", .{@tagName(self.id)});

        var child_i: usize = 0;
        while (self.iterate(child_i)) |child| : (child_i += 1) {
            child.dump(indent + 2);
        }
    }

    /// The decls data follows this struct in memory as an array of Node pointers.
    pub const Root = struct {
        base: Node = Node{ .id = .root },
        eof_token: TokenIndex,
        decls_len: NodeIndex,

        /// After this the caller must initialize the decls list.
        pub fn create(allocator: *mem.Allocator, decls_len: NodeIndex, eof_token: TokenIndex) !*Root {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Root), sizeInBytes(decls_len));
            const self = @ptrCast(*Root, bytes.ptr);
            self.* = .{
                .eof_token = eof_token,
                .decls_len = decls_len,
            };
            return self;
        }

        pub fn destroy(self: *Decl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Root, index: usize) ?*Node {
            var i = index;

            if (i < self.decls_len) return self.declsConst()[i];
            return null;
        }

        pub fn decls(self: *Root) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Root);
            return @ptrCast([*]*Node, decls_start)[0..self.decls_len];
        }

        pub fn declsConst(self: *const Root) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Root);
            return @ptrCast([*]const *Node, decls_start)[0..self.decls_len];
        }

        pub fn firstToken(self: *const Root) TokenIndex {
            if (self.decls_len == 0) return self.eof_token;
            return self.declsConst()[0].firstToken();
        }

        pub fn lastToken(self: *const Root) TokenIndex {
            if (self.decls_len == 0) return self.eof_token;
            return self.declsConst()[self.decls_len - 1].lastToken();
        }

        fn sizeInBytes(decls_len: NodeIndex) usize {
            return @sizeOf(Root) + @sizeOf(*Node) * @as(usize, decls_len);
        }
    };

    pub const VarDecl = struct {
        base: Node = Node{ .id = .var_decl },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        thread_local_token: ?TokenIndex,
        name_token: TokenIndex,
        eq_token: ?TokenIndex,
        mut_token: TokenIndex,
        comptime_token: ?TokenIndex,
        extern_export_token: ?TokenIndex,
        lib_name: ?*Node,
        type_node: ?*Node,
        align_node: ?*Node,
        section_node: ?*Node,
        init_node: ?*Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *const VarDecl, index: usize) ?*Node {
            var i = index;

            if (self.type_node) |type_node| {
                if (i < 1) return type_node;
                i -= 1;
            }

            if (self.align_node) |align_node| {
                if (i < 1) return align_node;
                i -= 1;
            }

            if (self.section_node) |section_node| {
                if (i < 1) return section_node;
                i -= 1;
            }

            if (self.init_node) |init_node| {
                if (i < 1) return init_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const VarDecl) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.thread_local_token) |thread_local_token| return thread_local_token;
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.extern_export_token) |extern_export_token| return extern_export_token;
            assert(self.lib_name == null);
            return self.mut_token;
        }

        pub fn lastToken(self: *const VarDecl) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const Use = struct {
        base: Node = Node{ .id = .use },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        use_token: TokenIndex,
        expr: *Node,
        semicolon_token: TokenIndex,

        pub fn iterate(self: *const Use, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Use) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            return self.use_token;
        }

        pub fn lastToken(self: *const Use) TokenIndex {
            return self.semicolon_token;
        }
    };

    pub const ErrorSetDecl = struct {
        base: Node = Node{ .id = .error_set_decl },
        error_token: TokenIndex,
        rbrace_token: TokenIndex,
        decls_len: NodeIndex,

        /// After this the caller must initialize the decls list.
        pub fn alloc(allocator: *mem.Allocator, decls_len: NodeIndex) !*ErrorSetDecl {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ErrorSetDecl), sizeInBytes(decls_len));
            return @ptrCast(*ErrorSetDecl, bytes.ptr);
        }

        pub fn free(self: *ErrorSetDecl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ErrorSetDecl, index: usize) ?*Node {
            var i = index;

            if (i < self.decls_len) return self.declsConst()[i];
            i -= self.decls_len;

            return null;
        }

        pub fn firstToken(self: *const ErrorSetDecl) TokenIndex {
            return self.error_token;
        }

        pub fn lastToken(self: *const ErrorSetDecl) TokenIndex {
            return self.rbrace_token;
        }

        pub fn decls(self: *ErrorSetDecl) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ErrorSetDecl);
            return @ptrCast([*]*Node, decls_start)[0..self.decls_len];
        }

        pub fn declsConst(self: *const ErrorSetDecl) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ErrorSetDecl);
            return @ptrCast([*]const *Node, decls_start)[0..self.decls_len];
        }

        fn sizeInBytes(decls_len: NodeIndex) usize {
            return @sizeOf(ErrorSetDecl) + @sizeOf(*Node) * @as(usize, decls_len);
        }
    };

    /// The fields and decls Node pointers directly follow this struct in memory.
    pub const ContainerDecl = struct {
        base: Node = Node{ .id = .container_decl },
        kind_token: TokenIndex,
        layout_token: ?TokenIndex,
        lbrace_token: TokenIndex,
        rbrace_token: TokenIndex,
        fields_and_decls_len: NodeIndex,
        init_arg_expr: InitArg,

        pub const InitArg = union(enum) {
            None,
            Enum: ?*Node,
            Type: *Node,
        };

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, fields_and_decls_len: NodeIndex) !*ContainerDecl {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ContainerDecl), sizeInBytes(fields_and_decls_len));
            return @ptrCast(*ContainerDecl, bytes.ptr);
        }

        pub fn free(self: *ContainerDecl, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.fields_and_decls_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ContainerDecl, index: usize) ?*Node {
            var i = index;

            switch (self.init_arg_expr) {
                .Type => |t| {
                    if (i < 1) return t;
                    i -= 1;
                },
                .None, .Enum => {},
            }

            if (i < self.fields_and_decls_len) return self.fieldsAndDeclsConst()[i];
            i -= self.fields_and_decls_len;

            return null;
        }

        pub fn firstToken(self: *const ContainerDecl) TokenIndex {
            if (self.layout_token) |layout_token| {
                return layout_token;
            }
            return self.kind_token;
        }

        pub fn lastToken(self: *const ContainerDecl) TokenIndex {
            return self.rbrace_token;
        }

        pub fn fieldsAndDecls(self: *ContainerDecl) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ContainerDecl);
            return @ptrCast([*]*Node, decls_start)[0..self.fields_and_decls_len];
        }

        pub fn fieldsAndDeclsConst(self: *const ContainerDecl) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ContainerDecl);
            return @ptrCast([*]const *Node, decls_start)[0..self.fields_and_decls_len];
        }

        fn sizeInBytes(fields_and_decls_len: NodeIndex) usize {
            return @sizeOf(ContainerDecl) + @sizeOf(*Node) * @as(usize, fields_and_decls_len);
        }
    };

    pub const ContainerField = struct {
        base: Node = Node{ .id = .container_field },
        doc_comments: ?*DocComment,
        comptime_token: ?TokenIndex,
        name_token: TokenIndex,
        type_expr: ?*Node,
        value_expr: ?*Node,
        align_expr: ?*Node,

        pub fn iterate(self: *const ContainerField, index: usize) ?*Node {
            var i = index;

            if (self.type_expr) |type_expr| {
                if (i < 1) return type_expr;
                i -= 1;
            }

            if (self.align_expr) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            if (self.value_expr) |value_expr| {
                if (i < 1) return value_expr;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ContainerField) TokenIndex {
            return self.comptime_token orelse self.name_token;
        }

        pub fn lastToken(self: *const ContainerField) TokenIndex {
            if (self.value_expr) |value_expr| {
                return value_expr.lastToken();
            }
            if (self.align_expr) |align_expr| {
                // The expression refers to what's inside the parenthesis, the
                // last token is the closing one
                return align_expr.lastToken() + 1;
            }
            if (self.type_expr) |type_expr| {
                return type_expr.lastToken();
            }

            return self.name_token;
        }
    };

    pub const ErrorTag = struct {
        base: Node = Node{ .id = .error_tag },
        doc_comments: ?*DocComment,
        name_token: TokenIndex,

        pub fn iterate(self: *const ErrorTag, index: usize) ?*Node {
            var i = index;

            if (self.doc_comments) |comments| {
                if (i < 1) return &comments.base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ErrorTag) TokenIndex {
            return self.name_token;
        }

        pub fn lastToken(self: *const ErrorTag) TokenIndex {
            return self.name_token;
        }
    };

    pub const Identifier = struct {
        base: Node = Node{ .id = .identifier },
        token: TokenIndex,

        pub fn iterate(self: *const Identifier, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const Identifier) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const Identifier) TokenIndex {
            return self.token;
        }
    };

    /// The params are directly after the FnProto in memory.
    pub const FnProto = struct {
        base: Node = Node{ .id = .fn_proto },
        doc_comments: ?*DocComment,
        visib_token: ?TokenIndex,
        fn_token: TokenIndex,
        name_token: ?TokenIndex,
        params_len: NodeIndex,
        return_type: ReturnType,
        var_args_token: ?TokenIndex,
        extern_export_inline_token: ?TokenIndex,
        body_node: ?*Node,
        lib_name: ?*Node, // populated if this is an extern declaration
        align_expr: ?*Node, // populated if align(A) is present
        section_expr: ?*Node, // populated if linksection(A) is present
        callconv_expr: ?*Node, // populated if callconv(A) is present
        is_extern_prototype: bool = false, // TODO: Remove once extern fn rewriting is
        is_async: bool = false, // TODO: remove once async fn rewriting is

        pub const ReturnType = union(enum) {
            explicit: *Node,
            infer_error_set: *Node,
            invalid: TokenIndex,
        };

        pub const ParamDecl = struct {
            doc_comments: ?*DocComment,
            comptime_token: ?TokenIndex,
            noalias_token: ?TokenIndex,
            name_token: ?TokenIndex,
            param_type: ParamType,

            pub const ParamType = union(enum) {
                var_type: *Node,
                var_args: TokenIndex,
                type_expr: *Node,
            };

            pub fn iterate(self: *const ParamDecl, index: usize) ?*Node {
                var i = index;

                if (i < 1) {
                    switch (self.param_type) {
                        .var_args => return null,
                        .var_type, .type_expr => |node| return node,
                    }
                }
                i -= 1;

                return null;
            }

            pub fn firstToken(self: *const ParamDecl) TokenIndex {
                if (self.comptime_token) |comptime_token| return comptime_token;
                if (self.noalias_token) |noalias_token| return noalias_token;
                if (self.name_token) |name_token| return name_token;
                switch (self.param_type) {
                    .var_args => |tok| return tok,
                    .var_type, .type_expr => |node| return node.firstToken(),
                }
            }

            pub fn lastToken(self: *const ParamDecl) TokenIndex {
                switch (self.param_type) {
                    .var_args => |tok| return tok,
                    .var_type, .type_expr => |node| return node.lastToken(),
                }
            }
        };

        /// After this the caller must initialize the params list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*FnProto {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(FnProto), sizeInBytes(params_len));
            return @ptrCast(*FnProto, bytes.ptr);
        }

        pub fn free(self: *FnProto, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const FnProto, index: usize) ?*Node {
            var i = index;

            if (self.lib_name) |lib_name| {
                if (i < 1) return lib_name;
                i -= 1;
            }

            const params_len: usize = if (self.params_len == 0)
                0
            else switch (self.paramsConst()[self.params_len - 1].param_type) {
                .var_type, .type_expr => self.params_len,
                .var_args => self.params_len - 1,
            };
            if (i < params_len) {
                switch (self.paramsConst()[i].param_type) {
                    .var_type => |n| return n,
                    .var_args => unreachable,
                    .type_expr => |n| return n,
                }
            }
            i -= params_len;

            if (self.align_expr) |align_expr| {
                if (i < 1) return align_expr;
                i -= 1;
            }

            if (self.section_expr) |section_expr| {
                if (i < 1) return section_expr;
                i -= 1;
            }

            switch (self.return_type) {
                .explicit, .infer_error_set => |node| {
                    if (i < 1) return node;
                    i -= 1;
                },
                .invalid => {},
            }

            if (self.body_node) |body_node| {
                if (i < 1) return body_node;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const FnProto) TokenIndex {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.extern_export_inline_token) |extern_export_inline_token| return extern_export_inline_token;
            assert(self.lib_name == null);
            return self.fn_token;
        }

        pub fn lastToken(self: *const FnProto) TokenIndex {
            if (self.body_node) |body_node| return body_node.lastToken();
            switch (self.return_type) {
                .explicit, .infer_error_set => |node| return node.lastToken(),
                .invalid => |tok| return tok,
            }
        }

        pub fn params(self: *FnProto) []ParamDecl {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]ParamDecl, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const FnProto) []const ParamDecl {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(FnProto);
            return @ptrCast([*]const ParamDecl, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(FnProto) + @sizeOf(ParamDecl) * @as(usize, params_len);
        }
    };

    pub const AnyFrameType = struct {
        base: Node = Node{ .id = .any_frame_type },
        anyframe_token: TokenIndex,
        result: ?Result,

        pub const Result = struct {
            arrow_token: TokenIndex,
            return_type: *Node,
        };

        pub fn iterate(self: *const AnyFrameType, index: usize) ?*Node {
            var i = index;

            if (self.result) |result| {
                if (i < 1) return result.return_type;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const AnyFrameType) TokenIndex {
            return self.anyframe_token;
        }

        pub fn lastToken(self: *const AnyFrameType) TokenIndex {
            if (self.result) |result| return result.return_type.lastToken();
            return self.anyframe_token;
        }
    };

    /// The statements of the block follow Block directly in memory.
    pub const Block = struct {
        base: Node = Node{ .id = .block },
        statements_len: NodeIndex,
        lbrace: TokenIndex,
        rbrace: TokenIndex,
        label: ?TokenIndex,

        /// After this the caller must initialize the statements list.
        pub fn alloc(allocator: *mem.Allocator, statements_len: NodeIndex) !*Block {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Block), sizeInBytes(statements_len));
            return @ptrCast(*Block, bytes.ptr);
        }

        pub fn free(self: *Block, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.statements_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Block, index: usize) ?*Node {
            var i = index;

            if (i < self.statements_len) return self.statementsConst()[i];
            i -= self.statements_len;

            return null;
        }

        pub fn firstToken(self: *const Block) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            return self.lbrace;
        }

        pub fn lastToken(self: *const Block) TokenIndex {
            return self.rbrace;
        }

        pub fn statements(self: *Block) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Block);
            return @ptrCast([*]*Node, decls_start)[0..self.statements_len];
        }

        pub fn statementsConst(self: *const Block) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Block);
            return @ptrCast([*]const *Node, decls_start)[0..self.statements_len];
        }

        fn sizeInBytes(statements_len: NodeIndex) usize {
            return @sizeOf(Block) + @sizeOf(*Node) * @as(usize, statements_len);
        }
    };

    pub const Defer = struct {
        base: Node = Node{ .id = .Defer },
        defer_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,

        pub fn iterate(self: *const Defer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Defer) TokenIndex {
            return self.defer_token;
        }

        pub fn lastToken(self: *const Defer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Comptime = struct {
        base: Node = Node{ .id = .Comptime },
        doc_comments: ?*DocComment,
        comptime_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const Comptime, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Comptime) TokenIndex {
            return self.comptime_token;
        }

        pub fn lastToken(self: *const Comptime) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Nosuspend = struct {
        base: Node = Node{ .id = .Nosuspend },
        nosuspend_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const Nosuspend, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Nosuspend) TokenIndex {
            return self.nosuspend_token;
        }

        pub fn lastToken(self: *const Nosuspend) TokenIndex {
            return self.expr.lastToken();
        }
    };

    pub const Payload = struct {
        base: Node = Node{ .id = .payload },
        lpipe: TokenIndex,
        error_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const Payload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.error_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Payload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const Payload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerPayload = struct {
        base: Node = Node{ .id = .pointer_payload },
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const PointerPayload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const PointerPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const PointerPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const PointerIndexPayload = struct {
        base: Node = Node{ .id = .pointer_index_payload },
        lpipe: TokenIndex,
        ptr_token: ?TokenIndex,
        value_symbol: *Node,
        index_symbol: ?*Node,
        rpipe: TokenIndex,

        pub fn iterate(self: *const PointerIndexPayload, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            if (self.index_symbol) |index_symbol| {
                if (i < 1) return index_symbol;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const PointerIndexPayload) TokenIndex {
            return self.lpipe;
        }

        pub fn lastToken(self: *const PointerIndexPayload) TokenIndex {
            return self.rpipe;
        }
    };

    pub const Else = struct {
        base: Node = Node{ .id = .Else },
        else_token: TokenIndex,
        payload: ?*Node,
        body: *Node,

        pub fn iterate(self: *const Else, index: usize) ?*Node {
            var i = index;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const Else) TokenIndex {
            return self.else_token;
        }

        pub fn lastToken(self: *const Else) TokenIndex {
            return self.body.lastToken();
        }
    };

    /// The cases node pointers are found in memory after Switch.
    /// They must be SwitchCase or SwitchElse nodes.
    pub const Switch = struct {
        base: Node = Node{ .id = .Switch },
        switch_token: TokenIndex,
        rbrace: TokenIndex,
        cases_len: NodeIndex,
        expr: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, cases_len: NodeIndex) !*Switch {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Switch), sizeInBytes(cases_len));
            return @ptrCast(*Switch, bytes.ptr);
        }

        pub fn free(self: *Switch, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.cases_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Switch, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            if (i < self.cases_len) return self.casesConst()[i];
            i -= self.cases_len;

            return null;
        }

        pub fn firstToken(self: *const Switch) TokenIndex {
            return self.switch_token;
        }

        pub fn lastToken(self: *const Switch) TokenIndex {
            return self.rbrace;
        }

        pub fn cases(self: *Switch) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Switch);
            return @ptrCast([*]*Node, decls_start)[0..self.cases_len];
        }

        pub fn casesConst(self: *const Switch) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Switch);
            return @ptrCast([*]const *Node, decls_start)[0..self.cases_len];
        }

        fn sizeInBytes(cases_len: NodeIndex) usize {
            return @sizeOf(Switch) + @sizeOf(*Node) * @as(usize, cases_len);
        }
    };

    /// Items sub-nodes appear in memory directly following SwitchCase.
    pub const SwitchCase = struct {
        base: Node = Node{ .id = .switch_case },
        arrow_token: TokenIndex,
        payload: ?*Node,
        expr: *Node,
        items_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, items_len: NodeIndex) !*SwitchCase {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(SwitchCase), sizeInBytes(items_len));
            return @ptrCast(*SwitchCase, bytes.ptr);
        }

        pub fn free(self: *SwitchCase, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.items_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const SwitchCase, index: usize) ?*Node {
            var i = index;

            if (i < self.items_len) return self.itemsConst()[i];
            i -= self.items_len;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const SwitchCase) TokenIndex {
            return self.itemsConst()[0].firstToken();
        }

        pub fn lastToken(self: *const SwitchCase) TokenIndex {
            return self.expr.lastToken();
        }

        pub fn items(self: *SwitchCase) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(SwitchCase);
            return @ptrCast([*]*Node, decls_start)[0..self.items_len];
        }

        pub fn itemsConst(self: *const SwitchCase) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(SwitchCase);
            return @ptrCast([*]const *Node, decls_start)[0..self.items_len];
        }

        fn sizeInBytes(items_len: NodeIndex) usize {
            return @sizeOf(SwitchCase) + @sizeOf(*Node) * @as(usize, items_len);
        }
    };

    pub const SwitchElse = struct {
        base: Node = Node{ .id = .switch_else },
        token: TokenIndex,

        pub fn iterate(self: *const SwitchElse, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const SwitchElse) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const SwitchElse) TokenIndex {
            return self.token;
        }
    };

    pub const While = struct {
        base: Node = Node{ .id = .While },
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        while_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        continue_expr: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const While, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (self.continue_expr) |continue_expr| {
                if (i < 1) return continue_expr;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const While) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.while_token;
        }

        pub fn lastToken(self: *const While) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const For = struct {
        base: Node = Node{ .id = .For },
        label: ?TokenIndex,
        inline_token: ?TokenIndex,
        for_token: TokenIndex,
        array_expr: *Node,
        payload: *Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const For, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.array_expr;
            i -= 1;

            if (i < 1) return self.payload;
            i -= 1;

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const For) TokenIndex {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.for_token;
        }

        pub fn lastToken(self: *const For) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const If = struct {
        base: Node = Node{ .id = .If },
        if_token: TokenIndex,
        condition: *Node,
        payload: ?*Node,
        body: *Node,
        @"else": ?*Else,

        pub fn iterate(self: *const If, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            if (self.@"else") |@"else"| {
                if (i < 1) return &@"else".base;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const If) TokenIndex {
            return self.if_token;
        }

        pub fn lastToken(self: *const If) TokenIndex {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const InfixOp = struct {
        base: Node = Node{ .id = .infix_op },
        op_token: TokenIndex,
        lhs: *Node,
        op: Op,
        rhs: *Node,

        pub const Op = union(enum) {
            add,
            add_wrap,
            array_cat,
            array_mult,
            assign,
            assign_bit_and,
            assign_bit_or,
            assign_bit_shift_left,
            assign_bit_shift_right,
            assign_bit_xor,
            assign_div,
            assign_sub,
            assign_sub_wrap,
            assign_mod,
            assign_add,
            assign_add_wrap,
            assign_mul,
            assign_mul_wrap,
            bang_equal,
            bit_and,
            bit_or,
            bit_shift_left,
            bit_shift_right,
            bit_xor,
            bool_and,
            bool_or,
            Catch: ?*Node,
            div,
            equal_equal,
            error_union,
            greater_or_equal,
            greater_than,
            less_or_equal,
            less_than,
            merge_error_sets,
            mod,
            mul,
            mul_wrap,
            period,
            range,
            sub,
            sub_wrap,
            unwrap_optional,
        };

        pub fn iterate(self: *const InfixOp, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                .Catch => |maybe_payload| {
                    if (maybe_payload) |payload| {
                        if (i < 1) return payload;
                        i -= 1;
                    }
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
                .error_union,
                .greater_or_equal,
                .greater_than,
                .less_or_equal,
                .less_than,
                .merge_error_sets,
                .mod,
                .mul,
                .mul_wrap,
                .period,
                .range,
                .sub,
                .sub_wrap,
                .unwrap_optional,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const InfixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const InfixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const PrefixOp = struct {
        base: Node = Node{ .id = .prefix_op },
        op_token: TokenIndex,
        op: Op,
        rhs: *Node,

        pub const Op = union(enum) {
            address_of,
            array_type: ArrayInfo,
            Await,
            bit_not,
            bool_not,
            optional_type,
            negation,
            negation_wrap,
            Resume,
            ptr_type: PtrInfo,
            slice_type: PtrInfo,
            Try,
        };

        pub const ArrayInfo = struct {
            len_expr: *Node,
            sentinel: ?*Node,
        };

        pub const PtrInfo = struct {
            allowzero_token: ?TokenIndex = null,
            align_info: ?Align = null,
            const_token: ?TokenIndex = null,
            volatile_token: ?TokenIndex = null,
            sentinel: ?*Node = null,

            pub const Align = struct {
                node: *Node,
                bit_range: ?BitRange,

                pub const BitRange = struct {
                    start: *Node,
                    end: *Node,
                };
            };
        };

        pub fn iterate(self: *const PrefixOp, index: usize) ?*Node {
            var i = index;

            switch (self.op) {
                .ptr_type, .slice_type => |addr_of_info| {
                    if (addr_of_info.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }

                    if (addr_of_info.align_info) |align_info| {
                        if (i < 1) return align_info.node;
                        i -= 1;
                    }
                },

                .array_type => |array_info| {
                    if (i < 1) return array_info.len_expr;
                    i -= 1;
                    if (array_info.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }
                },

                .address_of,
                .Await,
                .bit_not,
                .bool_not,
                .optional_type,
                .negation,
                .negation_wrap,
                .Try,
                .Resume,
                => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const PrefixOp) TokenIndex {
            return self.op_token;
        }

        pub fn lastToken(self: *const PrefixOp) TokenIndex {
            return self.rhs.lastToken();
        }
    };

    pub const FieldInitializer = struct {
        base: Node = Node{ .id = .field_initializer },
        period_token: TokenIndex,
        name_token: TokenIndex,
        expr: *Node,

        pub fn iterate(self: *const FieldInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const FieldInitializer) TokenIndex {
            return self.period_token;
        }

        pub fn lastToken(self: *const FieldInitializer) TokenIndex {
            return self.expr.lastToken();
        }
    };

    /// Elements occur directly in memory after ArrayInitializer.
    pub const ArrayInitializer = struct {
        base: Node = Node{ .id = .array_initializer },
        rtoken: TokenIndex,
        list_len: NodeIndex,
        lhs: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*ArrayInitializer {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ArrayInitializer), sizeInBytes(list_len));
            return @ptrCast(*ArrayInitializer, bytes.ptr);
        }

        pub fn free(self: *ArrayInitializer, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ArrayInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const ArrayInitializer) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *ArrayInitializer) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ArrayInitializer);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const ArrayInitializer) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ArrayInitializer);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(ArrayInitializer) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after ArrayInitializerDot.
    pub const ArrayInitializerDot = struct {
        base: Node = Node{ .id = .array_initializer_dot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*ArrayInitializerDot {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(ArrayInitializerDot), sizeInBytes(list_len));
            return @ptrCast(*ArrayInitializerDot, bytes.ptr);
        }

        pub fn free(self: *ArrayInitializerDot, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const ArrayInitializerDot, index: usize) ?*Node {
            var i = index;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const ArrayInitializerDot) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *ArrayInitializerDot) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(ArrayInitializerDot);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const ArrayInitializerDot) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(ArrayInitializerDot);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(ArrayInitializerDot) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after StructInitializer.
    pub const StructInitializer = struct {
        base: Node = Node{ .id = .struct_initializer },
        rtoken: TokenIndex,
        list_len: NodeIndex,
        lhs: *Node,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*StructInitializer {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(StructInitializer), sizeInBytes(list_len));
            return @ptrCast(*StructInitializer, bytes.ptr);
        }

        pub fn free(self: *StructInitializer, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const StructInitializer, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializer) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const StructInitializer) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *StructInitializer) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(StructInitializer);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const StructInitializer) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(StructInitializer);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(StructInitializer) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Elements occur directly in memory after StructInitializerDot.
    pub const StructInitializerDot = struct {
        base: Node = Node{ .id = .struct_initializer_dot },
        dot: TokenIndex,
        rtoken: TokenIndex,
        list_len: NodeIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, list_len: NodeIndex) !*StructInitializerDot {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(StructInitializerDot), sizeInBytes(list_len));
            return @ptrCast(*StructInitializerDot, bytes.ptr);
        }

        pub fn free(self: *StructInitializerDot, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.list_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const StructInitializerDot, index: usize) ?*Node {
            var i = index;

            if (i < self.list_len) return self.listConst()[i];
            i -= self.list_len;

            return null;
        }

        pub fn firstToken(self: *const StructInitializerDot) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const StructInitializerDot) TokenIndex {
            return self.rtoken;
        }

        pub fn list(self: *StructInitializerDot) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(StructInitializerDot);
            return @ptrCast([*]*Node, decls_start)[0..self.list_len];
        }

        pub fn listConst(self: *const StructInitializerDot) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(StructInitializerDot);
            return @ptrCast([*]const *Node, decls_start)[0..self.list_len];
        }

        fn sizeInBytes(list_len: NodeIndex) usize {
            return @sizeOf(StructInitializerDot) + @sizeOf(*Node) * @as(usize, list_len);
        }
    };

    /// Parameter nodes directly follow Call in memory.
    pub const Call = struct {
        base: Node = Node{ .id = .call },
        lhs: *Node,
        rtoken: TokenIndex,
        params_len: NodeIndex,
        async_token: ?TokenIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*Call {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(Call), sizeInBytes(params_len));
            return @ptrCast(*Call, bytes.ptr);
        }

        pub fn free(self: *Call, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const Call, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            if (i < self.params_len) return self.paramsConst()[i];
            i -= self.params_len;

            return null;
        }

        pub fn firstToken(self: *const Call) TokenIndex {
            if (self.async_token) |async_token| return async_token;
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const Call) TokenIndex {
            return self.rtoken;
        }

        pub fn params(self: *Call) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(Call);
            return @ptrCast([*]*Node, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const Call) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(Call);
            return @ptrCast([*]const *Node, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(Call) + @sizeOf(*Node) * @as(usize, params_len);
        }
    };

    pub const SuffixOp = struct {
        base: Node = Node{ .id = .suffix_op },
        op: Op,
        lhs: *Node,
        rtoken: TokenIndex,

        pub const Op = union(enum) {
            array_access: *Node,
            slice: Slice,
            deref,
            unwrap_optional,

            pub const Slice = struct {
                start: *Node,
                end: ?*Node,
                sentinel: ?*Node,
            };
        };

        pub fn iterate(self: *const SuffixOp, index: usize) ?*Node {
            var i = index;

            if (i == 0) return self.lhs;
            i -= 1;

            switch (self.op) {
                .array_access => |index_expr| {
                    if (i < 1) return index_expr;
                    i -= 1;
                },
                .slice => |range| {
                    if (i < 1) return range.start;
                    i -= 1;

                    if (range.end) |end| {
                        if (i < 1) return end;
                        i -= 1;
                    }
                    if (range.sentinel) |sentinel| {
                        if (i < 1) return sentinel;
                        i -= 1;
                    }
                },
                .unwrap_optional,
                .deref,
                => {},
            }

            return null;
        }

        pub fn firstToken(self: *const SuffixOp) TokenIndex {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: *const SuffixOp) TokenIndex {
            return self.rtoken;
        }
    };

    pub const GroupedExpression = struct {
        base: Node = Node{ .id = .grouped_expression },
        lparen: TokenIndex,
        expr: *Node,
        rparen: TokenIndex,

        pub fn iterate(self: *const GroupedExpression, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const GroupedExpression) TokenIndex {
            return self.lparen;
        }

        pub fn lastToken(self: *const GroupedExpression) TokenIndex {
            return self.rparen;
        }
    };

    pub const ControlFlowExpression = struct {
        base: Node = Node{ .id = .control_flow_expression },
        ltoken: TokenIndex,
        kind: Kind,
        rhs: ?*Node,

        pub const Kind = union(enum) {
            Break: ?*Node,
            Continue: ?*Node,
            Return,
        };

        pub fn iterate(self: *const ControlFlowExpression, index: usize) ?*Node {
            var i = index;

            switch (self.kind) {
                .Break, .Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                .Return => {},
            }

            if (self.rhs) |rhs| {
                if (i < 1) return rhs;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const ControlFlowExpression) TokenIndex {
            return self.ltoken;
        }

        pub fn lastToken(self: *const ControlFlowExpression) TokenIndex {
            if (self.rhs) |rhs| {
                return rhs.lastToken();
            }

            switch (self.kind) {
                .Break, .Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                .Return => return self.ltoken,
            }

            return self.ltoken;
        }
    };

    pub const Suspend = struct {
        base: Node = Node{ .id = .Suspend },
        suspend_token: TokenIndex,
        body: ?*Node,

        pub fn iterate(self: *const Suspend, index: usize) ?*Node {
            var i = index;

            if (self.body) |body| {
                if (i < 1) return body;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: *const Suspend) TokenIndex {
            return self.suspend_token;
        }

        pub fn lastToken(self: *const Suspend) TokenIndex {
            if (self.body) |body| {
                return body.lastToken();
            }

            return self.suspend_token;
        }
    };

    pub const IntegerLiteral = struct {
        base: Node = Node{ .id = .integer_literal },
        token: TokenIndex,

        pub fn iterate(self: *const IntegerLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const IntegerLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const IntegerLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const EnumLiteral = struct {
        base: Node = Node{ .id = .enum_literal },
        dot: TokenIndex,
        name: TokenIndex,

        pub fn iterate(self: *const EnumLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const EnumLiteral) TokenIndex {
            return self.dot;
        }

        pub fn lastToken(self: *const EnumLiteral) TokenIndex {
            return self.name;
        }
    };

    pub const FloatLiteral = struct {
        base: Node = Node{ .id = .float_literal },
        token: TokenIndex,

        pub fn iterate(self: *const FloatLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const FloatLiteral) TokenIndex {
            return self.token;
        }
    };

    /// Parameters are in memory following BuiltinCall.
    pub const BuiltinCall = struct {
        base: Node = Node{ .id = .builtin_call },
        params_len: NodeIndex,
        builtin_token: TokenIndex,
        rparen_token: TokenIndex,

        /// After this the caller must initialize the fields_and_decls list.
        pub fn alloc(allocator: *mem.Allocator, params_len: NodeIndex) !*BuiltinCall {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(BuiltinCall), sizeInBytes(params_len));
            return @ptrCast(*BuiltinCall, bytes.ptr);
        }

        pub fn free(self: *BuiltinCall, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.params_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const BuiltinCall, index: usize) ?*Node {
            var i = index;

            if (i < self.params_len) return self.paramsConst()[i];
            i -= self.params_len;

            return null;
        }

        pub fn firstToken(self: *const BuiltinCall) TokenIndex {
            return self.builtin_token;
        }

        pub fn lastToken(self: *const BuiltinCall) TokenIndex {
            return self.rparen_token;
        }

        pub fn params(self: *BuiltinCall) []*Node {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(BuiltinCall);
            return @ptrCast([*]*Node, decls_start)[0..self.params_len];
        }

        pub fn paramsConst(self: *const BuiltinCall) []const *Node {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(BuiltinCall);
            return @ptrCast([*]const *Node, decls_start)[0..self.params_len];
        }

        fn sizeInBytes(params_len: NodeIndex) usize {
            return @sizeOf(BuiltinCall) + @sizeOf(*Node) * @as(usize, params_len);
        }
    };

    pub const StringLiteral = struct {
        base: Node = Node{ .id = .string_literal },
        token: TokenIndex,

        pub fn iterate(self: *const StringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const StringLiteral) TokenIndex {
            return self.token;
        }
    };

    /// The string literal tokens appear directly in memory after MultilineStringLiteral.
    pub const MultilineStringLiteral = struct {
        base: Node = Node{ .id = .multiline_string_literal },
        lines_len: TokenIndex,

        /// After this the caller must initialize the lines list.
        pub fn alloc(allocator: *mem.Allocator, lines_len: NodeIndex) !*MultilineStringLiteral {
            const bytes = try allocator.alignedAlloc(u8, @alignOf(MultilineStringLiteral), sizeInBytes(lines_len));
            return @ptrCast(*MultilineStringLiteral, bytes.ptr);
        }

        pub fn free(self: *MultilineStringLiteral, allocator: *mem.Allocator) void {
            const bytes = @ptrCast([*]u8, self)[0..sizeInBytes(self.lines_len)];
            allocator.free(bytes);
        }

        pub fn iterate(self: *const MultilineStringLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const MultilineStringLiteral) TokenIndex {
            return self.linesConst()[0];
        }

        pub fn lastToken(self: *const MultilineStringLiteral) TokenIndex {
            return self.linesConst()[self.lines_len - 1];
        }

        pub fn lines(self: *MultilineStringLiteral) []TokenIndex {
            const decls_start = @ptrCast([*]u8, self) + @sizeOf(MultilineStringLiteral);
            return @ptrCast([*]TokenIndex, decls_start)[0..self.lines_len];
        }

        pub fn linesConst(self: *const MultilineStringLiteral) []const TokenIndex {
            const decls_start = @ptrCast([*]const u8, self) + @sizeOf(MultilineStringLiteral);
            return @ptrCast([*]const TokenIndex, decls_start)[0..self.lines_len];
        }

        fn sizeInBytes(lines_len: NodeIndex) usize {
            return @sizeOf(MultilineStringLiteral) + @sizeOf(TokenIndex) * @as(usize, lines_len);
        }
    };

    pub const CharLiteral = struct {
        base: Node = Node{ .id = .char_literal },
        token: TokenIndex,

        pub fn iterate(self: *const CharLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const CharLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const CharLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const BoolLiteral = struct {
        base: Node = Node{ .id = .bool_literal },
        token: TokenIndex,

        pub fn iterate(self: *const BoolLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const BoolLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const BoolLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const NullLiteral = struct {
        base: Node = Node{ .id = .null_literal },
        token: TokenIndex,

        pub fn iterate(self: *const NullLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const NullLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const NullLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const UndefinedLiteral = struct {
        base: Node = Node{ .id = .undefined_literal },
        token: TokenIndex,

        pub fn iterate(self: *const UndefinedLiteral, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const UndefinedLiteral) TokenIndex {
            return self.token;
        }
    };

    pub const Asm = struct {
        base: Node = Node{ .id = .Asm },
        asm_token: TokenIndex,
        rparen: TokenIndex,
        volatile_token: ?TokenIndex,
        template: *Node,
        outputs: []Output,
        inputs: []Input,
        /// A clobber node must be a StringLiteral or MultilineStringLiteral.
        clobbers: []*Node,

        pub const Output = struct {
            lbracket: TokenIndex,
            symbolic_name: *Node,
            constraint: *Node,
            kind: Kind,
            rparen: TokenIndex,

            pub const Kind = union(enum) {
                Variable: *Identifier,
                Return: *Node,
            };

            pub fn iterate(self: *const Output, index: usize) ?*Node {
                var i = index;

                if (i < 1) return self.symbolic_name;
                i -= 1;

                if (i < 1) return self.constraint;
                i -= 1;

                switch (self.kind) {
                    .Variable => |variable_name| {
                        if (i < 1) return &variable_name.base;
                        i -= 1;
                    },
                    .Return => |return_type| {
                        if (i < 1) return return_type;
                        i -= 1;
                    },
                }

                return null;
            }

            pub fn firstToken(self: *const Output) TokenIndex {
                return self.lbracket;
            }

            pub fn lastToken(self: *const Output) TokenIndex {
                return self.rparen;
            }
        };

        pub const Input = struct {
            lbracket: TokenIndex,
            symbolic_name: *Node,
            constraint: *Node,
            expr: *Node,
            rparen: TokenIndex,

            pub fn iterate(self: *const Input, index: usize) ?*Node {
                var i = index;

                if (i < 1) return self.symbolic_name;
                i -= 1;

                if (i < 1) return self.constraint;
                i -= 1;

                if (i < 1) return self.expr;
                i -= 1;

                return null;
            }

            pub fn firstToken(self: *const Input) TokenIndex {
                return self.lbracket;
            }

            pub fn lastToken(self: *const Input) TokenIndex {
                return self.rparen;
            }
        };

        pub fn iterate(self: *const Asm, index: usize) ?*Node {
            var i = index;

            if (i < self.outputs.len * 3) switch (i % 3) {
                0 => return self.outputs[i / 3].symbolic_name,
                1 => return self.outputs[i / 3].constraint,
                2 => switch (self.outputs[i / 3].kind) {
                    .Variable => |variable_name| return &variable_name.base,
                    .Return => |return_type| return return_type,
                },
                else => unreachable,
            };
            i -= self.outputs.len * 3;

            if (i < self.inputs.len * 3) switch (i % 3) {
                0 => return self.inputs[i / 3].symbolic_name,
                1 => return self.inputs[i / 3].constraint,
                2 => return self.inputs[i / 3].expr,
                else => unreachable,
            };
            i -= self.inputs.len * 3;

            return null;
        }

        pub fn firstToken(self: *const Asm) TokenIndex {
            return self.asm_token;
        }

        pub fn lastToken(self: *const Asm) TokenIndex {
            return self.rparen;
        }
    };

    pub const Unreachable = struct {
        base: Node = Node{ .id = .Unreachable },
        token: TokenIndex,

        pub fn iterate(self: *const Unreachable, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const Unreachable) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const Unreachable) TokenIndex {
            return self.token;
        }
    };

    pub const ErrorType = struct {
        base: Node = Node{ .id = .error_type },
        token: TokenIndex,

        pub fn iterate(self: *const ErrorType, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const ErrorType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const ErrorType) TokenIndex {
            return self.token;
        }
    };

    pub const VarType = struct {
        base: Node = Node{ .id = .var_type },
        token: TokenIndex,

        pub fn iterate(self: *const VarType, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const VarType) TokenIndex {
            return self.token;
        }

        pub fn lastToken(self: *const VarType) TokenIndex {
            return self.token;
        }
    };

    pub const DocComment = struct {
        base: Node = Node{ .id = .doc_comment },
        /// Points to the first doc comment token. API users are expected to iterate over the
        /// tokens array, looking for more doc comments, ignoring line comments, and stopping
        /// at the first other token.
        first_line: TokenIndex,

        pub fn iterate(self: *const DocComment, index: usize) ?*Node {
            return null;
        }

        pub fn firstToken(self: *const DocComment) TokenIndex {
            return self.first_line;
        }

        /// Returns the first doc comment line. Be careful, this may not be the desired behavior,
        /// which would require the tokens array.
        pub fn lastToken(self: *const DocComment) TokenIndex {
            return self.first_line;
        }
    };

    pub const TestDecl = struct {
        base: Node = Node{ .id = .test_decl },
        doc_comments: ?*DocComment,
        test_token: TokenIndex,
        name: *Node,
        body_node: *Node,

        pub fn iterate(self: *const TestDecl, index: usize) ?*Node {
            var i = index;

            if (i < 1) return self.body_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: *const TestDecl) TokenIndex {
            return self.test_token;
        }

        pub fn lastToken(self: *const TestDecl) TokenIndex {
            return self.body_node.lastToken();
        }
    };
};

test "iterate" {
    var root = Node.Root{
        .base = Node{ .id = Node.Id.root },
        .decls_len = 0,
        .eof_token = 0,
    };
    var base = &root.base;
    testing.expect(base.iterate(0) == null);
}
