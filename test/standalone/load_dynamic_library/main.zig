const std = @import("std");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.testing.allocator);
    defer std.process.argsFree(std.testing.allocator, args);

    const dynlib_name = args[1];

    var lib = try std.DynLib.open(dynlib_name);
    defer lib.close();

    const addFn = lib.lookup(fn (i32, i32) callconv(.C) i32, "add") orelse return error.SymbolNotFound;

    const result = addFn(12, 34);
    std.debug.assert(result == 46);
}
