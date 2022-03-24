var x: f64 = 1.0;
var y: f32 = x;

export fn entry() usize { return @sizeOf(@TypeOf(y)); }

// implicit cast from f64 to f32
//
// tmp.zig:2:14: error: expected type 'f32', found 'f64'
