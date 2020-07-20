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

const DeclTable = std.HashMap(usize, []const u8, addrHash, addrEql, false);

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
const AliasList = std.ArrayList(struct {
    alias: []const u8,
    name: []const u8,
});

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

    /// Represents an in-progress ast.Node.Switch. This struct is stack-allocated.
    /// When it is deinitialized, it produces an ast.Node.Switch which is allocated
    /// into the main arena.
    const Switch = struct {
        base: Scope,
        pending_block: Block,
        cases: []*ast.Node,
        case_index: usize,
        has_default: bool = false,
    };

    /// Used for the scope of condition expressions, for example `if (cond)`.
    /// The block is lazily initialised because it is only needed for rare
    /// cases of comma operators being used.
    const Condition = struct {
        base: Scope,
        block: ?Block = null,

        fn getBlockScope(self: *Condition, c: *Context) !*Block {
            if (self.block) |*b| return b;
            self.block = try Block.init(c, &self.base, "blk");
            return &self.block.?;
        }

        fn deinit(self: *Condition) void {
            if (self.block) |*b| b.deinit();
        }
    };

    /// Represents an in-progress ast.Node.Block. This struct is stack-allocated.
    /// When it is deinitialized, it produces an ast.Node.Block which is allocated
    /// into the main arena.
    const Block = struct {
        base: Scope,
        statements: std.ArrayList(*ast.Node),
        variables: AliasList,
        label: ?ast.TokenIndex,
        mangle_count: u32 = 0,
        lbrace: ast.TokenIndex,

        fn init(c: *Context, parent: *Scope, label: ?[]const u8) !Block {
            return Block{
                .base = .{
                    .id = .Block,
                    .parent = parent,
                },
                .statements = std.ArrayList(*ast.Node).init(c.gpa),
                .variables = AliasList.init(c.gpa),
                .label = if (label) |l| blk: {
                    const ll = try appendIdentifier(c, l);
                    _ = try appendToken(c, .Colon, ":");
                    break :blk ll;
                } else null,
                .lbrace = try appendToken(c, .LBrace, "{"),
            };
        }

        fn deinit(self: *Block) void {
            self.statements.deinit();
            self.variables.deinit();
            self.* = undefined;
        }

        fn complete(self: *Block, c: *Context) !*ast.Node.Block {
            // We reserve 1 extra statement if the parent is a Loop. This is in case of
            // do while, we want to put `if (cond) break;` at the end.
            const alloc_len = self.statements.items.len + @boolToInt(self.base.parent.?.id == .Loop);
            const node = try ast.Node.Block.alloc(c.arena, alloc_len);
            node.* = .{
                .statements_len = self.statements.items.len,
                .lbrace = self.lbrace,
                .rbrace = try appendToken(c, .RBrace, "}"),
                .label = self.label,
            };
            mem.copy(*ast.Node, node.statements(), self.statements.items);
            return node;
        }

        /// Given the desired name, return a name that does not shadow anything from outer scopes.
        /// Inserts the returned name into the scope.
        fn makeMangledName(scope: *Block, c: *Context, name: []const u8) ![]const u8 {
            const name_copy = try c.arena.dupe(u8, name);
            var proposed_name = name_copy;
            while (scope.contains(proposed_name)) {
                scope.mangle_count += 1;
                proposed_name = try std.fmt.allocPrint(c.arena, "{}_{}", .{ name, scope.mangle_count });
            }
            try scope.variables.append(.{ .name = name_copy, .alias = proposed_name });
            return proposed_name;
        }

        fn getAlias(scope: *Block, name: []const u8) []const u8 {
            for (scope.variables.items) |p| {
                if (mem.eql(u8, p.name, name))
                    return p.alias;
            }
            return scope.base.parent.?.getAlias(name);
        }

        fn localContains(scope: *Block, name: []const u8) bool {
            for (scope.variables.items) |p| {
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
                .sym_table = SymbolTable.init(c.arena),
                .macro_table = SymbolTable.init(c.arena),
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
                .Condition => return @fieldParentPtr(Condition, "base", scope).getBlockScope(c),
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
    gpa: *mem.Allocator,
    arena: *mem.Allocator,
    token_ids: std.ArrayListUnmanaged(Token.Id),
    token_locs: std.ArrayListUnmanaged(Token.Loc),
    errors: std.ArrayListUnmanaged(ast.Error),
    source_buffer: *std.ArrayList(u8),
    err: Error,
    source_manager: *ZigClangSourceManager,
    decl_table: DeclTable,
    alias_list: AliasList,
    global_scope: *Scope.Root,
    clang_context: *ZigClangASTContext,
    mangle_count: u32 = 0,
    root_decls: std.ArrayListUnmanaged(*ast.Node),

    /// This one is different than the root scope's name table. This contains
    /// a list of names that we found by visiting all the top level decls without
    /// translating them. The other maps are updated as we translate; this one is updated
    /// up front in a pre-processing step.
    global_names: std.StringHashMap(void),

    fn getMangle(c: *Context) u32 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*:0]const u8) ![]u8 {
        return mem.dupe(c.arena, u8, mem.spanZ(s));
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: ZigClangSourceLocation) ![]u8 {
        const spelling_loc = ZigClangSourceManager_getSpellingLoc(c.source_manager, loc);
        const filename_c = ZigClangSourceManager_getFilename(c.source_manager, spelling_loc);
        const filename = if (filename_c) |s| try c.str(s) else @as([]const u8, "(no file)");

        const line = ZigClangSourceManager_getSpellingLineNumber(c.source_manager, spelling_loc);
        const column = ZigClangSourceManager_getSpellingColumnNumber(c.source_manager, spelling_loc);
        return std.fmt.allocPrint(c.arena, "{}:{}:{}", .{ filename, line, column });
    }

    fn createCall(c: *Context, fn_expr: *ast.Node, params_len: ast.NodeIndex) !*ast.Node.Call {
        _ = try appendToken(c, .LParen, "(");
        const node = try ast.Node.Call.alloc(c.arena, params_len);
        node.* = .{
            .lhs = fn_expr,
            .params_len = params_len,
            .async_token = null,
            .rtoken = undefined, // set after appending args
        };
        return node;
    }

    fn createBuiltinCall(c: *Context, name: []const u8, params_len: ast.NodeIndex) !*ast.Node.BuiltinCall {
        const builtin_token = try appendToken(c, .Builtin, name);
        _ = try appendToken(c, .LParen, "(");
        const node = try ast.Node.BuiltinCall.alloc(c.arena, params_len);
        node.* = .{
            .builtin_token = builtin_token,
            .params_len = params_len,
            .rparen_token = undefined, // set after appending args
        };
        return node;
    }

    fn createBlock(c: *Context, label: ?[]const u8, statements_len: ast.NodeIndex) !*ast.Node.Block {
        const label_node = if (label) |l| blk: {
            const ll = try appendIdentifier(c, l);
            _ = try appendToken(c, .Colon, ":");
            break :blk ll;
        } else null;
        const block_node = try ast.Node.Block.alloc(c.arena, statements_len);
        block_node.* = .{
            .label = label_node,
            .lbrace = try appendToken(c, .LBrace, "{"),
            .statements_len = statements_len,
            .rbrace = undefined,
        };
        return block_node;
    }
};

pub fn translate(
    gpa: *mem.Allocator,
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

    var source_buffer = std.ArrayList(u8).init(gpa);
    defer source_buffer.deinit();

    // For memory that has the same lifetime as the Tree that we return
    // from this function.
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();

    var context = Context{
        .gpa = gpa,
        .arena = &arena.allocator,
        .source_buffer = &source_buffer,
        .source_manager = ZigClangASTUnit_getSourceManager(ast_unit),
        .err = undefined,
        .decl_table = DeclTable.init(gpa),
        .alias_list = AliasList.init(gpa),
        .global_scope = try arena.allocator.create(Scope.Root),
        .clang_context = ZigClangASTUnit_getASTContext(ast_unit).?,
        .global_names = std.StringHashMap(void).init(gpa),
        .token_ids = .{},
        .token_locs = .{},
        .errors = .{},
        .root_decls = .{},
    };
    context.global_scope.* = Scope.Root.init(&context);
    defer context.decl_table.deinit();
    defer context.alias_list.deinit();
    defer context.token_ids.deinit(gpa);
    defer context.token_locs.deinit(gpa);
    defer context.errors.deinit(gpa);
    defer context.global_names.deinit();
    defer context.root_decls.deinit(gpa);

    try prepopulateGlobalNameTable(ast_unit, &context);

    if (!ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, &context, declVisitorC)) {
        return context.err;
    }

    try transPreprocessorEntities(&context, ast_unit);

    try addMacros(&context);
    for (context.alias_list.items) |alias| {
        if (!context.global_scope.sym_table.contains(alias.alias)) {
            try createAlias(&context, alias);
        }
    }

    const eof_token = try appendToken(&context, .Eof, "");
    const root_node = try ast.Node.Root.create(&arena.allocator, context.root_decls.items.len, eof_token);
    mem.copy(*ast.Node, root_node.decls(), context.root_decls.items);

    if (false) {
        std.debug.warn("debug source:\n{}\n==EOF==\ntokens:\n", .{source_buffer.items});
        for (context.token_ids.items) |token| {
            std.debug.warn("{}\n", .{token});
        }
    }

    const tree = try arena.allocator.create(ast.Tree);
    tree.* = .{
        .gpa = gpa,
        .source = try arena.allocator.dupe(u8, source_buffer.items),
        .token_ids = context.token_ids.toOwnedSlice(gpa),
        .token_locs = context.token_locs.toOwnedSlice(gpa),
        .errors = context.errors.toOwnedSlice(gpa),
        .root_node = root_node,
        .arena = arena.state,
        .generated = true,
    };
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
    var block_scope = try Scope.Block.init(rp.c, &c.global_scope.base, null);
    defer block_scope.deinit();
    var scope = &block_scope.base;

    var param_id: c_uint = 0;
    for (proto_node.params()) |*param, i| {
        const param_name = if (param.name_token) |name_tok|
            tokenSlice(c, name_tok)
        else
            return failDecl(c, fn_decl_loc, fn_name, "function {} parameter has no name", .{fn_name});

        const c_param = ZigClangFunctionDecl_getParamDecl(fn_decl, param_id);
        const qual_type = ZigClangParmVarDecl_getOriginalType(c_param);
        const is_const = ZigClangQualType_isConstQualified(qual_type);

        const mangled_param_name = try block_scope.makeMangledName(c, param_name);

        if (!is_const) {
            const bare_arg_name = try std.fmt.allocPrint(c.arena, "arg_{}", .{mangled_param_name});
            const arg_name = try block_scope.makeMangledName(c, bare_arg_name);

            const mut_tok = try appendToken(c, .Keyword_var, "var");
            const name_tok = try appendIdentifier(c, mangled_param_name);
            const eq_token = try appendToken(c, .Equal, "=");
            const init_node = try transCreateNodeIdentifier(c, arg_name);
            const semicolon_token = try appendToken(c, .Semicolon, ";");
            const node = try ast.Node.VarDecl.create(c.arena, .{
                .mut_token = mut_tok,
                .name_token = name_tok,
                .semicolon_token = semicolon_token,
            }, .{
                .eq_token = eq_token,
                .init_node = init_node,
            });
            try block_scope.statements.append(&node.base);
            param.name_token = try appendIdentifier(c, arg_name);
            _ = try appendToken(c, .Colon, ":");
        }

        param_id += 1;
    }

    const casted_body = @ptrCast(*const ZigClangCompoundStmt, body_stmt);
    transCompoundStmtInline(rp, &block_scope.base, casted_body, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function", .{}),
    };
    const body_node = try block_scope.complete(rp.c);
    proto_node.setTrailer("body_node", &body_node.base);
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
    const checked_name = if (isZigPrimitiveType(var_name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ var_name, c.getMangle() }) else var_name;
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
        eq_tok = try appendToken(c, .Equal, "=");
        init_node = try transCreateNodeIdentifierUnchecked(c, "undefined");
    }

    const linksection_expr = blk: {
        var str_len: usize = undefined;
        if (ZigClangVarDecl_getSectionAttribute(var_decl, &str_len)) |str_ptr| {
            _ = try appendToken(rp.c, .Keyword_linksection, "linksection");
            _ = try appendToken(rp.c, .LParen, "(");
            const expr = try transCreateNodeStringLiteral(
                rp.c,
                try std.fmt.allocPrint(rp.c.arena, "\"{}\"", .{str_ptr[0..str_len]}),
            );
            _ = try appendToken(rp.c, .RParen, ")");

            break :blk expr;
        }
        break :blk null;
    };

    const align_expr = blk: {
        const alignment = ZigClangVarDecl_getAlignedAttribute(var_decl, rp.c.clang_context);
        if (alignment != 0) {
            _ = try appendToken(rp.c, .Keyword_align, "align");
            _ = try appendToken(rp.c, .LParen, "(");
            // Clang reports the alignment in bits
            const expr = try transCreateNodeInt(rp.c, alignment / 8);
            _ = try appendToken(rp.c, .RParen, ")");

            break :blk expr;
        }
        break :blk null;
    };

    const node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = try appendToken(c, .Semicolon, ";"),
    }, .{
        .visib_token = visib_tok,
        .thread_local_token = thread_local_token,
        .eq_token = eq_tok,
        .extern_export_token = extern_tok,
        .type_node = type_node,
        .align_node = align_expr,
        .section_node = linksection_expr,
        .init_node = init_node,
    });
    return addTopLevelDecl(c, checked_name, &node.base);
}

fn transTypeDefAsBuiltin(c: *Context, typedef_decl: *const ZigClangTypedefNameDecl, builtin_name: []const u8) !*ast.Node {
    _ = try c.decl_table.put(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)), builtin_name);
    return transCreateNodeIdentifier(c, builtin_name);
}

fn checkForBuiltinTypedef(checked_name: []const u8) ?[]const u8 {
    const table = [_][2][]const u8{
        .{ "uint8_t", "u8" },
        .{ "int8_t", "i8" },
        .{ "uint16_t", "u16" },
        .{ "int16_t", "i16" },
        .{ "uint32_t", "u32" },
        .{ "int32_t", "i32" },
        .{ "uint64_t", "u64" },
        .{ "int64_t", "i64" },
        .{ "intptr_t", "isize" },
        .{ "uintptr_t", "usize" },
        .{ "ssize_t", "isize" },
        .{ "size_t", "usize" },
    };

    for (table) |entry| {
        if (mem.eql(u8, checked_name, entry[0])) {
            return entry[1];
        }
    }

    return null;
}

