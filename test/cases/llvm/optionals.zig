fn assert(ok: bool) void {
    if (!ok) unreachable;
}

pub fn main() void {
    var opt_val: ?i32 = 10;
    var null_val: ?i32 = null;

    var val1: i32 = opt_val.?;
    _ = &val1;
    const val1_1: i32 = opt_val.?;
    var ptr_val1 = &(opt_val.?);
    _ = &ptr_val1;
    const ptr_val1_1 = &(opt_val.?);

    var val2: i32 = null_val orelse 20;
    const val2_2: i32 = null_val orelse 20;

    var value: i32 = 20;
    var ptr_val2 = &(null_val orelse value);
    _ = &ptr_val2;

    const val3 = opt_val orelse 30;
    var val3_var = opt_val orelse 30;
    _ = &val3_var;

    assert(val1 == 10);
    assert(val1_1 == 10);
    assert(ptr_val1.* == 10);
    assert(ptr_val1_1.* == 10);

    assert(val2 == 20);
    assert(val2_2 == 20);
    assert(ptr_val2.* == 20);

    assert(val3 == 10);
    assert(val3_var == 10);

    (null_val orelse val2) = 1234;
    assert(val2 == 1234);

    (opt_val orelse val2) = 5678;
    assert(opt_val.? == 5678);
}

// run
// backend=llvm
// target=x86_64-linux,x86_64-macos
//
