fn foo(x: *u8) void {
    switch (x) {
        &y => {},
    }
}
const y: u8 = 100;
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: else prong required when switching on type '*u8'
