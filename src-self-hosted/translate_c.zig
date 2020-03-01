// This is the userland implementation of translate-c which is used by both stage1
// and stage2.

const std = @import("std");
const assert = std.debug.assert;
const ast = std.zig.ast;
const Token = std.zig.Token;
usingnamespace @import("clang.zig");
const ctok = std.c.tokenizer;
const CToken = std.c.Token;
const CTokenList = std.c.tokenizer.Source.TokenList;
const mem = std.mem;
const math = std.math;

const CallingConvention = std.builtin.CallingConvention;

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
        Condition,
        Loop,
    };

    const Switch = struct {
        base: Scope,
        pending_block: *ast.Node.Block,
        cases: *ast.Node.Switch.CaseList,
        has_default: bool = false,
    };

    const Block = struct {
        base: Scope,
        block_node: *ast.Node.Block,
        variables: AliasList,
        label: ?[]const u8,
        mangle_count: u32 = 0,

        /// Don't forget to set rbrace token and block_node later
        fn init(c: *Context, parent: *Scope, label: ?[]const u8) !*Block {
            const block = try c.a().create(Block);
            block.* = .{
                .base = .{
                    .id = .Block,
                    .parent = parent,
                },
                .block_node = undefined,
                .variables = AliasList.init(c.a()),
                .label = label,
            };
            return block;
        }

        /// Given the desired name, return a name that does not shadow anything from outer scopes.
        /// Inserts the returned name into the scope.
        fn makeMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
            var proposed_name = name;
            while (scope.contains(proposed_name)) {
                scope.mangle_count += 1;
                proposed_name = try std.fmt.allocPrint(c.a(), "{}_{}", .{ name, scope.mangle_count });
            }
            try scope.variables.push(.{ .name = name, .alias = proposed_name });
            return proposed_name;
        }

        fn getAlias(scope: *Block, name: []const u8) []const u8 {
            var it = scope.variables.iterator(0);
            while (it.next()) |p| {
                if (mem.eql(u8, p.name, name))
                    return p.alias;
            }
            return scope.base.parent.?.getAlias(name);
        }

        fn localContains(scope: *Block, name: []const u8) bool {
            var it = scope.variables.iterator(0);
            while (it.next()) |p| {
                if (mem.eql(u8, p.name, name))
                    return true;
            }
            return false;
        }

        fn contains(scope: *Block, name: []const u8) bool {
            if (scope.localContains(name))
                return true;
            return scope.base.parent.?.contains(name);
        }
    };

    const Root = struct {
        base: Scope,
        sym_table: SymbolTable,
        macro_table: SymbolTable,
        context: *Context,

        fn init(c: *Context) Root {
            return .{
                .base = .{
                    .id = .Root,
                    .parent = null,
                },
                .sym_table = SymbolTable.init(c.a()),
                .macro_table = SymbolTable.init(c.a()),
                .context = c,
            };
        }

        /// Check if the global scope contains this name, without looking into the "future", e.g.
        /// ignore the preprocessed decl and macro names.
        fn containsNow(scope: *Root, name: []const u8) bool {
            return isZigPrimitiveType(name) or
                scope.sym_table.contains(name) or
                scope.macro_table.contains(name);
        }

        /// Check if the global scope contains the name, includes all decls that haven't been translated yet.
        fn contains(scope: *Root, name: []const u8) bool {
            return scope.containsNow(name) or scope.context.global_names.contains(name);
        }
    };

    fn findBlockScope(inner: *Scope, c: *Context) !*Scope.Block {
        var scope = inner;
        while (true) {
            switch (scope.id) {
                .Root => unreachable,
                .Block => return @fieldParentPtr(Block, "base", scope),
                .Condition => {
                    // comma operator used
                    return try Block.init(c, scope, "blk");
                },
                else => scope = scope.parent.?,
            }
        }
    }

    fn getAlias(scope: *Scope, name: []const u8) []const u8 {
        return switch (scope.id) {
            .Root => return name,
            .Block => @fieldParentPtr(Block, "base", scope).getAlias(name),
            .Switch, .Loop, .Condition => scope.parent.?.getAlias(name),
        };
    }

    fn contains(scope: *Scope, name: []const u8) bool {
        return switch (scope.id) {
            .Root => @fieldParentPtr(Root, "base", scope).contains(name),
            .Block => @fieldParentPtr(Block, "base", scope).contains(name),
            .Switch, .Loop, .Condition => scope.parent.?.contains(name),
        };
    }

    fn getBreakableScope(inner: *Scope) *Scope {
        var scope = inner;
        while (true) {
            switch (scope.id) {
                .Root => unreachable,
                .Switch => return scope,
                .Loop => return scope,
                else => scope = scope.parent.?,
            }
        }
    }

    fn getSwitch(inner: *Scope) *Scope.Switch {
        var scope = inner;
        while (true) {
            switch (scope.id) {
                .Root => unreachable,
                .Switch => return @fieldParentPtr(Switch, "base", scope),
                else => scope = scope.parent.?,
            }
        }
    }
};

pub const Context = struct {
    tree: *ast.Tree,
    source_buffer: *std.Buffer,
    err: Error,
    source_manager: *ZigClangSourceManager,
    decl_table: DeclTable,
    alias_list: AliasList,
    global_scope: *Scope.Root,
    clang_context: *ZigClangASTContext,
    mangle_count: u32 = 0,

    /// This one is different than the root scope's name table. This contains
    /// a list of names that we found by visiting all the top level decls without
    /// translating them. The other maps are updated as we translate; this one is updated
    /// up front in a pre-processing step.
    global_names: std.StringHashMap(void),

    fn getMangle(c: *Context) u32 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    fn a(c: *Context) *mem.Allocator {
        return &c.tree.arena_allocator.allocator;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*:0]const u8) ![]u8 {
        return mem.dupe(c.a(), u8, mem.toSliceConst(u8, s));
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
    backing_allocator: *mem.Allocator,
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
        if (errors.len == 0) return error.ASTUnitFailure;
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
            .generated = true,
        };
        break :blk tree;
    };
    const arena = &tree.arena_allocator.allocator; // now we can reference the allocator
    errdefer tree.arena_allocator.deinit();
    tree.tokens = ast.Tree.TokenList.init(arena);
    tree.errors = ast.Tree.ErrorList.init(arena);

    tree.root_node = try arena.create(ast.Node.Root);
    tree.root_node.* = .{
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
        .clang_context = ZigClangASTUnit_getASTContext(ast_unit).?,
        .global_names = std.StringHashMap(void).init(arena),
    };
    context.global_scope.* = Scope.Root.init(&context);

    try prepopulateGlobalNameTable(ast_unit, &context);

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
        std.debug.warn("debug source:\n{}\n==EOF==\ntokens:\n", .{tree.source});
        var i: usize = 0;
        while (i < tree.tokens.len) : (i += 1) {
            const token = tree.tokens.at(i);
            std.debug.warn("{}\n", .{token});
        }
    }
    return tree;
}

fn prepopulateGlobalNameTable(ast_unit: *ZigClangASTUnit, c: *Context) !void {
    if (!ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, c, declVisitorNamesOnlyC)) {
        return c.err;
    }

    // TODO if we see #undef, delete it from the table
    var it = ZigClangASTUnit_getLocalPreprocessingEntities_begin(ast_unit);
    const it_end = ZigClangASTUnit_getLocalPreprocessingEntities_end(ast_unit);

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = ZigClangPreprocessingRecord_iterator_deref(it);
        switch (ZigClangPreprocessedEntity_getKind(entity)) {
            .MacroDefinitionKind => {
                const macro = @ptrCast(*ZigClangMacroDefinitionRecord, entity);
                const raw_name = ZigClangMacroDefinitionRecord_getName_getNameStart(macro);
                const name = try c.str(raw_name);
                _ = try c.global_names.put(name, {});
            },
            else => {},
        }
    }
}

fn declVisitorNamesOnlyC(context: ?*c_void, decl: *const ZigClangDecl) callconv(.C) bool {
    const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    declVisitorNamesOnly(c, decl) catch |err| {
        c.err = err;
        return false;
    };
    return true;
}

fn declVisitorC(context: ?*c_void, decl: *const ZigClangDecl) callconv(.C) bool {
    const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    declVisitor(c, decl) catch |err| {
        c.err = err;
        return false;
    };
    return true;
}

fn declVisitorNamesOnly(c: *Context, decl: *const ZigClangDecl) Error!void {
    if (ZigClangDecl_castToNamedDecl(decl)) |named_decl| {
        const decl_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(named_decl));
        _ = try c.global_names.put(decl_name, {});
    }
}

fn declVisitor(c: *Context, decl: *const ZigClangDecl) Error!void {
    switch (ZigClangDecl_getKind(decl)) {
        .Function => {
            return visitFnDecl(c, @ptrCast(*const ZigClangFunctionDecl, decl));
        },
        .Typedef => {
            _ = try transTypeDef(c, @ptrCast(*const ZigClangTypedefNameDecl, decl), true);
        },
        .Enum => {
            _ = try transEnumDecl(c, @ptrCast(*const ZigClangEnumDecl, decl));
        },
        .Record => {
            _ = try transRecordDecl(c, @ptrCast(*const ZigClangRecordDecl, decl));
        },
        .Var => {
            return visitVarDecl(c, @ptrCast(*const ZigClangVarDecl, decl));
        },
        .Empty => {
            // Do nothing
        },
        else => {
            const decl_name = try c.str(ZigClangDecl_getDeclKindName(decl));
            try emitWarning(c, ZigClangDecl_getLocation(decl), "ignoring {} declaration", .{decl_name});
        },
    }
}

fn visitFnDecl(c: *Context, fn_decl: *const ZigClangFunctionDecl) Error!void {
    const fn_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, fn_decl)));
    if (c.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    // Skip this declaration if a proper definition exists
    if (!ZigClangFunctionDecl_isThisDeclarationADefinition(fn_decl)) {
        if (ZigClangFunctionDecl_getDefinition(fn_decl)) |def|
            return visitFnDecl(c, def);
    }

    const rp = makeRestorePoint(c);
    const fn_decl_loc = ZigClangFunctionDecl_getLocation(fn_decl);
    const has_body = ZigClangFunctionDecl_hasBody(fn_decl);
    const storage_class = ZigClangFunctionDecl_getStorageClass(fn_decl);
    const decl_ctx = FnDeclContext{
        .fn_name = fn_name,
        .has_body = has_body,
        .storage_class = storage_class,
        .is_export = switch (storage_class) {
            .None => has_body and !ZigClangFunctionDecl_isInlineSpecified(fn_decl),
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern", .{}),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        },
    };

    var fn_qt = ZigClangFunctionDecl_getType(fn_decl);

    const fn_type = while (true) {
        const fn_type = ZigClangQualType_getTypePtr(fn_qt);

        switch (ZigClangType_getTypeClass(fn_type)) {
            .Attributed => {
                const attr_type = @ptrCast(*const ZigClangAttributedType, fn_type);
                fn_qt = ZigClangAttributedType_getEquivalentType(attr_type);
            },
            .Paren => {
                const paren_type = @ptrCast(*const ZigClangParenType, fn_type);
                fn_qt = ZigClangParenType_getInnerType(paren_type);
            },
            else => break fn_type,
        }
    } else unreachable;

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
        else => return failDecl(c, fn_decl_loc, fn_name, "unable to resolve function type {}", .{ZigClangType_getTypeClass(fn_type)}),
    };

    if (!decl_ctx.has_body) {
        const semi_tok = try appendToken(c, .Semicolon, ";");
        return addTopLevelDecl(c, fn_name, &proto_node.base);
    }

    // actual function definition with body
    const body_stmt = ZigClangFunctionDecl_getBody(fn_decl);
    const block_scope = try Scope.Block.init(rp.c, &c.global_scope.base, null);
    var scope = &block_scope.base;
    const block_node = try transCreateNodeBlock(rp.c, null);
    block_scope.block_node = block_node;

    var it = proto_node.params.iterator(0);
    var param_id: c_uint = 0;
    while (it.next()) |p| {
        const param = @fieldParentPtr(ast.Node.ParamDecl, "base", p.*);
        const param_name = if (param.name_token) |name_tok|
            tokenSlice(c, name_tok)
        else if (param.var_args_token != null) {
            assert(it.next() == null);
            _ = proto_node.params.pop();
            break;
        } else
            return failDecl(c, fn_decl_loc, fn_name, "function {} parameter has no name", .{fn_name});

        const mangled_param_name = try block_scope.makeMangledName(c, param_name);

        const c_param = ZigClangFunctionDecl_getParamDecl(fn_decl, param_id);
        const qual_type = ZigClangParmVarDecl_getOriginalType(c_param);
        const is_const = ZigClangQualType_isConstQualified(qual_type);

        const arg_name = blk: {
            const param_prefix = if (is_const) "" else "arg_";
            const bare_arg_name = try std.fmt.allocPrint(c.a(), "{}{}", .{ param_prefix, mangled_param_name });
            break :blk try block_scope.makeMangledName(c, bare_arg_name);
        };

        if (!is_const) {
            const node = try transCreateNodeVarDecl(c, false, false, mangled_param_name);
            node.eq_token = try appendToken(c, .Equal, "=");
            node.init_node = try transCreateNodeIdentifier(c, arg_name);
            node.semicolon_token = try appendToken(c, .Semicolon, ";");
            try block_node.statements.push(&node.base);
            param.name_token = try appendIdentifier(c, arg_name);
            _ = try appendToken(c, .Colon, ":");
        }

        param_id += 1;
    }

    transCompoundStmtInline(rp, &block_scope.base, @ptrCast(*const ZigClangCompoundStmt, body_stmt), block_node) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function", .{}),
    };
    block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    proto_node.body_node = &block_node.base;
    return addTopLevelDecl(c, fn_name, &proto_node.base);
}

fn visitVarDecl(c: *Context, var_decl: *const ZigClangVarDecl) Error!void {
    const var_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, var_decl)));
    if (c.global_scope.sym_table.contains(var_name))
        return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");

    const thread_local_token = if (ZigClangVarDecl_getTLSKind(var_decl) == .None)
        null
    else
        try appendToken(c, .Keyword_threadlocal, "threadlocal");

    const scope = &c.global_scope.base;

    // TODO https://github.com/ziglang/zig/issues/3756
    // TODO https://github.com/ziglang/zig/issues/1802
    const checked_name = if (isZigPrimitiveType(var_name)) try std.fmt.allocPrint(c.a(), "_{}", .{var_name}) else var_name;
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

    const name_tok = try appendIdentifier(c, checked_name);

    _ = try appendToken(c, .Colon, ":");
    const type_node = transQualType(rp, qual_type, var_decl_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            return failDecl(c, var_decl_loc, checked_name, "unable to resolve variable type", .{});
        },
        error.OutOfMemory => |e| return e,
    };

    var eq_tok: ast.TokenIndex = undefined;
    var init_node: ?*ast.Node = null;

    // If the initialization expression is not present, initialize with undefined.
    // If it is an integer literal, we can skip the @as since it will be redundant
    // with the variable type.
    if (ZigClangVarDecl_hasInit(var_decl)) {
        eq_tok = try appendToken(c, .Equal, "=");
        init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
            transExprCoercing(rp, &c.global_scope.base, expr, .used, .r_value) catch |err| switch (err) {
                error.UnsupportedTranslation,
                error.UnsupportedType,
                => {
                    return failDecl(c, var_decl_loc, checked_name, "unable to translate initializer", .{});
                },
                error.OutOfMemory => |e| return e,
            }
        else
            try transCreateNodeUndefinedLiteral(c);
    } else if (storage_class != .Extern) {
        return failDecl(c, var_decl_loc, checked_name, "non-extern variable has no initializer", .{});
    }

    const linksection_expr = blk: {
        var str_len: usize = undefined;
        if (ZigClangVarDecl_getSectionAttribute(var_decl, &str_len)) |str_ptr| {
            _ = try appendToken(rp.c, .Keyword_linksection, "linksection");
            _ = try appendToken(rp.c, .LParen, "(");
            const expr = try transCreateNodeStringLiteral(
                rp.c,
                try std.fmt.allocPrint(rp.c.a(), "\"{}\"", .{str_ptr[0..str_len]}),
            );
            _ = try appendToken(rp.c, .RParen, ")");

            break :blk expr;
        }
        break :blk null;
    };

    const align_expr = blk: {
        const alignment = ZigClangVarDecl_getAlignedAttribute(var_decl, rp.c.clang_context);
        if (alignment != 0) {
            _ = try appendToken(rp.c, .Keyword_linksection, "align");
            _ = try appendToken(rp.c, .LParen, "(");
            // Clang reports the alignment in bits
            const expr = try transCreateNodeInt(rp.c, alignment / 8);
            _ = try appendToken(rp.c, .RParen, ")");

            break :blk expr;
        }
        break :blk null;
    };

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
        .align_node = align_expr,
        .section_node = linksection_expr,
        .init_node = init_node,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    };
    return addTopLevelDecl(c, checked_name, &node.base);
}

fn transTypeDefAsBuiltin(c: *Context, typedef_decl: *const ZigClangTypedefNameDecl, builtin_name: []const u8) !*ast.Node {
    _ = try c.decl_table.put(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)), builtin_name);
    return transCreateNodeIdentifier(c, builtin_name);
}

