const assert = @import("std").debug.assert;

const updateHidden = @extern(*const fn (u32) callconv(.C) void, .{ .name = "updateHidden" });
const getHidden = @extern(*const fn () callconv(.C) u32, .{ .name = "getHidden" });

const T = extern struct { x: u32 };

test {
    const mut_val_ptr = @extern(*f64, .{ .name = "mut_val" });
    const const_val_ptr = @extern(*const T, .{ .name = "const_val" });

    assert(getHidden() == 0);
    updateHidden(123);
    assert(getHidden() == 123);

    assert(mut_val_ptr.* == 1.23);
    mut_val_ptr.* = 10.0;
    assert(mut_val_ptr.* == 10.0);

    assert(const_val_ptr.x == 42);
}
