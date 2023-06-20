fn foo(x: u2) void {
    switch (x) {
        0 => {},
        1 => {},
        2 => {},
        3 => {},
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
// :7:14: error: unreachable else prong; all cases already handled
