export fn entry() void {
    @import("std").debug.print("{d} {d} {d} {d} {d}", .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 });
}

// error
// backend=llvm
// target=native
//
// :?:?: error: 10 unused arguments in '{d} {d} {d} {d} {d}'