fn transTypeDef(c: *Context, typedef_decl: *const ZigClangTypedefNameDecl, top_level_visit: bool) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)))) |name|
        return transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);

    const typedef_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, typedef_decl)));

    // TODO https://github.com/ziglang/zig/issues/3756
    // TODO https://github.com/ziglang/zig/issues/1802
    const checked_name = if (isZigPrimitiveType(typedef_name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ typedef_name, c.getMangle() }) else typedef_name;
    if (checkForBuiltinTypedef(checked_name)) |builtin| {
        return transTypeDefAsBuiltin(c, typedef_decl, builtin);
    }

    if (!top_level_visit) {
        return transCreateNodeIdentifier(c, checked_name);
    }

    _ = try c.decl_table.put(@ptrToInt(ZigClangTypedefNameDecl_getCanonicalDecl(typedef_decl)), checked_name);
    const node = (try transCreateNodeTypedef(rp, typedef_decl, true, checked_name)) orelse return null;
    try addTopLevelDecl(c, checked_name, node);
    return transCreateNodeIdentifier(c, checked_name);
}

fn transCreateNodeTypedef(
    rp: RestorePoint,
    typedef_decl: *const ZigClangTypedefNameDecl,
    toplevel: bool,
    checked_name: []const u8,
) Error!?*ast.Node {
    const visib_tok = if (toplevel) try appendToken(rp.c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, checked_name);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const child_qt = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
    const typedef_loc = ZigClangTypedefNameDecl_getLocation(typedef_decl);
    const init_node = transQualType(rp, child_qt, typedef_loc) catch |err| switch (err) {
        error.UnsupportedType => {
            try failDecl(rp.c, typedef_loc, checked_name, "unable to resolve typedef child type", .{});
            return null;
        },
        error.OutOfMemory => |e| return e,
    };
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");

    const node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .visib_token = visib_tok,
        .eq_token = eq_token,
        .init_node = init_node,
    });
    return &node.base;
}

fn transRecordDecl(c: *Context, record_decl: *const ZigClangRecordDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)))) |name|
        return try transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const record_loc = ZigClangRecordDecl_getLocation(record_decl);

    var bare_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, record_decl)));
    var is_unnamed = false;
    // Record declarations such as `struct {...} x` have no name but they're not
    // anonymous hence here isAnonymousStructOrUnion is not needed
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{c.getMangle()});
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

    const name = try std.fmt.allocPrint(c.arena, "{}_{}", .{ container_kind_name, bare_name });
    _ = try c.decl_table.put(@ptrToInt(ZigClangRecordDecl_getCanonicalDecl(record_decl)), name);

    const visib_tok = if (!is_unnamed) try appendToken(c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);

    const eq_token = try appendToken(c, .Equal, "=");

    var semicolon: ast.TokenIndex = undefined;
    const init_node = blk: {
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

        var fields_and_decls = std.ArrayList(*ast.Node).init(c.gpa);
        defer fields_and_decls.deinit();

        var unnamed_field_count: u32 = 0;
        var it = ZigClangRecordDecl_field_begin(record_def);
        const end_it = ZigClangRecordDecl_field_end(record_def);
        while (ZigClangRecordDecl_field_iterator_neq(it, end_it)) : (it = ZigClangRecordDecl_field_iterator_next(it)) {
            const field_decl = ZigClangRecordDecl_field_iterator_deref(it);
            const field_loc = ZigClangFieldDecl_getLocation(field_decl);
            const field_qt = ZigClangFieldDecl_getType(field_decl);

            if (ZigClangFieldDecl_isBitField(field_decl)) {
                const opaque = try transCreateNodeOpaqueType(c);
                semicolon = try appendToken(c, .Semicolon, ";");
                try emitWarning(c, field_loc, "{} demoted to opaque type - has bitfield", .{container_kind_name});
                break :blk opaque;
            }

            if (ZigClangType_isIncompleteOrZeroLengthArrayType(qualTypeCanon(field_qt), c.clang_context)) {
                const opaque = try transCreateNodeOpaqueType(c);
                semicolon = try appendToken(c, .Semicolon, ";");
                try emitWarning(c, field_loc, "{} demoted to opaque type - has variable length array", .{container_kind_name});
                break :blk opaque;
            }

            var is_anon = false;
            var raw_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, field_decl)));
            if (ZigClangFieldDecl_isAnonymousStructOrUnion(field_decl) or raw_name.len == 0) {
                // Context.getMangle() is not used here because doing so causes unpredictable field names for anonymous fields.
                raw_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{unnamed_field_count});
                unnamed_field_count += 1;
                is_anon = true;
            }
            const field_name = try appendIdentifier(c, raw_name);
            _ = try appendToken(c, .Colon, ":");
            const field_type = transQualType(rp, field_qt, field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    const opaque = try transCreateNodeOpaqueType(c);
                    semicolon = try appendToken(c, .Semicolon, ";");
                    try emitWarning(c, record_loc, "{} demoted to opaque type - unable to translate type of field {}", .{ container_kind_name, raw_name });
                    break :blk opaque;
                },
                else => |e| return e,
            };

            const align_expr = blk: {
                const alignment = ZigClangFieldDecl_getAlignedAttribute(field_decl, rp.c.clang_context);
                if (alignment != 0) {
                    _ = try appendToken(rp.c, .Keyword_align, "align");
                    _ = try appendToken(rp.c, .LParen, "(");
                    // Clang reports the alignment in bits
                    const expr = try transCreateNodeInt(rp.c, alignment / 8);
                    _ = try appendToken(rp.c, .RParen, ")");

                    break :blk expr;
                }
                break :blk null;
            };

            const field_node = try c.arena.create(ast.Node.ContainerField);
            field_node.* = .{
                .doc_comments = null,
                .comptime_token = null,
                .name_token = field_name,
                .type_expr = field_type,
                .value_expr = null,
                .align_expr = align_expr,
            };

            if (is_anon) {
                _ = try c.decl_table.put(
                    @ptrToInt(ZigClangFieldDecl_getCanonicalDecl(field_decl)),
                    raw_name,
                );
            }

            try fields_and_decls.append(&field_node.base);
            _ = try appendToken(c, .Comma, ",");
        }
        const container_node = try ast.Node.ContainerDecl.alloc(c.arena, fields_and_decls.items.len);
        container_node.* = .{
            .layout_token = layout_tok,
            .kind_token = container_tok,
            .init_arg_expr = .None,
            .fields_and_decls_len = fields_and_decls.items.len,
            .lbrace_token = lbrace_token,
            .rbrace_token = try appendToken(c, .RBrace, "}"),
        };
        mem.copy(*ast.Node, container_node.fieldsAndDecls(), fields_and_decls.items);
        semicolon = try appendToken(c, .Semicolon, ";");
        break :blk &container_node.base;
    };

    const node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon,
    }, .{
        .visib_token = visib_tok,
        .eq_token = eq_token,
        .init_node = init_node,
    });

    try addTopLevelDecl(c, name, &node.base);
    if (!is_unnamed)
        try c.alias_list.append(.{ .alias = bare_name, .name = name });
    return transCreateNodeIdentifier(c, name);
}

fn transEnumDecl(c: *Context, enum_decl: *const ZigClangEnumDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)))) |name|
        return try transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const enum_loc = ZigClangEnumDecl_getLocation(enum_decl);

    var bare_name = try c.str(ZigClangNamedDecl_getName_bytes_begin(@ptrCast(*const ZigClangNamedDecl, enum_decl)));
    var is_unnamed = false;
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    const name = try std.fmt.allocPrint(c.arena, "enum_{}", .{bare_name});
    _ = try c.decl_table.put(@ptrToInt(ZigClangEnumDecl_getCanonicalDecl(enum_decl)), name);

    const visib_tok = if (!is_unnamed) try appendToken(c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);
    const eq_token = try appendToken(c, .Equal, "=");

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

        var fields_and_decls = std.ArrayList(*ast.Node).init(c.gpa);
        defer fields_and_decls.deinit();

        const int_type = ZigClangEnumDecl_getIntegerType(enum_decl);
        // The underlying type may be null in case of forward-declared enum
        // types, while that's not ISO-C compliant many compilers allow this and
        // default to the usual integer type used for all the enums.

        // default to c_int since msvc and gcc default to different types
        _ = try appendToken(c, .LParen, "(");
        const init_arg_expr = ast.Node.ContainerDecl.InitArg{
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

        const lbrace_token = try appendToken(c, .LBrace, "{");

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

            const field_node = try c.arena.create(ast.Node.ContainerField);
            field_node.* = .{
                .doc_comments = null,
                .comptime_token = null,
                .name_token = field_name_tok,
                .type_expr = null,
                .value_expr = int_node,
                .align_expr = null,
            };

            try fields_and_decls.append(&field_node.base);
            _ = try appendToken(c, .Comma, ",");

            // In C each enum value is in the global namespace. So we put them there too.
            // At this point we can rely on the enum emitting successfully.
            const tld_visib_tok = try appendToken(c, .Keyword_pub, "pub");
            const tld_mut_tok = try appendToken(c, .Keyword_const, "const");
            const tld_name_tok = try appendIdentifier(c, enum_val_name);
            const tld_eq_token = try appendToken(c, .Equal, "=");
            const cast_node = try rp.c.createBuiltinCall("@enumToInt", 1);
            const enum_ident = try transCreateNodeIdentifier(c, name);
            const period_tok = try appendToken(c, .Period, ".");
            const field_ident = try transCreateNodeIdentifier(c, field_name);
            const field_access_node = try c.arena.create(ast.Node.SimpleInfixOp);
            field_access_node.* = .{
                .base = .{ .tag = .Period },
                .op_token = period_tok,
                .lhs = enum_ident,
                .rhs = field_ident,
            };
            cast_node.params()[0] = &field_access_node.base;
            cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            const tld_init_node = &cast_node.base;
            const tld_semicolon_token = try appendToken(c, .Semicolon, ";");
            const tld_node = try ast.Node.VarDecl.create(c.arena, .{
                .name_token = tld_name_tok,
                .mut_token = tld_mut_tok,
                .semicolon_token = tld_semicolon_token,
            }, .{
                .visib_token = tld_visib_tok,
                .eq_token = tld_eq_token,
                .init_node = tld_init_node,
            });
            try addTopLevelDecl(c, field_name, &tld_node.base);
        }
        // make non exhaustive
        const field_node = try c.arena.create(ast.Node.ContainerField);
        field_node.* = .{
            .doc_comments = null,
            .comptime_token = null,
            .name_token = try appendIdentifier(c, "_"),
            .type_expr = null,
            .value_expr = null,
            .align_expr = null,
        };

        try fields_and_decls.append(&field_node.base);
        _ = try appendToken(c, .Comma, ",");
        const container_node = try ast.Node.ContainerDecl.alloc(c.arena, fields_and_decls.items.len);
        container_node.* = .{
            .layout_token = extern_tok,
            .kind_token = container_tok,
            .init_arg_expr = init_arg_expr,
            .fields_and_decls_len = fields_and_decls.items.len,
            .lbrace_token = lbrace_token,
            .rbrace_token = try appendToken(c, .RBrace, "}"),
        };
        mem.copy(*ast.Node, container_node.fieldsAndDecls(), fields_and_decls.items);
        break :blk &container_node.base;
    } else
        try transCreateNodeOpaqueType(c);

    const semicolon_token = try appendToken(c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .visib_token = visib_tok,
        .eq_token = eq_token,
        .init_node = init_node,
    });

    try addTopLevelDecl(c, name, &node.base);
    if (!is_unnamed)
        try c.alias_list.append(.{ .alias = bare_name, .name = name });
    return transCreateNodeIdentifier(c, name);
}

