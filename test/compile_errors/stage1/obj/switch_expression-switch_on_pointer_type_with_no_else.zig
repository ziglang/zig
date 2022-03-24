fn foo(x: *u8) void {
    switch (x) {
        &y => {},
    }
}
const y: u8 = 100;
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// switch expression - switch on pointer type with no else
//
// tmp.zig:2:5: error: else prong required when switching on type '*u8'
