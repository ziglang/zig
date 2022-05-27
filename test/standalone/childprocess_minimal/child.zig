const std = @import("std");
pub fn main() !void {
    var it = try std.process.argsWithAllocator(std.testing.allocator);
    defer it.deinit(); // no-op unless WASI or Windows
    _ = it.next() orelse unreachable; // skip binary name
    const input = it.next() orelse unreachable;
    var expect_helloworld = "hello world".*;
    try std.testing.expect(std.mem.eql(u8, &expect_helloworld, input));
    try std.testing.expect(it.next() == null);
    try std.testing.expect(!it.skip());
}
