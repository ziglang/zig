const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;

test "struct contains null pointer which contains original struct" {
    var x: ?*NodeLineComment = null;
    assertOrPanic(x == null);
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
