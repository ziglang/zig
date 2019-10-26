// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently the only way it is used is with `zig translate-c-2`.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const ast = std.zig.ast;
const Token = std.zig.Token;
usingnamespace @import("clang.zig");

pub const Mode = enum {
    import,
    translate,
};

// TODO merge with Type.Fn.CallingConvention
const CallingConvention = builtin.TypeInfo.CallingConvention;

pub const ClangErrMsg = Stage2ErrorMsg;

pub const Error = error{OutOfMemory};
const TypeError = Error || error{UnsupportedType};
const TransError = TypeError || error{UnsupportedTranslation};

const DeclTable = std.HashMap(usize, void, addrHash, addrEql);

fn addrHash(x: usize) u32 {
    switch (@typeInfo(usize).Int.bits) {
        32 => return x,
        // pointers are usually aligned so we ignore the bits that are probably all 0 anyway
        // usually the larger bits of addr space are unused so we just chop em off
        64 => return @truncate(u32, x >> 4),
        else => @compileError("unreachable"),
    }
}

fn addrEql(a: usize, b: usize) bool {
    return a == b;
}

const Scope = struct {
    id: Id,
    parent: ?*Scope,

    const Id = enum {
        Switch,
        Var,
        Block,
        Root,
        While,
    };
    const Switch = struct {
        base: Scope,
    };

    const Var = struct {
        base: Scope,
        c_name: []const u8,
        zig_name: []const u8,
    };

    const Block = struct {
        base: Scope,
        block_node: *ast.Node.Block,

        /// Don't forget to set rbrace token later
        fn create(c: *Context, parent: *Scope, lbrace_tok: ast.TokenIndex) !*Block {
            const block = try c.a().create(Block);
            block.* = Block{
                .base = Scope{
                    .id = Id.Block,
                    .parent = parent,
                },
                .block_node = try c.a().create(ast.Node.Block),
            };
            block.block_node.* = ast.Node.Block{
                .base = ast.Node{ .id = ast.Node.Id.Block },
                .label = null,
                .lbrace = lbrace_tok,
                .statements = ast.Node.Block.StatementList.init(c.a()),
                .rbrace = undefined,
            };
            return block;
        }
    };

    const Root = struct {
        base: Scope,
    };

    const While = struct {
        base: Scope,
    };
};

const TransResult = struct {
    node: *ast.Node,
    node_scope: *Scope,
    child_scope: *Scope,
};

const Context = struct {
    tree: *ast.Tree,
    source_buffer: *std.Buffer,
    err: Error,
    source_manager: *ZigClangSourceManager,
    decl_table: DeclTable,
    global_scope: *Scope.Root,
    mode: Mode,
    ptr_params: std.BufSet,
    clang_context: *ZigClangASTContext,

    fn a(c: *Context) *std.mem.Allocator {
        return &c.tree.arena_allocator.allocator;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*]const u8) ![]u8 {
        return std.mem.dupe(c.a(), u8, std.mem.toSliceConst(u8, s));
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: ZigClangSourceLocation) ![]u8 {
        const spelling_loc = ZigClangSourceManager_getSpellingLoc(c.source_manager, loc);
        const filename_c = ZigClangSourceManager_getFilename(c.source_manager, spelling_loc);
        const filename = if (filename_c) |s| try c.str(s) else ([]const u8)("(no file)");

        const line = ZigClangSourceManager_getSpellingLineNumber(c.source_manager, spelling_loc);
        const column = ZigClangSourceManager_getSpellingColumnNumber(c.source_manager, spelling_loc);
        return std.fmt.allocPrint(c.a(), "{}:{}:{}", filename, line, column);
    }
};

pub fn translate(
    backing_allocator: *std.mem.Allocator,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    mode: Mode,
    errors: *[]ClangErrMsg,
    resources_path: [*]const u8,
) !*ast.Tree {
    const ast_unit = ZigClangLoadFromCommandLine(
        args_begin,
        args_end,
        &errors.ptr,
        &errors.len,
        resources_path,
    ) orelse {
        if (errors.len == 0) return error.OutOfMemory;
        return error.SemanticAnalyzeFail;
    };
    defer ZigClangASTUnit_delete(ast_unit);

    const tree = blk: {
        var tree_arena = std.heap.ArenaAllocator.init(backing_allocator);
        errdefer tree_arena.deinit();

        const tree = try tree_arena.allocator.create(ast.Tree);
        tree.* = ast.Tree{
            .source = undefined, // need to use Buffer.toOwnedSlice later
            .root_node = undefined,
            .arena_allocator = tree_arena,
            .tokens = undefined, // can't reference the allocator yet
            .errors = undefined, // can't reference the allocator yet
        };
        break :blk tree;
    };
    const arena = &tree.arena_allocator.allocator; // now we can reference the allocator
    errdefer arena.deinit();
    tree.tokens = ast.Tree.TokenList.init(arena);
    tree.errors = ast.Tree.ErrorList.init(arena);

    tree.root_node = try arena.create(ast.Node.Root);
    tree.root_node.* = ast.Node.Root{
        .base = ast.Node{ .id = ast.Node.Id.Root },
        .decls = ast.Node.Root.DeclList.init(arena),
        .doc_comments = null,
        // initialized with the eof token at the end
        .eof_token = undefined,
    };

    var source_buffer = try std.Buffer.initSize(arena, 0);

    var context = Context{
        .tree = tree,
        .source_buffer = &source_buffer,
        .source_manager = ZigClangASTUnit_getSourceManager(ast_unit),
        .err = undefined,
        .decl_table = DeclTable.init(arena),
        .global_scope = try arena.create(Scope.Root),
        .mode = mode,
        .ptr_params = std.BufSet.init(arena),
        .clang_context = ZigClangASTUnit_getASTContext(ast_unit).?,
    };
    context.global_scope.* = Scope.Root{
        .base = Scope{
            .id = Scope.Id.Root,
            .parent = null,
        },
    };

    if (!ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, &context, declVisitorC)) {
        return context.err;
    }

    tree.root_node.eof_token = try appendToken(&context, .Eof, "");
    tree.source = source_buffer.toOwnedSlice();
    if (false) {
        std.debug.warn("debug source:\n{}\n==EOF==\ntokens:\n", tree.source);
        var i: usize = 0;
        while (i < tree.tokens.len) : (i += 1) {
            const token = tree.tokens.at(i);
            std.debug.warn("{}\n", token);
        }
    }
    return tree;
}

