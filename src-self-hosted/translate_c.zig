// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently the only way it is used is with `zig translate-c-2`.

const std = @import("std");
const ast = std.zig.ast;
const Token = std.zig.Token;
use @import("clang.zig");

pub const Mode = enum {
    import,
    translate,
};

pub const ClangErrMsg = Stage2ErrorMsg;

pub const Error = error {
    OutOfMemory,
};

const Context = struct {
    tree: *ast.Tree,
    source_buffer: *std.Buffer,
    err: Error,
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
    const arena = &tree_arena.allocator;

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
        .arena_allocator = tree_arena,
        .tokens = ast.Tree.TokenList.init(arena),
        .errors = ast.Tree.ErrorList.init(arena),
    };

    var source_buffer = try std.Buffer.initSize(arena, 0);

    var context = Context{
        .tree = tree,
        .source_buffer = &source_buffer,
        .err = undefined,
    };

    if (!ZigClangASTUnit_visitLocalTopLevelDecls(ast_unit, &context, declVisitorC)) {
        return context.err;
    }

    try appendToken(&context, .Eof, "");
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
            try appendToken(c, .LineComment, "// TODO translate function decl");
        },
        .Typedef => {
            try appendToken(c, .LineComment, "// TODO translate typedef");
        },
        .Enum => {
            try appendToken(c, .LineComment, "// TODO translate enum");
        },
        .Record => {
            try appendToken(c, .LineComment, "// TODO translate struct");
        },
        .Var => {
            try appendToken(c, .LineComment, "// TODO translate variable");
        },
        else => {
            // TODO emit_warning(c, bitcast(decl->getLocation()), "ignoring %s decl", decl->getDeclKindName());
            try appendToken(c, .LineComment, "// TODO translate unknown decl");
        },
    }
}

fn appendToken(c: *Context, token_id: Token.Id, src_text: []const u8) !void {
    const start_index = c.source_buffer.len();
    try c.source_buffer.append(src_text);
    const end_index = c.source_buffer.len();
    const new_token = try c.tree.tokens.addOne();
    new_token.* = Token{
        .id = token_id,
        .start = start_index,
        .end = end_index,
    };
    try c.source_buffer.appendByte('\n');
}

pub fn freeErrors(errors: []ClangErrMsg) void {
    ZigClangErrorMsg_delete(errors.ptr, errors.len);
}
