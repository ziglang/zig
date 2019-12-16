// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently the only way it is used is with `zig translate-c-2`.

const std = @import("std");
const assert = std.debug.assert;
const ast = std.zig.ast;
const Token = std.zig.Token;
usingnamespace @import("clang.zig");
const ctok = @import("c_tokenizer.zig");
const CToken = ctok.CToken;

const CallingConvention = std.builtin.TypeInfo.CallingConvention;

pub const ClangErrMsg = Stage2ErrorMsg;

pub const Error = error{OutOfMemory};
const TypeError = Error || error{UnsupportedType};
const TransError = TypeError || error{UnsupportedTranslation};

const DeclTable = std.HashMap(usize, []const u8, addrHash, addrEql);

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

const SymbolTable = std.StringHashMap(*ast.Node);
const AliasList = std.SegmentedList(struct {
    alias: []const u8,
    name: []const u8,
}, 4);

const Scope = struct {
    id: Id,
    parent: ?*Scope,

    const Id = enum {
        Switch,
        Block,
        Root,
        While,
        FnDef,
        Ref,
    };

    const Switch = struct {
        base: Scope,
    };

    /// used when getting a member `a.b`
    const Ref = struct {
        base: Scope,
    };

    const Block = struct {
        base: Scope,
        block_node: *ast.Node.Block,
        variables: AliasList,

        /// Don't forget to set rbrace token later
        fn init(c: *Context, parent: *Scope, block_node: *ast.Node.Block) !*Block {
            const block = try c.a().create(Block);
            block.* = .{
                .base = .{
                    .id = .Block,
                    .parent = parent,
                },
                .block_node = block_node,
                .variables = AliasList.init(c.a()),
            };
            return block;
        }

        fn getAlias(scope: *Block, name: []const u8) ?[]const u8 {
            var it = scope.variables.iterator(0);
            while (it.next()) |p| {
                if (std.mem.eql(u8, p.name, name))
                    return p.alias;
            }
            return scope.base.parent.?.getAlias(name);
        }

        fn contains(scope: *Block, name: []const u8) bool {
            var it = scope.variables.iterator(0);
            while (it.next()) |p| {
                if (std.mem.eql(u8, p.name, name))
                    return true;
            }
            return scope.base.parent.?.contains(name);
        }
    };

    const Root = struct {
        base: Scope,
        sym_table: SymbolTable,
        macro_table: SymbolTable,

        fn init(c: *Context) Root {
            return .{
                .base = .{
                    .id = .Root,
                    .parent = null,
                },
                .sym_table = SymbolTable.init(c.a()),
                .macro_table = SymbolTable.init(c.a()),
            };
        }

        fn contains(scope: *Root, name: []const u8) bool {
            return scope.sym_table.contains(name) or scope.macro_table.contains(name);
        }
    };

    const While = struct {
        base: Scope,
    };

    const FnDef = struct {
        base: Scope,
        params: AliasList,

        fn init(c: *Context) FnDef {
            return .{
                .base = .{
                    .id = .FnDef,
                    .parent = &c.global_scope.base,
                },
                .params = AliasList.init(c.a()),
            };
        }

        fn getAlias(scope: *FnDef, name: []const u8) ?[]const u8 {
            var it = scope.params.iterator(0);
            while (it.next()) |p| {
                if (std.mem.eql(u8, p.name, name))
                    return p.alias;
            }
            return scope.base.parent.?.getAlias(name);
        }

        fn contains(scope: *FnDef, name: []const u8) bool {
            var it = scope.params.iterator(0);
            while (it.next()) |p| {
                if (std.mem.eql(u8, p.name, name))
                    return true;
            }
            return scope.base.parent.?.contains(name);
        }
    };

    fn findBlockScope(inner: *Scope) *Scope.Block {
        var scope = inner;
        while (true) : (scope = scope.parent orelse unreachable) {
            if (scope.id == .Block) return @fieldParentPtr(Scope.Block, "base", scope);
        }
    }

    fn createAlias(scope: *Scope, c: *Context, name: []const u8) !?[]const u8 {
        if (scope.contains(name)) {
            return try std.fmt.allocPrint(c.a(), "{}_{}", .{ name, c.getMangle() });
        }
        return null;
    }

    fn getAlias(scope: *Scope, name: []const u8) ?[]const u8 {
        return switch (scope.id) {
            .Root => null,
            .Ref => null,
            .FnDef => @fieldParentPtr(FnDef, "base", scope).getAlias(name),
            .Block => @fieldParentPtr(Block, "base", scope).getAlias(name),
            else => @panic("TODO Scope.getAlias"),
        };
    }

    fn contains(scope: *Scope, name: []const u8) bool {
        return switch (scope.id) {
            .Ref => false,
            .Root => @fieldParentPtr(Root, "base", scope).contains(name),
            .FnDef => @fieldParentPtr(FnDef, "base", scope).contains(name),
            .Block => @fieldParentPtr(Block, "base", scope).contains(name),
            else => @panic("TODO Scope.contains"),
        };
    }
};

const Context = struct {
    tree: *ast.Tree,
    source_buffer: *std.Buffer,
    err: Error,
    source_manager: *ZigClangSourceManager,
    decl_table: DeclTable,
    alias_list: AliasList,
    global_scope: *Scope.Root,
    ptr_params: std.BufSet,
    clang_context: *ZigClangASTContext,
    mangle_count: u64 = 0,

    fn getMangle(c: *Context) u64 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    fn a(c: *Context) *std.mem.Allocator {
        return &c.tree.arena_allocator.allocator;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*:0]const u8) ![]u8 {
        return std.mem.dupe(c.a(), u8, std.mem.toSliceConst(u8, s));
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: ZigClangSourceLocation) ![]u8 {
        const spelling_loc = ZigClangSourceManager_getSpellingLoc(c.source_manager, loc);
        const filename_c = ZigClangSourceManager_getFilename(c.source_manager, spelling_loc);
        const filename = if (filename_c) |s| try c.str(s) else @as([]const u8, "(no file)");

        const line = ZigClangSourceManager_getSpellingLineNumber(c.source_manager, spelling_loc);
        const column = ZigClangSourceManager_getSpellingColumnNumber(c.source_manager, spelling_loc);
        return std.fmt.allocPrint(c.a(), "{}:{}:{}", .{ filename, line, column });
    }
};

pub fn translate(
    backing_allocator: *std.mem.Allocator,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors: *[]ClangErrMsg,
    resources_path: [*:0]const u8,
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
    errdefer tree.arena_allocator.deinit();
    tree.tokens = ast.Tree.TokenList.init(arena);
    tree.errors = ast.Tree.ErrorList.init(arena);

    tree.root_node = try arena.create(ast.Node.Root);
    tree.root_node.* = ast.Node.Root{
        .base = ast.Node{ .id = ast.Node.Id.Root },
        .decls = ast.Node.Root.DeclList.init(arena),
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
        .alias_list = AliasList.init(arena),
        .global_scope = try arena.create(Scope.Root),
        .ptr_params = std.BufSet.init(arena),
        .clang_context = ZigClangASTUnit_getASTContext(ast_unit).?,
    };
    context.global_scope.* = Scope.Root.init(&context);

    if (!ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, &context, declVisitorC)) {
        return context.err;
    }

    try transPreprocessorEntities(&context, ast_unit);

    try addMacros(&context);
    var it = context.alias_list.iterator(0);
    while (it.next()) |alias| {
        if (!context.global_scope.sym_table.contains(alias.alias)) {
            try createAlias(&context, alias);
        }
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
            return resolveTypeDef(c, @ptrCast(*const ZigClangTypedefNameDecl, decl));
        },
        .Enum => {
            _ = try transEnumDecl(c, @ptrCast(*const ZigClangEnumDecl, decl));
        },
        .Record => {
            return resolveRecordDecl(c, @ptrCast(*const ZigClangRecordDecl, decl));
        },
        .Var => {
            return visitVarDecl(c, @ptrCast(*const ZigClangVarDecl, decl));
        },
        else => {
            const decl_name = try c.str(ZigClangDecl_getDeclKindName(decl));
            try emitWarning(c, ZigClangDecl_getLocation(decl), "ignoring {} declaration", .{decl_name});
        },
    }
}

fn visitFnDecl(c: *Context, fn_decl: *const ZigClangFunctionDecl) Error!void {
    if (c.decl_table.contains(@ptrToInt(fn_decl))) return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const fn_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, fn_decl)));
    _ = try c.decl_table.put(@ptrToInt(fn_decl), fn_name);
    const fn_decl_loc = ZigClangFunctionDecl_getLocation(fn_decl);
    const fn_qt = ZigClangFunctionDecl_getType(fn_decl);
    const fn_type = ZigClangQualType_getTypePtr(fn_qt);
    var fndef_scope = Scope.FnDef.init(c);
    var scope = &fndef_scope.base;
    const has_body = ZigClangFunctionDecl_hasBody(fn_decl);
    const storage_class = ZigClangFunctionDecl_getStorageClass(fn_decl);
    const decl_ctx = FnDeclContext{
        .fn_name = fn_name,
        .has_body = has_body,
        .storage_class = storage_class,
        .scope = &scope,
        .is_export = switch (storage_class) {
            .None => has_body,
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern", .{}),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
            else => unreachable,
        },
    };
    const proto_node = switch (ZigClangType_getTypeClass(fn_type)) {
        .FunctionProto => blk: {
            const fn_proto_type = @ptrCast(*const ZigClangFunctionProtoType, fn_type);
            break :blk transFnProto(rp, fn_decl, fn_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
                },
                error.OutOfMemory => |e| return e,
            };
        },
        .FunctionNoProto => blk: {
            const fn_no_proto_type = @ptrCast(*const ZigClangFunctionType, fn_type);
            break :blk transFnNoProto(rp, fn_no_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
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
    const body_node = transStmt(rp, scope, body_stmt, .unused, .r_value) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function", .{}),
    };
    assert(body_node.id == .Block);
    proto_node.body_node = body_node;

    return addTopLevelDecl(c, fn_name, &proto_node.base);
}

