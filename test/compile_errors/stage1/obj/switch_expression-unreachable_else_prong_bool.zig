fn foo(x: bool) void {
    switch (x) {
        true => {},
        false => {},
        else => {},
    }
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:5:9: error: unreachable else prong, all cases already handled
