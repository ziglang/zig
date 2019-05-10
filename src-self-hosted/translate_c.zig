// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently the only way it is used is with `zig translate-c-2`.

const std = @import("std");
const builtin = @import("builtin");
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
    };

    const Root = struct {
        base: Scope,
    };

    const While = struct {
        base: Scope,
    };
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
    const proto_node = switch (ZigClangType_getTypeClass(fn_type)) {
        .FunctionProto => transFnProto(
            rp,
            @ptrCast(*const ZigClangFunctionProtoType, fn_type),
            fn_decl_loc,
            fn_decl,
            fn_name,
        ) catch |err| switch (err) {
            error.UnsupportedType => {
                return failDecl(c, fn_decl_loc, fn_name, "unable to resolve prototype of function");
            },
            else => return err,
        },
        .FunctionNoProto => return failDecl(c, fn_decl_loc, fn_name, "TODO support functions with no prototype"),
        else => unreachable,
    };

    if (!ZigClangFunctionDecl_hasBody(fn_decl)) {
        const semi_tok = try appendToken(c, .Semicolon, ";");
        return addTopLevelDecl(c, fn_name, &proto_node.base);
    }

    try emitWarning(c, fn_decl_loc, "TODO implement function body translation");
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
                else => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported builtin type"),
            }
        },
        .FunctionProto => {
            const fn_proto_ty = @ptrCast(*const ZigClangFunctionProtoType, ty);
            const fn_proto = try transFnProto(rp, fn_proto_ty, source_loc, null, null);
            return &fn_proto.base;
        },
        else => {
            const type_name = rp.c.str(ZigClangType_getTypeClassName(ty));
            return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported type: '{}'", type_name);
        },
    }
}

fn transFnProto(
    rp: RestorePoint,
    fn_proto_ty: *const ZigClangFunctionProtoType,
    source_loc: ZigClangSourceLocation,
    opt_fn_decl: ?*const ZigClangFunctionDecl,
    fn_name: ?[]const u8,
) !*ast.Node.FnProto {
    const fn_ty = @ptrCast(*const ZigClangFunctionType, fn_proto_ty);
    const cc = switch (ZigClangFunctionType_getCallConv(fn_ty)) {
        .C => CallingConvention.C,
        .X86StdCall => CallingConvention.Stdcall,
        .X86FastCall => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 fastcall"),
        .X86ThisCall => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 thiscall"),
        .X86VectorCall => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 vectorcall"),
        .X86Pascal => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 pascal"),
        .Win64 => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: win64"),
        .X86_64SysV => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 64sysv"),
        .X86RegCall => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: x86 reg"),
        .AAPCS => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: aapcs"),
        .AAPCS_VFP => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: aapcs-vfp"),
        .IntelOclBicc => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: intel_ocl_bicc"),
        .SpirFunction => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: SPIR function"),
        .OpenCLKernel => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: OpenCLKernel"),
        .Swift => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: Swift"),
        .PreserveMost => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: PreserveMost"),
        .PreserveAll => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: PreserveAll"),
        .AArch64VectorCall => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported calling convention: AArch64VectorCall"),
    };

    const is_var_args = ZigClangFunctionProtoType_isVariadic(fn_proto_ty);
    const param_count: usize = ZigClangFunctionProtoType_getNumParams(fn_proto_ty);
    var i: usize = 0;
    while (i < param_count) : (i += 1) {
        return revertAndWarn(rp, error.UnsupportedType, source_loc, "TODO: implement parameters for FunctionProto in transType");
    }
    // TODO check for always_inline attribute
    // TODO check for align attribute

    // extern fn name(...) T
    const cc_tok = if (cc == .Stdcall) try appendToken(rp.c, .Keyword_stdcallcc, "stdcallcc") else null;
    const is_export = exp: {
        const fn_decl = opt_fn_decl orelse break :exp false;
        const has_body = ZigClangFunctionDecl_hasBody(fn_decl);
        const storage_class = ZigClangFunctionDecl_getStorageClass(fn_decl);
        break :exp switch (storage_class) {
            .None => switch (rp.c.mode) {
                .import => false,
                .translate => has_body,
            },
            .Extern, .Static => false,
            .PrivateExtern => return revertAndWarn(rp, error.UnsupportedType, source_loc, "unsupported storage class: private extern"),
            .Auto => unreachable, // Not legal on functions
            .Register => unreachable, // Not legal on functions
        };
    };
    const extern_export_inline_tok = if (is_export)
        try appendToken(rp.c, .Keyword_export, "export")
    else if (cc == .C)
        try appendToken(rp.c, .Keyword_extern, "extern")
    else
        null;
    const fn_tok = try appendToken(rp.c, .Keyword_fn, "fn");
    const name_tok = if (fn_name) |n| try appendToken(rp.c, .Identifier, "{}", n) else null;
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
                    else => return err,
                };
            }
        }
    };

    const fn_proto = try rp.c.a().create(ast.Node.FnProto);
    fn_proto.* = ast.Node.FnProto{
        .base = ast.Node{ .id = ast.Node.Id.FnProto },
        .doc_comments = null,
        .visib_token = null,
        .fn_token = fn_tok,
        .name_token = name_tok,
        .params = ast.Node.FnProto.ParamList.init(rp.c.a()),
        .return_type = ast.Node.FnProto.ReturnType{ .Explicit = return_type_node },
        .var_args_token = var_args_tok,
        .extern_export_inline_token = extern_export_inline_tok,
        .cc_token = cc_tok,
        .async_attr = null,
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
    args: ...,
) (@typeOf(err) || error{OutOfMemory}) {
    rp.activate();
    try emitWarning(rp.c, source_loc, format, args);
    return err;
}

fn emitWarning(c: *Context, loc: ZigClangSourceLocation, comptime format: []const u8, args: ...) !void {
    _ = try appendToken(c, .LineComment, "// {}: warning: " ++ format, c.locStr(loc), args);
}

fn failDecl(c: *Context, loc: ZigClangSourceLocation, name: []const u8, comptime format: []const u8, args: ...) !void {
    // const name = @compileError(msg);
    const const_tok = try appendToken(c, .Keyword_const, "const");
    const name_tok = try appendToken(c, .Identifier, "{}", name);
    const eq_tok = try appendToken(c, .Equal, "=");
    const builtin_tok = try appendToken(c, .Builtin, "@compileError");
    const lparen_tok = try appendToken(c, .LParen, "(");
    const msg_tok = try appendToken(c, .StringLiteral, "\"" ++ format ++ "\"", args);
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

fn appendToken(c: *Context, token_id: Token.Id, comptime format: []const u8, args: ...) !ast.TokenIndex {
    const S = struct {
        fn callback(context: *Context, bytes: []const u8) Error!void {
            return context.source_buffer.append(bytes);
        }
    };
    const start_index = c.source_buffer.len();
    errdefer c.source_buffer.shrink(start_index);

    try std.fmt.format(c, Error, S.callback, format, args);
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
    const token_index = try appendToken(c, .Identifier, "{}", name);
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