fn transTypeDef(c: *Context, typedef_decl: *const ZigClangTypedefNameDecl, top_level_visit: bool) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)))) |kv|
        return transCreateNodeIdentifier(c, kv.value); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);

    const typedef_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, typedef_decl)));

    // TODO https://github.com/ziglang/zig/issues/3756
    // TODO https://github.com/ziglang/zig/issues/1802
    const checked_name = if (isZigPrimitiveType(typedef_name)) try std.fmt.allocPrint(c.a(), "_{}", .{typedef_name}) else typedef_name;

    if (mem.eql(u8, checked_name, "uint8_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "u8")
    else if (mem.eql(u8, checked_name, "int8_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "i8")
    else if (mem.eql(u8, checked_name, "uint16_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "u16")
    else if (mem.eql(u8, checked_name, "int16_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "i16")
    else if (mem.eql(u8, checked_name, "uint32_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "u32")
    else if (mem.eql(u8, checked_name, "int32_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "i32")
    else if (mem.eql(u8, checked_name, "uint64_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "u64")
    else if (mem.eql(u8, checked_name, "int64_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "i64")
    else if (mem.eql(u8, checked_name, "intptr_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "isize")
    else if (mem.eql(u8, checked_name, "uintptr_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "usize")
    else if (mem.eql(u8, checked_name, "ssize_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "isize")
    else if (mem.eql(u8, checked_name, "size_t"))
        return transTypeDefAsBuiltin(c, typedef_decl, "usize");

    if (!top_level_visit) {
        return transCreateNodeIdentifier(c, checked_name);
    }

    _ = try c.decl_table.put(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)), checked_name);
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const const_tok = try appendToken(c, .Keyword_const, "const");
    const node = try transCreateNodeVarDecl(c, true, true, checked_name);
    node.eq_token = try appendToken(c, .Equal, "=");

    const child_qt = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
    const typedef_loc = ZigClangTypedefNameDecl_getLocation(typedef_decl);
    node.init_node = transQualType(rp, child_qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            try failDecl(c, typedef_loc, checked_name, "unable to resolve typedef child type", .{});
            return null;
        },
        error.OutOfMemory => |e| return e,
    };
    node.semicolon_token = try appendToken(c, .Semicolon, ";");
    try addTopLevelDecl(c, checked_name, &node.base);
    return transCreateNodeIdentifier(c, checked_name);
}

fn transRecordDecl(c: *Context, record_decl: *const ZigClangRecordDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)))) |kv|
        return try transCreateNodeIdentifier(c, kv.value); // Avoid processing this decl twice
    const record_loc = ZigClangRecordDecl_getLocation(record_decl);

    var bare_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, record_decl)));
    var is_unnamed = false;
    // Record declarations such as `struct {...} x` have no name but they're not
    // anonymous hence here isAnonymousStructOrUnion is not needed
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.a(), "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    var container_kind_name: []const u8 = undefined;
    var container_kind: std.zig.Token.Id = undefined;
    if (ZigClangRecordDecl_isUnion(record_decl)) {
        container_kind_name = "union";
        container_kind = .Keyword_union;
    } else if (ZigClangRecordDecl_isStruct(record_decl)) {
        container_kind_name = "struct";
        container_kind = .Keyword_struct;
    } else {
        try emitWarning(c, record_loc, "record {} is not a struct or union", .{bare_name});
        return null;
    }

    const name = try std.fmt.allocPrint(c.a(), "{}_{}", .{ container_kind_name, bare_name });
    _ = try c.decl_table.put(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)), name);

    const node = try transCreateNodeVarDecl(c, !is_unnamed, true, name);

    node.eq_token = try appendToken(c, .Equal, "=");

    var semicolon: ast.TokenIndex = undefined;
    node.init_node = blk: {
        const rp = makeRestorePoint(c);
        const record_def = ZigClangRecordDecl_getDefinition(record_decl) orelse {
            const opaque = try transCreateNodeOpaqueType(c);
            semicolon = try appendToken(c, .Semicolon, ";");
            break :blk opaque;
        };

        const layout_tok = try if (ZigClangRecordDecl_getPackedAttribute(record_decl))
            appendToken(c, .Keyword_packed, "packed")
        else
            appendToken(c, .Keyword_extern, "extern");
        const container_tok = try appendToken(c, container_kind, container_kind_name);
        const lbrace_token = try appendToken(c, .LBrace, "{");

        const container_node = try c.a().create(ast.Node.ContainerDecl);
        container_node.* = .{
            .layout_token = layout_tok,
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
                const opaque = try transCreateNodeOpaqueType(c);
                semicolon = try appendToken(c, .Semicolon, ";");
                try emitWarning(c, field_loc, "{} demoted to opaque type - has bitfield", .{container_kind_name});
                break :blk opaque;
            }

            var is_anon = false;
            var raw_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, field_decl)));
            if (ZigClangFieldDecl_isAnonymousStructOrUnion(field_decl)) {
                raw_name = try std.fmt.allocPrint(c.a(), "unnamed_{}", .{c.getMangle()});
                is_anon = true;
            }
            const field_name = try appendIdentifier(c, raw_name);
            _ = try appendToken(c, .Colon, ":");
            const field_type = transQualType(rp, ZigClangFieldDecl_getType(field_decl), field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    try failDecl(c, record_loc, name, "unable to translate {} member type", .{container_kind_name});
                    return null;
                },
                else => |e| return e,
            };

            const field_node = try c.a().create(ast.Node.ContainerField);
            field_node.* = .{
                .doc_comments = null,
                .comptime_token = null,
                .name_token = field_name,
                .type_expr = field_type,
                .value_expr = null,
                .align_expr = null,
            };

            if (is_anon) {
                _ = try c.decl_table.put(
                    @ptrToInt(ZigClangFieldDecl_getCanonicalDecl(field_decl)),
                    raw_name,
                );
            }

            try container_node.fields_and_decls.push(&field_node.base);
            _ = try appendToken(c, .Comma, ",");
        }
        container_node.rbrace_token = try appendToken(c, .RBrace, "}");
        semicolon = try appendToken(c, .Semicolon, ";");
        break :blk &container_node.base;
    };
    node.semicolon_token = semicolon;

    try addTopLevelDecl(c, name, &node.base);
    if (!is_unnamed)
        try c.alias_list.push(.{ .alias = bare_name, .name = name });
    return transCreateNodeIdentifier(c, name);
}

fn transEnumDecl(c: *Context, enum_decl: *const ZigClangEnumDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)))) |name|
        return try transCreateNodeIdentifier(c, name.value); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const enum_loc = ZigClangEnumDecl_getLocation(enum_decl);

    var bare_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, enum_decl)));
    var is_unnamed = false;
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.a(), "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    const name = try std.fmt.allocPrint(c.a(), "enum_{}", .{bare_name});
    _ = try c.decl_table.put(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)), name);
    const node = try transCreateNodeVarDecl(c, !is_unnamed, true, name);
    node.eq_token = try appendToken(c, .Equal, "=");

    node.init_node = if (ZigClangEnumDecl_getDefinition(enum_decl)) |enum_def| blk: {
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
        // The underlying type may be null in case of forward-declared enum
        // types, while that's not ISO-C compliant many compilers allow this and
        // default to the usual integer type used for all the enums.

        // default to c_int since msvc and gcc default to different types
        _ = try appendToken(c, .LParen, "(");
        container_node.init_arg_expr = .{
            .Type = if (int_type.ptr != null and
                !isCBuiltinType(int_type, .UInt) and
                !isCBuiltinType(int_type, .Int))
                transQualType(rp, int_type, enum_loc) catch |err| switch (err) {
                    error.UnsupportedType => {
                        try failDecl(c, enum_loc, name, "unable to translate enum tag type", .{});
                        return null;
                    },
                    else => |e| return e,
                }
            else
                try transCreateNodeIdentifier(c, "c_int"),
        };
        _ = try appendToken(c, .RParen, ")");

        container_node.lbrace_token = try appendToken(c, .LBrace, "{");

        it = ZigClangEnumDecl_enumerator_begin(enum_def);
        end_it = ZigClangEnumDecl_enumerator_end(enum_def);
        while (ZigClangEnumDecl_enumerator_iterator_neq(it, end_it)) : (it = ZigClangEnumDecl_enumerator_iterator_next(it)) {
            const enum_const = ZigClangEnumDecl_enumerator_iterator_deref(it);

            const enum_val_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, enum_const)));

            const field_name = if (!is_unnamed and mem.startsWith(u8, enum_val_name, bare_name))
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
            const tld_node = try transCreateNodeVarDecl(c, true, true, enum_val_name);
            tld_node.eq_token = try appendToken(c, .Equal, "=");
            const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@enumToInt");
            const enum_ident = try transCreateNodeIdentifier(c, name);
            const period_tok = try appendToken(c, .Period, ".");
            const field_ident = try transCreateNodeIdentifier(c, field_name);
            const field_access_node = try c.a().create(ast.Node.InfixOp);
            field_access_node.* = .{
                .op_token = period_tok,
                .lhs = enum_ident,
                .op = .Period,
                .rhs = field_ident,
            };
            try cast_node.params.push(&field_access_node.base);
            cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            tld_node.init_node = &cast_node.base;
            tld_node.semicolon_token = try appendToken(c, .Semicolon, ";");
            try addTopLevelDecl(c, field_name, &tld_node.base);
        }
        // make non exhaustive
        const field_node = try c.a().create(ast.Node.ContainerField);
        field_node.* = .{
            .doc_comments = null,
            .comptime_token = null,
            .name_token = try appendIdentifier(c, "_"),
            .type_expr = null,
            .value_expr = null,
            .align_expr = null,
        };

        try container_node.fields_and_decls.push(&field_node.base);
        _ = try appendToken(c, .Comma, ",");
        container_node.rbrace_token = try appendToken(c, .RBrace, "}");

        break :blk &container_node.base;
    } else
        try transCreateNodeOpaqueType(c);

    node.semicolon_token = try appendToken(c, .Semicolon, ";");

    try addTopLevelDecl(c, name, &node.base);
    if (!is_unnamed)
        try c.alias_list.push(.{ .alias = bare_name, .name = name });
    return transCreateNodeIdentifier(c, name);
}

fn createAlias(c: *Context, alias: var) !void {
    const node = try transCreateNodeVarDecl(c, true, true, alias.alias);
    node.eq_token = try appendToken(c, .Equal, "=");
    node.init_node = try transCreateNodeIdentifier(c, alias.name);
    node.semicolon_token = try appendToken(c, .Semicolon, ";");
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
        .IntegerLiteralClass => return transIntegerLiteral(rp, scope, @ptrCast(*const ZigClangIntegerLiteral, stmt), result_used, .with_as),
        .ReturnStmtClass => return transReturnStmt(rp, scope, @ptrCast(*const ZigClangReturnStmt, stmt)),
        .StringLiteralClass => return transStringLiteral(rp, scope, @ptrCast(*const ZigClangStringLiteral, stmt), result_used),
        .ParenExprClass => {
            const expr = try transExpr(rp, scope, ZigClangParenExpr_getSubExpr(@ptrCast(*const ZigClangParenExpr, stmt)), .used, lrvalue);
            if (expr.id == .GroupedExpression) return maybeSuppressResult(rp, scope, result_used, expr);
            const node = try rp.c.a().create(ast.Node.GroupedExpression);
            node.* = .{
                .lparen = try appendToken(rp.c, .LParen, "("),
                .expr = expr,
                .rparen = try appendToken(rp.c, .RParen, ")"),
            };
            return maybeSuppressResult(rp, scope, result_used, &node.base);
        },
        .InitListExprClass => return transInitListExpr(rp, scope, @ptrCast(*const ZigClangInitListExpr, stmt), result_used),
        .ImplicitValueInitExprClass => return transImplicitValueInitExpr(rp, scope, @ptrCast(*const ZigClangExpr, stmt), result_used),
        .IfStmtClass => return transIfStmt(rp, scope, @ptrCast(*const ZigClangIfStmt, stmt)),
        .WhileStmtClass => return transWhileLoop(rp, scope, @ptrCast(*const ZigClangWhileStmt, stmt)),
        .DoStmtClass => return transDoWhileLoop(rp, scope, @ptrCast(*const ZigClangDoStmt, stmt)),
        .NullStmtClass => {
            const block = try transCreateNodeBlock(rp.c, null);
            block.rbrace = try appendToken(rp.c, .RBrace, "}");
            return &block.base;
        },
        .ContinueStmtClass => return try transCreateNodeContinue(rp.c),
        .BreakStmtClass => return transBreak(rp, scope),
        .ForStmtClass => return transForLoop(rp, scope, @ptrCast(*const ZigClangForStmt, stmt)),
        .FloatingLiteralClass => return transFloatingLiteral(rp, scope, @ptrCast(*const ZigClangFloatingLiteral, stmt), result_used),
        .ConditionalOperatorClass => {
            return transConditionalOperator(rp, scope, @ptrCast(*const ZigClangConditionalOperator, stmt), result_used);
        },
        .BinaryConditionalOperatorClass => {
            return transBinaryConditionalOperator(rp, scope, @ptrCast(*const ZigClangBinaryConditionalOperator, stmt), result_used);
        },
        .SwitchStmtClass => return transSwitch(rp, scope, @ptrCast(*const ZigClangSwitchStmt, stmt)),
        .CaseStmtClass => return transCase(rp, scope, @ptrCast(*const ZigClangCaseStmt, stmt)),
        .DefaultStmtClass => return transDefault(rp, scope, @ptrCast(*const ZigClangDefaultStmt, stmt)),
        .ConstantExprClass => return transConstantExpr(rp, scope, @ptrCast(*const ZigClangExpr, stmt), result_used),
        .PredefinedExprClass => return transPredefinedExpr(rp, scope, @ptrCast(*const ZigClangPredefinedExpr, stmt), result_used),
        .CharacterLiteralClass => return transCharLiteral(rp, scope, @ptrCast(*const ZigClangCharacterLiteral, stmt), result_used, .with_as),
        .StmtExprClass => return transStmtExpr(rp, scope, @ptrCast(*const ZigClangStmtExpr, stmt), result_used),
        .MemberExprClass => return transMemberExpr(rp, scope, @ptrCast(*const ZigClangMemberExpr, stmt), result_used),
        .ArraySubscriptExprClass => return transArrayAccess(rp, scope, @ptrCast(*const ZigClangArraySubscriptExpr, stmt), result_used),
        .CallExprClass => return transCallExpr(rp, scope, @ptrCast(*const ZigClangCallExpr, stmt), result_used),
        .UnaryExprOrTypeTraitExprClass => return transUnaryExprOrTypeTraitExpr(rp, scope, @ptrCast(*const ZigClangUnaryExprOrTypeTraitExpr, stmt), result_used),
        .UnaryOperatorClass => return transUnaryOperator(rp, scope, @ptrCast(*const ZigClangUnaryOperator, stmt), result_used),
        .CompoundAssignOperatorClass => return transCompoundAssignOperator(rp, scope, @ptrCast(*const ZigClangCompoundAssignOperator, stmt), result_used),
        .OpaqueValueExprClass => {
            const source_expr = ZigClangOpaqueValueExpr_getSourceExpr(@ptrCast(*const ZigClangOpaqueValueExpr, stmt)).?;
            const expr = try transExpr(rp, scope, source_expr, .used, lrvalue);
            if (expr.id == .GroupedExpression) return maybeSuppressResult(rp, scope, result_used, expr);
            const node = try rp.c.a().create(ast.Node.GroupedExpression);
            node.* = .{
                .lparen = try appendToken(rp.c, .LParen, "("),
                .expr = expr,
                .rparen = try appendToken(rp.c, .RParen, ")"),
            };
            return maybeSuppressResult(rp, scope, result_used, &node.base);
        },
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
    var op_token: ast.TokenIndex = undefined;
    var op_id: ast.Node.InfixOp.Op = undefined;
    switch (op) {
        .Assign => return transCreateNodeAssign(rp, scope, result_used, ZigClangBinaryOperator_getLHS(stmt), ZigClangBinaryOperator_getRHS(stmt)),
        .Comma => {
            const block_scope = try scope.findBlockScope(rp.c);
            const expr = block_scope.base.parent == scope;
            const lparen = if (expr) blk: {
                const l = try appendToken(rp.c, .LParen, "(");
                block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);
                break :blk l;
            } else undefined;

            const lhs = try transExpr(rp, &block_scope.base, ZigClangBinaryOperator_getLHS(stmt), .unused, .r_value);
            try block_scope.block_node.statements.push(lhs);

            const rhs = try transExpr(rp, &block_scope.base, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
            if (expr) {
                _ = try appendToken(rp.c, .Semicolon, ";");
                const break_node = try transCreateNodeBreak(rp.c, block_scope.label);
                break_node.rhs = rhs;
                try block_scope.block_node.statements.push(&break_node.base);
                block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
                const rparen = try appendToken(rp.c, .RParen, ")");
                const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
                grouped_expr.* = .{
                    .lparen = lparen,
                    .expr = &block_scope.block_node.base,
                    .rparen = rparen,
                };
                return maybeSuppressResult(rp, scope, result_used, &grouped_expr.base);
            } else {
                return maybeSuppressResult(rp, scope, result_used, rhs);
            }
        },
        .Div => {
            if (!cIsUnsignedInteger(qt)) {
                // signed integer division uses @divTrunc
                const div_trunc_node = try transCreateNodeBuiltinFnCall(rp.c, "@divTrunc");
                try div_trunc_node.params.push(try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value));
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                try div_trunc_node.params.push(rhs);
                div_trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &div_trunc_node.base);
            }
        },
        .Rem => {
            if (!cIsUnsignedInteger(qt)) {
                // signed integer division uses @rem
                const rem_node = try transCreateNodeBuiltinFnCall(rp.c, "@rem");
                try rem_node.params.push(try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value));
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                try rem_node.params.push(rhs);
                rem_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &rem_node.base);
            }
        },
        .Shl => {
            const node = try transCreateNodeShiftOp(rp, scope, stmt, .BitShiftLeft, .AngleBracketAngleBracketLeft, "<<");
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .Shr => {
            const node = try transCreateNodeShiftOp(rp, scope, stmt, .BitShiftRight, .AngleBracketAngleBracketRight, ">>");
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .LAnd => {
            const node = try transCreateNodeBoolInfixOp(rp, scope, stmt, .BoolAnd, result_used, true);
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        .LOr => {
            const node = try transCreateNodeBoolInfixOp(rp, scope, stmt, .BoolOr, result_used, true);
            return maybeSuppressResult(rp, scope, result_used, node);
        },
        else => {},
    }
    const lhs_node = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
    switch (op) {
        .Add => {
            if (cIsUnsignedInteger(qt)) {
                op_token = try appendToken(rp.c, .PlusPercent, "+%");
                op_id = .AddWrap;
            } else {
                op_token = try appendToken(rp.c, .Plus, "+");
                op_id = .Add;
            }
        },
        .Sub => {
            if (cIsUnsignedInteger(qt)) {
                op_token = try appendToken(rp.c, .MinusPercent, "-%");
                op_id = .SubWrap;
            } else {
                op_token = try appendToken(rp.c, .Minus, "-");
                op_id = .Sub;
            }
        },
        .Mul => {
            if (cIsUnsignedInteger(qt)) {
                op_token = try appendToken(rp.c, .AsteriskPercent, "*%");
                op_id = .MulWrap;
            } else {
                op_token = try appendToken(rp.c, .Asterisk, "*");
                op_id = .Mul;
            }
        },
        .Div => {
            // unsigned/float division uses the operator
            op_id = .Div;
            op_token = try appendToken(rp.c, .Slash, "/");
        },
        .Rem => {
            // unsigned/float division uses the operator
            op_id = .Mod;
            op_token = try appendToken(rp.c, .Percent, "%");
        },
        .LT => {
            op_id = .LessThan;
            op_token = try appendToken(rp.c, .AngleBracketLeft, "<");
        },
        .GT => {
            op_id = .GreaterThan;
            op_token = try appendToken(rp.c, .AngleBracketRight, ">");
        },
        .LE => {
            op_id = .LessOrEqual;
            op_token = try appendToken(rp.c, .AngleBracketLeftEqual, "<=");
        },
        .GE => {
            op_id = .GreaterOrEqual;
            op_token = try appendToken(rp.c, .AngleBracketRightEqual, ">=");
        },
        .EQ => {
            op_id = .EqualEqual;
            op_token = try appendToken(rp.c, .EqualEqual, "==");
        },
        .NE => {
            op_id = .BangEqual;
            op_token = try appendToken(rp.c, .BangEqual, "!=");
        },
        .And => {
            op_id = .BitAnd;
            op_token = try appendToken(rp.c, .Ampersand, "&");
        },
        .Xor => {
            op_id = .BitXor;
            op_token = try appendToken(rp.c, .Caret, "^");
        },
        .Or => {
            op_id = .BitOr;
            op_token = try appendToken(rp.c, .Pipe, "|");
        },
        else => unreachable,
    }

    const rhs_node = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
    return transCreateNodeInfixOp(rp, scope, lhs_node, op_id, op_token, rhs_node, result_used, true);
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
    const block_scope = try Scope.Block.init(rp.c, scope, null);
    block_scope.block_node = try transCreateNodeBlock(rp.c, null);
    try transCompoundStmtInline(rp, &block_scope.base, stmt, block_scope.block_node);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    return &block_scope.block_node.base;
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
    const block_scope = scope.findBlockScope(c) catch unreachable;

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
                const name = try c.str(ZigClangNamedDecl_getName_bytes_begin(
                    @ptrCast(*const ZigClangNamedDecl, var_decl),
                ));
                const mangled_name = try block_scope.makeMangledName(c, name);
                const node = try transCreateNodeVarDecl(c, false, ZigClangQualType_isConstQualified(qual_type), mangled_name);

                _ = try appendToken(c, .Colon, ":");
                const loc = ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt));
                node.type_node = try transQualType(rp, qual_type, loc);

                node.eq_token = try appendToken(c, .Equal, "=");
                var init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
                    try transExprCoercing(rp, scope, expr, .used, .r_value)
                else
                    try transCreateNodeUndefinedLiteral(c);
                if (!qualTypeIsBoolean(qual_type) and isBoolRes(init_node)) {
                    const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@boolToInt");
                    try builtin_node.params.push(init_node);
                    builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                    init_node = &builtin_node.base;
                }
                node.init_node = init_node;
                node.semicolon_token = try appendToken(c, .Semicolon, ";");
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
    const name = try rp.c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, value_decl)));
    const mangled_name = scope.getAlias(name);
    return transCreateNodeIdentifier(rp.c, mangled_name);
}

