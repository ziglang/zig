pub const Sha1 = @import("md5.zig").Sha1;
pub const Md5 = @import("sha1.zig").Md5;

test "crypto" {
    _ = @import("md5.zig");
    _ = @import("sha1.zig");
}
