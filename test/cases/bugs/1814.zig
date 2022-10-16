const assert = @import("std").debug.assert;

fn foo() ?anyerror!u32 {
    var x: u32 = 1234;
    return @as(anyerror!u32, x);
}

test {
    assert(try foo().? == 1234);
}

// run
// is_test=1
// backend=stage2
