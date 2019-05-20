const std = @import("../std.zig");
const builtin = @import("builtin");
pub const is_the_target = builtin.os == .freebsd;
pub use std.c;