fn visitVarDecl(c: *Context, var_decl: *const ZigClangVarDecl) Error!void {
    if (c.decl_table.contains(@ptrToInt(var_decl))) return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");

    const thread_local_token = if (ZigClangVarDecl_getTLSKind(var_decl) == .None)
        null
    else
        try appendToken(c, .Keyword_threadlocal, "threadlocal");

    const scope = &c.global_scope.base;
    const var_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, var_decl)));
    _ = try c.decl_table.put(@ptrToInt(var_decl), var_name);
    const var_decl_loc = ZigClangVarDecl_getLocation(var_decl);

    const qual_type = ZigClangVarDecl_getTypeSourceInfo_getType(var_decl);
    const storage_class = ZigClangVarDecl_getStorageClass(var_decl);
    const is_const = ZigClangQualType_isConstQualified(qual_type);

    const extern_tok = if (storage_class == .Extern)
        try appendToken(c, .Keyword_extern, "extern")
    else if (storage_class != .Static)
        try appendToken(c, .Keyword_export, "export")
    else
        null;

    const mut_tok = if (is_const)
        try appendToken(c, .Keyword_const, "const")
    else
        try appendToken(c, .Keyword_var, "var");

    const name_tok = try appendIdentifier(c, var_name);

    _ = try appendToken(c, .Colon, ":");
    const type_node = transQualType(rp, qual_type, var_decl_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, var_decl_loc, var_name, "unable to resolve variable type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    var eq_tok: ast.TokenIndex = undefined;
    var init_node: ?*ast.Node = null;

    if (ZigClangVarDecl_hasInit(var_decl)) {
        eq_tok = try appendToken(c, .Equal, "=");
        init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
            transExpr(rp, &c.global_scope.base, expr, .used, .r_value) catch |err| switch (err) {
                error.UnsupportedTranslation,
                error.UnsupportedType,
                => {
                    return failDecl(c, var_decl_loc, var_name, "unable to translate initializer", .{});
                },
                error.OutOfMemory => |e| return e,
            }
        else
            try transCreateNodeUndefinedLiteral(c);
    } else if (storage_class != .Extern) {
        return failDecl(c, var_decl_loc, var_name, "non-extern variable has no initializer", .{});
    }

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .doc_comments = null,
        .visib_token = visib_tok,
        .thread_local_token = thread_local_token,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .mut_token = mut_tok,
        .comptime_token = null,
        .extern_export_token = extern_tok,
        .lib_name = null,
        .type_node = type_node,
        .align_node = null,
        .section_node = null,
        .init_node = init_node,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    };
    return addTopLevelDecl(c, var_name, &node.base);
}

fn resolveTypeDef(c: *Context, typedef_decl: *const ZigClangTypedefNameDecl) Error!void {
    if (c.decl_table.contains(
        @ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)),
    )) return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const const_tok = try appendToken(c, .Keyword_const, "const");

    const typedef_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, typedef_decl)));
    _ = try c.decl_table.put(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)), typedef_name);
    const name_tok = try appendIdentifier(c, typedef_name);
    const eq_tok = try appendToken(c, .Equal, "=");

    const child_qt = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
    const typedef_loc = ZigClangTypedefNameDecl_getLocation(typedef_decl);
    const type_node = transQualType(rp, child_qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, typedef_loc, typedef_name, "unable to resolve typedef child type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .doc_comments = null,
        .visib_token = visib_tok,
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
        .init_node = type_node,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    };
    try addTopLevelDecl(c, typedef_name, &node.base);
}

fn resolveRecordDecl(c: *Context, record_decl: *const ZigClangRecordDecl) Error!void {
    if (c.decl_table.contains(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)))) return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);

    const bare_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, record_decl)));

    const container_kind_name = if (ZigClangRecordDecl_isUnion(record_decl))
        "union"
    else if (ZigClangRecordDecl_isStruct(record_decl))
        "struct"
    else
        return emitWarning(c, ZigClangRecordDecl_getLocation(record_decl), "record {} is not a struct or union", .{bare_name});

    if (ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl) or bare_name.len == 0)
        return;

    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const const_tok = try appendToken(c, .Keyword_const, "const");

    const name = try std.fmt.allocPrint(c.a(), "{}_{}", .{ container_kind_name, bare_name });
    _ = try c.decl_table.put(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)), name);
    const name_tok = try appendIdentifier(c, name);

    const eq_tok = try appendToken(c, .Equal, "=");
    const init_node = transRecordDecl(c, record_decl) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, ZigClangRecordDecl_getLocation(record_decl), name, "unable to resolve record type", .{});
        },
        error.OutOfMemory => |e| return e,
    };
    const semicolon_token = try appendToken(c, .Semicolon, ";");

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .doc_comments = null,
        .visib_token = visib_tok,
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
        .init_node = init_node,
        .semicolon_token = semicolon_token,
    };

    try addTopLevelDecl(c, name, &node.base);
    try c.alias_list.push(.{ .alias = bare_name, .name = name });
}

fn createAlias(c: *Context, alias: var) !void {
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, alias.alias);

    const eq_tok = try appendToken(c, .Equal, "=");
    const init_node = try transCreateNodeIdentifier(c, alias.name);

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .doc_comments = null,
        .visib_token = visib_tok,
        .thread_local_token = null,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .mut_token = mut_tok,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
        .init_node = init_node,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    };
    return addTopLevelDecl(c, alias.alias, &node.base);
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
) TransError!*ast.Node {
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
        .ParenExprClass => return transExpr(rp, scope, ZigClangParenExpr_getSubExpr(@ptrCast(*const ZigClangParenExpr, stmt)), result_used, lrvalue),
        .InitListExprClass => return transInitListExpr(rp, scope, @ptrCast(*const ZigClangInitListExpr, stmt), result_used),
        .ImplicitValueInitExprClass => return transImplicitValueInitExpr(rp, scope, @ptrCast(*const ZigClangExpr, stmt), result_used),
        else => {
            return revertAndWarn(
                rp,
                error.UnsupportedTranslation,
                ZigClangStmt_getBeginLoc(stmt),
                "TODO implement translation of stmt class {}",
                .{@tagName(sc)},
            );
        },
    }
}

fn transBinaryOperator(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const op = ZigClangBinaryOperator_getOpcode(stmt);
    const qt = ZigClangBinaryOperator_getType(stmt);
    switch (op) {
        .PtrMemD, .PtrMemI, .Cmp => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangBinaryOperator_getBeginLoc(stmt),
            "TODO: handle more C binary operators: {}",
            .{op},
        ),
        .Assign => return &(try transCreateNodeAssign(rp, scope, result_used, ZigClangBinaryOperator_getLHS(stmt), ZigClangBinaryOperator_getRHS(stmt))).base,
        .Add => {
            const node = if (cIsUnsignedInteger(qt))
                try transCreateNodeInfixOp(rp, scope, stmt, .AddWrap, .PlusPercent, "+%", true)
            else
                try transCreateNodeInfixOp(rp, scope, stmt, .Add, .Plus, "+", true);
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .Sub => {
            const node = if (cIsUnsignedInteger(qt))
                try transCreateNodeInfixOp(rp, scope, stmt, .SubWrap, .MinusPercent, "-%", true)
            else
                try transCreateNodeInfixOp(rp, scope, stmt, .Sub, .Minus, "-", true);
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .Mul => {
            const node = if (cIsUnsignedInteger(qt))
                try transCreateNodeInfixOp(rp, scope, stmt, .MultWrap, .AsteriskPercent, "*%", true)
            else
                try transCreateNodeInfixOp(rp, scope, stmt, .Mult, .Asterisk, "*", true);
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .Div => {
            if (!cIsUnsignedInteger(qt)) {
                // signed integer division uses @divTrunc
                const div_trunc_node = try transCreateNodeBuiltinFnCall(rp.c, "@divTrunc");
                const lhs = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
                try div_trunc_node.params.push(lhs);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                try div_trunc_node.params.push(rhs);
                div_trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &div_trunc_node.base);
            } else {
                // unsigned/float division uses the operator
                const node = try transCreateNodeInfixOp(rp, scope, stmt, .Div, .Slash, "/", true);
                return maybeSuppressResult(rp, scope, result_used, node);
            }
        },
        .Rem => {
            if (!cIsUnsignedInteger(qt)) {
                // signed integer division uses @rem
                const rem_node = try transCreateNodeBuiltinFnCall(rp.c, "@rem");
                const lhs = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
                try rem_node.params.push(lhs);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                try rem_node.params.push(rhs);
                rem_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &rem_node.base);
            } else {
                // unsigned/float division uses the operator
                const node = try transCreateNodeInfixOp(rp, scope, stmt, .Mod, .Percent, "%", true);
                return maybeSuppressResult(rp, scope, result_used, node);
            }
        },
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
            .{op},
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
        else => unreachable,
    }
}

fn transCompoundStmtInline(
    rp: RestorePoint,
    parent_scope: *Scope,
    stmt: *const ZigClangCompoundStmt,
    block_node: *ast.Node.Block,
) TransError!void {
    var it = ZigClangCompoundStmt_body_begin(stmt);
    const end_it = ZigClangCompoundStmt_body_end(stmt);
    while (it != end_it) : (it += 1) {
        const result = try transStmt(rp, parent_scope, it[0], .unused, .r_value);
        if (result != &block_node.base)
            try block_node.statements.push(result);
    }
}

fn transCompoundStmt(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangCompoundStmt) TransError!*ast.Node {
    const block_node = try transCreateNodeBlock(rp.c, null);
    const block_scope = try Scope.Block.init(rp.c, scope, block_node);
    try transCompoundStmtInline(rp, &block_scope.base, stmt, block_node);
    block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    return &block_node.base;
}

fn transCStyleCastExprClass(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCStyleCastExpr,
    result_used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    const sub_expr = ZigClangCStyleCastExpr_getSubExpr(stmt);
    const cast_node = (try transCCast(
        rp,
        scope,
        ZigClangCStyleCastExpr_getBeginLoc(stmt),
        ZigClangCStyleCastExpr_getType(stmt),
        ZigClangExpr_getType(sub_expr),
        try transExpr(rp, scope, sub_expr, .used, lrvalue),
    ));
    return maybeSuppressResult(rp, scope, result_used, cast_node);
}

