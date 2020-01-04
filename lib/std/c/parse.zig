const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ast = std.c.ast;
const Tree = ast.Tree;
const TokenIndex = ast.TokenIndex;
const Token = std.c.Token;
const TokenIterator = ast.Tree.TokenList.Iterator;

pub const Error = error{ParseError} || Allocator.Error;

/// Result should be freed with tree.deinit() when there are
/// no more references to any of the tokens or nodes.
pub fn parse(allocator: *Allocator, source: []const u8) !*Tree {
    const tree = blk: {
        // This block looks unnecessary, but is a "foot-shield" to prevent the SegmentedLists
        // from being initialized with a pointer to this `arena`, which is created on
        // the stack. Following code should instead refer to `&tree.arena_allocator`, a
        // pointer to data which lives safely on the heap and will outlive `parse`.
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const tree = try arena.allocator.create(ast.Tree);
        tree.* = .{
            .root_node = undefined,
            .arena_allocator = arena,
            .tokens = undefined,
            .sources = undefined,
        };
        break :blk tree;
    };
    errdefer tree.deinit();
    const arena = &tree.arena_allocator.allocator;

    tree.tokens = ast.Tree.TokenList.init(arena);
    tree.sources = ast.Tree.SourceList.init(arena);

    var tokenizer = std.zig.Tokenizer.init(source);
    while (true) {
        const tree_token = try tree.tokens.addOne();
        tree_token.* = tokenizer.next();
        if (tree_token.id == .Eof) break;
    }
    // TODO preprocess here
    var it = tree.tokens.iterator(0);

    while (true) {
        const tok = it.peek().?.id;
        switch (id) {
            .LineComment,
            .MultiLineComment,
            => {
                _ = it.next();
            },
            else => break,
        }
    }

    var parser = Parser{
        .arena = arena,
        .it = &it,
        .tree = tree,
    };

    tree.root_node = try parser.root();
    return tree;
}