fn createAlias(c: *Context, alias: anytype) !void {
    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, alias.alias);
    const eq_token = try appendToken(c, .Equal, "=");
    const init_node = try transCreateNodeIdentifier(c, alias.name);
    const semicolon_token = try appendToken(c, .Semicolon, ";");

    const node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .visib_token = visib_tok,
        .eq_token = eq_token,
        .init_node = init_node,
    });
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
            if (expr.tag == .GroupedExpression) return maybeSuppressResult(rp, scope, result_used, expr);
            const node = try rp.c.arena.create(ast.Node.GroupedExpression);
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
            const block = try rp.c.createBlock(null, 0);
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
            if (expr.tag == .GroupedExpression) return maybeSuppressResult(rp, scope, result_used, expr);
            const node = try rp.c.arena.create(ast.Node.GroupedExpression);
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
    var op_id: ast.Node.Tag = undefined;
    switch (op) {
        .Assign => return try transCreateNodeAssign(rp, scope, result_used, ZigClangBinaryOperator_getLHS(stmt), ZigClangBinaryOperator_getRHS(stmt)),
        .Comma => {
            const block_scope = try scope.findBlockScope(rp.c);
            const expr = block_scope.base.parent == scope;
            const lparen = if (expr) try appendToken(rp.c, .LParen, "(") else undefined;

            const lhs = try transExpr(rp, &block_scope.base, ZigClangBinaryOperator_getLHS(stmt), .unused, .r_value);
            try block_scope.statements.append(lhs);

            const rhs = try transExpr(rp, &block_scope.base, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
            if (expr) {
                _ = try appendToken(rp.c, .Semicolon, ";");
                const break_node = try transCreateNodeBreakToken(rp.c, block_scope.label);
                break_node.rhs = rhs;
                try block_scope.statements.append(&break_node.base);
                const block_node = try block_scope.complete(rp.c);
                const rparen = try appendToken(rp.c, .RParen, ")");
                const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
                grouped_expr.* = .{
                    .lparen = lparen,
                    .expr = &block_node.base,
                    .rparen = rparen,
                };
                return maybeSuppressResult(rp, scope, result_used, &grouped_expr.base);
            } else {
                return maybeSuppressResult(rp, scope, result_used, rhs);
            }
        },
        .Div => {
            if (cIsSignedInteger(qt)) {
                // signed integer division uses @divTrunc
                const div_trunc_node = try rp.c.createBuiltinCall("@divTrunc", 2);
                div_trunc_node.params()[0] = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                div_trunc_node.params()[1] = rhs;
                div_trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &div_trunc_node.base);
            }
        },
        .Rem => {
            if (cIsSignedInteger(qt)) {
                // signed integer division uses @rem
                const rem_node = try rp.c.createBuiltinCall("@rem", 2);
                rem_node.params()[0] = try transExpr(rp, scope, ZigClangBinaryOperator_getLHS(stmt), .used, .l_value);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, ZigClangBinaryOperator_getRHS(stmt), .used, .r_value);
                rem_node.params()[1] = rhs;
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

    const lhs = if (isBoolRes(lhs_node)) init: {
        const cast_node = try rp.c.createBuiltinCall("@boolToInt", 1);
        cast_node.params()[0] = lhs_node;
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        break :init &cast_node.base;
    } else lhs_node;

    const rhs = if (isBoolRes(rhs_node)) init: {
        const cast_node = try rp.c.createBuiltinCall("@boolToInt", 1);
        cast_node.params()[0] = rhs_node;
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        break :init &cast_node.base;
    } else rhs_node;

    return transCreateNodeInfixOp(rp, scope, lhs, op_id, op_token, rhs, result_used, true);
}

fn transCompoundStmtInline(
    rp: RestorePoint,
    parent_scope: *Scope,
    stmt: *const ZigClangCompoundStmt,
    block: *Scope.Block,
) TransError!void {
    var it = ZigClangCompoundStmt_body_begin(stmt);
    const end_it = ZigClangCompoundStmt_body_end(stmt);
    while (it != end_it) : (it += 1) {
        const result = try transStmt(rp, parent_scope, it[0], .unused, .r_value);
        try block.statements.append(result);
    }
}

fn transCompoundStmt(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangCompoundStmt) TransError!*ast.Node {
    var block_scope = try Scope.Block.init(rp.c, scope, null);
    defer block_scope.deinit();
    try transCompoundStmtInline(rp, &block_scope.base, stmt, &block_scope);
    const node = try block_scope.complete(rp.c);
    return &node.base;
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

fn transDeclStmtOne(
    rp: RestorePoint,
    scope: *Scope,
    decl: *const ZigClangDecl,
    block_scope: *Scope.Block,
) TransError!*ast.Node {
    const c = rp.c;

    switch (ZigClangDecl_getKind(decl)) {
        .Var => {
            const var_decl = @ptrCast(*const ZigClangVarDecl, decl);

            const thread_local_token = if (ZigClangVarDecl_getTLSKind(var_decl) == .None)
                null
            else
                try appendToken(c, .Keyword_threadlocal, "threadlocal");
            const qual_type = ZigClangVarDecl_getTypeSourceInfo_getType(var_decl);
            const name = try c.str(ZigClangNamedDecl_getName_bytes_begin(
                @ptrCast(*const ZigClangNamedDecl, var_decl),
            ));
            const mangled_name = try block_scope.makeMangledName(c, name);
            const mut_tok = if (ZigClangQualType_isConstQualified(qual_type))
                try appendToken(c, .Keyword_const, "const")
            else
                try appendToken(c, .Keyword_var, "var");
            const name_tok = try appendIdentifier(c, mangled_name);

            _ = try appendToken(c, .Colon, ":");
            const loc = ZigClangDecl_getLocation(decl);
            const type_node = try transQualType(rp, qual_type, loc);

            const eq_token = try appendToken(c, .Equal, "=");
            var init_node = if (ZigClangVarDecl_getInit(var_decl)) |expr|
                try transExprCoercing(rp, scope, expr, .used, .r_value)
            else
                try transCreateNodeUndefinedLiteral(c);
            if (!qualTypeIsBoolean(qual_type) and isBoolRes(init_node)) {
                const builtin_node = try rp.c.createBuiltinCall("@boolToInt", 1);
                builtin_node.params()[0] = init_node;
                builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                init_node = &builtin_node.base;
            }
            const semicolon_token = try appendToken(c, .Semicolon, ";");
            const node = try ast.Node.VarDecl.create(c.arena, .{
                .name_token = name_tok,
                .mut_token = mut_tok,
                .semicolon_token = semicolon_token,
            }, .{
                .thread_local_token = thread_local_token,
                .eq_token = eq_token,
                .type_node = type_node,
                .init_node = init_node,
            });
            return &node.base;
        },
        .Typedef => {
            const typedef_decl = @ptrCast(*const ZigClangTypedefNameDecl, decl);
            const name = try c.str(ZigClangNamedDecl_getName_bytes_begin(
                @ptrCast(*const ZigClangNamedDecl, typedef_decl),
            ));

            const underlying_qual = ZigClangTypedefNameDecl_getUnderlyingType(typedef_decl);
            const underlying_type = ZigClangQualType_getTypePtr(underlying_qual);

            const mangled_name = try block_scope.makeMangledName(c, name);
            const node = (try transCreateNodeTypedef(rp, typedef_decl, false, mangled_name)) orelse
                return error.UnsupportedTranslation;
            return node;
        },
        else => |kind| return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            ZigClangDecl_getLocation(decl),
            "TODO implement translation of DeclStmt kind {}",
            .{@tagName(kind)},
        ),
    }
}

fn transDeclStmt(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangDeclStmt) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;

    var it = ZigClangDeclStmt_decl_begin(stmt);
    const end_it = ZigClangDeclStmt_decl_end(stmt);
    assert(it != end_it);
    while (true) : (it += 1) {
        const node = try transDeclStmtOne(rp, scope, it[0], block_scope);

        if (it + 1 == end_it) {
            return node;
        } else {
            try block_scope.statements.append(node);
        }
    }
    unreachable;
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
            return try transCCast(rp, scope, ZigClangImplicitCastExpr_getBeginLoc(expr), dest_type, src_type, sub_expr_node);
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

            const prefix_op = try transCreateNodeSimplePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
            prefix_op.rhs = try transExpr(rp, scope, sub_expr, .used, .r_value);

            return maybeSuppressResult(rp, scope, result_used, &prefix_op.base);
        },
        .NullToPointer => {
            return try transCreateNodeNullLiteral(rp.c);
        },
        .PointerToBoolean => {
            // @ptrToInt(val) != 0
            const ptr_to_int = try rp.c.createBuiltinCall("@ptrToInt", 1);
            ptr_to_int.params()[0] = try transExpr(rp, scope, sub_expr, .used, .r_value);
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
        if (!grouped and res.tag == .GroupedExpression) {
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
        const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
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
    switch (res.tag) {
        .BoolOr,
        .BoolAnd,
        .EqualEqual,
        .BangEqual,
        .LessThan,
        .GreaterThan,
        .LessOrEqual,
        .GreaterOrEqual,
        .BoolNot,
        .BoolLiteral,
        => return true,

        .GroupedExpression => return isBoolRes(@fieldParentPtr(ast.Node.GroupedExpression, "base", res).expr),

        else => return false,
    }
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
    const as_node = try rp.c.createBuiltinCall("@as", 2);
    const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
    as_node.params()[0] = ty_node;
    _ = try appendToken(rp.c, .Comma, ",");
    as_node.params()[1] = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&eval_result.Val));

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

            const buf = try rp.c.arena.alloc(u8, len + "\"\"".len);
            buf[0] = '"';
            writeEscapedString(buf[1..], str);
            buf[buf.len - 1] = '"';

            const token = try appendToken(rp.c, .StringLiteral, buf);
            const node = try rp.c.arena.create(ast.Node.StringLiteral);
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
        '\"' => "\\\"",
        '\'' => "\\'",
        '\\' => "\\\\",
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
        // Handle the remaining escapes Zig doesn't support by turning them
        // into their respective hex representation
        else => if (std.ascii.isCntrl(c))
            std.fmt.bufPrint(char_buf, "\\x{x:0<2}", .{c}) catch unreachable
        else
            std.fmt.bufPrint(char_buf, "{c}", .{c}) catch unreachable,
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
        const cast_node = try rp.c.createBuiltinCall("@bitCast", 2);
        cast_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");

        switch (cIntTypeCmp(dst_type, src_type)) {
            .lt => {
                // @truncate(SameSignSmallerInt, src_type)
                const trunc_node = try rp.c.createBuiltinCall("@truncate", 2);
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, cIsSignedInteger(src_type));
                trunc_node.params()[0] = ty_node;
                _ = try appendToken(rp.c, .Comma, ",");
                trunc_node.params()[1] = expr;
                trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                cast_node.params()[1] = &trunc_node.base;
            },
            .gt => {
                // @as(SameSignBiggerInt, src_type)
                const as_node = try rp.c.createBuiltinCall("@as", 2);
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, cIsSignedInteger(src_type));
                as_node.params()[0] = ty_node;
                _ = try appendToken(rp.c, .Comma, ",");
                as_node.params()[1] = expr;
                as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                cast_node.params()[1] = &as_node.base;
            },
            .eq => {
                cast_node.params()[1] = expr;
            },
        }
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    }
    if (cIsInteger(dst_type) and qualTypeIsPtr(src_type)) {
        // @intCast(dest_type, @ptrToInt(val))
        const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
        cast_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        const builtin_node = try rp.c.createBuiltinCall("@ptrToInt", 1);
        builtin_node.params()[0] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        cast_node.params()[1] = &builtin_node.base;
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &cast_node.base;
    }
    if (cIsInteger(src_type) and qualTypeIsPtr(dst_type)) {
        // @intToPtr(dest_type, val)
        const builtin_node = try rp.c.createBuiltinCall("@intToPtr", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (cIsFloating(src_type) and cIsFloating(dst_type)) {
        const builtin_node = try rp.c.createBuiltinCall("@floatCast", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (cIsFloating(src_type) and !cIsFloating(dst_type)) {
        const builtin_node = try rp.c.createBuiltinCall("@floatToInt", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (!cIsFloating(src_type) and cIsFloating(dst_type)) {
        const builtin_node = try rp.c.createBuiltinCall("@intToFloat", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (ZigClangType_isBooleanType(qualTypeCanon(src_type)) and
        !ZigClangType_isBooleanType(qualTypeCanon(dst_type)))
    {
        // @boolToInt returns either a comptime_int or a u1
        const builtin_node = try rp.c.createBuiltinCall("@boolToInt", 1);
        builtin_node.params()[0] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        const inner_cast_node = try rp.c.createBuiltinCall("@intCast", 2);
        inner_cast_node.params()[0] = try transCreateNodeIdentifier(rp.c, "u1");
        _ = try appendToken(rp.c, .Comma, ",");
        inner_cast_node.params()[1] = &builtin_node.base;
        inner_cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
        cast_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");

        if (cIsSignedInteger(dst_type)) {
            const bitcast_node = try rp.c.createBuiltinCall("@bitCast", 2);
            bitcast_node.params()[0] = try transCreateNodeIdentifier(rp.c, "i1");
            _ = try appendToken(rp.c, .Comma, ",");
            bitcast_node.params()[1] = &inner_cast_node.base;
            bitcast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            cast_node.params()[1] = &bitcast_node.base;
        } else {
            cast_node.params()[1] = &inner_cast_node.base;
        }
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        return &cast_node.base;
    }
    if (ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(dst_type)) == .Enum) {
        const builtin_node = try rp.c.createBuiltinCall("@intToEnum", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(src_type)) == .Enum and
        ZigClangQualType_getTypeClass(ZigClangQualType_getCanonicalType(dst_type)) != .Enum)
    {
        const builtin_node = try rp.c.createBuiltinCall("@enumToInt", 1);
        builtin_node.params()[0] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    const cast_node = try rp.c.createBuiltinCall("@as", 2);
    cast_node.params()[0] = try transQualType(rp, dst_type, loc);
    _ = try appendToken(rp.c, .Comma, ",");
    cast_node.params()[1] = expr;
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
    var field_inits = std.ArrayList(*ast.Node).init(rp.c.gpa);
    defer field_inits.deinit();

    _ = try appendToken(rp.c, .LBrace, "{");

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
            raw_name = try mem.dupe(rp.c.arena, u8, name);
        }
        const field_name_tok = try appendIdentifier(rp.c, raw_name);

        _ = try appendToken(rp.c, .Equal, "=");

        const field_init_node = try rp.c.arena.create(ast.Node.FieldInitializer);
        field_init_node.* = .{
            .period_token = period_tok,
            .name_token = field_name_tok,
            .expr = try transExpr(rp, scope, elem_expr, .used, .r_value),
        };

        try field_inits.append(&field_init_node.base);
        _ = try appendToken(rp.c, .Comma, ",");
    }

    const node = try ast.Node.StructInitializer.alloc(rp.c.arena, field_inits.items.len);
    node.* = .{
        .lhs = ty_node,
        .rtoken = try appendToken(rp.c, .RBrace, "}"),
        .list_len = field_inits.items.len,
    };
    mem.copy(*ast.Node, node.list(), field_inits.items);
    return &node.base;
}

fn transCreateNodeArrayType(
    rp: RestorePoint,
    source_loc: ZigClangSourceLocation,
    ty: *const ZigClangType,
    len: anytype,
) !*ast.Node {
    const node = try rp.c.arena.create(ast.Node.ArrayType);
    const op_token = try appendToken(rp.c, .LBracket, "[");
    const len_expr = try transCreateNodeInt(rp.c, len);
    _ = try appendToken(rp.c, .RBracket, "]");
    node.* = .{
        .op_token = op_token,
        .rhs = try transType(rp, ty, source_loc),
        .len_expr = len_expr,
    };
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

    var init_node: *ast.Node.ArrayInitializer = undefined;
    var cat_tok: ast.TokenIndex = undefined;
    if (init_count != 0) {
        const ty_node = try transCreateNodeArrayType(
            rp,
            loc,
            ZigClangQualType_getTypePtr(child_qt),
            init_count,
        );
        _ = try appendToken(rp.c, .LBrace, "{");
        init_node = try ast.Node.ArrayInitializer.alloc(rp.c.arena, init_count);
        init_node.* = .{
            .lhs = ty_node,
            .rtoken = undefined,
            .list_len = init_count,
        };
        const init_list = init_node.list();

        var i: c_uint = 0;
        while (i < init_count) : (i += 1) {
            const elem_expr = ZigClangInitListExpr_getInit(expr, i);
            init_list[i] = try transExpr(rp, scope, elem_expr, .used, .r_value);
            _ = try appendToken(rp.c, .Comma, ",");
        }
        init_node.rtoken = try appendToken(rp.c, .RBrace, "}");
        if (leftover_count == 0) {
            return &init_node.base;
        }
        cat_tok = try appendToken(rp.c, .PlusPlus, "++");
    }

    const ty_node = try transCreateNodeArrayType(rp, loc, ZigClangQualType_getTypePtr(child_qt), 1);
    _ = try appendToken(rp.c, .LBrace, "{");
    const filler_init_node = try ast.Node.ArrayInitializer.alloc(rp.c.arena, 1);
    filler_init_node.* = .{
        .lhs = ty_node,
        .rtoken = undefined,
        .list_len = 1,
    };
    const filler_val_expr = ZigClangInitListExpr_getArrayFiller(expr);
    filler_init_node.list()[0] = try transExpr(rp, scope, filler_val_expr, .used, .r_value);
    filler_init_node.rtoken = try appendToken(rp.c, .RBrace, "}");

    const rhs_node = if (leftover_count == 1)
        &filler_init_node.base
    else blk: {
        const mul_tok = try appendToken(rp.c, .AsteriskAsterisk, "**");
        const mul_node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
        mul_node.* = .{
            .base = .{ .tag = .ArrayMult },
            .op_token = mul_tok,
            .lhs = &filler_init_node.base,
            .rhs = try transCreateNodeInt(rp.c, leftover_count),
        };
        break :blk &mul_node.base;
    };

    if (init_count == 0) {
        return rhs_node;
    }

    const cat_node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
    cat_node.* = .{
        .base = .{ .tag = .ArrayCat },
        .op_token = cat_tok,
        .lhs = &init_node.base,
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

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const cond_expr = @ptrCast(*const ZigClangExpr, ZigClangIfStmt_getCond(stmt));
    if_node.condition = try transBoolExpr(rp, &cond_scope.base, cond_expr, .used, .r_value, false);
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

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const cond_expr = @ptrCast(*const ZigClangExpr, ZigClangWhileStmt_getCond(stmt));
    while_node.condition = try transBoolExpr(rp, &cond_scope.base, cond_expr, .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };
    while_node.body = try transStmt(rp, &loop_scope, ZigClangWhileStmt_getBody(stmt), .unused, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");
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
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const prefix_op = try transCreateNodeSimplePrefixOp(rp.c, .BoolNot, .Bang, "!");
    prefix_op.rhs = try transBoolExpr(rp, &cond_scope.base, @ptrCast(*const ZigClangExpr, ZigClangDoStmt_getCond(stmt)), .used, .r_value, true);
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
        const node = try transStmt(rp, &loop_scope, ZigClangDoStmt_getBody(stmt), .unused, .r_value);
        break :blk node.cast(ast.Node.Block).?;
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
        const block = try rp.c.createBlock(null, 2);
        block.statements_len = 1; // over-allocated so we can add another below
        block.statements()[0] = try transStmt(rp, &loop_scope, ZigClangDoStmt_getBody(stmt), .unused, .r_value);
        break :blk block;
    };

    // In both cases above, we reserved 1 extra statement.
    body_node.statements_len += 1;
    body_node.statements()[body_node.statements_len - 1] = &if_node.base;
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

    var block_scope: ?Scope.Block = null;
    defer if (block_scope) |*bs| bs.deinit();

    if (ZigClangForStmt_getInit(stmt)) |init| {
        block_scope = try Scope.Block.init(rp.c, scope, null);
        loop_scope.parent = &block_scope.?.base;
        const init_node = try transStmt(rp, &block_scope.?.base, init, .unused, .r_value);
        try block_scope.?.statements.append(init_node);
    }
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = &loop_scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();

    const while_node = try transCreateNodeWhile(rp.c);
    while_node.condition = if (ZigClangForStmt_getCond(stmt)) |cond|
        try transBoolExpr(rp, &cond_scope.base, cond, .used, .r_value, false)
    else
        try transCreateNodeBoolLiteral(rp.c, true);
    _ = try appendToken(rp.c, .RParen, ")");

    if (ZigClangForStmt_getInc(stmt)) |incr| {
        _ = try appendToken(rp.c, .Colon, ":");
        _ = try appendToken(rp.c, .LParen, "(");
        while_node.continue_expr = try transExpr(rp, &cond_scope.base, incr, .unused, .r_value);
        _ = try appendToken(rp.c, .RParen, ")");
    }

    while_node.body = try transStmt(rp, &loop_scope, ZigClangForStmt_getBody(stmt), .unused, .r_value);
    if (block_scope) |*bs| {
        try bs.statements.append(&while_node.base);
        const node = try bs.complete(rp.c);
        return &node.base;
    } else {
        _ = try appendToken(rp.c, .Semicolon, ";");
        return &while_node.base;
    }
}

fn getSwitchCaseCount(stmt: *const ZigClangSwitchStmt) usize {
    const body = ZigClangSwitchStmt_getBody(stmt);
    assert(ZigClangStmt_getStmtClass(body) == .CompoundStmtClass);
    const comp = @ptrCast(*const ZigClangCompoundStmt, body);
    // TODO https://github.com/ziglang/zig/issues/1738
    // return ZigClangCompoundStmt_body_end(comp) - ZigClangCompoundStmt_body_begin(comp);
    const start_addr = @ptrToInt(ZigClangCompoundStmt_body_begin(comp));
    const end_addr = @ptrToInt(ZigClangCompoundStmt_body_end(comp));
    return (end_addr - start_addr) / @sizeOf(*ZigClangStmt);
}

fn transSwitch(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangSwitchStmt,
) TransError!*ast.Node {
    const switch_tok = try appendToken(rp.c, .Keyword_switch, "switch");
    _ = try appendToken(rp.c, .LParen, "(");

    const cases_len = getSwitchCaseCount(stmt);

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const switch_expr = try transExpr(rp, &cond_scope.base, ZigClangSwitchStmt_getCond(stmt), .used, .r_value);
    _ = try appendToken(rp.c, .RParen, ")");
    _ = try appendToken(rp.c, .LBrace, "{");
    // reserve +1 case in case there is no default case
    const switch_node = try ast.Node.Switch.alloc(rp.c.arena, cases_len + 1);
    switch_node.* = .{
        .switch_token = switch_tok,
        .expr = switch_expr,
        .cases_len = cases_len + 1,
        .rbrace = try appendToken(rp.c, .RBrace, "}"),
    };

    var switch_scope = Scope.Switch{
        .base = .{
            .id = .Switch,
            .parent = scope,
        },
        .cases = switch_node.cases(),
        .case_index = 0,
        .pending_block = undefined,
    };

    // tmp block that all statements will go before being picked up by a case or default
    var block_scope = try Scope.Block.init(rp.c, &switch_scope.base, null);
    defer block_scope.deinit();

    // Note that we do not defer a deinit here; the switch_scope.pending_block field
    // has its own memory management. This resource is freed inside `transCase` and
    // then the final pending_block is freed at the bottom of this function with
    // pending_block.deinit().
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, null);
    try switch_scope.pending_block.statements.append(&switch_node.base);

    const last = try transStmt(rp, &block_scope.base, ZigClangSwitchStmt_getBody(stmt), .unused, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    // take all pending statements
    const last_block_stmts = last.cast(ast.Node.Block).?.statements();
    try switch_scope.pending_block.statements.ensureCapacity(
        switch_scope.pending_block.statements.items.len + last_block_stmts.len,
    );
    for (last_block_stmts) |n| {
        switch_scope.pending_block.statements.appendAssumeCapacity(n);
    }

    switch_scope.pending_block.label = try appendIdentifier(rp.c, "__switch");
    _ = try appendToken(rp.c, .Colon, ":");
    if (!switch_scope.has_default) {
        const else_prong = try transCreateNodeSwitchCase(rp.c, try transCreateNodeSwitchElse(rp.c));
        else_prong.expr = &(try transCreateNodeBreak(rp.c, "__switch")).base;
        _ = try appendToken(rp.c, .Comma, ",");

        if (switch_scope.case_index >= switch_scope.cases.len)
            return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)), "TODO complex switch cases", .{});
        switch_scope.cases[switch_scope.case_index] = &else_prong.base;
        switch_scope.case_index += 1;
    }
    // We overallocated in case there was no default, so now we correct
    // the number of cases in the AST node.
    switch_node.cases_len = switch_scope.case_index;

    const result_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    return &result_node.base;
}

fn transCase(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangCaseStmt,
) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;
    const switch_scope = scope.getSwitch();
    const label = try std.fmt.allocPrint(rp.c.arena, "__case_{}", .{switch_scope.case_index - @boolToInt(switch_scope.has_default)});
    _ = try appendToken(rp.c, .Semicolon, ";");

    const expr = if (ZigClangCaseStmt_getRHS(stmt)) |rhs| blk: {
        const lhs_node = try transExpr(rp, scope, ZigClangCaseStmt_getLHS(stmt), .used, .r_value);
        const ellips = try appendToken(rp.c, .Ellipsis3, "...");
        const rhs_node = try transExpr(rp, scope, rhs, .used, .r_value);

        const node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
        node.* = .{
            .base = .{ .tag = .Range },
            .op_token = ellips,
            .lhs = lhs_node,
            .rhs = rhs_node,
        };
        break :blk &node.base;
    } else
        try transExpr(rp, scope, ZigClangCaseStmt_getLHS(stmt), .used, .r_value);

    const switch_prong = try transCreateNodeSwitchCase(rp.c, expr);
    switch_prong.expr = &(try transCreateNodeBreak(rp.c, label)).base;
    _ = try appendToken(rp.c, .Comma, ",");

    if (switch_scope.case_index >= switch_scope.cases.len)
        return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)), "TODO complex switch cases", .{});
    switch_scope.cases[switch_scope.case_index] = &switch_prong.base;
    switch_scope.case_index += 1;

    switch_scope.pending_block.label = try appendIdentifier(rp.c, label);
    _ = try appendToken(rp.c, .Colon, ":");

    // take all pending statements
    try switch_scope.pending_block.statements.appendSlice(block_scope.statements.items);
    block_scope.statements.shrink(0);

    const pending_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, null);

    try switch_scope.pending_block.statements.append(&pending_node.base);

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

    if (switch_scope.case_index >= switch_scope.cases.len)
        return revertAndWarn(rp, error.UnsupportedTranslation, ZigClangStmt_getBeginLoc(@ptrCast(*const ZigClangStmt, stmt)), "TODO complex switch cases", .{});
    switch_scope.cases[switch_scope.case_index] = &else_prong.base;
    switch_scope.case_index += 1;

    switch_scope.pending_block.label = try appendIdentifier(rp.c, label);
    _ = try appendToken(rp.c, .Colon, ":");

    // take all pending statements
    try switch_scope.pending_block.statements.appendSlice(block_scope.statements.items);
    block_scope.statements.shrink(0);

    const pending_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, null);
    try switch_scope.pending_block.statements.append(&pending_node.base);

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
            const as_node = try rp.c.createBuiltinCall("@as", 2);
            const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
            as_node.params()[0] = ty_node;
            _ = try appendToken(rp.c, .Comma, ",");

            const int_lit_node = try transCreateNodeAPInt(rp.c, ZigClangAPValue_getInt(&result.Val));
            as_node.params()[1] = int_lit_node;

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
            const node = try rp.c.arena.create(ast.Node.CharLiteral);
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
    const as_node = try rp.c.createBuiltinCall("@as", 2);
    const ty_node = try transQualType(rp, ZigClangExpr_getType(expr_base), ZigClangExpr_getBeginLoc(expr_base));
    as_node.params()[0] = ty_node;
    _ = try appendToken(rp.c, .Comma, ",");
    as_node.params()[1] = int_lit_node;

    as_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &as_node.base);
}

