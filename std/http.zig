test "std.http" {
    _ = @import("http/headers.zig");
}

pub const Headers = @import("http/headers.zig").Headers;
