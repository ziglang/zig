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

// duplicate field in struct value expression
//
// tmp.zig:11:9: error: duplicate field
