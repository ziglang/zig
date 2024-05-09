const std = @import("std");
fn foo() noreturn {
    std.process.exit(0);
}
fn bar(_: u8, _: u8) void {}
pub fn main() void {
    bar(foo(), @compileError("bad"));
}
