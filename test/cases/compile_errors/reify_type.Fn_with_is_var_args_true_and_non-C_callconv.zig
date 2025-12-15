comptime {
    _ = @Fn(&.{u32}, &.{.{}}, u8, .{ .varargs = true });
}

// error
// target=x86_64-linux
//
// :2:36: error: variadic function does not support 'auto' calling convention
// :2:36: note: supported calling conventions: 'x86_64_sysv', 'x86_64_x32', 'x86_64_win'
