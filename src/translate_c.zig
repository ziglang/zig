//! This is the userland implementation of translate-c which is used by both stage1
//! and stage2.

const std = @import("std");
const assert = std.debug.assert;
const ast = std.zig.ast;
const Token = std.zig.Token;
const clang = @import("clang.zig");
const ctok = std.c.tokenizer;
const CToken = std.c.Token;
const mem = std.mem;
const math = std.math;

const CallingConvention = std.builtin.CallingConvention;

pub const ClangErrMsg = clang.Stage2ErrorMsg;

pub const Error = error{OutOfMemory};
const TypeError = Error || error{UnsupportedType};
const TransError = TypeError || error{UnsupportedTranslation};

const SymbolTable = std.StringArrayHashMap(*ast.Node);
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
        switch_label: ?[]const u8,
        default_label: ?[]const u8,
    };

    /// Used for the scope of condition expressions, for example `if (cond)`.
    /// The block is lazily initialised because it is only needed for rare
    /// cases of comma operators being used.
    const Condition = struct {
        base: Scope,
        block: ?Block = null,

        fn getBlockScope(self: *Condition, c: *Context) !*Block {
            if (self.block) |*b| return b;
            self.block = try Block.init(c, &self.base, true);
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

        fn init(c: *Context, parent: *Scope, labeled: bool) !Block {
            var blk = Block{
                .base = .{
                    .id = .Block,
                    .parent = parent,
                },
                .statements = std.ArrayList(*ast.Node).init(c.gpa),
                .variables = AliasList.init(c.gpa),
                .label = null,
                .lbrace = try appendToken(c, .LBrace, "{"),
            };
            if (labeled) {
                blk.label = try appendIdentifier(c, try blk.makeMangledName(c, "blk"));
                _ = try appendToken(c, .Colon, ":");
            }
            return blk;
        }

        fn deinit(self: *Block) void {
            self.statements.deinit();
            self.variables.deinit();
            self.* = undefined;
        }

        fn complete(self: *Block, c: *Context) !*ast.Node {
            // We reserve 1 extra statement if the parent is a Loop. This is in case of
            // do while, we want to put `if (cond) break;` at the end.
            const alloc_len = self.statements.items.len + @boolToInt(self.base.parent.?.id == .Loop);
            const rbrace = try appendToken(c, .RBrace, "}");
            if (self.label) |label| {
                const node = try ast.Node.LabeledBlock.alloc(c.arena, alloc_len);
                node.* = .{
                    .statements_len = self.statements.items.len,
                    .lbrace = self.lbrace,
                    .rbrace = rbrace,
                    .label = label,
                };
                mem.copy(*ast.Node, node.statements(), self.statements.items);
                return &node.base;
            } else {
                const node = try ast.Node.Block.alloc(c.arena, alloc_len);
                node.* = .{
                    .statements_len = self.statements.items.len,
                    .lbrace = self.lbrace,
                    .rbrace = rbrace,
                };
                mem.copy(*ast.Node, node.statements(), self.statements.items);
                return &node.base;
            }
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
                if (mem.eql(u8, p.alias, name))
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
    token_ids: std.ArrayListUnmanaged(Token.Id) = .{},
    token_locs: std.ArrayListUnmanaged(Token.Loc) = .{},
    errors: std.ArrayListUnmanaged(ast.Error) = .{},
    source_buffer: *std.ArrayList(u8),
    err: Error,
    source_manager: *clang.SourceManager,
    decl_table: std.AutoArrayHashMapUnmanaged(usize, []const u8) = .{},
    alias_list: AliasList,
    global_scope: *Scope.Root,
    clang_context: *clang.ASTContext,
    mangle_count: u32 = 0,
    root_decls: std.ArrayListUnmanaged(*ast.Node) = .{},
    opaque_demotes: std.AutoHashMapUnmanaged(usize, void) = .{},

    /// This one is different than the root scope's name table. This contains
    /// a list of names that we found by visiting all the top level decls without
    /// translating them. The other maps are updated as we translate; this one is updated
    /// up front in a pre-processing step.
    global_names: std.StringArrayHashMapUnmanaged(void) = .{},

    fn getMangle(c: *Context) u32 {
        c.mangle_count += 1;
        return c.mangle_count;
    }

    /// Convert a null-terminated C string to a slice allocated in the arena
    fn str(c: *Context, s: [*:0]const u8) ![]u8 {
        return mem.dupe(c.arena, u8, mem.spanZ(s));
    }

    /// Convert a clang source location to a file:line:column string
    fn locStr(c: *Context, loc: clang.SourceLocation) ![]u8 {
        const spelling_loc = c.source_manager.getSpellingLoc(loc);
        const filename_c = c.source_manager.getFilename(spelling_loc);
        const filename = if (filename_c) |s| try c.str(s) else @as([]const u8, "(no file)");

        const line = c.source_manager.getSpellingLineNumber(spelling_loc);
        const column = c.source_manager.getSpellingColumnNumber(spelling_loc);
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

    fn createBlock(c: *Context, statements_len: ast.NodeIndex) !*ast.Node.Block {
        const block_node = try ast.Node.Block.alloc(c.arena, statements_len);
        block_node.* = .{
            .lbrace = try appendToken(c, .LBrace, "{"),
            .statements_len = statements_len,
            .rbrace = undefined,
        };
        return block_node;
    }
};

fn addCBuiltinsNamespace(c: *Context) Error!void {
    // pub usingnamespace @import("std").c.builtins;
    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const use_tok = try appendToken(c, .Keyword_usingnamespace, "usingnamespace");
    const import_tok = try appendToken(c, .Builtin, "@import");
    const lparen_tok = try appendToken(c, .LParen, "(");
    const std_tok = try appendToken(c, .StringLiteral, "\"std\"");
    const rparen_tok = try appendToken(c, .RParen, ")");

    const std_node = try c.arena.create(ast.Node.OneToken);
    std_node.* = .{
        .base = .{ .tag = .StringLiteral },
        .token = std_tok,
    };

    const call_node = try ast.Node.BuiltinCall.alloc(c.arena, 1);
    call_node.* = .{
        .builtin_token = import_tok,
        .params_len = 1,
        .rparen_token = rparen_tok,
    };
    call_node.params()[0] = &std_node.base;

    var access_chain = &call_node.base;
    access_chain = try transCreateNodeFieldAccess(c, access_chain, "c");
    access_chain = try transCreateNodeFieldAccess(c, access_chain, "builtins");

    const semi_tok = try appendToken(c, .Semicolon, ";");

    const bytes = try c.gpa.alignedAlloc(u8, @alignOf(ast.Node.Use), @sizeOf(ast.Node.Use));
    const using_node = @ptrCast(*ast.Node.Use, bytes.ptr);
    using_node.* = .{
        .doc_comments = null,
        .visib_token = pub_tok,
        .use_token = use_tok,
        .expr = access_chain,
        .semicolon_token = semi_tok,
    };
    try c.root_decls.append(c.gpa, &using_node.base);
}

pub fn translate(
    gpa: *mem.Allocator,
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors: *[]ClangErrMsg,
    resources_path: [*:0]const u8,
) !*ast.Tree {
    const ast_unit = clang.LoadFromCommandLine(
        args_begin,
        args_end,
        &errors.ptr,
        &errors.len,
        resources_path,
    ) orelse {
        if (errors.len == 0) return error.ASTUnitFailure;
        return error.SemanticAnalyzeFail;
    };
    defer ast_unit.delete();

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
        .source_manager = ast_unit.getSourceManager(),
        .err = undefined,
        .alias_list = AliasList.init(gpa),
        .global_scope = try arena.allocator.create(Scope.Root),
        .clang_context = ast_unit.getASTContext(),
    };
    context.global_scope.* = Scope.Root.init(&context);
    defer {
        context.decl_table.deinit(gpa);
        context.alias_list.deinit();
        context.token_ids.deinit(gpa);
        context.token_locs.deinit(gpa);
        context.errors.deinit(gpa);
        context.global_names.deinit(gpa);
        context.root_decls.deinit(gpa);
        context.opaque_demotes.deinit(gpa);
    }

    try addCBuiltinsNamespace(&context);

    try prepopulateGlobalNameTable(ast_unit, &context);

    if (!ast_unit.visitLocalTopLevelDecls(&context, declVisitorC)) {
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

fn prepopulateGlobalNameTable(ast_unit: *clang.ASTUnit, c: *Context) !void {
    if (!ast_unit.visitLocalTopLevelDecls(c, declVisitorNamesOnlyC)) {
        return c.err;
    }

    // TODO if we see #undef, delete it from the table
    var it = ast_unit.getLocalPreprocessingEntities_begin();
    const it_end = ast_unit.getLocalPreprocessingEntities_end();

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = it.deref();
        switch (entity.getKind()) {
            .MacroDefinitionKind => {
                const macro = @ptrCast(*clang.MacroDefinitionRecord, entity);
                const raw_name = macro.getName_getNameStart();
                const name = try c.str(raw_name);
                _ = try c.global_names.put(c.gpa, name, {});
            },
            else => {},
        }
    }
}

fn declVisitorNamesOnlyC(context: ?*c_void, decl: *const clang.Decl) callconv(.C) bool {
    const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    declVisitorNamesOnly(c, decl) catch |err| {
        c.err = err;
        return false;
    };
    return true;
}

fn declVisitorC(context: ?*c_void, decl: *const clang.Decl) callconv(.C) bool {
    const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    declVisitor(c, decl) catch |err| {
        c.err = err;
        return false;
    };
    return true;
}

fn declVisitorNamesOnly(c: *Context, decl: *const clang.Decl) Error!void {
    if (decl.castToNamedDecl()) |named_decl| {
        const decl_name = try c.str(named_decl.getName_bytes_begin());
        _ = try c.global_names.put(c.gpa, decl_name, {});
    }
}

fn declVisitor(c: *Context, decl: *const clang.Decl) Error!void {
    switch (decl.getKind()) {
        .Function => {
            return visitFnDecl(c, @ptrCast(*const clang.FunctionDecl, decl));
        },
        .Typedef => {
            _ = try transTypeDef(c, @ptrCast(*const clang.TypedefNameDecl, decl), true);
        },
        .Enum => {
            _ = try transEnumDecl(c, @ptrCast(*const clang.EnumDecl, decl));
        },
        .Record => {
            _ = try transRecordDecl(c, @ptrCast(*const clang.RecordDecl, decl));
        },
        .Var => {
            return visitVarDecl(c, @ptrCast(*const clang.VarDecl, decl), null);
        },
        .Empty => {
            // Do nothing
        },
        else => {
            const decl_name = try c.str(decl.getDeclKindName());
            try emitWarning(c, decl.getLocation(), "ignoring {} declaration", .{decl_name});
        },
    }
}

fn visitFnDecl(c: *Context, fn_decl: *const clang.FunctionDecl) Error!void {
    const fn_name = try c.str(@ptrCast(*const clang.NamedDecl, fn_decl).getName_bytes_begin());
    if (c.global_scope.sym_table.contains(fn_name))
        return; // Avoid processing this decl twice

    // Skip this declaration if a proper definition exists
    if (!fn_decl.isThisDeclarationADefinition()) {
        if (fn_decl.getDefinition()) |def|
            return visitFnDecl(c, def);
    }

    const rp = makeRestorePoint(c);
    const fn_decl_loc = fn_decl.getLocation();
    const has_body = fn_decl.hasBody();
    const storage_class = fn_decl.getStorageClass();
    var decl_ctx = FnDeclContext{
        .fn_name = fn_name,
        .has_body = has_body,
        .storage_class = storage_class,
        .is_export = switch (storage_class) {
            .None => has_body and !fn_decl.isInlineSpecified(),
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern", .{}),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        },
    };

    var fn_qt = fn_decl.getType();

    const fn_type = while (true) {
        const fn_type = fn_qt.getTypePtr();

        switch (fn_type.getTypeClass()) {
            .Attributed => {
                const attr_type = @ptrCast(*const clang.AttributedType, fn_type);
                fn_qt = attr_type.getEquivalentType();
            },
            .Paren => {
                const paren_type = @ptrCast(*const clang.ParenType, fn_type);
                fn_qt = paren_type.getInnerType();
            },
            else => break fn_type,
        }
    } else unreachable;

    const proto_node = switch (fn_type.getTypeClass()) {
        .FunctionProto => blk: {
            const fn_proto_type = @ptrCast(*const clang.FunctionProtoType, fn_type);
            if (has_body and fn_proto_type.isVariadic()) {
                decl_ctx.has_body = false;
                decl_ctx.storage_class = .Extern;
                decl_ctx.is_export = false;
                try emitWarning(c, fn_decl_loc, "TODO unable to translate variadic function, demoted to declaration", .{});
            }
            break :blk transFnProto(rp, fn_decl, fn_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
                },
                error.OutOfMemory => |e| return e,
            };
        },
        .FunctionNoProto => blk: {
            const fn_no_proto_type = @ptrCast(*const clang.FunctionType, fn_type);
            break :blk transFnNoProto(rp, fn_no_proto_type, fn_decl_loc, decl_ctx, true) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function", .{});
                },
                error.OutOfMemory => |e| return e,
            };
        },
        else => return failDecl(c, fn_decl_loc, fn_name, "unable to resolve function type {}", .{fn_type.getTypeClass()}),
    };

    if (!decl_ctx.has_body) {
        const semi_tok = try appendToken(c, .Semicolon, ";");
        return addTopLevelDecl(c, fn_name, &proto_node.base);
    }

    // actual function definition with body
    const body_stmt = fn_decl.getBody();
    var block_scope = try Scope.Block.init(rp.c, &c.global_scope.base, false);
    defer block_scope.deinit();
    var scope = &block_scope.base;

    var param_id: c_uint = 0;
    for (proto_node.params()) |*param, i| {
        const param_name = if (param.name_token) |name_tok|
            tokenSlice(c, name_tok)
        else
            return failDecl(c, fn_decl_loc, fn_name, "function {} parameter has no name", .{fn_name});

        const c_param = fn_decl.getParamDecl(param_id);
        const qual_type = c_param.getOriginalType();
        const is_const = qual_type.isConstQualified();

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

    const casted_body = @ptrCast(*const clang.CompoundStmt, body_stmt);
    transCompoundStmtInline(rp, &block_scope.base, casted_body, &block_scope) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.UnsupportedTranslation,
        error.UnsupportedType,
        => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function", .{}),
    };
    // add return statement if the function didn't have one
    blk: {
        const fn_ty = @ptrCast(*const clang.FunctionType, fn_type);

        if (fn_ty.getNoReturnAttr()) break :blk;
        const return_qt = fn_ty.getReturnType();
        if (isCVoid(return_qt)) break :blk;

        if (block_scope.statements.items.len > 0) {
            var last = block_scope.statements.items[block_scope.statements.items.len - 1];
            while (true) {
                switch (last.tag) {
                    .Block, .LabeledBlock => {
                        const stmts = last.blockStatements();
                        if (stmts.len == 0) break;

                        last = stmts[stmts.len - 1];
                    },
                    // no extra return needed
                    .Return => break :blk,
                    else => break,
                }
            }
        }

        const return_expr = try ast.Node.ControlFlowExpression.create(rp.c.arena, .{
            .ltoken = try appendToken(rp.c, .Keyword_return, "return"),
            .tag = .Return,
        }, .{
            .rhs = transZeroInitExpr(rp, scope, fn_decl_loc, return_qt.getTypePtr()) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.UnsupportedTranslation,
                error.UnsupportedType,
                => return failDecl(c, fn_decl_loc, fn_name, "unable to create a return value for function", .{}),
            },
        });
        _ = try appendToken(rp.c, .Semicolon, ";");
        try block_scope.statements.append(&return_expr.base);
    }

    const body_node = try block_scope.complete(rp.c);
    proto_node.setBodyNode(body_node);
    return addTopLevelDecl(c, fn_name, &proto_node.base);
}

