const std = @import("std.zig");
const SegmentedList = std.SegmentedList;
const Token = std.c.Token;
const Source = std.c.tokenizer.Source;

pub const TokenIndex = usize;

pub const Tree = struct {
    tokens: TokenList,
    sources: SourceList,
    root_node: *Node.Root,
    arena_allocator: std.heap.ArenaAllocator,
    errors: ErrorList,

    pub const SourceList = SegmentedList(Source, 4);
    pub const TokenList = Source.TokenList;
    pub const ErrorList = SegmentedList(Error, 0);

    pub fn deinit(self: *Tree) void {
        // Here we copy the arena allocator into stack memory, because
        // otherwise it would destroy itself while it was still working.
        var arena_allocator = self.arena_allocator;
        arena_allocator.deinit();
        // self is destroyed
    }
};

pub const Error = union(enum) {
    InvalidToken: SingleTokenError("invalid token '{}'"),
    ExpectedToken: ExpectedToken,
    ExpectedExpr: SingleTokenError("expected expression, found '{}'"),
    ExpectedStmt: SingleTokenError("expected statement, found '{}'"),
    InvalidTypeSpecifier: InvalidTypeSpecifier,
    DuplicateQualifier: SingleTokenError("duplicate type qualifier '{}'"),

    pub fn render(self: *const Error, tokens: *Tree.TokenList, stream: var) !void {
        switch (self.*) {
            .InvalidToken => |*x| return x.render(tokens, stream),
            .ExpectedToken => |*x| return x.render(tokens, stream),
            .ExpectedExpr => |*x| return x.render(tokens, stream),
            .ExpectedStmt => |*x| return x.render(tokens, stream),
            .InvalidTypeSpecifier => |*x| return x.render(tokens, stream),
            .DuplicateQualifier => |*x| return x.render(tokens, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .InvalidToken => |x| return x.token,
            .ExpectedToken => |x| return x.token,
            .ExpectedExpr => |x| return x.token,
            .ExpectedStmt => |x| return x.token,
            .InvalidTypeSpecifier => |x| return x.token,
            .DuplicateQualifier => |x| return x.token,
        }
    }

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: @TagType(Token.Id),

        pub fn render(self: *const ExpectedToken, tokens: *Tree.TokenList, stream: var) !void {
            const found_token = tokens.at(self.token);
            if (found_token.id == .Invalid) {
                return stream.print("expected '{}', found invalid bytes", .{self.expected_id.symbol()});
            } else {
                const token_name = found_token.id.symbol();
                return stream.print("expected '{}', found '{}'", .{ self.expected_id.symbol(), token_name });
            }
        }
    };

    pub const InvalidTypeSpecifier = struct {
        token: TokenIndex,
        type: *Node.Type,

        pub fn render(self: *const ExpectedToken, tokens: *Tree.TokenList, stream: var) !void {
            try stream.write("invalid type specifier '");
            try type.specifier.print(tokens, stream);
            const token_name = tokens.at(self.token).id.symbol();
            return stream.print("{}'", .{ token_name });
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            token: TokenIndex,

            pub fn render(self: *const @This(), tokens: *Tree.TokenList, stream: var) !void {
                const actual_token = tokens.at(self.token);
                return stream.print(msg, .{actual_token.id.symbol()});
            }
        };
    }
};

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        Root,
        JumpStmt,
        ExprStmt,
        Label,
        CompoundStmt,
        IfStmt,
    };

    pub const Root = struct {
        base: Node,
        decls: DeclList,
        eof: TokenIndex,

        pub const DeclList = SegmentedList(*Node, 4);
    };

    pub const Type = struct {
        qualifiers: Qualifiers,
        specifier: union(enum) {
            /// error or default to int
            None,
            Void: TokenIndex,
            Char: struct {
                sign: ?TokenIndex = null,
                char: TokenIndex,
            },
            Short: struct {
                sign: ?TokenIndex = null,
                short: TokenIndex = null,
                int: ?TokenIndex = null,
            },
            Int: struct {
                sign: ?TokenIndex = null,
                int: ?TokenIndex = null,
            },
            Long: struct {
                sign: ?TokenIndex = null,
                long: TokenIndex,
                longlong: ?TokenIndex = null,
                int: ?TokenIndex = null,
            },
            Float: struct {
                float: TokenIndex,
                complex: ?TokenIndex = null,
            },
            Double: struct {
                long: ?TokenIndex = null,
                double: ?TokenIndex,
                complex: ?TokenIndex = null,
            },
            Bool: TokenIndex,
            Atomic: struct {
                atomic: TokenIndex,
                typename: *Node,
                rparen: TokenIndex,
            },

            //todo
            // @"enum",
            // record,

            Typedef: TokenIndex,

            pub fn print(self: *@This(), self: *const @This(), tokens: *Tree.TokenList, stream: var) !void {
                switch (self) {
                    .None => unreachable,
                    else => @panic("TODO print type specifier"),
                }
            }
        },
    };

    pub const Qualifiers = struct {
        @"const": ?TokenIndex = null,
        atomic: ?TokenIndex = null,
        @"volatile": ?TokenIndex = null,
        restrict: ?TokenIndex = null,
    };

    pub const JumpStmt = struct {
        base: Node = Node{ .id = .JumpStmt },
        ltoken: TokenIndex,
        kind: Kind,
        semicolon: TokenIndex,

        pub const Kind = union(enum) {
            Break,
            Continue,
            Return: ?*Node,
            Goto: TokenIndex,
        };
    };

    pub const ExprStmt = struct {
        base: Node = Node{ .id = .ExprStmt },
        expr: ?*Node,
        semicolon: TokenIndex,
    };

    pub const Label = struct {
        base: Node = Node{ .id = .Label },
        identifier: TokenIndex,
        colon: TokenIndex,
    };

    pub const CompoundStmt = struct {
        base: Node = Node{ .id = .CompoundStmt },
        lbrace: TokenIndex,
        statements: StmtList,
        rbrace: TokenIndex,

        pub const StmtList = Root.DeclList;
    };

    pub const IfStmt = struct {
        base: Node = Node{ .id = .IfStmt },
        @"if": TokenIndex,
        cond: *Node,
        @"else": ?struct {
            tok: TokenIndex,
            stmt: *Node,
        },
    };
};
