const Foo = struct {
    a: i32 = crap,
    b: i32,
};
export fn entry() void {
    const x: Foo = .{
        .b = 5,
    };
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: use of undeclared identifier 'crap'