fn transImplicitCastExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangImplicitCastExpr,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const c = rp.c;
    const sub_expr = ZigClangImplicitCastExpr_getSubExpr(expr);
    const dest_type = getExprQualType(c, @ptrCast(*const ZigClangExpr, expr));
    const src_type = getExprQualType(c, sub_expr);
    switch (ZigClangImplicitCastExpr_getCastKind(expr)) {
        .BitCast, .FloatingCast, .FloatingToIntegral, .IntegralToFloating, .IntegralCast, .PointerToIntegral, .IntegralToPointer => {
            const sub_expr_node = try transExpr(rp, scope, sub_expr, .used, .r_value);
            return transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node);
        },
        .LValueToRValue, .NoOp, .FunctionToPointerDecay => {
            const sub_expr_node = try transExpr(rp, scope, sub_expr, .used, .r_value);
            return maybeSuppressResult(rp, scope, result_used, sub_expr_node);
        },
        .ArrayToPointerDecay => {
            if (exprIsStringLiteral(sub_expr)) {
                const sub_expr_node = try transExpr(rp, scope, sub_expr, .used, .r_value);
                return maybeSuppressResult(rp, scope, result_used, sub_expr_node);
            }

            const prefix_op = try transCreateNodePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
            prefix_op.rhs = try transExpr(rp, scope, sub_expr, .used, .r_value);

            return maybeSuppressResult(rp, scope, result_used, &prefix_op.base);
        },
        .NullToPointer => {
            return try transCreateNodeNullLiteral(rp.c);
        },
        .PointerToBoolean => {
            // @ptrToInt(val) != 0
            const ptr_to_int = try transCreateNodeBuiltinFnCall(rp.c, "@ptrToInt");
            try ptr_to_int.params.push(try transExpr(rp, scope, sub_expr, .used, .r_value));
            ptr_to_int.rparen_token = try appendToken(rp.c, .RParen, ")");

            const op_token = try appendToken(rp.c, .BangEqual, "!=");
            const rhs_node = try transCreateNodeInt(rp.c, 0);
            return transCreateNodeInfixOp(rp, scope, &ptr_to_int.base, .BangEqual, op_token, rhs_node, result_used, false);
        },
        .IntegralToBoolean => {
            const sub_expr_node = try transExpr(rp, scope, sub_expr, .used, .r_value);

            // The expression is already a boolean one, return it as-is
            if (isBoolRes(sub_expr_node))
                return sub_expr_node;

            // val != 0
            const op_token = try appendToken(rp.c, .BangEqual, "!=");
            const rhs_node = try transCreateNodeInt(rp.c, 0);
            return transCreateNodeInfixOp(rp, scope, sub_expr_node, .BangEqual, op_token, rhs_node, result_used, false);
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

fn transBoolExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangExpr,
    used: ResultUsed,
    lrvalue: LRValue,
    grouped: bool,
) TransError!*ast.Node {
    const lparen = if (grouped)
        try appendToken(rp.c, .LParen, "(")
    else
        undefined;
    var res = try transExpr(rp, scope, expr, used, lrvalue);

    if (isBoolRes(res)) {
        if (!grouped and res.id == .GroupedExpression) {
            const group = @fieldParentPtr(ast.Node.GroupedExpression, "base", res);
            res = group.expr;
            // get zig fmt to work properly
            tokenSlice(rp.c, group.lparen)[0] = ')';
        }
        return res;
    }

    const ty = ZigClangQualType_getTypePtr(getExprQualType(rp.c, expr));
    const node = try finishBoolExpr(rp, scope, ZigClangExpr_getBeginLoc(expr), ty, res, used);

    if (grouped) {
        const rparen = try appendToken(rp.c, .RParen, ")");
        const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
        grouped_expr.* = .{
            .lparen = lparen,
            .expr = node,
            .rparen = rparen,
        };
        return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
    } else {
        return maybeSuppressResult(rp, scope, used, node);
    }
}

fn exprIsBooleanType(expr: *const ZigClangExpr) bool {
    return qualTypeIsBoolean(ZigClangExpr_getType(expr));
}

fn exprIsStringLiteral(expr: *const ZigClangExpr) bool {
    switch (ZigClangExpr_getStmtClass(expr)) {
        .StringLiteralClass => return true,
        .PredefinedExprClass => return true,
        .UnaryOperatorClass => {
            const op_expr = ZigClangUnaryOperator_getSubExpr(@ptrCast(*const ZigClangUnaryOperator, expr));
            return exprIsStringLiteral(op_expr);
        },
        else => return false,
    }
}

fn isBoolRes(res: *ast.Node) bool {
    switch (res.id) {
        .InfixOp => switch (@fieldParentPtr(ast.Node.InfixOp, "base", res).op) {
            .BoolOr,
            .BoolAnd,
            .EqualEqual,
            .BangEqual,
            .LessThan,
            .GreaterThan,
            .LessOrEqual,
            .GreaterOrEqual,
            => return true,

            else => {},
        },
        .PrefixOp => switch (@fieldParentPtr(ast.Node.PrefixOp, "base", res).op) {
            .BoolNot => return true,

            else => {},
        },
        .BoolLiteral => return true,
        .GroupedExpression => return isBoolRes(@fieldParentPtr(ast.Node.GroupedExpression, "base", res).expr),
        else => {},
    }
    return false;
}

fn finishBoolExpr(
    rp: RestorePoint,
    scope: *Scope,
    loc: ZigClangSourceLocation,
    ty: *const ZigClangType,
    node: *ast.Node,
    used: ResultUsed,
) TransError!*ast.Node {
    switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);

            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Bool => return node,
                .Char_U,
                .UChar,
                .Char_S,
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
                .LongDouble,
                .WChar_U,
                .Char8,
                .Char16,
                .Char32,
                .WChar_S,
                .Float16,
                => {
                    const op_token = try appendToken(rp.c, .BangEqual, "!=");
                    const rhs_node = try transCreateNodeInt(rp.c, 0);
                    return transCreateNodeInfixOp(rp, scope, node, .BangEqual, op_token, rhs_node, used, false);
                },
                .NullPtr => {
                    const op_token = try appendToken(rp.c, .EqualEqual, "==");
                    const rhs_node = try transCreateNodeNullLiteral(rp.c);
                    return transCreateNodeInfixOp(rp, scope, node, .EqualEqual, op_token, rhs_node, used, false);
                },
                else => {},
            }
        },
        .Pointer => {
            const op_token = try appendToken(rp.c, .BangEqual, "!=");
            const rhs_node = try transCreateNodeNullLiteral(rp.c);
            return transCreateNodeInfixOp(rp, scope, node, .BangEqual, op_token, rhs_node, used, false);
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);
            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            const underlying_type = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
            return finishBoolExpr(rp, scope, loc, ZigClangQualType_getTypePtr(underlying_type), node, used);
        },
        .Enum => {
            const op_token = try appendToken(rp.c, .BangEqual, "!=");
            const rhs_node = try transCreateNodeInt(rp.c, 0);
            return transCreateNodeInfixOp(rp, scope, node, .BangEqual, op_token, rhs_node, used, false);
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const ZigClangElaboratedType, ty);
            const named_type = ZigClangElaboratedType_getNamedType(elaborated_ty);
            return finishBoolExpr(rp, scope, loc, ZigClangQualType_getTypePtr(named_type), node, used);
        },
        else => {},
    }
    return revertAndWarn(rp, error.UnsupportedType, loc, "unsupported bool expression type", .{});
}

const SuppressCast = enum {
    with_as,
    no_as,
};
fn transIntegerLiteral(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangIntegerLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!*ast.Node {
    var eval_result: ZigClangExprEvalResult = undefined;
    if (!ZigClangIntegerLiteral_EvaluateAsInt(expr, &eval_result, rp.c.clang_context)) {
        const loc = ZigClangIntegerLiteral_getBeginLoc(expr);
        return revertAndWarn(rp, error.UnsupportedTranslation, loc, "invalid integer literal", .{});
    }

    if (suppress_as == .no_as) {
        const int_lit_node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&eval_result.Val));
        return maybeSuppressResult(rp, scope, result_used, int_lit_node);
    }

    // Integer literals in C have types, and this can matter for several reasons.
    // For example, this is valid C:
    //     unsigned char y = 256;
    // How this gets evaluated is the 256 is an integer, which gets truncated to signed char, then bit-casted
    // to unsigned char, resulting in 0. In order for this to work, we have to emit this zig code:
    //     var y = @bitCast(u8, @truncate(i8, @as(c_int, 256)));
    // Ideally in translate-c we could flatten this out to simply:
    //     var y: u8 = 0;
    // But the first step is to be correct, and the next step is to make the output more elegant.

    // @as(T, x)
    const expr_base = @ptrCast(*const ZigClangExpr, expr);
    const as_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
    const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
    try as_node.params.push(ty_node);
    _ = try appendToken(rp.c, .Comma, ",");

    const int_lit_node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&eval_result.Val));
    try as_node.params.push(int_lit_node);

    as_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &as_node.base);
}

fn transReturnStmt(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangReturnStmt,
) TransError!*ast.Node {
    const node = try transCreateNodeReturnExpr(rp.c);
    if (ZigClangReturnStmt_getRetValue(expr)) |val_expr| {
        node.rhs = try transExprCoercing(rp, scope, val_expr, .used, .r_value);
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
            node.* = .{
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
        mem.copy(u8, buf[i..], escaped);
        i += escaped.len;
    }
}

// Returns either a string literal or a slice of `buf`.
fn escapeChar(c: u8, char_buf: *[4]u8) []const u8 {
    return switch (c) {
        '\"' => "\\\""[0..],
        '\'' => "\\'"[0..],
        '\\' => "\\\\"[0..],
        '\n' => "\\n"[0..],
        '\r' => "\\r"[0..],
        '\t' => "\\t"[0..],
        else => {
            // Handle the remaining escapes Zig doesn't support by turning them
            // into their respective hex representation
            if (std.ascii.isCntrl(c))
                return std.fmt.bufPrint(char_buf[0..], "\\x{x:0<2}", .{c}) catch unreachable
            else
                return std.fmt.bufPrint(char_buf[0..], "{c}", .{c}) catch unreachable;
        },
    };
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
    if (cIsInteger(dst_type) and cIsInteger(src_type)) {
        // 1. Extend or truncate without changing signed-ness.
        // 2. Bit-cast to correct signed-ness

        // @bitCast(dest_type, intermediate_value)
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@bitCast");
        try cast_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");

        switch (cIntTypeCmp(dst_type, src_type)) {
            .lt => {
                // @truncate(SameSignSmallerInt, src_type)
                const trunc_node = try transCreateNodeBuiltinFnCall(rp.c, "@truncate");
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, cIsSignedInteger(src_type));
                try trunc_node.params.push(ty_node);
                _ = try appendToken(rp.c, .Comma, ",");
                try trunc_node.params.push(expr);
                trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                try cast_node.params.push(&trunc_node.base);
            },
            .gt => {
                // @as(SameSignBiggerInt, src_type)
                const as_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, cIsSignedInteger(src_type));
                try as_node.params.push(ty_node);
                _ = try appendToken(rp.c, .Comma, ",");
                try as_node.params.push(expr);
                as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                try cast_node.params.push(&as_node.base);
            },
            .eq => {
                try cast_node.params.push(expr);
            },
        }
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    }
    if (cIsInteger(dst_type) and qualTypeIsPtr(src_type)) {
        // @intCast(dest_type, @ptrToInt(val))
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
        try cast_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrToInt");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        try cast_node.params.push(&builtin_node.base);
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    }
    if (cIsInteger(src_type) and qualTypeIsPtr(dst_type)) {
        // @intToPtr(dest_type, val)
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@intToPtr");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (cIsFloating(src_type) and cIsFloating(dst_type)) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@floatCast");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (cIsFloating(src_type) and !cIsFloating(dst_type)) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@floatToInt");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (!cIsFloating(src_type) and cIsFloating(dst_type)) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@intToFloat");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (ZigClangType_isBooleanType(qualTypeCanon(src_type)) and
        !ZigClangType_isBooleanType(qualTypeCanon(dst_type)))
    {
        // @boolToInt returns either a comptime_int or a u1
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@boolToInt");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        const inner_cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
        try inner_cast_node.params.push(try transCreateNodeIdentifier(rp.c, "u1"));
        _ = try appendToken(rp.c, .Comma, ",");
        try inner_cast_node.params.push(&builtin_node.base);
        inner_cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
        try cast_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");

        if (cIsSignedInteger(dst_type)) {
            const bitcast_node = try transCreateNodeBuiltinFnCall(rp.c, "@bitCast");
            try bitcast_node.params.push(try transCreateNodeIdentifier(rp.c, "i1"));
            _ = try appendToken(rp.c, .Comma, ",");
            try bitcast_node.params.push(&inner_cast_node.base);
            bitcast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            try cast_node.params.push(&bitcast_node.base);
        } else {
            try cast_node.params.push(&inner_cast_node.base);
        }
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        return &cast_node.base;
    }
    if (ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(dst_type)) == .Enum) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@intToEnum");
        try builtin_node.params.push(try transQualType(rp, dst_type, loc));
        _ = try appendToken(rp.c, .Comma, ",");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(src_type)) == .Enum and
        ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(dst_type)) != .Enum)
    {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@enumToInt");
        try builtin_node.params.push(expr);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
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

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangExpr,
    used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    switch (ZigClangStmt_getStmtClass(@ptrCast(*const ZigClangStmt, expr))) {
        .IntegerLiteralClass => {
            return transIntegerLiteral(rp, scope, @ptrCast(*const ZigClangIntegerLiteral, expr), .used, .no_as);
        },
        .CharacterLiteralClass => {
            return transCharLiteral(rp, scope, @ptrCast(*const ZigClangCharacterLiteral, expr), .used, .no_as);
        },
        .UnaryOperatorClass => {
            const un_expr = @ptrCast(*const ZigClangUnaryOperator, expr);
            if (ZigClangUnaryOperator_getOpcode(un_expr) == .Extension) {
                return transExprCoercing(rp, scope, ZigClangUnaryOperator_getSubExpr(un_expr), used, lrvalue);
            }
        },
        else => {},
    }
    return transExpr(rp, scope, expr, .used, .r_value);
}

fn transInitListExprRecord(
    rp: RestorePoint,
    scope: *Scope,
    loc: ZigClangSourceLocation,
    expr: *const ZigClangInitListExpr,
    ty: *const ZigClangType,
    used: ResultUsed,
) TransError!*ast.Node {
    var is_union_type = false;
    // Unions and Structs are both represented as RecordDecl
    const record_ty = ZigClangType_getAsRecordType(ty) orelse
        blk: {
        is_union_type = true;
        break :blk ZigClangType_getAsUnionType(ty);
    } orelse unreachable;
    const record_decl = ZigClangRecordType_getDecl(record_ty);
    const record_def = ZigClangRecordDecl_getDefinition(record_decl) orelse
        unreachable;

    const ty_node = try transType(rp, ty, loc);
    const init_count = ZigClangInitListExpr_getNumInits(expr);
    var init_node = try transCreateNodeStructInitializer(rp.c, ty_node);

    var init_i: c_uint = 0;
    var it = ZigClangRecordDecl_field_begin(record_def);
    const end_it = ZigClangRecordDecl_field_end(record_def);
    while (ZigClangRecordDecl_field_iterator_neq(it, end_it)) : (it = ZigClangRecordDecl_field_iterator_next(it)) {
        const field_decl = ZigClangRecordDecl_field_iterator_deref(it);

        // The initializer for a union type has a single entry only
        if (is_union_type and field_decl != ZigClangInitListExpr_getInitializedFieldInUnion(expr)) {
            continue;
        }

        assert(init_i < init_count);
        const elem_expr = ZigClangInitListExpr_getInit(expr, init_i);
        init_i += 1;

        // Generate the field assignment expression:
        //     .field_name = expr
        const period_tok = try appendToken(rp.c, .Period, ".");

        var raw_name = try rp.c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, field_decl)));
        if (ZigClangFieldDecl_isAnonymousStructOrUnion(field_decl)) {
            const name = rp.c.decl_table.get(@ptrToInt(ZigClangFieldDecl_getCanonicalDecl(field_decl))).?;
            raw_name = try mem.dupe(rp.c.a(), u8, name.value);
        }
        const field_name_tok = try appendIdentifier(rp.c, raw_name);

        _ = try appendToken(rp.c, .Equal, "=");

        const field_init_node = try rp.c.a().create(ast.Node.FieldInitializer);
        field_init_node.* = .{
            .period_token = period_tok,
            .name_token = field_name_tok,
            .expr = try transExpr(rp, scope, elem_expr, .used, .r_value),
        };

        try init_node.op.StructInitializer.push(&field_init_node.base);
        _ = try appendToken(rp.c, .Comma, ",");
    }

    init_node.rtoken = try appendToken(rp.c, .RBrace, "}");

    return &init_node.base;
}

fn transCreateNodeArrayType(
    rp: RestorePoint,
    source_loc: ZigClangSourceLocation,
    ty: *const ZigClangType,
    len: var,
) TransError!*ast.Node {
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
    node.op.ArrayType.len_expr = try transCreateNodeInt(rp.c, len);
    _ = try appendToken(rp.c, .RBracket, "]");
    node.rhs = try transType(rp, ty, source_loc);
    return &node.base;
}

fn transInitListExprArray(
    rp: RestorePoint,
    scope: *Scope,
    loc: ZigClangSourceLocation,
    expr: *const ZigClangInitListExpr,
    ty: *const ZigClangType,
    used: ResultUsed,
) TransError!*ast.Node {
    const arr_type = ZigClangType_getAsArrayTypeUnsafe(ty);
    const child_qt = ZigClangArrayType_getElementType(arr_type);
    const init_count = ZigClangInitListExpr_getNumInits(expr);
    assert(ZigClangType_isConstantArrayType(@ptrCast(*const ZigClangType, arr_type)));
    const const_arr_ty = @ptrCast(*const ZigClangConstantArrayType, arr_type);
    const size_ap_int = ZigClangConstantArrayType_getSize(const_arr_ty);
    const all_count = ZigClangAPInt_getLimitedValue(size_ap_int, math.maxInt(usize));
    const leftover_count = all_count - init_count;

    var init_node: *ast.Node.SuffixOp = undefined;
    var cat_tok: ast.TokenIndex = undefined;
    if (init_count != 0) {
        const ty_node = try transCreateNodeArrayType(
            rp,
            loc,
            ZigClangQualType_getTypePtr(child_qt),
            init_count,
        );
        init_node = try transCreateNodeArrayInitializer(rp.c, ty_node);
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

    const ty_node = try transCreateNodeArrayType(rp, loc, ZigClangQualType_getTypePtr(child_qt), 1);
    var filler_init_node = try transCreateNodeArrayInitializer(rp.c, ty_node);
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

fn transInitListExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const ZigClangInitListExpr,
    used: ResultUsed,
) TransError!*ast.Node {
    const qt = getExprQualType(rp.c, @ptrCast(*const ZigClangExpr, expr));
    var qual_type = ZigClangQualType_getTypePtr(qt);
    const source_loc = ZigClangExpr_getBeginLoc(@ptrCast(*const ZigClangExpr, expr));

    if (ZigClangType_isRecordType(qual_type)) {
        return transInitListExprRecord(
            rp,
            scope,
            source_loc,
            expr,
            qual_type,
            used,
        );
    } else if (ZigClangType_isArrayType(qual_type)) {
        return transInitListExprArray(
            rp,
            scope,
            source_loc,
            expr,
            qual_type,
            used,
        );
    } else {
        const type_name = rp.c.str(ZigClangType_getTypeClassName(qual_type));
        return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported initlist type: '{}'", .{type_name});
    }
}

fn transZeroInitExpr(
    rp: RestorePoint,
    scope: *Scope,
    source_loc: ZigClangSourceLocation,
    ty: *const ZigClangType,
) TransError!*ast.Node {
    switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => blk: {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Bool => return try transCreateNodeBoolLiteral(rp.c, false),
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
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);
            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            return transZeroInitExpr(
                rp,
                scope,
                source_loc,
                ZigClangQualType_getTypePtr(
                    ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl),
                ),
            );
        },
        else => {},
    }

    return revertAndWarn(rp, error.UnsupportedType, source_loc, "type does not have an implicit init value", .{});
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
    return transZeroInitExpr(rp, scope, source_loc, ty);
}