fn transStmtExpr(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangStmtExpr, used: ResultUsed) TransError!*ast.Node {
    const comp = ZigClangStmtExpr_getSubStmt(stmt);
    if (used == .unused) {
        return transCompoundStmt(rp, scope, comp);
    }
    const lparen = try appendToken(rp.c, .LParen, "(");
    var block_scope = try Scope.Block.init(rp.c, scope, "blk");
    defer block_scope.deinit();

    var it = ZigClangCompoundStmt_body_begin(comp);
    const end_it = ZigClangCompoundStmt_body_end(comp);
    while (it != end_it - 1) : (it += 1) {
        const result = try transStmt(rp, &block_scope.base, it[0], .unused, .r_value);
        try block_scope.statements.append(result);
    }
    const break_node = try transCreateNodeBreak(rp.c, "blk");
    break_node.rhs = try transStmt(rp, &block_scope.base, it[0], .used, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = &block_node.base,
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
                break :blk try mem.dupe(rp.c.arena, u8, name);
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
        const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
        // check if long long first so that signed long long doesn't just become unsigned long long
        var typeid_node = if (is_longlong) try transCreateNodeIdentifier(rp.c, "usize") else try transQualTypeIntWidthOf(rp.c, qt, false);
        cast_node.params()[0] = typeid_node;
        _ = try appendToken(rp.c, .Comma, ",");
        cast_node.params()[1] = try transExpr(rp, scope, subscr_expr, .used, .r_value);
        cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        node.rtoken = try appendToken(rp.c, .RBrace, "]");
        node.index_expr = &cast_node.base;
    } else {
        node.index_expr = try transExpr(rp, scope, subscr_expr, .used, .r_value);
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

    const num_args = ZigClangCallExpr_getNumArgs(stmt);
    const node = try rp.c.createCall(fn_expr, num_args);
    const call_params = node.params();

    const args = ZigClangCallExpr_getArgs(stmt);
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        if (i != 0) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
        call_params[i] = try transExpr(rp, scope, args[i], .used, .r_value);
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

    const builtin_node = try rp.c.createBuiltinCall("@sizeOf", 1);
    builtin_node.params()[0] = type_node;
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
            const op_node = try transCreateNodeSimplePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
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
                const op_node = try transCreateNodeSimplePrefixOp(rp.c, .Negation, .Minus, "-");
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
            const op_node = try transCreateNodeSimplePrefixOp(rp.c, .BitNot, .Tilde, "~");
            op_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
            return &op_node.base;
        },
        .LNot => {
            const op_node = try transCreateNodeSimplePrefixOp(rp.c, .BoolNot, .Bang, "!");
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
    op: ast.Node.Tag,
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
    var block_scope = try Scope.Block.init(rp.c, scope, "blk");
    defer block_scope.deinit();
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, ref);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const rhs_node = try transCreateNodeSimplePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    rhs_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
    const init_node = &rhs_node.base;
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = eq_token,
        .init_node = init_node,
    });
    try block_scope.statements.append(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const token = try appendToken(rp.c, op_tok_id, bytes);
    const one = try transCreateNodeInt(rp.c, 1);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const assign = try transCreateNodeInfixOp(rp, scope, ref_node, op, token, one, .used, false);
    try block_scope.statements.append(assign);

    const break_node = try transCreateNodeBreakToken(rp.c, block_scope.label);
    break_node.rhs = ref_node;
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCreatePostCrement(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangUnaryOperator,
    op: ast.Node.Tag,
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
    var block_scope = try Scope.Block.init(rp.c, scope, "blk");
    defer block_scope.deinit();
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, ref);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const rhs_node = try transCreateNodeSimplePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    rhs_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
    const init_node = &rhs_node.base;
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = eq_token,
        .init_node = init_node,
    });
    try block_scope.statements.append(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");

    const tmp = try block_scope.makeMangledName(rp.c, "tmp");
    const tmp_mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const tmp_name_tok = try appendIdentifier(rp.c, tmp);
    const tmp_eq_token = try appendToken(rp.c, .Equal, "=");
    const tmp_init_node = ref_node;
    const tmp_semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const tmp_node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = tmp_name_tok,
        .mut_token = tmp_mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = tmp_eq_token,
        .init_node = tmp_init_node,
    });
    try block_scope.statements.append(&tmp_node.base);

    const token = try appendToken(rp.c, op_tok_id, bytes);
    const one = try transCreateNodeInt(rp.c, 1);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const assign = try transCreateNodeInfixOp(rp, scope, ref_node, op, token, one, .used, false);
    try block_scope.statements.append(assign);

    const break_node = try transCreateNodeBreakToken(rp.c, block_scope.label);
    break_node.rhs = try transCreateNodeIdentifier(rp.c, tmp);
    try block_scope.statements.append(&break_node.base);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const block_node = try block_scope.complete(rp.c);
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_node.base,
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
        .DivAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignDiv, .SlashEqual, "/=", .Div, .Slash, "/", used),
        .RemAssign => return transCreateCompoundAssign(rp, scope, stmt, .AssignMod, .PercentEqual, "%=", .Mod, .Percent, "%", used),
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
    assign_op: ast.Node.Tag,
    assign_tok_id: std.zig.Token.Id,
    assign_bytes: []const u8,
    bin_op: ast.Node.Tag,
    bin_tok_id: std.zig.Token.Id,
    bin_bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const is_shift = bin_op == .BitShiftLeft or bin_op == .BitShiftRight;
    const is_div = bin_op == .Div;
    const is_mod = bin_op == .Mod;
    const lhs = ZigClangCompoundAssignOperator_getLHS(stmt);
    const rhs = ZigClangCompoundAssignOperator_getRHS(stmt);
    const loc = ZigClangCompoundAssignOperator_getBeginLoc(stmt);
    const lhs_qt = getExprQualType(rp.c, lhs);
    const rhs_qt = getExprQualType(rp.c, rhs);
    const is_signed = cIsSignedInteger(lhs_qt);
    const requires_int_cast = blk: {
        const are_integers = cIsInteger(lhs_qt) and cIsInteger(rhs_qt);
        const are_same_sign = cIsSignedInteger(lhs_qt) == cIsSignedInteger(rhs_qt);
        break :blk are_integers and !are_same_sign;
    };
    if (used == .unused) {
        // common case
        // c: lhs += rhs
        // zig: lhs += rhs
        if ((is_mod or is_div) and is_signed) {
            const op_token = try appendToken(rp.c, .Equal, "=");
            const op_node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
            const builtin = if (is_mod) "@rem" else "@divTrunc";
            const builtin_node = try rp.c.createBuiltinCall(builtin, 2);
            const lhs_node = try transExpr(rp, scope, lhs, .used, .l_value);
            builtin_node.params()[0] = lhs_node;
            _ = try appendToken(rp.c, .Comma, ",");
            builtin_node.params()[1] = try transExpr(rp, scope, rhs, .used, .r_value);
            builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            op_node.* = .{
                .base = .{ .tag = .Assign },
                .op_token = op_token,
                .lhs = lhs_node,
                .rhs = &builtin_node.base,
            };
            _ = try appendToken(rp.c, .Semicolon, ";");
            return &op_node.base;
        }

        const lhs_node = try transExpr(rp, scope, lhs, .used, .l_value);
        const eq_token = try appendToken(rp.c, assign_tok_id, assign_bytes);
        var rhs_node = if (is_shift or requires_int_cast)
            try transExprCoercing(rp, scope, rhs, .used, .r_value)
        else
            try transExpr(rp, scope, rhs, .used, .r_value);

        if (is_shift or requires_int_cast) {
            const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
            const cast_to_type = if (is_shift)
                try qualTypeToLog2IntRef(rp, getExprQualType(rp.c, rhs), loc)
            else
                try transQualType(rp, getExprQualType(rp.c, lhs), loc);
            cast_node.params()[0] = cast_to_type;
            _ = try appendToken(rp.c, .Comma, ",");
            cast_node.params()[1] = rhs_node;
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
    var block_scope = try Scope.Block.init(rp.c, scope, "blk");
    defer block_scope.deinit();
    const ref = try block_scope.makeMangledName(rp.c, "ref");

    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, ref);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const addr_node = try transCreateNodeSimplePrefixOp(rp.c, .AddressOf, .Ampersand, "&");
    addr_node.rhs = try transExpr(rp, scope, lhs, .used, .l_value);
    const init_node = &addr_node.base;
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = eq_token,
        .init_node = init_node,
    });
    try block_scope.statements.append(&node.base);

    const lhs_node = try transCreateNodeIdentifier(rp.c, ref);
    const ref_node = try transCreateNodePtrDeref(rp.c, lhs_node);
    _ = try appendToken(rp.c, .Semicolon, ";");

    if ((is_mod or is_div) and is_signed) {
        const op_token = try appendToken(rp.c, .Equal, "=");
        const op_node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
        const builtin = if (is_mod) "@rem" else "@divTrunc";
        const builtin_node = try rp.c.createBuiltinCall(builtin, 2);
        builtin_node.params()[0] = try transCreateNodePtrDeref(rp.c, lhs_node);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = try transExpr(rp, scope, rhs, .used, .r_value);
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        _ = try appendToken(rp.c, .Semicolon, ";");
        op_node.* = .{
            .base = .{ .tag = .Assign },
            .op_token = op_token,
            .lhs = ref_node,
            .rhs = &builtin_node.base,
        };
        _ = try appendToken(rp.c, .Semicolon, ";");
        try block_scope.statements.append(&op_node.base);
    } else {
        const bin_token = try appendToken(rp.c, bin_tok_id, bin_bytes);
        var rhs_node = try transExpr(rp, scope, rhs, .used, .r_value);

        if (is_shift or requires_int_cast) {
            const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
            const cast_to_type = if (is_shift)
                try qualTypeToLog2IntRef(rp, getExprQualType(rp.c, rhs), loc)
            else
                try transQualType(rp, getExprQualType(rp.c, lhs), loc);
            cast_node.params()[0] = cast_to_type;
            _ = try appendToken(rp.c, .Comma, ",");
            cast_node.params()[1] = rhs_node;
            cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            rhs_node = &cast_node.base;
        }

        const rhs_bin = try transCreateNodeInfixOp(rp, scope, ref_node, bin_op, bin_token, rhs_node, .used, false);
        _ = try appendToken(rp.c, .Semicolon, ";");

        const ass_eq_token = try appendToken(rp.c, .Equal, "=");
        const assign = try transCreateNodeInfixOp(rp, scope, ref_node, .Assign, ass_eq_token, rhs_bin, .used, false);
        try block_scope.statements.append(assign);
    }

    const break_node = try transCreateNodeBreakToken(rp.c, block_scope.label);
    break_node.rhs = ref_node;
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = &block_node.base,
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
        const inttoptr_node = try rp.c.createBuiltinCall("@intToPtr", 2);
        const dst_type_node = try transType(rp, ty, loc);
        inttoptr_node.params()[0] = dst_type_node;
        _ = try appendToken(rp.c, .Comma, ",");

        const ptrtoint_node = try rp.c.createBuiltinCall("@ptrToInt", 1);
        ptrtoint_node.params()[0] = expr;
        ptrtoint_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        inttoptr_node.params()[1] = &ptrtoint_node.base;
        inttoptr_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &inttoptr_node.base;
    } else {
        // Implicit downcasting from higher to lower alignment values is forbidden,
        // use @alignCast to side-step this problem
        const ptrcast_node = try rp.c.createBuiltinCall("@ptrCast", 2);
        const dst_type_node = try transType(rp, ty, loc);
        ptrcast_node.params()[0] = dst_type_node;
        _ = try appendToken(rp.c, .Comma, ",");

        if (ZigClangType_isVoidType(qualTypeCanon(child_type))) {
            // void has 1-byte alignment, so @alignCast is not needed
            ptrcast_node.params()[1] = expr;
        } else if (typeIsOpaque(rp.c, qualTypeCanon(child_type), loc)) {
            // For opaque types a ptrCast is enough
            ptrcast_node.params()[1] = expr;
        } else {
            const aligncast_node = try rp.c.createBuiltinCall("@alignCast", 2);
            const alignof_node = try rp.c.createBuiltinCall("@alignOf", 1);
            const child_type_node = try transQualType(rp, child_type, loc);
            alignof_node.params()[0] = child_type_node;
            alignof_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            aligncast_node.params()[0] = &alignof_node.base;
            _ = try appendToken(rp.c, .Comma, ",");
            aligncast_node.params()[1] = expr;
            aligncast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
            ptrcast_node.params()[1] = &aligncast_node.base;
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
    const node = try rp.c.arena.create(ast.Node.FloatLiteral);
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

    var block_scope = try Scope.Block.init(rp.c, scope, "blk");
    defer block_scope.deinit();

    const mangled_name = try block_scope.makeMangledName(rp.c, "cond_temp");
    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, mangled_name);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const init_node = try transExpr(rp, &block_scope.base, cond_expr, .used, .r_value);
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const tmp_var = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = eq_token,
        .init_node = init_node,
    });
    try block_scope.statements.append(&tmp_var.base);

    const break_node = try transCreateNodeBreakToken(rp.c, block_scope.label);

    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = &block_scope.base,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const tmp_var_node = try transCreateNodeIdentifier(rp.c, mangled_name);

    const ty = ZigClangQualType_getTypePtr(getExprQualType(rp.c, cond_expr));
    const cond_node = try finishBoolExpr(rp, &cond_scope.base, ZigClangExpr_getBeginLoc(cond_expr), ty, tmp_var_node, used);
    if_node.condition = cond_node;
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transCreateNodeIdentifier(rp.c, mangled_name);
    if_node.@"else" = try transCreateNodeElse(rp.c);
    if_node.@"else".?.body = try transExpr(rp, &block_scope.base, false_expr, .used, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    break_node.rhs = &if_node.base;
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);

    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = &block_node.base,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transConditionalOperator(rp: RestorePoint, scope: *Scope, stmt: *const ZigClangConditionalOperator, used: ResultUsed) TransError!*ast.Node {
    const grouped = scope.id == .Condition;
    const lparen = if (grouped) try appendToken(rp.c, .LParen, "(") else undefined;
    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();

    const casted_stmt = @ptrCast(*const ZigClangAbstractConditionalOperator, stmt);
    const cond_expr = ZigClangAbstractConditionalOperator_getCond(casted_stmt);
    const true_expr = ZigClangAbstractConditionalOperator_getTrueExpr(casted_stmt);
    const false_expr = ZigClangAbstractConditionalOperator_getFalseExpr(casted_stmt);

    if_node.condition = try transBoolExpr(rp, &cond_scope.base, cond_expr, .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transExpr(rp, scope, true_expr, .used, .r_value);

    if_node.@"else" = try transCreateNodeElse(rp.c);
    if_node.@"else".?.body = try transExpr(rp, scope, false_expr, .used, .r_value);

    if (grouped) {
        const rparen = try appendToken(rp.c, .RParen, ")");
        const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
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
    const op_node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
    op_node.* = .{
        .base = .{ .tag = .Assign },
        .op_token = op_token,
        .lhs = lhs,
        .rhs = result,
    };
    return &op_node.base;
}

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: *ast.Node) !void {
    try c.root_decls.append(c.gpa, decl_node);
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
        const node = try rp.c.arena.create(ast.Node.IntegerLiteral);
        node.* = .{
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

    const import_fn_call = try rp.c.createBuiltinCall("@import", 1);
    const std_token = try appendToken(rp.c, .StringLiteral, "\"std\"");
    const std_node = try rp.c.arena.create(ast.Node.StringLiteral);
    std_node.* = .{
        .token = std_token,
    };
    import_fn_call.params()[0] = &std_node.base;
    import_fn_call.rparen_token = try appendToken(rp.c, .RParen, ")");

    const inner_field_access = try transCreateNodeFieldAccess(rp.c, &import_fn_call.base, "math");
    const outer_field_access = try transCreateNodeFieldAccess(rp.c, inner_field_access, "Log2Int");
    const log2int_fn_call = try rp.c.createCall(outer_field_access, 1);
    log2int_fn_call.params()[0] = zig_type_node;
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
            const builtin_node = try rp.c.createBuiltinCall("@boolToInt", 1);
            builtin_node.params()[0] = rhs_node;
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
    const label_name = "blk";
    var block_scope = try Scope.Block.init(rp.c, scope, label_name);
    defer block_scope.deinit();

    const tmp = try block_scope.makeMangledName(rp.c, "tmp");
    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, tmp);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    var rhs_node = try transExpr(rp, &block_scope.base, rhs, .used, .r_value);
    if (!exprIsBooleanType(lhs) and isBoolRes(rhs_node)) {
        const builtin_node = try rp.c.createBuiltinCall("@boolToInt", 1);
        builtin_node.params()[0] = rhs_node;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        rhs_node = &builtin_node.base;
    }
    const init_node = rhs_node;
    const semicolon_token = try appendToken(rp.c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(rp.c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .eq_token = eq_token,
        .init_node = init_node,
    });
    try block_scope.statements.append(&node.base);

    const lhs_node = try transExpr(rp, &block_scope.base, lhs, .used, .l_value);
    const lhs_eq_token = try appendToken(rp.c, .Equal, "=");
    const ident = try transCreateNodeIdentifier(rp.c, tmp);
    _ = try appendToken(rp.c, .Semicolon, ";");

    const assign = try transCreateNodeInfixOp(rp, &block_scope.base, lhs_node, .Assign, lhs_eq_token, ident, .used, false);
    try block_scope.statements.append(assign);

    const break_node = try transCreateNodeBreak(rp.c, label_name);
    break_node.rhs = try transCreateNodeIdentifier(rp.c, tmp);
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &block_node.base;
}

fn transCreateNodeFieldAccess(c: *Context, container: *ast.Node, field_name: []const u8) !*ast.Node {
    const field_access_node = try c.arena.create(ast.Node.SimpleInfixOp);
    field_access_node.* = .{
        .base = .{ .tag = .Period },
        .op_token = try appendToken(c, .Period, "."),
        .lhs = container,
        .rhs = try transCreateNodeIdentifier(c, field_name),
    };
    return &field_access_node.base;
}

fn transCreateNodeSimplePrefixOp(
    c: *Context,
    comptime tag: ast.Node.Tag,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
) !*ast.Node.SimplePrefixOp {
    const node = try c.arena.create(ast.Node.SimplePrefixOp);
    node.* = .{
        .base = .{ .tag = tag },
        .op_token = try appendToken(c, op_tok_id, bytes),
        .rhs = undefined, // translate and set afterward
    };
    return node;
}

fn transCreateNodeInfixOp(
    rp: RestorePoint,
    scope: *Scope,
    lhs_node: *ast.Node,
    op: ast.Node.Tag,
    op_token: ast.TokenIndex,
    rhs_node: *ast.Node,
    used: ResultUsed,
    grouped: bool,
) !*ast.Node {
    var lparen = if (grouped)
        try appendToken(rp.c, .LParen, "(")
    else
        null;
    const node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
    node.* = .{
        .base = .{ .tag = op },
        .op_token = op_token,
        .lhs = lhs_node,
        .rhs = rhs_node,
    };
    if (!grouped) return maybeSuppressResult(rp, scope, used, &node.base);
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
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
    op: ast.Node.Tag,
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
) !*ast.Node.PtrType {
    const node = try c.arena.create(ast.Node.PtrType);
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
        .ptr_info = .{
            .const_token = if (is_const) try appendToken(c, .Keyword_const, "const") else null,
            .volatile_token = if (is_volatile) try appendToken(c, .Keyword_volatile, "volatile") else null,
        },
        .rhs = undefined, // translate and set afterward
    };
    return node;
}

