const builtin = @import("builtin");
const std = @import("../std.zig");
pub const is_the_target = switch (builtin.os) {
    .macosx, .tvos, .watchos, .ios => true,
    else => false,
};
pub use std.c;
