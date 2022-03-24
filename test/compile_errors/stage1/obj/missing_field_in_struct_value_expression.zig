const A = struct {
    x : i32,
    y : i32,
    z : i32,
};
export fn f() void {
    // we want the error on the '{' not the 'A' because
    // the A could be a complicated expression
    const a = A {
        .z = 4,
        .y = 2,
    };
    _ = a;
}

// missing field in struct value expression
//
// tmp.zig:9:17: error: missing field: 'x'