fn transCreateNodeAPInt(c: *Context, int: *const ZigClangAPSInt) !*ast.Node {
    const num_limbs = math.cast(usize, ZigClangAPSInt_getNumWords(int)) catch |err| switch (err) {
        error.Overflow => return error.OutOfMemory,
    };
    var aps_int = int;
    const is_negative = ZigClangAPSInt_isSigned(int) and ZigClangAPSInt_isNegative(int);
    if (is_negative) aps_int = ZigClangAPSInt_negate(aps_int);
    defer if (is_negative) {
        ZigClangAPSInt_free(aps_int);
    };

    const limbs = try c.arena.alloc(math.big.Limb, num_limbs);
    defer c.arena.free(limbs);

    const data = ZigClangAPSInt_getRawData(aps_int);
    switch (@sizeOf(math.big.Limb)) {
        8 => {
            var i: usize = 0;
            while (i < num_limbs) : (i += 1) {
                limbs[i] = data[i];
            }
        },
        4 => {
            var limb_i: usize = 0;
            var data_i: usize = 0;
            while (limb_i < num_limbs) : ({
                limb_i += 2;
                data_i += 1;
            }) {
                limbs[limb_i] = @truncate(u32, data[data_i]);
                limbs[limb_i + 1] = @truncate(u32, data[data_i] >> 32);
            }
        },
        else => @compileError("unimplemented"),
    }

    const big: math.big.int.Const = .{ .limbs = limbs, .positive = !is_negative };
    const str = big.toStringAlloc(c.arena, 10, false) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    defer c.arena.free(str);
    const token = try appendToken(c, .IntegerLiteral, str);
    const node = try c.arena.create(ast.Node.IntegerLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeReturnExpr(c: *Context) !*ast.Node.ControlFlowExpression {
    const ltoken = try appendToken(c, .Keyword_return, "return");
    const node = try c.arena.create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .Return,
        .rhs = null,
    };
    return node;
}

fn transCreateNodeUndefinedLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_undefined, "undefined");
    const node = try c.arena.create(ast.Node.UndefinedLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeNullLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_null, "null");
    const node = try c.arena.create(ast.Node.NullLiteral);
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
    const node = try c.arena.create(ast.Node.BoolLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeInt(c: *Context, int: anytype) !*ast.Node {
    const token = try appendTokenFmt(c, .IntegerLiteral, "{}", .{int});
    const node = try c.arena.create(ast.Node.IntegerLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeFloat(c: *Context, int: anytype) !*ast.Node {
    const token = try appendTokenFmt(c, .FloatLiteral, "{}", .{int});
    const node = try c.arena.create(ast.Node.FloatLiteral);
    node.* = .{
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeOpaqueType(c: *Context) !*ast.Node {
    const call_node = try c.createBuiltinCall("@Type", 1);
    call_node.params()[0] = try transCreateNodeEnumLiteral(c, "Opaque");
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

    var fn_params = std.ArrayList(ast.Node.FnProto.ParamDecl).init(c.gpa);
    defer fn_params.deinit();

    for (proto_alias.params()) |param, i| {
        if (i != 0) {
            _ = try appendToken(c, .Comma, ",");
        }
        const param_name_tok = param.name_token orelse
            try appendTokenFmt(c, .Identifier, "arg_{}", .{c.getMangle()});

        _ = try appendToken(c, .Colon, ":");

        (try fn_params.addOne()).* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = param.noalias_token,
            .name_token = param_name_tok,
            .param_type = param.param_type,
        };
    }

    _ = try appendToken(c, .RParen, ")");

    const block_lbrace = try appendToken(c, .LBrace, "{");

    const return_expr = try transCreateNodeReturnExpr(c);
    const unwrap_expr = try transCreateNodeUnwrapNull(c, ref.cast(ast.Node.VarDecl).?.getTrailer("init_node").?);

    const call_expr = try c.createCall(unwrap_expr, fn_params.items.len);
    const call_params = call_expr.params();

    for (fn_params.items) |param, i| {
        if (i != 0) {
            _ = try appendToken(c, .Comma, ",");
        }
        call_params[i] = try transCreateNodeIdentifier(c, tokenSlice(c, param.name_token.?));
    }
    call_expr.rtoken = try appendToken(c, .RParen, ")");

    return_expr.rhs = &call_expr.base;
    _ = try appendToken(c, .Semicolon, ";");

    const block = try ast.Node.Block.alloc(c.arena, 1);
    block.* = .{
        .label = null,
        .lbrace = block_lbrace,
        .statements_len = 1,
        .rbrace = try appendToken(c, .RBrace, "}"),
    };
    block.statements()[0] = &return_expr.base;

    const fn_proto = try ast.Node.FnProto.create(c.arena, .{
        .params_len = fn_params.items.len,
        .fn_token = fn_tok,
        .return_type = proto_alias.return_type,
    }, .{
        .visib_token = pub_tok,
        .name_token = name_tok,
        .extern_export_inline_token = inline_tok,
        .body_node = &block.base,
    });
    mem.copy(ast.Node.FnProto.ParamDecl, fn_proto.params(), fn_params.items);
    return &fn_proto.base;
}

fn transCreateNodeUnwrapNull(c: *Context, wrapped: *ast.Node) !*ast.Node {
    _ = try appendToken(c, .Period, ".");
    const qm = try appendToken(c, .QuestionMark, "?");
    const node = try c.arena.create(ast.Node.SimpleSuffixOp);
    node.* = .{
        .base = .{ .tag = .UnwrapOptional },
        .lhs = wrapped,
        .rtoken = qm,
    };
    return &node.base;
}

fn transCreateNodeEnumLiteral(c: *Context, name: []const u8) !*ast.Node {
    const node = try c.arena.create(ast.Node.EnumLiteral);
    node.* = .{
        .dot = try appendToken(c, .Period, "."),
        .name = try appendIdentifier(c, name),
    };
    return &node.base;
}

fn transCreateNodeStringLiteral(c: *Context, str: []const u8) !*ast.Node {
    const node = try c.arena.create(ast.Node.StringLiteral);
    node.* = .{
        .token = try appendToken(c, .StringLiteral, str),
    };
    return &node.base;
}

fn transCreateNodeIf(c: *Context) !*ast.Node.If {
    const if_tok = try appendToken(c, .Keyword_if, "if");
    _ = try appendToken(c, .LParen, "(");
    const node = try c.arena.create(ast.Node.If);
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
    const node = try c.arena.create(ast.Node.Else);
    node.* = .{
        .else_token = try appendToken(c, .Keyword_else, "else"),
        .payload = null,
        .body = undefined,
    };
    return node;
}

fn transCreateNodeBreakToken(c: *Context, label: ?ast.TokenIndex) !*ast.Node.ControlFlowExpression {
    const other_token = label orelse return transCreateNodeBreak(c, null);
    const loc = c.token_locs.items[other_token];
    const label_name = c.source_buffer.items[loc.start..loc.end];
    return transCreateNodeBreak(c, label_name);
}

fn transCreateNodeBreak(c: *Context, label: ?[]const u8) !*ast.Node.ControlFlowExpression {
    const ltoken = try appendToken(c, .Keyword_break, "break");
    const label_node = if (label) |l| blk: {
        _ = try appendToken(c, .Colon, ":");
        break :blk try transCreateNodeIdentifier(c, l);
    } else null;
    const node = try c.arena.create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .{ .Break = label_node },
        .rhs = null,
    };
    return node;
}

fn transCreateNodeWhile(c: *Context) !*ast.Node.While {
    const while_tok = try appendToken(c, .Keyword_while, "while");
    _ = try appendToken(c, .LParen, "(");

    const node = try c.arena.create(ast.Node.While);
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
    const node = try c.arena.create(ast.Node.ControlFlowExpression);
    node.* = .{
        .ltoken = ltoken,
        .kind = .{ .Continue = null },
        .rhs = null,
    };
    _ = try appendToken(c, .Semicolon, ";");
    return &node.base;
}

fn transCreateNodeSwitchCase(c: *Context, lhs: *ast.Node) !*ast.Node.SwitchCase {
    const arrow_tok = try appendToken(c, .EqualAngleBracketRight, "=>");

    const node = try ast.Node.SwitchCase.alloc(c.arena, 1);
    node.* = .{
        .items_len = 1,
        .arrow_token = arrow_tok,
        .payload = null,
        .expr = undefined,
    };
    node.items()[0] = lhs;
    return node;
}

fn transCreateNodeSwitchElse(c: *Context) !*ast.Node {
    const node = try c.arena.create(ast.Node.SwitchElse);
    node.* = .{
        .token = try appendToken(c, .Keyword_else, "else"),
    };
    return &node.base;
}

fn transCreateNodeShiftOp(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const ZigClangBinaryOperator,
    op: ast.Node.Tag,
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

    const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
    const rhs_type = try qualTypeToLog2IntRef(rp, ZigClangBinaryOperator_getType(stmt), rhs_location);
    cast_node.params()[0] = rhs_type;
    _ = try appendToken(rp.c, .Comma, ",");
    const rhs = try transExprCoercing(rp, scope, rhs_expr, .used, .r_value);
    cast_node.params()[1] = rhs;
    cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");

    const node = try rp.c.arena.create(ast.Node.SimpleInfixOp);
    node.* = .{
        .base = .{ .tag = op },
        .op_token = op_token,
        .lhs = lhs,
        .rhs = &cast_node.base,
    };

    return &node.base;
}

fn transCreateNodePtrDeref(c: *Context, lhs: *ast.Node) !*ast.Node {
    const node = try c.arena.create(ast.Node.SimpleSuffixOp);
    node.* = .{
        .base = .{ .tag = .Deref },
        .lhs = lhs,
        .rtoken = try appendToken(c, .PeriodAsterisk, ".*"),
    };
    return &node.base;
}

fn transCreateNodeArrayAccess(c: *Context, lhs: *ast.Node) !*ast.Node.ArrayAccess {
    _ = try appendToken(c, .LBrace, "[");
    const node = try c.arena.create(ast.Node.ArrayAccess);
    node.* = .{
        .lhs = lhs,
        .index_expr = undefined,
        .rtoken = undefined,
    };
    return node;
}

const RestorePoint = struct {
    c: *Context,
    token_index: ast.TokenIndex,
    src_buf_index: usize,

    fn activate(self: RestorePoint) void {
        self.c.token_ids.shrink(self.c.gpa, self.token_index);
        self.c.token_locs.shrink(self.c.gpa, self.token_index);
        self.c.source_buffer.shrink(self.src_buf_index);
    }
};

fn makeRestorePoint(c: *Context) RestorePoint {
    return RestorePoint{
        .c = c,
        .token_index = c.token_ids.items.len,
        .src_buf_index = c.source_buffer.items.len,
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
                const optional_node = try transCreateNodeSimplePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
                optional_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            if (typeIsOpaque(rp.c, ZigClangQualType_getTypePtr(child_qt), source_loc)) {
                const optional_node = try transCreateNodeSimplePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
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
            const elem_ty = ZigClangQualType_getTypePtr(ZigClangConstantArrayType_getElementType(const_arr_ty));
            return try transCreateNodeArrayType(rp, source_loc, elem_ty, size);
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

    var fn_params = std.ArrayList(ast.Node.FnProto.ParamDecl).init(rp.c.gpa);
    defer fn_params.deinit();
    const param_count: usize = if (fn_proto_ty != null) ZigClangFunctionProtoType_getNumParams(fn_proto_ty.?) else 0;
    try fn_params.ensureCapacity(param_count + 1); // +1 for possible var args node

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

        fn_params.addOneAssumeCapacity().* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = noalias_tok,
            .name_token = param_name_tok,
            .param_type = .{ .type_expr = type_node },
        };

        if (i + 1 < param_count) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
    }

    const var_args_token: ?ast.TokenIndex = if (is_var_args) blk: {
        if (param_count > 0) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
        break :blk try appendToken(rp.c, .Ellipsis3, "...");
    } else null;

    const rparen_tok = try appendToken(rp.c, .RParen, ")");

    const linksection_expr = blk: {
        if (fn_decl) |decl| {
            var str_len: usize = undefined;
            if (ZigClangFunctionDecl_getSectionAttribute(decl, &str_len)) |str_ptr| {
                _ = try appendToken(rp.c, .Keyword_linksection, "linksection");
                _ = try appendToken(rp.c, .LParen, "(");
                const expr = try transCreateNodeStringLiteral(
                    rp.c,
                    try std.fmt.allocPrint(rp.c.arena, "\"{}\"", .{str_ptr[0..str_len]}),
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
                _ = try appendToken(rp.c, .Keyword_align, "align");
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

    // We need to reserve an undefined (but non-null) body node to set later.
    var body_node: ?*ast.Node = null;
    if (fn_decl_context) |ctx| {
        if (ctx.has_body) {
            // TODO: we should be able to use undefined here but
            // it causes a bug. This is undefined without zig language
            // being aware of it.
            body_node = @intToPtr(*ast.Node, 0x08);
        }
    }

    const fn_proto = try ast.Node.FnProto.create(rp.c.arena, .{
        .params_len = fn_params.items.len,
        .return_type = .{ .Explicit = return_type_node },
        .fn_token = fn_tok,
    }, .{
        .visib_token = pub_tok,
        .name_token = name_tok,
        .extern_export_inline_token = extern_export_inline_tok,
        .align_expr = align_expr,
        .section_expr = linksection_expr,
        .callconv_expr = callconv_expr,
        .body_node = body_node,
        .var_args_token = var_args_token,
    });
    mem.copy(ast.Node.FnProto.ParamDecl, fn_proto.params(), fn_params.items);
    return fn_proto;
}

fn revertAndWarn(
    rp: RestorePoint,
    err: anytype,
    source_loc: ZigClangSourceLocation,
    comptime format: []const u8,
    args: anytype,
) (@TypeOf(err) || error{OutOfMemory}) {
    rp.activate();
    try emitWarning(rp.c, source_loc, format, args);
    return err;
}

fn emitWarning(c: *Context, loc: ZigClangSourceLocation, comptime format: []const u8, args: anytype) !void {
    const args_prefix = .{c.locStr(loc)};
    _ = try appendTokenFmt(c, .LineComment, "// {}: warning: " ++ format, args_prefix ++ args);
}

pub fn failDecl(c: *Context, loc: ZigClangSourceLocation, name: []const u8, comptime format: []const u8, args: anytype) !void {
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
    _ = try appendTokenFmt(c, .LineComment, "// {}", .{c.locStr(loc)});

    const msg_node = try c.arena.create(ast.Node.StringLiteral);
    msg_node.* = .{
        .token = msg_tok,
    };

    const call_node = try ast.Node.BuiltinCall.alloc(c.arena, 1);
    call_node.* = .{
        .builtin_token = builtin_tok,
        .params_len = 1,
        .rparen_token = rparen_tok,
    };
    call_node.params()[0] = &msg_node.base;

    const var_decl_node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = const_tok,
        .semicolon_token = semi_tok,
    }, .{
        .visib_token = pub_tok,
        .eq_token = eq_tok,
        .init_node = &call_node.base,
    });
    try addTopLevelDecl(c, name, &var_decl_node.base);
}

fn appendToken(c: *Context, token_id: Token.Id, bytes: []const u8) !ast.TokenIndex {
    std.debug.assert(token_id != .Identifier); // use appendIdentifier
    return appendTokenFmt(c, token_id, "{}", .{bytes});
}

fn appendTokenFmt(c: *Context, token_id: Token.Id, comptime format: []const u8, args: anytype) !ast.TokenIndex {
    assert(token_id != .Invalid);

    try c.token_ids.ensureCapacity(c.gpa, c.token_ids.items.len + 1);
    try c.token_locs.ensureCapacity(c.gpa, c.token_locs.items.len + 1);

    const start_index = c.source_buffer.items.len;
    try c.source_buffer.outStream().print(format ++ " ", args);

    c.token_ids.appendAssumeCapacity(token_id);
    c.token_locs.appendAssumeCapacity(.{
        .start = start_index,
        .end = c.source_buffer.items.len - 1, // back up before the space
    });

    return c.token_ids.items.len - 1;
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
    const identifier = try c.arena.create(ast.Node.Identifier);
    identifier.* = .{
        .token = token_index,
    };
    return &identifier.base;
}

fn transCreateNodeIdentifierUnchecked(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendTokenFmt(c, .Identifier, "{}", .{name});
    const identifier = try c.arena.create(ast.Node.Identifier);
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
    var tok_list = CTokenList.init(c.arena);
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
                const mangled_name = if (isZigPrimitiveType(name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ name, c.getMangle() }) else name;
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
                assert(mem.eql(u8, slice[first_tok.start..first_tok.end], name));

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

    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);
    const eq_token = try appendToken(c, .Equal, "=");

    const init_node = try parseCExpr(c, it, source, source_loc, scope);
    const last = it.next().?;
    if (last.id != .Eof and last.id != .Nl)
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: unexpected token .{}",
            .{@tagName(last.id)},
        );

    const semicolon_token = try appendToken(c, .Semicolon, ";");
    const node = try ast.Node.VarDecl.create(c.arena, .{
        .name_token = name_tok,
        .mut_token = mut_tok,
        .semicolon_token = semicolon_token,
    }, .{
        .visib_token = visib_tok,
        .eq_token = eq_token,
        .init_node = init_node,
    });
    _ = try c.global_scope.macro_table.put(name, &node.base);
}

fn transMacroFnDefine(c: *Context, it: *CTokenList.Iterator, source: []const u8, name: []const u8, source_loc: ZigClangSourceLocation) ParseError!void {
    var block_scope = try Scope.Block.init(c, &c.global_scope.base, null);
    defer block_scope.deinit();
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

    var fn_params = std.ArrayList(ast.Node.FnProto.ParamDecl).init(c.gpa);
    defer fn_params.deinit();

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

        const any_type = try c.arena.create(ast.Node.AnyType);
        any_type.* = .{
            .token = try appendToken(c, .Keyword_anytype, "anytype"),
        };

        (try fn_params.addOne()).* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = null,
            .name_token = param_name_tok,
            .param_type = .{ .any_type = &any_type.base },
        };

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

    const type_of = try c.createBuiltinCall("@TypeOf", 1);

    const return_expr = try transCreateNodeReturnExpr(c);
    const expr = try parseCExpr(c, it, source, source_loc, scope);
    const last = it.next().?;
    if (last.id != .Eof and last.id != .Nl)
        return failDecl(
            c,
            source_loc,
            name,
            "unable to translate C expr: unexpected token .{}",
            .{@tagName(last.id)},
        );
    _ = try appendToken(c, .Semicolon, ";");
    const type_of_arg = if (expr.tag != .Block) expr else blk: {
        const blk = @fieldParentPtr(ast.Node.Block, "base", expr);
        const blk_last = blk.statements()[blk.statements_len - 1];
        std.debug.assert(blk_last.tag == .ControlFlowExpression);
        const br = @fieldParentPtr(ast.Node.ControlFlowExpression, "base", blk_last);
        break :blk br.rhs.?;
    };
    type_of.params()[0] = type_of_arg;
    type_of.rparen_token = try appendToken(c, .RParen, ")");
    return_expr.rhs = expr;

    try block_scope.statements.append(&return_expr.base);
    const block_node = try block_scope.complete(c);
    const fn_proto = try ast.Node.FnProto.create(c.arena, .{
        .fn_token = fn_tok,
        .params_len = fn_params.items.len,
        .return_type = .{ .Explicit = &type_of.base },
    }, .{
        .visib_token = pub_tok,
        .extern_export_inline_token = inline_tok,
        .name_token = name_tok,
        .body_node = &block_node.base,
    });
    mem.copy(ast.Node.FnProto.ParamDecl, fn_proto.params(), fn_params.items);

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
        .Comma => {
            _ = try appendToken(c, .Semicolon, ";");
            const label_name = "blk";
            var block_scope = try Scope.Block.init(c, scope, label_name);
            defer block_scope.deinit();

            var last = node;
            while (true) {
                // suppress result
                const lhs = try transCreateNodeIdentifier(c, "_");
                const op_token = try appendToken(c, .Equal, "=");
                const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
                op_node.* = .{
                    .base = .{ .tag = .Assign },
                    .op_token = op_token,
                    .lhs = lhs,
                    .rhs = last,
                };
                try block_scope.statements.append(&op_node.base);

                last = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                _ = try appendToken(c, .Semicolon, ";");
                if (it.next().?.id != .Comma) {
                    _ = it.prev();
                    break;
                }
            }

            const break_node = try transCreateNodeBreak(c, label_name);
            break_node.rhs = last;
            try block_scope.statements.append(&break_node.base);
            const block_node = try block_scope.complete(c);
            return &block_node.base;
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
                    lit_bytes = try std.fmt.allocPrint(c.arena, "0o{}", .{lit_bytes});
                },
                'X' => {
                    // Hexadecimal with capital X, valid in C but not in Zig
                    lit_bytes = try std.fmt.allocPrint(c.arena, "0x{}", .{lit_bytes[2..]});
                },
                else => {},
            }
        }

        if (tok.id.IntegerLiteral == .None) {
            return transCreateNodeInt(c, lit_bytes);
        }

        const cast_node = try c.createBuiltinCall("@as", 2);
        cast_node.params()[0] = try transCreateNodeIdentifier(c, switch (tok.id.IntegerLiteral) {
            .U => "c_uint",
            .L => "c_long",
            .LU => "c_ulong",
            .LL => "c_longlong",
            .LLU => "c_ulonglong",
            else => unreachable,
        });
        lit_bytes = lit_bytes[0 .. lit_bytes.len - switch (tok.id.IntegerLiteral) {
            .U, .L => @as(u8, 1),
            .LU, .LL => 2,
            .LLU => 3,
            else => unreachable,
        }];
        _ = try appendToken(c, .Comma, ",");
        cast_node.params()[1] = try transCreateNodeInt(c, lit_bytes);
        cast_node.rparen_token = try appendToken(c, .RParen, ")");
        return &cast_node.base;
    } else if (tok.id == .FloatLiteral) {
        if (lit_bytes[0] == '.')
            lit_bytes = try std.fmt.allocPrint(c.arena, "0{}", .{lit_bytes});
        if (tok.id.FloatLiteral == .None) {
            return transCreateNodeFloat(c, lit_bytes);
        }
        const cast_node = try c.createBuiltinCall("@as", 2);
        cast_node.params()[0] = try transCreateNodeIdentifier(c, switch (tok.id.FloatLiteral) {
            .F => "f32",
            .L => "c_longdouble",
            else => unreachable,
        });
        _ = try appendToken(c, .Comma, ",");
        cast_node.params()[1] = try transCreateNodeFloat(c, lit_bytes[0 .. lit_bytes.len - 1]);
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
    var bytes = try ctx.arena.alloc(u8, source.len * 2);
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
            if (source[tok.start] != '\'' or source[tok.start + 1] == '\\' or tok.end - tok.start == 3) {
                const token = try appendToken(c, .CharLiteral, try zigifyEscapeSequences(c, source[tok.start..tok.end], source[first_tok.start..first_tok.end], source_loc));
                const node = try c.arena.create(ast.Node.CharLiteral);
                node.* = .{
                    .token = token,
                };
                return &node.base;
            } else {
                const token = try appendTokenFmt(c, .IntegerLiteral, "0x{x}", .{source[tok.start + 1 .. tok.end - 1]});
                const node = try c.arena.create(ast.Node.IntegerLiteral);
                node.* = .{
                    .token = token,
                };
                return &node.base;
            }
        },
        .StringLiteral => {
            const first_tok = it.list.at(0);
            const token = try appendToken(c, .StringLiteral, try zigifyEscapeSequences(c, source[tok.start..tok.end], source[first_tok.start..first_tok.end], source_loc));
            const node = try c.arena.create(ast.Node.StringLiteral);
            node.* = .{
                .token = token,
            };
            return &node.base;
        },
        .IntegerLiteral, .FloatLiteral => {
            return parseCNumLit(c, tok, source, source_loc);
        },
        // eventually this will be replaced by std.c.parse which will handle these correctly
        .Keyword_void => return transCreateNodeIdentifierUnchecked(c, "c_void"),
        .Keyword_bool => return transCreateNodeIdentifierUnchecked(c, "bool"),
        .Keyword_double => return transCreateNodeIdentifierUnchecked(c, "f64"),
        .Keyword_long => return transCreateNodeIdentifierUnchecked(c, "c_long"),
        .Keyword_int => return transCreateNodeIdentifierUnchecked(c, "c_int"),
        .Keyword_float => return transCreateNodeIdentifierUnchecked(c, "f32"),
        .Keyword_short => return transCreateNodeIdentifierUnchecked(c, "c_short"),
        .Keyword_char => return transCreateNodeIdentifierUnchecked(c, "c_char"),
        .Keyword_unsigned => return transCreateNodeIdentifierUnchecked(c, "c_uint"),
        .Identifier => {
            const mangled_name = scope.getAlias(source[tok.start..tok.end]);
            return transCreateNodeIdentifier(c, mangled_name);
        },
        .LParen => {
            const inner_node = try parseCExpr(c, it, source, source_loc, scope);

            const next_id = it.next().?.id;
            if (next_id != .RParen) {
                const first_tok = it.list.at(0);
                try failDecl(
                    c,
                    source_loc,
                    source[first_tok.start..first_tok.end],
                    "unable to translate C expr: expected ')'' instead got: {}",
                    .{@tagName(next_id)},
                );
                return error.ParseError;
            }
            var saw_l_paren = false;
            var saw_integer_literal = false;
            switch (it.peek().?.id) {
                // (type)(to_cast)
                .LParen => {
                    saw_l_paren = true;
                    _ = it.next();
                },
                // (type)identifier
                .Identifier => {},
                // (type)integer
                .IntegerLiteral => {
                    saw_integer_literal = true;
                },
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

            const lparen = try appendToken(c, .LParen, "(");

            //(@import("std").meta.cast(dest, x))
            const import_fn_call = try c.createBuiltinCall("@import", 1);
            const std_node = try transCreateNodeStringLiteral(c, "\"std\"");
            import_fn_call.params()[0] = std_node;
            import_fn_call.rparen_token = try appendToken(c, .RParen, ")");
            const inner_field_access = try transCreateNodeFieldAccess(c, &import_fn_call.base, "meta");
            const outer_field_access = try transCreateNodeFieldAccess(c, inner_field_access, "cast");

            const cast_fn_call = try c.createCall(outer_field_access, 2);
            cast_fn_call.params()[0] = inner_node;
            cast_fn_call.params()[1] = node_to_cast;
            cast_fn_call.rtoken = try appendToken(c, .RParen, ")");

            const group_node = try c.arena.create(ast.Node.GroupedExpression);
            group_node.* = .{
                .lparen = lparen,
                .expr = &cast_fn_call.base,
                .rparen = try appendToken(c, .RParen, ")"),
            };
            return &group_node.base;
        },
        else => {
            const first_tok = it.list.at(0);
            try failDecl(
                c,
                source_loc,
                source[first_tok.start..first_tok.end],
                "unable to translate C expr: unexpected token .{}",
                .{@tagName(tok.id)},
            );
            return error.ParseError;
        },
    }
}

