// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently it's not used by anything, as it's not feature complete.

const std = @import("std");
const ast = std.zig.ast;
const Token = std.zig.Token;
use @import("clang.zig");

pub const Mode = enum {
    import,
    translate,
};

pub const ClangErrMsg = Stage2ErrorMsg;

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

    try appendToken(tree, &source_buffer, "// TODO: implement more than just an empty source file", .LineComment);

    try appendToken(tree, &source_buffer, "", .Eof);
    tree.source = source_buffer.toOwnedSlice();
    return tree;
}

fn appendToken(tree: *ast.Tree, source_buffer: *std.Buffer, src_text: []const u8, token_id: Token.Id) !void {
    const start_index = source_buffer.len();
    try source_buffer.append(src_text);
    const end_index = source_buffer.len();
    const new_token = try tree.tokens.addOne();
    new_token.* = Token{
        .id = token_id,
        .start = start_index,
        .end = end_index,
    };
}

pub fn freeErrors(errors: []ClangErrMsg) void {
    ZigClangErrorMsg_delete(errors.ptr, errors.len);
}
