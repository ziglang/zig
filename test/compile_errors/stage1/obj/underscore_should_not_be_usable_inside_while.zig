export fn returns() void {
    while (optionalReturn()) |_| {
        while (optionalReturn()) |_| {
            return _;
        }
    }
}
fn optionalReturn() ?u32 {
    return 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:20: error: '_' used as an identifier without @"_" syntax
