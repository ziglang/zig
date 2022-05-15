export fn entry() void {
    _ = @Type(0);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: expected type 'std.builtin.Type', found 'comptime_int'
