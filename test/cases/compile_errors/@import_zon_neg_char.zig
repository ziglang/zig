export fn entry() void {
    const f: u8 = @import("zon/neg_char.zon");
    _ = f;
}

// error
// imports=zon/neg_char.zon
//
// neg_char.zon:1:1: error: expected number or 'inf' after '-'
