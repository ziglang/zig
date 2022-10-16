const assert = @import("std").debug.assert;

test "incorrect bounds check on @ptrCast const value" {
    const val: u32 = 0;
    const val_ptr = @ptrCast([*]const u8, &val);
    assert(val_ptr[1] == 0);
}

// run
// is_test=1
// backend=llvm
