pub fn main() void {
    _ = bar();
}
inline fn bar() u8 {
    noret();
}
const std = @import("std");
inline fn noret() noreturn {
    std.process.exit(0);
}
