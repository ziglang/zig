export fn returns() void {
    for ([_]void{}) |_, i| {
        for ([_]void{}) |_, j| {
            return _;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:20: error: '_' used as an identifier without @"_" syntax
