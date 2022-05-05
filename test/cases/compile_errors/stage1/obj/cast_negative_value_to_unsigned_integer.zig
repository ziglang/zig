comptime {
    const value: i32 = -1;
    const unsigned = @intCast(u32, value);
    _ = unsigned;
}
export fn entry1() void {
    const value: i32 = -1;
    const unsigned: u32 = value;
    _ = unsigned;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:22: error: attempt to cast negative value to unsigned integer
// tmp.zig:8:27: error: cannot cast negative value -1 to unsigned integer type 'u32'