extern fn declVisitorC(context: ?*c_void, decl: *const ZigClangDecl) bool {
    const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    declVisitor(c, decl) catch |err| {
        c.err = err;
        return false;
    };
    return true;
}

fn declVisitor(c: *Context, decl: *const ZigClangDecl) Error!void {
    switch (ZigClangDecl_getKind(decl)) {
        .Function => {
            return visitFnDecl(c, @ptrCast(*const ZigClangFunctionDecl, decl));
        },
        .Typedef => {
            try emitWarning(c, ZigClangDecl_getLocation(decl), "TODO implement translate-c for typedefs");
        },
        .Enum => {
            try emitWarning(c, ZigClangDecl_getLocation(decl), "TODO implement translate-c for enums");
        },
        .Record => {
            try emitWarning(c, ZigClangDecl_getLocation(decl), "TODO implement translate-c for structs");
        },
        .Var => {
            try emitWarning(c, ZigClangDecl_getLocation(decl), "TODO implement translate-c for variables");
        },
        else => {
            const decl_name = try c.str(ZigClangDecl_getDeclKindName(decl));
            try emitWarning(c, ZigClangDecl_getLocation(decl), "ignoring {} declaration", decl_name);
        },
    }
}

fn visitFnDecl(c: *Context, fn_decl: *const ZigClangFunctionDecl) Error!void {
    if (try c.decl_table.put(@ptrToInt(fn_decl), {})) |_| return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const fn_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, fn_decl)));
    const fn_decl_loc = ZigClangFunctionDecl_getLocation(fn_decl);
    const fn_qt = ZigClangFunctionDecl_getType(fn_decl);
    const fn_type = ZigClangQualType_getTypePtr(fn_qt);
    var scope = &c.global_scope.base;
    const has_body = ZigClangFunctionDecl_hasBody(fn_decl);
    const storage_class = ZigClangFunctionDecl_getStorageClass(fn_decl);
    const decl_ctx = FnDeclContext{
        .fn_name = fn_name,
        .has_body = has_body,
        .storage_class = storage_class,
        .scope = &scope,
        .is_export = switch (storage_class) {
            .None => has_body and c.mode != .import,
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern"),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        },
    };
    const proto_node = switch (ZigClangType_getTypeClass(fn_type)) {
        .FunctionProto => blk: {
            const fn_proto_type = @ptrCast(*const ZigClangFunctionProtoType, fn_type);
            break :blk transFnProto(rp, fn_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function");
                },
                error.OutOfMemory => |e| return e,
            };
        },
        .FunctionNoProto => blk: {
            const fn_no_proto_type = @ptrCast(*const ZigClangFunctionType, fn_type);
            break :blk transFnNoProto(rp, fn_no_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function");
                },
                error.OutOfMemory => |e| return e,
            };
        },
        else => unreachable,
    };

    if (!decl_ctx.has_body) {
        const semi_tok = try appendToken(c, .Semicolon, ";");
        return addTopLevelDecl(c, fn_name, &proto_node.base);
    }

    // actual function definition with body
    const body_stmt = ZigClangFunctionDecl_getBody(fn_decl);
    const result = transStmt(rp, scope, body_stmt, .unused, .r_value) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function"),
    };
    assert(result.node.id == ast.Node.Id.Block);
    proto_node.body_node = result.node;

    return addTopLevelDecl(c, fn_name, &proto_node.base);
}

const ResultUsed = enum {
    used,
    unused,
};

const LRValue = enum {
    l_value,
    r_value,
};

fn transStmt(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangStmt,
    result_used: ResultUsed,
    lrvalue: LRValue,
) !TransResult {
    const sc = ZigClangStmt_getStmtClass(stmt);
    switch (sc) {
        .BinaryOperatorClass => return transBinaryOperator(rp, scope, @ptrCast(*const ZigClangBinaryOperator, stmt), result_used),
        .CompoundStmtClass => return transCompoundStmt(rp, scope, @ptrCast(*const ZigClangCompoundStmt, stmt)),
        .CStyleCastExprClass => return transCStyleCastExprClass(rp, scope, @ptrCast(*const ZigClangCStyleCastExpr, stmt), result_used, lrvalue),
        .DeclStmtClass => return transDeclStmt(rp, scope, @ptrCast(*const ZigClangDeclStmt, stmt)),
        .DeclRefExprClass => return transDeclRefExpr(rp, scope, @ptrCast(*const ZigClangDeclRefExpr, stmt), lrvalue),
        .ImplicitCastExprClass => return transImplicitCastExpr(rp, scope, @ptrCast(*const ZigClangImplicitCastExpr, stmt), result_used),
        .IntegerLiteralClass => return transIntegerLiteral(rp, scope, @ptrCast(*const ZigClangIntegerLiteral, stmt), result_used),
        .ReturnStmtClass => return transReturnStmt(rp, scope, @ptrCast(*const ZigClangReturnStmt, stmt)),
        .StringLiteralClass => return transStringLiteral(rp, scope, @ptrCast(*const ZigClangStringLiteral, stmt), result_used),
        else => {
            return revertAndWarn(
                rp,
                error.UnsupportedTranslation,
                ZigClangStmt_getBeginLoc(stmt),
                "TODO implement translation of stmt class {}",
                @tagName(sc),
            );
        },
    }
}

fn transBinaryOperator(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    result_used: ResultUsed,
) TransError!TransResult {
    const op = ZigClangBinaryOperator_getOpcode(stmt);
    const qt = ZigClangBinaryOperator_getType(stmt);
    switch (op) {
        .PtrMemD, .PtrMemI, .Cmp => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangBinaryOperator_getBeginLoc(stmt),
            "TODO: handle more C binary operators: {}",
            op,
        ),
        .Assign => return TransResult{
            .node = &(try transCreateNodeAssign(rp, scope, result_used, ZigClangBinaryOperator_getLHS(stmt), ZigClangBinaryOperator_getRHS(stmt))).base,
            .child_scope = scope,
            .node_scope = scope,
        },
        .Add => {
            const node = if (cIsUnsignedInteger(qt))
                try transCreateNodeInfixOp(rp, scope, stmt, .AddWrap, .PlusPercent, "+%", true)
            else
                try transCreateNodeInfixOp(rp, scope, stmt, .Add, .Plus, "+", true);
            return maybeSuppressResult(rp, scope, result_used, TransResult{
                .node = node,
                .child_scope = scope,
                .node_scope = scope,
            });
        },
        .Sub => {
            const node = if (cIsUnsignedInteger(qt))
                try transCreateNodeInfixOp(rp, scope, stmt, .SubWrap, .MinusPercent, "-%", true)
            else
                try transCreateNodeInfixOp(rp, scope, stmt, .Sub, .Minus, "-", true);
            return maybeSuppressResult(rp, scope, result_used, TransResult{
                .node = node,
                .child_scope = scope,
                .node_scope = scope,
            });
        },
        .Mul,
        .Div,
        .Rem,
        .Shl,
        .Shr,
        .LT,
        .GT,
        .LE,
        .GE,
        .EQ,
        .NE,
        .And,
        .Xor,
        .Or,
        .LAnd,
        .LOr,
        .Comma,
        => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangBinaryOperator_getBeginLoc(stmt),
            "TODO: handle more C binary operators: {}",
            op,
        ),
        .MulAssign,
        .DivAssign,
        .RemAssign,
        .AddAssign,
        .SubAssign,
        .ShlAssign,
        .ShrAssign,
        .AndAssign,
        .XorAssign,
        .OrAssign,
        => unreachable,
    }
}

