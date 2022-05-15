comptime {
    asm volatile ("");
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: volatile is meaningless on global assembly
