const A = struct {
    x : i32,
    y : i32,
    z : i32,
};
export fn f() void {
    const a = A {
        .z = 4,
        .y = 2,
        .foo = 42,
    };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :10:10: error: no field named 'foo' in struct 'tmp.A'
// :1:11: note: struct declared here
