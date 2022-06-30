export fn returns() void {
    for ([_]void{}) |_, i| {
        for ([_]void{}) |_, j| {
            return _;
        }
    }
}

// error
// backend=stage2
// target=native
//
// :4:20: error: '_' used as an identifier without @"_" syntax
