const std = @import("../std.zig");
const builtin = @import("builtin");
pub const is_the_target = builtin.os == .linux;
pub const sys = @import("linux/sys.zig");
pub use if (builtin.link_libc) std.c else sys;

test "import" {
    if (is_the_target) {
        _ = @import("linux/test.zig");
    }
}
