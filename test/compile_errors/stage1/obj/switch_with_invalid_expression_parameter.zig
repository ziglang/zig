export fn entry() void {
    Test(i32);
}
fn Test(comptime T: type) void {
    const x = switch (T) {
        []u8 => |x| x,
        i32 => |x| x,
        else => unreachable,
    };
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:17: error: switch on type 'type' provides no expression parameter
