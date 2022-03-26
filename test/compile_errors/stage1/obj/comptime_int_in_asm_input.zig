export fn foo() void {
    asm volatile ("" : : [bar]"r"(3) : "");
}

// comptime_int in asm input
//
// tmp.zig:2:35: error: expected sized integer or sized float, found comptime_int
