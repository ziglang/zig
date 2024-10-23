const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

extern fn add(a: u32, b: u32, addr: *usize) u32;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var debug_info = try std.debug.SelfInfo.open(allocator);
    defer debug_info.deinit();

    var add_addr: usize = undefined;
    _ = add(1, 2, &add_addr);

    const module = try debug_info.getModuleForAddress(add_addr);
    const symbol = try module.getSymbolAtAddress(allocator, add_addr);
    defer if (symbol.source_location) |sl| allocator.free(sl.file_name);

    try testing.expectEqualStrings("add", symbol.name);
    try testing.expect(symbol.source_location != null);
    try testing.expectEqualStrings("shared_lib.c", std.fs.path.basename(symbol.source_location.?.file_name));
    try testing.expectEqual(@as(u64, 3), symbol.source_location.?.line);
    try testing.expectEqual(@as(u64, 0), symbol.source_location.?.column);
}
