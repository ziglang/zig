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
        Number.Four => 4,
        Number.Two => 2,
    }
}

export fn entry() usize {
    return @sizeOf(@TypeOf(&f));
}

// error
// backend=stage2
// target=native
//
// :13:15: error: duplicate switch value
// :10:15: note: previous value here