fn transIfStmt(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangIfStmt,
) TransError!*ast.Node {
    // if (c) t
    // if (c) t else e
    const if_node = try transCreateNodeIf(rp.c);

    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };
    if_node.condition = try transBoolExpr(rp, &cond_scope, @ptrCast(*const ZigClangExpr, ZigClangIfStmt_getCond(stmt)), .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transStmt(rp, scope, ZigClangIfStmt_getThen(stmt), .unused, .r_value);

    if (ZigClangIfStmt_getElse(stmt)) |expr| {
        if_node.@"else" = try transCreateNodeElse(rp.c);
        if_node.@"else".?.body = try transStmt(rp, scope, expr, .unused, .r_value);
    }
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &if_node.base;
}

fn transWhileLoop(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangWhileStmt,
) TransError!*ast.Node {
    const while_node = try transCreateNodeWhile(rp.c);

    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };
    while_node.condition = try transBoolExpr(rp, &cond_scope, @ptrCast(*const ZigClangExpr, ZigClangWhileStmt_getCond(stmt)), .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };
    while_node.body = try transStmt(rp, &loop_scope, ZigClangWhileStmt_getBody(stmt), .unused, .r_value);
    return &while_node.base;
}

fn transDoWhileLoop(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangDoStmt,
) TransError!*ast.Node {
    const while_node = try transCreateNodeWhile(rp.c);

    while_node.condition = try transCreateNodeBoolLiteral(rp.c, true);
    _ = try appendToken(rp.c, .RParen, ")");
    var new = false;
    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };

    // if (!cond) break;
    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };
    const prefix_op = try transCreateNodePrefixOp(rp.c, .BoolNot, .Bang, "!");
    prefix_op.rhs = try transBoolExpr(rp, &cond_scope, @ptrCast(*const ZigClangExpr, ZigClangDoStmt_getCond(stmt)), .used, .r_value, true);
    _ = try appendToken(rp.c, .RParen, ")");
    if_node.condition = &prefix_op.base;
    if_node.body = &(try transCreateNodeBreak(rp.c, null)).base;
    _ = try appendToken(rp.c, .Semicolon, ";");

    const body_node = if (ZigClangStmt_getStmtClass(ZigClangDoStmt_getBody(stmt)) == .CompoundStmtClass) blk: {
        // there's already a block in C, so we'll append our condition to it.
        // c: do {
        // c:   a;
        // c:   b;
        // c: } while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   b;
        // zig:   if (!cond) break;
        // zig: }
        break :blk (try transStmt(rp, &loop_scope, ZigClangDoStmt_getBody(stmt), .unused, .r_value)).cast(ast.Node.Block).?;
    } else blk: {
        // the C statement is without a block, so we need to create a block to contain it.
        // c: do
        // c:   a;
        // c: while(c);
        // zig: while (true) {
        // zig:   a;
        // zig:   if (!cond) break;
        // zig: }
        new = true;
        const block = try transCreateNodeBlock(rp.c, null);
        try block.statements.push(try transStmt(rp, &loop_scope, ZigClangDoStmt_getBody(stmt), .unused, .r_value));
        break :blk block;
    };

    try body_node.statements.push(&if_node.base);
    if (new)
        body_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    while_node.body = &body_node.base;
    return &while_node.base;
}

fn transForLoop(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangForStmt,
) TransError!*ast.Node {
    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };

    var block_scope: ?*Scope.Block = null;
    if (ZigClangForStmt_getInit(stmt)) |init| {
        block_scope = try Scope.Block.init(rp.c, scope, null);
        const block = try transCreateNodeBlock(rp.c, null);
        block_scope.?.block_node = block;
        loop_scope.parent = &block_scope.?.base;
        const result = try transStmt(rp, &block_scope.?.base, init, .unused, .r_value);
        if (result != &block.base)
            try block.statements.push(result);
    }
    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };

    const while_node = try transCreateNodeWhile(rp.c);
    while_node.condition = if (ZigClangForStmt_getCond(stmt)) |cond|
        try transBoolExpr(rp, &cond_scope, cond, .used, .r_value, false)
    else
        try transCreateNodeBoolLiteral(rp.c, true);
    _ = try appendToken(rp.c, .RParen, ")");

    if (ZigClangForStmt_getInc(stmt)) |incr| {
        _ = try appendToken(rp.c, .Colon, ":");
        _ = try appendToken(rp.c, .LParen, "(");
        while_node.continue_expr = try transExpr(rp, &cond_scope, incr, .unused, .r_value);
        _ = try appendToken(rp.c, .RParen, ")");
    }

    while_node.body = try transStmt(rp, &loop_scope, ZigClangForStmt_getBody(stmt), .unused, .r_value);
    if (block_scope != null) {
        try block_scope.?.block_node.statements.push(&while_node.base);
        block_scope.?.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
        return &block_scope.?.block_node.base;
    } else
        return &while_node.base;
}

fn transSwitch(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangSwitchStmt,
) TransError!*ast.Node {
    const switch_node = try transCreateNodeSwitch(rp.c);
    var switch_scope = Scope.Switch{
        .base = .{
            .id = .Switch,
            .parent = scope,
        },
        .cases = &switch_node.cases,
        .pending_block = undefined,
    };

    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };
    switch_node.expr = try transExpr(rp, &cond_scope, ZigClangSwitchStmt_getCond(stmt), .used, .r_value);
    _ = try appendToken(rp.c, .RParen, ")");
    _ = try appendToken(rp.c, .LBrace, "{");
    switch_node.rbrace = try appendToken(rp.c, .RBrace, "}");

    const block_scope = try Scope.Block.init(rp.c, &switch_scope.base, null);
    // tmp block that all statements will go before being picked up by a case or default
    const block = try transCreateNodeBlock(rp.c, null);
    block_scope.block_node = block;

    const switch_block = try transCreateNodeBlock(rp.c, null);
    try switch_block.statements.push(&switch_node.base);
    switch_scope.pending_block = switch_block;

    const last = try transStmt(rp, &block_scope.base, ZigClangSwitchStmt_getBody(stmt), .unused, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    // take all pending statements
    var it = last.cast(ast.Node.Block).?.statements.iterator(0);
    while (it.next()) |n| {
        try switch_scope.pending_block.statements.push(n.*);
    }

    switch_scope.pending_block.label = try appendIdentifier(rp.c, "__switch");
    _ = try appendToken(rp.c, .Colon, ":");
    if (!switch_scope.has_default) {
        const else_prong = try transCreateNodeSwitchCase(rp.c, try transCreateNodeSwitchElse(rp.c));
        else_prong.expr = &(try transCreateNodeBreak(rp.c, "__switch")).base;
        _ = try appendToken(rp.c, .Comma, ",");
        try switch_node.cases.push(&else_prong.base);
    }
    switch_scope.pending_block.rbrace = try appendToken(rp.c, .RBrace, "}");
    return &switch_scope.pending_block.base;
}

fn transCase(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCaseStmt,
) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;
    const switch_scope = scope.getSwitch();
    const label = try std.fmt.allocPrint(rp.c.a(), "__case_{}", .{switch_scope.cases.len - @boolToInt(switch_scope.has_default)});
    _ = try appendToken(rp.c, .Semicolon, ";");

    const expr = if (ZigClangCaseStmt_getRHS(stmt)) |rhs| blk: {
        const lhs_node = try transExpr(rp, scope, ZigClangCaseStmt_getLHS(stmt), .used, .r_value);
        const ellips = try appendToken(rp.c, .Ellipsis3, "...");
        const rhs_node = try transExpr(rp, scope, rhs, .used, .r_value);

        const node = try rp.c.a().create(ast.Node.InfixOp);
        node.* = .{
            .op_token = ellips,
            .lhs = lhs_node,
            .op = .Range,
            .rhs = rhs_node,
        };
        break :blk &node.base;
    } else
        try transExpr(rp, scope, ZigClangCaseStmt_getLHS(stmt), .used, .r_value);

    const switch_prong = try transCreateNodeSwitchCase(rp.c, expr);
    switch_prong.expr = &(try transCreateNodeBreak(rp.c, label)).base;
    _ = try appendToken(rp.c, .Comma, ",");
    try switch_scope.cases.push(&switch_prong.base);

    const block = try transCreateNodeBlock(rp.c, null);
    switch_scope.pending_block.label = try appendIdentifier(rp.c, label);
    _ = try appendToken(rp.c, .Colon, ":");
    switch_scope.pending_block.rbrace = try appendToken(rp.c, .RBrace, "}");
    try block.statements.push(&switch_scope.pending_block.base);

    // take all pending statements
    var it = block_scope.block_node.statements.iterator(0);
    while (it.next()) |n| {
        try switch_scope.pending_block.statements.push(n.*);
    }
    block_scope.block_node.statements.shrink(0);

    switch_scope.pending_block = block;

    return transStmt(rp, scope, ZigClangCaseStmt_getSubStmt(stmt), .unused, .r_value);
}

fn transDefault(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangDefaultStmt,
) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;
    const switch_scope = scope.getSwitch();
    const label = "__default";
    switch_scope.has_default = true;
    _ = try appendToken(rp.c, .Semicolon, ";");

    const else_prong = try transCreateNodeSwitchCase(rp.c, try transCreateNodeSwitchElse(rp.c));
    else_prong.expr = &(try transCreateNodeBreak(rp.c, label)).base;
    _ = try appendToken(rp.c, .Comma, ",");
    try switch_scope.cases.push(&else_prong.base);

    const block = try transCreateNodeBlock(rp.c, null);
    switch_scope.pending_block.label = try appendIdentifier(rp.c, label);
    _ = try appendToken(rp.c, .Colon, ":");
    switch_scope.pending_block.rbrace = try appendToken(rp.c, .RBrace, "}");
    try block.statements.push(&switch_scope.pending_block.base);

    // take all pending statements
    var it = block_scope.block_node.statements.iterator(0);
    while (it.next()) |n| {
        try switch_scope.pending_block.statements.push(n.*);
    }
    block_scope.block_node.statements.shrink(0);

    switch_scope.pending_block = block;
    return transStmt(rp, scope, ZigClangDefaultStmt_getSubStmt(stmt), .unused, .r_value);
}

fn transConstantExpr(rp: RestorePoint, scope: *Scope, expr: *const ZigClangExpr, used: ResultUsed) TransError!*ast.Node {
    var result: ZigClangExprEvalResult = undefined;
    if (!ZigClangExpr_EvaluateAsConstantExpr(expr, &result, .EvaluateForCodeGen, rp.c.clang_context))
        return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangExpr_getBeginLoc(expr), "invalid constant expression", .{});

    var val_node: ?*ast.Node = null;
    switch (ZigClangAPValue_getKind(&result.Val)) {
        .Int => {
            // See comment in `transIntegerLiteral` for why this code is here.
            // @as(T, x)
            const expr_base = @ptrCast(*const ZigClangExpr, expr);
            const as_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
            const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
            try as_node.params.push(ty_node);
            _ = try appendToken(rp.c, .Comma, ",");

            const int_lit_node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&result.Val));
            try as_node.params.push(int_lit_node);

            as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

            return maybeSuppressResult(rp, scope, used, &as_node.base);
        },
        else => {
            return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangExpr_getBeginLoc(expr), "unsupported constant expression kind", .{});
        },
    }
}

fn transPredefinedExpr(rp: RestorePoint, scope: *Scope, expr: *const ZigClangPredefinedExpr, used: ResultUsed) TransError!*ast.Node {
    return transStringLiteral(rp, scope, ZigClangPredefinedExpr_getFunctionName(expr), used);
}

fn transCharLiteral(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCharacterLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!*ast.Node {
    const kind = ZigClangCharacterLiteral_getKind(stmt);
    const int_lit_node = switch (kind) {
        .Ascii, .UTF8 => blk: {
            const val = ZigClangCharacterLiteral_getValue(stmt);
            if (kind == .Ascii) {
                // C has a somewhat obscure feature called multi-character character
                // constant
                if (val > 255)
                    break :blk try transCreateNodeInt(rp.c, val);
            }
            var char_buf: [4]u8 = undefined;
            const token = try appendTokenFmt(rp.c, .CharLiteral, "'{}'", .{escapeChar(@intCast(u8, val), &char_buf)});
            const node = try rp.c.a().create(ast.Node.CharLiteral);
            node.* = .{
                .token = token,
            };
            break :blk &node.base;
        },
        .UTF16, .UTF32, .Wide => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)),
            "TODO: support character literal kind {}",
            .{kind},
        ),
        else => unreachable,
    };
    if (suppress_as == .no_as) {
        return maybeSuppressResult(rp, scope, result_used, int_lit_node);
    }
    // See comment in `transIntegerLiteral` for why this code is here.
    // @as(T, x)
    const expr_base = @ptrCast(*const ZigClangExpr, stmt);
    const as_node = try transCreateNodeBuiltinFnCall(rp.c, "@as");
    const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
    try as_node.params.push(ty_node);
    _ = try appendToken(rp.c, .Comma, ",");

    try as_node.params.push(int_lit_node);

    as_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &as_node.base);
}

fn transStmtExpr(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangStmtExpr, used: ResultUsed) TransError!*ast.Node {
    const comp = ZigClangStmtExpr_getSubStmt(stmt);
    if (used == .unused) {
        return transCompoundStmt(rp, scope, comp);
    }
    const lparen = try appendToken(rp.c, .LParen, "(");
    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    const block = try transCreateNodeBlock(rp.c, "blk");
    block_scope.block_node = block;

    var it = ZigClangCompoundStmt_body_begin(comp);
    const end_it = ZigClangCompoundStmt_body_end(comp);
    while (it != end_it - 1) : (it += 1) {
        const result = try transStmt(rp, &block_scope.base, it[0], .unused, .r_value);
        if (result != &block.base)
            try block.statements.push(result);
    }
    const break_node = try transCreateNodeBreak(rp.c, "blk");
    break_node.rhs = try transStmt(rp, &block_scope.base, it[0], .used, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block.statements.push(&break_node.base);
    block.rbrace = try appendToken(rp.c, .RBrace, "}");
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = &block.base,
        .rparen = rparen,
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transMemberExpr(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangMemberExpr, result_used: ResultUsed) TransError!*ast.Node {
    var container_node = try transExpr(rp, scope, ZigClangMemberExpr_getBase(stmt), .used, .r_value);

    if (ZigClangMemberExpr_isArrow(stmt)) {
        container_node = try transCreateNodePtrDeref(rp.c, container_node);
    }

    const member_decl = ZigClangMemberExpr_getMemberDecl(stmt);
    const name = blk: {
        const decl_kind = ZigClangDecl_getKind(@ptrCast(*const ZigClangDecl, member_decl));
        // If we're referring to a anonymous struct/enum find the bogus name
        // we've assigned to it during the RecordDecl translation
        if (decl_kind == .Field) {
            const field_decl = @ptrCast(*const struct_ZigClangFieldDecl, member_decl);
            if (ZigClangFieldDecl_isAnonymousStructOrUnion(field_decl)) {
                const name = rp.c.decl_table.get(@ptrToInt(ZigClangFieldDecl_getCanonicalDecl(field_decl))).?;
                break :blk try mem.dupe(rp.c.a(), u8, name.value);
            }
        }
        const decl = @ptrCast(*const ZigClangNamedDecl, member_decl);
        break :blk try rp.c.str(ZigClangNamedDecl_getName_bytes_begin(decl));
    };

    const node = try transCreateNodeFieldAccess(rp.c, container_node, name);
    return maybeSuppressResult(rp, scope, result_used, node);
}

fn transArrayAccess(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangArraySubscriptExpr, result_used: ResultUsed) TransError!*ast.Node {
    var base_stmt = ZigClangArraySubscriptExpr_getBase(stmt);

    // Unwrap the base statement if it's an array decayed to a bare pointer type
    // so that we index the array itself
    if (ZigClangStmt_getStmtClass(@ptrCast(*const ZigClangStmt, base_stmt)) == .ImplicitCastExprClass) {
        const implicit_cast = @ptrCast(*const ZigClangImplicitCastExpr, base_stmt);

        if (ZigClangImplicitCastExpr_getCastKind(implicit_cast) == .ArrayToPointerDecay) {
            base_stmt = ZigClangImplicitCastExpr_getSubExpr(implicit_cast);
        }
    }

    const container_node = try transExpr(rp, scope, base_stmt, .used, .r_value);
    const node = try transCreateNodeArrayAccess(rp.c, container_node);

    // cast if the index is long long or signed
    const subscr_expr = ZigClangArraySubscriptExpr_getIdx(stmt);
    const qt = getExprQualType(rp.c, subscr_expr);
    const is_longlong = cIsLongLongInteger(qt);
    const is_signed = cIsSignedInteger(qt);

    if (is_longlong or is_signed) {
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
        // check if long long first so that signed long long doesn't just become unsigned long long
        var typeid_node = if (is_longlong) try transCreateNodeIdentifier(rp.c, "usize") else try transQualTypeIntWidthOf(rp.c, qt, false);
        try cast_node.params.push(typeid_node);
        _ = try appendToken(rp.c, .Comma, ",");
        try cast_node.params.push(try transExpr(rp, scope, subscr_expr, .used, .r_value));
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        node.rtoken = try appendToken(rp.c, .RBrace, "]");
        node.op.ArrayAccess = &cast_node.base;
    } else {
        node.op.ArrayAccess = try transExpr(rp, scope, subscr_expr, .used, .r_value);
        node.rtoken = try appendToken(rp.c, .RBrace, "]");
    }
    return maybeSuppressResult(rp, scope, result_used, &node.base);
}

fn transCallExpr(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangCallExpr, result_used: ResultUsed) TransError!*ast.Node {
    const callee = ZigClangCallExpr_getCallee(stmt);
    var raw_fn_expr = try transExpr(rp, scope, callee, .used, .r_value);

    var is_ptr = false;
    const fn_ty = qualTypeGetFnProto(ZigClangExpr_getType(callee), &is_ptr);

    const fn_expr = if (is_ptr and fn_ty != null) blk: {
        if (ZigClangExpr_getStmtClass(callee) == .ImplicitCastExprClass) {
            const implicit_cast = @ptrCast(*const ZigClangImplicitCastExpr, callee);

            if (ZigClangImplicitCastExpr_getCastKind(implicit_cast) == .FunctionToPointerDecay) {
                const subexpr = ZigClangImplicitCastExpr_getSubExpr(implicit_cast);
                if (ZigClangExpr_getStmtClass(subexpr) == .DeclRefExprClass) {
                    const decl_ref = @ptrCast(*const ZigClangDeclRefExpr, subexpr);
                    const named_decl = ZigClangDeclRefExpr_getFoundDecl(decl_ref);
                    if (ZigClangDecl_getKind(@ptrCast(*const ZigClangDecl, named_decl)) == .Function) {
                        break :blk raw_fn_expr;
                    }
                }
            }
        }
        break :blk try transCreateNodeUnwrapNull(rp.c, raw_fn_expr);
    } else
        raw_fn_expr;
    const node = try transCreateNodeFnCall(rp.c, fn_expr);

    const num_args = ZigClangCallExpr_getNumArgs(stmt);
    const args = ZigClangCallExpr_getArgs(stmt);
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        if (i != 0) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
        const arg = try transExpr(rp, scope, args[i], .used, .r_value);
        try node.op.Call.params.push(arg);
    }
    node.rtoken = try appendToken(rp.c, .RParen, ")");

    if (fn_ty) |ty| {
        const canon = ZigClangQualType_getCanonicalType(ty.getReturnType());
        const ret_ty = ZigClangQualType_getTypePtr(canon);
        if (ZigClangType_isVoidType(ret_ty)) {
            _ = try appendToken(rp.c, .Semicolon, ";");
            return &node.base;
        }
    }

    return maybeSuppressResult(rp, scope, result_used, &node.base);
}

const ClangFunctionType = union(enum) {
    Proto: *const ZigClangFunctionProtoType,
    NoProto: *const ZigClangFunctionType,

    fn getReturnType(self: @This()) ZigClangQualType {
        switch (@as(@TagType(@This()), self)) {
            .Proto => return ZigClangFunctionProtoType_getReturnType(self.Proto),
            .NoProto => return ZigClangFunctionType_getReturnType(self.NoProto),
        }
    }
};

fn qualTypeGetFnProto(qt: ZigClangQualType, is_ptr: *bool) ?ClangFunctionType {
    const canon = ZigClangQualType_getCanonicalType(qt);
    var ty = ZigClangQualType_getTypePtr(canon);
    is_ptr.* = false;

    if (ZigClangType_getTypeClass(ty) == .Pointer) {
        is_ptr.* = true;
        const child_qt = ZigClangType_getPointeeType(ty);
        ty = ZigClangQualType_getTypePtr(child_qt);
    }
    if (ZigClangType_getTypeClass(ty) == .FunctionProto) {
        return ClangFunctionType{ .Proto = @ptrCast(*const ZigClangFunctionProtoType, ty) };
    }
    if (ZigClangType_getTypeClass(ty) == .FunctionNoProto) {
        return ClangFunctionType{ .NoProto = @ptrCast(*const ZigClangFunctionType, ty) };
    }
    return null;
}

fn transUnaryExprOrTypeTraitExpr(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangUnaryExprOrTypeTraitExpr,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const type_node = try transQualType(
        rp,
        ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument(stmt),
        ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc(stmt),
    );

    const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@sizeOf");
    try builtin_node.params.push(type_node);
    builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &builtin_node.base);
}

