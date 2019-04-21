// This is the userland implementation of translate-c which will be used by both stage1
// and stage2. Currently it's not used by anything, as it's not feature complete.

const std = @import("std");
const ast = std.zig.ast;
use @import("clang.zig");

pub const Mode = enum {
    import,
    translate,
};

pub fn translate(args_begin: [*]?[*]const u8, args_end: [*]?[*]const u8, mode: Mode) !*ast.Tree {
    return error.Unimplemented;
}
