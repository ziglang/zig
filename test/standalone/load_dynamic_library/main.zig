const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.debug.global_allocator);
    defer std.process.argsFree(std.debug.global_allocator, args);

    const dynlib_name = args[1];

    var lib = try std.DynLib.open(dynlib_name);
    defer lib.close();

    const addr = lib.lookup("add") orelse return error.SymbolNotFound;
    const addFn = @intToPtr(extern fn (i32, i32) i32, addr);

    const result = addFn(12, 34);
    std.debug.assert(result == 46);
}
