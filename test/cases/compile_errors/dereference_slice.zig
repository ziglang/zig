fn entry(x: []i32) i32 {
    return x.*;
}
comptime {
    _ = &entry;
}

// error
// backend=stage2
// target=native
//
// :2:13: error: index syntax required for slice type '[]i32'
