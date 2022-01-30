const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "struct contains null pointer which contains original struct" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    var x: ?*NodeLineComment = null;
    try expect(x == null);
}

pub const Node = struct {
    id: Id,
    comment: ?*NodeLineComment,

    pub const Id = enum {
        Root,
        LineComment,
    };
};

pub const NodeLineComment = struct {
    base: Node,
};
