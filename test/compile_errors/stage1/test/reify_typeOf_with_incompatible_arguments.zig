export fn entry() void {
    var var_1: f32 = undefined;
    var var_2: u32 = undefined;
    _ = @TypeOf(var_1, var_2);
}

// @TypeOf with incompatible arguments
//
// tmp.zig:4:9: error: incompatible types: 'f32' and 'u32'