fn qualTypeHasWrappingOverflow(qt: ZigClangQualType) bool {
    if (cIsUnsignedInteger(qt)) {
        // unsigned integer overflow wraps around.
        return true;
    } else {
        // float, signed integer, and pointer overflow is undefined behavior.
        return false;
    }
}

fn transUnaryOperator(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangUnaryOperator, used: ResultUsed) TransError!*ast.Node {
    const op_expr = ZigClangUnaryOperator_getSubExpr(stmt);
    switch (ZigClangUnaryOperator_getOpcode(stmt)) {
        .PostInc => if (qualTypeHasWrappingOverflow(ZigClangUnaryOperator_getType(stmt)))
            return transCreatePostCrement(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", used)
        else
            return transCreatePostCrement(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", used),
        .PostDec => if (qualTypeHasWrappingOverflow(ZigClangUnaryOperator_getType(stmt)))
            return transCreatePostCrement(rp, scope, stmt, .AssignSubWrap, .MinusPercentEqual, "-%=", used)
        else
            return transCreatePostCrement(rp, scope, stmt, .AssignSub, .MinusEqual, "-=", used),
        .PreInc => if (qualTypeHasWrappingOverflow(ZigClangUnaryOperator_getType(stmt)))
            return transCreatePreCrement(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", used)
        else
            return transCreatePreCrement(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", used),
        .PreDec => if (qualTypeHasWrappingOverflow(ZigClangUnaryOperator_getType(stmt)))
            return transCreatePreCrement(rp, scope, stmt, .AssignSubWrap, .MinusPercentEqual, "-%=", used)
        else
            return transCreatePreCrement(rp, scope, stmt, .AssignSub, .MinusEqual, "-=", used),
        .AddrOf => {
            const op_node = try transCreateNodePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
            op_node.rhs = try transExpr(rp, scope, op_expr, used, .r_value);
            return &op_node.base;
        },
        .Deref => {
            const value_node = try transExpr(rp, scope, op_expr, used, .r_value);
            var is_ptr = false;
            const fn_ty = qualTypeGetFnProto(ZigClangExpr_getType(op_expr), &is_ptr);
            if (fn_ty != null and is_ptr)
                return value_node;
            const unwrapped = try transCreateNodeUnwrapNull(rp.c, value_node);
            return transCreateNodePtrDeref(rp.c, unwrapped);
        },
        .Plus => return transExpr(rp, scope, op_expr, used, .r_value),
        .Minus => {
            if (!qualTypeHasWrappingOverflow(ZigClangExpr_getType(op_expr))) {
                const op_node = try transCreateNodePrefixOp(rp.c, .Negation, .Minus, "-");
                op_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
                return &op_node.base;
            } else if (cIsUnsignedInteger(ZigClangExpr_getType(op_expr))) {
                // we gotta emit 0 -% x
                const zero = try transCreateNodeInt(rp.c, 0);
                const token = try appendToken(rp.c, .MinusPercent, "-%");
                const expr = try transExpr(rp, scope, op_expr, .used, .r_value);
                return transCreateNodeInfixOp(rp, scope, zero, .SubWrap, token, expr, used, true);
            } else
                return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangUnaryOperator_getBeginLoc(stmt), "C negation with non float non integer", .{});
        },
        .Not => {
            const op_node = try transCreateNodePrefixOp(rp.c, .BitNot, .Tilde, "~");
            op_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
            return &op_node.base;
        },
        .LNot => {
            const op_node = try transCreateNodePrefixOp(rp.c, .BoolNot, .Bang, "!");
            op_node.rhs = try transBoolExpr(rp, scope, op_expr, .used, .r_value, true);
            return &op_node.base;
        },
        .Extension => {
            return transExpr(rp, scope, ZigClangUnaryOperator_getSubExpr(stmt), used, .l_value);
        },
        else => return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangUnaryOperator_getBeginLoc(stmt), "unsupported C translation {}", .{ZigClangUnaryOperator_getOpcode(stmt)}),
    }
}

fn transCreatePreCrement(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangUnaryOperator,
    op: ast.Node.InfixOp.Op,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const op_expr = ZigClangUnaryOperator_getSubExpr(stmt);

    if (used == .unused) {
        // common case
        // c: ++expr
        // zig: expr += 1
        const expr = try transExpr(rp, scope, op_expr, .used, .r_value);
        const token = try appendToken(rp.c, op_tok_id, bytes);
        const one = try transCreateNodeInt(rp.c, 1);
        if (scope.id != .Condition)
            _ = try appendToken(rp.c, .Semicolon, ";");
        return transCreateNodeInfixOp(rp, scope, expr, op, token, one, .used, false);
    }
    // worst case
    // c: ++expr
    // zig: (blk: {
    // zig:     const _ref = &expr;
    // zig:     _ref.* += 1;
    // zig:     break :blk _ref.*
    // zig: })
    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const node = try transCreateNodeVarDecl(rp.c, false, true, ref);
    node.eq_token = try appendToken(rp.c, .Equal, "=");
    const rhs_node = try transCreateNodePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    rhs_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
    node.init_node = &rhs_node.base;
    node.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const token = try appendToken(rp.c, op_tok_id, bytes);
    const one = try transCreateNodeInt(rp.c, 1);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const assign = try transCreateNodeInfixOp(rp, scope, ref_node, op, token, one, .used, false);
    try block_scope.block_node.statements.push(assign);

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label);
    break_node.rhs = ref_node;
    try block_scope.block_node.statements.push(&break_node.base);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_scope.block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCreatePostCrement(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangUnaryOperator,
    op: ast.Node.InfixOp.Op,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const op_expr = ZigClangUnaryOperator_getSubExpr(stmt);

    if (used == .unused) {
        // common case
        // c: ++expr
        // zig: expr += 1
        const expr = try transExpr(rp, scope, op_expr, .used, .r_value);
        const token = try appendToken(rp.c, op_tok_id, bytes);
        const one = try transCreateNodeInt(rp.c, 1);
        if (scope.id != .Condition)
            _ = try appendToken(rp.c, .Semicolon, ";");
        return transCreateNodeInfixOp(rp, scope, expr, op, token, one, .used, false);
    }
    // worst case
    // c: expr++
    // zig: (blk: {
    // zig:     const _ref = &expr;
    // zig:     const _tmp = _ref.*;
    // zig:     _ref.* += 1;
    // zig:     break :blk _tmp
    // zig: })
    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const node = try transCreateNodeVarDecl(rp.c, false, true, ref);
    node.eq_token = try appendToken(rp.c, .Equal, "=");
    const rhs_node = try transCreateNodePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    rhs_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
    node.init_node = &rhs_node.base;
    node.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");

    const tmp = try block_scope.makeMangledName(rp.c, "tmp");
    const tmp_node = try transCreateNodeVarDecl(rp.c, false, true, tmp);
    tmp_node.eq_token = try appendToken(rp.c, .Equal, "=");
    tmp_node.init_node = ref_node;
    tmp_node.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&tmp_node.base);

    const token = try appendToken(rp.c, op_tok_id, bytes);
    const one = try transCreateNodeInt(rp.c, 1);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const assign = try transCreateNodeInfixOp(rp, scope, ref_node, op, token, one, .used, false);
    try block_scope.block_node.statements.push(assign);

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label);
    break_node.rhs = try transCreateNodeIdentifier(rp.c, tmp);
    try block_scope.block_node.statements.push(&break_node.base);
    _ = try appendToken(rp.c, .Semicolon, ";");
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_scope.block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCompoundAssignOperator(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangCompoundAssignOperator, used: ResultUsed) TransError!*ast.Node {
    switch (ZigClangCompoundAssignOperator_getOpcode(stmt)) {
        .MulAssign => if (qualTypeHasWrappingOverflow(ZigClangCompoundAssignOperator_getType(stmt)))
            return transCreateCompoundAssign(rp, scope, stmt, .AssignMulWrap, .AsteriskPercentEqual, "*%=", .MulWrap, .AsteriskPercent, "*%", used)
        else
            return transCreateCompoundAssign(rp, scope, stmt, .AssignMul, .AsteriskEqual, "*=", .Mul, .Asterisk, "*", used),
        .AddAssign => if (qualTypeHasWrappingOverflow(ZigClangCompoundAssignOperator_getType(stmt)))
            return transCreateCompoundAssign(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", .AddWrap, .PlusPercent, "+%", used)
        else
            return transCreateCompoundAssign(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", .Add, .Plus, "+", used),
        .SubAssign => if (qualTypeHasWrappingOverflow(ZigClangCompoundAssignOperator_getType(stmt)))
            return transCreateCompoundAssign(rp, scope, stmt, .AssignSubWrap, .MinusPercentEqual, "-%=", .SubWrap, .MinusPercent, "-%", used)
        else
            return transCreateCompoundAssign(rp, scope, stmt, .AssignSub, .MinusPercentEqual, "-=", .Sub, .Minus, "-", used),
        .ShlAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignBitShiftLeft, .AngleBracketAngleBracketLeftEqual, "<<=", .BitShiftLeft, .AngleBracketAngleBracketLeft, "<<", used),
        .ShrAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignBitShiftRight, .AngleBracketAngleBracketRightEqual, ">>=", .BitShiftRight, .AngleBracketAngleBracketRight, ">>", used),
        .AndAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignBitAnd, .AmpersandEqual, "&=", .BitAnd, .Ampersand, "&", used),
        .XorAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignBitXor, .CaretEqual, "^=", .BitXor, .Caret, "^", used),
        .OrAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignBitOr, .PipeEqual, "|=", .BitOr, .Pipe, "|", used),
        else => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangCompoundAssignOperator_getBeginLoc(stmt),
            "unsupported C translation {}",
            .{ZigClangCompoundAssignOperator_getOpcode(stmt)},
        ),
    }
}

fn transCreateCompoundAssign(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCompoundAssignOperator,
    assign_op: ast.Node.InfixOp.Op,
    assign_tok_id: std.zig.Token.Id,
    assign_bytes: []const u8,
    bin_op: ast.Node.InfixOp.Op,
    bin_tok_id: std.zig.Token.Id,
    bin_bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const is_shift = bin_op == .BitShiftLeft or bin_op == .BitShiftRight;
    const lhs = ZigClangCompoundAssignOperator_getLHS(stmt);
    const rhs = ZigClangCompoundAssignOperator_getRHS(stmt);
    const loc = ZigClangCompoundAssignOperator_getBeginLoc(stmt);
    if (used == .unused) {
        // common case
        // c: lhs += rhs
        // zig: lhs += rhs
        const lhs_node = try transExpr(rp, scope, lhs, .used, .l_value);
        const eq_token = try appendToken(rp.c, assign_tok_id, assign_bytes);
        var rhs_node = if (is_shift)
            try transExprCoercing(rp, scope, rhs, .used, .r_value)
        else
            try transExpr(rp, scope, rhs, .used, .r_value);

        if (is_shift) {
            const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
            const rhs_type = try qualTypeToLog2IntRef(rp, getExprQualType(rp.c, rhs), loc);
            try cast_node.params.push(rhs_type);
            _ = try appendToken(rp.c, .Comma, ",");
            try cast_node.params.push(rhs_node);
            cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            rhs_node = &cast_node.base;
        }
        if (scope.id != .Condition)
            _ = try appendToken(rp.c, .Semicolon, ";");
        return transCreateNodeInfixOp(rp, scope, lhs_node, assign_op, eq_token, rhs_node, .used, false);
    }
    // worst case
    // c:   lhs += rhs
    // zig: (blk: {
    // zig:     const _ref = &lhs;
    // zig:     _ref.* = _ref.* + rhs;
    // zig:     break :blk _ref.*
    // zig: })
    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const node = try transCreateNodeVarDecl(rp.c, false, true, ref);
    node.eq_token = try appendToken(rp.c, .Equal, "=");
    const addr_node = try transCreateNodePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    addr_node.rhs = try transExpr(rp, scope, lhs, .used, .l_value);
    node.init_node = &addr_node.base;
    node.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const bin_token = try appendToken(rp.c, bin_tok_id, bin_bytes);
    var rhs_node = try transExpr(rp, scope, rhs, .used, .r_value);
    if (is_shift) {
        const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
        const rhs_type = try qualTypeToLog2IntRef(rp, getExprQualType(rp.c, rhs), loc);
        try cast_node.params.push(rhs_type);
        _ = try appendToken(rp.c, .Comma, ",");
        try cast_node.params.push(rhs_node);
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        rhs_node = &cast_node.base;
    }
    const rhs_bin = try transCreateNodeInfixOp(rp, scope, ref_node, bin_op, bin_token, rhs_node, .used, false);

    _ = try appendToken(rp.c, .Semicolon, ";");

    const eq_token = try appendToken(rp.c, .Equal, "=");
    const assign = try transCreateNodeInfixOp(rp, scope, ref_node, .Assign, eq_token, rhs_bin, .used, false);
    try block_scope.block_node.statements.push(assign);

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label);
    break_node.rhs = ref_node;
    try block_scope.block_node.statements.push(&break_node.base);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_scope.block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
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
    const src_ty = ZigClangQualType_getTypePtr(src_type);
    const src_child_type = ZigClangType_getPointeeType(src_ty);

    if ((ZigClangQualType_isConstQualified(src_child_type) and
        !ZigClangQualType_isConstQualified(child_type)) or
        (ZigClangQualType_isVolatileQualified(src_child_type) and
        !ZigClangQualType_isVolatileQualified(child_type)))
    {
        // Casting away const or volatile requires us to use @intToPtr
        const inttoptr_node = try transCreateNodeBuiltinFnCall(rp.c, "@intToPtr");
        const dst_type_node = try transType(rp, ty, loc);
        try inttoptr_node.params.push(dst_type_node);
        _ = try appendToken(rp.c, .Comma, ",");

        const ptrtoint_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrToInt");
        try ptrtoint_node.params.push(expr);
        ptrtoint_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        try inttoptr_node.params.push(&ptrtoint_node.base);
        inttoptr_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &inttoptr_node.base;
    } else {
        // Implicit downcasting from higher to lower alignment values is forbidden,
        // use @alignCast to side-step this problem
        const ptrcast_node = try transCreateNodeBuiltinFnCall(rp.c, "@ptrCast");
        const dst_type_node = try transType(rp, ty, loc);
        try ptrcast_node.params.push(dst_type_node);
        _ = try appendToken(rp.c, .Comma, ",");

        if (ZigClangType_isVoidType(qualTypeCanon(child_type))) {
            // void has 1-byte alignment, so @alignCast is not needed
            try ptrcast_node.params.push(expr);
        } else if (typeIsOpaque(rp.c, qualTypeCanon(child_type), loc)) {
            // For opaque types a ptrCast is enough
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
}

fn transBreak(rp: RestorePoint, scope: *Scope) TransError!*ast.Node {
    const break_scope = scope.getBreakableScope();
    const br = try transCreateNodeBreak(rp.c, if (break_scope.id == .Switch)
        "__switch"
    else
        null);
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &br.base;
}

fn transFloatingLiteral(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangFloatingLiteral, used: ResultUsed) TransError!*ast.Node {
    // TODO use something more accurate
    const dbl = ZigClangAPFloat_getValueAsApproximateDouble(stmt);
    const node = try rp.c.a().create(ast.Node.FloatLiteral);
    node.* = .{
        .token = try appendTokenFmt(rp.c, .FloatLiteral, "{d}", .{dbl}),
    };
    return maybeSuppressResult(rp, scope, used, &node.base);
}

fn transBinaryConditionalOperator(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangBinaryConditionalOperator, used: ResultUsed) TransError!*ast.Node {
    // GNU extension of the ternary operator where the middle expression is
    // omitted, the conditition itself is returned if it evaluates to true
    const casted_stmt = @ptrCast(*const ZigClangAbstractConditionalOperator, stmt);
    const cond_expr = ZigClangAbstractConditionalOperator_getCond(casted_stmt);
    const true_expr = ZigClangAbstractConditionalOperator_getTrueExpr(casted_stmt);
    const false_expr = ZigClangAbstractConditionalOperator_getFalseExpr(casted_stmt);

    // c:   (cond_expr)?:(false_expr)
    // zig: (blk: {
    //          const _cond_temp = (cond_expr);
    //          break :blk if (_cond_temp) _cond_temp else (false_expr);
    //      })
    const lparen = try appendToken(rp.c, .LParen, "(");

    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);

    const mangled_name = try block_scope.makeMangledName(rp.c, "cond_temp");
    const tmp_var = try transCreateNodeVarDecl(rp.c, false, true, mangled_name);
    tmp_var.eq_token = try appendToken(rp.c, .Equal, "=");
    tmp_var.init_node = try transExpr(rp, &block_scope.base, cond_expr, .used, .r_value);
    tmp_var.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&tmp_var.base);

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label);

    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope{
        .parent = &block_scope.base,
        .id = .Condition,
    };
    const tmp_var_node = try transCreateNodeIdentifier(rp.c, mangled_name);

    const ty = ZigClangQualType_getTypePtr(getExprQualType(rp.c, cond_expr));
    const cond_node = try finishBoolExpr(rp, &block_scope.base, ZigClangExpr_getBeginLoc(cond_expr), ty, tmp_var_node, used);
    if_node.condition = cond_node;
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transCreateNodeIdentifier(rp.c, mangled_name);
    if_node.@"else" = try transCreateNodeElse(rp.c);
    if_node.@"else".?.body = try transExpr(rp, &block_scope.base, false_expr, .used, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    break_node.rhs = &if_node.base;
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&break_node.base);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");

    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = &block_scope.block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transConditionalOperator(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangConditionalOperator, used: ResultUsed) TransError!*ast.Node {
    const grouped = scope.id == .Condition;
    const lparen = if (grouped) try appendToken(rp.c, .LParen, "(") else undefined;
    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope{
        .parent = scope,
        .id = .Condition,
    };

    const casted_stmt = @ptrCast(*const ZigClangAbstractConditionalOperator, stmt);
    const cond_expr = ZigClangAbstractConditionalOperator_getCond(casted_stmt);
    const true_expr = ZigClangAbstractConditionalOperator_getTrueExpr(casted_stmt);
    const false_expr = ZigClangAbstractConditionalOperator_getFalseExpr(casted_stmt);

    if_node.condition = try transBoolExpr(rp, &cond_scope, cond_expr, .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transExpr(rp, scope, true_expr, .used, .r_value);

    if_node.@"else" = try transCreateNodeElse(rp.c);
    if_node.@"else".?.body = try transExpr(rp, scope, false_expr, .used, .r_value);

    if (grouped) {
        const rparen = try appendToken(rp.c, .RParen, ")");
        const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
        grouped_expr.* = .{
            .lparen = lparen,
            .expr = &if_node.base,
            .rparen = rparen,
        };
        return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
    } else {
        return maybeSuppressResult(rp, scope, used, &if_node.base);
    }
}

fn maybeSuppressResult(
    rp: RestorePoint,
    scope: *Scope,
    used: ResultUsed,
    result: *ast.Node,
) TransError!*ast.Node {
    if (used == .used) return result;
    if (scope.id != .Condition) {
        // NOTE: This is backwards, but the semicolon must immediately follow the node.
        _ = try appendToken(rp.c, .Semicolon, ";");
    } else { // TODO is there a way to avoid this hack?
        // this parenthesis must come immediately following the node
        _ = try appendToken(rp.c, .RParen, ")");
        // these need to come before _
        _ = try appendToken(rp.c, .Colon, ":");
        _ = try appendToken(rp.c, .LParen, "(");
    }
    const lhs = try transCreateNodeIdentifier(rp.c, "_");
    const op_token = try appendToken(rp.c, .Equal, "=");
    const op_node = try rp.c.a().create(ast.Node.InfixOp);
    op_node.* = .{
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

/// Produces a Zig AST node by translating a Clang QualType, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transQualTypeIntWidthOf(c: *Context, ty: ZigClangQualType, is_signed: bool) TypeError!*ast.Node {
    return transTypeIntWidthOf(c, qualTypeCanon(ty), is_signed);
}

/// Produces a Zig AST node by translating a Clang Type, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transTypeIntWidthOf(c: *Context, ty: *const ZigClangType, is_signed: bool) TypeError!*ast.Node {
    assert(ZigClangType_getTypeClass(ty) == .Builtin);
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);
    return transCreateNodeIdentifier(c, switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .Char_U, .Char_S, .UChar, .SChar, .Char8 => if (is_signed) "i8" else "u8",
        .UShort, .Short => if (is_signed) "c_short" else "c_ushort",
        .UInt, .Int => if (is_signed) "c_int" else "c_uint",
        .ULong, .Long => if (is_signed) "c_long" else "c_ulong",
        .ULongLong, .LongLong => if (is_signed) "c_longlong" else "c_ulonglong",
        .UInt128, .Int128 => if (is_signed) "i128" else "u128",
        .Char16 => if (is_signed) "i16" else "u16",
        .Char32 => if (is_signed) "i32" else "u32",
        else => unreachable, // only call this function when it has already been determined the type is int
    });
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