/// if mangled_name is not null, this var decl was declared in a block scope.
fn visitVarDecl(c: *Context, var_decl: *const clang.VarDecl, mangled_name: ?[]const u8) Error!void {
    const var_name = mangled_name orelse try c.str(@ptrCast(*const clang.NamedDecl, var_decl).getName_bytes_begin());
    if (c.global_scope.sym_table.contains(var_name))
        return; // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const visib_tok = if (mangled_name) |_| null else try appendToken(c, .Keyword_pub, "pub");

    const thread_local_token = if (var_decl.getTLSKind() == .None)
        null
    else
        try appendToken(c, .Keyword_threadlocal, "threadlocal");

    const scope = &c.global_scope.base;

    // TODO https://github.com/ziglang/zig/issues/3756
    // TODO https://github.com/ziglang/zig/issues/1802
    const checked_name = if (isZigPrimitiveType(var_name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ var_name, c.getMangle() }) else var_name;
    const var_decl_loc = var_decl.getLocation();

    const qual_type = var_decl.getTypeSourceInfo_getType();
    const storage_class = var_decl.getStorageClass();
    const is_const = qual_type.isConstQualified();
    const has_init = var_decl.hasInit();

    // In C extern variables with initializers behave like Zig exports.
    // extern int foo = 2;
    // does the same as:
    // extern int foo;
    // int foo = 2;
    const extern_tok = if (storage_class == .Extern and !has_init)
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
    if (has_init) {
        eq_tok = try appendToken(c, .Equal, "=");
        init_node = if (var_decl.getInit()) |expr|
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
        // The C language specification states that variables with static or threadlocal
        // storage without an initializer are initialized to a zero value.

        // @import("std").mem.zeroes(T)
        const import_fn_call = try c.createBuiltinCall("@import", 1);
        const std_node = try transCreateNodeStringLiteral(c, "\"std\"");
        import_fn_call.params()[0] = std_node;
        import_fn_call.rparen_token = try appendToken(c, .RParen, ")");
        const inner_field_access = try transCreateNodeFieldAccess(c, &import_fn_call.base, "mem");
        const outer_field_access = try transCreateNodeFieldAccess(c, inner_field_access, "zeroes");

        const zero_init_call = try c.createCall(outer_field_access, 1);
        zero_init_call.params()[0] = type_node;
        zero_init_call.rtoken = try appendToken(c, .RParen, ")");

        init_node = &zero_init_call.base;
    }

    const linksection_expr = blk: {
        var str_len: usize = undefined;
        if (var_decl.getSectionAttribute(&str_len)) |str_ptr| {
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
        const alignment = var_decl.getAlignedAttribute(rp.c.clang_context);
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

fn transTypeDefAsBuiltin(c: *Context, typedef_decl: *const clang.TypedefNameDecl, builtin_name: []const u8) !*ast.Node {
    _ = try c.decl_table.put(c.gpa, @ptrToInt(typedef_decl.getCanonicalDecl()), builtin_name);
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

fn transTypeDef(c: *Context, typedef_decl: *const clang.TypedefNameDecl, top_level_visit: bool) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(typedef_decl.getCanonicalDecl()))) |name|
        return transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);

    const typedef_name = try c.str(@ptrCast(*const clang.NamedDecl, typedef_decl).getName_bytes_begin());

    // TODO https://github.com/ziglang/zig/issues/3756
    // TODO https://github.com/ziglang/zig/issues/1802
    const checked_name = if (isZigPrimitiveType(typedef_name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ typedef_name, c.getMangle() }) else typedef_name;
    if (checkForBuiltinTypedef(checked_name)) |builtin| {
        return transTypeDefAsBuiltin(c, typedef_decl, builtin);
    }

    if (!top_level_visit) {
        return transCreateNodeIdentifier(c, checked_name);
    }

    _ = try c.decl_table.put(c.gpa, @ptrToInt(typedef_decl.getCanonicalDecl()), checked_name);
    const node = (try transCreateNodeTypedef(rp, typedef_decl, true, checked_name)) orelse return null;
    try addTopLevelDecl(c, checked_name, node);
    return transCreateNodeIdentifier(c, checked_name);
}

