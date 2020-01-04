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

    tree.root_node = try parseRoot(arena, &it, tree);
    return tree;
}

/// Root <- ExternalDeclaration* eof
fn parseRoot(arena: *Allocator, it: *TokenIterator, tree: *Tree) Allocator.Error!*Node {
    const node = try arena.create(ast.Root);
    node.* = .{
        .decls = ast.Node.DeclList.init(arena),
        .eof_token = undefined,
    };
    while (parseExternalDeclarations(arena, it, tree) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.ParseError => return node,
    }) |decl| {
        try node.decls.push(decl);
    }
    node.eof_token = eatToken(it, .Eof) orelse {
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
fn parseExternalDeclarations(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {
    if (try parseDeclaration(arena, it, tree)) |decl| {}
    return null;
}

/// Declaration
///     <- DeclarationSpecifiers (Declarator (EQUAL Initializer)?)* SEMICOLON
///     \ StaticAssertDeclaration
fn parseDeclaration(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {}

/// StaticAssertDeclaration <- Keyword_static_assert LPAREN ConstExpr COMMA STRINGLITERAL RPAREN SEMICOLON
fn parseStaticAssertDeclaration(arena: *Allocator, it: *TokenIterator, tree: *Tree) !?*Node {}

/// DeclarationSpecifiers
///     <- StorageClassSpecifier DeclarationSpecifiers?
///     / TypeSpecifier DeclarationSpecifiers?
///     / TypeQualifier DeclarationSpecifiers?
///     / FunctionSpecifier DeclarationSpecifiers?
///     / AlignmentSpecifier DeclarationSpecifiers?
fn parseDeclarationSpecifiers(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// StorageClassSpecifier
///     <- Keyword_typedef / Keyword_extern / Keyword_static / Keyword_thread_local / Keyword_auto / Keyword_register
fn parseStorageClassSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// TypeSpecifier
///     <- Keyword_void / Keyword_char / Keyword_short / Keyword_int / Keyword_long / Keyword_float / Keyword_double
///     / Keyword_signed / Keyword_unsigned / Keyword_bool / Keyword_complex / Keyword_imaginary /
///     / Keyword_atomic LPAREN TypeName RPAREN
///     / EnumSpecifier
///     / RecordSpecifier
///     / IDENTIFIER // typedef name
fn parseTypeSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// TypeQualifier <- Keyword_const / Keyword_restrict / Keyword_volatile / Keyword_atomic
fn parseTypeQualifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// FunctionSpecifier <- Keyword_inline / Keyword_noreturn
fn parseFunctionSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// AlignmentSpecifier <- Keyword_alignas LPAREN (TypeName / ConstExpr) RPAREN
fn parseAlignmentSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// EnumSpecifier <- Keyword_enum IDENTIFIER? (LBRACE EnumField RBRACE)?
fn parseEnumSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// EnumField <- IDENTIFIER (EQUAL ConstExpr)? (COMMA EnumField) COMMA?
fn parseEnumField(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// RecordSpecifier <- (Keyword_struct / Keyword_union) IDENTIFIER? (LBRACE RecordField+ RBRACE)?
fn parseRecordSpecifier(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// RecordField
///     <- SpecifierQualifer (RecordDeclarator (COMMA RecordDeclarator))? SEMICOLON
///     \ StaticAssertDeclaration
fn parseRecordField(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// TypeName
///     <- SpecifierQualifer AbstractDeclarator?
fn parseTypeName(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// SpecifierQualifer
///     <- TypeSpecifier SpecifierQualifer?
///     / TypeQualifier SpecifierQualifer?
fn parseSpecifierQualifer(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// RecordDeclarator <- Declarator? (COLON ConstExpr)?
fn parseRecordDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Declarator <- Pointer? DirectDeclarator
fn parseDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Pointer <- ASTERISK TypeQualifier* Pointer?
fn parsePointer(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// DirectDeclarator
///     <- IDENTIFIER
///     / LPAREN Declarator RPAREN
///     / DirectDeclarator LBRACKET (ASTERISK / BracketDeclarator)? RBRACKET
///     / DirectDeclarator LPAREN (ParamDecl (COMMA ParamDecl)* (COMMA ELLIPSIS)?)? RPAREN
fn parseDirectDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// BracketDeclarator
///     <- Keyword_static TypeQualifier* AssignmentExpr
///     / TypeQualifier+ (ASTERISK / Keyword_static AssignmentExpr)
///     / TypeQualifier+ AssignmentExpr?
///     / AssignmentExpr
fn parseBracketDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// ParamDecl <- DeclarationSpecifiers (Declarator / AbstractDeclarator)
fn parseParamDecl(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// AbstractDeclarator <- Pointer? DirectAbstractDeclarator?
fn parseAbstractDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// DirectAbstractDeclarator
///     <- IDENTIFIER
///     / LPAREN DirectAbstractDeclarator RPAREN
///     / DirectAbstractDeclarator? LBRACKET (ASTERISK / BracketDeclarator)? RBRACKET
///     / DirectAbstractDeclarator? LPAREN (ParamDecl (COMMA ParamDecl)* (COMMA ELLIPSIS)?)? RPAREN
fn parseDirectAbstractDeclarator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Expr <- AssignmentExpr (COMMA Expr)*
fn parseExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// AssignmentExpr
///     <- ConditionalExpr
///     / UnaryExpr (EQUAL / ASTERISKEQUAL / SLASHEQUAL / PERCENTEQUAL / PLUSEQUAL / MINUSEQUA /
///     / ANGLEBRACKETANGLEBRACKETLEFTEQUAL / ANGLEBRACKETANGLEBRACKETRIGHTEQUAL /
///     / AMPERSANDEQUAL / CARETEQUAL / PIPEEQUAL) AssignmentExpr
fn parseAssignmentExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// ConstExpr <- ConditionalExpr
/// ConditionalExpr <- LogicalOrExpr (QUESTIONMARK Expr COLON ConditionalExpr)?
fn parseConditionalExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// LogicalOrExpr <- LogicalAndExpr (PIPEPIPE LogicalOrExpr)*
fn parseLogicalOrExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// LogicalAndExpr <- BinOrExpr (AMPERSANDAMPERSAND LogicalAndExpr)*
fn parseLogicalAndExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// BinOrExpr <- BinXorExpr (PIPE BinOrExpr)*
fn parseBinOrExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// BinXorExpr <- BinAndExpr (CARET BinXorExpr)*
fn parseBinXorExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// BinAndExpr <- EqualityExpr (AMPERSAND BinAndExpr)*
fn parseBinAndExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// EqualityExpr <- ComparisionExpr ((EQUALEQUAL / BANGEQUAL) EqualityExpr)*
fn parseEqualityExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// ComparisionExpr <- ShiftExpr (ANGLEBRACKETLEFT / ANGLEBRACKETLEFTEQUAL /ANGLEBRACKETRIGHT / ANGLEBRACKETRIGHTEQUAL) ComparisionExpr)*
fn parseComparisionExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// ShiftExpr <- AdditiveExpr (ANGLEBRACKETANGLEBRACKETLEFT / ANGLEBRACKETANGLEBRACKETRIGHT) ShiftExpr)*
fn parseShiftExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// AdditiveExpr <- MultiplicativeExpr (PLUS / MINUS) AdditiveExpr)*
fn parseAdditiveExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// MultiplicativeExpr <- UnaryExpr (ASTERISK / SLASH / PERCENT) MultiplicativeExpr)*
fn parseMultiplicativeExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// UnaryExpr
///     <- LPAREN TypeName RPAREN UnaryExpr
///     / Keyword_sizeof LAPERN TypeName RPAREN
///     / Keyword_sizeof UnaryExpr
///     / Keyword_alignof LAPERN TypeName RPAREN
///     / (AMPERSAND / ASTERISK / PLUS / PLUSPLUS / MINUS / MINUSMINUS / TILDE / BANG) UnaryExpr
///     / PrimaryExpr PostFixExpr*
fn parseUnaryExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// PrimaryExpr
///     <- IDENTIFIER
///     / INTEGERLITERAL / FLITERAL / STRINGLITERAL / CHARLITERAL
///     / LPAREN Expr RPAREN
///     / Keyword_generic LPAREN AssignmentExpr (COMMA Generic)+ RPAREN
fn parsePrimaryExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Generic
///     <- TypeName COLON AssignmentExpr
///     / Keyword_default COLON AssignmentExpr
fn parseGeneric(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// PostFixExpr
///     <- LPAREN TypeName RPAREN LBRACE Initializers RBRACE
///     / LBRACKET Expr RBRACKET
///     / LPAREN (AssignmentExpr (COMMA AssignmentExpr)*)? RPAREN
///     / (PERIOD / ARROW) IDENTIFIER
///     / (PLUSPLUS / MINUSMINUS)
fn parsePostFixExpr(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Initializers <- ((Designator+ EQUAL)? Initializer COMMA)* (Designator+ EQUAL)? Initializer COMMA?
fn parseInitializers(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Initializer
///     <- LBRACE Initializers RBRACE
///     / AssignmentExpr
fn parseInitializer(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// Designator
///     <- LBRACKET Initializers RBRACKET
///     / PERIOD IDENTIFIER
fn parseDesignator(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// CompoundStmt <- LBRACE (Declaration / Stmt)* RBRACE
fn parseCompoundStmt(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

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
fn parseStmt(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}

/// ExprStmt <- Expr? SEMICOLON
fn parseExprStmt(arena: *Allocator, it: *TokenIterator, tree: *Tree) !*Node {}