fn qualTypeIsBoolean(qt: ZigClangQualType) bool {
    return ZigClangType_isBooleanType(qualTypeCanon(qt));
}

fn qualTypeIntBitWidth(rp: RestorePoint, qt: ZigClangQualType, source_loc: ZigClangSourceLocation) !u32 {
    const ty = ZigClangQualType_getTypePtr(qt);

    switch (ZigClangType_getTypeClass(ty)) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const ZigClangBuiltinType, ty);

            switch (ZigClangBuiltinType_getKind(builtin_ty)) {
                .Char_U,
                .UChar,
                .Char_S,
                .SChar,
                => return 8,
                .UInt128,
                .Int128,
                => return 128,
                else => return 0,
            }

            unreachable;
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const ZigClangTypedefType, ty);
            const typedef_decl = ZigClangTypedefType_getDecl(typedef_ty);
            const type_name = try rp.c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, typedef_decl)));

            if (mem.eql(u8, type_name, "uint8_t") or mem.eql(u8, type_name, "int8_t")) {
                return 8;
            } else if (mem.eql(u8, type_name, "uint16_t") or mem.eql(u8, type_name, "int16_t")) {
                return 16;
            } else if (mem.eql(u8, type_name, "uint32_t") or mem.eql(u8, type_name, "int32_t")) {
                return 32;
            } else if (mem.eql(u8, type_name, "uint64_t") or mem.eql(u8, type_name, "int64_t")) {
                return 64;
            } else {
                return 0;
            }
        },
        else => return 0,
    }

    unreachable;
}

fn qualTypeToLog2IntRef(rp: RestorePoint, qt: ZigClangQualType, source_loc: ZigClangSourceLocation) !*ast.Node {
    const int_bit_width = try qualTypeIntBitWidth(rp, qt, source_loc);

    if (int_bit_width != 0) {
        // we can perform the log2 now.
        const cast_bit_width = math.log2_int(u64, int_bit_width);
        const node = try rp.c.a().create(ast.Node.IntegerLiteral);
        node.* = ast.Node.IntegerLiteral{
            .token = try appendTokenFmt(rp.c, .Identifier, "u{}", .{cast_bit_width}),
        };
        return &node.base;
    }

    const zig_type_node = try transQualType(rp, qt, source_loc);

    //    @import("std").math.Log2Int(c_long);
    //
    //    FnCall
    //        FieldAccess
    //            FieldAccess
    //                FnCall (.builtin = true)
    //                    Symbol "import"
    //                    StringLiteral "std"
    //                Symbol "math"
    //            Symbol "Log2Int"
    //        Symbol <zig_type_node> (var from above)

    const import_fn_call = try transCreateNodeBuiltinFnCall(rp.c, "@import");
    const std_token = try appendToken(rp.c, .StringLiteral, "\"std\"");
    const std_node = try rp.c.a().create(ast.Node.StringLiteral);
    std_node.* = ast.Node.StringLiteral{
        .token = std_token,
    };
    try import_fn_call.params.push(&std_node.base);
    import_fn_call.rparen_token = try appendToken(rp.c, .RParen, ")");

    const inner_field_access = try transCreateNodeFieldAccess(rp.c, &import_fn_call.base, "math");
    const outer_field_access = try transCreateNodeFieldAccess(rp.c, inner_field_access, "Log2Int");
    const log2int_fn_call = try transCreateNodeFnCall(rp.c, outer_field_access);
    try @fieldParentPtr(ast.Node.SuffixOp, "base", &log2int_fn_call.base).op.Call.params.push(zig_type_node);
    log2int_fn_call.rtoken = try appendToken(rp.c, .RParen, ")");

    return &log2int_fn_call.base;
}

fn qualTypeChildIsFnProto(qt: ZigClangQualType) bool {
    const ty = qualTypeCanon(qt);

    switch (ZigClangType_getTypeClass(ty)) {
        .FunctionProto, .FunctionNoProto => return true,
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

fn cIsInteger(qt: ZigClangQualType) bool {
    return cIsSignedInteger(qt) or cIsUnsignedInteger(qt);
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

fn cIntTypeToIndex(qt: ZigClangQualType) u8 {
    const c_type = qualTypeCanon(qt);
    assert(ZigClangType_getTypeClass(c_type) == .Builtin);
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .Bool, .Char_U, .Char_S, .UChar, .SChar, .Char8 => 1,
        .WChar_U, .WChar_S => 2,
        .UShort, .Short, .Char16 => 3,
        .UInt, .Int, .Char32 => 4,
        .ULong, .Long => 5,
        .ULongLong, .LongLong => 6,
        .UInt128, .Int128 => 7,
        else => unreachable,
    };
}

fn cIntTypeCmp(a: ZigClangQualType, b: ZigClangQualType) math.Order {
    const a_index = cIntTypeToIndex(a);
    const b_index = cIntTypeToIndex(b);
    return math.order(a_index, b_index);
}

fn cIsSignedInteger(qt: ZigClangQualType) bool {
    const c_type = qualTypeCanon(qt);
    if (ZigClangType_getTypeClass(c_type) != .Builtin) return false;
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .SChar,
        .Short,
        .Int,
        .Long,
        .LongLong,
        .Int128,
        .WChar_S,
        => true,
        else => false,
    };
}

fn cIsFloating(qt: ZigClangQualType) bool {
    const c_type = qualTypeCanon(qt);
    if (ZigClangType_getTypeClass(c_type) != .Builtin) return false;
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .Float,
        .Double,
        .Float128,
        .LongDouble,
        => true,
        else => false,
    };
}

fn cIsLongLongInteger(qt: ZigClangQualType) bool {
    const c_type = qualTypeCanon(qt);
    if (ZigClangType_getTypeClass(c_type) != .Builtin) return false;
    const builtin_ty = @ptrCast(*const ZigClangBuiltinType, c_type);
    return switch (ZigClangBuiltinType_getKind(builtin_ty)) {
        .LongLong, .ULongLong, .Int128, .UInt128 => true,
        else => false,
    };
}
fn transCreateNodeAssign(
    rp: RestorePoint,
    scope: *Scope,
    result_used: ResultUsed,
    lhs: *const ZigClangExpr,
    rhs: *const ZigClangExpr,
) !*ast.Node {
    // common case
    // c:   lhs = rhs
    // zig: lhs = rhs
    if (result_used == .unused) {
        const lhs_node = try transExpr(rp, scope, lhs, .used, .l_value);
        const eq_token = try appendToken(rp.c, .Equal, "=");
        var rhs_node = try transExprCoercing(rp, scope, rhs, .used, .r_value);
        if (!exprIsBooleanType(lhs) and isBoolRes(rhs_node)) {
            const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@boolToInt");
            try builtin_node.params.push(rhs_node);
            builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            rhs_node = &builtin_node.base;
        }
        if (scope.id != .Condition)
            _ = try appendToken(rp.c, .Semicolon, ";");
        return transCreateNodeInfixOp(rp, scope, lhs_node, .Assign, eq_token, rhs_node, .used, false);
    }

    // worst case
    // c:   lhs = rhs
    // zig: (blk: {
    // zig:     const _tmp = rhs;
    // zig:     lhs = _tmp;
    // zig:     break :blk _tmp
    // zig: })
    const block_scope = try Scope.Block.init(rp.c, scope, "blk");
    block_scope.block_node = try transCreateNodeBlock(rp.c, block_scope.label);
    const tmp = try block_scope.makeMangledName(rp.c, "tmp");

    const node = try transCreateNodeVarDecl(rp.c, false, true, tmp);
    node.eq_token = try appendToken(rp.c, .Equal, "=");
    var rhs_node = try transExpr(rp, &block_scope.base, rhs, .used, .r_value);
    if (!exprIsBooleanType(lhs) and isBoolRes(rhs_node)) {
        const builtin_node = try transCreateNodeBuiltinFnCall(rp.c, "@boolToInt");
        try builtin_node.params.push(rhs_node);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        rhs_node = &builtin_node.base;
    }
    node.init_node = rhs_node;
    node.semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&node.base);

    const lhs_node = try transExpr(rp, &block_scope.base, lhs, .used, .l_value);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const ident = try transCreateNodeIdentifier(rp.c, tmp);
    _ = try appendToken(rp.c, .Semicolon, ";");

    const assign = try transCreateNodeInfixOp(rp, &block_scope.base, lhs_node, .Assign, eq_token, ident, .used, false);
    try block_scope.block_node.statements.push(assign);

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label);
    break_node.rhs = try transCreateNodeIdentifier(rp.c, tmp);
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.block_node.statements.push(&break_node.base);
    block_scope.block_node.rbrace = try appendToken(rp.c, .RBrace, "}");
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &block_scope.block_node.base;
}

fn transCreateNodeBuiltinFnCall(c: *Context, name: []const u8) !*ast.Node.BuiltinCall {
    const builtin_token = try appendToken(c, .Builtin, name);
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.BuiltinCall);
    node.* = .{
        .builtin_token = builtin_token,
        .params = ast.Node.BuiltinCall.ParamList.init(c.a()),
        .rparen_token = undefined, // set after appending args
    };
    return node;
}

fn transCreateNodeFnCall(c: *Context, fn_expr: *ast.Node) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LParen, "(");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = .{
        .lhs = .{ .node = fn_expr },
        .op = .{
            .Call = .{
                .params = ast.Node.SuffixOp.Op.Call.ParamList.init(c.a()),
                .async_token = null,
            },
        },
        .rtoken = undefined, // set after appending args
    };
    return node;
}

fn transCreateNodeFieldAccess(c: *Context, container: *ast.Node, field_name: []const u8) !*ast.Node {
    const field_access_node = try c.a().create(ast.Node.InfixOp);
    field_access_node.* = .{
        .op_token = try appendToken(c, .Period, "."),
        .lhs = container,
        .op = .Period,
        .rhs = try transCreateNodeIdentifier(c, field_name),
    };
    return &field_access_node.base;
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
    lhs_node: *ast.Node,
    op: ast.Node.InfixOp.Op,
    op_token: ast.TokenIndex,
    rhs_node: *ast.Node,
    used: ResultUsed,
    grouped: bool,
) !*ast.Node {
    var lparen = if (grouped)
        try appendToken(rp.c, .LParen, "(")
    else
        null;
    const node = try rp.c.a().create(ast.Node.InfixOp);
    node.* = .{
        .op_token = op_token,
        .lhs = lhs_node,
        .op = op,
        .rhs = rhs_node,
    };
    if (!grouped) return maybeSuppressResult(rp, scope, used, &node.base);
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.a().create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen.?,
        .expr = &node.base,
        .rparen = rparen,
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transCreateNodeBoolInfixOp(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    op: ast.Node.InfixOp.Op,
    used: ResultUsed,
    grouped: bool,
) !*ast.Node {
    std.debug.assert(op == .BoolAnd or op == .BoolOr);

    const lhs_hode = try transBoolExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value, true);
    const op_token = if (op == .BoolAnd)
        try appendToken(rp.c, .Keyword_and, "and")
    else
        try appendToken(rp.c, .Keyword_or, "or");
    const rhs = try transBoolExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value, true);

    return transCreateNodeInfixOp(
        rp,
        scope,
        lhs_hode,
        op,
        op_token,
        rhs,
        used,
        grouped,
    );
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
    node.* = .{
        .op_token = op_token,
        .op = .{
            .PtrType = .{
                .const_token = if (is_const) try appendToken(c, .Keyword_const, "const") else null,
                .volatile_token = if (is_volatile) try appendToken(c, .Keyword_volatile, "volatile") else null,
            },
        },
        .rhs = undefined, // translate and set afterward
    };
    return node;
}

fn transCreateNodeAPInt(c: *Context, int: *const ZigClangAPSInt) !*ast.Node {
    const num_limbs = ZigClangAPSInt_getNumWords(int);
    var aps_int = int;
    const is_negative = ZigClangAPSInt_isSigned(int) and ZigClangAPSInt_isNegative(int);
    if (is_negative)
        aps_int = ZigClangAPSInt_negate(aps_int);
    var big = try math.big.Int.initCapacity(c.a(), num_limbs);
    if (is_negative)
        big.negate();
    defer big.deinit();
    const data = ZigClangAPSInt_getRawData(aps_int);
    var i: @TypeOf(num_limbs) = 0;
    while (i < num_limbs) : (i += 1) big.limbs[i] = data[i];
    const str = big.toString(c.a(), 10) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable,
    };
    const token = try appendToken(c, .IntegerLiteral, str);
    const node = try c.a().create(ast.Node.IntegerLiteral);
    node.* = .{
        .token = token,
    };
    if (is_negative)
        ZigClangAPSInt_free(aps_int);
    return &node.base;
}

fn transCreateNodeReturnExpr(c: *Context) !*ast.Node.ControlFlowExpression {
    const ltoken = try appendToken(c, .Keyword_return, "return");
    const node = try c.a().create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .Return,
        .rhs = null,
    };
    return node;
}

fn transCreateNodeUndefinedLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_undefined, "undefined");
    const node = try c.a().create(ast.Node.UndefinedLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeNullLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_null, "null");
    const node = try c.a().create(ast.Node.NullLiteral);
    node.* = .{
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
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeArrayInitializer(c: *Context, ty: *ast.Node) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LBrace, "{");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = ast.Node.SuffixOp{
        .lhs = .{ .node = ty },
        .op = .{
            .ArrayInitializer = ast.Node.SuffixOp.Op.InitList.init(c.a()),
        },
        .rtoken = undefined, // set after appending values
    };
    return node;
}

fn transCreateNodeStructInitializer(c: *Context, ty: *ast.Node) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LBrace, "{");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = ast.Node.SuffixOp{
        .lhs = .{ .node = ty },
        .op = .{
            .StructInitializer = ast.Node.SuffixOp.Op.InitList.init(c.a()),
        },
        .rtoken = undefined, // set after appending values
    };
    return node;
}

