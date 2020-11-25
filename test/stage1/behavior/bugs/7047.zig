const std = @import("std");

const U = union(enum) {
    T: type,
    N: void,
};

fn S(comptime query: U) type {
    return struct {
        fn tag() type {
            return query.T;
        }
    };
}

test "compiler doesn't consider equal unions with different 'type' payload" {
    const s1 = S(U{ .T = u32 }).tag();
    std.testing.expectEqual(u32, s1);

    const s2 = S(U{ .T = u64 }).tag();
    std.testing.expectEqual(u64, s2);
}
