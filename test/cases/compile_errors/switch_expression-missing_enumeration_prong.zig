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

export fn entry() usize {
    return @sizeOf(@TypeOf(&f));
}

// error
// backend=stage2
// target=native
//
// :8:5: error: switch must handle all possibilities
// :5:5: note: unhandled enumeration value: 'Four'
// :1:16: note: enum 'tmp.Number' declared here