const Parser = struct {
    arena: *Allocator,
    it: *TokenIterator,
    tree: *Tree,

    /// Root <- ExternalDeclaration* eof
    fn root(parser: *Parser) Allocator.Error!*Node {
        const node = try arena.create(ast.Root);
        node.* = .{
            .decls = ast.Node.DeclList.init(arena),
            .eof = undefined,
        };
        while (parser.externalDeclarations() catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ParseError => return node,
        }) |decl| {
            try node.decls.push(decl);
        }
        node.eof = eatToken(it, .Eof) orelse {
            try tree.errors.push(.{
                .ExpectedDecl = .{ .token = it.index },
            });
            return node;
        };
        return node;
    }

    /// ExternalDeclaration
    ///     <- Declaration
    ///     / DeclarationSpecifiers Declarator Declaration* CompoundStmt
    fn externalDeclarations(parser: *Parser) !?*Node {
        if (try Declaration(parser)) |decl| {}
        return null;
    }

    /// Declaration
    ///     <- DeclarationSpecifiers (Declarator (EQUAL Initializer)?)* SEMICOLON
    ///     \ StaticAssertDeclaration
    fn declaration(parser: *Parser) !?*Node {}

    /// StaticAssertDeclaration <- Keyword_static_assert LPAREN ConstExpr COMMA STRINGLITERAL RPAREN SEMICOLON
    fn staticAssertDeclaration(parser: *Parser) !?*Node {}

    /// DeclarationSpecifiers
    ///     <- StorageClassSpecifier DeclarationSpecifiers?
    ///     / TypeSpecifier DeclarationSpecifiers?
    ///     / TypeQualifier DeclarationSpecifiers?
    ///     / FunctionSpecifier DeclarationSpecifiers?
    ///     / AlignmentSpecifier DeclarationSpecifiers?
    fn declarationSpecifiers(parser: *Parser) !*Node {}

    /// StorageClassSpecifier
    ///     <- Keyword_typedef / Keyword_extern / Keyword_static / Keyword_thread_local / Keyword_auto / Keyword_register
    fn storageClassSpecifier(parser: *Parser) !*Node {}

    /// TypeSpecifier
    ///     <- Keyword_void / Keyword_char / Keyword_short / Keyword_int / Keyword_long / Keyword_float / Keyword_double
    ///     / Keyword_signed / Keyword_unsigned / Keyword_bool / Keyword_complex / Keyword_imaginary /
    ///     / Keyword_atomic LPAREN TypeName RPAREN
    ///     / EnumSpecifier
    ///     / RecordSpecifier
    ///     / IDENTIFIER // typedef name
    fn typeSpecifier(parser: *Parser) !*Node {}

    /// TypeQualifier <- Keyword_const / Keyword_restrict / Keyword_volatile / Keyword_atomic
    fn typeQualifier(parser: *Parser) !*Node {}

    /// FunctionSpecifier <- Keyword_inline / Keyword_noreturn
    fn functionSpecifier(parser: *Parser) !*Node {}

    /// AlignmentSpecifier <- Keyword_alignas LPAREN (TypeName / ConstExpr) RPAREN
    fn alignmentSpecifier(parser: *Parser) !*Node {}

    /// EnumSpecifier <- Keyword_enum IDENTIFIER? (LBRACE EnumField RBRACE)?
    fn enumSpecifier(parser: *Parser) !*Node {}

    /// EnumField <- IDENTIFIER (EQUAL ConstExpr)? (COMMA EnumField) COMMA?
    fn enumField(parser: *Parser) !*Node {}

    /// RecordSpecifier <- (Keyword_struct / Keyword_union) IDENTIFIER? (LBRACE RecordField+ RBRACE)?
    fn recordSpecifier(parser: *Parser) !*Node {}

    /// RecordField
    ///     <- SpecifierQualifer (RecordDeclarator (COMMA RecordDeclarator))? SEMICOLON
    ///     \ StaticAssertDeclaration
    fn recordField(parser: *Parser) !*Node {}

    /// TypeName
    ///     <- SpecifierQualifer AbstractDeclarator?
    fn typeName(parser: *Parser) !*Node {}

    /// SpecifierQualifer
    ///     <- TypeSpecifier SpecifierQualifer?
    ///     / TypeQualifier SpecifierQualifer?
    fn specifierQualifer(parser: *Parser) !*Node {}

    /// RecordDeclarator <- Declarator? (COLON ConstExpr)?
    fn recordDeclarator(parser: *Parser) !*Node {}

    /// Declarator <- Pointer? DirectDeclarator
    fn declarator(parser: *Parser) !*Node {}

    /// Pointer <- ASTERISK TypeQualifier* Pointer?
    fn pointer(parser: *Parser) !*Node {}

    /// DirectDeclarator
    ///     <- IDENTIFIER
    ///     / LPAREN Declarator RPAREN
    ///     / DirectDeclarator LBRACKET (ASTERISK / BracketDeclarator)? RBRACKET
    ///     / DirectDeclarator LPAREN (ParamDecl (COMMA ParamDecl)* (COMMA ELLIPSIS)?)? RPAREN
    fn directDeclarator(parser: *Parser) !*Node {}

    /// BracketDeclarator
    ///     <- Keyword_static TypeQualifier* AssignmentExpr
    ///     / TypeQualifier+ (ASTERISK / Keyword_static AssignmentExpr)
    ///     / TypeQualifier+ AssignmentExpr?
    ///     / AssignmentExpr
    fn bracketDeclarator(parser: *Parser) !*Node {}

    /// ParamDecl <- DeclarationSpecifiers (Declarator / AbstractDeclarator)
    fn paramDecl(parser: *Parser) !*Node {}

    /// AbstractDeclarator <- Pointer? DirectAbstractDeclarator?
    fn abstractDeclarator(parser: *Parser) !*Node {}

    /// DirectAbstractDeclarator
    ///     <- IDENTIFIER
    ///     / LPAREN DirectAbstractDeclarator RPAREN
    ///     / DirectAbstractDeclarator? LBRACKET (ASTERISK / BracketDeclarator)? RBRACKET
    ///     / DirectAbstractDeclarator? LPAREN (ParamDecl (COMMA ParamDecl)* (COMMA ELLIPSIS)?)? RPAREN
    fn directAbstractDeclarator(parser: *Parser) !*Node {}

    /// Expr <- AssignmentExpr (COMMA Expr)*
    fn expr(parser: *Parser) !*Node {}

    /// AssignmentExpr
    ///     <- ConditionalExpr // TODO recursive?
    ///     / UnaryExpr (EQUAL / ASTERISKEQUAL / SLASHEQUAL / PERCENTEQUAL / PLUSEQUAL / MINUSEQUA /
    ///     / ANGLEBRACKETANGLEBRACKETLEFTEQUAL / ANGLEBRACKETANGLEBRACKETRIGHTEQUAL /
    ///     / AMPERSANDEQUAL / CARETEQUAL / PIPEEQUAL) AssignmentExpr
    fn assignmentExpr(parser: *Parser) !*Node {}

    /// ConstExpr <- ConditionalExpr
    /// ConditionalExpr <- LogicalOrExpr (QUESTIONMARK Expr COLON ConditionalExpr)?
    fn conditionalExpr(parser: *Parser) !*Node {}

    /// LogicalOrExpr <- LogicalAndExpr (PIPEPIPE LogicalOrExpr)*
    fn logicalOrExpr(parser: *Parser) !*Node {}

    /// LogicalAndExpr <- BinOrExpr (AMPERSANDAMPERSAND LogicalAndExpr)*
    fn logicalAndExpr(parser: *Parser) !*Node {}

    /// BinOrExpr <- BinXorExpr (PIPE BinOrExpr)*
    fn binOrExpr(parser: *Parser) !*Node {}

    /// BinXorExpr <- BinAndExpr (CARET BinXorExpr)*
    fn binXorExpr(parser: *Parser) !*Node {}

    /// BinAndExpr <- EqualityExpr (AMPERSAND BinAndExpr)*
    fn binAndExpr(parser: *Parser) !*Node {}

    /// EqualityExpr <- ComparisionExpr ((EQUALEQUAL / BANGEQUAL) EqualityExpr)*
    fn equalityExpr(parser: *Parser) !*Node {}

    /// ComparisionExpr <- ShiftExpr (ANGLEBRACKETLEFT / ANGLEBRACKETLEFTEQUAL /ANGLEBRACKETRIGHT / ANGLEBRACKETRIGHTEQUAL) ComparisionExpr)*
    fn comparisionExpr(parser: *Parser) !*Node {}

    /// ShiftExpr <- AdditiveExpr (ANGLEBRACKETANGLEBRACKETLEFT / ANGLEBRACKETANGLEBRACKETRIGHT) ShiftExpr)*
    fn shiftExpr(parser: *Parser) !*Node {}

    /// AdditiveExpr <- MultiplicativeExpr (PLUS / MINUS) AdditiveExpr)*
    fn additiveExpr(parser: *Parser) !*Node {}

    /// MultiplicativeExpr <- UnaryExpr (ASTERISK / SLASH / PERCENT) MultiplicativeExpr)*
    fn multiplicativeExpr(parser: *Parser) !*Node {}

    /// UnaryExpr
    ///     <- LPAREN TypeName RPAREN UnaryExpr
    ///     / Keyword_sizeof LAPERN TypeName RPAREN
    ///     / Keyword_sizeof UnaryExpr
    ///     / Keyword_alignof LAPERN TypeName RPAREN
    ///     / (AMPERSAND / ASTERISK / PLUS / PLUSPLUS / MINUS / MINUSMINUS / TILDE / BANG) UnaryExpr
    ///     / PrimaryExpr PostFixExpr*
    fn unaryExpr(parser: *Parser) !*Node {}

    /// PrimaryExpr
    ///     <- IDENTIFIER
    ///     / INTEGERLITERAL / FLITERAL / STRINGLITERAL / CHARLITERAL
    ///     / LPAREN Expr RPAREN
    ///     / Keyword_generic LPAREN AssignmentExpr (COMMA Generic)+ RPAREN
    fn primaryExpr(parser: *Parser) !*Node {}

    /// Generic
    ///     <- TypeName COLON AssignmentExpr
    ///     / Keyword_default COLON AssignmentExpr
    fn generic(parser: *Parser) !*Node {}

    /// PostFixExpr
    ///     <- LPAREN TypeName RPAREN LBRACE Initializers RBRACE
    ///     / LBRACKET Expr RBRACKET
    ///     / LPAREN (AssignmentExpr (COMMA AssignmentExpr)*)? RPAREN
    ///     / (PERIOD / ARROW) IDENTIFIER
    ///     / (PLUSPLUS / MINUSMINUS)
    fn postFixExpr(parser: *Parser) !*Node {}

    /// Initializers <- ((Designator+ EQUAL)? Initializer COMMA)* (Designator+ EQUAL)? Initializer COMMA?
    fn initializers(parser: *Parser) !*Node {}

    /// Initializer
    ///     <- LBRACE Initializers RBRACE
    ///     / AssignmentExpr
    fn initializer(parser: *Parser) !*Node {}

    /// Designator
    ///     <- LBRACKET Initializers RBRACKET
    ///     / PERIOD IDENTIFIER
    fn designator(parser: *Parser) !*Node {}

    /// CompoundStmt <- LBRACE (Declaration / Stmt)* RBRACE
    fn compoundStmt(parser: *Parser) !?*Node {
        const lbrace = parser.eatToken(.LBrace) orelse return null;
        const node = try parser.arena.create(Node.CompoundStmt);
        node.* = .{
            .lbrace = lbrace,
            .statements = Node.JumpStmt.StmtList.init(parser.arena),
            .rbrace = undefined,
        };
        while (parser.declaration() orelse parser.stmt()) |node|
            try node.statements.push(node);
        node.rbrace = try parser.expectToken(.RBrace);
        return &node.base;
    }

    /// Stmt
    ///     <- CompoundStmt
    ///     / Keyword_if LPAREN Expr RPAREN Stmt (Keyword_ELSE Stmt)?
    ///     / Keyword_switch LPAREN Expr RPAREN Stmt
    ///     / Keyword_while LPAREN Expr RPAREN Stmt
    ///     / Keyword_do statement Keyword_while LPAREN Expr RPAREN SEMICOLON
    ///     / Keyword_for LPAREN (Declaration / ExprStmt) ExprStmt Expr? RPAREN Stmt
    ///     / Keyword_default COLON Stmt
    ///     / Keyword_case ConstExpr COLON Stmt
    ///     / Keyword_goto IDENTIFIER SEMICOLON
    ///     / Keyword_continue SEMICOLON
    ///     / Keyword_break SEMICOLON
    ///     / Keyword_return Expr? SEMICOLON
    ///     / IDENTIFIER COLON Stmt
    ///     / ExprStmt
    fn stmt(parser: *Parser) !?*Node {
        if (parser.compoundStmt()) |node| return node;
        if (parser.eatToken(.Keyword_if)) |tok| {
            const node = try parser.arena.create(Node.IfStmt);
            _ = try parser.expectToken(.LParen);
            node.* = .{
                .@"if" = tok,
                .cond = try parser.expect(expr, .{
                    .ExpectedExpr = .{ .token = it.index },
                }),
                .@"else" = null,
            };
            _ = try parser.expectToken(.RParen);
            if (parser.eatToken(.Keyword_else)) |else_tok| {
                node.@"else" = .{
                    .tok = else_tok,
                    .stmt =  try parser.stmt(expr, .{
                        .ExpectedStmt = .{ .token = it.index },
                    }),
                };
            }
            return &node.base;
        }
        // if (parser.eatToken(.Keyword_switch)) |tok| {}
        // if (parser.eatToken(.Keyword_while)) |tok| {}
        // if (parser.eatToken(.Keyword_do)) |tok| {}
        // if (parser.eatToken(.Keyword_for)) |tok| {}
        // if (parser.eatToken(.Keyword_default)) |tok| {}
        // if (parser.eatToken(.Keyword_case)) |tok| {}
        if (parser.eatToken(.Keyword_goto)) |tok| {
            const node = try parser.arena.create(Node.JumpStmt);
            node.* = .{
                .ltoken = tok,
                .kind = .Goto,
                .semicolon = parser.expectToken(.Semicolon),
            };
            return &node.base;
        }
        if (parser.eatToken(.Keyword_continue)) |tok| {
            const node = try parser.arena.create(Node.JumpStmt);
            node.* = .{
                .ltoken = tok,
                .kind = .Continue,
                .semicolon = parser.expectToken(.Semicolon),
            };
            return &node.base;
        }
        if (parser.eatToken(.Keyword_break)) |tok| {
            const node = try parser.arena.create(Node.JumpStmt);
            node.* = .{
                .ltoken = tok,
                .kind = .Break,
                .semicolon = parser.expectToken(.Semicolon),
            };
            return &node.base;
        }
        if (parser.eatToken(.Keyword_return)) |tok| {
            const node = try parser.arena.create(Node.JumpStmt);
            node.* = .{
                .ltoken = tok,
                .kind = .{ .Return = try parser.expr() },
                .semicolon = parser.expectToken(.Semicolon),
            };
            return &node.base;
        }
        if (parser.eatToken(.Identifier)) |tok| {
            if (parser.eatToken(.Colon)) |col| {
                const node = try parser.arena.create(Node.Label);
                node.* = .{
                    .identifier = tok,
                    .semicolon = parser.expectToken(.Colon),
                };
                return &node.base;
            }
            putBackToken(tok);
        }
        if (parser.exprStmt()) |node| return node;
        return null;
    }

    /// ExprStmt <- Expr? SEMICOLON
    fn exprStmt(parser: *Parser) !*Node {
        const node = try parser.arena.create(Node.ExprStmt);
        node.* = .{
            .expr = try parser.expr(),
            .semicolon = parser.expectToken(.Semicolon),
        };
        return &node.base;
    }

    fn eatToken(parser: *Parser, id: Token.Id) ?TokenIndex {
        while (true) {
            const next_tok = parser.it.next() orelse return null;
            if (next_tok.id != .LineComment and next_tok.id != .MultiLineComment) {
                if (next_tok.id == id) {
                    return parser.it.index;
                }
                parser.it.prev();
                return null;
            }
        }
    }

    fn expectToken(parser: *Parser, id: Token.Id) Error!TokenIndex {
        while (true) {
            const next_tok = parser.it.next() orelse return error.ParseError;
            if (next_tok.id != .LineComment and next_tok.id != .MultiLineComment) {
                if (next_tok.id != id) {
                    try tree.errors.push(.{
                        .ExpectedToken = .{ .token = parser.it.index, .expected_id = id },
                    });
                    return error.ParseError;
                }
                return parser.it.index;
            }
        }
    }

    fn putBackToken(it: *TokenIterator, putting_back: TokenIndex) void {
        while (true) {
            const prev_tok = it.prev() orelse return;
            if (next_tok.id == .LineComment or next_tok.id == .MultiLineComment) continue;
            assert(it.list.at(putting_back) == prev_tok);
            return;
        }
    }

    fn expect(
        parser: *Parser,
        parseFn: fn (*Parser) Error!?*Node,
        err: ast.Error, // if parsing fails
    ) Error!*Node {
        return (try parseFn(arena, it, tree)) orelse {
            try parser.tree.errors.push(err);
            return error.ParseError;
        };
    }
};
