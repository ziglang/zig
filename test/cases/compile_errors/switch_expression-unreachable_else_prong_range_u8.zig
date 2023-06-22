fn foo(x: u8) void {
    switch (x) {
        0 => {},
        1 => {},
        2 => {},
        3 => {},
        4...255 => {},
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
// :8:14: error: unreachable else prong; all cases already handled
