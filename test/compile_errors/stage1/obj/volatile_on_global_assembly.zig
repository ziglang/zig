comptime {
    asm volatile ("");
}

// volatile on global assembly
//
// tmp.zig:2:9: error: volatile is meaningless on global assembly
