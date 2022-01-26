const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const builtin = @import("builtin");

test "self-referential struct through a slice of optional" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    const S = struct {
        const Node = struct {
            children: []?Node,
            data: ?u8,

            fn new() Node {
                return Node{
                    .children = undefined,
                    .data = null,
                };
            }
        };
    };

    var n = S.Node.new();
    try expect(n.data == null);
}
