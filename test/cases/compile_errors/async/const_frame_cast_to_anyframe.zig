export fn a() void {
    const f = async func();
    resume f;
}
export fn b() void {
    const f = async func();
    var x: anyframe = &f;
    _ = &x;
}
fn func() void {
    suspend {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:12: error: expected type 'anyframe', found '*const @Frame(func)'
// tmp.zig:7:24: error: expected type 'anyframe', found '*const @Frame(func)'
