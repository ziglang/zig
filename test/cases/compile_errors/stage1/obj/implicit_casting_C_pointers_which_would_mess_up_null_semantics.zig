export fn entry() void {
    var slice: []const u8 = "aoeu";
    const opt_many_ptr: [*]const u8 = slice.ptr;
    var ptr_opt_many_ptr = &opt_many_ptr;
    var c_ptr: [*c]const [*c]const u8 = ptr_opt_many_ptr;
    ptr_opt_many_ptr = c_ptr;
}
export fn entry2() void {
    var buf: [4]u8 = "aoeu".*;
    var slice: []u8 = &buf;
    var opt_many_ptr: [*]u8 = slice.ptr;
    var ptr_opt_many_ptr = &opt_many_ptr;
    var c_ptr: [*c][*c]const u8 = ptr_opt_many_ptr;
    _ = c_ptr;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:24: error: expected type '*const [*]const u8', found '[*c]const [*c]const u8'
// tmp.zig:6:24: note: pointer type child '[*c]const u8' cannot cast into pointer type child '[*]const u8'
// tmp.zig:6:24: note: '[*c]const u8' could have null values which are illegal in type '[*]const u8'
// tmp.zig:13:35: error: expected type '[*c][*c]const u8', found '*[*]u8'
// tmp.zig:13:35: note: pointer type child '[*]u8' cannot cast into pointer type child '[*c]const u8'
// tmp.zig:13:35: note: mutable '[*c]const u8' allows illegal null values stored to type '[*]u8'