fn transCompoundStmtInline(
    rp: RestorePoint,
    parent_scope: *Scope,
    stmt: *const ZigClangCompoundStmt,
    block_node: *ast.Node.Block,
) TransError!TransResult {
    var it = ZigClangCompoundStmt_body_begin(stmt);
    const end_it = ZigClangCompoundStmt_body_end(stmt);
    var scope = parent_scope;
    while (it != end_it) : (it += 1) {
        const result = try transStmt(rp, parent_scope, it.*, .unused, .r_value);
        scope = result.child_scope;
        if (result.node != &block_node.base)
            try block_node.statements.push(result.node);
    }
    return TransResult{
        .node = &block_node.base,
        .child_scope = scope,
        .node_scope = scope,
    };
}

fn transCompoundStmt(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangCompoundStmt) !TransResult {
    const lbrace_tok = try appendToken(rp.c, .LBrace, "{");
    const block_scope = try Scope.Block.create(rp.c, scope, lbrace_tok);
    const inline_result = try transCompoundStmtInline(rp, &block_scope.base, stmt, block_scope.block_node);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    return TransResult{
        .node = &block_scope.block_node.base,
        .node_scope = inline_result.node_scope,
        .child_scope = inline_result.child_scope,
    };
}

fn transCStyleCastExprClass(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCStyleCastExpr,
    result_used: ResultUsed,
    lrvalue: LRValue,
) !TransResult {
    const sub_expr = ZigClangCStyleCastExpr_getSubExpr(stmt);
    const cast_node = (try transCCast(
        rp,
        scope,
        ZigClangCStyleCastExpr_getBeginLoc(stmt),
        ZigClangCStyleCastExpr_getType(stmt),
        ZigClangExpr_getType(sub_expr),
        (try transExpr(rp, scope, sub_expr, .used, lrvalue)).node,
    ));
    const cast_res = TransResult{
        .node = cast_node,
        .child_scope = scope,
        .node_scope = scope,
    };
    return maybeSuppressResult(rp, scope, result_used, cast_res);
}

fn transDeclStmt(rp: RestorePoint, parent_scope: *Scope, stmt: *const ZigClangDeclStmt) !TransResult {
    const c = rp.c;
    const block_scope = findBlockScope(parent_scope);
    var scope = parent_scope;

    var it = ZigClangDeclStmt_decl_begin(stmt);
    const end_it = ZigClangDeclStmt_decl_end(stmt);
    while (it != end_it) : (it += 1) {
        switch (ZigClangDecl_getKind(it.*)) {
            .Var => {
                const var_decl = @ptrCast(*const ZigClangVarDecl, it.*);

                const thread_local_token = if (ZigClangVarDecl_getTLSKind(var_decl) == .None)
                    null
                else
                    try appendToken(c, .Keyword_threadlocal, "threadlocal");
                const qual_type = ZigClangVarDecl_getType(var_decl);
                const mut_token = if (ZigClangQualType_isConstQualified(qual_type))
                    try appendToken(c, .Keyword_const, "const")
                else
                    try appendToken(c, .Keyword_var, "var");
                const c_name = try c.str(ZigClangDecl_getName_bytes_begin(
                    @ptrCast(*const ZigClangDecl, var_decl),
                ));
                const name_token = try appendToken(c, .Identifier, c_name);

                const var_scope = try c.a().create(Scope.Var);
                var_scope.* = Scope.Var{
                    .base = Scope{ .id = .Var, .parent = scope },
                    .c_name = c_name,
                    .zig_name = c_name, // TODO: getWantedName
                };
                scope = &var_scope.base;

                const colon_token = try appendToken(c, .Colon, ":");
                const loc = ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt));
                const type_node = try transQualType(rp, qual_type, loc);

                const eq_token = try appendToken(c, .Equal, "=");
                const init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
                    (try transExpr(rp, scope, expr, .used, .r_value)).node
                else blk: {
                    const undefined_token = try appendToken(c, .Keyword_undefined, "undefined");
                    const undefined_node = try rp.c.a().create(ast.Node.UndefinedLiteral);
                    undefined_node.* = ast.Node.UndefinedLiteral{
                        .base = ast.Node{ .id = .UndefinedLiteral },
                        .token = undefined_token,
                    };
                    break :blk &undefined_node.base;
                };
                const semicolon_token = try appendToken(c, .Semicolon, ";");

                const node = try c.a().create(ast.Node.VarDecl);
                node.* = ast.Node.VarDecl{
                    .base = ast.Node{ .id = .VarDecl },
                    .doc_comments = null,
                    .visib_token = null,
                    .thread_local_token = thread_local_token,
                    .name_token = name_token,
                    .eq_token = eq_token,
                    .mut_token = mut_token,
                    .comptime_token = null,
                    .extern_export_token = null,
                    .lib_name = null,
                    .type_node = type_node,
                    .align_node = null, // TODO ?*Node,
                    .section_node = null,
                    .init_node = init_node,
                    .semicolon_token = semicolon_token,
                };
                try block_scope.block_node.statements.push(&node.base);
            },

            else => |kind| return revertAndWarn(
                rp,
                error.UnsupportedTranslation,
                ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)),
                "TODO implement translation of DeclStmt kind {}",
                @tagName(kind),
            ),
        }
    }

    return TransResult{
        .node = &block_scope.block_node.base,
        .node_scope = scope,
        .child_scope = scope,
    };
}

