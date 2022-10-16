const assert = @import("std").debug.assert;

test "@floatToInt compiler crash on c_longdouble" {
    const a: c_longdouble = 1.4;
    const b = @floatToInt(u32, a);
    _ = b;
}

// run
// is_test=1
// backend=llvm
