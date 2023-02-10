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

const Object = struct {
    field_1: u32,
    field_2: u32,
};
fn dump(_: Object) void {}
pub export fn entry() void {
    dump(.{ .field_1 = 123, .field_3 = 456 });
}


// error
// backend=stage2
// target=native
//
// :10:10: error: no field named 'foo' in struct 'tmp.A'
// :1:11: note: struct declared here
// :21:30: error: no field named 'field_3' in struct 'tmp.Object'
// :15:16: note: struct declared here