fn transDeclRefExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangDeclRefExpr,
    lrvalue: LRValue,
) !TransResult {
    const value_decl = ZigClangDeclRefExpr_getDecl(expr);
    const c_name = try rp.c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, value_decl)));
    const zig_name = transLookupZigIdentifier(scope, c_name);
    if (lrvalue == .l_value) try rp.c.ptr_params.put(zig_name);
    const node = try appendIdentifier(rp.c, zig_name);
    return TransResult{
        .node = node,
        .node_scope = scope,
        .child_scope = scope,
    };
}

fn transImplicitCastExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangImplicitCastExpr,
    result_used: ResultUsed,
) !TransResult {
    const c = rp.c;
    const sub_expr = ZigClangImplicitCastExpr_getSubExpr(expr);
    const sub_expr_node = try transExpr(rp, scope, @ptrCast(*const ZigClangExpr, sub_expr), .used, .r_value);
    switch (ZigClangImplicitCastExpr_getCastKind(expr)) {
        .BitCast => {
            const dest_type = getExprQualType(c, @ptrCast(*const ZigClangExpr, expr));
            const src_type = getExprQualType(c, sub_expr);
            return TransResult{
                .node = try transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node.node),
                .node_scope = scope,
                .child_scope = scope,
            };
        },
        .IntegralCast => {
            const dest_type = ZigClangExpr_getType(@ptrCast(*const ZigClangExpr, expr));
            const src_type = ZigClangExpr_getType(sub_expr);
            return TransResult{
                .node = try transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node.node),
                .node_scope = scope,
                .child_scope = scope,
            };
        },
        .FunctionToPointerDecay, .ArrayToPointerDecay => {
            return maybeSuppressResult(rp, scope, result_used, sub_expr_node);
        },
        .LValueToRValue => {
            return transExpr(rp, scope, sub_expr, .used, .r_value);
        },
        else => |kind| return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, expr)),
            "TODO implement translation of CastKind {}",
            @tagName(kind),
        ),
    }
}

fn transIntegerLiteral(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangIntegerLiteral,
    result_used: ResultUsed,
) !TransResult {
    var eval_result: ZigClangExprEvalResult = undefined;
    if (!ZigClangIntegerLiteral_EvaluateAsInt(expr, &eval_result, rp.c.clang_context)) {
        const loc = ZigClangIntegerLiteral_getBeginLoc(expr);
        return revertAndWarn(rp, error.UnsupportedTranslation, loc, "invalid integer literal");
    }
    const node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&eval_result.Val));
    const res = TransResult{
        .node = node,
        .child_scope = scope,
        .node_scope = scope,
    };
    return maybeSuppressResult(rp, scope, result_used, res);
}

fn transReturnStmt(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangReturnStmt,
) !TransResult {
    const node = try transCreateNodeReturnExpr(rp.c);
    if (ZigClangReturnStmt_getRetValue(expr)) |val_expr| {
        const ret_node = node.cast(ast.Node.ControlFlowExpression).?;
        ret_node.rhs = (try transExpr(rp, scope, val_expr, .used, .r_value)).node;
    }
    _ = try appendToken(rp.c, .Semicolon, ";");
    return TransResult{
        .node = node,
        .child_scope = scope,
        .node_scope = scope,
    };
}

fn transStringLiteral(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangStringLiteral,
    result_used: ResultUsed,
) !TransResult {
    const kind = ZigClangStringLiteral_getKind(stmt);
    switch (kind) {
        .Ascii, .UTF8 => {
            var len: usize = undefined;
            const bytes_ptr = ZigClangStringLiteral_getString_bytes_begin_size(stmt, &len);
            const str = bytes_ptr[0..len];

            var char_buf: [4]u8 = undefined;
            len = 0;
            for (str) |c| len += escapeChar(c, &char_buf).len;

            const buf = try rp.c.a().alloc(u8, len + "c\"\"".len);
            buf[0] = 'c';
            buf[1] = '"';
            writeEscapedString(buf[2..], str);
            buf[buf.len - 1] = '"';

            const token = try appendToken(rp.c, .StringLiteral, buf);
            const node = try rp.c.a().create(ast.Node.StringLiteral);
            node.* = ast.Node.StringLiteral{
                .base = ast.Node{ .id = .StringLiteral },
                .token = token,
            };
            const res = TransResult{
                .node = &node.base,
                .child_scope = scope,
                .node_scope = scope,
            };
            return maybeSuppressResult(rp, scope, result_used, res);
        },
        .UTF16, .UTF32, .Wide => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)),
            "TODO: support string literal kind {}",
            kind,
        ),
    }
}

fn escapedStringLen(s: []const u8) usize {
    var len: usize = 0;
    var char_buf: [4]u8 = undefined;
    for (s) |c| len += escapeChar(c, &char_buf).len;
    return len;
}

fn writeEscapedString(buf: []u8, s: []const u8) void {
    var char_buf: [4]u8 = undefined;
    var i: usize = 0;
    for (s) |c| {
        const escaped = escapeChar(c, &char_buf);
        std.mem.copy(u8, buf[i..], escaped);
        i += escaped.len;
    }
}

// Returns either a string literal or a slice of `buf`.
fn escapeChar(c: u8, char_buf: *[4]u8) []const u8 {
    // TODO: https://github.com/ziglang/zig/issues/2749
    const escaped = switch (c) {
        // Printable ASCII except for ' " \
        ' ', '!', '#'...'&', '('...'[', ']'...'~' => ([_]u8{c})[0..],
        '\'', '\"', '\\' => ([_]u8{ '\\', c })[0..],
        '\n' => return "\\n"[0..],
        '\r' => return "\\r"[0..],
        '\t' => return "\\t"[0..],
        else => return std.fmt.bufPrint(char_buf[0..], "\\x{x:2}", c) catch unreachable,
    };
    std.mem.copy(u8, char_buf, escaped);
    return char_buf[0..escaped.len];
}