fn transDeclStmt(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangDeclStmt) TransError!*ast.Node {
    const c = rp.c;
    const block_scope = scope.findBlockScope();

    var it = ZigClangDeclStmt_decl_begin(stmt);
    const end_it = ZigClangDeclStmt_decl_end(stmt);
    while (it != end_it) : (it += 1) {
        switch (ZigClangDecl_getKind(it[0])) {
            .Var => {
                const var_decl = @ptrCast(*const ZigClangVarDecl, it[0]);

                const thread_local_token = if (ZigClangVarDecl_getTLSKind(var_decl) == .None)
                    null
                else
                    try appendToken(c, .Keyword_threadlocal, "threadlocal");
                const qual_type = ZigClangVarDecl_getTypeSourceInfo_getType(var_decl);
                const mut_token = if (ZigClangQualType_isConstQualified(qual_type))
                    try appendToken(c, .Keyword_const, "const")
                else
                    try appendToken(c, .Keyword_var, "var");
                const name = try c.str(ZigClangDecl_getName_bytes_begin(
                    @ptrCast(*const ZigClangDecl, var_decl),
                ));
                const checked_name = if (try scope.createAlias(c, name)) |a| blk: {
                    try block_scope.variables.push(.{ .name = name, .alias = a });
                    break :blk a;
                } else name;
                const name_token = try appendIdentifier(c, checked_name);

                const colon_token = try appendToken(c, .Colon, ":");
                const loc = ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt));
                const type_node = try transQualType(rp, qual_type, loc);

                const eq_token = try appendToken(c, .Equal, "=");
                const init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
                    try transExpr(rp, scope, expr, .used, .r_value)
                else
                    try transCreateNodeUndefinedLiteral(c);
                const semicolon_token = try appendToken(c, .Semicolon, ";");

                const node = try c.a().create(ast.Node.VarDecl);
                node.* = ast.Node.VarDecl{
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
                .{@tagName(kind)},
            ),
        }
    }
    return &block_scope.block_node.base;
}

fn transDeclRefExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangDeclRefExpr,
    lrvalue: LRValue,
) TransError!*ast.Node {
    const value_decl = ZigClangDeclRefExpr_getDecl(expr);
    const name = try rp.c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, value_decl)));
    const checked_name = if (scope.getAlias(name)) |a| a else name;
    if (lrvalue == .l_value) try rp.c.ptr_params.put(checked_name);
    return transCreateNodeIdentifier(rp.c, checked_name);
}

fn transImplicitCastExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangImplicitCastExpr,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const c = rp.c;
    const sub_expr = ZigClangImplicitCastExpr_getSubExpr(expr);
    const sub_expr_node = try transExpr(rp, scope, @ptrCast(*const ZigClangExpr, sub_expr), .used, .r_value);
    switch (ZigClangImplicitCastExpr_getCastKind(expr)) {
        .BitCast => {
            const dest_type = getExprQualType(c, @ptrCast(*const ZigClangExpr, expr));
            const src_type = getExprQualType(c, sub_expr);
            return transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node);
        },
        .IntegralCast => {
            const dest_type = ZigClangExpr_getType(@ptrCast(*const ZigClangExpr, expr));
            const src_type = ZigClangExpr_getType(sub_expr);
            return transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node);
        },
        .FunctionToPointerDecay, .ArrayToPointerDecay => {
            return maybeSuppressResult(rp, scope, result_used, sub_expr_node);
        },
        .LValueToRValue, .NoOp => {
            return transExpr(rp, scope, sub_expr, .used, .r_value);
        },
        .NullToPointer => {
            return transCreateNodeNullLiteral(rp.c);
        },
        else => |kind| return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, expr)),
            "TODO implement translation of CastKind {}",
            .{@tagName(kind)},
        ),
    }
}

fn transIntegerLiteral(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangIntegerLiteral,
    result_used: ResultUsed,
) TransError!*ast.Node {
    var eval_result: ZigClangExprEvalResult = undefined;
    if (!ZigClangIntegerLiteral_EvaluateAsInt(expr, &eval_result, rp.c.clang_context)) {
        const loc = ZigClangIntegerLiteral_getBeginLoc(expr);
        return revertAndWarn(rp, error.UnsupportedTranslation, loc, "invalid integer literal", .{});
    }
    const node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&eval_result.Val));
    return maybeSuppressResult(rp, scope, result_used, node);
}

fn transReturnStmt(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangReturnStmt,
) TransError!*ast.Node {
    const node = try transCreateNodeReturnExpr(rp.c);
    if (ZigClangReturnStmt_getRetValue(expr)) |val_expr| {
        node.rhs = try transExpr(rp, scope, val_expr, .used, .r_value);
    }
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &node.base;
}

fn transStringLiteral(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangStringLiteral,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const kind = ZigClangStringLiteral_getKind(stmt);
    switch (kind) {
        .Ascii, .UTF8 => {
            var len: usize = undefined;
            const bytes_ptr = ZigClangStringLiteral_getString_bytes_begin_size(stmt, &len);
            const str = bytes_ptr[0..len];

            var char_buf: [4]u8 = undefined;
            len = 0;
            for (str) |c| len += escapeChar(c, &char_buf).len;

            const buf = try rp.c.a().alloc(u8, len + "\"\"".len);
            buf[0] = '"';
            writeEscapedString(buf[1..], str);
            buf[buf.len - 1] = '"';

            const token = try appendToken(rp.c, .StringLiteral, buf);
            const node = try rp.c.a().create(ast.Node.StringLiteral);
            node.* = ast.Node.StringLiteral{
                .token = token,
            };
            return maybeSuppressResult(rp, scope, result_used, &node.base);
        },
        .UTF16, .UTF32, .Wide => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)),
            "TODO: support string literal kind {}",
            .{kind},
        ),
        else => unreachable,
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
        else => return std.fmt.bufPrint(char_buf[0..], "\\x{x:2}", .{c}) catch unreachable,
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
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
        try cast_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrToInt");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        try cast_node.params.push(&builtin_node.base);
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
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
    const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
    try cast_node.params.push(try transQualType(rp, dst_type, loc));
    _ = try appendToken(rp.c, .Comma, ",");
    try cast_node.params.push(expr);
    cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return &cast_node.base;
}

fn transExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangExpr,
    used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    return transStmt(rp, scope, @ptrCast(*const ZigClangStmt, expr), used, lrvalue);
}

fn transInitListExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangInitListExpr,
    used: ResultUsed,
) TransError!*ast.Node {
    const qt = getExprQualType(rp.c, @ptrCast(*const ZigClangExpr, expr));
    const qual_type = ZigClangQualType_getTypePtr(qt);
    const source_loc = ZigClangExpr_getBeginLoc(@ptrCast(*const ZigClangExpr, expr));
    switch (ZigClangType_getTypeClass(qual_type)) {
        .ConstantArray => {},
        .Record, .Elaborated => {
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "TODO initListExpr for structs", .{});
        },
        else => {
            const type_name = rp.c.str(ZigClangType_getTypeClassName(qual_type));
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported initlist type: '{}'", .{type_name});
        },
    }

    const arr_type = ZigClangType_getAsArrayTypeUnsafe(qual_type);
    const child_qt = ZigClangArrayType_getElementType(arr_type);
    const init_count = ZigClangInitListExpr_getNumInits(expr);
    const const_arr_ty = @ptrCast(*const ZigClangConstantArrayType, qual_type);
    const size_ap_int = ZigClangConstantArrayType_getSize(const_arr_ty);
    const all_count = ZigClangAPInt_getLimitedValue(size_ap_int, std.math.maxInt(usize));
    const leftover_count = all_count - init_count;

    var init_node: *ast.Node.SuffixOp = undefined;
    var cat_tok: ast.TokenIndex = undefined;
    if (init_count != 0) {
        const dot_tok = try appendToken(rp.c, .Period, ".");
        init_node = try transCreateNodeArrayInitializer(rp.c, dot_tok);
        var i: c_uint = 0;
        while (i < init_count) : (i += 1) {
            const elem_expr = ZigClangInitListExpr_getInit(expr, i);
            try init_node.op.ArrayInitializer.push(try transExpr(rp, scope, elem_expr, .used, .r_value));
            _ = try appendToken(rp.c, .Comma, ",");
        }
        init_node.rtoken = try appendToken(rp.c, .RBrace, "}");
        if (leftover_count == 0) {
            return &init_node.base;
        }
        cat_tok = try appendToken(rp.c, .PlusPlus, "++");
    }

    const dot_tok = try appendToken(rp.c, .Period, ".");
    var filler_init_node = try transCreateNodeArrayInitializer(rp.c, dot_tok);
    const filler_val_expr = ZigClangInitListExpr_getArrayFiller(expr);
    try filler_init_node.op.ArrayInitializer.push(try transExpr(rp, scope, filler_val_expr, .used, .r_value));
    filler_init_node.rtoken = try appendToken(rp.c, .RBrace, "}");

    const rhs_node = if (leftover_count == 1)
        &filler_init_node.base
    else blk: {
        const mul_tok = try appendToken(rp.c, .AsteriskAsterisk, "**");
        const mul_node = try rp.c.a().create(ast.Node.InfixOp);
        mul_node.* = .{
            .op_token = mul_tok,
            .lhs = &filler_init_node.base,
            .op = .ArrayMult,
            .rhs = try transCreateNodeInt(rp.c, leftover_count),
        };
        break :blk &mul_node.base;
    };

    if (init_count == 0) {
        return rhs_node;
    }

    const cat_node = try rp.c.a().create(ast.Node.InfixOp);
    cat_node.* = .{
        .op_token = cat_tok,
        .lhs = &init_node.base,
        .op = .ArrayCat,
        .rhs = rhs_node,
    };
    return &cat_node.base;
}

