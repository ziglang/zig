export fn entry() void {
    var var_1: f32 = undefined;
    var var_2: u32 = undefined;
    _ = @TypeOf(var_1, var_2);
    _ = .{ &var_1, &var_2 };
}

// error
// backend=stage2
// target=native
//
// :4:9: error: incompatible types: 'f32' and 'u32'
// :4:17: note: type 'f32' here
// :4:24: note: type 'u32' here
