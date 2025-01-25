var rt_slice: []const u8 = &.{ 1, 2, 3 };

export fn foo() void {
    inline for (rt_slice) |_| {}
}

export fn bar() void {
    inline while (rt_slice.len == 0) {}
}

// error
//
// :4:17: error: unable to resolve comptime value
// :4:17: note: inline loop condition must be comptime-known
// :8:32: error: unable to resolve comptime value
// :8:32: note: inline loop condition must be comptime-known