fn transCCast(
    rp: RestorePoint,
    scope: *Scope,
    loc: ZigClangSourceLocation,
    dst_type: ZigClangQualType,
    src_type: ZigClangQualType,
    expr: *ast.Node,
) !*ast.Node {
    if (ZigClangType_isVoidType(qualTypeCanon(dst_type))) return expr;
    if (ZigClangQualType_eq(dst_type, src_type)) return expr;
    if (qualTypeIsPtr(dst_type) and qualTypeIsPtr(src_type))
        return transCPtrCast(rp, loc, dst_type, src_type, expr);
    if (cIsUnsignedInteger(dst_type) and qualTypeIsPtr(src_type)) {
        const cast_node = try transCreateNodeFnCall(rp.c, try transQualType(rp, dst_type, loc));
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrToInt");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        try cast_node.op.Call.params.push(&builtin_node.base);
        cast_node.rtoken = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    }
    if (cIsUnsignedInteger(src_type) and qualTypeIsPtr(dst_type)) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@intToPtr");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    // TODO: maybe widen to increase size
    // TODO: maybe bitcast to change sign
    // TODO: maybe truncate to reduce size
    const cast_node = try transCreateNodeFnCall(rp.c, try transQualType(rp, dst_type, loc));
    try cast_node.op.Call.params.push(expr);
    cast_node.rtoken = try appendToken(rp.c, .RParen, ")");
    return &cast_node.base;
}

fn transExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangExpr,
    used: ResultUsed,
    lrvalue: LRValue,
) TransError!TransResult {
    return transStmt(rp, scope, @ptrCast(*const ZigClangStmt, expr), used, lrvalue);
}

fn findBlockScope(inner: *Scope) *Scope.Block {
    var scope = inner;
    while (true) : (scope = scope.parent orelse unreachable) {
        if (scope.id == .Block) return @fieldParentPtr(Scope.Block, "base", scope);
    }
}

fn transLookupZigIdentifier(inner: *Scope, c_name: []const u8) []const u8 {
    var scope = inner;
    while (true) : (scope = scope.parent orelse return c_name) {
        if (scope.id == .Var) {
            const var_scope = @ptrCast(*const Scope.Var, scope);
            if (std.mem.eql(u8, var_scope.c_name, c_name)) return var_scope.zig_name;
        }
    }
}

fn transCPtrCast(
    rp: RestorePoint,
    loc: ZigClangSourceLocation,
    dst_type: ZigClangQualType,
    src_type: ZigClangQualType,
    expr: *ast.Node,
) !*ast.Node {
    const ty = ZigClangQualType_getTypePtr(dst_type);
    const child_type = ZigClangType_getPointeeType(ty);

    // Implicit downcasting from higher to lower alignment values is forbidden,
    // use @alignCast to side-step this problem
    const ptrcast_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrCast");
    const dst_type_node = try transType(rp, ty, loc);
    try ptrcast_node.params.push(dst_type_node);
    _ = try appendToken(rp.c, .Comma, ",");

    if (ZigClangType_isVoidType(qualTypeCanon(child_type))) {
        // void has 1-byte alignment, so @alignCast is not needed
        try ptrcast_node.params.push(expr);
    } else {
        const aligncast_node = try transCreateNodeBuiltinFnCall(rp.c, "@alignCast");
        const alignof_node = try transCreateNodeBuiltinFnCall(rp.c, "@alignOf");
        const child_type_node = try transQualType(rp, child_type, loc);
        try alignof_node.params.push(child_type_node);
        alignof_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        try aligncast_node.params.push(&alignof_node.base);
        _ = try appendToken(rp.c, .Comma, ",");
        try aligncast_node.params.push(expr);
        aligncast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        try ptrcast_node.params.push(&aligncast_node.base);
    }
    ptrcast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

    return &ptrcast_node.base;
}

fn maybeSuppressResult(
    rp: RestorePoint,
    scope: *Scope,
    used: ResultUsed,
    result: TransResult,
) !TransResult {
    if (used == .used) return result;
    // NOTE: This is backwards, but the semicolon must immediately follow the node.
    _ = try appendToken(rp.c, .Semicolon, ";");
    const lhs = try appendIdentifier(rp.c, "_");
    const op_token = try appendToken(rp.c, .Equal, "=");
    const op_node = try rp.c.a().create(ast.Node.InfixOp);
    op_node.* = ast.Node.InfixOp{
        .base = ast.Node{ .id = .InfixOp },
        .op_token = op_token,
        .lhs = lhs,
        .op = .Assign,
        .rhs = result.node,
    };
    return TransResult{
        .node = &op_node.base,
        .child_scope = scope,
        .node_scope = scope,
    };
}

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: *ast.Node) !void {
    try c.tree.root_node.decls.push(decl_node);
}

fn transQualType(rp: RestorePoint, qt: ZigClangQualType, source_loc: ZigClangSourceLocation) TypeError!*ast.Node {
    return transType(rp, ZigClangQualType_getTypePtr(qt), source_loc);
}

fn qualTypeIsPtr(qt: ZigClangQualType) bool {
    return ZigClangType_getTypeClass(qualTypeCanon(qt)) == .Pointer;
}

fn qualTypeChildIsFnProto(qt: ZigClangQualType) bool {
    const ty = ZigClangQualType_getTypePtr(qt);
    if (ZigClangType_getTypeClass(ty) == .Paren) {
        const paren_type = @ptrCast(*const ZigClangParenType, ty);
        const inner_type = ZigClangParenType_getInnerType(paren_type);
        return ZigClangQualType_getTypeClass(inner_type) == .FunctionProto;
    }
    if (ZigClangType_getTypeClass(ty) == .Attributed) {
        const attr_type = @ptrCast(*const ZigClangAttributedType, ty);
        return qualTypeChildIsFnProto(ZigClangAttributedType_getEquivalentType(attr_type));
    }
    return false;
}

fn qualTypeCanon(qt: ZigClangQualType) *const ZigClangType {
    const canon = ZigClangQualType_getCanonicalType(qt);
    return ZigClangQualType_getTypePtr(canon);
}

fn getExprQualType(c: *Context, expr: *const ZigClangExpr) ZigClangQualType {
    blk: {
        // If this is a C `char *`, turn it into a `const char *`
        if (ZigClangExpr_getStmtClass(expr) != .ImplicitCastExprClass) break :blk;
        const cast_expr = @ptrCast(*const ZigClangImplicitCastExpr, expr);
        if (ZigClangImplicitCastExpr_getCastKind(cast_expr) != .ArrayToPointerDecay) break :blk;
        const sub_expr = ZigClangImplicitCastExpr_getSubExpr(cast_expr);
        if (ZigClangExpr_getStmtClass(sub_expr) != .StringLiteralClass) break :blk;
        const array_qt = ZigClangExpr_getType(sub_expr);
        const array_type = @ptrCast(*const ZigClangArrayType, ZigClangQualType_getTypePtr(array_qt));
        var pointee_qt = ZigClangArrayType_getElementType(array_type);
        ZigClangQualType_addConst(&pointee_qt);
        return ZigClangASTContext_getPointerType(c.clang_context, pointee_qt);
    }
    return ZigClangExpr_getType(expr);
}

