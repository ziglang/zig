export fn returns() void {
    while (optionalReturnError()) |_| {
        while (optionalReturnError()) |_| {
            return;
        } else |_| {
            if (_ == error.optionalReturnError) return;
        }
    }
}
fn optionalReturnError() !?u32 {
    return error.optionalReturnError;
}

// error
// backend=stage2
// target=native
//
// :6:17: error: '_' used as an identifier without @"_" syntax
