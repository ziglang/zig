const x : u8 = 300;
export fn entry() usize { return @sizeOf(@TypeOf(x)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:16: error: integer value 300 cannot be coerced to type 'u8'
