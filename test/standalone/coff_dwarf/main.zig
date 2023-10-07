const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

extern fn add(a: u32, b: u32, addr: *usize) u32;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var debug_info = try std.debug.openSelfDebugInfo(allocator);
    defer debug_info.deinit();

    var add_addr: usize = undefined;
    _ = add(1, 2, &add_addr);

    const module = try debug_info.getModuleForAddress(add_addr);
    const symbol = try module.getSymbolAtAddress(allocator, add_addr);
    defer symbol.deinit(allocator);

    try testing.expectEqualStrings("add", symbol.symbol_name);
    try testing.expect(symbol.line_info != null);
    try testing.expectEqualStrings("shared_lib.c", std.fs.path.basename(symbol.line_info.?.file_name));
    try testing.expectEqual(@as(u64, 3), symbol.line_info.?.line);
    try testing.expectEqual(@as(u64, 0), symbol.line_info.?.column);
}
