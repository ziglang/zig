const std = @import("../std.zig");
const builtin = @import("builtin");
pub const is_the_target = builtin.os == .dragonfly;
pub use std.c;
