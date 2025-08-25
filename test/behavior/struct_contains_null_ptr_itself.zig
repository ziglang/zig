const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

test "struct contains null pointer which contains original struct" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    var x: ?*NodeLineComment = null;
    _ = &x;
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