fn nodeIsInfixOp(tag: ast.Node.Tag) bool {
    return switch (tag) {
        .Add,
        .AddWrap,
        .ArrayCat,
        .ArrayMult,
        .Assign,
        .AssignBitAnd,
        .AssignBitOr,
        .AssignBitShiftLeft,
        .AssignBitShiftRight,
        .AssignBitXor,
        .AssignDiv,
        .AssignSub,
        .AssignSubWrap,
        .AssignMod,
        .AssignAdd,
        .AssignAddWrap,
        .AssignMul,
        .AssignMulWrap,
        .BangEqual,
        .BitAnd,
        .BitOr,
        .BitShiftLeft,
        .BitShiftRight,
        .BitXor,
        .BoolAnd,
        .BoolOr,
        .Div,
        .EqualEqual,
        .ErrorUnion,
        .GreaterOrEqual,
        .GreaterThan,
        .LessOrEqual,
        .LessThan,
        .MergeErrorSets,
        .Mod,
        .Mul,
        .MulWrap,
        .Period,
        .Range,
        .Sub,
        .SubWrap,
        .UnwrapOptional,
        .Catch,
        => true,

        else => false,
    };
}

fn macroBoolToInt(c: *Context, node: *ast.Node) !*ast.Node {
    if (!isBoolRes(node)) {
        if (!nodeIsInfixOp(node.tag)) return node;

        const group_node = try c.arena.create(ast.Node.GroupedExpression);
        group_node.* = .{
            .lparen = try appendToken(c, .LParen, "("),
            .expr = node,
            .rparen = try appendToken(c, .RParen, ")"),
        };
        return &group_node.base;
    }

    const builtin_node = try c.createBuiltinCall("@boolToInt", 1);
    builtin_node.params()[0] = node;
    builtin_node.rparen_token = try appendToken(c, .RParen, ")");
    return &builtin_node.base;
}

