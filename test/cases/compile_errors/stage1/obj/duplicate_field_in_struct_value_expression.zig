const A = struct {
    x : i32,
    y : i32,
    z : i32,
};
export fn f() void {
    const a = A {
        .z = 1,
        .y = 2,
        .x = 3,
        .z = 4,
    };
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:11:9: error: duplicate field
