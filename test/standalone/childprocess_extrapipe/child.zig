const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (general_purpose_allocator.deinit()) @panic("found memory leaks");
    const gpa = general_purpose_allocator.allocator();

    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const s_handle = it.next() orelse unreachable;
    var file_handle = try std.os.stringToHandle(s_handle);
    defer std.os.close(file_handle);

    // child inherited the handle, so inheritance must be enabled
    const is_inheritable = try std.os.isInheritable(file_handle);
    std.debug.assert(is_inheritable);

    try std.os.disableInheritance(file_handle);
    var file_in = std.fs.File{ .handle = file_handle }; // read side of pipe
    const file_in_reader = file_in.reader();
    const message = try file_in_reader.readUntilDelimiterAlloc(gpa, '\x17', 20_000);
    defer gpa.free(message);
    try std.testing.expectEqualSlices(u8, message, "test123");
}
