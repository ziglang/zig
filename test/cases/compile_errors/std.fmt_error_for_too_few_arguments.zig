export fn entry() void {
    // we add extra garbage at the end of the format string to ensure they're properly escaped in the error message
    @import("std").debug.print("{d} {d} {d} {d} {d}\n\x00\"", .{ 1, 2, 3 });
}

// error
// backend=llvm
// target=native
//
// :?:?: error: too few arguments in '{d} {d} {d} {d} {d}\n\x00\"'
