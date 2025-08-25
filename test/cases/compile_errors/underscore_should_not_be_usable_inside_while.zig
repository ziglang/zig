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
// backend=stage2
// target=native
//
// :4:20: error: '_' used as an identifier without @"_" syntax
