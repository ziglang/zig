var x: f64 = 1.0;
var y: f32 = x;

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:14: error: expected type 'f32', found 'f64'
