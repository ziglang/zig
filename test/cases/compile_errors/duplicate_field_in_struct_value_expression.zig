const A = struct {
    x: i32,
    y: i32,
    z: i32,
};
export fn f() void {
    const a = A{
        .z = 1,
        .y = 2,
        .x = 3,
        .z = 4,
    };
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :8:10: error: duplicate struct field name
// :11:10: note: duplicate name here
// :7:16: note: struct declared here
