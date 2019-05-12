// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently the only way it is used is with `zig translate-c-2`.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const ast = std.zig.ast;
const Token = std.zig.Token;
use @import("clang.zig");

pub const Mode = enum {
    import,
    translate,
};

// TODO merge with Type.Fn.CallingConvention
const CallingConvention = builtin.TypeInfo.CallingConvention;

pub const ClangErrMsg = Stage2ErrorMsg;

pub const Error = error{
    OutOfMemory,
    UnsupportedType,
};
pub const TransError = error{
    OutOfMemory,
    UnsupportedTranslation,
};

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

    var tree_arena = std.heap.ArenaAllocator.init(backing_allocator);
    errdefer tree_arena.deinit();
    var arena = &tree_arena.allocator;

    const root_node = try arena.create(ast.Node.Root);
    root_node.* = ast.Node.Root{
        .base = ast.Node{ .id = ast.Node.Id.Root },
        .decls = ast.Node.Root.DeclList.init(arena),
        .doc_comments = null,
        // initialized with the eof token at the end
        .eof_token = undefined,
    };

    const tree = try arena.create(ast.Tree);
    tree.* = ast.Tree{
        .source = undefined, // need to use Buffer.toOwnedSlice later
        .root_node = root_node,
        .arena_allocator = undefined,
        .tokens = ast.Tree.TokenList.init(arena),
        .errors = ast.Tree.ErrorList.init(arena),
    };
    tree.arena_allocator = tree_arena;
    arena = &tree.arena_allocator.allocator;

    var source_buffer = try std.Buffer.initSize(arena, 0);

    var context = Context{
        .tree = tree,
        .source_buffer = &source_buffer,
        .source_manager = ZigClangASTUnit_getSourceManager(ast_unit),
        .err = undefined,
        .decl_table = DeclTable.init(arena),
        .global_scope = try arena.create(Scope.Root),
        .mode = mode,
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

    _ = try appendToken(&context, .Eof, "");
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
            .None => has_body,
            .Extern, .Static => false,
            .PrivateExtern => return failDecl(c, fn_decl_loc, fn_name, "unsupported storage class: private extern"),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        },
    };
    const proto_node = switch (ZigClangType_getTypeClass(fn_type)) {
        .FunctionProto => blk: {
            const fn_proto_type = @ptrCast(*const ZigClangFunctionProtoType, fn_type);
            break :blk transFnProto(rp, fn_proto_type, fn_decl_loc, decl_ctx) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function");
                },
                error.OutOfMemory => return error.OutOfMemory,
            };
        },
        .FunctionNoProto => blk: {
            const fn_no_proto_type = @ptrCast(*const ZigClangFunctionType, fn_type);
            break :blk transFnNoProto(rp, fn_no_proto_type, fn_decl_loc, decl_ctx) catch |err| switch (err) {
                error.UnsupportedType => {
                    return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function");
                },
                error.OutOfMemory => return error.OutOfMemory,
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
        error.OutOfMemory => return error.OutOfMemory,
        error.UnsupportedTranslation => return failDecl(c, fn_decl_loc, fn_name, "unable to translate function"),
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
        .CompoundStmtClass => return transCompoundStmt(rp, scope, @ptrCast(*const ZigClangCompoundStmt, stmt)),
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
        const result = try transStmt(rp, scope, it.*, .unused, .r_value);
        scope = result.child_scope;
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

fn addTopLevelDecl(c: *Context, name: []const u8, decl_node: *ast.Node) !void {
    try c.tree.root_node.decls.push(decl_node);
}

fn transQualType(rp: RestorePoint, qt: ZigClangQualType, source_loc: ZigClangSourceLocation) Error!*ast.Node {
    return transType(rp, ZigClangQualType_getTypePtr(qt), source_loc);
}

fn qualTypeCanon(qt: ZigClangQualType) *const ZigClangType {
    const canon = ZigClangQualType_getCanonicalType(qt);
    return ZigClangQualType_getTypePtr(canon);
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

fn transType(rp: RestorePoint, ty: *const ZigClangType, source_loc: ZigClangSourceLocation) Error!*ast.Node {
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
            const fn_proto = try transFnProto(rp, fn_proto_ty, source_loc, null);
            return &fn_proto.base;
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
) !*ast.Node.FnProto {
    const fn_ty = @ptrCast(*const ZigClangFunctionType, fn_proto_ty);
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = ZigClangFunctionProtoType_isVariadic(fn_proto_ty);
    const param_count: usize = ZigClangFunctionProtoType_getNumParams(fn_proto_ty);
    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        return revertAndWarn(rp, error.UnsupportedType, source_loc, "TODO: implement parameters for FunctionProto in transType");
    }

    return finishTransFnProto(rp, fn_ty, source_loc, fn_decl_context, is_var_args, cc);
}

fn transFnNoProto(
    rp: RestorePoint,
    fn_ty: *const ZigClangFunctionType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
) !*ast.Node.FnProto {
    const cc = try transCC(rp, fn_ty, source_loc);
    const is_var_args = if (fn_decl_context) |ctx| !ctx.is_export else true;
    return finishTransFnProto(rp, fn_ty, source_loc, fn_decl_context, is_var_args, cc);
}

fn finishTransFnProto(
    rp: RestorePoint,
    fn_ty: *const ZigClangFunctionType,
    source_loc: ZigClangSourceLocation,
    fn_decl_context: ?FnDeclContext,
    is_var_args: bool,
    cc: CallingConvention,
) !*ast.Node.FnProto {
    const is_export = if (fn_decl_context) |ctx| ctx.is_export else false;

    // TODO check for always_inline attribute
    // TODO check for align attribute

    // pub extern fn name(...) T
    const pub_tok = try appendToken(rp.c, .Keyword_pub, "pub");
    const cc_tok = if (cc == .Stdcall) try appendToken(rp.c, .Keyword_stdcallcc, "stdcallcc") else null;
    const extern_export_inline_tok = if (is_export)
        try appendToken(rp.c, .Keyword_export, "export")
    else if (cc == .C)
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
                    error.OutOfMemory => return error.OutOfMemory,
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
        .async_attr = null,
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
    try c.source_buffer.appendByte('\n');

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
