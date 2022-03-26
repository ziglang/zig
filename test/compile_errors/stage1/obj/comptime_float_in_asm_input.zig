export fn foo() void {
    asm volatile ("" : : [bar]"r"(3.17) : "");
}

// comptime_float in asm input
//
// tmp.zig:2:35: error: expected sized integer or sized float, found comptime_float