fn transImplicitValueInitExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangExpr,
    used: ResultUsed,
) TransError!*ast.Node {
    const source_loc = ZigClangExpr_getBeginLoc(expr);
    const qt = getExprQualType(rp.c, expr);
    const ty = ZigClangQualType_getTypePtr(qt);
    const node = switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => blk: {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Bool => return transCreateNodeBoolLiteral(rp.c, false),
                .Char_U,
                .UChar,
                .Char_S,
                .Char8,
                .SChar,
                .UShort,
                .UInt,
                .ULong,
                .ULongLong,
                .Short,
                .Int,
                .Long,
                .LongLong,
                .UInt128,
                .Int128,
                .Float,
                .Double,
                .Float128,
                .Float16,
                .LongDouble,
                => return transCreateNodeInt(rp.c, 0),
                else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported builtin type", .{}),
            }
        },
        .Pointer => return transCreateNodeNullLiteral(rp.c),
        else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "type does not have an implicit init value", .{}),
    };
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
    result: *ast.Node,
) TransError!*ast.Node {
    if (used == .used) return result;
    // NOTE: This is backwards, but the semicolon must immediately follow the node.
    _ = try appendToken(rp.c, .Semicolon, ";");
    const lhs = try transCreateNodeIdentifier(rp.c, "_");
    const op_token = try appendToken(rp.c, .Equal, "=");
    const op_node = try rp.c.a().create(ast.Node.InfixOp);
    op_node.* = ast.Node.InfixOp{
        .op_token = op_token,
        .lhs = lhs,
        .op = .Assign,
        .rhs = result,
    };
    return &op_node.base;
}

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: *ast.Node) !void {
    try c.tree.root_node.decls.push(decl_node);
    _ = try c.global_scope.sym_table.put(name, decl_node);
}

fn transQualType(rp: RestorePoint, qt: ZigClangQualType, source_loc: ZigClangSourceLocation) TypeError!*ast.Node {
    return transType(rp, ZigClangQualType_getTypePtr(qt), source_loc);
}

fn transRecordDecl(c: *Context, record_decl: *const ZigClangRecordDecl) TypeError!*ast.Node {
    const rp = makeRestorePoint(c);

    const record_loc = ZigClangRecordDecl_getLocation(record_decl);

    var container_kind_name: []const u8 = undefined;
    var container_kind: std.zig.Token.Id = undefined;

    if (ZigClangRecordDecl_isUnion(record_decl)) {
        container_kind_name = "union";
        container_kind = .Keyword_union;
    } else if (ZigClangRecordDecl_isStruct(record_decl)) {
        container_kind_name = "struct";
        container_kind = .Keyword_struct;
    } else {
        return revertAndWarn(
            rp,
            error.UnsupportedType,
            record_loc,
            "unsupported record type",
            .{},
        );
    }

    const record_def = ZigClangRecordDecl_getDefinition(record_decl) orelse {
        return transCreateNodeOpaqueType(c);
    };

    const extern_tok = try appendToken(c, .Keyword_extern, "extern");
    const container_tok = try appendToken(c, container_kind, container_kind_name);
    const lbrace_token = try appendToken(c, .LBrace, "{");

    const container_node = try c.a().create(ast.Node.ContainerDecl);
    container_node.* = .{
        .layout_token = extern_tok,
        .kind_token = container_tok,
        .init_arg_expr = .None,
        .fields_and_decls = ast.Node.ContainerDecl.DeclList.init(c.a()),
        .lbrace_token = lbrace_token,
        .rbrace_token = undefined,
    };

    var it = ZigClangRecordDecl_field_begin(record_def);
    const end_it = ZigClangRecordDecl_field_end(record_def);
    while (ZigClangRecordDecl_field_iterator_neq(it, end_it)) : (it = ZigClangRecordDecl_field_iterator_next(it)) {
        const field_decl = ZigClangRecordDecl_field_iterator_deref(it);
        const field_loc = ZigClangFieldDecl_getLocation(field_decl);

        if (ZigClangFieldDecl_isBitField(field_decl)) {
            rp.activate();
            const node = try transCreateNodeOpaqueType(c);
            try emitWarning(c, field_loc, "{} demoted to opaque type - has bitfield", .{container_kind_name});
            return node;
        }

        const field_name = try appendIdentifier(c, try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, field_decl))));
        _ = try appendToken(c, .Colon, ":");
        const field_type = try transQualType(rp, ZigClangFieldDecl_getType(field_decl), field_loc);

        const field_node = try c.a().create(ast.Node.ContainerField);
        field_node.* = .{
            .doc_comments = null,
            .comptime_token = null,
            .name_token = field_name,
            .type_expr = field_type,
            .value_expr = null,
            .align_expr = null,
        };

        try container_node.fields_and_decls.push(&field_node.base);
        _ = try appendToken(c, .Comma, ",");
    }

    container_node.rbrace_token = try appendToken(c, .RBrace, "}");
    return &container_node.base;
}

fn transEnumDecl(c: *Context, enum_decl: *const ZigClangEnumDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)))) |name|
        return try transCreateNodeIdentifier(c, name.value); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const enum_loc = ZigClangEnumDecl_getLocation(enum_decl);

    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const const_tok = try appendToken(c, .Keyword_const, "const");

    var bare_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, enum_decl)));
    var is_unnamed = false;
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.a(), "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    const name = try std.fmt.allocPrint(c.a(), "enum_{}", .{bare_name});
    _ = try c.decl_table.put(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)), name);
    const name_tok = try appendIdentifier(c, name);
    const eq_tok = try appendToken(c, .Equal, "=");

    const init_node = if (ZigClangEnumDecl_getDefinition(enum_decl)) |enum_def| blk: {
        var pure_enum = true;
        var it = ZigClangEnumDecl_enumerator_begin(enum_def);
        var end_it = ZigClangEnumDecl_enumerator_end(enum_def);
        while (ZigClangEnumDecl_enumerator_iterator_neq(it, end_it)) : (it = ZigClangEnumDecl_enumerator_iterator_next(it)) {
            const enum_const = ZigClangEnumDecl_enumerator_iterator_deref(it);
            if (ZigClangEnumConstantDecl_getInitExpr(enum_const)) |_| {
                pure_enum = false;
                break;
            }
        }

        const extern_tok = try appendToken(c, .Keyword_extern, "extern");
        const container_tok = try appendToken(c, .Keyword_enum, "enum");

        const container_node = try c.a().create(ast.Node.ContainerDecl);
        container_node.* = .{
            .layout_token = extern_tok,
            .kind_token = container_tok,
            .init_arg_expr = .None,
            .fields_and_decls = ast.Node.ContainerDecl.DeclList.init(c.a()),
            .lbrace_token = undefined,
            .rbrace_token = undefined,
        };

        const int_type = ZigClangEnumDecl_getIntegerType(enum_decl);

        // TODO only emit this tag type if the enum tag type is not the default.
        // I don't know what the default is, need to figure out how clang is deciding.
        // it appears to at least be different across gcc/msvc
        if (!isCBuiltinType(int_type, .UInt) and
            !isCBuiltinType(int_type, .Int))
        {
            _ = try appendToken(c, .LParen, "(");
            container_node.init_arg_expr = .{
                .Type = transQualType(rp, int_type, enum_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        if (is_unnamed) {
                            try emitWarning(c, enum_loc, "unable to translate enum tag type", .{});
                        } else {
                            try failDecl(c, enum_loc, name, "unable to translate enum tag type", .{});
                        }
                        return null;
                    },
                    else => |e| return e,
                },
            };
            _ = try appendToken(c, .RParen, ")");
        }

        container_node.lbrace_token = try appendToken(c, .LBrace, "{");

        it = ZigClangEnumDecl_enumerator_begin(enum_def);
        end_it = ZigClangEnumDecl_enumerator_end(enum_def);
        while (ZigClangEnumDecl_enumerator_iterator_neq(it, end_it)) : (it = ZigClangEnumDecl_enumerator_iterator_next(it)) {
            const enum_const = ZigClangEnumDecl_enumerator_iterator_deref(it);

            const enum_val_name = try c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, enum_const)));

            const field_name = if (!is_unnamed and std.mem.startsWith(u8, enum_val_name, bare_name))
                enum_val_name[bare_name.len..]
            else
                enum_val_name;

            const field_name_tok = try appendIdentifier(c, field_name);

            const int_node = if (!pure_enum) blk: {
                _ = try appendToken(c, .Colon, "=");
                break :blk try transCreateNodeAPInt(c, ZigClangEnumConstantDecl_getInitVal(enum_const));
            } else
                null;

            const field_node = try c.a().create(ast.Node.ContainerField);
            field_node.* = .{
                .doc_comments = null,
                .comptime_token = null,
                .name_token = field_name_tok,
                .type_expr = null,
                .value_expr = int_node,
                .align_expr = null,
            };

            try container_node.fields_and_decls.push(&field_node.base);
            _ = try appendToken(c, .Comma, ",");
            // In C each enum value is in the global namespace. So we put them there too.
            // At this point we can rely on the enum emitting successfully.
            try addEnumTopLevel(c, name, field_name, enum_val_name);
        }
        container_node.rbrace_token = try appendToken(c, .RBrace, "}");

        break :blk &container_node.base;
    } else
        try transCreateNodeOpaqueType(c);

    const semicolon_token = try appendToken(c, .Semicolon, ";");

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .visib_token = visib_tok,
        .mut_token = const_tok,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .init_node = init_node,
        .semicolon_token = semicolon_token,
        .doc_comments = null,
        .comptime_token = null,
        .extern_export_token = null,
        .thread_local_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
    };

    try addTopLevelDecl(c, name, &node.base);
    if (!is_unnamed)
        try c.alias_list.push(.{ .alias = bare_name, .name = name });
    return transCreateNodeIdentifier(c, name);
}

fn addEnumTopLevel(c: *Context, enum_name: []const u8, field_name: []const u8, enum_val_name: []const u8) !void {
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const const_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, enum_val_name);
    const eq_tok = try appendToken(c, .Equal, "=");

    const enum_ident = try transCreateNodeIdentifier(c, enum_name);
    const period_tok = try appendToken(c, .Period, ".");
    const field_ident = try transCreateNodeIdentifier(c, field_name);

    const field_access_node = try c.a().create(ast.Node.InfixOp);
    field_access_node.* = .{
        .op_token = period_tok,
        .lhs = enum_ident,
        .op = .Period,
        .rhs = field_ident,
    };
    const semicolon_token = try appendToken(c, .Semicolon, ";");

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .visib_token = visib_tok,
        .mut_token = const_tok,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .init_node = &field_access_node.base,
        .semicolon_token = semicolon_token,
        .thread_local_token = null,
        .doc_comments = null,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
    };

    try addTopLevelDecl(c, field_name, &node.base);
}

fn isCBuiltinType(qt: ZigClangQualType, kind: ZigClangBuiltinTypeKind) bool {
    const c_type = qualTypeCanon(qt);
    if (ZigClangType_getTypeClass(c_type) != .Builtin)
        return false;
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return ZigClangBuiltinType_getKind(builtin_ty) == kind;
}

