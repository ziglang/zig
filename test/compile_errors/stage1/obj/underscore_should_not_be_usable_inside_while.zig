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

// `_` should not be usable inside while
//
// tmp.zig:4:20: error: '_' used as an identifier without @"_" syntax
