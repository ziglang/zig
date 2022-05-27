const std = @import("std");
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();
    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit(); // no-op unless WASI or Windows
    _ = it.next() orelse unreachable; // skip binary name
    const input = it.next() orelse unreachable;
    var expect_helloworld = "hello world".*;
    try std.testing.expect(std.mem.eql(u8, &expect_helloworld, input));
    try std.testing.expect(it.next() == null);
    try std.testing.expect(!it.skip());
}