fn macroIntToBool(c: *Context, node: *ast.Node) !*ast.Node {
    if (isBoolRes(node)) {
        if (!nodeIsInfixOp(node.tag)) return node;

        const group_node = try c.arena.create(ast.Node.GroupedExpression);
        group_node.* = .{
            .lparen = try appendToken(c, .LParen, "("),
            .expr = node,
            .rparen = try appendToken(c, .RParen, ")"),
        };
        return &group_node.base;
    }

    const op_token = try appendToken(c, .BangEqual, "!=");
    const zero = try transCreateNodeInt(c, 0);
    const res = try c.arena.create(ast.Node.SimpleInfixOp);
    res.* = .{
        .base = .{ .tag = .BangEqual },
        .op_token = op_token,
        .lhs = node,
        .rhs = zero,
    };
    const group_node = try c.arena.create(ast.Node.GroupedExpression);
    group_node.* = .{
        .lparen = try appendToken(c, .LParen, "("),
        .expr = &res.base,
        .rparen = try appendToken(c, .RParen, ")"),
    };
    return &group_node.base;
}

fn parseCSuffixOpExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCPrimaryExpr(c, it, source, source_loc, scope);
    while (true) {
        const tok = it.next().?;
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        var bool_op = false;
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
                continue;
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
                continue;
            },
            .Asterisk => {
                if (it.peek().?.id == .RParen) {
                    // type *)

                    // hack to get zig fmt to render a comma in builtin calls
                    _ = try appendToken(c, .Comma, ",");

                    // * token
                    _ = it.prev();
                    // last token of `node`
                    const prev_id = it.prev().?.id;
                    _ = it.next();
                    _ = it.next();

                    if (prev_id == .Keyword_void) {
                        const ptr = try transCreateNodePtrType(c, false, false, .Asterisk);
                        ptr.rhs = node;
                        const optional_node = try transCreateNodeSimplePrefixOp(c, .OptionalType, .QuestionMark, "?");
                        optional_node.rhs = &ptr.base;
                        return &optional_node.base;
                    } else {
                        const ptr = try transCreateNodePtrType(c, false, false, Token.Id.Identifier);
                        ptr.rhs = node;
                        return &ptr.base;
                    }
                } else {
                    // expr * expr
                    op_token = try appendToken(c, .Asterisk, "*");
                    op_id = .BitShiftLeft;
                }
            },
            .AngleBracketAngleBracketLeft => {
                op_token = try appendToken(c, .AngleBracketAngleBracketLeft, "<<");
                op_id = .BitShiftLeft;
            },
            .AngleBracketAngleBracketRight => {
                op_token = try appendToken(c, .AngleBracketAngleBracketRight, ">>");
                op_id = .BitShiftRight;
            },
            .Pipe => {
                op_token = try appendToken(c, .Pipe, "|");
                op_id = .BitOr;
            },
            .Ampersand => {
                op_token = try appendToken(c, .Ampersand, "&");
                op_id = .BitAnd;
            },
            .Plus => {
                op_token = try appendToken(c, .Plus, "+");
                op_id = .Add;
            },
            .Minus => {
                op_token = try appendToken(c, .Minus, "-");
                op_id = .Sub;
            },
            .AmpersandAmpersand => {
                op_token = try appendToken(c, .Keyword_and, "and");
                op_id = .BoolAnd;
                bool_op = true;
            },
            .PipePipe => {
                op_token = try appendToken(c, .Keyword_or, "or");
                op_id = .BoolOr;
                bool_op = true;
            },
            .AngleBracketRight => {
                op_token = try appendToken(c, .AngleBracketRight, ">");
                op_id = .GreaterThan;
            },
            .AngleBracketRightEqual => {
                op_token = try appendToken(c, .AngleBracketRightEqual, ">=");
                op_id = .GreaterOrEqual;
            },
            .AngleBracketLeft => {
                op_token = try appendToken(c, .AngleBracketLeft, "<");
                op_id = .LessThan;
            },
            .AngleBracketLeftEqual => {
                op_token = try appendToken(c, .AngleBracketLeftEqual, "<=");
                op_id = .LessOrEqual;
            },
            .LBracket => {
                const arr_node = try transCreateNodeArrayAccess(c, node);
                arr_node.index_expr = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
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
                continue;
            },
            .LParen => {
                _ = try appendToken(c, .LParen, "(");
                var call_params = std.ArrayList(*ast.Node).init(c.gpa);
                defer call_params.deinit();
                while (true) {
                    const arg = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                    try call_params.append(arg);
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
                const call_node = try ast.Node.Call.alloc(c.arena, call_params.items.len);
                call_node.* = .{
                    .lhs = node,
                    .params_len = call_params.items.len,
                    .async_token = null,
                    .rtoken = try appendToken(c, .RParen, ")"),
                };
                mem.copy(*ast.Node, call_node.params(), call_params.items);
                node = &call_node.base;
                continue;
            },
            .LBrace => {
                // must come immediately after `node`
                _ = try appendToken(c, .Comma, ",");

                const dot = try appendToken(c, .Period, ".");
                _ = try appendToken(c, .LBrace, "{");

                var init_vals = std.ArrayList(*ast.Node).init(c.gpa);
                defer init_vals.deinit();

                while (true) {
                    const val = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
                    try init_vals.append(val);
                    const next = it.next().?;
                    if (next.id == .Comma)
                        _ = try appendToken(c, .Comma, ",")
                    else if (next.id == .RBrace)
                        break
                    else {
                        const first_tok = it.list.at(0);
                        try failDecl(
                            c,
                            source_loc,
                            source[first_tok.start..first_tok.end],
                            "unable to translate C expr: expected ',' or '}}'",
                            .{},
                        );
                        return error.ParseError;
                    }
                }
                const tuple_node = try ast.Node.StructInitializerDot.alloc(c.arena, init_vals.items.len);
                tuple_node.* = .{
                    .dot = dot,
                    .list_len = init_vals.items.len,
                    .rtoken = try appendToken(c, .RBrace, "}"),
                };
                mem.copy(*ast.Node, tuple_node.list(), init_vals.items);

                //(@import("std").mem.zeroInit(T, .{x}))
                const import_fn_call = try c.createBuiltinCall("@import", 1);
                const std_node = try transCreateNodeStringLiteral(c, "\"std\"");
                import_fn_call.params()[0] = std_node;
                import_fn_call.rparen_token = try appendToken(c, .RParen, ")");
                const inner_field_access = try transCreateNodeFieldAccess(c, &import_fn_call.base, "mem");
                const outer_field_access = try transCreateNodeFieldAccess(c, inner_field_access, "zeroInit");

                const zero_init_call = try c.createCall(outer_field_access, 2);
                zero_init_call.params()[0] = node;
                zero_init_call.params()[1] = &tuple_node.base;
                zero_init_call.rtoken = try appendToken(c, .RParen, ")");

                node = &zero_init_call.base;
                continue;
            },
            .BangEqual => {
                op_token = try appendToken(c, .BangEqual, "!=");
                op_id = .BangEqual;
            },
            .EqualEqual => {
                op_token = try appendToken(c, .EqualEqual, "==");
                op_id = .EqualEqual;
            },
            .Slash => {
                op_id = .Div;
                op_token = try appendToken(c, .Slash, "/");
            },
            .Percent => {
                op_id = .Mod;
                op_token = try appendToken(c, .Percent, "%");
            },
            .StringLiteral => {
                op_id = .ArrayCat;
                op_token = try appendToken(c, .PlusPlus, "++");

                _ = it.prev();
            },
            .Identifier => {
                op_id = .ArrayCat;
                op_token = try appendToken(c, .PlusPlus, "++");

                _ = it.prev();
            },
            else => {
                _ = it.prev();
                return node;
            },
        }
        const cast_fn = if (bool_op) macroIntToBool else macroBoolToInt;
        const lhs_node = try cast_fn(c, node);
        const rhs_node = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try cast_fn(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCPrefixOpExpr(c: *Context, it: *CTokenList.Iterator, source: []const u8, source_loc: ZigClangSourceLocation, scope: *Scope) ParseError!*ast.Node {
    const op_tok = it.next().?;

    switch (op_tok.id) {
        .Bang => {
            const node = try transCreateNodeSimplePrefixOp(c, .BoolNot, .Bang, "!");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Minus => {
            const node = try transCreateNodeSimplePrefixOp(c, .Negation, .Minus, "-");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Plus => return try parseCPrefixOpExpr(c, it, source, source_loc, scope),
        .Tilde => {
            const node = try transCreateNodeSimplePrefixOp(c, .BitNot, .Tilde, "~");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        .Asterisk => {
            const node = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return try transCreateNodePtrDeref(c, node);
        },
        .Ampersand => {
            const node = try transCreateNodeSimplePrefixOp(c, .AddressOf, .Ampersand, "&");
            node.rhs = try parseCPrefixOpExpr(c, it, source, source_loc, scope);
            return &node.base;
        },
        else => {
            _ = it.prev();
            return try parseCSuffixOpExpr(c, it, source, source_loc, scope);
        },
    }
}

fn tokenSlice(c: *Context, token: ast.TokenIndex) []u8 {
    const tok = c.token_locs.items[token];
    const slice = c.source_buffer.span()[tok.start..tok.end];
    return if (mem.startsWith(u8, slice, "@\""))
        slice[2 .. slice.len - 1]
    else
        slice;
}

fn getContainer(c: *Context, node: *ast.Node) ?*ast.Node {
    switch (node.tag) {
        .ContainerDecl,
        .AddressOf,
        .Await,
        .BitNot,
        .BoolNot,
        .OptionalType,
        .Negation,
        .NegationWrap,
        .Resume,
        .Try,
        .ArrayType,
        .ArrayTypeSentinel,
        .PtrType,
        .SliceType,
        => return node,

        .Identifier => {
            const ident = node.cast(ast.Node.Identifier).?;
            if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |value| {
                if (value.cast(ast.Node.VarDecl)) |var_decl|
                    return getContainer(c, var_decl.getTrailer("init_node").?);
            }
        },

        .Period => {
            const infix = node.castTag(.Period).?;

            if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
                if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                    for (container.fieldsAndDecls()) |field_ref| {
                        const field = field_ref.cast(ast.Node.ContainerField).?;
                        const ident = infix.rhs.cast(ast.Node.Identifier).?;
                        if (mem.eql(u8, tokenSlice(c, field.name_token), tokenSlice(c, ident.token))) {
                            return getContainer(c, field.type_expr.?);
                        }
                    }
                }
            }
        },

        else => {},
    }
    return null;
}

fn getContainerTypeOf(c: *Context, ref: *ast.Node) ?*ast.Node {
    if (ref.cast(ast.Node.Identifier)) |ident| {
        if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |value| {
            if (value.cast(ast.Node.VarDecl)) |var_decl| {
                if (var_decl.getTrailer("type_node")) |ty|
                    return getContainer(c, ty);
            }
        }
    } else if (ref.castTag(.Period)) |infix| {
        if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
            if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                for (container.fieldsAndDecls()) |field_ref| {
                    const field = field_ref.cast(ast.Node.ContainerField).?;
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
    const init = if (ref.cast(ast.Node.VarDecl)) |v| v.getTrailer("init_node").? else return null;
    if (getContainerTypeOf(c, init)) |ty_node| {
        if (ty_node.castTag(.OptionalType)) |prefix| {
            if (prefix.rhs.cast(ast.Node.FnProto)) |fn_proto| {
                return fn_proto;
            }
        }
    }
    return null;
}

fn addMacros(c: *Context) !void {
    for (c.global_scope.macro_table.items()) |kv| {
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
