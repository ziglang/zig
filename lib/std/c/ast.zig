const std = @import("std");
const SegmentedList = std.SegmentedList;
const Token = std.c.Token;
const Source = std.c.tokenizer.Source;

pub const TokenIndex = usize;

pub const Tree = struct {
    tokens: TokenList,
    sources: SourceList,
    root_node: *Node.Root,
    arena_allocator: std.heap.ArenaAllocator,
    msgs: MsgList,

    pub const SourceList = SegmentedList(Source, 4);
    pub const TokenList = Source.TokenList;
    pub const MsgList = SegmentedList(Msg, 0);

    pub fn deinit(self: *Tree) void {
        // Here we copy the arena allocator into stack memory, because
        // otherwise it would destroy itself while it was still working.
        var arena_allocator = self.arena_allocator;
        arena_allocator.deinit();
        // self is destroyed
    }

    pub fn slice(tree: *Tree, token: TokenIndex) []const u8 {
        const tok = tree.tokens.at(token);
        return tok.source.buffer[tok.start..tok.end];
    }
};

pub const Msg = struct {
    kind: enum {
        Error,
        Warning,
        Note,
    },
    inner: Error,
};

pub const Error = union(enum) {
    InvalidToken: SingleTokenError("invalid token '{}'"),
    ExpectedToken: ExpectedToken,
    ExpectedExpr: SingleTokenError("expected expression, found '{}'"),
    ExpectedStmt: SingleTokenError("expected statement, found '{}'"),
    ExpectedTypeName: SingleTokenError("expected type name, found '{}'"),
    ExpectedFnBody: SingleTokenError("expected function body, found '{}'"),
    ExpectedDeclarator: SingleTokenError("expected declarator, found '{}'"),
    ExpectedInitializer: SingleTokenError("expected initializer, found '{}'"),
    InvalidTypeSpecifier: InvalidTypeSpecifier,
    DuplicateQualifier: SingleTokenError("duplicate type qualifier '{}'"),
    DuplicateSpecifier: SingleTokenError("duplicate declaration specifier '{}'"),

    pub fn render(self: *const Error, tree: *Tree, stream: var) !void {
        switch (self.*) {
            .InvalidToken => |*x| return x.render(tree, stream),
            .ExpectedToken => |*x| return x.render(tree, stream),
            .ExpectedExpr => |*x| return x.render(tree, stream),
            .ExpectedStmt => |*x| return x.render(tree, stream),
            .ExpectedTypeName => |*x| return x.render(tree, stream),
            .ExpectedDeclarator => |*x| return x.render(tree, stream),
            .ExpectedFnBody => |*x| return x.render(tree, stream),
            .ExpectedInitializer => |*x| return x.render(tree, stream),
            .InvalidTypeSpecifier => |*x| return x.render(tree, stream),
            .DuplicateQualifier => |*x| return x.render(tree, stream),
            .DuplicateSpecifier => |*x| return x.render(tree, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .InvalidToken => |x| return x.token,
            .ExpectedToken => |x| return x.token,
            .ExpectedExpr => |x| return x.token,
            .ExpectedStmt => |x| return x.token,
            .ExpectedTypeName => |x| return x.token,
            .ExpectedDeclarator => |x| return x.token,
            .ExpectedFnBody => |x| return x.token,
            .ExpectedInitializer => |x| return x.token,
            .InvalidTypeSpecifier => |x| return x.token,
            .DuplicateQualifier => |x| return x.token,
            .DuplicateSpecifier => |x| return x.token,
        }
    }

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: @TagType(Token.Id),

        pub fn render(self: *const ExpectedToken, tree: *Tree, stream: var) !void {
            const found_token = tree.tokens.at(self.token);
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
        type_spec: *Node.TypeSpec,

        pub fn render(self: *const ExpectedToken, tree: *Tree, stream: var) !void {
            try stream.write("invalid type specifier '");
            try type_spec.spec.print(tree, stream);
            const token_name = tree.tokens.at(self.token).id.symbol();
            return stream.print("{}'", .{token_name});
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            token: TokenIndex,

            pub fn render(self: *const @This(), tree: *Tree, stream: var) !void {
                const actual_token = tree.tokens.at(self.token);
                return stream.print(msg, .{actual_token.id.symbol()});
            }
        };
    }
};

pub const Type = struct {
    pub const TypeList = std.SegmentedList(*Type, 4);
    @"const": bool,
    atomic: bool,
    @"volatile": bool,
    restrict: bool,

    id: union(enum) {
        Int: struct {
            quals: Qualifiers,
            id: Id,
            is_signed: bool,

            pub const Id = enum {
                Char,
                Short,
                Int,
                Long,
                LongLong,
            };
        },
        Float: struct {
            quals: Qualifiers,
            id: Id,

            pub const Id = enum {
                Float,
                Double,
                LongDouble,
            };
        },
        Pointer: struct {
            quals: Qualifiers,
            child_type: *Type,
        },
        Function: struct {
            return_type: *Type,
            param_types: TypeList,
        },
        Typedef: *Type,
        Record: *Node.RecordType,
        Enum: *Node.EnumType,
    },
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
        StaticAssert,
        Fn,
        Typedef,
        Var,
    };

    pub const Root = struct {
        base: Node = Node{ .id = .Root },
        decls: DeclList,
        eof: TokenIndex,

        pub const DeclList = SegmentedList(*Node, 4);
    };

    pub const DeclSpec = struct {
        storage_class: union(enum) {
            Auto: TokenIndex,
            Extern: TokenIndex,
            Register: TokenIndex,
            Static: TokenIndex,
            Typedef: TokenIndex,
            None,
        } = .None,
        thread_local: ?TokenIndex = null,
        type_spec: TypeSpec = TypeSpec{},
        fn_spec: union(enum) {
            Inline: TokenIndex,
            Noreturn: TokenIndex,
            None,
        } = .None,
        align_spec: ?struct {
            alignas: TokenIndex,
            expr: *Node,
            rparen: TokenIndex,
        } = null,
    };

    pub const TypeSpec = struct {
        qual: TypeQual = TypeQual{},
        spec: union(enum) {
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
            Enum: *EnumType,
            Record: *RecordType,
            Typedef: struct {
                sym: TokenIndex,
                sym_type: *Type,
            },

            pub fn print(self: *@This(), self: *const @This(), tree: *Tree, stream: var) !void {
                switch (self.spec) {
                    .None => unreachable,
                    .Void => |index| try stream.write(tree.slice(index)),
                    .Char => |char| {
                        if (char.sign) |s| {
                            try stream.write(tree.slice(s));
                            try stream.writeByte(' ');
                        }
                        try stream.write(tree.slice(char.char));
                    },
                    .Short => |short| {
                        if (short.sign) |s| {
                            try stream.write(tree.slice(s));
                            try stream.writeByte(' ');
                        }
                        try stream.write(tree.slice(short.short));
                        if (short.int) |i| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(i));
                        }
                    },
                    .Int => |int| {
                        if (int.sign) |s| {
                            try stream.write(tree.slice(s));
                            try stream.writeByte(' ');
                        }
                        if (int.int) |i| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(i));
                        }
                    },
                    .Long => |long| {
                        if (long.sign) |s| {
                            try stream.write(tree.slice(s));
                            try stream.writeByte(' ');
                        }
                        try stream.write(tree.slice(long.long));
                        if (long.longlong) |l| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(l));
                        }
                        if (long.int) |i| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(i));
                        }
                    },
                    .Float => |float| {
                        try stream.write(tree.slice(float.float));
                        if (float.complex) |c| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(c));
                        }
                    },
                    .Double => |double| {
                        if (double.long) |l| {
                            try stream.write(tree.slice(l));
                            try stream.writeByte(' ');
                        }
                        try stream.write(tree.slice(double.double));
                        if (double.complex) |c| {
                            try stream.writeByte(' ');
                            try stream.write(tree.slice(c));
                        }
                    },
                    .Bool => |index| try stream.write(tree.slice(index)),
                    .Typedef => |typedef| try stream.write(tree.slice(typedef.sym)),
                    else => try stream.print("TODO print {}", self.spec),
                }
            }
        } = .None,
    };

    pub const EnumType = struct {
        tok: TokenIndex,
        name: ?TokenIndex,
        body: ?struct {
            lbrace: TokenIndex,

            /// always EnumField
            fields: FieldList,
            rbrace: TokenIndex,
        },

        pub const FieldList = Root.DeclList;
    };

    pub const EnumField = struct {
        base: Node = Node{ .id = EnumField },
        name: TokenIndex,
        value: ?*Node,
    };

    pub const RecordType = struct {
        kind: union(enum) {
            Struct: TokenIndex,
            Union: TokenIndex,
        },
        name: ?TokenIndex,
        body: ?struct {
            lbrace: TokenIndex,

            /// RecordField or StaticAssert
            fields: FieldList,
            rbrace: TokenIndex,
        },

        pub const FieldList = Root.DeclList;
    };

    pub const RecordField = struct {
        base: Node = Node{ .id = RecordField },
        // TODO
    };

    pub const TypeQual = struct {
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

    pub const StaticAssert = struct {
        base: Node = Node{ .id = .StaticAssert },
        assert: TokenIndex,
        expr: *Node,
        semicolon: TokenIndex,
    };

    pub const Declarator = struct {
        base: Node = Node{ .id = .Declarator },
        pointer: *Pointer,
        prefix: union(enum) {
            None,
            Identifer: TokenIndex,
            Complex: struct {
                lparen: TokenIndex,
                inner: *Node,
                rparen: TokenIndex,
            },
        },
        suffix: union(enum) {
            None,
            Fn: struct {
                lparen: TokenIndex,
                params: Params,
                rparen: TokenIndex,
            },
            Array: Arrays,
        },

        pub const Arrays = std.SegmentedList(*Array, 2);
        pub const Params = std.SegmentedList(*Param, 4);
    };

    pub const Array = struct {
        rbracket: TokenIndex,
        inner: union(enum) {
            Inferred,
            Unspecified: TokenIndex,
            Variable: struct {
                asterisk: ?TokenIndex,
                static: ?TokenIndex,
                qual: TypeQual,
                expr: *Expr,
            },
        },
        rbracket: TokenIndex,
    };

    pub const Pointer = struct {
        base: Node = Node{ .id = .Pointer },
        asterisk: TokenIndex,
        qual: TypeQual,
        pointer: ?*Pointer,
    };

    pub const Param = struct {
        kind: union(enum) {
            Variable,
            Old: TokenIndex,
            Normal: struct {
                decl_spec: *DeclSpec,
                declarator: *Node,
            },
        },
    };

    pub const Fn = struct {
        base: Node = Node{ .id = .Fn },
        decl_spec: DeclSpec,
        declarator: *Node,
        old_decls: OldDeclList,
        body: ?*CompoundStmt,

        pub const OldDeclList = SegmentedList(*Node, 0);
    };

    pub const Typedef = struct {
        base: Node = Node{ .id = .Typedef },
        decl_spec: DeclSpec,
        declarators: DeclaratorList,

        pub const DeclaratorList = Root.DeclList;
    };

    pub const Var = struct {
        base: Node = Node{ .id = .Var },
        decl_spec: DeclSpec,
        initializers: Initializers,

        pub const Initializers = std.SegmentedList(*Initialized, 2);
    };

    pub const Initialized = struct {
        declarator: *Node,
        eq: TokenIndex,
        init: Initializer,
    };

    pub const Initializer = union(enum) {
        list: struct {
            initializers: InitializerList,
            rbrace: TokenIndex,
        },
        expr: *Expr,
        pub const InitializerList = std.SegmentedList(*Initializer, 4);
    };
};
