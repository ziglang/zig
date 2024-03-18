comptime {
    _ = *align(1:32:4) u8;
}
comptime {
    _ = *align(1:25:4) u8;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: packed type 'u8' at bit offset 32 starts 0 bits after the end of a 4 byte host integer
// :5:18: error: packed type 'u8' at bit offset 25 ends 1 bits after the end of a 4 byte host integer
