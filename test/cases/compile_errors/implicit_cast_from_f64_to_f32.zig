var x: f64 = 1.0;
var y: f32 = x;

export fn entry() void {
    _ = y;
}
export fn entry2() void {
    var x1: f64 = 1.0;
    var y2: f32 = x1;
    _ = .{ &x1, &y2 };
}

// error
// backend=llvm
// target=native
//
// :2:14: error: expected type 'f32', found 'f64'
// :9:19: error: expected type 'f32', found 'f64'
