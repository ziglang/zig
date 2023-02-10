inline fn foo(x: i32) i32 {
    if (x <= 0) {
        return 0;
    } else {
        return x * 2 + foo(x - 1);
    }
}

pub export fn entry() void {
    var x: i32 = 4;
    _ = foo(x) == 20;
}

// error
// backend=stage2
// target=native
//
// :5:27: error: inline call is recursive