fn typeIsOpaque(c: *Context, ty: *const ZigClangType, loc: ZigClangSourceLocation) bool {
    switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
            return ZigClangBuiltinType_getKind(builtin_ty) == .Void;
        },
        .Record => {
            const record_ty = @ptrCast(*const ZigClangRecordType, ty);
            const record_decl = ZigClangRecordType_getDecl(record_ty);
            return (ZigClangRecordDecl_getDefinition(record_decl) == null);
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const ZigClangElaboratedType, ty);
            const qt = ZigClangElaboratedType_getNamedType(elaborated_ty);
            return typeIsOpaque(c, ZigClangQualType_getTypePtr(qt), loc);
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);
            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            const underlying_type = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
            return typeIsOpaque(c, ZigClangQualType_getTypePtr(underlying_type), loc);
        },
        else => return false,
    }
}

fn cIsUnsignedInteger(qt: ZigClangQualType) bool {
    const c_type = qualTypeCanon(qt);
    if (ZigClangType_getTypeClass(c_type) != .Builtin) return false;
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .Char_U,
        .UChar,
        .Char_S,
        .UShort,
        .UInt,
        .ULong,
        .ULongLong,
        .UInt128,
        .WChar_U,
        => true,
        else => false,
    };
}

fn transCreateNodeAssign(
    rp: RestorePoint,
    scope: *Scope,
    result_used: ResultUsed,
    lhs: *const ZigClangExpr,
    rhs: *const ZigClangExpr,
) !*ast.Node.InfixOp {
    // common case
    // c:   lhs = rhs
    // zig: lhs = rhs
    if (result_used == .unused) {
        const lhs_node = try transExpr(rp, scope, lhs, .used, .l_value);
        const eq_token = try appendToken(rp.c, .Equal, "=");
        const rhs_node = try transExpr(rp, scope, rhs, .used, .r_value);
        _ = try appendToken(rp.c, .Semicolon, ";");

        const node = try rp.c.a().create(ast.Node.InfixOp);
        node.* = ast.Node.InfixOp{
            .base = ast.Node{ .id = .InfixOp },
            .op_token = eq_token,
            .lhs = lhs_node.node,
            .op = .Assign,
            .rhs = rhs_node.node,
        };
        return node;
    }

    // worst case
    // c:   lhs = rhs
    // zig: (x: {
    // zig:     const _tmp = rhs;
    // zig:     lhs = _tmp;
    // zig:     break :x _tmp
    // zig: })
    return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangExpr_getBeginLoc(lhs), "TODO: worst case assign op expr");
}

fn transCreateNodeBuiltinFnCall(c: *Context, name: []const u8) !*ast.Node.BuiltinCall {
    const builtin_token = try appendToken(c, .Builtin, name);
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.BuiltinCall);
    node.* = ast.Node.BuiltinCall{
        .base = ast.Node{ .id = .BuiltinCall },
        .builtin_token = builtin_token,
        .params = ast.Node.BuiltinCall.ParamList.init(c.a()),
        .rparen_token = undefined, // set after appending args
    };
    return node;
}

fn transCreateNodeFnCall(c: *Context, fn_expr: *ast.Node) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = ast.Node.SuffixOp{
        .base = ast.Node{ .id = .SuffixOp },
        .lhs = fn_expr,
        .op = ast.Node.SuffixOp.Op{
            .Call = ast.Node.SuffixOp.Op.Call{
                .params = ast.Node.SuffixOp.Op.Call.ParamList.init(c.a()),
                .async_token = null,
            },
        },
        .rtoken = undefined, // set after appending args
    };
    return node;
}

fn transCreateNodePrefixOp(
    c: *Context,
    op: ast.Node.PrefixOp.Op,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
) !*ast.Node.PrefixOp {
    const node = try c.a().create(ast.Node.PrefixOp);
    node.* = ast.Node.PrefixOp{
        .base = ast.Node{ .id = .PrefixOp },
        .op_token = try appendToken(c, op_tok_id, bytes),
        .op = op,
        .rhs = undefined, // translate and set afterward
    };
    return node;
}

fn transCreateNodeInfixOp(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    op: ast.Node.InfixOp.Op,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
    grouped: bool,
) !*ast.Node {
    const lparen = if (grouped) try appendToken(rp.c, .LParen, "(") else undefined;
    const lhs = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
    const op_token = try appendToken(rp.c, op_tok_id, bytes);
    const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
    const node = try rp.c.a().create(ast.Node.InfixOp);
    node.* = ast.Node.InfixOp{
        .base = ast.Node{ .id = .InfixOp },
        .op_token = op_token,
        .lhs = lhs.node,
        .op = op,
        .rhs = rhs.node,
    };
    if (!grouped) return &node.base;
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = ast.Node.GroupedExpression{
        .base = ast.Node{ .id = .GroupedExpression },
        .lparen = lparen,
        .expr = &node.base,
        .rparen = rparen,
    };
    return &grouped_expr.base;
}

fn transCreateNodePtrType(
    c: *Context,
    is_const: bool,
    is_volatile: bool,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
) !*ast.Node.PrefixOp {
    const node = try c.a().create(ast.Node.PrefixOp);
    node.* = ast.Node.PrefixOp{
        .base = ast.Node{ .id = .PrefixOp },
        .op_token = try appendToken(c, op_tok_id, bytes),
        .op = ast.Node.PrefixOp.Op{
            .PtrType = ast.Node.PrefixOp.PtrInfo{
                .allowzero_token = null,
                .align_info = null,
                .const_token = if (is_const) try appendToken(c, .Keyword_const, "const") else null,
                .volatile_token = if (is_volatile) try appendToken(c, .Keyword_volatile, "volatile") else null,
            },
        },
        .rhs = undefined, // translate and set afterward
    };
    return node;
}

