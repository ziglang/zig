fn entry(x: []i32) i32 {
    return x.*;
}
comptime {
    _ = &entry;
}

// error
//
// :2:13: error: index syntax required for slice type '[]i32'
