export fn entry() void {
    const f: u128 = @import("zon/invalid_number.zon");
    _ = f;
}

// error
// imports=zon/invalid_number.zon
//
// invalid_number.zon:1:19: error: invalid digit 'a' for decimal base
