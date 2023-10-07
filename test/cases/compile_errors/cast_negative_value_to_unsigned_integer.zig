comptime {
    const value: i32 = -1;
    const unsigned: u32 = @intCast(value);
    _ = unsigned;
}
export fn entry1() void {
    const value: i32 = -1;
    const unsigned: u32 = value;
    _ = unsigned;
}

// error
// backend=llvm
// target=native
//
// :3:36: error: type 'u32' cannot represent integer value '-1'
// :8:27: error: type 'u32' cannot represent integer value '-1'
