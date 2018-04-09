const std = @import("../index.zig");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

pub const utf8 = @import("utf8.zig");
pub const ascii = @import("ascii.zig");

test "Representations" {
    _ = @import("utf8.zig");
    _ = @import("ascii.zig");
}