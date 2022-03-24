const Number = enum {
    One,
    Two,
    Three,
    Four,
};
fn f(n: Number) i32 {
    switch (n) {
        Number.One => 1,
        Number.Two => 2,
        Number.Three => @as(i32, 3),
    }
}

export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// switch expression - missing enumeration prong
//
// tmp.zig:8:5: error: enumeration value 'Number.Four' not handled in switch