fn transCreateNodeAPInt(c: *Context, int: ?*const ZigClangAPSInt) !*ast.Node {
    const num_limbs = ZigClangAPSInt_getNumWords(int.?);
    var big = try std.math.big.Int.initCapacity(c.a(), num_limbs);
    defer big.deinit();
    const data = ZigClangAPSInt_getRawData(int.?);
    var i: @typeOf(num_limbs) = 0;
    while (i < num_limbs) : (i += 1) big.limbs[i] = data[i];
    const str = big.toString(c.a(), 10) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
    const token = try appendToken(c, .IntegerLiteral, str);
    const node = try c.a().create(ast.Node.IntegerLiteral);
    node.* = ast.Node.IntegerLiteral{
        .base = ast.Node{ .id = .IntegerLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeReturnExpr(c: *Context) !*ast.Node {
    const ltoken = try appendToken(c, .Keyword_return, "return");
    const node = try c.a().create(ast.Node.ControlFlowExpression);
    node.* = ast.Node.ControlFlowExpression{
        .base = ast.Node{ .id = .ControlFlowExpression },
        .ltoken = ltoken,
        .kind = .Return,
        .rhs = null,
    };
    return &node.base;
}

const RestorePoint = struct {
    c: *Context,
    token_index: ast.TokenIndex,
    src_buf_index: usize,

    fn activate(self: RestorePoint) void {
        self.c.tree.tokens.shrink(self.token_index);
        self.c.source_buffer.shrink(self.src_buf_index);
    }
};

fn makeRestorePoint(c: *Context) RestorePoint {
    return RestorePoint{
        .c = c,
        .token_index = c.tree.tokens.len,
        .src_buf_index = c.source_buffer.len(),
    };
}

fn transType(rp: RestorePoint, ty: *const ZigClangType, source_loc: ZigClangSourceLocation) TypeError!*ast.Node {
    switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Void => return appendIdentifier(rp.c, "c_void"),
                .Bool => return appendIdentifier(rp.c, "bool"),
                .Char_U, .UChar, .Char_S, .Char8 => return appendIdentifier(rp.c, "u8"),
                .SChar => return appendIdentifier(rp.c, "i8"),
                .UShort => return appendIdentifier(rp.c, "c_ushort"),
                .UInt => return appendIdentifier(rp.c, "c_uint"),
                .ULong => return appendIdentifier(rp.c, "c_ulong"),
                .ULongLong => return appendIdentifier(rp.c, "c_ulonglong"),
                .Short => return appendIdentifier(rp.c, "c_short"),
                .Int => return appendIdentifier(rp.c, "c_int"),
                .Long => return appendIdentifier(rp.c, "c_long"),
                .LongLong => return appendIdentifier(rp.c, "c_longlong"),
                .UInt128 => return appendIdentifier(rp.c, "u128"),
                .Int128 => return appendIdentifier(rp.c, "i128"),
                .Float => return appendIdentifier(rp.c, "f32"),
                .Double => return appendIdentifier(rp.c, "f64"),
                .Float128 => return appendIdentifier(rp.c, "f128"),
                .Float16 => return appendIdentifier(rp.c, "f16"),
                .LongDouble => return appendIdentifier(rp.c, "c_longdouble"),
                else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported builtin type"),
            }
        },
        .FunctionProto => {
            const fn_proto_ty = @ptrCast(*const ZigClangFunctionProtoType, ty);
            const fn_proto = try transFnProto(rp, fn_proto_ty, source_loc, null, false);
            return &fn_proto.base;
        },
        .Paren => {
            const paren_ty = @ptrCast(*const ZigClangParenType, ty);
            return transQualType(rp, ZigClangParenType_getInnerType(paren_ty), source_loc);
        },
        .Pointer => {
            const child_qt = ZigClangType_getPointeeType(ty);
            if (qualTypeChildIsFnProto(child_qt)) {
                const optional_node = try transCreateNodePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
                optional_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            if (typeIsOpaque(rp.c, ZigClangQualType_getTypePtr(child_qt), source_loc)) {
                const optional_node = try transCreateNodePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
                const pointer_node = try transCreateNodePtrType(
                    rp.c,
                    ZigClangQualType_isConstQualified(child_qt),
                    ZigClangQualType_isVolatileQualified(child_qt),
                    .Asterisk,
                    "*",
                );
                optional_node.rhs = &pointer_node.base;
                pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            const pointer_node = try transCreateNodePtrType(
                rp.c,
                ZigClangQualType_isConstQualified(child_qt),
                ZigClangQualType_isVolatileQualified(child_qt),
                .BracketStarCBracket,
                "[*c]",
            );
            pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
            return &pointer_node.base;
        },
        else => {
            const type_name = rp.c.str(ZigClangType_getTypeClassName(ty));
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported type: '{}'", type_name);
        },
    }
}

const FnDeclContext = struct {
    fn_name: []const u8,
    has_body: bool,
    storage_class: ZigClangStorageClass,
    scope: **Scope,
    is_export: bool,
};

fn transCC(
    rp: RestorePoint,
    fn_ty: *const ZigClangFunctionType,
    source_loc: ZigClangSourceLocation,
) !CallingConvention {
    const clang_cc = ZigClangFunctionType_getCallConv(fn_ty);
    switch (clang_cc) {
        .C => return CallingConvention.C,
        .X86StdCall => return CallingConvention.Stdcall,
        else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: {}", @tagName(clang_cc)),
    }
}

fn transFnProto(
    rp: RestorePoint,
    fn_proto_ty: *const ZigClangFunctionProtoType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Node.FnProto {
    const fn_ty = @ptrCast(*const ZigClangFunctionType, fn_proto_ty);
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = ZigClangFunctionProtoType_isVariadic(fn_proto_ty);
    const param_count: usize = ZigClangFunctionProtoType_getNumParams(fn_proto_ty);
    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        return revertAndWarn(rp, error.UnsupportedType, source_loc, "TODO: implement parameters for FunctionProto in transType");
    }

    return finishTransFnProto(rp, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn transFnNoProto(
    rp: RestorePoint,
    fn_ty: *const ZigClangFunctionType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Node.FnProto {
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = if (fn_decl_context) |ctx| !ctx.is_export else true;
    return finishTransFnProto(rp, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn finishTransFnProto(
    rp: RestorePoint,
    fn_ty: *const ZigClangFunctionType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_var_args: bool,
    cc: CallingConvention,
    is_pub: bool,
) !*ast.Node.FnProto {
    const is_export = if (fn_decl_context) |ctx| ctx.is_export else false;
    const is_extern = if (fn_decl_context) |ctx| !ctx.has_body else true;

    // TODO check for always_inline attribute
    // TODO check for align attribute

    // pub extern fn name(...) T
    const pub_tok = if (is_pub) try appendToken(rp.c, .Keyword_pub, "pub") else null;
    const cc_tok = if (cc == .Stdcall) try appendToken(rp.c, .Keyword_stdcallcc, "stdcallcc") else null;
    const extern_export_inline_tok = if (is_export)
        try appendToken(rp.c, .Keyword_export, "export")
    else if (cc == .C and is_extern)
        try appendToken(rp.c, .Keyword_extern, "extern")
    else
        null;
    const fn_tok = try appendToken(rp.c, .Keyword_fn, "fn");
    const name_tok = if (fn_decl_context) |ctx| try appendToken(rp.c, .Identifier, ctx.fn_name) else null;
    const lparen_tok = try appendToken(rp.c, .LParen, "(");
    const var_args_tok = if (is_var_args) try appendToken(rp.c, .Ellipsis3, "...") else null;
    const rparen_tok = try appendToken(rp.c, .RParen, ")");

    const return_type_node = blk: {
        if (ZigClangFunctionType_getNoReturnAttr(fn_ty)) {
            break :blk try appendIdentifier(rp.c, "noreturn");
        } else {
            const return_qt = ZigClangFunctionType_getReturnType(fn_ty);
            if (ZigClangType_isVoidType(qualTypeCanon(return_qt))) {
                break :blk try appendIdentifier(rp.c, "void");
            } else {
                break :blk transQualType(rp, return_qt, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try emitWarning(rp.c, source_loc, "unsupported function proto return type");
                        return err;
                    },
                    error.OutOfMemory => |e| return e,
                };
            }
        }
    };

    const fn_proto = try rp.c.a().create(ast.Node.FnProto);
    fn_proto.* = ast.Node.FnProto{
        .base = ast.Node{ .id = ast.Node.Id.FnProto },
        .doc_comments = null,
        .visib_token = pub_tok,
        .fn_token = fn_tok,
        .name_token = name_tok,
        .params = ast.Node.FnProto.ParamList.init(rp.c.a()),
        .return_type = ast.Node.FnProto.ReturnType{ .Explicit = return_type_node },
        .var_args_token = null, // TODO this field is broken in the AST data model
        .extern_export_inline_token = extern_export_inline_tok,
        .cc_token = cc_tok,
        .body_node = null,
        .lib_name = null,
        .align_expr = null,
        .section_expr = null,
    };
    if (is_var_args) {
        const var_arg_node = try rp.c.a().create(ast.Node.ParamDecl);
        var_arg_node.* = ast.Node.ParamDecl{
            .base = ast.Node{ .id = ast.Node.Id.ParamDecl },
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = null,
            .name_token = null,
            .type_node = undefined,
            .var_args_token = var_args_tok,
        };
        try fn_proto.params.push(&var_arg_node.base);
    }
    return fn_proto;
}

fn revertAndWarn(
    rp: RestorePoint,
    err: var,
    source_loc: ZigClangSourceLocation,
    comptime format: []const u8,
    args: ...,
) (@typeOf(err) || error{OutOfMemory}) {
    rp.activate();
    try emitWarning(rp.c, source_loc, format, args);
    return err;
}

fn emitWarning(c: *Context, loc: ZigClangSourceLocation, comptime format: []const u8, args: ...) !void {
    _ = try appendTokenFmt(c, .LineComment, "// {}: warning: " ++ format, c.locStr(loc), args);
}

fn failDecl(c: *Context, loc: ZigClangSourceLocation, name: []const u8, comptime format: []const u8, args: ...) !void {
    // const name = @compileError(msg);
    const const_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendToken(c, .Identifier, name);
    const eq_tok = try appendToken(c, .Equal, "=");
    const builtin_tok = try appendToken(c, .Builtin, "@compileError");
    const lparen_tok = try appendToken(c, .LParen, "(");
    const msg_tok = try appendTokenFmt(c, .StringLiteral, "\"" ++ format ++ "\"", args);
    const rparen_tok = try appendToken(c, .RParen, ")");
    const semi_tok = try appendToken(c, .Semicolon, ";");

    const msg_node = try c.a().create(ast.Node.StringLiteral);
    msg_node.* = ast.Node.StringLiteral{
        .base = ast.Node{ .id = ast.Node.Id.StringLiteral },
        .token = msg_tok,
    };

    const call_node = try c.a().create(ast.Node.BuiltinCall);
    call_node.* = ast.Node.BuiltinCall{
        .base = ast.Node{ .id = ast.Node.Id.BuiltinCall },
        .builtin_token = builtin_tok,
        .params = ast.Node.BuiltinCall.ParamList.init(c.a()),
        .rparen_token = rparen_tok,
    };
    try call_node.params.push(&msg_node.base);

    const var_decl_node = try c.a().create(ast.Node.VarDecl);
    var_decl_node.* = ast.Node.VarDecl{
        .base = ast.Node{ .id = ast.Node.Id.VarDecl },
        .doc_comments = null,
        .visib_token = null,
        .thread_local_token = null,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .mut_token = const_tok,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
        .init_node = &call_node.base,
        .semicolon_token = semi_tok,
    };
    try c.tree.root_node.decls.push(&var_decl_node.base);
}

fn appendToken(c: *Context, token_id: Token.Id, bytes: []const u8) !ast.TokenIndex {
    return appendTokenFmt(c, token_id, "{}", bytes);
}

fn appendTokenFmt(c: *Context, token_id: Token.Id, comptime format: []const u8, args: ...) !ast.TokenIndex {
    const S = struct {
        fn callback(context: *Context, bytes: []const u8) error{OutOfMemory}!void {
            return context.source_buffer.append(bytes);
        }
    };
    const start_index = c.source_buffer.len();
    errdefer c.source_buffer.shrink(start_index);

    try std.fmt.format(c, error{OutOfMemory}, S.callback, format, args);
    const end_index = c.source_buffer.len();
    const token_index = c.tree.tokens.len;
    const new_token = try c.tree.tokens.addOne();
    errdefer c.tree.tokens.shrink(token_index);

    new_token.* = Token{
        .id = token_id,
        .start = start_index,
        .end = end_index,
    };
    try c.source_buffer.appendByte(' ');

    return token_index;
}

fn appendIdentifier(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendToken(c, .Identifier, name);
    const identifier = try c.a().create(ast.Node.Identifier);
    identifier.* = ast.Node.Identifier{
        .base = ast.Node{ .id = ast.Node.Id.Identifier },
        .token = token_index,
    };
    return &identifier.base;
}

pub fn freeErrors(errors: []ClangErrMsg) void {
    ZigClangErrorMsg_delete(errors.ptr, errors.len);
}
