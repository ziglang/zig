export fn a() void {
    const f = async func();
    resume f;
}
export fn b() void {
    const f = async func();
    var x: anyframe = &f;
    _ = x;
}
fn func() void {
    suspend {}
}

// const frame cast to anyframe
//
// tmp.zig:3:12: error: expected type 'anyframe', found '*const @Frame(func)'
// tmp.zig:7:24: error: expected type 'anyframe', found '*const @Frame(func)'
