export fn entry() void {
    var arr: [4]f32 = undefined;
    arr = concat();
}
fn concat() [16]f32 {
    return [1]f32{0}**16;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:17: error: expected type '[4]f32', found '[16]f32'
