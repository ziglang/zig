fn b(comptime T: type) ?*const fn () error{}!T {
    return null;
}

export fn entry() void {
    _ = b(void);
}