fn transCreateNodeTypedef(
    rp: RestorePoint,
    typedef_decl: *const clang.TypedefNameDecl,
    toplevel: bool,
    checked_name: []const u8,
) Error!?*ast.Node {
    const visib_tok = if (toplevel) try appendToken(rp.c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(rp.c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(rp.c, checked_name);
    const eq_token = try appendToken(rp.c, .Equal, "=");
    const child_qt = typedef_decl.getUnderlyingType();
    const typedef_loc = typedef_decl.getLocation();
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

fn transRecordDecl(c: *Context, record_decl: *const clang.RecordDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(record_decl.getCanonicalDecl()))) |name|
        return try transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const record_loc = record_decl.getLocation();

    var bare_name = try c.str(@ptrCast(*const clang.NamedDecl, record_decl).getName_bytes_begin());
    var is_unnamed = false;
    // Record declarations such as `struct {...} x` have no name but they're not
    // anonymous hence here isAnonymousStructOrUnion is not needed
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    var container_kind_name: []const u8 = undefined;
    var container_kind: std.zig.Token.Id = undefined;
    if (record_decl.isUnion()) {
        container_kind_name = "union";
        container_kind = .Keyword_union;
    } else if (record_decl.isStruct()) {
        container_kind_name = "struct";
        container_kind = .Keyword_struct;
    } else {
        try emitWarning(c, record_loc, "record {} is not a struct or union", .{bare_name});
        return null;
    }

    const name = try std.fmt.allocPrint(c.arena, "{}_{}", .{ container_kind_name, bare_name });
    _ = try c.decl_table.put(c.gpa, @ptrToInt(record_decl.getCanonicalDecl()), name);

    const visib_tok = if (!is_unnamed) try appendToken(c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);

    const eq_token = try appendToken(c, .Equal, "=");

    var semicolon: ast.TokenIndex = undefined;
    const init_node = blk: {
        const rp = makeRestorePoint(c);
        const record_def = record_decl.getDefinition() orelse {
            _ = try c.opaque_demotes.put(c.gpa, @ptrToInt(record_decl.getCanonicalDecl()), {});
            const opaque_type = try transCreateNodeOpaqueType(c);
            semicolon = try appendToken(c, .Semicolon, ";");
            break :blk opaque_type;
        };

        const layout_tok = try if (record_decl.getPackedAttribute())
            appendToken(c, .Keyword_packed, "packed")
        else
            appendToken(c, .Keyword_extern, "extern");
        const container_tok = try appendToken(c, container_kind, container_kind_name);
        const lbrace_token = try appendToken(c, .LBrace, "{");

        var fields_and_decls = std.ArrayList(*ast.Node).init(c.gpa);
        defer fields_and_decls.deinit();

        var unnamed_field_count: u32 = 0;
        var it = record_def.field_begin();
        const end_it = record_def.field_end();
        while (it.neq(end_it)) : (it = it.next()) {
            const field_decl = it.deref();
            const field_loc = field_decl.getLocation();
            const field_qt = field_decl.getType();

            if (field_decl.isBitField()) {
                _ = try c.opaque_demotes.put(c.gpa, @ptrToInt(record_decl.getCanonicalDecl()), {});
                const opaque_type = try transCreateNodeOpaqueType(c);
                semicolon = try appendToken(c, .Semicolon, ";");
                try emitWarning(c, field_loc, "{} demoted to opaque type - has bitfield", .{container_kind_name});
                break :blk opaque_type;
            }

            if (qualTypeCanon(field_qt).isIncompleteOrZeroLengthArrayType(c.clang_context)) {
                _ = try c.opaque_demotes.put(c.gpa, @ptrToInt(record_decl.getCanonicalDecl()), {});
                const opaque_type = try transCreateNodeOpaqueType(c);
                semicolon = try appendToken(c, .Semicolon, ";");
                try emitWarning(c, field_loc, "{} demoted to opaque type - has variable length array", .{container_kind_name});
                break :blk opaque_type;
            }

            var is_anon = false;
            var raw_name = try c.str(@ptrCast(*const clang.NamedDecl, field_decl).getName_bytes_begin());
            if (field_decl.isAnonymousStructOrUnion() or raw_name.len == 0) {
                // Context.getMangle() is not used here because doing so causes unpredictable field names for anonymous fields.
                raw_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{unnamed_field_count});
                unnamed_field_count += 1;
                is_anon = true;
            }
            const field_name = try appendIdentifier(c, raw_name);
            _ = try appendToken(c, .Colon, ":");
            const field_type = transQualType(rp, field_qt, field_loc) catch |err| switch (err) {
                error.UnsupportedType => {
                    _ = try c.opaque_demotes.put(c.gpa, @ptrToInt(record_decl.getCanonicalDecl()), {});
                    const opaque_type = try transCreateNodeOpaqueType(c);
                    semicolon = try appendToken(c, .Semicolon, ";");
                    try emitWarning(c, record_loc, "{} demoted to opaque type - unable to translate type of field {}", .{ container_kind_name, raw_name });
                    break :blk opaque_type;
                },
                else => |e| return e,
            };

            const align_expr = blk_2: {
                const alignment = field_decl.getAlignedAttribute(c.clang_context);
                if (alignment != 0) {
                    _ = try appendToken(c, .Keyword_align, "align");
                    _ = try appendToken(c, .LParen, "(");
                    // Clang reports the alignment in bits
                    const expr = try transCreateNodeInt(c, alignment / 8);
                    _ = try appendToken(c, .RParen, ")");

                    break :blk_2 expr;
                }
                break :blk_2 null;
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
                    c.gpa,
                    @ptrToInt(field_decl.getCanonicalDecl()),
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

fn transEnumDecl(c: *Context, enum_decl: *const clang.EnumDecl) Error!?*ast.Node {
    if (c.decl_table.get(@ptrToInt(enum_decl.getCanonicalDecl()))) |name|
        return try transCreateNodeIdentifier(c, name); // Avoid processing this decl twice
    const rp = makeRestorePoint(c);
    const enum_loc = enum_decl.getLocation();

    var bare_name = try c.str(@ptrCast(*const clang.NamedDecl, enum_decl).getName_bytes_begin());
    var is_unnamed = false;
    if (bare_name.len == 0) {
        bare_name = try std.fmt.allocPrint(c.arena, "unnamed_{}", .{c.getMangle()});
        is_unnamed = true;
    }

    const name = try std.fmt.allocPrint(c.arena, "enum_{}", .{bare_name});
    _ = try c.decl_table.put(c.gpa, @ptrToInt(enum_decl.getCanonicalDecl()), name);

    const visib_tok = if (!is_unnamed) try appendToken(c, .Keyword_pub, "pub") else null;
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, name);
    const eq_token = try appendToken(c, .Equal, "=");

    const init_node = if (enum_decl.getDefinition()) |enum_def| blk: {
        var pure_enum = true;
        var it = enum_def.enumerator_begin();
        var end_it = enum_def.enumerator_end();
        while (it.neq(end_it)) : (it = it.next()) {
            const enum_const = it.deref();
            if (enum_const.getInitExpr()) |_| {
                pure_enum = false;
                break;
            }
        }

        const extern_tok = try appendToken(c, .Keyword_extern, "extern");
        const container_tok = try appendToken(c, .Keyword_enum, "enum");

        var fields_and_decls = std.ArrayList(*ast.Node).init(c.gpa);
        defer fields_and_decls.deinit();

        const int_type = enum_decl.getIntegerType();
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

        it = enum_def.enumerator_begin();
        end_it = enum_def.enumerator_end();
        while (it.neq(end_it)) : (it = it.next()) {
            const enum_const = it.deref();

            const enum_val_name = try c.str(@ptrCast(*const clang.NamedDecl, enum_const).getName_bytes_begin());

            const field_name = if (!is_unnamed and mem.startsWith(u8, enum_val_name, bare_name))
                enum_val_name[bare_name.len..]
            else
                enum_val_name;

            const field_name_tok = try appendIdentifier(c, field_name);

            const int_node = if (!pure_enum) blk_2: {
                _ = try appendToken(c, .Colon, "=");
                break :blk_2 try transCreateNodeAPInt(c, enum_const.getInitVal());
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
    } else blk: {
        _ = try c.opaque_demotes.put(c.gpa, @ptrToInt(enum_decl.getCanonicalDecl()), {});
        break :blk try transCreateNodeOpaqueType(c);
    };

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
    stmt: *const clang.Stmt,
    result_used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    const sc = stmt.getStmtClass();
    switch (sc) {
        .BinaryOperatorClass => return transBinaryOperator(rp, scope, @ptrCast(*const clang.BinaryOperator, stmt), result_used),
        .CompoundStmtClass => return transCompoundStmt(rp, scope, @ptrCast(*const clang.CompoundStmt, stmt)),
        .CStyleCastExprClass => return transCStyleCastExprClass(rp, scope, @ptrCast(*const clang.CStyleCastExpr, stmt), result_used, lrvalue),
        .DeclStmtClass => return transDeclStmt(rp, scope, @ptrCast(*const clang.DeclStmt, stmt)),
        .DeclRefExprClass => return transDeclRefExpr(rp, scope, @ptrCast(*const clang.DeclRefExpr, stmt), lrvalue),
        .ImplicitCastExprClass => return transImplicitCastExpr(rp, scope, @ptrCast(*const clang.ImplicitCastExpr, stmt), result_used),
        .IntegerLiteralClass => return transIntegerLiteral(rp, scope, @ptrCast(*const clang.IntegerLiteral, stmt), result_used, .with_as),
        .ReturnStmtClass => return transReturnStmt(rp, scope, @ptrCast(*const clang.ReturnStmt, stmt)),
        .StringLiteralClass => return transStringLiteral(rp, scope, @ptrCast(*const clang.StringLiteral, stmt), result_used),
        .ParenExprClass => {
            const expr = try transExpr(rp, scope, @ptrCast(*const clang.ParenExpr, stmt).getSubExpr(), .used, lrvalue);
            if (expr.tag == .GroupedExpression) return maybeSuppressResult(rp, scope, result_used, expr);
            const node = try rp.c.arena.create(ast.Node.GroupedExpression);
            node.* = .{
                .lparen = try appendToken(rp.c, .LParen, "("),
                .expr = expr,
                .rparen = try appendToken(rp.c, .RParen, ")"),
            };
            return maybeSuppressResult(rp, scope, result_used, &node.base);
        },
        .InitListExprClass => return transInitListExpr(rp, scope, @ptrCast(*const clang.InitListExpr, stmt), result_used),
        .ImplicitValueInitExprClass => return transImplicitValueInitExpr(rp, scope, @ptrCast(*const clang.Expr, stmt), result_used),
        .IfStmtClass => return transIfStmt(rp, scope, @ptrCast(*const clang.IfStmt, stmt)),
        .WhileStmtClass => return transWhileLoop(rp, scope, @ptrCast(*const clang.WhileStmt, stmt)),
        .DoStmtClass => return transDoWhileLoop(rp, scope, @ptrCast(*const clang.DoStmt, stmt)),
        .NullStmtClass => {
            const block = try rp.c.createBlock(0);
            block.rbrace = try appendToken(rp.c, .RBrace, "}");
            return &block.base;
        },
        .ContinueStmtClass => return try transCreateNodeContinue(rp.c),
        .BreakStmtClass => return transBreak(rp, scope),
        .ForStmtClass => return transForLoop(rp, scope, @ptrCast(*const clang.ForStmt, stmt)),
        .FloatingLiteralClass => return transFloatingLiteral(rp, scope, @ptrCast(*const clang.FloatingLiteral, stmt), result_used),
        .ConditionalOperatorClass => {
            return transConditionalOperator(rp, scope, @ptrCast(*const clang.ConditionalOperator, stmt), result_used);
        },
        .BinaryConditionalOperatorClass => {
            return transBinaryConditionalOperator(rp, scope, @ptrCast(*const clang.BinaryConditionalOperator, stmt), result_used);
        },
        .SwitchStmtClass => return transSwitch(rp, scope, @ptrCast(*const clang.SwitchStmt, stmt)),
        .CaseStmtClass => return transCase(rp, scope, @ptrCast(*const clang.CaseStmt, stmt)),
        .DefaultStmtClass => return transDefault(rp, scope, @ptrCast(*const clang.DefaultStmt, stmt)),
        .ConstantExprClass => return transConstantExpr(rp, scope, @ptrCast(*const clang.Expr, stmt), result_used),
        .PredefinedExprClass => return transPredefinedExpr(rp, scope, @ptrCast(*const clang.PredefinedExpr, stmt), result_used),
        .CharacterLiteralClass => return transCharLiteral(rp, scope, @ptrCast(*const clang.CharacterLiteral, stmt), result_used, .with_as),
        .StmtExprClass => return transStmtExpr(rp, scope, @ptrCast(*const clang.StmtExpr, stmt), result_used),
        .MemberExprClass => return transMemberExpr(rp, scope, @ptrCast(*const clang.MemberExpr, stmt), result_used),
        .ArraySubscriptExprClass => return transArrayAccess(rp, scope, @ptrCast(*const clang.ArraySubscriptExpr, stmt), result_used),
        .CallExprClass => return transCallExpr(rp, scope, @ptrCast(*const clang.CallExpr, stmt), result_used),
        .UnaryExprOrTypeTraitExprClass => return transUnaryExprOrTypeTraitExpr(rp, scope, @ptrCast(*const clang.UnaryExprOrTypeTraitExpr, stmt), result_used),
        .UnaryOperatorClass => return transUnaryOperator(rp, scope, @ptrCast(*const clang.UnaryOperator, stmt), result_used),
        .CompoundAssignOperatorClass => return transCompoundAssignOperator(rp, scope, @ptrCast(*const clang.CompoundAssignOperator, stmt), result_used),
        .OpaqueValueExprClass => {
            const source_expr = @ptrCast(*const clang.OpaqueValueExpr, stmt).getSourceExpr().?;
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
                stmt.getBeginLoc(),
                "TODO implement translation of stmt class {}",
                .{@tagName(sc)},
            );
        },
    }
}

fn transBinaryOperator(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.BinaryOperator,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const op = stmt.getOpcode();
    const qt = stmt.getType();
    var op_token: ast.TokenIndex = undefined;
    var op_id: ast.Node.Tag = undefined;
    switch (op) {
        .Assign => return try transCreateNodeAssign(rp, scope, result_used, stmt.getLHS(), stmt.getRHS()),
        .Comma => {
            const block_scope = try scope.findBlockScope(rp.c);
            const expr = block_scope.base.parent == scope;
            const lparen = if (expr) try appendToken(rp.c, .LParen, "(") else undefined;

            const lhs = try transExpr(rp, &block_scope.base, stmt.getLHS(), .unused, .r_value);
            try block_scope.statements.append(lhs);

            const rhs = try transExpr(rp, &block_scope.base, stmt.getRHS(), .used, .r_value);
            if (expr) {
                _ = try appendToken(rp.c, .Semicolon, ";");
                const break_node = try transCreateNodeBreak(rp.c, block_scope.label, rhs);
                try block_scope.statements.append(&break_node.base);
                const block_node = try block_scope.complete(rp.c);
                const rparen = try appendToken(rp.c, .RParen, ")");
                const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
                grouped_expr.* = .{
                    .lparen = lparen,
                    .expr = block_node,
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
                div_trunc_node.params()[0] = try transExpr(rp, scope, stmt.getLHS(), .used, .l_value);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, stmt.getRHS(), .used, .r_value);
                div_trunc_node.params()[1] = rhs;
                div_trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");
                return maybeSuppressResult(rp, scope, result_used, &div_trunc_node.base);
            }
        },
        .Rem => {
            if (cIsSignedInteger(qt)) {
                // signed integer division uses @rem
                const rem_node = try rp.c.createBuiltinCall("@rem", 2);
                rem_node.params()[0] = try transExpr(rp, scope, stmt.getLHS(), .used, .l_value);
                _ = try appendToken(rp.c, .Comma, ",");
                const rhs = try transExpr(rp, scope, stmt.getRHS(), .used, .r_value);
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
    const lhs_node = try transExpr(rp, scope, stmt.getLHS(), .used, .l_value);
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

    const rhs_node = try transExpr(rp, scope, stmt.getRHS(), .used, .r_value);

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
    stmt: *const clang.CompoundStmt,
    block: *Scope.Block,
) TransError!void {
    var it = stmt.body_begin();
    const end_it = stmt.body_end();
    while (it != end_it) : (it += 1) {
        const result = try transStmt(rp, parent_scope, it[0], .unused, .r_value);
        try block.statements.append(result);
    }
}

fn transCompoundStmt(rp: RestorePoint, scope: *Scope, stmt: *const clang.CompoundStmt) TransError!*ast.Node {
    var block_scope = try Scope.Block.init(rp.c, scope, false);
    defer block_scope.deinit();
    try transCompoundStmtInline(rp, &block_scope.base, stmt, &block_scope);
    return try block_scope.complete(rp.c);
}

fn transCStyleCastExprClass(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.CStyleCastExpr,
    result_used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    const sub_expr = stmt.getSubExpr();
    const cast_node = (try transCCast(
        rp,
        scope,
        stmt.getBeginLoc(),
        stmt.getType(),
        sub_expr.getType(),
        try transExpr(rp, scope, sub_expr, .used, lrvalue),
    ));
    return maybeSuppressResult(rp, scope, result_used, cast_node);
}

fn transDeclStmtOne(
    rp: RestorePoint,
    scope: *Scope,
    decl: *const clang.Decl,
    block_scope: *Scope.Block,
) TransError!*ast.Node {
    const c = rp.c;

    switch (decl.getKind()) {
        .Var => {
            const var_decl = @ptrCast(*const clang.VarDecl, decl);

            const qual_type = var_decl.getTypeSourceInfo_getType();
            const name = try c.str(@ptrCast(*const clang.NamedDecl, var_decl).getName_bytes_begin());
            const mangled_name = try block_scope.makeMangledName(c, name);

            switch (var_decl.getStorageClass()) {
                .Extern, .Static => {
                    // This is actually a global variable, put it in the global scope and reference it.
                    // `_ = mangled_name;`
                    try visitVarDecl(rp.c, var_decl, mangled_name);
                    return try maybeSuppressResult(rp, scope, .unused, try transCreateNodeIdentifier(rp.c, mangled_name));
                },
                else => {},
            }

            const mut_tok = if (qual_type.isConstQualified())
                try appendToken(c, .Keyword_const, "const")
            else
                try appendToken(c, .Keyword_var, "var");
            const name_tok = try appendIdentifier(c, mangled_name);

            _ = try appendToken(c, .Colon, ":");
            const loc = decl.getLocation();
            const type_node = try transQualType(rp, qual_type, loc);

            const eq_token = try appendToken(c, .Equal, "=");
            var init_node = if (var_decl.getInit()) |expr|
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
                .eq_token = eq_token,
                .type_node = type_node,
                .init_node = init_node,
            });
            return &node.base;
        },
        .Typedef => {
            const typedef_decl = @ptrCast(*const clang.TypedefNameDecl, decl);
            const name = try c.str(@ptrCast(*const clang.NamedDecl, typedef_decl).getName_bytes_begin());

            const underlying_qual = typedef_decl.getUnderlyingType();
            const underlying_type = underlying_qual.getTypePtr();

            const mangled_name = try block_scope.makeMangledName(c, name);
            const node = (try transCreateNodeTypedef(rp, typedef_decl, false, mangled_name)) orelse
                return error.UnsupportedTranslation;
            return node;
        },
        else => |kind| return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            decl.getLocation(),
            "TODO implement translation of DeclStmt kind {}",
            .{@tagName(kind)},
        ),
    }
}

fn transDeclStmt(rp: RestorePoint, scope: *Scope, stmt: *const clang.DeclStmt) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;

    var it = stmt.decl_begin();
    const end_it = stmt.decl_end();
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
    expr: *const clang.DeclRefExpr,
    lrvalue: LRValue,
) TransError!*ast.Node {
    const value_decl = expr.getDecl();
    const name = try rp.c.str(@ptrCast(*const clang.NamedDecl, value_decl).getName_bytes_begin());
    const mangled_name = scope.getAlias(name);
    return transCreateNodeIdentifier(rp.c, mangled_name);
}

fn transImplicitCastExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.ImplicitCastExpr,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const c = rp.c;
    const sub_expr = expr.getSubExpr();
    const dest_type = getExprQualType(c, @ptrCast(*const clang.Expr, expr));
    const src_type = getExprQualType(c, sub_expr);
    switch (expr.getCastKind()) {
        .BitCast, .FloatingCast, .FloatingToIntegral, .IntegralToFloating, .IntegralCast, .PointerToIntegral, .IntegralToPointer => {
            const sub_expr_node = try transExpr(rp, scope, sub_expr, .used, .r_value);
            return try transCCast(rp, scope, expr.getBeginLoc(), dest_type, src_type, sub_expr_node);
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
        .BuiltinFnToFnPtr => {
            return transExpr(rp, scope, sub_expr, .used, .r_value);
        },
        else => |kind| return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            @ptrCast(*const clang.Stmt, expr).getBeginLoc(),
            "TODO implement translation of CastKind {}",
            .{@tagName(kind)},
        ),
    }
}

fn transBoolExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.Expr,
    used: ResultUsed,
    lrvalue: LRValue,
    grouped: bool,
) TransError!*ast.Node {
    if (@ptrCast(*const clang.Stmt, expr).getStmtClass() == .IntegerLiteralClass) {
        var is_zero: bool = undefined;
        if (!(@ptrCast(*const clang.IntegerLiteral, expr).isZero(&is_zero, rp.c.clang_context))) {
            return revertAndWarn(rp, error.UnsupportedTranslation, expr.getBeginLoc(), "invalid integer literal", .{});
        }
        return try transCreateNodeBoolLiteral(rp.c, !is_zero);
    }

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

    const ty = getExprQualType(rp.c, expr).getTypePtr();
    const node = try finishBoolExpr(rp, scope, expr.getBeginLoc(), ty, res, used);

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

fn exprIsBooleanType(expr: *const clang.Expr) bool {
    return qualTypeIsBoolean(expr.getType());
}

fn exprIsStringLiteral(expr: *const clang.Expr) bool {
    switch (expr.getStmtClass()) {
        .StringLiteralClass => return true,
        .PredefinedExprClass => return true,
        .UnaryOperatorClass => {
            const op_expr = @ptrCast(*const clang.UnaryOperator, expr).getSubExpr();
            return exprIsStringLiteral(op_expr);
        },
        .ParenExprClass => {
            const op_expr = @ptrCast(*const clang.ParenExpr, expr).getSubExpr();
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
    loc: clang.SourceLocation,
    ty: *const clang.Type,
    node: *ast.Node,
    used: ResultUsed,
) TransError!*ast.Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);

            switch (builtin_ty.getKind()) {
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
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);
            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return finishBoolExpr(rp, scope, loc, underlying_type.getTypePtr(), node, used);
        },
        .Enum => {
            const op_token = try appendToken(rp.c, .BangEqual, "!=");
            const rhs_node = try transCreateNodeInt(rp.c, 0);
            return transCreateNodeInfixOp(rp, scope, node, .BangEqual, op_token, rhs_node, used, false);
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const clang.ElaboratedType, ty);
            const named_type = elaborated_ty.getNamedType();
            return finishBoolExpr(rp, scope, loc, named_type.getTypePtr(), node, used);
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
    expr: *const clang.IntegerLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!*ast.Node {
    var eval_result: clang.ExprEvalResult = undefined;
    if (!expr.EvaluateAsInt(&eval_result, rp.c.clang_context)) {
        const loc = expr.getBeginLoc();
        return revertAndWarn(rp, error.UnsupportedTranslation, loc, "invalid integer literal", .{});
    }

    if (suppress_as == .no_as) {
        const int_lit_node = try transCreateNodeAPInt(rp.c, eval_result.Val.getInt());
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
    const expr_base = @ptrCast(*const clang.Expr, expr);
    const as_node = try rp.c.createBuiltinCall("@as", 2);
    const ty_node = try transQualType(rp, expr_base.getType(), expr_base.getBeginLoc());
    as_node.params()[0] = ty_node;
    _ = try appendToken(rp.c, .Comma, ",");
    as_node.params()[1] = try transCreateNodeAPInt(rp.c, eval_result.Val.getInt());

    as_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &as_node.base);
}

fn transReturnStmt(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.ReturnStmt,
) TransError!*ast.Node {
    const return_kw = try appendToken(rp.c, .Keyword_return, "return");
    const rhs: ?*ast.Node = if (expr.getRetValue()) |val_expr|
        try transExprCoercing(rp, scope, val_expr, .used, .r_value)
    else
        null;
    const return_expr = try ast.Node.ControlFlowExpression.create(rp.c.arena, .{
        .ltoken = return_kw,
        .tag = .Return,
    }, .{
        .rhs = rhs,
    });
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &return_expr.base;
}

fn transStringLiteral(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.StringLiteral,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const kind = stmt.getKind();
    switch (kind) {
        .Ascii, .UTF8 => {
            var len: usize = undefined;
            const bytes_ptr = stmt.getString_bytes_begin_size(&len);
            const str = bytes_ptr[0..len];

            const token = try appendTokenFmt(rp.c, .StringLiteral, "\"{Z}\"", .{str});
            const node = try rp.c.arena.create(ast.Node.OneToken);
            node.* = .{
                .base = .{ .tag = .StringLiteral },
                .token = token,
            };
            return maybeSuppressResult(rp, scope, result_used, &node.base);
        },
        .UTF16, .UTF32, .Wide => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            @ptrCast(*const clang.Stmt, stmt).getBeginLoc(),
            "TODO: support string literal kind {}",
            .{kind},
        ),
    }
}

fn cIsEnum(qt: clang.QualType) bool {
    return qt.getCanonicalType().getTypeClass() == .Enum;
}

/// Get the underlying int type of an enum. The C compiler chooses a signed int
/// type that is large enough to hold all of the enum's values. It is not required
/// to be the smallest possible type that can hold all the values.
fn cIntTypeForEnum(enum_qt: clang.QualType) clang.QualType {
    assert(cIsEnum(enum_qt));
    const ty = enum_qt.getCanonicalType().getTypePtr();
    const enum_ty = @ptrCast(*const clang.EnumType, ty);
    const enum_decl = enum_ty.getDecl();
    return enum_decl.getIntegerType();
}

fn transCCast(
    rp: RestorePoint,
    scope: *Scope,
    loc: clang.SourceLocation,
    dst_type: clang.QualType,
    src_type: clang.QualType,
    expr: *ast.Node,
) !*ast.Node {
    if (qualTypeCanon(dst_type).isVoidType()) return expr;
    if (dst_type.eq(src_type)) return expr;
    if (qualTypeIsPtr(dst_type) and qualTypeIsPtr(src_type))
        return transCPtrCast(rp, loc, dst_type, src_type, expr);
    if (cIsInteger(dst_type) and (cIsInteger(src_type) or cIsEnum(src_type))) {
        // 1. If src_type is an enum, determine the underlying signed int type
        // 2. Extend or truncate without changing signed-ness.
        // 3. Bit-cast to correct signed-ness
        const src_type_is_signed = cIsSignedInteger(src_type) or cIsEnum(src_type);
        const src_int_type = if (cIsInteger(src_type)) src_type else cIntTypeForEnum(src_type);
        const src_int_expr = if (cIsInteger(src_type)) expr else try transEnumToInt(rp.c, expr);

        // @bitCast(dest_type, intermediate_value)
        const cast_node = try rp.c.createBuiltinCall("@bitCast", 2);
        cast_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");

        switch (cIntTypeCmp(dst_type, src_int_type)) {
            .lt => {
                // @truncate(SameSignSmallerInt, src_int_expr)
                const trunc_node = try rp.c.createBuiltinCall("@truncate", 2);
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, src_type_is_signed);
                trunc_node.params()[0] = ty_node;
                _ = try appendToken(rp.c, .Comma, ",");
                trunc_node.params()[1] = src_int_expr;
                trunc_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                cast_node.params()[1] = &trunc_node.base;
            },
            .gt => {
                // @as(SameSignBiggerInt, src_int_expr)
                const as_node = try rp.c.createBuiltinCall("@as", 2);
                const ty_node = try transQualTypeIntWidthOf(rp.c, dst_type, src_type_is_signed);
                as_node.params()[0] = ty_node;
                _ = try appendToken(rp.c, .Comma, ",");
                as_node.params()[1] = src_int_expr;
                as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

                cast_node.params()[1] = &as_node.base;
            },
            .eq => {
                cast_node.params()[1] = src_int_expr;
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
    if (qualTypeIsBoolean(src_type) and !qualTypeIsBoolean(dst_type)) {
        // @boolToInt returns either a comptime_int or a u1
        // TODO: if dst_type is 1 bit & signed (bitfield) we need @bitCast
        // instead of @as

        const builtin_node = try rp.c.createBuiltinCall("@boolToInt", 1);
        builtin_node.params()[0] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        const as_node = try rp.c.createBuiltinCall("@as", 2);
        as_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        as_node.params()[1] = &builtin_node.base;
        as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

        return &as_node.base;
    }
    if (cIsEnum(dst_type)) {
        const builtin_node = try rp.c.createBuiltinCall("@intToEnum", 2);
        builtin_node.params()[0] = try transQualType(rp, dst_type, loc);
        _ = try appendToken(rp.c, .Comma, ",");
        builtin_node.params()[1] = expr;
        builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
        return &builtin_node.base;
    }
    if (cIsEnum(src_type) and !cIsEnum(dst_type)) {
        return transEnumToInt(rp.c, expr);
    }
    const cast_node = try rp.c.createBuiltinCall("@as", 2);
    cast_node.params()[0] = try transQualType(rp, dst_type, loc);
    _ = try appendToken(rp.c, .Comma, ",");
    cast_node.params()[1] = expr;
    cast_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return &cast_node.base;
}

fn transEnumToInt(c: *Context, enum_expr: *ast.Node) TypeError!*ast.Node {
    const builtin_node = try c.createBuiltinCall("@enumToInt", 1);
    builtin_node.params()[0] = enum_expr;
    builtin_node.rparen_token = try appendToken(c, .RParen, ")");
    return &builtin_node.base;
}

fn transExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.Expr,
    used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    return transStmt(rp, scope, @ptrCast(*const clang.Stmt, expr), used, lrvalue);
}

/// Same as `transExpr` but with the knowledge that the operand will be type coerced, and therefore
/// an `@as` would be redundant. This is used to prevent redundant `@as` in integer literals.
fn transExprCoercing(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.Expr,
    used: ResultUsed,
    lrvalue: LRValue,
) TransError!*ast.Node {
    switch (@ptrCast(*const clang.Stmt, expr).getStmtClass()) {
        .IntegerLiteralClass => {
            return transIntegerLiteral(rp, scope, @ptrCast(*const clang.IntegerLiteral, expr), .used, .no_as);
        },
        .CharacterLiteralClass => {
            return transCharLiteral(rp, scope, @ptrCast(*const clang.CharacterLiteral, expr), .used, .no_as);
        },
        .UnaryOperatorClass => {
            const un_expr = @ptrCast(*const clang.UnaryOperator, expr);
            if (un_expr.getOpcode() == .Extension) {
                return transExprCoercing(rp, scope, un_expr.getSubExpr(), used, lrvalue);
            }
        },
        else => {},
    }
    return transExpr(rp, scope, expr, .used, .r_value);
}

fn transInitListExprRecord(
    rp: RestorePoint,
    scope: *Scope,
    loc: clang.SourceLocation,
    expr: *const clang.InitListExpr,
    ty: *const clang.Type,
    used: ResultUsed,
) TransError!*ast.Node {
    var is_union_type = false;
    // Unions and Structs are both represented as RecordDecl
    const record_ty = ty.getAsRecordType() orelse
        blk: {
        is_union_type = true;
        break :blk ty.getAsUnionType();
    } orelse unreachable;
    const record_decl = record_ty.getDecl();
    const record_def = record_decl.getDefinition() orelse
        unreachable;

    const ty_node = try transType(rp, ty, loc);
    const init_count = expr.getNumInits();
    var field_inits = std.ArrayList(*ast.Node).init(rp.c.gpa);
    defer field_inits.deinit();

    _ = try appendToken(rp.c, .LBrace, "{");

    var init_i: c_uint = 0;
    var it = record_def.field_begin();
    const end_it = record_def.field_end();
    while (it.neq(end_it)) : (it = it.next()) {
        const field_decl = it.deref();

        // The initializer for a union type has a single entry only
        if (is_union_type and field_decl != expr.getInitializedFieldInUnion()) {
            continue;
        }

        assert(init_i < init_count);
        const elem_expr = expr.getInit(init_i);
        init_i += 1;

        // Generate the field assignment expression:
        //     .field_name = expr
        const period_tok = try appendToken(rp.c, .Period, ".");

        var raw_name = try rp.c.str(@ptrCast(*const clang.NamedDecl, field_decl).getName_bytes_begin());
        if (field_decl.isAnonymousStructOrUnion()) {
            const name = rp.c.decl_table.get(@ptrToInt(field_decl.getCanonicalDecl())).?;
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
    source_loc: clang.SourceLocation,
    ty: *const clang.Type,
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
    loc: clang.SourceLocation,
    expr: *const clang.InitListExpr,
    ty: *const clang.Type,
    used: ResultUsed,
) TransError!*ast.Node {
    const arr_type = ty.getAsArrayTypeUnsafe();
    const child_qt = arr_type.getElementType();
    const init_count = expr.getNumInits();
    assert(@ptrCast(*const clang.Type, arr_type).isConstantArrayType());
    const const_arr_ty = @ptrCast(*const clang.ConstantArrayType, arr_type);
    const size_ap_int = const_arr_ty.getSize();
    const all_count = size_ap_int.getLimitedValue(math.maxInt(usize));
    const leftover_count = all_count - init_count;

    var init_node: *ast.Node.ArrayInitializer = undefined;
    var cat_tok: ast.TokenIndex = undefined;
    if (init_count != 0) {
        const ty_node = try transCreateNodeArrayType(
            rp,
            loc,
            child_qt.getTypePtr(),
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
            const elem_expr = expr.getInit(i);
            init_list[i] = try transExpr(rp, scope, elem_expr, .used, .r_value);
            _ = try appendToken(rp.c, .Comma, ",");
        }
        init_node.rtoken = try appendToken(rp.c, .RBrace, "}");
        if (leftover_count == 0) {
            return &init_node.base;
        }
        cat_tok = try appendToken(rp.c, .PlusPlus, "++");
    }

    const ty_node = try transCreateNodeArrayType(rp, loc, child_qt.getTypePtr(), 1);
    _ = try appendToken(rp.c, .LBrace, "{");
    const filler_init_node = try ast.Node.ArrayInitializer.alloc(rp.c.arena, 1);
    filler_init_node.* = .{
        .lhs = ty_node,
        .rtoken = undefined,
        .list_len = 1,
    };
    const filler_val_expr = expr.getArrayFiller();
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
    expr: *const clang.InitListExpr,
    used: ResultUsed,
) TransError!*ast.Node {
    const qt = getExprQualType(rp.c, @ptrCast(*const clang.Expr, expr));
    var qual_type = qt.getTypePtr();
    const source_loc = @ptrCast(*const clang.Expr, expr).getBeginLoc();

    if (qual_type.isRecordType()) {
        return transInitListExprRecord(
            rp,
            scope,
            source_loc,
            expr,
            qual_type,
            used,
        );
    } else if (qual_type.isArrayType()) {
        return transInitListExprArray(
            rp,
            scope,
            source_loc,
            expr,
            qual_type,
            used,
        );
    } else {
        const type_name = rp.c.str(qual_type.getTypeClassName());
        return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported initlist type: '{}'", .{type_name});
    }
}

fn transZeroInitExpr(
    rp: RestorePoint,
    scope: *Scope,
    source_loc: clang.SourceLocation,
    ty: *const clang.Type,
) TransError!*ast.Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);
            switch (builtin_ty.getKind()) {
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
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);
            const typedef_decl = typedef_ty.getDecl();
            return transZeroInitExpr(
                rp,
                scope,
                source_loc,
                typedef_decl.getUnderlyingType().getTypePtr(),
            );
        },
        else => {},
    }

    return revertAndWarn(rp, error.UnsupportedType, source_loc, "type does not have an implicit init value", .{});
}

