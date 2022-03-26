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

// invalid field in struct value expression
//
// tmp.zig:10:9: error: no member named 'foo' in struct 'A'
