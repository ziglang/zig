// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const ArrayList = std.ArrayList;
const Token = std.c.Token;
const Source = std.c.tokenizer.Source;

pub const TokenIndex = usize;

pub const Tree = struct {
    tokens: []Token,
    sources: []Source,
    root_node: *Node.Root,
    arena_state: std.heap.ArenaAllocator.State,
    gpa: *mem.Allocator,
    msgs: []Msg,

    pub fn deinit(self: *Tree) void {
        self.arena_state.promote(self.gpa).deinit();
    }

    pub fn tokenSlice(tree: *Tree, token: TokenIndex) []const u8 {
        return tree.tokens.at(token).slice();
    }

    pub fn tokenEql(tree: *Tree, a: TokenIndex, b: TokenIndex) bool {
        const atok = tree.tokens.at(a);
        const btok = tree.tokens.at(b);
        return atok.eql(btok.*);
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
    ExpectedTypeName: SingleTokenError("expected type name, found '{}'"),
    ExpectedFnBody: SingleTokenError("expected function body, found '{}'"),
    ExpectedDeclarator: SingleTokenError("expected declarator, found '{}'"),
    ExpectedInitializer: SingleTokenError("expected initializer, found '{}'"),
    ExpectedEnumField: SingleTokenError("expected enum field, found '{}'"),
    ExpectedType: SingleTokenError("expected enum field, found '{}'"),
    InvalidTypeSpecifier: InvalidTypeSpecifier,
    InvalidStorageClass: SingleTokenError("invalid storage class, found '{}'"),
    InvalidDeclarator: SimpleError("invalid declarator"),
    DuplicateQualifier: SingleTokenError("duplicate type qualifier '{}'"),
    DuplicateSpecifier: SingleTokenError("duplicate declaration specifier '{}'"),
    MustUseKwToRefer: MustUseKwToRefer,
    FnSpecOnNonFn: SingleTokenError("function specifier '{}' on non function"),
    NothingDeclared: SimpleError("declaration doesn't declare anything"),
    QualifierIgnored: SingleTokenError("qualifier '{}' ignored"),

    pub fn render(self: *const Error, tree: *Tree, stream: anytype) !void {
        switch (self.*) {
            .InvalidToken => |*x| return x.render(tree, stream),
            .ExpectedToken => |*x| return x.render(tree, stream),
            .ExpectedExpr => |*x| return x.render(tree, stream),
            .ExpectedTypeName => |*x| return x.render(tree, stream),
            .ExpectedDeclarator => |*x| return x.render(tree, stream),
            .ExpectedFnBody => |*x| return x.render(tree, stream),
            .ExpectedInitializer => |*x| return x.render(tree, stream),
            .ExpectedEnumField => |*x| return x.render(tree, stream),
            .ExpectedType => |*x| return x.render(tree, stream),
            .InvalidTypeSpecifier => |*x| return x.render(tree, stream),
            .InvalidStorageClass => |*x| return x.render(tree, stream),
            .InvalidDeclarator => |*x| return x.render(tree, stream),
            .DuplicateQualifier => |*x| return x.render(tree, stream),
            .DuplicateSpecifier => |*x| return x.render(tree, stream),
            .MustUseKwToRefer => |*x| return x.render(tree, stream),
            .FnSpecOnNonFn => |*x| return x.render(tree, stream),
            .NothingDeclared => |*x| return x.render(tree, stream),
            .QualifierIgnored => |*x| return x.render(tree, stream),
        }
    }

    pub fn loc(self: *const Error) TokenIndex {
        switch (self.*) {
            .InvalidToken => |x| return x.token,
            .ExpectedToken => |x| return x.token,
            .ExpectedExpr => |x| return x.token,
            .ExpectedTypeName => |x| return x.token,
            .ExpectedDeclarator => |x| return x.token,
            .ExpectedFnBody => |x| return x.token,
            .ExpectedInitializer => |x| return x.token,
            .ExpectedEnumField => |x| return x.token,
            .ExpectedType => |*x| return x.token,
            .InvalidTypeSpecifier => |x| return x.token,
            .InvalidStorageClass => |x| return x.token,
            .InvalidDeclarator => |x| return x.token,
            .DuplicateQualifier => |x| return x.token,
            .DuplicateSpecifier => |x| return x.token,
            .MustUseKwToRefer => |*x| return x.name,
            .FnSpecOnNonFn => |*x| return x.name,
            .NothingDeclared => |*x| return x.name,
            .QualifierIgnored => |*x| return x.name,
        }
    }

    pub const ExpectedToken = struct {
        token: TokenIndex,
        expected_id: std.meta.Tag(Token.Id),

        pub fn render(self: *const ExpectedToken, tree: *Tree, stream: anytype) !void {
            const found_token = tree.tokens.at(self.token);
            if (found_token.id == .Invalid) {
                return stream.print("expected '{s}', found invalid bytes", .{self.expected_id.symbol()});
            } else {
                const token_name = found_token.id.symbol();
                return stream.print("expected '{s}', found '{s}'", .{ self.expected_id.symbol(), token_name });
            }
        }
    };

    pub const InvalidTypeSpecifier = struct {
        token: TokenIndex,
        type_spec: *Node.TypeSpec,

        pub fn render(self: *const ExpectedToken, tree: *Tree, stream: anytype) !void {
            try stream.write("invalid type specifier '");
            try type_spec.spec.print(tree, stream);
            const token_name = tree.tokens.at(self.token).id.symbol();
            return stream.print("{s}'", .{token_name});
        }
    };

    pub const MustUseKwToRefer = struct {
        kw: TokenIndex,
        name: TokenIndex,

        pub fn render(self: *const ExpectedToken, tree: *Tree, stream: anytype) !void {
            return stream.print("must use '{s}' tag to refer to type '{s}'", .{ tree.slice(kw), tree.slice(name) });
        }
    };

    fn SingleTokenError(comptime msg: []const u8) type {
        return struct {
            token: TokenIndex,

            pub fn render(self: *const @This(), tree: *Tree, stream: anytype) !void {
                const actual_token = tree.tokens.at(self.token);
                return stream.print(msg, .{actual_token.id.symbol()});
            }
        };
    }

    fn SimpleError(comptime msg: []const u8) type {
        return struct {
            const ThisError = @This();

            token: TokenIndex,

            pub fn render(self: *const ThisError, tokens: *Tree.TokenList, stream: anytype) !void {
                return stream.write(msg);
            }
        };
    }
};

pub const Type = struct {
    pub const TypeList = ArrayList(*Type);

    @"const": bool = false,
    atomic: bool = false,
    @"volatile": bool = false,
    restrict: bool = false,

    id: union(enum) {
        Int: struct {
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
            id: Id,

            pub const Id = enum {
                Float,
                Double,
                LongDouble,
            };
        },
        Pointer: *Type,
        Function: struct {
            return_type: *Type,
            param_types: TypeList,
        },
        Typedef: *Type,
        Record: *Node.RecordType,
        Enum: *Node.EnumType,

        /// Special case for macro parameters that can be any type.
        /// Only present if `retain_macros == true`.
        Macro,
    },
};

pub const Node = struct {
    id: Id,

    pub const Id = enum {
        Root,
        EnumField,
        RecordField,
        RecordDeclarator,
        JumpStmt,
        ExprStmt,
        LabeledStmt,
        CompoundStmt,
        IfStmt,
        SwitchStmt,
        WhileStmt,
        DoStmt,
        ForStmt,
        StaticAssert,
        Declarator,
        Pointer,
        FnDecl,
        Typedef,
        VarDecl,
    };

    pub const Root = struct {
        base: Node = Node{ .id = .Root },
        decls: DeclList,
        eof: TokenIndex,

        pub const DeclList = ArrayList(*Node);
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

            pub fn print(self: *@This(), self: *const @This(), tree: *Tree, stream: anytype) !void {
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
        base: Node = Node{ .id = .EnumField },
        name: TokenIndex,
        value: ?*Node,
    };

    pub const RecordType = struct {
        tok: TokenIndex,
        kind: enum {
            Struct,
            Union,
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
        base: Node = Node{ .id = .RecordField },
        type_spec: TypeSpec,
        declarators: DeclaratorList,
        semicolon: TokenIndex,

        pub const DeclaratorList = Root.DeclList;
    };

    pub const RecordDeclarator = struct {
        base: Node = Node{ .id = .RecordDeclarator },
        declarator: ?*Declarator,
        bit_field_expr: ?*Expr,
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
        kind: union(enum) {
            Break,
            Continue,
            Return: ?*Node,
            Goto: TokenIndex,
        },
        semicolon: TokenIndex,
    };

    pub const ExprStmt = struct {
        base: Node = Node{ .id = .ExprStmt },
        expr: ?*Expr,
        semicolon: TokenIndex,
    };

    pub const LabeledStmt = struct {
        base: Node = Node{ .id = .LabeledStmt },
        kind: union(enum) {
            Label: TokenIndex,
            Case: TokenIndex,
            Default: TokenIndex,
        },
        stmt: *Node,
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
        body: *Node,
        @"else": ?struct {
            tok: TokenIndex,
            body: *Node,
        },
    };

    pub const SwitchStmt = struct {
        base: Node = Node{ .id = .SwitchStmt },
        @"switch": TokenIndex,
        expr: *Expr,
        rparen: TokenIndex,
        stmt: *Node,
    };

    pub const WhileStmt = struct {
        base: Node = Node{ .id = .WhileStmt },
        @"while": TokenIndex,
        cond: *Expr,
        rparen: TokenIndex,
        body: *Node,
    };

    pub const DoStmt = struct {
        base: Node = Node{ .id = .DoStmt },
        do: TokenIndex,
        body: *Node,
        @"while": TokenIndex,
        cond: *Expr,
        semicolon: TokenIndex,
    };

    pub const ForStmt = struct {
        base: Node = Node{ .id = .ForStmt },
        @"for": TokenIndex,
        init: ?*Node,
        cond: ?*Expr,
        semicolon: TokenIndex,
        incr: ?*Expr,
        rparen: TokenIndex,
        body: *Node,
    };

    pub const StaticAssert = struct {
        base: Node = Node{ .id = .StaticAssert },
        assert: TokenIndex,
        expr: *Node,
        semicolon: TokenIndex,
    };

    pub const Declarator = struct {
        base: Node = Node{ .id = .Declarator },
        pointer: ?*Pointer,
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

        pub const Arrays = ArrayList(*Array);
        pub const Params = ArrayList(*Param);
    };

    pub const Array = struct {
        lbracket: TokenIndex,
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

    pub const FnDecl = struct {
        base: Node = Node{ .id = .FnDecl },
        decl_spec: DeclSpec,
        declarator: *Declarator,
        old_decls: OldDeclList,
        body: ?*CompoundStmt,

        pub const OldDeclList = ArrayList(*Node);
    };

    pub const Typedef = struct {
        base: Node = Node{ .id = .Typedef },
        decl_spec: DeclSpec,
        declarators: DeclaratorList,
        semicolon: TokenIndex,

        pub const DeclaratorList = Root.DeclList;
    };

    pub const VarDecl = struct {
        base: Node = Node{ .id = .VarDecl },
        decl_spec: DeclSpec,
        initializers: Initializers,
        semicolon: TokenIndex,

        pub const Initializers = Root.DeclList;
    };

    pub const Initialized = struct {
        base: Node = Node{ .id = Initialized },
        declarator: *Declarator,
        eq: TokenIndex,
        init: Initializer,
    };

    pub const Initializer = union(enum) {
        list: struct {
            initializers: List,
            rbrace: TokenIndex,
        },
        expr: *Expr,

        pub const List = ArrayList(*Initializer);
    };

    pub const Macro = struct {
        base: Node = Node{ .id = Macro },
        kind: union(enum) {
            Undef: []const u8,
            Fn: struct {
                params: []const []const u8,
                expr: *Expr,
            },
            Expr: *Expr,
        },
    };
};

pub const Expr = struct {
    id: Id,
    ty: *Type,
    value: union(enum) {
        None,
    },

    pub const Id = enum {
        Infix,
        Literal,
    };

    pub const Infix = struct {
        base: Expr = Expr{ .id = .Infix },
        lhs: *Expr,
        op_token: TokenIndex,
        op: Op,
        rhs: *Expr,

        pub const Op = enum {};
    };
};