fn transImplicitValueInitExpr(
    rp: RestorePoint,
    scope: *Scope,
    expr: *const clang.Expr,
    used: ResultUsed,
) TransError!*ast.Node {
    const source_loc = expr.getBeginLoc();
    const qt = getExprQualType(rp.c, expr);
    const ty = qt.getTypePtr();
    return transZeroInitExpr(rp, scope, source_loc, ty);
}

fn transIfStmt(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.IfStmt,
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
    const cond_expr = @ptrCast(*const clang.Expr, stmt.getCond());
    if_node.condition = try transBoolExpr(rp, &cond_scope.base, cond_expr, .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transStmt(rp, scope, stmt.getThen(), .unused, .r_value);

    if (stmt.getElse()) |expr| {
        if_node.@"else" = try transCreateNodeElse(rp.c);
        if_node.@"else".?.body = try transStmt(rp, scope, expr, .unused, .r_value);
    }
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &if_node.base;
}

fn transWhileLoop(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.WhileStmt,
) TransError!*ast.Node {
    const while_node = try transCreateNodeWhile(rp.c);

    var cond_scope = Scope.Condition{
        .base = .{
            .parent = scope,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const cond_expr = @ptrCast(*const clang.Expr, stmt.getCond());
    while_node.condition = try transBoolExpr(rp, &cond_scope.base, cond_expr, .used, .r_value, false);
    _ = try appendToken(rp.c, .RParen, ")");

    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };
    while_node.body = try transStmt(rp, &loop_scope, stmt.getBody(), .unused, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &while_node.base;
}

fn transDoWhileLoop(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.DoStmt,
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
    prefix_op.rhs = try transBoolExpr(rp, &cond_scope.base, @ptrCast(*const clang.Expr, stmt.getCond()), .used, .r_value, true);
    _ = try appendToken(rp.c, .RParen, ")");
    if_node.condition = &prefix_op.base;
    if_node.body = &(try transCreateNodeBreak(rp.c, null, null)).base;
    _ = try appendToken(rp.c, .Semicolon, ";");

    const body_node = if (stmt.getBody().getStmtClass() == .CompoundStmtClass) blk: {
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
        const node = try transStmt(rp, &loop_scope, stmt.getBody(), .unused, .r_value);
        break :blk node.castTag(.Block).?;
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
        const block = try rp.c.createBlock(2);
        block.statements_len = 1; // over-allocated so we can add another below
        block.statements()[0] = try transStmt(rp, &loop_scope, stmt.getBody(), .unused, .r_value);
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
    stmt: *const clang.ForStmt,
) TransError!*ast.Node {
    var loop_scope = Scope{
        .parent = scope,
        .id = .Loop,
    };

    var block_scope: ?Scope.Block = null;
    defer if (block_scope) |*bs| bs.deinit();

    if (stmt.getInit()) |init| {
        block_scope = try Scope.Block.init(rp.c, scope, false);
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
    while_node.condition = if (stmt.getCond()) |cond|
        try transBoolExpr(rp, &cond_scope.base, cond, .used, .r_value, false)
    else
        try transCreateNodeBoolLiteral(rp.c, true);
    _ = try appendToken(rp.c, .RParen, ")");

    if (stmt.getInc()) |incr| {
        _ = try appendToken(rp.c, .Colon, ":");
        _ = try appendToken(rp.c, .LParen, "(");
        while_node.continue_expr = try transExpr(rp, &cond_scope.base, incr, .unused, .r_value);
        _ = try appendToken(rp.c, .RParen, ")");
    }

    while_node.body = try transStmt(rp, &loop_scope, stmt.getBody(), .unused, .r_value);
    if (block_scope) |*bs| {
        try bs.statements.append(&while_node.base);
        return try bs.complete(rp.c);
    } else {
        _ = try appendToken(rp.c, .Semicolon, ";");
        return &while_node.base;
    }
}

fn getSwitchCaseCount(stmt: *const clang.SwitchStmt) usize {
    const body = stmt.getBody();
    assert(body.getStmtClass() == .CompoundStmtClass);
    const comp = @ptrCast(*const clang.CompoundStmt, body);
    // TODO https://github.com/ziglang/zig/issues/1738
    // return comp.body_end() - comp.body_begin();
    const start_addr = @ptrToInt(comp.body_begin());
    const end_addr = @ptrToInt(comp.body_end());
    return (end_addr - start_addr) / @sizeOf(*clang.Stmt);
}

fn transSwitch(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.SwitchStmt,
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
    const switch_expr = try transExpr(rp, &cond_scope.base, stmt.getCond(), .used, .r_value);
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
        .default_label = null,
        .switch_label = null,
    };

    // tmp block that all statements will go before being picked up by a case or default
    var block_scope = try Scope.Block.init(rp.c, &switch_scope.base, false);
    defer block_scope.deinit();

    // Note that we do not defer a deinit here; the switch_scope.pending_block field
    // has its own memory management. This resource is freed inside `transCase` and
    // then the final pending_block is freed at the bottom of this function with
    // pending_block.deinit().
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, false);
    try switch_scope.pending_block.statements.append(&switch_node.base);

    const last = try transStmt(rp, &block_scope.base, stmt.getBody(), .unused, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    // take all pending statements
    const last_block_stmts = last.cast(ast.Node.Block).?.statements();
    try switch_scope.pending_block.statements.ensureCapacity(
        switch_scope.pending_block.statements.items.len + last_block_stmts.len,
    );
    for (last_block_stmts) |n| {
        switch_scope.pending_block.statements.appendAssumeCapacity(n);
    }

    if (switch_scope.default_label == null) {
        switch_scope.switch_label = try block_scope.makeMangledName(rp.c, "switch");
    }
    if (switch_scope.switch_label) |l| {
        switch_scope.pending_block.label = try appendIdentifier(rp.c, l);
        _ = try appendToken(rp.c, .Colon, ":");
    }
    if (switch_scope.default_label == null) {
        const else_prong = try transCreateNodeSwitchCase(rp.c, try transCreateNodeSwitchElse(rp.c));
        else_prong.expr = blk: {
            var br = try CtrlFlow.init(rp.c, .Break, switch_scope.switch_label.?);
            break :blk &(try br.finish(null)).base;
        };
        _ = try appendToken(rp.c, .Comma, ",");

        if (switch_scope.case_index >= switch_scope.cases.len)
            return revertAndWarn(rp, error.UnsupportedTranslation, @ptrCast(*const clang.Stmt, stmt).getBeginLoc(), "TODO complex switch cases", .{});
        switch_scope.cases[switch_scope.case_index] = &else_prong.base;
        switch_scope.case_index += 1;
    }
    // We overallocated in case there was no default, so now we correct
    // the number of cases in the AST node.
    switch_node.cases_len = switch_scope.case_index;

    const result_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    return result_node;
}

fn transCase(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.CaseStmt,
) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;
    const switch_scope = scope.getSwitch();
    const label = try block_scope.makeMangledName(rp.c, "case");
    _ = try appendToken(rp.c, .Semicolon, ";");

    const expr = if (stmt.getRHS()) |rhs| blk: {
        const lhs_node = try transExpr(rp, scope, stmt.getLHS(), .used, .r_value);
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
        try transExpr(rp, scope, stmt.getLHS(), .used, .r_value);

    const switch_prong = try transCreateNodeSwitchCase(rp.c, expr);
    switch_prong.expr = blk: {
        var br = try CtrlFlow.init(rp.c, .Break, label);
        break :blk &(try br.finish(null)).base;
    };
    _ = try appendToken(rp.c, .Comma, ",");

    if (switch_scope.case_index >= switch_scope.cases.len)
        return revertAndWarn(rp, error.UnsupportedTranslation, @ptrCast(*const clang.Stmt, stmt).getBeginLoc(), "TODO complex switch cases", .{});
    switch_scope.cases[switch_scope.case_index] = &switch_prong.base;
    switch_scope.case_index += 1;

    switch_scope.pending_block.label = try appendIdentifier(rp.c, label);
    _ = try appendToken(rp.c, .Colon, ":");

    // take all pending statements
    try switch_scope.pending_block.statements.appendSlice(block_scope.statements.items);
    block_scope.statements.shrink(0);

    const pending_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, false);

    try switch_scope.pending_block.statements.append(pending_node);

    return transStmt(rp, scope, stmt.getSubStmt(), .unused, .r_value);
}

fn transDefault(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.DefaultStmt,
) TransError!*ast.Node {
    const block_scope = scope.findBlockScope(rp.c) catch unreachable;
    const switch_scope = scope.getSwitch();
    switch_scope.default_label = try block_scope.makeMangledName(rp.c, "default");
    _ = try appendToken(rp.c, .Semicolon, ";");

    const else_prong = try transCreateNodeSwitchCase(rp.c, try transCreateNodeSwitchElse(rp.c));
    else_prong.expr = blk: {
        var br = try CtrlFlow.init(rp.c, .Break, switch_scope.default_label.?);
        break :blk &(try br.finish(null)).base;
    };
    _ = try appendToken(rp.c, .Comma, ",");

    if (switch_scope.case_index >= switch_scope.cases.len)
        return revertAndWarn(rp, error.UnsupportedTranslation, @ptrCast(*const clang.Stmt, stmt).getBeginLoc(), "TODO complex switch cases", .{});
    switch_scope.cases[switch_scope.case_index] = &else_prong.base;
    switch_scope.case_index += 1;

    switch_scope.pending_block.label = try appendIdentifier(rp.c, switch_scope.default_label.?);
    _ = try appendToken(rp.c, .Colon, ":");

    // take all pending statements
    try switch_scope.pending_block.statements.appendSlice(block_scope.statements.items);
    block_scope.statements.shrink(0);

    const pending_node = try switch_scope.pending_block.complete(rp.c);
    switch_scope.pending_block.deinit();
    switch_scope.pending_block = try Scope.Block.init(rp.c, scope, false);
    try switch_scope.pending_block.statements.append(pending_node);

    return transStmt(rp, scope, stmt.getSubStmt(), .unused, .r_value);
}

fn transConstantExpr(rp: RestorePoint, scope: *Scope, expr: *const clang.Expr, used: ResultUsed) TransError!*ast.Node {
    var result: clang.ExprEvalResult = undefined;
    if (!expr.EvaluateAsConstantExpr(&result, .EvaluateForCodeGen, rp.c.clang_context))
        return revertAndWarn(rp, error.UnsupportedTranslation, expr.getBeginLoc(), "invalid constant expression", .{});

    var val_node: ?*ast.Node = null;
    switch (result.Val.getKind()) {
        .Int => {
            // See comment in `transIntegerLiteral` for why this code is here.
            // @as(T, x)
            const expr_base = @ptrCast(*const clang.Expr, expr);
            const as_node = try rp.c.createBuiltinCall("@as", 2);
            const ty_node = try transQualType(rp, expr_base.getType(), expr_base.getBeginLoc());
            as_node.params()[0] = ty_node;
            _ = try appendToken(rp.c, .Comma, ",");

            const int_lit_node = try transCreateNodeAPInt(rp.c, result.Val.getInt());
            as_node.params()[1] = int_lit_node;

            as_node.rparen_token = try appendToken(rp.c, .RParen, ")");

            return maybeSuppressResult(rp, scope, used, &as_node.base);
        },
        else => {
            return revertAndWarn(rp, error.UnsupportedTranslation, expr.getBeginLoc(), "unsupported constant expression kind", .{});
        },
    }
}

fn transPredefinedExpr(rp: RestorePoint, scope: *Scope, expr: *const clang.PredefinedExpr, used: ResultUsed) TransError!*ast.Node {
    return transStringLiteral(rp, scope, expr.getFunctionName(), used);
}

fn transCharLiteral(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.CharacterLiteral,
    result_used: ResultUsed,
    suppress_as: SuppressCast,
) TransError!*ast.Node {
    const kind = stmt.getKind();
    const int_lit_node = switch (kind) {
        .Ascii, .UTF8 => blk: {
            const val = stmt.getValue();
            if (kind == .Ascii) {
                // C has a somewhat obscure feature called multi-character character
                // constant
                if (val > 255)
                    break :blk try transCreateNodeInt(rp.c, val);
            }
            const token = try appendTokenFmt(rp.c, .CharLiteral, "'{Z}'", .{@intCast(u8, val)});
            const node = try rp.c.arena.create(ast.Node.OneToken);
            node.* = .{
                .base = .{ .tag = .CharLiteral },
                .token = token,
            };
            break :blk &node.base;
        },
        .UTF16, .UTF32, .Wide => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            @ptrCast(*const clang.Stmt, stmt).getBeginLoc(),
            "TODO: support character literal kind {}",
            .{kind},
        ),
    };
    if (suppress_as == .no_as) {
        return maybeSuppressResult(rp, scope, result_used, int_lit_node);
    }
    // See comment in `transIntegerLiteral` for why this code is here.
    // @as(T, x)
    const expr_base = @ptrCast(*const clang.Expr, stmt);
    const as_node = try rp.c.createBuiltinCall("@as", 2);
    const ty_node = try transQualType(rp, expr_base.getType(), expr_base.getBeginLoc());
    as_node.params()[0] = ty_node;
    _ = try appendToken(rp.c, .Comma, ",");
    as_node.params()[1] = int_lit_node;

    as_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &as_node.base);
}

fn transStmtExpr(rp: RestorePoint, scope: *Scope, stmt: *const clang.StmtExpr, used: ResultUsed) TransError!*ast.Node {
    const comp = stmt.getSubStmt();
    if (used == .unused) {
        return transCompoundStmt(rp, scope, comp);
    }
    const lparen = try appendToken(rp.c, .LParen, "(");
    var block_scope = try Scope.Block.init(rp.c, scope, true);
    defer block_scope.deinit();

    var it = comp.body_begin();
    const end_it = comp.body_end();
    while (it != end_it - 1) : (it += 1) {
        const result = try transStmt(rp, &block_scope.base, it[0], .unused, .r_value);
        try block_scope.statements.append(result);
    }
    const break_node = blk: {
        var tmp = try CtrlFlow.init(rp.c, .Break, "blk");
        const rhs = try transStmt(rp, &block_scope.base, it[0], .used, .r_value);
        break :blk try tmp.finish(rhs);
    };
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    const rparen = try appendToken(rp.c, .RParen, ")");
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = block_node,
        .rparen = rparen,
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transMemberExpr(rp: RestorePoint, scope: *Scope, stmt: *const clang.MemberExpr, result_used: ResultUsed) TransError!*ast.Node {
    var container_node = try transExpr(rp, scope, stmt.getBase(), .used, .r_value);

    if (stmt.isArrow()) {
        container_node = try transCreateNodePtrDeref(rp.c, container_node);
    }

    const member_decl = stmt.getMemberDecl();
    const name = blk: {
        const decl_kind = @ptrCast(*const clang.Decl, member_decl).getKind();
        // If we're referring to a anonymous struct/enum find the bogus name
        // we've assigned to it during the RecordDecl translation
        if (decl_kind == .Field) {
            const field_decl = @ptrCast(*const clang.FieldDecl, member_decl);
            if (field_decl.isAnonymousStructOrUnion()) {
                const name = rp.c.decl_table.get(@ptrToInt(field_decl.getCanonicalDecl())).?;
                break :blk try mem.dupe(rp.c.arena, u8, name);
            }
        }
        const decl = @ptrCast(*const clang.NamedDecl, member_decl);
        break :blk try rp.c.str(decl.getName_bytes_begin());
    };

    const node = try transCreateNodeFieldAccess(rp.c, container_node, name);
    return maybeSuppressResult(rp, scope, result_used, node);
}

fn transArrayAccess(rp: RestorePoint, scope: *Scope, stmt: *const clang.ArraySubscriptExpr, result_used: ResultUsed) TransError!*ast.Node {
    var base_stmt = stmt.getBase();

    // Unwrap the base statement if it's an array decayed to a bare pointer type
    // so that we index the array itself
    if (@ptrCast(*const clang.Stmt, base_stmt).getStmtClass() == .ImplicitCastExprClass) {
        const implicit_cast = @ptrCast(*const clang.ImplicitCastExpr, base_stmt);

        if (implicit_cast.getCastKind() == .ArrayToPointerDecay) {
            base_stmt = implicit_cast.getSubExpr();
        }
    }

    const container_node = try transExpr(rp, scope, base_stmt, .used, .r_value);
    const node = try transCreateNodeArrayAccess(rp.c, container_node);

    // cast if the index is long long or signed
    const subscr_expr = stmt.getIdx();
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

fn transCallExpr(rp: RestorePoint, scope: *Scope, stmt: *const clang.CallExpr, result_used: ResultUsed) TransError!*ast.Node {
    const callee = stmt.getCallee();
    var raw_fn_expr = try transExpr(rp, scope, callee, .used, .r_value);

    var is_ptr = false;
    const fn_ty = qualTypeGetFnProto(callee.getType(), &is_ptr);

    const fn_expr = if (is_ptr and fn_ty != null) blk: {
        if (callee.getStmtClass() == .ImplicitCastExprClass) {
            const implicit_cast = @ptrCast(*const clang.ImplicitCastExpr, callee);
            const cast_kind = implicit_cast.getCastKind();
            if (cast_kind == .BuiltinFnToFnPtr) break :blk raw_fn_expr;
            if (cast_kind == .FunctionToPointerDecay) {
                const subexpr = implicit_cast.getSubExpr();
                if (subexpr.getStmtClass() == .DeclRefExprClass) {
                    const decl_ref = @ptrCast(*const clang.DeclRefExpr, subexpr);
                    const named_decl = decl_ref.getFoundDecl();
                    if (@ptrCast(*const clang.Decl, named_decl).getKind() == .Function) {
                        break :blk raw_fn_expr;
                    }
                }
            }
        }
        break :blk try transCreateNodeUnwrapNull(rp.c, raw_fn_expr);
    } else
        raw_fn_expr;

    const num_args = stmt.getNumArgs();
    const node = try rp.c.createCall(fn_expr, num_args);
    const call_params = node.params();

    const args = stmt.getArgs();
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        if (i != 0) {
            _ = try appendToken(rp.c, .Comma, ",");
        }
        call_params[i] = try transExpr(rp, scope, args[i], .used, .r_value);
    }
    node.rtoken = try appendToken(rp.c, .RParen, ")");

    if (fn_ty) |ty| {
        const canon = ty.getReturnType().getCanonicalType();
        const ret_ty = canon.getTypePtr();
        if (ret_ty.isVoidType()) {
            _ = try appendToken(rp.c, .Semicolon, ";");
            return &node.base;
        }
    }

    return maybeSuppressResult(rp, scope, result_used, &node.base);
}

const ClangFunctionType = union(enum) {
    Proto: *const clang.FunctionProtoType,
    NoProto: *const clang.FunctionType,

    fn getReturnType(self: @This()) clang.QualType {
        switch (@as(@TagType(@This()), self)) {
            .Proto => return self.Proto.getReturnType(),
            .NoProto => return self.NoProto.getReturnType(),
        }
    }
};

fn qualTypeGetFnProto(qt: clang.QualType, is_ptr: *bool) ?ClangFunctionType {
    const canon = qt.getCanonicalType();
    var ty = canon.getTypePtr();
    is_ptr.* = false;

    if (ty.getTypeClass() == .Pointer) {
        is_ptr.* = true;
        const child_qt = ty.getPointeeType();
        ty = child_qt.getTypePtr();
    }
    if (ty.getTypeClass() == .FunctionProto) {
        return ClangFunctionType{ .Proto = @ptrCast(*const clang.FunctionProtoType, ty) };
    }
    if (ty.getTypeClass() == .FunctionNoProto) {
        return ClangFunctionType{ .NoProto = @ptrCast(*const clang.FunctionType, ty) };
    }
    return null;
}

fn transUnaryExprOrTypeTraitExpr(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.UnaryExprOrTypeTraitExpr,
    result_used: ResultUsed,
) TransError!*ast.Node {
    const loc = stmt.getBeginLoc();
    const type_node = try transQualType(
        rp,
        stmt.getTypeOfArgument(),
        loc,
    );

    const kind = stmt.getKind();
    const kind_str = switch (kind) {
        .SizeOf => "@sizeOf",
        .AlignOf => "@alignOf",
        .PreferredAlignOf,
        .VecStep,
        .OpenMPRequiredSimdAlign,
        => return revertAndWarn(
            rp,
            error.UnsupportedTranslation,
            loc,
            "Unsupported type trait kind {}",
            .{kind},
        ),
    };

    const builtin_node = try rp.c.createBuiltinCall(kind_str, 1);
    builtin_node.params()[0] = type_node;
    builtin_node.rparen_token = try appendToken(rp.c, .RParen, ")");
    return maybeSuppressResult(rp, scope, result_used, &builtin_node.base);
}

fn qualTypeHasWrappingOverflow(qt: clang.QualType) bool {
    if (cIsUnsignedInteger(qt)) {
        // unsigned integer overflow wraps around.
        return true;
    } else {
        // float, signed integer, and pointer overflow is undefined behavior.
        return false;
    }
}

fn transUnaryOperator(rp: RestorePoint, scope: *Scope, stmt: *const clang.UnaryOperator, used: ResultUsed) TransError!*ast.Node {
    const op_expr = stmt.getSubExpr();
    switch (stmt.getOpcode()) {
        .PostInc => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePostCrement(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", used)
        else
            return transCreatePostCrement(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", used),
        .PostDec => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePostCrement(rp, scope, stmt, .AssignSubWrap, .MinusPercentEqual, "-%=", used)
        else
            return transCreatePostCrement(rp, scope, stmt, .AssignSub, .MinusEqual, "-=", used),
        .PreInc => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreatePreCrement(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", used)
        else
            return transCreatePreCrement(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", used),
        .PreDec => if (qualTypeHasWrappingOverflow(stmt.getType()))
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
            const fn_ty = qualTypeGetFnProto(op_expr.getType(), &is_ptr);
            if (fn_ty != null and is_ptr)
                return value_node;
            const unwrapped = try transCreateNodeUnwrapNull(rp.c, value_node);
            return transCreateNodePtrDeref(rp.c, unwrapped);
        },
        .Plus => return transExpr(rp, scope, op_expr, used, .r_value),
        .Minus => {
            if (!qualTypeHasWrappingOverflow(op_expr.getType())) {
                const op_node = try transCreateNodeSimplePrefixOp(rp.c, .Negation, .Minus, "-");
                op_node.rhs = try transExpr(rp, scope, op_expr, .used, .r_value);
                return &op_node.base;
            } else if (cIsUnsignedInteger(op_expr.getType())) {
                // we gotta emit 0 -% x
                const zero = try transCreateNodeInt(rp.c, 0);
                const token = try appendToken(rp.c, .MinusPercent, "-%");
                const expr = try transExpr(rp, scope, op_expr, .used, .r_value);
                return transCreateNodeInfixOp(rp, scope, zero, .SubWrap, token, expr, used, true);
            } else
                return revertAndWarn(rp, error.UnsupportedTranslation, stmt.getBeginLoc(), "C negation with non float non integer", .{});
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
            return transExpr(rp, scope, stmt.getSubExpr(), used, .l_value);
        },
        else => return revertAndWarn(rp, error.UnsupportedTranslation, stmt.getBeginLoc(), "unsupported C translation {}", .{stmt.getOpcode()}),
    }
}

fn transCreatePreCrement(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.UnaryOperator,
    op: ast.Node.Tag,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const op_expr = stmt.getSubExpr();

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
    var block_scope = try Scope.Block.init(rp.c, scope, true);
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

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label, ref_node);
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = block_node,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCreatePostCrement(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.UnaryOperator,
    op: ast.Node.Tag,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
    used: ResultUsed,
) TransError!*ast.Node {
    const op_expr = stmt.getSubExpr();

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
    var block_scope = try Scope.Block.init(rp.c, scope, true);
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

    const break_node = blk: {
        var tmp_ctrl_flow = try CtrlFlow.initToken(rp.c, .Break, block_scope.label);
        const rhs = try transCreateNodeIdentifier(rp.c, tmp);
        break :blk try tmp_ctrl_flow.finish(rhs);
    };
    try block_scope.statements.append(&break_node.base);
    _ = try appendToken(rp.c, .Semicolon, ";");
    const block_node = try block_scope.complete(rp.c);
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = block_node,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCompoundAssignOperator(rp: RestorePoint, scope: *Scope, stmt: *const clang.CompoundAssignOperator, used: ResultUsed) TransError!*ast.Node {
    switch (stmt.getOpcode()) {
        .MulAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreateCompoundAssign(rp, scope, stmt, .AssignMulWrap, .AsteriskPercentEqual, "*%=", .MulWrap, .AsteriskPercent, "*%", used)
        else
            return transCreateCompoundAssign(rp, scope, stmt, .AssignMul, .AsteriskEqual, "*=", .Mul, .Asterisk, "*", used),
        .AddAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
            return transCreateCompoundAssign(rp, scope, stmt, .AssignAddWrap, .PlusPercentEqual, "+%=", .AddWrap, .PlusPercent, "+%", used)
        else
            return transCreateCompoundAssign(rp, scope, stmt, .AssignAdd, .PlusEqual, "+=", .Add, .Plus, "+", used),
        .SubAssign => if (qualTypeHasWrappingOverflow(stmt.getType()))
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
            stmt.getBeginLoc(),
            "unsupported C translation {}",
            .{stmt.getOpcode()},
        ),
    }
}

fn transCreateCompoundAssign(
    rp: RestorePoint,
    scope: *Scope,
    stmt: *const clang.CompoundAssignOperator,
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
    const lhs = stmt.getLHS();
    const rhs = stmt.getRHS();
    const loc = stmt.getBeginLoc();
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
    var block_scope = try Scope.Block.init(rp.c, scope, true);
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

    const break_node = try transCreateNodeBreak(rp.c, block_scope.label, ref_node);
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = try appendToken(rp.c, .LParen, "("),
        .expr = block_node,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return &grouped_expr.base;
}

fn transCPtrCast(
    rp: RestorePoint,
    loc: clang.SourceLocation,
    dst_type: clang.QualType,
    src_type: clang.QualType,
    expr: *ast.Node,
) !*ast.Node {
    const ty = dst_type.getTypePtr();
    const child_type = ty.getPointeeType();
    const src_ty = src_type.getTypePtr();
    const src_child_type = src_ty.getPointeeType();

    if ((src_child_type.isConstQualified() and
        !child_type.isConstQualified()) or
        (src_child_type.isVolatileQualified() and
        !child_type.isVolatileQualified()))
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

        if (qualTypeCanon(child_type).isVoidType()) {
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
    const label_text: ?[]const u8 = if (break_scope.id == .Switch) blk: {
        const swtch = @fieldParentPtr(Scope.Switch, "base", break_scope);
        const block_scope = try scope.findBlockScope(rp.c);
        swtch.switch_label = try block_scope.makeMangledName(rp.c, "switch");
        break :blk swtch.switch_label;
    } else
        null;

    var cf = try CtrlFlow.init(rp.c, .Break, label_text);
    const br = try cf.finish(null);
    _ = try appendToken(rp.c, .Semicolon, ";");
    return &br.base;
}

fn transFloatingLiteral(rp: RestorePoint, scope: *Scope, stmt: *const clang.FloatingLiteral, used: ResultUsed) TransError!*ast.Node {
    // TODO use something more accurate
    const dbl = stmt.getValueAsApproximateDouble();
    const node = try rp.c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .FloatLiteral },
        .token = try appendTokenFmt(rp.c, .FloatLiteral, "{d}", .{dbl}),
    };
    return maybeSuppressResult(rp, scope, used, &node.base);
}

fn transBinaryConditionalOperator(rp: RestorePoint, scope: *Scope, stmt: *const clang.BinaryConditionalOperator, used: ResultUsed) TransError!*ast.Node {
    // GNU extension of the ternary operator where the middle expression is
    // omitted, the conditition itself is returned if it evaluates to true
    const casted_stmt = @ptrCast(*const clang.AbstractConditionalOperator, stmt);
    const cond_expr = casted_stmt.getCond();
    const true_expr = casted_stmt.getTrueExpr();
    const false_expr = casted_stmt.getFalseExpr();

    // c:   (cond_expr)?:(false_expr)
    // zig: (blk: {
    //          const _cond_temp = (cond_expr);
    //          break :blk if (_cond_temp) _cond_temp else (false_expr);
    //      })
    const lparen = try appendToken(rp.c, .LParen, "(");

    var block_scope = try Scope.Block.init(rp.c, scope, true);
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

    var break_node_tmp = try CtrlFlow.initToken(rp.c, .Break, block_scope.label);

    const if_node = try transCreateNodeIf(rp.c);
    var cond_scope = Scope.Condition{
        .base = .{
            .parent = &block_scope.base,
            .id = .Condition,
        },
    };
    defer cond_scope.deinit();
    const tmp_var_node = try transCreateNodeIdentifier(rp.c, mangled_name);

    const ty = getExprQualType(rp.c, cond_expr).getTypePtr();
    const cond_node = try finishBoolExpr(rp, &cond_scope.base, cond_expr.getBeginLoc(), ty, tmp_var_node, used);
    if_node.condition = cond_node;
    _ = try appendToken(rp.c, .RParen, ")");

    if_node.body = try transCreateNodeIdentifier(rp.c, mangled_name);
    if_node.@"else" = try transCreateNodeElse(rp.c);
    if_node.@"else".?.body = try transExpr(rp, &block_scope.base, false_expr, .used, .r_value);
    _ = try appendToken(rp.c, .Semicolon, ";");

    const break_node = try break_node_tmp.finish(&if_node.base);
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);

    const grouped_expr = try rp.c.arena.create(ast.Node.GroupedExpression);
    grouped_expr.* = .{
        .lparen = lparen,
        .expr = block_node,
        .rparen = try appendToken(rp.c, .RParen, ")"),
    };
    return maybeSuppressResult(rp, scope, used, &grouped_expr.base);
}

fn transConditionalOperator(rp: RestorePoint, scope: *Scope, stmt: *const clang.ConditionalOperator, used: ResultUsed) TransError!*ast.Node {
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

    const casted_stmt = @ptrCast(*const clang.AbstractConditionalOperator, stmt);
    const cond_expr = casted_stmt.getCond();
    const true_expr = casted_stmt.getTrueExpr();
    const false_expr = casted_stmt.getFalseExpr();

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

fn transQualType(rp: RestorePoint, qt: clang.QualType, source_loc: clang.SourceLocation) TypeError!*ast.Node {
    return transType(rp, qt.getTypePtr(), source_loc);
}

/// Produces a Zig AST node by translating a Clang QualType, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transQualTypeIntWidthOf(c: *Context, ty: clang.QualType, is_signed: bool) TypeError!*ast.Node {
    return transTypeIntWidthOf(c, qualTypeCanon(ty), is_signed);
}

/// Produces a Zig AST node by translating a Clang Type, respecting the width, but modifying the signed-ness.
/// Asserts the type is an integer.
fn transTypeIntWidthOf(c: *Context, ty: *const clang.Type, is_signed: bool) TypeError!*ast.Node {
    assert(ty.getTypeClass() == .Builtin);
    const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);
    return transCreateNodeIdentifier(c, switch (builtin_ty.getKind()) {
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

fn isCBuiltinType(qt: clang.QualType, kind: clang.BuiltinTypeKind) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin)
        return false;
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return builtin_ty.getKind() == kind;
}

fn qualTypeIsPtr(qt: clang.QualType) bool {
    return qualTypeCanon(qt).getTypeClass() == .Pointer;
}

fn qualTypeIsBoolean(qt: clang.QualType) bool {
    return qualTypeCanon(qt).isBooleanType();
}

fn qualTypeIntBitWidth(rp: RestorePoint, qt: clang.QualType, source_loc: clang.SourceLocation) !u32 {
    const ty = qt.getTypePtr();

    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);

            switch (builtin_ty.getKind()) {
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
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);
            const typedef_decl = typedef_ty.getDecl();
            const type_name = try rp.c.str(@ptrCast(*const clang.NamedDecl, typedef_decl).getName_bytes_begin());

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

fn qualTypeToLog2IntRef(rp: RestorePoint, qt: clang.QualType, source_loc: clang.SourceLocation) !*ast.Node {
    const int_bit_width = try qualTypeIntBitWidth(rp, qt, source_loc);

    if (int_bit_width != 0) {
        // we can perform the log2 now.
        const cast_bit_width = math.log2_int(u64, int_bit_width);
        const node = try rp.c.arena.create(ast.Node.OneToken);
        node.* = .{
            .base = .{ .tag = .IntegerLiteral },
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
    const std_node = try rp.c.arena.create(ast.Node.OneToken);
    std_node.* = .{
        .base = .{ .tag = .StringLiteral },
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

fn qualTypeChildIsFnProto(qt: clang.QualType) bool {
    const ty = qualTypeCanon(qt);

    switch (ty.getTypeClass()) {
        .FunctionProto, .FunctionNoProto => return true,
        else => return false,
    }
}

fn qualTypeCanon(qt: clang.QualType) *const clang.Type {
    const canon = qt.getCanonicalType();
    return canon.getTypePtr();
}

fn getExprQualType(c: *Context, expr: *const clang.Expr) clang.QualType {
    blk: {
        // If this is a C `char *`, turn it into a `const char *`
        if (expr.getStmtClass() != .ImplicitCastExprClass) break :blk;
        const cast_expr = @ptrCast(*const clang.ImplicitCastExpr, expr);
        if (cast_expr.getCastKind() != .ArrayToPointerDecay) break :blk;
        const sub_expr = cast_expr.getSubExpr();
        if (sub_expr.getStmtClass() != .StringLiteralClass) break :blk;
        const array_qt = sub_expr.getType();
        const array_type = @ptrCast(*const clang.ArrayType, array_qt.getTypePtr());
        var pointee_qt = array_type.getElementType();
        pointee_qt.addConst();
        return c.clang_context.getPointerType(pointee_qt);
    }
    return expr.getType();
}

fn typeIsOpaque(c: *Context, ty: *const clang.Type, loc: clang.SourceLocation) bool {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);
            return builtin_ty.getKind() == .Void;
        },
        .Record => {
            const record_ty = @ptrCast(*const clang.RecordType, ty);
            const record_decl = record_ty.getDecl();
            const record_def = record_decl.getDefinition() orelse
                return true;
            var it = record_def.field_begin();
            const end_it = record_def.field_end();
            while (it.neq(end_it)) : (it = it.next()) {
                const field_decl = it.deref();

                if (field_decl.isBitField()) {
                    return true;
                }
            }
            return false;
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const clang.ElaboratedType, ty);
            const qt = elaborated_ty.getNamedType();
            return typeIsOpaque(c, qt.getTypePtr(), loc);
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);
            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return typeIsOpaque(c, underlying_type.getTypePtr(), loc);
        },
        else => return false,
    }
}

fn cIsInteger(qt: clang.QualType) bool {
    return cIsSignedInteger(qt) or cIsUnsignedInteger(qt);
}

fn cIsUnsignedInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return switch (builtin_ty.getKind()) {
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

fn cIntTypeToIndex(qt: clang.QualType) u8 {
    const c_type = qualTypeCanon(qt);
    assert(c_type.getTypeClass() == .Builtin);
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return switch (builtin_ty.getKind()) {
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

fn cIntTypeCmp(a: clang.QualType, b: clang.QualType) math.Order {
    const a_index = cIntTypeToIndex(a);
    const b_index = cIntTypeToIndex(b);
    return math.order(a_index, b_index);
}

fn cIsSignedInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return switch (builtin_ty.getKind()) {
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

fn cIsFloating(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return switch (builtin_ty.getKind()) {
        .Float,
        .Double,
        .Float128,
        .LongDouble,
        => true,
        else => false,
    };
}

fn cIsLongLongInteger(qt: clang.QualType) bool {
    const c_type = qualTypeCanon(qt);
    if (c_type.getTypeClass() != .Builtin) return false;
    const builtin_ty = @ptrCast(*const clang.BuiltinType, c_type);
    return switch (builtin_ty.getKind()) {
        .LongLong, .ULongLong, .Int128, .UInt128 => true,
        else => false,
    };
}
fn transCreateNodeAssign(
    rp: RestorePoint,
    scope: *Scope,
    result_used: ResultUsed,
    lhs: *const clang.Expr,
    rhs: *const clang.Expr,
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
    var block_scope = try Scope.Block.init(rp.c, scope, true);
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

    const break_node = blk: {
        var tmp_ctrl_flow = try CtrlFlow.init(rp.c, .Break, tokenSlice(rp.c, block_scope.label.?));
        const rhs_expr = try transCreateNodeIdentifier(rp.c, tmp);
        break :blk try tmp_ctrl_flow.finish(rhs_expr);
    };
    _ = try appendToken(rp.c, .Semicolon, ";");
    try block_scope.statements.append(&break_node.base);
    const block_node = try block_scope.complete(rp.c);
    // semicolon must immediately follow rbrace because it is the last token in a block
    _ = try appendToken(rp.c, .Semicolon, ";");
    return block_node;
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
    stmt: *const clang.BinaryOperator,
    op: ast.Node.Tag,
    used: ResultUsed,
    grouped: bool,
) !*ast.Node {
    std.debug.assert(op == .BoolAnd or op == .BoolOr);

    const lhs_hode = try transBoolExpr(rp, scope, stmt.getLHS(), .used, .l_value, true);
    const op_token = if (op == .BoolAnd)
        try appendToken(rp.c, .Keyword_and, "and")
    else
        try appendToken(rp.c, .Keyword_or, "or");
    const rhs = try transBoolExpr(rp, scope, stmt.getRHS(), .used, .r_value, true);

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

fn transCreateNodeAPInt(c: *Context, int: *const clang.APSInt) !*ast.Node {
    const num_limbs = math.cast(usize, int.getNumWords()) catch |err| switch (err) {
        error.Overflow => return error.OutOfMemory,
    };
    var aps_int = int;
    const is_negative = int.isSigned() and int.isNegative();
    if (is_negative) aps_int = aps_int.negate();
    defer if (is_negative) {
        aps_int.free();
    };

    const limbs = try c.arena.alloc(math.big.Limb, num_limbs);
    defer c.arena.free(limbs);

    const data = aps_int.getRawData();
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
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .IntegerLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeUndefinedLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_undefined, "undefined");
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .UndefinedLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeNullLiteral(c: *Context) !*ast.Node {
    const token = try appendToken(c, .Keyword_null, "null");
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .NullLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeBoolLiteral(c: *Context, value: bool) !*ast.Node {
    const token = if (value)
        try appendToken(c, .Keyword_true, "true")
    else
        try appendToken(c, .Keyword_false, "false");
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .BoolLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeInt(c: *Context, int: anytype) !*ast.Node {
    const token = try appendTokenFmt(c, .IntegerLiteral, "{}", .{int});
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .IntegerLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeFloat(c: *Context, int: anytype) !*ast.Node {
    const token = try appendTokenFmt(c, .FloatLiteral, "{}", .{int});
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .FloatLiteral },
        .token = token,
    };
    return &node.base;
}

fn transCreateNodeOpaqueType(c: *Context) !*ast.Node {
    const container_tok = try appendToken(c, .Keyword_opaque, "opaque");
    const lbrace_token = try appendToken(c, .LBrace, "{");
    const container_node = try ast.Node.ContainerDecl.alloc(c.arena, 0);
    container_node.* = .{
        .kind_token = container_tok,
        .layout_token = null,
        .lbrace_token = lbrace_token,
        .rbrace_token = try appendToken(c, .RBrace, "}"),
        .fields_and_decls_len = 0,
        .init_arg_expr = .None,
    };
    return &container_node.base;
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

    const return_kw = try appendToken(c, .Keyword_return, "return");
    const unwrap_expr = try transCreateNodeUnwrapNull(c, ref.cast(ast.Node.VarDecl).?.getInitNode().?);

    const call_expr = try c.createCall(unwrap_expr, fn_params.items.len);
    const call_params = call_expr.params();

    for (fn_params.items) |param, i| {
        if (i != 0) {
            _ = try appendToken(c, .Comma, ",");
        }
        call_params[i] = try transCreateNodeIdentifier(c, tokenSlice(c, param.name_token.?));
    }
    call_expr.rtoken = try appendToken(c, .RParen, ")");

    const return_expr = try ast.Node.ControlFlowExpression.create(c.arena, .{
        .ltoken = return_kw,
        .tag = .Return,
    }, .{
        .rhs = &call_expr.base,
    });
    _ = try appendToken(c, .Semicolon, ";");

    const block = try ast.Node.Block.alloc(c.arena, 1);
    block.* = .{
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
    const node = try c.arena.create(ast.Node.OneToken);
    node.* = .{
        .base = .{ .tag = .StringLiteral },
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

fn transCreateNodeBreak(
    c: *Context,
    label: ?ast.TokenIndex,
    rhs: ?*ast.Node,
) !*ast.Node.ControlFlowExpression {
    var ctrl_flow = try CtrlFlow.init(c, .Break, if (label) |l| tokenSlice(c, l) else null);
    return ctrl_flow.finish(rhs);
}

const CtrlFlow = struct {
    c: *Context,
    ltoken: ast.TokenIndex,
    label_token: ?ast.TokenIndex,
    tag: ast.Node.Tag,

    /// Does everything except the RHS.
    fn init(c: *Context, tag: ast.Node.Tag, label: ?[]const u8) !CtrlFlow {
        const kw: Token.Id = switch (tag) {
            .Break => .Keyword_break,
            .Continue => .Keyword_continue,
            .Return => .Keyword_return,
            else => unreachable,
        };
        const kw_text = switch (tag) {
            .Break => "break",
            .Continue => "continue",
            .Return => "return",
            else => unreachable,
        };
        const ltoken = try appendToken(c, kw, kw_text);
        const label_token = if (label) |l| blk: {
            _ = try appendToken(c, .Colon, ":");
            break :blk try appendIdentifier(c, l);
        } else null;
        return CtrlFlow{
            .c = c,
            .ltoken = ltoken,
            .label_token = label_token,
            .tag = tag,
        };
    }

    fn initToken(c: *Context, tag: ast.Node.Tag, label: ?ast.TokenIndex) !CtrlFlow {
        const other_token = label orelse return init(c, tag, null);
        const loc = c.token_locs.items[other_token];
        const label_name = c.source_buffer.items[loc.start..loc.end];
        return init(c, tag, label_name);
    }

    fn finish(self: *CtrlFlow, rhs: ?*ast.Node) !*ast.Node.ControlFlowExpression {
        return ast.Node.ControlFlowExpression.create(self.c.arena, .{
            .ltoken = self.ltoken,
            .tag = self.tag,
        }, .{
            .label = self.label_token,
            .rhs = rhs,
        });
    }
};

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
    const node = try ast.Node.ControlFlowExpression.create(c.arena, .{
        .ltoken = ltoken,
        .tag = .Continue,
    }, .{});
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
    stmt: *const clang.BinaryOperator,
    op: ast.Node.Tag,
    op_tok_id: std.zig.Token.Id,
    bytes: []const u8,
) !*ast.Node {
    std.debug.assert(op == .BitShiftLeft or op == .BitShiftRight);

    const lhs_expr = stmt.getLHS();
    const rhs_expr = stmt.getRHS();
    const rhs_location = rhs_expr.getBeginLoc();
    // lhs >> @as(u5, rh)

    const lhs = try transExpr(rp, scope, lhs_expr, .used, .l_value);
    const op_token = try appendToken(rp.c, op_tok_id, bytes);

    const cast_node = try rp.c.createBuiltinCall("@intCast", 2);
    const rhs_type = try qualTypeToLog2IntRef(rp, stmt.getType(), rhs_location);
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

fn transType(rp: RestorePoint, ty: *const clang.Type, source_loc: clang.SourceLocation) TypeError!*ast.Node {
    switch (ty.getTypeClass()) {
        .Builtin => {
            const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);
            return transCreateNodeIdentifier(rp.c, switch (builtin_ty.getKind()) {
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
            const fn_proto_ty = @ptrCast(*const clang.FunctionProtoType, ty);
            const fn_proto = try transFnProto(rp, null, fn_proto_ty, source_loc, null, false);
            return &fn_proto.base;
        },
        .FunctionNoProto => {
            const fn_no_proto_ty = @ptrCast(*const clang.FunctionType, ty);
            const fn_proto = try transFnNoProto(rp, fn_no_proto_ty, source_loc, null, false);
            return &fn_proto.base;
        },
        .Paren => {
            const paren_ty = @ptrCast(*const clang.ParenType, ty);
            return transQualType(rp, paren_ty.getInnerType(), source_loc);
        },
        .Pointer => {
            const child_qt = ty.getPointeeType();
            if (qualTypeChildIsFnProto(child_qt)) {
                const optional_node = try transCreateNodeSimplePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
                optional_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            if (typeIsOpaque(rp.c, child_qt.getTypePtr(), source_loc) or qualTypeWasDemotedToOpaque(rp.c, child_qt)) {
                const optional_node = try transCreateNodeSimplePrefixOp(rp.c, .OptionalType, .QuestionMark, "?");
                const pointer_node = try transCreateNodePtrType(
                    rp.c,
                    child_qt.isConstQualified(),
                    child_qt.isVolatileQualified(),
                    .Asterisk,
                );
                optional_node.rhs = &pointer_node.base;
                pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
                return &optional_node.base;
            }
            const pointer_node = try transCreateNodePtrType(
                rp.c,
                child_qt.isConstQualified(),
                child_qt.isVolatileQualified(),
                .Identifier,
            );
            pointer_node.rhs = try transQualType(rp, child_qt, source_loc);
            return &pointer_node.base;
        },
        .ConstantArray => {
            const const_arr_ty = @ptrCast(*const clang.ConstantArrayType, ty);

            const size_ap_int = const_arr_ty.getSize();
            const size = size_ap_int.getLimitedValue(math.maxInt(usize));
            const elem_ty = const_arr_ty.getElementType().getTypePtr();
            return try transCreateNodeArrayType(rp, source_loc, elem_ty, size);
        },
        .IncompleteArray => {
            const incomplete_array_ty = @ptrCast(*const clang.IncompleteArrayType, ty);

            const child_qt = incomplete_array_ty.getElementType();
            var node = try transCreateNodePtrType(
                rp.c,
                child_qt.isConstQualified(),
                child_qt.isVolatileQualified(),
                .Identifier,
            );
            node.rhs = try transQualType(rp, child_qt, source_loc);
            return &node.base;
        },
        .Typedef => {
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);

            const typedef_decl = typedef_ty.getDecl();
            return (try transTypeDef(rp.c, typedef_decl, false)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to translate typedef declaration", .{});
        },
        .Record => {
            const record_ty = @ptrCast(*const clang.RecordType, ty);

            const record_decl = record_ty.getDecl();
            return (try transRecordDecl(rp.c, record_decl)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to resolve record declaration", .{});
        },
        .Enum => {
            const enum_ty = @ptrCast(*const clang.EnumType, ty);

            const enum_decl = enum_ty.getDecl();
            return (try transEnumDecl(rp.c, enum_decl)) orelse
                revertAndWarn(rp, error.UnsupportedType, source_loc, "unable to translate enum declaration", .{});
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const clang.ElaboratedType, ty);
            return transQualType(rp, elaborated_ty.getNamedType(), source_loc);
        },
        .Decayed => {
            const decayed_ty = @ptrCast(*const clang.DecayedType, ty);
            return transQualType(rp, decayed_ty.getDecayedType(), source_loc);
        },
        .Attributed => {
            const attributed_ty = @ptrCast(*const clang.AttributedType, ty);
            return transQualType(rp, attributed_ty.getEquivalentType(), source_loc);
        },
        .MacroQualified => {
            const macroqualified_ty = @ptrCast(*const clang.MacroQualifiedType, ty);
            return transQualType(rp, macroqualified_ty.getModifiedType(), source_loc);
        },
        else => {
            const type_name = rp.c.str(ty.getTypeClassName());
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported type: '{}'", .{type_name});
        },
    }
}

fn qualTypeWasDemotedToOpaque(c: *Context, qt: clang.QualType) bool {
    const ty = qt.getTypePtr();
    switch (qt.getTypeClass()) {
        .Typedef => {
            const typedef_ty = @ptrCast(*const clang.TypedefType, ty);

            const typedef_decl = typedef_ty.getDecl();
            const underlying_type = typedef_decl.getUnderlyingType();
            return qualTypeWasDemotedToOpaque(c, underlying_type);
        },
        .Record => {
            const record_ty = @ptrCast(*const clang.RecordType, ty);

            const record_decl = record_ty.getDecl();
            const canonical = @ptrToInt(record_decl.getCanonicalDecl());
            return c.opaque_demotes.contains(canonical);
        },
        .Enum => {
            const enum_ty = @ptrCast(*const clang.EnumType, ty);

            const enum_decl = enum_ty.getDecl();
            const canonical = @ptrToInt(enum_decl.getCanonicalDecl());
            return c.opaque_demotes.contains(canonical);
        },
        .Elaborated => {
            const elaborated_ty = @ptrCast(*const clang.ElaboratedType, ty);
            return qualTypeWasDemotedToOpaque(c, elaborated_ty.getNamedType());
        },
        .Decayed => {
            const decayed_ty = @ptrCast(*const clang.DecayedType, ty);
            return qualTypeWasDemotedToOpaque(c, decayed_ty.getDecayedType());
        },
        .Attributed => {
            const attributed_ty = @ptrCast(*const clang.AttributedType, ty);
            return qualTypeWasDemotedToOpaque(c, attributed_ty.getEquivalentType());
        },
        .MacroQualified => {
            const macroqualified_ty = @ptrCast(*const clang.MacroQualifiedType, ty);
            return qualTypeWasDemotedToOpaque(c, macroqualified_ty.getModifiedType());
        },
        else => return false,
    }
}

fn isCVoid(qt: clang.QualType) bool {
    const ty = qt.getTypePtr();
    if (ty.getTypeClass() == .Builtin) {
        const builtin_ty = @ptrCast(*const clang.BuiltinType, ty);
        return builtin_ty.getKind() == .Void;
    }
    return false;
}

const FnDeclContext = struct {
    fn_name: []const u8,
    has_body: bool,
    storage_class: clang.StorageClass,
    is_export: bool,
};

fn transCC(
    rp: RestorePoint,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
) !CallingConvention {
    const clang_cc = fn_ty.getCallConv();
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
    fn_decl: ?*const clang.FunctionDecl,
    fn_proto_ty: *const clang.FunctionProtoType,
    source_loc: clang.SourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Node.FnProto {
    const fn_ty = @ptrCast(*const clang.FunctionType, fn_proto_ty);
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = fn_proto_ty.isVariadic();
    return finishTransFnProto(rp, fn_decl, fn_proto_ty, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn transFnNoProto(
    rp: RestorePoint,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_pub: bool,
) !*ast.Node.FnProto {
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = if (fn_decl_context) |ctx| !ctx.is_export else true;
    return finishTransFnProto(rp, null, null, fn_ty, source_loc, fn_decl_context, is_var_args, cc, is_pub);
}

fn finishTransFnProto(
    rp: RestorePoint,
    fn_decl: ?*const clang.FunctionDecl,
    fn_proto_ty: ?*const clang.FunctionProtoType,
    fn_ty: *const clang.FunctionType,
    source_loc: clang.SourceLocation,
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
    else if (is_extern)
        try appendToken(rp.c, .Keyword_extern, "extern")
    else
        null;
    const fn_tok = try appendToken(rp.c, .Keyword_fn, "fn");
    const name_tok = if (fn_decl_context) |ctx| try appendIdentifier(rp.c, ctx.fn_name) else null;
    const lparen_tok = try appendToken(rp.c, .LParen, "(");

    var fn_params = std.ArrayList(ast.Node.FnProto.ParamDecl).init(rp.c.gpa);
    defer fn_params.deinit();
    const param_count: usize = if (fn_proto_ty != null) fn_proto_ty.?.getNumParams() else 0;
    try fn_params.ensureCapacity(param_count + 1); // +1 for possible var args node

    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        const param_qt = fn_proto_ty.?.getParamType(@intCast(c_uint, i));

        const noalias_tok = if (param_qt.isRestrictQualified()) try appendToken(rp.c, .Keyword_noalias, "noalias") else null;

        const param_name_tok: ?ast.TokenIndex = blk: {
            if (fn_decl) |decl| {
                const param = decl.getParamDecl(@intCast(c_uint, i));
                const param_name: []const u8 = try rp.c.str(@ptrCast(*const clang.NamedDecl, param).getName_bytes_begin());
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
            if (decl.getSectionAttribute(&str_len)) |str_ptr| {
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
            const alignment = decl.getAlignedAttribute(rp.c.clang_context);
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
        if (fn_ty.getNoReturnAttr()) {
            break :blk try transCreateNodeIdentifier(rp.c, "noreturn");
        } else {
            const return_qt = fn_ty.getReturnType();
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
    source_loc: clang.SourceLocation,
    comptime format: []const u8,
    args: anytype,
) (@TypeOf(err) || error{OutOfMemory}) {
    rp.activate();
    try emitWarning(rp.c, source_loc, format, args);
    return err;
}

fn emitWarning(c: *Context, loc: clang.SourceLocation, comptime format: []const u8, args: anytype) !void {
    const args_prefix = .{c.locStr(loc)};
    _ = try appendTokenFmt(c, .LineComment, "// {}: warning: " ++ format, args_prefix ++ args);
}

pub fn failDecl(c: *Context, loc: clang.SourceLocation, name: []const u8, comptime format: []const u8, args: anytype) !void {
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

    const msg_node = try c.arena.create(ast.Node.OneToken);
    msg_node.* = .{
        .base = .{ .tag = .StringLiteral },
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

fn appendIdentifier(c: *Context, name: []const u8) !ast.TokenIndex {
    return appendTokenFmt(c, .Identifier, "{z}", .{name});
}

fn transCreateNodeIdentifier(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendIdentifier(c, name);
    const identifier = try c.arena.create(ast.Node.OneToken);
    identifier.* = .{
        .base = .{ .tag = .Identifier },
        .token = token_index,
    };
    return &identifier.base;
}

fn transCreateNodeIdentifierUnchecked(c: *Context, name: []const u8) !*ast.Node {
    const token_index = try appendTokenFmt(c, .Identifier, "{}", .{name});
    const identifier = try c.arena.create(ast.Node.OneToken);
    identifier.* = .{
        .base = .{ .tag = .Identifier },
        .token = token_index,
    };
    return &identifier.base;
}

pub fn freeErrors(errors: []ClangErrMsg) void {
    errors.ptr.delete(errors.len);
}

const MacroCtx = struct {
    source: []const u8,
    list: []const CToken,
    i: usize = 0,
    loc: clang.SourceLocation,
    name: []const u8,

    fn peek(self: *MacroCtx) ?CToken.Id {
        if (self.i >= self.list.len) return null;
        return self.list[self.i + 1].id;
    }

    fn next(self: *MacroCtx) ?CToken.Id {
        if (self.i >= self.list.len) return null;
        self.i += 1;
        return self.list[self.i].id;
    }

    fn slice(self: *MacroCtx) []const u8 {
        const tok = self.list[self.i];
        return self.source[tok.start..tok.end];
    }

    fn fail(self: *MacroCtx, c: *Context, comptime fmt: []const u8, args: anytype) !void {
        return failDecl(c, self.loc, self.name, fmt, args);
    }
};

fn transPreprocessorEntities(c: *Context, unit: *clang.ASTUnit) Error!void {
    // TODO if we see #undef, delete it from the table
    var it = unit.getLocalPreprocessingEntities_begin();
    const it_end = unit.getLocalPreprocessingEntities_end();
    var tok_list = std.ArrayList(CToken).init(c.gpa);
    defer tok_list.deinit();
    const scope = c.global_scope;

    while (it.I != it_end.I) : (it.I += 1) {
        const entity = it.deref();
        tok_list.items.len = 0;
        switch (entity.getKind()) {
            .MacroDefinitionKind => {
                const macro = @ptrCast(*clang.MacroDefinitionRecord, entity);
                const raw_name = macro.getName_getNameStart();
                const begin_loc = macro.getSourceRange_getBegin();

                const name = try c.str(raw_name);
                // TODO https://github.com/ziglang/zig/issues/3756
                // TODO https://github.com/ziglang/zig/issues/1802
                const mangled_name = if (isZigPrimitiveType(name)) try std.fmt.allocPrint(c.arena, "{}_{}", .{ name, c.getMangle() }) else name;
                if (scope.containsNow(mangled_name)) {
                    continue;
                }

                const begin_c = c.source_manager.getCharacterData(begin_loc);
                const slice = begin_c[0..mem.len(begin_c)];

                var tokenizer = std.c.Tokenizer{
                    .buffer = slice,
                };
                while (true) {
                    const tok = tokenizer.next();
                    switch (tok.id) {
                        .Nl, .Eof => {
                            try tok_list.append(tok);
                            break;
                        },
                        .LineComment, .MultiLineComment => continue,
                        else => {},
                    }
                    try tok_list.append(tok);
                }

                var macro_ctx = MacroCtx{
                    .source = slice,
                    .list = tok_list.items,
                    .name = mangled_name,
                    .loc = begin_loc,
                };
                assert(mem.eql(u8, macro_ctx.slice(), name));

                var macro_fn = false;
                switch (macro_ctx.peek().?) {
                    .Identifier => {
                        // if it equals itself, ignore. for example, from stdio.h:
                        // #define stdin stdin
                        const tok = macro_ctx.list[1];
                        if (mem.eql(u8, name, slice[tok.start..tok.end])) {
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
                        macro_fn = macro_ctx.list[0].end == macro_ctx.list[1].start;
                    },
                    else => {},
                }

                (if (macro_fn)
                    transMacroFnDefine(c, &macro_ctx)
                else
                    transMacroDefine(c, &macro_ctx)) catch |err| switch (err) {
                    error.ParseError => continue,
                    error.OutOfMemory => |e| return e,
                };
            },
            else => {},
        }
    }
}

fn transMacroDefine(c: *Context, m: *MacroCtx) ParseError!void {
    const scope = &c.global_scope.base;

    const visib_tok = try appendToken(c, .Keyword_pub, "pub");
    const mut_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendIdentifier(c, m.name);
    const eq_token = try appendToken(c, .Equal, "=");

    const init_node = try parseCExpr(c, m, scope);
    const last = m.next().?;
    if (last != .Eof and last != .Nl)
        return m.fail(c, "unable to translate C expr: unexpected token .{}", .{@tagName(last)});

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
    _ = try c.global_scope.macro_table.put(m.name, &node.base);
}

fn transMacroFnDefine(c: *Context, m: *MacroCtx) ParseError!void {
    var block_scope = try Scope.Block.init(c, &c.global_scope.base, false);
    defer block_scope.deinit();
    const scope = &block_scope.base;

    const pub_tok = try appendToken(c, .Keyword_pub, "pub");
    const inline_tok = try appendToken(c, .Keyword_inline, "inline");
    const fn_tok = try appendToken(c, .Keyword_fn, "fn");
    const name_tok = try appendIdentifier(c, m.name);
    _ = try appendToken(c, .LParen, "(");

    if (m.next().? != .LParen) {
        return m.fail(c, "unable to translate C expr: expected '('", .{});
    }

    var fn_params = std.ArrayList(ast.Node.FnProto.ParamDecl).init(c.gpa);
    defer fn_params.deinit();

    while (true) {
        if (m.peek().? != .Identifier) break;
        _ = m.next();

        const mangled_name = try block_scope.makeMangledName(c, m.slice());
        const param_name_tok = try appendIdentifier(c, mangled_name);
        _ = try appendToken(c, .Colon, ":");

        const any_type = try c.arena.create(ast.Node.OneToken);
        any_type.* = .{
            .base = .{ .tag = .AnyType },
            .token = try appendToken(c, .Keyword_anytype, "anytype"),
        };

        (try fn_params.addOne()).* = .{
            .doc_comments = null,
            .comptime_token = null,
            .noalias_token = null,
            .name_token = param_name_tok,
            .param_type = .{ .any_type = &any_type.base },
        };

        if (m.peek().? != .Comma) break;
        _ = m.next();
        _ = try appendToken(c, .Comma, ",");
    }

    if (m.next().? != .RParen) {
        return m.fail(c, "unable to translate C expr: expected ')'", .{});
    }

    _ = try appendToken(c, .RParen, ")");

    const type_of = try c.createBuiltinCall("@TypeOf", 1);

    const return_kw = try appendToken(c, .Keyword_return, "return");
    const expr = try parseCExpr(c, m, scope);
    const last = m.next().?;
    if (last != .Eof and last != .Nl)
        return m.fail(c, "unable to translate C expr: unexpected token .{}", .{@tagName(last)});
    _ = try appendToken(c, .Semicolon, ";");
    const type_of_arg = if (!expr.tag.isBlock()) expr else blk: {
        const stmts = expr.blockStatements();
        const blk_last = stmts[stmts.len - 1];
        const br = blk_last.cast(ast.Node.ControlFlowExpression).?;
        break :blk br.getRHS().?;
    };
    type_of.params()[0] = type_of_arg;
    type_of.rparen_token = try appendToken(c, .RParen, ")");
    const return_expr = try ast.Node.ControlFlowExpression.create(c.arena, .{
        .ltoken = return_kw,
        .tag = .Return,
    }, .{
        .rhs = expr,
    });

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
        .body_node = block_node,
    });
    mem.copy(ast.Node.FnProto.ParamDecl, fn_proto.params(), fn_params.items);

    _ = try c.global_scope.macro_table.put(m.name, &fn_proto.base);
}

const ParseError = Error || error{ParseError};

fn parseCExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    // TODO parseCAssignExpr here
    const node = try parseCCondExpr(c, m, scope);
    if (m.next().? != .Comma) {
        m.i -= 1;
        return node;
    }
    _ = try appendToken(c, .Semicolon, ";");
    var block_scope = try Scope.Block.init(c, scope, true);
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

        last = try parseCCondExpr(c, m, scope);
        _ = try appendToken(c, .Semicolon, ";");
        if (m.next().? != .Comma) {
            m.i -= 1;
            break;
        }
    }

    const break_node = try transCreateNodeBreak(c, block_scope.label, last);
    try block_scope.statements.append(&break_node.base);
    return try block_scope.complete(c);
}

fn parseCNumLit(c: *Context, m: *MacroCtx) ParseError!*ast.Node {
    var lit_bytes = m.slice();

    switch (m.list[m.i].id) {
        .IntegerLiteral => |suffix| {
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

            if (suffix == .none) {
                return transCreateNodeInt(c, lit_bytes);
            }

            const cast_node = try c.createBuiltinCall("@as", 2);
            cast_node.params()[0] = try transCreateNodeIdentifier(c, switch (suffix) {
                .u => "c_uint",
                .l => "c_long",
                .lu => "c_ulong",
                .ll => "c_longlong",
                .llu => "c_ulonglong",
                else => unreachable,
            });
            lit_bytes = lit_bytes[0 .. lit_bytes.len - switch (suffix) {
                .u, .l => @as(u8, 1),
                .lu, .ll => 2,
                .llu => 3,
                else => unreachable,
            }];
            _ = try appendToken(c, .Comma, ",");
            cast_node.params()[1] = try transCreateNodeInt(c, lit_bytes);
            cast_node.rparen_token = try appendToken(c, .RParen, ")");
            return &cast_node.base;
        },
        .FloatLiteral => |suffix| {
            if (lit_bytes[0] == '.')
                lit_bytes = try std.fmt.allocPrint(c.arena, "0{}", .{lit_bytes});
            if (suffix == .none) {
                return transCreateNodeFloat(c, lit_bytes);
            }
            const cast_node = try c.createBuiltinCall("@as", 2);
            cast_node.params()[0] = try transCreateNodeIdentifier(c, switch (suffix) {
                .f => "f32",
                .l => "c_longdouble",
                else => unreachable,
            });
            _ = try appendToken(c, .Comma, ",");
            cast_node.params()[1] = try transCreateNodeFloat(c, lit_bytes[0 .. lit_bytes.len - 1]);
            cast_node.rparen_token = try appendToken(c, .RParen, ")");
            return &cast_node.base;
        },
        else => unreachable,
    }
}

fn zigifyEscapeSequences(ctx: *Context, m: *MacroCtx) ![]const u8 {
    var source = m.slice();
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
                        try m.fail(ctx, "macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.ParseError;
                    },
                    else => {
                        try m.fail(ctx, "macro tokenizing failed: unknown escape sequence", .{});
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
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try m.fail(ctx, "macro tokenizing failed: hex literal overflowed", .{});
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
                        try m.fail(ctx, "macro tokenizing failed: octal literal overflowed", .{});
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

fn parseCPrimaryExprInner(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    const tok = m.next().?;
    const slice = m.slice();
    switch (tok) {
        .CharLiteral => {
            if (slice[0] != '\'' or slice[1] == '\\' or slice.len == 3) {
                const token = try appendToken(c, .CharLiteral, try zigifyEscapeSequences(c, m));
                const node = try c.arena.create(ast.Node.OneToken);
                node.* = .{
                    .base = .{ .tag = .CharLiteral },
                    .token = token,
                };
                return &node.base;
            } else {
                const token = try appendTokenFmt(c, .IntegerLiteral, "0x{x}", .{slice[1 .. slice.len - 1]});
                const node = try c.arena.create(ast.Node.OneToken);
                node.* = .{
                    .base = .{ .tag = .IntegerLiteral },
                    .token = token,
                };
                return &node.base;
            }
        },
        .StringLiteral => {
            const token = try appendToken(c, .StringLiteral, try zigifyEscapeSequences(c, m));
            const node = try c.arena.create(ast.Node.OneToken);
            node.* = .{
                .base = .{ .tag = .StringLiteral },
                .token = token,
            };
            return &node.base;
        },
        .IntegerLiteral, .FloatLiteral => {
            return parseCNumLit(c, m);
        },
        // eventually this will be replaced by std.c.parse which will handle these correctly
        .Keyword_void => return transCreateNodeIdentifierUnchecked(c, "c_void"),
        .Keyword_bool => return transCreateNodeIdentifierUnchecked(c, "bool"),
        .Keyword_double => return transCreateNodeIdentifierUnchecked(c, "f64"),
        .Keyword_long => return transCreateNodeIdentifierUnchecked(c, "c_long"),
        .Keyword_int => return transCreateNodeIdentifierUnchecked(c, "c_int"),
        .Keyword_float => return transCreateNodeIdentifierUnchecked(c, "f32"),
        .Keyword_short => return transCreateNodeIdentifierUnchecked(c, "c_short"),
        .Keyword_char => return transCreateNodeIdentifierUnchecked(c, "u8"),
        .Keyword_unsigned => if (m.next()) |t| switch (t) {
            .Keyword_char => return transCreateNodeIdentifierUnchecked(c, "u8"),
            .Keyword_short => return transCreateNodeIdentifierUnchecked(c, "c_ushort"),
            .Keyword_int => return transCreateNodeIdentifierUnchecked(c, "c_uint"),
            .Keyword_long => if (m.peek() != null and m.peek().? == .Keyword_long) {
                _ = m.next();
                return transCreateNodeIdentifierUnchecked(c, "c_ulonglong");
            } else return transCreateNodeIdentifierUnchecked(c, "c_ulong"),
            else => {
                m.i -= 1;
                return transCreateNodeIdentifierUnchecked(c, "c_uint");
            },
        } else {
            return transCreateNodeIdentifierUnchecked(c, "c_uint");
        },
        .Keyword_signed => if (m.next()) |t| switch (t) {
            .Keyword_char => return transCreateNodeIdentifierUnchecked(c, "i8"),
            .Keyword_short => return transCreateNodeIdentifierUnchecked(c, "c_short"),
            .Keyword_int => return transCreateNodeIdentifierUnchecked(c, "c_int"),
            .Keyword_long => if (m.peek() != null and m.peek().? == .Keyword_long) {
                _ = m.next();
                return transCreateNodeIdentifierUnchecked(c, "c_longlong");
            } else return transCreateNodeIdentifierUnchecked(c, "c_long"),
            else => {
                m.i -= 1;
                return transCreateNodeIdentifierUnchecked(c, "c_int");
            },
        } else {
            return transCreateNodeIdentifierUnchecked(c, "c_int");
        },
        .Keyword_enum, .Keyword_struct, .Keyword_union => {
            // struct Foo will be declared as struct_Foo by transRecordDecl
            const next_id = m.next().?;
            if (next_id != .Identifier) {
                try m.fail(c, "unable to translate C expr: expected Identifier instead got: {}", .{@tagName(next_id)});
                return error.ParseError;
            }

            const ident_token = try appendTokenFmt(c, .Identifier, "{}_{}", .{ slice, m.slice() });
            const identifier = try c.arena.create(ast.Node.OneToken);
            identifier.* = .{
                .base = .{ .tag = .Identifier },
                .token = ident_token,
            };
            return &identifier.base;
        },
        .Identifier => {
            const mangled_name = scope.getAlias(slice);
            return transCreateNodeIdentifier(c, checkForBuiltinTypedef(mangled_name) orelse mangled_name);
        },
        .LParen => {
            const inner_node = try parseCExpr(c, m, scope);

            const next_id = m.next().?;
            if (next_id != .RParen) {
                try m.fail(c, "unable to translate C expr: expected ')' instead got: {}", .{@tagName(next_id)});
                return error.ParseError;
            }
            var saw_l_paren = false;
            var saw_integer_literal = false;
            switch (m.peek().?) {
                // (type)(to_cast)
                .LParen => {
                    saw_l_paren = true;
                    _ = m.next();
                },
                // (type)sizeof(x)
                .Keyword_sizeof,
                // (type)alignof(x)
                .Keyword_alignof,
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

            const node_to_cast = try parseCExpr(c, m, scope);

            if (saw_l_paren and m.next().? != .RParen) {
                try m.fail(c, "unable to translate C expr: expected ')'", .{});
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
            try m.fail(c, "unable to translate C expr: unexpected token .{}", .{@tagName(tok)});
            return error.ParseError;
        },
    }
}

fn parseCPrimaryExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCPrimaryExprInner(c, m, scope);
    // In C the preprocessor would handle concatting strings while expanding macros.
    // This should do approximately the same by concatting any strings and identifiers
    // after a primary expression.
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.peek().?) {
            .StringLiteral, .Identifier => {},
            else => break,
        }
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .ArrayCat },
            .op_token = try appendToken(c, .PlusPlus, "++"),
            .lhs = node,
            .rhs = try parseCPrimaryExprInner(c, m, scope),
        };
        node = &op_node.base;
    }
    return node;
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

fn macroGroup(c: *Context, node: *ast.Node) !*ast.Node {
    if (!nodeIsInfixOp(node.tag)) return node;

    const group_node = try c.arena.create(ast.Node.GroupedExpression);
    group_node.* = .{
        .lparen = try appendToken(c, .LParen, "("),
        .expr = node,
        .rparen = try appendToken(c, .RParen, ")"),
    };
    return &group_node.base;
}

fn parseCCondExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    const node = try parseCOrExpr(c, m, scope);
    if (m.peek().? != .QuestionMark) {
        return node;
    }
    _ = m.next();

    // must come immediately after expr
    _ = try appendToken(c, .RParen, ")");
    const if_node = try transCreateNodeIf(c);
    if_node.condition = node;
    if_node.body = try parseCOrExpr(c, m, scope);
    if (m.next().? != .Colon) {
        try m.fail(c, "unable to translate C expr: expected ':'", .{});
        return error.ParseError;
    }
    if_node.@"else" = try transCreateNodeElse(c);
    if_node.@"else".?.body = try parseCCondExpr(c, m, scope);
    return &if_node.base;
}

fn parseCOrExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCAndExpr(c, m, scope);
    while (m.next().? == .PipePipe) {
        const lhs_node = try macroIntToBool(c, node);
        const op_token = try appendToken(c, .Keyword_or, "or");
        const rhs_node = try parseCAndExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .BoolOr },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroIntToBool(c, rhs_node),
        };
        node = &op_node.base;
    }
    m.i -= 1;
    return node;
}

fn parseCAndExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCBitOrExpr(c, m, scope);
    while (m.next().? == .AmpersandAmpersand) {
        const lhs_node = try macroIntToBool(c, node);
        const op_token = try appendToken(c, .Keyword_and, "and");
        const rhs_node = try parseCBitOrExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .BoolAnd },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroIntToBool(c, rhs_node),
        };
        node = &op_node.base;
    }
    m.i -= 1;
    return node;
}

fn parseCBitOrExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCBitXorExpr(c, m, scope);
    while (m.next().? == .Pipe) {
        const lhs_node = try macroBoolToInt(c, node);
        const op_token = try appendToken(c, .Pipe, "|");
        const rhs_node = try parseCBitXorExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .BitOr },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
    m.i -= 1;
    return node;
}

fn parseCBitXorExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCBitAndExpr(c, m, scope);
    while (m.next().? == .Caret) {
        const lhs_node = try macroBoolToInt(c, node);
        const op_token = try appendToken(c, .Caret, "^");
        const rhs_node = try parseCBitAndExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .BitXor },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
    m.i -= 1;
    return node;
}

fn parseCBitAndExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCEqExpr(c, m, scope);
    while (m.next().? == .Ampersand) {
        const lhs_node = try macroBoolToInt(c, node);
        const op_token = try appendToken(c, .Ampersand, "&");
        const rhs_node = try parseCEqExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = .BitAnd },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
    m.i -= 1;
    return node;
}

fn parseCEqExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCRelExpr(c, m, scope);
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.peek().?) {
            .BangEqual => {
                op_token = try appendToken(c, .BangEqual, "!=");
                op_id = .BangEqual;
            },
            .EqualEqual => {
                op_token = try appendToken(c, .EqualEqual, "==");
                op_id = .EqualEqual;
            },
            else => return node,
        }
        _ = m.next();
        const lhs_node = try macroBoolToInt(c, node);
        const rhs_node = try parseCRelExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCRelExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCShiftExpr(c, m, scope);
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.peek().?) {
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
            else => return node,
        }
        _ = m.next();
        const lhs_node = try macroBoolToInt(c, node);
        const rhs_node = try parseCShiftExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCShiftExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCAddSubExpr(c, m, scope);
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.peek().?) {
            .AngleBracketAngleBracketLeft => {
                op_token = try appendToken(c, .AngleBracketAngleBracketLeft, "<<");
                op_id = .BitShiftLeft;
            },
            .AngleBracketAngleBracketRight => {
                op_token = try appendToken(c, .AngleBracketAngleBracketRight, ">>");
                op_id = .BitShiftRight;
            },
            else => return node,
        }
        _ = m.next();
        const lhs_node = try macroBoolToInt(c, node);
        const rhs_node = try parseCAddSubExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCAddSubExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCMulExpr(c, m, scope);
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.peek().?) {
            .Plus => {
                op_token = try appendToken(c, .Plus, "+");
                op_id = .Add;
            },
            .Minus => {
                op_token = try appendToken(c, .Minus, "-");
                op_id = .Sub;
            },
            else => return node,
        }
        _ = m.next();
        const lhs_node = try macroBoolToInt(c, node);
        const rhs_node = try parseCMulExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCMulExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCUnaryExpr(c, m, scope);
    while (true) {
        var op_token: ast.TokenIndex = undefined;
        var op_id: ast.Node.Tag = undefined;
        switch (m.next().?) {
            .Asterisk => {
                if (m.peek().? == .RParen) {
                    // type *)

                    // hack to get zig fmt to render a comma in builtin calls
                    _ = try appendToken(c, .Comma, ",");

                    // last token of `node`
                    const prev_id = m.list[m.i - 1].id;

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
            .Slash => {
                op_id = .Div;
                op_token = try appendToken(c, .Slash, "/");
            },
            .Percent => {
                op_id = .Mod;
                op_token = try appendToken(c, .Percent, "%");
            },
            else => {
                m.i -= 1;
                return node;
            },
        }
        const lhs_node = try macroBoolToInt(c, node);
        const rhs_node = try parseCUnaryExpr(c, m, scope);
        const op_node = try c.arena.create(ast.Node.SimpleInfixOp);
        op_node.* = .{
            .base = .{ .tag = op_id },
            .op_token = op_token,
            .lhs = lhs_node,
            .rhs = try macroBoolToInt(c, rhs_node),
        };
        node = &op_node.base;
    }
}

fn parseCPostfixExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    var node = try parseCPrimaryExpr(c, m, scope);
    while (true) {
        switch (m.next().?) {
            .Period => {
                if (m.next().? != .Identifier) {
                    try m.fail(c, "unable to translate C expr: expected identifier", .{});
                    return error.ParseError;
                }

                node = try transCreateNodeFieldAccess(c, node, m.slice());
                continue;
            },
            .Arrow => {
                if (m.next().? != .Identifier) {
                    try m.fail(c, "unable to translate C expr: expected identifier", .{});
                    return error.ParseError;
                }
                const deref = try transCreateNodePtrDeref(c, node);
                node = try transCreateNodeFieldAccess(c, deref, m.slice());
                continue;
            },
            .LBracket => {
                const arr_node = try transCreateNodeArrayAccess(c, node);
                arr_node.index_expr = try parseCExpr(c, m, scope);
                arr_node.rtoken = try appendToken(c, .RBracket, "]");
                node = &arr_node.base;
                if (m.next().? != .RBracket) {
                    try m.fail(c, "unable to translate C expr: expected ']'", .{});
                    return error.ParseError;
                }
                continue;
            },
            .LParen => {
                _ = try appendToken(c, .LParen, "(");
                var call_params = std.ArrayList(*ast.Node).init(c.gpa);
                defer call_params.deinit();
                while (true) {
                    const arg = try parseCCondExpr(c, m, scope);
                    try call_params.append(arg);
                    switch (m.next().?) {
                        .Comma => _ = try appendToken(c, .Comma, ","),
                        .RParen => break,
                        else => {
                            try m.fail(c, "unable to translate C expr: expected ',' or ')'", .{});
                            return error.ParseError;
                        },
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
                    const val = try parseCCondExpr(c, m, scope);
                    try init_vals.append(val);
                    switch (m.next().?) {
                        .Comma => _ = try appendToken(c, .Comma, ","),
                        .RBrace => break,
                        else => {
                            try m.fail(c, "unable to translate C expr: expected ',' or '}}'", .{});
                            return error.ParseError;
                        },
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
            .PlusPlus, .MinusMinus => {
                try m.fail(c, "TODO postfix inc/dec expr", .{});
                return error.ParseError;
            },
            else => {
                m.i -= 1;
                return node;
            },
        }
    }
}

fn parseCUnaryExpr(c: *Context, m: *MacroCtx, scope: *Scope) ParseError!*ast.Node {
    switch (m.next().?) {
        .Bang => {
            const node = try transCreateNodeSimplePrefixOp(c, .BoolNot, .Bang, "!");
            node.rhs = try macroIntToBool(c, try parseCUnaryExpr(c, m, scope));
            return &node.base;
        },
        .Minus => {
            const node = try transCreateNodeSimplePrefixOp(c, .Negation, .Minus, "-");
            node.rhs = try macroBoolToInt(c, try parseCUnaryExpr(c, m, scope));
            return &node.base;
        },
        .Plus => return try parseCUnaryExpr(c, m, scope),
        .Tilde => {
            const node = try transCreateNodeSimplePrefixOp(c, .BitNot, .Tilde, "~");
            node.rhs = try macroBoolToInt(c, try parseCUnaryExpr(c, m, scope));
            return &node.base;
        },
        .Asterisk => {
            const node = try macroGroup(c, try parseCUnaryExpr(c, m, scope));
            return try transCreateNodePtrDeref(c, node);
        },
        .Ampersand => {
            const node = try transCreateNodeSimplePrefixOp(c, .AddressOf, .Ampersand, "&");
            node.rhs = try macroGroup(c, try parseCUnaryExpr(c, m, scope));
            return &node.base;
        },
        .Keyword_sizeof => {
            const inner = if (m.peek().? == .LParen) blk: {
                _ = m.next();
                // C grammar says this should be 'type-name' but we have to
                // use parseCMulExpr to correctly handle pointer types.
                const inner = try parseCMulExpr(c, m, scope);
                if (m.next().? != .RParen) {
                    try m.fail(c, "unable to translate C expr: expected ')'", .{});
                    return error.ParseError;
                }
                break :blk inner;
            } else try parseCUnaryExpr(c, m, scope);

            //(@import("std").meta.sizeof(dest, x))
            const import_fn_call = try c.createBuiltinCall("@import", 1);
            const std_node = try transCreateNodeStringLiteral(c, "\"std\"");
            import_fn_call.params()[0] = std_node;
            import_fn_call.rparen_token = try appendToken(c, .RParen, ")");
            const inner_field_access = try transCreateNodeFieldAccess(c, &import_fn_call.base, "meta");
            const outer_field_access = try transCreateNodeFieldAccess(c, inner_field_access, "sizeof");

            const sizeof_call = try c.createCall(outer_field_access, 1);
            sizeof_call.params()[0] = inner;
            sizeof_call.rtoken = try appendToken(c, .RParen, ")");
            return &sizeof_call.base;
        },
        .Keyword_alignof => {
            // TODO this won't work if using <stdalign.h>'s
            // #define alignof _Alignof
            if (m.next().? != .LParen) {
                try m.fail(c, "unable to translate C expr: expected '('", .{});
                return error.ParseError;
            }
            // C grammar says this should be 'type-name' but we have to
            // use parseCMulExpr to correctly handle pointer types.
            const inner = try parseCMulExpr(c, m, scope);
            if (m.next().? != .RParen) {
                try m.fail(c, "unable to translate C expr: expected ')'", .{});
                return error.ParseError;
            }

            const builtin_call = try c.createBuiltinCall("@alignOf", 1);
            builtin_call.params()[0] = inner;
            builtin_call.rparen_token = try appendToken(c, .RParen, ")");
            return &builtin_call.base;
        },
        .PlusPlus, .MinusMinus => {
            try m.fail(c, "TODO unary inc/dec expr", .{});
            return error.ParseError;
        },
        else => {
            m.i -= 1;
            return try parseCPostfixExpr(c, m, scope);
        },
    }
}

fn tokenSlice(c: *Context, token: ast.TokenIndex) []u8 {
    const tok = c.token_locs.items[token];
    const slice = c.source_buffer.items[tok.start..tok.end];
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
            const ident = node.castTag(.Identifier).?;
            if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |value| {
                if (value.cast(ast.Node.VarDecl)) |var_decl|
                    return getContainer(c, var_decl.getInitNode().?);
            }
        },

        .Period => {
            const infix = node.castTag(.Period).?;

            if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
                if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                    for (container.fieldsAndDecls()) |field_ref| {
                        const field = field_ref.cast(ast.Node.ContainerField).?;
                        const ident = infix.rhs.castTag(.Identifier).?;
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
    if (ref.castTag(.Identifier)) |ident| {
        if (c.global_scope.sym_table.get(tokenSlice(c, ident.token))) |value| {
            if (value.cast(ast.Node.VarDecl)) |var_decl| {
                if (var_decl.getTypeNode()) |ty|
                    return getContainer(c, ty);
            }
        }
    } else if (ref.castTag(.Period)) |infix| {
        if (getContainerTypeOf(c, infix.lhs)) |ty_node| {
            if (ty_node.cast(ast.Node.ContainerDecl)) |container| {
                for (container.fieldsAndDecls()) |field_ref| {
                    const field = field_ref.cast(ast.Node.ContainerField).?;
                    const ident = infix.rhs.castTag(.Identifier).?;
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
    const init = if (ref.cast(ast.Node.VarDecl)) |v| v.getInitNode().? else return null;
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
    var it = c.global_scope.macro_table.iterator();
    while (it.next()) |kv| {
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
