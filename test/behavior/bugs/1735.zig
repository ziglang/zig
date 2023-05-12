const std = @import("std");
const builtin = @import("builtin");

const mystruct = struct {
    pending: ?listofstructs,
};
pub fn TailQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            prev: ?*Node,
            next: ?*Node,
            data: T,
        };

        first: ?*Node,
        last: ?*Node,
        len: usize,

        pub fn init() Self {
            return Self{
                .first = null,
                .last = null,
                .len = 0,
            };
        }
    };
}
const listofstructs = TailQueue(mystruct);

const a = struct {
    const Self = @This();

    foo: listofstructs,

    pub fn init() Self {
        return Self{
            .foo = listofstructs.init(),
        };
    }
};

test "initialization" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var t = a.init();
    try std.testing.expect(t.foo.len == 0);
}
