const assertOrPanic = @import("std").debug.assertOrPanic;

test "maybe return" {
    maybeReturnImpl();
    comptime maybeReturnImpl();
}

fn maybeReturnImpl() void {
    assertOrPanic(foo(1235).?);
    if (foo(null) != null) unreachable;
    assertOrPanic(!foo(1234).?);
}

fn foo(x: ?i32) ?bool {
    const value = x orelse return null;
    return value > 1234;
}

test "optional types" {
    comptime {
        const opt_type_struct = StructWithOptionalType{ .t = u8 };
        assertOrPanic(opt_type_struct.t != null and opt_type_struct.t.? == u8);
    }
}

const StructWithOptionalType = struct {
    t: ?type,
};
