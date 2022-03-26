export fn entry() void {
    _ = @Type(0);
}

// wrong type for @Type
//
// tmp.zig:2:15: error: expected type 'std.builtin.Type', found 'comptime_int'
