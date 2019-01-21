const assertOrPanic = @import("std").debug.assertOrPanic;

test "optional types" {
    comptime {
        const opt_type_struct = StructWithOptionalType{ .t = u8 };
        assertOrPanic(opt_type_struct.t != null and opt_type_struct.t.? == u8);
    }
}

const StructWithOptionalType = struct {
    t: ?type,
};
