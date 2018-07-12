const ast = @import("std").zig.ast;

pub const ParsedFile = struct {
    tree: ast.Tree,
    realpath: []const u8,
};
