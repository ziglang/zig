const S = struct {
    const foo = 2;
    const bar = 2;
    const baz = 2;
    a: struct {
        a: u32,
        b: u32,
    },
    const foo1 = 2;
    const bar1 = 2;
    const baz1 = 2;
    b: usize,
};
comptime {
    _ = S;
}

// error
// backend=stage2
// target=native
//
// :9:5: error: declarations are not allowed between container fields
// :5:5: note: field before declarations here
// :12:5: note: field after declarations here
