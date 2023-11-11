export fn entry() void {
    var frame = async func();
    var result = await frame;
    _ = &result;
}
fn func() void {
    suspend {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: function with calling convention 'C' cannot be async
// tmp.zig:3:18: note: await here is a suspend point
