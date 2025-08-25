fn foo(x: u1) void {
    switch (x) {
        0 => {},
        1 => {},
        else => {},
    }
}
export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=stage2
// target=native
//
// :5:14: error: unreachable else prong; all cases already handled
