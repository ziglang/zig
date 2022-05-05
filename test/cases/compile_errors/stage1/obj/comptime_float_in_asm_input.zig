export fn foo() void {
    asm volatile ("" : : [bar]"r"(3.17) : "");
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:35: error: expected sized integer or sized float, found comptime_float
