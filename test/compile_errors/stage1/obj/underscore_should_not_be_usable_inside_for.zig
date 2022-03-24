export fn returns() void {
    for ([_]void{}) |_, i| {
        for ([_]void{}) |_, j| {
            return _;
        }
    }
}

// `_` should not be usable inside for
//
// tmp.zig:4:20: error: '_' used as an identifier without @"_" syntax
