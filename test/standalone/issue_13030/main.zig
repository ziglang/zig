fn b(comptime T: type) ?@import("std").meta.FnPtr(fn () error{}!T) {
    return null;
}

export fn c() void {
    _ = b(void);
}
