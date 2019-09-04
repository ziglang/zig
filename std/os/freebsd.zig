const std = @import("../std.zig");
const builtin = @import("builtin");
pub const is_the_target = builtin.os == .freebsd;
pub usingnamespace std.c;
pub usingnamespace @import("bits.zig");
