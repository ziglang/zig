const init: u32 = 1;
fn rt() u32 {
    return 3;
}

var tuple_val = .{init};
export fn tuple_field() void {
    tuple_val[0] = rt();
}

var struct_val = .{ .x = init };
export fn struct_field() void {
    struct_val.x = rt();
}

// error
//
// :8:14: error: cannot store runtime value in compile time variable
// :13:15: error: cannot store runtime value in compile time variable
