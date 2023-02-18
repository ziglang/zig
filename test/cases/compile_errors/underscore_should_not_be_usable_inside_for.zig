export fn returns() void {
    for ([_]void{}, 0..) |_, i| {
        for ([_]void{}, 0..) |_, j| {
            return _;
        }
    }
}

// error
// backend=stage2
// target=native
//
// :4:20: error: '_' used as an identifier without @"_" syntax