fn qualTypeIsPtr(qt: ZigClangQualType) bool {
    return ZigClangType_getTypeClass(qualTypeCanon(qt)) == .Pointer;
}

fn qualTypeChildIsFnProto(qt: ZigClangQualType) bool {
    const ty = ZigClangQualType_getTypePtr(qt);

    switch (ZigClangType_getTypeClass(ty)) {
        .FunctionProto, .FunctionNoProto => return true,
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const ZigClangElaboratedType, ty);
            return qualTypeChildIsFnProto(ZigClangElaboratedType_getNamedType(elaborated_ty));
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);
            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            return qualTypeChildIsFnProto(ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl));
        },
        .Paren => {
            const paren_type = @ptrCast(*const ZigClangParenType, ty);
            const inner_type = ZigClangParenType_getInnerType(paren_type);
            return ZigClangQualType_getTypeClass(inner_type) == .FunctionProto;
        },
        .Attributed => {
            const attr_type = @ptrCast(*const ZigClangAttributedType, ty);
            return qualTypeChildIsFnProto(ZigClangAttributedType_getEquivalentType(attr_type));
        },
        else => return false,
    }
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
            const record_def = ZigClangRecordDecl_getDefinition(record_decl) orelse
                return true;
            var it = ZigClangRecordDecl_field_begin(record_def);
            const end_it = ZigClangRecordDecl_field_end(record_def);
            while (ZigClangRecordDecl_field_iterator_neq(it, end_it)) : (it = ZigClangRecordDecl_field_iterator_next(it)) {
                const field_decl = ZigClangRecordDecl_field_iterator_deref(it);

                if (ZigClangFieldDecl_isBitField(field_decl)) {
                    return true;
                }
            }
            return false;
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
        node.* = .{
            .op_token = eq_token,
            .lhs = lhs_node,
            .op = .Assign,
            .rhs = rhs_node,
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
    return revertAndWarn(
        rp,
        error.UnsupportedTranslation,
        ZigClangExpr_getBeginLoc(lhs),
        "TODO: worst case assign op expr",
        .{},
    );
}

fn transCreateNodeBuiltinFnCall(c: *Context, name: []const u8) !*ast.Node.BuiltinCall {
    const builtin_token = try appendToken(c, .Builtin, name);
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.BuiltinCall);
    node.* = ast.Node.BuiltinCall{
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
        .lhs = .{ .node = fn_expr },
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
        .op_token = op_token,
        .lhs = lhs,
        .op = op,
        .rhs = rhs,
    };
    if (!grouped) return &node.base;
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = ast.Node.GroupedExpression{
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
) !*ast.Node.PrefixOp {
    const node = try c.a().create(ast.Node.PrefixOp);
    const op_token = switch (op_tok_id) {
        .LBracket => blk: {
            const lbracket = try appendToken(c, .LBracket, "[");
            _ = try appendToken(c, .Asterisk, "*");
            _ = try appendToken(c, .RBracket, "]");
            break :blk lbracket;
        },
        .Identifier => blk: {
            const lbracket = try appendToken(c, .LBracket, "["); // Rendering checks if this token + 2 == .Identifier, so needs to return this token
            _ = try appendToken(c, .Asterisk, "*");
            _ = try appendIdentifier(c, "c");
            _ = try appendToken(c, .RBracket, "]");
            break :blk lbracket;
        },
        .Asterisk => try appendToken(c, .Asterisk, "*"),
        else => unreachable,
    };
    node.* = ast.Node.PrefixOp{
        .op_token = op_token,
        .op = ast.Node.PrefixOp.Op{
            .PtrType = .{
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
    var i: @TypeOf(num_limbs) = 0;
    while (i < num_limbs) : (i += 1) big.limbs[i] = data[i];
    const str = big.toString(c.a(), 10) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
    const token = try appendToken(c, .IntegerLiteral, str);
    const node = try c.a().create(ast.Node.IntegerLiteral);
    node.* = ast.Node.IntegerLiteral{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeReturnExpr(c: *Context) !*ast.Node.ControlFlowExpression {
    const ltoken = try appendToken(c, .Keyword_return, "return");
    const node = try c.a().create(ast.Node.ControlFlowExpression);
    node.* = ast.Node.ControlFlowExpression{
        .ltoken = ltoken,
        .kind = .Return,
        .rhs = null,
    };
    return node;
}

fn transCreateNodeUndefinedLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_undefined, "undefined");
    const node = try c.a().create(ast.Node.UndefinedLiteral);
    node.* = ast.Node.UndefinedLiteral{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeNullLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_null, "null");
    const node = try c.a().create(ast.Node.NullLiteral);
    node.* = ast.Node.NullLiteral{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeBoolLiteral(c: *Context, value: bool) !*ast.Node {
    const token = if (value)
        try appendToken(c, .Keyword_true, "true")
    else
        try appendToken(c, .Keyword_false, "false");
    const node = try c.a().create(ast.Node.BoolLiteral);
    node.* = ast.Node.BoolLiteral{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeArrayInitializer(c: *Context, dot_tok: ast.TokenIndex) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LBrace, "{");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = ast.Node.SuffixOp{
        .lhs = .{ .dot = dot_tok },
        .op = .{
            .ArrayInitializer = ast.Node.SuffixOp.Op.InitList.init(c.a()),
        },
        .rtoken = undefined, // set after appending values
    };
    return node;
}

fn transCreateNodeInt(c: *Context, int: var) !*ast.Node {
    const token = try appendTokenFmt(c, .IntegerLiteral, "{}", .{int});
    const node = try c.a().create(ast.Node.IntegerLiteral);
    node.* = ast.Node.IntegerLiteral{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeFloat(c: *Context, int: var) !*ast.Node {
    const token = try appendTokenFmt(c, .FloatLiteral, "{}", .{int});
    const node = try c.a().create(ast.Node.FloatLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeOpaqueType(c: *Context) !*ast.Node {
    const call_node = try transCreateNodeBuiltinFnCall(c, "@OpaqueType");
    call_node.rparen_token = try appendToken(c, .RParen, ")");
    return &call_node.base;
}

fn transCreateNodeMacroFn(c: *Context, name: []const u8, ref: *ast.Node, proto_alias_node: *ast.Node) !*ast.Node {
    const scope = &c.global_scope.base;

    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const inline_tok = try appendToken(c, .Keyword_inline, "inline");
    const fn_tok = try appendToken(c, .Keyword_fn, "fn");
    const name_tok = try appendIdentifier(c, name);
    _ = try appendToken(c, .LParen, "(");

    const proto_alias = proto_alias_node.cast(ast.Node.FnProto).?;

    var fn_params = ast.Node.FnProto.ParamList.init(c.a());
    var it = proto_alias.params.iterator(0);
    while (it.next()) |pn| {
        if (it.index != 0) {
            _ = try appendToken(c, .Comma, ",");
        }
        const param = pn.*.cast(ast.Node.ParamDecl).?;

        const param_name_tok = param.name_token orelse
            try appendTokenFmt(c, .Identifier, "arg_{}", .{c.getMangle()});

        _ = try appendToken(c, .Colon, ":");

        const param_node = try c.a().create(ast.Node.ParamDecl);
        param_node.* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = param.noalias_token,
            .name_token = param_name_tok,
            .type_node = param.type_node,
            .var_args_token = null,
        };
        try fn_params.push(&param_node.base);
    }

    _ = try appendToken(c, .RParen, ")");

    const fn_proto = try c.a().create(ast.Node.FnProto);
    fn_proto.* = .{
        .doc_comments = null,
        .visib_token = pub_tok,
        .fn_token = fn_tok,
        .name_token = name_tok,
        .params = fn_params,
        .return_type = proto_alias.return_type,
        .var_args_token = null,
        .extern_export_inline_token = inline_tok,
        .cc_token = null,
        .body_node = null,
        .lib_name = null,
        .align_expr = null,
        .section_expr = null,
    };

    const block = try transCreateNodeBlock(c, null);

    const return_expr = try transCreateNodeReturnExpr(c);
    const unwrap_expr = try transCreateNodeUnwrapNull(c, ref.cast(ast.Node.VarDecl).?.init_node.?);
    const call_expr = try transCreateNodeFnCall(c, unwrap_expr);
    it = fn_params.iterator(0);
    while (it.next()) |pn| {
        if (it.index != 0) {
            _ = try appendToken(c, .Comma, ",");
        }
        const param = pn.*.cast(ast.Node.ParamDecl).?;
        try call_expr.op.Call.params.push(try transCreateNodeIdentifier(c, tokenSlice(c, param.name_token.?)));
    }
    call_expr.rtoken = try appendToken(c, .RParen, ")");
    return_expr.rhs = &call_expr.base;
    _ = try appendToken(c, .Semicolon, ";");

    block.rbrace = try appendToken(c, .RBrace, "}");
    try block.statements.push(&return_expr.base);
    fn_proto.body_node = &block.base;
    return &fn_proto.base;
}

fn transCreateNodeUnwrapNull(c: *Context, wrapped: *ast.Node) !*ast.Node {
    _ = try appendToken(c, .Period, ".");
    const qm = try appendToken(c, .QuestionMark, "?");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = .{
        .op = .UnwrapOptional,
        .lhs = .{ .node = wrapped },
        .rtoken = qm,
    };
    return &node.base;
}

fn transCreateNodeEnumLiteral(c: *Context, name: []const u8) !*ast.Node {
    const node = try c.a().create(ast.Node.EnumLiteral);
    node.* = .{
        .dot = try appendToken(c, .Period, "."),
        .name = try appendIdentifier(c, name),
    };
    return &node.base;
}

fn transCreateNodeIf(c: *Context) !*ast.Node.If {
    const if_tok = try appendToken(c, .Keyword_if, "if");
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.If);
    node.* = .{
        .if_token = if_tok,
        .condition = undefined,
        .payload = null,
        .body = undefined,
        .@"else" = null,
    };
    return node;
}

fn transCreateNodeElse(c: *Context) !*ast.Node.Else {
    const node = try c.a().create(ast.Node.Else);
    node.* = .{
        .else_token = try appendToken(c, .Keyword_else, "else"),
        .payload = null,
        .body = undefined,
    };
    return node;
}

fn transCreateNodeBlock(c: *Context, label: ?[]const u8) !*ast.Node.Block {
    const label_node = if (label) |l| blk: {
        const ll = try appendIdentifier(c, l);
        _ = try appendToken(c, .Colon, ":");
        break :blk ll;
    } else null;
    const block_node = try c.a().create(ast.Node.Block);
    block_node.* = .{
        .label = label_node,
        .lbrace = try appendToken(c, .LBrace, "{"),
        .statements = ast.Node.Block.StatementList.init(c.a()),
        .rbrace = undefined,
    };
    return block_node;
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
            return transCreateNodeIdentifier(rp.c, switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Void => "c_void",
                .Bool => "bool",
                .Char_U, .UChar, .Char_S, .Char8 => "u8",
                .SChar => "i8",
                .UShort => "c_ushort",
                .UInt => "c_uint",
                .ULong => "c_ulong",
                .ULongLong => "c_ulonglong",
                .Short => "c_short",
                .Int => "c_int",
                .Long => "c_long",
                .LongLong => "c_longlong",
                .UInt128 => "u128",
                .Int128 => "i128",
                .Float => "f32",
                .Double => "f64",
                .Float128 => "f128",
                .Float16 => "f16",
                .LongDouble => "c_longdouble",
                else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported builtin type", .{}),
            });
        },
        .FunctionProto => {
            const fn_proto_ty = @ptrCast(*const ZigClangFunctionProtoType, ty);
            const fn_proto = try transFnProto(rp, null, fn_proto_ty, source_loc, null, false);
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
                );
                optional_node.rhs = &pointer_node.base;
                pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            const pointer_node = try transCreateNodePtrType(
                rp.c,
                ZigClangQualType_isConstQualified(child_qt),
                ZigClangQualType_isVolatileQualified(child_qt),
                .Identifier,
            );
            pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
            return &pointer_node.base;
        },
        .ConstantArray => {
            const const_arr_ty = @ptrCast(*const ZigClangConstantArrayType, ty);

            const size_ap_int = ZigClangConstantArrayType_getSize(const_arr_ty);
            const size = ZigClangAPInt_getLimitedValue(size_ap_int, std.math.maxInt(usize));
            var node = try transCreateNodePrefixOp(
                rp.c,
                .{
                    .ArrayType = .{
                        .len_expr = undefined,
                        .sentinel = null,
                    },
                },
                .LBracket,
                "[",
            );
            node.op.ArrayType.len_expr = try transCreateNodeInt(rp.c, size);
            _ = try appendToken(rp.c, .RBracket, "]");
            node.rhs = try transQualType(rp, ZigClangConstantArrayType_getElementType(const_arr_ty), source_loc);
            return &node.base;
        },
        .IncompleteArray => {
            const incomplete_array_ty = @ptrCast(*const ZigClangIncompleteArrayType, ty);

            const child_qt = ZigClangIncompleteArrayType_getElementType(incomplete_array_ty);
            var node = try transCreateNodePtrType(
                rp.c,
                ZigClangQualType_isConstQualified(child_qt),
                ZigClangQualType_isVolatileQualified(child_qt),
                .Identifier,
            );
            node.rhs = try transQualType(rp, child_qt, source_loc);
            return &node.base;
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);

            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            const typedef_name = try rp.c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, typedef_decl)));
            return transCreateNodeIdentifier(rp.c, typedef_name);
        },
        .Record => {
            const record_ty = @ptrCast(*const ZigClangRecordType, ty);

            // TODO this sould get the name from decl_table
            // struct Foo {
            //     struct Bar{
            //         int b;
            //     };
            //     struct Bar c;
            // };
            const record_decl = ZigClangRecordType_getDecl(record_ty);
            if (try getContainerName(rp, record_decl)) |name|
                return transCreateNodeIdentifier(rp.c, name)
            else
                return transRecordDecl(rp.c, record_decl);
        },
        .Enum => {
            const enum_ty = @ptrCast(*const ZigClangEnumType, ty);

            const enum_decl = ZigClangEnumType_getDecl(enum_ty);
            return (try transEnumDecl(rp.c, enum_decl)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to translate enum declaration", .{});
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const ZigClangElaboratedType, ty);
            return transQualType(rp, ZigClangElaboratedType_getNamedType(elaborated_ty), source_loc);
        },
        .Decayed => {
            const decayed_ty = @ptrCast(*const ZigClangDecayedType, ty);
            return transQualType(rp, ZigClangDecayedType_getDecayedType(decayed_ty), source_loc);
        },
        .Attributed => {
            const attributed_ty = @ptrCast(*const ZigClangAttributedType, ty);
            return transQualType(rp, ZigClangAttributedType_getEquivalentType(attributed_ty), source_loc);
        },
        else => {
            const type_name = rp.c.str(ZigClangType_getTypeClassName(ty));
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported type: '{}'", .{type_name});
        },
    }
}

