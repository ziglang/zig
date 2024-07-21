const A = struct {
    x: i32,
    y: i32,
    z: i32,
};
export fn f() void {
    // we want the error on the '{' not the 'A' because
    // the A could be a complicated expression
    const a = A{
        .z = 4,
        .y = 2,
    };
    _ = a;
}

const B = struct { u32, u32 };
export fn g() void {
    const b = B{0};
    _ = b;
}
export fn h() void {
    const c = B{};
    _ = c;
}
// error
// backend=stage2
// target=native
//
// :9:16: error: missing struct field: x
// :1:11: note: struct declared here
// :18:16: error: missing tuple field with index 1
// :16:11: note: struct declared here
// :22:16: error: missing tuple field with index 0
// :22:16: note: missing tuple field with index 1
// :16:11: note: struct declared here