fn transCreateNodeInt(c: *Context, int: var) !*ast.Node {
    const token = try appendTokenFmt(c, .IntegerLiteral, "{}", .{int});
    const node = try c.a().create(ast.Node.IntegerLiteral);
    node.* = .{
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

fn transCreateNodeMacroFn(c: *Context, name: []const u8, ref: *ast.Node, proto_alias: *ast.Node.FnProto) !*ast.Node {
    const scope = &c.global_scope.base;

    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const inline_tok = try appendToken(c, .Keyword_inline, "inline");
    const fn_tok = try appendToken(c, .Keyword_fn, "fn");
    const name_tok = try appendIdentifier(c, name);
    _ = try appendToken(c, .LParen, "(");

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
        .callconv_expr = null,
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

fn transCreateNodeStringLiteral(c: *Context, str: []const u8) !*ast.Node {
    const node = try c.a().create(ast.Node.StringLiteral);
    node.* = .{
        .token = try appendToken(c, .StringLiteral, str),
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

fn transCreateNodeBreak(c: *Context, label: ?[]const u8) !*ast.Node.ControlFlowExpression {
    const ltoken = try appendToken(c, .Keyword_break, "break");
    const label_node = if (label) |l| blk: {
        _ = try appendToken(c, .Colon, ":");
        break :blk try transCreateNodeIdentifier(c, l);
    } else null;
    const node = try c.a().create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .{ .Break = label_node },
        .rhs = null,
    };
    return node;
}

fn transCreateNodeVarDecl(c: *Context, is_pub: bool, is_const: bool, name: []const u8) !*ast.Node.VarDecl {
    const visib_tok = if (is_pub) try appendToken(c, .Keyword_pub, "pub") else null;
    const mut_tok = if (is_const) try appendToken(c, .Keyword_const, "const") else try appendToken(c, .Keyword_var, "var");
    const name_tok = try appendIdentifier(c, name);

    const node = try c.a().create(ast.Node.VarDecl);
    node.* = .{
        .doc_comments = null,
        .visib_token = visib_tok,
        .thread_local_token = null,
        .name_token = name_tok,
        .eq_token = undefined,
        .mut_token = mut_tok,
        .comptime_token = null,
        .extern_export_token = null,
        .lib_name = null,
        .type_node = null,
        .align_node = null,
        .section_node = null,
        .init_node = null,
        .semicolon_token = undefined,
    };
    return node;
}

fn transCreateNodeWhile(c: *Context) !*ast.Node.While {
    const while_tok = try appendToken(c, .Keyword_while, "while");
    _ = try appendToken(c, .LParen, "(");

    const node = try c.a().create(ast.Node.While);
    node.* = .{
        .label = null,
        .inline_token = null,
        .while_token = while_tok,
        .condition = undefined,
        .payload = null,
        .continue_expr = null,
        .body = undefined,
        .@"else" = null,
    };
    return node;
}

fn transCreateNodeContinue(c: *Context) !*ast.Node {
    const ltoken = try appendToken(c, .Keyword_continue, "continue");
    const node = try c.a().create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .{ .Continue = null },
        .rhs = null,
    };
    _ = try appendToken(c, .Semicolon, ";");
    return &node.base;
}

fn transCreateNodeSwitch(c: *Context) !*ast.Node.Switch {
    const switch_tok = try appendToken(c, .Keyword_switch, "switch");
    _ = try appendToken(c, .LParen, "(");

    const node = try c.a().create(ast.Node.Switch);
    node.* = .{
        .switch_token = switch_tok,
        .expr = undefined,
        .cases = ast.Node.Switch.CaseList.init(c.a()),
        .rbrace = undefined,
    };
    return node;
}

fn transCreateNodeSwitchCase(c: *Context, lhs: *ast.Node) !*ast.Node.SwitchCase {
    const arrow_tok = try appendToken(c, .EqualAngleBracketRight, "=>");

    const node = try c.a().create(ast.Node.SwitchCase);
    node.* = .{
        .items = ast.Node.SwitchCase.ItemList.init(c.a()),
        .arrow_token = arrow_tok,
        .payload = null,
        .expr = undefined,
    };
    try node.items.push(lhs);
    return node;
}

fn transCreateNodeSwitchElse(c: *Context) !*ast.Node {
    const node = try c.a().create(ast.Node.SwitchElse);
    node.* = .{
        .token = try appendToken(c, .Keyword_else, "else"),
    };
    return &node.base;
}

fn transCreateNodeShiftOp(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    op: ast.Node.InfixOp.Op,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
) !*ast.Node {
    std.debug.assert(op == .BitShiftLeft or op == .BitShiftRight);

    const lhs_expr = ZigClangBinaryOperator_getLHS(stmt);
    const rhs_expr = ZigClangBinaryOperator_getRHS(stmt);
    const rhs_location = ZigClangExpr_getBeginLoc(rhs_expr);
    // lhs >> @as(u5, rh)

    const lhs = try transExpr(rp, scope, lhs_expr, .used, .l_value);
    const op_token = try appendToken(rp.c, op_tok_id, bytes);

    const cast_node = try transCreateNodeBuiltinFnCall(rp.c, "@intCast");
    const rhs_type = try qualTypeToLog2IntRef(rp, ZigClangBinaryOperator_getType(stmt), rhs_location);
    try cast_node.params.push(rhs_type);
    _ = try appendToken(rp.c, .Comma, ",");
    const rhs = try transExprCoercing(rp, scope, rhs_expr, .used, .r_value);
    try cast_node.params.push(rhs);
    cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

    const node = try rp.c.a().create(ast.Node.InfixOp);
    node.* = ast.Node.InfixOp{
        .op_token = op_token,
        .lhs = lhs,
        .op = op,
        .rhs = &cast_node.base,
    };

    return &node.base;
}

fn transCreateNodePtrDeref(c: *Context, lhs: *ast.Node) !*ast.Node {
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = .{
        .lhs = .{ .node = lhs },
        .op = .Deref,
        .rtoken = try appendToken(c, .PeriodAsterisk, ".*"),
    };
    return &node.base;
}

fn transCreateNodeArrayAccess(c: *Context, lhs: *ast.Node) !*ast.Node.SuffixOp {
    _ = try appendToken(c, .LBrace, "[");
    const node = try c.a().create(ast.Node.SuffixOp);
    node.* = .{
        .lhs = .{ .node = lhs },
        .op = .{
            .ArrayAccess = undefined,
        },
        .rtoken = undefined,
    };
    return node;
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
        .FunctionNoProto => {
            const fn_no_proto_ty = @ptrCast(*const ZigClangFunctionType, ty);
            const fn_proto = try transFnNoProto(rp, fn_no_proto_ty, source_loc, null, false);
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
            const size = ZigClangAPInt_getLimitedValue(size_ap_int, math.maxInt(usize));
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
            return (try transTypeDef(rp.c, typedef_decl, false)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to translate typedef declaration", .{});
        },
        .Record => {
            const record_ty = @ptrCast(*const ZigClangRecordType, ty);

            const record_decl = ZigClangRecordType_getDecl(record_ty);
            return (try transRecordDecl(rp.c, record_decl)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to resolve record declaration", .{});
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
        .MacroQualified => {
            const macroqualified_ty = @ptrCast(*const ZigClangMacroQualifiedType, ty);
            return transQualType(rp, ZigClangMacroQualifiedType_getModifiedType(macroqualified_ty), source_loc);
        },
        else => {
            const type_name = rp.c.str(ZigClangType_getTypeClassName(ty));
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported type: '{}'", .{type_name});
        },
    }
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
        .X86FastCall => return CallingConvention.Fastcall,
        .X86VectorCall, .AArch64VectorCall => return CallingConvention.Vectorcall,
        .X86ThisCall => return CallingConvention.Thiscall,
        .AAPCS => return CallingConvention.AAPCS,
        .AAPCS_VFP => return CallingConvention.AAPCSVFP,
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
    const is_extern = if (fn_decl_context) |ctx| !ctx.has_body else false;

    // TODO check for always_inline attribute
    // TODO check for align attribute

    // pub extern fn name(...) T
    const pub_tok = if (is_pub) try appendToken(rp.c, .Keyword_pub, "pub") else null;
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
            if (fn_decl) |decl| {
                const param = ZigClangFunctionDecl_getParamDecl(decl, @intCast(c_uint, i));
                const param_name: []const u8 = try rp.c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, param)));
                if (param_name.len < 1)
                    break :blk null;

                const result = try appendIdentifier(rp.c, param_name);
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

    const linksection_expr = blk: {
        if (fn_decl) |decl| {
            var str_len: usize = undefined;
            if (ZigClangFunctionDecl_getSectionAttribute(decl, &str_len)) |str_ptr| {
                _ = try appendToken(rp.c, .Keyword_linksection, "linksection");
                _ = try appendToken(rp.c, .LParen, "(");
                const expr = try transCreateNodeStringLiteral(
                    rp.c,
                    try std.fmt.allocPrint(rp.c.a(), "\"{}\"", .{str_ptr[0..str_len]}),
                );
                _ = try appendToken(rp.c, .RParen, ")");

                break :blk expr;
            }
        }
        break :blk null;
    };

    const align_expr = blk: {
        if (fn_decl) |decl| {
            const alignment = ZigClangFunctionDecl_getAlignedAttribute(decl, rp.c.clang_context);
            if (alignment != 0) {
                _ = try appendToken(rp.c, .Keyword_linksection, "align");
                _ = try appendToken(rp.c, .LParen, "(");
                // Clang reports the alignment in bits
                const expr = try transCreateNodeInt(rp.c, alignment / 8);
                _ = try appendToken(rp.c, .RParen, ")");

                break :blk expr;
            }
        }
        break :blk null;
    };

    const callconv_expr = if ((is_export or is_extern) and cc == .C) null else blk: {
        _ = try appendToken(rp.c, .Keyword_callconv, "callconv");
        _ = try appendToken(rp.c, .LParen, "(");
        const expr = try transCreateNodeEnumLiteral(rp.c, @tagName(cc));
        _ = try appendToken(rp.c, .RParen, ")");
        break :blk expr;
    };

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
    fn_proto.* = .{
        .doc_comments = null,
        .visib_token = pub_tok,
        .fn_token = fn_tok,
        .name_token = name_tok,
        .params = fn_params,
        .return_type = .{ .Explicit = return_type_node },
        .var_args_token = null, // TODO this field is broken in the AST data model
        .extern_export_inline_token = extern_export_inline_tok,
        .cc_token = null,
        .body_node = null,
        .lib_name = null,
        .align_expr = align_expr,
        .section_expr = linksection_expr,
        .callconv_expr = callconv_expr,
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

pub fn failDecl(c: *Context, loc: ZigClangSourceLocation, name: []const u8, comptime format: []const u8, args: var) !void {
    // pub const name = @compileError(msg);
    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
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
        .visib_token = pub_tok,
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

// TODO hook up with codegen
fn isZigPrimitiveType(name: []const u8) bool {
    if (name.len > 1 and (name[0] == 'u' or name[0] == 'i')) {
        for (name[1..]) |c| {
            switch (c) {
                '0'...'9' => {},
                else => return false,
            }
        }
        return true;
    }
    // void is invalid in c so it doesn't need to be checked.
    return mem.eql(u8, name, "comptime_float") or
        mem.eql(u8, name, "comptime_int") or
        mem.eql(u8, name, "bool") or
        mem.eql(u8, name, "isize") or
        mem.eql(u8, name, "usize") or
        mem.eql(u8, name, "f16") or
        mem.eql(u8, name, "f32") or
        mem.eql(u8, name, "f64") or
        mem.eql(u8, name, "f128") or
        mem.eql(u8, name, "c_longdouble") or
        mem.eql(u8, name, "noreturn") or
        mem.eql(u8, name, "type") or
        mem.eql(u8, name, "anyerror") or
        mem.eql(u8, name, "c_short") or
        mem.eql(u8, name, "c_ushort") or
        mem.eql(u8, name, "c_int") or
        mem.eql(u8, name, "c_uint") or
        mem.eql(u8, name, "c_long") or
        mem.eql(u8, name, "c_ulong") or
        mem.eql(u8, name, "c_longlong") or
        mem.eql(u8, name, "c_ulonglong");
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
    identifier.* = .{
        .token = token_index,
    };
    return &identifier.base;
}

fn transCreateNodeTypeIdentifier(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendTokenFmt(c, .Identifier, "{}", .{name});
    const identifier = try c.a().create(ast.Node.Identifier);
    identifier.* = .{
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
    var tok_list = CTokenList.init(c.a());
    const scope = c.global_scope;

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = ZigClangPreprocessingRecord_iterator_deref(it);
        tok_list.shrink(0);
        switch (ZigClangPreprocessedEntity_getKind(entity)) {
            .MacroDefinitionKind => {
                const macro = @ptrCast(*ZigClangMacroDefinitionRecord, entity);
                const raw_name = ZigClangMacroDefinitionRecord_getName_getNameStart(macro);
                const begin_loc = ZigClangMacroDefinitionRecord_getSourceRange_getBegin(macro);

                const name = try c.str(raw_name);
                // TODO https://github.com/ziglang/zig/issues/3756
                // TODO https://github.com/ziglang/zig/issues/1802
                const mangled_name = if (isZigPrimitiveType(name)) try std.fmt.allocPrint(c.a(), "_{}", .{name}) else name;
                if (scope.containsNow(mangled_name)) {
                    continue;
                }

                const begin_c = ZigClangSourceManager_getCharacterData(c.source_manager, begin_loc);
                const slice = begin_c[0..mem.len(begin_c)];

                tok_list.shrink(0);
                var tokenizer = std.c.Tokenizer{
                    .source = &std.c.tokenizer.Source{
                        .buffer = slice,
                        .file_name = undefined,
                        .tokens = undefined,
                    },
                };
                while (true) {
                    const tok = tokenizer.next();
                    switch (tok.id) {
                        .Nl, .Eof => {
                            try tok_list.push(tok);
                            break;
                        },
                        .LineComment, .MultiLineComment => continue,
                        else => {},
                    }
                    try tok_list.push(tok);
                }

                var tok_it = tok_list.iterator(0);
                const first_tok = tok_it.next().?;
                assert(first_tok.id == .Identifier and mem.eql(u8, slice[first_tok.start..first_tok.end], name));

                var macro_fn = false;
                const next = tok_it.peek().?;
                switch (next.id) {
                    .Identifier => {
                        // if it equals itself, ignore. for example, from stdio.h:
                        // #define stdin stdin
                        if (mem.eql(u8, name, slice[next.start..next.end])) {
                            continue;
                        }
                    },
                    .Nl, .Eof => {
                        // this means it is a macro without a value
                        // we don't care about such things
                        continue;
                    },
                    .LParen => {
                        // if the name is immediately followed by a '(' then it is a function
                        macro_fn = first_tok.end == next.start;
                    },
                    else => {},
                }

                (if (macro_fn)
                    transMacroFnDefine(c, &tok_it, slice, mangled_name, begin_loc)
                else
                    transMacroDefine(c, &tok_it, slice, mangled_name, begin_loc)) catch |err| switch (err) {
                    error.ParseError => continue,
                    error.OutOfMemory => |e| return e,
                };
            },
            else => {},
        }
    }
}

fn transMacroDefine(c: *Context, it: *CTokenList.Iterator, source: []const u8, name: []const u8, source_loc: ZigClangSourceLocation) ParseError!void {
    const scope = &c.global_scope.base;

    const node = try transCreateNodeVarDecl(c, true, true, name);
    node.eq_token = try appendToken(c, .Equal, "=");

    node.init_node = try parseCExpr(c, it, source, source_loc, scope);
    const last = it.next().?;
    if (last.id != .Eof and last.id != .Nl)
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: unexpected token {}",
            .{last.id},
        );

    node.semicolon_token = try appendToken(c, .Semicolon, ";");
    _ = try c.global_scope.macro_table.put(name, &node.base);
}

fn transMacroFnDefine(c: *Context, it: *CTokenList.Iterator, source: []const u8, name: []const u8, source_loc: ZigClangSourceLocation) ParseError!void {
    const block_scope = try Scope.Block.init(c, &c.global_scope.base, null);
    const scope = &block_scope.base;

    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const inline_tok = try appendToken(c, .Keyword_inline, "inline");
    const fn_tok = try appendToken(c, .Keyword_fn, "fn");
    const name_tok = try appendIdentifier(c, name);
    _ = try appendToken(c, .LParen, "(");

    if (it.next().?.id != .LParen) {
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: expected '('",
            .{},
        );
    }
    var fn_params = ast.Node.FnProto.ParamList.init(c.a());
    while (true) {
        const param_tok = it.next().?;
        if (param_tok.id != .Identifier) {
            return failDecl(
                c,
                source_loc,
                name,
                "unable to translate C expr: expected identifier",
                .{},
            );
        }

        const mangled_name = try block_scope.makeMangledName(c, source[param_tok.start..param_tok.end]);
        const param_name_tok = try appendIdentifier(c, mangled_name);
        _ = try appendToken(c, .Colon, ":");

        const token_index = try appendToken(c, .Keyword_var, "var");
        const identifier = try c.a().create(ast.Node.Identifier);
        identifier.* = .{
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
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: expected ')'",
            .{},
        );
    }

    _ = try appendToken(c, .RParen, ")");

    const type_of = try transCreateNodeBuiltinFnCall(c, "@TypeOf");
    type_of.rparen_token = try appendToken(c, .RParen, ")");

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
        .callconv_expr = null,
    };

    const block = try transCreateNodeBlock(c, null);

    const return_expr = try transCreateNodeReturnExpr(c);
    const expr = try parseCExpr(c, it, source, source_loc, scope);
    const last = it.next().?;
    if (last.id != .Eof and last.id != .Nl)
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: unexpected token {}",
            .{last.id},
        );
    _ = try appendToken(c, .Semicolon, ";");
    try type_of.params.push(expr);
    return_expr.rhs = expr;

    block.rbrace = try appendToken(c, .RBrace, "}");
    try block.statements.push(&return_expr.base);
    fn_proto.body_node = &block.base;
    _ = try c.global_scope.macro_table.put(name, &fn_proto.base);
}

const ParseError = Error || error{ParseError};

fn parseCExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const node = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
    switch (it.next().?.id) {
        .QuestionMark => {
            // must come immediately after expr
            _ = try appendToken(c, .RParen, ")");
            const if_node = try transCreateNodeIf(c);
            if_node.condition = node;
            if_node.body = try parseCPrimaryExpr(c, it, source, source_loc, scope);
            if (it.next().?.id != .Colon) {
                const first_tok = it.list.at(0);
                try failDecl(
                    c,
                    source_loc,
                    source[first_tok.start..first_tok.end],
                    "unable to translate C expr: expected ':'",
                    .{},
                );
                return error.ParseError;
            }
            if_node.@"else" = try transCreateNodeElse(c);
            if_node.@"else".?.body = try parseCPrimaryExpr(c, it, source, source_loc, scope);
            return &if_node.base;
        },
        else => {
            _ = it.prev();
            return node;
        },
    }
}

fn parseCNumLit(c: *Context, tok: *CToken, source: []const u8, source_loc: ZigClangSourceLocation) ParseError!*ast.Node {
    var lit_bytes = source[tok.start..tok.end];

    if (tok.id == .IntegerLiteral) {
        if (lit_bytes.len > 2 and lit_bytes[0] == '0') {
            switch (lit_bytes[1]) {
                '0'...'7' => {
                    // Octal
                    lit_bytes = try std.fmt.allocPrint(c.a(), "0o{}", .{lit_bytes});
                },
                'X' => {
                    // Hexadecimal with capital X, valid in C but not in Zig
                    lit_bytes = try std.fmt.allocPrint(c.a(), "0x{}", .{lit_bytes[2..]});
                },
                else => {},
            }
        }

        if (tok.id.IntegerLiteral == .None) {
            return transCreateNodeInt(c, lit_bytes);
        }

        const cast_node = try transCreateNodeBuiltinFnCall(c, "@as");
        try cast_node.params.push(try transCreateNodeIdentifier(c, switch (tok.id.IntegerLiteral) {
            .U => "c_uint",
            .L => "c_long",
            .LU => "c_ulong",
            .LL => "c_longlong",
            .LLU => "c_ulonglong",
            else => unreachable,
        }));
        lit_bytes = lit_bytes[0 .. lit_bytes.len - switch (tok.id.IntegerLiteral) {
            .U, .L => @as(u8, 1),
            .LU, .LL => 2,
            .LLU => 3,
            else => unreachable,
        }];
        _ = try appendToken(c, .Comma, ",");
        try cast_node.params.push(try transCreateNodeInt(c, lit_bytes));
        cast_node.rparen_token = try appendToken(c, .RParen, ")");
        return &cast_node.base;
    } else if (tok.id == .FloatLiteral) {
        if (lit_bytes[0] == '.')
            lit_bytes = try std.fmt.allocPrint(c.a(), "0{}", .{lit_bytes});
        if (tok.id.FloatLiteral == .None) {
            return transCreateNodeFloat(c, lit_bytes);
        }
        const cast_node = try transCreateNodeBuiltinFnCall(c, "@as");
        try cast_node.params.push(try transCreateNodeIdentifier(c, switch (tok.id.FloatLiteral) {
            .F => "f32",
            .L => "c_longdouble",
            else => unreachable,
        }));
        _ = try appendToken(c, .Comma, ",");
        try cast_node.params.push(try transCreateNodeFloat(c, lit_bytes[0 .. lit_bytes.len - 1]));
        cast_node.rparen_token = try appendToken(c, .RParen, ")");
        return &cast_node.base;
    } else unreachable;
}

fn zigifyEscapeSequences(ctx: *Context, source_bytes: []const u8, name: []const u8, source_loc: ZigClangSourceLocation) ![]const u8 {
    var source = source_bytes;
    for (source) |c, i| {
        if (c == '\"' or c == '\'') {
            source = source[i..];
            break;
        }
    }
    for (source) |c| {
        if (c == '\\') {
            break;
        }
    } else return source;
    var bytes = try ctx.a().alloc(u8, source.len * 2);
    var state: enum {
        Start,
        Escape,
        Hex,
        Octal,
    } = .Start;
    var i: usize = 0;
    var count: u8 = 0;
    var num: u8 = 0;
    for (source) |c| {
        switch (state) {
            .Escape => {
                switch (c) {
                    'n', 'r', 't', '\\', '\'', '\"' => {
                        bytes[i] = c;
                    },
                    '0'...'7' => {
                        count += 1;
                        num += c - '0';
                        state = .Octal;
                        bytes[i] = 'x';
                    },
                    'x' => {
                        state = .Hex;
                        bytes[i] = 'x';
                    },
                    'a' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '7';
                    },
                    'b' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '8';
                    },
                    'f' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'C';
                    },
                    'v' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'B';
                    },
                    '?' => {
                        i -= 1;
                        bytes[i] = '?';
                    },
                    'u', 'U' => {
                        try failDecl(ctx, source_loc, name, "macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.ParseError;
                    },
                    else => {
                        try failDecl(ctx, source_loc, name, "macro tokenizing failed: unknown escape sequence", .{});
                        return error.ParseError;
                    },
                }
                i += 1;
                if (state == .Escape)
                    state = .Start;
            },
            .Start => {
                if (c == '\\') {
                    state = .Escape;
                }
                bytes[i] = c;
                i += 1;
            },
            .Hex => {
                switch (c) {
                    '0'...'9' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, source_loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, source_loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try failDecl(ctx, source_loc, name, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'A' + 10;
                    },
                    else => {
                        i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                        num = 0;
                        if (c == '\\')
                            state = .Escape
                        else
                            state = .Start;
                        bytes[i] = c;
                        i += 1;
                    },
                }
            },
            .Octal => {
                const accept_digit = switch (c) {
                    // The maximum length of a octal literal is 3 digits
                    '0'...'7' => count < 3,
                    else => false,
                };

                if (accept_digit) {
                    count += 1;
                    num = std.math.mul(u8, num, 8) catch {
                        try failDecl(ctx, source_loc, name, "macro tokenizing failed: octal literal overflowed", .{});
                        return error.ParseError;
                    };
                    num += c - '0';
                } else {
                    i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
                    num = 0;
                    count = 0;
                    if (c == '\\')
                        state = .Escape
                    else
                        state = .Start;
                    bytes[i] = c;
                    i += 1;
                }
            },
        }
    }
    if (state == .Hex or state == .Octal)
        i += std.fmt.formatIntBuf(bytes[i..], num, 16, false, std.fmt.FormatOptions{ .fill = '0', .width = 2 });
    return bytes[0..i];
}

