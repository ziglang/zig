export fn entry() void {
    const f: u8 = @import("zon/neg_nan.zon");
    _ = f;
}

// error
// imports=zon/neg_nan.zon
//
// neg_nan.zon:1:1: error: expected number or 'inf' after '-'
