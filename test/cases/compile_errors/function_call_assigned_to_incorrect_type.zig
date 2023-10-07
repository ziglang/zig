export fn entry() void {
    var arr: [4]f32 = undefined;
    arr = concat();
}
fn concat() [16]f32 {
    return [1]f32{0} ** 16;
}

// error
// backend=llvm
// target=native
//
// :3:17: error: expected type '[4]f32', found '[16]f32'
// :3:17: note: array of length 16 cannot cast into an array of length 4