fn parseCPrimaryExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const tok = it.next().?;
    switch (tok.id) {
        .CharLiteral => {
            const first_tok = it.list.at(0);
            const token = try appendToken(c, .CharLiteral, try zigifyEscapeSequences(c, source[tok.start..tok.end], source[first_tok.start..first_tok.end], source_loc));
            const node = try c.a().create(ast.Node.CharLiteral);
            node.* = ast.Node.CharLiteral{
                .token = token,
            };
            return &node.base;
        },
        .StringLiteral => {
            const first_tok = it.list.at(0);
            const token = try appendToken(c, .StringLiteral, try zigifyEscapeSequences(c, source[tok.start..tok.end], source[first_tok.start..first_tok.end], source_loc));
            const node = try c.a().create(ast.Node.StringLiteral);
            node.* = ast.Node.StringLiteral{
                .token = token,
            };
            return &node.base;
        },
        .IntegerLiteral, .FloatLiteral => {
            return parseCNumLit(c, tok, source, source_loc);
        },
        // eventually this will be replaced by std.c.parse which will handle these correctly
        .Keyword_void => return transCreateNodeTypeIdentifier(c, "c_void"),
        .Keyword_bool => return transCreateNodeTypeIdentifier(c, "bool"),
        .Keyword_double => return transCreateNodeTypeIdentifier(c, "f64"),
        .Keyword_long => return transCreateNodeTypeIdentifier(c, "c_long"),
        .Keyword_int => return transCreateNodeTypeIdentifier(c, "c_int"),
        .Keyword_float => return transCreateNodeTypeIdentifier(c, "f32"),
        .Keyword_short => return transCreateNodeTypeIdentifier(c, "c_short"),
        .Keyword_char => return transCreateNodeTypeIdentifier(c, "c_char"),
        .Keyword_unsigned => return transCreateNodeTypeIdentifier(c, "c_uint"),
        .Identifier => {
            const mangled_name = scope.getAlias(source[tok.start..tok.end]);
            return transCreateNodeIdentifier(c, mangled_name);
        },
        .LParen => {
            const inner_node = try parseCExpr(c, it, source, source_loc, scope);

            if (it.next().?.id != .RParen) {
                const first_tok = it.list.at(0);
                try failDecl(
                    c,
                    source_loc,
                    source[first_tok.start..first_tok.end],
                    "unable to translate C expr: expected ')'' here",
                    .{},
                );
                return error.ParseError;
            }
            var saw_l_paren = false;
            switch (it.peek().?.id) {
                // (type)(to_cast)
                .LParen => {
                    saw_l_paren = true;
                    _ = it.next();
                },
                // (type)identifier
                .Identifier => {},
                else => return inner_node,
            }

            // hack to get zig fmt to render a comma in builtin calls
            _ = try appendToken(c, .Comma, ",");

            const node_to_cast = try parseCExpr(c, it, source, source_loc, scope);

            if (saw_l_paren and it.next().?.id != .RParen) {
                const first_tok = it.list.at(0);
                try failDecl(
                    c,
                    source_loc,
                    source[first_tok.start..first_tok.end],
                    "unable to translate C expr: expected ')''",
                    .{},
                );
                return error.ParseError;
            }

            //if (@typeInfo(@TypeOf(x)) == .Pointer)
            //    @ptrCast(dest, x)
            //else if (@typeInfo(@TypeOf(x)) == .Integer)
            //    @intToPtr(dest, x)
            //else
            //    @as(dest, x)

            const if_1 = try transCreateNodeIf(c);
            const type_id_1 = try transCreateNodeBuiltinFnCall(c, "@typeInfo");
            const type_of_1 = try transCreateNodeBuiltinFnCall(c, "@TypeOf");
            try type_id_1.params.push(&type_of_1.base);
            try type_of_1.params.push(node_to_cast);
            type_of_1.rparen_token = try appendToken(c, .RParen, ")");
            type_id_1.rparen_token = try appendToken(c, .RParen, ")");

            const cmp_1 = try c.a().create(ast.Node.InfixOp);
            cmp_1.* = .{
                .op_token = try appendToken(c, .EqualEqual, "=="),
                .lhs = &type_id_1.base,
                .op = .EqualEqual,
                .rhs = try transCreateNodeEnumLiteral(c, "Pointer"),
            };
            if_1.condition = &cmp_1.base;
            _ = try appendToken(c, .RParen, ")");

            const ptr_cast = try transCreateNodeBuiltinFnCall(c, "@ptrCast");
            try ptr_cast.params.push(inner_node);
            try ptr_cast.params.push(node_to_cast);
            ptr_cast.rparen_token = try appendToken(c, .RParen, ")");
            if_1.body = &ptr_cast.base;

            const else_1 = try transCreateNodeElse(c);
            if_1.@"else" = else_1;

            const if_2 = try transCreateNodeIf(c);
            const type_id_2 = try transCreateNodeBuiltinFnCall(c, "@typeInfo");
            const type_of_2 = try transCreateNodeBuiltinFnCall(c, "@TypeOf");
            try type_id_2.params.push(&type_of_2.base);
            try type_of_2.params.push(node_to_cast);
            type_of_2.rparen_token = try appendToken(c, .RParen, ")");
            type_id_2.rparen_token = try appendToken(c, .RParen, ")");

            const cmp_2 = try c.a().create(ast.Node.InfixOp);
            cmp_2.* = .{
                .op_token = try appendToken(c, .EqualEqual, "=="),
                .lhs = &type_id_2.base,
                .op = .EqualEqual,
                .rhs = try transCreateNodeEnumLiteral(c, "Int"),
            };
            if_2.condition = &cmp_2.base;
            else_1.body = &if_2.base;
            _ = try appendToken(c, .RParen, ")");

            const int_to_ptr = try transCreateNodeBuiltinFnCall(c, "@intToPtr");
            try int_to_ptr.params.push(inner_node);
            try int_to_ptr.params.push(node_to_cast);
            int_to_ptr.rparen_token = try appendToken(c, .RParen, ")");
            if_2.body = &int_to_ptr.base;

            const else_2 = try transCreateNodeElse(c);
            if_2.@"else" = else_2;

            const as = try transCreateNodeBuiltinFnCall(c, "@as");
            try as.params.push(inner_node);
            try as.params.push(node_to_cast);
            as.rparen_token = try appendToken(c, .RParen, ")");
            else_2.body = &as.base;

            return &if_1.base;
        },
        else => {
            const first_tok = it.list.at(0);
            try failDecl(
                c,
                source_loc,
                source[first_tok.start..first_tok.end],
                "unable to translate C expr: unexpected token {}",
                .{tok.id},
            );
            return error.ParseError;
        },
    }
}

fn parseCSuffixOpExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCPrimaryExpr(c, it, source, source_loc, scope);
    while (true) {
        const tok = it.next().?;
        switch (tok.id) {
            .Period => {
                const name_tok = it.next().?;
                if (name_tok.id != .Identifier) {
                    const first_tok = it.list.at(0);
                    try failDecl(
                        c,
                        source_loc,
                        source[first_tok.start..first_tok.end],
                        "unable to translate C expr: expected identifier",
                        .{},
                    );
                    return error.ParseError;
                }

                node = try transCreateNodeFieldAccess(c, node, source[name_tok.start..name_tok.end]);
            },
            .Arrow => {
                const name_tok = it.next().?;
                if (name_tok.id != .Identifier) {
                    const first_tok = it.list.at(0);
                    try failDecl(
                        c,
                        source_loc,
                        source[first_tok.start..first_tok.end],
                        "unable to translate C expr: expected identifier",
                        .{},
                    );
                    return error.ParseError;
                }

                const deref = try transCreateNodePtrDeref(c, node);
                node = try transCreateNodeFieldAccess(c, deref, source[name_tok.start..name_tok.end]);
            },
            .Asterisk => {
                if (it.peek().?.id == .RParen) {
                    // type *)

                    // hack to get zig fmt to render a comma in builtin calls
                    _ = try appendToken(c, .Comma, ",");

                    const ptr_kind = blk: {
                        // * token
                        _ = it.prev();
                        // last token of `node`
                        const prev_id = it.prev().?.id;
                        _ = it.next();
                        _ = it.next();
                        break :blk if (prev_id == .Keyword_void) .Asterisk else Token.Id.Identifier;
                    };

                    const ptr = try transCreateNodePtrType(c, false, false, ptr_kind);
                    ptr.rhs = node;
                    return &ptr.base;
                } else {
                    // expr * expr
                    const op_token = try appendToken(c, .Asterisk, "*");
                    const rhs = try parseCPrimaryExpr(c, it, source, source_loc, scope);
                    const mul_node = try c.a().create(ast.Node.InfixOp);
                    mul_node.* = .{
                        .op_token = op_token,
                        .lhs = node,
                        .op = .BitShiftLeft,
                        .rhs = rhs,
                    };
                    node = &mul_node.base;
                }
            },
            .AngleBracketAngleBracketLeft => {
                const op_token = try appendToken(c, .AngleBracketAngleBracketLeft, "<<");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const bitshift_node = try c.a().create(ast.Node.InfixOp);
                bitshift_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BitShiftLeft,
                    .rhs = rhs,
                };
                node = &bitshift_node.base;
            },
            .AngleBracketAngleBracketRight => {
                const op_token = try appendToken(c, .AngleBracketAngleBracketRight, ">>");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const bitshift_node = try c.a().create(ast.Node.InfixOp);
                bitshift_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BitShiftRight,
                    .rhs = rhs,
                };
                node = &bitshift_node.base;
            },
            .Pipe => {
                const op_token = try appendToken(c, .Pipe, "|");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const or_node = try c.a().create(ast.Node.InfixOp);
                or_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BitOr,
                    .rhs = rhs,
                };
                node = &or_node.base;
            },
            .Ampersand => {
                const op_token = try appendToken(c, .Ampersand, "&");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const bitand_node = try c.a().create(ast.Node.InfixOp);
                bitand_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BitAnd,
                    .rhs = rhs,
                };
                node = &bitand_node.base;
            },
            .Plus => {
                const op_token = try appendToken(c, .Plus, "+");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const add_node = try c.a().create(ast.Node.InfixOp);
                add_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .Add,
                    .rhs = rhs,
                };
                node = &add_node.base;
            },
            .Minus => {
                const op_token = try appendToken(c, .Minus, "-");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const sub_node = try c.a().create(ast.Node.InfixOp);
                sub_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .Sub,
                    .rhs = rhs,
                };
                node = &sub_node.base;
            },
            .AmpersandAmpersand => {
                const op_token = try appendToken(c, .Keyword_and, "and");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const and_node = try c.a().create(ast.Node.InfixOp);
                and_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BoolAnd,
                    .rhs = rhs,
                };
                node = &and_node.base;
            },
            .PipePipe => {
                const op_token = try appendToken(c, .Keyword_or, "or");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const or_node = try c.a().create(ast.Node.InfixOp);
                or_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .BoolOr,
                    .rhs = rhs,
                };
                node = &or_node.base;
            },
            .AngleBracketRight => {
                const op_token = try appendToken(c, .AngleBracketRight, ">");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const and_node = try c.a().create(ast.Node.InfixOp);
                and_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .GreaterThan,
                    .rhs = rhs,
                };
                node = &and_node.base;
            },
            .AngleBracketRightEqual => {
                const op_token = try appendToken(c, .AngleBracketRightEqual, ">=");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const and_node = try c.a().create(ast.Node.InfixOp);
                and_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .GreaterOrEqual,
                    .rhs = rhs,
                };
                node = &and_node.base;
            },
            .AngleBracketLeft => {
                const op_token = try appendToken(c, .AngleBracketLeft, "<");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const and_node = try c.a().create(ast.Node.InfixOp);
                and_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .LessThan,
                    .rhs = rhs,
                };
                node = &and_node.base;
            },
            .AngleBracketLeftEqual => {
                const op_token = try appendToken(c, .AngleBracketLeftEqual, "<=");
                const rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                const and_node = try c.a().create(ast.Node.InfixOp);
                and_node.* = .{
                    .op_token = op_token,
                    .lhs = node,
                    .op = .LessOrEqual,
                    .rhs = rhs,
                };
                node = &and_node.base;
            },
            .LBracket => {
                const arr_node = try transCreateNodeArrayAccess(c, node);
                arr_node.op.ArrayAccess = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                arr_node.rtoken = try appendToken(c, .RBracket, "]");
                node = &arr_node.base;
                if (it.next().?.id != .RBracket) {
                    const first_tok = it.list.at(0);
                    try failDecl(
                        c,
                        source_loc,
                        source[first_tok.start..first_tok.end],
                        "unable to translate C expr: expected ']'",
                        .{},
                    );
                    return error.ParseError;
                }
            },
            .LParen => {
                const call_node = try transCreateNodeFnCall(c, node);
                while (true) {
                    const arg = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                    try call_node.op.Call.params.push(arg);
                    const next = it.next().?;
                    if (next.id == .Comma)
                        _ = try appendToken(c, .Comma, ",")
                    else if (next.id == .RParen)
                        break
                    else {
                        const first_tok = it.list.at(0);
                        try failDecl(
                            c,
                            source_loc,
                            source[first_tok.start..first_tok.end],
                            "unable to translate C expr: expected ',' or ')'",
                            .{},
                        );
                        return error.ParseError;
                    }
                }
                call_node.rtoken = try appendToken(c, .RParen, ")");
                node = &call_node.base;
            },
            else => {
                _ = it.prev();
                return node;
            },
        }
    }
}

fn parseCPrefixOpExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const op_tok = it.next().?;

    switch (op_tok.id) {
        .Bang => {
            const node = try transCreateNodePrefixOp(c, .BoolNot, .Bang, "!");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Minus => {
            const node = try transCreateNodePrefixOp(c, .Negation, .Minus, "-");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Tilde => {
            const node = try transCreateNodePrefixOp(c, .BitNot, .Tilde, "~");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Asterisk => {
            const prefix_op_expr = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return try transCreateNodePtrDeref(c, prefix_op_expr);
        },
        else => {
            _ = it.prev();
            return try parseCSuffixOpExpr(c, it, source, source_loc, scope);
        },
    }
}

fn tokenSlice(c: *Context, token: ast.TokenIndex) []u8 {
    const tok = c.tree.tokens.at(token);
    const slice = c.source_buffer.toSlice()[tok.start..tok.end];
    return if (mem.startsWith(u8, slice, "@\""))
        slice[2 .. slice.len - 1]
    else
        slice;
}

fn getContainer(c: *Context, node: *ast.Node) ?*ast.Node {
    if (node.id == .ContainerDecl) {
        return node;
    } else if (node.id == .PrefixOp) {
        return node;
    } else if (node.cast(ast.Node.Identifier)) |ident| {
        if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |kv| {
            if (kv.value.cast(ast.Node.VarDecl)) |var_decl|
                return getContainer(c, var_decl.init_node.?);
        }
    } else if (node.cast(ast.Node.InfixOp)) |infix| {
        if (infix.op != .Period)
            return null;
        if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
            if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                var it = container.fields_and_decls.iterator(0);
                while (it.next()) |field_ref| {
                    const field = field_ref.*.cast(ast.Node.ContainerField).?;
                    const ident = infix.rhs.cast(ast.Node.Identifier).?;
                    if (mem.eql(u8, tokenSlice(c, field.name_token), tokenSlice(c, ident.token))) {
                        return getContainer(c, field.type_expr.?);
                    }
                }
            }
        }
    }
    return null;
}

fn getContainerTypeOf(c: *Context, ref: *ast.Node) ?*ast.Node {
    if (ref.cast(ast.Node.Identifier)) |ident| {
        if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |kv| {
            if (kv.value.cast(ast.Node.VarDecl)) |var_decl| {
                if (var_decl.type_node) |ty|
                    return getContainer(c, ty);
            }
        }
    } else if (ref.cast(ast.Node.InfixOp)) |infix| {
        if (infix.op != .Period)
            return null;
        if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
            if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                var it = container.fields_and_decls.iterator(0);
                while (it.next()) |field_ref| {
                    const field = field_ref.*.cast(ast.Node.ContainerField).?;
                    const ident = infix.rhs.cast(ast.Node.Identifier).?;
                    if (mem.eql(u8, tokenSlice(c, field.name_token), tokenSlice(c, ident.token))) {
                        return getContainer(c, field.type_expr.?);
                    }
                }
            } else
                return ty_node;
        }
    }
    return null;
}

fn getFnProto(c: *Context, ref: *ast.Node) ?*ast.Node.FnProto {
    const init = if (ref.cast(ast.Node.VarDecl)) |v| v.init_node.? else return null;
    if (getContainerTypeOf(c, init)) |ty_node| {
        if (ty_node.cast(ast.Node.PrefixOp)) |prefix| {
            if (prefix.op == .OptionalType) {
                if (prefix.rhs.cast(ast.Node.FnProto)) |fn_proto| {
                    return fn_proto;
                }
            }
        }
    }
    return null;
}

fn addMacros(c: *Context) !void {
    var macro_it = c.global_scope.macro_table.iterator();
    while (macro_it.next()) |kv| {
        if (getFnProto(c, kv.value)) |proto_node| {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            try addTopLevelDecl(c, kv.key, try transCreateNodeMacroFn(c, kv.key, kv.value, proto_node));
        } else {
            try addTopLevelDecl(c, kv.key, kv.value);
        }
    }
}
