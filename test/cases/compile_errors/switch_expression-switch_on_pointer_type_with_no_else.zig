fn foo(x: *u8) void {
    switch (x) {
        &y => {},
    }
}
var y: u8 = 100;
export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=stage2
// target=native
//
// :2:5: error: else prong required when switching on type '*u8'
