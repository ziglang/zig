export fn b() void {
    var buf: [5]u8 = undefined;
    _ = buf[foo(6)..][0..10];
    return error.TestFailed;
}

fn foo(a: u32) u32 {
    return a;
}

// error
// backend=stage2
// target=native
//
// :3:26: error: slice end index 10 exceeds array length of type '[5]u8'