fn getContainerName(rp: RestorePoint, record_decl: *const ZigClangRecordDecl) !?[]const u8 {
    const bare_name = try rp.c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, record_decl)));

    const container_kind_name = if (ZigClangRecordDecl_isUnion(record_decl))
        "union"
    else if (ZigClangRecordDecl_isStruct(record_decl))
        "struct"
    else
        return revertAndWarn(rp, error.UnsupportedType, ZigClangRecordDecl_getLocation(record_decl), "record {} is not a struct or union", .{bare_name});

    if (ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl) or bare_name.len == 0)
        return null;

    return try std.fmt.allocPrint(rp.c.a(), "{}_{}", .{ container_kind_name, bare_name });
}

fn isCVoid(qt: ZigClangQualType) bool {
    const ty = ZigClangQualType_getTypePtr(qt);
    if (ZigClangType_getTypeClass(ty) == .Builtin) {
        const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
        return ZigClangBuiltinType_getKind(builtin_ty) == .Void;
    }
    return false;
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
        else => return revertAndWarn(
            rp,
            error.UnsupportedType,
            source_loc,
            "unsupported calling convention: {}",
            .{@tagName(clang_cc)},
        ),
    }
}

fn transFnProto(
    rp: RestorePoint,
    fn_decl: ?*const ZigClangFunctionDecl,
    fn_proto_ty: *const ZigClangFunctionProtoType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Node.FnProto {
    const fn_ty = @ptrCast(*const ZigClangFunctionType, fn_proto_ty);
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = ZigClangFunctionProtoType_isVariadic(fn_proto_ty);
    return finishTransFnProto(rp, fn_decl, fn_proto_ty, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
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
    return finishTransFnProto(rp, null, null, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn finishTransFnProto(
    rp: RestorePoint,
    fn_decl: ?*const ZigClangFunctionDecl,
    fn_proto_ty: ?*const ZigClangFunctionProtoType,
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

    var fndef_scope = Scope.FnDef.init(rp.c);
    const scope = &fndef_scope.base;

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
    const name_tok = if (fn_decl_context) |ctx| try appendIdentifier(rp.c, ctx.fn_name) else null;
    const lparen_tok = try appendToken(rp.c, .LParen, "(");

    var fn_params = ast.Node.FnProto.ParamList.init(rp.c.a());
    const param_count: usize = if (fn_proto_ty != null) ZigClangFunctionProtoType_getNumParams(fn_proto_ty.?) else 0;

    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        const param_qt = ZigClangFunctionProtoType_getParamType(fn_proto_ty.?, @intCast(c_uint, i));

        const noalias_tok = if (ZigClangQualType_isRestrictQualified(param_qt)) try appendToken(rp.c, .Keyword_noalias, "noalias") else null;

        const param_name_tok: ?ast.TokenIndex = blk: {
            if (fn_decl != null) {
                const param = ZigClangFunctionDecl_getParamDecl(fn_decl.?, @intCast(c_uint, i));
                var param_name: []const u8 = try rp.c.str(ZigClangDecl_getName_bytes_begin(@ptrCast(*const ZigClangDecl, param)));
                if (param_name.len < 1)
                    param_name = "arg"[0..];
                const checked_param_name = if (try scope.createAlias(rp.c, param_name)) |a| blk: {
                    try fndef_scope.params.push(.{ .name = param_name, .alias = a });
                    break :blk a;
                } else param_name;

                const result = try appendIdentifier(rp.c, checked_param_name);
                _ = try appendToken(rp.c, .Colon, ":");
                break :blk result;
            }
            break :blk null;
        };

        const type_node = try transQualType(rp, param_qt, source_loc);

        const param_node = try rp.c.a().create(ast.Node.ParamDecl);
        param_node.* = ast.Node.ParamDecl{
            .base = ast.Node{ .id = ast.Node.Id.ParamDecl },
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = noalias_tok,
            .name_token = param_name_tok,
            .type_node = type_node,
            .var_args_token = null,
        };
        try fn_params.push(&param_node.base);

        if (i + 1 < param_count) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
    }

    if (is_var_args) {
        if (param_count > 0) {
            _ = try appendToken(rp.c, .Comma, ",");
        }

        const var_arg_node = try rp.c.a().create(ast.Node.ParamDecl);
        var_arg_node.* = ast.Node.ParamDecl{
            .base = ast.Node{ .id = ast.Node.Id.ParamDecl },
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = null,
            .name_token = null,
            .type_node = undefined, // Note: Accessing this causes an access violation. Need to check .var_args_token first before trying this field
            .var_args_token = try appendToken(rp.c, .Ellipsis3, "..."),
        };
        try fn_params.push(&var_arg_node.base);
    }

    const rparen_tok = try appendToken(rp.c, .RParen, ")");

    const return_type_node = blk: {
        if (ZigClangFunctionType_getNoReturnAttr(fn_ty)) {
            break :blk try transCreateNodeIdentifier(rp.c, "noreturn");
        } else {
            const return_qt = ZigClangFunctionType_getReturnType(fn_ty);
            if (isCVoid(return_qt)) {
                // convert primitive c_void to actual void (only for return type)
                break :blk try transCreateNodeIdentifier(rp.c, "void");
            } else {
                break :blk transQualType(rp, return_qt, source_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try emitWarning(rp.c, source_loc, "unsupported function proto return type", .{});
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
        .params = fn_params,
        .return_type = ast.Node.FnProto.ReturnType{ .Explicit = return_type_node },
        .var_args_token = null, // TODO this field is broken in the AST data model
        .extern_export_inline_token = extern_export_inline_tok,
        .cc_token = cc_tok,
        .body_node = null,
        .lib_name = null,
        .align_expr = null,
        .section_expr = null,
    };
    return fn_proto;
}

fn revertAndWarn(
    rp: RestorePoint,
    err: var,
    source_loc: ZigClangSourceLocation,
    comptime format: []const u8,
    args: var,
) (@TypeOf(err) || error{OutOfMemory}) {
    rp.activate();
    try emitWarning(rp.c, source_loc, format, args);
    return err;
}

fn emitWarning(c: *Context, loc: ZigClangSourceLocation, comptime format: []const u8, args: var) !void {
    const args_prefix = .{c.locStr(loc)};
    _ = try appendTokenFmt(c, .LineComment, "// {}: warning: " ++ format, args_prefix ++ args);
}

fn failDecl(c: *Context, loc: ZigClangSourceLocation, name: []const u8, comptime format: []const u8, args: var) !void {
    // const name = @compileError(msg);
    const const_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);
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
    try addTopLevelDecl(c, name, &var_decl_node.base);
}

fn appendToken(c: *Context, token_id: Token.Id, bytes: []const u8) !ast.TokenIndex {
    std.debug.assert(token_id != .Identifier); // use appendIdentifier
    return appendTokenFmt(c, token_id, "{}", .{bytes});
}

fn appendTokenFmt(c: *Context, token_id: Token.Id, comptime format: []const u8, args: var) !ast.TokenIndex {
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

fn isValidZigIdentifier(name: []const u8) bool {
    for (name) |c, i| {
        switch (c) {
            '_', 'a'...'z', 'A'...'Z' => {},
            '0'...'9' => if (i == 0) return false,
            else => return false,
        }
    }
    return true;
}

fn appendIdentifier(c: *Context, name: []const u8) !ast.TokenIndex {
    if (!isValidZigIdentifier(name) or std.zig.Token.getKeyword(name) != null) {
        return appendTokenFmt(c, .Identifier, "@\"{}\"", .{name});
    } else {
        return appendTokenFmt(c, .Identifier, "{}", .{name});
    }
}

fn transCreateNodeIdentifier(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendIdentifier(c, name);
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

fn transPreprocessorEntities(c: *Context, unit: *ZigClangASTUnit) Error!void {
    // TODO if we see #undef, delete it from the table
    var it = ZigClangASTUnit_getLocalPreprocessingEntities_begin(unit);
    const it_end = ZigClangASTUnit_getLocalPreprocessingEntities_end(unit);
    var tok_list = ctok.TokenList.init(c.a());
    const scope = &c.global_scope.base;

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = ZigClangPreprocessingRecord_iterator_deref(it);
        tok_list.shrink(0);
        switch (ZigClangPreprocessedEntity_getKind(entity)) {
            .MacroDefinitionKind => {
                const macro = @ptrCast(*ZigClangMacroDefinitionRecord, entity);
                const raw_name = ZigClangMacroDefinitionRecord_getName_getNameStart(macro);
                const begin_loc = ZigClangMacroDefinitionRecord_getSourceRange_getBegin(macro);

                const name = try c.str(raw_name);
                if (scope.contains(name)) {
                    continue;
                }
                const begin_c = ZigClangSourceManager_getCharacterData(c.source_manager, begin_loc);
                ctok.tokenizeCMacro(&tok_list, begin_c) catch |err| switch (err) {
                    error.OutOfMemory => |e| return e,
                    else => {
                        try failDecl(c, begin_loc, name, "unable to tokenize macro definition", .{});
                        continue;
                    },
                };

                var tok_it = tok_list.iterator(0);
                const first_tok = tok_it.next().?;
                assert(first_tok.id == .Identifier and std.mem.eql(u8, first_tok.bytes, name));
                const next = tok_it.peek().?;
                switch (next.id) {
                    .Identifier => {
                        // if it equals itself, ignore. for example, from stdio.h:
                        // #define stdin stdin
                        if (std.mem.eql(u8, name, next.bytes)) {
                            continue;
                        }
                    },
                    .Eof => {
                        // this means it is a macro without a value
                        // we don't care about such things
                        continue;
                    },
                    else => {},
                }
                const macro_fn = if (tok_it.peek().?.id == .Fn) blk: {
                    _ = tok_it.next();
                    break :blk true;
                } else false;

                (if (macro_fn)
                    transMacroFnDefine(c, &tok_it, name, begin_loc)
                else
                    transMacroDefine(c, &tok_it, name, begin_loc)) catch |err| switch (err) {
                    error.UnsupportedTranslation,
                    error.ParseError,
                    => try failDecl(c, begin_loc, name, "unable to translate macro", .{}),
                    error.OutOfMemory => |e| return e,
                };
            },
            else => {},
        }
    }
}

fn transMacroDefine(c: *Context, it: *ctok.TokenList.Iterator, name: []const u8, source_loc: ZigClangSourceLocation) ParseError!void {
    const rp = makeRestorePoint(c);
    const scope = &c.global_scope.base;

    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);
    const eq_tok = try appendToken(c, .Equal, "=");

    const init_node = try parseCExpr(rp, it, source_loc, scope);

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = ast.Node.VarDecl{
        .doc_comments = null,
        .visib_token = visib_tok,
        .thread_local_token = null,
        .name_token = name_tok,
        .eq_token = eq_tok,
        .mut_token = mut_tok,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
        .init_node = init_node,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    };
    _ = try c.global_scope.macro_table.put(name, &node.base);
}

fn transMacroFnDefine(c: *Context, it: *ctok.TokenList.Iterator, name: []const u8, source_loc: ZigClangSourceLocation) ParseError!void {
    const rp = makeRestorePoint(c);
    var fndef_scope = Scope.FnDef.init(c);
    const scope = &fndef_scope.base;

    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const inline_tok = try appendToken(c, .Keyword_inline, "inline");
    const fn_tok = try appendToken(c, .Keyword_fn, "fn");
    const name_tok = try appendIdentifier(c, name);
    _ = try appendToken(c, .LParen, "(");

    if (it.next().?.id != .LParen) {
        return error.ParseError;
    }
    var fn_params = ast.Node.FnProto.ParamList.init(c.a());
    while (true) {
        const param_tok = it.next().?;
        if (param_tok.id != .Identifier)
            return error.ParseError;

        const checked_name = if (try scope.createAlias(c, param_tok.bytes)) |alias| blk: {
            try fndef_scope.params.push(.{ .name = param_tok.bytes, .alias = alias });
            break :blk alias;
        } else param_tok.bytes;

        const param_name_tok = try appendIdentifier(c, checked_name);
        _ = try appendToken(c, .Colon, ":");

        const token_index = try appendToken(c, .Keyword_var, "var");
        const identifier = try c.a().create(ast.Node.Identifier);
        identifier.* = ast.Node.Identifier{
            .base = ast.Node{ .id = ast.Node.Id.Identifier },
            .token = token_index,
        };

        const param_node = try c.a().create(ast.Node.ParamDecl);
        param_node.* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = null,
            .name_token = param_name_tok,
            .type_node = &identifier.base,
            .var_args_token = null,
        };
        try fn_params.push(&param_node.base);

        if (it.peek().?.id != .Comma)
            break;
        _ = it.next();
        _ = try appendToken(c, .Comma, ",");
    }

    if (it.next().?.id != .RParen) {
        return error.ParseError;
    }

    _ = try appendToken(c, .RParen, ")");

    const type_of = try transCreateNodeBuiltinFnCall(c, "@TypeOf");
    type_of.rparen_token = try appendToken(c, .LParen, ")");

    const fn_proto = try c.a().create(ast.Node.FnProto);
    fn_proto.* = .{
        .visib_token = pub_tok,
        .extern_export_inline_token = inline_tok,
        .fn_token = fn_tok,
        .name_token = name_tok,
        .params = fn_params,
        .return_type = .{ .Explicit = &type_of.base },
        .doc_comments = null,
        .var_args_token = null,
        .cc_token = null,
        .body_node = null,
        .lib_name = null,
        .align_expr = null,
        .section_expr = null,
    };

    const block = try transCreateNodeBlock(c, null);

    const return_expr = try transCreateNodeReturnExpr(c);
    const expr = try parseCExpr(rp, it, source_loc, scope);
    _ = try appendToken(c, .Semicolon, ";");
    try type_of.params.push(expr);
    return_expr.rhs = expr;

    block.rbrace = try appendToken(c, .RBrace, "}");
    try block.statements.push(&return_expr.base);
    fn_proto.body_node = &block.base;
    _ = try c.global_scope.macro_table.put(name, &fn_proto.base);
}

const ParseError = Error || error{
    ParseError,
    UnsupportedTranslation,
};

fn parseCExpr(rp: RestorePoint, it: *ctok.TokenList.Iterator, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    return parseCPrefixOpExpr(rp, it, source_loc, scope);
}

fn parseCNumLit(rp: RestorePoint, tok: *CToken, source_loc: ZigClangSourceLocation) ParseError!*ast.Node {
    if (tok.id == .NumLitInt) {
        if (tok.num_lit_suffix == .None) {
            if (tok.bytes.len > 2 and tok.bytes[0] == '0') {
                switch (tok.bytes[1]) {
                    '0'...'7' => {
                        // octal
                        return transCreateNodeInt(rp.c, try std.fmt.allocPrint(rp.c.a(), "0o{}", .{tok.bytes}));
                    },
                    else => {},
                }
            }
            return transCreateNodeInt(rp.c, tok.bytes);
        }
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
        try cast_node.params.push(try transCreateNodeIdentifier(rp.c, switch (tok.num_lit_suffix) {
            .U => "c_uint",
            .L => "c_long",
            .LU => "c_ulong",
            .LL => "c_longlong",
            .LLU => "c_ulonglong",
            else => unreachable,
        }));
        _ = try appendToken(rp.c, .Comma, ",");
        try cast_node.params.push(try transCreateNodeInt(rp.c, tok.bytes));
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    } else if (tok.id == .NumLitFloat) {
        if (tok.num_lit_suffix == .None) {
            return transCreateNodeFloat(rp.c, tok.bytes);
        }
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
        try cast_node.params.push(try transCreateNodeIdentifier(rp.c, switch (tok.num_lit_suffix) {
            .F => "f32",
            .L => "f64",
            else => unreachable,
        }));
        _ = try appendToken(rp.c, .Comma, ",");
        try cast_node.params.push(try transCreateNodeFloat(rp.c, tok.bytes));
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    } else
        return revertAndWarn(
        rp,
        error.ParseError,
        source_loc,
        "expected number literal",
        .{},
    );
}

fn parseCPrimaryExpr(rp: RestorePoint, it: *ctok.TokenList.Iterator, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const tok = it.next().?;
    switch (tok.id) {
        .CharLit => {
            const token = try appendToken(rp.c, .CharLiteral, tok.bytes);
            const node = try rp.c.a().create(ast.Node.CharLiteral);
            node.* = ast.Node.CharLiteral{
                .token = token,
            };
            return &node.base;
        },
        .StrLit => {
            const token = try appendToken(rp.c, .StringLiteral, tok.bytes);
            const node = try rp.c.a().create(ast.Node.StringLiteral);
            node.* = ast.Node.StringLiteral{
                .token = token,
            };
            return &node.base;
        },
        .NumLitInt, .NumLitFloat => {
            return parseCNumLit(rp, tok, source_loc);
        },
        .Identifier => {
            const name = if (scope.getAlias(tok.bytes)) |a| a else tok.bytes;
            return transCreateNodeIdentifier(rp.c, name);
        },
        .LParen => {
            const inner_node = try parseCExpr(rp, it, source_loc, scope);

            if (it.peek().?.id == .RParen) {
                _ = it.next();
                return inner_node;
            }

            // hack to get zig fmt to render a comma in builtin calls
            _ = try appendToken(rp.c, .Comma, ",");

            const node_to_cast = try parseCExpr(rp, it, source_loc, scope);

            if (it.next().?.id != .RParen) {
                return revertAndWarn(
                    rp,
                    error.ParseError,
                    source_loc,
                    "unable to translate C expr",
                    .{},
                );
            }

            //if (@typeId(@TypeOf(x)) == .Pointer)
            //    @ptrCast(dest, x)
            //else if (@typeId(@TypeOf(x)) == .Integer)
            //    @intToPtr(dest, x)
            //else
            //    @as(dest, x)

            const if_1 = try transCreateNodeIf(rp.c);
            const type_id_1 = try transCreateNodeBuiltinFnCall(rp.c, "@typeId");
            const type_of_1 = try transCreateNodeBuiltinFnCall(rp.c, "@TypeOf");
            try type_id_1.params.push(&type_of_1.base);
            try type_of_1.params.push(node_to_cast);
            type_of_1.rparen_token = try appendToken(rp.c, .LParen, ")");
            type_id_1.rparen_token = try appendToken(rp.c, .LParen, ")");

            const cmp_1 = try rp.c.a().create(ast.Node.InfixOp);
            cmp_1.* = .{
                .op_token = try appendToken(rp.c, .EqualEqual, "=="),
                .lhs = &type_id_1.base,
                .op = .EqualEqual,
                .rhs = try transCreateNodeEnumLiteral(rp.c, "Pointer"),
            };
            if_1.condition = &cmp_1.base;
            _ = try appendToken(rp.c, .LParen, ")");

            const ptr_cast = try transCreateNodeBuiltinFnCall(rp.c, "@ptrCast");
            try ptr_cast.params.push(inner_node);
            try ptr_cast.params.push(node_to_cast);
            ptr_cast.rparen_token = try appendToken(rp.c, .LParen, ")");
            if_1.body = &ptr_cast.base;

            const else_1 = try transCreateNodeElse(rp.c);
            if_1.@"else" = else_1;

            const if_2 = try transCreateNodeIf(rp.c);
            const type_id_2 = try transCreateNodeBuiltinFnCall(rp.c, "@typeId");
            const type_of_2 = try transCreateNodeBuiltinFnCall(rp.c, "@TypeOf");
            try type_id_2.params.push(&type_of_2.base);
            try type_of_2.params.push(node_to_cast);
            type_of_2.rparen_token = try appendToken(rp.c, .LParen, ")");
            type_id_2.rparen_token = try appendToken(rp.c, .LParen, ")");

            const cmp_2 = try rp.c.a().create(ast.Node.InfixOp);
            cmp_2.* = .{
                .op_token = try appendToken(rp.c, .EqualEqual, "=="),
                .lhs = &type_id_2.base,
                .op = .EqualEqual,
                .rhs = try transCreateNodeEnumLiteral(rp.c, "Int"),
            };
            if_2.condition = &cmp_2.base;
            else_1.body = &if_2.base;
            _ = try appendToken(rp.c, .LParen, ")");

            const int_to_ptr = try transCreateNodeBuiltinFnCall(rp.c, "@intToPtr");
            try int_to_ptr.params.push(inner_node);
            try int_to_ptr.params.push(node_to_cast);
            int_to_ptr.rparen_token = try appendToken(rp.c, .LParen, ")");
            if_2.body = &int_to_ptr.base;

            const else_2 = try transCreateNodeElse(rp.c);
            if_2.@"else" = else_2;

            const as = try transCreateNodeBuiltinFnCall(rp.c, "@as");
            try as.params.push(inner_node);
            try as.params.push(node_to_cast);
            as.rparen_token = try appendToken(rp.c, .LParen, ")");
            else_2.body = &as.base;

            return &if_1.base;
        },
        else => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            source_loc,
            "unable to translate C expr",
            .{},
        ),
    }
}

fn parseCSuffixOpExpr(rp: RestorePoint, it: *ctok.TokenList.Iterator, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCPrimaryExpr(rp, it, source_loc, scope);
    while (true) {
        const tok = it.next().?;
        switch (tok.id) {
            .Dot => {
                const name_tok = it.next().?;
                if (name_tok.id != .Identifier)
                    return revertAndWarn(
                        rp,
                        error.ParseError,
                        source_loc,
                        "unable to translate C expr",
                        .{},
                    );

                const op_token = try appendToken(rp.c, .Period, ".");
                const rhs = try transCreateNodeIdentifier(rp.c, name_tok.bytes);
                const access_node = try rp.c.a().create(ast.Node.InfixOp);
                access_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .Period,
                    .rhs = rhs,
                };
                node = &access_node.base;
            },
            .Asterisk => {
                if (it.peek().?.id == .RParen) {
                    // type *)

                    // hack to get zig fmt to render a comma in builtin calls
                    _ = try appendToken(rp.c, .Comma, ",");

                    const ptr = try transCreateNodePtrType(rp.c, false, false, .Identifier);
                    ptr.rhs = node;
                    return &ptr.base;
                } else {
                    // expr * expr
                    const op_token = try appendToken(rp.c, .Asterisk, "*");
                    const rhs = try parseCPrimaryExpr(rp, it, source_loc, scope);
                    const bitshift_node = try rp.c.a().create(ast.Node.InfixOp);
                    bitshift_node.* = .{
                        .op_token = op_token,
                        .lhs = node,
                        .op = .BitShiftLeft,
                        .rhs = rhs,
                    };
                    node = &bitshift_node.base;
                }
            },
            .Shl => {
                const op_token = try appendToken(rp.c, .AngleBracketAngleBracketLeft, "<<");
                const rhs = try parseCPrimaryExpr(rp, it, source_loc, scope);
                const bitshift_node = try rp.c.a().create(ast.Node.InfixOp);
                bitshift_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BitShiftLeft,
                    .rhs = rhs,
                };
                node = &bitshift_node.base;
            },
            else => {
                _ = it.prev();
                return node;
            },
        }
    }
}

fn parseCPrefixOpExpr(rp: RestorePoint, it: *ctok.TokenList.Iterator, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const op_tok = it.next().?;

    switch (op_tok.id) {
        .Bang => {
            const node = try transCreateNodePrefixOp(rp.c, .BoolNot, .Bang, "!");
            node.rhs = try parseCPrefixOpExpr(rp, it, source_loc, scope);
            return &node.base;
        },
        .Minus => {
            const node = try transCreateNodePrefixOp(rp.c, .Negation, .Minus, "-");
            node.rhs = try parseCPrefixOpExpr(rp, it, source_loc, scope);
            return &node.base;
        },
        .Tilde => {
            const node = try transCreateNodePrefixOp(rp.c, .BitNot, .Tilde, "~");
            node.rhs = try parseCPrefixOpExpr(rp, it, source_loc, scope);
            return &node.base;
        },
        .Asterisk => {
            const prefix_op_expr = try parseCPrefixOpExpr(rp, it, source_loc, scope);
            const node = try rp.c.a().create(ast.Node.SuffixOp);
            node.* = .{
                .lhs = .{ .node = prefix_op_expr },
                .op = .Deref,
                .rtoken = try appendToken(rp.c, .PeriodAsterisk, ".*"),
            };
            return &node.base;
        },
        else => {
            _ = it.prev();
            return try parseCSuffixOpExpr(rp, it, source_loc, scope);
        },
    }
}

fn tokenSlice(c: *Context, token: ast.TokenIndex) []const u8 {
    const tok = c.tree.tokens.at(token);
    return c.source_buffer.toSliceConst()[tok.start..tok.end];
}

fn getFnDecl(c: *Context, ref: *ast.Node) ?*ast.Node {
    const init = if (ref.cast(ast.Node.VarDecl)) |v| v.init_node.? else return null;
    const name = if (init.cast(ast.Node.Identifier)) |id|
        tokenSlice(c, id.token)
    else
        return null;
    // TODO a.b.c
    if (c.global_scope.sym_table.get(name)) |kv| {
        if (kv.value.cast(ast.Node.VarDecl)) |val| {
            if (val.type_node) |type_node| {
                if (type_node.cast(ast.Node.PrefixOp)) |casted| {
                    if (casted.rhs.id == .FnProto) {
                        return casted.rhs;
                    }
                }
            }
        }
    }
    return null;
}

fn addMacros(c: *Context) !void {
    var macro_it = c.global_scope.macro_table.iterator();
    while (macro_it.next()) |kv| {
        if (getFnDecl(c, kv.value)) |proto_node| {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            try addTopLevelDecl(c, kv.key, try transCreateNodeMacroFn(c, kv.key, kv.value, proto_node));
        } else {
            try addTopLevelDecl(c, kv.key, kv.value);
        }
    }
}
