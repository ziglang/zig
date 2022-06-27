comptime {
    asm volatile ("");
}

// error
// backend=stage2
// target=native
//
// :2:9: error: volatile is meaningless on global assembly
