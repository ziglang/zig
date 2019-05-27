const builtin = @import("builtin");
const std = @import("../std.zig");
pub const is_the_target = builtin.os == .netbsd;
pub use std.c;
