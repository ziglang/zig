fn foo(x: u8) void {
    switch (x) {
        0 => {},
    }
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: switch must handle all possibilities
