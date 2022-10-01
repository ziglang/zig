const std = @import("std");
fn a() error{}!void {}
fn b() std.meta.FnPtr(fn () error{}!void) {
    return &a;
}
export fn c() void {
    _ = b();
}
