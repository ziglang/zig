inline fn x() bool {
    return true;
}

export fn entry() void {
    const y: *const fn () bool = @ptrCast(&x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :6:34: error: Cannot @ptrCast comptime type '*const fn () callconv(.Inline) bool' to non-comptime type '*const fn () bool'
