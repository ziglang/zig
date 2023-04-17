const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    const dynlib_name = args[1];

    var lib = try std.DynLib.open(dynlib_name);
    defer lib.close();

    const Add = *const fn (i32, i32) callconv(.C) i32;
    const addFn = lib.lookup(Add, "add") orelse return error.SymbolNotFound;

    const result = addFn(12, 34);
    std.debug.assert(result == 46);
}
