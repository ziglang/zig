export fn entry() void {
    var var_1: f32 = undefined;
    var var_2: u32 = undefined;
    _ = @TypeOf(var_1, var_2);
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:4:9: error: incompatible types: 'f32' and 'u32'
